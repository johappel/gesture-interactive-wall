param([switch]$NonInteractive)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\common.ps1")
$log = Get-WirklichtLogPath "start.log"
$renderer = $null
$capture = $null

function Stop-WirklichtProcesses {
    if ($null -ne $capture -and -not $capture.HasExited) { Stop-Process -Id $capture.Id -Force -ErrorAction SilentlyContinue }
    if ($null -ne $renderer -and -not $renderer.HasExited) { Stop-Process -Id $renderer.Id -Force -ErrorAction SilentlyContinue }
}

try {
    Write-WirklichtHeader "WIRKLICHT START"
    if (-not (Test-Path -LiteralPath (Join-Path $script:WirklichtRoot "renderer\project.godot"))) { throw "Das WIRKLICHT-Projekt fehlt. Bitte WIRKLICHT aktualisieren." }
    if (-not (Test-Path -LiteralPath (Join-Path $script:WirklichtRoot "config\config.json"))) { throw "Die Config fehlt. Bitte WIRKLICHT aktualisieren." }
    Write-WirklichtStep "Installation pruefen" "OK" Green
    Test-WirklichtSystem | Out-Null
    $python = Ensure-WirklichtPython
    Write-WirklichtStep "Python" "OK" Green
    $venv = Ensure-WirklichtPythonEnvironment -PythonInfo $python
    Write-WirklichtStep "Python-Umgebung" "OK" Green
    Ensure-WirklichtModel -VenvPython $venv | Out-Null
    Write-WirklichtStep "Pose-Modell" "OK" Green
    $godot = Ensure-WirklichtGodot
    Write-WirklichtStep "Godot" "OK" Green
    $camera = Select-WirklichtCamera -VenvPython $venv -NonInteractive:$NonInteractive
    Write-WirklichtStep ("Kamera {0}" -f $camera) "OK" Green

    $rendererLog = Get-WirklichtLogPath "renderer.log"
    $captureLog = Get-WirklichtLogPath "capture.log"
    Write-Host "Renderer wird gestartet ..."
    $rendererPath = Join-Path $script:WirklichtRoot "renderer"
    $renderer = Start-Process -FilePath $godot -WorkingDirectory $script:WirklichtRoot -ArgumentList @("--path", ('"{0}"' -f $rendererPath), "--log-file", ('"{0}"' -f $rendererLog)) -PassThru
    Start-Sleep -Seconds 2
    if ($renderer.HasExited) { throw "Der Renderer konnte nicht gestartet werden. Bitte WIRKLICHT Hilfe & Diagnose oeffnen." }
    Write-WirklichtStep "Renderer" "OK" Green
    $captureErrorLog = Get-WirklichtLogPath "capture-error.log"
    $capture = Start-Process -FilePath $venv -WorkingDirectory $script:WirklichtRoot -ArgumentList @("-m", "capture.tracker") -RedirectStandardOutput $captureLog -RedirectStandardError $captureErrorLog -WindowStyle Hidden -PassThru
    Start-Sleep -Seconds 2
    if ($capture.HasExited) { throw "Die Personenerkennung konnte nicht gestartet werden. Bitte WIRKLICHT Hilfe & Diagnose oeffnen." }
    Write-WirklichtStep "Personenerkennung" "OK" Green
    Write-WirklichtLog -Path $log -Message ("Bereit, Version $(Get-WirklichtVersion), Kamera $camera.")
    Write-WirklichtHeader "WIRKLICHT IST BEREIT"
    Write-Host "Dieses Fenster offen lassen. Zum Beenden Fenster schliessen oder Strg+C druecken."
    while (-not $renderer.HasExited -and -not $capture.HasExited) { Start-Sleep -Seconds 1 }
    if ($renderer.HasExited -and -not $capture.HasExited) { throw "Der Renderer wurde beendet." }
    if ($capture.HasExited -and -not $renderer.HasExited) { throw "Die Personenerkennung wurde beendet." }
} catch {
    Stop-WirklichtProcesses
    Write-WirklichtLog -Path $log -Message ("FEHLER: " + $_.Exception.Message)
    Write-WirklichtHeader "WIRKLICHT KANN NICHT STARTEN"
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host "Bitte WIRKLICHT Hilfe & Diagnose oeffnen oder die USB-Kamera pruefen."
    if (-not $NonInteractive) { Read-Host "ENTER zum Beenden" | Out-Null }
    exit 1
} finally {
    Stop-WirklichtProcesses
}
