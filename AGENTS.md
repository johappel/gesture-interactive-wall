# Repository Guidelines (WIRKLICHT)

Gesten-Resonanz auf einer Fassade: Kameras erfassen Bewegungen, ein Rechner
übersetzt sie **vollständig lokal und anonym** in Licht auf einer Projektion.

## Projektstruktur

- `capture/` — Python-App (MediaPipe Pose-Tracking, Feature-Mathematik, UDP-Versand).
  - `tracker.py` — Einstiegspunkt (`python -m capture.tracker`), CLI, Frame-Bau.
  - `features.py` — reine Python-Mathematik (ID-Tracking, Intensität, Paare) — **ohne** ML-Abhängigkeiten, damit unit-testbar.
  - `pose.py`, `camera.py`, `net.py`, `sim.py` — MediaPipe, Webcam (OpenCV), UDP, Simulator.
- `renderer/` — Godot-4.7-Projekt (empfängt JSON/UDP, erzeugt Licht/Partikel/Spuren).
- `config/config.json` — zentrale Konfiguration (Kamera, Netzwerk, Feature-Parameter).
- `docs/protocol.md` — verbindliches JSON/UDP-Protokoll zwischen capture ↔ renderer.
- `tests/` — Unit-Tests (ohne Kamera/Godot lauffähig).

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
  `python -m unittest discover -s tests -v` grün durch.
- Neue oder geänderte Logik in `capture/` erhält passende Tests in `tests/`
  (Dateiname nach Verhalten, z. B. `test_features.py`, `test_cli.py`).
- Test-Design: Logik von Hardware/ML trennen. Reine Mathematik und CLI/Config
  gehören in test-bare Funktionen (siehe `features.py`, `build_parser`,
  `apply_overrides`); OpenCV/MediaPipe/Godot werden **nicht** in Unit-Tests
  geladen. `cv2` wird lazy importiert, damit Tests ohne Kamera laufen.
- Erfolgs- **und** Fehlerpfade prüfen (z. B. unbekanntes Backend, leere Eingaben).

## Coding Style

Python: 4 Leerzeichen Einrückung, UTF-8 mit echten Umlauten, Typannotationen an
öffentlichen Funktionen, `snake_case` für Funktionen/Variablen, `PascalCase` für
Klassen. Kleine, einzweckige Module; keine versteckten Globals.

## Datenschutz (KO-Kriterium)

- Bildverarbeitung läuft **ausschließlich lokal**. Es werden **keine** Bilder
  oder Videos gespeichert oder übertragen.
- Über UDP (nur `127.0.0.1`) wandern **nur abstrakte Zahlenwerte** (Positionen,
  Intensität) — keine Personendaten, keine Cloud. Dies gilt für jede Änderung.

## Kameras (Windows-Hinweis)

Neben physischen Webcams existieren oft **virtuelle Kameras** (OBS, Handy-als-
Webcam, Hersteller-Tools). `--camera 0` erwischt häufig eine solche (erkennbar
an Logo-Bild, „0 Personen"). Mit `--list-cameras` die Indizes ermitteln und den
richtigen per `--camera N` oder in `config.json` (`camera.index`) setzen. Backend
über `--backend {any,dshow,msmf}` bzw. `camera.backend` wählbar.

## Commits & Pull Requests

Kurze imperative Betreffzeilen, optional nach Bereich (z. B. `capture:`,
`renderer:`). Unabhängige Änderungen trennen. PRs beschreiben die sichtbare
Wirkung, listen ausgeführte Validierungsbefehle (inkl. Testlauf) und fügen bei
visuellen Änderungen einen Screenshot/kurzes Video bei.
