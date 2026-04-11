--[[
SpyNampower.lua - Nampower-based player detection for Spy

Replaces SpySuperWoW.lua entirely. Requires Nampower >= 3.0.0.
No SuperWoW dependency whatsoever.

Detection sources:
  - SPELL_START_OTHER      → enemy cast begin (incl. instant Stealth alert via spell IDs)
  - SPELL_GO_OTHER         → enemy cast completed / instant spells missed by START
  - AUTO_ATTACK_OTHER      → melee auto-attacks (Warriors, Rogues who never cast)
  - SPELL_DAMAGE_EVENT_OTHER → spell/DoT damage without a preceding GO event
  - SPELL_MISS_OTHER       → missed/dodged/resisted attacks reveal attacker GUID
  - SPELL_HEAL_BY_OTHER    → enemy healer healing someone
  - BUFF_ADDED_OTHER       → aura applied (catches stealth going UP)
  - BUFF_REMOVED_OTHER     → aura removed (catches stealth dropping)
  - DEBUFF_ADDED_OTHER     → enemy gains a debuff (in combat signal)
  - DEBUFF_REMOVED_OTHER   → debuff removed
  - DAMAGE_SHIELD_OTHER    → Thorns/Fire Shield proc reveals attacker GUID
  - ENVIRONMENTAL_DMG_OTHER → fall/lava/drowning damage reveals GUID without combat
  - UNIT_AURA_GUID         → aura change on any tracked GUID (Nampower GUID event)
  - UNIT_FLAGS_GUID        → flags change (PvP, combat)
  - UNIT_HEALTH_GUID       → health change
  - UNIT_MANA_GUID         → mana change (casters, druids, etc.)
  - UNIT_RAGE_GUID         → rage change (warriors, bear druids)
  - UNIT_ENERGY_GUID       → energy change (rogues, cat druids)
  - UNIT_COMBAT_GUID       → combat feedback
  - UNIT_NAME_UPDATE_GUID  → name resolved (e.g. player exits stealth)
  - SPELL_DISPEL_BY_OTHER  → dispeller GUID revealed when enemy dispels
  - UNIT_DIED              → real death → immediate GUID cleanup
  - UPDATE_MOUSEOVER_UNIT, PLAYER_TARGET_CHANGED, PLAYER_ENTERING_WORLD
    → opportunistic collection via GetUnitGUID(token)

Required CVars (set automatically on Initialize):
  NP_EnableSpellStartEvents = 1
  NP_EnableSpellGoEvents    = 1
  NP_EnableAutoAttackEvents = 1

GUID handling:
  - GetUnitGUID(token) is the primary source for GUIDs.
    Supported tokens: player, target, targettarget, mouseover,
    party1-4, raid1-40, pet, mark1-8, and raw "0x..." GUID strings.
  - UnitExists(guid) works because Nampower supports raw GUIDs as unit tokens.
  - Stealth detection uses GetUnitField(guid, "aura") to scan aura slots.

Required CVars set automatically on Initialize:
  NP_EnableSpellStartEvents, NP_EnableSpellGoEvents, NP_EnableAutoAttackEvents
]]

-- Register SpyModules.Nampower IMMEDIATELY as very first line of code.
-- Spy.lua polls SpyModules.Nampower in its OnEnable retry loop.
SpyModules = SpyModules or {}
SpyModules.Nampower = SpyModules.Nampower or {}
local SpyNP = SpyModules.Nampower

-- Cache frequently used globals
local strfind   = string.find
local strlower  = string.lower
local strformat = string.format
local tinsert   = table.insert

-- DebugMode cache: re-read at most every 0.25 s to avoid table lookups per frame
local debugModeCache     = false
local debugModeCacheTime = 0

local function IsDebugMode()
    local now = GetTime()
    if now - debugModeCacheTime > 0.25 then
        debugModeCacheTime = now
        debugModeCache = Spy and Spy.db and Spy.db.profile and Spy.db.profile.DebugMode
    end
    return debugModeCache
end

local function TS()
    return strformat("[%.2f] ", GetTime())
end

--[[===========================================================================
    Stealth Spell / Aura ID tables
=============================================================================]]

-- Spell IDs that represent entering stealth (used in SPELL_START_OTHER)
SpyNP.STEALTH_SPELL_IDS = {
    [1784]  = "Stealth",
    [1785]  = "Stealth",
    [1786]  = "Stealth",
    [1787]  = "Stealth",
    [5215]  = "Prowl",
    [6783]  = "Prowl",
    [9913]  = "Prowl",
    [20580] = "Shadowmeld",
    [1856]  = "Vanish",
    [11327] = "Vanish",
    [1857]  = "Vanish",
    [11329] = "Vanish",
}

-- Same IDs are the active aura IDs (used in GetUnitField "aura" scan)
SpyNP.STEALTH_AURA_IDS = SpyNP.STEALTH_SPELL_IDS

--[[===========================================================================
    State tables
=============================================================================]]

SpyNP.Stats = {
    guidsCollected  = 0,
    eventsProcessed = 0,
    playersDetected = 0,
    scansPerformed  = 0,
    lastScanTime    = 0,
    petsSkipped     = 0,
}

SpyNP.guids             = {}   -- guid  → timestamp (all tracked enemies)
SpyNP.enemyGuids        = {}   -- guid  → timestamp (enemy subset, mirrors guids)
SpyNP.nameToGuid        = {}   -- name  → guid
SpyNP.guidToName        = {}   -- guid  → name (reverse map, avoids O(n) lookup in cleanup)
SpyNP.detectedPlayers   = {}   -- name  → timestamp (reported to Spy core)
SpyNP.lastStealthState  = {}   -- name  → bool
SpyNP.auraScannedGuids  = {}   -- guid  → bool (aura scanned this range-cycle)
SpyNP.lastScanPresent   = {}   -- guid  → bool (present in last OnUpdate scan)
SpyNP.factionCache      = {}   -- guid  → faction string
SpyNP.releasedGuids     = {}   -- guid  → true (pressed Release Spirit, spell 8326)
SpyNP.deadGuids         = {}   -- name  → true (UNIT_DIED fired = real death, no distance)

--[[
    Hook tables — external code (e.g. Spy.lua) registers callbacks here
    instead of listening to Nampower events directly.

    Usage:
        SpyNP.hooks.on_spell_go[myKey] = function(spellId, casterGuid, targetGuid, numHit, numMissed) end
        SpyNP.hooks.on_auto_attack[myKey] = function(attackerGuid, targetGuid, damage, hitInfo) end
        SpyNP.hooks.on_unit_died[myKey] = function(guid) end

    Remove by setting the key to nil.
]]
SpyNP.hooks = {
    on_spell_go    = {},   -- SPELL_GO_OTHER  (spellId, casterGuid, targetGuid, numHit, numMissed)
    on_spell_start = {},   -- SPELL_START_OTHER (spellId, casterGuid, targetGuid)
    on_auto_attack = {},   -- AUTO_ATTACK_OTHER (attackerGuid, targetGuid, damage, hitInfo)
    on_spell_dmg   = {},   -- SPELL_DAMAGE_EVENT_OTHER (casterGuid, targetGuid, spellId, amount)
    on_spell_miss  = {},   -- SPELL_MISS_OTHER  (casterGuid, targetGuid, spellId, missInfo)
    on_spell_heal  = {},   -- SPELL_HEAL_BY_OTHER (casterGuid, targetGuid, spellId, amount)
    on_buff_added  = {},   -- BUFF_ADDED_OTHER  (guid, spellId, stackCount)
    on_buff_removed= {},   -- BUFF_REMOVED_OTHER (guid, spellId)
    on_debuff_added= {},   -- DEBUFF_ADDED_OTHER (guid, spellId, stackCount)
    on_debuff_removed={},  -- DEBUFF_REMOVED_OTHER (guid, spellId)
    on_dmg_shield  = {},   -- DAMAGE_SHIELD_OTHER (shieldOwnerGuid, attackerGuid, damage)
    on_energize    = {},   -- SPELL_ENERGIZE_BY_OTHER (casterGuid, targetGuid, spellId, powerType, amount)
    on_aura_cast   = {},   -- AURA_CAST_ON_OTHER (spellId, casterGuid, targetGuid)
    on_dispel      = {},   -- SPELL_DISPEL_BY_OTHER (casterGuid, targetGuid, spellId)
    on_unit_died   = {},   -- UNIT_DIED  (guid)
    on_guid_seen   = {},   -- fires whenever any GUID event reveals an enemy player (guid)
}

local function FireHooks(hookTable, a, b, c, d, e)
    for _, fn in pairs(hookTable) do
        fn(a, b, c, d, e)
    end
end

SpyNP.SCAN_INTERVAL    = 1.0
SpyNP.CLEANUP_INTERVAL = 5
SpyNP.isShuttingDown   = false

--[[===========================================================================
    GetUnitGUID wrapper
    Returns the GUID string for any supported unit token, or nil.
=============================================================================]]

local function GUIDOf(token)
    if not token or not GetUnitGUID then return nil end
    return GetUnitGUID(token)
end

--[[===========================================================================
    Stealth detection via GetUnitField(guid, "aura")
    Returns: isStealthed (bool), stealthType (string or nil)
=============================================================================]]

local function HasStealthAura(guid)
    if not GetUnitField then return false, nil end
    local auras = GetUnitField(guid, "aura")
    if not auras then return false, nil end
    for i = 1, 48 do
        local spellId = auras[i]
        if spellId and spellId ~= 0 then
            local st = SpyNP.STEALTH_AURA_IDS[spellId]
            if st then return true, st end
        end
    end
    return false, nil
end

--[[===========================================================================
    Filter helpers
=============================================================================]]

