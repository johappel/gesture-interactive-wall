# WIRKLICHT — Projektplan & Roadmap

Dieses Dokument ist die **gemeinsame Diskussionsgrundlage**. Es beschreibt nicht
nur die technische Umsetzung, sondern auch die künstlerische Logik, nach der
Körper, Beziehungen und gemeinsame Anwesenheit auf der Fassade sichtbar werden.

Ereignis: **Lichterfest Bad Wilhelmshöhe, 30.10.2026, 18–22 Uhr** (Dämmerung/Nacht).
Rahmen: *Licht in der Dunkelheit* — Menschen wirken wie Lichter. Ihre Anwesenheit,
Bewegung, Nähe und gemeinsame Dynamik hinterlassen sichtbare Resonanz.

## 1. Leitidee und KO-Kriterien

WIRKLICHT soll **kein berührungsloses Bedieninterface** sein. Menschen sollen
nicht lernen müssen: „Wenn ich Geste X mache, passiert Effekt Y.“

Leitgedanke:

> **WIRKLICHT visualisiert nicht die Befehle von Menschen, sondern die Spuren
> ihrer Anwesenheit, Bewegung und Beziehung.**

Daraus folgen fünf Grundsätze:

1. **Resonanz statt Gestensteuerung:** überwiegend kontinuierliche Körper- und
   Beziehungssignale statt eines Katalogs benannter Kommandogesten.
2. **Nachwirkung statt sofortigem Verschwinden:** Menschen und Gruppen können
   Spuren hinterlassen, die noch weiterwirken, wenn sie den Erfassungsbereich
   verlassen haben.
3. **Individuum → Beziehung → Gruppe → Raum:** je mehr Menschen beteiligt sind,
   desto weniger soll die Fassade wie viele einzelne Avatare wirken und desto
   stärker wird das gemeinsame Geschehen sichtbar.
4. **Datenschutz als Architekturprinzip:** Bildverarbeitung ausschließlich lokal,
   keine Speicherung oder Übertragung von Bildern.
5. **Live-Tauglichkeit durch schaltbare Effekte:** jede eigenständige visuelle
   Materialität muss über `config.json` einzeln deaktivierbar sein, damit sich
   die Installation vor Ort schnell beruhigen, vereinfachen oder stabilisieren
   lässt.

Über UDP (`127.0.0.1`) werden ausschließlich **abstrakte Zahlenwerte**
(Position, Bewegung, Resonanzqualitäten, Beziehungen, Ereignisse) an den Renderer
gesendet.

## 2. Räumlicher Rahmen

Die Installation erfasst **nicht einen ganzen Straßenzug**. Vorgesehen ist ein
klar begrenzter Interaktionsbereich an einem beleuchteten Stand vor der Fassade
bzw. im Eingangsbereich des Kirchenamtes.

Zielgröße: ungefähr **2–20 gleichzeitig erfasste Personen**.

Daraus folgt für die Hardware:

- Eine normale RGB-Kamera bleibt zunächst die **Primärlösung**.
- Entscheidend ist eine gute, gleichmäßige Stand-/Eingangsbeleuchtung, die für
  Menschen angenehm und für Pose-Tracking ausreichend ist.
- IR-Beleuchtung oder Tiefenkamera bleiben **Optionen nach Praxistest**, nicht
  automatisch Voraussetzung.
- Früh testen: reale Entfernung, reales Sichtfeld, reale Beleuchtung, mehrere
  Personen und teilweise Verdeckungen.

## 3. Architektur

```text
Kamera ─[OpenCV]→ MediaPipe Pose ─[features.py]→ Resonanzsignale
       ─JSON/UDP→ Godot 4.7 → Licht / Partikel / Felder / Spuren / Wellen → Beamer
```

Die Trennung bleibt bewusst einfach:

- `capture/` erkennt Körper und berechnet möglichst **semantisch arme,
  kontinuierliche Eigenschaften**.
- Das Protokoll transportiert Körper-, Beziehungs-, Gruppen- und ausgewählte
  Ereignisdaten.
- `renderer/` interpretiert diese Daten künstlerisch.
- `config/config.json` steuert Kamera, Features und **alle eigenständigen
  visuellen Effektfamilien**.

So kann die visuelle Grammatik verändert werden, ohne die Wahrnehmungsschicht neu
zu bauen.

### 3.1 Verbindliche Regel für visuelle Effekte

