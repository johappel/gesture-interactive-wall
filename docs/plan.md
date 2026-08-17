# WIRKLICHT — Projektplan & Roadmap

Dieses Dokument ist die **gemeinsame Diskussionsgrundlage**. Bitte direkt hier
kommentieren / ändern — offene Entscheidungen stehen am Ende.

Ereignis: **Lichterfest Bad Wilhelmshöhe, 30.10.2026, 18–22 Uhr** (Dämmerung/Nacht).
Rahmen: *Licht in der Dunkelheit* — Menschen wirken wie Lichter; jede Bewegung,
jede Nähe, jede Geste wird auf der Fassade sichtbar.

## 1. Grundprinzip (unverändert, KO-Kriterium)

- Bildverarbeitung **ausschließlich lokal**, **keine** Speicherung/Übertragung
  von Bildern.
- Über UDP (`127.0.0.1`) nur **abstrakte Zahlen** (Position, Intensität, Gesten-
  Signale) → Renderer → Beamer.

## 2. Architektur (Kurzform, Details in `protocol.md`)

```
Kamera ─[OpenCV]→ MediaPipe Pose ─[features.py]→ Body-/Gesten-Signale
       ─JSON/UDP→ Godot 4.7 (Licht, Partikel, Spuren, Lichtkugeln, Wellen) → Beamer
```

## 3. Status

| Phase | Inhalt | Stand |
|------:|--------|-------|
| 0 | Repo-Gerüst, Config, Protokoll, Tests | ✅ |
| 1 | Capture-MVP: Ganzkörper-Pose, Features, UDP, Simulator | ✅ |
| 2 | Renderer-MVP: Lichtgestalten, Bloom | ✅ |
| 3 | Leuchtspuren (Trails) | ✅ |
| 4 | Multi-Person + Lichtbrücken (Nähe) | ✅ |
| **4.5** | **Gestenerkennung (siehe §5)** | 🔜 **nächster Schritt** |
| 5 | Klang (optional, OSC) | offen |
| 6 | Projektion & Kalibrierung (Fassaden-Mapping) | offen |
| 7 | Nacht-Robustheit & Hardware (IR/Tiefe) | offen |
| 8 | DSGVO/Beschilderung & Betriebshandbuch | offen |

Heute erfasst das System bereits: Position, Geschwindigkeit, **Bewegungs-
intensität** und **Armöffnung** pro Person sowie **Nähe** zwischen Personen.
Das sind *kontinuierliche* Signale — noch **keine benannten Gesten**.

## 4. Zu deinen Beobachtungen (Kamera & Warnungen)

- **Kamera-Index:** `--list-cameras` findet mehrere 640×480-Geräte, weil Windows
  virtuelle + physische Kameras (und Doppel-Registrierungen) meldet. Dass
  `camera.index = 1` in `config.json` funktioniert, ist das erwartete Ergebnis —
  Index 0 war die virtuelle „VCAM". **→ erledigt.**
- **`obsensor ... Camera index out of range` / `VIDEOIO/FFMPEG ... libavdevice`:**
  harmlose Probe-/Backend-Meldungen von OpenCV beim Durchtesten der Indizes.
- **`Using NORM_RECT without IMAGE_DIMENSIONS ...`:** harmlose MediaPipe-Warnung
  des Landmark-Projektors; beeinflusst das Tracking nicht. Kann später durch
  Übergabe der Bildmaße unterdrückt werden (Kosmetik, keine Funktion).

## 5. Gestenerkennung — Konzept (Kern dieses Plans)

**Kurzantwort: Ja, machbar** — aber auf **Arm-/Körper-Ebene**, nicht auf Finger-
Ebene (Begründung in §7). Gesten sind *abgeleitete Signale* auf dem vorhandenen
Skelett (Schultern, Ellbogen, Handgelenke, Hüften, Nase). Wir unterscheiden:

- **Kontinuierliche Signale** (0..1, pro Frame) → treiben Aussehen an
  (Farbe, Größe, Wellen).
- **Diskrete Ereignisse** (einmaliger Auslöser) → treiben Aktionen an
  (Lichtkugel abschießen, Blitz/Burst).

### 5.1 Gesten-Katalog

| Deine Geste | Pose-Signal (aus Landmarks) | Typ | Visualisierung |
|-------------|-----------------------------|-----|----------------|
| **Zeigen / Arm ausstrecken** | Vektor Schulter→Handgelenk lang + schnelle Auswärtsbewegung des Handgelenks | Ereignis `shoot` (+ Richtung) | Lichtkugel startet am Handgelenk, fliegt in Zeigerichtung |
| **Gestikulieren (Arme fuchteln)** | hohe Handgelenk-Geschwindigkeit (steckt schon in `intensity`) | kontinuierlich | mehr Funken/Partikel, hellere Aura |
| **Klatschen** | beide Handgelenke nähern sich schnell an (kleiner Abstand + hohe Schließ-Geschwindigkeit) auf Brusthöhe | Ereignis `clap` | Blitz/Schockwelle, kurzer Ton |
| **Recken / Arme hoch** | beide Handgelenke oberhalb der Schultern/Nase | kontinuierlich `reach` 0..1 | Lichtsäulen steigen auf, Aura wächst nach oben |
| **Klein machen / ducken** | Körperhöhe (Nase→Hüfte) schrumpft bzw. Nase sinkt Richtung Hüfte | kontinuierlich `crouch` 0..1 | Farbwechsel (warm→kühl), Aura sammelt sich |
| **Arme wiegen** | Handgelenk-x pendelt (Vorzeichenwechsel der Handgelenk-Geschwindigkeit über ein Zeitfenster) | kontinuierlich `sway` (Amplitude/Phase) | Wellen/Ranken, die seitlich über die Fassade laufen |

