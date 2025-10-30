local AceLocale = LibStub:GetLibrary("AceLocale-3.0")
local L = AceLocale:NewLocale("Spy", "enUS", true)
if not L then return end

-- Addon information
L["Spy"] = "Spy"
L["Version"] = "Version"
L["LoadDescription"] = "|cff9933ffSpy addon loaded. Type |cffffffff/spy|cff9933ff for options."
L["SpyEnabled"] = "|cff9933ffSpy addon enabled."
L["SpyDisabled"] = "|cff9933ffSpy addon disabled. Type |cffffffff/spy show|cff9933ff to enable."
L["UpgradeAvailable"] = "|cff9933ffA new version of Spy is available. It can be downloaded from:\n|cffffffffhttps://github.com/laytya/Spy"
L["Show Minimap Icon"] = "Show Minimap Icon"
L["Show/Hide Spy"] = "Show/Hide Spy"

-- Configuration strings
L["Profiles"] = "Profiles"

L["About"] = "About"
L["SpyDescription1"] = [[
Spy is an addon that will alert you to the presence of nearby enemy players.
]]

L["SpyDescription2"] = [[

|cffffd000Nearby list|cffffffff
The Nearby list displays any enemy players that have been detected nearby. Clicking the list allows you to target the player, however this only works out of combat. Players are removed from the list if they have not been detected after a period of time.

The clear button in the title bar can be used to clear the list, and holding Control while clearing the list will allow you to quickly enable/disable Spy.

|cffffd000Last Hour list|cffffffff
The Last Hour list displays all enemies that have been detected in the last hour.

|cffffd000Ignore list|cffffffff
Players that are added to the Ignore list will not be reported by Spy. You can add and remove players to/from this list by using the button's drop down menu or by holding the Control key while clicking the button.

|cffffd000Kill On Sight list|cffffffff
Players on your Kill On Sight list cause an alarm to sound when detected. You can add and remove players to/from this list by using the button's drop down menu or by holding the Shift key while clicking the button.

The drop down menu can also be used to set the reasons why you have added someone to the Kill On Sight list. If you want to enter a specific reason that is not in the list, then use the "Enter your own reason..." in the Other list.

]]

L["SpyDescription3"] = [[
|cffffd000 Statistics Window |cffffffff
The Statistics Window contains a list of all enemy encounters which can be sorted by name, level, guild, wins, losses and the last time an enemy was detected. It also provides the ability to search for a specific enemy by name or guild and has filters to show only enemies that are marked as Kill on Sight, with a Win/Loss or entered Reasons.

|cffffd000 Kill On Sight Button |cffffffff
If enabled, this button will be located on the enemy players target frame. Clicking on this button will add/remove the enemy target to/from the Kill On Sight list. Right clicking on the button will allow you to enter Kill on Sight reasons.

|cffffd000 Author:|cffffffff Slipjack
|cffffd000 Ported to Vanilla:|cffffffff LaYt
]]

-- General Settings
L["GeneralSettings"] = "General Settings"
L["GeneralSettingsDescription"] = [[
Options for when Spy is Enabled or Disabled.
]]
L["EnableSpy"] = "Enable Spy"
L["EnableSpyDescription"] = "Enables or disables Spy both now and also on login."
L["EnabledInBattlegrounds"] = "Enable Spy in battlegrounds"
L["EnabledInBattlegroundsDescription"] = "Enables or disables Spy when you are in a battleground."
L["DisableWhenPVPUnflagged"] = "Disable Spy when not flagged for PVP"
L["DisableWhenPVPUnflaggedDescription"] = "Enables or disables Spy depending on your PVP status."
L["DisabledInZones"] = "Disable Spy while in these locations"
L["DisabledInZonesDescription"] = "Select locations where Spy will be disabled"
L["Booty Bay"] = "Booty Bay"
L["Everlook"] = "Everlook"
L["Gadgetzan"] = "Gadgetzan"
L["Ratchet"] = "Ratchet"
L["Nordanaar"] = "Nordanaar"
L["Tel Co. Basecamp"] = "Tel Co. Basecamp"

