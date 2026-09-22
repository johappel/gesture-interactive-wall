param(
    [string]$Scenario = "",
    [switch]$NonInteractive
)

# WIRKLICHT simulation launcher.
#
# Starts the renderer and then feeds it synthetic, camera-free data. This is the
# acceptance and demo path: crowd_aura, stillness resonance and aftereffect
# waves can be judged without a real camera, audience or evening light.
#
# Only local numbers are sent (127.0.0.1). No camera image is read or stored.

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\common.ps1")
$log = Get-WirklichtLogPath "simulate.log"
$renderer = $null
$simulator = $null
$failureArea = "Start"

function Stop-WirklichtSimulation {
    if ($null -ne $simulator -and -not $simulator.HasExited) { Stop-Process -Id $simulator.Id -Force -ErrorAction SilentlyContinue }
    if ($null -ne $renderer -and -not $renderer.HasExited) { Stop-Process -Id $renderer.Id -Force -ErrorAction SilentlyContinue }
}

function Get-WirklichtSimScenarios {
    param([string]$VenvPython)
    $fallback = @("phase44")
    if (-not (Test-Path -LiteralPath $VenvPython)) { return $fallback }
    $previousErrorActionPreference = $ErrorActionPreference
    # capture/ is a package, so the import only resolves from the repo root.
    Push-Location $script:WirklichtRoot
    try {
        $ErrorActionPreference = "Continue"
        # chr(10) avoids any backslash-escaping ambiguity between PowerShell and
        # Python; the list itself stays defined only in capture/sim.py.
        $output = @(& $VenvPython "-c" "from capture.sim import LIFECYCLE_SCENARIOS; print(chr(10).join(LIFECYCLE_SCENARIOS))" 2>$null)
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
        Pop-Location
    }
    $scenarios = @($output | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { ([string]$_).Trim() })
    if ($scenarios.Count -eq 0) { return $fallback }
    return @("phase44") + $scenarios
}