-- GuidExists: checks if a GUID is known to the client.
-- Uses GetUnitGUID(guid) instead of UnitExists(guid) because UnitExists returns
-- false for Feign Death hunters (client hides them), while GetUnitGUID still
-- resolves the GUID as long as the unit is in the client's object list.
local function GuidExists(guid)
    if not guid then return false end
    if GetUnitGUID then return GetUnitGUID(guid) ~= nil end
    return UnitExists(guid)  -- fallback if Nampower somehow unavailable
end

local function IsGhost(guid)
    return UnitIsGhost and UnitIsGhost(guid)
end

local function PassesSpyFilters(guid)
    if not GuidExists(guid)   then return false end
    if not UnitIsPlayer(guid) then return false end
    -- Ghosts are truly gone (spirit form after death), FD hunters are NOT ghosts
    if IsGhost(guid)          then return false end
    if not UnitIsPVP(guid)    then return false end
    local pf = UnitFactionGroup("player")
    local tf = UnitFactionGroup(guid)
    if pf and tf then return pf ~= tf end
    return UnitIsEnemy("player", guid)
end

--[[===========================================================================
    GUID Collection
    Accepts a raw GUID string (from events or GetUnitGUID).
=============================================================================]]

function SpyNP:AddGUID(guid)
    if not guid then return end
    if not GuidExists(guid) then return end

    -- Early return: already a known enemy - just refresh timestamp, skip all checks
    if self.guids[guid] then
        local now = GetTime()
        self.guids[guid]      = now
        self.enemyGuids[guid] = now
        return
    end

    local isPlayer     = UnitIsPlayer(guid)
    local isControlled = UnitPlayerControlled(guid)
    local isPet        = not isPlayer and isControlled

    if isPet then
        self.Stats.petsSkipped = self.Stats.petsSkipped + 1
        return
    end
    if not isPlayer then return end

    -- Real players always have a class
    local class = UnitClass(guid)
    if not class then
        self.Stats.petsSkipped = self.Stats.petsSkipped + 1
        return
    end

    -- Enemies only
    local pf = UnitFactionGroup("player")
    local tf = UnitFactionGroup(guid)
    local isEnemy
    if pf and tf then
        isEnemy = (pf ~= tf)
    else
        isEnemy = UnitIsEnemy("player", guid)
    end
    if not isEnemy then return end

    -- Must be PvP flagged
    if not UnitIsPVP(guid) then return end

    -- ✅ FIX: Skip dead players via GetUnitField (no frame delay, no FD false-positive)
    -- UNIT_DIED already removed them from cache; this prevents re-entry from
    -- trailing events (UNIT_HEALTH_GUID, UNIT_AURA_GUID) that fire after death.
    if GetUnitField then
        local hp = GetUnitField(guid, "health")
        if hp ~= nil and hp == 0 then return end
    end

    local now = GetTime()
    self.guids[guid]      = now
    self.enemyGuids[guid] = now
    if tf then self.factionCache[guid] = tf end

    local name = UnitName(guid)
    if name then
        self.nameToGuid[name] = guid
        self.guidToName[guid] = name  -- maintain reverse map
        -- ✅ FIX: Clear dead flag when player is alive again (respawned)
        if self.deadGuids[name] then
            self.deadGuids[name]       = nil
            self.detectedPlayers[name] = nil  -- force re-detection → ActiveList
            if Spy.InactiveList[name] then
                Spy.InactiveList[name] = nil
            end
        end
    end

    self.Stats.guidsCollected = self.Stats.guidsCollected + 1
    if IsDebugMode() then
        DEFAULT_CHAT_FRAME:AddMessage(
            TS() .. "|cffff00ff[SpyNP]|r GUID collected: "
            .. (name or "?") .. " (" .. class .. ")"
        )
    end
end

-- Convenience: collect from a named unit token
function SpyNP:AddUnit(token)
    local guid = GUIDOf(token)
    if guid then self:AddGUID(guid) end
end

--[[===========================================================================
    Name ↔ GUID helpers  (called by Spy.lua)
=============================================================================]]

function SpyNP:GetNameFromGUID(guid)
    if not guid then return nil end
    if self.guids[guid] and GuidExists(guid) then
        return UnitName(guid)
    end
    return nil
end

function SpyNP:GetGUIDFromName(playerName)
    if not playerName then return nil end
    local g = self.nameToGuid[playerName]
    if g then return g end
    for guid in pairs(self.guids) do
        if GuidExists(guid) then
            local n = UnitName(guid)
            if n == playerName then
                self.nameToGuid[playerName] = guid
                self.guidToName[guid]       = playerName
                return guid
            end
        end
    end
    return nil
end

function SpyNP:GetFactionByGUID(guid)
    if not guid then return nil end
    if self.factionCache[guid] then return self.factionCache[guid] end
    if GuidExists(guid) then
        local f = UnitFactionGroup(guid)
        if f then self.factionCache[guid] = f; return f end
    end
    return nil
end

function SpyNP:GetFactionByName(playerName)
    if not playerName then return nil end
    return self:GetFactionByGUID(self:GetGUIDFromName(playerName))
end

function SpyNP:IsSameFaction(name1, name2)
    local f1, f2 = self:GetFactionByName(name1), self:GetFactionByName(name2)
    if not f1 or not f2 then return nil end
    return f1 == f2
end

--[[===========================================================================
    Player data extraction
=============================================================================]]

local function GetPlayerData(guid)
    if not GuidExists(guid)              then return nil end
    if not UnitIsPlayer(guid)            then return nil end
    if UnitIsGhost and UnitIsGhost(guid) then return nil end  -- spirit = truly gone
    if not UnitCanAttack("player", guid) then return nil end

    local name = UnitName(guid)
    if not name or name == "Unknown" then return nil end

    local class, classToken = UnitClass(guid)
    if not classToken and class then classToken = strupper(class) end
    if not classToken then return nil end

    local race, raceToken = UnitRace(guid)
    local level = UnitLevel(guid) or 0
    local guild = GetGuildInfo(guid)

    -- Use GetUnitField for health: hp=0 means dead OR feign death
    -- We do NOT use UnitIsDead() because FD sets it true while the hunter is alive.
    -- UNIT_DIED (Nampower, server-side) is the only authoritative real-death signal.
    local isDead = false
    if GetUnitField then
        local hp = GetUnitField(guid, "health")
        isDead = (hp ~= nil and hp == 0)
    end

    -- Stealth: scan aura slots (only for stealth-capable classes/races)
    local isStealthed, stealthType = false, nil
    local canStealth = (classToken == "ROGUE" or classToken == "DRUID"
                        or raceToken == "NightElf")

    if canStealth and not SpyNP.auraScannedGuids[guid] then
        isStealthed, stealthType = HasStealthAura(guid)
        SpyNP.auraScannedGuids[guid] = true
    end

    return {
        name        = name,
        level       = level,
        class       = class,
        classToken  = classToken,
        race        = race,
        raceToken   = raceToken,
        guild       = guild,
        isStealthed = isStealthed,
        stealthType = stealthType,
        isDead      = isDead,
        isPlayer    = true,
        time        = time(),
        guid        = guid,
    }
end

--[[===========================================================================
    Scan loop  (called from OnUpdate every SCAN_INTERVAL seconds)
=============================================================================]]

-- Nameplate GUID collection via Nampower's CSimpleFrame:GetName(1)
-- Iterates all WorldFrame children to find nameplate frames and extract GUIDs.
-- This catches enemies who are simply standing still without casting/buffing.
local function ScanNameplates()
    local children = { WorldFrame:GetChildren() }
    for _, frame in ipairs(children) do
        -- GetName(1) is a Nampower extension: returns GUID of the nameplate's unit
        local guid = frame:GetName(1)
        if guid and type(guid) == "string" and string.sub(guid, 1, 2) == "0x" then
            SpyNP:AddGUID(guid)
        end
    end
end

function SpyNP:ScanNearbyPlayers(currentTime)
    -- First: harvest GUIDs from all visible nameplates (catches still-standing enemies)
    ScanNameplates()

    local found = {}
    self.Stats.scansPerformed = self.Stats.scansPerformed + 1
    self.Stats.lastScanTime   = currentTime

    local prevPresent = {}
    for guid in pairs(self.lastScanPresent) do prevPresent[guid] = true end
    self.lastScanPresent = {}

    for guid in pairs(self.enemyGuids) do
        if GuidExists(guid) then
            self.enemyGuids[guid]      = currentTime
            self.guids[guid]           = currentTime
            self.lastScanPresent[guid] = true

            if IsDebugMode() and not prevPresent[guid] then
                local n = UnitName(guid)
                if n then
                    DEFAULT_CHAT_FRAME:AddMessage(
                        TS() .. "|cff00ffff[SpyNP SCAN]|r ✓ " .. n .. " returned to range"
                    )
                end
            end

            -- Filter: must be a PvP-flagged player, but do NOT check UnitIsDead!
            -- Feign Death sets UnitIsDead=true while the hunter is still alive.
            -- Real death is handled exclusively by UNIT_DIED (Nampower server event).
            -- Ghosts are the only exception: they truly left the fight.
            if UnitIsPlayer(guid)
               and UnitIsPVP(guid)
               and not (UnitIsGhost and UnitIsGhost(guid))
            then
                local data = GetPlayerData(guid)
                if data then tinsert(found, data) end
            end
        end
    end

    -- Clear aura scan cache for players who left range
    for guid in pairs(prevPresent) do
        if not self.lastScanPresent[guid] then
            self.auraScannedGuids[guid] = nil
            if IsDebugMode() then
                local n = UnitName(guid)
                if n then
                    DEFAULT_CHAT_FRAME:AddMessage(
                        TS() .. "|cffaaaaaa[SpyNP SCAN]|r ✗ " .. n .. " left range"
                    )
                end
            end
        end
    end

    return found
end

--[[===========================================================================
    GUID cleanup
=============================================================================]]

