# WIRKLICHT — Installer bauen (Windows PowerShell 5.1).
#
# Erzeugt dist\WIRKLICHT-Setup-<Version>.exe aus installer\wirklicht.iss.
# Die Version kommt aus der Datei VERSION im Projektwurzelverzeichnis, damit
# Installer und Projekt nie auseinanderlaufen.
#
# Verwendung:
#   powershell -ExecutionPolicy Bypass -File installer\build.ps1
#
# Voraussetzung: Inno Setup 6. Fehlt es, wird der Installationsbefehl
# ausgegeben statt stillschweigend zu scheitern.

param(
    [string]$Version,
    [switch]$OpenOutputFolder
)

$ErrorActionPreference = "Stop"

$installerDir = $PSScriptRoot
$root = Split-Path -Parent $installerDir

function Find-InnoCompiler {
    $candidates = @(
        (Join-Path ${env:ProgramFiles(x86)} "Inno Setup 6\ISCC.exe"),
        (Join-Path $env:ProgramFiles "Inno Setup 6\ISCC.exe"),
        (Join-Path $env:LOCALAPPDATA "Programs\Inno Setup 6\ISCC.exe")
    )
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate)) { return $candidate }
    }
    $command = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    if ($null -ne $command) { return $command.Source }
    return $null
}

function Get-ProjectVersion {
    $versionFile = Join-Path $root "VERSION"
    if (Test-Path -LiteralPath $versionFile) {
        return (Get-Content -LiteralPath $versionFile -Raw).Trim()
    }
    return "0.0.0"
}

# Inno Setup erwartet eine numerische VersionInfoVersion der Form a.b.c.d.
# Die Projektversion kann kuerzer sein (z. B. "0.5.4"); fehlende Stellen
# werden mit 0 aufgefuellt, damit die Versionsinformationen gueltig bleiben.
function ConvertTo-FourPartVersion {
    param([string]$Value)
    $parts = @($Value -split '[.\-+]' | Where-Object { $_ -match '^\d+$' })
    if ($parts.Count -eq 0) { return "0.0.0.0" }
    while ($parts.Count -lt 4) { $parts += "0" }
    return ($parts[0..3] -join ".")
}

$compiler = Find-InnoCompiler
if ($null -eq $compiler) {
    Write-Host "Inno Setup 6 wurde nicht gefunden." -ForegroundColor Red
    Write-Host "Installation z. B. mit:" -ForegroundColor Yellow
    Write-Host "  winget install --id JRSoftware.InnoSetup --accept-package-agreements --accept-source-agreements"
    exit 1
}

if ([string]::IsNullOrWhiteSpace($Version)) { $Version = Get-ProjectVersion }
$fourPartVersion = ConvertTo-FourPartVersion -Value $Version

$script = Join-Path $installerDir "wirklicht.iss"
if (-not (Test-Path -LiteralPath $script)) {
    Write-Host "Installer-Skript nicht gefunden: $script" -ForegroundColor Red
    exit 1
}

$distDir = Join-Path $root "dist"
New-Item -ItemType Directory -Force -Path $distDir | Out-Null

Write-Host ("WIRKLICHT-Installer wird gebaut (Version {0}) ..." -f $Version)

# /DVersion uebergibt die Projektversion, /DVersionNumeric die vierteilige
# Form fuer die Windows-Versionsinformationen der setup.exe.
& $compiler "/DVersion=$Version" "/DVersionNumeric=$fourPartVersion" $script
if ($LASTEXITCODE -ne 0) {
    Write-Host "Der Installer konnte nicht gebaut werden." -ForegroundColor Red
    exit $LASTEXITCODE
}

$output = Join-Path $distDir ("WIRKLICHT-Setup-{0}.exe" -f $Version)
if (-not (Test-Path -LiteralPath $output)) {
    Write-Host "Es wurde keine setup.exe erzeugt. Bitte die ISCC-Ausgabe pruefen." -ForegroundColor Red
    exit 1
}

$size = [math]::Round((Get-Item -LiteralPath $output).Length / 1MB, 2)
Write-Host ("Fertig: {0} ({1} MB)" -f $output, $size) -ForegroundColor Green
Write-Host "Hinweis: Ohne Code-Signatur bleibt beim Start eine SmartScreen-Warnung (unbekannter Herausgeber)."

if ($OpenOutputFolder) { Invoke-Item -LiteralPath $distDir }
