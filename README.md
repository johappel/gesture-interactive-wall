# WIRKLICHT — Gesten-Resonanz auf der Fassade

Interaktive Licht-Installation für das **Lichterfest Bad Wilhelmshöhe** (30.10.2026).
Ein begrenzter, beleuchteter Interaktionsbereich vor der Fassade bzw. im
Eingangsbereich des Kirchenamtes wird lokal per Kamera erfasst. Ein Rechner
übersetzt die Bewegungen und Beziehungen von ungefähr **2–20 Personen**
**vollständig lokal und anonym** in Licht, Partikel, Felder, Spuren und Wellen.

> Theologisch-künstlerischer Rahmen: *Licht in der Dunkelheit*. Menschen wirken wie
> Lichter — ihre Anwesenheit, Bewegung, Nähe und gemeinsame Dynamik hinterlassen
> sichtbare Resonanz.

## QUICKSTART - Windows

Auf einem Windows-Rechner kann WIRKLICHT mit einem einzigen PowerShell-Befehl
eingerichtet werden. PowerShell oeffnen, den folgenden Befehl einfuegen und
ausfuehren:

```powershell
powershell -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/johappel/gesture-interactive-wall/main/install.ps1 | iex"
```

> Sicherheit: Dieser Befehl fuehrt bewusst das offizielle Installationsskript
> direkt von GitHub aus. Vor einem Veranstaltungseinsatz sollte die verwendete
> Version geprueft und danach nicht mehr kurzfristig automatisch aktualisiert
> werden.

Der Installer richtet Python 3.11, Godot, WIRKLICHT, MediaPipe/OpenCV, das
Pose-Modell, die Kameraauswahl und Desktop-Verknuepfungen ein. Git ist nicht
erforderlich. Nach erfolgreicher Installation genuegt ein Doppelklick auf
**WIRKLICHT starten**. Der normale Betrieb funktioniert danach ohne Internet.

### Erstinstallation

Die Installation benoetigt Internet und kann Windows-Installationsdialoge fuer
Python anzeigen. Das Projekt wird nach `C:\WIRKLICHT` installiert.

### Start

Desktop -> **WIRKLICHT starten**. Das Fenster bleibt waehrend des Betriebs offen.

### Kamera wechseln

Wenn die bisherige Kamera fehlt, listet WIRKLICHT die erkannten Kameras auf und
speichert die Auswahl wieder in `C:\WIRKLICHT\config\config.json`.

### Update

`C:\WIRKLICHT\update.ps1` in PowerShell ausfuehren. Das Update legt vorher ein
Backup unter `C:\WIRKLICHT\backup` an und behaelt die lokale Config. Es gibt
keine stillen Updates beim normalen Start. Die vorbereitete Einstellung
`updates.enabled` steht standardmaessig auf `false`.

### Diagnose

Desktop -> **WIRKLICHT Hilfe & Diagnose**. Die Datei
`WIRKLICHT-DIAGNOSE.txt` wird auf dem Desktop erzeugt und kann fuer Remote-Support
weitergegeben werden. Sie enthaelt keine Kamerabilder oder Videos.

## Leitidee

WIRKLICHT ist **kein berührungsloses Bedieninterface**. Menschen sollen nicht
lernen müssen: „Wenn ich Geste X mache, passiert Effekt Y.“

Stattdessen arbeitet die Installation mit kontinuierlichen Resonanzqualitäten wie
Bewegungsintensität, Öffnung, Ruhe, Nähe, Rhythmus und gemeinsamer Dynamik.

> **WIRKLICHT visualisiert nicht die Befehle von Menschen, sondern die Spuren
> ihrer Anwesenheit, Bewegung und Beziehung.**

Eine Person oder Gruppe soll beim Verlassen des Erfassungsbereichs außerdem nicht
einfach verschwinden: Als **Nachwirkung** kann vom Austrittsrand eine ruhige,
zurücklaufende Wasser-/Lichtwelle in die Fassadenfläche hinein entstehen.

Die theologisch-ästhetische Begründung und offene Diskussionsfragen stehen in
[docs/Theologische-Aesthetik.md](docs/Theologische-Aesthetik.md).

## Datenschutz (KO-Kriterium)

