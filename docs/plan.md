# WIRKLICHT — Projektplan & Roadmap

Dieses Dokument ist die **gemeinsame Diskussionsgrundlage**. Es beschreibt nicht nur die technische Umsetzung, sondern auch die künstlerische Logik, nach der Körper, Beziehungen und gemeinsame Anwesenheit auf der Fassade sichtbar werden.

Ereignis: **Lichterfest Bad Wilhelmshöhe, 30.10.2026, 18–22 Uhr** (Dämmerung/Nacht).  
Rahmen: *Licht in der Dunkelheit* — Menschen wirken wie Lichter. Ihre Anwesenheit, Bewegung, Nähe und gemeinsame Dynamik hinterlassen sichtbare Resonanz.

## 1. Leitidee und KO-Kriterien

WIRKLICHT soll **kein berührungsloses Bedieninterface** sein. Menschen sollen nicht lernen müssen: „Wenn ich Geste X mache, passiert Effekt Y.“

Leitgedanke:

> **WIRKLICHT visualisiert nicht die Befehle von Menschen, sondern die Spuren ihrer Anwesenheit, Bewegung und Beziehung.**

Daraus folgen sechs Grundsätze:

1. **Resonanz statt Gestensteuerung:** kontinuierliche Körper- und Beziehungssignale statt eines Katalogs benannter Kommandogesten.
2. **Nachwirkung statt sofortigem Verschwinden:** Menschen und Gruppen können Spuren hinterlassen, die noch weiterwirken, wenn sie den Erfassungsbereich verlassen haben.
3. **Individuum → Beziehung → Gruppe → Raum:** je mehr Menschen beteiligt sind, desto weniger soll die Fassade wie viele einzelne Avatare wirken und desto stärker wird das gemeinsame Geschehen sichtbar.
4. **Datenschutz als Architekturprinzip:** Bildverarbeitung ausschließlich lokal; keine Speicherung oder Cloud-Übertragung von Bildern.
5. **Live-Tauglichkeit durch schaltbare Effekte:** jede eigenständige visuelle Materialität muss über `config/config.json` einzeln deaktivierbar sein.
6. **Verständliche Rückkopplung ohne Bedienanleitung:** Passant:innen dürfen nicht erst zufällig die Fassade beobachten und den Zusammenhang selbst erraten müssen. Der Nahraum muss die Kopplung **Ich ↔ Resonanz ↔ Fassade** schnell erfahrbar machen, ohne das Projekt zur Technikdemo zu machen.

## 2. Räumlicher Rahmen und Stand

Die Installation erfasst **nicht einen ganzen Straßenzug**. Vorgesehen ist ein klar begrenzter, beleuchteter Resonanzbereich am Stand bzw. im Eingangsbereich des Kirchenamtes.

Zielgröße: ungefähr **2–20 gleichzeitig erfasste Personen**.

Der Stand ist keine Informations- oder Spielstation, sondern eine **Schwelle** zwischen alltäglichem Verkehrsraum und Resonanzraum. Die Lichtinsel markiert den zuverlässig erfassbaren Bereich atmosphärisch, nicht als exakte Bühnenposition.

Neu verbindlich ist eine dreistufige Vermittlungsdramaturgie:

1. **Lichtinsel:** „Hier ist ein besonderer Ort.“
2. **Nahraum-Monitor:** „Das dort hat mit mir zu tun.“
3. **Kurze Frage:** „Was geschieht, wenn du bleibst?“

Die Fassade bleibt der eigentliche öffentliche Resonanzraum. Der Monitor ist nur die unmittelbare Rückkopplung im Nahbereich.

Details: `docs/Standkonzept.md`.

## 3. Architektur

```text
Kamera ─[OpenCV]→ MediaPipe Pose ─[features.py]→ Resonanzsignale
       ─JSON/UDP→ Godot 4.7 → Licht / Partikel / Felder / Spuren / Wellen → Beamer
                                      │
                                      └→ Resonanz-Vorschau → Nahraum-Monitor
```