L["DisplayOptions"] = "Display"
L["DisplayOptionsDescription"] = [[
Spy can be shown or hidden automatically.
]]
L["ShowOnDetection"] = "Show Spy when enemy players are detected"
L["ShowOnDetectionDescription"] = "Set this to display the Spy window and the Nearby list if Spy is hidden when enemy players are detected."
L["HideSpy"] = "Hide Spy when no enemy players are detected"
L["HideSpyDescription"] = "Set this to hide Spy when the Nearby list is displayed and it becomes empty. Spy will not be hidden if you clear the list manually."
L["ShowKoSButton"] = "Show KOS button on the enemy target frame"
L["ShowKoSButtonDescription"] = "Set this to show the KOS button on the enemy player's target frame."
L["Alpha"] = "Transparency"
L["AlphaDescription"] = "Set the transparency of the Spy window."
L["AlphaBG"] = "Transparency in BGs"
L["AlphaBGDescription"] = "Set the transparency of the Spy window in battlegrounds."
L["LockSpy"] = "Lock the Spy window"
L["LockSpyDescription"] = "Locks the Spy window in place so it doesn't move."
L["ClampToScreen"] = "Clamp to Screen"
L["ClampToScreenDescription"] = "Controls whether the Spy window can be dragged off screen."
L["InvertSpy"] = "Invert the Spy window"
L["InvertSpyDescription"] = "Flips the Spy window upside down."
L["Reload"] = "Reload UI"
L["ReloadDescription"] = "Required when changing the Spy window."
L["LockSpy"] = "Lock the Spy window"
L["LockSpyDescription"] = "Locks the Spy window in place so it doesn't move."
L["ResizeSpy"] = "Resize the Spy window automatically"
L["ResizeSpyDescription"] = "Set this to automatically resize the Spy window as enemy players are added and removed."
L["ResizeSpyLimit"] = "List Limit"
L["ResizeSpyLimitDescription"] = "Limit the number of enemy players shown in the Spy window."
L["DisplayTooltipNearSpyWindow"] = "Display tooltip near the Spy window"
L["DisplayTooltipNearSpyWindowDescription"] = "Set this to display tooltips near the Spy window."
L["SelectTooltipAnchor"] = "Tooltip Anchor Point"
L["SelectTooltipAnchorDescription"] = "Select the anchor point for the tooltip if the option above has been checked"
L["ANCHOR_CURSOR"] = "Cursor"
L["ANCHOR_TOP"] = "Top"
L["ANCHOR_BOTTOM"] = "Bottom"
L["ANCHOR_LEFT"] = "Left"
L["ANCHOR_RIGHT"] = "Right"
L["TooltipDisplayWinLoss"] = "Display win/loss statistics in tooltip"
L["TooltipDisplayWinLossDescription"] = "Set this to display the win/loss statistics of a player in the player's tooltip."
L["TooltipDisplayKOSReason"] = "Display Kill On Sight reasons in tooltip"
L["TooltipDisplayKOSReasonDescription"] = "Set this to display the Kill On Sight reasons of a player in the player's tooltip."
L["TooltipDisplayLastSeen"] = "Display last seen details in tooltip"
L["TooltipDisplayLastSeenDescription"] = "Set this to display the last known time and location of a player in the player's tooltip."
L["DisplayListData"] = "Select enemy data to display"
L["Name"] = "Name"
L["Class"] = "Class"
L["SelectFont"] = "Select a Font"
L["SelectFontDescription"] = "Select a Font for the Spy Window."
L["RowHeight"] = "Select the Row Height"
L["RowHeightDescription"] = "Select the Row Height for the Spy window."
L["Texture"] = "Texture"
L["TextureDescription"] = "Select a texture for the Spy Window"


