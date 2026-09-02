# Shared, operator-facing helpers for the WIRKLICHT Windows scripts.
# The script intentionally uses only Windows PowerShell 5.1 features.

$script:WirklichtRoot = Split-Path -Parent $PSScriptRoot
$script:WirklichtRepoZipUrl = "https://github.com/johappel/gesture-interactive-wall/archive/refs/heads/main.zip"
$script:WirklichtGodotVersion = "4.7.1-stable"
$script:WirklichtGodotUrl = "https://github.com/godotengine/godot/releases/download/4.7.1-stable/Godot_v4.7.1-stable_win64.exe.zip"
$script:WirklichtPythonVersion = "3.11.9"
$script:WirklichtPythonInstallerUrl = "https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe"
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
    $json = $Value | ConvertTo-Json -Depth 20
    $utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)
    [IO.File]::WriteAllText($temporary, $json, $utf8WithoutBom)
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
    $launcher = Get-Command py -ErrorAction SilentlyContinue
    if ($null -ne $launcher -and $launcher.Source -notlike "*WindowsApps*") {
        try {
            $launcherPython = (& $launcher.Source -3.11 -c "import sys; print(sys.executable)" 2>$null | Out-String).Trim()
            if ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $launcherPython)) {
                [void]$paths.Add($launcherPython)
            }
        } catch { }
    }
    $pythonCommand = Get-Command python -ErrorAction SilentlyContinue
    if ($null -ne $pythonCommand -and $pythonCommand.Source -notlike "*WindowsApps*") {
        [void]$paths.Add($pythonCommand.Source)
    }
    foreach ($registryPath in @(
        "HKCU:\Software\Python\PythonCore\3.11\InstallPath",
        "HKLM:\Software\Python\PythonCore\3.11\InstallPath"
    )) {
        try {
            $installPath = (Get-ItemProperty -LiteralPath $registryPath -ErrorAction Stop).ExecutablePath
            if ($installPath -and (Test-Path -LiteralPath $installPath)) {
                [void]$paths.Add($installPath)
            }
        } catch { }
    }
    foreach ($path in @(
        (Join-Path $env:LOCALAPPDATA "Programs\Python\Python311\python.exe"),
        "C:\Program Files\Python311\python.exe",
        "C:\Python311\python.exe"
    )) {
        if (Test-Path -LiteralPath $path) {
            [void]$paths.Add($path)
        }
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

function Test-WirklichtWinget {
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($null -eq $winget) { return $false }
    try {
        & $winget.Source --version 2>$null | Out-Null
        return ($LASTEXITCODE -eq 0)
    } catch { return $false }
}

function Ensure-WirklichtPython {
    $info = Get-WirklichtPythonInfo
    if ($null -ne $info -and $info.Major -eq 3 -and $info.Minor -eq 11) {
        return $info
    }

    $winget = Get-Command winget -ErrorAction SilentlyContinue
    $wingetWorked = $false
    if ($null -ne $winget) {
        if (Test-WirklichtWinget) {
            Write-Host "Python 3.11 wird ueber winget installiert. Ein Windows-Dialog kann erscheinen ..."
            $previousErrorActionPreference = $ErrorActionPreference
            try {
                $ErrorActionPreference = "Continue"
                & $winget.Source install --id Python.Python.3.11 --exact --scope user --accept-source-agreements --accept-package-agreements --disable-interactivity
                $wingetWorked = ($LASTEXITCODE -eq 0)
            } finally {
                $ErrorActionPreference = $previousErrorActionPreference
            }
        }
    }
    if (-not $wingetWorked) {
        Write-Host "winget ist nicht nutzbar. Der offizielle Python-Installer wird verwendet ..."
        $temporaryInstaller = Join-Path ([IO.Path]::GetTempPath()) ("python-" + $script:WirklichtPythonVersion + "-amd64.exe")
        try {
            Invoke-WirklichtDownload -Uri $script:WirklichtPythonInstallerUrl -OutFile $temporaryInstaller
            $process = Start-Process -FilePath $temporaryInstaller -ArgumentList @(
                "/quiet", "InstallAllUsers=0", "PrependPath=0", "Include_launcher=1",
                "Include_test=0", "SimpleInstall=1", "Shortcuts=0"
            ) -Wait -PassThru
            if ($process.ExitCode -ne 0) {
                throw ("Der offizielle Python-Installer meldet Fehlercode {0}." -f $process.ExitCode)
            }
        } finally {
            Remove-Item -LiteralPath $temporaryInstaller -Force -ErrorAction SilentlyContinue
        }
    }
    $info = Get-WirklichtPythonInfo
    if ($null -eq $info -or $info.Major -ne 3 -or $info.Minor -ne 11) {
        throw "Python 3.11 wurde installiert, konnte aber nicht gestartet werden. Bitte WIRKLICHT Hilfe & Diagnose oeffnen."
    }
    return $info
}

function Get-WirklichtVenvPython {
    return (Join-Path $script:WirklichtRoot ".venv\Scripts\python.exe")
}

function Invoke-WirklichtPython {
    param([string]$PythonPath, [string[]]$Arguments)
    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        $output = @(& $PythonPath @Arguments 2>&1)
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    foreach ($line in $output) { Write-Host ([string]$line) }
    if ($exitCode -ne 0) {
        $details = ($output | Select-Object -Last 8 | ForEach-Object { [string]$_ }) -join " | "
        throw ("Ein Python-Schritt ist fehlgeschlagen (Exit-Code {0}). {1}" -f $exitCode, $details)
    }
}

function Test-WirklichtPythonDependencies {
    param([string]$PythonPath)
    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        $check = "import cv2,cv2_enumerate_cameras,mediapipe,numpy,importlib.metadata as m,sys; p={d.metadata['Name'].lower().replace('_','-'):d.version for d in m.distributions()}; sys.exit(0 if p.get('opencv-contrib-python')=='4.11.0.86' and p.get('cv2-enumerate-cameras')=='1.3.3' and p.get('mediapipe')=='0.10.21' and p.get('numpy')=='1.26.4' and 'opencv-python' not in p else 1)"
        & $PythonPath "-c" $check 2>$null | Out-Null
        return ($LASTEXITCODE -eq 0)
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
}

function Get-WirklichtRequirementsHash {
    $requirements = Join-Path $script:WirklichtRoot "capture\requirements.txt"
    if (-not (Test-Path -LiteralPath $requirements)) { return "" }
    return (Get-FileHash -LiteralPath $requirements -Algorithm SHA256).Hash
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

    $requirementsHash = Get-WirklichtRequirementsHash
    $requirementsStamp = Join-Path $script:WirklichtRoot ".venv\.wirklicht-requirements.sha256"
    $installedHash = if (Test-Path -LiteralPath $requirementsStamp) { (Get-Content -LiteralPath $requirementsStamp -Raw).Trim() } else { "" }
    if (-not (Test-WirklichtPythonDependencies -PythonPath $venvPython) -or $installedHash -ne $requirementsHash) {
        Write-Host "Python-Pakete fehlen. Sie werden eingerichtet ..."
        Invoke-WirklichtPython -PythonPath $venvPython -Arguments @("-m", "pip", "uninstall", "-y", "opencv-python", "opencv-contrib-python")
        Invoke-WirklichtPython -PythonPath $venvPython -Arguments @("-m", "pip", "install", "-r", (Join-Path $script:WirklichtRoot "capture\requirements.txt"))
        Set-Content -LiteralPath $requirementsStamp -Value $requirementsHash -Encoding ASCII
    }
    return $venvPython
}

function Invoke-WirklichtDownload {
    param([string]$Uri, [string]$OutFile, [int]$Attempts = 3)
    for ($attempt = 1; $attempt -le $Attempts; $attempt++) {
        try {
            Remove-Item -LiteralPath $OutFile -Force -ErrorAction SilentlyContinue
            Invoke-WebRequest -Uri $Uri -OutFile $OutFile -UseBasicParsing
            if ((Test-Path -LiteralPath $OutFile) -and (Get-Item -LiteralPath $OutFile).Length -gt 0) { return }
        } catch {
            if ($attempt -lt $Attempts) {
                Write-Host ("Download unterbrochen. Neuer Versuch {0} von {1} ..." -f ($attempt + 1), $Attempts)
                Start-Sleep -Seconds 2
            }
        }
    }
    $curl = Get-Command curl.exe -ErrorAction SilentlyContinue
    if ($null -ne $curl) {
        $previousErrorActionPreference = $ErrorActionPreference
        try {
            $ErrorActionPreference = "Continue"
            & $curl.Source --fail --location --retry 3 --retry-delay 2 --output $OutFile $Uri
            if ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $OutFile) -and (Get-Item -LiteralPath $OutFile).Length -gt 0) { return }
        } finally {
            $ErrorActionPreference = $previousErrorActionPreference
        }
    }
    throw "Der Download konnte nach mehreren Versuchen nicht abgeschlossen werden. Bitte Internetverbindung pruefen und erneut starten."
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