Die Trennung bleibt bewusst:

- `capture/` erkennt Körper und berechnet möglichst **semantisch arme, kontinuierliche Eigenschaften**.
- Das Protokoll transportiert Körper-, Beziehungs-, Gruppen- und ausgewählte Ereignisdaten.
- `renderer/` interpretiert diese Daten künstlerisch.
- `config/config.json` steuert Kamera, Features, Stand-/Monitoroptionen und visuelle Effektfamilien.
- `config/prompts.json` enthält die **kuratierten kurzen Sprachimpulse**; Texte werden nicht im Renderer-Code festgeschrieben.

Für die räumliche Installation ist ein Sensorrechner in Kameranähe weiterhin die bevorzugte Variante. Über die etwa 50 m zum Hauptrechner werden primär abstrakte Tracking-/Resonanzdaten transportiert. Für den Nahraum-Monitor fließt zusätzlich eine niedrig-latente Visualisierungs-Vorschau zurück.

**Wichtig:** Der Publikumsmonitor zeigt niemals das rohe Kamerabild. Kameravideo bleibt ausschließlich Diagnose-/Einrichtungswerkzeug.

## 4. Konfiguration und Live-Schalter

### 4.1 Visuelle Effekte

Jeder eigenständige visuelle Effekt benötigt in `config/config.json` mindestens einen expliziten `enabled`-Schalter.

```json
{
  "effects": {
    "body_glow": { "enabled": true },
    "trails": { "enabled": true },
    "sparks": { "enabled": true },
    "proximity_bridges": { "enabled": true },
    "mist": { "enabled": false },
    "waves": { "enabled": false },
    "floating_bodies": { "enabled": false },
    "aftereffect_waves": { "enabled": false },
    "crowd_field": { "enabled": false }
  }
}
```

`enabled: false` bedeutet: Effekt nicht erzeugen und nicht weiter simulieren. Capture-/Resonanzsignale bleiben davon unabhängig.

### 4.2 Stand, Monitor und Sprachimpuls

Standbezogene Funktionen erhalten einen eigenen Config-Bereich:

```json
{
  "station": {
    "monitor": {
      "enabled": true,
      "mode": "facade_preview",
      "show_camera_image": false
    },
    "prompt": {
      "enabled": true,
      "source": "config/prompts.json",
      "prompt_key": "stay_question"
    }
  }
}
```

Die Config entscheidet also **ob und welcher** Sprachimpuls aktiv ist; `config/prompts.json` ist die kuratierte Inhaltsquelle.

Bevorzugter Impuls:

> **Was geschieht, wenn du bleibst?**

Weitere Varianten dürfen erprobt werden, müssen aber dieselbe Leitplanke einhalten: keine Bedienanweisung, keine Geste-X→Effekt-Y-Sprache, keine Technikbeschreibung.

## 5. Status

| Phase | Inhalt | Stand |
|------:|--------|-------|
| 0 | Repo-Gerüst, Config, Protokoll, Tests | ✅ |
| 1 | Capture-MVP: Ganzkörper-Pose, Features, UDP, Simulator | ✅ |
| 2 | Renderer-MVP: Lichtgestalten, Bloom | ✅ |
| 3 | Leuchtspuren (Trails) | ✅ |
| 4 | Multi-Person + Lichtbrücken (Nähe) | ✅ |
| **4.5** | **Resonanzgrammatik + Nachwirkung + Effektsteuerung** | 🔜 nächster Schritt |
| **4.6** | **Nahraum-Monitor + Sprachimpuls + Verweil-Dramaturgie** | 🔜 parallel prototypisieren |
| 5 | Realwelt-Test: Beleuchtung, Distanz, 2–20 Personen, Verständlichkeit | offen |
| 6 | Projektion & Kalibrierung (Fassaden-Mapping) | offen |
| 7 | Hardware-Entscheidung / Robustheit | offen |
| 8 | Klang (optional) | offen |
| 9 | DSGVO/Beschilderung & Betriebshandbuch | offen |

