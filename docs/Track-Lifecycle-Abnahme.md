# WIRKLICHT — Abnahme Track-Lebenszyklus

Dieses Dokument ergänzt `docs/plan.md` für Phase 4.5. Es beschreibt die verbindlichen Abnahmekriterien für die Stabilität von Track-IDs und für die Unterscheidung zwischen kurzzeitigem Trackingverlust und echtem Verlassen des Erfassungsraums.

## Grundsatz

Eine Track-ID bezeichnet keine biometrische Identität einer Person, sondern eine **aktuelle Anwesenheitsepisode im Resonanzraum**.

Ein kurzfristiger Detection-Ausfall oder eine Verdeckung darf deshalb nicht automatisch eine neue Anwesenheit erzeugen. Umgekehrt soll eine Person, die den Erfassungsraum wirklich verlassen hat und später zurückkehrt, eine neue Track-ID erhalten.

Diese Logik ist Voraussetzung für eine verlässliche Nachwirkung: Nur ein plausibler tatsächlicher Austritt darf `departure` und damit eine Nachwirkungswelle auslösen.

## Erwarteter Track-Lebenszyklus

Mindestens folgende Zustände sollen fachlich unterscheidbar sein:

```text
active
  ↓ kurzzeitig nicht erkannt
temporarily_missing
  ├─ plausible Wiederaufnahme → active mit gleicher ID
  └─ plausibler Rand-Austritt → departed
```

Ein Verlust mitten im Bild ohne plausiblen Rand-Austritt darf nicht als `departed` gewertet werden.

## Verbindliche Abnahmekriterien für Phase 4.5

### 1. Stabile Anwesenheit

Eine kontinuierlich sichtbare Person behält ihre Track-ID über die gesamte Anwesenheit.

### 2. Kurze Verdeckung

Wird eine Person für eine kurze, definierte Grace Period verdeckt oder nicht erkannt und taucht räumlich plausibel wieder auf, wird derselbe Track fortgesetzt.

Erwartung:

- gleiche ID;
- kein künstliches Ende der Anwesenheit;
- kein `departure`;
- keine Nachwirkungswelle.

### 3. Detection-Flackern

Ein einzelner oder kurzer Ausfall der Pose-Erkennung darf weder eine neue Person erzeugen noch den vorhandenen Track als verlassen markieren.

### 4. Kreuzende Personen

Bei zwei sich kreuzenden Personen gilt mindestens:

- nie dieselbe Track-ID gleichzeitig für zwei Personen;
- keine doppelten Track-Referenzen im selben Frame;
- ID-Swaps sollen durch die Zuordnungslogik soweit praktisch möglich vermieden werden.

Dieser Fall muss ausdrücklich im Simulator und später mit realer Kamera getestet werden.

### 5. Verlust in der Bildmitte

Verschwindet eine Person aufgrund von Verdeckung, Pose-Ausfall oder Trackingfehler innerhalb des Resonanzraums, darf daraus **kein `departure`** entstehen.

Das gilt auch dann, wenn der Track nach Ablauf der Grace Period technisch beendet werden muss.

### 6. Echter Austritt

Ein Track darf als `departed` gelten, wenn der zeitliche und räumliche Verlauf einen tatsächlichen Austritt am Rand des definierten Erfassungsraums plausibel macht.

Nur dieser Fall darf eine Nachwirkung auslösen.

### 7. Rückkehr nach beendetem Track

Hat eine Person den Erfassungsraum tatsächlich verlassen und kehrt später zurück, beginnt eine neue Anwesenheitsepisode.

Erwartung:

```text
Austritt → Track beendet → spätere Rückkehr → neue Track-ID
```

Es findet keine biometrische Wiedererkennung statt.

### 8. Referenzintegrität

Für jeden ausgegebenen Frame gilt:

- jede aktive Track-ID ist eindeutig;
- `pairs` referenzieren nur im jeweiligen Zustand zulässige Tracks;
- Crowd-/Gruppendaten enthalten keine verwaisten Track-IDs;
- beendete Tracks werden nicht unbegrenzt weitergeführt.

### 9. Langlauf

Ein längerer Simulatorlauf muss zeigen, dass:

- keine unkontrolliert wachsende Menge alter Tracks verbleibt;
- keine Track-ID gleichzeitig mehrfach aktiv ist;
- temporär verlorene Tracks zuverlässig bereinigt werden;
- wiederholtes Eintreten und Verlassen zu konsistenten neuen Anwesenheitsepisoden führt.

## Pflichtszenarien im Simulator

Vor Abnahme von Phase 4.5 mindestens testen:

1. eine Person bleibt kontinuierlich sichtbar;
2. eine Person wird kurz verdeckt und erscheint wieder;
3. ein einzelner Detection-Frame fällt aus;
4. zwei Personen kreuzen sich;
5. eine Person verschwindet mitten im Bild;
6. eine Person verlässt den Raum links;
7. eine Person verlässt den Raum rechts;
8. mehrere Personen verlassen gemeinsam einen Randbereich;
9. eine Person verlässt vollständig und kehrt später zurück;
10. längerer Lauf mit wiederholtem Eintritt, Verdeckung, Kreuzung und Austritt.

## Realwelt-Abnahme

Die automatisierten Tests reichen nicht aus. In Phase 5 ist mit realer Kamera zusätzlich zu prüfen:

- Verdeckungen durch andere Personen;
- schlechte oder wechselnde Beleuchtung;
- Personen, die eng aneinander vorbeigehen;
- Personen am Rand des Kamerabildes;
- kurzfristige Pose-Aussetzer;
- falsche `departure`-Ereignisse;
- Stabilität bei mehreren gleichzeitig erfassten Personen.

Die Abnahme ist erfolgreich, wenn technische Trackingfehler **nicht als ästhetisch bedeutungsvolle Ereignisse ausgegeben werden**. Insbesondere darf eine Verdeckung nicht wie ein Fortgehen inszeniert werden.
