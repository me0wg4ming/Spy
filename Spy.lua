local SM = LibStub:GetLibrary("LibSharedMedia-3.0")
local AceLocale = LibStub("AceLocale-3.0")
local L = AceLocale:GetLocale("Spy")
local ACD3 = LibStub("AceConfigDialog-3.0")
local AceCore = LibStub("AceCore-3.0")
local fonts = SM:List("font")

local LDB = LibStub("LibDataBroker-1.1", true)
local ldbIcon = LibStub("LibDBIcon-1.0", true)

local strsplit, strtrim = AceCore.strsplit, AceCore.strtrim
local format, strfind, strsub, find = string.format, string.find, string.sub, string.find

Spy = LibStub("AceAddon-3.0"):NewAddon("Spy", "AceConsole-3.0", "AceEvent-3.0", "AceComm-3.0", "AceTimer-3.0")
Spy.Version = "4.0.5"
Spy.DatabaseVersion = "1.1"
Spy.Signature = "[Spy]"
Spy.MaximumPlayerLevel = 60
-- Map note variables removed - map display feature removed
Spy.ZoneID = {}
Spy.KOSGuild = {}
Spy.CurrentList = {}
Spy.NearbyList = {}
Spy.LastHourList = {}
Spy.ActiveList = {}
Spy.InactiveList = {}
Spy.PlayerCommList = {}
Spy.ListAmountDisplayed = 0
Spy.ButtonName = {}
Spy.EnabledInZone = false
Spy.InInstance = false
Spy.AlertType = nil
Spy.UpgradeMessageSent = false
Spy.initTimer = ""
Spy.Skull = -1
Spy.WorldMapInitialized = false  -- ✅ FIX: Track if WorldMap has been initialized

-- ============================================================================
-- PET DETECTION - Prevents pets from being detected as players
-- ============================================================================

Spy.DebugPets = false

function Spy:IsPet(unitId)
	if not unitId or not UnitExists(unitId) then return nil end
	if UnitIsPlayer(unitId) then return false end
	if UnitPlayerControlled(unitId) then return true end
	if UnitCreatureType(unitId) then return true end
	return nil
end

function Spy:ValidatePlayerNotPet(name, guid)
	if not name then return nil end
	if guid and UnitExists(guid) then
		local isPet = self:IsPet(guid)
		if isPet == false then return true end
		if isPet == true then
			if self.DebugPets then
				DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[Spy]|r " .. name .. " is pet - BLOCKED")
			end
			return false
		end
	end
	for _, unit in ipairs({"target", "mouseover"}) do
		if UnitExists(unit) and UnitName(unit) == name then
			local isPet = self:IsPet(unit)
			if isPet ~= nil then
				if isPet and self.DebugPets then
					DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[Spy]|r " .. name .. " is pet - BLOCKED")
				end
				return not isPet
			end
		end
	end
	for i = 1, 40 do
		if UnitExists("raid"..i.."pet") and UnitName("raid"..i.."pet") == name then
			if self.DebugPets then
				DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[Spy]|r "..name.." is raid pet - BLOCKED")
			end
			return false
		end
	end
	for i = 1, 4 do
		if UnitExists("party"..i.."pet") and UnitName("party"..i.."pet") == name then
			if self.DebugPets then
				DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[Spy]|r "..name.." is party pet - BLOCKED")
			end
			return false
		end
	end
	if UnitExists("pet") and UnitName("pet") == name then
		if self.DebugPets then
			DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[Spy]|r " .. name .. " is your pet - BLOCKED")
		end
		return false
	end
	return nil
end

-- Localizations for xml
L_STATS = "Spy " .. L["Statistics"]
L_LIST = L["List"]
L_TIME = L["Time"]
L_FILTER = FILTER .. ":"
L_SHOWONLY = L["Show Only"] .. ":"