function SpyNP:CleanupOldGUIDs(currentTime)
    local removed = 0
    local timeout = Spy.InactiveTimeout or 60

    for guid, lastSeen in pairs(self.guids) do
        if not GuidExists(guid) then
            local age = currentTime - lastSeen
            local isEnemy = self.enemyGuids[guid]
            local shouldRemove = false

            if isEnemy then
                if timeout > 0 and age > timeout then shouldRemove = true end
            else
                -- Friendly / unknown → clean up immediately
                shouldRemove = true
            end

            if shouldRemove then
                -- O(1) reverse lookup via guidToName map
                local playerName = self.guidToName[guid]

                -- ✅ FIX: For enemy players still shown in NearbyList, keep
                -- detectedPlayers and nameToGuid alive so the scan loop does
                -- NOT treat them as a brand-new detection when they return to
                -- range.  Only wipe these when the player has actually left
                -- the Nearby list (i.e. InactiveTimeout expired).
                -- For friendly / non-enemy players we can clean up everything
                -- immediately since they are never in NearbyList.
                local stillInNearby = playerName
                    and isEnemy
                    and Spy.NearbyList[playerName]

                if playerName then
                    if not stillInNearby then
                        -- Player is gone from Nearby → full cleanup
                        self.detectedPlayers[playerName]  = nil
                        self.nameToGuid[playerName]       = nil
                    end
                    -- Stealth state can always be cleared; it will be
                    -- re-evaluated on the next scan if the unit returns.
                    self.lastStealthState[playerName] = nil
                end

                self.guids[guid]            = nil
                self.enemyGuids[guid]       = nil
                self.auraScannedGuids[guid] = nil
                self.lastScanPresent[guid]  = nil
                self.factionCache[guid]     = nil
                self.guidToName[guid]       = nil
                removed = removed + 1

                if IsDebugMode() then
                    DEFAULT_CHAT_FRAME:AddMessage(
                        TS() .. "|cffaaaaaa[SpyNP Cleanup]|r Removed "
                        .. (playerName or guid)
                        .. (stillInNearby and " (GUID only, kept detectedPlayers)" or "")
                        .. " after " .. math.floor(age) .. "s"
                    )
                end
            end
        end
    end

    -- Orphaned enemyGuid entries
    for guid in pairs(self.enemyGuids) do
        if not self.guids[guid] then self.enemyGuids[guid] = nil end
    end

    if removed > 0 and IsDebugMode() then
        DEFAULT_CHAT_FRAME:AddMessage(
            TS() .. "|cffaaaaaa[SpyNP Cleanup]|r Total removed: " .. removed
        )
    end
end

--[[===========================================================================
    Mode helpers
=============================================================================]]

local function IsStealthOnlyMode()
    return Spy and Spy.db and Spy.db.profile
        and Spy.db.profile.WarnOnStealthEvenIfDisabled
        and not Spy.db.profile.Enabled
end

local function IsFullyEnabled()
    return Spy and Spy.db and Spy.db.profile
        and Spy.db.profile.Enabled
        and Spy.EnabledInZone
end

--[[===========================================================================
    Stealth alert logic (shared between scan loop and SPELL_START_OTHER)
=============================================================================]]

local function TriggerStealthAlert(playerName, stealthType)
    -- BG check
    if Spy.InInstance and Spy.db and Spy.db.profile
       and not Spy.db.profile.EnabledInBattlegrounds
    then
        return
    end
    -- PvP unflagged check
    if Spy.db and Spy.db.profile
       and Spy.db.profile.DisableWhenPVPUnflagged
       and not UnitIsPVP("player")
    then
        return
    end

    if Spy and Spy.AlertStealthPlayer then
        if IsDebugMode() then
            DEFAULT_CHAT_FRAME:AddMessage(
                TS() .. "|cffff0000[SpyNP]|r ✔ STEALTH ALERT: "
                .. playerName
                .. " (" .. (stealthType or "?") .. ")"
            )
        end
        Spy:AlertStealthPlayer(playerName)
    end
end

--[[===========================================================================
    ReportPlayerToSpy
    Central function: send a detected player to Spy core with dedup + stealth.
=============================================================================]]

local function ReportPlayerToSpy(playerData, currentTime)
    local playerName = playerData.name
    local guid       = playerData.guid
    local level      = playerData.level
    if level < 0 then level = 0 end

    local stealthOnly = IsStealthOnlyMode()
    local fullEnabled = IsFullyEnabled()

    -- Ignore list
    if SpyPerCharDB and SpyPerCharDB.IgnoreData
       and SpyPerCharDB.IgnoreData[playerName]
    then
        SpyNP.detectedPlayers[playerName] = currentTime
        return
    end

    -- Faction / PvP filter
    if not PassesSpyFilters(guid) then
        SpyNP.detectedPlayers[playerName] = currentTime
        return
    end

    local isNowStealthed = playerData.isStealthed
    local isNowDead      = playerData.isDead
    local wasDetected    = SpyNP.detectedPlayers[playerName]
    local wasStealthed   = SpyNP.lastStealthState[playerName]

    -- ✅ FIX: If GUID cleanup wiped detectedPlayers but the player is still
    -- shown in the Nearby list (active or inactive), treat them as already
    -- detected so we never fire a duplicate "Player detected" alert.
    if not wasDetected and Spy.NearbyList[playerName] then
        wasDetected = true
        -- Restore detectedPlayers entry so future scans take the fast path
        SpyNP.detectedPlayers[playerName] = currentTime
    end

    -- ── Stealth-Only mode ──────────────────────────────────────────────────
    if stealthOnly then
        if isNowStealthed and not wasStealthed then
            local ct = playerData.classToken
            local rt = playerData.raceToken
            if ct == "ROGUE" or ct == "DRUID"
               or rt == "NightElf" or rt == "Human"
            then
                TriggerStealthAlert(playerName, playerData.stealthType)
                SpyNP.lastStealthState[playerName] = true
            end
        elseif wasStealthed and not isNowStealthed then
            SpyNP.lastStealthState[playerName] = nil
        end
        return
    end

    -- ── Normal mode ────────────────────────────────────────────────────────
    if not wasDetected then
        -- First detection
        if IsDebugMode() then
            DEFAULT_CHAT_FRAME:AddMessage(
                TS() .. "|cff00ff00[SpyNP]|r NEW: " .. playerName
                .. " Lvl" .. level
                .. " " .. (playerData.class or "?")
                .. (isNowDead and " [hp=0]" or "")
                .. (isNowStealthed
                    and (" [" .. (playerData.stealthType or "STEALTH") .. "]")
                    or "")
            )
        end

        local detected = Spy:UpdatePlayerData(
            playerName, playerData.classToken, level,
            playerData.race, playerData.guild,
            true, false
        )

        SpyNP.detectedPlayers[playerName] = currentTime

        if detected and fullEnabled then
            SpyNP.Stats.playersDetected = SpyNP.Stats.playersDetected + 1
            Spy:AddDetected(playerName, playerData.time, false, nil)

            if IsDebugMode() then
                DEFAULT_CHAT_FRAME:AddMessage(
                    "|cff00ff00[SpyNP SCAN]|r ✓ Added: " .. playerName
                    .. (isNowDead and " → InactiveList (hp=0)" or " → ActiveList")
                )
            end

            -- hp=0 on first sight: put straight into InactiveList (grayed out)
            if isNowDead then
                Spy.InactiveList[playerName] = time()
                Spy.ActiveList[playerName]   = nil
            end

            if isNowStealthed and not wasStealthed then
                TriggerStealthAlert(playerName, playerData.stealthType)
            end
        end

        SpyNP.lastStealthState[playerName] = isNowStealthed

    else
        -- Already detected: just refresh timestamp + data.
        -- Active/Inactive switching is handled by the HP-OnUpdate (0.1s) in MainWindow.lua
        -- which has direct access to GetUnitField and reacts immediately.
        SpyNP.detectedPlayers[playerName] = currentTime

        if isNowStealthed and not wasStealthed then
            if not (SpyPerCharDB and SpyPerCharDB.IgnoreData
                    and SpyPerCharDB.IgnoreData[playerName])
            then
                TriggerStealthAlert(playerName, playerData.stealthType)
            end
        elseif wasStealthed and not isNowStealthed then
            if IsDebugMode() then
                DEFAULT_CHAT_FRAME:AddMessage(
                    TS() .. "|cffaaaaaa[SpyNP]|r " .. playerName .. " left stealth"
                )
            end
        end

        SpyNP.lastStealthState[playerName] = isNowStealthed

        if not (SpyPerCharDB and SpyPerCharDB.IgnoreData
                and SpyPerCharDB.IgnoreData[playerName])
        then
            Spy:UpdatePlayerData(
                playerName, playerData.classToken, level,
                playerData.race, playerData.guild,
                true, false
            )
            if fullEnabled then
                Spy:AddDetected(playerName, playerData.time, false, nil)
            end
        end
    end
end

--[[===========================================================================
    Scan / cleanup OnUpdate frame
=============================================================================]]

local scanFrame    = CreateFrame("Frame")
local scanTimer    = 0
local cleanupTimer = 0

scanFrame:RegisterEvent("PLAYER_LOGOUT")
scanFrame:SetScript("OnEvent", function()
    if event == "PLAYER_LOGOUT" then
        SpyNP.isShuttingDown = true
        this:UnregisterAllEvents()
        this:SetScript("OnUpdate", nil)
        this:SetScript("OnEvent", nil)
    end
end)

scanFrame:SetScript("OnUpdate", function()
    if SpyNP.isShuttingDown then return end

    local fullEnabled = IsFullyEnabled()
    local stealthOnly = IsStealthOnlyMode()
    if not fullEnabled and not stealthOnly then return end

    local currentTime = GetTime()
    scanTimer    = scanTimer    + arg1
    cleanupTimer = cleanupTimer + arg1

    if scanTimer >= SpyNP.SCAN_INTERVAL then
        scanTimer = 0
        local players = SpyNP:ScanNearbyPlayers(currentTime)
        for _, data in ipairs(players) do
            ReportPlayerToSpy(data, currentTime)
        end
    end

    if cleanupTimer >= SpyNP.CLEANUP_INTERVAL then
        cleanupTimer = 0
        SpyNP:CleanupOldGUIDs(currentTime)
    end
end)

