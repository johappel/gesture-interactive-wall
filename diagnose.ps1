param([string]$OutputPath = "")

$ErrorActionPreference = "SilentlyContinue"
. (Join-Path $PSScriptRoot "lib\common.ps1")
$log = Get-WirklichtLogPath "diagnose.log"
if ([string]::IsNullOrWhiteSpace($OutputPath)) { $OutputPath = Join-Path ([Environment]::GetFolderPath("Desktop")) "WIRKLICHT-DIAGNOSE.txt" }
$configPath = Join-Path $script:WirklichtRoot "config\config.json"
$config = $null
try { $config = Read-WirklichtJson $configPath } catch { }
$python = Get-WirklichtPythonInfo
$venv = Get-WirklichtVenvPython
$godot = Get-WirklichtGodotPath
$cameras = @()
if (Test-Path -LiteralPath $venv) {
    $backend = if ($null -ne $config -and $config.camera.backend) { [string]$config.camera.backend } else { "any" }
    $cameras = @(Get-WirklichtAvailableCameras -VenvPython $venv -Backend $backend)
}
$cameraIndex = if ($null -ne $config) { $config.camera.index } else { "unbekannt" }
$cameraBackend = if ($null -ne $config -and $config.camera.backend) { [string]$config.camera.backend } else { "any" }
$cameraOpen = if ($null -ne $config -and (Test-Path -LiteralPath $venv)) {
    Test-WirklichtCameraSelection -VenvPython $venv -Index ([int]$cameraIndex) -Backend $cameraBackend
} else { $false }
$os = Get-CimInstance Win32_OperatingSystem
$computer = Get-CimInstance Win32_ComputerSystem
$cpu = (Get-CimInstance Win32_Processor | Select-Object -First 1).Name
$gpu = (Get-CimInstance Win32_VideoController | Select-Object -First 1).Name
$godotVersion = if (Test-Path -LiteralPath $godot) { (& $godot --version 2>&1 | Out-String).Trim() } else { "nicht gefunden" }
$relevantPackages = if (Test-Path -LiteralPath $venv) { (& $venv -m pip list 2>&1 | Select-String "opencv|cv2[-_]enumerate|mediapipe|numpy" | Out-String).Trim() } else { "nicht vorhanden" }
$configSummary = if ($null -ne $config) { ($config | ConvertTo-Json -Depth 10) } else { "CONFIG NICHT LESBAR" }
$lastErrors = @()
foreach ($logName in @("start.log", "capture-error.log", "renderer.log")) {
    $candidateLog = Get-WirklichtLogPath $logName
    if (Test-Path -LiteralPath $candidateLog) {
        $lastErrors += @(Get-Content -LiteralPath $candidateLog -Tail 100 | Select-String "ERROR|FEHLER|Exception|Traceback")
    }
}
if ($lastErrors.Count -eq 0) { $lastErrors = @("keine passenden Fehler in den lokalen Logs") }
$lines = @(
    "WIRKLICHT-DIAGNOSE",
    "===================",
    "Datum / Uhrzeit: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')",
    "WIRKLICHT-Version: $(Get-WirklichtVersion)",
    "Windows: $($os.Caption) $($os.Version) (64 Bit: $([Environment]::Is64BitOperatingSystem))",
    "CPU: $cpu",
    "GPU: $gpu",
    "RAM: $([math]::Round($computer.TotalPhysicalMemory / 1GB, 1)) GB",
    "Python-Version: $(if ($null -ne $python) { $python.Version } else { 'nicht gefunden' })",
    "Python-Pfad: $(if ($null -ne $python) { $python.Path } else { 'nicht gefunden' })",
    "Virtualenv vorhanden: $(Test-Path -LiteralPath $venv)",
    "Relevante Python-Pakete:", $relevantPackages,
    "Godot-Pfad: $godot",
    "Godot-Version: $godotVersion",
    "Pose-Modell vorhanden: $(Test-Path -LiteralPath (Get-WirklichtModelPath))",
    "Erkannte Kameras: $(if ($cameras.Count -eq 0) { 'keine' } else { ($cameras | ForEach-Object { "[$($_.index)] $($_.name) ($($_.source_backend), VID:PID $($_.vid):$($_.pid))" }) -join ', ' })",
    "Konfigurierte Kamera: $(if ($null -ne $config -and $config.camera.name) { $config.camera.name } else { 'unbekannt' })",
    "Konfigurierter Kameraindex: $cameraIndex",
    "Konfigurierte Kamera oeffnbar: $cameraOpen",
    "Godot-Projekt vorhanden: $(Test-Path -LiteralPath (Join-Path $script:WirklichtRoot 'renderer\project.godot'))",
    "",
    "Wichtige Config-Werte:", $configSummary,
    "",
    "Letzte relevante Startfehler:", $lastErrors,
    "",
    "Datenschutz: Diese Diagnose enthaelt keine Kamerabilder, Videos oder Personenlisten."
)
$lines | Set-Content -LiteralPath $OutputPath -Encoding UTF8
Write-WirklichtLog -Path $log -Message "Diagnose geschrieben: $OutputPath"
Write-WirklichtHeader "DIAGNOSE ERSTELLT"
Write-Host $OutputPath
Write-Host "Bitte diese Datei an Joachim schicken."
