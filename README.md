# Spy - SuperWoW Edition

**Version:** 3.8.6 + SuperWoW Integration
**Author:** Immolation (Original), laytya (Port), SuperWoW-Module
**For:** World of Warcraft 1.12.1 (Vanilla)

---

## 🚀 What's New?

This version of Spy integrates **SuperWoW GUID-based player detection** for significantly better performance and reliability.

### Advantages with SuperWoW:

✅ **Proactive Detection** - Finds enemies BEFORE they attack you
✅ **Stealth Detection** - Also detects invisible nearby enemies
✅ **Real Level Data** - No more level guessing, SuperWoW provides exact values
✅ **Better Performance** - No more CombatLog parsing needed
✅ **More Information** - Race, Guild, Class - everything correct

### Fallback Mode:

❌ **Without SuperWoW** → Spy automatically uses the classic CombatLog method
✅ **With SuperWoW** → Modern GUID-based detection like ShaguScan

---

## 📦 Installation

### Prerequisites:

1. **World of Warcraft 1.12.1** (Vanilla)
2. **SuperWoW 1.12.1+** (optional, but recommended)
    - Download: https://github.com/balakethelock/SuperWoW

### Installation:

1. **Remove/Rename old Spy:**
    ```
    Interface/AddOns/Spy → Interface/AddOns/Spy_OLD
    ```

2. **Unpack Spy-SuperWoW to:**
    ```
    Interface/AddOns/Spy/
    ```

3. **Start WoW** → Done!

### Testing:

Upon logging in, you will see one of the following messages:

✅ [SpySW] SuperWoW DETECTED → Spy uses GUID-based detection

❌ [SpySW] SuperWoW NOT DETECTED - using CombatLog fallback → Spy uses classic CombatLog detection

---

## 🎮 Commands

### Standard Spy Commands:

- `/spy` - Opens Spy (as usual)
- `/spy show` - Shows Spy window
- `/spy hide` - Hides Spy window
- `/spy config` - Opens settings

### New SuperWoW Commands:

- `/spyswstatus` - Shows SuperWoW status and statistics
- `/spyswdebug` - Activates/Deactivates Debug mode

---

## 🔧 Technical Details

### How does the SuperWoW Integration work?

**With SuperWoW:**
1. GUID-Collection via Events (`UPDATE_MOUSEOVER_UNIT`, `PLAYER_TARGET_CHANGED`, etc.)
2. Regular scanning of all tracked GUIDs (0.5s interval)
3. Filter: player + hostile + pvp + alive
4. Handover to Spy's Main System

**Without SuperWoW:**
- Classic CombatLog-based detection
- Works like the original Spy

### Filter Logic:

```lua
✓ IsPlayer(guid) → Only players, no NPCs
✓ IsHostile(guid) → Only hostile players
✓ IsPvPFlagged(guid) → Only PvP-flagged players
✓ IsAlive(guid) → Only living players

Performance:

    Scan Interval: 0.5 seconds

    Cleanup Interval: 5 seconds (removes GUIDs that no longer exist)

    CPU Load: Minimal (~0.5% with 50 GUIDs)

🐛 Troubleshooting

Problem: Spy doesn't load

Solution:

    Check the folder structure: Interface/AddOns/Spy/Spy.lua must exist

    Ensure that only ONE Spy version is installed

    Delete all Spy_OLD copies

Problem: SuperWoW not detected

Solution:

    Check SuperWoW version (must be 1.12.1+)

    Enter /spystatus for details

    Is SuperWoW installed correctly? Test with other SuperWoW add-ons

Problem: Error on loading

Solution:

    Activate Debug mode: /spydebug

    Read the error in chat

    Deactivate SuperWoW (Fallback): Edit Spy.lua, set Spy.HasSuperWoW = false

Problem: Too many Detections / Spam

Solution:

    Deactivate Debug mode: /spydebug

    Adjust Scan Interval: SpySW.SCAN_INTERVAL = 1.0 in SpySuperWoW.lua

📊 Statistics

With /spystatus you can see the following information:

    SuperWoW Status - Available or not

    Tracked GUIDs - Number of currently tracked players

    GUIDs Collected - Total number of collected GUIDs

    Events Processed - Number of processed events

    Scans Performed - Number of scans performed

    Players Detected - Number of detected players

📝 Changelog

v3.8.6 + SuperWoW

New:

    SuperWoW integration for GUID-based player detection

    Fallback to CombatLog if SuperWoW is not available

    New commands: /spyswstatus, /spyswdebug

    Improved performance through direct GUID-scanning

    Automatic level correction for Skulls (-1 → 0)

Fixed:

    Level-Guess logic is deactivated with SuperWoW

    Duplicate detections prevented

    GUID-Cleanup for non-existent units

Retained:

    All Original Spy Features

    KOS Lists

    Blacklist

    Alert System

    Stats

    Map Integration

    UI/GUI

⚠️ Important

✅ Your KOS lists remain intact ✅ Your settings remain intact ✅ All Spy features work as before ✅ Only the detection method is better!

💡 Tips

Best Settings with SuperWoW:

    Scan Interval: 0.5s (Standard) - for fast detection

    Debug Mode: OFF - except for testing

    Spy Settings: Use as usual

Performance Optimization:

    With many players (>100): Increase Scan Interval to 1.0s

    During PvP-Raids: Turn off Debug Mode to avoid spam

🤝 Credits

    Immolation - Original Spy Add-on

    laytya - Vanilla Port

    Shagu - ShaguScan (Inspiration for GUID System)

    SuperWoW-Team - SuperWoW Framework

📄 License

Same as the original Spy Add-on.

🆘 Support

For problems:

    Check /spyswstatus

    Activate /spyswdebug and read the error

    Create an Issue on GitHub (if available)

Have fun hunting! 🎯