L["AlertOptions"] = "Alerts"
L["AlertOptionsDescription"] = [[
You can announce the details on an encounter to a chat channel and control how Spy alerts you when enemy players are detected.
]]
L["SoundChannel"] = "Select Sound Channel"
L["Master"] = "Master"
L["SFX"] = "Sound Effects"
L["Music"] = "Music"
L["Ambience"] = "Ambience"
L["Announce"] = "Announce to:"
L["None"] = "None"
L["NoneDescription"] = "Do not announce when enemy players are detected."
L["Self"] = "Self"
L["SelfDescription"] = "Announce to yourself when enemy players are detected."
L["Party"] = "Party"
L["PartyDescription"] = "Announce to your party when enemy players are detected."
L["Guild"] = "Guild"
L["GuildDescription"] = "Announce to your guild when enemy players are detected."
L["Raid"] = "Raid"
L["RaidDescription"] = "Announce to your raid when enemy players are detected."
L["LocalDefense"] = "Local Defense"
L["LocalDefenseDescription"] = "Announce to the Local Defense channel when enemy players are detected."
L["OnlyAnnounceKoS"] = "Only announce enemy players that are Kill On Sight"
L["OnlyAnnounceKoSDescription"] = "Set this to only announce enemy players that are on your Kill On Sight list."
L["WarnOnStealth"] = "Warn upon stealth detection"
L["WarnOnStealthDescription"] = "Set this to display a warning and sound an alert when an enemy player gains stealth."
L["WarnOnKOS"] = "Warn upon Kill On Sight detection"
L["WarnOnKOSDescription"] = "Set this to display a warning and sound an alert when an enemy player on your Kill On Sight list is detected."
L["WarnOnKOSGuild"] = "Warn upon Kill On Sight guild detection"
L["WarnOnKOSGuildDescription"] = "Set this to display a warning and sound an alert when an enemy player in the same guild as someone on your Kill On Sight list is detected."
L["WarnOnRace"] = "Warn upon Race detection"
L["WarnOnRaceDescription"] = "Set this to sound an alert when the selected Race is detected."
L["SelectWarnRace"] = "Select Race for detection"
L["SelectWarnRaceDescription"] = "Select a Race for audio alert."
L["WarnRaceNote"] = "Note: You must target an enemy at least once so their Race can be added to the database. Upon the next detection an alert will sound. This does not work the same as detecting nearby enemies in combat."
L["DisplayWarnings"] = "Select warnings message location"
L["Default"] = "Default"
L["ErrorFrame"] = "Error Frame"
L["Moveable"] = "Moveable"
L["EnableSound"] = "Enable audio alerts"
L["EnableSoundDescription"] = "Set this to enable audio alerts when enemy players are detected. Different alerts sound if an enemy player gains stealth or if an enemy player is on your Kill On Sight list."
L["OnlySoundKoS"] = "Only sound audio alerts for Kill On Sight detection"
L["OnlySoundKoSDescription"] = "Set this to only play audio alerts when enemy players on the Kill on Sight list are detected."
L["StopAlertsOnTaxi"] = "Turn off alerts while on a flight path"
L["StopAlertsOnTaxiDescription"] = "Stop all new alerts and warnings while on a flight path."

L["SoundEnabled"] = "Sound enabled"
L["SoundDisabled"] = "Sound disabled"

L["ListOptions"] = "Nearby List"
L["ListOptionsDescription"] = [[
You can configure how Spy adds and removes enemy players to and from the Nearby list.
]]
L["RemoveUndetected"] = "Remove enemy players from the Nearby list after:"
L["Always"] = "Always remove"
L["AlwaysDescription"] = "Always Remove an enemy player who has not been detected nearby."
L["1Min"] = "1 minute"
L["1MinDescription"] = "Remove an enemy player who has been undetected for over 1 minute."
L["2Min"] = "2 minutes"
L["2MinDescription"] = "Remove an enemy player who has been undetected for over 2 minutes."
L["5Min"] = "5 minutes"
L["5MinDescription"] = "Remove an enemy player who has been undetected for over 5 minutes."
L["10Min"] = "10 minutes"
L["10MinDescription"] = "Remove an enemy player who has been undetected for over 10 minutes."
L["15Min"] = "15 minutes"
L["15MinDescription"] = "Remove an enemy player who has been undetected for over 15 minutes."
L["Never"] = "Never remove"
L["NeverDescription"] = "Never remove enemy players. The Nearby list can still be cleared manually."
L["ShowNearbyList"] = "Switch to the Nearby list upon enemy player detection"
L["ShowNearbyListDescription"] = "Set this to display the Nearby list if it is not already visible when enemy players are detected."
L["PrioritiseKoS"] = "Prioritise Kill On Sight enemy players in the Nearby list"
L["PrioritiseKoSDescription"] = "Set this to always show Kill On Sight enemy players first in the Nearby list."

