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

-- ✅ CRITICAL FIX: Register SpyModules.SuperWoW IMMEDIATELY as FIRST line of code
-- This MUST happen before ANY other code (including CreateFrame) so Spy:OnEnable finds it
SpyModules = SpyModules or {}
SpyModules.SuperWoW = SpyModules.SuperWoW or {}
local SpySW = SpyModules.SuperWoW

-- Performance: Cache global functions as locals
local strfind = string.find
local strlower = string.lower
local strformat = string.format
local tinsert = table.insert
local tgetn = table.getn
local tconcat = table.concat

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

-- SpySW already defined at top of file as SpyModules.SuperWoW

-- Statistics
SpySW.Stats = {
	guidsCollected = 0,
	eventsProcessed = 0,
	playersDetected = 0,
	scansPerformed = 0,
	lastScanTime = 0,
	petsSkipped = 0,  -- ✅ NEW: Track skipped pets
}

-- Track which players have already been sent to Spy
SpySW.detectedPlayers = {}

-- Track stealth state per player (to only alert on state change)
SpySW.lastStealthState = {}

-- GUID storage
SpySW.guids = {}

-- GUID storage
SpySW.enemyGuids = {}
SpySW.friendlyGuids = {}

-- ✅ NEW: Name-to-GUID mapping (persistent, doesn't rely on UnitExists)
SpySW.nameToGuid = {}

-- Scan interval in seconds
SpySW.SCAN_INTERVAL = 0.5

-- GUID cleanup interval (check if units still exist)
SpySW.CLEANUP_INTERVAL = 5  -- Check every 5 seconds if GUIDs still exist

-- ✅ Stealth Spell IDs (for UNIT_CASTEVENT detection)
SpySW.STEALTH_SPELL_IDS = {
	[1784] = "Stealth",      -- Rogue Stealth (Rank 1)
	[1785] = "Stealth",      -- Rogue Stealth (Rank 2)
	[1786] = "Stealth",      -- Rogue Stealth (Rank 3)
	[1787] = "Stealth",      -- Rogue Stealth (Rank 4)
	[5215] = "Prowl",        -- Druid Prowl (Rank 1)
	[6783] = "Prowl",        -- Druid Prowl (Rank 2)
	[9913] = "Prowl",        -- Druid Prowl (Rank 3)
	[20580] = "Shadowmeld (Racial)",  -- Night Elf Shadowmeld
	[1856] = "Vanish",       -- Rogue Vanish (Rank 1)
	[11327] = "Vanish",      -- Rogue Vanish (Rank 1)
    [1857] = "Vanish",       -- Rogue Vanish (Rank 2)
    [11329] = "Vanish",      -- Rogue Vanish (Rank 2)
}

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
        -- Different faction = enemy, but MUST be PvP flagged and alive
        if not IsPvPFlagged(guid) then
            return false
        end
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
	
	if not guid then return end
	
	-- ✅ Pet Filter (wie ShaguScan):
	-- Pet = NOT UnitIsPlayer AND UnitPlayerControlled
	local isPlayer = UnitIsPlayer(guid)
	local isControlled = UnitPlayerControlled(guid)
	local isPet = not isPlayer and isControlled
	
	if isPet then
		self.Stats.petsSkipped = self.Stats.petsSkipped + 1
		if Spy and Spy.db and Spy.db.profile and Spy.db.profile.DebugMode then
			DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[SpySW]|r SKIPPED PET: " .. (UnitName(guid) or "?"))
		end
		return
	end
	
	-- Only process real players
	if isPlayer then
		-- ✅ Additional safety: Real players ALWAYS have a class
		local class = UnitClass(guid)
		if not class then
			self.Stats.petsSkipped = self.Stats.petsSkipped + 1
			if Spy and Spy.db and Spy.db.profile and Spy.db.profile.DebugMode then
				DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[SpySW]|r SKIPPED: " .. (UnitName(guid) or "?") .. " (no class)")
			end
			return
		end
		
		local isNew = self.guids[guid] == nil
		self.guids[guid] = GetTime()
		
		-- ✅ Store name-to-GUID mapping (for targeting by name)
		local playerName = UnitName(guid)
		if playerName then
			self.nameToGuid[playerName] = guid
		end
		
		-- ✅ Separate by faction
		local playerFaction = UnitFactionGroup("player")
		local targetFaction = UnitFactionGroup(guid)
		
		if playerFaction and targetFaction then
			if playerFaction ~= targetFaction then
				-- Enemy - in enemy cache
				self.enemyGuids[guid] = GetTime()
			else
				-- Friendly - in friendly cache
				self.friendlyGuids[guid] = GetTime()
			end
		else
			-- Faction unknown, fallback to old method
			if UnitIsEnemy("player", guid) then
				self.enemyGuids[guid] = GetTime()
			else
				self.friendlyGuids[guid] = GetTime()
			end
		end
		
		if isNew then
			self.Stats.guidsCollected = self.Stats.guidsCollected + 1
			-- Debug: Log when new GUID is collected
			if Spy and Spy.db and Spy.db.profile and Spy.db.profile.DebugMode then
				DEFAULT_CHAT_FRAME:AddMessage("|cffff00ff[SpySW]|r GUID collected: " .. (UnitName(guid) or "?") .. " (" .. class .. ") via unit=" .. tostring(unit))
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

-- Convert player name to GUID (for targeting)
function SpySW:GetGUIDFromName(playerName)
	if not playerName then return nil end
	
	-- Check nameToGuid map first (fastest)
	local guid = self.nameToGuid[playerName]
	if guid then
		-- ✅ IMPORTANT: Return GUID even if UnitExists is false!
		-- SuperWoW's TargetUnit() can target players out of range
		return guid
	end
	
	-- Fallback: Search through all GUIDs (slower but works if map is outdated)
	for guid, timestamp in pairs(self.guids) do
		if UnitExists(guid) then
			local name = UnitName(guid)
			if name == playerName then
				-- Update map for future lookups
				self.nameToGuid[playerName] = guid
				return guid
			end
		end
	end
	
	-- Not found
	return nil
end

--[[===========================================================================
	Player Data Extraction
=============================================================================]]

local function GetPlayerData(guid)
	if not UnitExists(guid) then
		return nil
	end
	
	-- ✅ FIRST: Check if it's actually a player (before getting name!)
	if not UnitIsPlayer(guid) then
		return nil
	end
	
	-- ✅ NEW: Double-check - reject if it's classified as NPC
	if UnitClassification(guid) == "elite" or UnitClassification(guid) == "worldboss" or UnitClassification(guid) == "rare" or UnitClassification(guid) == "rareelite" then
		-- Skip boss mobs and elite NPCs
		return nil
	end
	
	-- ✅ SECOND: Verify PvP capability (must be attackable)
	if not UnitCanAttack("player", guid) then
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
			local nameLower = strlower(tostring(buffName))
			
			-- Check for stealth buffs (multi-language)
			if strfind(nameLower, "prowl") or strfind(nameLower, "anschleichen") then
				data.isStealthed = true
				data.stealthType = "Prowl"
				break
			elseif strfind(nameLower, "stealth") or strfind(nameLower, "schleichen") then
				data.isStealthed = true
				data.stealthType = "Stealth"
				break
			elseif strfind(nameLower, "shadowmeld") or strfind(nameLower, "schattenhaftigkeit") then
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

function SpySW:ScanNearbyPlayers(currentTime)
	local foundPlayers = {}
	local now = currentTime or GetTime()  -- Fallback if called without parameter
	
	self.Stats.scansPerformed = self.Stats.scansPerformed + 1
	self.Stats.lastScanTime = now
	
	-- ✅ Loop only over ENEMY GUIDs (no friendlies anymore!)
	for guid, lastSeen in pairs(self.enemyGuids) do
		-- ✅ CRITICAL FIX: Update timestamp when GUID exists again!
		-- This ensures that when a player comes back into range, the GUID doesn't get cleaned up
		if UnitExists(guid) then
			-- Update the timestamp (player is back in range!)
			self.enemyGuids[guid] = now
			
			-- Now check other filters
			if UnitIsPlayer(guid) and not UnitIsDead(guid) and UnitIsPVP(guid) then
				local playerData = GetPlayerData(guid)
				
				if playerData then
					playerData.guid = guid  -- Store GUID for debugging
					tinsert(foundPlayers, playerData)
				end
			end
		end
	end
	
	return foundPlayers
end

--[[===========================================================================
	GUID Cleanup
=============================================================================]]

function SpySW:CleanupOldGUIDs(currentTime)
	local removed = 0
	local now = currentTime or GetTime()  -- Fallback if called without parameter
	
	-- âœ… Cleanup main cache
	for guid, lastSeen in pairs(self.guids) do
		if not UnitExists(guid) then
			local name = UnitName(guid)
			if name then
				-- âœ… Check if this was an ENEMY or FRIENDLY player
				local wasEnemy = self.enemyGuids[guid] ~= nil
				local wasFriendly = self.friendlyGuids[guid] ~= nil
				
				local lastDetected = self.detectedPlayers[name]
				
				if wasFriendly then
					-- âœ… FRIENDLY: Remove immediately (no timeout)
					if lastDetected then
						self.detectedPlayers[name] = nil
						if Spy.db and Spy.db.profile and Spy.db.profile.DebugMode then
							DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa[SpySW Cleanup]|r Removed friendly " .. name .. " (no timeout)")
						end
					end
				elseif wasEnemy then
					-- âœ… ENEMY: Only remove after configured timeout
					if lastDetected then
						local timeout = Spy.InactiveTimeout or 60
						if timeout > 0 and (now - lastDetected) > timeout then
							self.detectedPlayers[name] = nil
							if Spy.db and Spy.db.profile and Spy.db.profile.DebugMode then
								DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa[SpySW Cleanup]|r Removed enemy " .. name .. " after " .. timeout .. "s timeout")
							end
						end
					end
				else
					-- âœ… UNKNOWN: Remove immediately (safety fallback)
					if lastDetected then
						self.detectedPlayers[name] = nil
						if Spy.db and Spy.db.profile and Spy.db.profile.DebugMode then
							DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa[SpySW Cleanup]|r Removed unknown " .. name .. " (no faction data)")
						end
					end
				end
				
				-- Reset stealth state (so it can re-alert when player returns)
				if self.lastStealthState[name] then
					self.lastStealthState[name] = nil
				end
				
				-- ✅ CRITICAL FIX: Clean up nameToGuid if this GUID is stale
				-- This prevents the expensive Priority 3 loop in RefreshCurrentList
				-- New GUID will be set when player is detected again
				if self.nameToGuid[name] == guid then
					self.nameToGuid[name] = nil
				end
			end
			
			self.guids[guid] = nil
			removed = removed + 1
		end
	end
	
	-- ✅ CRITICAL FIX: Keep GUIDs in enemyGuids cache longer!
	-- Don't remove immediately when UnitExists() returns false
	-- Only remove after the INACTIVE timeout (default 60 seconds)
	-- This allows the scanner to continue finding the player when they come back into range
	for guid, lastSeen in pairs(self.enemyGuids) do
		if not UnitExists(guid) then
			-- Check how long ago we last saw this GUID
			local timeSinceLastSeen = now - lastSeen
			local timeout = Spy.InactiveTimeout or 60
			
			-- Only remove after timeout (not immediately!)
			if timeout > 0 and timeSinceLastSeen > timeout then
				self.enemyGuids[guid] = nil
				if Spy.db and Spy.db.profile and Spy.db.profile.DebugMode then
					local name = UnitName(guid) or "Unknown"
					DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa[SpySW Cleanup]|r Removed enemy GUID " .. name .. " from cache after " .. math.floor(timeSinceLastSeen) .. "s")
				end
			end
		end
	end
	
	-- ✅ Cleanup friendly cache (these can be removed immediately)
	for guid, lastSeen in pairs(self.friendlyGuids) do
		if not UnitExists(guid) then
			self.friendlyGuids[guid] = nil
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
	-- ✅ PERFORMANCE: Cache GetTime() once per frame tick
	local currentTime = GetTime()
	
	-- Check if we should scan
	local isEnabled = Spy.db and Spy.db.profile and Spy.db.profile.Enabled and Spy.EnabledInZone
	-- ✅ FIX: Stealth-Only mode should work independently of EnabledInZone
	local stealthOnlyMode = Spy.db and Spy.db.profile and Spy.db.profile.WarnOnStealthEvenIfDisabled and not Spy.db.profile.Enabled
	
	-- Don't scan if Spy is disabled AND stealth-only mode is not active
	if not isEnabled and not stealthOnlyMode then
		return
	end
	
	scanTimer = scanTimer + arg1
	cleanupTimer = cleanupTimer + arg1
	
	-- Scan for players
	if scanTimer >= SpySW.SCAN_INTERVAL then
		scanTimer = 0
		
		local players = SpySW:ScanNearbyPlayers(currentTime)
		
		-- Send detected players to Spy's main system
		for _, playerData in ipairs(players) do
			local playerName = playerData.name
			
			-- Fix: Convert level -1 (skull) to 0 for Spy
			local level = playerData.level
			if level < 0 then
				level = 0
			end
			
			-- STEALTH-ONLY MODE: Only process stealthed players
			if stealthOnlyMode then
				-- Check if we were tracking this player's stealth state
				local wasStealthed = SpySW.lastStealthState[playerName]
				local isNowStealthed = playerData.isStealthed
				
				-- If player WAS stealthed but is NO LONGER stealthed → reset state
				if wasStealthed and not isNowStealthed then
					SpySW.lastStealthState[playerName] = nil
					if Spy.db and Spy.db.profile and Spy.db.profile.DebugMode then
						DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa[SpySW STEALTH-ONLY]|r " .. playerName .. " left stealth, state reset")
					end
				end
				
				if playerData.isStealthed then
					-- Only process stealth-capable classes (Rogue, Druid, Night Elf)
					local class = playerData.classToken
					local race = playerData.race
					local isStealthCapable = (class == "ROGUE" or class == "DRUID" or race == "Night Elf")
					
					if isStealthCapable and Spy and Spy.AlertStealthPlayer then
						-- Check stealth state transition
						local wasStealthed = SpySW.lastStealthState[playerName]
						local isNowStealthed = true  -- We're in the isStealthed branch
						
						-- Only alert on transition: not-stealth → stealth
						if not wasStealthed then
							if Spy.db and Spy.db.profile and Spy.db.profile.DebugMode then
								DEFAULT_CHAT_FRAME:AddMessage("|cffff00ff[SpySW STEALTH-ONLY]|r " .. playerName .. " (" .. (playerData.stealthType or "Unknown") .. ")")
							end
							Spy:AlertStealthPlayer(playerName)
						end
						
						-- Update stealth state
						SpySW.lastStealthState[playerName] = isNowStealthed
					end
				end
			-- NORMAL MODE: Process all players
			else
				-- ✅ FIX: Check stealth state at the beginning for ALL cases
				local wasDetected = SpySW.detectedPlayers[playerName]
				local wasStealthed = SpySW.lastStealthState[playerName]
				local isNowStealthed = playerData.isStealthed
				
				-- Check if player was already detected by US (not by Spy)
				if not wasDetected then
					-- Check if player is on Ignore list
					if SpyPerCharDB and SpyPerCharDB.IgnoreData and SpyPerCharDB.IgnoreData[playerName] then
						-- Player is ignored, skip detection
						if Spy and Spy.db and Spy.db.profile and Spy.db.profile.DebugMode then
							DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa[SpySW]|r IGNORED: " .. playerName .. " (on Ignore list)")
						end
						-- Mark as detected to prevent spam, but don't add to Spy
						SpySW.detectedPlayers[playerName] = currentTime
					-- ✅ CRITICAL FIX: Check if player passes faction/PvP filters
					elseif not PassesSpyFilters(playerData.guid) then
						-- Player is friendly faction, not PvP flagged, or dead - skip
						if Spy and Spy.db and Spy.db.profile and Spy.db.profile.DebugMode then
							local faction = UnitFactionGroup(playerData.guid) or "?"
							local pvp = IsPvPFlagged(playerData.guid) and "YES" or "NO"
							DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa[SpySW]|r FILTERED: " .. playerName .. " (Faction: " .. faction .. ", PvP: " .. pvp .. ")")
						end
						-- Mark as detected to prevent spam
						SpySW.detectedPlayers[playerName] = currentTime
					else
						-- Player NOT ignored - proceed with normal detection
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
						SpySW.detectedPlayers[playerName] = currentTime
						
						-- Add to detected list if player was successfully added
						if detected and Spy.EnabledInZone then
							SpySW.Stats.playersDetected = SpySW.Stats.playersDetected + 1
							
							Spy:AddDetected(
								playerName,
								playerData.time,
								false,  -- learnt (not from combat log parsing)
								nil     -- source
							)
							
							-- Debug: Scanner added player to Nearby
							if Spy and Spy.db and Spy.db.profile and Spy.db.profile.DebugMode then
								DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SpySW SCAN]|r ✓ Added to Nearby (Scanner): " .. playerName)
							end
							
							-- ✅ Trigger stealth alert if player is stealthed (only on state change)
							if isNowStealthed and not wasStealthed and Spy.AlertStealthPlayer then
								-- Check battleground setting
								local allowAlert = true
								
								if Spy.InInstance and not Spy.db.profile.EnabledInBattlegrounds then
									allowAlert = false
									if Spy.db and Spy.db.profile and Spy.db.profile.DebugMode then
										DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa[SpySW]|r Stealth alert skipped: Battlegrounds disabled")
									end
								end
								
								-- Check PvP flag requirement
								if allowAlert and Spy.db and Spy.db.profile and Spy.db.profile.DisableWhenPVPUnflagged then
									if not UnitIsPVP("player") then
										allowAlert = false
										if Spy.db.profile.DebugMode then
											DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa[SpySW]|r Stealth alert skipped: Player not PvP flagged")
										end
									end
								end
								
								if allowAlert then
									if Spy.db and Spy.db.profile and Spy.db.profile.DebugMode then
										DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[SpySW]|r ✔ STEALTH ALERT: " .. playerName .. " (" .. (playerData.stealthType or "Unknown") .. ")")
									end
									Spy:AlertStealthPlayer(playerName)
								end
							end
							
							-- ✅ Update stealth state for next scan
							SpySW.lastStealthState[playerName] = isNowStealthed
							
							-- ✅ Reset stealth state if player is no longer stealthed
							if not isNowStealthed and wasStealthed then
								if Spy.db and Spy.db.profile and Spy.db.profile.DebugMode then
									DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa[SpySW]|r " .. playerName .. " left stealth, state reset")
								end
							end
						end
					end
				else
					-- ✅ NEW: Player already detected - check for stealth state change!
					-- IMPORTANT: Auch bei bereits erkannten playern Stealth-Änderungen tracken!
					if isNowStealthed and not wasStealthed then
						-- Check if player is on Ignore list
						if not (SpyPerCharDB and SpyPerCharDB.IgnoreData and SpyPerCharDB.IgnoreData[playerName]) then
							-- Stealth transition detected!
							if Spy and Spy.AlertStealthPlayer then
								-- Check battleground setting
								local allowAlert = true
								
								if Spy.InInstance and not Spy.db.profile.EnabledInBattlegrounds then
									allowAlert = false
									if Spy.db and Spy.db.profile and Spy.db.profile.DebugMode then
										DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa[SpySW]|r Stealth alert skipped: Battlegrounds disabled")
									end
								end
								
								-- Check PvP flag requirement
								if allowAlert and Spy.db and Spy.db.profile and Spy.db.profile.DisableWhenPVPUnflagged then
									if not UnitIsPVP("player") then
										allowAlert = false
										if Spy.db.profile.DebugMode then
											DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa[SpySW]|r Stealth alert skipped: Player not PvP flagged")
										end
									end
								end
								
								if allowAlert then
									if Spy.db and Spy.db.profile and Spy.db.profile.DebugMode then
										DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[SpySW SCAN]|r ✔ STEALTH ALERT (already detected): " .. playerName .. " (" .. (playerData.stealthType or "Unknown") .. ")")
									end
									Spy:AlertStealthPlayer(playerName)
								end
							end
						end
					end
					
					-- ✅ Update stealth state (wichtig!)
					SpySW.lastStealthState[playerName] = isNowStealthed
					
					-- Player already detected - update timestamp to keep them in Nearby list
					-- Check if player is on Ignore list (even for already detected players)
					if not (SpyPerCharDB and SpyPerCharDB.IgnoreData and SpyPerCharDB.IgnoreData[playerName]) then
			-- ✅ CRITICAL FIX: Update detectedPlayers timestamp!
			-- This prevents the 60s cleanup timer from removing players who are still in range
			SpySW.detectedPlayers[playerName] = currentTime

						Spy:UpdatePlayerData(
							playerName,
							playerData.classToken,
							level,
							playerData.race,
							playerData.guild,
							true,
							false
						)
						
						-- IMPORTANT: Auch AddDetected aufrufen damit Spy den Timestamp updated
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
			end  -- end else (normal mode)
		end  -- end for loop
	end
	
	-- Cleanup old GUIDs
	if cleanupTimer >= SpySW.CLEANUP_INTERVAL then
		cleanupTimer = 0
		SpySW:CleanupOldGUIDs(currentTime)
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
	-- Check if we should collect GUIDs
	local isEnabled = Spy.db and Spy.db.profile and Spy.db.profile.Enabled and Spy.EnabledInZone
	local stealthOnlyMode = Spy.db and Spy.db.profile and Spy.db.profile.WarnOnStealthEvenIfDisabled and not isEnabled
	
	-- Don't collect GUIDs if Spy is disabled AND stealth-only mode is not active
	if not isEnabled and not stealthOnlyMode then
		return
	end
	
	SpySW.Stats.eventsProcessed = SpySW.Stats.eventsProcessed + 1
	
	if event == "UPDATE_MOUSEOVER_UNIT" then
		local unit = "mouseover"
		-- Nur player sammeln
		if UnitExists(unit) and UnitIsPlayer(unit) then
			SpySW:AddUnit(unit)
		end
	elseif event == "PLAYER_ENTERING_WORLD" then
		SpySW:AddUnit("player")
		SpySW:AddUnit("target")
		SpySW:AddUnit("targettarget")
	elseif event == "PLAYER_TARGET_CHANGED" then
		local unit = "target"
		-- Nur player sammeln
		if UnitExists(unit) and UnitIsPlayer(unit) then
			SpySW:AddUnit(unit)
		end
		local unit2 = "targettarget"
		if UnitExists(unit2) and UnitIsPlayer(unit2) then
			SpySW:AddUnit(unit2)
		end
	elseif event == "UNIT_CASTEVENT" then
		-- ✅ NEW: Handle UNIT_CASTEVENT for instant Stealth detection
		SpySW:OnUnitCastEvent(arg1, arg2, arg3, arg4, arg5)
	else
		-- For all other events (UNIT_COMBAT, etc): Only collect players
		local unit = arg1
		if unit and UnitExists(unit) and UnitIsPlayer(unit) then
			SpySW:AddUnit(unit)
		end
	end