Spy.options = {
	name = L["Spy"],
	type = "group",
	args = {
		About = {
			name = L["About"],
			desc = L["About"],
			type = "group",
			order = 1,
			args = {
				intro1 = {
					name = L["SpyDescription1"],
					type = "description",
					order = 1,
					fontSize = "medium",
				},
				intro2 = {
					name = L["SpyDescription2"],
					type = "description",
					order = 2,
					fontSize = "medium",
				},
				intro3 = {
					name = L["SpyDescription3"],
					type = "description",
					order = 3,
					fontSize = "medium",
				},
			},
		},
		General = {
			name = L["GeneralSettings"],
			desc = L["GeneralSettings"],
			type = "group",
			order = 1,
			args = {
				intro = {
					name = L["GeneralSettingsDescription"],
					type = "description",
					order = 1,
					fontSize = "medium",
				},
				Enabled = {
					name = L["EnableSpy"],
					desc = L["EnableSpyDescription"],
					type = "toggle",
					order = 2,
					width = "full",
					get = function(info)
						return Spy.db.profile.Enabled
					end,
					set = function(info, value)
						Spy:EnableSpy(value, true)
					end,
				},
				EnabledInBattlegrounds = {
					name = L["EnabledInBattlegrounds"],
					desc = L["EnabledInBattlegroundsDescription"],
					type = "toggle",
					order = 2,
					width = "full",
					get = function(info)
						return Spy.db.profile.EnabledInBattlegrounds
					end,
					set = function(info, value)
						Spy.db.profile.EnabledInBattlegrounds = value
						Spy:ZoneChangedEvent()
					end,
				},
				DisableWhenPVPUnflagged = {
					name = L["DisableWhenPVPUnflagged"],
					desc = L["DisableWhenPVPUnflaggedDescription"],
					type = "toggle",
					order = 5,
					width = "full",
					get = function(info)
						return Spy.db.profile.DisableWhenPVPUnflagged
					end,
					set = function(info, value)
						Spy.db.profile.DisableWhenPVPUnflagged = value
						Spy:ZoneChangedEvent()
					end,
				},
				DisabledInZones = {
					name = L["DisabledInZones"],
					desc = L["DisabledInZonesDescription"],
					type = "multiselect",
					order = 6,
					get = function(info, key)
						return Spy.db.profile.FilteredZones[key]
					end,
					set = function(info, key, value)
						Spy.db.profile.FilteredZones[key] = value
						-- Update zone status immediately when settings change
						Spy:ZoneChangedEvent()
					end,
					values = {
						["Booty Bay"] = L["Booty Bay"],
						["Everlook"] = L["Everlook"],
						["Gadgetzan"] = L["Gadgetzan"],
						["Ratchet"] = L["Ratchet"],
						["Nordanaar"] = L["Nordanaar"],
						["Tel Co. Basecamp"] = L["Tel Co. Basecamp"],
					},
				},
				NearbySortOrder = {
					name = "Nearby Sort System",
					type = "group",
					order = 7,
					inline = true,
					args = {
						range = {
							name = "Range (closest first)",
							desc = "Sort by distance to player (requires SpyDistance)",
							type = "toggle",
							order = 1,
							width = "full",
							get = function(info)
								return Spy.db.profile.NearbySortOrder == "range"
							end,
							set = function(info, value)
								Spy.db.profile.NearbySortOrder = "range"
								Spy:RefreshCurrentList()
							end,
						},
						name = {
							name = "Names (alphabetical)",
							desc = "Sort by player name alphabetically",
							type = "toggle",
							order = 2,
							width = "full",
							get = function(info)
								return Spy.db.profile.NearbySortOrder == "name"
							end,
							set = function(info, value)
								Spy.db.profile.NearbySortOrder = "name"
								Spy:RefreshCurrentList()
							end,
						},
						class = {
							name = "Class (alphabetical)",
							desc = "Sort by class alphabetically",
							type = "toggle",
							order = 3,
							width = "full",
							get = function(info)
								return Spy.db.profile.NearbySortOrder == "class"
							end,
							set = function(info, value)
								Spy.db.profile.NearbySortOrder = "class"
								Spy:RefreshCurrentList()
							end,
						},
						time = {
							name = "Time Added (newest first)",
							desc = "Sort by detection time (newest first)",
							type = "toggle",
							order = 4,
							width = "full",
							get = function(info)
								return Spy.db.profile.NearbySortOrder == "time"
							end,
							set = function(info, value)
								Spy.db.profile.NearbySortOrder = "time"
								Spy:RefreshCurrentList()
							end,
						},
					},
				},
				ShowOnDetection = {
					name = L["ShowOnDetection"],
					desc = L["ShowOnDetectionDescription"],
					type = "toggle",
					order = 7,
					width = "full",
					get = function(info)
						return Spy.db.profile.ShowOnDetection
					end,
					set = function(info, value)
						Spy.db.profile.ShowOnDetection = value
					end,
				},
				HideSpy = {
					name = L["HideSpy"],
					desc = L["HideSpyDescription"],
					type = "toggle",
					order = 8,
					width = "full",
					get = function(info)
						return Spy.db.profile.HideSpy
					end,
					set = function(info, value)
						Spy.db.profile.HideSpy = value
						if Spy.db.profile.HideSpy and Spy:GetNearbyListSize() == 0 then
							Spy.MainWindow:Hide()
						end
					end,
				},
				-- ShowKoSButton option removed - doesn't work in Vanilla 1.12.1
				-- Target frame API not available, KOS button only works in Nearby list
			},
		},
		DisplayOptions = {
			name = L["DisplayOptions"],
			desc = L["DisplayOptions"],
			type = "group",
			order = 2,
			args = {
				intro = {
					name = L["DisplayOptionsDescription"],
					type = "description",
					order = 1,
					fontSize = "medium",
				},
				ShowNearbyList = {
					name = L["ShowNearbyList"],
					desc = L["ShowNearbyListDescription"],
					type = "toggle",
					order = 2,
					width = "full",
					get = function(info)
						return Spy.db.profile.ShowNearbyList
					end,
					set = function(info, value)
						Spy.db.profile.ShowNearbyList = value
					end,
				},
				PrioritiseKoS = {
					name = L["PrioritiseKoS"],
					desc = L["PrioritiseKoSDescription"],
					type = "toggle",
					order = 3,
					width = "full",
					get = function(info)
						return Spy.db.profile.PrioritiseKoS
					end,
					set = function(info, value)
						Spy.db.profile.PrioritiseKoS = value
					end,
				},
				Alpha = {
					name = L["Alpha"],
					desc = L["AlphaDescription"],
					type = "range",
					order = 4,
					width = "normal",
					min = 0, max = 1, step = 0.01,
					isPercent = true,
					get = function()
						return Spy.db.profile.MainWindow.Alpha
					end,
					set = function(info, value)
						Spy.db.profile.MainWindow.Alpha = value
						Spy:UpdateMainWindow()

					end,
				},
				AlphaBG = {
					name = L["AlphaBG"],
					desc = L["AlphaBGDescription"],
					type = "range",
					order = 5,
					width = "normal",
					min = 0, max = 1, step = 0.01,
					isPercent = true,
					get = function()
						return Spy.db.profile.MainWindow.AlphaBG
					end,
					set = function(info, value)
						Spy.db.profile.MainWindow.AlphaBG = value
						Spy:UpdateMainWindow()
					end,
				},
				Lock = {
					name = L["LockSpy"],
					desc = L["LockSpyDescription"],
					type = "toggle",
					order = 6,
					width = "normal",
					get = function(info)
						return Spy.db.profile.Locked
					end,
					set = function(info, value)
						Spy.db.profile.Locked = value
						Spy:LockWindows(value)
						Spy:RefreshCurrentList()
					end,
				},
				ClampToScreen = {
					name = L["ClampToScreen"],
					desc = L["ClampToScreenDescription"],
					type = "toggle",
					order = 7,
					width = "normal",
					get = function(info)
						return Spy.db.profile.ClampToScreen
					end,
					set = function(info, value)
						Spy.db.profile.ClampToScreen = value
						Spy:ClampToScreen(value)
					end,
					hidden = true, -- not working in Vanilla
				},
				InvertSpy = {
					name = L["InvertSpy"],
					desc = L["InvertSpyDescription"],
					type = "toggle",
					order = 8,
					width = "normal",
					get = function(info)
						return Spy.db.profile.InvertSpy
					end,
					set = function(info, value)
						Spy.db.profile.InvertSpy = value
					end,
				},
				[L["Reload"]] = {
					name = L["Reload"],
					desc = L["ReloadDescription"],
					type = 'execute',
					order = 9,
					width = "half",
					func = function()
						ReloadUI()
					end
				},
				ResizeSpy = {
					name = L["ResizeSpy"],
					desc = L["ResizeSpyDescription"],
					type = "toggle",
					order = 10,
					width = "full",
					get = function(info)
						return Spy.db.profile.ResizeSpy
					end,
					set = function(info, value)
						Spy.db.profile.ResizeSpy = value
						if value then Spy:RefreshCurrentList() end
					end,
				},
				ResizeSpyLimit = {
					type = "range",
					order = 11,
					name = L["ResizeSpyLimit"],
					desc = L["ResizeSpyLimitDescription"],
					min = 1, max = 15, step = 1,
					get = function() return Spy.db.profile.ResizeSpyLimit end,
					set = function(info, value)
						Spy.db.profile.ResizeSpyLimit = value
						if value then
							Spy:ResizeMainWindow()
							Spy:RefreshCurrentList()
						end
					end,
				},
				SelectFont = {
					type = "select",
					order = 13,
					name = L["SelectFont"],
					desc = L["SelectFontDescription"],
					dialogControl = "LSM30_Font",
					values = SM:HashTable("font"),
					get = function()
						return Spy.db.profile.Font
					end,
					set = function(_, value)
						--printT(value)
						Spy.db.profile.Font = value
						if value then
							Spy:UpdateBarTextures(nil, SM.MediaType.FONT, value)
						end
					end,
				},
				RowHeight = {
					type = "range",
					order = 14,
					name = L["RowHeight"],
					desc = L["RowHeightDescription"],
					min = 8, max = 20, step = 1,
					get = function()
						return Spy.db.profile.MainWindow.RowHeight
					end,
					set = function(info, value)
						Spy.db.profile.MainWindow.RowHeight = value
						if value then
							Spy:BarsChanged()
						end
					end,
				},
				BarTexture = {
					type = "select",
					order = 15,
					name = L["Texture"],
					desc = L["TextureDescription"],
					dialogControl = "LSM30_Statusbar",
					width = "double",
					values = SM:HashTable("statusbar"),
					get = function()
						return Spy.db.profile.BarTexture
					end,
					set = function(_, key)
						Spy.db.profile.BarTexture = key
						Spy:UpdateBarTextures(nil, SM.MediaType.STATUSBAR, key)
					end,
				},
				DisplayTooltipNearSpyWindow = {
					name = L["DisplayTooltipNearSpyWindow"],
					desc = L["DisplayTooltipNearSpyWindowDescription"],
					type = "toggle",
					order = 16,
					width = "full",
					get = function(info)
						return Spy.db.profile.DisplayTooltipNearSpyWindow
					end,
					set = function(info, value)
						Spy.db.profile.DisplayTooltipNearSpyWindow = value
					end,
				},
				SelectTooltipAnchor = {
					type = "select",
					order = 17,
					name = L["SelectTooltipAnchor"],
					desc = L["SelectTooltipAnchorDescription"],
					values = {
						["ANCHOR_CURSOR"] = L["ANCHOR_CURSOR"],
						["ANCHOR_TOP"] = L["ANCHOR_TOP"],
						["ANCHOR_BOTTOM"] = L["ANCHOR_BOTTOM"],
						["ANCHOR_LEFT"] = L["ANCHOR_LEFT"],
						["ANCHOR_RIGHT"] = L["ANCHOR_RIGHT"],
					},
					get = function()
						return Spy.db.profile.TooltipAnchor
					end,
					set = function(info, value)
						Spy.db.profile.TooltipAnchor = value
					end,
				},
				DisplayWinLossStatistics = {
					name = L["TooltipDisplayWinLoss"],
					desc = L["TooltipDisplayWinLossDescription"],
					type = "toggle",
					order = 18,
					width = "full",
					get = function(info)
						return Spy.db.profile.DisplayWinLossStatistics
					end,
					set = function(info, value)
						Spy.db.profile.DisplayWinLossStatistics = value
					end,
				},
				DisplayKOSReason = {
					name = L["TooltipDisplayKOSReason"],
					desc = L["TooltipDisplayKOSReasonDescription"],
					type = "toggle",
					order = 19,
					width = "full",
					get = function(info)
						return Spy.db.profile.DisplayKOSReason
					end,
					set = function(info, value)
						Spy.db.profile.DisplayKOSReason = value
					end,
				},
				DisplayLastSeen = {
					name = L["TooltipDisplayLastSeen"],
					desc = L["TooltipDisplayLastSeenDescription"],
					type = "toggle",
					order = 20,
					width = "full",
					get = function(info)
						return Spy.db.profile.DisplayLastSeen
					end,
					set = function(info, value)
						Spy.db.profile.DisplayLastSeen = value
					end,
				},
			},
		},
		AlertOptions = {
			name = L["AlertOptions"],
			desc = L["AlertOptions"],
			type = "group",
			order = 3,
			args = {
				intro = {
					name = L["AlertOptionsDescription"],
					type = "description",
					order = 1,
				},
				EnableSound = {
					name = L["EnableSound"],
					desc = L["EnableSoundDescription"],
					type = "toggle",
					order = 2,
					width = "full",
					get = function(info)
						return Spy.db.profile.EnableSound
					end,
					set = function(info, value)
						Spy.db.profile.EnableSound = value
					end,
				},
				SoundChannel = {
					name = L["SoundChannel"],
					type = 'select',
					order = 3,
					values = {
						["Master"] = L["Master"],
						["SFX"] = L["SFX"],
						["Music"] = L["Music"],
						["Ambience"] = L["Ambience"],
					},
					get = function()
						return Spy.db.profile.SoundChannel
					end,
					set = function(info, value)
						Spy.db.profile.SoundChannel = value
					end,
				},
				OnlySoundKoS = {
					name = L["OnlySoundKoS"],
					desc = L["OnlySoundKoSDescription"],
					type = "toggle",
					order = 4,
					width = "full",
					get = function(info)
						return Spy.db.profile.OnlySoundKoS
					end,
					set = function(info, value)
						Spy.db.profile.OnlySoundKoS = value
					end,
				},
				StopAlertsOnTaxi = {
					name = L["StopAlertsOnTaxi"],
					desc = L["StopAlertsOnTaxiDescription"],
					type = "toggle",
					order = 5,
					width = "full",
					get = function(info)
						return Spy.db.profile.StopAlertsOnTaxi
					end,
					set = function(info, value)
						Spy.db.profile.StopAlertsOnTaxi = value
					end,
				},
				Announce = {
					name = L["Announce"],
					type = "group",
					order = 6,
					inline = true,
					args = {
						None = {
							name = L["None"],
							desc = L["NoneDescription"],
							type = "toggle",
							order = 1,
							get = function(info)
								return Spy.db.profile.Announce == "None"
							end,
							set = function(info, value)
								Spy.db.profile.Announce = "None"
							end,
						},
						Self = {
							name = L["Self"],
							desc = L["SelfDescription"],
							type = "toggle",
							order = 2,
							get = function(info)
								return Spy.db.profile.Announce == "Self"
							end,
							set = function(info, value)
								Spy.db.profile.Announce = "Self"
							end,
						},
						Party = {
							name = L["Party"],
							desc = L["PartyDescription"],
							type = "toggle",
							order = 3,
							get = function(info)
								return Spy.db.profile.Announce == "Party"
							end,
							set = function(info, value)
								Spy.db.profile.Announce = "Party"
							end,
						},
						Guild = {
							name = L["Guild"],
							desc = L["GuildDescription"],
							type = "toggle",
							order = 4,
							get = function(info)
								return Spy.db.profile.Announce == "Guild"
							end,
							set = function(info, value)
								Spy.db.profile.Announce = "Guild"
							end,
						},
						Raid = {
							name = L["Raid"],
							desc = L["RaidDescription"],
							type = "toggle",
							order = 5,
							get = function(info)
								return Spy.db.profile.Announce == "Raid"
							end,
							set = function(info, value)
								Spy.db.profile.Announce = "Raid"
							end,
						},
						LocalDefense = {
							name = L["LocalDefense"],
							desc = L["LocalDefenseDescription"],
							type = "toggle",
							order = 6,
							get = function(info)
								return Spy.db.profile.Announce == "LocalDefense"
							end,
							set = function(info, value)
								Spy.db.profile.Announce = "LocalDefense"
							end,
						},
					},
				},
				OnlyAnnounceKoS = {
					name = L["OnlyAnnounceKoS"],
					desc = L["OnlyAnnounceKoSDescription"],
					type = "toggle",
					order = 7,
					width = "full",
					get = function(info)
						return Spy.db.profile.OnlyAnnounceKoS
					end,
					set = function(info, value)
						Spy.db.profile.OnlyAnnounceKoS = value
					end,
				},
				DisplayWarnings = {
					name = L["DisplayWarnings"],
					type = 'select',
					order = 8,
					values = {
						["Default"] = L["Default"],
						["ErrorFrame"] = L["ErrorFrame"],
						["Moveable"] = L["Moveable"],
					},
					get = function()
						return Spy.db.profile.DisplayWarnings
					end,
					set = function(info, value)
						Spy.db.profile.DisplayWarnings = value
						Spy:UpdateAlertWindow()
					end,
				},
				WarnOnStealth = {
					name = L["WarnOnStealth"],
					desc = L["WarnOnStealthDescription"],
					type = "toggle",
					order = 9,
					width = "full",
					get = function(info)
						return Spy.db.profile.WarnOnStealth
					end,
					set = function(info, value)
						Spy.db.profile.WarnOnStealth = value
					end,
				},
				WarnOnStealthEvenIfDisabled = {
					name = "Warn even if Spy is disabled",
					desc = "Continue detecting stealthed players (Rogues, Druids, Night Elves using Stealth/Prowl/Shadowmeld) even when Spy is disabled. Players will be tracked in the database but NOT shown in the Nearby list. Only stealth alerts will be shown.",
					type = "toggle",
					order = 9.5,
					width = "full",
					get = function(info)
						return Spy.db.profile.WarnOnStealthEvenIfDisabled
					end,
					set = function(info, value)
						Spy.db.profile.WarnOnStealthEvenIfDisabled = value
					end,
				},
				WarnOnKOS = {
					name = L["WarnOnKOS"],
					desc = L["WarnOnKOSDescription"],
					type = "toggle",
					order = 10,
					width = "full",
					get = function(info)
						return Spy.db.profile.WarnOnKOS
					end,
					set = function(info, value)
						Spy.db.profile.WarnOnKOS = value
					end,
				},
				WarnOnKOSGuild = {
					name = L["WarnOnKOSGuild"],
					desc = L["WarnOnKOSGuildDescription"],
					type = "toggle",
					order = 11,
					width = "full",
					get = function(info)
						return Spy.db.profile.WarnOnKOSGuild
					end,
					set = function(info, value)
						Spy.db.profile.WarnOnKOSGuild = value
					end,
				},
				WarnOnRace = {
					name = L["WarnOnRace"],
					desc = L["WarnOnRaceDescription"],
					type = "toggle",
					order = 12,
					width = "full",
					get = function(info)
						return Spy.db.profile.WarnOnRace
					end,
					set = function(info, value)
						Spy.db.profile.WarnOnRace = value
					end,
				},
				SelectWarnRace = {
					type = "select",
					order = 13,
					name = L["SelectWarnRace"],
					desc = L["SelectWarnRaceDescription"],
					get = function()
						return Spy.db.profile.SelectWarnRace
					end,
					set = function(info, value)
						Spy.db.profile.SelectWarnRace = value
					end,
					values = function()
						local raceOptions = {}
						local races = {
							Alliance = {
								["None"] = L["None"],
								["Human"] = L["Human"],
								["Dwarf"] = L["Dwarf"],
								["Night Elf"] = L["Night Elf"],
								["Gnome"] = L["Gnome"],
								["High Elf"] = L["High Elf"],
							},
							Horde = {
								["None"] = L["None"],
								["Orc"] = L["Orc"],
								["Tauren"] = L["Tauren"],
								["Troll"] = L["Troll"],
								["Undead"] = L["Undead"],
								["Goblin"] = L["Goblin"],
							},
						}
						if Spy.EnemyFactionName == "Alliance" then
							raceOptions = races.Alliance
						end
						if Spy.EnemyFactionName == "Horde" then
							raceOptions = races.Horde
						end
						return raceOptions
					end,
				},
				WarnRaceNote = {
					order = 14,
					type = "description",
					name = L["WarnRaceNote"],
				},
			},
		},
		MapOptions = {
			name = L["MapOptions"],
			desc = L["MapOptions"],
			type = "group",
			order = 4,
			args = {
				intro = {
					name = L["MapOptionsDescription"],
					type = "description",
					order = 1,
					fontSize = "medium",
				},
				MinimapDetection = {
					name = L["MinimapDetection"],
					desc = L["MinimapDetectionDescription"],
					type = "toggle",
					order = 2,
					width = "full",
					get = function(info)
						return Spy.db.profile.MinimapDetection
					end,
					set = function(info, value)
						Spy.db.profile.MinimapDetection = value
					end,
				},
				MinimapNote = {
					order = 3,
					type = "description",
					name = L["MinimapNote"],
				},
				MinimapDetails = {
					name = L["MinimapDetails"],
					desc = L["MinimapDetailsDescription"],
					type = "toggle",
					order = 4,
					width = "full",
					get = function(info)
						return Spy.db.profile.MinimapDetails
					end,
					set = function(info, value)
						Spy.db.profile.MinimapDetails = value
					end,
				},
				-- Map display options removed - don't work in Vanilla for solo players
				-- Only useful with data sharing between multiple Spy users
			},
		},
		DataOptions = {
			name = L["DataOptions"],
			desc = L["DataOptions"],
			type = "group",
			order = 5,
			args = {
				intro = {
					name = L["ListOptionsDescription"],
					type = "description",
					order = 1,
					fontSize = "medium",
				},
				RemoveUndetected = {
					name = function()
						local val = Spy.db.profile.RemoveUndetectedTime or 1
						if val >= 121 then
							return L["RemoveUndetected"] .. ": |cffff0000" .. L["Always"] .. "|r"
						else
							return L["RemoveUndetected"] .. ": |cffffff00" .. val .. " " .. L["Minutes"] .. "|r"
						end
					end,
					desc = L["RemoveUndetectedDescription"],
					type = "range",
					order = 2,
					width = "full",
					min = 1,
					max = 121,
					step = 1,
					get = function(info)
						return Spy.db.profile.RemoveUndetectedTime or 1
					end,
					set = function(info, value)
						Spy.db.profile.RemoveUndetectedTime = value
						Spy:UpdateTimeoutSettings()
					end,
				},
				PurgeData = {
					name = L["PurgeData"],
					type = "group",
					order = 7,
					inline = true,
					args = {
						OneDay = {
							name = L["OneDay"],
							desc = L["OneDayDescription"],
							type = "toggle",
							order = 1,
							get = function(info)
								return Spy.db.profile.PurgeData == "OneDay"
							end,
							set = function(info, value)
								Spy.db.profile.PurgeData = "OneDay"
							end,
						},
						FiveDays = {
							name = L["FiveDays"],
							desc = L["FiveDaysDescription"],
							type = "toggle",
							order = 2,
							get = function(info)
								return Spy.db.profile.PurgeData == "FiveDays"
							end,
							set = function(info, value)
								Spy.db.profile.PurgeData = "FiveDays"
							end,
						},
						TenDays = {
							name = L["TenDays"],
							desc = L["TenDaysDescription"],
							type = "toggle",
							order = 3,
							get = function(info)
								return Spy.db.profile.PurgeData == "TenDays"
							end,
							set = function(info, value)
								Spy.db.profile.PurgeData = "TenDays"
							end,
						},
						ThirtyDays = {
							name = L["ThirtyDays"],
							desc = L["ThirtyDaysDescription"],
							type = "toggle",
							order = 4,
							get = function(info)
								return Spy.db.profile.PurgeData == "ThirtyDays"
							end,
							set = function(info, value)
								Spy.db.profile.PurgeData = "ThirtyDays"
							end,
						},
						SixtyDays = {
							name = L["SixtyDays"],
							desc = L["SixtyDaysDescription"],
							type = "toggle",
							order = 5,
							get = function(info)
								return Spy.db.profile.PurgeData == "SixtyDays"
							end,
							set = function(info, value)
								Spy.db.profile.PurgeData = "SixtyDays"
							end,
						},
						NinetyDays = {
							name = L["NinetyDays"],
							desc = L["NinetyDaysDescription"],
							type = "toggle",
							order = 6,
							get = function(info)
								return Spy.db.profile.PurgeData == "NinetyDays"
							end,
							set = function(info, value)
								Spy.db.profile.PurgeData = "NinetyDays"
							end,
						},
					},
				},
				PurgeKoS = {
					name = L["PurgeKoS"],
					desc = L["PurgeKoSDescription"],
					type = "toggle",
					order = 8,
					width = "full",
					get = function(info)
						return Spy.db.profile.PurgeKoS
					end,
					set = function(info, value)
						Spy.db.profile.PurgeKoS = value
					end,
				},
				PurgeWinLossData = {
					name = L["PurgeWinLossData"],
					desc = L["PurgeWinLossDataDescription"],
					type = "toggle",
					order = 9,
					width = "full",
					get = function(info)
						return Spy.db.profile.PurgeWinLossData
					end,
					set = function(info, value)
						Spy.db.profile.PurgeWinLossData = value
					end,
				},
				ShareData = {
					name = L["ShareData"],
					desc = L["ShareDataDescription"],
					type = "toggle",
					order = 10,
					width = "full",
					get = function(info)
						return Spy.db.profile.ShareData
					end,
					set = function(info, value)
						Spy.db.profile.ShareData = value
					end,
				},
				UseData = {
					name = L["UseData"],
					desc = L["UseDataDescription"],
					type = "toggle",
					order = 11,
					width = "full",
					get = function(info)
						return Spy.db.profile.UseData
					end,
					set = function(info, value)
						Spy.db.profile.UseData = value
					end,
				},
				ShareKOSBetweenCharacters = {
					name = L["ShareKOSBetweenCharacters"],
					desc = L["ShareKOSBetweenCharactersDescription"],
					type = "toggle",
					order = 12,
					width = "full",
					get = function(info)
						return Spy.db.profile.ShareKOSBetweenCharacters
					end,
					set = function(info, value)
						Spy.db.profile.ShareKOSBetweenCharacters = value
						if value then Spy:RegenerateKOSCentralList() end
					end,
				},

			},
		},
	},
}

