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