end)

--[[===========================================================================
	UNIT_CASTEVENT Handler (Instant Stealth Detection)
=============================================================================]]

function SpySW:OnUnitCastEvent(casterGUID, targetGUID, eventType, spellID, castDuration)
    -- Nur CAST und CHANNEL Events verarbeiten
    if eventType ~= "CAST" and eventType ~= "CHANNEL" then
        return
    end

    local isDebug = Spy and Spy.db and Spy.db.profile and Spy.db.profile.DebugMode
    local isEnabled = Spy and Spy.db and Spy.db.profile and Spy.db.profile.Enabled and Spy.EnabledInZone
    local stealthOnlyMode = Spy and Spy.db and Spy.db.profile and Spy.db.profile.WarnOnStealthEvenIfDisabled and not isEnabled

    -- Wenn beide Modi inaktiv sind, abbrechen
    if not isEnabled and not stealthOnlyMode then
        return
    end
    
    -- === INITIALE GUID/SPIELER-PRUEFUNG ===
    
    if not casterGUID or not UnitExists(casterGUID) then
        return
    end
    
    if not UnitIsPlayer(casterGUID) then
        return
    end
    
    local playerName = UnitName(casterGUID)
    if not playerName then
        if isDebug then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff7700[SpySW DEBUG]|r UNIT_CASTEVENT: Could not resolve name for GUID: " .. casterGUID)
        end
        return
    end
    
    -- === ALLGEMEINE FILTER (Gelten fuer NEARBY-Hinzufuegung und Alarm) ===

    -- 1. Ignorier-Liste (Hoechste Prioritaet)
    if SpyPerCharDB and SpyPerCharDB.IgnoreData and SpyPerCharDB.IgnoreData[playerName] then
        if isDebug then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff7700[SpySW DEBUG]|r IGNORING CAST: " .. playerName .. " is on the Ignore list.")
        end
        return
    end
    
    -- 2. Battleground-Einstellung
    if Spy.InInstance and not Spy.db.profile.EnabledInBattlegrounds then
        return
    end
    
    -- 3. PvP-Flag-Anforderung
    if Spy.db and Spy.db.profile and Spy.db.profile.DisableWhenPVPUnflagged and not UnitIsPVP("player") then
        if isDebug then
            DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa[SpySW DEBUG]|r Detection skipped: Player not PvP flagged (Option active)")
        end
        return
    end
    
    -- 4. Gleiche Fraktion (Duell/Freundlich)
    local playerFaction = UnitFactionGroup("player")
    local casterFaction = UnitFactionGroup(casterGUID)
    
    if playerFaction and casterFaction and playerFaction == casterFaction then
        if isDebug then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff7700[SpySW DEBUG]|r IGNORING CAST: " .. playerName .. " has same faction.")
        end
        return
    end
    
    -- 5. KRITISCH: Angreifbarkeit (Range/Phasing/Schutzzone)
    if not UnitCanAttack("player", casterGUID) then
        if isDebug then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff7700[SpySW DEBUG]|r IGNORING CAST: " .. playerName .. " cast, but UnitCanAttack returned false (Check range/Protected zone).")
        end
        return
    end
    
    -- Wenn wir diesen Punkt erreichen, ist der player ein angreifbarer, feindlicher player und NICHT auf der Ignorier-Liste.
    
    -- ✅ CRITICAL FIX: Add GUID to cache/scanner
    -- This ensures the GUID is monitored by SpySW until out of range (cache persistence).
    local wasNew = self.guids[casterGUID] == nil
    self:AddUnit(casterGUID)
    if isDebug and wasNew then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff[SpySW DEBUG]|r Added GUID to tracking cache: " .. playerName)
    end
    
    -- === DATA QUERY AND ADDITION TO NEARBY LIST (GENERIC LOGIC) ===
    
    local _, class = UnitClass(casterGUID)
    local race, _ = UnitRace(casterGUID)
    local level = UnitLevel(casterGUID) or 0
    if level < 0 then level = 0 end 
    local guild = GetGuildInfo(casterGUID)
    
    -- Always update data, regardless of spell type
    local detected = Spy:UpdatePlayerData(playerName, class, level, race, guild, true, false)
    
    if not detected then
        if isDebug then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff7700[SpySW DEBUG]|r IGNORING CAST: Failed to update player data for " .. playerName .. ".")
        end
        return
    end

    -- ADD TO NEARBY LIST IF SPY IS ACTIVE (Generic cast event)
    if isEnabled then
        local wasInNearby = Spy.NearbyList[playerName] ~= nil
        Spy:AddDetected(
            playerName,
            time(),
            false,
            nil
        )
        if isDebug and not wasInNearby then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SpySW UNIT_CASTEVENT]|r ✓ Added to Nearby (Generic Cast): " .. playerName)
        end
    end
    
    -- Markiere als erkannt (um doppelte Events zu verhindern)
    SpySW.detectedPlayers[playerName] = GetTime()

    -- === SPEZIFISCHE STEALTH-ALARM-LOGIK (LEVEL 1) ===
    
    local spellName, _ = SpellInfo(spellID)
    local stealthType = self.STEALTH_SPELL_IDS[spellID]

    if stealthType then
        -- Nur Stealth-Zauber loesen den speziellen Alarm aus!
        
        -- Stealth-Only Modus (wenn Spy deaktiviert) darf nur Stealth-Klassen verarbeiten
        if stealthOnlyMode then
            local isStealthClass = (class == "ROGUE" or class == "DRUID" or race == "Night Elf" or race == "Human")
            if not isStealthClass then
                if isDebug then
                    DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa[SpySW DEBUG]|r Stealth-Only Mode: Skipped " .. playerName .. " (not NE/Human/Stealth Class)")
                end
                return
            end
        end

        -- Debug Output fuer Stealth-Zauber
        if isDebug then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff00ff[SpySW UNIT_CASTEVENT]|r " .. playerName .. " cast " .. (spellName or "Unknown") .. " - TRIGGERING Stealth Alert!")
        end
        
        -- Wichtiger Aufruf fuer den speziellen Sound/Alarm
        if Spy and Spy.AlertStealthPlayer then
            Spy:AlertStealthPlayer(playerName)
            SpySW.lastStealthState[playerName] = true
        end

        -- Nur im Stealth-Only Mode die "Nearby"-Hinzufuegung bewusst ueberspringen
        if stealthOnlyMode and isDebug then
            DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa[SpySW UNIT_CASTEVENT]|r Stealth-Only Mode: NOT added to Nearby.")
        end
    end