--[[===========================================================================
    GUID collection frame
    Collects GUIDs from standard WoW events + Nampower *_GUID events.

    Nampower GUID events (UNIT_AURA_GUID, UNIT_FLAGS_GUID, etc.) fire once
    per unit per state change.  arg1 = guid string, arg2 = isPlayer (1/0),
    arg3 = isTarget, arg4 = isMouseover, arg5 = isPet,
    arg6 = partyIndex, arg7 = raidIndex.
=============================================================================]]

local guidFrame = CreateFrame("Frame")

guidFrame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
guidFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
guidFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
guidFrame:RegisterEvent("PLAYER_LOGOUT")

-- Nampower GUID events (fire once per unit, not per registered token)
guidFrame:RegisterEvent("UNIT_AURA_GUID")
guidFrame:RegisterEvent("UNIT_FLAGS_GUID")
guidFrame:RegisterEvent("UNIT_HEALTH_GUID")
guidFrame:RegisterEvent("UNIT_MANA_GUID")
guidFrame:RegisterEvent("UNIT_RAGE_GUID")
guidFrame:RegisterEvent("UNIT_ENERGY_GUID")
guidFrame:RegisterEvent("UNIT_COMBAT_GUID")
guidFrame:RegisterEvent("UNIT_NAME_UPDATE_GUID")

guidFrame:SetScript("OnEvent", function()
    if event == "PLAYER_LOGOUT" then
        SpyNP.isShuttingDown = true
        this:UnregisterAllEvents()
        this:SetScript("OnEvent", nil)
        for k in pairs(SpyNP.guids)           do SpyNP.guids[k]           = nil end
        for k in pairs(SpyNP.releasedGuids)   do SpyNP.releasedGuids[k]   = nil end
        for k in pairs(SpyNP.deadGuids)         do SpyNP.deadGuids[k]         = nil end
        for k in pairs(SpyNP.enemyGuids)      do SpyNP.enemyGuids[k]      = nil end
        for k in pairs(SpyNP.nameToGuid)      do SpyNP.nameToGuid[k]      = nil end
        for k in pairs(SpyNP.guidToName)      do SpyNP.guidToName[k]      = nil end
        for k in pairs(SpyNP.detectedPlayers) do SpyNP.detectedPlayers[k] = nil end
        for k in pairs(SpyNP.factionCache)    do SpyNP.factionCache[k]    = nil end
        return
    end

    if SpyNP.isShuttingDown then return end

    local fullEnabled = IsFullyEnabled()
    local stealthOnly = IsStealthOnlyMode()
    if not fullEnabled and not stealthOnly then return end

    SpyNP.Stats.eventsProcessed = SpyNP.Stats.eventsProcessed + 1

    if event == "UPDATE_MOUSEOVER_UNIT" then
        -- Use GetUnitGUID("mouseover") – Nampower supports this token
        local guid = GUIDOf("mouseover")
        if guid and UnitIsPlayer("mouseover") then
            SpyNP:AddGUID(guid)
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        SpyNP:AddUnit("target")

    elseif event == "PLAYER_TARGET_CHANGED" then
        local guid = GUIDOf("target")
        if guid and UnitIsPlayer("target") then
            SpyNP:AddGUID(guid)
        end
        local guid2 = GUIDOf("targettarget")
        if guid2 and UnitIsPlayer("targettarget") then
            SpyNP:AddGUID(guid2)
        end

    elseif event == "UNIT_AURA_GUID"
        or event == "UNIT_FLAGS_GUID"
        or event == "UNIT_HEALTH_GUID"
        or event == "UNIT_MANA_GUID"
        or event == "UNIT_RAGE_GUID"
        or event == "UNIT_ENERGY_GUID"
        or event == "UNIT_COMBAT_GUID"
        or event == "UNIT_NAME_UPDATE_GUID"
    then
        -- arg1 = guid, arg2 = isPlayer (1 = yes)
        local guid     = arg1
        local isPlayer = (arg2 == 1)
        if guid and isPlayer then
            -- Invalidate aura scan cache on UNIT_AURA_GUID so we re-check stealth
            if event == "UNIT_AURA_GUID" then
                SpyNP.auraScannedGuids[guid] = nil
            end
            SpyNP:AddGUID(guid)
            FireHooks(SpyNP.hooks.on_guid_seen, guid)
        end
    end
end)

--[[===========================================================================
    SPELL_START_OTHER / SPELL_GO_OTHER frame
    Instant detection + stealth alerting when an enemy casts a spell.

    SPELL_START_OTHER fires on cast begin (has castTime, covers channeling).
    SPELL_GO_OTHER    fires on cast complete / instant spells (no START fires
                      for instants, so GO is the only signal for those).

    Both share the same handler logic — casterGuid is arg3 in both.

    Nampower SPELL_START_OTHER parameters:
      arg1 = itemId       arg2 = spellId     arg3 = casterGuid
      arg4 = targetGuid   arg5 = castFlags   arg6 = castTime
      arg7 = duration     arg8 = spellType   arg9 = corpseOwnerGuid

    Nampower SPELL_GO_OTHER parameters:
      arg1 = itemId       arg2 = spellId     arg3 = casterGuid
      arg4 = targetGuid   arg5 = castFlags   arg6 = numHit
      arg7 = numMissed    arg8 = corpseOwnerGuid
=============================================================================]]

local spellGoFrame = CreateFrame("Frame")
spellGoFrame:RegisterEvent("PLAYER_LOGOUT")
spellGoFrame:RegisterEvent("SPELL_START_OTHER")
spellGoFrame:RegisterEvent("SPELL_GO_OTHER")

spellGoFrame:SetScript("OnEvent", function()
    if event == "PLAYER_LOGOUT" then
        SpyNP.isShuttingDown = true
        this:UnregisterAllEvents()
        this:SetScript("OnEvent", nil)
        return
    end

    if SpyNP.isShuttingDown  then return end
    if event ~= "SPELL_START_OTHER" and event ~= "SPELL_GO_OTHER" then return end

    local fullEnabled = IsFullyEnabled()
    local stealthOnly = IsStealthOnlyMode()
    if not fullEnabled and not stealthOnly then return end

    local spellId    = arg2
    local casterGuid = arg3


    if not casterGuid or not spellId then return end

    -- Release Spirit (spell 8326) must be checked first, before ANY other filters.
    -- Ghosts fail UnitExists, UnitIsPlayer, UnitCanAttack — so we can't filter first.
    -- We just set the flag and return; no list manipulation here.
    if spellId == 8326 then
        SpyNP.releasedGuids[casterGuid] = true
        if IsDebugMode() then
            DEFAULT_CHAT_FRAME:AddMessage(
                TS() .. "|cffaaaaaa[SpyNP]|r " .. (UnitName(casterGuid) or casterGuid)
                .. " pressed Release (8326) → stays Inactive"
            )
        end
        return
    end

    -- Must be an existing player
    if not UnitExists(casterGuid)    then return end
    if not UnitIsPlayer(casterGuid)  then return end

    -- Enemy faction only
    local pf = UnitFactionGroup("player")
    local cf = UnitFactionGroup(casterGuid)
    if pf and cf and pf == cf then return end

    local playerName = UnitName(casterGuid)
    if not playerName then return end

    -- Ignore list
    if SpyPerCharDB and SpyPerCharDB.IgnoreData
       and SpyPerCharDB.IgnoreData[playerName]
    then
        return
    end

    -- BG / PvP-flag checks
    if Spy.InInstance and Spy.db and Spy.db.profile
       and not Spy.db.profile.EnabledInBattlegrounds
    then
        return
    end
    if Spy.db and Spy.db.profile
       and Spy.db.profile.DisableWhenPVPUnflagged
       and not UnitIsPVP("player")
    then
        return
    end

    -- Must be attackable (range / protection zone)
    if not UnitCanAttack("player", casterGuid) then return end

    -- Add to GUID tracking
    SpyNP:AddGUID(casterGuid)

    -- Fire hooks so external code (Spy.lua) can react without registering events directly
    local targetGuid = arg4
    local numHit     = arg6 or 0
    local numMissed  = arg7 or 0
    if event == "SPELL_GO_OTHER" then
        FireHooks(SpyNP.hooks.on_spell_go, spellId, casterGuid, targetGuid, numHit, numMissed)
    else
        FireHooks(SpyNP.hooks.on_spell_start, spellId, casterGuid, targetGuid)
    end
    FireHooks(SpyNP.hooks.on_guid_seen, casterGuid)

    -- Build player data
    local _, classToken = UnitClass(casterGuid)
    if not classToken then
        local cls = UnitClass(casterGuid)
        if cls then classToken = strupper(cls) end
    end
    local race, raceToken = UnitRace(casterGuid)
    local level = UnitLevel(casterGuid) or 0
    if level < 0 then level = 0 end
    local guild = GetGuildInfo(casterGuid)

    -- Update Spy player database
    local detected = Spy:UpdatePlayerData(
        playerName, classToken, level, race, guild, true, false
    )

    local currentTime = GetTime()
    SpyNP.detectedPlayers[playerName] = currentTime

    if detected and fullEnabled then
        Spy:AddDetected(playerName, time(), false, nil)
        if IsDebugMode() then
            DEFAULT_CHAT_FRAME:AddMessage(
                TS() .. "|cff00ff00[SpyNP " .. event .. "]|r ✓ "
                .. playerName
                .. " (spellId=" .. spellId .. ")"
            )
        end
    end

    -- ── Stealth spell detection ─────────────────────────────────────────
    local stealthType = SpyNP.STEALTH_SPELL_IDS[spellId]
    if stealthType then
        local wasStealthed = SpyNP.lastStealthState[playerName]

        -- Stealth-only mode: verify class
        if stealthOnly then
            if classToken ~= "ROGUE" and classToken ~= "DRUID"
               and raceToken ~= "NightElf" and raceToken ~= "Human"
            then
                return
            end
        end

        if IsDebugMode() then
            DEFAULT_CHAT_FRAME:AddMessage(
                "|cffff00ff[SpyNP SPELL_START]|r "
                .. playerName .. " → " .. stealthType
            )
        end

        if not wasStealthed then
            TriggerStealthAlert(playerName, stealthType)
        end
        SpyNP.lastStealthState[playerName] = true
    end
end)

