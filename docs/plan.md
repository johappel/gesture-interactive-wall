# WIRKLICHT — Projektplan & Roadmap

Dieses Dokument ist die **gemeinsame Diskussionsgrundlage**. Es beschreibt technische Umsetzung und künstlerische Logik der Fassadenprojektion.

Ereignis: **Lichterfest Bad Wilhelmshöhe, 30.10.2026, 18–22 Uhr**.  
Rahmen: *Licht in der Dunkelheit* — Menschen wirken wie Lichter. Anwesenheit, Bewegung, Nähe und gemeinsame Dynamik hinterlassen sichtbare Resonanz.

## 1. Leitidee und KO-Kriterien

WIRKLICHT ist **kein berührungsloses Bedieninterface**. Menschen sollen keine Gestenkommandos lernen müssen.

> **WIRKLICHT visualisiert nicht die Befehle von Menschen, sondern die Spuren ihrer Anwesenheit, Bewegung und Beziehung.**

Verbindliche Grundsätze:

1. **Resonanz statt Gestensteuerung.**
2. **Nachwirkung statt sofortigem Verschwinden.**
3. **Individuum → Beziehung → Gruppe → Raum.**
4. **Datenschutz als Architekturprinzip:** lokale Bildverarbeitung, keine Speicherung/Cloud-Übertragung von Bildern.
5. **Live-Tauglichkeit:** jede eigenständige visuelle Effektfamilie ist über `config/config.json` einzeln abschaltbar.
6. **Verständliche Rückkopplung ohne Bedienanleitung:** Passant:innen dürfen den Zusammenhang zwischen eigener Anwesenheit und Fassadenbild nicht erst zufällig erraten müssen.

## 2. Räumlicher Rahmen und Stand

Die Installation erfasst einen klar begrenzten, beleuchteten Resonanzbereich am Stand bzw. im Eingangsbereich des Kirchenamtes, nicht einen ganzen Straßenzug.

Zielgröße: ungefähr **2–20 gleichzeitig erfasste Personen**.

Die Vermittlungsdramaturgie lautet:

1. **Lichtinsel:** „Hier ist ein besonderer Ort.“
2. **Nahraum-Monitor:** „Das dort hat mit mir zu tun.“
3. **Kurze Frage:** „Was geschieht, wenn du bleibst?“

Die Fassade bleibt der eigentliche öffentliche Resonanzraum. Der Monitor ist eine unmittelbare Nahraum-Rückkopplung und keine zweite Hauptleinwand.

Details: `docs/Standkonzept.md`.

## 3. Architektur

```text
Kamera ─[OpenCV]→ MediaPipe Pose ─[features.py]→ Resonanzsignale
       ─JSON/UDP→ Godot 4.7 → Licht / Partikel / Felder / Spuren / Wellen → Beamer
                                      │
                                      └→ Resonanz-Vorschau → Nahraum-Monitor
```

- `capture/` erkennt Körper und berechnet semantisch arme, kontinuierliche Eigenschaften.
- Das Protokoll transportiert Körper-, Beziehungs-, Gruppen- und Zustandsdaten.
- `renderer/` interpretiert diese Daten künstlerisch.
- `config/config.json` steuert Kamera, Features, Stand-/Monitoroptionen und Effekte.
- `config/prompts.json` enthält kuratierte kurze Sprachimpulse.

Für die räumliche Installation ist ein Sensorrechner in Kameranähe die bevorzugte Variante. Über die ca. 50 m zum Hauptrechner werden primär abstrakte Tracking-/Resonanzdaten transportiert. Für den Nahraum-Monitor gibt es zusätzlich einen Rückkanal der Visualisierung.

**Der Publikumsmonitor zeigt niemals das rohe Kamerabild.** Kameravideo bleibt Diagnose-/Einrichtungswerkzeug.

## 4. Konfiguration

### 4.1 Effekte

Jede eigenständige Effektfamilie benötigt einen `enabled`-Schalter unter `effects`.

