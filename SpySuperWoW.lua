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
		end
	end
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
	DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SpySW]|r Commands: /spyswstatus")
	
	return true
end

-- Export to Spy namespace (will be set by Spy.lua)
SpyModules = SpyModules or {}
SpyModules.SuperWoW = SpySW

--[[===========================================================================
	Slash Commands - Registered AFTER export to global namespace
=============================================================================]]

SLASH_SPYSWSTATUS1 = "/spyswstatus"
SlashCmdList["SPYSWSTATUS"] = function()
	if SpyModules and SpyModules.SuperWoW then
		SpyModules.SuperWoW:PrintStatus()
	else
		DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[SpySW]|r Module not loaded!")
	end
end
