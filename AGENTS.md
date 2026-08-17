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

Ebenso wichtig: Die Installation darf ihre Interaktivität nicht so stark
verbergen, dass Passant:innen den Zusammenhang zwischen eigener Anwesenheit und
Fassadenbild nur zufällig entdecken können. Der Nahraum muss die Kopplung
**Ich ↔ Resonanz ↔ Fassade** schnell erfahrbar machen, ohne daraus eine
Bedienoberfläche oder Technikdemo zu machen.

Vor Änderungen an Wahrnehmungslogik, Effekten, Stand-/Monitorlogik oder
Dramaturgie zuerst `docs/plan.md`, `docs/Standkonzept.md` und
`docs/Theologische-Aesthetik.md` lesen. Diese Dokumente sind für die
Entwicklungsrichtung verbindliche Referenzen; das ästhetische Papier ist als
Diskussions- und Prüfdokument zu verstehen, nicht als starre Dogmatik.

## Projektstruktur

- `capture/` — Python-App (MediaPipe Pose-Tracking, Feature-Mathematik, UDP-Versand).
  - `tracker.py` — Einstiegspunkt (`python -m capture.tracker`), CLI, Frame-Bau.
  - `features.py` — reine Python-Mathematik (ID-Tracking, Intensität, Paare) — **ohne** ML-Abhängigkeiten, damit unit-testbar.
  - `pose.py`, `camera.py`, `net.py`, `sim.py` — MediaPipe, Webcam (OpenCV), UDP, Simulator.
- `renderer/` — Godot-4.7-Projekt (empfängt JSON/UDP, interpretiert Resonanzsignale als visuelle Materialitäten).
- `config/config.json` — zentrale Konfiguration für Kamera, Netzwerk, Feature-Parameter, Stand-/Monitoroptionen und Renderer-Effekte.
- `config/prompts.json` — kuratierte kurze Sprachimpulse für den Nahraum; keine technischen Bedienanweisungen.
- `docs/Standkonzept.md` — räumliche, technische und vermittlungsbezogene Gestaltung des Resonanzraums.
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

### Verständlichkeit ohne Bedienlogik

Die Interaktion muss **entdeckbar**, aber nicht **erklärungsbedürftig bedienbar**
sein.

Verbindliche Dramaturgie:

```text
Lichtinsel → Nahraum-Rückkopplung → Fassade
```

und inhaltlich:

```text
Gehen → Spur
Bleiben → Resonanz
Mehrere → Beziehung
Fortgehen → Nachwirkung
```

Daraus folgen Regeln:

- Der kleine Monitor in Kameranähe ist **Nahraum der Rückkopplung**, nicht zweite
  Hauptleinwand.
- Im Publikumsbetrieb darf der Monitor **niemals das rohe Kamerabild** zeigen.
- Bevorzugter Modus ist `facade_preview`: dieselbe oder eine visuell eng
  verwandte Resonanzdarstellung wie auf der Fassade.
- Die Vorschau muss ausreichend latenzarm sein, damit Menschen die eigene
  Anwesenheit als Ursache der Resonanz erkennen können.
- Der Monitor darf die Fassade nicht als Blickziel ersetzen; er soll den Blick
  dorthin weiterführen.
- Ein kurzer Satz darf die Entdeckung anstoßen, soll aber keine Technik erklären
  und keine konkrete Geste verlangen.
- Bevorzugter Impuls: **„Was geschieht, wenn du bleibst?“**
- Kurze Impulse ausschließlich in `config/prompts.json` kuratieren; nicht als
  String-Literale in Renderer-/Capture-Code verstreuen.
- Aktive Auswahl/Deaktivierung erfolgt über `station.prompt` in
  `config/config.json`.
- Änderungen an Sprachimpulsen als **inhaltlich-ästhetische Änderungen** behandeln,
  nicht bloß als UI-Copy.

### Bleiben muss eine Antwort bekommen

Wenn der Stand mit „Was geschieht, wenn du bleibst?“ zum Verweilen einlädt, muss
`stillness` bzw. `presence_time` eine qualitativ andere Resonanz ermöglichen als
bloßes Vorübergehen.

Nicht ausreichend ist: Ein bewegter Effekt friert einfach ein.

Geeignete Zielrichtungen sind z. B. Verdichtung, langsames Pulsieren, ruhigere
Feldbildung oder räumliche Ausbreitung. Der Übergang soll eher als allmähliche
Entdeckung denn als harter Zustands-Schalter erscheinen.

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
- Monitorvorschau und Fassadenbild müssen visuell eng genug verwandt bleiben,
  damit die Kausalität verständlich wird;
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

## Stand-Konfiguration

`station.monitor` und `station.prompt` gehören nicht unter `effects`, weil sie
Vermittlungs-/Standfunktionen und keine visuellen Effektfamilien sind.

Verbindlich:

- `station.monitor.enabled` schaltet den Publikumsmonitor.
- `station.monitor.mode = "facade_preview"` ist der bevorzugte Zielmodus.
- `station.monitor.show_camera_image` bleibt im Publikumsbetrieb `false`.
- `station.prompt.enabled` schaltet den kurzen Sprachimpuls.
- `station.prompt.prompt_key` referenziert einen Eintrag in
  `config/prompts.json`.
