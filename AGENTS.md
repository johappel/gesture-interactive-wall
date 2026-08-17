# Repository Guidelines (WIRKLICHT)

WIRKLICHT ist eine interaktive Fassadenprojektion für das Lichterfest Bad
Wilhelmshöhe. Ein klar begrenzter, beleuchteter Interaktionsbereich wird per
Kamera erfasst; ein Rechner übersetzt Anwesenheit, Bewegung und Beziehung von
ungefähr **2–20 Personen** **vollständig lokal und anonym** in Licht, Partikel,
Felder, Spuren und Wellen.

Wichtig: Das Projekt ist **kein berührungsloses Bedieninterface**. Menschen sollen
keine Gestenkommandos lernen müssen. Leitgedanke:

> **WIRKLICHT visualisiert nicht die Befehle von Menschen, sondern die Spuren
> ihrer Anwesenheit, Bewegung und Beziehung.**

Vor Änderungen an Wahrnehmungslogik, Effekten oder Dramaturgie zuerst
`docs/plan.md` und `docs/Theologische-Aesthetik.md` lesen. Beide Dokumente sind
für die Entwicklungsrichtung verbindliche Referenzen; das ästhetische Papier ist
als Diskussions- und Prüfdokument zu verstehen, nicht als starre Dogmatik.

## Projektstruktur

- `capture/` — Python-App (MediaPipe Pose-Tracking, Feature-Mathematik, UDP-Versand).
  - `tracker.py` — Einstiegspunkt (`python -m capture.tracker`), CLI, Frame-Bau.
  - `features.py` — reine Python-Mathematik (ID-Tracking, Intensität, Paare) — **ohne** ML-Abhängigkeiten, damit unit-testbar.
  - `pose.py`, `camera.py`, `net.py`, `sim.py` — MediaPipe, Webcam (OpenCV), UDP, Simulator.
- `renderer/` — Godot-4.7-Projekt (empfängt JSON/UDP, interpretiert Resonanzsignale als visuelle Materialitäten).
- `config/config.json` — zentrale Konfiguration für Kamera, Netzwerk, Feature-Parameter und Renderer-Effekte.
- `docs/plan.md` — verbindlicher Projektplan, Resonanzgrammatik, Roadmap und Realwelt-Test.
- `docs/Theologische-Aesthetik.md` — Diskussionspapier zur theologischen und ästhetischen Logik des Projekts.
- `docs/protocol.md` — verbindliches JSON/UDP-Protokoll zwischen capture ↔ renderer.
- `tests/` — Unit-Tests (ohne Kamera/Godot lauffähig).

## Künstlerisch-technische Leitplanken (verbindlich)

### Resonanz statt Gestensteuerung

- Bevorzuge **kontinuierliche, semantisch arme Resonanzsignale** wie
  `intensity`, `openness`, `stillness`, `verticality`, `rhythm`, `proximity`,
  `synchrony` oder `presence_time`.
- Keine neue 1:1-Kommandologik nach dem Muster „Geste X → Effekt Y“, sofern sie
  nicht ausdrücklich im Projektplan diskutiert und begründet wurde.
- Keine Emotions- oder Bedeutungszuschreibung an Körperdaten. Das System erkennt
  keine „Freude“, „Trauer“, „Gebet“ o. Ä.
- Capture beschreibt beobachtbare Qualitäten; **der Renderer interpretiert sie
  künstlerisch**. Diese Schichten nicht unnötig koppeln.

### Individuum → Beziehung → Gruppe → Raum

Das vorhandene Modell `body → pair → crowd` ist konzeptionell gewollt.
Mit wachsender Personenzahl soll die Darstellung nicht zu vielen unabhängigen
Avataren/Effektmaschinen zerfallen:

- ca. 2–4 Personen: Individuen und direkte Beziehungen dürfen deutlich sein.
- ca. 5–10 Personen: Felder, Gruppierungen und gemeinsame Dynamik gewinnen an Gewicht.
- ca. 10–20 Personen: stärkerer gemeinsamer Resonanzkörper der Fassade.

Leitregel:

