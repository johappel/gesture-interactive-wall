param([string]$SourceUrl = "https://github.com/johappel/gesture-interactive-wall/archive/refs/heads/main.zip")

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\common.ps1")
if (-not (Invoke-WirklichtUpdate -SourceUrl $SourceUrl)) { exit 1 }
Read-Host "ENTER zum Beenden" | Out-Null