-- Map
L["MapOptions"] = "Map"
L["MapOptionsDescription"] = [[
Options for world map and minimap including icons and tooltips.
]]
L["MinimapDetection"] = "Enable minimap detection"
L["MinimapDetectionDescription"] = "Rolling the cursor over known enemy players detected on the minimap will add them to the Nearby list."
L["MinimapNote"] = "          Note: Only works for players that can Track Humanoids."
L["MinimapDetails"] = "Display level/class details"
L["MinimapDetailsDescription"] = "Set this to update the minimap tooltip so that level/class details are displayed alongside enemy names."
L["DisplayOnMap"] = "Display enemy location on map"
L["DisplayOnMapDescription"] = "Set this to display on the world map and minimap the location of enemies detected by other Spy users in your party, raid and guild."
L["SwitchToZone"] = "Switch to current zone map on enemy detection"
L["SwitchToZoneDescription"] = "Change the map to the players current zone map when enemies are detected."
L["MapDisplayLimit"] = "Limit displayed map icons to:"
L["LimitNone"] = "Everywhere"
L["LimitNoneDescription"] = "Displayes all detected enemies on the map regardless of your current location."
L["LimitSameZone"] = "Same zone"
L["LimitSameZoneDescription"] = "Only displays detected enemies on the map if you are in the same zone."
L["LimitSameContinent"] = "Same continent"
L["LimitSameContinentDescription"] = "Only displays detected enemies on the map if you are on the same continent."

-- Data Management
L["DataOptions"] = "Data Management"
L["DataOptionsDescription"] = [[

Options on how Spy maintains and gathers data.
]]
L["PurgeData"] = "Purge undetected enemy player data after:"
L["OneDay"] = "1 day"
L["OneDayDescription"] = "Purge data for enemy players that have been undetected for 1 day."
L["FiveDays"] = "5 days"
L["FiveDaysDescription"] = "Purge data for enemy players that have been undetected for 5 days."
L["TenDays"] = "10 days"
L["TenDaysDescription"] = "Purge data for enemy players that have been undetected for 10 days."
L["ThirtyDays"] = "30 days"
L["ThirtyDaysDescription"] = "Purge data for enemy players that have been undetected for 30 days."
L["SixtyDays"] = "60 days"
L["SixtyDaysDescription"] = "Purge data for enemy players that have been undetected for 60 days."
L["NinetyDays"] = "90 days"
L["NinetyDaysDescription"] = "Purge data for enemy players that have been undetected for 90 days."
L["PurgeKoS"] = "Purge Kill on Sight players based on undetected time."
L["PurgeKoSDescription"] = "Set this to purge Kill on Sight players that have been undetected based on the time settings for undetected players."
L["PurgeWinLossData"] = "Purge win/loss data based on undetected time."
L["PurgeWinLossDataDescription"] = "Set this to purge win/loss data of your enemy encounters based on the time settings for undetected players."
L["ShareData"] = "Share data with other Spy addon users"
L["ShareDataDescription"] = "Set this to share the details of your enemy player encounters with other Spy users in your party, raid and guild."
L["UseData"] = "Use data from other Spy addon users"
L["UseDataDescription"] = [[Set this to use the data collected by other Spy users in your party, raid and guild.

If another Spy user detects an enemy player then that enemy player will be added to your Nearby list if there is room.
]]
L["ShareKOSBetweenCharacters"] = "Share Kill On Sight players between your characters"
L["ShareKOSBetweenCharactersDescription"] = "Set this to share the players you mark as Kill On Sight between other characters that you play on the same server and faction."

L["SlashCommand"] = "Slash Command"
L["SpySlashDescription"] = "These buttons execute the same functions as the ones in the slash command /spy"
L["Enable"] = "Enable"
L["EnableDescription"] = "Enables Spy and shows the main window."
L["Show"] = "Show"
L["ShowDescription"] = "Shows the main window."
L["Hide"] = "Hide"
L["HideDescription"] = "Hides the main window."
L["Reset"] = "Reset"
L["ResetDescription"] = "Resets the position and appearance of the main window."
L["ClearSlash"] = "Clear"
L["ClearSlashDescription"] = "Clears the list of players that have been detected."
L["Config"] = "Config"
L["ConfigDescription"] = "Open the Interface Addons configuration window for Spy."
L["KOS"] = "KOS"
L["KOSDescription"] = "Add/remove a player to/from the Kill On Sight list."
L["Ignore"] = "Ignore"
L["IgnoreDescription"] = "Add/remove a player to/from the Ignore list."
L["InvalidInput"] = "Invalid Input"
L["Test"] = "Test"
L["TestDescription"] = "Shows a warning so it can be repositioned."

-- Lists
L["Nearby"] = "Nearby"
L["LastHour"] = "Last Hour"
L["Ignore"] = "Ignore"
L["KillOnSight"] = "Kill On Sight"

