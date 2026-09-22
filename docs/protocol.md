# WIRKLICHT — Datenprotokoll

Die Capture-App sendet pro Frame **ein JSON-Paket** per UDP an den Renderer.
Standard: `127.0.0.1:4242`. Es werden ausschließlich abstrakte Zahlenwerte
übertragen — keine Bilder, keine Personendaten.

## Frame-Format

```json
{
  "t": 12.345,
  "bodies": [
    {
      "id": 0,
      "x": 0.5,
      "y": 0.4,
      "vx": 0.12,
      "vy": -0.03,
      "intensity": 0.31,
      "openness": 0.62,
      "presence_time": 8.4,
      "stillness": 0.73
    }
  ],
  "pairs": [
    { "a": 0, "b": 1, "proximity": 0.8, "mx": 0.5, "my": 0.5, "ax": 0.42, "ay": 0.5, "bx": 0.58, "by": 0.5 }
  ],
  "crowd": { "count": 2, "energy": 0.4 },
  "events": {
    "departures": [
      {
        "id": 7,
        "edge": "left",
        "x": 0.01,
        "y": 0.54,
        "vx": -0.23,
        "vy": 0.02
      }
    ]
  },
  "tracking": {
    "temporarily_missing": []
  }
}
```

## Felder

| Feld               | Bereich   | Bedeutung |
|--------------------|-----------|-----------|
| `t`                | Sekunden  | Zeitstempel seit Start |
| `bodies[].id`      | int       | Stabile ID über Frames hinweg |
| `bodies[].x/y`     | 0..1      | Normierte Position (Torsomitte) |
| `bodies[].vx/vy`   | ~-1..1    | Geschwindigkeit (Einheiten/s, normiert) |
| `bodies[].intensity` | 0..1    | Geglättete Bewegungsintensität |
| `bodies[].openness`  | 0..1    | Armöffnung (0 = geschlossen, 1 = weit) |
| `bodies[].presence_time` | Sekunden | Dauer der aktuellen anonymen Anwesenheitsepisode; zählt auch über einen begrenzten Detection-Ausfall weiter |
| `bodies[].stillness` | 0..1 | Geglättete, beobachtete Bewegungsruhe; 0 = zuletzt bewegt, 1 = über Zeit ruhig |
| `pairs[].a/b`      | int       | IDs der nahen Personen |
| `pairs[].proximity`| 0..1      | 1 = sehr nah |
| `pairs[].mx/my`    | 0..1      | Mittelpunkt für die Lichtbrücke |
| `pairs[].ax/ay`    | 0..1      | Position von `a` (die Brücke zeichnet aus diesen Endpunkten, unabhängig von der Body-Sichtbarkeit) |
| `pairs[].bx/by`    | 0..1      | Position von `b` |
| `crowd.count`      | int       | Anzahl erkannter Personen |
| `crowd.energy`     | 0..1      | Mittlere Intensität aller Personen |
| `tracking.temporarily_missing` | int[] | Bestätigte anonyme IDs innerhalb der kurzen Track-Grace-Period; hält nur ihren bereits sichtbaren Lichtzustand |

### Departure-Ereignis

| Feld | Bereich | Bedeutung |
|------|---------|-----------|
| `events.departures` | array | Einmalige, plausible Rand-Austritte dieses Frames |
| `events.departures[].id` | int | ID der gerade beendeten Anwesenheitsepisode |
| `events.departures[].edge` | left/right/top/bottom | Rand, an dem der letzte Verlauf nach außen zeigte |
| `events.departures[].x/y` | 0..1 | Letzte valide Torso-Position |
| `events.departures[].vx/vy` | ~-1..1 | Letzte beobachtete Geschwindigkeit (Einheiten/s) |

## Track-Lifecycle und Ereignisse (Phase 4.5A)

`bodies` enthält weiterhin nur im jeweiligen Frame tatsächlich erkannte
Personen. Ein kurzfristig nicht erkannter Track bleibt intern für die
konfigurierte `track_grace_period` erhalten und wird **nicht** als Body oder in
Crowd-Daten ausgegeben. Bei räumlich plausibler Wiederaufnahme behält er seine
ID.