Spy.optionsSlash = {
	name = L["SlashCommand"],
	order = -3,
	type = "group",
	dialogHidden = true,
	args = {
		intro = {
			name = L["SpySlashDescription"],
			type = "description",
			order = 1,
			cmdHidden = true,
		},
		show = {
			name = L["Show"],
			desc = L["ShowDescription"],
			type = 'execute',
			order = 2,
			func = function()
				Spy:EnableSpy(true, true)
			end,
			dialogHidden = true
		},
		hide = {
			name = L["Hide"],
			desc = L["HideDescription"],
			type = 'execute',
			order = 3,
			func = function()
				Spy:EnableSpy(false, true)
			end,
			dialogHidden = true
		},
		reset = {
			name = L["Reset"],
			desc = L["ResetDescription"],
			type = 'execute',
			order = 4,
			func = function()
				Spy:ResetPositions()
			end,
			dialogHidden = true
		},
		clear = {
			name = L["ClearSlash"],
			desc = L["ClearSlashDescription"],
			type = 'execute',
			order = 5,
			func = function()
				Spy:ClearList()
			end,
			dialogHidden = true
		},
		config = {
			name = L["Config"],
			desc = L["ConfigDescription"],
			type = 'execute',
			order = 6,
			func = function()
				Spy:ShowConfig()
			end,
			dialogHidden = true
		},
		kos = {
			name = L["KOS"],
			desc = L["KOSDescription"],
			type = 'input',
			order = 7,
			pattern = ".", -- Changed so names with special characters can be added
			set = function(info, value)
				if Spy_IgnoreList[value] or strfind(value, "[%s%d]+") then
					DEFAULT_CHAT_FRAME:AddMessage(value .. " - " .. L["InvalidInput"])
				else
					Spy:ToggleKOSPlayer(not SpyPerCharDB.KOSData[value], value)
				end
			end,
			dialogHidden = true
		},
		ignore = {
			name = L["Ignore"],
			desc = L["IgnoreDescription"],
			type = 'input',
			order = 8,
			pattern = ".",
			set = function(info, value)
				if Spy_IgnoreList[value] or strfind(value, "[%s%d]+") then
					DEFAULT_CHAT_FRAME:AddMessage(value .. " - " .. L["InvalidInput"])
				else
					Spy:ToggleIgnorePlayer(not SpyPerCharDB.IgnoreData[value], value)
				end
			end,
			dialogHidden = true
		},
		stats = {
			name = L["Statistics"],
			desc = L["StatsDescription"],
			type = 'execute',
			order = 9,
			func = function()
				SpyStats:Toggle()
			end,
			dialogHidden = true
		},
		commdebug = {
			name = "Comm Debug",
			desc = "Toggle Comm Debug Mode to see received/rejected player data",
			type = 'execute',
			order = 10,
			func = function()
				Spy.db.profile.CommDebug = not Spy.db.profile.CommDebug
				if Spy.db.profile.CommDebug then
					DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[Spy]|r Comm Debug Mode: |cff00ff00ON|r - You will see accepted/rejected comm data")
				else
					DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[Spy]|r Comm Debug Mode: |cffff0000OFF|r")
				end
			end,
			dialogHidden = true
		},
		test = {
			name = L["Test"],
			desc = L["TestDescription"],
			type = 'execute',
			order = 11,
			func = function()
				Spy:AlertStealthPlayer("Bazzalan")
			end
		},
	},
}

local Default_Profile = {
	profile = {
		Colors = {
			["Window"] = {
				["Title"] = { r = 1, g = 1, b = 1, a = 1 },
				["Background"] = { r = 24 / 255, g = 24 / 255, b = 24 / 255, a = 1 },
				["Title Text"] = { r = 1, g = 1, b = 1, a = 1 },
			},
			["Other Windows"] = {
				["Title"] = { r = 1, g = 0, b = 0, a = 1 },
				["Background"] = { r = 24 / 255, g = 24 / 255, b = 24 / 255, a = 1 },
				["Title Text"] = { r = 1, g = 1, b = 1, a = 1 },
			},
			["Bar"] = {
				["Bar Text"] = { r = 1, g = 1, b = 1 },
			},
			["Warning"] = {
				["Warning Text"] = { r = 1, g = 1, b = 1 },
			},
			["Tooltip"] = {
				["Title Text"] = { r = 0.8, g = 0.3, b = 0.22 },
				["Details Text"] = { r = 1, g = 1, b = 1 },
				["Location Text"] = { r = 1, g = 0.82, b = 0 },
				["Reason Text"] = { r = 1, g = 0, b = 0 },
			},
			["Alert"] = {
				["Background"] = { r = 0, g = 0, b = 0, a = 0.4 },
				["Icon"] = { r = 1, g = 1, b = 1, a = 0.5 },
				["KOS Border"] = { r = 1, g = 0, b = 0, a = 0.4 },
				["KOS Text"] = { r = 1, g = 0, b = 0 },
				["KOS Guild Border"] = { r = 1, g = 0.82, b = 0, a = 0.4 },
				["KOS Guild Text"] = { r = 1, g = 0.82, b = 0 },
				["Stealth Border"] = { r = 0.6, g = 0.2, b = 1, a = 0.4 },
				["Stealth Text"] = { r = 0.6, g = 0.2, b = 1 },
				["Away Border"] = { r = 0, g = 1, b = 0, a = 0.4 },
				["Away Text"] = { r = 0, g = 1, b = 0 },
				["Location Text"] = { r = 1, g = 0.82, b = 0 },
				["Name Text"] = { r = 1, g = 1, b = 1 },
			},
			["Class"] = {
				["HUNTER"] = { r = 0.67, g = 0.83, b = 0.45, a = 0.6 },
				["WARLOCK"] = { r = 0.53, g = 0.53, b = 0.93, a = 0.6 },
				["PRIEST"] = { r = 1.00, g = 1.00, b = 1.00, a = 0.6 },
				["PALADIN"] = { r = 0.96, g = 0.55, b = 0.73, a = 0.6 },
				["MAGE"] = { r = 0.25, g = 0.78, b = 0.92, a = 0.6 },
				["ROGUE"] = { r = 1.00, g = 0.96, b = 0.41, a = 0.6 },
				["DRUID"] = { r = 1.00, g = 0.49, b = 0.04, a = 0.6 },
				["SHAMAN"] = { r = 0.00, g = 0.44, b = 0.87, a = 0.6 },
				["WARRIOR"] = { r = 0.78, g = 0.61, b = 0.43, a = 0.6 },
				["DEATHKNIGHT"] = { r = 0.77, g = 0.12, b = 0.23, a = 0.6 },
				["PET"] = { r = 0.09, g = 0.61, b = 0.55, a = 0.6 },
				["MOB"] = { r = 0.58, g = 0.24, b = 0.63, a = 0.6 },
				["UNKNOWN"] = { r = 0.1, g = 0.1, b = 0.1, a = 0.6 },
				["HOSTILE"] = { r = 0.7, g = 0.1, b = 0.1, a = 0.6 },
				["UNGROUPED"] = { r = 0.63, g = 0.58, b = 0.24, a = 0.6 },
			},
		},
		MainWindow = {
			Alpha = 1,
			AlphaBG = 1,
			Buttons = {
				ClearButton = true,
				LeftButton = true,
				RightButton = true,
			},
			RowHeight = 15,
			RowSpacing = 2,
			TextHeight = 5,
			AutoHide = true,
			BarText = {
				RankNum = true,
				PerSec = true,
				Percent = true,
				NumFormat = 1,
			},
			Position = {
				x = 4,
				y = 740,
				w = 190,
				h = 34,
			},
		},
		AlertWindow = {
			Position = {
				--				x = 0,
				--				y = -140,
				x = 750,
				y = 750,
			},
			NameSize = 14,
			LocationSize = 10,
		},
		AlertWindowNameSize = 14,
		AlertWindowLocationSize = 10,
		BarTexture = "Minimalist",
		MainWindowVis = true,
		CurrentList = 1,
		Locked = false,
		Font = "Friz Quadrata TT",
		Scaling = 1,
		Enabled = true,
		EnabledInBattlegrounds = true,
		DisableWhenPVPUnflagged = false,
		NearbySortOrder = "time",
		MinimapDetection = false,
		MinimapDetails = true,
		-- Map display options removed (DisplayOnMap, SwitchToZone, MapDisplayLimit)
		DisplayTooltipNearSpyWindow = false,
		TooltipAnchor = "ANCHOR_CURSOR",
		DisplayWinLossStatistics = true,
		DisplayKOSReason = true,
		DisplayLastSeen = true,
		ShowOnDetection = true,
		HideSpy = false,
		ShowKoSButton = false,
		InvertSpy = false,
		ResizeSpy = true,
		ResizeSpyLimit = 15,
		SoundChannel = "SFX",
		Announce = "None",
		OnlyAnnounceKoS = false,
		WarnOnStealth = true,
		WarnOnStealthEvenIfDisabled = false,
		WarnOnKOS = true,
		WarnOnKOSGuild = false,
		WarnOnRace = false,
		SelectWarnRace = "None",
		DisplayWarnings = "Default",
		EnableSound = true,
		OnlySoundKoS = false,
		StopAlertsOnTaxi = true,
		RemoveUndetectedTime = 121, -- 1-120=Minutes, 121=Always
		ShowNearbyList = true,
		PrioritiseKoS = true,
		PurgeData = "NinetyDays",
		PurgeKoS = false,
		PurgeWinLossData = false,
		ShareData = false,
		UseData = false,
		CommUpdateInterval = 5,
		CommDebug = false,
		ShareKOSBetweenCharacters = true,
		FilteredZones = {
			["Booty Bay"] = false,
			["Gadgetzan"] = false,
			["Ratchet"] = false,
			["Everlook"] = false,
			["Nordanaar"] = false,
			["Tel Co. Basecamp"] = false,

		},
	}
}

