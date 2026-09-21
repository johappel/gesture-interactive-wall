# WIRKLICHT — Release ausloesen.
#
# Setzt den Git-Tag aus der VERSION-Datei und pusht ihn. Damit kann der Tag
# nicht mehr von Hand falsch gesetzt werden: Tag und VERSION-Datei koennen
# nicht mehr auseinanderlaufen.
#
# Verwendung:
#   powershell -ExecutionPolicy Bypass -File release.ps1
#   powershell -ExecutionPolicy Bypass -File release.ps1 -Bump patch
#   powershell -ExecutionPolicy Bypass -File release.ps1 -Bump minor -Message "..."
#
# Der Tag-Push loest den Workflow aus, der den Installer baut und an das
# Release haengt.

param(
    [ValidateSet("none", "major", "minor", "patch")]
    [string]$Bump = "none",
    [string]$Message,
    [switch]$Yes
)

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot

function Get-VersionFromFile {
    $versionFile = Join-Path $root "VERSION"
    if (-not (Test-Path -LiteralPath $versionFile)) { throw "VERSION-Datei fehlt: $versionFile" }
    return (Get-Content -LiteralPath $versionFile -Raw).Trim()
}

function Add-VersionBump {
    param([string]$Version, [string]$Kind)
    if ($Kind -eq "none") { return $Version }
    $parts = @($Version -split '[.\-+]')
    if ($parts.Count -lt 3) { throw "VERSION '$Version' hat kein Format a.b.c und kann nicht erhoeht werden." }
    foreach ($part in $parts[0..2]) {
        if ($part -notmatch '^\d+$') { throw "VERSION '$Version' enthaelt kein Zahlenformat und kann nicht erhoeht werden." }
    }
    $major = [int]$parts[0]; $minor = [int]$parts[1]; $patch = [int]$parts[2]
    switch ($Kind) {
        "major" { $major += 1; $minor = 0; $patch = 0 }
        "minor" { $minor += 1; $patch = 0 }
        "patch" { $patch += 1 }
    }
    return "$major.$minor.$patch"
}

function Invoke-Git {
    param([string[]]$Arguments)
    # git schreibt Fortschritt (z.B. "To https://..." beim Push) nach stderr.
    # Mit $ErrorActionPreference = "Stop" wuerde PowerShell das als Fehler
    # werfen, obwohl der Befehl gelingt. Daher hier gezielt auf Continue
    # schalten und allein den Exit-Code als Wahrheit verwenden.
    $previous = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        $output = & git -C $root @Arguments 2>&1
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previous
    }
    if ($exitCode -ne 0) {
        # NativeCommandError-Objekte lesbar machen.
        $text = ($output | ForEach-Object { $_.ToString() }) -join "`n"
        throw ("git " + ($Arguments -join " ") + " fehlgeschlagen (Exit $exitCode):`n" + $text)
    }
    return $output
}

function Get-RemoteTagLine {
    # ls-remote gibt nichts aus (Exit 0), wenn der Tag fehlt. stderr bleibt
    # ausserhalb der Fehlerbehandlung, weil "not found" kein Fehler ist.
    param([string]$Tag)
    $previous = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        $line = & git -C $root ls-remote --tags origin $Tag 2>$null
    } finally {
        $ErrorActionPreference = $previous
    }
    return $line
}

function Get-RemoteBranchHead {
    param([string]$Branch)
    $previous = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        $line = & git -C $root ls-remote origin ("refs/heads/" + $Branch) 2>$null
    } finally {
        $ErrorActionPreference = $previous
    }
    if (-not $line) { return "" }
    return (($line -join " " -split '\s+')[0])
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw "git wurde nicht gefunden." }
# 1. Arbeitsbaum muss sauber sein. Das wird ZUERST geprueft: das Skript aendert
#    die VERSION-Datei selbst, und eine spaetere Pruefung wuerde an dieser
#    eigenen Aenderung scheitern.
$status = Invoke-Git @("status", "--porcelain")
if ($status) {
    Write-Host "Der Arbeitsbaum ist nicht sauber:" -ForegroundColor Red
    $status | ForEach-Object { Write-Host ("  " + $_) }
    Write-Host "Bitte zuerst committen (oder die Aenderungen verwerfen), damit der Tag einen klaren Stand bezeichnet."
    exit 1
}

