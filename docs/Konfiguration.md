# WIRKLICHT — Konfiguration

Zentrale Konfigurationsdatei: **`config/config.json`**.
Sprachimpulse liegen getrennt in **`config/prompts.json`**.

Diese Datei erklärt alle Abschnitte und Parameter und ihre Wirkung. Sie ist als
Nachschlagewerk gedacht, nicht als Bedienungsanleitung. Verbindliche
Architekturregeln stehen in `AGENTS.md`, das Datenformat in `docs/protocol.md`.

## Grundregeln

- **Capture** (`capture/`) liest `camera`, `network`, `pose`, `features`, `debug`.
- **Renderer** (Godot, `renderer/`) liest `network.port`, `effects` und `station`.
- Der Renderer fällt bei fehlenden oder ungültigen Werten auf sichere Defaults
  zurück und schreibt eine Warnung ins Godot-Log. Eine kaputte Config darf den
  Betrieb nie verhindern.
- Jede eigenständige Effektfamilie hat einen eigenen `enabled`-Schalter.
  `enabled: false` bedeutet: **nicht erzeugen und nicht simulieren** — nicht bloß
  unsichtbar machen.
- Die Datei wird als UTF-8 (mit oder ohne BOM) gelesen. Echte Umlaute sind
  erlaubt.

---

## `camera` — Kameraquelle (Capture)

| Parameter | Typ | Wirkung |
|---|---|---|
| `index` | int | OpenCV-Geräteindex. Unter Windows ist er **nicht stabil**: virtuelle Kameras (OBS, Handy-Webcam) und ein USB-Portwechsel verschieben ihn. Bei Backend `any` kodiert OpenCV das Backend in die hohen Stellen (z. B. `701` = DirectShow-Kamera 1). |
| `width`, `height` | int | Angeforderte Auflösung. Die Kamera kann abweichende Werte liefern. Höhere Auflösung = bessere Pose-Erkennung, aber mehr CPU-Last. |
| `flip` | bool | Spiegelt das Bild horizontal. Sinnvoll bei frontaler Webcam, damit Bewegung und Fassade nicht seitenverkehrt wirken. |
| `backend` | `"any"` \| `"dshow"` \| `"msmf"` | OpenCV-Backend. `dshow` findet physische Webcams unter Windows am zuverlässigsten; `any` lässt OpenCV wählen. |
| `name` | string | Menschenlesbarer Kameraname (z. B. `"Logitech StreamCam"`). Dient der Wiedererkennung nach Indexwechsel. |
| `device_path` | string | Windows-Gerätepfad. **Präziseste** Identität: bleibt auch bei Index- und Portwechsel erhalten. |
| `vid`, `pid` | string | USB-Hersteller-/Produkt-ID (Hex). Zweitbeste Identität, wenn der Gerätepfad fehlt. |

**Auflösungsreihenfolge der Kameraauswahl** (`capture/camera.py`):
`device_path` → `vid`/`pid` → `name` → `index`+`backend`.
Die ersten drei überleben einen USB-Portwechsel, der Index nicht.

**CLI-Overrides** (überschreiben die Config für diesen Lauf):
`--camera N` setzt `index` und verwirft `name`/`device_path`/`vid`/`pid`;
`--backend {any,dshow,msmf}` setzt `backend`. `--list-cameras` zeigt alle
gefundenen Kameras mit Index, Backend und USB-Kennung.

---

## `network` — Übertragung Capture → Renderer

| Parameter | Typ | Wirkung |
|---|---|---|
| `host` | string | Zieladresse. Muss `127.0.0.1` bleiben — es verlassen nur abstrakte Zahlen den Rechner (Datenschutz-KO-Kriterium). |
| `port` | int | UDP-Port. Capture sendet dorthin, der Renderer bindet denselben Port. Beide Seiten müssen übereinstimmen. |

Es wird **ein JSON-Paket pro Frame** gesendet, ohne Bilder oder Videos.

---

## `pose` — Pose-Erkennung (Capture)

