--[[
SpySuperWoW.lua - SuperWoW-based player detection for Spy

This module provides modern GUID-based player scanning when SuperWoW is available.
It falls back gracefully to the old CombatLog method on vanilla 1.12.1 clients.

Benefits with SuperWoW:
- Proactive detection (doesn't wait for combat)
- Finds stealthed/inactive players
- Real level data (no guessing needed)
- Lower CPU usage (no string parsing)
- More accurate player data (race, guild, etc.)
]]

--[[===========================================================================
	Tooltip Scanner (for reading buff names)
=============================================================================]]

-- Create Tooltip Scanner (like pfUI's libtipscan)
local SpyBuffScanner = CreateFrame("GameTooltip", "SpyBuffScanner", nil, "GameTooltipTemplate")
SpyBuffScanner:SetOwner(WorldFrame, "ANCHOR_NONE")

local function ScanBuffName(unit, buffIndex)
	SpyBuffScanner:ClearLines()
	SpyBuffScanner:SetOwner(WorldFrame, "ANCHOR_NONE")
	SpyBuffScanner:SetUnitBuff(unit, buffIndex)
	
	-- Read first line of tooltip (that's the buff name)
	local buffName = _G["SpyBuffScannerTextLeft1"]
	if buffName and buffName:IsVisible() then
		local text = buffName:GetText()
		return text
	end
	return nil
end

--[[===========================================================================
	SuperWoW Scanning System
=============================================================================]]

-- This table will be initialized by Spy.lua after it's loaded
local SpySW = {}

-- Statistics
SpySW.Stats = {
	guidsCollected = 0,
	eventsProcessed = 0,
	playersDetected = 0,
	scansPerformed = 0,
	lastScanTime = 0,
}

-- Track which players have already been sent to Spy
SpySW.detectedPlayers = {}

-- GUID storage
SpySW.guids = {}

-- Scan interval in seconds
SpySW.SCAN_INTERVAL = 0.5

-- GUID cleanup interval (check if units still exist)
SpySW.CLEANUP_INTERVAL = 5  -- Check every 5 seconds if GUIDs still exist

--[[===========================================================================
	GUID-based Faction Check (für Duel-Detection)
=============================================================================]]

-- Cache for player factions (GUID -> Faction)
SpySW.factionCache = {}

-- Get faction from GUID (works WITHOUT targeting!)
function SpySW:GetFactionByGUID(guid)
	if not guid then return nil end
	
	-- Check cache first
	if self.factionCache[guid] then
		return self.factionCache[guid]
	end
	
	-- Try to get faction from GUID directly
	if UnitExists(guid) then
		local faction = UnitFactionGroup(guid)
		if faction then
			-- Cache the result
			self.factionCache[guid] = faction
			return faction
		end
	end
	
	return nil
end

-- Get faction by player name (searches in GUID cache)
function SpySW:GetFactionByName(playerName)
	if not playerName then return nil end
	
	-- Search through our GUID cache
	for guid, timestamp in pairs(self.guids) do
		if UnitExists(guid) then
			local name = UnitName(guid)
			if name == playerName then
				-- Found the player, get their faction
				local faction = self:GetFactionByGUID(guid)
				return faction
			end
		end
	end
	
	return nil
end

-- Check if two players are same faction (duel check)
function SpySW:IsSameFaction(playerName1, playerName2)
	local faction1 = self:GetFactionByName(playerName1)
	local faction2 = self:GetFactionByName(playerName2)
	
	-- If we can't determine both factions, return nil (unknown)
	if not faction1 or not faction2 then
		return nil
	end
	
	-- Return true if same faction (duel), false if different (enemy)
	return faction1 == faction2
end

--[[===========================================================================
	Filter Functions (PvP-specific)
=============================================================================]]

local function IsPlayer(guid)
	return UnitIsPlayer(guid)
end

local function IsHostile(guid)
	return UnitIsEnemy("player", guid)
end

local function IsPvPFlagged(guid)
	return UnitIsPVP(guid)
end

local function IsAlive(guid)
	return not UnitIsDead(guid)
end

local function PassesSpyFilters(guid)
	if not UnitExists(guid) then
		return false
	end
	
	-- Only players
	if not IsPlayer(guid) then
		return false
	end
	
	-- Check factions
	local playerFaction = UnitFactionGroup("player")
	local targetFaction = UnitFactionGroup(guid)
	
	-- If we can determine both factions
	if playerFaction and targetFaction then
		-- Same faction = friendly, reject
		if playerFaction == targetFaction then
			return false
		end
		-- Different faction = enemy, accept if alive
		return IsAlive(guid)
	end
	
	-- Faction unknown (shouldn't happen but fallback to strict checks)
	if not IsHostile(guid) then
		return false
	end
	
	if not IsPvPFlagged(guid) then
		return false
	end
	
	if not IsAlive(guid) then
		return false
	end
	
	return true
end

--[[===========================================================================
	GUID Collection
=============================================================================]]

function SpySW:AddUnit(unit)
	local _, guid = UnitExists(unit)
	
	if guid then
		local isNew = self.guids[guid] == nil
		self.guids[guid] = GetTime()
		
		if isNew and UnitIsPlayer(guid) then
			self.Stats.guidsCollected = self.Stats.guidsCollected + 1
			-- Debug: Log when new GUID is collected
			if Spy and Spy.db and Spy.db.profile and Spy.db.profile.DebugMode then
				DEFAULT_CHAT_FRAME:AddMessage("|cffff00ff[SpySW]|r GUID collected: " .. (UnitName(guid) or "?") .. " via unit=" .. tostring(unit))
			end
		end
	end
end

-- Convert GUID to player name
function SpySW:GetNameFromGUID(guid)
	if not guid then return nil end
	
	-- Check if GUID exists in our tracked GUIDs
	if self.guids[guid] then
		-- GUID exists, get name from it
		if UnitExists(guid) then
			local name = UnitName(guid)
			return name
		end
	end
	
	return nil
end

--[[===========================================================================
	Player Data Extraction
=============================================================================]]

local function GetPlayerData(guid)
	if not UnitExists(guid) then
		return nil
	end
	
	local name = UnitName(guid)
	if not name then
		return nil
	end
	
	-- Filter out "Unknown" - Blizzard's placeholder when name hasn't loaded yet
	if name == "Unknown" then
		return nil
	end
	
	-- Build player data structure
	local data = {}
	data.name = name
	data.level = UnitLevel(guid) or 0
	
	-- Get class
	local class, classToken = UnitClass(guid)
	data.class = class
	data.classToken = classToken
	
	-- Get race
	local race, raceToken = UnitRace(guid)
	data.race = race
	data.raceToken = raceToken
	
	-- Get guild info if available
	data.guild = GetGuildInfo(guid)
	
	-- Check for stealth buffs via Tooltip Scanner (GUID-based - works without targeting!)
	data.isStealthed = false
	data.stealthType = nil
	
	-- Scan buffs with Tooltip Scanner using GUID directly
	for i = 1, 32 do
		local buffName = ScanBuffName(guid, i)
		if buffName then
			local nameLower = string.lower(tostring(buffName))
			
			-- Check for stealth buffs (multi-language)
			if string.find(nameLower, "prowl") or string.find(nameLower, "anschleichen") then
				data.isStealthed = true
				data.stealthType = "Prowl"
				break
			elseif string.find(nameLower, "stealth") or string.find(nameLower, "schleichen") then
				data.isStealthed = true
				data.stealthType = "Stealth"
				break
			elseif string.find(nameLower, "shadowmeld") or string.find(nameLower, "schattenhaftigkeit") then
				data.isStealthed = true
				data.stealthType = "Shadowmeld"
				break
			end
		end
	end
	
	-- Additional data
	data.isPlayer = true
	data.time = time()  -- Unix timestamp for Spy
	
	return data
end

--[[===========================================================================
	Scanning Loop
=============================================================================]]

function SpySW:ScanNearbyPlayers()
	local foundPlayers = {}
	local currentTime = GetTime()
	
	self.Stats.scansPerformed = self.Stats.scansPerformed + 1
	self.Stats.lastScanTime = currentTime
	
	-- Loop through all tracked GUIDs
	for guid, lastSeen in pairs(self.guids) do
		if PassesSpyFilters(guid) then
			local playerData = GetPlayerData(guid)
			
			if playerData then
				playerData.guid = guid  -- Store GUID for debugging
				table.insert(foundPlayers, playerData)
			end
		end
	end
	
	return foundPlayers
end

--[[===========================================================================
	GUID Cleanup
=============================================================================]]

function SpySW:CleanupOldGUIDs()
	local removed = 0
	
	-- Only remove GUIDs that no longer exist (not time-based)
	for guid, lastSeen in pairs(self.guids) do
		if not UnitExists(guid) then
			-- Also remove from detectedPlayers
			local name = UnitName(guid)
			if name and self.detectedPlayers[name] then
				self.detectedPlayers[name] = nil
			end
			
			self.guids[guid] = nil
			removed = removed + 1
		end
	end
end

--[[===========================================================================
	Event System
=============================================================================]]

local scanFrame = CreateFrame("Frame")
local scanTimer = 0
local cleanupTimer = 0

scanFrame:SetScript("OnUpdate", function()
	scanTimer = scanTimer + arg1
	cleanupTimer = cleanupTimer + arg1
	
	-- Scan for players
	if scanTimer >= SpySW.SCAN_INTERVAL then
		scanTimer = 0
		
		local players = SpySW:ScanNearbyPlayers()
		
		-- Send detected players to Spy's main system
		for _, playerData in ipairs(players) do
			local playerName = playerData.name
			
			-- Fix: Convert level -1 (skull) to 0 for Spy
			local level = playerData.level
			if level < 0 then
				level = 0
			end
			
			-- Check if player was already detected by US (not by Spy)
			if not SpySW.detectedPlayers[playerName] then
				-- Debug output (uses Spy's debug system)
				if Spy and Spy.db and Spy.db.profile and Spy.db.profile.DebugMode then
					local stealthStatus = playerData.isStealthed and (" [" .. (playerData.stealthType or "STEALTH") .. "]") or ""
					DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SpySW]|r NEW: " .. playerName .. " Lvl" .. level .. " " .. (playerData.class or "?") .. stealthStatus)
					DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SpySW]|r   Race: " .. (playerData.race or "?") .. " | PvP: " .. tostring(IsPvPFlagged(playerData.guid)) .. " | Hostile: " .. tostring(IsHostile(playerData.guid)))
					DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SpySW]|r   GUID: " .. tostring(playerData.guid))
				end
				
				-- Update player data (creates entry if doesn't exist)
				local detected = Spy:UpdatePlayerData(
					playerName,
					playerData.classToken,
					level,
					playerData.race,
					playerData.guild,
					true,  -- isEnemy
					false  -- isGuess (SuperWoW has real data!)
				)
				
				-- Always mark as detected (even if UpdatePlayerData failed) to prevent spam
				SpySW.detectedPlayers[playerName] = GetTime()
				
				-- Add to detected list if player was successfully added
				if detected and Spy.EnabledInZone then
					SpySW.Stats.playersDetected = SpySW.Stats.playersDetected + 1
					
					Spy:AddDetected(
						playerName,
						playerData.time,
						false,  -- learnt (not from combat log parsing)
						nil     -- source
					)
					
					-- Trigger stealth alert if player is stealthed
					if playerData.isStealthed and Spy.AlertStealthPlayer then
						if Spy.db and Spy.db.profile and Spy.db.profile.DebugMode then
							DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[SpySW]|r ✓ STEALTH ALERT: " .. playerName .. " (" .. (playerData.stealthType or "Unknown") .. ")")
						end
						Spy:AlertStealthPlayer(playerName)
					end
				end
			else
				-- Player already detected - update timestamp to keep them in Nearby list
				Spy:UpdatePlayerData(
					playerName,
					playerData.classToken,
					level,
					playerData.race,
					playerData.guild,
					true,
					false
				)
				
				-- WICHTIG: Auch AddDetected aufrufen damit Spy den Timestamp updated
				if Spy.EnabledInZone then
					Spy:AddDetected(
						playerName,
						playerData.time,
						false,
						nil
					)
				end
			end
		end
	end
	
	-- Cleanup old GUIDs
	if cleanupTimer >= SpySW.CLEANUP_INTERVAL then
		cleanupTimer = 0
		SpySW:CleanupOldGUIDs()
	end
end)

-- Register events for GUID collection
local guidFrame = CreateFrame("Frame")

-- These events provide unit information
guidFrame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
guidFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
guidFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

-- Unit events (arg1 contains unit)
guidFrame:RegisterEvent("UNIT_COMBAT")
guidFrame:RegisterEvent("UNIT_HAPPINESS")
guidFrame:RegisterEvent("UNIT_MODEL_CHANGED")
guidFrame:RegisterEvent("UNIT_PORTRAIT_UPDATE")
guidFrame:RegisterEvent("UNIT_FACTION")
guidFrame:RegisterEvent("UNIT_FLAGS")
guidFrame:RegisterEvent("UNIT_AURA")
guidFrame:RegisterEvent("UNIT_HEALTH")
guidFrame:RegisterEvent("UNIT_CASTEVENT")

guidFrame:SetScript("OnEvent", function()
	SpySW.Stats.eventsProcessed = SpySW.Stats.eventsProcessed + 1
	
	if event == "UPDATE_MOUSEOVER_UNIT" then
		SpySW:AddUnit("mouseover")
	elseif event == "PLAYER_ENTERING_WORLD" then
		SpySW:AddUnit("player")
		SpySW:AddUnit("target")
		SpySW:AddUnit("targettarget")
	elseif event == "PLAYER_TARGET_CHANGED" then
		SpySW:AddUnit("target")
		SpySW:AddUnit("targettarget")
	else
		SpySW:AddUnit(arg1)
	end
end)

--[[===========================================================================
	Enable/Disable
=============================================================================]]

function SpySW:Enable()
	scanFrame:Show()
	guidFrame:Show()
end

function SpySW:Disable()
	scanFrame:Hide()
	guidFrame:Hide()
end

--[[===========================================================================
	Info Function
=============================================================================]]

function SpySW:GetInfo()
	local guidCount = 0
	for _ in pairs(self.guids) do
		guidCount = guidCount + 1
	end
	
	return string.format("SuperWoW Active | Tracking %d GUIDs", guidCount)
end

function SpySW:PrintStatus()
	DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00========== SpySuperWoW Status ==========|r")
	
	-- Check if SuperWoW is available
	local hasSuperWoW = (GetPlayerBuffID ~= nil and CombatLogAdd ~= nil and SpellInfo ~= nil)
	
	if hasSuperWoW then
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00SuperWoW:|r |cff00ff00AVAILABLE|r")
		local _, testguid = UnitExists("player")
		if testguid then
			DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00GUID Test:|r " .. testguid)
		end
	else
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00SuperWoW:|r |cffff0000NOT AVAILABLE|r")
		DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00Using CombatLog fallback mode|r")
		return
	end
	
	-- Check if Spy is using SuperWoW
	if Spy and Spy.HasSuperWoW then
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Spy Mode:|r |cff00ff00SuperWoW Scanning|r")
	else
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Spy Mode:|r |cffffcc00CombatLog Fallback|r")
	end
	
	-- GUID count
	local guidCount = 0
	for _ in pairs(self.guids) do
		guidCount = guidCount + 1
	end
	DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Tracked GUIDs:|r " .. guidCount)
	
	-- Statistics
	DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Statistics:|r")
	DEFAULT_CHAT_FRAME:AddMessage("  GUIDs Collected: " .. self.Stats.guidsCollected)
	DEFAULT_CHAT_FRAME:AddMessage("  Events Processed: " .. self.Stats.eventsProcessed)
	DEFAULT_CHAT_FRAME:AddMessage("  Scans Performed: " .. self.Stats.scansPerformed)
	DEFAULT_CHAT_FRAME:AddMessage("  Players Detected: " .. self.Stats.playersDetected)
	
	-- Settings
	DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Settings:|r")
	DEFAULT_CHAT_FRAME:AddMessage("  Scan Interval: " .. self.SCAN_INTERVAL .. "s")
	DEFAULT_CHAT_FRAME:AddMessage("  Cleanup Interval: " .. self.CLEANUP_INTERVAL .. "s")
	
	-- Spy status
	if Spy then
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Spy Status:|r")
		DEFAULT_CHAT_FRAME:AddMessage("  Enabled: " .. tostring(Spy.IsEnabled or false))
		DEFAULT_CHAT_FRAME:AddMessage("  Enabled in Zone: " .. tostring(Spy.EnabledInZone or false))
	end
	
	DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00======================================|r")
end

-- Initialize
-- Module loaded successfully

--[[===========================================================================
	Initialization Function - Called by Spy.lua after it's loaded
=============================================================================]]

function SpySW:Initialize()
	DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SpySW]|r Initializing...")
	
	-- Check if SuperWoW is available by testing for SuperWoW-specific functions
	-- These functions only exist with SuperWoW installed
	local hasSuperWoW = (GetPlayerBuffID ~= nil and CombatLogAdd ~= nil and SpellInfo ~= nil)
	
	if not hasSuperWoW then
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SpySW]|r SuperWoW |cffff0000NOT DETECTED|r - using CombatLog fallback")
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SpySW]|r Install SuperWoW for better player detection!")
		return false
	end
	
	-- Test GUID functionality
	local _, testguid = UnitExists("player")
	if testguid then
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SpySW]|r SuperWoW |cff00ff00DETECTED|r - GUID: " .. testguid)
	else
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SpySW]|r SuperWoW |cff00ff00DETECTED|r")
	end
	DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SpySW]|r Commands: /spystatus")
	
	return true
