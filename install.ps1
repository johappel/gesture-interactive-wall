param(
    [string]$InstallPath = "C:\WIRKLICHT",
    [string]$SourceUrl = "https://github.com/johappel/gesture-interactive-wall/archive/refs/heads/main.zip",
    [switch]$SkipProjectDownload,
    [switch]$NonInteractive
)

$ErrorActionPreference = "Stop"

# This small bootstrap is deliberately self-contained: it also works when this
# file is streamed directly from raw.githubusercontent.com.
$localCommon = $null
if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
    $localCommon = Join-Path $PSScriptRoot "lib\common.ps1"
}
if ($null -eq $localCommon -or -not (Test-Path -LiteralPath $localCommon)) {
    try {
        if ($env:OS -ne "Windows_NT") { throw "WIRKLICHT benoetigt Windows." }
        $temporary = Join-Path ([IO.Path]::GetTempPath()) ("wirklicht-bootstrap-" + [guid]::NewGuid().ToString("N"))
        New-Item -ItemType Directory -Force -Path $temporary | Out-Null
        $zip = Join-Path $temporary "wirklicht.zip"
        Invoke-WebRequest -Uri $SourceUrl -OutFile $zip -UseBasicParsing
        Expand-Archive -LiteralPath $zip -DestinationPath $temporary -Force
        $source = Get-ChildItem -LiteralPath $temporary -Directory | Select-Object -First 1
        if ($null -eq $source) { throw "Das WIRKLICHT-Archiv konnte nicht entpackt werden." }
        $destination = $InstallPath
        $hadConfig = Test-Path -LiteralPath (Join-Path $destination "config\config.json")
        $backup = $null
        if ($hadConfig) {
            $backup = Join-Path $destination ("backup\bootstrap-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
            New-Item -ItemType Directory -Force -Path $backup | Out-Null
            Copy-Item -LiteralPath (Join-Path $destination "config\config.json") -Destination $backup -Force
            if (Test-Path -LiteralPath (Join-Path $destination "config\local.json")) { Copy-Item -LiteralPath (Join-Path $destination "config\local.json") -Destination $backup -Force }
        }
        New-Item -ItemType Directory -Force -Path $destination | Out-Null
        Get-ChildItem -LiteralPath $source.FullName -Force -Recurse | ForEach-Object {
            $relative = $_.FullName.Substring($source.FullName.Length).TrimStart('\')
            if ($relative -in @("config\config.json", "config\local.json")) { return }
            if ($relative -match "^(\.git|\.venv|models|logs|backup|tools)(\\|$)") { return }
            $target = Join-Path $destination $relative
            if ($_.PSIsContainer) { New-Item -ItemType Directory -Force -Path $target | Out-Null }
            else { New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null; Copy-Item -LiteralPath $_.FullName -Destination $target -Force }
        }
        if (-not $hadConfig) { Copy-Item -LiteralPath (Join-Path $source.FullName "config\config.json") -Destination (Join-Path $destination "config\config.json") -Force }
        Remove-Item -LiteralPath $temporary -Recurse -Force -ErrorAction SilentlyContinue
        $localCommon = Join-Path $destination "lib\common.ps1"
        if (-not (Test-Path -LiteralPath $localCommon)) { throw "Die WIRKLICHT-Dateien konnten nicht installiert werden." }
        # The archive is already in place; continue with dependency setup below.
        $SkipProjectDownload = $true
    } catch {
        Write-Host "WIRKLICHT konnte noch nicht installiert werden." -ForegroundColor Red
        Write-Host ("Grund: " + $_.Exception.Message) -ForegroundColor Red
        exit 1
    }
}

. $localCommon
Set-WirklichtRoot -Path $InstallPath
if (-not (Invoke-WirklichtInstallation -SkipProjectDownload:$SkipProjectDownload -SourceUrl $SourceUrl -NonInteractive:$NonInteractive)) { exit 1 }