- Die Bildverarbeitung läuft **ausschließlich lokal** auf dem Rechner.
- Es werden **keine Bilder oder Videos** gespeichert oder ins Netz übertragen.
- Über UDP (nur `127.0.0.1`) wandern **nur abstrakte Zahlenwerte** wie Position,
  Intensität, Resonanzqualitäten, Beziehungen und ausgewählte Zustandsereignisse
  an den Renderer — keine Kameraaufnahmen, keine Cloud.

## Architektur

```text
Kamera ──► capture/ (Python + MediaPipe) ──JSON/UDP──► renderer/ (Godot 4) ──► Beamer
           Pose-Tracking + Resonanzsignale             Licht / Partikel / Felder /
                                                        Spuren / Wellen
```

- `capture/` — Python-App: Ganzkörper-Pose-Tracking (MediaPipe), Feature-Extraktion,
  Mehrpersonen-Tracking und Versand als JSON über UDP.
- `renderer/` — Godot-4-Projekt: interpretiert die abstrakten Werte künstlerisch.
- `config/` — zentrale Konfiguration für Kamera, Netzwerk, Feature-Parameter und
  **alle eigenständigen visuellen Effektfamilien**.
- `docs/` — Projektplan, Datenprotokoll, theologisch-ästhetisches Diskussionspapier
  und spätere Betriebsdokumentation.
- `tests/` — Unit-Tests der Feature-Mathematik (ohne Kamera lauffähig).

Die Wahrnehmungsschicht bleibt bewusst unabhängig von der Darstellung: Ein
Renderer-Effekt kann deaktiviert werden, ohne dass die zugrunde liegenden
Resonanzsignale im Capture verschwinden.

## Visuelles Vokabular

Die Fassade soll nicht nur aus unterschiedlich hellem Glow bestehen. Vorgesehen
sind verschiedene visuelle Materialitäten, zum Beispiel:

- Lichtkörper / Glow für Anwesenheit,
- Funken und aufsteigende Lichtpartikel für Bewegung,
- Trails für Wege durch den Raum,
- Lichtbrücken und Felder für Nähe,
- Lichtdunst für länger anhaltende Beziehung bzw. Atmosphäre,
- Wellen für Rhythmus und Modulation,
- gelegentliche schwebende Lichtkörper für intensive gemeinsame Phasen,
- zurücklaufende Wasser-/Lichtwellen als **Nachwirkung** beim Verlassen.

Mit wachsender Personenzahl soll die Darstellung von einzelnen Lichtkörpern
zunehmend zu einem gemeinsamen Resonanzkörper der Fassade übergehen:

```text
body → pair → crowd
presence → relation → collective → memory
```

## Verbindliche Effekt-Schalter

Für den Live-Betrieb gilt eine Architekturregel:

> **Jeder eigenständige visuelle Effekt muss in `config/config.json` einen
> expliziten `enabled`-Schalter besitzen.**

So können vor Ort Effekte kurzfristig abgeschaltet werden, wenn sie zu unruhig,
zu schwach, performancekritisch oder für die reale Projektionsfläche ungeeignet
sind.

Aktuell werden `body_glow`, `trails`, `sparks` und `proximity_bridges` vom
Renderer tatsächlich aus der gemeinsamen Config gelesen. Weitere Effektfamilien
sind bereits als deaktivierte Config-Blöcke reserviert und werden erst bei ihrer
Implementierung aktiviert.

Beispiel:

```json
{
  "effects": {
    "enabled": true,
    "minimal_mode": false,
    "body_glow": { "enabled": true },
    "trails": {
      "enabled": true,
      "max_points": 48,
      "width": 10.0
    },
    "sparks": {
      "enabled": true,
      "amount_min": 24,
      "amount_max": 112,
      "lifetime": 1.4,
      "velocity_min": 20.0,
      "velocity_max": 300.0
    },
    "proximity_bridges": { "enabled": true },
    "mist": { "enabled": false },
    "waves": { "enabled": false },
    "floating_bodies": { "enabled": false },
    "aftereffect_waves": { "enabled": false },
    "crowd_field": { "enabled": false }
  }
}
```

Dabei gilt:

- `effects.enabled: false` schaltet alle Effektfamilien ab.
- `effects.minimal_mode: true` erzwingt einen stabilen Fallback aus
  **Body Glow + Trails + Proximity Bridges**.