## 6. Resonanzgrammatik

WIRKLICHT soll nicht versuchen zu erkennen, **was eine Bewegung bedeutet** oder welche Emotion jemand hat. Es erkennt beobachtbare körperliche Qualitäten.

Geeignete Resonanzsignale:

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

Keine Emotionsklassifikation und keine Interpretation wie „Freude“, „Trauer“ oder „Gebet“.

## 7. Visuelles Vokabular

| Resonanz | mögliche Materialität |
|----------|-----------------------|
| Anwesenheit | Lichtkörper / Glow |
| Bewegung | Funken / aufsteigende Lichtpartikel |
| schnelle oder kräftige Bewegung | stärkerer Partikelstrom |
| Ruhe / Bleiben | Verdichtung, langsames Pulsieren, ruhigere Feldbildung |
| Öffnung | räumliche Ausdehnung des Lichtfeldes |
| Bewegung durch den Raum | Spur / Trail |
| Nähe | Lichtbrücke / gemeinsames Feld |
| längere Nähe | Lichtdunst / leuchtende Atmosphäre |
| gemeinsamer Rhythmus | Wellen / rhythmische Modulation |
| größere Gruppe | gemeinsamer Atmosphärenzustand der Fassade |
| Verlassen | Nachwirkung / zurücklaufende Welle |

Die Tabelle ist **kein 1:1-Regelwerk**. Ein Zustand entsteht aus mehreren Signalen gleichzeitig.

Besonders wichtig für die neue Standdramaturgie:

> **Bleiben darf nicht bloß die Abwesenheit von Bewegung sein.**

Wenn eine Person nach dem Entdecken der Rückkopplung stehen bleibt, muss das System nach kurzer Zeit eine qualitativ andere Antwort anbieten können. Sonst bleibt die Frage „Was geschieht, wenn du bleibst?“ leer.

Zieldramaturgie:

> **Gehen → Spur.  
> Bleiben → Resonanz.  
> Mehrere → Beziehung.  
> Fortgehen → Nachwirkung.**

## 8. Projektionstauglichkeit

Die Installation läuft bei Dämmerung/Nacht auf einer realen Fassade bzw. Projektionsfläche.

Grundregeln:

- feine dunkle Effekte vermeiden;
- klare helle Kanten und aus Distanz lesbare Formen bevorzugen;
- Dunst eher als leuchtende Atmosphäre statt realistischer Rauch;
- Partikel nicht zu klein wählen;
- Nachwirkungen dürfen eine andere Formsprache besitzen als Anwesenheit;
- Monitorvorschau und Fassadenbild müssen visuell eng genug verwandt sein, dass die Kopplung intuitiv erkennbar bleibt.

## 9. Nachwirkung / Echo

Eine Person oder Gruppe soll beim Verlassen des Erfassungsbereichs **nicht einfach verschwinden**.

Bevorzugte Formsprache ist eine ruhige, vom Austrittsrand zurücklaufende Wasser-/Lichtwelle:

- Ursprung am plausiblen Austrittsrand;
- wenige breite Wellenfronten statt Splash-/Feuerwerk;
- Lichtreflexion statt realistisches Wasser;
- langsamer als normale Körperbewegung;
- kann vorhandene Partikel/Felder kurz modulieren;
- Gruppen-Austritte dürfen aggregiert werden.

Nur ein plausibler Austritt am Bildrand erzeugt `departure`; Trackingverlust durch Verdeckung nicht.

## 10. Vom Individuum zum gemeinsamen Resonanzkörper

### ca. 2–4 Personen

- Individuen deutlich erkennbar;
- eigene Lichtkörper und Spuren;
- direkte Beziehungen gut sichtbar.

### ca. 5–10 Personen

- Paarbeziehungen und kleine Gruppen gewinnen an Bedeutung;
- Felder, Dunst, gemeinsame Rhythmen und überlagerte Spuren treten stärker hervor.

### ca. 10–20 Personen

