local AceLocale = LibStub("AceLocale-3.0")
local L = AceLocale:GetLocale("Spy")

-- Performance: Cache global functions as locals
local upper, lower = string.upper, string.lower
local format, strfind, strsub = string.format, string.find, string.sub
local strlen = string.len
local strgfind = string.gfind
local tinsert = table.insert
local tsort = table.sort

-- ✅ FIX 1: In RefreshCurrentList() - Store GUID directly in frame
function Spy:RefreshCurrentList(player, source)
	local MainWindow = Spy.MainWindow
	if not MainWindow then return end
	if not MainWindow:IsShown() then
		return
	end

	local mode = Spy.db.profile.CurrentList
	local manageFunction = Spy.ListTypes[mode][2]
	if manageFunction then manageFunction() end

	-- ✅ Build list of players currently in CurrentList
	local playersInList = {}
	for index, data in pairs(Spy.CurrentList) do
		playersInList[data.player] = true
	end
	
	-- ✅ Hide only frames NOT in current list
	for playerName, frame in pairs(Spy.MainWindow.PlayerFrames) do
		if not playersInList[playerName] then
			frame:Hide()
			frame.visible = false
			frame.displayIndex = nil
		end
	end

	-- Now iterate through CurrentList and show frames
	local yOffset = 34
	local displayCount = 0
	
	for index, data in ipairs(Spy.CurrentList) do
		if displayCount < Spy.db.profile.ResizeSpyLimit then
			local playerName = data.player
			
			-- Get or create frame for this player
			local frame = Spy:CreatePlayerFrame(playerName)
			
			-- ✅ CRITICAL FIX: Always update GUID before showing frame
			-- This ensures targeting works even if GUID was missing during creation
			if not frame.PlayerGUID or not UnitExists(frame.PlayerGUID) then
				local guid = nil
				
				-- ✅ Priority 1: SpySW nameToGuid (always fresh from scanner)
				-- SuperWoW can target units even if UnitExists returns false, so trust the GUID!
				if SpySW and SpySW.nameToGuid then
					guid = SpySW.nameToGuid[playerName]
				end
				
				-- Priority 2: GUID from PlayerData (fallback if SpySW doesn't have it yet)
				if not guid then
					local playerData = SpyPerCharDB.PlayerData[playerName]
					if playerData and playerData.guid then
						guid = playerData.guid
					end
				end
				
				-- Priority 3: GUID from SpySW.guids table (search by name)
				if not guid and SpySW and SpySW.guids then
					for cachedGuid, timestamp in pairs(SpySW.guids) do
						if UnitExists(cachedGuid) then
							local name = UnitName(cachedGuid)
							if name == playerName then
								guid = cachedGuid
								break
							end
						end
					end
				end
				
				-- Update frame GUID if found
				if guid then
					frame.PlayerGUID = guid
					frame.PlayerName = playerName
				end
			end
			
			-- ✅ CRITICAL FIX: Store name in ButtonName table for backwards compatibility
			-- This ensures OnClick handlers can always find the player name
			if not frame.id then
				-- Assign a stable ID to this frame
				frame.id = displayCount + 1
			end
			Spy.ButtonName = Spy.ButtonName or {}
			Spy.ButtonName[frame.id] = playerName
			
			-- Prepare data for display
			local description = ""
			local level = "??"
			local class = "UNKNOWN"
			local guild = "??"
			local opacity = 1

			local playerData = SpyPerCharDB.PlayerData[playerName]
			if playerData then
				if playerData.level then
					level = (playerData.level == 0) and "??" or playerData.level
					if playerData.isGuess == true and tonumber(playerData.level) < Spy.MaximumPlayerLevel then
						level = level .. "+"
					end
				end
				if playerData.class then
					class = playerData.class
				end
				if playerData.guild then
					guild = playerData.guild
				end
			end
			
			if mode == 1 and Spy.InactiveList[playerName] then
				opacity = 0.5
			end
			
			-- HP-Bar: Try to get initial HP value
			local currentBarValue = 100
			
			-- Try to get HP immediately if GUID available
			local guid = frame.PlayerGUID
			if guid and UnitExists(guid) then
				local currentHP = UnitHealth(guid)
				local maxHP = UnitHealthMax(guid)
				if maxHP > 0 then
					currentBarValue = (currentHP / maxHP) * 100
				end
			end
			
			frame.StatusBar:SetValue(currentBarValue)
			
			-- Update LeftText size
			local leftFont, _, leftFlags = frame.LeftText:GetFont()
			local leftSize = math.max(Spy.db.profile.MainWindow.RowHeight * 0.85, Spy.db.profile.MainWindow.RowHeight - 1)
			frame.LeftText:SetFont(leftFont, leftSize, leftFlags or "THINOUTLINE")
			
			-- Set level text (left)
			frame.LeftText:SetText(level)
			
			-- Create MiddleText if not exists
			if not frame.MiddleText then
				frame.MiddleText = frame.StatusBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
				frame.MiddleText:SetJustifyH("LEFT")
				
				local fontName = "Fonts\\FRIZQT__.TTF"
				local fontSize = math.max(Spy.db.profile.MainWindow.RowHeight * 0.85, Spy.db.profile.MainWindow.RowHeight - 1)
				if Spy.db.profile.Font and SM and SM.Fetch then
					fontName = SM:Fetch("font", Spy.db.profile.Font) or fontName
				end
				frame.MiddleText:SetFont(fontName, fontSize, "THINOUTLINE")
				
				Spy.Colors:RegisterFont("Bar", "Bar Text", frame.MiddleText)
				Spy:AddFontString(frame.MiddleText)
			else
				-- Update font size on refresh (keeps font name from SetFont)
				local currentFont, _, currentFlags = frame.MiddleText:GetFont()
				local fontSize = math.max(Spy.db.profile.MainWindow.RowHeight * 0.85, Spy.db.profile.MainWindow.RowHeight - 1)
				frame.MiddleText:SetFont(currentFont, fontSize, currentFlags or "THINOUTLINE")
			end
			
			frame.MiddleText:SetText(playerName)  -- Name in center
			
			-- Calculate available widths to avoid overlap
			local frameWidth = frame:GetWidth()
			local levelWidth = frame.LeftText:GetStringWidth() + 4  -- Level + Spacing
			local rightWidth = 30  -- Reserve for Distance (-- or numbers)
			local nameWidth = frameWidth - levelWidth - rightWidth - 8  -- 8px total padding
			
			-- Limit MiddleText Width
			frame.MiddleText:SetWidth(nameWidth)
			frame.MiddleText:ClearAllPoints()
			frame.MiddleText:SetPoint("LEFT", frame.LeftText, "RIGHT", 4, 0)
			
			-- Distance on right (only if SP3 is available)
			if Spy.Distance and Spy.Distance.enabled then
				-- Update RightText size
				local rightFont, _, rightFlags = frame.RightText:GetFont()
				local rightSize = math.max(Spy.db.profile.MainWindow.RowHeight * 0.75, Spy.db.profile.MainWindow.RowHeight - 8)
				frame.RightText:SetFont(rightFont, rightSize, rightFlags or "THINOUTLINE")
				
				local distanceText = "--"
				local distance = nil
				
				-- ✅ FIX: Use same logic as opacity - only show distance if player is ACTIVE
				-- If player is in InactiveList (grayed out), they're out of range → show "--"
				if not (mode == 1 and Spy.InactiveList[playerName]) then
					distance = Spy.Distance:GetDistance(playerName)
					if distance then
						distanceText = Spy.Distance:FormatDistance(distance)
					end
				end
				
				frame.RightText:SetText(distanceText)
				frame.RightText:Show()
				
				-- Line of Sight color (only if we have actual distance AND player is active)
				local distanceR, distanceG, distanceB = 1, 1, 1  -- Default: White
				if distance and frame.PlayerGUID and UnitExists(frame.PlayerGUID) then
					local los = UnitXP("inSight", "player", frame.PlayerGUID)
					if los == true then
						distanceR, distanceG, distanceB = 0, 1, 0  -- Green: Line of sight clear
					else
						distanceR, distanceG, distanceB = 1, 0, 0  -- Red: Line of sight blocked
					end
				end
				
				frame.RightText:SetTextColor(distanceR, distanceG, distanceB, opacity)
			else
				-- SP3 not available - hide RightText completely
				frame.RightText:SetText("")
				frame.RightText:Hide()
			end
			
			-- HP-Bar: Store class for OnUpdate HP feature
			frame.playerClass = class
			
			-- ✅ CRITICAL FIX: Set frame level RELATIVE to MainWindow
			frame:SetFrameLevel(Spy.MainWindow:GetFrameLevel() + displayCount + 2)
			frame.StatusBar:SetFrameLevel(Spy.MainWindow:GetFrameLevel() + displayCount + 1)
			
			-- Set class color
			local r, g, b = Spy:GetClassColor(class)
			frame.StatusBar:SetStatusBarColor(r, g, b, opacity)
			
			-- Level color system (WoW PvP Style)
			local levelR, levelG, levelB = 1, 1, 1  -- Default: White

			local playerLevel = UnitLevel("player")
			local enemyLevel = tonumber(level)

			if level == "??" then
				levelR, levelG, levelB = 1.0, 0.0, 0.0
			elseif playerLevel and enemyLevel and enemyLevel > 0 then
				local levelDiff = enemyLevel - playerLevel
				
				if levelDiff >= 5 then
					levelR, levelG, levelB = 1.0, 0.0, 0.0
				elseif levelDiff >= 3 then
					levelR, levelG, levelB = 1.0, 0.5, 0.0
				elseif levelDiff >= -2 then
					levelR, levelG, levelB = 1.0, 1.0, 0.0
				elseif levelDiff >= -9 then
					levelR, levelG, levelB = 0.25, 1.0, 0.25
				else
					levelR, levelG, levelB = 0.5, 0.5, 0.5
				end
			end

			frame.LeftText:SetTextColor(levelR, levelG, levelB, opacity)
			frame.MiddleText:SetTextColor(1, 1, 1, opacity)
			
			-- Position frame
			frame:ClearAllPoints()
			frame:SetPoint("TOPLEFT", MainWindow, "TOPLEFT", 2, -yOffset)
			yOffset = yOffset + Spy.db.profile.MainWindow.RowHeight + Spy.db.profile.MainWindow.RowSpacing
			
			-- ✅ Show frame and mark as visible
			frame:Show()
			frame.visible = true
			frame.displayIndex = displayCount + 1
			displayCount = displayCount + 1
			
			-- Alert if needed
			if player == playerName then
				if not source or source ~= Spy.CharacterName then
					Spy:AlertPlayer(player, source)
					if not source then 
						Spy:AnnouncePlayer(player) 
					end
				end
			end
		else
			-- Hide frames beyond the limit
			local frame = Spy.MainWindow.PlayerFrames[data.player]
			if frame then
				frame:Hide()
				frame.visible = false
			end
		end
	end
	
	Spy.ListAmountDisplayed = displayCount

	-- Auto-resize if enabled
	if Spy.db.profile.ResizeSpy then
		Spy:AutomaticallyResize()
	else
		if not Spy.db.profile.InvertSpy then
			if Spy.MainWindow:GetHeight() < 34 then
				Spy:RestoreMainWindowPosition(Spy.MainWindow:GetLeft(), Spy.MainWindow:GetTop(), Spy.MainWindow:GetWidth(), 34)
			end
		else
			if Spy.MainWindow:GetHeight() < 34 then 
				Spy:RestoreMainWindowPosition(Spy.MainWindow:GetLeft(), Spy.MainWindow:GetBottom(), Spy.MainWindow:GetWidth(), 34)
			end
		end	
	end

	Spy:ManageBarsDisplayed()
end

-- ✅ NEW: /spyguid command - Show GUID info for all visible players
SLASH_SPYGUID1 = "/spyguid"
SlashCmdList["SPYGUID"] = function()
	if not Spy.MainWindow or not Spy.MainWindow.PlayerFrames then
		DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[SpyGUID]|r Main window not initialized!")
		return
	end
	
	-- Toggle GUID debug mode
	Spy.GuidDebug = not Spy.GuidDebug
	
	if Spy.GuidDebug then
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SpyGUID]|r GUID Debug Mode: |cff00ff00ENABLED|r")
		DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00Click on player frames to see targeting info|r")
	else
		DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[SpyGUID]|r GUID Debug Mode: |cffff0000DISABLED|r")
		return
	end
	
	-- Show GUID info for all visible frames
	DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00========== Visible Player GUIDs ==========|r")
	
	local visibleCount = 0
	for playerName, frame in pairs(Spy.MainWindow.PlayerFrames) do
		if frame.visible and frame:IsShown() then
			visibleCount = visibleCount + 1
			
			local guid = frame.PlayerGUID
			local guidStatus = guid and "|cff00ff00STORED|r" or "|cffff0000MISSING|r"
			local existsStatus = ""
			
			if guid then
				if UnitExists(guid) then
					existsStatus = " |cff00ff00(in range)|r"
				else
					existsStatus = " |cffffcc00(out of range)|r"
				end
			end
			
			DEFAULT_CHAT_FRAME:AddMessage(string.format(
				"|cff00ffff%d.|r %s - GUID: %s%s",
				visibleCount,
				playerName,
				guidStatus,
				existsStatus
			))
			
			if guid then
				DEFAULT_CHAT_FRAME:AddMessage("    |cffaaaaaa" .. tostring(guid) .. "|r")
			end
		end
	end
	
	if visibleCount == 0 then
		DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00No visible players in list|r")
	else
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Total: " .. visibleCount .. " players|r")
	end
	
	DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00========================================|r")