SM:Register("statusbar", "blend", [[Interface\Addons\Spy\Textures\bar-blend.tga]])
SM:Register("statusbar", "Minimalist", [[Interface\Addons\Spy\Textures\Minimalist.tga]])

function Spy:CheckDatabase()
	if not SpyPerCharDB or not SpyPerCharDB.PlayerData then
		SpyPerCharDB = {}
	end
	SpyPerCharDB.version = Spy.DatabaseVersion
	if not SpyPerCharDB.PlayerData then
		SpyPerCharDB.PlayerData = {}
	end
	if not SpyPerCharDB.IgnoreData then
		SpyPerCharDB.IgnoreData = {}
	end
	if not SpyPerCharDB.KOSData then
		SpyPerCharDB.KOSData = {}
	end
	if not SpyDB.FriendsData then
		SpyDB.FriendsData = {}
	end

	if SpyDB.kosData == nil then SpyDB.kosData = {} end
	if SpyDB.kosData[Spy.RealmName] == nil then SpyDB.kosData[Spy.RealmName] = {} end
	if SpyDB.kosData[Spy.RealmName][Spy.FactionName] == nil then SpyDB.kosData[Spy.RealmName][Spy.FactionName] = {} end
	if SpyDB.kosData[Spy.RealmName][Spy.FactionName][Spy.CharacterName] == nil then SpyDB.kosData[Spy.RealmName][
		Spy.FactionName][Spy.CharacterName] = {} end
	if SpyDB.removeKOSData == nil then SpyDB.removeKOSData = {} end
	if SpyDB.removeKOSData[Spy.RealmName] == nil then SpyDB.removeKOSData[Spy.RealmName] = {} end
	if SpyDB.removeKOSData[Spy.RealmName][Spy.FactionName] == nil then SpyDB.removeKOSData[Spy.RealmName][Spy.FactionName] = {} end
	
	-- ✅ FIX: Cleanup "Unknown" placeholder entries from database
	local cleanedCount = 0
	for name, data in pairs(SpyPerCharDB.PlayerData) do
		if name == "Unknown" or name == "" or not name then
			SpyPerCharDB.PlayerData[name] = nil
			cleanedCount = cleanedCount + 1
		end
	end
	
	if cleanedCount > 0 then
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[Spy]|r Cleaned " .. cleanedCount .. " invalid 'Unknown' entries from database")
	end
end

function Spy:ResetProfile()
	Spy.db.profile = Default_Profile.profile
end

function Spy:HandleProfileChanges()
	-- Access db.profile to trigger the metatable and load the profile
	-- This is safe even during profile switching
	local profile = Spy.db.profile
	
	-- Ensure ldbIcon table exists for new/switched profiles
	if not profile.ldbIcon then
		profile.ldbIcon = {}
	end
	
	Spy:CreateMainWindow()
	Spy:RestoreMainWindowPosition(profile.MainWindow.Position.x, profile.MainWindow.Position.y,
		profile.MainWindow.Position.w, 34)
	Spy:ResizeMainWindow()
	Spy:UpdateTimeoutSettings()
	Spy:LockWindows(profile.Locked)
	--	Spy:ClampToScreen(profile.ClampToScreen)
end

function Spy:RegisterModuleOptions(name, optionTbl, displayName)
	Spy.options.args[name] = (type(optionTbl) == "function") and optionTbl() or optionTbl
	self.optionsFrames[name] = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("Spy", displayName, "Spy", name)
end

function Spy:SetupOptions()
	self.optionsFrames = {}
	self.acr = LibStub("AceConfigRegistry-3.0")
	self.ac = LibStub("AceConfig-3.0")
	self.acr.RegisterOptionsTable(self, "Spy", Spy.options)
	self.ac.RegisterOptionsTable(self, "Spy Commands", Spy.optionsSlash, "spy")


	self.optionsFrames.Spy = ACD3:AddToBlizOptions("Spy", nil, nil, "About")
	self.optionsFrames.GeneralOptions = ACD3:AddToBlizOptions("Spy", L["GeneralSettings"], "Spy", "General")
	self.optionsFrames.DisplayOptions = ACD3:AddToBlizOptions("Spy", L["DisplayOptions"], "Spy", "DisplayOptions")
	self.optionsFrames.AlertOptions = ACD3:AddToBlizOptions("Spy", L["AlertOptions"], "Spy", "AlertOptions")
	self.optionsFrames.MapOptions = ACD3:AddToBlizOptions("Spy", L["MapOptions"], "Spy", "MapOptions")
	self.optionsFrames.DataOptions = ACD3:AddToBlizOptions("Spy", L["DataOptions"], "Spy", "DataOptions")

	self:RegisterModuleOptions("Profiles", LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db), L["Profiles"])
	
	-- Wrap the SetProfile and GetProfile functions to prevent selecting the same profile
	local profileOptions = Spy.options.args.Profiles.args
	if profileOptions and profileOptions.choose then
		local originalGet = profileOptions.choose.get
		local originalSet = profileOptions.choose.set
		
		-- Wrap get to ensure it always returns a valid string
		profileOptions.choose.get = function(info)
			local current
			if type(originalGet) == "string" then
				local handler = Spy.options.args.Profiles.handler
				if handler and handler[originalGet] then
					current = handler[originalGet](handler, info)
				end
			elseif type(originalGet) == "function" then
				current = originalGet(info)
			end
			-- Ensure we always return a valid profile name, never nil
			return current or "Default"
		end
		
		-- Wrap set to prevent selecting the same profile
		profileOptions.choose.set = function(info, value)
			-- Don't do anything if trying to select the current profile or value is nil
			if not value or value == Spy.db:GetCurrentProfile() then
				return
			end
			-- Call original SetProfile
			if type(originalSet) == "string" then
				local handler = Spy.options.args.Profiles.handler
				if handler and handler[originalSet] then
					handler[originalSet](handler, info, value)
				end
			elseif type(originalSet) == "function" then
				originalSet(info, value)
			end
		end
	end
	
	Spy.options.args.Profiles.order = -2
	Spy:InitDBIcon()
end

SLASH_SPY1 = '/spygui'


function SlashCmdList.SPY()

	ACD3:Open('Spy')

end

SLASH_SPYDEBUG1 = '/spydebug'
function SlashCmdList.SPYDEBUG()
	if not Spy.db then
		DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[Spy]|r Database not loaded yet!")
		return
	end
	
	if not Spy.db.profile.DebugMode then
		Spy.db.profile.DebugMode = true
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[Spy]|r Debug mode |cff00ff00ENABLED|r - Will show stealth events")
	else
		Spy.db.profile.DebugMode = false
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[Spy]|r Debug mode |cffff0000DISABLED|r")
	end
end

SLASH_SPYCOUNTDEBUG1 = '/spycount'
function SlashCmdList.SPYCOUNTDEBUG()
	DEFAULT_CHAT_FRAME:AddMessage("=== SPY COUNT DEBUG ===")
	
	if not Spy.MainWindow then
		DEFAULT_CHAT_FRAME:AddMessage("|cffff0000MainWindow not found!|r")
		return
	end
	
	DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00MainWindow exists|r")
	DEFAULT_CHAT_FRAME:AddMessage("MainWindow position: " .. (Spy.MainWindow:GetLeft() or "nil") .. ", " .. (Spy.MainWindow:GetTop() or "nil"))
	DEFAULT_CHAT_FRAME:AddMessage("MainWindow size: " .. Spy.MainWindow:GetWidth() .. " x " .. Spy.MainWindow:GetHeight())
	DEFAULT_CHAT_FRAME:AddMessage("MainWindow visible: " .. (Spy.MainWindow:IsShown() and "YES" or "NO"))
	
	if Spy.MainWindow.Title then
		DEFAULT_CHAT_FRAME:AddMessage("Title exists: " .. (Spy.MainWindow.Title:GetText() or "nil"))
		DEFAULT_CHAT_FRAME:AddMessage("Title position: " .. (Spy.MainWindow.Title:GetLeft() or "nil") .. ", " .. (Spy.MainWindow.Title:GetTop() or "nil"))
	end
	
	if not Spy.MainWindow.CountFrame then
		DEFAULT_CHAT_FRAME:AddMessage("|cffff0000CountFrame not found!|r")
		return
	end
	
	DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00CountFrame exists|r")
	local visible = Spy.MainWindow.CountFrame:IsShown() and "VISIBLE" or "HIDDEN"
	DEFAULT_CHAT_FRAME:AddMessage("CountFrame status: |cff00ffff" .. visible .. "|r")
	DEFAULT_CHAT_FRAME:AddMessage("CountFrame position: " .. (Spy.MainWindow.CountFrame:GetLeft() or "nil") .. ", " .. (Spy.MainWindow.CountFrame:GetTop() or "nil"))
	DEFAULT_CHAT_FRAME:AddMessage("CountFrame size: " .. Spy.MainWindow.CountFrame:GetWidth() .. " x " .. Spy.MainWindow.CountFrame:GetHeight())
	DEFAULT_CHAT_FRAME:AddMessage("CountFrame parent: " .. (Spy.MainWindow.CountFrame:GetParent():GetName() or "nil"))
	
	if not Spy.MainWindow.CountFrame.Text then
		DEFAULT_CHAT_FRAME:AddMessage("|cffff0000CountFrame.Text not found!|r")
		return
	end
	
	DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00CountFrame.Text exists|r")
	local textVisible = Spy.MainWindow.CountFrame.Text:IsShown() and "VISIBLE" or "HIDDEN"
	DEFAULT_CHAT_FRAME:AddMessage("CountFrame.Text status: |cff00ffff" .. textVisible .. "|r")
	DEFAULT_CHAT_FRAME:AddMessage("CountFrame.Text position: " .. (Spy.MainWindow.CountFrame.Text:GetLeft() or "nil") .. ", " .. (Spy.MainWindow.CountFrame.Text:GetTop() or "nil"))
	DEFAULT_CHAT_FRAME:AddMessage("CountFrame.Text size: " .. (Spy.MainWindow.CountFrame.Text:GetWidth() or "nil") .. " x " .. (Spy.MainWindow.CountFrame.Text:GetHeight() or "nil"))
	DEFAULT_CHAT_FRAME:AddMessage("CountFrame.Text parent: " .. (Spy.MainWindow.CountFrame.Text:GetParent():GetName() or "nil"))
	local fontName, fontSize, fontFlags = Spy.MainWindow.CountFrame.Text:GetFont()
	DEFAULT_CHAT_FRAME:AddMessage("CountFrame.Text font: " .. (fontName or "nil") .. ", size: " .. (fontSize or "nil"))
	local r, g, b, a = Spy.MainWindow.CountFrame.Text:GetTextColor()
	DEFAULT_CHAT_FRAME:AddMessage("CountFrame.Text color: " .. r .. ", " .. g .. ", " .. b .. ", " .. a)
	
	local currentText = Spy.MainWindow.CountFrame.Text:GetText() or "NIL"
	DEFAULT_CHAT_FRAME:AddMessage("Current text: |cff00ffff" .. currentText .. "|r")
	
	-- Count active list
	local count = 0
	for k in pairs(Spy.ActiveList) do
		count = count + 1
	end
	DEFAULT_CHAT_FRAME:AddMessage("Active players in list: |cff00ffff" .. count .. "|r")
	
	-- Try to force update
	DEFAULT_CHAT_FRAME:AddMessage("Forcing update...")
	Spy:UpdateActiveCount()
	
	DEFAULT_CHAT_FRAME:AddMessage("=== END DEBUG ===")
end

-- ✅ HP-Bar Debug Command
SLASH_SPYTESTHPDEBUG1 = '/spytesthp'
SLASH_SPYTESTHPDEBUG2 = '/spyhp'
function SlashCmdList.SPYTESTHPDEBUG()
	if not Spy.HPBarDebug then
		Spy.HPBarDebug = true
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[Spy HP]|r HP-Bar Debug |cff00ff00ENABLED|r")
	else
		Spy.HPBarDebug = false
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[Spy HP]|r HP-Bar Debug |cffff0000DISABLED|r")
	end
end

-- ✅ List Sort Debug Command
SLASH_SPYLISTDEBUG1 = '/spylist'
function SlashCmdList.SPYLISTDEBUG()
	if not Spy.SortDebug then
		Spy.SortDebug = true
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[Spy List]|r Sort Debug |cff00ff00ENABLED|r - Will show detection order in chat")
	else
		Spy.SortDebug = false
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[Spy List]|r Sort Debug |cffff0000DISABLED|r")
	end
end

-- ✅ Pet Detection Debug Command
SLASH_SPYPETDEBUG1 = '/spypet'
SLASH_SPYPETDEBUG2 = '/spypets'
function SlashCmdList.SPYPETDEBUG(msg)
	if not msg or msg == "" or msg == "debug" then
		Spy.DebugPets = not Spy.DebugPets
		local status = Spy.DebugPets and "|cff00ff00ON|r" or "|cffff0000OFF|r"
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[Spy]|r Pet detection debugging: " .. status)
		if Spy.DebugPets then
			DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff[Spy]|r You will now see messages when pets are detected and blocked")
		end
	elseif strsub(msg, 1, 5) == "check" then
		local testName = strtrim(strsub(msg, 7))
		if testName and testName ~= "" then
			local guid = nil
			if SpySW and SpySW.nameToGuid then
				guid = SpySW.nameToGuid[testName]
			end
			
			local isValidPlayer = Spy:ValidatePlayerNotPet(testName, guid)
			
			DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[Spy]|r Checking: " .. testName)
			if isValidPlayer == true then
				DEFAULT_CHAT_FRAME:AddMessage("  Result: |cff00ff00Confirmed PLAYER|r")
			elseif isValidPlayer == false then
				DEFAULT_CHAT_FRAME:AddMessage("  Result: |cffff0000Confirmed PET|r")
			else
				DEFAULT_CHAT_FRAME:AddMessage("  Result: |cff888888UNKNOWN|r (unit not visible)")
			end
			if guid then
				DEFAULT_CHAT_FRAME:AddMessage("  GUID: " .. tostring(guid))
			else
				DEFAULT_CHAT_FRAME:AddMessage("  GUID: |cff888888No GUID available|r")
			end
		else
			DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[Spy]|r Usage: /spypet check <name>")
			DEFAULT_CHAT_FRAME:AddMessage("|cff888888Example: /spypet check Darktifa|r")
		end
	else
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[Spy Pet Detection]|r Commands:")
		DEFAULT_CHAT_FRAME:AddMessage("  |cff00ffff/spypet|r or |cff00ffff/spypet debug|r - Toggle debug mode")
		DEFAULT_CHAT_FRAME:AddMessage("  |cff00ffff/spypet check <name>|r - Check if name is player or pet")
	end