--Stats
L["Show/Hide stats"] = "Show/Hide stats"
L["Won"] = "Won"
L["Lost"] = "Lost"
L["Time"] = "Time"
L["List"] = "List"
L["Filter"] = "Filter"
L["Show Only"] = "Show Only"
L["Realm"] = "Realm"
L["KOS"] = "KOS"
L["Won/Lost"] = "Won/Lost"
L["Reason"] = "Reason"
L["HonorKills"] = "Honor Kills"
L["PvPDeaths"] = "PvP Deaths"

--++ Class descriptions
L["DRUID"] = "|cffff7c0aDruid|cffffffff"
L["HUNTER"] = "|cffaad372Hunter|cffffffff"
L["MAGE"] = "|cff68ccefMage|cffffffff"
L["PALADIN"] = "|cfff48cbaPaladin|cffffffff"
L["PRIEST"] = "|cffffffffPriest|cffffffff"
L["ROGUE"] = "|cfffff468Rogue|cffffffff"
L["SHAMAN"] = "|cff2359ffShaman|cffffffff"
L["WARLOCK"] = "|cff9382c9Warlock|cffffffff"
L["WARRIOR"] = "|cffc69b6dWarrior|cffffffff"
L["UNKNOWN"] = "|cff191919Unknown|cffffffff"

-- Race descriptions
L["Human"] = "Human"
L["Orc"] = "Orc"
L["Dwarf"] = "Dwarf"
L["Tauren"] = "Tauren"
L["Troll"] = "Troll"
L["Night Elf"] = "Night Elf"
L["Undead"] = "Undead"
L["Gnome"] = "Gnome"
L["Goblin"] = "Goblin"
L["High Elf"] = "High Elf"

-- Stealth abilities
L["Stealth"] = "Stealth"
L["Prowl"] = "Prowl"
L["Vanish"] = "Vanish"
L["Shadowmeld"] = "Shadowmeld"
-- Channel names
L["LocalDefenseChannelName"] = "LocalDefense"

-- Minimap color codes
L["MinimapClassTextDRUID"] = "|cffff7c0a"
L["MinimapClassTextHUNTER"] = "|cffaad372"
L["MinimapClassTextMAGE"] = "|cff68ccef"
L["MinimapClassTextPALADIN"] = "|cfff48cba"
L["MinimapClassTextPRIEST"] = "|cffffffff"
L["MinimapClassTextROGUE"] = "|cfffff468"
L["MinimapClassTextSHAMAN"] = "|cff2359ff"
L["MinimapClassTextWARLOCK"] = "|cff9382c9"
L["MinimapClassTextWARRIOR"] = "|cffc69b6d"
L["MinimapClassTextUNKNOWN"] = "|cff191919"
L["MinimapGuildText"] = "|cffffffff"