`enabled: false` bedeutet: Effekt nicht erzeugen und nicht weiter simulieren. Capture-/Resonanzsignale bleiben davon unabhängig.

### 4.2 Stand, Monitor und Sprachimpuls

```json
{
  "station": {
    "monitor": {
      "enabled": true,
      "mode": "facade_preview",
      "show_camera_image": false,
      "width": 960,
      "height": 540,
      "prompt_font_size": 38
    },
    "prompt": {
      "enabled": true,
      "source": "config/prompts.json",
      "prompt_key": "stay_question"
    }
  }
}
```

Die Config entscheidet, **ob und welcher** Sprachimpuls aktiv ist; `config/prompts.json` ist die kuratierte Inhaltsquelle.

Bevorzugter Impuls:

> **Was geschieht, wenn du bleibst?**

## 5. Status und Reihenfolge

| Phase | Inhalt | Stand |
|------:|--------|-------|
| 0 | Repo-Gerüst, Config, Protokoll, Tests | ✅ |
| 1 | Capture-MVP: Ganzkörper-Pose, Features, UDP, Simulator | ✅ |
| 2 | Renderer-MVP: Lichtgestalten, Bloom | ✅ |
| 3 | Leuchtspuren (Trails) | ✅ |
| 4 | Multi-Person + Lichtbrücken (Nähe) | ✅ |
| **4.4** | **Nahraum-Monitor + Sprachimpuls + technische Rückkopplung** | ✅ **technisch integriert; bereit für Abnahme** |
| **4.5** | **Resonanzgrammatik + Nachwirkung + Effektsteuerung** | danach |
| 5 | Realwelt-Test: Beleuchtung, Distanz, 2–20 Personen, Verständlichkeit | offen |
| 6 | Projektion & Kalibrierung | offen |
| 7 | Hardware / Robustheit | offen |
| 8 | Klang (optional) | offen |
| 9 | DSGVO/Beschilderung & Betriebshandbuch | offen |

**Phase 4.5 beginnt erst, wenn Phase 4.4 technisch integriert ist.** Die Rückkopplung im Nahraum ist keine nachträgliche Vermittlungsschicht, sondern Teil des Interaktionssystems.

## 6. Phase 4.4 — Nahraum-Rückkopplung

### 6.1 Renderer / Config

Vor Phase 4.5 verbindlich integrieren:

- `station.monitor` aus `config/config.json` lesen;
- `station.prompt` aus `config/config.json` lesen;
- `config/prompts.json` laden;
- ungültige/fehlende Prompt-Dateien und Keys robust behandeln;
- `show_camera_image=true` im Publikumsrenderer nicht zulassen;
- separates Vorschau-Fenster für `facade_preview` erzeugen;
- Haupt-Viewport als Resonanz-Vorschau spiegeln;
- Prompt nur im Leerlauf anzeigen;
- sobald Personen erkannt werden, Prompt ausblenden und Vorschau wirken lassen;
- Monitor über Config vollständig abschaltbar halten.

### 6.2 Aktueller Integrationsstand

Der Renderer besitzt und prüft dafür jetzt:

- `station`-Konfigurationsauswertung;
- sichere Teil-Defaults für fehlende oder fehlerhafte `station.monitor`- und
  `station.prompt`-Blöcke;
- Laden der kuratierten Prompts;
- Warnungen und leerer Zustand bei fehlender/ungültiger Prompt-Datei oder
  unbekanntem Prompt-Key, ohne erfundenen Ersatztext;
- `facade_preview` als separates Godot-Fenster;
- konfigurierbare Monitorgröße und Prompt-Schriftgröße;
- Ausblenden des Prompts bei erkannter Anwesenheit;
- Schutz davor, das rohe Kamerabild im Publikumsmodus anzuzeigen, auch wenn
  `show_camera_image=true` gesetzt wird;
- Schließen des lokalen Vorschaufensters ohne Beeinträchtigung der
  Hauptausgabe;
- ein wiederholbarer Simulatorablauf `Leerlauf → eine Person → mehrere
  Personen → Leerlauf` mit den bestehenden Signalen.