**Ausnahme Nähe-Paare:** Eine Beziehung ist nicht dasselbe wie zwei sichtbare
Erkennungen. Stehen zwei Menschen zusammen, liefert MediaPipe häufig nur eine
Pose; der zweite Track sitzt dann in der Grace-Period. Damit die Lichtbrücke im
entscheidenden Moment nicht ausblendet, darf ein solcher verdeckter Partner mit
seiner zuletzt bekannten Position weiterhin **Endpunkt eines Paares** sein —
sofern mindestens ein Endpunkt aktuell erkannt ist und der Abstand unter der
Schwelle bleibt. Zwei gleichzeitig verdeckte Personen werden nie verbunden. Der
verdeckte Partner erscheint dabei trotzdem nicht in `bodies` oder Crowd-Daten.

Nach Ablauf der Grace Period wird ein Track beendet. Ein Eintrag in
`events.departures` entsteht dabei **nur**, wenn die letzte valide Position in
der Randzone lag und die letzte beobachtete Geschwindigkeit durch denselben
Rand nach außen zeigte. Ein Verlust in der Bildmitte und ein bloßer Timeout
erzeugen kein Ereignis. Das Ereignis wird beim Beenden genau einmal gesendet;
eine spätere Rückkehr erhält eine neue Track-ID.

Phase 4.5C verarbeitet ausschließlich diese plausiblen `departure`-Ereignisse
als Nachwirkungswellen. Sie sind keine Body-Daten und werden nicht als
individuelle Darstellung fortgeführt.

## Verweilen-Signale (Phase 4.5B)

`presence_time` und `stillness` werden nur für im jeweiligen Frame sichtbare,
bestätigte Bodies übertragen. Sie beschreiben weder Identität noch Emotion oder
eine Geste. `presence_time` beginnt mit der aktuellen anonymen
Anwesenheitsepisode. Ein Track innerhalb der `track_grace_period` behält seine
ID und seinen Startzeitpunkt; die Zeit zählt deshalb über einen kurzen
Detection-Ausfall weiter.

`stillness` entsteht aus der geglätteten beobachteten Torso-/Handbewegung. Der
Wert steigt und fällt mit Zeitkonstanten, statt ein Zustands-Schalter zu sein.
Während eines Detection-Ausfalls wird keine nicht beobachtbare Bewegung
hinzuerfunden: bei Wiederaufnahme bleibt der zuletzt erreichte Stillness-Wert
erhalten und wird erst mit der nächsten zusammenhängenden Beobachtung erneut
aktualisiert.

`tracking.temporarily_missing` enthält während derselben Grace-Period nur die
bereits bestätigten, momentan nicht erkannten Track-IDs. Diese IDs sind keine
Bodies und fließen nicht in Pairs oder Crowd ein. Der Renderer hält dafür allein
den zuletzt sichtbaren Lichtzustand, damit ein kurzer Pose-Ausfall nicht als
sichtbares Verschwinden erscheint. Nach Ablauf der Grace-Period entfällt die ID
und der Renderer blendet den Lichtpunkt regulär aus.

## Tracking-Konfiguration

Die Schwellenwerte stehen in `config/config.json` unter `features`:

| Feld | Bedeutung |
|-------|-----------|
| `track_max_dist` | Maximaler Abstand zur kurz extrapolierten letzten Position für eine Reassociation |
| `track_grace_period` | Sekunden, die ein fehlender Track intern erhalten bleibt |
| `departure_edge_margin` | Breite der Randzone in normierten Bildkoordinaten |
| `departure_min_speed` | Mindestgeschwindigkeit in Auswärtsrichtung für ein `departure` |
| `track_timeout` | Kompatibilitäts-Fallback, falls `track_grace_period` in älteren Configs fehlt |
| `track_confirmation_frames` | Zahl konsistenter Erkennungsframes, bevor ein neuer Track sichtbar wird |
| `stillness_speed_threshold` | Normierte Bewegungsrate, ab der eine Beobachtung nicht mehr als ruhig zählt |
| `stillness_rise_seconds` | Zeitkonstante, mit der kontinuierliche Ruhe Stillness aufbaut |
| `stillness_fall_seconds` | Zeitkonstante, mit der neu beobachtete Bewegung Stillness wieder löst |

## Pose-Qualität und Resonanzraum