- keine zwanzig unabhängigen Effektmaschinen;
- stärkerer gemeinsamer Resonanzkörper der Fassade;
- Crowd-Energie, Gruppierung, Rhythmus und Atmosphäre bestimmen zunehmend das Gesamtbild.

Leitregel:

> **Je mehr Menschen dazukommen, desto weniger zeigt WIRKLICHT einzelne Menschen und desto stärker zeigt es das Geschehen zwischen ihnen.**

Zeitliche Zielrichtung:

```text
presence → relation → collective → memory
```

## 11. Phase 4.5 — Resonanzgrammatik

### Capture / Features

Priorisiert ergänzen:

1. `stillness`
2. `presence_time`
3. `verticality` bzw. `contraction`
4. einfacher zeitlicher `rhythm`
5. robuste Erkennung eines plausiblen Rand-Austritts (`departure`)

Bestehende Signale `intensity`, `openness` und `proximity` weiterverwenden.

### Simulator

Mindestens simulieren:

- lebendige Bewegung,
- Ruhe / Verweilen,
- Öffnung / Verdichtung,
- zwei Personen kommen zusammen,
- größere Gruppe,
- einzelne Person verlässt links/rechts,
- mehrere Personen verlassen gemeinsam einen Randbereich.

### Renderer

Schrittweise ergänzen:

1. Funken / Aufstieg;
2. Ruhe als Verdichtung statt Dunkelwerden;
3. Nähe als Feld / Dunst zusätzlich zur Linie;
4. rhythmische Bewegung als dezente Wellenmodulation;
5. `departure` als zurücklaufende Wasser-/Lichtwelle;
6. Interaktion der Wellen mit vorhandenen Partikeln/Feldern;
7. verpflichtende Config-Schalter für jede eigenständige Effektfamilie.

## 12. Phase 4.6 — Verständliche Rückkopplung im Nahraum

Diese Phase wird parallel zur Resonanzgrammatik prototypisiert, weil sie kein nachträgliches „Informationsdesign“, sondern Teil der Interaktion ist.

### 12.1 Monitor

Zu bauen/testen:

- kleiner Monitor in Kameranähe;
- keine rohe Kameraansicht im Publikumsbetrieb;
- `facade_preview`: möglichst gleiche oder eng verwandte Visualisierung wie auf der Fassade;
- niedrige Latenz zwischen Bewegung und Vorschau;
- Vorschau darf technisch reduziert sein, darf aber die Kausalität nicht verfälschen;
- Monitor darf die Fassade nicht als Hauptblickziel ersetzen.

### 12.2 Sprachimpuls

Ruhezustand zunächst mit:

> **Was geschieht, wenn du bleibst?**

Beim Eintritt einer Person soll der Text zurücktreten oder verschwinden und die Resonanz-Vorschau übernehmen.

Texte werden aus `config/prompts.json` geladen bzw. dort kuratiert; aktive Auswahl über `station.prompt.prompt_key`.

### 12.3 Verweil-Antwort

Der Prototyp muss sicherstellen, dass `stillness`/`presence_time` eine **qualitativ andere Resonanz** ermöglichen als bloßes Vorübergehen.

Zu testen:

- nach welcher Zeit „Bleiben“ wahrnehmbar werden soll;
- ob Verdichtung, Pulsieren oder Feldbildung am verständlichsten und ästhetisch stärksten wirkt;
- ob der Übergang langsam genug ist, um als Entdeckung statt als Schalter wahrgenommen zu werden.

## 13. Phase 5 — Realwelt-Test

Zu testen sind nicht nur Tracking und Projektion, sondern ausdrücklich auch **Verständlichkeit und Verweildynamik**:

- reale Stand-/Eingangsbeleuchtung bei Dämmerung und Nacht;
- Kameraposition und Sichtfeld;
- 2, 5, 10 und wenn möglich bis etwa 20 Personen;
- Verdeckungen und kreuzende Laufwege;
- Stabilität der Track-IDs;
- zuverlässige Rand-Austritte;
- Lesbarkeit der Projektion;
- Wirkung der Materialitäten;
- Latenz und Lesbarkeit des Nahraum-Monitors;
- erkennen Menschen innerhalb weniger Sekunden, dass ihre Anwesenheit die Visualisierung beeinflusst?
- verstehen sie ohne Erklärung, dass Fassade und Nahraum-Vorschau zusammengehören?
- erzeugt die Frage „Was geschieht, wenn du bleibst?“ tatsächlich Verweilen?
- erleben Menschen beim Bleiben eine neue Qualität oder nur einen gestoppten Effekt?
- konkurriert der Monitor mit der Fassade oder führt er den Blick dorthin?
- gezieltes Abschalten einzelner Effekte und Minimalzustand als Live-Fallback.

Erst nach diesem Test werden endgültige Hardware- und Vermittlungsentscheidungen getroffen.

## 14. Weitere Roadmap

### Phase 6 — Projektion & Kalibrierung

- Vollbildbetrieb;
- Eckpunkt-/Warp-Mapping;
- Laden/Speichern der Kalibrierung;
- Kontrast- und Helligkeitsabstimmung.

### Phase 7 — Hardware / Robustheit

- RGB beibehalten oder Beleuchtung optimieren;
- falls nötig IR-/Tiefenkamera evaluieren;
- Performance bei 2–20 Personen;
- robuste Netzwerkstrecke zum Sensorstand;
- Rückkanal für Monitorvorschau;
- Fallbacks bei Tracking-/Netzwerkausfällen.

### Phase 8 — Klang (optional)

Nur ergänzen, wenn Klang die Resonanzidee stärkt und die Installation nicht überlädt.

### Phase 9 — DSGVO & Betrieb

- Beschilderung zur lokalen, anonymen Verarbeitung;
- klare Trennung Datenschutzinfo ↔ poetischer Sprachimpuls;
- Kiosk-/Autostart;
- Failsafe;
- Betriebshandbuch;
- dokumentierte Effekt- und Stand-Defaults.

## 15. Bewusste Grenzen

- Keine Finger-/Handzeichenerkennung als Kerninteraktion.
- Keine Emotionserkennung.
- Keine Geste-X-löst-Effekt-Y-Sprache als dominantes Bedienprinzip.
- Keine Cloud-Bildverarbeitung.
- Keine Speicherung von Kameraaufnahmen.
- Kein rohes Kamerabild auf dem Publikumsmonitor.
- Kein erklärender Textblock als Voraussetzung zum Verstehen.
- Tracking muss nicht einen ganzen Straßenzug beherrschen; Ziel ist ein begrenzter Resonanzbereich mit ca. 2–20 Menschen.
- Projektionstauglichkeit ist wichtiger als feine Bildschirmästhetik.
- Jeder eigenständige visuelle Effekt bleibt zur Laufzeit abschaltbar.
- Monitor und Sprachimpuls müssen ebenfalls zur Laufzeit deaktivierbar sein.

## 16. Offene Entscheidungen

1. Wie lange muss eine Person ungefähr verweilen, bevor `stillness`/`presence_time` eine deutlich neue visuelle Qualität auslösen?
2. Welche Formsprache beantwortet das Bleiben am stärksten: Verdichtung, Pulsieren, Feldbildung oder eine Mischung?
3. Wie exakt muss die Monitor-Vorschau das Fassadenbild spiegeln, und wie stark darf sie reduziert werden?
4. Welcher technische Rückkanal bietet über ca. 50 m die ausreichend niedrige Latenz für die Vorschau?
5. Welche Monitorgröße und Position führen den Blick zur Fassade, statt ihn dort festzuhalten?
6. Welcher kurze Sprachimpuls funktioniert im Realwelt-Test am besten?
7. Wie lange soll Nachwirkung typischerweise bestehen?
8. Welche Kombination wird als robuster `minimal`-Fallback definiert?
9. Klang: überhaupt gewünscht, und wenn ja eher atmosphärisch in Godot oder über OSC an ein externes System?