Die Vorschau spiegelt die Texture des Haupt-Viewports. Sie berechnet keine
zweite Resonanz und zeigt keine Diagnosewerte. Die aktuelle Phase-4.4-Stufe
verwendet dafür bewusst ein lokales zweites Godot-Fenster. Ein echter
Netzwerk-Rückkanal über die perspektivischen ca. 50 m ist noch nicht
implementiert und wird nicht vorgetäuscht.

Noch praktisch zu prüfen:

- sichtbare Ausgabe mit zwei realen Displays;
- Platzierung des Vorschau-Fensters auf dem Monitor am Stand;
- Latenz und visuelle Übereinstimmung von Vorschau und Fassadenbild;
- Verhalten bei Vollbildbetrieb des Beamers;
- Neustart-/Failsafe-Verhalten bei fehlendem zweiten Display.

Automatisiert bzw. technisch geprüft sind: 23 Python-Unit-Tests, der
GDScript-Editor-/Parse-Check mit Godot 4.7.1 und ein headless Renderer-Start
mit UDP-Bind, Config-Laden, Monitor-/Prompt-Status und dem lokalen
`facade_preview`-Pfad. Die headless-Prüfung ersetzt keine sichtbare
Zwei-Monitor-Abnahme.

### 6.3 Abnahmekriterium vor 4.5

Phase 4.4 gilt als ausreichend integriert, wenn im Simulatorbetrieb ohne Kamera folgende Abfolge funktioniert:

```text
Leerlauf
→ Monitor zeigt „Was geschieht, wenn du bleibst?“
→ simulierte Person erscheint
→ Text verschwindet
→ dieselbe Resonanz ist im Vorschaufenster und auf der Hauptausgabe sichtbar
→ Person verschwindet
→ nach dem Ausblenden kehrt der Leerlauf-Impuls zurück
```

Der Simulator führt diese Abfolge in einem 14-Sekunden-Zyklus aus. Er nutzt
weiterhin ausschließlich `intensity`, `openness`, Positionen, Paare und
Crowd-Energie; Phase-4.5-Signale und Nachwirkungsereignisse wurden dafür nicht
vorgezogen.

### 6.4 Abnahmegrenzen

Phase 4.4 ist technisch bereit für die manuelle Abnahme. Offen bleiben nur
die Prüfungen, die eine sichtbare bzw. reale Installation voraussetzen:

- zwei physische Displays inklusive Fensterplatzierung und Vollbildprojektor;
- subjektiv ausreichende Latenz und Blickführung vom Nahraum zur Fassade;
- reale 50-m-Netzwerkstrecke und ein späterer Netzwerk-Rückkanal;
- Neustart- und Betriebserfahrung am konkreten Veranstaltungsaufbau.

Für die manuelle Godot-Abnahme sind mit Neustart des Renderers diese Fälle
auszuführen:

1. Monitor und Prompt aktiviert: Prompt im Leerlauf, Vorschau bei Anwesenheit.
2. Prompt deaktiviert: kein Text, Vorschau bleibt aktiv.
3. Monitor deaktiviert: kein zusätzliches Fenster, Hauptausgabe bleibt aktiv.
4. unbekannter `prompt_key`: Warnung und leerer Prompt-Zustand, kein Ersatztext.
5. fehlende bzw. ungültige `prompts.json`: Warnung, kein Crash, Hauptausgabe
   bleibt aktiv.
6. `show_camera_image=true`: deutliche Warnung, weiterhin ausschließlich
   Resonanz-Vorschau und kein Kamerabild.

Diese sechs sichtbaren Varianten sowie die echte Fensterplatzierung auf zwei
Displays wurden hier nicht als visuelle Hardware-Abnahme ausgeführt.

Die verbindlichen Tracking-Lifecycle-Kriterien in
`docs/Track-Lifecycle-Abnahme.md` bleiben ein Gate für Phase 4.5. Diese Phase
4.4 führt weder `active`/`temporarily_missing`/`departed` als neue
Produktionslogik noch `departure`, `stillness`, `presence_time`, `rhythm`,
Nachwirkungswellen oder neue Effektfamilien ein.