end

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
	
	return strformat("SuperWoW Active | Tracking %d GUIDs", guidCount)
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
	
	-- ✅ Separate counts
	local enemyCount = 0
	for _ in pairs(self.enemyGuids) do
		enemyCount = enemyCount + 1
	end
	local friendlyCount = 0
	for _ in pairs(self.friendlyGuids) do
		friendlyCount = friendlyCount + 1
	end
	DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00  Enemies:|r " .. enemyCount .. " |cff00ff00Friendlies:|r " .. friendlyCount)
	
	-- Statistics
	DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Statistics:|r")
	DEFAULT_CHAT_FRAME:AddMessage("  GUIDs Collected: " .. self.Stats.guidsCollected)
	DEFAULT_CHAT_FRAME:AddMessage("  Events Processed: " .. self.Stats.eventsProcessed)
	DEFAULT_CHAT_FRAME:AddMessage("  Scans Performed: " .. self.Stats.scansPerformed)
	DEFAULT_CHAT_FRAME:AddMessage("  Players Detected: " .. self.Stats.playersDetected)
	DEFAULT_CHAT_FRAME:AddMessage("  Pets Skipped: " .. self.Stats.petsSkipped)  -- ✅ NEW
	
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
    local hasSuperWoW = (GetPlayerBuffID ~= nil and CombatLogAdd ~= nil and SpellInfo ~= nil)
   
    if not hasSuperWoW then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000============================================|r")
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[Spy] CRITICAL ERROR: SuperWoW NOT DETECTED!|r")
        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00This addon REQUIRES SuperWoW to function.|r")
        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00Without SuperWoW, player detection will not work.|r")
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00|r")
        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00Please install SuperWoW from:|r")
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00https://github.com/balakethelock/SuperWoW|r")
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00|r")
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000Spy addon has been DISABLED.|r")
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000Please reload UI after installing SuperWoW.|r")
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000============================================|r")
       
        -- Helper function to block all Spy commands
        local function BlockAllSpyCommands()
            local function showDisabledMessage()
                DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[Spy]|r Spy is DISABLED - SuperWoW not detected!")
                DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00Please install SuperWoW and reload UI.|r")
            end
            
            -- Block main Spy commands
            SLASH_SPY1 = "/spy"
            SlashCmdList["SPY"] = showDisabledMessage
            
            SLASH_SPYGUI1 = "/spygui"
            SlashCmdList["SPYGUI"] = showDisabledMessage
            
            -- Block debug commands
            SLASH_SPYDEBUG1 = "/spydebug"
            SlashCmdList["SPYDEBUG"] = showDisabledMessage

			-- Block event commands
            SLASH_SPYEVENT1 = "/spyevent"
            SlashCmdList["SPYEVENT"] = showDisabledMessage
            
            -- Block SpySuperWoW commands
            SLASH_SPYSWSTATUS1 = "/spystatus"
            SlashCmdList["SPYSWSTATUS"] = showDisabledMessage
            
            SLASH_SPYBUFF1 = "/spybuff"
            SlashCmdList["SPYBUFF"] = showDisabledMessage
            
            SLASH_SPYPETTEST1 = "/spypet"
            SlashCmdList["SPYPETTEST"] = showDisabledMessage
            
            SLASH_SPYTARGET1 = "/spytarget"
            SlashCmdList["SPYTARGET"] = showDisabledMessage
        end
       
        -- Completely disable Spy addon
        if Spy then
            -- Set disabled flag FIRST
            Spy.DisabledDueToMissingSuperWoW = true
           
            -- Disable all functionality
            if Spy.OnDisable then
                Spy:OnDisable()
            end
           
            -- Hide and disable main window permanently
            if Spy.MainWindow then
                if Spy.MainWindow.Hide then
                    Spy.MainWindow:Hide()
                end
                if Spy.MainWindow.EnableMouse then
                    Spy.MainWindow:EnableMouse(false)
                end
                if Spy.MainWindow.SetScript then
                    Spy.MainWindow:SetScript("OnShow", function()
                        if Spy.MainWindow and Spy.MainWindow.Hide then
                            Spy.MainWindow:Hide()
                        end
                    end)
                end
            end
           
            -- Disable settings
            if Spy.db and Spy.db.profile then
                Spy.db.profile.Enabled = false
            end
           
            -- Block ALL Spy commands (single function call)
            BlockAllSpyCommands()
           
            -- Unregister all events to prevent background processing
            if Spy.OnEventFrame then
                if Spy.OnEventFrame.UnregisterAllEvents then
                    Spy.OnEventFrame:UnregisterAllEvents()
                end
                if Spy.OnEventFrame.SetScript then
                    Spy.OnEventFrame:SetScript("OnEvent", nil)
                    Spy.OnEventFrame:SetScript("OnUpdate", nil)
                end
            end
           
            -- Disable all Spy frames (safely)
            for key, frame in pairs(Spy) do
                if type(frame) == "table" then
                    if frame.UnregisterAllEvents then
                        frame:UnregisterAllEvents()
                    end
                    if frame.Hide then
                        frame:Hide()
                    end
                end
            end
        end
       
        return false
    end
   
    -- Test GUID functionality
    local _, testguid = UnitExists("player")
    if testguid then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SpySW]|r SuperWoW |cff00ff00DETECTED [OK]|r")
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SpySW]|r Your GUID: |cff00ff00" .. testguid .. "|r")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SpySW]|r SuperWoW |cff00ff00DETECTED [OK]|r")
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SpySW]|r GUID-based player detection: |cff00ff00ACTIVE|r")
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SpySW]|r Proactive scanning: |cff00ff00ACTIVE|r")
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SpySW]|r Commands: /spystatus, /spybuff, /spypet")
   
    return true
