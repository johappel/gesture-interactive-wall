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

Auf einem Windows-Rechner kann WIRKLICHT auf zwei Wegen eingerichtet werden.

### Empfohlen: Installer herunterladen

Unter [Releases](https://github.com/johappel/gesture-interactive-wall/releases)
`WIRKLICHT-Setup-<Version>.exe` herunterladen und doppelklicken. Der Installer
enthaelt den vollstaendigen Projektcode und richtet danach Python 3.11, Godot,
MediaPipe/OpenCV, das Pose-Modell, die Kameraauswahl und die
Desktop-Verknuepfungen ein.

Godot, Python und die Python-Pakete werden waehrend der Installation
nachgeladen. Die Installation dauert daher einige Minuten und benoetigt
Internet. Das Fenster zeigt dabei den echten Fortschritt.

> Der Installer ist **nicht** code-signiert. Windows SmartScreen zeigt deshalb
> einmalig „Windows hat den Start dieser App verhindert" bzw. „Unbekannter
> Herausgeber". Ueber **Weitere Informationen → Trotzdem ausfuehren** fortfahren.
> Das ist keine Malware-Warnung, sondern die Folge der fehlenden Signatur.

### Alternativ: PowerShell-Befehl

PowerShell oeffnen, den folgenden Befehl einfuegen und ausfuehren:

```powershell
powershell -ExecutionPolicy Bypass -Command "& ([scriptblock]::Create((irm https://raw.githubusercontent.com/johappel/gesture-interactive-wall/main/install.ps1)))"
```

> **Warum nicht `| iex`?** Die Kurzform `irm ... | iex` ist das klassische
> Muster fuer Remote-Code-Ausfuehrung. Windows Defender und andere Scanner
> melden sie heuristisch als `Trojan:Win32/Commando.A!ml` — ein **Fehlalarm**,
> kein echter Fund. Der Befehl oben laedt dasselbe offizielle Skript, vermeidet
> aber das erkannte Muster. Wird trotzdem gewarnt, ist das Skript zuvor lokal
> zu speichern und auszufuehren (siehe unten).

> Sicherheit: Dieser Befehl fuehrt bewusst das offizielle Installationsskript
> direkt von GitHub aus. Vor einem Veranstaltungseinsatz sollte die verwendete
> Version geprueft und danach nicht mehr kurzfristig automatisch aktualisiert
> werden.

### Ganz ohne Warnung: Skript zuerst speichern

Wer die Defender- oder SmartScreen-Warnung vollstaendig vermeiden will, laedt
das Skript herunter, sieht es sich an und startet es als lokale Datei:

```powershell
$dir = Join-Path $env:TEMP "wirklicht-setup"
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$file = Join-Path $dir "install.ps1"
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/johappel/gesture-interactive-wall/main/install.ps1" -OutFile $file -UseBasicParsing
Get-Content $file | Select-Object -First 20   # kurz pruefen
powershell -ExecutionPolicy Bypass -File $file
```

Alternativ das Repository als ZIP herunterladen, entpacken und
`install.ps1` per Rechtsklick **Mit PowerShell ausfuehren** starten.

### Falls Defender die Datei blockiert

Wurde die Datei bereits in Quarantaene verschoben, ist sie nach der Pruefung
wiederherstellbar:

```powershell
# Nur nach eigener Pruefung des Skripts ausfuehren.
Add-MpPreference -ExclusionPath (Join-Path $env:TEMP "wirklicht-setup")
```

Die Ausnahme danach wieder entfernen:

```powershell
Remove-MpPreference -ExclusionPath (Join-Path $env:TEMP "wirklicht-setup")
```

Eine dauerhafte Ausnahme fuer `C:\WIRKLICHT` ist **nicht** noetig und sollte
vermieden werden.

### Installer selbst bauen

Wer den Installer aus dem Quelltext erzeugen will, braucht
[Inno Setup 6](https://jrsoftware.org/isdl.php) und ruft auf:

```powershell
winget install --id JRSoftware.InnoSetup --accept-package-agreements --accept-source-agreements
powershell -ExecutionPolicy Bypass -File installer\build.ps1
```

Das Ergebnis landet als `dist\WIRKLICHT-Setup-<Version>.exe`. Die Version kommt
aus der Datei `VERSION`, damit Installer und Projekt nicht auseinanderlaufen.
Der GitHub-Workflow `.github/workflows/installer.yml` baut dasselbe Paket bei
einem Tag `v*` und haengt es an das Release.

> **Wichtig: Tag und `VERSION` muessen uebereinstimmen.**
>
> Der Tag benennt das Release, die `VERSION`-Datei den Inhalt der `setup.exe`.
> Ein Release heisst also `v0.5.4` und enthaelt `WIRKLICHT-Setup-0.5.4.exe`.
> Laufen beide auseinander, haengt unter dem Release `v0.0.2` eine Datei mit
> der Version `0.5.4` — der Workflow bricht deshalb ab, statt ein solches
> Release zu erzeugen.
>
> **Setze den Tag deshalb nicht von Hand**, sondern ueber `release.ps1`. Das
> Skript leitet den Tag aus `VERSION` ab, sodass beide nicht mehr auseinander
> laufen koennen:
>
> ```powershell
> # VERSION bleibt wie sie ist; Tag daraus ableiten:
> powershell -ExecutionPolicy Bypass -File release.ps1
>
> # VERSION erhoehen (patch/minor/major) und direkt veroeffentlichen:
> powershell -ExecutionPolicy Bypass -File release.ps1 -Bump patch
> ```
>
> Das Skript prueft vor jeder Aenderung, ob der Arbeitsbaum sauber ist, ob der
> Tag schon existiert und ob der Commit gepusht ist. Es fragt vor dem Push nach
> Bestaetigung (`-Yes` ueberspringt die Rueckfrage).

Der Installer richtet Python 3.11, Godot, WIRKLICHT, MediaPipe/OpenCV, das
Pose-Modell, die Kameraauswahl und Desktop-Verknuepfungen ein. Git ist nicht
erforderlich. Nach erfolgreicher Installation genuegt ein Doppelklick auf
**WIRKLICHT starten**. Der normale Betrieb funktioniert danach ohne Internet.
Ist bei der Installation noch keine Kamera angeschlossen, wird die Einrichtung
trotzdem abgeschlossen und die Kamera beim ersten Start erneut gesucht.

### Erstinstallation

Die Installation benoetigt Internet und kann Windows-Installationsdialoge fuer
Python anzeigen. Das Projekt wird nach `C:\WIRKLICHT` installiert.

### Start

Desktop -> **WIRKLICHT starten**. Das Fenster bleibt waehrend des Betriebs offen.
Der Installer legt die Verknüpfung auf dem von Windows gemeldeten Desktop,
gegebenenfalls zusätzlich auf dem OneDrive-Desktop und im Startmenü unter
**WIRKLICHT** an. Falls eine Desktop-Verknüpfung nicht sichtbar ist, funktioniert
auch ein Doppelklick auf `C:\WIRKLICHT\WIRKLICHT starten.cmd`.

### Kamera wechseln

Desktop -> **WIRKLICHT Kamera waehlen** öffnet einen Auswahldialog mit echten
Kameranamen. Die gewählte Kamera wird kurz getestet und erst bei einem
erfolgreichen Bild gespeichert. Wenn die bisherige Kamera fehlt, bietet
WIRKLICHT ebenfalls eine Neuauswahl an. Gespeichert
werden Kameraname, lokaler Gerätepfad und USB-VID/PID. Dadurch bleibt die Wahl
auch erhalten, wenn Windows nach einem USB-Portwechsel einen anderen Index
vergibt. Virtuelle Kameras von OBS, Animaze oder Logi Capture werden namentlich
gekennzeichnet.

Der Renderer startet unter Windows im Godot-Kompatibilitätsmodus (OpenGL 3),
damit installierte OBS-/Bandicam-Vulkan-Hooks den Start nicht blockieren.

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
- eine gemeinsame **Crowd-Aura** als atmosphärischer Resonanzraum der Gruppe,
- zurücklaufende Wasser-/Lichtwellen als **Nachwirkung** beim Verlassen.

Mit wachsender Personenzahl soll die Darstellung von einzelnen Lichtkörpern
zunehmend zu einem gemeinsamen Resonanzkörper der Fassade übergehen:

```text
body → pair → crowd
presence → relation → collective → memory
```

Die **Crowd-Aura** löst diese Aussage erstmals sichtbar ein: Je mehr Menschen
dazukommen, desto stärker zeigt WIRKLICHT das Geschehen zwischen ihnen. Die
Aura ist kein größerer Glow und kein Effekt für eine einzelne Person, sondern
ein gemeinsames, weich begrenztes Lichtfeld, das aus den vorhandenen anonymen
Body- und Crowd-Daten entsteht.

Dabei gilt eine wichtige Einschränkung: **Das WIR darf die Einzelnen nicht
unscharf machen.** Die Aura ist kein Lichtschleier über der Gruppe. Sie wird
rund um jeden Körper ausgespart und betont den Zwischenraum; personengebundene
Effekte werden mit wachsender Gruppe nur über Größe und Helligkeit zurück-
genommen, nie über die Deckkraft. Personen bleiben also erkennbare,
definierte Lichtkörper — Gemeinschaft entsteht nicht dadurch, dass
Individuen verschwimmen.

## Verbindliche Effekt-Schalter

Für den Live-Betrieb gilt eine Architekturregel:

> **Jeder eigenständige visuelle Effekt muss in `config/config.json` einen
> expliziten `enabled`-Schalter besitzen.**

So können vor Ort Effekte kurzfristig abgeschaltet werden, wenn sie zu unruhig,
zu schwach, performancekritisch oder für die reale Projektionsfläche ungeeignet
sind.

Aktuell werden `body_glow`, `trails`, `sparks`, `proximity_bridges`,
`stillness_resonance`, `crowd_aura` und `aftereffect_waves` vom Renderer
tatsächlich aus der gemeinsamen Config gelesen.

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
    "stillness_resonance": { "enabled": true },
    "crowd_aura": {
      "enabled": true,
      "min_people": 3,
      "full_strength_people": 10
    },
    "aftereffect_waves": { "enabled": true }
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

### 3.2 Simulation ohne Kamera (empfohlen für die Abnahme)

Für die Beurteilung von Effekten wie `crowd_aura` gibt es einen eigenen
Doppelklick-Launcher. Er startet den Renderer und speist anschließend
synthetische Daten ein — **ohne Kamera, ohne Publikum, ohne Abendlicht**:

```text
WIRKLICHT Simulation.cmd
```

Der Launcher fragt nach einem Szenario und zeigt die verfügbare Liste an. Die
Szenarien selbst stehen ausschließlich in `capture/sim.py` und werden von dort
gelesen, nicht im Skript dupliziert. Beispiele:

| Szenario | Zeigt |
|---|---|
| `crowd_aura` | 0 → 14 Personen, Bewegung, Ruhe, Aufteilung, schrittweises Fortgehen |
| `stay_resonance` | ruhiges Bleiben mit kurzer Erkennungslücke |
| `aftereffect_waves` | einzelner und gemeinsamer Austritt |
| `phase44` | Leerlauf → eine Person → mehrere Personen → Leerlauf |

Auch nicht-interaktiv startbar:

```powershell
powershell -ExecutionPolicy Bypass -File simulate.ps1 -Scenario crowd_aura
```

> Der Simulator ersetzt **keine** reale Fassadenabnahme. Helligkeit,
> Distanzlesbarkeit und die Wirkung bei echtem Publikum bleiben offen.

### 3.1 Beamer und Nahraum-Monitor im Vollbild

Die Ausgaben werden in `config/config.json` unter `station` gespeichert. Beim
ersten normalen Start mit mehreren Bildschirmen öffnet sich die Auswahl für die
Fassade bzw. den Beamer. Sie zeigt Auflösung, Position und Hauptbildschirm an
und speichert die Auswahl. Später kann sie über **WIRKLICHT Bildschirm waehlen**
auf dem Desktop erneut geöffnet werden.

Die Fassade setzt zuerst ihren Bildschirm und wechselt anschließend in Godots
rahmenloses `Window.MODE_FULLSCREEN`. Der Nahraum-Monitor bleibt eine getrennte,
ebenfalls konfigurierbare Ausgabe, zum Beispiel:

```json
"facade": { "screen": 1, "fullscreen": true },
"monitor": { "screen": 0, "fullscreen": true }
```

Beim Renderer-Neustart erscheint die Fassade rahmenlos auf dem Beamer; der
Nahraum-Monitor zeigt die Resonanz-Vorschau samt Leerlaufimpuls ebenfalls ohne
Fensterrahmen. Fehlt die gespeicherte Ausgabe, zeigt der normale Start die
Auswahl erneut; ein manueller Renderer-Start fällt sicher auf den Hauptbildschirm
zurück. Bei nur einer erkannten Anzeige bleibt die Nahraum-Vorschau bewusst aus,
damit sie die Fassadenausgabe nicht überlagert. `Alt` + `Enter` schaltet nur für
Entwicklung und Fehlerbehebung zwischen Fenster und Vollbild um und behält dabei
den gewählten Fassaden-Bildschirm.

### 4. Mit echter Webcam

Zuerst die richtige Kamera finden (Windows zeigt oft auch **virtuelle** Kameras):

```powershell
python -m capture.tracker --list-cameras
```

Dann mit dem ausgegebenen Index starten (die dreistelligen Windows-Indizes sind
absichtlich backend-codiert und stabiler als ein roher Index wie `1`):

```powershell
python -m capture.tracker --camera 701 --backend any
```

Ohne `--camera` sucht WIRKLICHT die in `config/config.json` gespeicherte Kamera
zuerst über Gerätepfad, dann USB-VID/PID und Namen; der Index ist nur noch der
Rückfall. Mit `q` im Vorschaufenster beenden.

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
- [x] Phase 4.5 — Resonanzgrammatik + Nachwirkung (Effektsteuerung bereits umgesetzt)
- [ ] Phase 5 — Realwelt-Test (Beleuchtung, Distanz, 2–20 Personen)
- [ ] Phase 6 — Projektion & Kalibrierung
- [ ] Phase 7 — Hardware-Entscheidung / Robustheit
- [ ] Phase 8 — Klang (optional)
- [ ] Phase 9 — DSGVO/Beschilderung & Betriebshandbuch

Vollständiger Projektplan und Resonanzkonzept: [docs/plan.md](docs/plan.md).
Theologisch-ästhetisches Diskussionspapier: [docs/Theologische-Aesthetik.md](docs/Theologische-Aesthetik.md).
Datenprotokoll: [docs/protocol.md](docs/protocol.md).