end

local hintString = "|cffffffff%s:|r %s"
local hintText = {
	"Spy",
	format(hintString, "Left-Click", "Show/Hide Spy"),
	format(hintString, "Right-Click", L["Config"]),
	--format(hintString, "Alt-Click", ""),
	format(hintString, "Ctrl-Click", L["Reset"]),
	format(hintString, "Shift-Click", L["Show/Hide stats"]),
}

local function LDBOnClick(self, button)
	if (button == "LeftButton") then
		if (IsShiftKeyDown()) then
			SpyStats:Toggle()
		elseif (IsControlKeyDown()) then
			Spy:ResetMainWindow()
		elseif (IsAltKeyDown()) then

		else
			Spy:EnableSpy(not Spy.db.profile.Enabled, true)
		end
	elseif (button == "RightButton") then
		InterfaceOptionsFrame_OpenToCategory("Spy")
	end
end

function Spy:InitDBIcon()

	if (LDB) then
		local ldbSpy = LibStub("LibDataBroker-1.1"):NewDataObject("Spy", {
			type = "launcher",
			icon = "Interface\\AddOns\\Spy\\Textures\\spy",
			tocname = "Spy",
			label = "Spy",
			OnClick = LDBOnClick,
			OnTooltipShow = function(tooltip)

				if (tooltip and tooltip.AddLine) then
					for _i, text in ipairs(hintText) do
						tooltip:AddLine(text)
					end
				end
			end,
		})

		if (ldbIcon) then
			if (not Spy.db.profile.ldbIcon) then
				Spy.db.profile.ldbIcon = {}
			end
			ldbIcon:Register("Spy", ldbSpy, Spy.db.profile.ldbIcon)

			self.options.args.DisplayOptions.args.ldbIcon = {
				type = "toggle",
				order = 199,
				width = "normal",
				name = L["Show Minimap Icon"],
				desc = L["Show Minimap Icon"],
				get = function() return not Spy.db.profile.ldbIcon.hide end,
				set = function(info, value)
					value = not value
					Spy.db.profile.ldbIcon.hide = value
					if (value) then
						ldbIcon:Hide("Spy")
					else
						ldbIcon:Show("Spy")
					end
				end,
			}
		end
	end
end

function Spy:UpdateTimeoutSettings()
	-- ✅ Migration: Convert old string values to new number format
	if type(Spy.db.profile.RemoveUndetected) == "string" then
		local oldValue = Spy.db.profile.RemoveUndetected
		if oldValue == "Never" then
			Spy.db.profile.RemoveUndetectedTime = 1  -- Never no longer supported, use 1 minute
		elseif oldValue == "Always" then
			Spy.db.profile.RemoveUndetectedTime = 121
		elseif oldValue == "OneMinute" then
			Spy.db.profile.RemoveUndetectedTime = 1
		elseif oldValue == "TwoMinutes" then
			Spy.db.profile.RemoveUndetectedTime = 2
		elseif oldValue == "FiveMinutes" then
			Spy.db.profile.RemoveUndetectedTime = 5
		elseif oldValue == "TenMinutes" then
			Spy.db.profile.RemoveUndetectedTime = 10
		elseif oldValue == "FifteenMinutes" then
			Spy.db.profile.RemoveUndetectedTime = 15
		else
			Spy.db.profile.RemoveUndetectedTime = 5 -- Default
		end
		Spy.db.profile.RemoveUndetected = nil -- Clear old value
	end
	
	local timeout = Spy.db.profile.RemoveUndetectedTime or 1
	Spy.ActiveTimeout = 1
	
	if timeout >= 121 then
		-- Always remove immediately
		Spy.InactiveTimeout = 0.1
	else
		-- Remove after X minutes
		Spy.InactiveTimeout = timeout * 60
	end
end

function Spy:ResetMainWindow()
	Spy:EnableSpy(true, true)
	Spy:CreateMainWindow()
	Spy:RestoreMainWindowPosition(Default_Profile.profile.MainWindow.Position.x,
		Default_Profile.profile.MainWindow.Position.y, Default_Profile.profile.MainWindow.Position.w, 34)
	Spy:RefreshCurrentList()
end

function Spy:ResetPositions()
	Spy:ResetPositionAllWindows()
end

function Spy:ShowConfig()
	InterfaceOptionsFrame_OpenToCategory('Spy')
end

function Spy:OnEnable(first)
	if Spy.db and Spy.db.profile and Spy.db.profile.DebugMode then
		DEFAULT_CHAT_FRAME:AddMessage("|cffff00ff[Spy DEBUG]|r ========== OnEnable START ==========")
	end
	
	-- Safety check: ensure db is initialized before proceeding
	if not Spy.db or not Spy.db.profile then
		if Spy.db and Spy.db.profile and Spy.db.profile.DebugMode then
			DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[Spy DEBUG]|r DB not ready, scheduling retry")
		end
		-- Schedule retry after a short delay to allow initialization to complete
		Spy:ScheduleTimer("OnEnable", 0.5)
		return
	end
	
	if Spy.db.profile.DebugMode then
		DEFAULT_CHAT_FRAME:AddMessage("|cffff00ff[Spy DEBUG]|r DB ready, Enabled=" .. tostring(Spy.db.profile.Enabled))
	end
	
	-- ✅ CRITICAL FIX: Wait for SpySuperWoW.lua to load
	-- SpySuperWoW.lua is loaded AFTER Spy.lua, but OnEnable can be called before all files are loaded
	if not SpyModules or not SpyModules.SuperWoW then
		if Spy.db.profile.DebugMode then
			DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[Spy DEBUG]|r SpyModules.SuperWoW not loaded yet, scheduling retry...")
		end
		Spy:ScheduleTimer("OnEnable", 0.1)
		return
	end
	
	if Spy.db.profile.DebugMode then
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[Spy DEBUG]|r SpyModules.SuperWoW is loaded")
	end
	
	-- Initialize SuperWoW module if available (loaded from SpySuperWoW.lua)
	if not Spy.HasSuperWoW and SpyModules and SpyModules.SuperWoW then
		if Spy.db.profile.DebugMode then
			DEFAULT_CHAT_FRAME:AddMessage("|cffff00ff[Spy DEBUG]|r Initializing SuperWoW...")
		end
		-- Try to initialize SuperWoW (only once)
		if SpyModules.SuperWoW:Initialize() then
			Spy.HasSuperWoW = true
			Spy.SuperWoW = SpyModules.SuperWoW
			if Spy.db.profile.DebugMode then
				DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[Spy DEBUG]|r SuperWoW initialized OK")
			end
		else
			Spy.HasSuperWoW = false
			if Spy.db.profile.DebugMode then
				DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[Spy DEBUG]|r SuperWoW init FAILED")
			end
		end
	else
		if Spy.db.profile.DebugMode then
			DEFAULT_CHAT_FRAME:AddMessage("|cffff00ff[Spy DEBUG]|r SuperWoW already initialized: " .. tostring(Spy.HasSuperWoW))
		end
	end
	
	-- ✅ FIX Bug 1: Only initialize if Enabled OR if Stealth-Only mode is active
	local stealthOnlyMode = Spy.db.profile.WarnOnStealthEvenIfDisabled and not Spy.db.profile.Enabled
	if Spy.db.profile.DebugMode then
		DEFAULT_CHAT_FRAME:AddMessage("|cffff00ff[Spy DEBUG]|r Stealth-Only mode: " .. tostring(stealthOnlyMode))
		DEFAULT_CHAT_FRAME:AddMessage("|cffff00ff[Spy DEBUG]|r Enabled: " .. tostring(Spy.db.profile.Enabled))
		DEFAULT_CHAT_FRAME:AddMessage("|cffff00ff[Spy DEBUG]|r WarnOnStealthEvenIfDisabled: " .. tostring(Spy.db.profile.WarnOnStealthEvenIfDisabled))
	end
	
	-- ✅ FIX: Initialisiere SpyDistance nach PLAYER_ENTERING_WORLD
	if Spy.Distance and Spy.Distance.Initialize then
		if Spy.db.profile.DebugMode then
			DEFAULT_CHAT_FRAME:AddMessage("|cffff00ff[Spy DEBUG]|r Initializing SpyDistance...")
		end
		Spy.Distance:Initialize()
		if Spy.db.profile.DebugMode then
			DEFAULT_CHAT_FRAME:AddMessage("|cffff00ff[Spy DEBUG]|r SpyDistance enabled: " .. tostring(Spy.Distance.enabled))
		end
	end
	
	-- ✅ CRITICAL: Don't return early - events must be registered even in Stealth-Only mode!
	-- If completely disabled (no Enabled, no Stealth-Only), skip initialization
	if not Spy.db.profile.Enabled and not stealthOnlyMode then
		if Spy.db.profile.DebugMode then
			DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[Spy DEBUG]|r Spy completely disabled, SKIPPING OnEnable")
		end
		return
	end
	
	-- ✅ FIX: Clear all lists on startup to prevent showing stale data from last session
	-- Old players from SavedVariables are no longer nearby after a reload
	-- Clear SpySW detected players cache
	if SpySW and SpySW.detectedPlayers then
		for k in pairs(SpySW.detectedPlayers) do
			SpySW.detectedPlayers[k] = nil
		end
	end
	
	-- Clear Spy's internal lists (these are loaded from SavedVariables!)
	Spy.NearbyList = {}
	Spy.ActiveList = {}
	Spy.InactiveList = {}
	Spy.LastHourList = {}
	Spy.PlayerCommList = {}
	Spy.ListAmountDisplayed = 0
	
	-- ✅ FIX: Also destroy any leftover player frames from previous session
	if Spy.MainWindow and Spy.MainWindow.PlayerFrames then
		Spy:DestroyAllPlayerFrames()
	end
	
	if Spy.db.profile.DebugMode then
		local modeStr = stealthOnlyMode and " (Stealth-Only mode)" or ""
		DEFAULT_CHAT_FRAME:AddMessage("|cffff9900[Spy]|r Cleared all lists on startup" .. modeStr)
	end
	
	-- ✅ Update counter immediately after clearing to show grey 0
	Spy:UpdateActiveCount()
	
	Spy.timeid = Spy:ScheduleRepeatingTimer("ManageExpirations", 1, 1, true)
	Spy:RegisterEvent("ZONE_CHANGED", "ZoneChangedEvent")
	Spy:RegisterEvent("ZONE_CHANGED_NEW_AREA", "ZoneChangedEvent")
	Spy:RegisterEvent("ZONE_CHANGED_INDOORS", "ZoneChangedEvent")
	Spy:RegisterEvent("PLAYER_ENTERING_WORLD", "ZoneChangedEvent")
	Spy:RegisterEvent("UNIT_FACTION", "ZoneChangedEvent")
	
	-- SuperWoW is REQUIRED - no fallback to classic detection
	if Spy.HasSuperWoW and Spy.SuperWoW then
		-- SuperWoW is available - use modern GUID-based scanning
		Spy.SuperWoW:Enable()
		
		-- Register RAW_COMBATLOG for direct combat log parsing (SuperWoW feature)
		Spy:RegisterEvent("RAW_COMBATLOG", "RawCombatLogEvent")
		
		-- Register minimal events for Win/Loss tracking
		Spy:RegisterEvent("CHAT_MSG_COMBAT_FRIENDLY_DEATH", "DeathLogEvent")
		Spy:RegisterEvent("CHAT_MSG_COMBAT_HOSTILE_DEATH", "DeathLogEvent")
	else
		-- SuperWoW NOT available - Spy will not function
		DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[Spy]|r ERROR: SuperWoW is required! Spy is disabled.")
		return
	end
	
	-- WORLD_MAP_UPDATE removed - map display feature removed
	Spy:RegisterEvent("PLAYER_REGEN_ENABLED", "LeftCombatEvent")
	--Spy:RegisterEvent("PLAYER_DEAD", "PlayerDeadEvent")
	Spy:RegisterComm(Spy.Signature, "CommReceived")

	--[[	Spy.uc.RegisterCallback(self, "NewCast", "CombatLogEvent")
	Spy.uc.RegisterCallback(self, "NewBuff", "CombatLogEvent")
	Spy.uc.RegisterCallback(self, "NewHeal", "CombatLogEvent")
	Spy.uc.RegisterCallback(self, "Hit", "CombatLogEvent")
	Spy.uc.RegisterCallback(self, "Death", "DeathLog")
	]]
	
	-- ✅ FIX Bug 2: Don't set IsEnabled=true in Stealth-Only mode
	-- This prevents RefreshCurrentList from being called
	if not stealthOnlyMode then
		if Spy.db.profile.DebugMode then
			DEFAULT_CHAT_FRAME:AddMessage("|cffff00ff[Spy DEBUG]|r Setting IsEnabled=true, refreshing list")
		end
		Spy.IsEnabled = true
		if not Spy:TimerStatus(Spy.initTimer) then
			Spy:RefreshCurrentList()
		end
	else
		if Spy.db.profile.DebugMode then
			DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[Spy DEBUG]|r Stealth-Only mode: IsEnabled stays false")
		end
	end
	
	-- ✅ CRITICAL FIX: Manually trigger ZoneChangedEvent 
	-- PLAYER_ENTERING_WORLD might have fired BEFORE OnEnable completed
	-- This ensures WorldMap gets initialized and EnabledInZone is set correctly
	if Spy.db.profile.DebugMode then
		DEFAULT_CHAT_FRAME:AddMessage("|cffff00ff[Spy DEBUG]|r Manually triggering ZoneChangedEvent...")
	end
	Spy:ZoneChangedEvent()
	
	if Spy.db.profile.DebugMode then
		DEFAULT_CHAT_FRAME:AddMessage("|cffff00ff[Spy DEBUG]|r ========== OnEnable COMPLETE ==========")
	end