end

-- SpyModules.SuperWoW already set at top of file

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
			local texLower = strlower(tostring(texture))
			local isStealthBuff = strfind(texLower, "stealth") or strfind(texLower, "prowl") or strfind(texLower, "shadowmeld")
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
				local texLower = strlower(tostring(texture))
				local isStealthBuff = strfind(texLower, "stealth") or strfind(texLower, "prowl") or strfind(texLower, "shadowmeld")
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
			local nameLower = name and strlower(tostring(name)) or ""
			local texLower = strlower(tostring(texture))
			local isStealthBuff = strfind(nameLower, "stealth") or strfind(nameLower, "prowl") or strfind(nameLower, "shadowmeld") or strfind(texLower, "stealth") or strfind(texLower, "prowl") or strfind(texLower, "shadowmeld")
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
				local texLower = strlower(tostring(texture))
				local isStealthBuff = strfind(texLower, "stealth") or strfind(texLower, "prowl") or strfind(texLower, "shadowmeld")
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
					local texLower = strlower(tostring(texture))
					local isStealthBuff = strfind(texLower, "stealth") or strfind(texLower, "prowl") or strfind(texLower, "shadowmeld")
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
				local texLower = strlower(tostring(texture))
				local isStealthBuff = strfind(texLower, "stealth") or strfind(texLower, "prowl") or strfind(texLower, "shadowmeld")
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
			local nameLower = strlower(tostring(buffName))
			local isStealthBuff = strfind(nameLower, "prowl") or 
			                      strfind(nameLower, "stealth") or 
			                      strfind(nameLower, "shadowmeld") or
			                      strfind(nameLower, "schleichen") or
			                      strfind(nameLower, "anschleichen")
			
			local marker = isStealthBuff and " |cffff0000<-- STEALTH!|r" or ""
			DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SpySW]|r   " .. i .. ": " .. tostring(buffName) .. marker)
			
			if isStealthBuff then
				tinsert(stealthBuffs8a, buffName)
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
				local nameLower = strlower(tostring(buffName))
				local isStealthBuff = strfind(nameLower, "prowl") or 
				                      strfind(nameLower, "stealth") or 
				                      strfind(nameLower, "shadowmeld") or
				                      strfind(nameLower, "schleichen") or
				                      strfind(nameLower, "anschleichen")
				
				local marker = isStealthBuff and " |cffff0000<-- STEALTH!|r" or ""
				DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SpySW]|r   " .. i .. ": " .. tostring(buffName) .. marker)
				
				if isStealthBuff then
					tinsert(stealthBuffs8b, buffName)
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
				local nameLower = strlower(tostring(buffName))
				local isStealthBuff = strfind(nameLower, "prowl") or 
				                      strfind(nameLower, "stealth") or 
				                      strfind(nameLower, "shadowmeld") or
				                      strfind(nameLower, "schleichen") or
				                      strfind(nameLower, "anschleichen")
				
				local marker = isStealthBuff and " |cffff0000<-- STEALTH!|r" or ""
				DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SpySW]|r   " .. i .. ": " .. tostring(buffName) .. marker)
				
				if isStealthBuff then
					tinsert(stealthBuffs8c, buffName)
				end
			end
		end
	else
		DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[SpySW]|r   No mouseover unit")
	end
	DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SpySW]|r   Total: " .. count8c)
	
	-- Summary
	local allStealthBuffs = {}
	for _, buff in ipairs(stealthBuffs8a) do tinsert(allStealthBuffs, "8a:" .. buff) end
	for _, buff in ipairs(stealthBuffs8b) do tinsert(allStealthBuffs, "8b:" .. buff) end
	for _, buff in ipairs(stealthBuffs8c) do tinsert(allStealthBuffs, "8c:" .. buff) end
	
	if tgetn(allStealthBuffs) > 0 then
		DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[SpySW]|r ✓ STEALTH DETECTED: " .. tconcat(allStealthBuffs, ", "))
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