Vor dem Tracking akzeptiert Capture nur Posen mit sichtbaren, endlichen
Schultern und Hüften. `pose.min_detection_confidence` ist die MediaPipe-Schwelle;
`pose.min_torso_visibility` ist die zusätzliche Landmark-Qualitätsschwelle.
So wird aus einer einzelnen objektähnlichen Fehl-Pose nicht sofort eine
sichtbare Anwesenheit.

`pose.active_region` ist standardmäßig deaktiviert. Nach der realen
Kamera-Kalibrierung kann sie auf die Lichtinsel gesetzt werden; Posen außerhalb
werden dann verworfen. Sie begrenzt nur die Annahme von Posen und verändert
keine Koordinaten. Wird sie eingeengt, müssen Randzone und Departure-Verhalten
mit der echten Kamera erneut geprüft werden.

## Renderer-Mapping (Konzept)

- `intensity` → Helligkeit, Partikelausstoß, Farbtemperatur (sanft → energisch)
- `openness`  → Größe/Ausdehnung der Lichtaura
- `pairs`     → wachsende Lichtbrücke am Mittelpunkt `mx/my`
- `crowd.count` + Body-Positionen → Mittelpunkt, Ausdehnung und Stärke der
  gemeinsamen Crowd-Aura
- `crowd.energy` → innere Bewegung/Helligkeitsmodulation der Crowd-Aura;
  **nicht** ihre Sichtbarkeit
- `presence_time` + `stillness` → nach einer Mindestdauer ein zurückhaltendes,
  langsam pulsierendes Resonanzfeld um den vorhandenen Lichtkörper

Die Effektfamilie `effects.stillness_resonance` ist unabhängig schaltbar. Bei
`enabled: false` wird ihr Feld nicht erzeugt und nicht simuliert. Fassade und
Nahraum-Monitor nutzen dieselbe Renderer-Ausgabe (`facade_preview`); es wird
kein Kamerabild übertragen oder angezeigt.

### Crowd-Aura (Phase 4.5D)

`effects.crowd_aura` leitet ein gemeinsames atmosphärisches Lichtfeld
ausschließlich aus den bereits vorhandenen anonymen Daten ab: den aktuellen
Body-Positionen, `crowd.count` und `crowd.energy`. Es wird **kein** neues
Protokollfeld eingeführt.

- Die Geometrie (Mittelpunkt, räumliche Ausdehnung) folgt der tatsächlichen
  Streuung der Gruppe und wird zeitlich geglättet.
- Ein geglätteter `collective_strength`-Wert blendet die Aura über eigene Auf-
  und Abbauzeiten ein und aus. Es gibt keinen harten „ab N Personen“-Schalter.
- `crowd.energy` moduliert nur die innere Bewegung; eine ruhige Gruppe behält
  eine deutliche gemeinsame Präsenz.
- Die aktuellen Body-Positionen werden zusätzlich an den Shader gegeben, damit
  das Feld rund um jeden Körper ausgespart und der Zwischenraum betont wird.
  So bleibt jede Person ein definierter Lichtkörper statt in der Atmosphäre zu
  verwischen.
- `enabled: false` erzeugt und simuliert keine Aura und schwächt auch keine
  anderen Effektfamilien ab.

### Nachwirkungswellen (Phase 4.5C)

`effects.aftereffect_waves` verarbeitet nur gültige `events.departures[]` aus
zeitlich nicht rückläufigen Frames. Der Renderer prüft `id`, Rand, Position und
Geschwindigkeit, verwirft unvollständige bzw. ungültige Ereignisse und hält die
anonyme Episode-ID nur für `dedupe_seconds` im Arbeitsspeicher gegen
wiederholte UDP-Frames. Die Welleninstanz erhält anschließend ausschließlich
Rand und Position; sie speichert oder zeichnet keine Person-ID.

Der Renderer prüft jedes zwischen zwei Renderzyklen eingetroffene gültige
UDP-Frame auf `departure`, auch wenn für die fortlaufende Körperdarstellung nur
der neueste Zustand relevant ist. Ein einmaliges Ereignis kann dadurch nicht
durch ein jüngeres, ereignisloses UDP-Frame im lokalen Empfangspuffer verloren
gehen.

