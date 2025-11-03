--[[
Spy Distance Display Integration (WoW 1.12.1 / Lua 5.0 compatible)
FIXED VERSION - Hooks SetBar directly to prevent width conflicts
]]

-- Distance tracking module
Spy.Distance = {
    cache = {},
    updateInterval = 0.1,
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

-- Format distance text with color
function Spy.Distance:FormatDistance(distance)
    if not distance then
        return "|cff888888--|r"
    end
    
    local color
    if distance < 5 then
        color = "|cff0000ff" -- Blue (melee range)
    elseif distance < 8 then
        color = "|cff3380ff" -- Light blue
    elseif distance < 20 then
        color = "|cff57b3ff" -- Cyan
    elseif distance < 30 then
        color = "|cff00dc00" -- Green
    elseif distance < 35 then
        color = "|cffb3dc00" -- Yellow-green
    elseif distance < 41 then
        color = "|cffffff00" -- Yellow
    else
        color = "|cffff0000" -- Red (out of range)
    end
    
    return string.format("%s%.0f|r", color, distance)
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
✅ NEW APPROACH: Hook SetBar DIRECTLY to inject distance column setup
This runs IMMEDIATELY after SetBar creates/updates the row, before any other code
]]
local function HookSetBar()
    if Spy.Distance.debug then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff00ff[Distance DEBUG]|r Installing SetBar hook...")
    end
    
    local Spy_SetBar_Original = Spy.SetBar
    
    function Spy:SetBar(num, name, desc, value, colorgroup, colorclass, tooltipData, opacity)
        -- Call original SetBar first
        Spy_SetBar_Original(self, num, name, desc, value, colorgroup, colorclass, tooltipData, opacity)
        
        local Row = Spy.MainWindow.Rows[num]
        if not Row or not name or name == "" then 
            return 
        end
        
        -- Store player name for updates
        Row.playerName = name
        
        -- ✅ CREATE DistanceText if it doesn't exist yet
        if not Row.DistanceText then
            Row.DistanceText = Row.StatusBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            
            -- Use same font as other button text
            local fontName = "Fonts\\FRIZQT__.TTF"
            local fontSize = 12
            
            if Spy.db and Spy.db.profile then
                if Spy.db.profile.Font and SM and SM.Fetch then
                    fontName = SM:Fetch("font", Spy.db.profile.Font) or fontName
                end
                if Spy.db.profile.MainWindow and Spy.db.profile.MainWindow.RowHeight then
                    fontSize = math.max(Spy.db.profile.MainWindow.RowHeight * 0.75, Spy.db.profile.MainWindow.RowHeight - 8)
                end
            end
            
            Row.DistanceText:SetFont(fontName, fontSize, "")
            Row.DistanceText:SetJustifyH("CENTER")
            Row.DistanceText:SetTextColor(1, 1, 1, 1)
            
            -- Register with Spy's color system
            if Spy.Colors and Spy.Colors.RegisterFont then
                Spy.Colors:RegisterFont("Bar", "Bar Text", Row.DistanceText)
            end
        end
        
        -- ✅ CALCULATE WIDTHS (proportional to current row width)
        local rowWidth = Row:GetWidth()
        local nameWidth = rowWidth * 0.45   -- 40% for name
        local distWidth = rowWidth * 0.15   -- 20% for distance
        local detailWidth = rowWidth * 0.40 -- 40% for class/level
        
        -- ✅ REPOSITION LeftText (Name)
        Row.LeftText:ClearAllPoints()
        Row.LeftText:SetPoint("LEFT", Row.StatusBar, "LEFT", 2, 0)
        Row.LeftText:SetWidth(nameWidth)
        Row.LeftText:SetJustifyH("LEFT")
        
        -- ✅ REPOSITION DistanceText (Center)
        Row.DistanceText:ClearAllPoints()
        Row.DistanceText:SetPoint("LEFT", Row.LeftText, "RIGHT", 25, 0)
        Row.DistanceText:SetWidth(distWidth)
        Row.DistanceText:SetHeight(Row:GetHeight())
        
        -- Get distance and update text
        local distance = Spy.Distance:GetDistance(name)
        if not distance then
            distance = Spy.Distance:GetCachedDistance(name)
        end
        local distanceText = Spy.Distance:FormatDistance(distance)
        Row.DistanceText:SetText(distanceText)
        Row.DistanceText:Show()
        
        -- ✅ REPOSITION RightText (Details)
        Row.RightText:ClearAllPoints()
        Row.RightText:SetPoint("RIGHT", Row.StatusBar, "RIGHT", -2, 0)
        Row.RightText:SetWidth(detailWidth)
        Row.RightText:SetJustifyH("RIGHT")
        
        if Spy.Distance.debug then
            -- Only log if values changed
            local debugKey = string.format("%d:%s:%.0f:%.0f:%.0f", num, name, nameWidth, distWidth, detailWidth)
            if not Row._lastDebugKey or Row._lastDebugKey ~= debugKey then
                Row._lastDebugKey = debugKey
                DEFAULT_CHAT_FRAME:AddMessage(string.format(
                    "|cff00ff00[Distance]|r SetBar(%d, %s) widths: Name=%.0f, Dist=%.0f, Detail=%.0f",
                    num, name, nameWidth, distWidth, detailWidth
                ))
            end
        end
    end