### 5.2 Protokoll-Erweiterung (Vorschlag)

Ergänzung zum bestehenden Frame (siehe `protocol.md`) — **abwärtskompatibel**,
Renderer ignoriert unbekannte Felder:

```json
{
  "bodies": [
    {
      "id": 0,
      "x": 0.5, "y": 0.4, "vx": 0.1, "vy": 0.0,
      "intensity": 0.3, "openness": 0.6,
      "reach": 0.0,        // 0..1  Arme über Schulterhöhe
      "crouch": 0.0,       // 0..1  klein machen / ducken
      "sway": 0.0          // 0..1  Amplitude der Arm-Wiege-Bewegung
    }
  ],
  "events": [
    { "type": "shoot", "id": 0, "x": 0.62, "y": 0.35, "dx": 0.8, "dy": -0.6, "strength": 0.9 },
    { "type": "clap",  "id": 1, "x": 0.40, "y": 0.45, "strength": 1.0 }
  ]
}
```

- Neue **kontinuierliche** Felder (`reach`, `crouch`, `sway`) werden wie
  `intensity`/`openness` in `features.py` berechnet und pro Frame gesendet.
- Neuer **`events[]`**-Kanal für einmalige Auslöser (`shoot`, `clap`, …) mit
  Entprellung (Cooldown pro Person, damit ein Klatschen nicht 30× feuert).

### 5.3 Umsetzung in Etappen (Phase 4.5)

1. **Signale in `features.py`** (reine Mathematik, testbar): `reach`, `crouch`,
   `sway`; Event-Detektoren `clap`, `shoot` mit Cooldown. **Tests zuerst**
   (Erfolgs- und Fehlerpfade), gemäß `AGENTS.md`.
2. **Simulator** (`sim.py`) um Bewegungen erweitern, die die Gesten auslösen —
   damit ohne Kamera testbar.
3. **`protocol.md`** um die neuen Felder/Events ergänzen.
4. **Renderer** (Godot): `reach`→Lichtsäulen, `crouch`→Farbwechsel,
   `sway`→Wellen; `events` → Lichtkugeln/Bursts.
5. Feintuning der Schwellwerte über `config.json` (`gestures`-Block).

## 6. Roadmap-Details Phasen 5–8

- **Phase 5 — Klang (optional):** Frame zusätzlich als OSC spiegeln
  (`/wirklicht/body|pair|crowd|event`), Ableton/SuperCollider koppelt Intensität/
  Events an Sound. Alternativ prozedural in Godot.
- **Phase 6 — Projektion & Kalibrierung:** Vollbild, Eckpunkt-/Warp-Shader für
  das Fassaden-Mapping, Laden/Speichern der Kalibrierung. **Kritisch für den
  Veranstaltungsort.**
- **Phase 7 — Nacht-Robustheit & Hardware:** RGB-Webcam versagt bei Dunkelheit →
  IR-Beleuchtung oder Tiefenkamera (z. B. RealSense/OAK), Mehrkamera-Fusion,
  Performance-Tuning. **Kritisch für den Termin (18–22 Uhr).**
- **Phase 8 — DSGVO/Betrieb:** Beschilderung „lokale, anonyme Verarbeitung",
  Kiosk-/Autostart, Failsafe, Betriebshandbuch.

## 7. Grenzen & bewusste Entscheidungen

- **Keine Finger-/Handzeichen** (Faust, „V", einzelner Zeigefinger): MediaPipe
  **Pose** liefert nur Körper-Landmarks, keine Finger. Feinere Handerkennung
  bräuchte MediaPipe **Hands** — auf Fassaden-Distanz und bei Nacht unzuverlässig.
  → „Zeigen" = **ganzer ausgestreckter Arm**, nicht der Finger.
- **Distanz/Auflösung:** Je weiter das Publikum, desto gröber die Pose. Gesten
  auf Arm-/Körper-Ebene sind robust; Feinheiten nicht.
- **Nacht:** Ohne IR/Tiefe kein verlässliches Tracking im Dunkeln (siehe Phase 7).

## 8. Offene Entscheidungen (bitte kommentieren)

1. **Gesten-Umfang für den ersten Wurf:** Reicht `shoot` (Zeigen→Lichtkugel) +
   `clap` + `reach` + `sway` + `crouch`, oder Priorisierung?
2. **Diskret vs. kontinuierlich:** Sollen Lichtkugeln nur per Ereignis („Abschuss")
   entstehen, oder auch dauerhaft bei ausgestrecktem Arm „tropfen"?
3. **Klang (Phase 5):** überhaupt gewünscht, und wenn ja Ableton oder in Godot?
4. **Hardware (Phase 7):** Budget/Bezug einer IR- oder Tiefenkamera klären —
   das bestimmt die Nacht-Tauglichkeit am 30.10.
5. **Reihenfolge:** Erst Gesten (4.5) fertig machen, oder parallel Phase 6
   (Projektion) angehen, weil ortsabhängig?