end

function Spy:OnDisable()
	if not Spy.IsEnabled then
		return
	end
	
	-- ✅ FIX: Check if Stealth-Only mode should stay active
	local stealthOnlyMode = Spy.db and Spy.db.profile and Spy.db.profile.WarnOnStealthEvenIfDisabled
	
	if Spy.timeid then
		Spy:CancelTimer(Spy.timeid)
		Spy.timeid = nil
	end
	
	-- ✅ FIX: Only disable SuperWoW if Stealth-Only mode is NOT active
	if not stealthOnlyMode then
		if Spy.HasSuperWoW and Spy.SuperWoW then
			Spy.SuperWoW:Disable()
		end
		
		-- ✅ FIX Bug 2: Clear detectedPlayers when fully disabling Spy
		if SpySW and SpySW.detectedPlayers then
			for k in pairs(SpySW.detectedPlayers) do
				SpySW.detectedPlayers[k] = nil
			end
			if Spy.db and Spy.db.profile and Spy.db.profile.DebugMode then
				DEFAULT_CHAT_FRAME:AddMessage("|cffff9900[Spy]|r Cleared detectedPlayers on disable")
			end
		end
		
		Spy:UnregisterEvent("ZONE_CHANGED")
		Spy:UnregisterEvent("ZONE_CHANGED_NEW_AREA")
		Spy:UnregisterEvent("PLAYER_ENTERING_WORLD")
		Spy:UnregisterEvent("UNIT_FACTION")
		Spy:UnregisterEvent("RAW_COMBATLOG")
		Spy:UnregisterEvent("CHAT_MSG_COMBAT_FRIENDLY_DEATH")
		Spy:UnregisterEvent("CHAT_MSG_COMBAT_HOSTILE_DEATH")
		Spy:UnregisterEvent("PLAYER_REGEN_ENABLED")
		Spy:UnregisterEvent("PLAYER_DEAD")
		Spy:UnregisterComm(Spy.Signature)
	else
		-- Stealth-Only mode: Keep SuperWoW active but minimal events
		if Spy.db.profile.DebugMode then
			DEFAULT_CHAT_FRAME:AddMessage("|cffff9900[Spy]|r Stealth-Only mode: SuperWoW stays active")
		end
		
		-- Unregister only non-essential events
		Spy:UnregisterEvent("RAW_COMBATLOG")
		Spy:UnregisterEvent("CHAT_MSG_COMBAT_FRIENDLY_DEATH")
		Spy:UnregisterEvent("CHAT_MSG_COMBAT_HOSTILE_DEATH")
		Spy:UnregisterEvent("PLAYER_REGEN_ENABLED")
		Spy:UnregisterEvent("PLAYER_DEAD")
		Spy:UnregisterComm(Spy.Signature)
	end

	Spy.IsEnabled = false
end

function Spy:EnableSpy(value, changeDisplay, hideEnabledMessage)
	Spy.db.profile.Enabled = value
	if value then
		if changeDisplay then Spy.MainWindow:Show() end
		Spy:OnEnable()
		if not hideEnabledMessage then DEFAULT_CHAT_FRAME:AddMessage(L["SpyEnabled"]) end
	else
		if changeDisplay then Spy.MainWindow:Hide() end
		Spy:OnDisable()
		DEFAULT_CHAT_FRAME:AddMessage(L["SpyDisabled"])
	end
end

function Spy:BuildZoneIDTable(ContinentList)
	local contIndex = 0
	for C in pairs(ContinentList) do
		contIndex = contIndex + 1
		local zones = { GetMapZones(C) };
		local zoneIndex = 0
		for Z, N in ipairs(zones) do
			zoneIndex = zoneIndex + 1
			Spy.ZoneID[N] = {}
			Spy.ZoneID[N].continentIndex = contIndex
			Spy.ZoneID[N].zoneIndex = zoneIndex
		end
	end
end

function Spy:GetZoneID(zoneName)
	if not Spy.ZoneID[zoneName] then
		return nil
	end
	return Spy.ZoneID[zoneName].continentIndex, Spy.ZoneID[zoneName].zoneIndex
end

function Spy:EnableSound(value)
	Spy.db.profile.EnableSound = value
	if value then
		DEFAULT_CHAT_FRAME:AddMessage(L["SoundEnabled"])
	else
		DEFAULT_CHAT_FRAME:AddMessage(L["SoundDisabled"])
	end
end

function Spy:OnInitialize()
	if Spy.db and Spy.db.profile and Spy.db.profile.DebugMode then
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff[Spy DEBUG]|r OnInitialize START")
	end
	Spy.FactionName, _ = UnitFactionGroup("player")

	if Spy.FactionName == nil then
		if Spy.db and Spy.db.profile and Spy.db.profile.DebugMode then
			DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff[Spy DEBUG]|r FactionName nil, scheduling retry")
		end
		Spy.initTimer = Spy:ScheduleTimer("OnInitialize", 1)
		return
	end
	
	if Spy.db and Spy.db.profile and Spy.db.profile.DebugMode then
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff[Spy DEBUG]|r FactionName: " .. tostring(Spy.FactionName))
	end

	-- ✅ WorldMap initialization moved to ZoneChangedEvent (PLAYER_ENTERING_WORLD)
	-- This ensures it happens at the right time, not too early

	Spy.RealmName = GetCVar("realmName")
	if Spy.db and Spy.db.profile and Spy.db.profile.DebugMode then
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff[Spy DEBUG]|r RealmName: " .. tostring(Spy.RealmName))
	end

	if Spy.FactionName == "Alliance" then
		Spy.EnemyFactionName = "Horde"
	else
		Spy.EnemyFactionName = "Alliance"
	end
	Spy.CharacterName = UnitName("player")

	Spy.ValidClasses = {
		["DRUID"] = true,
		["HUNTER"] = true,
		["MAGE"] = true,
		["PALADIN"] = true,
		["PRIEST"] = true,
		["ROGUE"] = true,
		["SHAMAN"] = true,
		["WARLOCK"] = true,
		["WARRIOR"] = true,
	}

	Spy.ValidRaces = {
		["Human"] = true,
		["Orc"] = true,
		["Dwarf"] = true,
		["Tauren"] = true,
		["Troll"] = true,
		["NightElf"] = true,
		["Night Elf"] = true,  -- Display name variant
		["Scourge"] = true,    -- API name for Undead
		["Undead"] = true,     -- Display name variant
		["Gnome"] = true,
		["HighElf"] = true,
		["High Elf"] = true,   -- Display name variant
		["Goblin"] = true,

	}

	local acedb = LibStub:GetLibrary("AceDB-3.0")

	Spy.db = acedb:New("SpyDB", Default_Profile)
	Spy:CheckDatabase()

	--	self.db.RegisterCallback(self, "OnNewProfile", "ResetProfile")
	self.db.RegisterCallback(self, "OnNewProfile", "HandleProfileChanges")
	--	self.db.RegisterCallback(self, "OnProfileReset", "ResetProfile")
	self.db.RegisterCallback(self, "OnProfileReset", "HandleProfileChanges")
	self.db.RegisterCallback(self, "OnProfileChanged", "HandleProfileChanges")
	self.db.RegisterCallback(self, "OnProfileCopied", "HandleProfileChanges")
	self:SetupOptions()

	local ContinentList, _, _ = { GetMapContinents() };

	Spy:BuildZoneIDTable(ContinentList)

	SpyTempTooltip = CreateFrame("GameTooltip", "SpyTempTooltip", nil, "GameTooltipTemplate")
	SpyTempTooltip:SetOwner(UIParent, "ANCHOR_NONE")

	Spy:RegenerateKOSGuildList()
	if Spy.db.profile.ShareKOSBetweenCharacters then
		Spy:RemoveLocalKOSPlayers()
		Spy:RegenerateKOSCentralList()
		Spy:RegenerateKOSListFromCentral()
	end
	Spy:PurgeUndetectedData()
	Spy:CreateMainWindow()
	Spy:CreateKoSButton()
	Spy:UpdateTimeoutSettings()

	--	SM.RegisterCallback(Spy, "LibSharedMedia_Registered", "UpdateBarTextures")
	SM.RegisterCallback(Spy, "LibSharedMedia_SetGlobal", "UpdateBarTextures")
	if Spy.db.profile.BarTexture then
		Spy:SetBarTextures(Spy.db.profile.BarTexture)
	end

	-- ✅ FIX Bug 2: Don't refresh list on init if Spy is disabled
	-- This prevents Nearby list from being populated before OnEnable clears it
	if Spy.db.profile.Enabled then
		if Spy.db.profile.DebugMode then
			DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff[Spy DEBUG]|r Spy enabled, refreshing list")
		end
		Spy:RefreshCurrentList()
	else
		if Spy.db.profile.DebugMode then
			DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff[Spy DEBUG]|r Spy disabled, skipping list refresh")
		end
	end

	Spy:LockWindows(Spy.db.profile.Locked)
	--	ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", Spy.FilterNotInParty)
	if Spy.db.profile.DebugMode then
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff[Spy DEBUG]|r OnInitialize COMPLETE")
	end
	DEFAULT_CHAT_FRAME:AddMessage(L["LoadDescription"])
end

function Spy:ZoneChangedEvent()
	if Spy.db and Spy.db.profile and Spy.db.profile.DebugMode then
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff[Spy DEBUG]|r ========== ZoneChangedEvent START ==========")
	end

	if not Spy.MainWindow then
		if Spy.db and Spy.db.profile and Spy.db.profile.DebugMode then
			DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[Spy DEBUG]|r MainWindow not ready, scheduling retry")
		end
		Spy:ScheduleTimer("ZoneChangedEvent", 1)
		return
	end
	
	-- ✅ FIX: Initialize WorldMap on first PLAYER_ENTERING_WORLD
	-- This ensures GetPlayerMapPosition() works correctly
	if not Spy.WorldMapInitialized then
		if Spy.db and Spy.db.profile and Spy.db.profile.DebugMode then
			DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff[Spy DEBUG]|r Initializing WorldMap...")
		end
		WorldMapFrame:Show()
		SetMapToCurrentZone()
		WorldMapFrame:Hide()
		Spy.WorldMapInitialized = true
		if Spy.db and Spy.db.profile and Spy.db.profile.DebugMode then
			DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[Spy DEBUG]|r WorldMap initialized OK")
			
			-- Test map position
			local testX, testY = GetPlayerMapPosition("player")
			DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff[Spy DEBUG]|r Test map pos: " .. tostring(testX) .. ", " .. tostring(testY))
		end
	end

	Spy.InInstance = false
	local pvpType = GetZonePVPInfo()
	local zone = GetZoneText()
	local subZone = GetSubZoneText()
	if Spy.db and Spy.db.profile and Spy.db.profile.DebugMode then
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff[Spy DEBUG]|r Zone: " .. tostring(zone) .. " / " .. tostring(subZone) .. " (PvP: " .. tostring(pvpType) .. ")")
	end
	
	local InFilteredZone = Spy:InFilteredZone(subZone)
	if pvpType == "sanctuary" or zone == "" or InFilteredZone then
		Spy.EnabledInZone = false
		if Spy.db and Spy.db.profile and Spy.db.profile.DebugMode then
			DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[Spy DEBUG]|r EnabledInZone = FALSE (sanctuary/empty/filtered)")
		end
	else
		Spy.EnabledInZone = true
		if Spy.db and Spy.db.profile and Spy.db.profile.DebugMode then
			DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[Spy DEBUG]|r EnabledInZone = TRUE")
		end

		local inInstance, instanceType = IsInInstance()
		if inInstance then
			Spy.InInstance = true
			if instanceType == "party" or instanceType == "raid" or
				(not Spy.db.profile.EnabledInBattlegrounds and instanceType == "pvp") then
				Spy.EnabledInZone = false
			end

		elseif (pvpType == "friendly" or pvpType == nil) then
			if UnitIsPVP("player") == nil and Spy.db.profile.DisableWhenPVPUnflagged then
				Spy.EnabledInZone = false
			end
		end
	end

	if Spy.EnabledInZone then
		if Spy.db and Spy.db.profile and Spy.db.profile.DebugMode then
			DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff[Spy DEBUG]|r EnabledInZone=true, checking Enabled=" .. tostring(Spy.db.profile.Enabled))
		end
		-- ✅ FIX Bug 2: Only show window and refresh if Spy is actually enabled
		-- Don't show Nearby list in Stealth-Only mode
		if Spy.db.profile.Enabled then
			if not Spy.db.profile.HideSpy then
				if Spy.db and Spy.db.profile and Spy.db.profile.DebugMode then
					DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[Spy DEBUG]|r Showing MainWindow and refreshing list")
				end
				Spy.MainWindow:Show()
				Spy:RefreshCurrentList()
			else
				if Spy.db and Spy.db.profile and Spy.db.profile.DebugMode then
					DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[Spy DEBUG]|r HideSpy=true, not showing window")
				end
			end
		else
			if Spy.db and Spy.db.profile and Spy.db.profile.DebugMode then
				DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[Spy DEBUG]|r Spy disabled, hiding window (Stealth-Only mode)")
			end
			-- Stealth-Only mode: Hide window even if EnabledInZone is true
			Spy.MainWindow:Hide()
		end
	else
		if Spy.db and Spy.db.profile and Spy.db.profile.DebugMode then
			DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[Spy DEBUG]|r EnabledInZone=false, hiding window")
		end
		Spy.MainWindow:Hide()
	end
	
	if Spy.db and Spy.db.profile and Spy.db.profile.DebugMode then
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff[Spy DEBUG]|r ========== ZoneChangedEvent COMPLETE ==========")
	end