--[[===========================================================================
    combatFrame
    Catches all remaining combat signals that reveal enemy GUIDs:

    AUTO_ATTACK_OTHER       arg1=attackerGuid  arg2=targetGuid
    SPELL_DAMAGE_EVENT_OTHER arg1=targetGuid   arg2=casterGuid  arg3=spellId
    SPELL_MISS_OTHER        arg1=casterGuid    arg2=targetGuid  arg3=spellId
    SPELL_HEAL_BY_OTHER     arg1=targetGuid    arg2=casterGuid  arg3=spellId
    SPELL_ENERGIZE_BY_OTHER arg1=targetGuid    arg2=casterGuid  arg3=spellId  (Innervate, Mana Tide etc.)
    AURA_CAST_ON_OTHER      arg1=spellId       arg2=casterGuid  arg3=targetGuid (backup when BUFF_ADDED misses due to cap)
    BUFF_ADDED_OTHER        arg1=guid          (aura applied)
    BUFF_REMOVED_OTHER      arg1=guid          (aura removed – stealth dropped)
    DEBUFF_ADDED_OTHER      arg1=guid
    DEBUFF_REMOVED_OTHER    arg1=guid
    DAMAGE_SHIELD_OTHER     arg1=unitGuid      arg2=targetGuid  (Thorns etc.)

    For BUFF/DEBUFF: arg3=spellId so we can detect stealth-buff application
    even when SPELL_START_OTHER didn't fire (e.g. re-stealth out of combat).
=============================================================================]]

local combatFrame = CreateFrame("Frame")
combatFrame:RegisterEvent("PLAYER_LOGOUT")
combatFrame:RegisterEvent("AUTO_ATTACK_OTHER")
combatFrame:RegisterEvent("SPELL_DAMAGE_EVENT_OTHER")
combatFrame:RegisterEvent("SPELL_MISS_OTHER")
combatFrame:RegisterEvent("SPELL_HEAL_BY_OTHER")
combatFrame:RegisterEvent("SPELL_ENERGIZE_BY_OTHER")
combatFrame:RegisterEvent("AURA_CAST_ON_OTHER")
combatFrame:RegisterEvent("BUFF_ADDED_OTHER")
combatFrame:RegisterEvent("BUFF_REMOVED_OTHER")
combatFrame:RegisterEvent("DEBUFF_ADDED_OTHER")
combatFrame:RegisterEvent("DEBUFF_REMOVED_OTHER")
combatFrame:RegisterEvent("DAMAGE_SHIELD_OTHER")
combatFrame:RegisterEvent("SPELL_DISPEL_BY_OTHER")
combatFrame:RegisterEvent("ENVIRONMENTAL_DMG_OTHER")

combatFrame:SetScript("OnEvent", function()
    if event == "PLAYER_LOGOUT" then
        SpyNP.isShuttingDown = true
        this:UnregisterAllEvents()
        this:SetScript("OnEvent", nil)
        return
    end

    if SpyNP.isShuttingDown then return end

    local fullEnabled = IsFullyEnabled()
    local stealthOnly = IsStealthOnlyMode()
    if not fullEnabled and not stealthOnly then return end

    -- ── Resolve which GUID is the enemy we care about ───────────────────
    -- For each event, pick the GUID that belongs to the enemy player.
    local guid

    if event == "AUTO_ATTACK_OTHER" then
        -- arg1=attackerGuid, arg2=targetGuid
        -- The attacker is the one we want to track.
        guid = arg1

    elseif event == "SPELL_DAMAGE_EVENT_OTHER" then
        -- arg1=targetGuid, arg2=casterGuid
        guid = arg2

    elseif event == "SPELL_MISS_OTHER" then
        -- arg1=casterGuid, arg2=targetGuid
        guid = arg1

    elseif event == "SPELL_HEAL_BY_OTHER" then
        -- arg1=targetGuid, arg2=casterGuid
        -- Track the healer (casterGuid).
        guid = arg2

    elseif event == "SPELL_ENERGIZE_BY_OTHER" then
        -- arg1=targetGuid, arg2=casterGuid
        guid = arg2

    elseif event == "AURA_CAST_ON_OTHER" then
        -- arg1=spellId, arg2=casterGuid, arg3=targetGuid
        -- NP_EnableAuraCastEvents CVar must be 1 (set in Initialize)
        guid = arg2

    elseif event == "BUFF_ADDED_OTHER"
        or event == "BUFF_REMOVED_OTHER"
        or event == "DEBUFF_ADDED_OTHER"
        or event == "DEBUFF_REMOVED_OTHER"
    then
        -- arg1=guid, arg3=spellId
        guid = arg1

        -- Special: BUFF_ADDED_OTHER with a stealth spellId → stealth alert
        if event == "BUFF_ADDED_OTHER" then
            local spellId    = arg3
            local stealthType = spellId and SpyNP.STEALTH_SPELL_IDS[spellId]
            if stealthType and guid then
                -- Invalidate aura cache so next scan re-checks
                SpyNP.auraScannedGuids[guid] = nil
                -- Try to resolve name for immediate stealth alert
                if GuidExists(guid) and UnitIsPlayer(guid) then
                    local playerName = UnitName(guid)
                    if playerName and not SpyNP.lastStealthState[playerName] then
                        -- Faction check
                        local pf = UnitFactionGroup("player")
                        local tf = UnitFactionGroup(guid)
                        local isEnemy = (pf and tf) and (pf ~= tf)
                                     or UnitIsEnemy("player", guid)
                        if isEnemy then
                            if IsDebugMode() then
                                DEFAULT_CHAT_FRAME:AddMessage(
                                    TS() .. "|cffff00ff[SpyNP BUFF_ADDED]|r "
                                    .. playerName .. " → " .. stealthType
                                )
                            end
                            TriggerStealthAlert(playerName, stealthType)
                            SpyNP.lastStealthState[playerName] = true
                        end
                    end
                end
            end
        elseif event == "BUFF_REMOVED_OTHER" then
            -- Clear stealth state when stealth buff drops
            local spellId    = arg3
            local stealthType = spellId and SpyNP.STEALTH_SPELL_IDS[spellId]
            if stealthType and guid then
                SpyNP.auraScannedGuids[guid] = nil
                if GuidExists(guid) and UnitIsPlayer(guid) then
                    local playerName = UnitName(guid)
                    if playerName then
                        SpyNP.lastStealthState[playerName] = nil
                        if IsDebugMode() then
                            DEFAULT_CHAT_FRAME:AddMessage(
                                TS() .. "|cffaaaaaa[SpyNP BUFF_REMOVED]|r "
                                .. playerName .. " left stealth"
                            )
                        end
                    end
                end
            end
        end

    elseif event == "DAMAGE_SHIELD_OTHER" then
        -- arg1=unitGuid (shield owner), arg2=targetGuid (attacker who triggered it)
        -- The attacker (arg2) is an enemy who hit someone — track them.
        guid = arg2

    elseif event == "ENVIRONMENTAL_DMG_OTHER" then
        -- arg1=unitGuid (unit that took env damage), arg2=dmgType, arg3=damage
        -- Free GUID collection: enemy took fall/lava/drowning damage nearby.
        guid = arg1

    elseif event == "SPELL_DISPEL_BY_OTHER" then
        -- arg1=casterGuid, arg2=targetGuid, arg3=spellId
        -- Track the dispeller.
        guid = arg1
    end

    if not guid then return end

    -- ── Standard enemy-player checks ────────────────────────────────────
    if not GuidExists(guid)   then return end
    if not UnitIsPlayer(guid) then return end

    local pf = UnitFactionGroup("player")
    local tf = UnitFactionGroup(guid)
    local isEnemy = (pf and tf) and (pf ~= tf) or UnitIsEnemy("player", guid)
    if not isEnemy then return end

    SpyNP.Stats.eventsProcessed = SpyNP.Stats.eventsProcessed + 1

    -- BUFF/DEBUFF events don't require UnitCanAttack (unit may be out of combat range)
    -- but all other combat events imply the unit just acted near someone we know about.
    -- We still let AddGUID's own filters decide.
    SpyNP:AddGUID(guid)

    -- Fire the appropriate hook so Spy.lua doesn't need to register these events itself
    if event == "AUTO_ATTACK_OTHER" then
        FireHooks(SpyNP.hooks.on_auto_attack, arg1, arg2, arg3 or 0, arg4 or 0)
    elseif event == "SPELL_DAMAGE_EVENT_OTHER" then
        FireHooks(SpyNP.hooks.on_spell_dmg, arg2, arg1, arg3, arg4 or 0)
    elseif event == "SPELL_MISS_OTHER" then
        FireHooks(SpyNP.hooks.on_spell_miss, arg1, arg2, arg3, arg4)
    elseif event == "SPELL_HEAL_BY_OTHER" then
        FireHooks(SpyNP.hooks.on_spell_heal, arg2, arg1, arg3, arg4 or 0)
    elseif event == "SPELL_ENERGIZE_BY_OTHER" then
        FireHooks(SpyNP.hooks.on_energize, arg2, arg1, arg3, arg4, arg5 or 0)
    elseif event == "AURA_CAST_ON_OTHER" then
        FireHooks(SpyNP.hooks.on_aura_cast, arg1, arg2, arg3)
    elseif event == "BUFF_ADDED_OTHER" then
        FireHooks(SpyNP.hooks.on_buff_added, arg1, arg3, arg4 or 0)
    elseif event == "BUFF_REMOVED_OTHER" then
        FireHooks(SpyNP.hooks.on_buff_removed, arg1, arg3)
    elseif event == "DEBUFF_ADDED_OTHER" then
        FireHooks(SpyNP.hooks.on_debuff_added, arg1, arg3, arg4 or 0)
    elseif event == "DEBUFF_REMOVED_OTHER" then
        FireHooks(SpyNP.hooks.on_debuff_removed, arg1, arg3)
    elseif event == "DAMAGE_SHIELD_OTHER" then
        FireHooks(SpyNP.hooks.on_dmg_shield, arg1, arg2, arg3 or 0)
    elseif event == "SPELL_DISPEL_BY_OTHER" then
        FireHooks(SpyNP.hooks.on_dispel, arg1, arg2, arg3)
    end
    FireHooks(SpyNP.hooks.on_guid_seen, guid)

    if IsDebugMode() then
        local playerName = UnitName(guid) or tostring(guid)
        DEFAULT_CHAT_FRAME:AddMessage(
            TS() .. "|cff00ffff[SpyNP " .. event .. "]|r " .. playerName
        )
    end
end)

