# Spy - SuperWoW Edition

[![Version](https://img.shields.io/badge/version-4.1.0-blue.svg)](https://github.com/me0wg4ming/Spy)
[![WoW](https://img.shields.io/badge/WoW-1.12.1%20Vanilla-orange.svg)](#)
[![SuperWoW](https://img.shields.io/badge/SuperWoW-Required-red.svg)](https://github.com/balakethelock/SuperWoW)

**Enhanced enemy detection addon for World of Warcraft 1.12.1 (Vanilla)**

---

## 📑 Quick Links

- [Installation](#-installation)
- [Commands & Usage](#-commands--usage)
- [Detection Features](#-detection-features)
- [Configuration Options](#️-configuration-options)
- [KoS System](#-kos-kill-on-sight-system)
- [Troubleshooting](#️-troubleshooting)
- [Support](#-support)

---

## 🚀 What's New in Version 4.1.0 (December 13, 2025)
- ✅ **Massive Performance Fix for Large Battles** - Optimized for 200+ player fights (e.g., 200 Horde vs 200 Alliance)
- ✅ **Friendly Units Skip** - Friendly players completely ignored (no tracking, no caching) = 50% less GUIDs tracked in faction battles
- ✅ **Combat Log Throttling** - Limited to 20 events/sec instead of 500+, reducing pattern matching by 95%
- ✅ **Stealth Detection Optimization** - Buff scanning only for stealth-capable classes (Rogue/Druid/Night Elf) = 80% fewer buff checks
- ✅ **Scan Interval Increased** - Changed from 0.5s to 1.0s for 50% less CPU usage during scanning
- ✅ **Debug Mode Caching** - Cached debug mode setting to eliminate repeated table lookups

**Performance Impact:** In 400-player battles (200v200), tracking reduced from 400 to 200 GUIDs, buff checks reduced by 95%, and pattern matching reduced by 95%. Should eliminate lag in massive world PvP scenarios.

---

## 🚀 What's New in Version 4.0.8 (December 10, 2025)
- ✅ **Timer Leak Fix** - Fixed AceTimer leak that caused "146 live timers" warning after multiple enable/disable cycles or zone changes
- ✅ **Removed Duplicate Timer** - Removed redundant ManageExpirations timer in MainWindow.lua that was never cancelled

**Technical Details:** Previously, each call to `OnEnable()` (via `/spy show`, options toggle, or `ResetMainWindow()`) created a new repeating timer without cancelling the old one. This caused timer accumulation over time, especially for players frequently entering/leaving battlegrounds.

---

## 🚀 What's New in Version 4.0.7 (December 4, 2025)
- ✅ **Major Performance Fix** - Fixed massive lag spikes when 80+ enemies are detected with "Sort by Range" enabled
- ✅ **Distance Display Toggle** - Added on/off toggle in Data Management to completely disable distance tracking for maximum performance
- ✅ **Configurable Update Rate** - Added slider (1-5 Hz) to control how often distance values update, allowing players to balance smoothness vs CPU usage
- ✅ **Lazy Distance Caching** - Distance sorting now uses pre-calculated cache instead of calling expensive UnitXP() during sort operations
- ✅ **Optimized Cache System** - Global distance cache updates in background for ALL detected players, eliminating sort-time calculations

**Performance Impact:** With 80 detected enemies, sorting by range no longer causes lag spikes. Distance display can now be toggled off entirely for extreme cases.

---

## 🚀 What's New in Version 4.0.5 (November 25, 2025)
- ✅ Fixed shared scans missing out on specific classes or races.
- ✅ Fixed players changing their PvP state to non-pvp to still show the range update on nearby frame.
- ✅Several performance improvements for the frames.
- ✅ Data Management rework, added a slider to let the player decide after how many minutes non-detected players are removed from the nearby frame.
<img width="848" height="143" alt="grafik" src="https://github.com/user-attachments/assets/1832b61e-c4e8-4a27-8a1d-1a64c69338e8" />

---

## 🚀 What's New in Version 4.0.2 (November 10, 2025)
- ✅ Fixed shared scans from other Spy users not being shown in the "Statistics" window.:
- ✅ Different Fonts can be properly changed and applied now to the "Nearby" Window.
- ✅ Little fixup for enemy detection logics, no more players from the same faction in the list.
- ✅ Gave the Distance display a black outline.
- ✅ Announce nearby players (right clicking on the nearby player frame) will work properly now in group, raid, localdefense and guild.

---

## 🚀 What's New in Version 4.0.1 (November 6, 2025)
- ✅ LOS Check on Range indicator/numbers:
- 🟢 Green = Line of Sight free → Player can be attacked
- 🔴 Red = Line of Sight blocked → Player can't be attacked
- ⚪ White = Out of range/not found "--" (NO GUID/No available

- ✅ Fixed Player Frames Overlapping when more then 15 Players are in range.)

## 🚀 What's New in Version 4.0.0

### 🆕 Major Features (November 5, 2025)

- ✅ **Complete Rework of Frame System** - Individual persistent frames for each player instead of reusable row pool
- ✅ **Live HP Bars** - Real-time health percentage display with class-colored bars
- ✅ **Improved Click Detection** - Frames no longer hide/show on every refresh, fixing click reliability issues
- ✅ **Frame Persistence** - Each player maintains their own frame, eliminating visual flickering
- ✅ **Sorting Stability** - Uses millisecond-precision DetectionTimestamp instead of second-precision time()

### 🎨 UI Improvements

- ✅ **Minimum Window Width** - Set to 190 pixels (matches default configuration)
- ✅ **Frame Clamping** - Window cannot be dragged outside screen boundaries
- ✅ **Position-Only Updates** - Frames only update position during sorting, not entire frame recreation
- ✅ **Reduced Flickering** - Frames remain visible when player stays in list, only hidden when actually removed

### 🐛 Critical Bugfixes

- ✅ **Click Detection Fixed** - Removed frame hide/show on every refresh that was blocking clicks
- ✅ **OnClick Stability** - OnClick handler set only once during frame creation, not on every refresh
- ✅ **GUID Updates** - PlayerGUID updated intelligently only when invalid or missing
- ✅ **Frame Level Management** - Proper SetFrameLevel to ensure frames are clickable above other UI elements

### 🔧 Technical Changes

- ✅ **PlayerFrames Table** - New persistent frame storage: `Spy.MainWindow.PlayerFrames[playerName]`
- ✅ **OnUpdate HP System** - 0.2s throttled HP updates per frame (similar to ShaguScan)
- ✅ **Smart Frame Hiding** - Only hides frames not in current list, not all frames on every refresh
- ✅ **Removed Legacy Code** - Cleaned up ButtonClicked() function and /spyclick debug command

### 📊 Architecture Changes

**Old System (Row Pool):**
- Fixed number of reusable rows
- Rows constantly reassigned to different players
- RefreshCurrentList() rebuilt entire list 15-35 times/second
- Caused visual flickering and click detection issues

**New System (Persistent Frames):**
- One frame per player, created once
- Frames persist until player leaves list
- Only position updates during sorting
- No flickering, reliable click detection

### 🎯 Performance Optimizations

- ✅ **Reduced Refresh Overhead** - Frames only created once per player, not on every refresh
- ✅ **Throttled HP Updates** - 0.2s update interval prevents excessive processing
- ✅ **Smart GUID Caching** - GUID stored on frame, only refreshed when invalid
- ✅ **Position Caching** - Frame position only updated when actually changed

---

**Version:** 4.0.0  
**Release Date:** November 5, 2025  
**Requirements:** SuperWoW 1.12.1+ (MANDATORY), UnitXP (OPTIONAL for Distance Display)

**⚠️ BREAKING CHANGE:** This version completely rebuilds the frame system. If upgrading from 3.9.6, a `/reload` is recommended after installation.
---

## ⚠️ CRITICAL: SuperWoW is REQUIRED

**Without SuperWoW, Spy will NOT function!**

### Why SuperWoW is Mandatory

- ❌ **Without SuperWoW** → Spy automatically DISABLES itself on login
- ✅ **With SuperWoW** → Full GUID-based detection similar to ShaguScan

### Download UnitXP_SP3

**Official Repository:** [https://codeberg.org/konaka/UnitXP_SP3/releases](https://codeberg.org/konaka/UnitXP_SP3/releases)

### Download SuperWoW

**Official Repository:** [https://github.com/balakethelock/SuperWoW](https://github.com/balakethelock/SuperWoW)

Follow the installation instructions in the SuperWoW repository to set it up correctly.

> **Note:** This Spy version is specifically designed for SuperWoW and will not work with other detection methods. For the best experience, ensure SuperWoW is properly installed before using Spy.

---

## 📦 Installation

### Prerequisites

1. **World of Warcraft 1.12.1** (Vanilla)
2. **SuperWoW 1.12.1+** (MANDATORY) - [Download here](https://github.com/balakethelock/SuperWoW)

### Installation Steps

1. **Backup/Remove old Spy version:**
   ```
   Rename: Interface/AddOns/Spy → Interface/AddOns/Spy_OLD
   ```

2. **Extract this Spy version to:**
   ```
   Interface/AddOns/Spy/
   ```
   Make sure the folder structure is: `Interface/AddOns/Spy/Spy.lua`

3. **Launch World of Warcraft**

### Verify Installation

After logging in, check the chat window:

- ✅ **Success:** `[SpySW] SuperWoW DETECTED ✓` → Spy is fully functional
- ❌ **Error:** `[Spy] CRITICAL ERROR: SuperWoW NOT DETECTED!` → Spy is disabled, install SuperWoW

Type `/spy` to open the main window.

---

## 🎮 Commands & Usage

### Basic Commands

| Command | Description |
|---------|-------------|
| `/spy` | Toggle Spy window |
| `/spy show` | Show Spy window |
| `/spy hide` | Hide Spy window |
| `/spy config` | Open settings |
| `/spy reset` | Reset window positions |
| `/spy clear` | Clear nearby list |
| `/spy stats` | Open statistics window |
| `/spy kos <name>` | Toggle KoS for player |
| `/spy ignore <name>` | Toggle ignore for player |

### SuperWoW Debug Commands

| Command | Description |
|---------|-------------|
| `/spystatus` | Show SuperWoW status and statistics |
| `/spydebug` | Toggle debug mode (shows detection events) |
| `/spyevent` | Toggle cast event logging (developer tool) |
| `/spybuff` | Test buff detection methods (developer tool) |
| `/spypet` | Test pet detection (developer tool) |
| `/spytarget` | Test targeting methods (developer tool) |

### Keyboard Shortcuts

#### In Nearby List

- **Left-Click** → Target player (GUID-based, works out of range!)
- **Shift + Left-Click** → Toggle KoS
- **Ctrl + Left-Click** → Toggle Ignore
- **Right-Click** → Open context menu

#### Title Bar

- **Alt + Mouse Wheel** → Switch between lists (Nearby/Last Hour/Ignore/KoS)
- **Shift-Click Clear Button** → Toggle sound on/off
- **Ctrl-Click Clear Button** → Toggle Spy on/off

---

## 🔍 Detection Features

### 1. Proactive Scanning (SuperWoW)

- Scans for nearby enemy players every 0.5 seconds (this is only for already detected players - new detected players will be scanned instantly)
- Works WITHOUT combat - finds idle/stealthed players
- GUID-based tracking for accuracy

### 2. Stealth Detection (Multiple Methods)

Spy uses three complementary methods to detect stealthed enemies:

#### Method A: Buff Scanning (Tooltip Scanner)
- **How it works:** Scans target's buffs using tooltip analysis
- **Detects:** Stealth, Prowl, Shadowmeld, Vanish
- **Languages:** English and German patterns supported
- **Interval:** Every 0.5 seconds for detected players
- **Advantage:** Works on any targeted enemy

#### Method B: UNIT_CASTEVENT (Instant Detection)
- **How it works:** Listens for stealth spell casts in real-time
- **Detects:** Instant notification when stealth is activated
- **Spell IDs tracked:**
  - Stealth (Rogue): 1784, 1785, 1786, 1787
  - Prowl (Druid): 5215, 6783, 9913
  - Shadowmeld (Night Elf): 20580
  - Vanish (Rogue): 1856, 1857
- **Advantage:** Zero delay, immediate alert

#### Method C: Stealth-Only Mode
- **How it works:** Detects stealthed players even when Spy is disabled
- **Enable:** Set `WarnOnStealthEvenIfDisabled = true` in config
- **Classes filtered:** Only processes Rogues, Druids, and Night Elves
- **Use case:** Perfect for battlegrounds/instances where you want main Spy off but still need stealth alerts
- **Advantage:** Minimal resource usage while maintaining stealth awareness

### 3. Smart Filtering

- ✅ Only tracks: Players + Hostile + PvP Flagged + Alive
- ✅ Ignores: Friendlies, Pets, NPCs, Same-Faction (even in duels)
- ✅ Separate caches for enemies/friendlies
- ✅ Automatic pet detection via class check + UnitPlayerControlled

### 4. Zone-Based Control

- Auto-disable in sanctuaries (Booty Bay, Gadgetzan, Everlook, Ratchet, etc.)
- Battleground support (enable/disable via settings)
- PvP flag requirement option
- Taxi mode (stop alerts while on flight paths)

---

## 📊 Statistics Window

### Features

- **Sort by:** Name, Level, Class, Guild, Wins, Loses, Time
- **Filter Options:**
  - Search by name or guild (real-time)
  - Show only KoS players
  - Show only players with Win/Loss records
  - Show only players with KoS reasons
- **Display Information:**
  - Player name, level, class, guild
  - Win/Loss statistics
  - KoS reasons
  - Last seen location and time
  - List indicator (shows which lists player is on)

### Keyboard Shortcuts

- **Shift-Click Spy button** → Open/close statistics

---

## ⚙️ Configuration Options

### General Settings

- **Enable Spy** - Master on/off switch (instant, no reload!)
- **Enabled in Battlegrounds** - Allow detection in BGs
- **Disable When PvP Unflagged** - Only detect when flagged
- **Disabled in Zones** - Select sanctuary zones
- **Show on Detection** - Auto-show window when enemy detected
- **Hide Spy** - Auto-hide when no enemies nearby
- **Stop Alerts on Taxi** - Pause alerts while flying

### Display Options

- **Window Opacity** - Normal and battleground alpha
- **Lock Windows** - Prevent accidental moving
- **Invert Spy** - Flip window upside-down (title at bottom)
- **Auto-Resize** - Window grows/shrinks with player count
- **Resize Limit** - Maximum bars to display (1-15)
- **Display Data** - Choose what to show in bars (Name/Level/Class/Guild combinations)
- **Font Selection** - Choose from available fonts
- **Bar Texture** - Customize bar appearance
- **Row Height** - Adjust bar size (8-20 pixels)
- **Tooltip Options** - Position, content, anchor point
- **Show Minimap Icon** - Toggle LDB icon visibility

### Alert Options

- **Enable Sound** - Master sound toggle
- **Sound Channel** - Choose audio channel (Master/SFX/Music/Ambience)
- **Only Sound for KoS** - Silence regular detections
- **Stop Alerts on Taxi** - No sounds while flying
- **Announce To** - Auto-announce to: None/Self/Party/Guild/Raid/LocalDefense
- **Only Announce KoS** - Limit announcements
- **Display Warnings** - Alert style: Default/ErrorFrame/Moveable
- **Warn on Stealth** - Alert for stealthed players
- **Warn on Stealth (Even if Disabled)** - **NEW!** Stealth-only mode
- **Warn on KoS** - Alert for KoS players
- **Warn on KoS Guild** - Alert if guild member is KoS
- **Warn on Race** - Alert for specific enemy race

### Map Options

- **Minimap Detection** - Scan minimap tooltips (legacy feature)
- **Minimap Details** - Show class/level in tooltips

### Data Management

- **Remove Undetected** - Auto-cleanup timer: Always/1-15 min/Never
- **Purge Data** - Old data cleanup: 1-90 days
- **Purge KoS** - Include KoS in purge
- **Purge Win/Loss Data** - Include combat stats in purge
- **Share Data** - Send detections to other Spy users
- **Use Data** - Receive detections from others
- **Share KoS Between Characters** - Sync KoS across your account

---

## 🎯 KoS (Kill on Sight) System

### Managing KoS Players

- **Add to KoS:** `/spy kos <name>` or Shift-Click in list
- **Remove from KoS:** Same command/click again
- **Set Reason:** Right-click player → KoS Reason menu
- **Custom Reason:** Select "Other" and type reason

### KoS Features

- 🔴 Red border alert for KoS players
- 🟡 Yellow border for KoS guild members
- 📢 Announce KoS detections to party/raid
- 🎵 Special sound for KoS alerts
- 📝 Multiple reasons per player
- 🔄 Cross-character KoS sharing
- 📊 KoS tab in statistics window

### Ignore List

- **Add to Ignore:** `/spy ignore <name>` or Ctrl-Click in list
- **Effect:** Completely blocks detection for that player
- **Use Cases:** Friendly enemy players, RPers, etc.

---

## 🔧 Technical Details

### How SuperWoW Integration Works

#### 1. GUID Collection
- Events: UPDATE_MOUSEOVER_UNIT, PLAYER_TARGET_CHANGED, UNIT_COMBAT, etc.
- Stores GUIDs of all players encountered
- Name-to-GUID mapping for targeting

#### 2. Scanning System
- Interval: 0.5 seconds (configurable)
- Filter: IsPlayer + IsHostile + IsPvPFlagged + IsAlive
- Cleanup: Every 5 seconds (removes non-existent GUIDs)

#### 3. Data Extraction
- Level (exact, no guessing!)
- Class & Race
- Guild
- Stealth status (via buff scanning)
- Faction (for duel detection)

#### 4. Stealth Detection
- Buff scanning with Tooltip Scanner (works with GUIDs!)
- UNIT_CASTEVENT for instant detection
- Multi-language support (EN/DE patterns)
- Same-faction filtering (no duel alerts)

### Performance

- **Scan Interval:** 0.5s (500ms)
- **CPU Load:** ~0.5% with 50 tracked GUIDs
- **Memory:** Minimal, automatic cleanup
- **Pet Filtering:** Intelligent class + UnitPlayerControlled check

---

## 🛠️ Troubleshooting

### Problem: Spy doesn't load

**Check:**
1. Folder structure: `Interface/AddOns/Spy/Spy.lua` must exist
2. Only ONE Spy version installed
3. Delete `Spy_OLD` copies

**Fix:**
```
Delete Interface/AddOns/Spy*
Extract fresh Spy-SuperWoW.zip
```

### Problem: SuperWoW not detected

**Symptoms:**
- Error message on login
- `/spystatus` shows "NOT AVAILABLE"

**Fix:**
1. Verify SuperWoW installation: https://github.com/balakethelock/SuperWoW
2. Check for SuperWoW DLL in WoW folder
3. Test with other SuperWoW addons (ShaguQuest, pfUI)
4. Reinstall SuperWoW

### Problem: Too many detections / Spam

**Causes:**
- Debug mode active
- Low scan interval

**Fix:**
1. `/spydebug` - Disable debug mode
2. Edit `SpySuperWoW.lua` line ~85: `SpySW.SCAN_INTERVAL = 1.0` (default: 0.5)

### Problem: Stealth not detected

**Check:**
1. Target enemy player
2. `/spybuff` - Test buff detection
3. Check which methods work
4. Enable debug: `/spydebug`

**Note:** Tooltip Scanner (Method 8) should work best with SuperWoW

### Problem: Error on profile switch

**Symptoms:**
- Lua error when changing profiles
- "attempt to index nil value"

**Fix:**
- Fixed in 3.9.3! Profile system now works correctly
- If still happening, `/reload` after profile change

### Problem: Players not targetable

**Symptoms:**
- Click doesn't target
- "Cannot target" in debug

**Check:**
1. SuperWoW installed? (GUID targeting requires it)
2. Player out of range? (SuperWoW can target further than normal)
3. Enable debug: `/spydebug` and check GUID tracking

### Problem: Pets showing as players

**Symptoms:**
- Hunter/Warlock pets in list
- "Wolf" or "Voidwalker" detected

**Status:** Fixed in 3.9.3!
- Dual-check: NOT IsPlayer AND IsPlayerControlled = Pet
- Class verification (pets have no class)
- See debug: "SKIPPED PET: <name>"

---

## 📈 Statistics

**Check with `/spystatus`:**

```
========== SpySuperWoW Status ==========
SuperWoW: AVAILABLE
Spy Mode: SuperWoW Scanning
Tracked GUIDs: 12
  Enemies: 12
Statistics:
  GUIDs Collected: 156
  Events Processed: 2341
  Scans Performed: 678
  Players Detected: 23
  Pets Skipped: 89
Settings:
  Scan Interval: 1.0s
  Cleanup Interval: 5s
Spy Status:
  Enabled: true
  Enabled in Zone: true
========================================
```

---

## 🎨 Features Summary

### Core Features

- ✅ GUID-based player detection (SuperWoW)
- ✅ Proactive scanning (finds idle enemies)
- ✅ Advanced stealth detection (3 methods)
- ✅ Stealth-only mode (works when Spy disabled)
- ✅ Real level data (no guessing)
- ✅ Nearby counter with visual indicator
- ✅ Quick announce button (say/party/raid)
- ✅ Win/Loss tracking (PvP statistics)
- ✅ KoS system with reasons
- ✅ Ignore list
- ✅ Cross-character KoS sharing
- ✅ Advanced statistics window
- ✅ Real-time filtering (name/guild)
- ✅ Auto-resize window
- ✅ Smart pet filtering
- ✅ Zone-based control
- ✅ Battleground support
- ✅ Profile system
- ✅ Minimap icon (LDB)
- ✅ Unlimited range targeting
- ✅ Instant enable/disable

### Removed Features (Not Working in Vanilla)

- ❌ Map display (requires TBC+ API)
- ❌ KoS button on target frame (no target frame API)
- ❌ Astrolabe integration (TBC+ library)

---

## 💡 Tips & Tricks

### Optimal Settings

- **Scan Interval:** 1.0s (default in v4.1.0) - perfect balance of detection speed and performance
- **Debug Mode:** OFF except for testing
- **Auto-Resize:** ON for dynamic window size
- **Stealth-Only Mode:** Great for instances/BGs where you want Spy off

### Performance Optimization

- **Large battles (200+ players):** Version 4.1.0 is specifically optimized for this - no further tuning needed
- **High player density (>100):** Scan interval already at 1.0s (optimal balance)
- **During raids:** Turn off debug mode
- **Low FPS:** Consider increasing scan interval to 2.0s in `SpySuperWoW.lua` line 87

### Stealth Detection

- **Best Method:** UNIT_CASTEVENT (instant, no delay)
- **Backup:** Buff scanning (0.5s delay)
- **Most Reliable:** Both enabled (default)

### Targeting Out-of-Range Players

- SuperWoW allows targeting beyond normal range
- Click player in list, even if they're far away
- GUID-based targeting works as long as they were detected once

---

## 🤝 Credits & Acknowledgments

- **Immolation** - Original Spy addon creator (TBC/WotLK)
- **laytya** - Vanilla 1.12.1 port and maintenance
- **me0wg4ming** - SuperWoW integration and enhancements
- **Shagu** - ShaguScan inspiration for GUID-based detection system
- **SuperWoW Team** - SuperWoW framework development
- **Shagu** - pfUI tooltip scanning techniques
- **Abstr4ctz** - ModernSpellAlert cast event scanning techniques
- **Community** - Bug reports, feature suggestions, and testing

### Special Thanks

- All players who provided feedback and bug reports
- Private server communities for testing support
- Contributors to the Vanilla WoW addon development scene

---

## 📄 License

Same as original Spy addon - free to use and modify.

---

## 🆘 Support

### Getting Help

1. **Check `/spystatus`** - Verify SuperWoW is detected
2. **Enable `/spydebug`** - See what errors appear in chat
3. **Test `/spybuff`** on enemy player - Verify stealth detection
4. **Verify SuperWoW installation** - Check for DLL in WoW folder
5. **Visit GitHub** - Check for known issues or create a new one
   - Repository: https://github.com/me0wg4ming/Spy
   - Issues: https://github.com/me0wg4ming/Spy/issues

### Providing Useful Bug Reports

When reporting issues, please include:
- SuperWoW version
- WoW client version (1.12.1)
- Output of `/spystatus`
- Error message from `/spydebug` (if any)
- Steps to reproduce the issue
- Screenshots (if applicable)

### Common Questions

**Q: Can I use Spy without SuperWoW?**  
A: No, SuperWoW is mandatory. Spy will auto-disable without it.

**Q: Why can't I target players by clicking?**  
A: SuperWoW must be installed for GUID-based targeting.

**Q: Does Spy work on private servers?**  
A: Yes, fully compatible with Vanilla 1.12.1 servers.

**Q: Can I import KoS lists from old Spy?**  
A: Yes, KoS data is preserved when updating.

**Q: Why do I see pets in my list?**  
A: Fixed in 3.9.3, update to latest version.

---

## 🎯 Final Notes

### Remember

- ⚠️ SuperWoW is REQUIRED - No exceptions!
- 🔍 Spy detects enemies automatically, no action needed
- 🎵 Adjust sound settings to your preference
- 📊 Use statistics to track rivals
- 🔴 Mark dangerous players as KoS
- ⚪ Ignore friendly enemies
- 🐛 Report bugs with `/spystatus` output

**Have fun hunting in Azeroth!** 🗡️

---

## 📌 Links

- **GitHub Repository:** https://github.com/me0wg4ming/Spy
- **SuperWoW:** https://github.com/balakethelock/SuperWoW
- **Report Issues:** https://github.com/me0wg4ming/Spy/issues

---

**Version:** 4.1.0  
**Release Date:** December 13, 2025  
**Compatibility:** World of Warcraft 1.12.1 (Vanilla)  
**Requirement:** SuperWoW 1.12.1+  
**Status:** Stable & Production-Ready (Optimized for Large Battles)  
**License:** Free to use and modify