Jeder eigenständige visuelle Effekt benötigt in `config.json` mindestens einen
expliziten `enabled`-Schalter.

Beispiel:

```json
{
  "effects": {
    "body_glow": { "enabled": true },
    "trails": { "enabled": true },
    "sparks": { "enabled": true },
    "proximity_bridges": { "enabled": true },
    "mist": { "enabled": true },
    "waves": { "enabled": true },
    "floating_bodies": { "enabled": false },
    "aftereffect_waves": { "enabled": true },
    "crowd_field": { "enabled": true }
  }
}
```

Architekturregeln:

- `enabled: false` bedeutet: Der Effekt wird **nicht erzeugt und nicht weiter
  simuliert**, nicht nur unsichtbar geschaltet.
- Effektparameter gehören zum jeweiligen Effektblock, z. B. Partikelanzahl,
  Lebensdauer oder Intensität unter `effects.sparks` statt verteilt an anderen
  Stellen der Config.
- Resonanzsignale im Capture bleiben **unabhängig von Renderer-Effekten**. Ein
  deaktivierter Effekt darf nicht dazu führen, dass `stillness`, `openness`,
  `rhythm` usw. nicht mehr berechnet oder übertragen werden.
- Neue eigenständige Effektfamilien gelten nur dann als vollständig integriert,
  wenn sie einen Config-Schalter besitzen.
- Die Defaults sollen einen robusten, ästhetisch brauchbaren Zustand ergeben.

Optional kann später zusätzlich ein Preset-System (`minimal`, `calm`, `full`,
`debug`) eingeführt werden. Presets ersetzen die Einzel-Schalter nicht, sondern
setzen sie nur gesammelt.

Ein späterer `minimal_mode` darf als schneller Fallback dienen, z. B. nur mit
`body_glow`, `trails` und `proximity_bridges`.

## 4. Status

| Phase | Inhalt | Stand |
|------:|--------|-------|
| 0 | Repo-Gerüst, Config, Protokoll, Tests | ✅ |
| 1 | Capture-MVP: Ganzkörper-Pose, Features, UDP, Simulator | ✅ |
| 2 | Renderer-MVP: Lichtgestalten, Bloom | ✅ |
| 3 | Leuchtspuren (Trails) | ✅ |
| 4 | Multi-Person + Lichtbrücken (Nähe) | ✅ |
| **4.5** | **Resonanzgrammatik + Nachwirkung + Effektsteuerung** | 🔜 **nächster Schritt** |
| 5 | Realwelt-Test: Beleuchtung, Distanz, 2–20 Personen | offen |
| 6 | Projektion & Kalibrierung (Fassaden-Mapping) | offen |
| 7 | Hardware-Entscheidung / Robustheit | offen |
| 8 | Klang (optional) | offen |
| 9 | DSGVO/Beschilderung & Betriebshandbuch | offen |

Heute erfasst das System bereits pro Person:

- Position und Geschwindigkeit,
- Bewegungsintensität,
- Armöffnung,
- Nähe zwischen Personen,
- Crowd-Energie.

Das ist bereits eine gute Grundlage für die Resonanzgrammatik.

## 5. Resonanzgrammatik

### 5.1 Wahrnehmung statt Bedeutungszuschreibung

WIRKLICHT soll nicht versuchen zu erkennen, **was eine Bewegung bedeutet** oder
welche Emotion jemand hat. Es erkennt nur beobachtbare körperliche Qualitäten.

Keine Emotionsklassifikation, keine Interpretation wie „Freude“, „Trauer“ oder
„Gebet“.

Geeignete Resonanzsignale sind beispielsweise:

| Signal | Bedeutung im System |
|--------|---------------------|
| `intensity` | Stärke / Lebendigkeit der Bewegung |
| `openness` | räumliche Öffnung des Körpers |
| `verticality` | Aufrichtung / vertikale Ausdehnung |
| `contraction` | räumliche Verdichtung / Kleinmachen |
| `stillness` | anhaltende Ruhe |
| `rhythm` | wiederkehrende bzw. pendelnde Bewegung |
| `directionality` | gerichtete Bewegung |
| `proximity` | räumliche Nähe zwischen Personen |
| `synchrony` | ähnliche Bewegung mehrerer Personen über Zeit |
| `presence_time` | Dauer der Anwesenheit im Resonanzraum |

Nicht alle Signale müssen sofort implementiert werden. Wichtig ist die Richtung:
**kontinuierliche Resonanzqualitäten vor benannten Gesten.**

