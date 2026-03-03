# Spy - Nampower Edition

[![Version](https://img.shields.io/badge/version-4.5.0-blue.svg)](https://github.com/me0wg4ming/Spy)
[![WoW](https://img.shields.io/badge/WoW-1.12.1%20Vanilla-orange.svg)](#)
[![Nampower](https://img.shields.io/badge/Nampower-Required-red.svg)](https://github.com/pepopo978/nampower)

**Enhanced enemy detection addon for World of Warcraft 1.12.1 (Vanilla)**

---

## Quick Links

- [Installation](#-installation)
- [Commands & Usage](#-commands--usage)
- [Detection Features](#-detection-features)
- [Configuration Options](#️-configuration-options)
- [KoS System](#-kos-kill-on-sight-system)
- [Troubleshooting](#️-troubleshooting)
- [Support](#-support)

---

## What's New in Version 4.5.0 (March 2026)

### 🔄 Complete Rewrite: SuperWoW → Nampower

Spy has been fully migrated from SuperWoW to **Nampower** as its detection backend. SuperWoW is no longer required or supported.

### 🆕 New Detection Features

- **Nameplate Scanner** — Detects enemies simply standing in range without casting or moving, using Nampower's `CSimpleFrame:GetName(1)` nameplate GUID API
- **SPELL_GO_OTHER** — Instant enemy detection on every spell cast, replaces the old `UNIT_CASTEVENT` + `RAW_COMBATLOG` system
- **UNIT_*_GUID Events** — Proactive GUID collection via `UNIT_AURA_GUID`, `UNIT_FLAGS_GUID`, `UNIT_HEALTH_GUID`, `UNIT_COMBAT_GUID` — fires once per state change per unit, extremely low CPU cost
- **UNIT_DIED** — Server-authoritative real death signal (not Feign Death). Immediately removes the player from all lists
- **Release Spirit Detection** — `SPELL_GO_OTHER` with spell ID 8326 marks players who pressed Release, preventing false reactivation in the nearby list

### 🎯 Accurate Death & Feign Death Handling

The old system used `UnitIsDead()` which returned `true` for both real death **and** Feign Death, causing hunters to incorrectly appear as Inactive. The new system:

| Situation | Old Behavior | New Behavior |
|---|---|---|
| Hunter uses Feign Death | → Moved to Inactive ❌ | → Stays Active (hp > 0 detected) ✅ |
| Player dies | → Moved to Inactive (timeout-based) | → Immediate via `GetUnitField` hp=0 ✅ |
| Player presses Release | → Flickered back to Active ❌ | → Stays Inactive (spell 8326 detected) ✅ |
| Out-of-range death | → Stayed Active forever ❌ | → hp=0 via `GetUnitField` → Inactive ✅ |
| Real death in range | → Timeout cleanup (5s delay) | → `UNIT_DIED` → instant removal ✅ |

### ⚡ Performance Improvements

- **`RAW_COMBATLOG` completely removed** — This event fired dozens of times per second in combat and required expensive text pattern matching on every single event. Replaced entirely by `SPELL_GO_OTHER` and `UNIT_*_GUID` events
- **HP bars now use `GetUnitField`** — Direct memory read instead of `UnitHealth()` / `UnitHealthMax()`, more accurate and faster
- **HP=0 → Inactive transition** now happens in the 0.1s HP-OnUpdate, not the 1.0s scan loop — 10x faster visual response
- **Stealth detection via `GetUnitField(guid, "aura")`** — Direct aura slot scan instead of tooltip parsing

### 🔧 Technical Changes

- `SpySuperWoW.lua` → `SpyNampower.lua` (complete rewrite, ~1200 lines)
- `_G.SpySW` alias maintained for backwards compatibility with Spy.lua internals
- `NP_EnableSpellGoEvents=1` CVar set automatically on initialization
- Nampower version check on load (requires ≥ 3.0.0)
- `RawCombatLogEvent` removed, replaced by `SpellGoOtherLastAttack`
- `UnitCombatEvent` updated to use `GetUnitGUID()` instead of SuperWoW's second return value from `UnitExists()`

**Version:** 4.5.0
**Release Date:** March 2026
**Requirements:** Nampower ≥ 3.0.0 (MANDATORY), UnitXP (OPTIONAL for Distance Display)

---

## What's New in Version 4.2.0 (December 29, 2025)

### 🆕 Fixed: InvertSpy Mode
- **Inverted Player List** - Players now display ABOVE the "Nearby" title bar instead of below
- **Mirrored Title Texture** - Uses `title-industrial2.tga` for proper visual appearance when inverted
- **Dynamic Resize Grips** - Resize arrows reposition to top corners of player list and move with list growth
- **Background Texture** - Automatically adjusts height based on player count in inverted mode

### 🐛 Bugfixes
- **Map Jump Fix** - Map no longer automatically jumps to current zone when players are detected

---

## ⚠️ CRITICAL: Nampower is REQUIRED

**Without Nampower, Spy will NOT function!**

### Why Nampower is Mandatory

- ❌ **Without Nampower** → Spy automatically DISABLES itself on login
- ✅ **With Nampower** → Full GUID-based detection with server-accurate death events

### Download Nampower

**Official Repository:** [https://github.com/pepopo978/nampower](https://github.com/pepopo978/nampower)

Follow the installation instructions in the Nampower repository. Nampower version **3.0.0 or higher** is required.

### Download UnitXP (Optional)

**Official Repository:** [https://codeberg.org/konaka/UnitXP_SP3/releases](https://codeberg.org/konaka/UnitXP_SP3/releases)

Only needed for the distance display feature.

---

## 📦 Installation

### Prerequisites

1. **World of Warcraft 1.12.1** (Vanilla)
2. **Nampower 3.0.0+** (MANDATORY)
3. **UnitXP SP3** (OPTIONAL — for distance display)

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

After logging in type `/spystatus` to confirm Nampower is detected and scanning is active.

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
| `/spy kos <n>` | Toggle KoS for player |
| `/spy ignore <n>` | Toggle ignore for player |

### Nampower Debug Commands

| Command | Description |
|---------|-------------|
| `/spystatus` | Show Nampower status and detection statistics |
| `/spydebug` | Toggle debug mode (shows detection events in chat) |
| `/spyevent` | Toggle SPELL_GO_OTHER cast logger (developer tool) |
| `/spybuff` | Test aura scan via GetUnitField on current target |
| `/spypet` | Test pet detection on current target |

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

### 1. Nameplate Scanner (NEW in 4.5)

Scans all visible Nampower nameplate frames every 1.0 second using `CSimpleFrame:GetName(1)` to extract GUIDs. Catches enemies who are simply standing still without casting or triggering any events. This is the most passive and comprehensive detection source — no action required from the enemy.

### 2. SPELL_GO_OTHER (Instant Detection)

Every spell cast by a nearby enemy is intercepted in real time. Detection happens the moment a spell completes, with zero scan delay. Also handles Release Spirit (spell 8326) to prevent false reactivation after death.

### 3. UNIT_*_GUID Events (Proactive)

Nampower fires these events once per state change per unit. Far cheaper than standard `UNIT_*` events which fire once per token. Used for proactive GUID collection as units appear in range:

- `UNIT_AURA_GUID` — buff/debuff changes
- `UNIT_FLAGS_GUID` — PvP flag changes
- `UNIT_HEALTH_GUID` — health changes
- `UNIT_COMBAT_GUID` — entering/leaving combat

### 4. Stealth Detection

Two complementary methods:

**Method A: SPELL_GO_OTHER (Instant)**
Intercepts stealth spell casts in real time. Spell IDs tracked:
- Stealth (Rogue): 1784, 1785, 1786, 1787
- Prowl (Druid): 5215, 6783, 9913
- Shadowmeld (Night Elf): 20580
- Vanish (Rogue): 1856, 1857, 11327, 11329

**Method B: GetUnitField Aura Scan**
Scans aura slots directly via `GetUnitField(guid, "aura")` for active stealth auras. Runs once per range cycle per GUID, cached to avoid redundant reads.

### 5. Smart Filtering

- ✅ Only tracks: Enemy players + PvP flagged + Not a ghost
- ✅ Feign Death hunters remain Active (hp > 0, no UNIT_DIED fired)
- ✅ Dead players (hp = 0) shown as Inactive immediately (0.1s response)
- ✅ Released players stay Inactive (spell 8326 intercepted)
- ✅ Pets filtered via `UnitIsPlayer` + `UnitPlayerControlled` + `UnitClass` check
- ✅ Zone-based auto-disable (sanctuaries, instances)

---

## 🔧 Technical Details

### Detection Architecture

```
Nameplates (1.0s)     → ScanNameplates() → AddGUID()
SPELL_GO_OTHER        → instant detection + stealth alert + release tracking
UNIT_*_GUID events    → proactive GUID collection on state changes
Mouseover / Target    → GUID collection on interaction
UNIT_DIED             → immediate removal (real death only, not FD)
HP OnUpdate (0.1s)    → hp=0 → Inactive, hp>0 → Active (FD recovery)
Scan Loop (1.0s)      → iterate enemyGuids → ReportPlayerToSpy()
Cleanup (5s)          → remove stale GUIDs
```

### HP / Death State Logic

```
hp = GetUnitField(guid, "health")

hp == 0, no UNIT_DIED        → Feign Death or out-of-range death → Inactive
hp == 0, UNIT_DIED fired     → Real death → removed from all lists
hp > 0, not ghost,
        not releasedGuids    → back to Active (FD hunter stood up)
SPELL_GO_OTHER spellId=8326  → releasedGuids[guid]=true → blocks reactivation
UNIT_DIED                    → clears releasedGuids[guid]
```

### Performance

- **RAW_COMBATLOG:** Removed (was firing 50–200×/sec in raids with full text parsing)
- **UNIT_*_GUID:** Fires once per state change — negligible CPU
- **SPELL_GO_OTHER:** Replaces both UNIT_CASTEVENT and RAW_COMBATLOG
- **GetUnitField:** Direct memory read, faster than UnitHealth/UnitHealthMax
- **Scan interval:** 1.0s
- **HP update interval:** 0.1s

---

## 🛠️ Troubleshooting

### Problem: Spy doesn't load

Check folder structure: `Interface/AddOns/Spy/Spy.lua` must exist. Only ONE Spy version installed.

### Problem: Nampower not detected

- Verify Nampower installation (version ≥ 3.0.0 required)
- Check that Nampower DLL is in the WoW folder
- Test with other Nampower addons (pfUI, libdebuff)
- Type `/spystatus` — should show "Nampower: AVAILABLE"

### Problem: Enemy not detected

1. Check if enemy has their Nameplate visible (default Nampower range)
2. Enable debug: `/spydebug`
3. Test `/spybuff` on a targeted enemy
4. Verify `NP_EnableSpellGoEvents` is set to 1 (done automatically on load)

### Problem: Hunter stays Inactive after Feign Death

Should be fixed in 4.5.0. If still occurring, enable `/spydebug` and check if `UNIT_DIED` is incorrectly firing for FD. Report with `/spystatus` output.

### Problem: Player flickers Active/Inactive on death

Should be fixed in 4.5.0 via Release Spirit detection (spell 8326). Enable `/spydebug` to confirm `SPELL_GO_OTHER` is being received for the released player.

---

## 📈 Status Output

**Check with `/spystatus`:**

```
========== SpyNampower Status ==========
Nampower: AVAILABLE (v3.x.x)
Spy Mode: Nampower Scanning
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
=========================================
```

---

## 🤝 Credits & Acknowledgments

- **Immolation** — Original Spy addon creator (TBC/WotLK)
- **laytya** — Vanilla 1.12.1 port and maintenance
- **me0wg4ming** — SuperWoW integration and enhancements (v4.0–4.2)
- **Nampower migration** — Complete rewrite for Nampower backend (v4.5)
- **Shagu** — ShaguScan inspiration for GUID-based detection system
- **pepopo978** — Nampower framework development
- **Community** — Bug reports, feature suggestions, and testing

---

## 📄 License

Same as original Spy addon — free to use and modify.

---

## 🆘 Support

### Getting Help

1. **Check `/spystatus`** — Verify Nampower is detected
2. **Enable `/spydebug`** — See detection events in chat
3. **Test `/spybuff`** on an enemy — Verify aura scanning works
4. **Verify Nampower installation** — Check version ≥ 3.0.0
5. **GitHub Issues:** https://github.com/me0wg4ming/Spy/issues

### Providing Useful Bug Reports

- Nampower version
- WoW client version (1.12.1)
- Output of `/spystatus`
- Error message (if any)
- Steps to reproduce

---

**Version:** 4.5.0
**Release Date:** March 2026
**Compatibility:** World of Warcraft 1.12.1 (Vanilla)
**Requirement:** Nampower ≥ 3.0.0
**Status:** Stable & Production-Ready
**License:** Free to use and modify