--[[===========================================================================
    UNIT_DIED frame
    Nampower fires UNIT_DIED(guid) from the server combat log death record.
    This is a real death, not Feign Death.
=============================================================================]]

local diedFrame = CreateFrame("Frame")
diedFrame:RegisterEvent("PLAYER_LOGOUT")
diedFrame:RegisterEvent("UNIT_DIED")

diedFrame:SetScript("OnEvent", function()
    if event == "PLAYER_LOGOUT" then
        this:UnregisterAllEvents()
        this:SetScript("OnEvent", nil)
        return
    end
    if event ~= "UNIT_DIED" then return end

    local guid = arg1
    if not guid then return end

    -- Clear released flag regardless of whether we tracked this GUID
    SpyNP.releasedGuids[guid] = nil
    if not SpyNP.guids[guid] then return end  -- not our concern

    -- Remove from GUID tracking so scan loop stops processing this unit.
    -- Do NOT touch NearbyList/ActiveList/InactiveList here -
    -- the normal Cleanup timer handles removal from Nearby.
    -- We only move them to Inactive so they appear grayed out.
    SpyNP.guids[guid]            = nil
    SpyNP.enemyGuids[guid]       = nil
    SpyNP.auraScannedGuids[guid] = nil
    SpyNP.lastScanPresent[guid]  = nil
    SpyNP.factionCache[guid]     = nil

    local name = SpyNP.guidToName[guid]
    if name then
        SpyNP.deadGuids[name]        = true  -- blocks reactivation + hides distance
        SpyNP.detectedPlayers[name]  = nil   -- stop scan loop from re-reporting
        SpyNP.lastStealthState[name] = nil
        SpyNP.nameToGuid[name]       = nil
        SpyNP.guidToName[guid]       = nil

        -- Move to Inactive (grayed out), let normal cleanup timer remove from Nearby.
        -- Use time() as the Inactive timestamp so InactiveTimeout counts from NOW,
        -- not from when they were last seen active (which could be old).
        if Spy.ActiveList[name] then
            Spy.InactiveList[name] = time()
            Spy.ActiveList[name]   = nil
            Spy:RefreshCurrentList()
            Spy:UpdateActiveCount()
        elseif not Spy.InactiveList[name] then
            -- Already inactive (e.g. hp=0 path got there first) - ensure timestamp is fresh
            Spy.InactiveList[name] = time()
        end
    end

    -- Fire hook AFTER internal state is cleaned up
    FireHooks(SpyNP.hooks.on_unit_died, guid)

    if IsDebugMode() then
        DEFAULT_CHAT_FRAME:AddMessage(
            TS() .. "|cffaaaaaa[SpyNP]|r UNIT_DIED -> Inactive " .. tostring(guid)
        )
    end
end)

--[[===========================================================================
    Enable / Disable  (called by Spy.lua)
=============================================================================]]

function SpyNP:Enable()
    scanFrame:Show()
    guidFrame:Show()
    spellGoFrame:Show()
    combatFrame:Show()
    diedFrame:Show()
end

function SpyNP:Disable()
    scanFrame:Hide()
    guidFrame:Hide()
    spellGoFrame:Hide()
    combatFrame:Hide()
    diedFrame:Hide()
end

function SpyNP:GetInfo()
    local n = 0
    for _ in pairs(self.guids) do n = n + 1 end
    return strformat("Nampower Active | Tracking %d GUIDs", n)
end

--[[===========================================================================
    PrintStatus  (/spystatus)
=============================================================================]]

function SpyNP:PrintStatus()
    DEFAULT_CHAT_FRAME:AddMessage(
        "|cff00ff00========== SpyNampower Status ==========|r"
    )

    if GetNampowerVersion then
        local maj, min, pat = GetNampowerVersion()
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cff00ff00Nampower:|r |cff00ff00v"
            .. maj .. "." .. min .. "." .. (pat or 0) .. " DETECTED|r"
        )
    else
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cff00ff00Nampower:|r |cffff0000NOT DETECTED|r"
        )
    end

    if GetUnitGUID then
        local g = GetUnitGUID("player")
        if g then
            DEFAULT_CHAT_FRAME:AddMessage(
                "|cff00ff00GetUnitGUID:|r |cff00ff00OK|r (" .. g .. ")"
            )
        end
    end

    local total, enemy = 0, 0
    for _ in pairs(self.guids)      do total = total + 1 end
    for _ in pairs(self.enemyGuids) do enemy = enemy + 1 end
    DEFAULT_CHAT_FRAME:AddMessage(
        "|cff00ff00Tracked GUIDs:|r " .. total .. "  (enemies: " .. enemy .. ")"
    )

    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Statistics:|r")
    DEFAULT_CHAT_FRAME:AddMessage(
        "  GUIDs Collected:  " .. self.Stats.guidsCollected
    )
    DEFAULT_CHAT_FRAME:AddMessage(
        "  Events Processed: " .. self.Stats.eventsProcessed
    )
    DEFAULT_CHAT_FRAME:AddMessage(
        "  Scans Performed:  " .. self.Stats.scansPerformed
    )
    DEFAULT_CHAT_FRAME:AddMessage(
        "  Players Detected: " .. self.Stats.playersDetected
    )
    DEFAULT_CHAT_FRAME:AddMessage(
        "  Pets Skipped:     " .. self.Stats.petsSkipped
    )

    if Spy then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Spy Status:|r")
        DEFAULT_CHAT_FRAME:AddMessage(
            "  Enabled:       " .. tostring(Spy.IsEnabled or false)
        )
        DEFAULT_CHAT_FRAME:AddMessage(
            "  EnabledInZone: " .. tostring(Spy.EnabledInZone or false)
        )
        DEFAULT_CHAT_FRAME:AddMessage(
            "  HasNampower:   " .. tostring(Spy.HasNampower or false)
        )
    end

    DEFAULT_CHAT_FRAME:AddMessage(
        "|cff00ff00========================================|r"
    )
end

--[[===========================================================================
    Initialize  (called by Spy.lua:OnEnable via SpyModules.Nampower:Initialize)
=============================================================================]]

function SpyNP:Initialize()
    DEFAULT_CHAT_FRAME:AddMessage(TS() .. "|cff00ff00[SpyNP]|r Initializing...")

    -- Require Nampower (checks for GetNampowerVersion as capability marker)
    if not GetNampowerVersion then
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cffff0000============================================|r"
        )
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cffff0000[Spy] CRITICAL ERROR: Nampower NOT DETECTED!|r"
        )
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cffffcc00This addon requires Nampower 3.0.0+.|r"
        )
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cffffcc00https://gitea.com/avitasia/nampower/releases|r"
        )
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cffff0000Spy addon has been DISABLED.|r"
        )
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cffff0000============================================|r"
        )

        if Spy then
            Spy.DisabledDueToMissingNampower = true
            if Spy.db and Spy.db.profile then
                Spy.db.profile.Enabled = false
            end
            local function showMsg()
                DEFAULT_CHAT_FRAME:AddMessage(
                    "|cffff0000[Spy]|r Disabled – Nampower 3.0.0+ required!"
                )
            end
            SLASH_SPY1 = "/spy"; SlashCmdList["SPY"] = showMsg
            SLASH_SPYSTATUS1 = "/spystatus"; SlashCmdList["SPYSTATUS"] = showMsg
            SLASH_SPYSWSTATUS1 = "/spystatus"  -- alias kept for compat
        end
        return false
    end

    -- Version check: need >= 3.0.0
    local maj, min, pat = GetNampowerVersion()
    pat = pat or 0
    local ok = (maj > 3) or (maj == 3 and min > 0)
             or (maj == 3 and min == 0 and pat >= 0)
    if not ok then
        DEFAULT_CHAT_FRAME:AddMessage(
            TS() .. "|cffff0000[SpyNP]|r Nampower v"
            .. maj .. "." .. min .. "." .. pat
            .. " is too old – need 3.0.0+"
        )
        return false
    end

    -- Enable required CVars
    if SetCVar then
        if GetCVar("NP_EnableSpellStartEvents") ~= "1" then
            SetCVar("NP_EnableSpellStartEvents", "1")
            DEFAULT_CHAT_FRAME:AddMessage(
                TS() .. "|cff00ff00[SpyNP]|r NP_EnableSpellStartEvents → 1"
            )
        end
        if GetCVar("NP_EnableSpellGoEvents") ~= "1" then
            SetCVar("NP_EnableSpellGoEvents", "1")
            DEFAULT_CHAT_FRAME:AddMessage(
                TS() .. "|cff00ff00[SpyNP]|r NP_EnableSpellGoEvents → 1"
            )
        end
        if GetCVar("NP_EnableAutoAttackEvents") ~= "1" then
            SetCVar("NP_EnableAutoAttackEvents", "1")
            DEFAULT_CHAT_FRAME:AddMessage(
                TS() .. "|cff00ff00[SpyNP]|r NP_EnableAutoAttackEvents → 1"
            )
        end
        if GetCVar("NP_EnableAuraCastEvents") ~= "1" then
            SetCVar("NP_EnableAuraCastEvents", "1")
            DEFAULT_CHAT_FRAME:AddMessage(
                TS() .. "|cff00ff00[SpyNP]|r NP_EnableAuraCastEvents → 1"
            )
        end
    end

    -- Confirm GetUnitGUID availability
    local testGuid = GetUnitGUID and GetUnitGUID("player")
    if testGuid then
        DEFAULT_CHAT_FRAME:AddMessage(
            TS() .. "|cff00ff00[SpyNP]|r Nampower v"
            .. maj .. "." .. min .. "." .. pat
            .. " |cff00ff00[OK]|r  playerGUID=" .. testGuid
        )
    else
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cffff9900[SpyNP]|r Nampower detected but GetUnitGUID unavailable"
        )
    end

    DEFAULT_CHAT_FRAME:AddMessage(
        TS() .. "|cff00ff00[SpyNP]|r GUID-based detection: |cff00ff00ACTIVE|r"
    )
    DEFAULT_CHAT_FRAME:AddMessage(
        TS() .. "|cff00ff00[SpyNP]|r Proactive scanning:   |cff00ff00ACTIVE|r"
    )
    DEFAULT_CHAT_FRAME:AddMessage(
        TS() .. "|cff00ff00[SpyNP]|r Commands: /spystatus  /spybuff  /spypet  /spyevent"
    )

    return true