end

-- Export to Spy namespace (will be set by Spy.lua)
SpyModules = SpyModules or {}
SpyModules.SuperWoW = SpySW

--[[===========================================================================
	Slash Commands - Registered AFTER export to global namespace
=============================================================================]]

SLASH_SPYSWSTATUS1 = "/spystatus"
SlashCmdList["SPYSWSTATUS"] = function()
	if SpyModules and SpyModules.SuperWoW then
		SpyModules.SuperWoW:PrintStatus()
	else
		DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[SpySW]|r Module not loaded!")
	end
end


SLASH_SPYBUFF1 = "/spybuff"
SlashCmdList["SPYBUFF"] = function()
	DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SpySW]|r === TARGET BUFF DETECTION TEST ===")
	
	if not UnitExists("target") then
		DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[SpySW]|r No target selected!")
		return
	end
	
	local targetName = UnitName("target")
	local _, targetGuid = UnitExists("target")
	local isEnemy = UnitIsEnemy("player", "target")
	local faction = UnitFactionGroup("target")
	
	DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SpySW]|r Target: " .. tostring(targetName))
	DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SpySW]|r GUID: " .. tostring(targetGuid))
	DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SpySW]|r Enemy: " .. tostring(isEnemy) .. " | Faction: " .. tostring(faction))
	
	-- Method 1: UnitBuff with "target" string
	DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SpySW]|r --- Method 1: UnitBuff('target', i) [Vanilla API] ---")
	local count1 = 0
	for i = 1, 32 do
		local texture = UnitBuff("target", i)
		if texture then
			count1 = count1 + 1
			local texLower = string.lower(tostring(texture))
			local isStealthBuff = string.find(texLower, "stealth") or string.find(texLower, "prowl") or string.find(texLower, "shadowmeld")
			local marker = isStealthBuff and " |cffff0000<-- STEALTH!|r" or ""
			DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SpySW]|r   " .. i .. ": " .. tostring(texture) .. marker)
		end
	end
	DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SpySW]|r   Total: " .. count1)
	
	-- Method 2: UnitBuff with GUID (SuperWoW extension)
	DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SpySW]|r --- Method 2: UnitBuff(guid, i) [SuperWoW GUID] ---")
	local count2 = 0
	if targetGuid then
		for i = 1, 32 do
			local texture = UnitBuff(targetGuid, i)
			if texture then
				count2 = count2 + 1
				local texLower = string.lower(tostring(texture))
				local isStealthBuff = string.find(texLower, "stealth") or string.find(texLower, "prowl") or string.find(texLower, "shadowmeld")
				local marker = isStealthBuff and " |cffff0000<-- STEALTH!|r" or ""
				DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SpySW]|r   " .. i .. ": " .. tostring(texture) .. marker)
			end
		end
	end
	DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SpySW]|r   Total: " .. count2)
	
	-- Method 3: _G.UnitBuff with SuperWoW extended returns (name, rank, etc)
	DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SpySW]|r --- Method 3: _G.UnitBuff('target', i) [SuperWoW Extended] ---")
	local count3 = 0
	for i = 1, 32 do
		local name, rank, texture, stacks, dtype, timeleft = _G.UnitBuff("target", i)
		if texture then
			count3 = count3 + 1
			local nameLower = name and string.lower(tostring(name)) or ""
			local texLower = string.lower(tostring(texture))
			local isStealthBuff = string.find(nameLower, "stealth") or string.find(nameLower, "prowl") or string.find(nameLower, "shadowmeld") or string.find(texLower, "stealth") or string.find(texLower, "prowl") or string.find(texLower, "shadowmeld")
			local marker = isStealthBuff and " |cffff0000<-- STEALTH!|r" or ""
			DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SpySW]|r   " .. i .. ": name=" .. tostring(name) .. " texture=" .. tostring(texture) .. marker)
		end
	end
	DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SpySW]|r   Total: " .. count3)
	
	-- Method 4: TargetFrame Buff Icons (UI Fallback)
	DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SpySW]|r --- Method 4: TargetFrameBuff Icons [UI Fallback] ---")
	local count4 = 0
	for i = 1, 16 do
		local buffFrame = getglobal("TargetFrameBuff" .. i)
		if buffFrame and buffFrame:IsVisible() then
			count4 = count4 + 1
			local icon = getglobal("TargetFrameBuff" .. i .. "Icon")
			if icon then
				local texture = icon:GetTexture()
				local texLower = string.lower(tostring(texture))
				local isStealthBuff = string.find(texLower, "stealth") or string.find(texLower, "prowl") or string.find(texLower, "shadowmeld")
				local marker = isStealthBuff and " |cffff0000<-- STEALTH!|r" or ""
				DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SpySW]|r   " .. i .. ": " .. tostring(texture) .. marker)
			end
		end
	end
	DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SpySW]|r   Total: " .. count4)
	
	-- Method 5: TargetFrame Debuff Icons
	DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SpySW]|r --- Method 5: TargetFrameDebuff Icons ---")
	local count5 = 0
	for i = 1, 16 do
		local debuffFrame = getglobal("TargetFrameDebuff" .. i)
		if debuffFrame and debuffFrame:IsVisible() then
			count5 = count5 + 1
			local icon = getglobal("TargetFrameDebuff" .. i .. "Icon")
			if icon then
				local texture = icon:GetTexture()
				DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SpySW]|r   " .. i .. ": " .. tostring(texture))
			end
		end
	end
	DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SpySW]|r   Total: " .. count5)
	
	-- Method 6: pfUI Detection (if available)
	DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SpySW]|r --- Method 6: pfUI.uf.target.buffs [pfUI Data] ---")
	if pfUI and pfUI.uf and pfUI.uf.target and pfUI.uf.target.buffs then
		local count6 = 0
		for i = 1, 32 do
			if pfUI.uf.target.buffs[i] and pfUI.uf.target.buffs[i]:IsShown() then
				count6 = count6 + 1
				local texture = pfUI.uf.target.buffs[i].texture:GetTexture()
				if texture then
					local texLower = string.lower(tostring(texture))
					local isStealthBuff = string.find(texLower, "stealth") or string.find(texLower, "prowl") or string.find(texLower, "shadowmeld")
					local marker = isStealthBuff and " |cffff0000<-- STEALTH!|r" or ""
					DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SpySW]|r   " .. i .. ": " .. tostring(texture) .. marker)
				end
			end
		end
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SpySW]|r   Total: " .. count6)
	else
		DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[SpySW]|r   pfUI not found or target frame not available")
	end
	
	-- Method 7: Check if pfUI DetectBuff works
	DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SpySW]|r --- Method 7: pfUI.uf:DetectBuff('target', i) ---")
	if pfUI and pfUI.uf and pfUI.uf.DetectBuff then
		local count7 = 0
		for i = 1, 32 do
			local texture, stacks = pfUI.uf:DetectBuff("target", i)
			if texture then
				count7 = count7 + 1
				local texLower = string.lower(tostring(texture))
				local isStealthBuff = string.find(texLower, "stealth") or string.find(texLower, "prowl") or string.find(texLower, "shadowmeld")
				local marker = isStealthBuff and " |cffff0000<-- STEALTH!|r" or ""
				DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SpySW]|r   " .. i .. ": " .. tostring(texture) .. marker)
			end
		end
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SpySW]|r   Total: " .. count7)
	else
		DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[SpySW]|r   pfUI.uf:DetectBuff not available")
	end
	
	-- Method 8a: Tooltip Scanner with "target" string
	DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SpySW]|r --- Method 8a: Tooltip Scanner ('target') ---")
	local count8a = 0
	local stealthBuffs8a = {}
	for i = 1, 32 do
		local buffName = ScanBuffName("target", i)
		if buffName then
			count8a = count8a + 1
			local nameLower = string.lower(tostring(buffName))
			local isStealthBuff = string.find(nameLower, "prowl") or 
			                      string.find(nameLower, "stealth") or 
			                      string.find(nameLower, "shadowmeld") or
			                      string.find(nameLower, "schleichen") or
			                      string.find(nameLower, "anschleichen")
			
			local marker = isStealthBuff and " |cffff0000<-- STEALTH!|r" or ""
			DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SpySW]|r   " .. i .. ": " .. tostring(buffName) .. marker)
			
			if isStealthBuff then
				table.insert(stealthBuffs8a, buffName)
			end
		end
	end
	DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SpySW]|r   Total: " .. count8a)
	
	-- Method 8b: Tooltip Scanner with GUID
	DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SpySW]|r --- Method 8b: Tooltip Scanner (GUID) ---")
	local count8b = 0
	local stealthBuffs8b = {}
	if targetGuid then
		for i = 1, 32 do
			local buffName = ScanBuffName(targetGuid, i)
			if buffName then
				count8b = count8b + 1
				local nameLower = string.lower(tostring(buffName))
				local isStealthBuff = string.find(nameLower, "prowl") or 
				                      string.find(nameLower, "stealth") or 
				                      string.find(nameLower, "shadowmeld") or
				                      string.find(nameLower, "schleichen") or
				                      string.find(nameLower, "anschleichen")
				
				local marker = isStealthBuff and " |cffff0000<-- STEALTH!|r" or ""
				DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SpySW]|r   " .. i .. ": " .. tostring(buffName) .. marker)
				
				if isStealthBuff then
					table.insert(stealthBuffs8b, buffName)
				end
			end
		end
	end
	DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SpySW]|r   Total: " .. count8b)
	
	-- Method 8c: Tooltip Scanner with mouseover (if exists)
	DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SpySW]|r --- Method 8c: Tooltip Scanner ('mouseover') ---")
	local count8c = 0
	local stealthBuffs8c = {}
	if UnitExists("mouseover") then
		local mouseoverName = UnitName("mouseover")
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SpySW]|r   Mouseover: " .. tostring(mouseoverName))
		
		for i = 1, 32 do
			local buffName = ScanBuffName("mouseover", i)
			if buffName then
				count8c = count8c + 1
				local nameLower = string.lower(tostring(buffName))
				local isStealthBuff = string.find(nameLower, "prowl") or 
				                      string.find(nameLower, "stealth") or 
				                      string.find(nameLower, "shadowmeld") or
				                      string.find(nameLower, "schleichen") or
				                      string.find(nameLower, "anschleichen")
				
				local marker = isStealthBuff and " |cffff0000<-- STEALTH!|r" or ""
				DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SpySW]|r   " .. i .. ": " .. tostring(buffName) .. marker)
				
				if isStealthBuff then
					table.insert(stealthBuffs8c, buffName)
				end
			end
		end
	else
		DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[SpySW]|r   No mouseover unit")
	end
	DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SpySW]|r   Total: " .. count8c)
	
	-- Summary
	local allStealthBuffs = {}
	for _, buff in ipairs(stealthBuffs8a) do table.insert(allStealthBuffs, "8a:" .. buff) end
	for _, buff in ipairs(stealthBuffs8b) do table.insert(allStealthBuffs, "8b:" .. buff) end
	for _, buff in ipairs(stealthBuffs8c) do table.insert(allStealthBuffs, "8c:" .. buff) end
	
	if table.getn(allStealthBuffs) > 0 then
		DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[SpySW]|r ✓ STEALTH DETECTED: " .. table.concat(allStealthBuffs, ", "))
	end
	
	DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SpySW]|r === TEST COMPLETE ===")
	DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[SpySW]|r Method 8a (target) = " .. count8a .. " buffs")
	DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[SpySW]|r Method 8b (GUID) = " .. count8b .. " buffs")
	DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[SpySW]|r Method 8c (mouseover) = " .. count8c .. " buffs")
	DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[SpySW]|r")
	DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[SpySW]|r If 8b or 8c work, we can scan buffs WITHOUT targeting!")
end

-- Make SpySW globally available for Spy.lua to use
_G.SpySW = SpySW