> **Je mehr Menschen dazukommen, desto weniger zeigt WIRKLICHT einzelne Menschen
> und desto stärker zeigt es das Geschehen zwischen ihnen.**

### Zeit, Nachwirkung und Erinnerung

Anwesenheit darf zeitlich nachwirken. Ein Track soll beim Verlassen des
Erfassungsbereichs nicht zwingend einfach verschwinden.

Für `departure`/Nachwirkung gilt:

- nur plausiblen Austritt **am Bildrand** als Ereignis behandeln;
- Trackingverlust durch Verdeckung nicht mit einem Austritt verwechseln;
- bevorzugte Formsprache: ruhige, vom Austrittsrand zurücklaufende
  Wasser-/Lichtwelle;
- keine Splash-/Feuerwerk-Ästhetik;
- Gruppen-Austritte dürfen zu einer gemeinsamen Nachwirkung aggregiert werden.

Zeitliche Zielrichtung:

```text
presence → relation → collective → memory
```

### Visuelles Vokabular und Projektionstauglichkeit

Vorgesehene Materialitäten sind u. a. Lichtkörper, Funken, Trails,
Nähe-Brücken/Felder, Lichtdunst, Wellen, schwebende Lichtkörper,
Nachwirkungswellen und Crowd-Felder.

Bei neuen oder geänderten Effekten immer bedenken:

- reale Projektion auf Fassade/Leinwand bei Dämmerung/Nacht, kein perfekter
  Display-Schwarzwert;
- schwache dunkle Details und sehr filigrane Partikel können real verschwinden;
- klare helle Kanten und aus Distanz lesbare Formen bevorzugen;
- nicht alles als Glow lösen: neue Effekte sollen nach Möglichkeit eine eigene
  Materialität bzw. Resonanzqualität beitragen;
- „mehr spektakulär“ ist **kein** hinreichendes Qualitätskriterium.

Vor einem neuen visuellen Effekt die Prüffragen in
`docs/Theologische-Aesthetik.md` heranziehen.

## Effekt-Konfiguration (verbindliche Architekturregel)

**Jede eigenständige visuelle Effektfamilie benötigt einen expliziten
`enabled`-Schalter unter `effects` in `config/config.json`.**

Dabei gilt:

- `enabled: false` bedeutet: Effekt **nicht erzeugen und nicht weiter simulieren**;
  bloßes Unsichtbarmachen reicht nicht.
- Effektparameter gehören in denselben Effektblock (`effects.<name>.*`).
- Capture-/Resonanzsignale bleiben unabhängig vom Renderer-Effekt verfügbar.
- Eine neue Effektfamilie ist erst vollständig integriert, wenn Config-Schalter,
  sinnvolle Defaults und Renderer-Behandlung vorhanden sind.
- `minimal_mode` ist ein Live-Fallback und soll einen stabilen Grundzustand
  herstellen.
- spätere Presets (`minimal`, `calm`, `full`, `debug`) dürfen Einzel-Schalter
  bündeln, aber nicht ersetzen.
- Bei Änderungen an der Config muss der Renderer bei fehlenden/ungültigen Werten
  robust auf sichere Defaults zurückfallen.

Aktuell implementierte schaltbare Effekte:

- `body_glow`
- `trails`
- `sparks`
- `proximity_bridges`

Reservierte, noch nicht vollständig implementierte Effektfamilien:

- `mist`
- `waves`
- `floating_bodies`
- `aftereffect_waves`
- `crowd_field`

## Räumlicher und technischer Rahmen

- Kein ganzer Straßenzug: vorgesehen ist ein begrenzter, beleuchteter Bereich am
  Stand bzw. im Eingangsbereich des Kirchenamtes.
- Zielgröße ungefähr **2–20 gleichzeitig erfasste Personen**.
- RGB-Kamera ist zunächst Primärlösung; IR/Tiefe sind Optionen nach Realwelt-Test.
- Beleuchtung, Entfernung, Sichtfeld, Verdeckungen und Track-Stabilität unter
  realen Abendbedingungen früh testen.

## Build, Test & Entwicklung