end

--[[===========================================================================
    Slash Commands
=============================================================================]]

SLASH_SPYSWSTATUS1 = "/spystatus"
SlashCmdList["SPYSWSTATUS"] = function()
    if SpyModules and SpyModules.Nampower then
        SpyModules.Nampower:PrintStatus()
    else
        DEFAULT_CHAT_FRAME:AddMessage(TS() .. "|cffff0000[SpyNP]|r Module not loaded!")
    end
end

SLASH_SPYBUFF1 = "/spybuff"
SlashCmdList["SPYBUFF"] = function()
    DEFAULT_CHAT_FRAME:AddMessage(
        TS() .. "|cff00ff00[SpyNP]|r === AURA SCAN TEST (target) ==="
    )
    if not UnitExists("target") then
        DEFAULT_CHAT_FRAME:AddMessage(TS() .. "|cffff0000[SpyNP]|r No target selected!")
        return
    end
    local name = UnitName("target")
    local guid = GUIDOf("target")
    DEFAULT_CHAT_FRAME:AddMessage(
        TS() .. "|cff00ff00[SpyNP]|r Target: " .. tostring(name)
        .. "  GUID: " .. tostring(guid)
    )
    if guid and GetUnitField then
        local auras = GetUnitField(guid, "aura")
        if auras then
            local count = 0
            for i = 1, 48 do
                local sid = auras[i]
                if sid and sid ~= 0 then
                    count = count + 1
                    local st = SpyModules.Nampower.STEALTH_AURA_IDS[sid]
                    local mark = st and (" |cffff0000<-- STEALTH: " .. st .. "|r") or ""
                    DEFAULT_CHAT_FRAME:AddMessage(
                        TS() .. "|cff00ff00[SpyNP]|r  aura[" .. i .. "] = " .. sid .. mark
                    )
                end
            end
            DEFAULT_CHAT_FRAME:AddMessage(
                TS() .. "|cff00ff00[SpyNP]|r Total auras: " .. count
            )
        else
            DEFAULT_CHAT_FRAME:AddMessage(
                TS() .. "|cffffcc00[SpyNP]|r GetUnitField returned nil"
            )
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage(
            TS() .. "|cffffcc00[SpyNP]|r GetUnitField / GetUnitGUID not available"
        )
    end
    DEFAULT_CHAT_FRAME:AddMessage(TS() .. "|cff00ff00[SpyNP]|r === TEST COMPLETE ===")
end

SLASH_SPYPETTEST1 = "/spypet"
SlashCmdList["SPYPETTEST"] = function()
    if not UnitExists("target") then
        DEFAULT_CHAT_FRAME:AddMessage(TS() .. "|cffff0000[SpyNP]|r No target!")
        return
    end
    local guid = GUIDOf("target")
    DEFAULT_CHAT_FRAME:AddMessage(TS() .. "|cff00ff00[SpyNP]|r === PET TEST ===")
    DEFAULT_CHAT_FRAME:AddMessage("Name:         " .. tostring(UnitName("target")))
    DEFAULT_CHAT_FRAME:AddMessage("IsPlayer:     " .. tostring(UnitIsPlayer("target")))
    DEFAULT_CHAT_FRAME:AddMessage("IsControlled: " .. tostring(UnitPlayerControlled("target")))
    DEFAULT_CHAT_FRAME:AddMessage("Class:        " .. tostring(UnitClass("target")))
    DEFAULT_CHAT_FRAME:AddMessage("Creature:     " .. tostring(UnitCreatureType("target")))
    DEFAULT_CHAT_FRAME:AddMessage("GUID:         " .. tostring(guid))
end

--[[===========================================================================
    /spyevent  –  toggleable event logger for debugging detection coverage.
    Shows every Nampower combat event that Spy uses to detect enemy players.
    Useful to verify which events fire for a given class/situation.
=============================================================================]]

local castLogger = CreateFrame("Frame")
local isLogging  = false
castLogger:Show()  -- must be visible to receive events in vanilla WoW

-- Events the logger can subscribe to (all gated, registered only when active)
local LOG_EVENTS = {
    -- spell events
    "SPELL_START_OTHER",
    "SPELL_GO_OTHER",
    "SPELL_DAMAGE_EVENT_OTHER",
    "SPELL_MISS_OTHER",
    "SPELL_HEAL_BY_OTHER",
    "SPELL_ENERGIZE_BY_OTHER",
    -- melee
    "AUTO_ATTACK_OTHER",
    -- aura events
    "AURA_CAST_ON_OTHER",
    "BUFF_ADDED_OTHER",
    "BUFF_REMOVED_OTHER",
    "DEBUFF_ADDED_OTHER",
    "DEBUFF_REMOVED_OTHER",
    "DAMAGE_SHIELD_OTHER",
    "SPELL_DISPEL_BY_OTHER",
    "ENVIRONMENTAL_DMG_OTHER",
    -- GUID events
    "UNIT_AURA_GUID",
    "UNIT_FLAGS_GUID",
    "UNIT_HEALTH_GUID",
    "UNIT_MANA_GUID",
    "UNIT_RAGE_GUID",
    "UNIT_ENERGY_GUID",
    "UNIT_COMBAT_GUID",
    "UNIT_NAME_UPDATE_GUID",
}

