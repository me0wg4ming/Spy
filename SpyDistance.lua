--[[
Spy Distance Display Integration (WoW 1.12.1 / Lua 5.0 compatible)
Distance display for PlayerFrames
]]

-- Distance tracking module
Spy.Distance = {
    cache = {},
    globalDistanceCache = {},  -- ✅ NEW: Global cache for ALL players (used by sorting)
    updateInterval = 0.2,  -- ✅ Changed from 0.1 to 0.2 (5 Hz instead of 10 Hz)
    lastUpdate = 0,
    debug = false,
    enabled = false,
}

-- Save the working UnitXP method
local UnitXP_GetDistance = nil

-- Check if UnitXP works with "distanceBetween"
local function CheckUnitXP()
    if not UnitXP then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[SpyRange]|r UnitXP not found - Distance display DISABLED")
        return false
    end
    
    -- Test: UnitXP("distanceBetween", "player", "player")
    local success, result = pcall(function()
        return UnitXP("distanceBetween", "player", "player")
    end)
    
    if success and type(result) == "number" then
        -- It works! Save the method
        UnitXP_GetDistance = function(unit1, unit2)
            return UnitXP("distanceBetween", unit1, unit2)
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SpyRange]|r UnitXP detected - Distance display ENABLED")
        return true
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[SpyRange]|r UnitXP not found - Distance display DISABLED")
        if Spy.Distance.debug then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[Distance DEBUG]|r Error: " .. tostring(result))
        end
        return false
    end
end

-- ✅ FIX: Delay initialization until PLAYER_ENTERING_WORLD
Spy.Distance.initialized = false

function Spy.Distance:Initialize()
    if self.initialized then
        return self.enabled
    end
    
    self.initialized = true
    self.enabled = CheckUnitXP()
    
    if not self.enabled then
        function Spy.Distance:GetDistance(playerName) return nil end
        function Spy.Distance:GetCachedDistance(playerName) return nil end
        function Spy.Distance:FormatDistance(distance) return "|cff888888--|r" end
        function Spy.Distance:CleanCache() end
        return false
    end
    
    return true
end

-- Temporary dummy functions until Initialize()
function Spy.Distance:GetDistance(playerName) 
    if not self.initialized then self:Initialize() end
    return nil 
end
function Spy.Distance:GetCachedDistance(playerName) return nil end
function Spy.Distance:FormatDistance(distance) return "|cff888888--|r" end
function Spy.Distance:CleanCache() end

-- ======================================================================
-- FROM HERE ONLY CODE IF UNITXP IS AVAILABLE
-- ======================================================================

-- Get distance for a player by name
function Spy.Distance:GetDistance(playerName)
    if not playerName then 
        if Spy.Distance.debug then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[Distance DEBUG]|r playerName is nil")
        end
        return nil 
    end
    
    -- Try to get GUID from SpySW
    local guid = nil
    if SpySW and SpySW.GetGUIDFromName then
        guid = SpySW:GetGUIDFromName(playerName)
    end
    
    if not guid then
        return nil
    end
    
    -- Check if unit exists
    if not UnitExists(guid) then
        -- ✅ OPTIMIZATION: Skip expensive fallback iteration
        -- If GUID doesn't exist, player is likely out of range
        -- The fallback search is O(n²) and causes major lag with many players
        -- Instead, return nil immediately and let cache handle stale data
        return nil
    end
    
    -- Get distance using the stored working method
    local success, distance = pcall(function()
        return UnitXP_GetDistance("player", guid)
    end)
    
    if not success then
        return nil
    end
    
    if distance then
        -- Cache the distance
        self.cache[playerName] = {
            distance = distance,
            timestamp = GetTime(),
        }
        return distance
    end
    
    return nil
end

-- Get cached distance
function Spy.Distance:GetCachedDistance(playerName)
    local cached = self.cache[playerName]
    if cached then
        -- Use cached value if less than 1 second old
        if (GetTime() - cached.timestamp) < 1 then
            return cached.distance
        end
    end
    return nil
end

-- ✅ NEW: Get distance from global cache for sorting (NEVER calls UnitXP)
-- This is used by ManageNearbyList sorting to avoid expensive UnitXP calls
function Spy.Distance:GetCachedDistanceForSort(playerName)
    local cached = self.globalDistanceCache[playerName]
    if cached then
        -- Use cached value if less than 2 seconds old
        if (GetTime() - cached.timestamp) < 2 then
            return cached.distance
        end
    end
    return nil
end

-- Format distance text (no colors - colors now set by Line of Sight in List.lua)
function Spy.Distance:FormatDistance(distance)
    if not distance then
        return "--"
    end
    
    return string.format("%.0f", distance)
end

-- Clean up old cache entries
function Spy.Distance:CleanCache()
    local now = GetTime()
    for name, data in pairs(self.cache) do
        if (now - data.timestamp) > 5 then
            self.cache[name] = nil
        end
    end
end

--[[
Add distance update loop (only updates distance values, not layout)
]]
local distanceUpdateFrame = CreateFrame("Frame")
local distanceTimer = 0