try {
    Write-WirklichtHeader "WIRKLICHT SIMULATION"
    if (-not (Test-Path -LiteralPath (Join-Path $script:WirklichtRoot "renderer\project.godot"))) { throw "Das WIRKLICHT-Projekt fehlt. Bitte WIRKLICHT aktualisieren." }
    if (-not (Test-Path -LiteralPath (Join-Path $script:WirklichtRoot "config\config.json"))) { throw "Die Config fehlt. Bitte WIRKLICHT aktualisieren." }
    Write-Host "Ohne Kamera. Es werden nur synthetische, lokale Zahlen gesendet." -ForegroundColor Gray
    Write-Host ""

    $failureArea = "Python"
    $python = Ensure-WirklichtPython
    $venv = Ensure-WirklichtPythonEnvironment -PythonInfo $python
    Write-WirklichtStep "Python-Umgebung" "OK" Green
    $godot = Ensure-WirklichtGodot
    Write-WirklichtStep "Godot" "OK" Green

    $failureArea = "Szenario"
    $scenarios = Get-WirklichtSimScenarios -VenvPython $venv
    if ([string]::IsNullOrWhiteSpace($Scenario)) {
        if ($NonInteractive) {
            $Scenario = "phase44"
        } else {
            Write-Host "Verfuegbare Szenarien:" -ForegroundColor Cyan
            for ($position = 0; $position -lt $scenarios.Count; $position++) {
                Write-Host ("  [{0}] {1}" -f ($position + 1), $scenarios[$position])
            }
            Write-Host ""
            Write-Host "Empfehlung fuer die Gruppenabnahme: crowd_aura" -ForegroundColor Gray
            $answer = Read-Host ("Nummer oder Name (ENTER = {0})" -f $scenarios[0])
            if ([string]::IsNullOrWhiteSpace($answer)) {
                $Scenario = $scenarios[0]
            } elseif ($scenarios -contains $answer.Trim()) {
                $Scenario = $answer.Trim()
            } else {
                $choice = 0
                if ([int]::TryParse($answer, [ref]$choice) -and $choice -ge 1 -and $choice -le $scenarios.Count) {
                    $Scenario = $scenarios[$choice - 1]
                } else {
                    throw ("Unbekanntes Szenario '{0}'. Bitte eines aus der Liste waehlen." -f $answer)
                }
            }
        }
    }
    if ($scenarios -notcontains $Scenario) {
        throw ("Unbekanntes Szenario '{0}'. Verfuegbar: {1}" -f $Scenario, ($scenarios -join ", "))
    }
    Write-WirklichtStep ("Szenario {0}" -f $Scenario) "OK" Green

    $failureArea = "Bildschirm"
    try {
        $facadeScreen = Select-WirklichtFacadeScreen -NonInteractive:$NonInteractive -NoPrompt
    } catch {
        if ($NonInteractive) { throw }
        Write-Host "Die Fassaden-Ausgabe wird ausgewaehlt ..." -ForegroundColor Yellow
        $picker = Start-Process -FilePath (Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe") -ArgumentList @(
            "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", ('"{0}"' -f (Join-Path $script:WirklichtRoot "monitor-select.ps1")), "-Target", "facade"
        ) -Wait -PassThru
        if ($picker.ExitCode -ne 0) { throw "Es wurde kein Bildschirm fuer die Fassade ausgewaehlt." }
        $facadeScreen = Select-WirklichtFacadeScreen -NoPrompt
    }
    Write-WirklichtStep ("Fassade Bildschirm {0}" -f $facadeScreen.index) "OK" Green
    Write-WirklichtLog -Path $log -Message ("Fassade Bildschirm {0}: Position {1},{2}; Groesse {3}x{4}." -f $facadeScreen.index, $facadeScreen.x, $facadeScreen.y, $facadeScreen.width, $facadeScreen.height)

    $failureArea = "Renderer"
    $rendererLog = Get-WirklichtLogPath "renderer.log"
    Write-Host "Renderer wird gestartet ..."
    $rendererPath = Join-Path $script:WirklichtRoot "renderer"
    $renderer = Start-Process -FilePath $godot -WorkingDirectory $script:WirklichtRoot -ArgumentList @(
        "--path", ('"{0}"' -f $rendererPath),
        "--rendering-method", "gl_compatibility",
        "--rendering-driver", "opengl3",
        "--log-file", ('"{0}"' -f $rendererLog)
    ) -PassThru
    Start-Sleep -Seconds 3
    if ($renderer.HasExited) { throw "Der Renderer konnte nicht gestartet werden. Bitte WIRKLICHT Hilfe & Diagnose oeffnen." }
    Write-WirklichtStep "Renderer" "OK" Green

    $failureArea = "Simulator"
    $simLog = Get-WirklichtLogPath "simulator.log"
    $simErrorLog = Get-WirklichtLogPath "simulator-error.log"
    Write-Host ("Simulator sendet jetzt Szenario '{0}' ..." -f $Scenario)
    $simulator = Start-Process -FilePath $venv -WorkingDirectory $script:WirklichtRoot -ArgumentList @(
        "-m", "capture.tracker", "--sim", "--sim-scenario", $Scenario
    ) -RedirectStandardOutput $simLog -RedirectStandardError $simErrorLog -WindowStyle Hidden -PassThru
    Start-Sleep -Seconds 2
    if ($simulator.HasExited) { throw "Der Simulator konnte nicht gestartet werden. Bitte logs\simulator-error.log pruefen." }
    Write-WirklichtStep "Simulator" "OK" Green

    Write-WirklichtLog -Path $log -Message ("Simulation bereit, Szenario {0}, Version {1}." -f $Scenario, (Get-WirklichtVersion))
    Write-WirklichtHeader "SIMULATION LAEUFT"
    Write-Host "Dieses Fenster offen lassen. Zum Beenden Fenster schliessen oder Strg+C druecken." -ForegroundColor Gray
    Write-Host ("Szenario: {0}" -f $Scenario) -ForegroundColor Gray
    Write-Host ""
    while (-not $renderer.HasExited -and -not $simulator.HasExited) { Start-Sleep -Seconds 1 }
    if ($renderer.HasExited -and -not $simulator.HasExited) { throw "Der Renderer wurde beendet." }
    if ($simulator.HasExited -and -not $renderer.HasExited) { throw "Der Simulator wurde beendet." }
} catch {
    Stop-WirklichtSimulation
    Write-WirklichtLog -Path $log -Message ("FEHLER: " + $_.Exception.Message)
    Write-WirklichtHeader "SIMULATION KANN NICHT STARTEN"
    Write-Host $_.Exception.Message -ForegroundColor Red
    if ($failureArea -eq "Bildschirm") {
        Write-Host "Bitte auf dem Desktop WIRKLICHT Bildschirm waehlen oeffnen." -ForegroundColor Yellow
    } elseif ($failureArea -eq "Renderer") {
        Write-Host "Bitte WIRKLICHT Hilfe & Diagnose oeffnen." -ForegroundColor Yellow
    } else {
        Write-Host "Bitte WIRKLICHT Hilfe & Diagnose oeffnen." -ForegroundColor Yellow
    }
    if (-not $NonInteractive) { Read-Host "ENTER zum Beenden" | Out-Null }
    exit 1
} finally {
    Stop-WirklichtSimulation
}