SLASH_SPYPETTEST1 = "/spypet"
SlashCmdList["SPYPETTEST"] = function()
	if not UnitExists("target") then
		DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[SpySW]|r No target!")
		return
	end
	
	local name = UnitName("target")
	local isPlayer = UnitIsPlayer("target")
	local class = UnitClass("target")
	local creature = UnitCreatureType("target")
	local _, guid = UnitExists("target")
	
	DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SpySW]|r === PET TEST ===")
	DEFAULT_CHAT_FRAME:AddMessage("Name: " .. tostring(name))
	DEFAULT_CHAT_FRAME:AddMessage("IsPlayer: " .. tostring(isPlayer))
	DEFAULT_CHAT_FRAME:AddMessage("Class: " .. tostring(class))
	DEFAULT_CHAT_FRAME:AddMessage("Creature: " .. tostring(creature))
	DEFAULT_CHAT_FRAME:AddMessage("GUID: " .. tostring(guid))
end

SLASH_SPYTARGET1 = "/spytarget"
SlashCmdList["SPYTARGET"] = function()
	if not UnitExists("target") then
		DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[SpySW]|r No target!")
		return
	end
	
	local name = UnitName("target")
	local _, guid = UnitExists("target")
	
	DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SpySW]|r === TARGET TEST ===")
	DEFAULT_CHAT_FRAME:AddMessage("Name: " .. tostring(name))
	DEFAULT_CHAT_FRAME:AddMessage("GUID: " .. tostring(guid))
	
	-- Clear target
	ClearTarget()
	DEFAULT_CHAT_FRAME:AddMessage("Target cleared...")
	
	-- Test 1: TargetByName with GUID
	DEFAULT_CHAT_FRAME:AddMessage("Test 1: TargetByName(guid)")
	TargetByName(guid)
	local test1 = UnitName("target")
	DEFAULT_CHAT_FRAME:AddMessage("  Result: " .. tostring(test1))
	ClearTarget()
	
	-- Test 2: TargetByName with name
	DEFAULT_CHAT_FRAME:AddMessage("Test 2: TargetByName(name, true)")
	TargetByName(name, true)
	local test2 = UnitName("target")
	DEFAULT_CHAT_FRAME:AddMessage("  Result: " .. tostring(test2))
	ClearTarget()
	
	-- Test 3: Direct GUID as unit (if SuperWoW supports it)
	DEFAULT_CHAT_FRAME:AddMessage("Test 3: Direct GUID targeting")
	if UnitExists(guid) then
		DEFAULT_CHAT_FRAME:AddMessage("  UnitExists(guid) = true, trying to target...")
		-- Try to make the GUID the current target
		TargetUnit(guid) -- This might be the SuperWoW function
		local test3 = UnitName("target")
		DEFAULT_CHAT_FRAME:AddMessage("  Result: " .. tostring(test3))
	else
		DEFAULT_CHAT_FRAME:AddMessage("  UnitExists(guid) = false")
	end
	
	DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SpySW]|r === TEST COMPLETE ===")
end

-- Temporary: Log ALL spell casts with IDs (toggleable)
local castLogger = CreateFrame("Frame")
local isLogging = false

local function ToggleCastLogger()
    isLogging = not isLogging
    
    if isLogging then
        castLogger:RegisterEvent("UNIT_CASTEVENT")
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SpySW]|r Cast Logger ENABLED - all casts will be logged!")
    else
        castLogger:UnregisterEvent("UNIT_CASTEVENT")
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[SpySW]|r Cast Logger DISABLED")
    end
end

castLogger:SetScript("OnEvent", function()
    local casterGUID, targetGUID, eventType, spellID, castDuration = arg1, arg2, arg3, arg4, arg5
    if eventType == "CAST" or eventType == "CHANNEL" then
        local casterName = UnitName(casterGUID) or "Unknown"
        local spellName, rank = SpellInfo(spellID)
        DEFAULT_CHAT_FRAME:AddMessage("|cffff00ff[CAST LOG]|r " .. casterName .. " cast " .. tostring(spellName) .. " (" .. tostring(rank) .. ") - ID: " .. spellID)
    end
end)

-- Register slash command
SLASH_SPYEVENT1 = "/spyevent"
SlashCmdList["SPYEVENT"] = ToggleCastLogger