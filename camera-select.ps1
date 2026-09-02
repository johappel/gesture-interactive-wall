param([switch]$NonInteractive)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\common.ps1")

try {
    Write-WirklichtHeader "WIRKLICHT KAMERA WAEHLEN"
    Test-WirklichtSystem | Out-Null
    $python = Ensure-WirklichtPython
    $venv = Ensure-WirklichtPythonEnvironment -PythonInfo $python

    if ($NonInteractive) {
        $name = Select-WirklichtCamera -VenvPython $venv -NonInteractive
        Write-WirklichtStep "Kamera $name" "gespeichert" Green
        exit 0
    }

    $cameras = @(Get-WirklichtAvailableCameras -VenvPython $venv -Backend "any")
    if ($cameras.Count -eq 0) {
        throw "Keine Kamera gefunden. Bitte USB-Kamera anschliessen und Kamera-Apps schliessen."
    }

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "WIRKLICHT - Kamera wählen"
    $form.StartPosition = "CenterScreen"
    $form.ClientSize = New-Object System.Drawing.Size(620, 390)
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.TopMost = $true

    $title = New-Object System.Windows.Forms.Label
    $title.Text = "Welche Kamera soll WIRKLICHT verwenden?"
    $title.Location = New-Object System.Drawing.Point(20, 18)
    $title.Size = New-Object System.Drawing.Size(580, 28)
    $title.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($title)

    $hint = New-Object System.Windows.Forms.Label
    $hint.Text = "Physische USB-Kameras sind empfohlen. Die Auswahl wird getestet und dauerhaft gespeichert."
    $hint.Location = New-Object System.Drawing.Point(20, 52)
    $hint.Size = New-Object System.Drawing.Size(580, 40)
    $form.Controls.Add($hint)

    $list = New-Object System.Windows.Forms.ListBox
    $list.Location = New-Object System.Drawing.Point(20, 98)
    $list.Size = New-Object System.Drawing.Size(580, 200)
    $list.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    for ($position = 0; $position -lt $cameras.Count; $position++) {
        $camera = $cameras[$position]
        $kind = if ([bool]$camera.physical) { "USB-Kamera $($camera.vid):$($camera.pid)" } else { "virtuell/unklar" }
        [void]$list.Items.Add(("{0}  -  {1}" -f $camera.name, $kind))
    }
    $configuredName = (Read-WirklichtJson (Join-Path $script:WirklichtRoot "config\config.json")).camera.name
    $configuredPosition = -1
    for ($position = 0; $position -lt $cameras.Count; $position++) {
        if ([string]$cameras[$position].name -eq [string]$configuredName) { $configuredPosition = $position; break }
    }
    $list.SelectedIndex = if ($configuredPosition -ge 0) { $configuredPosition } else { 0 }
    $form.Controls.Add($list)

    $status = New-Object System.Windows.Forms.Label
    $status.Text = ""
    $status.Location = New-Object System.Drawing.Point(20, 310)
    $status.Size = New-Object System.Drawing.Size(370, 48)
    $status.ForeColor = [System.Drawing.Color]::DarkRed
    $form.Controls.Add($status)

    $cancel = New-Object System.Windows.Forms.Button
    $cancel.Text = "Abbrechen"
    $cancel.Location = New-Object System.Drawing.Point(350, 320)
    $cancel.Size = New-Object System.Drawing.Size(100, 34)
    $cancel.Add_Click({ $form.DialogResult = [System.Windows.Forms.DialogResult]::Cancel; $form.Close() })
    $form.Controls.Add($cancel)

    $ok = New-Object System.Windows.Forms.Button
    $ok.Text = "Testen & speichern"
    $ok.Location = New-Object System.Drawing.Point(460, 320)
    $ok.Size = New-Object System.Drawing.Size(140, 34)
    $ok.Add_Click({
        if ($list.SelectedIndex -lt 0) { $status.Text = "Bitte zuerst eine Kamera auswählen."; return }
        $chosen = $cameras[$list.SelectedIndex]
        $status.ForeColor = [System.Drawing.Color]::DarkBlue
        $status.Text = "Kamera wird kurz getestet ..."
        $form.Refresh()
        if (-not (Test-WirklichtCameraSelection -VenvPython $venv -Index ([int]$chosen.index) -Backend ([string]$chosen.backend))) {
            $status.ForeColor = [System.Drawing.Color]::DarkRed
            $status.Text = "Diese Kamera liefert kein Bild. Bitte eine andere auswählen oder Kamera-Apps schließen."
            return
        }
        Save-WirklichtCameraSelection -Camera $chosen
        $script:selectedName = [string]$chosen.name
        $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $form.Close()
    })
    $form.Controls.Add($ok)
    $form.AcceptButton = $ok
    $form.CancelButton = $cancel

    $result = $form.ShowDialog()
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        Write-WirklichtHeader "KAMERA GESPEICHERT"
        Write-Host $script:selectedName
        exit 0
    }
    Write-Host "Kameraauswahl wurde nicht geändert."
    exit 0
} catch {
    Write-WirklichtHeader "KAMERA NICHT GESPEICHERT"
    Write-Host $_.Exception.Message -ForegroundColor Red
    if (-not $NonInteractive) { Read-Host "ENTER zum Beenden" | Out-Null }
    exit 1
}
