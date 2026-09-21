; WIRKLICHT — Windows-Installer (Inno Setup 6).
;
; Diese setup.exe ist bewusst nur eine duenne Huelle: sie enthaelt den
; vollstaendigen Projektcode (ca. 1 MB) und fuehrt danach die bestehende,
; gepruefte Logik aus lib/common.ps1 aus. Damit gibt es genau eine Quelle der
; Wahrheit fuer die Installation — unabhaengig davon, ob sie per PowerShell-
; Befehl oder per Doppelklick gestartet wird.
;
; Godot, Python und das Pose-Modell werden weiterhin bei der Installation
; nachgeladen. Ein gebuendeltes Offline-Paket bleibt damit ohne Aenderung an
; der Logik moeglich: dann entfaellt nur das Nachladen in lib/common.ps1.
;
; Bauen:  installer\build.ps1   (ruft ISCC.exe mit diesem Skript auf)

#define WirklichtName "WIRKLICHT"
#define WirklichtPublisher "WIRKLICHT (Lichterfest Bad Wilhelmshoehe)"

; Version wird von build.ps1 per /DVersion=... uebergeben. Der Fallback haelt
; einen direkten ISCC-Aufruf ohne Parameter lauffaehig.
#ifndef Version
  #define Version "0.0.0"
#endif

; Windows-Versionsinformationen brauchen vier Zahlstellen (a.b.c.d).
; build.ps1 uebergibt sie als /DVersionNumeric=...; der Fallback erlaubt
; einen direkten ISCC-Aufruf ohne Parameter.
#ifndef VersionNumeric
  #define VersionNumeric "0.0.0.0"
#endif