### 5.2 Visuelles Vokabular

Die Fassade soll nicht ausschließlich aus unterschiedlich hellem Glow bestehen.
Verschiedene Resonanzqualitäten dürfen verschiedene **visuelle Materialitäten**
annehmen:

| Resonanz | mögliche Materialität |
|----------|-----------------------|
| Anwesenheit | Lichtkörper / Glow |
| Bewegung | Funken / aufsteigende Lichtpartikel |
| schnelle oder kräftige Bewegung | stärkerer Partikelstrom |
| Ruhe | Verdichtung, langsames Pulsieren |
| Öffnung | räumliche Ausdehnung des Lichtfeldes |
| Bewegung durch den Raum | Spur / Trail |
| Nähe | Lichtbrücke / gemeinsames Feld |
| längere Nähe | Lichtdunst / leuchtende Atmosphäre |
| gemeinsamer Rhythmus | Wellen / rhythmische Modulation |
| intensive gemeinsame Phase | gelegentlich schwebender Lichtkörper |
| größere Gruppe | gemeinsamer Atmosphärenzustand der Fassade |
| Verlassen | Nachwirkung / zurücklaufende Welle |

Diese Tabelle ist **kein 1:1-Regelwerk**. Der Renderer soll Eigenschaften mischen.
Ein Zustand entsteht aus mehreren Signalen gleichzeitig, ähnlich wie bei einem
Instrument Klangfarbe, Dynamik und Artikulation zusammenwirken.

### 5.3 Materialitäten und Projektionstauglichkeit

Die Installation läuft nachts auf einer realen Fassade bzw. Projektionsfläche.
Deshalb müssen Effekte aus Distanz und unter Restlicht lesbar bleiben.

Grundregeln:

- feine dunkle Effekte vermeiden — der Projektor kann kein echtes Schwarz
  erzeugen und der Nachthimmel schluckt schwache Details;
- lieber **klare helle Kanten und gut lesbare Formen** als zu filigrane Partikel;
- Dunst eher als leuchtende Atmosphäre, nicht als realistischer Rauch;
- Partikel nicht zu klein wählen;
- Nachwirkungen dürfen eine andere Formsprache besitzen als Anwesenheit, damit
  nicht alles zu einer einzigen Glow-Ästhetik verschmilzt.

## 6. Nachwirkung / Echo

Eine Person oder Gruppe soll beim Verlassen des Erfassungsbereichs **nicht einfach
verschwinden**.

Der Bildrand wird künstlerisch als **Schwelle** verstanden.

Wenn ein stabil verfolgter Track den Bereich plausibel an einem Rand verlässt,
kann dort eine Nachwirkung entstehen:

> Die Person ist bereits fort, aber ihre Wirkung breitet sich noch einmal in den
> gemeinsamen Raum hinein aus.

### 6.1 Wasser-/Lichtwelle

Bevorzugte visuelle Form ist eine **zurücklaufende Wasserwelle**:

- Ursprung genau dort, wo die Person den Erfassungsbereich verlässt;
- Bewegung **vom Rand zurück in die Fassadenfläche**;
- ein bis wenige breite, ruhige Wellenfronten statt eines Splash- oder
  Feuerwerk-Effekts;
- optisch eher wie **Lichtreflexion auf Wasser** als wie realistisches Wasser;
- hohe Lesbarkeit durch helle, schmale Brechungs-/Reflexionskanten;
- langsamer als normale Körperbewegungen, damit die Nachwirkung als eigener
  zeitlicher Zustand erkennbar wird;
- nach einigen Sekunden ausdünnen und in den gemeinsamen Fassadenzustand
  übergehen.

Besonders interessant: Die Welle kann vorhandene Partikel oder Lichtfelder kurz
modulieren, verschieben oder zum Mitschwingen bringen. Die Nachwirkung ist dann
nicht nur ein aufgesetzter Ring, sondern beeinflusst das bestehende Geschehen.

### 6.2 Gruppen-Nachwirkung

Verlassen mehrere Menschen ungefähr gemeinsam denselben Randbereich, sollen nicht
zwangsläufig viele einzelne Wellen übereinandergelegt werden.

Möglich ist eine Aggregation:

- ähnliche Austrittszeit + ähnlicher Randbereich → gemeinsamer Nachwirkungsimpuls;
- größere Gruppe → breitere / energiereichere, nicht zwingend hellere Welle;
- mehrere zeitlich versetzte Gruppen → sich überlagernde Wellenfronten.

