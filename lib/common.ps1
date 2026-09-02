# Shared, operator-facing helpers for the WIRKLICHT Windows scripts.
# The script intentionally uses only Windows PowerShell 5.1 features.

$script:WirklichtRoot = Split-Path -Parent $PSScriptRoot
$script:WirklichtRepoZipUrl = "https://github.com/johappel/gesture-interactive-wall/archive/refs/heads/main.zip"
$script:WirklichtGodotVersion = "4.7.1-stable"
$script:WirklichtGodotUrl = "https://github.com/godotengine/godot/releases/download/4.7.1-stable/Godot_v4.7.1-stable_win64.exe"
$script:WirklichtMinimumFreeSpaceGB = 5

function Set-WirklichtRoot {
    param([string]$Path)
    $script:WirklichtRoot = [IO.Path]::GetFullPath($Path)
}

function Get-WirklichtVersion {
    $versionFile = Join-Path $script:WirklichtRoot "VERSION"
    if (Test-Path -LiteralPath $versionFile) {
        return (Get-Content -LiteralPath $versionFile -Raw).Trim()
    }
    return "unbekannt"
}

function Get-WirklichtLogPath {
    param([string]$Name)
    $logDirectory = Join-Path $script:WirklichtRoot "logs"
    New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null
    return (Join-Path $logDirectory $Name)
}

function Limit-WirklichtLog {
    param([string]$Path, [int]$MaximumBytes = 1048576)
    if ((Test-Path -LiteralPath $Path) -and ((Get-Item -LiteralPath $Path).Length -gt $MaximumBytes)) {
        $tail = Get-Content -LiteralPath $Path -Tail 5000
        Set-Content -LiteralPath $Path -Value $tail -Encoding UTF8
    }
}

function Write-WirklichtLog {
    param([string]$Path, [string]$Message)
    $line = "{0} {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
    Add-Content -LiteralPath $Path -Value $line -Encoding UTF8
    Limit-WirklichtLog -Path $Path
}

function Write-WirklichtHeader {
    param([string]$Title)
    Write-Host ""
    Write-Host "========================================" -ForegroundColor DarkCyan
    Write-Host ("          {0}" -f $Title) -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor DarkCyan
    Write-Host ""
}

function Write-WirklichtStep {
    param([string]$Name, [string]$State, [ConsoleColor]$Color = [ConsoleColor]::Gray)
    Write-Host ("{0,-32} {1}" -f $Name, $State) -ForegroundColor $Color
}

function Read-WirklichtJson {
    param([string]$Path)
    try {
        return (Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json)
    } catch {
        throw "Die Konfiguration ist beschaedigt oder nicht lesbar: $Path"
    }
}

function Write-WirklichtJson {
    param([string]$Path, [object]$Value)
    $directory = Split-Path -Parent $Path
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
    $temporary = "$Path.tmp"
    $Value | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $temporary -Encoding UTF8
    Move-Item -LiteralPath $temporary -Destination $Path -Force
}

function Get-WirklichtLocalStatePaths {
    return @(
        (Join-Path $script:WirklichtRoot "config\config.json"),
        (Join-Path $script:WirklichtRoot "config\local.json")
    )
}

function Backup-WirklichtLocalState {
    param([string]$DestinationRoot = (Join-Path $script:WirklichtRoot "backup"))
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss-fff"
    $destination = Join-Path $DestinationRoot $stamp
    New-Item -ItemType Directory -Force -Path $destination | Out-Null
    foreach ($path in Get-WirklichtLocalStatePaths) {
        if (Test-Path -LiteralPath $path) {
            Copy-Item -LiteralPath $path -Destination (Join-Path $destination (Split-Path -Leaf $path)) -Force
        }
    }
    return $destination
}

