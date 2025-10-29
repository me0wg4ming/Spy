# Spy - SuperWoW Edition

**Version:** 3.9.1 + SuperWoW Integration
**Author:** Immolation (Original), laytya (Port), SuperWoW-Module
**For:** World of Warcraft 1.12.1 (Vanilla)

---

## 🚀 What's New?

This version of Spy **requires SuperWoW** for GUID-based player detection. Without SuperWoW, the addon will not function.

### Advantages with SuperWoW:

✅ **Proactive Detection** - Finds enemies BEFORE they attack you
✅ **Stealth Detection** - Detects invisible nearby enemies
✅ **Real Level Data** - No more level guessing, SuperWoW provides exact values
✅ **Better Performance** - Direct GUID scanning without string parsing
✅ **More Information** - Race, Guild, Class - everything accurate

### ⚠️ IMPORTANT:

❌ **Without SuperWoW** → Spy will automatically DISABLE itself on login
✅ **With SuperWoW** → Full GUID-based detection like ShaguScan

**SuperWoW is mandatory - there is no fallback mode!**

---

## 📦 Installation

### Prerequisites:

1. **World of Warcraft 1.12.1** (Vanilla)
2. **SuperWoW 1.12.1+** (**REQUIRED**)
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

✅ **[SpySW] SuperWoW DETECTED ✓** → Spy is fully functional

❌ **[Spy] CRITICAL ERROR: SuperWoW NOT DETECTED!** → Spy has been disabled

---

## 🎮 Commands

### Standard Spy Commands:

- `/spy` - Opens Spy (as usual)
- `/spy show` - Shows Spy window
- `/spy hide` - Hides Spy window
- `/spy config` - Opens settings

### SuperWoW Commands:

- `/spystatus` - Shows SuperWoW status and statistics
- `/spydebug` - Activates/Deactivates Debug mode
- `/spybuff` - Tests buff detection methods (for developers)
- `/spypet` - Tests pet detection (for developers)
- `/spytarget` - Tests targeting methods (for developers)

---

## 🔧 Technical Details

### How does the SuperWoW Integration work?

**Detection System:**
1. GUID Collection via Events (`UPDATE_MOUSEOVER_UNIT`, `PLAYER_TARGET_CHANGED`, etc.)
2. Regular scanning of all tracked GUIDs (0.5s interval)
3. Filter: player + hostile + pvp + alive
4. Handover to Spy's Main System

**Win/Loss Tracking:**
- RAW_COMBATLOG event for direct combat log parsing
- Minimal CombatLog events for death tracking
- LastAttack tracking with GUID-to-name resolution

### Filter Logic:
```lua
✓ IsPlayer(guid) → Only players, no NPCs
✓ IsHostile(guid) → Only hostile players
✓ IsPvPFlagged(guid) → Only PvP-flagged players
✓ IsAlive(guid) → Only living players
```

### Performance:

- **Scan Interval:** 0.5 seconds
- **Cleanup Interval:** 5 seconds (removes GUIDs that no longer exist)
- **CPU Load:** Minimal (~0.5% with 50 GUIDs)
- **Pet Filtering:** Intelligent detection to skip hunter/warlock pets

---

## 🐛 Troubleshooting

### Problem: Spy doesn't load

**Solution:**

- Check the folder structure: `Interface/AddOns/Spy/Spy.lua` must exist
- Ensure that only ONE Spy version is installed
- Delete all Spy_OLD copies

### Problem: SuperWoW not detected

**Solution:**

- Check SuperWoW version (must be 1.12.1+)
- Enter `/spystatus` for details
- Is SuperWoW installed correctly? Test with other SuperWoW addons
- Reinstall SuperWoW from https://github.com/balakethelock/SuperWoW

### Problem: Error on loading

**Solution:**

- Activate Debug mode: `/spydebug`
- Read the error in chat
- Check if SuperWoW is active: `/spystatus`

### Problem: Too many Detections / Spam

**Solution:**

- Deactivate Debug mode: `/spydebug`
- Adjust Scan Interval: `SpySW.SCAN_INTERVAL = 1.0` in SpySuperWoW.lua

---

## 📊 Statistics

With `/spystatus` you can see the following information:

- **SuperWoW Status** - Available or not
- **Tracked GUIDs** - Number of currently tracked players
- **Enemies** - Number of tracked enemy players
- **Friendlies** - Number of tracked friendly players
- **GUIDs Collected** - Total number of collected GUIDs
- **Events Processed** - Number of processed events
- **Scans Performed** - Number of scans performed
- **Players Detected** - Number of detected players
- **Pets Skipped** - Number of correctly filtered pets

---

## 📝 Changelog

### v3.8.6 + SuperWoW

**New:**

- SuperWoW integration for GUID-based player detection
- **SuperWoW is now REQUIRED** - no fallback mode
- Addon automatically disables if SuperWoW is not detected
- New commands: `/spystatus`, `/spydebug`, `/spybuff`, `/spypet`, `/spytarget`
- Improved performance through direct GUID-scanning
- Automatic level correction for Skulls (-1 → 0)
- Intelligent pet filtering (no more pet spam)
- RAW_COMBATLOG support for better combat tracking

**Fixed:**

- Level-Guess logic is deactivated with SuperWoW
- Duplicate detections prevented
- GUID-Cleanup for non-existent units
- Pet detection improved (uses class check + UnitPlayerControlled)
- LastAttack tracking with GUID-to-name resolution

**Retained:**

- All Original Spy Features
- KOS Lists
- Blacklist
- Alert System
- Stats
- Map Integration
- UI/GUI

---

## ⚠️ Important

✅ Your KOS lists remain intact
✅ Your settings remain intact
✅ All Spy features work as before
✅ Only the detection method has changed - and it's better!

❌ **SuperWoW is REQUIRED** - the addon will not work without it!

---

## 💡 Tips

### Best Settings with SuperWoW:

- **Scan Interval:** 0.5s (Standard) - for fast detection
- **Debug Mode:** OFF - except for testing
- **Spy Settings:** Use as usual

### Performance Optimization:

- With many players (>100): Increase Scan Interval to 1.0s
- During PvP-Raids: Turn off Debug Mode to avoid spam

---

## 🤝 Credits

- **Immolation** - Original Spy Add-on
- **laytya** - Vanilla Port
- **Shagu** - ShaguScan (Inspiration for GUID System)
- **SuperWoW-Team** - SuperWoW Framework

---

## 📄 License

Same as the original Spy Add-on.

---

## 🆘 Support

For problems:

1. Check `/spystatus`
2. Activate `/spydebug` and read the error
3. Verify SuperWoW is installed correctly
4. Create an Issue on GitHub (if available)

---

## 🎯 Have fun hunting!

**Remember: SuperWoW is REQUIRED for this addon to function!**