```powershell
python -m venv .venv; .\.venv\Scripts\Activate.ps1
pip install -r capture/requirements.txt
python capture/download_model.py                 # Multi-Person-Pose-Modell

python -m unittest discover -s tests -v          # komplette Testsuite
python -m capture.tracker --sim                  # Renderer ohne Kamera speisen
python -m capture.tracker --list-cameras         # verfügbare Kameras + Index
python -m capture.tracker --camera 1             # echte Webcam, Index überschreiben
```

Godot 4.7: `renderer/project.godot` importieren, mit **F5** starten.

## Test-Pflicht (verbindlich)

- **Jede Änderung wird über Tests verifiziert.** Vor Abschluss läuft
  `python -m unittest discover -s tests -v` grün durch, soweit die Änderung mit
  der verfügbaren Umgebung ausführbar ist.
- Neue oder geänderte Logik in `capture/` erhält passende Tests in `tests/`
  (Dateiname nach Verhalten, z. B. `test_features.py`, `test_cli.py`).
- Test-Design: Logik von Hardware/ML trennen. Reine Mathematik und CLI/Config
  gehören in test-bare Funktionen (siehe `features.py`, `build_parser`,
  `apply_overrides`); OpenCV/MediaPipe/Godot werden **nicht** in Unit-Tests
  geladen. `cv2` wird lazy importiert, damit Tests ohne Kamera laufen.
- Erfolgs- **und** Fehlerpfade prüfen (z. B. unbekanntes Backend, leere Eingaben,
  fehlende oder ungültige Config-Werte).
- Visuelle Änderungen zusätzlich im Godot-Simulator prüfen. Wenn kein Godot-Lauf
  möglich ist, dies im Abschluss transparent benennen und keinen erfolgreichen
  Lauf behaupten.
- Neue Resonanzsignale im Simulator mit repräsentativen Situationen abbilden,
  bevor Hardware als Voraussetzung für Tests entsteht.

## Coding Style

Python: 4 Leerzeichen Einrückung, UTF-8 mit echten Umlauten, Typannotationen an
öffentlichen Funktionen, `snake_case` für Funktionen/Variablen, `PascalCase` für
Klassen. Kleine, einzweckige Module; keine versteckten Globals.

Godot/GDScript: Effektfamilien möglichst getrennt halten. Keine große monolithische
Effektklasse aufbauen, wenn eine Materialität eigenständig konfigurierbar und
abschaltbar sein soll.

## Datenschutz (KO-Kriterium)

- Bildverarbeitung läuft **ausschließlich lokal**. Es werden **keine** Bilder
  oder Videos gespeichert oder übertragen.
- Über UDP (nur `127.0.0.1`) wandern **nur abstrakte Zahlenwerte** wie Position,
  Intensität, Resonanzqualitäten, Beziehungen und ausgewählte Zustandsereignisse
  — keine Kameraaufnahmen, keine Cloud. Dies gilt für jede Änderung.
- Keine Gesichtserkennung, Personenidentifikation oder biometrische Zuordnung
  hinzufügen.

## Kameras (Windows-Hinweis)

Neben physischen Webcams existieren oft **virtuelle Kameras** (OBS, Handy-als-
Webcam, Hersteller-Tools). `--camera 0` erwischt häufig eine solche (erkennbar
an Logo-Bild, „0 Personen"). Mit `--list-cameras` die Indizes ermitteln und den
richtigen per `--camera N` oder in `config.json` (`camera.index`) setzen. Backend
über `--backend {any,dshow,msmf}` bzw. `camera.backend` wählbar.

## Commits & Pull Requests

Kurze imperative Betreffzeilen, optional nach Bereich (z. B. `capture:`,
`renderer:`, `docs:`). Unabhängige Änderungen trennen. PRs beschreiben nicht nur
die technische Änderung, sondern bei visuellen/interactionalen Änderungen auch
die **sichtbare Wirkung und Resonanzabsicht**. Ausgeführte Validierungsbefehle
auflisten; bei visuellen Änderungen Screenshot/kurzes Video beifügen.
