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
      "openness": 0.62
    }
  ],
  "pairs": [
    { "a": 0, "b": 1, "proximity": 0.8, "mx": 0.5, "my": 0.5 }
  ],
  "crowd": { "count": 2, "energy": 0.4 }
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
| `pairs[].a/b`      | int       | IDs der nahen Personen |
| `pairs[].proximity`| 0..1      | 1 = sehr nah |
| `pairs[].mx/my`    | 0..1      | Mittelpunkt für die Lichtbrücke |
| `crowd.count`      | int       | Anzahl erkannter Personen |
| `crowd.energy`     | 0..1      | Mittlere Intensität aller Personen |

## Renderer-Mapping (Konzept)

- `intensity` → Helligkeit, Partikelausstoß, Farbtemperatur (sanft → energisch)
- `openness`  → Größe/Ausdehnung der Lichtaura
- `pairs`     → wachsende Lichtbrücke am Mittelpunkt `mx/my`
- `crowd.energy` → Gesamtglühen der Fassade

## OSC (später, Phase 5)

Für die Audio-Anbindung (Ableton/SuperCollider) wird das gleiche Schema
zusätzlich als OSC gespiegelt. Adressen: `/wirklicht/body`, `/wirklicht/pair`,
`/wirklicht/crowd`.