function Test-WirklichtGodotExecutable {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    if ((Get-Item -LiteralPath $Path).Length -lt 10MB) { return $false }
    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        & $Path --version 2>$null | Out-Null
        return ($LASTEXITCODE -eq 0)
    } catch { return $false }
    finally { $ErrorActionPreference = $previousErrorActionPreference }
}

function Ensure-WirklichtGodot {
    $godotPath = Get-WirklichtGodotPath
    if (-not (Test-WirklichtGodotExecutable -Path $godotPath)) {
        Write-Host "Godot wird bereitgestellt (portable Version, kein Projektmanager erforderlich) ..."
        $godotPath = Join-Path $script:WirklichtRoot ("tools\Godot_v{0}_win64.exe" -f $script:WirklichtGodotVersion)
        $toolsDirectory = Split-Path -Parent $godotPath
        $archivePath = Join-Path $toolsDirectory "godot-download.zip"
        New-Item -ItemType Directory -Force -Path $toolsDirectory | Out-Null
        Remove-Item -LiteralPath $godotPath -Force -ErrorAction SilentlyContinue
        try {
            Invoke-WirklichtDownload -Uri $script:WirklichtGodotUrl -OutFile $archivePath
            Expand-Archive -LiteralPath $archivePath -DestinationPath $toolsDirectory -Force
        } finally {
            Remove-Item -LiteralPath $archivePath -Force -ErrorAction SilentlyContinue
        }
    }
    if (-not (Test-WirklichtGodotExecutable -Path $godotPath)) { throw "Godot konnte nicht vollstaendig bereitgestellt oder gestartet werden." }
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
    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        $raw = (& $VenvPython "-c" $code 2>$null | Out-String).Trim()
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($raw)) { return @() }
        return @(($raw | ConvertFrom-Json))
    } catch { return @() }
    finally { $ErrorActionPreference = $previousErrorActionPreference }
}