# 2. Zielversion bestimmen. Die Datei wird erst nach der Bestaetigung geaendert.
$currentVersion = Get-VersionFromFile
$targetVersion = Add-VersionBump -Version $currentVersion -Kind $Bump
$targetTag = "v$targetVersion"

# 3. Tag darf noch nicht existieren (lokal oder auf origin).
$existing = Invoke-Git @("tag", "--list", $targetTag)
if ($existing) { throw "Der Tag $targetTag existiert bereits. Fuer eine neue Version vorher -Bump verwenden." }
if (Get-RemoteTagLine -Tag $targetTag) { throw "Der Tag $targetTag existiert bereits auf origin." }

$branch = (Invoke-Git @("rev-parse", "--abbrev-ref", "HEAD")) -join ""
$commit = (Invoke-Git @("rev-parse", "--short", "HEAD")) -join ""
$head = (Invoke-Git @("log", "-1", "--pretty=%s")) -join ""

# Der Tag bezeichnet einen Commit, der auch auf origin liegen muss. Sonst zeigt
# das Release auf einen Stand, den das Remote-Repository nicht kennt. Bei
# -Bump wird ohnehin gepusht, daher betrifft das nur den reinen Tag-Fall.
if ($Bump -eq "none") {
    $localHead = (Invoke-Git @("rev-parse", "HEAD")) -join ""
    $remoteHead = Get-RemoteBranchHead -Branch $branch
    if ($remoteHead -and $localHead -ne $remoteHead) {
        # Bewusst Zeichenketten-Interpolation statt -f: der -f-Operator bindet
        # staerker als +, wodurch Platzhalter in zusammengesetzten Texten
        # unersetzt bleiben koennen.
        throw "HEAD ($commit) ist nicht auf origin/$branch gepusht. Erst pushen, damit der Tag einen veroeffentlichten Stand bezeichnet."
    }
}

Write-Host ""
Write-Host "Release wird vorbereitet:" -ForegroundColor Cyan
Write-Host ("  Version : {0}" -f $targetVersion)
Write-Host ("  Tag     : {0}" -f $targetTag)
Write-Host ("  Branch  : {0} @ {1}" -f $branch, $commit)
Write-Host ("  Commit  : {0}" -f $head)
Write-Host ""

if (-not $Yes) {
    $answer = Read-Host "Tag setzen und pushen? (j/N)"
    if ($answer -notmatch '^(j|J|ja|Ja|y|Y|yes)$') {
        Write-Host "Abgebrochen. Es wurde nichts gepusht."
        return
    }
}

# 4. Erhoehen und committen (falls gewuenscht), taggen, pushen.
if ($Bump -ne "none") {
    # Erst jetzt schreiben: bis hierher ist nichts veraendert worden, ein
    # Abbruch laesst den Arbeitsbaum also unberuehrt.
    Write-Host ("VERSION wird erhoeht: {0} -> {1}" -f $currentVersion, $targetVersion)
    # Ohne abschliessenden Zeilenumbruch, wie die Datei bisher aussieht.
    [IO.File]::WriteAllText((Join-Path $root "VERSION"), $targetVersion, (New-Object Text.UTF8Encoding($false)))

    Invoke-Git @("add", "--", "VERSION") | Out-Null
    $commitMessage = if ([string]::IsNullOrWhiteSpace($Message)) { "chore: VERSION auf $targetVersion erhoeht" } else { $Message }
    Invoke-Git @("commit", "-m", $commitMessage) | Out-Null
    Invoke-Git @("push", "origin", $branch) | Out-Null
    Write-Host ("VERSION {0} committet und gepusht." -f $targetVersion) -ForegroundColor Green

    # Der Tag muss den neuen Commit bezeichnen.
    $commit = (Invoke-Git @("rev-parse", "--short", "HEAD")) -join ""
}

Invoke-Git @("tag", "-a", $targetTag, "-m", ("WIRKLICHT " + $targetVersion)) | Out-Null
Invoke-Git @("push", "origin", $targetTag) | Out-Null

Write-Host ""
Write-Host ("Tag {0} gepusht." -f $targetTag) -ForegroundColor Green
Write-Host "Der Workflow baut jetzt WIRKLICHT-Setup-$targetVersion.exe und legt sie an das Release."
Write-Host ""
Write-Host "Verlauf verfolgen:"
Write-Host "  gh run watch"
Write-Host "Release pruefen:"
Write-Host "  gh release view $targetTag"