| Parameter | Typ | Wirkung |
|---|---|---|
| `model_path` | string | Pfad zum MediaPipe-PoseLandmarker-Modell (`.task`), relativ zum Projektwurzelverzeichnis. Fehlt die Datei, fällt Capture auf Einzelperson-Tracking zurück (Legacy-API). |
| `num_poses` | int | Maximale Anzahl gleichzeitig erkannter Personen. Höher = mehr Rechenlast. Zielgröße der Installation: 2–20 Personen. |
| `min_detection_confidence` | 0..1 | Mindestkonfidenz für Erkennung **und** Tracking. Niedriger = mehr (auch falsche) Treffer, höher = stabiler, aber empfindlicher gegen Verdeckung. |
| `min_torso_visibility` | 0..1 | Qualitätsschwelle: Schultern und Hüften müssen mindestens so sichtbar sein. Filtert Objektkanten, die MediaPipe gelegentlich als Pose deutet. Bewusst klein und **nicht biometrisch**. |
| `active_region.enabled` | bool | Schaltet einen rechteckigen Interaktionsbereich frei. Nur wenn `true`, wird der Bereich ausgewertet. |
| `active_region.x_min/x_max/y_min/y_max` | 0..1 | Grenzen des Bereichs in normierten Bildkoordinaten. Nur Torsomitten innerhalb des Rechtecks werden übernommen. Ungültige Werte (`x_min >= x_max` usw.) verwerfen **alle** Personen. |

Der aktive Bereich ist das Mittel, um nur die beleuchtete Interaktionszone vor
der Fassade zu erfassen und Passant:innen am Rand auszublenden.

---

## `features` — Tracking und Resonanzsignale (Capture)

Diese Werte formen die anonymen Signale, die der Renderer künstlerisch deutet.
Reine Mathematik, ohne ML-Abhängigkeit — vollständig unit-testbar.

### Intensität

| Parameter | Typ | Wirkung |
|---|---|---|
| `intensity_scale` | float | Verstärkung der gemessenen Bewegung (Körper- plus Handgelenkgeschwindigkeit). Höher = schon kleine Bewegungen wirken intensiv. |
| `intensity_smoothing` | 0..1 | Glättungsfaktor pro Frame. Klein = träge und ruhig, groß = schnell und zappelig. |

### Nähe und Beziehung

| Parameter | Typ | Wirkung |
|---|---|---|
| `proximity_threshold` | 0..1 | Abstand, unter dem zwei Personen als „nah“ gelten und ein `pair` bilden. Größer = mehr Brücken. |

### Track-Lebenszyklus

| Parameter | Typ | Wirkung |
|---|---|---|
| `track_max_dist` | 0..1 | Maximaler Abstand zwischen Vorhersage und neuer Erkennung, um sie demselben Track zuzuordnen. Zu klein = ID-Wechsel, zu groß = Verwechslung benachbarter Personen. |
| `track_timeout` | Sekunden | Veralteter Name für die Grace-Period; wird nur genutzt, wenn `track_grace_period` fehlt. |
| `track_grace_period` | Sekunden | Wie lange ein kurz nicht erkannter Track intern erhalten bleibt und wieder zugeordnet werden kann. In dieser Zeit erscheint er **nicht** in `bodies`/`pairs`/`crowd`, nur in `tracking.temporarily_missing`. Verhindert, dass eine kurze Verdeckung als Austritt gilt. |
| `track_confirmation_frames` | int | Anzahl Frames, bevor ein Track sichtbar wird und ein `departure` auslösen darf. Filtert Ein-Frame-Geister. |
| `departure_edge_margin` | 0..1 | Randzone, in der ein Track als möglicher Austritt gilt. |
| `departure_min_speed` | float | Mindestgeschwindigkeit **nach außen** durch denselben Rand. Beide Bedingungen müssen zutreffen — Nähe zum Rand allein genügt nicht, damit eine Verdeckung am Rand kein ästhetisch bedeutsames Ereignis wird. |

### Ruhe (Stillness)

| Parameter | Typ | Wirkung |
|---|---|---|
| `stillness_speed_threshold` | float | Geschwindigkeit, unterhalb derer eine Person als „ruhig“ gilt. |
| `stillness_rise_seconds` | Sekunden | Zeitkonstante, mit der `stillness` bei Ruhe ansteigt. Größer = Verweilen muss länger dauern, bevor es sichtbar wird. |
| `stillness_fall_seconds` | Sekunden | Zeitkonstante, mit der `stillness` bei Bewegung wieder abfällt. Klein = Ruhe „bricht“ schnell ab. |