-- Output messages
L["AlertStealthTitle"] = "Stealthed player detected!"
L["AlertKOSTitle"] = "Kill On Sight player detected!"
L["AlertKOSGuildTitle"] = "Kill On Sight player guild detected!"
L["AlertTitle_kosaway"] = "Kill On Sight player located by "
L["AlertTitle_kosguildaway"] = "Kill On Sight player guild located by "
L["StealthWarning"] = "|cff9933ffStealthed player detected: |cffffffff"
L["KOSWarning"] = "|cffff0000Kill On Sight player detected: |cffffffff"
L["KOSGuildWarning"] = "|cffff0000Kill On Sight player guild detected: |cffffffff"
L["SpySignatureColored"] = "|cff9933ff[Spy] "
L["PlayerDetectedColored"] = "|cff40ff00Player detected: |cffffffff"
L["KillOnSightDetectedColored"] = "|cffff0000Kill On Sight player detected: |cffffffff"
L["PlayerAddedToIgnoreColored"] = "|cffff0000Added player to Ignore list: |cffffffff"
L["PlayerRemovedFromIgnoreColored"] = "|cff40ff00Removed player from Ignore list: |cffffffff"
L["PlayerAddedToKOSColored"] = "|cffff0000Added player to Kill On Sight list: |cffffffff"
L["PlayerRemovedFromKOSColored"] = "|cff40ff00Removed player from Kill On Sight list: |cffffffff"
L["PlayerDetected"] = "[Spy] Player detected: "
L["KillOnSightDetected"] = "[Spy] Kill On Sight player detected: "
L["Level"] = "Level"
L["LastSeen"] = "Last seen"
L["LessThanOneMinuteAgo"] = "less than a minute ago"
L["MinutesAgo"] = "minutes ago"
L["HoursAgo"] = "hours ago"
L["DaysAgo"] = "days ago"
L["Close"] = "Close"
L["CloseDescription"] = "|cffffffffHides the Spy window. By default will show again when the next enemy player is detected."
L["Left/Right"] = "Left/Right"
L["Left/RightDescription"] = "|cffffffffNavigates between the Nearby, Last Hour, Ignore and Kill On Sight lists."
L["Clear"] = "Clear"
L["ClearDescription"] = "|cffffffffClears the list of players that have been detected. CTRL click will Enable/Disable Spy while displayed."
L["NearbyCount"] = "Nearby Count"
L["NearbyCountDescription"] = "|cffffffffSends the count of nearby players to chat."
L["Statistics"] = "Statistics"
L["StatsDescription"] = "|cffffffffShows a list of enemy players encountered, win/loss records and where they were last seen."
L["AddToIgnoreList"] = "Add to Ignore list"
L["AddToKOSList"] = "Add to Kill On Sight list"
L["RemoveFromIgnoreList"] = "Remove from Ignore list"
L["RemoveFromKOSList"] = "Remove from Kill On Sight list"
L["RemoveFromStatsList"] = "Remove from Statistics List" --++
L["AnnounceDropDownMenu"] = "Announce"
L["KOSReasonDropDownMenu"] = "Set Kill On Sight reason"
L["PartyDropDownMenu"] = "Party"
L["RaidDropDownMenu"] = "Raid"
L["GuildDropDownMenu"] = "Guild"
L["LocalDefenseDropDownMenu"] = "Local Defense"
L["Player"] = " (Player)"
L["KOSReason"] = "Kill On Sight"
L["KOSReasonIndent"] = "    "
L["KOSReasonOther"] = "Enter your own reason..."
L["KOSReasonClear"] = "Clear"
L["StatsWins"] = "|cff40ff00Wins: "
L["StatsSeparator"] = "  "
L["StatsLoses"] = "|cff0070ddLoses: "
L["Located"] = "located:"
L["Yards"] = "yards"

L["Get Census Data"] = "Get Census Data"
L["GetCensusData"] = "Get names of your factions to filter them in player detection."