distanceUpdateFrame:SetScript("OnUpdate", function() 
    local elapsed = arg1 or 0
    
    distanceTimer = distanceTimer + elapsed
    
    -- ✅ Use dynamic updateInterval from config (default 0.2 = 5 Hz)
    local interval = Spy.Distance.updateInterval
    if Spy.db and Spy.db.profile.DistanceUpdateRate then
        interval = 1 / Spy.db.profile.DistanceUpdateRate
    end
    
    if distanceTimer < interval then
        return
    end
    distanceTimer = 0
    
    if not Spy.db or not Spy.db.profile.Enabled then
        return
    end
    
    -- ✅ Check if distance display is enabled
    if not Spy.db.profile.EnableDistanceDisplay then
        return
    end
    
    if not Spy.MainWindow or not Spy.MainWindow:IsVisible() then
        return
    end
    
    local maxButtons = 20
    if Spy.db and Spy.db.profile.ResizeSpyLimit then
        maxButtons = Spy.db.profile.ResizeSpyLimit
    end
    
    -- ✅ PHASE 1: Update globalDistanceCache for ACTIVE players only
    -- InactiveList players (grayed out, not PVP flagged anymore) don't need distance updates
    -- This reduces CPU usage significantly when many players timeout but stay in list
    
    -- Update globalDistanceCache only for ActiveList
    if Spy.ActiveList then
        for playerName in pairs(Spy.ActiveList) do
            local distance = Spy.Distance:GetDistance(playerName)
            if distance then
                Spy.Distance.globalDistanceCache[playerName] = {
                    distance = distance,
                    timestamp = GetTime(),
                }
            end
        end
    end
    
    -- ✅ PHASE 2: Update distance TEXT only for visible frames
    if not Spy.MainWindow.PlayerFrames then return end
    
    for playerName, frame in pairs(Spy.MainWindow.PlayerFrames) do
        if frame.visible and frame:IsVisible() and frame.PlayerName and frame.RightText then
            local distanceText = "--"
            
            -- ✅ Only update distance for active players (not in InactiveList)
            if not Spy.InactiveList[frame.PlayerName] then
                -- Use cached value from globalDistanceCache (already updated in Phase 1)
                local cached = Spy.Distance.globalDistanceCache[frame.PlayerName]
                if cached then
                    distanceText = Spy.Distance:FormatDistance(cached.distance)
                end
            end
            
            frame.RightText:SetText(distanceText)
        end
    end
    
    -- Cleanup old cache entries occasionally
    if math.random(1, 10) == 1 then
        Spy.Distance:CleanCache()
        
        -- Also cleanup globalDistanceCache
        local now = GetTime()
        for name, data in pairs(Spy.Distance.globalDistanceCache) do
            if (now - data.timestamp) > 5 then
                Spy.Distance.globalDistanceCache[name] = nil
            end
        end
    end
end)

-- Start/Stop functions
local function StartDistanceUpdates()
    distanceUpdateFrame:Show()
end

local function StopDistanceUpdates()
    distanceUpdateFrame:Hide()
end

-- Hook into Spy's enable/disable
local Spy_EnableSpy_Original = Spy.EnableSpy
function Spy:EnableSpy(value, changeDisplay, hideEnabledMessage)
    Spy_EnableSpy_Original(self, value, changeDisplay, hideEnabledMessage)
    
    if value then
        StartDistanceUpdates()
    else
        StopDistanceUpdates()
    end
end

-- Initialize on load
if Spy.db and Spy.db.profile.Enabled then
    StartDistanceUpdates()
end

-- Debug command
SLASH_SPYDIST1 = "/spydist"

SlashCmdList["SPYDIST"] = function(msg)
    local isDebugToggle = (string.lower(msg) == "debug")
    
    if isDebugToggle then
        Spy.Distance.debug = not Spy.Distance.debug
        local debugStatus = Spy.Distance.debug and "|cff00ff00AN|r" or "|cffff0000AUS|r"
        
        DEFAULT_CHAT_FRAME:AddMessage("=== Spy Distance Debugging Toggle ===")
        DEFAULT_CHAT_FRAME:AddMessage("Detailed logging is now " .. debugStatus)
        
        if Spy.Distance.debug then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff[Distance DEBUG]|r **LOGGING ACTIVE! Expect detailed messages on enemy updates.**")
        end
        
        DEFAULT_CHAT_FRAME:AddMessage("==================================")
        return
    end

    -- Status check
    if not Spy.Distance.enabled then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[SpyRange]|r Feature is DISABLED (UnitXP 'distanceBetween' not available)")
        return
    end

    -- Summary
    DEFAULT_CHAT_FRAME:AddMessage("=== Spy Distance Summary ===")
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Status:|r ENABLED")
    
    if not SpySW then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000ERROR|r: SpySW (GUID module) not found! Distances will not work.")
        DEFAULT_CHAT_FRAME:AddMessage("==================================")
        return
    end
    
    local count = 0
    for name, _ in pairs(Spy.ActiveList) do
        count = count + 1
        
        local distance = Spy.Distance:GetCachedDistance(name) or Spy.Distance:GetDistance(name)
        
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00ff00%s|r: Distance=%s",
            name,
            distance and Spy.Distance:FormatDistance(distance) or "|cff888888Wird aktualisiert...|r"
        ))
    end
    
    DEFAULT_CHAT_FRAME:AddMessage("Total active enemies: " .. count)
    
    if Spy.Distance.debug then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff(NOTE: Debug logging is active. Use '/spydist debug' to disable)|r")
    end
    
    DEFAULT_CHAT_FRAME:AddMessage("==================================")
end

DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[Spy]|r Distance Display loaded. |cff00ffff/spydist debug|r to toggle detailed logging.")