function Test-WirklichtCameraSelection {
    param([string]$VenvPython, [int]$Index, [string]$Backend = "any")
    $code = "from capture.camera import camera_works; raise SystemExit(0 if camera_works($Index, '$Backend') else 1)"
    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        & $VenvPython "-c" $code 2>$null | Out-Null
        return ($LASTEXITCODE -eq 0)
    } catch { return $false }
    finally { $ErrorActionPreference = $previousErrorActionPreference }
}

function Save-WirklichtCameraSelection {
    param([object]$Camera)
    $configPath = Join-Path $script:WirklichtRoot "config\config.json"
    $config = Read-WirklichtJson $configPath
    $values = @{
        index = [int]$Camera.index
        backend = [string]$Camera.backend
        name = [string]$Camera.name
        device_path = [string]$Camera.path
        vid = [string]$Camera.vid
        pid = [string]$Camera.pid
    }
    foreach ($key in $values.Keys) {
        $property = $config.camera.PSObject.Properties[$key]
        if ($null -eq $property) {
            $config.camera | Add-Member -MemberType NoteProperty -Name $key -Value $values[$key]
        } else {
            $property.Value = $values[$key]
        }
    }
    Write-WirklichtJson -Path $configPath -Value $config
}

function Select-WirklichtCamera {
    param([string]$VenvPython, [switch]$NonInteractive, [switch]$NoPrompt)
    $configPath = Join-Path $script:WirklichtRoot "config\config.json"
    $config = Read-WirklichtJson $configPath
    $backend = if ($config.camera.backend) { [string]$config.camera.backend } else { "any" }
    $cameras = @(Get-WirklichtAvailableCameras -VenvPython $VenvPython -Backend $backend)
    if ($cameras.Count -eq 0) { throw "Keine Kamera gefunden. Bitte USB-Kamera anschliessen und Zoom, Teams oder OBS schliessen." }

    $selected = $null
    if ($config.camera.device_path) {
        $selected = $cameras | Where-Object { [string]$_.path -eq [string]$config.camera.device_path } | Select-Object -First 1
    }
    if ($null -eq $selected -and $config.camera.vid -and $config.camera.pid) {
        $selected = $cameras | Where-Object {
            [string]$_.vid -eq [string]$config.camera.vid -and [string]$_.pid -eq [string]$config.camera.pid
        } | Select-Object -First 1
    }
    if ($null -eq $selected -and $config.camera.name) {
        $selected = $cameras | Where-Object { [string]$_.name -eq [string]$config.camera.name } | Select-Object -First 1
    }
    if ($null -eq $selected) {
        $configured = [int]$config.camera.index
        $selected = $cameras | Where-Object {
            [int]$_.index -eq $configured -and [string]$_.backend -eq $backend
        } | Select-Object -First 1
    }
    if ($null -ne $selected -and (Test-WirklichtCameraSelection -VenvPython $VenvPython -Index ([int]$selected.index) -Backend ([string]$selected.backend))) {
        Save-WirklichtCameraSelection -Camera $selected
        return [string]$selected.name
    }

    if ($NoPrompt) {
        throw "Die gespeicherte Kamera ist nicht verfügbar oder liefert kein Bild."
    }

    Write-Host "Die bisher verwendete Kamera wurde nicht gefunden."
    Write-Host "Gefundene Kameras:"
    for ($position = 0; $position -lt $cameras.Count; $position++) {
        $camera = $cameras[$position]
        $kind = if ([bool]$camera.physical) { "USB $($camera.vid):$($camera.pid)" } else { "virtuell/unklar" }
        Write-Host ("  [{0}] {1} ({2}, {3})" -f ($position + 1), $camera.name, $camera.source_backend, $kind)
    }
    if ($cameras.Count -eq 1 -or $NonInteractive) {
        $selected = $cameras | Where-Object { [bool]$_.physical } | Select-Object -First 1
        if ($null -eq $selected) { $selected = $cameras[0] }
        Write-Host ("{0} wird verwendet." -f $selected.name)
    } else {
        do {
            $answer = Read-Host "Nummer"
            $choice = 0
            $validNumber = [int]::TryParse($answer, [ref]$choice)
            if (-not $validNumber -or $choice -lt 1 -or $choice -gt $cameras.Count) {
                Write-Host "Bitte eine Nummer aus der Liste eingeben." -ForegroundColor Yellow
            }
        } while (-not $validNumber -or $choice -lt 1 -or $choice -gt $cameras.Count)
        $selected = $cameras[$choice - 1]
    }
    if (-not (Test-WirklichtCameraSelection -VenvPython $VenvPython -Index ([int]$selected.index) -Backend ([string]$selected.backend))) {
        throw ("{0} wurde erkannt, liefert WIRKLICHT aber kein Bild. Bitte Zoom, Teams, Discord und OBS schliessen und erneut starten." -f $selected.name)
    }
    Save-WirklichtCameraSelection -Camera $selected
    return [string]$selected.name
}

