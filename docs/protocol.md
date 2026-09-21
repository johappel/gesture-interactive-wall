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
    { "a": 0, "b": 1, "proximity": 0.8, "mx": 0.5, "my": 0.5 }
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
| `crowd.count`      | int       | Anzahl erkannter Personen |
| `crowd.energy`     | 0..1      | Mittlere Intensität aller Personen |

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
konfigurierte `track_grace_period` erhalten, wird aber weder als Body noch in
`pairs` oder Crowd-Daten ausgegeben. Bei räumlich plausibler Wiederaufnahme
behält er seine ID.

Nach Ablauf der Grace Period wird ein Track beendet. Ein Eintrag in
`events.departures` entsteht dabei **nur**, wenn die letzte valide Position in
der Randzone lag und die letzte beobachtete Geschwindigkeit durch denselben
Rand nach außen zeigte. Ein Verlust in der Bildmitte und ein bloßer Timeout
erzeugen kein Ereignis. Das Ereignis wird beim Beenden genau einmal gesendet;
eine spätere Rückkehr erhält eine neue Track-ID.

Der Renderer darf `events` vorerst ignorieren. Phase 4.5A fügt bewusst keine
Nachwirkungs- oder sonstigen Godot-Effekte hinzu.

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
- `crowd.energy` → Gesamtglühen der Fassade
- `presence_time` + `stillness` → nach einer Mindestdauer ein zurückhaltendes,
  langsam pulsierendes Resonanzfeld um den vorhandenen Lichtkörper

Die Effektfamilie `effects.stillness_resonance` ist unabhängig schaltbar. Bei
`enabled: false` wird ihr Feld nicht erzeugt und nicht simuliert. Fassade und
Nahraum-Monitor nutzen dieselbe Renderer-Ausgabe (`facade_preview`); es wird
kein Kamerabild übertragen oder angezeigt. Nachwirkungswellen, Rhythmus, Dunst
und Crowd-Felder sind nicht Teil von Phase 4.5B.

## OSC (später, Phase 5)

Für die Audio-Anbindung (Ableton/SuperCollider) wird das gleiche Schema
zusätzlich als OSC gespiegelt. Adressen: `/wirklicht/body`, `/wirklicht/pair`,
`/wirklicht/crowd`.