end

-- ✅ STABLE SORT: Track insertion order
Spy.DetectionOrder = Spy.DetectionOrder or {}
Spy.DetectionOrderCounter = Spy.DetectionOrderCounter or 0

function Spy:ManageNearbyList()
	-- ✅ SAFETY: Ensure tables exist (defensive programming)
	Spy.DetectionOrder = Spy.DetectionOrder or {}
	Spy.DetectionTimestamp = Spy.DetectionTimestamp or {}
	
	local prioritiseKoS = Spy.db.profile.PrioritiseKoS

	local activeKoS = {}
	local active = {}
	
	-- ✅ FIX: Create sorted list from ActiveList first (by high-precision timestamp)
	-- This ensures stable iteration order before sorting by time
	local activePlayers = {}
	for player in pairs(Spy.ActiveList) do
		tinsert(activePlayers, player)
	end
	-- Pre-sort by high-precision timestamp with DetectionOrder as tiebreaker for stability
	tsort(activePlayers, function(a, b)
		local timeA = Spy.DetectionTimestamp[a] or 0
		local timeB = Spy.DetectionTimestamp[b] or 0
		if timeA == timeB then
			-- Same timestamp â†’ use DetectionOrder for stable sort
			local orderA = Spy.DetectionOrder[a] or 0
			local orderB = Spy.DetectionOrder[b] or 0
			return orderA < orderB  -- Lower order (earlier detection) first
		end
		return timeA > timeB  -- Newer first
	end)
	
	for _, player in ipairs(activePlayers) do
		local position = Spy.NearbyList[player]
		if position ~= nil then
			-- ✅ Use DetectionTimestamp for sorting (millisecond precision) instead of position (second precision)
			local preciseTime = Spy.DetectionTimestamp[player] or position
			local order = Spy.DetectionOrder[player] or 0
			
			if prioritiseKoS and SpyPerCharDB.KOSData[player] then
				tinsert(activeKoS, { player = player, time = preciseTime, order = order })
			else
				tinsert(active, { player = player, time = preciseTime, order = order })
			end
		end
	end

	local inactiveKoS = {}
	local inactive = {}
	
	-- ✅ Same fix for InactiveList
	local inactivePlayers = {}
	for player in pairs(Spy.InactiveList) do
		tinsert(inactivePlayers, player)
	end
	tsort(inactivePlayers, function(a, b)
		local timeA = Spy.DetectionTimestamp[a] or 0
		local timeB = Spy.DetectionTimestamp[b] or 0
		if timeA == timeB then
			-- Same timestamp â†’ use DetectionOrder for stable sort
			local orderA = Spy.DetectionOrder[a] or 0
			local orderB = Spy.DetectionOrder[b] or 0
			return orderA < orderB  -- Lower order (earlier detection) first
		end
		return timeA > timeB  -- Newer first
	end)
	
	for _, player in ipairs(inactivePlayers) do
		local position = Spy.NearbyList[player]
		if position ~= nil then
			-- ✅ Use DetectionTimestamp for sorting (millisecond precision) instead of position (second precision)
			local preciseTime = Spy.DetectionTimestamp[player] or position
			local order = Spy.DetectionOrder[player] or 0
			
			if prioritiseKoS and SpyPerCharDB.KOSData[player] then
				tinsert(inactiveKoS, { player = player, time = preciseTime, order = order })
			else
				tinsert(inactive, { player = player, time = preciseTime, order = order })
			end
		end
	end

	-- Sort based on user preference
	local sortOrder = Spy.db.profile.NearbySortOrder or "time"
	
	if sortOrder == "range" then
		-- Sort by distance (closest first) - requires SpyDistance
		if Spy.Distance and Spy.Distance.enabled and Spy.Distance.GetDistance then
			-- ✅ STABLE SORT: Use order as tiebreaker
			tsort(activeKoS, function(a, b)
				local distA = Spy.Distance:GetDistance(a.player) or 999999
				local distB = Spy.Distance:GetDistance(b.player) or 999999
				if distA == distB then
					return a.order < b.order  -- Same distance â†’ use insertion order
				end
				return distA < distB
			end)
			tsort(inactiveKoS, function(a, b)
				local distA = Spy.Distance:GetDistance(a.player) or 999999
				local distB = Spy.Distance:GetDistance(b.player) or 999999
				if distA == distB then
					return a.order < b.order
				end
				return distA < distB
			end)
			tsort(active, function(a, b)
				local distA = Spy.Distance:GetDistance(a.player) or 999999
				local distB = Spy.Distance:GetDistance(b.player) or 999999
				if distA == distB then
					return a.order < b.order
				end
				return distA < distB
			end)
			tsort(inactive, function(a, b)
				local distA = Spy.Distance:GetDistance(a.player) or 999999
				local distB = Spy.Distance:GetDistance(b.player) or 999999
				if distA == distB then
					return a.order < b.order
				end
				return distA < distB
			end)
		else
			-- Fallback to time if SpyDistance not available
			-- ✅ STABLE SORT: Use order as tiebreaker
			tsort(activeKoS, function(a, b)
				if a.time == b.time then
					return a.order < b.order
				end
				return a.time > b.time
			end)
			tsort(inactiveKoS, function(a, b)
				if a.time == b.time then
					return a.order < b.order
				end
				return a.time > b.time
			end)
			tsort(active, function(a, b)
				if a.time == b.time then
					return a.order < b.order
				end
				return a.time > b.time
			end)
			tsort(inactive, function(a, b)
				if a.time == b.time then
					return a.order < b.order
				end
				return a.time > b.time
			end)
		end
	elseif sortOrder == "name" then
		-- Sort by name (alphabetical)
		-- ✅ STABLE SORT: Use order as tiebreaker (edge case: same name shouldn't happen)
		tsort(activeKoS, function(a, b)
			if a.player == b.player then
				return a.order < b.order
			end
			return a.player < b.player
		end)
		tsort(inactiveKoS, function(a, b)
			if a.player == b.player then
				return a.order < b.order
			end
			return a.player < b.player
		end)
		tsort(active, function(a, b)
			if a.player == b.player then
				return a.order < b.order
			end
			return a.player < b.player
		end)
		tsort(inactive, function(a, b)
			if a.player == b.player then
				return a.order < b.order
			end
			return a.player < b.player
		end)
	elseif sortOrder == "class" then
		-- Sort by class (alphabetical)
		-- ✅ STABLE SORT: Use order as tiebreaker
		tsort(activeKoS, function(a, b)
			local classA = SpyPerCharDB.PlayerData[a.player] and SpyPerCharDB.PlayerData[a.player].class or "ZZZ"
			local classB = SpyPerCharDB.PlayerData[b.player] and SpyPerCharDB.PlayerData[b.player].class or "ZZZ"
			if classA == classB then
				return a.order < b.order
			end
			return classA < classB
		end)
		tsort(inactiveKoS, function(a, b)
			local classA = SpyPerCharDB.PlayerData[a.player] and SpyPerCharDB.PlayerData[a.player].class or "ZZZ"
			local classB = SpyPerCharDB.PlayerData[b.player] and SpyPerCharDB.PlayerData[b.player].class or "ZZZ"
			if classA == classB then
				return a.order < b.order
			end
			return classA < classB
		end)
		tsort(active, function(a, b)
			local classA = SpyPerCharDB.PlayerData[a.player] and SpyPerCharDB.PlayerData[a.player].class or "ZZZ"
			local classB = SpyPerCharDB.PlayerData[b.player] and SpyPerCharDB.PlayerData[b.player].class or "ZZZ"
			if classA == classB then
				return a.order < b.order
			end
			return classA < classB
		end)
		tsort(inactive, function(a, b)
			local classA = SpyPerCharDB.PlayerData[a.player] and SpyPerCharDB.PlayerData[a.player].class or "ZZZ"
			local classB = SpyPerCharDB.PlayerData[b.player] and SpyPerCharDB.PlayerData[b.player].class or "ZZZ"
			if classA == classB then
				return a.order < b.order
			end
			return classA < classB
		end)
	else
		-- Sort by time (newest first) - default
		-- ✅ STABLE SORT: Newer detections on top, same time = EARLIER detection (lower order) stays on top
		tsort(activeKoS, function(a, b)
			if a.time == b.time then
				return a.order < b.order  -- Same time â†’ earlier detection (lower order) stays on top
			end
			return a.time > b.time
		end)
		tsort(inactiveKoS, function(a, b)
			if a.time == b.time then
				return a.order < b.order
			end
			return a.time > b.time
		end)
		tsort(active, function(a, b)
			if a.time == b.time then
				return a.order < b.order
			end
			return a.time > b.time
		end)
		tsort(inactive, function(a, b)
			if a.time == b.time then
				return a.order < b.order
			end
			return a.time > b.time
		end)
	end

	local list = {}
	for _, data in ipairs(activeKoS) do tinsert(list, data) end
	for _, data in ipairs(inactiveKoS) do tinsert(list, data) end
	for _, data in ipairs(active) do tinsert(list, data) end
	for _, data in ipairs(inactive) do tinsert(list, data) end
	Spy.CurrentList = list
end

function Spy:ManageLastHourList()
	local list = {}
	for player in pairs(Spy.LastHourList) do
		tinsert(list, { player = player, time = Spy.LastHourList[player] })
	end
	tsort(list, function(a, b) return a.time > b.time end)
	Spy.CurrentList = list
end

function Spy:ManageIgnoreList()
	local list = {}
	for player in pairs(SpyPerCharDB.IgnoreData) do
		local playerData = SpyPerCharDB.PlayerData[player]
		local position = time()
		if playerData then position = playerData.time end
		tinsert(list, { player = player, time = position })
	end
	tsort(list, function(a, b) return a.time > b.time end)
	Spy.CurrentList = list
end

function Spy:ManageKillOnSightList()
	local list = {}
	for player in pairs(SpyPerCharDB.KOSData) do
		local playerData = SpyPerCharDB.PlayerData[player]
		local position = time()
		if playerData then position = playerData.time end
		tinsert(list, { player = player, time = position })
	end
	tsort(list, function(a, b) return a.time > b.time end)
	Spy.CurrentList = list
end

function Spy:GetNearbyListSize()
	local entries = 0
	for _ in pairs(Spy.NearbyList) do
		entries = entries + 1
	end
	return entries
end

function Spy:UpdateActiveCount()
    local activeCount = 0
    for k in pairs(Spy.ActiveList) do
        activeCount = activeCount + 1
    end
	local theFrame = Spy.MainWindow
	if not theFrame then return end
	if not theFrame.CountFrame or not theFrame.CountFrame.Text then return end
	
    if activeCount > 0 then 
		theFrame.CountFrame.Text:SetText(activeCount) 
		theFrame.CountFrame.Text:SetTextColor(1, 1, 0, 1)
    else 
        theFrame.CountFrame.Text:SetText("0")
		theFrame.CountFrame.Text:SetTextColor(0.5, 0.5, 0.5, 1)
    end
end

function Spy:ManageExpirations()
	local mode = Spy.db.profile.CurrentList
	local expirationFunction = Spy.ListTypes[mode][3]
	if expirationFunction then 
		expirationFunction() 
	end
end

function Spy:ManageNearbyListExpirations()
	local expired = false
	local currentTime = time()
	for player in pairs(Spy.ActiveList) do
		if (currentTime - Spy.ActiveList[player]) > Spy.ActiveTimeout then
			Spy.InactiveList[player] = Spy.ActiveList[player]
			Spy.ActiveList[player] = nil
			expired = true
		end
	end
	if Spy.db.profile.RemoveUndetected ~= "Never" then
		for player in pairs(Spy.InactiveList) do
			if (currentTime - Spy.InactiveList[player]) > Spy.InactiveTimeout then
				-- Map note cleanup removed - MapNoteList no longer exists
				Spy.InactiveList[player] = nil
				Spy.NearbyList[player] = nil
				-- ✅ FIX: Destroy player frame when removed from Nearby
				Spy:DestroyPlayerFrame(player)
				expired = true
			end
		end
	end
	if expired then
		Spy:RefreshCurrentList()
		Spy:UpdateActiveCount()
		if Spy.db.profile.HideSpy and Spy:GetNearbyListSize() == 0 then
			if Spy.MainWindow then  -- Safety check
				Spy.MainWindow:Hide()
			end
		end
	end
end

function Spy:ManageLastHourListExpirations()
	local expired = false
	local currentTime = time()
	for player in pairs(Spy.LastHourList) do
		if (currentTime - Spy.LastHourList[player]) > 3600 then
			Spy.LastHourList[player] = nil
			expired = true
		end
	end
	if expired then
		Spy:RefreshCurrentList()
	end
end

function Spy:RemovePlayerFromList(player)
	if player == nil then return end
	Spy.NearbyList[player] = nil
	Spy.ActiveList[player] = nil
	Spy.InactiveList[player] = nil
	-- ✅ FIX: Destroy player frame when manually removed
	Spy:DestroyPlayerFrame(player)
	-- Map note cleanup removed - MapNoteList no longer exists
	Spy:RefreshCurrentList()
	Spy:UpdateActiveCount()
end

function Spy:ClearList()
	if IsShiftKeyDown () then
		Spy:EnableSound(not Spy.db.profile.EnableSound, false)
	else
		-- ✅ FIX: Destroy all player frames when clearing list
		Spy:DestroyAllPlayerFrames()
		Spy.NearbyList = {}
		Spy.ActiveList = {}
		Spy.InactiveList = {}
		Spy.PlayerCommList = {}
		Spy.ListAmountDisplayed = 0
		-- Map note cleanup loop removed - MapNoteList no longer exists
		Spy:SetCurrentList(1)
		if IsControlKeyDown() then
			Spy:EnableSpy(not Spy.db.profile.Enabled, false)
		end
		Spy:UpdateActiveCount()
	end
end

function Spy:AddPlayerData(name, class, level, race, guild, isEnemy, isGuess)
	-- ✅ FIX: Never add "Unknown" placeholder names
	if not name or name == "Unknown" or name == "" then
		if Spy.db and Spy.db.profile and Spy.db.profile.DebugMode then
			DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[Spy]|r Rejected Unknown/invalid name")
		end
		return nil
	end
	
	local info = {}
	info.name = name --++ added to normalize data
	info.class = class
	if type(level) == "number" then info.level = level end
	info.race = race
	info.guild = guild
	info.isEnemy = isEnemy
	info.isGuess = isGuess
	SpyPerCharDB.PlayerData[name] = info
	return SpyPerCharDB.PlayerData[name]
end

function Spy:UpdatePlayerData(name, class, level, race, guild, isEnemy, isGuess)
	-- ✅ PET CHECK: Validate this is actually a player, not a pet
	local guid = nil
	if SpySW and SpySW.nameToGuid then
		guid = SpySW.nameToGuid[name]
	end
	
	local isValidPlayer = Spy:ValidatePlayerNotPet(name, guid)
	
	if isValidPlayer == false then
		-- Confirmed pet - do NOT add to database
		if Spy.DebugPets then
			DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[Spy-Pet]|r Blocked pet from database: " .. tostring(name))
		end
		return false
	end
	
	if isValidPlayer == nil then
		-- Unable to determine - be cautious
		-- Only proceed if we already have this player in database
		if not SpyPerCharDB.PlayerData[name] then
			if Spy.DebugPets then
				DEFAULT_CHAT_FRAME:AddMessage("|cff888888[Spy-Pet]|r Uncertain detection skipped: " .. tostring(name))
			end
			return false
		end
	end
	
	if Spy.DebugPets and isValidPlayer == true then
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[Spy-Pet]|r Confirmed player: " .. tostring(name))
	end
	
	-- ✅ FIX: Never process "Unknown" placeholder names
	if not name or name == "Unknown" or name == "" then
		if Spy.db and Spy.db.profile and Spy.db.profile.DebugMode then
			DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[Spy]|r Rejected Unknown/invalid name")
		end
		return false
	end
	
	local detected = true
	local playerData = SpyPerCharDB.PlayerData[name]
	
	-- ✅ Check if this is a NEW player (never seen before)
	local isNewPlayer = (playerData == nil)
	
	if Spy:PlayerIsFriend(name) then
		if playerData then
			Spy:RemovePlayerData(name)
		end
		return
	end
	
	if not playerData then
		playerData = Spy:AddPlayerData(name, class, level, race, guild, isEnemy, isGuess)
		if not playerData then
			return false  -- AddPlayerData rejected the name
		end
		-- ✅ Debug ONLY for NEW players
		if Spy.db and Spy.db.profile and Spy.db.profile.DebugMode then
			DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff[Spy DEBUG]|r NEW PLAYER: " .. name .. " Lvl" .. tostring(level) .. " " .. tostring(class))
		end
	else
		-- ✅ Player already exists - only update changed fields (NO DEBUG)
		if name ~= nil then playerData.name = name end 
		if class ~= nil then playerData.class = class end
		if type(level) == "number" then playerData.level = level end
		if race ~= nil then playerData.race = race end
		if guild ~= nil then playerData.guild = guild end
		if isEnemy ~= nil then playerData.isEnemy = isEnemy end
		if isGuess ~= nil then playerData.isGuess = isGuess end
	end
	
	if playerData then
		playerData.time = time()
		
		-- ✅ CRITICAL FIX: Always update GUID from SpySW for distance calculation
		-- The GUID is needed by SpyDistance to calculate range
		-- Update it every time to ensure it's never stale
		if SpySW and SpySW.nameToGuid then
			local guid = SpySW.nameToGuid[name]
			if guid then
				-- ✅ FIX: Update playerData.guid even if UnitExists returns false temporarily
				-- The GUID might be valid but unit temporarily unavailable (phasing, loading, etc)
				-- We trust SpySW's scanner - if it has the GUID, it's current
				playerData.guid = guid
			end
		end
		
		-- ✅ ALWAYS update zone/coords - this is YOUR location where you detected them
		-- Get map coordinates (your current position)
		local mapX, mapY = 0, 0
		
		if WorldMapFrame:IsVisible() then
			SetMapToCurrentZone()
			mapX, mapY = GetPlayerMapPosition("player")
		else
			-- Try to get position without showing WorldMap
			mapX, mapY = GetPlayerMapPosition("player")
		end
		
		if mapX ~= 0 and mapY ~= 0 then
			mapX = math.floor(tonumber(mapX) * 100) / 100
			mapY = math.floor(tonumber(mapY) * 100) / 100
			playerData.mapX = mapX
			playerData.mapY = mapY
			playerData.zone = GetZoneText()
			playerData.subZone = GetSubZoneText()
		else
			-- ✅ Map coords not available yet - store zone info only
			-- This is NORMAL on first login
			playerData.zone = GetZoneText()
			playerData.subZone = GetSubZoneText()
			
			-- ✅ Debug if no coords available
			if isNewPlayer and Spy.db and Spy.db.profile and Spy.db.profile.DebugMode then
				DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[Spy DEBUG]|r No map coords for " .. name .. ", zone: " .. tostring(playerData.zone))
			end
		end
	end
	
	-- ✅ NO DEBUG for routine updates - only logged once per NEW player above
	return detected
end

function Spy:UpdatePlayerStatus(name, class, level, race, guild, isEnemy, isGuess)
	local playerData = SpyPerCharDB.PlayerData[name]
	if not playerData then
		playerData = Spy:AddPlayerData(name, class, level, race, guild, isEnemy, isGuess)
	else
		if name ~= nil then playerData.name = name end  
		if class ~= nil then playerData.class = class end
		if type(level) == "number" then playerData.level = level end
		if race ~= nil then playerData.race = race end
		if guild ~= nil then playerData.guild = guild end
		if isEnemy ~= nil then playerData.isEnemy = isEnemy end
		if isGuess ~= nil then playerData.isGuess = isGuess end
	end
	if playerData.time == nil then
		playerData.time = time()
	end	
end

function Spy:RemovePlayerData(name)
	if name then
		SpyPerCharDB.PlayerData[name] = nil
	end
end

function Spy:AddFriendsData(name)
	SpyDB.FriendsData[name] = true
end

function Spy:PlayerIsFriend(name)
	return SpyDB.FriendsData[name]
end

function Spy:AddIgnoreData(name)
	SpyPerCharDB.IgnoreData[name] = true
end

function Spy:RemoveIgnoreData(name)
	if SpyPerCharDB.IgnoreData[name] then
		SpyPerCharDB.IgnoreData[name] = nil
	end
end

function Spy:AddKOSData(name)
	SpyPerCharDB.KOSData[name] = time()
	if Spy.db.profile.ShareKOSBetweenCharacters then 
		SpyDB.removeKOSData[Spy.RealmName][Spy.FactionName][name] = nil 
	end
end

function Spy:RemoveKOSData(name)
	if SpyPerCharDB.KOSData[name] then
		local playerData = SpyPerCharDB.PlayerData[name]
		if playerData and playerData.reason then playerData.reason = nil end
		SpyPerCharDB.KOSData[name] = nil
		if SpyPerCharDB.PlayerData[name] then
			SpyPerCharDB.PlayerData[name].kos = nil
		end
		if Spy.db.profile.ShareKOSBetweenCharacters then 
			SpyDB.removeKOSData[Spy.RealmName][Spy.FactionName][name] = time() 
		end
	end
end

function Spy:SetKOSReason(name, reason, other)
	local playerData = SpyPerCharDB.PlayerData[name]
	if playerData then
		if not reason then
			playerData.reason = nil
		else
			if not playerData.reason then playerData.reason = {} end
			if reason == L["KOSReasonOther"] then
				if not other then
					local dialog = StaticPopup_Show("Spy_SetKOSReasonOther", name)
					if dialog then dialog.playerName = name end
				else
					if other == "" then
						playerData.reason[L["KOSReasonOther"]] = nil
					else
						playerData.reason[L["KOSReasonOther"]] = other
					end
					Spy:RegenerateKOSCentralList(name)
				end
			else
				if playerData.reason[reason] then
					playerData.reason[reason] = nil
				else
					playerData.reason[reason] = true
				end
				Spy:RegenerateKOSCentralList(name)
			end
		end
	end
end

function Spy:AlertPlayer(player, source)
	if Spy:PlayerIsFriend(player) then
		return
	end
	local playerData = SpyPerCharDB.PlayerData[player]
	if SpyPerCharDB.KOSData[player] and Spy.db.profile.WarnOnKOS then
		--if Spy.db.profile.DisplayWarningsInErrorsFrame then
		if Spy.db.profile.DisplayWarnings == "ErrorFrame" then
			local text = Spy.db.profile.Colors.Warning["Warning Text"]
			local msg = L["KOSWarning"] .. player
			UIErrorsFrame:AddMessage(msg, text.r, text.g, text.b, 1.0, UIERRORS_HOLD_TIME)
		else
			if source ~= nil and source ~= Spy.CharacterName then
				Spy:ShowAlert("kosaway", player, source, Spy:GetPlayerLocation(playerData))
			else
				local reasonText = ""
				if playerData.reason then
					for reason in pairs(playerData.reason) do
						if reasonText ~= "" then reasonText = reasonText .. ", " end
						if reason == L["KOSReasonOther"] then
							reasonText = reasonText .. playerData.reason[reason]
						else
							reasonText = reasonText .. reason
						end
					end
				end
				Spy:ShowAlert("kos", player, nil, reasonText)
			end
		end
		if Spy.db.profile.EnableSound then
			if source ~= nil and source ~= Spy.CharacterName then
				PlaySoundFile("Interface\\AddOns\\Spy\\Sounds\\detected-kosaway.wav")
			else
				PlaySoundFile("Interface\\AddOns\\Spy\\Sounds\\detected-kos.wav")
			end
		end
		if Spy.db.profile.ShareKOSBetweenCharacters then Spy:RegenerateKOSCentralList(player) end
	elseif Spy.db.profile.WarnOnKOSGuild then
		if playerData and playerData.guild and Spy.KOSGuild[playerData.guild] then
			--if Spy.db.profile.DisplayWarningsInErrorsFrame then
			if Spy.db.profile.DisplayWarnings == "ErrorFrame" then
				local text = Spy.db.profile.Colors.Warning["Warning Text"]
				local msg = L["KOSGuildWarning"] .. "<" .. playerData.guild .. ">"
				UIErrorsFrame:AddMessage(msg, text.r, text.g, text.b, 1.0, UIERRORS_HOLD_TIME)
			else
				if source ~= nil and source ~= Spy.CharacterName then
					Spy:ShowAlert("kosguildaway", "<" .. playerData.guild .. ">", source, Spy:GetPlayerLocation(playerData))
				else
					Spy:ShowAlert("kosguild", "<" .. playerData.guild .. ">")
				end
			end
			if Spy.db.profile.EnableSound then
				if source ~= nil and source ~= Spy.CharacterName then
					PlaySoundFile("Interface\\AddOns\\Spy\\Sounds\\detected-kosaway.wav")
				else
					PlaySoundFile("Interface\\AddOns\\Spy\\Sounds\\detected-kosguild.wav")
				end
			end
		else
			if Spy.db.profile.EnableSound and not Spy.db.profile.OnlySoundKoS then
				if source == nil or source == Spy.CharacterName then
					if playerData and Spy.db.profile.WarnOnRace and playerData.race == Spy.db.profile.SelectWarnRace then --++
						PlaySoundFile("Interface\\AddOns\\Spy\\Sounds\\detected-race.wav") 
					else
						PlaySoundFile("Interface\\AddOns\\Spy\\Sounds\\detected-nearby.wav")
					end
				end
			end
		end
	elseif Spy.db.profile.EnableSound and not Spy.db.profile.OnlySoundKoS then
		if source == nil or source == Spy.CharacterName then
			if playerData and Spy.db.profile.WarnOnRace and playerData.race == Spy.db.profile.SelectWarnRace then --++
				PlaySoundFile("Interface\\AddOns\\Spy\\Sounds\\detected-race.wav") 
			else
				PlaySoundFile("Interface\\AddOns\\Spy\\Sounds\\detected-nearby.wav")
			end
		end
	end
end

function Spy:AlertStealthPlayer(player)
	if Spy.db.profile.WarnOnStealth then
		--if Spy.db.profile.DisplayWarningsInErrorsFrame then
		if Spy.db.profile.DisplayWarnings == "ErrorFrame" then
			local text = Spy.db.profile.Colors.Warning["Warning Text"]
			local msg = L["StealthWarning"] .. player
			UIErrorsFrame:AddMessage(msg, text.r, text.g, text.b, 1.0, UIERRORS_HOLD_TIME)
		else
			Spy:ShowAlert("stealth", player)
		end
		if Spy.db.profile.EnableSound then
			PlaySoundFile("Interface\\AddOns\\Spy\\Sounds\\detected-stealth.wav")
		end
	end
end

function Spy:AnnouncePlayer(player, channel)
	if not Spy_IgnoreList[player] then
		local msg = ""
		local isKOS = SpyPerCharDB.KOSData[player]
		local playerData = SpyPerCharDB.PlayerData[player]
		
		-- ✅ CRITICAL: Only announce if we have BOTH class AND level
		-- This is the final failsafe to prevent incomplete announcements
		-- Even if playerData exists, we need the essential info
		if not playerData or not playerData.class or playerData.level == nil then
			if Spy.db.profile.DebugMode then
				-- ✅ FIX: Correctly display level 0 (skull) instead of showing it as "nil"
				local classStr = playerData and playerData.class or "nil"
				local levelStr = (playerData and playerData.level ~= nil) and tostring(playerData.level) or "nil"
				DEFAULT_CHAT_FRAME:AddMessage("|cffff8800[Spy Announce]|r Skipped incomplete data for: " .. player .. 
					" (class=" .. classStr .. ", level=" .. levelStr .. ")")
			end
			return
		end

		local announce = Spy.db.profile.Announce
		if channel or announce == "Self" or announce == "LocalDefense" or
			(announce == "Guild" and GetGuildInfo("player") ~= nil and not Spy.InInstance) or
			(announce == "Party" and GetNumPartyMembers() > 0) or (announce == "Raid" and UnitInRaid("player")) then
			if announce == "Self" and not channel then
				if isKOS then
					msg = msg .. L["SpySignatureColored"] .. L["KillOnSightDetectedColored"] .. player .. " "
				else
					msg = msg .. L["SpySignatureColored"] .. L["PlayerDetectedColored"] .. player .. " "
				end
			else
				if isKOS then
					msg = msg .. L["KillOnSightDetected"] .. player .. " "
				else
					msg = msg .. L["PlayerDetected"] .. player .. " "
				end
			end
			if playerData then
				if playerData.guild and playerData.guild ~= "" then
					msg = msg .. "<" .. playerData.guild .. "> "
				end
				
				-- Details are guaranteed to exist (class + level) because of strict check above
				msg = msg .. "- "
				
				if playerData.level ~= nil then 
					local levelText = (playerData.level == 0) and "??" or playerData.level
					msg = msg .. L["Level"] .. " " .. levelText .. " " 
				end
				if playerData.race and playerData.race ~= "" then 
					msg = msg .. playerData.race .. " " 
				end
				if playerData.class and playerData.class ~= "" then
					if announce == "Self" and not channel then
						msg = msg .. L[playerData.class] .. " "
					else
						msg = msg .. upper(strsub(playerData.class, 1, 1)) .. lower(strsub(playerData.class, 2)) .. " "
					end
				end
				
				if playerData.zone then
					if playerData.subZone and playerData.subZone ~= "" and playerData.subZone ~= playerData.zone then
						msg = msg .. "- " .. playerData.subZone .. ", " .. playerData.zone
					else
						msg = msg .. "- " .. playerData.zone
					end
				end
				if playerData.mapX and playerData.mapY then msg = msg ..
						" (" .. math.floor(tonumber(playerData.mapX) * 100) .. "," .. math.floor(tonumber(playerData.mapY) * 100) .. ")"
				end
			end

			if channel then
				-- announce to selected channel
				if (channel == "PARTY" and GetNumPartyMembers() > 0) or (channel == "RAID" and UnitInRaid("player")) or
					(channel == "GUILD" and GetGuildInfo("player") ~= nil) then
					SendChatMessage(msg, channel)
				elseif channel == "LOCAL" then
					SendChatMessage(msg, "CHANNEL", nil, GetChannelName(L["LocalDefenseChannelName"] .. " - " .. GetZoneText()))
				end
			else
				-- announce to standard channel
				if isKOS or not Spy.db.profile.OnlyAnnounceKoS then
					if announce == "Self" then
						DEFAULT_CHAT_FRAME:AddMessage(msg)
					elseif announce == "LocalDefense" then
						SendChatMessage(msg, "CHANNEL", nil, GetChannelName(L["LocalDefenseChannelName"] .. " - " .. GetZoneText()))
					else
						SendChatMessage(msg, strupper(announce))
					end
				end
			end
		end

		-- announce to other Spy users
		if Spy.db.profile.ShareData then
			local class, level, race, zone, subZone, mapX, mapY, guild, guid = "", "", "", "", "", "", "", "", ""
			if playerData then
				if playerData.class then class = playerData.class end
				if playerData.level and playerData.isGuess == false then level = playerData.level end
				if playerData.race then race = playerData.race end
				if playerData.zone then zone = playerData.zone end
				if playerData.subZone then subZone = playerData.subZone end
				if playerData.mapX then mapX = playerData.mapX end
				if playerData.mapY then mapY = playerData.mapY end
				if playerData.guild then guild = playerData.guild end
				-- ✅ NEW: Include GUID if available (SuperWoW)
				if playerData.guid then guid = playerData.guid end
			end
			-- ✅ NEW: Append GUID to message (backwards compatible - old clients will ignore it)
			local details = Spy.Version ..
				"," .. player .. "," .. class .. "," .. level .. "," ..
				race .. "," .. zone .. "," .. subZone .. "," .. mapX .. "," .. mapY .. "," .. guild .. "," .. guid

			if strlen(details) < 240 then
				if channel then
					if (channel == "PARTY" and GetNumPartyMembers() > 0) or (channel == "RAID" and UnitInRaid("player")) or
						(channel == "GUILD" and GetGuildInfo("player") ~= nil) then
						Spy:SendCommMessage(Spy.Signature, details, channel)
					end
				else
					if GetNumPartyMembers() > 0 then 
						Spy:SendCommMessage(Spy.Signature, details, "PARTY") 
					end
					if UnitInRaid("player") then 
						Spy:SendCommMessage(Spy.Signature, details, "RAID") 
					end
					if Spy.InInstance == false and GetGuildInfo("player") ~= nil then 
						Spy:SendCommMessage(Spy.Signature, details, "GUILD") 
					end
				end
			end
		end
	end
end

function Spy:SendKoStoGuild(player)
	local playerData = SpyPerCharDB.PlayerData[player]
	local class, level, race, zone, subZone, mapX, mapY, guild, mapID = "", "", "", "", "", "", "", "", ""	 			
	if playerData then
		if playerData.class then class = playerData.class end
		if playerData.level and playerData.isGuess == false then level = playerData.level end
		if playerData.race then race = playerData.race end
		if playerData.zone then zone = playerData.zone end
		if playerData.mapID then mapID = playerData.mapID end
		if playerData.subZone then subZone = playerData.subZone end
		if playerData.mapX then mapX = playerData.mapX end
		if playerData.mapY then mapY = playerData.mapY end
		if playerData.guild then guild = playerData.guild end
	end
	local details = Spy.Version..","..player..","..class..","..level..","..race..","..zone..","..subZone..","..mapX..","..mapY..","..guild..","..mapID
	if strlen(details) < 240 then
		if Spy.InInstance == false and GetGuildInfo("player") ~= nil then
			Spy:SendCommMessage(Spy.Signature, details, "GUILD")
		end
	end
end

function Spy:ToggleIgnorePlayer(ignore, player)
	if ignore then
		Spy:AddIgnoreData(player)
		Spy:RemoveKOSData(player)
		if Spy.db.profile.EnableSound then
			PlaySoundFile("Interface\\AddOns\\Spy\\Sounds\\list-add.wav")
		end
		DEFAULT_CHAT_FRAME:AddMessage(L["SpySignatureColored"] .. L["PlayerAddedToIgnoreColored"] .. player)
	else
		Spy:RemoveIgnoreData(player)
		if Spy.db.profile.EnableSound then
			PlaySoundFile("Interface\\AddOns\\Spy\\Sounds\\list-remove.wav")
		end
		DEFAULT_CHAT_FRAME:AddMessage(L["SpySignatureColored"] .. L["PlayerRemovedFromIgnoreColored"] .. player)
	end
	Spy:RegenerateKOSGuildList()
	if Spy.db.profile.ShareKOSBetweenCharacters then Spy:RegenerateKOSCentralList() end
	Spy:RefreshCurrentList()
end

function Spy:ToggleKOSPlayer(kos, player)
	if kos then
		Spy:AddKOSData(player)
		Spy:RemoveIgnoreData(player)
		if player ~= SpyPerCharDB.PlayerData[name] then --????
			--Spy:UpdatePlayerData(player, nil, nil, nil, nil, true, nil)
			Spy:UpdatePlayerStatus(player, nil, nil, nil, nil, true, nil)
			SpyPerCharDB.PlayerData[player].kos = 1
		end
		if Spy.db.profile.EnableSound then
			PlaySoundFile("Interface\\AddOns\\Spy\\Sounds\\list-add.wav")
		end
		DEFAULT_CHAT_FRAME:AddMessage(L["SpySignatureColored"] .. L["PlayerAddedToKOSColored"] .. player)
	else
		Spy:RemoveKOSData(player)
		if Spy.db.profile.EnableSound then
			PlaySoundFile("Interface\\AddOns\\Spy\\Sounds\\list-remove.wav")
		end
		DEFAULT_CHAT_FRAME:AddMessage(L["SpySignatureColored"] .. L["PlayerRemovedFromKOSColored"] .. player)
	end
	Spy:RegenerateKOSGuildList()
	if Spy.db.profile.ShareKOSBetweenCharacters then Spy:RegenerateKOSCentralList() end
	Spy:RefreshCurrentList()
end

function Spy:PurgeUndetectedData()
	local secondsPerDay = 60 * 60 * 24
	local timeout = 90 * secondsPerDay
	if Spy.db.profile.PurgeData == "OneDay" then
		timeout = secondsPerDay
	elseif Spy.db.profile.PurgeData == "FiveDays" then
		timeout = 5 * secondsPerDay
	elseif Spy.db.profile.PurgeData == "TenDays" then
		timeout = 10 * secondsPerDay
	elseif Spy.db.profile.PurgeData == "ThirtyDays" then
		timeout = 30 * secondsPerDay
	elseif Spy.db.profile.PurgeData == "SixtyDays" then
		timeout = 60 * secondsPerDay
	elseif Spy.db.profile.PurgeData == "NinetyDays" then
		timeout = 90 * secondsPerDay
	end

	-- remove expired players held in character data
	local currentTime = time()
	for player in pairs(SpyPerCharDB.PlayerData) do
		local playerData = SpyPerCharDB.PlayerData[player]
		if Spy.db.profile.PurgeWinLossData then 
			if not playerData.time or (currentTime - playerData.time) > timeout or not playerData.isEnemy then
				Spy:RemoveIgnoreData(player)
				Spy:RemoveKOSData(player)
				SpyPerCharDB.PlayerData[player] = nil
			end
		else
			if ((playerData.loses == nil) and (playerData.wins == nil)) then 
				if not playerData.time or (currentTime - playerData.time) > timeout or not playerData.isEnemy then
					Spy:RemoveIgnoreData(player)
					if Spy.db.profile.PurgeKoS then 
						Spy:RemoveKOSData(player)
						SpyPerCharDB.PlayerData[player] = nil
					else
						SpyPerCharDB.PlayerData[player] = nil 
					end
				end
			end
		end
	end

	-- remove expired kos players held in central data
	local kosData = SpyDB.kosData[Spy.RealmName][Spy.FactionName]
	for characterName in pairs(kosData) do
		local characterKosData = kosData[characterName]
		for player in pairs(characterKosData) do
			local kosPlayerData = characterKosData[player]
			if Spy.db.profile.PurgeKoS then
				if not kosPlayerData.time or (currentTime - kosPlayerData.time) > timeout or not kosPlayerData.isEnemy then
					SpyDB.kosData[Spy.RealmName][Spy.FactionName][characterName][player] = nil
					SpyDB.removeKOSData[Spy.RealmName][Spy.FactionName][player] = nil
				end
			end
		end
	end
	if not Spy.db.profile.AppendUnitNameCheck then
		Spy:AppendUnitNames()
	end
	if not Spy.db.profile.AppendUnitKoSCheck then
		Spy:AppendUnitKoS()
	end
end

function Spy:RegenerateKOSGuildList()
	Spy.KOSGuild = {}
	for player in pairs(SpyPerCharDB.KOSData) do
		local playerData = SpyPerCharDB.PlayerData[player]
		if playerData and playerData.guild then
			Spy.KOSGuild[playerData.guild] = true
		end
	end
end

function Spy:RemoveLocalKOSPlayers()
	for player in pairs(SpyPerCharDB.KOSData) do
		if SpyDB.removeKOSData[Spy.RealmName][Spy.FactionName][player] then
			Spy:RemoveKOSData(player)
		end
	end
end

function Spy:RegenerateKOSCentralList(player)
	if player then
		local playerData = SpyPerCharDB.PlayerData[player]
		SpyDB.kosData[Spy.RealmName][Spy.FactionName][Spy.CharacterName][player] = {}
		if playerData then 
			SpyDB.kosData[Spy.RealmName][Spy.FactionName][Spy.CharacterName][player] = playerData 
		end
		SpyDB.kosData[Spy.RealmName][Spy.FactionName][Spy.CharacterName][player].added = SpyPerCharDB.KOSData[player]
	else
		for player in pairs(SpyPerCharDB.KOSData) do
			local playerData = SpyPerCharDB.PlayerData[player]
			SpyDB.kosData[Spy.RealmName][Spy.FactionName][Spy.CharacterName][player] = {}
			if playerData then 
				SpyDB.kosData[Spy.RealmName][Spy.FactionName][Spy.CharacterName][player] = playerData 
			end
			SpyDB.kosData[Spy.RealmName][Spy.FactionName][Spy.CharacterName][player].added = SpyPerCharDB.KOSData[player]
		end
	end
end

function Spy:RegenerateKOSListFromCentral()
	local kosData = SpyDB.kosData[Spy.RealmName][Spy.FactionName]
	for characterName in pairs(kosData) do
		if characterName ~= Spy.CharacterName then
			local characterKosData = kosData[characterName]
			for player in pairs(characterKosData) do
				if not SpyDB.removeKOSData[Spy.RealmName][Spy.FactionName][player] then
					local playerData = SpyPerCharDB.PlayerData[player]
					if not playerData then
						playerData = Spy:AddPlayerData(player, class, level, race, guild, isEnemy, isGuess)
					end
					local kosPlayerData = characterKosData[player]
					if kosPlayerData.time and (not playerData.time or (playerData.time and playerData.time < kosPlayerData.time)) then
						playerData.time = kosPlayerData.time
						if kosPlayerData.class then playerData.class = kosPlayerData.class end
						if type(kosPlayerData.level) == "number" and
							(type(playerData.level) ~= "number" or playerData.level < kosPlayerData.level) then playerData.level = kosPlayerData
							.level end
						if kosPlayerData.race then playerData.race = kosPlayerData.race end
						if kosPlayerData.guild then playerData.guild = kosPlayerData.guild end
						if kosPlayerData.isEnemy then playerData.isEnemy = kosPlayerData.isEnemy end
						if kosPlayerData.isGuess then playerData.isGuess = kosPlayerData.isGuess end
						if type(kosPlayerData.wins) == "number" and
							(type(playerData.wins) ~= "number" or playerData.wins < kosPlayerData.wins) then playerData.wins = kosPlayerData.wins end
						if type(kosPlayerData.loses) == "number" and
							(type(playerData.loses) ~= "number" or playerData.loses < kosPlayerData.loses) then playerData.loses = kosPlayerData
							.loses end
						if kosPlayerData.mapX then playerData.mapX = kosPlayerData.mapX end
						if kosPlayerData.mapY then playerData.mapY = kosPlayerData.mapY end
						if kosPlayerData.zone then playerData.zone = kosPlayerData.zone end
						if kosPlayerData.subZone then playerData.subZone = kosPlayerData.subZone end
						if kosPlayerData.reason then
							playerData.reason = {}
							for reason in pairs(kosPlayerData.reason) do
								playerData.reason[reason] = kosPlayerData.reason[reason]
							end
						end
					end
					local characterKOSPlayerData = SpyPerCharDB.KOSData[player]
					if kosPlayerData.added and (not characterKOSPlayerData or characterKOSPlayerData < kosPlayerData.added) then
						SpyPerCharDB.KOSData[player] = kosPlayerData.added
					end
				end
			end
		end
	end
end

function Spy:ParseMinimapTooltip(tooltip)
	local newTooltip = ""
	local newLine = false
	for text in strgfind(tooltip, "[^\n]*") do
		local name = text
		if strlen(text) > 0 then
			if strsub(text, 1, 2) == "|c" then
				name = strsub(text, 11, -3)
			end
			local playerData = SpyPerCharDB.PlayerData[name]
			if not playerData then
				for index, _ in pairs(Spy.LastHourList) do
					local realmSeparator = strfind(index, "-")
					if realmSeparator and realmSeparator > 1 and
						strsub(index, 1, realmSeparator - 1) == strsub(name, 1, realmSeparator - 1) then
						playerData = SpyPerCharDB.PlayerData[index]
						break
					end
				end
			end
			if playerData and playerData.isEnemy then
				local desc = ""
				if playerData.class and playerData.level then
					desc = L["MinimapClassText" .. playerData.class] .. "[" .. playerData.level .. " " .. L[playerData.class] .. "]|r"
				elseif playerData.class then
					desc = L["MinimapClassText" .. playerData.class] .. "[" .. L[playerData.class] .. "]|r"
				elseif playerData.level then
					desc = "[" .. playerData.level .. "]|r"
				end
				--				newTooltip = newTooltip..text.."|r "..desc
				if (newTooltip and desc == "") then
					newTooltip = text
				elseif (newTooltip == "") then
					newTooltip = text .. "|r" .. desc
				else
					newTooltip = newTooltip .. "\r" .. text .. "|r" .. desc
				end
				if not SpyPerCharDB.IgnoreData[name] and not Spy.InInstance then
					local detected = Spy:UpdatePlayerData(name, nil, nil, nil, nil, true, nil)
					if detected and Spy.db.profile.MinimapDetection then
						Spy:AddDetected(name, time(), false)
					end
				end
			else
				--				newTooltip = newTooltip..text.."|r"
				if (newTooltip == "") then
					newTooltip = text
				else
					newTooltip = newTooltip .. "\n" .. text
				end
			end
			newLine = false
		elseif not newLine then
			--			newTooltip = newTooltip.."\n"
			newTooltip = newTooltip
			newLine = true
		end
	end
	return newTooltip
end

function Spy:ParseUnitAbility(analyseSpell, event, player, spellName) --player, flags, spellId, spellName)
	local learnt = false
	if player and not Spy:PlayerIsFriend(player) then
		local class = nil
		local level = nil
		local race = nil
		local isEnemy = true
		local isGuess = true

		local playerData = SpyPerCharDB.PlayerData[player]
		if not playerData or playerData.isEnemy == nil then
			learnt = true
		end

		if analyseSpell then
			-- hit = { "source", "victim", "skill", "amount", "element", "isCrit", "isDOT", "isSplit" },
			-- buff = { "victim", "skill", "amountRank" },
			-- cast = { "source", "skill", "victim", "isBegin", "isPerform" },

			local ability = Spy_AbilityList[spellName]
			if ability then
				if ability.class and not (playerData and playerData.class) then
					class = ability.class
					learnt = true
				end
				if ability.level then
					local playerLevelNumber = nil
					if playerData and playerData.level then playerLevelNumber = tonumber(playerData.level) end
					if type(playerLevelNumber) ~= "number" or playerLevelNumber < ability.level then
						level = ability.level
						learnt = true
					end
				end
				if ability.race and not (playerData and playerData.race) then
					race = ability.race
					learnt = true
				end
			end
			if class and race and level == Spy.MaximumPlayerLevel then
				isGuess = false
				learnt = true
			end

		end

		Spy:UpdatePlayerData(player, class, level, race, nil, isEnemy, isGuess)
		return learnt, playerData
	end
	return learnt, nil