Nahe Austritte am selben Rand werden innerhalb von `group_window_seconds` zu
einer gemeinsamen Welle aggregiert. Der Renderer legt dafür ein anonymes,
großflächiges Shader-Lichtfeld an: Sein virtueller Mittelpunkt liegt bereits
außerhalb des Austrittsrands und wandert mit `origin_escape_distance` weiter
aus dem Bild. Sichtbar ist nur der nach innen reichende Teil der breiten,
weichen Resonanz. Er startet am Rand warm und hell, wird allmählich bläulich
und löst sich ohne harte Kontur in der dunklen Fassade auf. Das ist eine
Lichtmetapher für Nachwirkung, keine Wasser- oder Personenanimation.

Die Wellen liegen hinter Körpern, Trails, Funken und Lichtbrücken und werden
über geringe `max_alpha` begrenzt. Ein breiter Halo, ein schwacher innerer
Nachklang und das langsam verschwindende Quellglühen machen die Welle aus
Distanz lesbar, ohne die laufende Gegenwart zu dominieren.
`enabled: false` erzeugt keine Instanz und simuliert keine bestehenden Wellen.

| Config-Feld | Default | Bedeutung |
|---|---:|---|
| `enabled` | `true` | Effektfamilie aktiv; `false` erzeugt/simuliert nichts |
| `group_window_seconds` | `0.22` | Zeitfenster für gemeinsame Rand-Austritte |
| `group_distance` | `0.18` | maximaler normierter Abstand entlang desselben Randes |
| `group_width_per_departure` | `0.10` | Verbreiterung des gemeinsamen Lichtfelds je nahem Austritt |
| `duration_seconds` | `4.8` | Dauer, bis die Resonanz vollständig ausläuft |
| `initial_origin_outset` | `0.03` | anfänglicher Abstand des unsichtbaren Mittelpunkts außerhalb der Fassade |
| `origin_escape_distance` | `0.16` | zusätzlicher Außenweg des Mittelpunkts bis zum Ende |
| `start_radius` | `0.03` | anfänglicher Radius der Lichtresonanz |
| `propagation_speed` | `0.20` | Ausbreitungsgeschwindigkeit der Resonanz in normierten Einheiten/s |
| `band_width` | `0.09` | Weichheit und Breite des Hauptlichtfelds |
| `source_glow_radius` | `0.16` | Ausdehnung des warmen Quellglühens am Rand |
| `echo_spacing` | `0.15` | Abstand eines sehr schwachen inneren Nachklangs |
| `echo_strength` | `0.28` | Stärke dieses Nachklangs; klein halten, damit kein Rhythmuseffekt entsteht |
| `max_alpha` | `0.26` | zurückhaltende Maximal-Deckkraft des Lichtfelds |
| `fade_start_progress` | `0.15` | Anteil der Laufzeit, ab dem die Welle stetig merklich dunkler wird |
| `fade_end_progress` | `0.92` | Anteil der Laufzeit, an dem die Welle bereits vollständig transparent ist |
| `glow_strength` | `1.55` | additive Helligkeitsverstärkung für Projektionstauglichkeit |
| `warm_color` | `#fff0bd` | warme, helle Ausgangsfarbe am Austrittsrand |
| `blue_color` | `#5caeff` | allmählich erreichte blaue Ausklangfarbe |
| `dedupe_seconds` | `5.0` | kurzlebige UDP-Duplikatsperre für die anonyme Episode-ID |

Die Standardform ist eine einzige, breite und diffuse Lichtwelle. Ihre Mitte
bleibt unsichtbar jenseits des Austrittsrands und wandert weiter nach außen;
in die Fassade gelangt nur die weiche, langsam auslaufende Rückwirkung. Ihre
Helligkeit beginnt deutlich vor der Fassadenmitte stetig abzunehmen und ist vor
dem technischen Ablaufende bereits transparent; sie wird daher nicht sichtbar
abgeschaltet.

## OSC (später, Phase 5)

Für die Audio-Anbindung (Ableton/SuperCollider) wird das gleiche Schema
zusätzlich als OSC gespiegelt. Adressen: `/wirklicht/body`, `/wirklicht/pair`,
`/wirklicht/crowd`.