So kann das System auch nach dem Fortgehen noch Beziehung sichtbar machen.

### 6.3 Technisches Ereignis

Diskrete Ereignisse bleiben sinnvoll, wenn sie **Zustandswechsel** beschreiben,
nicht Gestenkommandos.

Für die Nachwirkung könnte das Protokoll beispielsweise enthalten:

```json
{
  "events": [
    {
      "type": "departure",
      "id": 3,
      "edge": "right",
      "x": 0.99,
      "y": 0.58,
      "dx": 0.42,
      "dy": 0.03,
      "intensity": 0.55,
      "presence_time": 18.4
    }
  ]
}
```

Wichtig: Nur ein **plausibler Austritt am Bildrand** soll `departure` erzeugen.
Ein durch Verdeckung oder Trackingfehler verlorener Körper darf nicht sofort eine
Nachwirkungswelle auslösen.

## 7. Vom Individuum zum gemeinsamen Resonanzkörper

Die Darstellung soll sich mit der Zahl der Menschen verändern.

### ca. 2–4 Personen

- Individuen deutlich erkennbar;
- eigene Lichtkörper und Spuren;
- Beziehungen zwischen einzelnen Personen gut sichtbar.

### ca. 5–10 Personen

- Paarbeziehungen und kleine Gruppen gewinnen an Bedeutung;
- Felder, Dunst, gemeinsame Rhythmen und überlagerte Spuren treten stärker hervor;
- einzelne Lichtkörper bleiben sichtbar, dominieren aber weniger.

### ca. 10–20 Personen

- nicht zwanzig unabhängige Effektmaschinen darstellen;
- stärkerer Übergang zu einem **gemeinsamen Resonanzkörper der Fassade**;
- Crowd-Energie, Gruppierung, Rhythmus und Atmosphäre bestimmen zunehmend das
  Gesamtbild.

Leitregel:

> **Je mehr Menschen dazukommen, desto weniger zeigt WIRKLICHT einzelne Menschen
> und desto stärker zeigt es das Geschehen zwischen ihnen.**

Das vorhandene Datenmodell `body → pair → crowd` bleibt dafür eine gute Grundlage
und kann perspektivisch um zeitliche Nachwirkung ergänzt werden:

```text
presence → relation → collective → memory
```

## 8. Phase 4.5 — Umsetzung Resonanzgrammatik

### 8.1 Capture / Features

Zuerst wenige robuste zusätzliche Signale implementieren und testen:

1. `stillness`
2. `verticality` bzw. `contraction`
3. einfacher zeitlicher `rhythm`
4. `presence_time`
5. robuste Erkennung eines plausiblen Rand-Austritts (`departure`)

Bestehende Signale `intensity`, `openness` und `proximity` weiterverwenden.

Tests zuerst, gemäß `AGENTS.md`.

### 8.2 Simulator

`sim.py` so erweitern, dass ohne Kamera mindestens folgende Situationen erzeugt
werden können:

- lebendige Bewegung,
- Ruhe,
- Öffnung / Verdichtung,
- zwei Personen kommen zusammen,
- größere Gruppe,
- einzelne Person verlässt links/rechts,
- mehrere Personen verlassen gemeinsam einen Randbereich.

### 8.3 Renderer

Schrittweise ergänzen:

1. vorhandene Partikel stärker als **Funken / Aufstieg** nutzen;
2. Ruhe als Verdichtung statt Dunkelwerden;
3. Nähe nicht nur als Linie, sondern optional als gemeinsames Feld / Dunst;
4. rhythmische Bewegung als dezente Wellenmodulation;
5. `departure` als zurücklaufende Wasser-/Lichtwelle;
6. Wellen dürfen bestehende Partikel / Felder vorübergehend beeinflussen;
7. **für jede eigenständige Effektfamilie einen verpflichtenden Config-Schalter
   implementieren und testen.**

### 8.4 Protokoll

`protocol.md` erst nach Festlegung der tatsächlich implementierten Felder
aktualisieren. Neue Felder bleiben abwärtskompatibel; der Renderer ignoriert
unbekannte Werte.

### 8.5 Effektsteuerung / Live-Fallback

Vor dem Realwelt-Test müssen mindestens die aktuell implementierten Effekte über
`config.json` einzeln schaltbar sein. Für neue Effekte gilt diese Regel ab ihrer
Einführung.