function Backup-WirklichtProgramFiles {
    param([string]$DestinationRoot)
    New-Item -ItemType Directory -Force -Path $DestinationRoot | Out-Null
    $excludedDirectories = @(".git", ".venv", "models", "logs", "backup", "tools")
    $sourceLength = $script:WirklichtRoot.TrimEnd('\').Length
    Get-ChildItem -LiteralPath $script:WirklichtRoot -Force -Recurse | ForEach-Object {
        $relative = $_.FullName.Substring($sourceLength).TrimStart('\')
        $parts = $relative -split '\\'
        if ($parts.Count -gt 0 -and $excludedDirectories -contains $parts[0]) { return }
        $destination = Join-Path $DestinationRoot $relative
        if ($_.PSIsContainer) { New-Item -ItemType Directory -Force -Path $destination | Out-Null }
        else { New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null; Copy-Item -LiteralPath $_.FullName -Destination $destination -Force }
    }
}

function Restore-WirklichtProgramFiles {
    param([string]$SourceRoot)
    if (-not (Test-Path -LiteralPath $SourceRoot)) { return }
    $sourceLength = $SourceRoot.TrimEnd('\').Length
    Get-ChildItem -LiteralPath $SourceRoot -Force -Recurse | ForEach-Object {
        $relative = $_.FullName.Substring($sourceLength).TrimStart('\')
        $destination = Join-Path $script:WirklichtRoot $relative
        if ($_.PSIsContainer) { New-Item -ItemType Directory -Force -Path $destination | Out-Null }
        else { New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null; Copy-Item -LiteralPath $_.FullName -Destination $destination -Force }
    }
}

function Get-WirklichtPythonCandidates {
    $paths = New-Object System.Collections.Generic.List[string]
    $commands = @("py", "python")
    foreach ($commandName in $commands) {
        $command = Get-Command $commandName -ErrorAction SilentlyContinue
        if ($null -ne $command -and $command.Source -notlike "*WindowsApps*") {
            [void]$paths.Add($command.Source)
        }
    }
    foreach ($path in @(
        (Join-Path $env:LOCALAPPDATA "Programs\Python\Python311\python.exe"),
        "C:\Program Files\Python311\python.exe",
        "C:\Python311\python.exe"
    )) {
        if (Test-Path -LiteralPath $path) { [void]$paths.Add($path) }
    }
    return @($paths | Select-Object -Unique)
}

function Get-WirklichtPythonInfo {
    foreach ($candidate in Get-WirklichtPythonCandidates) {
        try {
            $version = (& $candidate --version 2>&1 | Out-String).Trim()
            if ($version -match "Python\s+(\d+)\.(\d+)") {
                return [pscustomobject]@{
                    Path = $candidate
                    Version = $version
                    Major = [int]$Matches[1]
                    Minor = [int]$Matches[2]
                }
            }
        } catch { }
    }
    return $null
}

function Ensure-WirklichtPython {
    $info = Get-WirklichtPythonInfo
    if ($null -ne $info -and $info.Major -eq 3 -and $info.Minor -eq 11) {
        return $info
    }

    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($null -eq $winget) {
        throw "Python 3.11 wurde nicht gefunden und winget ist auf diesem Rechner nicht verfuegbar. Bitte Python 3.11 x64 installieren und erneut starten."
    }
    Write-Host "Python 3.11 wird installiert. Ein Windows-Dialog kann erscheinen ..."
    & $winget.Source install --id Python.Python.3.11 --exact --scope user --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) { throw "Python konnte nicht installiert werden. Bitte den Installationsdialog pruefen." }
    $info = Get-WirklichtPythonInfo
    if ($null -eq $info -or $info.Major -ne 3 -or $info.Minor -ne 11) {
        throw "Python wurde installiert, ist aber noch nicht auffindbar. Bitte WIRKLICHT erneut starten."
    }
    return $info
}

function Get-WirklichtVenvPython {
    return (Join-Path $script:WirklichtRoot ".venv\Scripts\python.exe")
}

function Invoke-WirklichtPython {
    param([string]$PythonPath, [string[]]$Arguments)
    & $PythonPath @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Ein Python-Schritt ist fehlgeschlagen. Details stehen im Log." }
}

function Ensure-WirklichtPythonEnvironment {
    param([pscustomobject]$PythonInfo)
    $venvPython = Get-WirklichtVenvPython
    if (Test-Path -LiteralPath $venvPython) {
        & $venvPython "--version" 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Python-Umgebung ist beschaedigt. Sie wird neu eingerichtet ..."
            Remove-Item -LiteralPath (Join-Path $script:WirklichtRoot ".venv") -Recurse -Force
        }
    }
    if (-not (Test-Path -LiteralPath $venvPython)) {
        Write-Host "Python-Umgebung fehlt. Sie wird repariert ..."
        Invoke-WirklichtPython -PythonPath $PythonInfo.Path -Arguments @("-m", "venv", (Join-Path $script:WirklichtRoot ".venv"))
    }

    $imports = "import cv2, mediapipe, numpy"
    & $venvPython "-c" $imports 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Python-Pakete fehlen. Sie werden eingerichtet ..."
        Invoke-WirklichtPython -PythonPath $venvPython -Arguments @("-m", "pip", "install", "-r", (Join-Path $script:WirklichtRoot "capture\requirements.txt"))
    }
    return $venvPython
}

function Get-WirklichtModelPath {
    $config = Join-Path $script:WirklichtRoot "config\config.json"
    if (Test-Path -LiteralPath $config) {
        try {
            $model = (Read-WirklichtJson $config).pose.model_path
            if ($model) { return (Join-Path $script:WirklichtRoot ($model -replace '/', '\')) }
        } catch { }
    }
    return (Join-Path $script:WirklichtRoot "models\pose_landmarker_full.task")
}

function Ensure-WirklichtModel {
    param([string]$VenvPython)
    $modelPath = Get-WirklichtModelPath
    if (-not (Test-Path -LiteralPath $modelPath)) {
        Write-Host "Pose-Modell fehlt. Es wird heruntergeladen ..."
        Invoke-WirklichtPython -PythonPath $VenvPython -Arguments @((Join-Path $script:WirklichtRoot "capture\download_model.py"))
    }
    if (-not (Test-Path -LiteralPath $modelPath)) { throw "Das Pose-Modell konnte nicht bereitgestellt werden." }
    return $modelPath
}

function Get-WirklichtGodotPath {
    $portable = Join-Path $script:WirklichtRoot ("tools\Godot_v{0}_win64.exe" -f $script:WirklichtGodotVersion)
    if (Test-Path -LiteralPath $portable) { return $portable }
    $command = Get-Command godot -ErrorAction SilentlyContinue
    if ($null -ne $command) { return $command.Source }
    return $portable
}

function Ensure-WirklichtGodot {
    $godotPath = Get-WirklichtGodotPath
    if (-not (Test-Path -LiteralPath $godotPath)) {
        Write-Host "Godot wird bereitgestellt (portable Version, kein Projektmanager erforderlich) ..."
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $godotPath) | Out-Null
        Invoke-WebRequest -Uri $script:WirklichtGodotUrl -OutFile $godotPath -UseBasicParsing
    }
    if (-not (Test-Path -LiteralPath $godotPath)) { throw "Godot konnte nicht bereitgestellt werden." }
    return $godotPath
}

function Test-WirklichtNetwork {
    foreach ($uri in @("https://raw.githubusercontent.com", "https://github.com")) {
        try {
            Invoke-WebRequest -Uri $uri -Method Head -UseBasicParsing -TimeoutSec 15 | Out-Null
        } catch { return $false }
    }
    return $true
}

function Test-WirklichtSystem {
    if ($env:OS -ne "Windows_NT") { throw "WIRKLICHT benoetigt Windows." }
    if ([Environment]::Is64BitOperatingSystem -eq $false) { throw "WIRKLICHT benoetigt ein 64-Bit-Windows." }
    $driveName = ([IO.Path]::GetPathRoot($script:WirklichtRoot)).TrimEnd('\').TrimEnd(':')
    $drive = Get-PSDrive -Name $driveName -ErrorAction SilentlyContinue
    if ($null -ne $drive -and ($drive.Free / 1GB) -lt $script:WirklichtMinimumFreeSpaceGB) {
        throw ("Auf Laufwerk {0} sind weniger als {1} GB frei." -f $driveName, $script:WirklichtMinimumFreeSpaceGB)
    }
    return [pscustomobject]@{ Windows = $true; Is64Bit = $true; FreeSpaceOK = $true }
}

function Get-WirklichtAvailableCameras {
    param([string]$VenvPython, [string]$Backend = "any")
    $code = "import json; from capture.camera import list_cameras; print(json.dumps(list_cameras(backend='$Backend')))"
    try {
        $raw = (& $VenvPython "-c" $code 2>$null | Out-String).Trim()
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($raw)) { return @() }
        return @(($raw | ConvertFrom-Json))
    } catch { return @() }
}

function Save-WirklichtCameraIndex {
    param([int]$Index)
    $configPath = Join-Path $script:WirklichtRoot "config\config.json"
    $config = Read-WirklichtJson $configPath
    $config.camera.index = $Index
    Write-WirklichtJson -Path $configPath -Value $config
}

function Select-WirklichtCamera {
    param([string]$VenvPython, [switch]$NonInteractive)
    $configPath = Join-Path $script:WirklichtRoot "config\config.json"
    $config = Read-WirklichtJson $configPath
    $backend = if ($config.camera.backend) { [string]$config.camera.backend } else { "any" }
    $cameras = @(Get-WirklichtAvailableCameras -VenvPython $VenvPython -Backend $backend)
    $configured = [int]$config.camera.index
    $selected = $cameras | Where-Object { [int]$_.index -eq $configured } | Select-Object -First 1
    if ($null -ne $selected) { return $configured }
    if ($cameras.Count -eq 0) { throw "Keine Kamera gefunden. Bitte USB-Kamera anschliessen und Zoom, Teams oder OBS schliessen." }
    Write-Host "Die bisher verwendete Kamera wurde nicht gefunden."
    Write-Host "Gefundene Kameras:"
    foreach ($camera in $cameras) { Write-Host ("  [{0}] Kamera {0} ({1}x{2})" -f $camera.index, $camera.width, $camera.height) }
    if ($cameras.Count -eq 1 -or $NonInteractive) {
        $choice = [int]$cameras[0].index
        Write-Host ("Kamera {0} wird verwendet." -f $choice)
    } else {
        do {
            $answer = Read-Host "Nummer"
            $valid = $cameras | Where-Object { [string]$_.index -eq $answer } | Select-Object -First 1
            if ($null -eq $valid) { Write-Host "Bitte eine Nummer aus der Liste eingeben." -ForegroundColor Yellow }
        } while ($null -eq $valid)
        $choice = [int]$valid.index
    }
    Save-WirklichtCameraIndex -Index $choice
    return $choice
}

function New-WirklichtShortcut {
    param([string]$Name, [string]$ScriptName, [string]$Description)
    $desktop = [Environment]::GetFolderPath("Desktop")
    $shortcutPath = Join-Path $desktop ("{0}.lnk" -f $Name)
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = (Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe")
    $shortcut.Arguments = '-NoProfile -ExecutionPolicy Bypass -File "{0}"' -f (Join-Path $script:WirklichtRoot $ScriptName)
    $shortcut.WorkingDirectory = $script:WirklichtRoot
    $shortcut.Description = $Description
    $shortcut.Save()
}

function Download-WirklichtArchive {
    param([string]$Url = $script:WirklichtRepoZipUrl)
    $temporaryDirectory = Join-Path ([IO.Path]::GetTempPath()) ("wirklicht-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path $temporaryDirectory | Out-Null
    $zipPath = Join-Path $temporaryDirectory "source.zip"
    try {
        Invoke-WebRequest -Uri $Url -OutFile $zipPath -UseBasicParsing
        Expand-Archive -LiteralPath $zipPath -DestinationPath $temporaryDirectory -Force
        $source = Get-ChildItem -LiteralPath $temporaryDirectory -Directory | Where-Object { $_.Name -ne "" } | Select-Object -First 1
        if ($null -eq $source) { throw "Das WIRKLICHT-Archiv konnte nicht entpackt werden." }
        return [pscustomobject]@{ Root = $source.FullName; TemporaryDirectory = $temporaryDirectory }
    } catch {
        Remove-Item -LiteralPath $temporaryDirectory -Recurse -Force -ErrorAction SilentlyContinue
        throw
    }
}

function Sync-WirklichtProject {
    param([string]$SourceRoot, [string]$DestinationRoot)
    $existingConfig = Test-Path -LiteralPath (Join-Path $DestinationRoot "config\config.json")
    $existingLocal = Test-Path -LiteralPath (Join-Path $DestinationRoot "config\local.json")
    New-Item -ItemType Directory -Force -Path $DestinationRoot | Out-Null
    $excludedDirectories = @(".git", ".venv", "models", "logs", "backup", "tools")
    $excludedFiles = @()
    if ($existingConfig) { $excludedFiles += "config\config.json" }
    if ($existingLocal) { $excludedFiles += "config\local.json" }
    $sourceLength = $SourceRoot.TrimEnd('\').Length
    Get-ChildItem -LiteralPath $SourceRoot -Force -Recurse | ForEach-Object {
        $relative = $_.FullName.Substring($sourceLength).TrimStart('\')
        $parts = $relative -split '\\'
        if ($parts.Count -gt 0 -and $excludedDirectories -contains $parts[0]) { return }
        if (-not $_.PSIsContainer -and $excludedFiles -contains $relative) { return }
        $destination = Join-Path $DestinationRoot $relative
        if ($_.PSIsContainer) {
            New-Item -ItemType Directory -Force -Path $destination | Out-Null
        } else {
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
            Copy-Item -LiteralPath $_.FullName -Destination $destination -Force
        }
    }
    if (-not $existingConfig) {
        $sourceConfig = Join-Path $SourceRoot "config\config.json"
        if (Test-Path -LiteralPath $sourceConfig) { Copy-Item -LiteralPath $sourceConfig -Destination (Join-Path $DestinationRoot "config\config.json") -Force }
    }
    return $true
}

function Invoke-WirklichtInstallation {
    param([switch]$SkipProjectDownload, [string]$SourceUrl = $script:WirklichtRepoZipUrl, [switch]$NonInteractive)
    $log = Get-WirklichtLogPath "install.log"
    try {
        Write-WirklichtHeader "WIRKLICHT INSTALLATION"
        Test-WirklichtSystem | Out-Null
        Write-WirklichtStep "Windows und Speicher" "OK" Green
        $wingetState = if ($null -ne (Get-Command winget -ErrorAction SilentlyContinue)) { "vorhanden" } else { "nicht vorhanden (nur bei Bedarf)" }
        Write-WirklichtStep "winget" $wingetState
        if (-not (Test-WirklichtNetwork)) { throw "Es besteht keine Internetverbindung. Bitte Verbindung herstellen und erneut starten." }
        Write-WirklichtStep "Internetverbindung" "OK" Green
        $archive = $null
        if (-not $SkipProjectDownload) {
            Write-Host "WIRKLICHT wird heruntergeladen ..."
            $archive = Download-WirklichtArchive -Url $SourceUrl
            if (Test-Path -LiteralPath $script:WirklichtRoot) { [void](Backup-WirklichtLocalState) }
            Sync-WirklichtProject -SourceRoot $archive.Root -DestinationRoot $script:WirklichtRoot | Out-Null
            Remove-Item -LiteralPath $archive.TemporaryDirectory -Recurse -Force -ErrorAction SilentlyContinue
            Write-WirklichtStep "Projektdateien" "OK" Green
        }
        $python = Ensure-WirklichtPython
        Write-WirklichtStep "Python 3.11" "OK" Green
        $venv = Ensure-WirklichtPythonEnvironment -PythonInfo $python
        Write-WirklichtStep "Python-Pakete" "OK" Green
        Ensure-WirklichtModel -VenvPython $venv | Out-Null
        Write-WirklichtStep "Pose-Modell" "OK" Green
        Ensure-WirklichtGodot | Out-Null
        Write-WirklichtStep "Godot" "OK" Green
        Select-WirklichtCamera -VenvPython $venv -NonInteractive:$NonInteractive | Out-Null
        Write-WirklichtStep "Kamera" "gespeichert" Green
        New-WirklichtShortcut -Name "WIRKLICHT starten" -ScriptName "start.ps1" -Description "WIRKLICHT starten"
        New-WirklichtShortcut -Name "WIRKLICHT Hilfe & Diagnose" -ScriptName "diagnose.ps1" -Description "WIRKLICHT Hilfe und Diagnose"
        Write-WirklichtStep "Desktop-Verknuepfungen" "OK" Green
        Write-WirklichtLog -Path $log -Message "Installation erfolgreich. Version $(Get-WirklichtVersion)."
        Write-WirklichtHeader "INSTALLATION ERFOLGREICH"
        Write-Host "Danach genuegt ein Doppelklick auf: WIRKLICHT starten"
        return $true
    } catch {
        Write-WirklichtLog -Path $log -Message ("FEHLER: " + $_.Exception.Message)
        Write-WirklichtHeader "INSTALLATION NICHT ABGESCHLOSSEN"
        Write-Host $_.Exception.Message -ForegroundColor Red
        return $false
    }
}

function Invoke-WirklichtUpdate {
    param([string]$SourceUrl = $script:WirklichtRepoZipUrl)
    $log = Get-WirklichtLogPath "install.log"
    $backup = $null
    $programBackup = $null
    $archive = $null
    try {
        Write-WirklichtHeader "WIRKLICHT UPDATE"
        Test-WirklichtSystem | Out-Null
        if (-not (Test-WirklichtNetwork)) { throw "Update nicht moeglich: keine Internetverbindung." }
        $backup = Backup-WirklichtLocalState
        $programBackup = Join-Path $backup "program"
        Backup-WirklichtProgramFiles -DestinationRoot $programBackup
        $archive = Download-WirklichtArchive -Url $SourceUrl
        Sync-WirklichtProject -SourceRoot $archive.Root -DestinationRoot $script:WirklichtRoot | Out-Null
        Remove-Item -LiteralPath $archive.TemporaryDirectory -Recurse -Force -ErrorAction SilentlyContinue
        $python = Ensure-WirklichtPython
        $venv = Ensure-WirklichtPythonEnvironment -PythonInfo $python
        Ensure-WirklichtModel -VenvPython $venv | Out-Null
        Ensure-WirklichtGodot | Out-Null
        Write-WirklichtLog -Path $log -Message "Update erfolgreich. Backup: $backup"
        Write-WirklichtHeader "UPDATE ERFOLGREICH"
        Write-Host "Lokale Config wurde beibehalten. Backup: $backup"
        return $true
    } catch {
        if ($null -ne $programBackup -and (Test-Path -LiteralPath $programBackup)) {
            Restore-WirklichtProgramFiles -SourceRoot $programBackup
        }
        Write-WirklichtLog -Path $log -Message ("UPDATE FEHLER: " + $_.Exception.Message)
        Write-WirklichtHeader "UPDATE NICHT ABGESCHLOSSEN"
        Write-Host "Die vorherige Konfiguration wurde beibehalten. Fehler: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    } finally {
        if ($null -ne $archive -and (Test-Path -LiteralPath $archive.TemporaryDirectory)) { Remove-Item -LiteralPath $archive.TemporaryDirectory -Recurse -Force -ErrorAction SilentlyContinue }
    }
}
