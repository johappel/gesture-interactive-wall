# WIRKLICHT — Konfiguration

Zentrale Konfigurationsdatei: **`config/config.json`**.
Sprachimpulse liegen getrennt in **`config/prompts.json`**.
Eine portable Referenz mit generischen Standardwerten liegt in
**`config/config.example.json`** (siehe „Woher die Datei kommt").

Diese Datei erklärt alle Abschnitte und Parameter und ihre Wirkung. Sie ist als
Nachschlagewerk gedacht, nicht als Bedienungsanleitung. Verbindliche
Architekturregeln stehen in `AGENTS.md`, das Datenformat in `docs/protocol.md`.

## Grundregeln

- **Capture** (`capture/`) liest `camera`, `network`, `pose`, `features`, `debug`.
- **Renderer** (Godot, `renderer/`) liest `network.port`, `effects`, `station`
  und `renderer`.
- Der Renderer fällt bei fehlenden oder ungültigen Werten auf sichere Defaults
  zurück und schreibt eine Warnung ins Godot-Log. Eine kaputte Config darf den
  Betrieb nie verhindern. Capture ist strenger: fehlt `config/config.json`,
  bricht der Start mit einer Fehlermeldung ab.
- **Live-Reload betrifft nur `effects`.** Der Renderer prüft die Datei etwa
  zweimal pro Sekunde und übernimmt Änderungen im `effects`-Block sofort.
  Alles andere braucht einen Neustart:
  - `renderer`, `station`, `network.port` → Renderer neu starten;
  - `camera`, `pose`, `features`, `debug` → Capture neu starten.
- Jede eigenständige Effektfamilie hat einen eigenen `enabled`-Schalter.
  `enabled: false` bedeutet: **nicht erzeugen und nicht simulieren** — nicht bloß
  unsichtbar machen.
- Die Datei wird als UTF-8 (mit oder ohne BOM) gelesen. Echte Umlaute sind
  erlaubt.

## Woher die Datei kommt

Bei einer Installation über `installer/` oder `install.ps1` entsteht
`config/config.json` **einmalig** aus der mitgelieferten Vorlage
`config/config.json.template`. Danach wird sie nie wieder angefasst:

- `install.ps1` schützt sie in `Sync-WirklichtProject` vor jedem Update.
- Der Installer liefert sie bewusst **nicht** mit, sondern nur die Vorlage.
- `update.ps1` legt vor jeder Änderung eine Sicherung unter
  `C:\WIRKLICHT\backup` an.

Kamera-Index, Bildschirmzuordnung und Effektschalter am Veranstaltungsort
überleben damit Updates. Wer die Vorlage ändert, ändert nur frische
Installationen — bestehende bleiben unberührt.

Drei Dateien sind dabei zu unterscheiden:

| Datei                         | Rolle                                                                                                                                                                 |
| ----------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `config/config.json`          | **Laufzeitkonfiguration.** Wird von Capture und Renderer gelesen und von den Auswahlskripten (`camera-select.ps1`, `monitor-select.ps1`) aktualisiert.                |
| `config/config.json.template` | Vorlage, die der Installer für **frische** Installationen anlegt. Entsteht beim Paketbau aus einer Config und ist nicht versioniert.                                  |
| `config/config.example.json`  | Versionierte **Referenz** mit generischen Standardwerten. Wird zur Laufzeit **nie** gelesen. Für einen neuen Stand kopieren und danach Kamera und Bildschirme wählen. |

`config/local.json` wird von Installation und Update zusätzlich als lokaler
Zustand behandelt: sie wird nie überschrieben oder mitgeliefert und vor
Änderungen gesichert. Capture und Renderer lesen sie derzeit nicht.

---

## `camera` — Kameraquelle (Capture)

| Parameter           | Typ                              | Wirkung                                                                                                                                                                                                                                                                                                                                      |
| ------------------- | -------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `index`             | int                              | OpenCV-Geräteindex. Unter Windows ist er **nicht stabil**: virtuelle Kameras (OBS, Handy-Webcam) und ein USB-Portwechsel verschieben ihn. Bei Backend `any` kodiert OpenCV das Backend in die hohen Stellen (z. B. `701` = DirectShow-Kamera 1).                                                                                             |
| `width`, `height`   | int                              | Angeforderte Auflösung. Die Kamera kann abweichende Werte liefern. Höhere Auflösung = bessere Pose-Erkennung, aber mehr CPU-Last.                                                                                                                                                                                                            |
| `fps`               | int                              | Angeforderte Bildrate. Wird nur verwendet, wenn die Kamera sie unterstützt.                                                                                                                                                                                                                                                                  |
| `fourcc`            | string                           | Angefordertes Pixelformat (Vier-Zeichen-Code, z. B. `"MJPG"`). `MJPG` erlaubt höhere Auflösungen über USB, weil weniger Daten anfallen.                                                                                                                                                                                                      |
| `latest_frame_wins` | bool                             | **Empfohlen `true`.** Ein Grab-Thread hält nur das jeweils neueste Bild; ältere Bilder werden verworfen (`dropped` in der Diagnose). Das verhindert, dass die sichtbare Pose hinter der Realität herhinkt, wenn die Inferenz langsamer ist als die Kamera. `false` liest direkt im Hauptthread und kann einen wachsenden Rückstand aufbauen. |
| `flip`              | bool                             | Spiegelt das Bild horizontal. Sinnvoll bei frontaler Webcam, damit Bewegung und Fassade nicht seitenverkehrt wirken.                                                                                                                                                                                                                         |
| `backend`           | `"any"` \| `"dshow"` \| `"msmf"` | OpenCV-Backend. `dshow` findet physische Webcams unter Windows am zuverlässigsten; `any` lässt OpenCV wählen.                                                                                                                                                                                                                                |
| `name`              | string                           | Menschenlesbarer Kameraname (z. B. `"Logitech StreamCam"`). Dient der Wiedererkennung nach Indexwechsel.                                                                                                                                                                                                                                     |
| `device_path`       | string                           | Windows-Gerätepfad. **Präziseste** Identität: bleibt auch bei Index- und Portwechsel erhalten.                                                                                                                                                                                                                                               |
| `vid`, `pid`        | string                           | USB-Hersteller-/Produkt-ID (Hex). Zweitbeste Identität, wenn der Gerätepfad fehlt.                                                                                                                                                                                                                                                           |

**Auflösungsreihenfolge der Kameraauswahl** (`capture/camera.py`):
`device_path` → `vid`/`pid` → `name` → `index`+`backend`.
Die ersten drei überleben einen USB-Portwechsel, der Index nicht.

**CLI-Overrides** (überschreiben die Config für diesen Lauf):
`--camera N` setzt `index` und verwirft `name`/`device_path`/`vid`/`pid`;
`--backend {any,dshow,msmf}` setzt `backend`. `--list-cameras` zeigt alle
gefundenen Kameras mit Index, Backend und USB-Kennung.

**Ausgehandelte Werte statt Wunschwerte:** Nach dem Öffnen liest Capture
Auflösung, Bildrate und Pixelformat per `cap.get(...)` zurück und protokolliert
Abweichungen (z. B. `[camera] Auflösung angefragt 1280x720, ausgehandelt
640x480`). OpenCV ignoriert nicht unterstützte Wünsche stillschweigend — die
Config beschreibt also eine Anforderung, nicht die Garantie. Die tatsächlich
aktiven Werte stehen in jeder Diagnosezeile (`backend`, `fourcc`,
`resolution`) und sind der schnellste Weg, eine falsch formatierte Kamera zu
erkennen.

Die Reihenfolge beim Setzen ist bewusst: Pixelformat, dann Auflösung, dann
Bildrate, danach ein möglichst kleiner Treiberpuffer
(`CAP_PROP_BUFFERSIZE = 1`). Viele Treiber liefern nur dann die gewünschte
Kombination.

---

## `network` — Übertragung Capture → Renderer

| Parameter | Typ    | Wirkung                                                                                                           |
| --------- | ------ | ----------------------------------------------------------------------------------------------------------------- |
| `host`    | string | Zieladresse. Muss `127.0.0.1` bleiben — es verlassen nur abstrakte Zahlen den Rechner (Datenschutz-KO-Kriterium). |
| `port`    | int    | UDP-Port. Capture sendet dorthin, der Renderer bindet denselben Port. Beide Seiten müssen übereinstimmen.         |

Es wird **ein JSON-Paket pro Frame** gesendet, ohne Bilder oder Videos. Das
Datenformat ist in `docs/protocol.md` verbindlich beschrieben.

Ist der Port belegt — fast immer durch einen noch laufenden alten
WIRKLICHT-Renderer — meldet der Renderer eine Warnung und versucht die Bindung
im Sekundenabstand erneut, statt still ohne Daten weiterzulaufen.

Der Simulator (`--sim`) öffnet zusätzlich einen **Debug-Steuerkanal auf
`port + 1`**. Nur das Debug-Overlay des Renderers (F3) sendet darüber einen
Szenariowechsel. Er ist loopback-only, optional, und schlägt er fehl, läuft der
Simulator mit seinem Startszenario weiter.

---

## `pose` — Pose-Erkennung (Capture)

| Parameter                               | Typ    | Wirkung                                                                                                                                                                                                                                                                                                                   |
| --------------------------------------- | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `model_path`                            | string | Pfad zum MediaPipe-PoseLandmarker-Modell (`.task`), relativ zum Projektwurzelverzeichnis. Fehlt die Datei, fällt Capture auf Einzelperson-Tracking zurück (Legacy-API) und weist im Log darauf hin; dann ist nur **eine** Person erfassbar und `num_poses` wirkungslos. Modell holen: `python capture/download_model.py`. |
| `num_poses`                             | int    | Maximale Anzahl gleichzeitig erkannter Personen. Höher = mehr Rechenlast. Zielgröße der Installation: 2–20 Personen. Nicht pauschal hochsetzen, sondern mit `python -m capture.bench` messen.                                                                                                                             |
| `min_detection_confidence`              | 0..1   | Schwelle für eine **neue** Erkennung (`min_pose_detection_confidence`). Niedriger = mehr (auch falsche) Treffer, höher = stabiler, aber träger beim Erfassen neuer Personen.                                                                                                                                              |
| `min_presence_confidence`               | 0..1   | Schwelle dafür, dass eine erkannte Pose als vorhanden gilt (`min_pose_presence_confidence`). Fehlt der Schlüssel, gilt `min_detection_confidence`.                                                                                                                                                                        |
| `min_tracking_confidence`               | 0..1   | Schwelle für die Weiterverfolgung einer bereits erkannten Pose. Fehlt der Schlüssel, gilt `min_detection_confidence`.                                                                                                                                                                                                     |
| `min_torso_visibility`                  | 0..1   | Qualitätsschwelle: Schultern und Hüften müssen mindestens so sichtbar sein. Filtert Objektkanten, die MediaPipe gelegentlich als Pose deutet. Bewusst klein und **nicht biometrisch**. Ein einzelner Torso-Punkt darf etwas außerhalb des Bildes liegen, solange die Torsomitte im Bild bleibt.                           |
| `inference_width`, `inference_height`   | int    | Auflösung, auf die das Kamerabild **vor** der Inferenz verkleinert wird. `0` = keine Verkleinerung (volles Kamerabild). Normalisierte Koordinaten bleiben gültig, deshalb ist Downscaling der erste Hebel gegen Latenz — ein aktuelles Bild ist wichtiger als ein scharfes.                                               |
| `active_region.enabled`                 | bool   | Schaltet einen rechteckigen Interaktionsbereich frei. Nur wenn `true`, wird der Bereich ausgewertet.                                                                                                                                                                                                                      |
| `active_region.x_min/x_max/y_min/y_max` | 0..1   | Grenzen des Bereichs in normierten Bildkoordinaten. Nur Torsomitten innerhalb des Rechtecks werden übernommen. Ungültige Werte (`x_min >= x_max` usw.) verwerfen **alle** Personen.                                                                                                                                       |

Der aktive Bereich ist das Mittel, um nur die beleuchtete Interaktionszone vor
der Fassade zu erfassen und Passant:innen am Rand auszublenden.

**Wichtig für die Erwartung an die Rechenlast:** MediaPipe Tasks (Python) rechnet
standardmäßig auf der **CPU**; eine vorhandene GPU beschleunigt die Inferenz hier
nicht automatisch. Latenz steuert man über `inference_width`/`inference_height`,
die Kameraauflösung und `num_poses` — in dieser Reihenfolge, jeweils mit
`python -m capture.bench` gemessen.

---

## `features` — Tracking und Resonanzsignale (Capture)

Diese Werte formen die anonymen Signale, die der Renderer künstlerisch deutet.
Reine Mathematik, ohne ML-Abhängigkeit — vollständig unit-testbar.

### Intensität

| Parameter             | Typ   | Wirkung                                                                                                                        |
| --------------------- | ----- | ------------------------------------------------------------------------------------------------------------------------------ |
| `intensity_scale`     | float | Verstärkung der gemessenen Bewegung (Körper- plus Handgelenkgeschwindigkeit). Höher = schon kleine Bewegungen wirken intensiv. |
| `intensity_smoothing` | 0..1  | Glättungsfaktor pro Frame. Klein = träge und ruhig, groß = schnell und zappelig.                                               |

### Nähe und Beziehung

| Parameter             | Typ  | Wirkung                                                                                                                                                                                                                                                                 |
| --------------------- | ---- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `proximity_threshold` | 0..1 | Abstand, unter dem zwei Personen als „nah“ gelten und ein `pair` bilden. Größer = mehr Brücken. Muss deutlich über der realen Pose-Ungenauigkeit liegen (Pose-Zentren schwanken um einige Prozent des Bildes), sonst springt die Brücke zwischen benachbarten Personen. |

### Track-Lebenszyklus

| Parameter                   | Typ      | Wirkung                                                                                                                                                                                                                                                                                                                                                                                  |
| --------------------------- | -------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `track_max_dist`            | 0..1     | Maximaler Abstand zwischen Vorhersage und neuer Erkennung, um sie demselben Track zuzuordnen. Zu klein = ID-Wechsel, zu groß = Verwechslung benachbarter Personen. Die Vorhersage nutzt die letzte Geschwindigkeit, aber höchstens die letzten 0.2 s — danach zählt wieder die zuletzt beobachtete Position.                                                                             |
| `track_timeout`             | Sekunden | Veralteter Name für die Grace-Period; wird nur genutzt, wenn `track_grace_period` fehlt. Neue Configs setzen nur `track_grace_period`.                                                                                                                                                                                                                                                   |
| `track_grace_period`        | Sekunden | Wie lange ein kurz nicht erkannter Track intern erhalten bleibt und wieder zugeordnet werden kann. In dieser Zeit erscheint er **nicht** in `bodies`/`pairs`/`crowd`, nur in `tracking.temporarily_missing`. Verhindert, dass eine kurze Verdeckung als Austritt gilt. Sie ist **kein** Anzeigewert: wie lange die Person sichtbar nachklingt, bestimmt `renderer.missing_hold_seconds`. |
| `track_confirmation_frames` | int      | Anzahl Frames, bevor ein Track sichtbar wird und ein `departure` auslösen darf. Filtert Ein-Frame-Geister. Bei 30 FPS entsprechen 4 Frames etwa 0.13 s.                                                                                                                                                                                                                                  |
| `position_smoothing`        | 0..1     | Glättung der **ausgegebenen** Position (EMA-Anteil pro erkanntem Frame). `1.0` gibt die rohe Torsomitte weiter, kleinere Werte dämpfen Pose-Zittern. Nach einem kurzen Ausfall springt die Position auf den frischen Messwert, statt über die Lücke zu gleiten. Betrifft nur die ausgegebene Position, nicht Matching oder Austrittsprüfung.                                             |
| `departure_edge_margin`     | 0..1     | Randzone, in der ein Track als möglicher Austritt gilt.                                                                                                                                                                                                                                                                                                                                  |
| `departure_min_speed`       | float    | Mindestgeschwindigkeit **nach außen** durch denselben Rand. Beide Bedingungen müssen zutreffen — Nähe zum Rand allein genügt nicht, damit eine Verdeckung am Rand kein ästhetisch bedeutsames Ereignis wird.                                                                                                                                                                             |

**Wann ein `departure` entsteht (wichtig für die Erwartung):** Geprüft wird die
**zuletzt beobachtete** Geschwindigkeit des Tracks, ausgewertet erst nach Ablauf
der `track_grace_period`. Endet ein Track mit stehenbleibenden Randframes — die
Person läuft in den Randbereich und bleibt dort, bis die Erkennung abbricht —
oder war die letzte Bewegung zu langsam, entsteht **kein** `departure`, und es
gibt dann auch keine Nachwirkungswelle. Ein Verlust in der Bildmitte ergibt
grundsätzlich kein `departure`. Die abgenommenen Fälle stehen in
`docs/Track-Lifecycle-Abnahme.md`; im Simulator zeigen `left_departure`,
`right_departure`, `aftereffect_waves` und `center_loss` das Verhalten.

### Ruhe (Stillness)

| Parameter                   | Typ      | Wirkung                                                                                                              |
| --------------------------- | -------- | -------------------------------------------------------------------------------------------------------------------- |
| `stillness_speed_threshold` | float    | Geschwindigkeit, unterhalb derer eine Person als „ruhig“ gilt.                                                       |
| `stillness_rise_seconds`    | Sekunden | Zeitkonstante, mit der `stillness` bei Ruhe ansteigt. Größer = Verweilen muss länger dauern, bevor es sichtbar wird. |
| `stillness_fall_seconds`    | Sekunden | Zeitkonstante, mit der `stillness` bei Bewegung wieder abfällt. Klein = Ruhe „bricht“ schnell ab.                    |

`stillness` ist ein kontinuierlicher, semantikfreier Wert (0 = zuletzt bewegt,
1 = über Zeit ruhig). Er ist die Grundlage dafür, dass **Bleiben eine Antwort
bekommt** — siehe `effects.stillness_resonance`.

---

## `station` — Stand, Monitor und Sprachimpuls (Renderer)

Stand-Funktionen sind bewusst **nicht** unter `effects`, weil sie Vermittlung
und keine visuellen Effektfamilien sind.

`screen` und `display` werden nicht von Hand gepflegt: die Auswahlskripte
schreiben sie (`WIRKLICHT Bildschirm waehlen.cmd` und `WIRKLICHT Nahraum-Monitor
waehlen.cmd` rufen beide `monitor-select.ps1` auf — ohne bzw. mit
`-Target monitor`; die Speicherlogik liegt in `lib/common.ps1`). Der Renderer
liest die Signatur und sucht den passenden Bildschirm; passt sie zu keinem
aktuellen Bildschirm, wird bei mehreren Bildschirmen vor dem Start gewählt. Der
Renderer selbst schreibt **nie** `station` zurück in die Datei.

### `station.facade` — Hauptausgabe

| Parameter    | Typ    | Wirkung                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| ------------ | ------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `screen`     | int    | Bildschirmindex als **Rückfall**. Der Renderer sucht zuerst über `display`; `screen` greift nur, wenn die Signatur nicht mehr passt (mit Warnung im Log). Ist auch der Index ungültig, wird der Hauptbildschirm verwendet.                                                                                                                                                                                                                         |
| `display`    | object | Gespeicherte Position und Auflösung der gewählten Ausgabe (`x`, `y`, `width`, `height`, `primary`, zusätzlich `relative_x`/`relative_y` zum Hauptbildschirm). Der Renderer nutzt zuerst die absolute Signatur, dann die relative, damit eine geänderte Windows-Reihenfolge oder ein abweichender virtueller Ursprung nicht stillschweigend auf den falschen Bildschirm zeigt. Fehlt die Signatur oder ist sie unvollständig, entscheidet `screen`. |
| `fullscreen` | bool   | Vollbild auf dem gewählten Bildschirm.                                                                                                                                                                                                                                                                                                                                                                                                             |

### `station.monitor` — Nahraum der Rückkopplung

| Parameter           | Typ    | Wirkung                                                                                                                                        |
| ------------------- | ------ | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| `enabled`           | bool   | Schaltet den Publikumsmonitor.                                                                                                                 |
| `mode`              | string | Zielmodus ist `"facade_preview"`: dieselbe bzw. eng verwandte Resonanzdarstellung wie auf der Fassade. Unbekannte Modi lassen den Monitor aus. |
| `show_camera_image` | bool   | **Im Publikumsbetrieb `false`.** Der Renderer ignoriert `true` und warnt; das rohe Kamerabild bleibt verborgen.                                |
| `title`             | string | Fenstertitel.                                                                                                                                  |
| `screen`            | int    | Bildschirmindex des Monitors. Muss sich von `facade.screen` unterscheiden, sonst bleibt der Monitor aus.                                       |
| `display`           | object | Gespeicherte Bildschirm-Signatur wie bei `station.facade`. Wird über **WIRKLICHT Nahraum-Monitor waehlen** gesetzt.                            |
| `fullscreen`        | bool   | Vollbild oder Fenster.                                                                                                                         |
| `width`, `height`   | int    | Fenstergröße im Fenstermodus.                                                                                                                  |
| `prompt_font_size`  | int    | Schriftgröße des Sprachimpulses auf dem Monitor.                                                                                               |

Der Monitor zeigt eine Vorschau der Fassadendarstellung, damit Menschen die
Kopplung **Ich ↔ Resonanz ↔ Fassade** erkennen. Er darf die Fassade nicht als
Blickziel ersetzen.

**Technisch** ist die Vorschau die Textur des Fassaden-Viewports, seitenrichtig
und mit erhaltem Seitenverhältnis skaliert. Beide Ausgaben zeigen deshalb
denselben Zustand mit derselben Latenz; es gibt keine zweite, unabhängige
Simulation. Der Sprachimpuls wird nur auf dem Monitor gezeichnet, nicht auf der
Fassade. Das Kamerabild erscheint nie.

Der Monitor bleibt in vier Fällen aus (mit Warnung im Log): `enabled: false`,
ein anderer `mode`, nur ein erkannter Bildschirm, oder `screen` gleich
`station.facade.screen`. `width`/`height` wirken nur im Fenstermodus.

### `station.prompt` — Kurzer Sprachimpuls

| Parameter                | Typ      | Wirkung                                                                                      |
| ------------------------ | -------- | -------------------------------------------------------------------------------------------- |
| `enabled`                | bool     | Schaltet den Sprachimpuls.                                                                   |
| `source`                 | string   | Pfad zur Promptdatei. Absolute Pfade und `..` werden abgelehnt.                              |
| `prompt_key`             | string   | Einzelner Fallback-Key, falls `prompt_keys` leer oder ungültig ist.                          |
| `prompt_keys`            | string[] | Liste der kuratierten Keys, die im Wechsel gezeigt werden. Unbekannte Keys werden ignoriert. |
| `fade_in_seconds`        | Sekunden | Einblenddauer des Textes.                                                                    |
| `fade_out_seconds`       | Sekunden | Ausblenddauer.                                                                               |
| `underline_seconds`      | Sekunden | Dauer, in der die Lichtspur unter dem Text aufgebaut wird.                                   |
| `star_tail_fade_seconds` | Sekunden | Nachleuchten der Lichtspur nach dem Aufbau.                                                  |
| `idle_cycle_seconds`     | Sekunden | Ruhezeit ohne Personen, nach der der nächste Impuls angeboten wird.                          |

**Verhalten:** Der Impuls erscheint nur, wenn **niemand** erfasst ist. Sobald
Personen da sind, blendet er aus. Der Wechsel erfolgt nie in place: der alte
Satz verschwindet, bevor der nächste erscheint. Fehlt die Promptdatei oder ist
kein gültiger Key vorhanden, wird einfach kein Text gezeigt (kein Absturz).

Sprachimpulse werden ausschließlich in `config/prompts.json` kuratiert und als
inhaltlich-ästhetische Änderungen behandelt — nicht als UI-Copy.

---

## `renderer` — Sichtbare Persistenz (Renderer)

Trennt **Tracking-Persistenz** (intern, `features.track_grace_period`) von
**visueller Persistenz**: Was ein Renderer zeigen darf, wenn ein Körper kurz
nicht mehr erkannt wird. Verbindliche Regel: `tracking persistence ≠ visual
persistence` (siehe `AGENTS.md`, `docs/protocol.md`).

| Parameter              | Typ        | Wirkung                                                                                                                                                             |
| ---------------------- | ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `missing_hold_seconds` | Sekunden   | Wie lange ein kurz nicht erkannter, aber in `tracking.temporarily_missing` gemeldeter Körper seinen zuletzt sichtbaren Zustand hält. Danach beginnt das Ausblenden. |
| `missing_fade_rate`    | 1/Sekunden | Ausblendrate des gehaltenen Lichts: `Deckkraft -= delta × missing_fade_rate`. Nach `1 / missing_fade_rate` Sekunden ist der Körper vollständig aus.                 |

Zusammenspiel und Invarianten:

- Gesamtdauer bis zum Verschwinden = `missing_hold_seconds + 1 / missing_fade_rate`
  (Standard: 0.15 s + 0.25 s ≈ 0.4 s).
- Diese Summe muss **deutlich** unter `features.track_grace_period` liegen,
  sonst stünde eine Geisterperson die ganze Grace-Period über im Bild.
  Der Test `tests/test_renderer_visual_grace.py` hält das fest.
- Der bewusste Departure-Nachlauf ist **nicht** hiermit geregelt, sondern allein
  durch `effects.aftereffect_waves`.
- Ein verdeckter Paar-Partner (`pair.occluded`) friert die Brücke ein, statt
  weiterbewegt zu werden — Details bei `proximity_bridges`.
- **Kein Live-Reload:** Der Renderer liest diesen Abschnitt nur beim Start.
  Änderungen wirken erst nach einem Neustart des Renderers.

---

## `effects` — Visuelle Effektfamilien (Renderer)

### Globale Schalter

| Parameter      | Typ  | Wirkung                                                                                                                     |
| -------------- | ---- | --------------------------------------------------------------------------------------------------------------------------- |
| `enabled`      | bool | Hauptschalter. `false` schaltet **alle** Effektfamilien ab, ohne sie zu erzeugen oder zu simulieren.                        |
| `minimal_mode` | bool | Live-Fallback: lässt nur `body_glow`, `trails` und `proximity_bridges` aktiv und stellt so einen stabilen Grundzustand her. |

Fehlt der `enabled`-Schlüssel innerhalb einer Familie, gilt der jeweilige
Standard des Renderers: `body_glow`, `trails`, `sparks` und `proximity_bridges`
sind dann **an**, `stillness_resonance`, `crowd_aura` und `aftereffect_waves`
**aus**. Fehlt der ganze `effects`-Block oder ist die Datei ungültig, verwendet
der Renderer seine eingebauten Standardwerte (`_default_effects()` in
`renderer/scripts/main.gd`).

Nur dieser Abschnitt ist live: der Renderer prüft die Datei etwa zweimal pro
Sekunde und übernimmt Änderungen sofort. Auch das Speichern aus dem
Debug-Overlay (F3) schreibt ausschließlich `effects` zurück.

### `body_glow` — Lichtkörper

| Parameter | Typ  | Wirkung                       |
| --------- | ---- | ----------------------------- |
| `enabled` | bool | Zeigt den leuchtenden Körper. |

Größe folgt `openness` und `intensity`, Farbe wandert mit `intensity` von Gold
nach Rot, Helligkeit steigt mit `intensity`. Die Familie hat keine eigenen
Parameter. Bei wachsender Gruppe nimmt `crowd_aura` personengebundene Effekte
nur über Größe und Helligkeit zurück — **nie** über die Deckkraft, damit ein
Mensch in der Gruppe nicht durchsichtig wird.

### `trails` — Bewegungsspur

| Parameter    | Typ   | Wirkung                                                                                      |
| ------------ | ----- | -------------------------------------------------------------------------------------------- |
| `enabled`    | bool  | Zeigt die Spur. Beim Abschalten werden vorhandene Punkte gelöscht.                           |
| `max_points` | int   | Maximale Anzahl gespeicherter Spurpunkte. Mehr = längere Spur, mehr Speicher/Zeichenaufwand. |
| `width`      | float | Linienbreite der Spur.                                                                       |

Die Spur gehört zum Lichtkörper und wird pro gezeichnetem Frame um einen Punkt
verlängert; ihre sichtbare Länge ist deshalb `max_points` × Frameabstand (bei
30 FPS sind 80 Punkte etwa 2.7 s). Sie verschwindet mit ihrem Körper — inklusive
des kurzen Nachhaltens nach einem Trackingverlust (`renderer.missing_*`).

### `sparks` — Funken

| Parameter                      | Typ      | Wirkung                                                                                                              |
| ------------------------------ | -------- | -------------------------------------------------------------------------------------------------------------------- |
| `enabled`                      | bool     | Zeigt Funken.                                                                                                        |
| `amount_min`, `amount_max`     | int      | Partikelanzahl bei minimaler bzw. maximaler Intensität (dazwischen interpoliert).                                    |
| `lifetime`                     | Sekunden | Lebensdauer eines Partikels.                                                                                         |
| `velocity_min`, `velocity_max` | float    | Startgeschwindigkeit bei minimaler bzw. maximaler Intensität.                                                        |
| `activation_intensity`         | 0..1     | Schwelle, ab der Funken überhaupt entstehen. Verhindert, dass ein kurzer Kamera-Geist als Partikelblitz aufleuchtet. |

Die Anzahl wird zwischen `amount_min` und `amount_max` mit der beobachteten
Intensität interpoliert und zusätzlich mit der Gruppengewichtung multipliziert
(`crowd_aura.individual_dimming_max`), aber nie unter einen Partikel gesetzt.
Die Funken gehören zum Lichtkörper und enden mit ihm; ein ruhiger Körper bleibt
ein Lichtkörper ohne Partikel.

### `proximity_bridges` — Nähe-Brücken

| Parameter               | Typ      | Wirkung                                                                                                                                                                             |
| ----------------------- | -------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `enabled`               | bool     | Zeigt die Nähe-Brücke. Beim Abschalten wird der Effekt-Node nicht erzeugt und nicht simuliert; `pairs` werden verworfen.                                                            |
| `orbs_min`, `orbs_max`  | int      | Anzahl schwebender Feuerkugeln bei geringer bzw. hoher Nähe (dazwischen interpoliert). Praktische Obergrenze ist 24 (fester Seed-Pool); darüber wiederholen sich die Bahnen.        |
| `travel`                | 0..1     | Wie weit die Kugeln bei Annäherung zwischen beiden Personen pendeln. Bei Zusammenstehen kollabiert der Weg, die Kugeln verdichten sich.                                             |
| `speed`                 | float    | Pendelgeschwindigkeit der Kugeln.                                                                                                                                                   |
| `orb_size`              | float    | Basisgröße einer Kugel in Pixeln.                                                                                                                                                   |
| `wobble`                | 0..1     | Seitliches Schweben quer zur Verbindung (Anteil der Verbindungslänge).                                                                                                              |
| `max_alpha`             | 0..1     | Maximale Helligkeit der Kugeln (additiv).                                                                                                                                           |
| `field_strength`        | 0..1     | Stärke des verdichteten gemeinsamen Paar-Felds, sobald zwei Personen zusammen stehen.                                                                                               |
| `fade_seconds`          | Sekunden | Ein-/Ausblendzeit, wenn ein Paar entsteht oder auseinandergeht.                                                                                                                     |
| `occluded_fade_seconds` | Sekunden | Ausblendzeit, wenn ein Partner nur noch erinnert wird (`pair.occluded`). Die Brücke wird bis auf den sichtbaren Boden abgedämpft und dort **gehalten**, statt ganz zu verschwinden. |
| `smoothing`             | Sekunden | Trägheit von Endpunkten und Nähe. Ein neuer Messwert wird nur mit `delta / smoothing` Anteil übernommen. Größer = ruhiger; bei niedriger Abtastrate gegen Pose-Jitter erhöhen.      |
| `min_distance`          | 0..1     | Normalisierter Abstand, ab dem zwei Personen als wirklich zusammenstehend gelten. Erst darunter verdichten sich die Kugeln zum Paar-Feld; die bloße Nähe-Schwelle genügt nicht.     |
| `warm_color`            | Hex      | Farbe bei Annäherung.                                                                                                                                                               |
| `hot_color`             | Hex      | Farbe bei großer Nähe; die Kugeln wandern von warm nach heiß.                                                                                                                       |

Die Brücke ist **keine Verbindungslinie**: Bei Annäherung pendeln warme
Feuerkugeln im Zwischenraum, bei wachsender Nähe werden sie langsamer, wärmer
und verdichten sich zu einem kleinen gemeinsamen Feld — dem Paar-„Wir“, eine
Ebene unter `crowd_aura`. Der Effekt hat eine eigene Bewegungszeit und zeichnet
jeden Frame neu (die frühere Linie aktualisierte sich nur bei Eingaben).

Endpunkte und Nähe werden bewusst geglättet (`smoothing`) und die Nähe aus dem
eigenen, geglätteten Abstand neu berechnet. Reale Pose-Zentren schwanken zwischen
zwei Abtastungen um einige Prozent des Bildes; ungeglättet ließen sie die Kugeln
zwischen Personen springen und flackern. Zusammen mit dem größeren
`proximity_threshold` bleibt eine Brücke auch bei geringer Abtastrate ruhig,
während die Paar-Schwelle in `features` weiterhin bestimmt, **welche** Paare
überhaupt existieren.

**Verdeckung ist keine Trennung.** Meldet Capture ein Paar als `occluded` (ein
Partner ist gerade nicht sichtbar), friert die Brücke ein: keine Bewegung, keine
neuen Kugeln, keine Verstärkung. Sie wird bis auf einen sichtbaren Boden
abgedämpft und dort gehalten. Bei Wiedererkennung läuft sie weich weiter; bleibt
der Partner weg, prüft Capture das Paar und die Brücke blendet über den normalen
Pfad (`fade_seconds`) aus. So überlebt eine Beziehung eine kurze Verdeckung,
ohne dass eine unbeobachtete Person weiter animiert wird.

### `stillness_resonance` — Antwort auf Bleiben

| Parameter              | Typ      | Wirkung                                                                                      |
| ---------------------- | -------- | -------------------------------------------------------------------------------------------- |
| `enabled`              | bool     | Zeigt das ruhige Feld. Beim Abschalten wird der Prozess-Node entfernt (nicht nur versteckt). |
| `min_presence_seconds` | Sekunden | Anwesenheitsdauer, ab der das Feld seine volle Reife erreicht.                               |
| `pulse_seconds`        | Sekunden | Periodendauer des langsamen Pulsierens.                                                      |
| `max_scale`            | float    | Maximale Feldgröße bei voller Reife und Ruhe.                                                |

Das Feld ist **keine Belohnung für eine Geste**: Anwesenheitszeit und beobachtete
Ruhe blenden kontinuierlich in ein langsames Pulsieren ein. Damit bekommt
Bleiben eine qualitativ andere Antwort als Vorübergehen.

Das Feld ist ein Kind des Lichtkörpers: es verschwindet mit der Person, auch
während eines kurzen Trackingverlusts. `max_scale` bestimmt den Radiusfaktor
`(0.45 + Stärke × max_scale) × Puls`; die Deckkraft liegt bei `0.10 + Stärke ×
0.32`. Beides wächst mit `presence_time` (Reife) und `stillness` — nie sprunghaft.

### `crowd_aura` — gemeinsamer Resonanzraum der Gruppe

| Parameter                | Typ      | Wirkung                                                                                                                                                     |
| ------------------------ | -------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `enabled`                | bool     | Zeigt die gemeinsame Aura. Beim Abschalten wird sie weder erzeugt noch simuliert und schwächt auch keine anderen Effekte ab.                                |
| `min_people`             | int      | Personenzahl, ab der die Aura überhaupt zu entstehen beginnt. Kein harter Schalter: die Stärke wächst geglättet.                                            |
| `full_strength_people`   | int      | Personenzahl, ab der die Aura ihre volle Stärke erreicht.                                                                                                   |
| `fade_in_seconds`        | Sekunden | Zeitkonstante des Aufbaus.                                                                                                                                  |
| `fade_out_seconds`       | Sekunden | Zeitkonstante des Abbaus. Die Aura läuft danach vollständig auf null aus — auch `min_alpha`; es bleibt kein Restlicht an der letzten Körperposition stehen. |
| `pulse_seconds`          | Sekunden | Periodendauer des langsamen atmenden Pulsierens.                                                                                                            |
| `padding`                | 0..1     | Zusätzliche Ausdehnung um die räumliche Streuung der Gruppe.                                                                                                |
| `softness`               | 0..1     | Weichheit des äußeren Randes. Größer = diffuser.                                                                                                            |
| `min_alpha`              | 0..1     | Untere Deckkraft der Aura **innerhalb einer anwesenden Gruppe**. Kein Restlicht: beim Fortgehen läuft das ganze Feld auf null aus.                          |
| `max_alpha`              | 0..1     | Obere Deckkraft. Bewusst niedrig gehalten (Nachtprojektion).                                                                                                |
| `energy_influence`       | 0..1     | Wie stark `crowd.energy` die innere Bewegung moduliert. Beeinflusst **nie** die Sichtbarkeit.                                                               |
| `individual_dimming_max` | 0..1     | Maximale Abschwächung personengebundener Effekte bei voller Aura. Bleibt unter 1, damit Personen sichtbar bleiben.                                          |
| `body_clearance`         | 0..1     | Radius um jede Person, in dem das Aura-Feld ausgespart bleibt. Verhindert, dass Körper in der Atmosphäre verwischen.                                        |
| `gap_emphasis`           | 0..1     | Wie stark das Feld im Zwischenraum betont und um die Körper herum zurückgenommen wird.                                                                      |
| `warm_color`             | Hex      | Farbe im gemeinsamen Zentrum.                                                                                                                               |
| `cool_color`             | Hex      | Farbe in den äußeren Bereichen.                                                                                                                             |

Die Aura ist **kein Effekt für eine einzelne Person** und kein größerer Glow.
Sie entsteht aus den vorhandenen anonymen Body-Positionen, `crowd.count` und
`crowd.energy`; es wird kein neues Capture-Signal benötigt. Mittelpunkt,
Ausdehnung, Stärke und Form werden zeitlich geglättet, damit das Feld nicht
jeder kleinen Bewegung hinterherspringt. Eine ruhige Gruppe behält eine
deutliche gemeinsame Präsenz, weil `crowd.energy` nur die innere Bewegung
moduliert.

**Wie die Stärke entsteht:** `Stärke = (Personenzahl − (min_people − 1)) /
(full_strength_people − (min_people − 1))`, begrenzt auf 0..1 und zeitlich
geglättet. Mit `min_people: 3` und `full_strength_people: 10` ergibt das bei 3
Personen 0 und bei 10 Personen 1. Dieselbe Stärke bestimmt, wie stark
personengebundene Effekte zurückgenommen werden (`individual_dimming_max`).

**Präsenz und Ausblenden:** Neben der Stärke führt der Renderer ein Präsenz-Gate
(1 = Gruppe ist da, 0 = niemand mehr erfasst). Es multipliziert das **ganze**
Feld einschließlich `min_alpha` und läuft mit `fade_out_seconds` aus. Deshalb
bleibt nach dem Fortgehen kein Restlicht an der letzten Körperposition stehen:
`min_alpha` ist eine Untergrenze *innerhalb* einer anwesenden Gruppe, kein
Nachleuchten. Die Nachwirkung nach dem Gehen ist allein Sache von
`aftereffect_waves`.

**Formgedächtnis:** Ohne erfasste Personen wird die geometrische Form nicht mehr
nachgeführt; sie bleibt während des Ausblendens an der letzten Stelle stehen und
verschwindet mit dem Feld. Mittelpunkt und Ausdehnung folgen der Gruppe sonst mit
einer Zeitkonstante von etwa 1.6 s, damit das Feld nicht jeder Bewegung
hinterherspringt.

**Wichtig — die Einzelnen bleiben scharf.** Zwei Mechanismen verhindern, dass
die Gruppe zu einem Brei wird:

- `body_clearance`/`gap_emphasis` sparen das Feld um jeden Körper herum aus und
  betonen stattdessen den Zwischenraum. Das WIR erscheint als Veränderung des
  Raumes *zwischen* den Körpern, nicht als Lichtschleier über ihnen.
- `individual_dimming_max` schwächt personengebundene Effekte nur über Größe
  und Helligkeit ab — **nie über die Deckkraft**. Ein Mensch wird in der Gruppe
  nicht durchsichtig; er bleibt ein definierter Lichtkörper.

### `aftereffect_waves` — Nachwirkung nach dem Gehen

| Parameter                   | Typ      | Wirkung                                                                                                                               |
| --------------------------- | -------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| `enabled`                   | bool     | Zeigt Nachwirkungswellen.                                                                                                             |
| `group_window_seconds`      | Sekunden | Zeitfenster, in dem Austritte an derselben Kante zu **einer** Welle gebündelt werden.                                                 |
| `group_distance`            | 0..1     | Maximaler Achsabstand, innerhalb dessen Austritte gruppiert werden.                                                                   |
| `group_width_per_departure` | float    | Zusätzliche Bandbreite pro weiterem Austritt in der Gruppe. Größere Gruppen erzeugen breitere Wellen.                                 |
| `duration_seconds`          | Sekunden | Gesamtlebensdauer einer Welle.                                                                                                        |
| `initial_origin_outset`     | 0..1     | Startabstand des virtuellen Ursprungs **außerhalb** des Bildrands.                                                                    |
| `origin_escape_distance`    | 0..1     | Wie weit der Ursprung im Verlauf nach außen wandert. Der sichtbare Teil ist dadurch eine zurücklaufende Resonanz, keine Person-Linie. |
| `start_radius`              | 0..1     | Anfangsradius der Welle.                                                                                                              |
| `propagation_speed`         | float    | Ausbreitungsgeschwindigkeit (Radius pro Sekunde).                                                                                     |
| `band_width`                | 0..1     | Breite des Hauptbands. Größer = weicher, diffuser.                                                                                    |
| `source_glow_radius`        | 0..1     | Radius des Quell-Leuchtens am Ursprung.                                                                                               |
| `echo_spacing`              | 0..1     | Abstand eines inneren Echos zum Hauptband.                                                                                            |
| `echo_strength`             | 0..1     | Stärke dieses Echos.                                                                                                                  |
| `max_alpha`                 | 0..1     | Maximale Deckkraft der Welle. Bewusst niedrig gehalten (Nachtprojektion).                                                             |
| `fade_start_progress`       | 0..1     | Fortschritt, ab dem die Welle zu verblassen beginnt.                                                                                  |
| `fade_end_progress`         | 0..1     | Fortschritt, bei dem die Deckkraft null erreicht. Muss größer als `fade_start_progress` sein.                                         |
| `glow_strength`             | float    | Helligkeitsverstärkung der Wellenfarbe.                                                                                               |
| `warm_color`                | Hex      | Farbe am Anfang (nah am Austritt).                                                                                                    |
| `blue_color`                | Hex      | Farbe im weiteren Verlauf; die Welle wandert von warm nach kühl.                                                                      |
| `dedupe_seconds`            | Sekunden | Sperrzeit pro Austritts-ID gegen doppelte Wellen aus wiederholten UDP-Paketen.                                                        |

Wellen sind bewusst anonym: nur Kante, gemeinsame Achse und Gruppengröße
überleben. Keine Splash- oder Feuerwerk-Ästhetik.

**Wann eine Welle entsteht:** nur aus einem plausiblen `departure` (siehe
`features.departure_edge_margin`/`departure_min_speed`). Ohne plausiblen
Rand-Austritt gibt es keine Welle; ein Verlust in der Bildmitte wird nicht als
Fortgehen inszeniert. Austritte an derselben Kante innerhalb von
`group_window_seconds` und `group_distance` werden zu **einer** Welle gebündelt;
`group_width_per_departure` macht sie dann breiter.

Der Renderer prüft jedes Austrittsereignis, bevor er es verwendet: Kante aus
`left`/`right`/`top`/`bottom`, ganzzahlige nicht-negative ID, endliche Werte,
`x`/`y` innerhalb 0..1. Ungültige oder doppelte Ereignisse werden ignoriert;
dieselbe ID löst innerhalb von `dedupe_seconds` nur eine Welle aus. Die ID
verlässt den Renderer nie — die Welle kennt nur Kante, Achse und Gruppengröße.

**Zeitverlauf:** `fade_start_progress` und `fade_end_progress` sind Anteile von
`duration_seconds` (nicht Sekunden). Im ersten Teil leuchtet ein weicher
Ursprung genau am Austrittspunkt und wandert `origin_escape_distance` nach
außen; `source_glow_radius` steuert die Größe dieses Leuchtens. Die sichtbare
Welle läuft von warm nach kühl zurück ins Bild hinein und erreicht vor dem Ende
der Lebensdauer Deckkraft null, damit kein hartes Abschalten entsteht.

---

## `debug` — Diagnose (Capture)

| Parameter              | Typ      | Wirkung                                                                                                                                                                      |
| ---------------------- | -------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `preview`              | bool     | Öffnet ein lokales Vorschaufenster mit Overlay (IDs, Intensität, Personenzahl). Nur für Aufbau und Kalibrierung. Taste `q` beendet. **Nicht** Teil der Publikumsdarstellung. |
| `diagnostics`          | bool     | Schaltet die kompakte Capture-Diagnose ein (zusätzlich per CLI `--diagnostics`).                                                                                             |
| `diagnostics_interval` | Sekunden | Abstand zwischen zwei Diagnosezeilen. Untergrenze 0.05 s.                                                                                                                    |

Eine Diagnosezeile pro Intervall (Standard: 1 s) enthält FPS der Kamera und der
Schleife, die mittleren Stage-Zeiten `read`/`pose`/`features`/`udp` in
Millisekunden, rohe und akzeptierte Posen pro Frame, Tracks, gerade fehlende
Tracks (`missing`), Paare, den kleinsten Abstand zweier Tracks (`nearest`),
verworfene Kamerabilder (`dropped`), die Ablehnungsgründe (`rejected`) sowie
`backend`, `fourcc` und `resolution`. Es werden **keine** Bilder und keine
Identitäten ausgegeben.

---

## Debug-Werkzeuge im Renderer (nicht Teil der Config)

Diese Werkzeuge gehören zur Abnahme, nicht zur Publikumsdarstellung:

- **F3** öffnet das Tuning-Overlay: Regler für die Effektparameter, Schalter je
  Effektfamilie, Szenarioauswahl für einen laufenden Simulator und **Speichern**
  (schreibt nur den `effects`-Block zurück in `config/config.json`).
- **Alt + Enter** schaltet das Vollbild der Fassade um.
- Der Start protokolliert eine Effekt- und Standzeile (siehe unten).

---

## `updates` — Automatische Updates

| Parameter | Typ  | Wirkung                                                                                                                                                     |
| --------- | ---- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
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
- Fehlt `config/config.json` ganz, nutzt der Renderer eingebaute Defaults
  (`_default_effects()`, `_default_station()` in `renderer/scripts/main.gd`).

Verhält sich ein Block untypisch, greift die Reihenfolge: fehlender Schlüssel →
Standard des Einzelmoduls (z. B. `crowd_aura.gd`); fehlender oder ungültiger
ganzer Block → Standard aus `_default_effects()`. Beide Sätze sind bewusst
ähnlich, aber nicht identisch — der Standard aus `_default_effects()` ist der
maßgebliche, wenn eine Config neu erstellt wird; `config/config.example.json`
enthält genau diese Werte plus die Modulstandards für die Parameter, die
`_default_effects()` nicht auflistet.

Capture ist robuster gegenüber **fehlenden** Schlüsseln, aber nicht gegenüber
einer fehlenden Datei:

- Fehlt ein Schlüssel in `camera`, `pose`, `features` oder `debug`, gilt der
  Standard aus `capture/tracker.py` (z. B. `camera.fps` = 30,
  `camera.fourcc` = `"MJPG"`, `camera.latest_frame_wins` = `true`,
  `pose.inference_width` = 0, `features.position_smoothing` = 1.0,
  `debug.diagnostics_interval` = 1.0).
- Fehlt `config/config.json`, bricht Capture ab.
- Zusätzliche, unbekannte Schlüssel werden ignoriert — die Referenzdatei darf
  deshalb einen erklärenden `_hinweis` enthalten.

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

Für die visuelle Abnahme ohne Kamera gibt es zusätzlich den Launcher
`WIRKLICHT Simulation.cmd` bzw. `simulate.ps1`. Er startet Renderer und
Simulator zusammen und liest die Szenarioliste aus `capture/sim.py`:

```powershell
powershell -ExecutionPolicy Bypass -File simulate.ps1 -Scenario crowd_aura
```

Visuelle Änderungen zusätzlich im Godot-Simulator prüfen. Für Monitor- und
Promptlogik sind zusätzlich der deaktivierte Zustand, ein ungültiger
`prompt_key`, eine fehlende Promptdatei und die sicheren Fallbacks zu testen.

**Was wann wirkt:**

| Geänderter Abschnitt                  | Nötig                                                      |
| ------------------------------------- | ---------------------------------------------------------- |
| `effects`                             | nichts — der Renderer übernimmt die Änderung in etwa 0.5 s |
| `renderer`, `station`, `network.port` | Renderer neu starten                                       |
| `camera`, `pose`, `features`, `debug` | Capture neu starten (`start.ps1`)                          |

**Referenzdatei mitpflegen:** `config/config.example.json` dokumentiert die
Standardwerte. Der Test `tests/test_config_example.py` prüft, dass sie jeden
Schlüssel der Laufzeitconfig abdeckt, keine standortgebundenen Werte
(Bildschirmsignaturen, Kameraidentität) enthält und dieselben Typen verwendet —
eine Änderung an `config/config.json` schlägt dort fehl, bis die Referenz
nachgezogen ist. Der Test liest keine Kameradaten und startet kein Godot.