- Neue Promptvarianten werden zentral dort ergänzt und ästhetisch geprüft.

## Räumlicher und technischer Rahmen

- Kein ganzer Straßenzug: vorgesehen ist ein begrenzter, beleuchteter Bereich am
  Stand bzw. im Eingangsbereich des Kirchenamtes.
- Zielgröße ungefähr **2–20 gleichzeitig erfasste Personen**.
- RGB-Kamera ist zunächst Primärlösung; IR/Tiefe sind Optionen nach Realwelt-Test.
- Beleuchtung, Entfernung, Sichtfeld, Verdeckungen und Track-Stabilität unter
  realen Abendbedingungen früh testen.
- Zwischen Kamerastand/Sensorrechner und Hauptrechner liegen ungefähr 50 m.
- Primär abstrakte Resonanzdaten zum Hauptrechner übertragen; Diagnosevideo ist
  separat und nicht Bestandteil der Publikumsdarstellung.
- Für den Nahraum-Monitor einen latenzarmen Rückkanal der Visualisierung vorsehen.

## Build, Test & Entwicklung

```powershell
python -m venv .venv; .\.venv\Scripts\Activate.ps1
pip install -r capture/requirements.txt
python capture/download_model.py

python -m unittest discover -s tests -v
python -m capture.tracker --sim
python -m capture.tracker --list-cameras
python -m capture.tracker --camera 1
```

Godot 4.7: `renderer/project.godot` importieren, mit **F5** starten.

## Test-Pflicht (verbindlich)

- **Jede Änderung wird über Tests verifiziert.** Vor Abschluss läuft
  `python -m unittest discover -s tests -v` grün durch, soweit die Änderung mit
  der verfügbaren Umgebung ausführbar ist.
- Neue oder geänderte Logik in `capture/` erhält passende Tests in `tests/`.
- Test-Design: Logik von Hardware/ML trennen. Reine Mathematik und CLI/Config
  gehören in test-bare Funktionen; OpenCV/MediaPipe/Godot werden nicht in
  Unit-Tests geladen.
- Erfolgs- und Fehlerpfade prüfen.
- Visuelle Änderungen zusätzlich im Godot-Simulator prüfen.
- Neue Resonanzsignale im Simulator mit repräsentativen Situationen abbilden.
- Für Monitor-/Promptlogik zusätzlich testen: deaktivierter Zustand, ungültiger
  `prompt_key`, fehlende Promptdatei und sichere Fallbacks.
- Der Realwelt-Test muss ausdrücklich auch die **Entdeckbarkeit der Interaktion**
  prüfen: Erkennen Menschen ohne Erklärung den Zusammenhang? Führt der Monitor
  den Blick zur Fassade? Bewirkt der Satz tatsächlich Verweilen?

## Coding Style

Python: 4 Leerzeichen Einrückung, UTF-8 mit echten Umlauten, Typannotationen an
öffentlichen Funktionen, `snake_case` für Funktionen/Variablen, `PascalCase` für
Klassen. Kleine, einzweckige Module; keine versteckten Globals.

Godot/GDScript: Effektfamilien möglichst getrennt halten. Keine große monolithische
Effektklasse aufbauen, wenn eine Materialität eigenständig konfigurierbar und
abschaltbar sein soll.

## Datenschutz (KO-Kriterium)

- Bildverarbeitung läuft **ausschließlich lokal**. Es werden **keine** Bilder
  oder Videos gespeichert oder in die Cloud übertragen.
- Über das Produktionsprotokoll wandern nur abstrakte Zahlenwerte wie Position,
  Intensität, Resonanzqualitäten, Beziehungen und ausgewählte Zustandsereignisse.
- Keine Gesichtserkennung, Personenidentifikation oder biometrische Zuordnung.
- Ein lokaler Diagnose-Videostream darf nur für Aufbau/Kalibrierung dienen.
- **Der Publikumsmonitor zeigt kein Kameravideo.**

## Kameras (Windows-Hinweis)

Neben physischen Webcams existieren oft **virtuelle Kameras** (OBS, Handy-als-
Webcam, Hersteller-Tools). `--camera 0` erwischt häufig eine solche. Mit
`--list-cameras` die Indizes ermitteln und den richtigen per `--camera N` oder in
`config.json` (`camera.index`) setzen. Backend über `--backend {any,dshow,msmf}`
bzw. `camera.backend` wählbar.

## Commits & Pull Requests

Kurze imperative Betreffzeilen, optional nach Bereich (z. B. `capture:`,
`renderer:`, `docs:`, `config:`). Unabhängige Änderungen trennen. PRs beschreiben
nicht nur die technische Änderung, sondern bei visuellen, sprachlichen oder
interactionalen Änderungen auch die **sichtbare Wirkung und Resonanzabsicht**.
Ausgeführte Validierungsbefehle auflisten; bei visuellen Änderungen Screenshot/
kurzes Video beifügen.
