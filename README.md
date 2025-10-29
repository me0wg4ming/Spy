Spy - SuperWoW Edition
Version: 3.9.3 + SuperWoW Integration
Author: Immolation (Original), laytya (Port), SuperWoW Integration
For: World of Warcraft 1.12.1 (Vanilla)

🚀 What's New in Version 3.9.3?
Major Features:

✅ SuperWoW Integration - GUID-based player detection (REQUIRED)
✅ Proactive Detection - Finds enemies BEFORE they attack you
✅ Advanced Stealth Detection - Multiple methods including UNIT_CASTEVENT
✅ Stealth-Only Mode - Detect stealthed players even when Spy is disabled
✅ Real Level Data - No more guessing, SuperWoW provides exact values
✅ Nearby Counter - Visual display of active enemies
✅ Announce Button - Quick announce to party/raid/say
✅ Statistics Overhaul - Redesigned stats window with improved filtering
✅ Window Size Optimization - Better scaling and auto-resize options
✅ Unlimited Range Detection - As far as you can see enemies
✅ Instant Enable/Disable - No reload required
✅ Goblin & High Elf Support - Added missing races for custom servers
✅ Profile System - Proper profile loading without errors
✅ Advanced Filter System - Search by name/guild in Statistics
✅ Always Clear Option - Automatic nearby list cleanup
✅ Ignore List Protection - Ignored players won't trigger detection

Performance Improvements:

🔧 Cleaned up unused TBC/WotLK features
🔧 Removed non-functional Vanilla features (map notes, KoS button on target frame)
🔧 Optimized GUID scanning (0.5s interval)
🔧 Better pet filtering to prevent false detections
🔧 Efficient memory usage with automatic cleanup


⚠️ CRITICAL: SuperWoW is REQUIRED
Without SuperWoW, Spy will NOT function!
Why SuperWoW is Mandatory:
❌ Without SuperWoW → Spy automatically DISABLES itself on login
✅ With SuperWoW → Full GUID-based detection like ShaguScan
SuperWoW Download: https://github.com/balakethelock/SuperWoW

📦 Installation
Prerequisites:

World of Warcraft 1.12.1 (Vanilla)
SuperWoW 1.12.1+ (MANDATORY)

Installation Steps:

Backup/Remove old Spy:
Interface/AddOns/Spy → Interface/AddOns/Spy_OLD
```

2. **Extract Spy-SuperWoW to:**
```
Interface/AddOns/Spy/
```

3. **Start WoW** → Done!

### First Login Check:

✅ **[SpySW] SuperWoW DETECTED ✓** → Spy is fully functional  
❌ **[Spy] CRITICAL ERROR: SuperWoW NOT DETECTED!** → Spy is disabled

---

## 🎮 Commands & Usage

### Basic Commands:
- `/spy` - Toggle Spy window
- `/spy show` - Show Spy window
- `/spy hide` - Hide Spy window
- `/spy config` - Open settings
- `/spy reset` - Reset window positions
- `/spy clear` - Clear nearby list
- `/spy stats` - Open statistics window
- `/spy kos <name>` - Toggle KoS for player
- `/spy ignore <name>` - Toggle ignore for player

### SuperWoW Debug Commands:
- `/spystatus` - Show SuperWoW status and statistics
- `/spydebug` - Toggle debug mode (shows detection events)
- `/spyevent` - Toggle cast event logging (developer tool)
- `/spybuff` - Test buff detection methods (developer tool)
- `/spypet` - Test pet detection (developer tool)
- `/spytarget` - Test targeting methods (developer tool)

### Keyboard Shortcuts:

**In Nearby List:**
- **Left-Click** → Target player (GUID-based, works out of range!)
- **Shift + Left-Click** → Toggle KoS
- **Ctrl + Left-Click** → Toggle Ignore
- **Right-Click** → Open context menu

**Title Bar:**
- **Alt + Mouse Wheel** → Switch between lists (Nearby/Last Hour/Ignore/KoS)
- **Shift-Click Clear Button** → Toggle sound on/off
- **Ctrl-Click Clear Button** → Toggle Spy on/off

---

## 🔍 Detection Features

### 1. **Proactive Scanning (SuperWoW)**
- Scans for nearby enemy players every 0.5 seconds
- Works WITHOUT combat - finds idle/stealthed players
- GUID-based tracking for accuracy

### 2. **Stealth Detection (Multiple Methods)**

**Method A: Buff Scanning**
- Scans target buffs via Tooltip Scanner
- Detects: Stealth, Prowl, Shadowmeld, Vanish
- Works in all languages (EN/DE patterns)

**Method B: UNIT_CASTEVENT**
- **NEW in 3.9.3!**
- Instant detection when stealth is cast
- Tracks spell IDs: 1784-1787 (Stealth), 5215/6783/9913 (Prowl), 20580 (Shadowmeld), 1856/1857 (Vanish)
- Triggers alert immediately, doesn't wait for buff scan

**Method C: Stealth-Only Mode**
- Enable: `WarnOnStealthEvenIfDisabled = true`
- Detects stealthed players even when Spy is disabled
- Only processes Rogues, Druids, Night Elves
- Perfect for battlegrounds/instances where you want Spy off but still want stealth alerts

### 3. **Smart Filtering**
- ✅ Only tracks: Players + Hostile + PvP Flagged + Alive
- ✅ Ignores: Friendlies, Pets, NPCs, Same-Faction (even in duels)
- ✅ Separate caches for enemies/friendlies
- ✅ Automatic pet detection via class check + UnitPlayerControlled

### 4. **Zone-Based Control**
- Auto-disable in sanctuaries (Booty Bay, Gadgetzan, Everlook, Ratchet, etc.)
- Battleground support (enable/disable via settings)
- PvP flag requirement option
- Taxi mode (stop alerts while on flight paths)

---

## 📊 Statistics Window

### Features:
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

### Keyboard Shortcuts:
- **Shift-Click Spy button** → Open/close statistics

---

## ⚙️ Configuration Options

### General Settings:
- **Enable Spy** - Master on/off switch (instant, no reload!)
- **Enabled in Battlegrounds** - Allow detection in BGs
- **Disable When PvP Unflagged** - Only detect when flagged
- **Disabled in Zones** - Select sanctuary zones
- **Show on Detection** - Auto-show window when enemy detected
- **Hide Spy** - Auto-hide when no enemies nearby
- **Stop Alerts on Taxi** - Pause alerts while flying

### Display Options:
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

### Alert Options:
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

### Map Options:
- **Minimap Detection** - Scan minimap tooltips (legacy feature)
- **Minimap Details** - Show class/level in tooltips

### Data Management:
- **Remove Undetected** - Auto-cleanup timer: Always/1-15 min/Never
- **Purge Data** - Old data cleanup: 1-90 days
- **Purge KoS** - Include KoS in purge
- **Purge Win/Loss Data** - Include combat stats in purge
- **Share Data** - Send detections to other Spy users
- **Use Data** - Receive detections from others
- **Share KoS Between Characters** - Sync KoS across your account

---

## 🎯 KoS (Kill on Sight) System

### Managing KoS Players:
- **Add to KoS:** `/spy kos <name>` or Shift-Click in list
- **Remove from KoS:** Same command/click again
- **Set Reason:** Right-click player → KoS Reason menu
- **Custom Reason:** Select "Other" and type reason

### KoS Features:
- 🔴 Red border alert for KoS players
- 🟡 Yellow border for KoS guild members
- 📢 Announce KoS detections to party/raid
- 🎵 Special sound for KoS alerts
- 📝 Multiple reasons per player
- 🔄 Cross-character KoS sharing
- 📊 KoS tab in statistics window

### Ignore List:
- **Add to Ignore:** `/spy ignore <name>` or Ctrl-Click in list
- **Effect:** Completely blocks detection for that player
- **Use Cases:** Friendly enemy players, RPers, etc.

---

## 🔧 Technical Details

### How SuperWoW Integration Works:

**1. GUID Collection:**
- Events: UPDATE_MOUSEOVER_UNIT, PLAYER_TARGET_CHANGED, UNIT_COMBAT, etc.
- Stores GUIDs of all players encountered
- Name-to-GUID mapping for targeting

**2. Scanning System:**
- Interval: 0.5 seconds (configurable)
- Filter: IsPlayer + IsHostile + IsPvPFlagged + IsAlive
- Cleanup: Every 5 seconds (removes non-existent GUIDs)

**3. Data Extraction:**
- Level (exact, no guessing!)
- Class & Race
- Guild
- Stealth status (via buff scanning)
- Faction (for duel detection)

**4. Stealth Detection:**
- Buff scanning with Tooltip Scanner (works with GUIDs!)
- UNIT_CASTEVENT for instant detection
- Multi-language support (EN/DE patterns)
- Same-faction filtering (no duel alerts)

### Performance:
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

---

### Problem: SuperWoW not detected

**Symptoms:**
- Error message on login
- `/spystatus` shows "NOT AVAILABLE"

**Fix:**
1. Verify SuperWoW installation: https://github.com/balakethelock/SuperWoW
2. Check for SuperWoW DLL in WoW folder
3. Test with other SuperWoW addons (ShaguQuest, pfUI)
4. Reinstall SuperWoW

---

### Problem: Too many detections / Spam

**Causes:**
- Debug mode active
- Low scan interval

**Fix:**
1. `/spydebug` - Disable debug mode
2. Edit `SpySuperWoW.lua` line ~85: `SpySW.SCAN_INTERVAL = 1.0` (default: 0.5)

---

### Problem: Stealth not detected

**Check:**
1. Target enemy player
2. `/spybuff` - Test buff detection
3. Check which methods work
4. Enable debug: `/spydebug`

**Note:** Tooltip Scanner (Method 8) should work best with SuperWoW

---

### Problem: Error on profile switch

**Symptoms:**
- Lua error when changing profiles
- "attempt to index nil value"

**Fix:**
- Fixed in 3.9.3! Profile system now works correctly
- If still happening, `/reload` after profile change

---

### Problem: Players not targetable

**Symptoms:**
- Click doesn't target
- "Cannot target" in debug

**Check:**
1. SuperWoW installed? (GUID targeting requires it)
2. Player out of range? (SuperWoW can target further than normal)
3. Enable debug: `/spydebug` and check GUID tracking

---

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
Tracked GUIDs: 45
  Enemies: 12  Friendlies: 33
Statistics:
  GUIDs Collected: 156
  Events Processed: 2341
  Scans Performed: 678
  Players Detected: 23
  Pets Skipped: 89
Settings:
  Scan Interval: 0.5s
  Cleanup Interval: 5s
Spy Status:
  Enabled: true
  Enabled in Zone: true
======================================

🎨 Features Summary
Core Features:
✅ GUID-based player detection (SuperWoW)
✅ Proactive scanning (finds idle enemies)
✅ Advanced stealth detection (3 methods)
✅ Stealth-only mode (works when Spy disabled)
✅ Real level data (no guessing)
✅ Nearby counter with visual indicator
✅ Quick announce button (say/party/raid)
✅ Win/Loss tracking (PvP statistics)
✅ KoS system with reasons
✅ Ignore list
✅ Cross-character KoS sharing
✅ Advanced statistics window
✅ Real-time filtering (name/guild)
✅ Auto-resize window
✅ Smart pet filtering
✅ Zone-based control
✅ Battleground support
✅ Profile system
✅ Minimap icon (LDB)
✅ Unlimited range targeting
✅ Instant enable/disable
Removed Features (Not Working in Vanilla):
❌ Map display (requires TBC+ API)
❌ KoS button on target frame (no target frame API)
❌ Astrolabe integration (TBC+ library)

💡 Tips & Tricks
Optimal Settings:

Scan Interval: 0.5s for fast detection, 1.0s for low-end PCs
Debug Mode: OFF except for testing
Auto-Resize: ON for dynamic window size
Stealth-Only Mode: Great for instances/BGs where you want Spy off

Performance Optimization:

High player density (>100): Increase scan interval to 1.0s
During raids: Turn off debug mode
Low FPS: Increase scan interval + disable auto-resize

Stealth Detection:

Best Method: UNIT_CASTEVENT (instant, no delay)
Backup: Buff scanning (0.5s delay)
Most Reliable: Both enabled (default)

Targeting Out-of-Range Players:

SuperWoW allows targeting beyond normal range
Click player in list, even if they're far away
GUID-based targeting works as long as they were detected once


🤝 Credits

Immolation - Original Spy addon (TBC/WotLK)
laytya - Vanilla 1.12.1 port
Shagu - ShaguScan (inspiration for GUID system)
SuperWoW Team - SuperWoW framework
pfUI Team - Tooltip scanning techniques
Community - Bug reports and feature suggestions


📄 License
Same as original Spy addon - free to use and modify.

🆘 Support
For Issues:

Check /spystatus - Is SuperWoW detected?
Enable /spydebug - What errors appear?
Try /spybuff on enemy player - Does stealth detection work?
Verify SuperWoW installation
Check WoW folder for SuperWoW DLL
Create GitHub issue (if available) with error details

Common Questions:
Q: Can I use Spy without SuperWoW?
A: No, SuperWoW is mandatory. Spy will auto-disable without it.
Q: Why can't I target players by clicking?
A: SuperWoW must be installed for GUID-based targeting.
Q: Does Spy work on private servers?
A: Yes, fully compatible with Vanilla 1.12.1 servers.
Q: Can I import KoS lists from old Spy?
A: Yes, KoS data is preserved when updating.
Q: Why do I see pets in my list?
A: Fixed in 3.9.3, update to latest version.

🎯 Final Notes
Remember:

⚠️ SuperWoW is REQUIRED - No exceptions!
🔍 Spy detects enemies automatically, no action needed
🎵 Adjust sound settings to your preference
📊 Use statistics to track rivals
🔴 Mark dangerous players as KoS
⚪ Ignore friendly enemies
🐛 Report bugs with /spystatus output

Have fun hunting in Azeroth! 🗡️

Version: 3.9.3 (2025)
Compatibility: World of Warcraft 1.12.1 (Vanilla)
Requirement: SuperWoW 1.12.1+
Status: Stable & Production-Ready