Mindestens vorzusehen:

- `body_glow`
- `trails`
- `sparks`
- `proximity_bridges`
- `mist`
- `waves`
- `floating_bodies`
- `aftereffect_waves`
- `crowd_field` (sobald implementiert)

Tests sollen sicherstellen, dass deaktivierte Effekte weder erzeugt noch weiter
simuliert werden und dass andere Effekte bzw. Resonanzsignale davon unbeeinflusst
bleiben.

## 9. Phase 5 — Realwelt-Test

Diese Phase wird bewusst vor eine endgültige Hardwareentscheidung gezogen.

Zu testen sind:

- reale Stand-/Eingangsbeleuchtung bei Dämmerung und Nacht;
- Kameraposition und Sichtfeld;
- Ganzkörpererkennung in realistischer Entfernung;
- 2, 5, 10 und wenn möglich bis etwa 20 Personen;
- Verdeckungen und kreuzende Laufwege;
- Stabilität der Track-IDs;
- zuverlässige Erkennung tatsächlicher Rand-Austritte;
- Lesbarkeit der Projektion auf der realen Fassade / Testfläche;
- Wirkung und Lesbarkeit der verschiedenen Materialitäten;
- gezieltes Abschalten einzelner Effekte und Nutzung eines Minimalzustands als
  Live-Fallback.

Erst danach wird entschieden, ob RGB + Standbeleuchtung genügt oder ob IR/Tiefe
wirklich nötig wird.

## 10. Weitere Roadmap

### Phase 6 — Projektion & Kalibrierung

- Vollbildbetrieb;
- Eckpunkt-/Warp-Mapping für die reale Fassade;
- Laden/Speichern der Kalibrierung;
- Kontrast- und Helligkeitsabstimmung für Nachthimmel und Projektionsfläche.

### Phase 7 — Hardware / Robustheit

Auf Basis des Realwelt-Tests:

- RGB beibehalten oder zusätzliche Beleuchtung optimieren;
- falls nötig IR- oder Tiefenkamera evaluieren;
- Performance bei 2–20 Personen;
- Fallbacks bei Tracking-Ausfällen.

### Phase 8 — Klang (optional)

Klang nur ergänzen, wenn er die Resonanzidee stärkt und die Installation nicht
überlädt. Möglich wären OSC-Spiegelung oder prozeduraler Klang in Godot.

### Phase 9 — DSGVO & Betrieb

- Beschilderung zur lokalen, anonymen Verarbeitung;
- Kiosk-/Autostart;
- Failsafe;
- Betriebshandbuch;
- dokumentierte Effekt-Defaults und Minimal-/Fallback-Konfiguration.

## 11. Bewusste Grenzen

- Keine Finger-/Handzeichenerkennung als Kerninteraktion.
- Keine Emotionserkennung.
- Keine Geste-X-löst-Effekt-Y-Sprache als dominantes Bedienprinzip.
- Keine Cloud-Bildverarbeitung.
- Keine Speicherung von Kameraaufnahmen.
- Tracking muss nicht „100 Menschen auf der Straße“ beherrschen; Ziel ist ein
  begrenzter Resonanzbereich mit ca. 2–20 Menschen.
- Projektionstauglichkeit ist wichtiger als feine Bildschirmästhetik.
- Jeder eigenständige visuelle Effekt bleibt **zur Laufzeit konfigurierbar
  abschaltbar**.

## 12. Offene Entscheidungen

1. Welche zusätzlichen Resonanzsignale bringen im ersten Wurf wirklich sichtbaren
   Mehrwert: `stillness`, `verticality`, `rhythm` — alle oder priorisieren?
2. Wie stark darf Dunst/Feldbildung werden, bevor die Projektion zu weich und
   unlesbar wird?
3. Wie lange soll Nachwirkung typischerweise bestehen: eher 5–10 Sekunden oder
   deutlich länger?
4. Soll eine Welle nur visuell überlagert werden oder tatsächlich andere
   Partikel/Felder kurz beeinflussen?
5. Welche Toleranz gilt für „gemeinsames Verlassen“, bevor mehrere `departure`-
   Ereignisse zu einer Gruppenwelle aggregiert werden?
6. Welche Kombination wird als robuster `minimal`-Fallback definiert?
7. Klang: überhaupt gewünscht, und wenn ja eher atmosphärisch in Godot oder über
   OSC an ein externes System?
