# WIRKLICHT - Vor-Ort-Betrieb

1. Rechner einschalten.
2. Kamera anschliessen und Zoom, Teams oder OBS schliessen.
3. **WIRKLICHT starten** auf dem Desktop doppelklicken.
4. Pruefen, ob **WIRKLICHT IST BEREIT** erscheint.
5. Bei einem Fehler **WIRKLICHT Hilfe & Diagnose** oeffnen.
6. `WIRKLICHT-DIAGNOSE.txt` an Joachim schicken.

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

## Bewusstes Update

Updates nur vor oder nach einer Veranstaltung ausfuehren. In PowerShell im
Installationsordner:

```powershell
powershell -ExecutionPolicy Bypass -File C:\WIRKLICHT\update.ps1
```

Das Update sichert die lokale Config und wichtige Betriebsdateien unter
`C:\WIRKLICHT\backup`.