end

function Spy:InFilteredZone(subzone)
	local InFilteredZone = false
	for filteredZone, value in pairs(Spy.db.profile.FilteredZones) do
		if subzone == filteredZone and value then
			InFilteredZone = true
			break
		end
	end
	return InFilteredZone
end

local playerName = UnitName("player")
function Spy:DeathLogEvent()
	-- Parse death messages from CHAT_MSG_COMBAT_*_DEATH events
	local message = arg1
	if not message then return end
	
	local playerName = UnitName("player")
	
	if Spy.db and Spy.db.profile and Spy.db.profile.DebugMode then
		DEFAULT_CHAT_FRAME:AddMessage("|cffff00ff[Spy Death]|r Event: " .. tostring(event))
		DEFAULT_CHAT_FRAME:AddMessage("|cffff00ff[Spy Death]|r Message: " .. tostring(message))
	end
	
	-- ✅ CHAT_MSG_COMBAT_HOSTILE_DEATH = Enemy died
	if event == "CHAT_MSG_COMBAT_HOSTILE_DEATH" then
		-- Patterns for enemy death:
		-- "PlayerName dies." - unknown killer
		-- "PlayerName is slain by PlayerName!" - specific killer
		-- "You have slain PlayerName!" - YOU are the killer
		
		local playerName = UnitName("player")
		local victim = nil
		local killer = nil
		
		-- Pattern 1: "You have slain PlayerName!"
		local _, _, v = strfind(message, "^You have slain (.+)!$")
		if v then
			victim = v
			killer = playerName  -- YOU are the killer
		end
		
		-- Pattern 2: "PlayerName is slain by KillerName!"
		if not victim then
			local _, _, v2, k = strfind(message, "^(.+) is slain by (.+)!$")
			if v2 and k then
				victim = v2
				killer = k
			end
		end
		
		-- Pattern 3: "PlayerName dies." (no killer info)
		
		if victim then
			-- Strip realm name if exists
			local realmSep = strfind(victim, "-")
			if realmSep then
				victim = strsub(victim, 1, realmSep - 1)
			end
			
			-- Only count win if YOU are the killer
			if killer then
				-- Strip realm from killer name
				local killerRealmSep = strfind(killer, "-")
				if killerRealmSep then
					killer = strsub(killer, 1, killerRealmSep - 1)
				end
				
				-- Check if YOU killed the enemy
				if killer == playerName then
					local playerData = SpyPerCharDB.PlayerData[victim]
					if playerData then
						if not playerData.wins then playerData.wins = 0 end
						playerData.wins = playerData.wins + 1
						
						-- ✅ Try to get and store GUID for victim
						if SpySW and SpySW.nameToGuid then
							local victimGuid = SpySW.nameToGuid[victim]
							if victimGuid and not playerData.guid then
								playerData.guid = victimGuid
							end
						end
						
						if Spy.db and Spy.db.profile and Spy.db.profile.DebugMode then
							local guidInfo = playerData.guid and (" [GUID: " .. playerData.guid .. "]") or ""
							DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[Spy Death]|r ✓ WIN counted for " .. victim .. guidInfo .. " (total: " .. playerData.wins .. ")")
						end
					else
						if Spy.db and Spy.db.profile and Spy.db.profile.DebugMode then
							DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[Spy Death]|r ⚠ WIN not counted - " .. victim .. " not in database")
						end
					end
				else
					if Spy.db and Spy.db.profile and Spy.db.profile.DebugMode then
						DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[Spy Death]|r ⚠ WIN not counted - " .. victim .. " killed by " .. killer .. " (not you)")
					end
				end
			else
				if Spy.db and Spy.db.profile and Spy.db.profile.DebugMode then
					DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[Spy Death]|r ⚠ WIN not counted - " .. victim .. " died (unknown killer)")
				end
			end
		end
	
	-- ✅ CHAT_MSG_COMBAT_FRIENDLY_DEATH = You or friendly died
	elseif event == "CHAT_MSG_COMBAT_FRIENDLY_DEATH" then
		-- Check if YOU died
		if strfind(message, "^You die") or strfind(message, "^You have died") then
			-- ✅ DELAY death processing by 0.5s to catch late damage events
			-- Combat log events sometimes arrive out of order!
			if Spy.db and Spy.db.profile and Spy.db.profile.DebugMode then
				DEFAULT_CHAT_FRAME:AddMessage("|cffff9900[Spy Death]|r Delaying death processing 0.5s to catch late hits...")
			end
			
			-- ✅ FIX: Set flag to prevent LeftCombatEvent from clearing LastAttack
			Spy.ProcessingDeath = true
			
			-- Schedule delayed processing
			Spy:ScheduleTimer("ProcessPlayerDeath", 0.5)
		end
	end
end

-- ✅ NEW: Process player death with delay (called by timer)
function Spy:ProcessPlayerDeath()
	local playerName = UnitName("player")
	
	-- YOU died - use LastAttack to find killer
	local killer = Spy.LastAttack
	local killerGuid = Spy.LastAttackGuid
	
	if killer then
		-- Strip realm name if exists
		local realmSep = strfind(killer, "%-")
		if realmSep then
			killer = strsub(killer, 1, realmSep - 1)
		end
		
		-- ✅ Try to get GUID if we only have name
		if not killerGuid and SpySW and SpySW.nameToGuid then
			killerGuid = SpySW.nameToGuid[killer]
		end
		
		-- If killer is a GUID string, try to resolve to name
		if strfind(tostring(killer), "^0x") then
			if SpySW and SpySW.GetNameFromGUID then
				local resolvedName = SpySW:GetNameFromGUID(killer)
				if resolvedName then
					killer = resolvedName
				end
			elseif UnitExists(killer) then
				local resolvedName = UnitName(killer)
				if resolvedName then
					killerGuid = killer
					killer = resolvedName
				end
			end
		end
		
		local playerData = SpyPerCharDB.PlayerData[killer]
		
		-- ✅ FIX: Create player entry if not exists (timing issue with scanner)
		if not playerData then
			SpyPerCharDB.PlayerData[killer] = {}
			playerData = SpyPerCharDB.PlayerData[killer]
			
			-- Store GUID if available
			if killerGuid then
				playerData.guid = killerGuid
			end
			
			if Spy.db and Spy.db.profile and Spy.db.profile.DebugMode then
				DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[Spy Death]|r ⚠ Created new entry for " .. killer)
			end
		end
		
		-- Count the loss
		if not playerData.loses then playerData.loses = 0 end
		playerData.loses = playerData.loses + 1
		
		-- ✅ Store GUID if available
		if killerGuid and not playerData.guid then
			playerData.guid = killerGuid
		end
		
		if Spy.db and Spy.db.profile and Spy.db.profile.DebugMode then
			local guidInfo = killerGuid and (" [GUID: " .. killerGuid .. "]") or ""
			DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[Spy Death]|r ✓ LOSS counted for " .. killer .. guidInfo .. " (total: " .. playerData.loses .. ")")
		end
		
		-- Reset LastAttack after processing death
		Spy.LastAttack = nil
		Spy.LastAttackGuid = nil
		Spy.ProcessingDeath = false  -- ✅ FIX: Reset processing flag
	else
		if Spy.db and Spy.db.profile and Spy.db.profile.DebugMode then
			DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[Spy Death]|r ✗ YOU died but no LastAttack found")
		end
		Spy.ProcessingDeath = false  -- ✅ FIX: Reset processing flag even if no attacker found
	end
end

-- RAW_COMBATLOG Event Handler (SuperWoW feature)
-- Parses raw combat log text to track last attacker
local playerName = UnitName("player")

function Spy:RawCombatLogEvent()
	local eventName = arg1
	local eventText = arg2
	
	if Spy.db and Spy.db.profile and Spy.db.profile.DebugMode then
		DEFAULT_CHAT_FRAME:AddMessage("|cffaaff00[Spy Debug]|r RAW_COMBATLOG: " .. tostring(eventName))
		DEFAULT_CHAT_FRAME:AddMessage("|cffaaff00[Spy Debug]|r   text=" .. tostring(eventText))
	end
	
	-- ✅ GUID Extractor for SuperWoW
	if SpySW and eventText then
		-- Look for GUID pattern: 0x followed by 16 hex digits
		local _, _, guid = strfind(eventText, "(0x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x)")
		
		if guid and UnitExists(guid) and UnitIsPlayer(guid) then
			-- Add GUID to tracking
			SpySW:AddUnit(guid)
			
			if Spy.db and Spy.db.profile and Spy.db.profile.DebugMode then
				local name = UnitName(guid)
				if name then
					DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff[SpySW COMBATLOG]|r GUID extracted: " .. name .. " (" .. guid .. ")")
				end
			end
		end
	end
	
	-- ✅ IMPROVED: Track LastAttack from damage messages with comprehensive patterns
	local playerName = UnitName("player")
	
	-- Skip self-damage (Hellfire, Life Tap, etc)
	if eventText and (strfind(eventText, "your own") or strfind(eventText, "You lose")) then
		return
	end
	
	if not eventText then return end
	
	-- ✅ DEBUG: Show all hits/crits to check for pet names
	if Spy.db and Spy.db.profile and Spy.db.profile.DebugMode then
		if strfind(eventText, " hits you") or strfind(eventText, " crits you") then
			DEFAULT_CHAT_FRAME:AddMessage("|cffff00ff[Spy Pet Debug]|r HIT TEXT: " .. tostring(eventText))
		end
	end
	
	-- ✅ Track attacker from COMPREHENSIVE damage patterns
	local attacker = nil
	local attackerGuid = nil
	
	-- === GUID-based patterns (SuperWoW) ===
	-- Pattern: "GUID hits you"
	if not attacker then
		local _, _, guid = strfind(eventText, "^(0x%x+) hits you")
		if guid and UnitExists(guid) then
			attackerGuid = guid
			attacker = UnitName(guid)
		end
	end
	
	-- Pattern: "GUID crits you"
	if not attacker then
		local _, _, guid = strfind(eventText, "^(0x%x+) crits you")
		if guid and UnitExists(guid) then
			attackerGuid = guid
			attacker = UnitName(guid)
		end
	end
	
	-- Pattern: "GUID's Spell hits/crits you"
	if not attacker then
		local _, _, guid = strfind(eventText, "^(0x%x+)'s .+ (%a+) you")
		if guid and UnitExists(guid) then
			attackerGuid = guid
			attacker = UnitName(guid)
		end
	end
	
	-- === Name-based patterns ===
	-- ✅ WICHTIG: Spezifische Patterns mit "'s" ZUERST, sonst matched "Name crits you" zu viel!
	
	-- Pattern: "Name's Spell hits you"
	if not attacker then
		_, _, attacker = strfind(eventText, "^([^']+)'s .+ hits you")
	end
	
	-- Pattern: "Name's Spell crits you"
	if not attacker then
		_, _, attacker = strfind(eventText, "^([^']+)'s .+ crits you")
	end
	
	-- Pattern: "Name hits you" (generisch, kommt NACH den spezifischen)
	if not attacker then
		_, _, attacker = strfind(eventText, "^(.+) hits you")
	end
	
	-- Pattern: "Name crits you" (generisch, kommt NACH den spezifischen)
	if not attacker then
		_, _, attacker = strfind(eventText, "^(.+) crits you")
	end
	
	-- === DoT patterns (Moonfire, etc) ===
	-- Pattern: "You suffer X damage from Name's Spell"
	if not attacker then
		_, _, attacker = strfind(eventText, "damage from ([^']+)'s")
	end
	
	-- Pattern: "Name's Spell hits you for X Y damage"
	if not attacker then
		_, _, attacker = strfind(eventText, "^([^']+)'s .+ hits you for %d+")
	end
	
	-- === Afflict/Absorb patterns ===
	-- Pattern: "You are afflicted by Name's Spell"
	if not attacker then
		_, _, attacker = strfind(eventText, "afflicted by ([^']+)'s")
	end
	
	-- Pattern: "Name's Spell was absorbed"
	if not attacker then
		_, _, attacker = strfind(eventText, "^([^']+)'s .+ was absorbed")
	end
	
	-- === Reflect/Thorns patterns ===
	-- Pattern: "GUID reflects X damage to you" (Thorns, Fire Shield, etc)
	if not attacker then
		local _, _, guid = strfind(eventText, "^(0x%x+) reflects %d+ .+ damage to you")
		if guid and UnitExists(guid) then
			attackerGuid = guid
			attacker = UnitName(guid)
		end
	end
	
	-- Pattern: "Name reflects X damage to you"
	if not attacker then
		_, _, attacker = strfind(eventText, "^(.+) reflects %d+ .+ damage to you")
	end
	
	-- === Drain/Leech patterns ===
	-- Pattern: "Name gains X from Spell" (Life Drain, Mana Drain that damages you)
	if not attacker then
		_, _, attacker = strfind(eventText, "^(.+) gains %d+ .- from")
	end
	
	-- Process attacker if found
	if attacker then
		-- ✅ If attacker is a GUID string, resolve to name
		if strfind(tostring(attacker), "^0x") then
			local guid = attacker
			attackerGuid = guid
			
			-- Try to resolve GUID to name
			if UnitExists(guid) then
				attacker = UnitName(guid)
			elseif SpySW and SpySW.GetNameFromGUID then
				attacker = SpySW:GetNameFromGUID(guid)
			end
			
			-- If we still can't resolve, skip this attacker
			if not attacker or strfind(tostring(attacker), "^0x") then
				if Spy.db and Spy.db.profile and Spy.db.profile.DebugMode then
					DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[Spy LastAttack]|r Could not resolve GUID: " .. tostring(guid))
				end
				attacker = nil
			end
		end
		
		-- Strip realm name if exists
		if attacker then
			local realmSep = strfind(attacker, "%-")
			if realmSep then
				attacker = strsub(attacker, 1, realmSep - 1)
			end
			
			-- Only set if it's not yourself
			if attacker ~= playerName then
				-- Store both name and GUID if available
				Spy.LastAttack = attacker
				Spy.LastAttackGuid = attackerGuid
				
				if Spy.db and Spy.db.profile and Spy.db.profile.DebugMode then
					local guidInfo = attackerGuid and (" [GUID: " .. attackerGuid .. "]") or ""
					DEFAULT_CHAT_FRAME:AddMessage("|cffff9900[Spy LastAttack]|r Set to: " .. tostring(attacker) .. guidInfo)
				end
			end
		end
	end