- `enabled: false` bedeutet **nicht erzeugen und nicht weiter simulieren**, nicht
  bloß unsichtbar machen.
- Effektparameter gehören in den jeweiligen Effektblock.
- Resonanzsignale wie `intensity`, `openness`, `stillness` oder `rhythm` bleiben
  unabhängig davon verfügbar.
- Neue Effektfamilien gelten erst dann als vollständig integriert, wenn ihr
  Config-Schalter vorhanden ist.
- Änderungen an `config/config.json` werden derzeit beim Start des Godot-Renderers
  eingelesen; für Änderungen im Betrieb muss der Renderer neu gestartet werden.
- Später können Presets wie `calm`, `full` oder `debug` hinzukommen; sie ersetzen
  die Einzel-Schalter nicht.

Beim Start gibt der Renderer den effektiven On/Off-Zustand der Effektfamilien in
der Godot-Konsole aus. So ist auch ein versehentlich aktivierter Effekt vor einem
Live-Test schnell erkennbar.

## Manuelle Installation / Entwicklung

### 1. Python-Umgebung

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r capture/requirements.txt
```

### 2. Pose-Modell laden (für Multi-Person-Tracking)

```powershell
python capture/download_model.py
```

Fehlt das Modell, fällt die App automatisch auf Einzelperson-Tracking zurück.

### 3. Renderer testen (ohne Kamera)

Godot 4.4+ öffnen (hier: `F:\code\godot\Godot_v4.7.1-stable_win64.exe`).
Im Projektmanager **Importieren** → `renderer/project.godot` auswählen →
**Importieren & Bearbeiten**. Dann mit **F5** starten.

> Zeigt der Projektmanager einen alten Eintrag als „Fehlendes Projekt“, diesen mit
> **Entfernen** löschen und `renderer/project.godot` neu importieren.

Dann den Simulator starten (als Modul, wegen der Paket-Importe):

```powershell
python -m capture.tracker --sim
```

Es sollten Lichtgestalten über die Godot-Ausgabe wandern.

### 4. Mit echter Webcam

Zuerst die richtige Kamera finden (Windows zeigt oft auch **virtuelle** Kameras):

```powershell
python -m capture.tracker --list-cameras
```

Dann mit dem passenden Index starten (Index 0 ist häufig eine virtuelle Kamera):

```powershell
python -m capture.tracker --camera 1
```

Ohne `--camera` gilt `camera.index` aus `config/config.json`. Backend bei Bedarf
mit `--backend dshow` (Windows) wählen. Mit `q` im Vorschaufenster beenden.

Für den späteren Veranstaltungsbetrieb ist eine gute, gleichmäßige Beleuchtung des
Interaktionsbereichs wichtiger als die Erfassung eines großen Straßenraums.
RGB-Kamera ist zunächst die Primärlösung; IR- oder Tiefenkamera bleiben Optionen
nach einem Realwelt-Test unter Dämmerungs-/Nachtbedingungen.

## Status

- [x] Phase 0 — Konzept & Repo-Gerüst
- [x] Phase 1 — Capture-MVP (Ganzkörper, Features, UDP) + Simulator
- [x] Phase 2 — Renderer-MVP (Godot: Lichtgestalten, Bloom)
- [x] Phase 3 — Leuchtspuren (Trails)
- [x] Phase 4 — Multi-Person + Verbundenheit (Lichtbrücken)
- [ ] Phase 4.5 — Resonanzgrammatik + Nachwirkung (Effektsteuerung bereits umgesetzt)
- [ ] Phase 5 — Realwelt-Test (Beleuchtung, Distanz, 2–20 Personen)
- [ ] Phase 6 — Projektion & Kalibrierung
- [ ] Phase 7 — Hardware-Entscheidung / Robustheit
- [ ] Phase 8 — Klang (optional)
- [ ] Phase 9 — DSGVO/Beschilderung & Betriebshandbuch

Vollständiger Projektplan und Resonanzkonzept: [docs/plan.md](docs/plan.md).
Theologisch-ästhetisches Diskussionspapier: [docs/Theologische-Aesthetik.md](docs/Theologische-Aesthetik.md).
Datenprotokoll: [docs/protocol.md](docs/protocol.md).
