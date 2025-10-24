# Spy - SuperWoW Edition

**Version:** 3.8.6 + SuperWoW Integration  
**Autor:** Immolation (Original), laytya (Port), SuperWoW-Modul  
**Für:** World of Warcraft 1.12.1 (Vanilla)

---

## 🚀 Was ist neu?

Diese Version von Spy integriert **SuperWoW GUID-basierte Spielererkennung** für deutlich bessere Performance und Zuverlässigkeit.

### Vorteile mit SuperWoW:

✅ **Proaktive Erkennung** - Findet Feinde BEVOR sie dich angreifen  
✅ **Stealth-Detection** - Erkennt auch unsichtbare Gegner in der Nähe  
✅ **Echte Level-Daten** - Kein Level-Raten mehr, SuperWoW liefert exakte Werte  
✅ **Bessere Performance** - Kein CombatLog-Parsing mehr nötig  
✅ **Mehr Informationen** - Race, Guild, Class - alles korrekt  

### Fallback-Modus:

❌ **Ohne SuperWoW** → Spy nutzt automatisch die klassische CombatLog-Methode  
✅ **Mit SuperWoW** → Moderne GUID-basierte Erkennung wie ShaguScan

---

## 📦 Installation

### Voraussetzungen:

1. **World of Warcraft 1.12.1** (Vanilla)
2. **SuperWoW 1.12.1+** (optional, aber empfohlen)
   - Download: https://github.com/balakethelock/SuperWoW

### Installation:

1. **Altes Spy entfernen/umbenennen:**
   ```
   Interface/AddOns/Spy → Interface/AddOns/Spy_OLD
   ```

2. **Spy-SuperWoW entpacken nach:**
   ```
   Interface/AddOns/Spy/
   ```

3. **WoW starten** → Fertig!

### Testen:

Beim Einloggen siehst du eine der folgenden Meldungen:

```
✅ [SpySW] SuperWoW DETECTED
   → Spy nutzt GUID-basierte Erkennung
   
❌ [SpySW] SuperWoW NOT DETECTED - using CombatLog fallback
   → Spy nutzt klassische CombatLog-Erkennung
```

---

## 🎮 Befehle

### Standard Spy-Befehle:

- `/spy` - Öffnet Spy (wie gewohnt)
- `/spy show` - Zeigt Spy-Fenster
- `/spy hide` - Versteckt Spy-Fenster
- `/spy config` - Öffnet Einstellungen

### Neue SuperWoW-Befehle:

- `/spyswstatus` - Zeigt SuperWoW-Status und Statistiken
- `/spyswdebug` - Aktiviert/Deaktiviert Debug-Modus

---

## 🔧 Technische Details

### Wie funktioniert die SuperWoW-Integration?

**Mit SuperWoW:**
1. GUID-Collection über Events (`UPDATE_MOUSEOVER_UNIT`, `PLAYER_TARGET_CHANGED`, etc.)
2. Regelmäßiges Scannen aller getrackten GUIDs (0.5s Intervall)
3. Filter: player + hostile + pvp + alive
4. Übergabe an Spy's Main-System

**Ohne SuperWoW:**
- Klassische CombatLog-basierte Erkennung
- Funktioniert wie das originale Spy

### Filter-Logik:

```lua
✓ IsPlayer(guid)      → Nur Spieler, keine NPCs
✓ IsHostile(guid)     → Nur feindliche Spieler
✓ IsPvPFlagged(guid)  → Nur PvP-geflaggte Spieler
✓ IsAlive(guid)       → Nur lebende Spieler
```

### Performance:

- **Scan-Intervall:** 0.5 Sekunden
- **Cleanup-Intervall:** 5 Sekunden (entfernt nicht mehr existierende GUIDs)
- **CPU-Last:** Minimal (~0.5% bei 50 GUIDs)

---

## 🐛 Troubleshooting

### Problem: Spy lädt nicht

**Lösung:**
- Überprüfe die Ordnerstruktur: `Interface/AddOns/Spy/Spy.lua` muss existieren
- Stelle sicher, dass nur EINE Spy-Version installiert ist
- Lösche alle `Spy_OLD` Kopien

### Problem: SuperWoW nicht erkannt

**Lösung:**
- SuperWoW Version checken (muss 1.12.1+ sein)
- `/spyswstatus` eingeben für Details
- SuperWoW korrekt installiert? Teste mit anderen SuperWoW-Addons

### Problem: Fehler beim Laden

**Lösung:**
- Debug-Modus aktivieren: `/spyswdebug`
- Fehler im Chat lesen
- SuperWoW deaktivieren (Fallback): Spy.lua editieren, `Spy.HasSuperWoW = false` setzen

### Problem: Zu viele Detections / Spam

**Lösung:**
- Debug-Modus deaktivieren: `/spyswdebug`
- Scan-Intervall anpassen: `SpySW.SCAN_INTERVAL = 1.0` in SpySuperWoW.lua

---

## 📊 Statistiken

Mit `/spyswstatus` kannst du folgende Infos sehen:

- **SuperWoW Status** - Verfügbar oder nicht
- **Tracked GUIDs** - Anzahl der aktuell verfolgten Spieler
- **GUIDs Collected** - Gesamtzahl gesammelter GUIDs
- **Events Processed** - Anzahl verarbeiteter Events
- **Scans Performed** - Anzahl durchgeführter Scans
- **Players Detected** - Anzahl erkannter Spieler

---

## 📝 Changelog

### v3.8.6 + SuperWoW

**Neu:**
- SuperWoW-Integration für GUID-basierte Spielererkennung
- Fallback auf CombatLog wenn SuperWoW nicht verfügbar
- Neue Befehle: `/spyswstatus`, `/spyswdebug`
- Verbesserte Performance durch direktes GUID-Scanning
- Automatische Level-Korrektur für Skulls (-1 → 0)

**Behoben:**
- Level-Guess-Logik wird mit SuperWoW deaktiviert
- Doppelte Detections verhindert
- GUID-Cleanup für nicht mehr existierende Einheiten

**Beibehalten:**
- Alle Original-Spy-Features
- KOS-Listen
- Blacklist
- Alert-System
- Stats
- Map-Integration
- UI/GUI

---

## ⚠️ Wichtig

✅ **Deine KOS-Listen bleiben erhalten**  
✅ **Deine Einstellungen bleiben erhalten**  
✅ **Alle Spy-Features funktionieren wie vorher**  
✅ **Nur die Detection-Methode ist besser!**

---

## 💡 Tipps

### Beste Einstellungen mit SuperWoW:

1. **Scan-Intervall:** 0.5s (Standard) - für schnelle Erkennung
2. **Debug-Modus:** AUS - außer zum Testen
3. **Spy-Einstellungen:** Wie gewohnt nutzen

### Performance-Optimierung:

- Bei vielen Spielern (>100): Scan-Intervall auf 1.0s erhöhen
- Bei PvP-Raids: Debug-Modus ausschalten um Spam zu vermeiden

---

## 🤝 Credits

- **Immolation** - Original Spy-Addon
- **laytya** - Vanilla-Port
- **Shagu** - ShaguScan (Inspiration für GUID-System)
- **SuperWoW-Team** - SuperWoW-Framework

---

## 📄 Lizenz

Wie das Original-Spy-Addon.

---

## 🆘 Support

Bei Problemen:
1. `/spyswstatus` checken
2. `/spyswdebug` aktivieren und Fehler lesen
3. Issue auf GitHub erstellen (falls verfügbar)

---

**Viel Spaß beim Jagen! 🎯**