Spy_KOSReasonListLength = 13
Spy_KOSReasonList = {
	[1] = {
		["title"] = "Started combat";
		["content"] = {
			"Ambushed me",
			"Always attacks me on sight",
			"Attacked me for no reason",
			"Attacked me while fighting mobs",
			"Attacked me while entering/leaving instances",
			"Attacked me while I was AFK",
			"Attacked me while I was mounted/flying",
			"Attacked me while I had low health/mana",
			"Steamrolled me with a group of enemies",
			"Doesn't attack without backup",
			"Dared to challenge me",
		};
	},
	[2] = {
		["title"] = "Style of combat";
		["content"] = {
			"Always calls for help",
			"Pushed me off a cliff",
			"Uses engineering tricks",
			"Uses too much crowd control",
			"Spams one ability all the time",
			"Forced me to take durability damage",
			"Killed me and escaped from my friends",
			"Ran away then ambushed me",
			"Always manages to escape",
			"Bubble hearths to escape",
			"Manages to stay in melee range",
			"Manages to stay at kiting range",
			"Absorbs too much damage",
			"Heals too much",
			"DPS's too much",
		};
	},
	[3] = {
		["title"] = "General behaviour";
		["content"] = {
			"Annoying",
			"Rudeness",
			"Cowardice",
			"Arrogance",
			"Overconfidence",
			"Untrustworthy",
			"Emotes too much",
			"Stalked me/friends",
			"Pretends to be good",
			"Emotes 'not going to happen'",
			"Waves goodbye at low health",
			"Tried to placate me with a wave",
			"Performed foul acts on my corpse",
			"Laughed at me",
			"Spat on me",
		};
	},
	[4] = {
		["title"] = "Camping";
		["content"] = {
			"Camped me",
			"Camped an alt",
			"Camped lowbies",
			"Camped from stealth",
			"Camped guild members",
			"Camped game NPCs/objectives",
			"Called in help to camp me",
			"Made levelling a nightmare",
			"Forced me to logout",
			"Won't fight my main",
		};
	},
	[5] = {
		["title"] = "Questing";
		["content"] = {
			"Attacked me while questing",
			"Attacked me after I helped with a quest",
			"Interfered with quest objectives",
			"Started a quest I wanted to do",
			"Killed my faction's NPCs",
			"Killed a quest NPC",
		};
	},
	[6] = {
		["title"] = "Stole resources";
		["content"] = {
			"Gathered herbs I wanted",
			"Gathered minerals I wanted",
			"Gathered resources I wanted",
			"Extracted gas from a cloud I wanted",
			"Killed me and stole my mob",
			"Skinned my kills",
			"Salvaged my kills",
			"Fished in my pool",
		};
	},
	[7] = {
		["title"] = "Battlegrounds";
		["content"] = {
			"Always loots corpses",
			"Very good flag runner",
			"Backcaps flags or bases",
			"Stealth caps flags or bases",
			"Killed me and took the flag",
			"Interferes with battleground objectives",
			"Took a power-up I wanted",
			"Forced tank to lose agro",
			"Caused a wipe",
			"Destroys siege engines",
			"Drops bombs",
			"Disarms bombs",
			"Fear bomber",
		};
	},
	[8] = {
		["title"] = "Real life";
		["content"] = {
			"Friend in real life",
			"Enemy in real life",
			"Spreads rumours about me",
			"Complains on the forums",
			"Spy for the other faction",
			"Traitor to my faction",
			"Reneged on a deal",
			"Pretentious nub",
			"Another know-it-all",
			"Another Johnny-come-lately",
			"Cross faction trash talker",
		};
	},
	[9] = {
		["title"] = "Difficulty";
		["content"] = {
			"Impossible to kill",
			"Wins most of the time",
			"Seems like a fair match",
			"Loses most of the time",
			"Fun to kill",
			"Easy honor",
		};
	},
	[10] = {
		["title"] = "Race";
		["content"] = {
			"Hate the player's race",
			"Blood Elves are narcissistic",
			"Draenei are slimy space squids",
			"Dwarves are short hairy doorstops",
			"Gnomes belong in a garden",
			"Humans are righteous busybodies",
			"Night Elves hug too many trees",
			"Orcs are warmongering barbarians",
			"Tauren should be on my burger",
			"Trolls should stay on web forums",
			"Undead are unnatural abominations",
		};
	},
	[11] = {
		["title"] = "Class";
		["content"] = {
			"Hate the player's class",
			"Death Knights are overpowered",
			"Druids are dirty animals",
			"Hunters are easy mode",
			"Mages are deluded intellects",
			"Paladins are sanctimonious fools",
			"Priests are pious preachers",
			"Rogues have no honor",
			"Shamans talk to imaginary animals",
			"Warlocks are necromantic sadists",
			"Warriors have anger issues",
		};
	},
	[12] = {
		["title"] = "Name";
		["content"] = {
			"Has a ridiculous name",
			"Pretentious name",
			"Variant of Legolas",
			"Name has weird characters",
			"Guild name is ridiculous",
			"Guild name uses only capital letters",
			"Guild name uses capital letters and spaces",
			"Guild name states they hate my faction",
		};
	},
	[13] = {
		["title"] = "Other";
		["content"] = {
			"Karma",
			"Red is dead",
			"Just because",
			"Fails at PvP",
			"Flagged for PvP",
			"Doesn't want to PvP",
			"Wastes both our time",
			"This player is a noob",
			"I really hate this player",
			"Doesn't level fast enough",
			"Exploits game mechanics",
			"Suspected hacker",
			"Farmer",
			"Enter your own reason...",
		};
	},
}

StaticPopupDialogs["Spy_SetKOSReasonOther"] = {
	text = "Enter the Kill On Sight reason for %s:",
	button1 = "Set",
	button2 = "Cancel",
	timeout = 0,
	hasEditBox = 1,
	whileDead = 1,
	hideOnEscape = 1,
	OnShow = function()
		getglobal(this:GetName() .. "EditBox"):SetText("");
	end,
	OnAccept = function()
		local reason = getglobal(this:GetParent():GetName() .. "EditBox"):GetText()
		Spy:SetKOSReason(this:GetParent().playerName, "Enter your own reason...", reason)
	end,
};

Spy_IgnoreList = {}