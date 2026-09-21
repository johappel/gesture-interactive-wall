param([switch]$NonInteractive)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\common.ps1")

try {
    Write-WirklichtHeader "WIRKLICHT BILDSCHIRM WÄHLEN"
    Test-WirklichtSystem | Out-Null
    $screens = @(Get-WirklichtAvailableScreens)
    if ($screens.Count -eq 0) { throw "Kein Bildschirm wurde von Windows erkannt." }
    if ($NonInteractive) {
        $selected = Select-WirklichtFacadeScreen -NonInteractive
        Write-WirklichtStep ("Fassade Bildschirm {0}" -f $selected.index) "gespeichert" Green
        exit 0
    }
    if ($screens.Count -eq 1) {
        Save-WirklichtFacadeScreenSelection -Screen $screens[0]
        Write-WirklichtStep "Einziger Bildschirm" "gespeichert" Green
        exit 0
    }

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "WIRKLICHT - Bildschirm wählen"
    $form.StartPosition = "CenterScreen"
    $form.ClientSize = New-Object System.Drawing.Size(690, 380)
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.TopMost = $true

    $title = New-Object System.Windows.Forms.Label
    $title.Text = "Auf welchem Bildschirm soll die Fassade erscheinen?"
    $title.Location = New-Object System.Drawing.Point(20, 18)
    $title.Size = New-Object System.Drawing.Size(650, 28)
    $title.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($title)
    $hint = New-Object System.Windows.Forms.Label
    $hint.Text = "WIRKLICHT setzt das Fenster beim Start zuerst auf diesen Bildschirm und aktiviert danach Vollbild. Die Auswahl wird gespeichert."
    $hint.Location = New-Object System.Drawing.Point(20, 52)
    $hint.Size = New-Object System.Drawing.Size(650, 42)
    $form.Controls.Add($hint)

    $list = New-Object System.Windows.Forms.ListBox
    $list.Location = New-Object System.Drawing.Point(20, 102)
    $list.Size = New-Object System.Drawing.Size(650, 190)
    $list.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    foreach ($screen in $screens) {
        $primary = if ($screen.primary) { ", Hauptbildschirm" } else { "" }
        [void]$list.Items.Add(("[{0}] Bildschirm {0} – {1}×{2}, Position {3},{4}{5}" -f $screen.index, $screen.width, $screen.height, $screen.x, $screen.y, $primary))
    }
    $config = Read-WirklichtJson (Join-Path $script:WirklichtRoot "config\config.json")
    $configured = Find-WirklichtConfiguredScreen -Screens $screens -Facade $config.station.facade
    $list.SelectedIndex = if ($null -ne $configured) { [int]$configured.index } else { 0 }
    $form.Controls.Add($list)

    $status = New-Object System.Windows.Forms.Label
    $status.Location = New-Object System.Drawing.Point(20, 305)
    $status.Size = New-Object System.Drawing.Size(420, 36)
    $status.ForeColor = [System.Drawing.Color]::DarkRed
    $form.Controls.Add($status)
    $cancel = New-Object System.Windows.Forms.Button
    $cancel.Text = "Abbrechen"
    $cancel.Location = New-Object System.Drawing.Point(460, 315)
    $cancel.Size = New-Object System.Drawing.Size(100, 34)
    $cancel.Add_Click({ $form.DialogResult = [System.Windows.Forms.DialogResult]::Cancel; $form.Close() })
    $form.Controls.Add($cancel)
    $ok = New-Object System.Windows.Forms.Button
    $ok.Text = "Speichern"
    $ok.Location = New-Object System.Drawing.Point(570, 315)
    $ok.Size = New-Object System.Drawing.Size(100, 34)
    $ok.Add_Click({
        if ($list.SelectedIndex -lt 0) { $status.Text = "Bitte zuerst einen Bildschirm auswählen."; return }
        $script:selectedScreen = $screens[$list.SelectedIndex]
        Save-WirklichtFacadeScreenSelection -Screen $script:selectedScreen
        $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $form.Close()
    })
    $form.Controls.Add($ok)
    $form.AcceptButton = $ok
    $form.CancelButton = $cancel
    if ($form.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        Write-WirklichtHeader "BILDSCHIRM GESPEICHERT"
        Write-Host ("Fassade: Bildschirm {0}" -f $script:selectedScreen.index)
        exit 0
    }
    Write-Host "Bildschirmauswahl wurde nicht geändert."
    exit 1
} catch {
    Write-WirklichtHeader "BILDSCHIRM NICHT GESPEICHERT"
    Write-Host $_.Exception.Message -ForegroundColor Red
    if (-not $NonInteractive) { Read-Host "ENTER zum Beenden" | Out-Null }
    exit 1
}
