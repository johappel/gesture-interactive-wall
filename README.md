# WIRKLICHT — Gesten-Resonanz auf der Fassade

Interaktive Licht-Installation für das **Lichterfest Bad Wilhelmshöhe** (30.10.2026).
Kameras erfassen Gesten und Bewegungen des Publikums, ein Rechner übersetzt sie
**vollständig lokal und anonym** in Licht, Farbe und Spuren auf einer Fassade.

> Theologisch-künstlerischer Rahmen: *Licht in der Dunkelheit*. Menschen wirken wie
> Lichter — jede Bewegung, jede Nähe, jede Freude ist wirksam und wird sichtbar.

## Datenschutz (KO-Kriterium)

- Die Bildverarbeitung läuft **ausschließlich lokal** auf dem Rechner.
- Es werden **keine Bilder oder Videos** gespeichert oder ins Netz übertragen.
- Über UDP (nur `127.0.0.1`) wandern **nur abstrakte Zahlenwerte** (Positionen,
  Intensität) an den Renderer — keine Personendaten, keine Cloud.

## Architektur

```
 Kamera ──► capture/ (Python + MediaPipe)  ──JSON/UDP──►  renderer/ (Godot 4)  ──► Beamer
           Pose-Tracking + Feature-Extraktion            Licht, Partikel, Spuren, Bloom
```

- `capture/` — Python-App: Ganzkörper-Pose-Tracking (MediaPipe), Feature-Extraktion,
  Versand als JSON über UDP.
- `renderer/` — Godot-4-Projekt: empfängt die Werte und erzeugt die Visualisierung.
- `config/` — zentrale Konfiguration (Kamera, Netzwerk, Feature-Parameter).
- `docs/` — Protokoll und Betriebsanleitung.
- `tests/` — Unit-Tests der Feature-Mathematik (ohne Kamera lauffähig).

## Schnellstart

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
Im Projektmanager **Importieren** → `renderer/project.godot` auswählen → **Importieren & Bearbeiten**.
Dann mit **F5** starten.

> Zeigt der Projektmanager einen alten Eintrag als „Fehlendes Projekt", diesen mit
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

## Status

- [x] Phase 0 — Konzept & Repo-Gerüst
- [x] Phase 1 — Capture-MVP (Ganzkörper, Features, UDP) + Simulator
- [x] Phase 2 — Renderer-MVP (Godot: Lichtgestalten, Bloom)
- [x] Phase 3 — Leuchtspuren (Trails)
- [x] Phase 4 — Multi-Person + Verbundenheit (Lichtbrücken)
- [ ] Phase 4.5 — Gestenerkennung (Zeigen/Lichtkugeln, Klatschen, Recken, Wiegen)
- [ ] Phase 5 — Klang (optional)
- [ ] Phase 6 — Projektion & Kalibrierung
- [ ] Phase 7 — Nacht-Robustheit & Hardware
- [ ] Phase 8 — DSGVO/Beschilderung & Betriebshandbuch

Vollständiger Plan & Gesten-Konzept: [docs/plan.md](docs/plan.md).
Datenprotokoll: [docs/protocol.md](docs/protocol.md).