end

function Spy:LeftCombatEvent()
	-- ✅ FIX: Don't clear LastAttack if we're processing a death
	-- This prevents the combat-exit event from clearing the killer info
	-- before the delayed death processing (0.5s timer) completes
	if not Spy.ProcessingDeath then
		Spy.LastAttack = nil
		Spy.LastAttackGuid = nil
	end
	Spy:RefreshCurrentList()
end

-- WorldMapUpdateEvent removed - map display feature removed

function Spy:CommReceived(prefix, message, distribution, source)
	if not Spy.EnabledInZone or not Spy.db.profile.UseData then
		return
	end
	
	if prefix ~= Spy.Signature or not message or source == Spy.CharacterName then
		return
	end
	
	local commDebug = Spy.db.profile.CommDebug
	local updateInterval = Spy.db.profile.CommUpdateInterval or 5
	
	-- Parse message - format: version,player,class,level,race,zone,subZone,mapX,mapY,guild[,guid]
	local version, player, class, level, race, zone, subZone, mapX, mapY, guild, guid = strsplit(",", message)
	
	-- Basic validation
	if not player or player == "" then
		if commDebug then
			DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[Spy Comm]|r Rejected: empty player name from " .. source)
		end
		return
	end
	
	-- Instance check
	if Spy.InInstance and zone ~= GetZoneText() then
		if commDebug then
			DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[Spy Comm]|r Rejected " .. player .. ": different instance zone")
		end
		return
	end
	
	-- Friend check
	if Spy:PlayerIsFriend(player) then
		if commDebug then
			DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[Spy Comm]|r Rejected " .. player .. ": is friend")
		end
		return
	end
	
	-- ✅ NEW: Check if we should accept update (timestamp-based)
	local now = time()
	local commData = Spy.PlayerCommList[player]
	local isUpdate = false
	
	if commData then
		local lastTime = commData.timestamp or 0
		if (now - lastTime) < updateInterval then
			-- Too soon for update, skip silently (no spam)
			return
		end
		isUpdate = true
	end
	
	-- Version check (only on first detection)
	if not isUpdate then
		local upgrade = Spy:VersionCheck(Spy.Version, version)
		if upgrade and not Spy.UpgradeMessageSent then
			DEFAULT_CHAT_FRAME:AddMessage(L["UpgradeAvailable"])
			Spy.UpgradeMessageSent = true
		end
	end
	
	-- Validate class
	if strlen(class) > 0 then
		if not Spy.ValidClasses[class] then
			if commDebug then
				DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[Spy Comm]|r Rejected " .. player .. ": invalid class '" .. class .. "'")
			end
			return
		end
	else
		class = nil
	end
	
	-- Validate level
	if strlen(level) > 0 then
		level = tonumber(level)
		if type(level) == "number" then
			if level < -1 or level > Spy.MaximumPlayerLevel or (level > 0 and math.floor(level) ~= level) then
				if commDebug then
					DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[Spy Comm]|r Rejected " .. player .. ": invalid level " .. tostring(level))
				end
				return
			end
			if level < 0 then
				level = 0
			end
		else
			if commDebug then
				DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[Spy Comm]|r Rejected " .. player .. ": level not a number")
			end
			return
		end
	else
		level = nil
	end
	
	-- Validate race
	if strlen(race) > 0 then
		if not Spy.ValidRaces[race] then
			if commDebug then
				DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[Spy Comm]|r Rejected " .. player .. ": invalid race '" .. race .. "'")
			end
			return
		end
		-- ✅ REMOVED: Faction-based race check - causes issues on custom servers
		-- and with cross-faction data sharing. ValidRaces check is sufficient.
	else
		race = nil
	end
	
	-- Validate zone (accept any non-empty string for custom servers)
	if strlen(zone) == 0 then
		zone = nil
	end
	
	-- SubZone
	if strlen(subZone) == 0 then
		subZone = nil
	end
	
	-- Validate mapX
	if strlen(mapX) > 0 then
		mapX = tonumber(mapX)
		if type(mapX) == "number" and mapX >= 0 and mapX <= 1 then
			mapX = math.floor(mapX * 100) / 100
		else
			if commDebug then
				DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[Spy Comm]|r Rejected " .. player .. ": invalid mapX")
			end
			return
		end
	else
		mapX = nil
	end
	
	-- Validate mapY
	if strlen(mapY) > 0 then
		mapY = tonumber(mapY)
		if type(mapY) == "number" and mapY >= 0 and mapY <= 1 then
			mapY = math.floor(mapY * 100) / 100
		else
			if commDebug then
				DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[Spy Comm]|r Rejected " .. player .. ": invalid mapY")
			end
			return
		end
	else
		mapY = nil
	end
	
	-- Validate guild
	if strlen(guild) > 0 then
		if strlen(guild) > 24 then
			if commDebug then
				DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[Spy Comm]|r Rejected " .. player .. ": guild name too long")
			end
			return
		end
	else
		guild = nil
	end
	
	-- ✅ NEW: Validate GUID if present (SuperWoW)
	if guid and strlen(guid) > 0 then
		-- Basic GUID format check (should be hex string like "0x0000000000123456")
		if strlen(guid) > 20 then
			guid = nil -- Invalid, ignore
		end
	else
		guid = nil
	end
	
	-- Process the player data
	local learnt, playerData = Spy:ParseUnitDetails(player, class, level, race, zone, subZone, mapX, mapY, guild)
	
	if playerData and playerData.isEnemy and not SpyPerCharDB.IgnoreData[player] then
		-- ✅ Store GUID in PlayerData if received (SuperWoW)
		if guid and (not playerData.guid or playerData.guid == "") then
			playerData.guid = guid
		end
		
		-- ✅ Store timestamp and optional GUID in CommList
		Spy.PlayerCommList[player] = {
			timestamp = now,
			guid = guid,
			source = source
		}
		
		if commDebug then
			local updateStr = isUpdate and " (UPDATE)" or " (NEW)"
			local guidStr = guid and (" GUID:" .. guid) or ""
			DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[Spy Comm]|r Accepted " .. player .. updateStr .. " from " .. source .. guidStr)
		end
		
		Spy:AddDetected(player, now, learnt, source)
	else
		if commDebug then
			local reason = "unknown"
			if not playerData then
				reason = "no playerData"
			elseif not playerData.isEnemy then
				reason = "not enemy"
			elseif SpyPerCharDB.IgnoreData[player] then
				reason = "on ignore list"
			end
			DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[Spy Comm]|r Rejected " .. player .. ": " .. reason)
		end
	end
end

function Spy:ParseUnitDetails(name, class, level, race, zone, subZone, mapX, mapY, guild)
	if not name then return false, nil end
	
	-- Get or create player data
	if not SpyPerCharDB.PlayerData[name] then
		SpyPerCharDB.PlayerData[name] = {}
	end
	
	local playerData = SpyPerCharDB.PlayerData[name]
	local learnt = false
	
	-- ✅ Set name in playerData (required for stats)
	playerData.name = name
	
	-- Update class (only if new data available)
	if class and not playerData.class then
		playerData.class = class
		learnt = true
	end
	
	-- ✅ Update level (also accept 0 for "??")
	if level ~= nil and not playerData.level then
		-- Level 0 = "??" (too high/too low)
		playerData.level = level
		learnt = true
	end
	
	-- Update race (only if new data available)
	if race and not playerData.race then
		playerData.race = race
		learnt = true
	end
	
	-- Update guild (only if new data available)
	if guild and not playerData.guild then
		playerData.guild = guild
		learnt = true
	end
	
	-- Always update location and timestamp
	if zone then
		playerData.zone = zone
	end
	if subZone then
		playerData.subZone = subZone
	end
	if mapX then
		playerData.mapX = mapX
	end
	if mapY then
		playerData.mapY = mapY
	end
	
	-- Set timestamp
	playerData.time = time()
	
	-- Set isEnemy flag (important for filtering)
	playerData.isEnemy = true
	
	return learnt, playerData
end

function Spy:VersionCheck(version1, version2)
	local major1, minor1, update1 = strsplit("%.", version1)
	local major2, minor2, update2 = strsplit("%.", version2)
	major1, minor1, update1 = tonumber(major1), tonumber(minor1), tonumber(update1)
	major2, minor2, update2 = tonumber(major2), tonumber(minor2), tonumber(update2)
	if major1 < major2 then
		return true
	elseif ((major1 == major2) and (minor1 < minor2)) then
		return true
	elseif ((major1 == major2) and (minor1 == minor2) and (update1 < update2)) then
		return true
	else
		return false
	end
end

function Spy:TrackHumanoids()
	local tooltip = GameTooltipTextLeft1:GetText()
	if tooltip and tooltip ~= Spy.LastTooltip then
		tooltip = Spy:ParseMinimapTooltip(tooltip)
		if Spy.db.profile.MinimapDetails then
			GameTooltipTextLeft1:SetText(tooltip)
			Spy.LastTooltip = tooltip
		end
		GameTooltip:Show()
	end
end

function Spy:FilterNotInParty(frame, event, message)
	if (event == ERR_NOT_IN_GROUP or event == ERR_NOT_IN_RAID) then
		return true
	end
	return false
end

-- ShowMapNote function removed - map display feature removed

function Spy:GetPlayerLocation(playerData)
	local location = playerData.zone
	local mapX = playerData.mapX
	local mapY = playerData.mapY
	if location and playerData.subZone and playerData.subZone ~= "" and playerData.subZone ~= location then
		location = playerData.subZone .. ", " .. location
	end
	if mapX and mapX ~= 0 and mapY and mapY ~= 0 then
		location = location .. " (" .. math.floor(tonumber(mapX) * 100) .. "," .. math.floor(tonumber(mapY) * 100) .. ")"
	end
	return location
end

local modf = math.modf or function(num)
	local int = math.floor(num)
	local frac = math.abs(num) - math.abs(int)

	return int, frac
end
function Spy:FormatTime(timestamp)
	if timestamp == 0 then return "Long " end

	local age = time() - timestamp

	local days
	if age >= 86400 then
		days = modf(age / 86400)
		age = age - (days * 86400)
	end

	local hours
	if age >= 3600 then
		hours = modf(age / 3600)
		age = age - (hours * 3600)
	end

	local minutes
	if age >= 60 then
		minutes = modf(age / 60)
		age = age - (minutes * 60)
	end

	local seconds = age

	local text = (days and days .. "d " or "") ..
		((hours and not days) and hours .. "h " or "") ..
		((minutes and not hours and not days) and minutes .. "m " or "") ..
		((seconds and not minutes and not hours and not days) and seconds .. "s " or "")

	return strtrim(text)
end

-- ✅ HP-Bar Feature: Get class color for health bar display
function Spy:GetClassColor(class)
	-- Default to gray if class unknown
	if not class or class == "UNKNOWN" then
		return 0.5, 0.5, 0.5
	end
	
	-- Use WoW's built-in class colors
	local classColor = RAID_CLASS_COLORS[class]
	if classColor then
		return classColor.r, classColor.g, classColor.b
	end
	
	-- Fallback to gray
	return 0.5, 0.5, 0.5
end

-- recieves pointer to SpyData db
function Spy:SetDataDb(val)
	Spy_db = val
end

-- Stub functions for KOS functionality
function Spy:RemoveLocalKOSPlayers()
	-- Placeholder
end

function Spy:RegenerateKOSCentralList()
	-- Placeholder
end

function Spy:RegenerateKOSListFromCentral()
	-- Placeholder
end

function Spy:RegenerateKOSGuildList()
	-- Placeholder
end

function Spy:PurgeUndetectedData()
	-- Placeholder
end