`stillness` ist ein kontinuierlicher, semantikfreier Wert (0 = zuletzt bewegt,
1 = über Zeit ruhig). Er ist die Grundlage dafür, dass **Bleiben eine Antwort
bekommt** — siehe `effects.stillness_resonance`.

---

## `station` — Stand, Monitor und Sprachimpuls (Renderer)

Stand-Funktionen sind bewusst **nicht** unter `effects`, weil sie Vermittlung
und keine visuellen Effektfamilien sind.

### `station.facade` — Hauptausgabe

| Parameter | Typ | Wirkung |
|---|---|---|
| `screen` | int | Bildschirmindex für die Fassade. Nicht verfügbare Werte fallen auf Bildschirm 0 zurück (mit Warnung). |
| `fullscreen` | bool | Vollbild auf dem gewählten Bildschirm. |

### `station.monitor` — Nahraum der Rückkopplung

| Parameter | Typ | Wirkung |
|---|---|---|
| `enabled` | bool | Schaltet den Publikumsmonitor. |
| `mode` | string | Zielmodus ist `"facade_preview"`: dieselbe bzw. eng verwandte Resonanzdarstellung wie auf der Fassade. Unbekannte Modi lassen den Monitor aus. |
| `show_camera_image` | bool | **Im Publikumsbetrieb `false`.** Der Renderer ignoriert `true` und warnt; das rohe Kamerabild bleibt verborgen. |
| `title` | string | Fenstertitel. |
| `screen` | int | Bildschirmindex des Monitors. Muss sich von `facade.screen` unterscheiden, sonst bleibt der Monitor aus. |
| `fullscreen` | bool | Vollbild oder Fenster. |
| `width`, `height` | int | Fenstergröße im Fenstermodus. |
| `prompt_font_size` | int | Schriftgröße des Sprachimpulses auf dem Monitor. |

Der Monitor zeigt eine Vorschau der Fassadendarstellung, damit Menschen die
Kopplung **Ich ↔ Resonanz ↔ Fassade** erkennen. Er darf die Fassade nicht als
Blickziel ersetzen.

### `station.prompt` — Kurzer Sprachimpuls

| Parameter | Typ | Wirkung |
|---|---|---|
| `enabled` | bool | Schaltet den Sprachimpuls. |
| `source` | string | Pfad zur Promptdatei. Absolute Pfade und `..` werden abgelehnt. |
| `prompt_key` | string | Einzelner Fallback-Key, falls `prompt_keys` leer oder ungültig ist. |
| `prompt_keys` | string[] | Liste der kuratierten Keys, die im Wechsel gezeigt werden. Unbekannte Keys werden ignoriert. |
| `fade_in_seconds` | Sekunden | Einblenddauer des Textes. |
| `fade_out_seconds` | Sekunden | Ausblenddauer. |
| `underline_seconds` | Sekunden | Dauer, in der die Lichtspur unter dem Text aufgebaut wird. |
| `star_tail_fade_seconds` | Sekunden | Nachleuchten der Lichtspur nach dem Aufbau. |
| `idle_cycle_seconds` | Sekunden | Ruhezeit ohne Personen, nach der der nächste Impuls angeboten wird. |

**Verhalten:** Der Impuls erscheint nur, wenn **niemand** erfasst ist. Sobald
Personen da sind, blendet er aus. Der Wechsel erfolgt nie in place: der alte
Satz verschwindet, bevor der nächste erscheint. Fehlt die Promptdatei oder ist
kein gültiger Key vorhanden, wird einfach kein Text gezeigt (kein Absturz).

Sprachimpulse werden ausschließlich in `config/prompts.json` kuratiert und als
inhaltlich-ästhetische Änderungen behandelt — nicht als UI-Copy.

---

## `effects` — Visuelle Effektfamilien (Renderer)

### Globale Schalter