## 7. Resonanzgrammatik

WIRKLICHT erkennt beobachtbare körperliche Qualitäten, keine Emotionen oder religiösen Bedeutungen.

Geeignete Signale:

| Signal | Bedeutung im System |
|--------|---------------------|
| `intensity` | Stärke / Lebendigkeit der Bewegung |
| `openness` | räumliche Öffnung |
| `verticality` | Aufrichtung |
| `contraction` | Verdichtung / Kleinmachen |
| `stillness` | anhaltende Ruhe |
| `rhythm` | wiederkehrende Bewegung |
| `directionality` | gerichtete Bewegung |
| `proximity` | Nähe zwischen Personen |
| `synchrony` | ähnliche Bewegung mehrerer Personen |
| `presence_time` | Dauer der Anwesenheit |

Keine Klassifikation wie „Freude“, „Trauer“ oder „Gebet“.

## 8. Visuelles Vokabular

| Resonanz | mögliche Materialität |
|----------|-----------------------|
| Anwesenheit | Lichtkörper / Glow |
| Bewegung | Funken / Lichtpartikel |
| Ruhe / Bleiben | Verdichtung, langsames Pulsieren, Feldbildung |
| Öffnung | räumliche Ausdehnung |
| Bewegung durch den Raum | Trail |
| Nähe | Lichtbrücke / gemeinsames Feld |
| längere Nähe | Lichtdunst |
| gemeinsamer Rhythmus | Wellen |
| größere Gruppe | gemeinsamer Atmosphärenzustand |
| Verlassen | Nachwirkung / zurücklaufende Welle |

Die Zuordnung ist kein starres 1:1-Regelwerk.

Besonders wichtig:

> **Bleiben darf nicht bloß die Abwesenheit von Bewegung sein.**

Zieldramaturgie:

> **Gehen → Spur.  
> Bleiben → Resonanz.  
> Mehrere → Beziehung.  
> Fortgehen → Nachwirkung.**

## 9. Phase 4.5 — Resonanzgrammatik und Nachwirkung

Erst nach Integration von 4.4:

### Capture / Features

1. `stillness`
2. `presence_time`
3. `verticality` bzw. `contraction`
4. einfacher zeitlicher `rhythm`
5. robuste Rand-Austritts-Erkennung (`departure`)

Bestehende Signale `intensity`, `openness` und `proximity` weiterverwenden.

### Simulator

Mindestens simulieren:

- lebendige Bewegung;
- Ruhe / Verweilen;
- Öffnung / Verdichtung;
- zwei Personen kommen zusammen;
- größere Gruppe;
- einzelne Person verlässt links/rechts;
- mehrere Personen verlassen gemeinsam einen Randbereich.

### Renderer

1. Funken / Aufstieg;
2. Ruhe als Verdichtung statt Dunkelwerden;
3. Nähe als Feld / Dunst zusätzlich zur Linie;
4. rhythmische Bewegung als dezente Wellenmodulation;
5. `departure` als zurücklaufende Wasser-/Lichtwelle;
6. Interaktion der Wellen mit vorhandenen Partikeln/Feldern;
7. Config-Schalter für jede neue Effektfamilie.

## 10. Nachwirkung / Echo

Beim Verlassen des Erfassungsbereichs soll eine Person oder Gruppe nicht einfach verschwinden.

Bevorzugte Formsprache: ruhige, vom Austrittsrand zurücklaufende Wasser-/Lichtwelle.

- Ursprung am plausiblen Rand-Austritt;
- wenige breite Wellenfronten statt Splash/Feuerwerk;
- Lichtreflexion statt realistisches Wasser;
- langsamer als normale Körperbewegung;
- kann vorhandene Partikel/Felder kurz modulieren;
- Gruppen-Austritte dürfen aggregiert werden.

Trackingverlust durch Verdeckung darf nicht als `departure` interpretiert werden.