end

-- Install SetBar hook immediately
HookSetBar()

--[[
Add distance update loop (only updates distance values, not layout)
]]
local distanceUpdateFrame = CreateFrame("Frame")
local distanceTimer = 0

distanceUpdateFrame:SetScript("OnUpdate", function() 
    local elapsed = arg1 or 0
    
    distanceTimer = distanceTimer + elapsed
    
    if distanceTimer < Spy.Distance.updateInterval then
        return
    end
    distanceTimer = 0
    
    if not Spy.db or not Spy.db.profile.Enabled then
        return
    end
    
    if not Spy.MainWindow or not Spy.MainWindow:IsVisible() then
        return
    end
    
    local maxButtons = 20
    if Spy.db and Spy.db.profile.ResizeSpyLimit then
        maxButtons = Spy.db.profile.ResizeSpyLimit
    end
    
    -- Only update distance TEXT, not layout
    for i = 1, maxButtons do
        local button = Spy.MainWindow.Rows[i]
        if button and button:IsVisible() and button.playerName and button.DistanceText then
            local distance = Spy.Distance:GetDistance(button.playerName)
            if not distance then
                distance = Spy.Distance:GetCachedDistance(button.playerName)
            end
            local distanceText = Spy.Distance:FormatDistance(distance)
            button.DistanceText:SetText(distanceText)
        end
    end
    
    -- Cleanup cache occasionally
    if math.random(1, 10) == 1 then
        Spy.Distance:CleanCache()
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
        DEFAULT_CHAT_FRAME:AddMessage("Detailliertes Logging ist jetzt " .. debugStatus)
        
        if Spy.Distance.debug then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff[Distance DEBUG]|r **LOGGING AKTIV! Erwarte detaillierte Meldungen bei Gegner-Updates.**")
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
    DEFAULT_CHAT_FRAME:AddMessage("=== Spy Distance Zusammenfassung ===")
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Status:|r ENABLED")
    
    if not SpySW then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000FEHLER|r: SpySW (Guid-Modul) nicht gefunden! Distanzen funktionieren nicht.")
        DEFAULT_CHAT_FRAME:AddMessage("==================================")
        return
    end
    
    local count = 0
    for name, _ in pairs(Spy.ActiveList) do
        count = count + 1
        
        local distance = Spy.Distance:GetCachedDistance(name) or Spy.Distance:GetDistance(name)
        
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00ff00%s|r: Distanz=%s",
            name,
            distance and Spy.Distance:FormatDistance(distance) or "|cff888888Wird aktualisiert...|r"
        ))
    end
    
    DEFAULT_CHAT_FRAME:AddMessage("Total aktive Feinde: " .. count)
    
    if Spy.Distance.debug then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff(HINWEIS: Debug-Logging ist aktiv. Nutzen Sie '/spydist debug' zum Ausschalten)|r")
    end
    
    DEFAULT_CHAT_FRAME:AddMessage("==================================")
end

DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[Spy]|r Distance Display loaded. |cff00ffff/spydist debug|r zum Togglen des detaillierten Loggings.")