[Setup]
AppId={{8F3A1C64-2B47-4E9D-9A15-7C0E5D3B6A21}
AppName={#WirklichtName}
AppVersion={#Version}
AppVerName={#WirklichtName} {#Version}
AppPublisher={#WirklichtPublisher}
DefaultDirName=C:\WIRKLICHT
DefaultGroupName={#WirklichtName}
DisableDirPage=no
DisableProgramGroupPage=yes
OutputDir=..\dist
OutputBaseFilename=WIRKLICHT-Setup-{#Version}
Compression=lzma2/max
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; Kein UAC-Dialog: Windows erlaubt das Anlegen neuer Ordner direkt unter C:\
; auch fuer Standardbenutzer, und Godot ist portabel. Entspricht dem
; bisherigen Verhalten von install.ps1.
PrivilegesRequired=lowest
; Der Projektcode ist klein; der Platzbedarf entsteht durch Godot, Python und
; die Python-Pakete, die waehrend der Installation nachgeladen werden.
ExtraDiskSpaceRequired=3221225472
LicenseFile=..\LICENSE
MinVersion=10.0
SetupLogging=yes
WizardStyle=modern
VersionInfoVersion={#VersionNumeric}
VersionInfoCompany={#WirklichtPublisher}
VersionInfoDescription={#WirklichtName} Installationsprogramm
VersionInfoProductName={#WirklichtName}
VersionInfoProductVersion={#Version}

[Languages]
Name: "german"; MessagesFile: "compiler:Languages\German.isl"

[Tasks]
Name: "desktopicon"; Description: "Verknuepfungen auf dem Desktop anlegen"; GroupDescription: "Zusaetzliche Verknuepfungen:"; Flags: checkedonce

[Files]
; Der gesamte Projektcode. Bewusst NICHT mitgeliefert:
;   - config\config.json  lokale Betriebseinstellungen (Kamera, Bildschirme);
;                         wird von install.ps1 nur angelegt, wenn sie fehlt
;   - models\, tools\, logs\, backup\, .venv\, .git
;                         nachgeladen bzw. reiner Laufzeit-/Betriebszustand
Source: "..\capture\*";  DestDir: "{app}\capture";  Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "__pycache__,*.pyc"
Source: "..\config\*";   DestDir: "{app}\config";   Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "config.json,local.json"
; Vorlage fuer eine frische Installation. install.ps1 legt daraus
; config\config.json an, falls noch keine lokale Konfiguration existiert.
; skipifsourcedoesntexist: ein direktes ISCC aus einer Quellbaum-Kopie ohne
; die Vorlage soll nicht am fehlenden Template scheitern.
Source: "..\config\config.json"; DestDir: "{app}\config"; DestName: "config.json.template"; Flags: ignoreversion skipifsourcedoesntexist
Source: "..\docs\*";     DestDir: "{app}\docs";     Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\lib\*";      DestDir: "{app}\lib";      Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\renderer\*"; DestDir: "{app}\renderer"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: ".godot"
Source: "..\tests\*";    DestDir: "{app}\tests";    Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "__pycache__,*.pyc"
Source: "..\*.ps1";      DestDir: "{app}";          Flags: ignoreversion
Source: "..\*.cmd";      DestDir: "{app}";          Flags: ignoreversion
Source: "..\VERSION";    DestDir: "{app}";          Flags: ignoreversion
Source: "..\README.md";  DestDir: "{app}";          Flags: ignoreversion
Source: "..\AGENTS.md";  DestDir: "{app}";          Flags: ignoreversion
Source: "..\LICENSE";    DestDir: "{app}";          Flags: ignoreversion

[Icons]
Name: "{group}\{#WirklichtName} starten";           Filename: "{app}\WIRKLICHT starten.cmd"
Name: "{group}\{#WirklichtName} Hilfe && Diagnose"; Filename: "{app}\WIRKLICHT Diagnose.cmd"
Name: "{group}\{#WirklichtName} deinstallieren";    Filename: "{uninstallexe}"
Name: "{autodesktop}\{#WirklichtName} starten";           Filename: "{app}\WIRKLICHT starten.cmd";    Tasks: desktopicon
Name: "{autodesktop}\{#WirklichtName} Hilfe && Diagnose"; Filename: "{app}\WIRKLICHT Diagnose.cmd";  Tasks: desktopicon

[UninstallDelete]
; Laufzeitdateien entfernen, die Inno nicht selbst installiert hat.
; Bewusst NICHT geloescht werden config\ und backup\: dort stehen die
; Betriebseinstellungen und die letzten Sicherungen des Veranstaltungsorts.
Type: filesandordirs; Name: "{app}\tools"
Type: filesandordirs; Name: "{app}\models"
Type: filesandordirs; Name: "{app}\.venv"
Type: filesandordirs; Name: "{app}\logs"
Type: filesandordirs; Name: "{app}\renderer\.godot"

[Run]
; Schritt 1: Der Projektcode wird ueber die gepruefte Logik von lib/common.ps1
; vervollstaendigt. -SkipProjectDownload verhindert, dass die eben entpackten
; Dateien erneut aus dem Netz geholt werden. -InstallPath ist zwingend, weil
; install.ps1 sonst auf seinen Default C:\WIRKLICHT zurueckfaellt und ein
; abweichend gewaehltes Zielverzeichnis ignorieren wuerde.
;
; Bewusst sichtbar (kein runhidden): Python, Godot und die Python-Pakete
; werden nachgeladen. Ein verstecktes Fenster wirkte ueber mehrere Minuten
; wie ein Haenger; so sieht der Bediener den echten Fortschritt.
Filename: "powershell.exe"; \
  Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\install.ps1"" -SkipProjectDownload -InstallPath ""{app}"""; \
  WorkingDir: "{app}"; \
  StatusMsg: "WIRKLICHT wird eingerichtet (Python, Godot, Pose-Modell) ..."; \
  Flags: waituntilterminated

; Schritt 2: Optionaler Start nach der Installation.
Filename: "{app}\WIRKLICHT starten.cmd"; \
  Description: "{#WirklichtName} jetzt starten"; \
  WorkingDir: "{app}"; \
  Flags: postinstall nowait skipifsilent unchecked

[Code]
// Ein stiller Teilfehler darf nicht als Erfolg gemeldet werden: nach dem
// Entpacken wird geprueft, ob die Kerndateien tatsaechlich vorliegen.
procedure CurStepChanged(CurStep: TSetupStep);
var
  Missing: string;
begin
  if CurStep = ssPostInstall then
  begin
    Missing := '';
    if not FileExists(ExpandConstant('{app}\lib\common.ps1')) then
      Missing := Missing + 'lib\common.ps1' + #13#10;
    if not FileExists(ExpandConstant('{app}\capture\tracker.py')) then
      Missing := Missing + 'capture\tracker.py' + #13#10;
    if not FileExists(ExpandConstant('{app}\config\config.json')) then
      Missing := Missing + 'config\config.json' + #13#10;
    if Missing <> '' then
      MsgBox('Die WIRKLICHT-Dateien sind unvollstaendig:' + #13#10#13#10 +
             Missing + #13#10 +
             'Bitte die Installation erneut ausfuehren.', mbError, MB_OK);
  end;
end;
