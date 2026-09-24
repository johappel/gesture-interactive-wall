# WIRKLICHT - Vor-Ort-Betrieb

1. Rechner einschalten.
2. Kamera anschliessen und Zoom, Teams oder OBS schliessen.
3. **WIRKLICHT starten** auf dem Desktop doppelklicken.
4. Erscheint die Bildschirmwahl, den Beamer bzw. die Fassade auswählen und
   **Speichern** klicken. Die Auswahl ist für spätere Starts gespeichert.
5. Pruefen, ob **WIRKLICHT IST BEREIT** erscheint.
6. Bei einem Fehler **WIRKLICHT Hilfe & Diagnose** oeffnen.
7. `WIRKLICHT-DIAGNOSE.txt` an Joachim schicken.

Wenn die Desktop-Verknüpfung nicht sichtbar ist: Im Windows-Startmenü nach
**WIRKLICHT** suchen oder `C:\WIRKLICHT\WIRKLICHT starten.cmd` doppelklicken.

Die normale Veranstaltung benoetigt kein Internet. Das Kamerabild wird lokal
verarbeitet und nicht gespeichert oder hochgeladen. Der Publikumsmonitor zeigt
kein rohes Kamerabild.

## Wenn die Kamera gewechselt wurde

Beim Start wird die bisher gespeicherte Kamera automatisch versucht. Wird sie
nicht gefunden, zeigt WIRKLICHT eine kurze Liste und speichert die Auswahl fuer
die naechsten Starts. Die Auswahl verwendet Kameraname und USB-Kennung und
bleibt deshalb normalerweise auch nach einem Wechsel des USB-Ports erhalten.
Virtuelle Kameras wie OBS werden in der Liste namentlich angezeigt.

Eine andere Kamera kann jederzeit über **WIRKLICHT Kamera waehlen** auf dem
Desktop ausgewählt werden. Der Dialog testet die Kamera vor dem Speichern.

## Wenn Beamer oder Bildschirm gewechselt wurde

Öffne auf dem Desktop **WIRKLICHT Bildschirm waehlen**. Der Dialog listet die
Windows-Bildschirme mit Auflösung, virtueller Position und Hauptmonitor-Markierung.
Wähle den Beamer für die Fassade und speichere. Beim nächsten Start setzt Godot
das Fenster zuerst auf diesen Bildschirm und aktiviert erst danach Vollbild.
Fehlt die gespeicherte Ausgabe, zeigt der normale Start die Auswahl erneut;
ein manueller Renderer-Start fällt sicher auf den Hauptbildschirm zurück.

Für die Resonanz-Vorschau auf dem kleinen Standbildschirm öffne
**WIRKLICHT Nahraum-Monitor waehlen**. Dieser Bildschirm muss sich von der
Fassade unterscheiden und zeigt weiterhin kein Kamerabild.

## Bewusstes Update

Updates nur vor oder nach einer Veranstaltung ausfuehren. In PowerShell im
Installationsordner:

```powershell
powershell -ExecutionPolicy Bypass -File C:\WIRKLICHT\update.ps1
```

Das Update sichert die lokale Config und wichtige Betriebsdateien unter
`C:\WIRKLICHT\backup`.

## Technische Diagnose (nur Aufbau/Techniker)

Für die Latenz- und Erkennungsdiagnose beim Aufbau (nicht im Publikumsbetrieb).
Im Repository-/Installationsordner in der aktivierten venv:

```powershell
python -m capture.tracker --diagnostics
```

Es erscheint einmal pro Sekunde eine kompakte Zeile, z. B.:

```text
[capture] camera=30.0fps loop=14.2fps read=4.1ms pose=62.8ms features=1.2ms
udp=0.2ms raw_poses=3.0 accepted=2.0 tracks=2 missing=0 dropped=16
rejected=torso_visibility:1 backend=any fourcc=MJPG resolution=1280x720
```

Deutung:

- `loop` deutlich unter `camera` und ein hohes `pose` (ms) → Inferenz ist der
  Flaschenhals. Gegenmittel in `config/config.json`: `camera.width/height`
  senken, `pose.inference_width/height` setzen (z. B. `960`/`540`) oder
  `pose.num_poses` reduzieren.
- `raw_poses` hoch, `accepted` niedrig, `rejected=torso_visibility` → eine
  reale Person wird herausgefiltert. `pose.min_torso_visibility` senken.
- `raw_poses` bereits niedrig → MediaPipe erkennt die Person gar nicht erst
  (Beleuchtung/Abstand/Gegenlicht prüfen), kein Filterproblem.
- `dropped` groß ist normal und erwünscht: alte Kamerabilder werden bewusst
  verworfen (latest-frame-wins), damit die Darstellung nicht zurückfällt.

`pose.num_poses` und Inferenzauflösung vor Ort messen statt raten:

```powershell
python -m capture.bench
```

Die Tabelle zeigt je Einstellung `pose_ms` und effektive `fps`; einen Default
wählen, der die Ziel-Personenzahl bei ausreichender Update-Rate trägt.

Hinweis: MediaPipe (Python) rechnet standardmäßig auf der **CPU**; eine starke
GPU beschleunigt die Pose-Erkennung hier nicht automatisch. Latenz zuerst über
Auflösung, Inferenz-Downscale und `num_poses` steuern.