castLogger:RegisterEvent("PLAYER_LOGOUT")
castLogger:SetScript("OnEvent", function()
    if event == "PLAYER_LOGOUT" then
        this:UnregisterAllEvents()
        this:SetScript("OnEvent", nil)
        return
    end

    -- ── SPELL_START_OTHER / SPELL_GO_OTHER ──────────────────────────────
    if event == "SPELL_START_OTHER" or event == "SPELL_GO_OTHER" then
        local spellId    = arg2
        local casterGuid = arg3
        local casterName = (casterGuid and UnitExists(casterGuid)
                            and UnitName(casterGuid)) or tostring(casterGuid)
        local spellName  = (GetSpellRecField
                            and GetSpellRecField(spellId, "name"))
                           or ("spell#" .. tostring(spellId))
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cffff00ff[" .. event .. "]|r "
            .. tostring(casterName)
            .. " → " .. tostring(spellName)
            .. " (id=" .. tostring(spellId) .. ")"
        )

    -- ── AUTO_ATTACK_OTHER ───────────────────────────────────────────────
    elseif event == "AUTO_ATTACK_OTHER" then
        local attackerGuid = arg1
        local targetGuid   = arg2
        local damage       = arg3 or 0
        local attackerName = (attackerGuid and UnitExists(attackerGuid)
                              and UnitName(attackerGuid)) or tostring(attackerGuid)
        local targetName   = (targetGuid and UnitExists(targetGuid)
                              and UnitName(targetGuid)) or tostring(targetGuid)
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cffff8800[AUTO_ATTACK_OTHER]|r "
            .. tostring(attackerName) .. " → " .. tostring(targetName)
            .. " (" .. damage .. " dmg)"
        )

    -- ── SPELL_DAMAGE_EVENT_OTHER ────────────────────────────────────────
    elseif event == "SPELL_DAMAGE_EVENT_OTHER" then
        local targetGuid = arg1
        local casterGuid = arg2
        local spellId    = arg3
        local amount     = arg4 or 0
        local casterName = (casterGuid and UnitExists(casterGuid)
                            and UnitName(casterGuid)) or tostring(casterGuid)
        local spellName  = (GetSpellRecField
                            and GetSpellRecField(spellId, "name"))
                           or ("spell#" .. tostring(spellId))
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cffff4444[SPELL_DMG_OTHER]|r "
            .. tostring(casterName)
            .. " → " .. tostring(spellName)
            .. " " .. amount .. " dmg"
        )

    -- ── SPELL_MISS_OTHER ────────────────────────────────────────────────
    elseif event == "SPELL_MISS_OTHER" then
        local casterGuid = arg1
        local spellId    = arg3
        local missInfo   = arg4
        local missNames  = { [1]="Miss",[2]="Resist",[3]="Dodge",[4]="Parry",
                             [5]="Block",[6]="Evade",[7]="Immune",[8]="Immune",
                             [9]="Deflect",[10]="Absorb",[11]="Reflect" }
        local casterName = (casterGuid and UnitExists(casterGuid)
                            and UnitName(casterGuid)) or tostring(casterGuid)
        local spellName  = (GetSpellRecField
                            and GetSpellRecField(spellId, "name"))
                           or ("spell#" .. tostring(spellId))
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cffaaaaff[SPELL_MISS_OTHER]|r "
            .. tostring(casterName)
            .. " → " .. tostring(spellName)
            .. " [" .. (missNames[missInfo] or tostring(missInfo)) .. "]"
        )

    -- ── SPELL_HEAL_BY_OTHER ─────────────────────────────────────────────
    elseif event == "SPELL_HEAL_BY_OTHER" then
        local targetGuid = arg1
        local casterGuid = arg2
        local spellId    = arg3
        local amount     = arg4 or 0
        local casterName = (casterGuid and UnitExists(casterGuid)
                            and UnitName(casterGuid)) or tostring(casterGuid)
        local spellName  = (GetSpellRecField
                            and GetSpellRecField(spellId, "name"))
                           or ("spell#" .. tostring(spellId))
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cff00ff88[SPELL_HEAL_OTHER]|r "
            .. tostring(casterName)
            .. " healed for " .. amount
            .. " (" .. tostring(spellName) .. ")"
        )

    -- ── BUFF_ADDED_OTHER / BUFF_REMOVED_OTHER ───────────────────────────
    elseif event == "BUFF_ADDED_OTHER" or event == "BUFF_REMOVED_OTHER" then
        local guid    = arg1
        local spellId = arg3
        local name    = (guid and UnitExists(guid)
                         and UnitName(guid)) or tostring(guid)
        local spellName = (GetSpellRecField
                           and GetSpellRecField(spellId, "name"))
                          or ("spell#" .. tostring(spellId))
        local stealthMark = SpyNP.STEALTH_SPELL_IDS[spellId]
                            and " |cffff0000<STEALTH>|r" or ""
        local col = (event == "BUFF_ADDED_OTHER") and "|cff88ff88" or "|cffaaaaaa"
        DEFAULT_CHAT_FRAME:AddMessage(
            col .. "[" .. event .. "]|r "
            .. tostring(name)
            .. " → " .. tostring(spellName) .. stealthMark
        )

    -- ── DEBUFF_ADDED_OTHER / DEBUFF_REMOVED_OTHER ───────────────────────
    elseif event == "DEBUFF_ADDED_OTHER" or event == "DEBUFF_REMOVED_OTHER" then
        local guid    = arg1
        local spellId = arg3
        local name    = (guid and UnitExists(guid)
                         and UnitName(guid)) or tostring(guid)
        local spellName = (GetSpellRecField
                           and GetSpellRecField(spellId, "name"))
                          or ("spell#" .. tostring(spellId))
        local col = (event == "DEBUFF_ADDED_OTHER") and "|cffff8844" or "|cffaaaaaa"
        DEFAULT_CHAT_FRAME:AddMessage(
            col .. "[" .. event .. "]|r "
            .. tostring(name)
            .. " → " .. tostring(spellName)
        )

    -- ── DAMAGE_SHIELD_OTHER ─────────────────────────────────────────────
    elseif event == "DAMAGE_SHIELD_OTHER" then
        local shieldOwner = arg1
        local attackerGuid = arg2
        local damage       = arg3 or 0
        local ownerName   = (shieldOwner and UnitExists(shieldOwner)
                             and UnitName(shieldOwner)) or tostring(shieldOwner)
        local atkName     = (attackerGuid and UnitExists(attackerGuid)
                             and UnitName(attackerGuid)) or tostring(attackerGuid)
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cffff44ff[DAMAGE_SHIELD_OTHER]|r "
            .. tostring(atkName) .. " hit " .. tostring(ownerName)
            .. "'s shield for " .. damage
        )

    -- ── SPELL_ENERGIZE_BY_OTHER ─────────────────────────────────────────
    elseif event == "SPELL_ENERGIZE_BY_OTHER" then
        local targetGuid = arg1
        local casterGuid = arg2
        local spellId    = arg3
        local powerType  = arg4
        local amount     = arg5 or 0
        local powerNames = { [0]="Mana",[1]="Rage",[2]="Focus",[3]="Energy",[4]="Happiness" }
        local casterName = (casterGuid and UnitExists(casterGuid)
                            and UnitName(casterGuid)) or tostring(casterGuid)
        local spellName  = (GetSpellRecField
                            and GetSpellRecField(spellId, "name"))
                           or ("spell#" .. tostring(spellId))
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cff44ffcc[SPELL_ENERGIZE_OTHER]|r "
            .. tostring(casterName)
            .. " → " .. tostring(spellName)
            .. " +" .. amount .. " " .. (powerNames[powerType] or "?")
        )

    -- ── AURA_CAST_ON_OTHER ──────────────────────────────────────────────
    elseif event == "AURA_CAST_ON_OTHER" then
        local spellId    = arg1
        local casterGuid = arg2
        local targetGuid = arg3
        local casterName = (casterGuid and UnitExists(casterGuid)
                            and UnitName(casterGuid)) or tostring(casterGuid)
        local spellName  = (GetSpellRecField
                            and GetSpellRecField(spellId, "name"))
                           or ("spell#" .. tostring(spellId))
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cffccaaff[AURA_CAST_OTHER]|r "
            .. tostring(casterName)
            .. " → " .. tostring(spellName)
        )

    -- ── ENVIRONMENTAL_DMG_OTHER ──────────────────────────────────────────
    elseif event == "ENVIRONMENTAL_DMG_OTHER" then
        local unitGuid = arg1
        local dmgType  = arg2 or 0
        local damage   = arg3 or 0
        local envNames = { [0]="Exhausted",[1]="Drowning",[2]="Fall",
                           [3]="Lava",[4]="Slime",[5]="Fire",[6]="FallToVoid" }
        local name = (unitGuid and UnitExists(unitGuid)
                      and UnitName(unitGuid)) or tostring(unitGuid)
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cffcc6600[ENVIRONMENTAL_DMG_OTHER]|r "
            .. tostring(name) .. " took " .. damage
            .. " " .. (envNames[dmgType] or "?") .. " damage"
        )

    -- ── UNIT_*_GUID events ───────────────────────────────────────────────
    elseif event == "UNIT_AURA_GUID"
        or event == "UNIT_FLAGS_GUID"
        or event == "UNIT_HEALTH_GUID"
        or event == "UNIT_MANA_GUID"
        or event == "UNIT_RAGE_GUID"
        or event == "UNIT_ENERGY_GUID"
        or event == "UNIT_COMBAT_GUID"
        or event == "UNIT_NAME_UPDATE_GUID"
    then
        local guid     = arg1
        local isPlayer = (arg2 == 1)
        if not isPlayer then return end
        local name = (guid and UnitExists(guid) and UnitName(guid)) or tostring(guid)
        local col  = "|cff888888"
        if event == "UNIT_AURA_GUID"        then col = "|cff88ff88" end
        if event == "UNIT_COMBAT_GUID"      then col = "|cffffaa44" end
        if event == "UNIT_MANA_GUID"        then col = "|cff88ccff" end
        if event == "UNIT_RAGE_GUID"        then col = "|cffff4444" end
        if event == "UNIT_ENERGY_GUID"      then col = "|cffffff44" end
        if event == "UNIT_NAME_UPDATE_GUID" then col = "|cffffcc00" end
        DEFAULT_CHAT_FRAME:AddMessage(
            col .. "[" .. event .. "]|r " .. tostring(name)
        )

    -- ── SPELL_DISPEL_BY_OTHER ────────────────────────────────────────────
    elseif event == "SPELL_DISPEL_BY_OTHER" then
        local casterGuid = arg1
        local targetGuid = arg2
        local spellId    = arg3
        local casterName = (casterGuid and UnitExists(casterGuid)
                            and UnitName(casterGuid)) or tostring(casterGuid)
        local spellName  = (GetSpellRecField
                            and GetSpellRecField(spellId, "name"))
                           or ("spell#" .. tostring(spellId))
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cffff88ff[SPELL_DISPEL_OTHER]|r "
            .. tostring(casterName)
            .. " dispelled " .. tostring(spellName)
        )
    end
end)

SLASH_SPYEVENT1 = "/spyevent"
SlashCmdList["SPYEVENT"] = function()
    isLogging = not isLogging
    if isLogging then
        for _, ev in ipairs(LOG_EVENTS) do
            castLogger:RegisterEvent(ev)
        end
        DEFAULT_CHAT_FRAME:AddMessage(
            TS() .. "|cff00ff00[SpyNP]|r Event Logger |cff00ff00ENABLED|r"
            .. " – logging " .. table.getn(LOG_EVENTS) .. " events"
        )
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cffffcc00  START/GO · AUTO_ATTACK · SPELL_DMG · SPELL_MISS"
            .. " · HEAL · ENERGIZE · AURA_CAST · BUFF/DEBUFF · DMG_SHIELD · DISPEL"
            .. " · UNIT_AURA/FLAGS/HEALTH/MANA/COMBAT/NAME_GUID|r"
        )
    else
        for _, ev in ipairs(LOG_EVENTS) do
            castLogger:UnregisterEvent(ev)
        end
        DEFAULT_CHAT_FRAME:AddMessage(
            TS() .. "|cffff0000[SpyNP]|r Event Logger |cffff0000DISABLED|r"
        )
    end
end

--[[===========================================================================
    Global aliases
    Spy.lua references SpySW.* in several places (nameToGuid, enemyGuids,
    GetNameFromGUID, etc.).  We point SpySW at SpyNP so those references
    keep working without modifying Spy.lua.
=============================================================================]]
_G.SpySW = SpyNP
_G.SpyNP = SpyNP