function Get-WirklichtShortcutDirectories {
    $directories = New-Object System.Collections.Generic.List[string]
    $desktop = [Environment]::GetFolderPath("Desktop")
    if (-not [string]::IsNullOrWhiteSpace($desktop)) { [void]$directories.Add($desktop) }
    if (-not [string]::IsNullOrWhiteSpace($env:OneDrive)) {
        $oneDriveDesktop = Join-Path $env:OneDrive "Desktop"
        if ((Test-Path -LiteralPath $oneDriveDesktop) -and $oneDriveDesktop -ne $desktop) {
            [void]$directories.Add($oneDriveDesktop)
        }
    }
    $programs = [Environment]::GetFolderPath("Programs")
    if (-not [string]::IsNullOrWhiteSpace($programs)) {
        [void]$directories.Add((Join-Path $programs "WIRKLICHT"))
    }
    return @($directories | Select-Object -Unique)
}

function New-WirklichtShortcut {
    param([string]$Name, [string]$ScriptName, [string]$Description)
    foreach ($directory in Get-WirklichtShortcutDirectories) {
        New-Item -ItemType Directory -Force -Path $directory | Out-Null
        $shortcutPath = Join-Path $directory ("{0}.lnk" -f $Name)
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = (Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe")
        $shortcut.Arguments = '-NoProfile -ExecutionPolicy Bypass -File "{0}"' -f (Join-Path $script:WirklichtRoot $ScriptName)
        $shortcut.WorkingDirectory = $script:WirklichtRoot
        $shortcut.Description = $Description
        $shortcut.Save()
        Write-Output $shortcutPath
    }
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
        $wingetState = if (Test-WirklichtWinget) { "nutzbar" } else { "nicht nutzbar (Fallback aktiv)" }
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
        try {
            Select-WirklichtCamera -VenvPython $venv -NonInteractive:$NonInteractive | Out-Null
            Write-WirklichtStep "Kamera" "gespeichert" Green
        } catch {
            Write-WirklichtStep "Kamera" "noch nicht gefunden" Yellow
            Write-Host "Die Installation wird trotzdem abgeschlossen. Kamera anschliessen; beim ersten Start wird sie erneut gesucht."
            Write-WirklichtLog -Path $log -Message ("Kamera noch nicht eingerichtet: " + $_.Exception.Message)
        }
        New-WirklichtShortcut -Name "WIRKLICHT starten" -ScriptName "start.ps1" -Description "WIRKLICHT starten" | Out-Null
        New-WirklichtShortcut -Name "WIRKLICHT Kamera waehlen" -ScriptName "camera-select.ps1" -Description "WIRKLICHT Kamera auswaehlen und testen" | Out-Null
        New-WirklichtShortcut -Name "WIRKLICHT Hilfe & Diagnose" -ScriptName "diagnose.ps1" -Description "WIRKLICHT Hilfe und Diagnose" | Out-Null
        Write-WirklichtStep "Desktop-Verknuepfungen" "OK" Green
        Write-Host ("Start-Verknuepfungen: " + ((Get-WirklichtShortcutDirectories) -join ", "))
        Write-Host ("Direkter Doppelklick: " + (Join-Path $script:WirklichtRoot "WIRKLICHT starten.cmd"))
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