## 11. Individuum → Beziehung → Gruppe → Raum

- ca. 2–4 Personen: Individuen und direkte Beziehungen deutlich sichtbar.
- ca. 5–10 Personen: Felder, Gruppierungen und gemeinsame Dynamik gewinnen Gewicht.
- ca. 10–20 Personen: stärkerer gemeinsamer Resonanzkörper statt vieler unabhängiger Avatare.

> **Je mehr Menschen dazukommen, desto weniger zeigt WIRKLICHT einzelne Menschen und desto stärker zeigt es das Geschehen zwischen ihnen.**

Zeitliche Zielrichtung:

```text
presence → relation → collective → memory
```

## 12. Phase 5 — Realwelt-Test

Zu testen sind ausdrücklich auch Verständlichkeit und Verweildynamik:

- reale Beleuchtung bei Dämmerung/Nacht;
- Kameraposition und Sichtfeld;
- 2, 5, 10 und wenn möglich bis ca. 20 Personen;
- Verdeckungen und Track-Stabilität;
- Lesbarkeit der Fassadenprojektion;
- Latenz des Nahraum-Monitors;
- erkennen Menschen innerhalb weniger Sekunden den Zusammenhang zwischen sich und der Visualisierung?
- führt der Monitor den Blick zur Fassade statt ihn dort festzuhalten?
- bewirkt „Was geschieht, wenn du bleibst?“ tatsächlich Verweilen?
- erlebt man beim Bleiben eine neue Qualität?
- funktionieren Effekt- und Stand-Fallbacks?

## 13. Weitere Roadmap

### Phase 6 — Projektion & Kalibrierung

- Vollbildbetrieb;
- Warp-/Eckpunkt-Mapping;
- Kalibrierung laden/speichern;
- Kontrast/Helligkeit abstimmen.

### Phase 7 — Hardware / Robustheit

- RGB beibehalten oder Beleuchtung optimieren;
- ggf. IR-/Tiefenkamera evaluieren;
- robuste Netzwerkstrecke;
- Rückkanal für Monitorvorschau;
- Fallbacks bei Tracking-/Netzwerkausfällen.

### Phase 8 — Klang (optional)

Nur ergänzen, wenn Klang die Resonanzidee stärkt und nicht überlädt.

### Phase 9 — DSGVO & Betrieb

- Beschilderung zur lokalen, anonymen Verarbeitung;
- Trennung Datenschutzinfo ↔ poetischer Impuls;
- Kiosk-/Autostart;
- Failsafe;
- Betriebshandbuch;
- dokumentierte Effekt- und Stand-Defaults.

## 14. Bewusste Grenzen

- Keine Finger-/Handzeichenerkennung als Kerninteraktion.
- Keine Emotionserkennung.
- Keine Geste-X→Effekt-Y-Sprache als dominantes Prinzip.
- Keine Cloud-Bildverarbeitung.
- Keine Speicherung von Kameraaufnahmen.
- Kein rohes Kamerabild auf dem Publikumsmonitor.
- Kein erklärender Textblock als Voraussetzung zum Verstehen.
- Projektionstauglichkeit ist wichtiger als feine Bildschirmästhetik.
- Effekte, Monitor und Sprachimpuls bleiben zur Laufzeit abschaltbar.

## 15. Offene Entscheidungen

1. Wie wird das Vorschau-Fenster im realen Mehrmonitor-Betrieb zuverlässig auf dem Standmonitor platziert?
2. Welche Latenz ist noch als unmittelbare Rückkopplung erlebbar?
3. Wie lange muss jemand verweilen, bevor `stillness`/`presence_time` eine neue Qualität auslösen?
4. Welche Formsprache beantwortet das Bleiben am stärksten?
5. Welche Monitorgröße und Position führen den Blick zur Fassade?
6. Welcher kurze Sprachimpuls funktioniert im Realwelt-Test am besten?
7. Wie lange soll Nachwirkung bestehen?
8. Welche Kombination wird robuster `minimal`-Fallback?
9. Klang: überhaupt gewünscht?