end

function Spy:AddDetected(player, timestamp, learnt, source)
	if Spy.db.profile.StopAlertsOnTaxi then
		if not UnitOnTaxi("player") then 
			Spy:AddDetectedToLists(player, timestamp, learnt, source)
		end
	else
		Spy:AddDetectedToLists(player, timestamp, learnt, source)
	end
end

function Spy:AddDetectedToLists(player, timestamp, learnt, source)
	if not Spy.NearbyList[player] then
		if Spy.db.profile.ShowOnDetection and not Spy.db.profile.MainWindowVis then
			Spy:SetCurrentList(1)
			Spy:EnableSpy(true, true, true)
		end
		if Spy.db.profile.CurrentList ~= 1 and Spy.db.profile.MainWindowVis and Spy.db.profile.ShowNearbyList then
			Spy:SetCurrentList(1)
		end

		-- ✅ CRITICAL: Store high-precision timestamp AND detection order for stable sorting
		Spy.DetectionTimestamp[player] = GetTime()
		
		-- ✅ CRITICAL: Set detection order immediately when player is first detected
		if not Spy.DetectionOrder[player] then
			Spy.DetectionOrderCounter = Spy.DetectionOrderCounter + 1
			Spy.DetectionOrder[player] = Spy.DetectionOrderCounter
		end
		
		if Spy.SortDebug then
			DEFAULT_CHAT_FRAME:AddMessage(string.format("|cffff00ff[AddDetected]|r NEW: %s at %.3f (order: %d)", player, Spy.DetectionTimestamp[player], Spy.DetectionOrder[player]))
		end
		
		if source and source ~= Spy.CharacterName and not Spy.ActiveList[player] then
			Spy.NearbyList[player] = timestamp
			Spy.LastHourList[player] = timestamp
			Spy.InactiveList[player] = timestamp
		else
			Spy.NearbyList[player] = timestamp
			Spy.LastHourList[player] = timestamp
			Spy.ActiveList[player] = timestamp
			Spy.InactiveList[player] = nil
			Spy:UpdateActiveCount()
		end

		if Spy.db.profile.CurrentList == 1 then
			Spy:RefreshCurrentList(player, source)
		else
			if not source or source ~= Spy.CharacterName then
				Spy:AlertPlayer(player, source)
				if not source then Spy:AnnouncePlayer(player) end
			end
		end
	elseif not Spy.ActiveList[player] then
		-- ✅ Player is in NearbyList but NOT in ActiveList (was inactive/grayed out)
		-- This happens when player was out of range for >10s (inactive) but still in Nearby
		-- Now they're back in range, so we move them from inactive to active
		
		if Spy.db.profile.ShowOnDetection and not Spy.db.profile.MainWindowVis then
			Spy:SetCurrentList(1)
			Spy:EnableSpy(true, true, true)
		end
		if Spy.db.profile.CurrentList ~= 1 and Spy.db.profile.MainWindowVis and Spy.db.profile.ShowNearbyList then
			Spy:SetCurrentList(1)
		end

		-- ✅ FIX: DON'T update DetectionTimestamp on reactivation
		-- Keep original detection time so player maintains position in list
		-- DetectionTimestamp should only be set on BRAND NEW detection
		
		Spy.LastHourList[player] = timestamp
		Spy.ActiveList[player] = timestamp
		Spy.InactiveList[player] = nil
		Spy:UpdateActiveCount()

		-- ✅ ALWAYS refresh the UI to update opacity (grayed out -> active)
		if Spy.db.profile.CurrentList == 1 then
			-- Check if we got this from comm system (needs alert/announce)
			if Spy.PlayerCommList[player] ~= nil then
				Spy:RefreshCurrentList(player, source)
			else
				-- Got it from direct detection (SuperWoW) - just refresh without alert
				Spy:RefreshCurrentList()
			end
		else
			-- We're not in Nearby list view, but still need to alert if from comm
			if Spy.PlayerCommList[player] ~= nil then
				if not source or source ~= Spy.CharacterName then
					Spy:AlertPlayer(player, source)
					if not source then Spy:AnnouncePlayer(player) end
				end
			end
		end
	else
		-- ✅ FIX: Update timestamps for players already in all lists
		-- Player is ALREADY in ActiveList AND in NearbyList
		-- This happens when:
		-- 1. Player was detected, went out of range (stayed in Nearby due to timeout)
		-- 2. Player came back into range and was detected again
		-- 3. SuperWoW scans them continuously while in range
		
		-- ✅ FIX: DON'T update DetectionTimestamp here - it should only be set on NEW detection
		-- Updating it here causes players to "jump around" in the list on HP updates
		
		Spy.NearbyList[player] = timestamp
		Spy.ActiveList[player] = timestamp
		Spy.LastHourList[player] = timestamp
		Spy:UpdateActiveCount()
		
		-- ✅ CRITICAL FIX: Always refresh the UI when in Nearby list mode
		-- Even if no new information was learned (learnt == false)
		-- This ensures the player shows as "active" (not grayed out) immediately
		-- when they come back into range
		if Spy.db.profile.CurrentList == 1 then
			Spy:RefreshCurrentList()
		end
	end