| Parameter | Typ | Wirkung |
|---|---|---|
| `enabled` | bool | Hauptschalter. `false` schaltet **alle** Effektfamilien ab. |
| `minimal_mode` | bool | Live-Fallback: lässt nur `body_glow`, `trails` und `proximity_bridges` aktiv und stellt so einen stabilen Grundzustand her. |

### `body_glow` — Lichtkörper

| Parameter | Typ | Wirkung |
|---|---|---|
| `enabled` | bool | Zeigt den leuchtenden Körper. |

Größe folgt `openness` und `intensity`, Farbe wandert mit `intensity` von Gold
nach Rot, Helligkeit steigt mit `intensity`.

### `trails` — Bewegungsspur

| Parameter | Typ | Wirkung |
|---|---|---|
| `enabled` | bool | Zeigt die Spur. Beim Abschalten werden vorhandene Punkte gelöscht. |
| `max_points` | int | Maximale Anzahl gespeicherter Spurpunkte. Mehr = längere Spur, mehr Speicher/Zeichenaufwand. |
| `width` | float | Linienbreite der Spur. |

### `sparks` — Funken

| Parameter | Typ | Wirkung |
|---|---|---|
| `enabled` | bool | Zeigt Funken. |
| `amount_min`, `amount_max` | int | Partikelanzahl bei minimaler bzw. maximaler Intensität (dazwischen interpoliert). |
| `lifetime` | Sekunden | Lebensdauer eines Partikels. |
| `velocity_min`, `velocity_max` | float | Startgeschwindigkeit bei minimaler bzw. maximaler Intensität. |
| `activation_intensity` | 0..1 | Schwelle, ab der Funken überhaupt entstehen. Verhindert, dass ein kurzer Kamera-Geist als Partikelblitz aufleuchtet. |

### `proximity_bridges` — Nähe-Brücken

| Parameter | Typ | Wirkung |
|---|---|---|
| `enabled` | bool | Zeichnet Lichtbrücken zwischen nahen Personen. Beim Abschalten werden `pairs` verworfen. |

Breite und Helligkeit folgen `proximity`.

### `stillness_resonance` — Antwort auf Bleiben

| Parameter | Typ | Wirkung |
|---|---|---|
| `enabled` | bool | Zeigt das ruhige Feld. Beim Abschalten wird der Prozess-Node entfernt (nicht nur versteckt). |
| `min_presence_seconds` | Sekunden | Anwesenheitsdauer, ab der das Feld seine volle Reife erreicht. |
| `pulse_seconds` | Sekunden | Periodendauer des langsamen Pulsierens. |
| `max_scale` | float | Maximale Feldgröße bei voller Reife und Ruhe. |

Das Feld ist **keine Belohnung für eine Geste**: Anwesenheitszeit und beobachtete
Ruhe blenden kontinuierlich in ein langsames Pulsieren ein. Damit bekommt
Bleiben eine qualitativ andere Antwort als Vorübergehen.

### `aftereffect_waves` — Nachwirkung nach dem Gehen

| Parameter | Typ | Wirkung |
|---|---|---|
| `enabled` | bool | Zeigt Nachwirkungswellen. |
| `group_window_seconds` | Sekunden | Zeitfenster, in dem Austritte an derselben Kante zu **einer** Welle gebündelt werden. |
| `group_distance` | 0..1 | Maximaler Achsabstand, innerhalb dessen Austritte gruppiert werden. |
| `group_width_per_departure` | float | Zusätzliche Bandbreite pro weiterem Austritt in der Gruppe. Größere Gruppen erzeugen breitere Wellen. |
| `duration_seconds` | Sekunden | Gesamtlebensdauer einer Welle. |
| `initial_origin_outset` | 0..1 | Startabstand des virtuellen Ursprungs **außerhalb** des Bildrands. |
| `origin_escape_distance` | 0..1 | Wie weit der Ursprung im Verlauf nach außen wandert. Der sichtbare Teil ist dadurch eine zurücklaufende Resonanz, keine Person-Linie. |
| `start_radius` | 0..1 | Anfangsradius der Welle. |
| `propagation_speed` | float | Ausbreitungsgeschwindigkeit (Radius pro Sekunde). |
| `band_width` | 0..1 | Breite des Hauptbands. Größer = weicher, diffuser. |
| `source_glow_radius` | 0..1 | Radius des Quell-Leuchtens am Ursprung. |
| `echo_spacing` | 0..1 | Abstand eines inneren Echos zum Hauptband. |
| `echo_strength` | 0..1 | Stärke dieses Echos. |
| `max_alpha` | 0..1 | Maximale Deckkraft der Welle. Bewusst niedrig gehalten (Nachtprojektion). |
| `fade_start_progress` | 0..1 | Fortschritt, ab dem die Welle zu verblassen beginnt. |
| `fade_end_progress` | 0..1 | Fortschritt, bei dem die Deckkraft null erreicht. Muss größer als `fade_start_progress` sein. |
| `glow_strength` | float | Helligkeitsverstärkung der Wellenfarbe. |
| `warm_color` | Hex | Farbe am Anfang (nah am Austritt). |
| `blue_color` | Hex | Farbe im weiteren Verlauf; die Welle wandert von warm nach kühl. |
| `dedupe_seconds` | Sekunden | Sperrzeit pro Austritts-ID gegen doppelte Wellen aus wiederholten UDP-Paketen. |