end

function Spy:AppendUnitNames()
	for key, unit in pairs(SpyPerCharDB.PlayerData) do
		-- find any units without a name
		if not unit.name then
			local name = key
			-- if unit.name does not exist update info
			if (not unit.name) and name then
				unit.name = key
			end
		end
	end
	Spy.db.profile.AppendUnitNameCheck = true --sets profile so it only runs once
end

function Spy:AppendUnitKoS()
	for kosName, value in pairs(SpyPerCharDB.KOSData) do
		if kosName then
			local playerData = SpyPerCharDB.PlayerData[kosName]
			if not playerData then
				Spy:UpdatePlayerData(kosName, nil, nil, nil, nil, true, nil)
				SpyPerCharDB.PlayerData[kosName].kos = 1
				SpyPerCharDB.PlayerData[kosName].time = value
			end
		end
	end
	Spy.db.profile.AppendUnitKoSCheck = true --sets profile so it only runs once
end

Spy.ListTypes = {
	{ L["Nearby"], Spy.ManageNearbyList, Spy.ManageNearbyListExpirations },
	{ L["LastHour"], Spy.ManageLastHourList, Spy.ManageLastHourListExpirations },
	{ L["Ignore"], Spy.ManageIgnoreList },
	{ L["KillOnSight"], Spy.ManageKillOnSightList },
}