Wellen sind bewusst anonym: nur Kante, gemeinsame Achse und Gruppengröße
überleben. Keine Splash- oder Feuerwerk-Ästhetik.

### Reservierte Effektfamilien

`mist`, `waves`, `floating_bodies`, `crowd_field` sind als Schalter vorhanden,
aber noch nicht vollständig implementiert. Sie stehen auf `enabled: false` und
werden derzeit nicht erzeugt.

---

## `debug` — Diagnose (Capture)

| Parameter | Typ | Wirkung |
|---|---|---|
| `preview` | bool | Öffnet ein lokales Vorschaufenster mit Overlay (IDs, Intensität, Personenzahl). Nur für Aufbau und Kalibrierung. Taste `q` beendet. **Nicht** Teil der Publikumsdarstellung. |

---

## `updates` — Automatische Updates

| Parameter | Typ | Wirkung |
|---|---|---|
| `enabled` | bool | Standard `false`. Es gibt keine stillen Updates beim normalen Start. Updates werden bewusst vor oder nach einer Veranstaltung über `update.ps1` ausgeführt. |

---

## `config/prompts.json` — Sprachimpulse

```json
{
  "prompts": {
    "stay_question": "Was geschieht, wenn du bleibst?",
    "stay_invitation": "Bleib einen Augenblick.",
    "trace_hint": "Deine Bewegung hinterlässt etwas."
  }
}
```

- Jeder Eintrag ist ein Key → Text. Leere oder nicht-textuelle Einträge werden
  ignoriert.
- `station.prompt.prompt_keys` referenziert diese Keys.
- Neue Impulse werden hier ergänzt und ästhetisch geprüft. Sie sollen Neugier
  wecken, aber keine Technik erklären und keine konkrete Geste verlangen.

---

## Sichere Defaults und Robustheit

Der Renderer normalisiert `station` und `effects` beim Start:

- Falsche Typen (z. B. `enabled: "ja"`) werden verworfen und durch Defaults
  ersetzt, mit Warnung im Log.
- Negative oder nicht-finite Zahlen werden auf sichere Werte korrigiert.
- `fade_end_progress` wird auf mindestens `fade_start_progress + 0.01` gehoben.
- Fehlt `config/config.json` ganz, nutzt der Renderer eingebaute Defaults.

Beim Start protokolliert der Renderer den Effekt- und Stand-Zustand, z. B.
`WIRKLICHT Effekte: body_glow=on, trails=on, ...` und
`WIRKLICHT Stand: fassade=screen-1, monitor=on (screen-0), prompt=on`.
Diese Zeilen sind die schnellste Prüfung, ob die Config wie beabsichtigt greift.

---

## Änderungen prüfen

Nach Änderungen an der Config:

```powershell
python -m unittest discover -s tests -v
python -m capture.tracker --sim
```

Visuelle Änderungen zusätzlich im Godot-Simulator prüfen. Für Monitor- und
Promptlogik sind zusätzlich der deaktivierte Zustand, ein ungültiger
`prompt_key`, eine fehlende Promptdatei und die sicheren Fallbacks zu testen.
