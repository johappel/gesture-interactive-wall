param([switch]$NonInteractive, [ValidateSet("facade", "monitor")][string]$Target = "facade")

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\common.ps1")

try {
    Write-WirklichtHeader "WIRKLICHT BILDSCHIRM WÄHLEN"
    Test-WirklichtSystem | Out-Null
    $screens = @(Get-WirklichtAvailableScreens)
    if ($screens.Count -eq 0) { throw "Kein Bildschirm wurde von Windows erkannt." }
    $config = Read-WirklichtJson (Join-Path $script:WirklichtRoot "config\config.json")
    $facade = Find-WirklichtConfiguredScreen -Screens $screens -Facade $config.station.facade
    $targetLabel = if ($Target -eq "monitor") { "Nahraum-Monitor" } else { "Fassade / Beamer" }
    $choices = @($screens)
    if ($Target -eq "monitor" -and $null -ne $facade) { $choices = @($screens | Where-Object { $_.index -ne $facade.index }) }
    if ($choices.Count -eq 0) { throw "Für den Nahraum-Monitor ist keine von der Fassade getrennte Anzeige verfügbar." }
    if ($NonInteractive) {
        $selected = if ($Target -eq "monitor") { Select-WirklichtMonitorScreen -FacadeScreen $facade -NonInteractive } else { Select-WirklichtFacadeScreen -NonInteractive }
        if ($null -ne $selected) { Write-WirklichtStep ("{0} Bildschirm {1}" -f $targetLabel, $selected.index) "gespeichert" Green }
        exit 0
    }
    if ($choices.Count -eq 1 -and $Target -eq "facade") {
        Save-WirklichtFacadeScreenSelection -Screen $choices[0] -Screens $screens
        Write-WirklichtStep "Einziger Bildschirm" "gespeichert" Green
        exit 0
    }

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "WIRKLICHT - " + $targetLabel + " wählen"
    $form.StartPosition = "CenterScreen"
    $form.ClientSize = New-Object System.Drawing.Size(690, 380)
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.TopMost = $true

    $title = New-Object System.Windows.Forms.Label
    $title.Text = "Auf welchem Bildschirm soll " + $targetLabel + " erscheinen?"
    $title.Location = New-Object System.Drawing.Point(20, 18)
    $title.Size = New-Object System.Drawing.Size(650, 28)
    $title.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($title)
    $hint = New-Object System.Windows.Forms.Label
    $hint.Text = if ($Target -eq "monitor") { "Der Nahraum-Monitor bleibt von der Fassade getrennt und zeigt keine Kameraaufnahme. Die Auswahl wird gespeichert." } else { "WIRKLICHT setzt das Fenster beim Start zuerst auf diesen Bildschirm und aktiviert danach Vollbild. Die Auswahl wird gespeichert." }
    $hint.Location = New-Object System.Drawing.Point(20, 52)
    $hint.Size = New-Object System.Drawing.Size(650, 42)
    $form.Controls.Add($hint)

    $list = New-Object System.Windows.Forms.ListBox
    $list.Location = New-Object System.Drawing.Point(20, 102)
    $list.Size = New-Object System.Drawing.Size(650, 190)
    $list.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    foreach ($screen in $choices) {
        $primary = if ($screen.primary) { ", Hauptbildschirm" } else { "" }
        [void]$list.Items.Add(("[{0}] Bildschirm {0} – {1}×{2}, Position {3},{4}{5}" -f $screen.index, $screen.width, $screen.height, $screen.x, $screen.y, $primary))
    }
    $configured = Find-WirklichtConfiguredScreen -Screens $screens -Facade $config.station.PSObject.Properties[$Target].Value
    $configuredPosition = -1
    for ($position = 0; $position -lt $choices.Count; $position++) {
        if ($null -ne $configured -and $choices[$position].index -eq $configured.index) { $configuredPosition = $position; break }
    }
    $list.SelectedIndex = if ($configuredPosition -ge 0) { $configuredPosition } else { 0 }
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
        $script:selectedScreen = $choices[$list.SelectedIndex]
        if ($Target -eq "monitor") { Save-WirklichtMonitorScreenSelection -Screen $script:selectedScreen -Screens $screens }
        else { Save-WirklichtFacadeScreenSelection -Screen $script:selectedScreen -Screens $screens }
        $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $form.Close()
    })
    $form.Controls.Add($ok)
    $form.AcceptButton = $ok
    $form.CancelButton = $cancel
    if ($form.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        Write-WirklichtHeader "BILDSCHIRM GESPEICHERT"
        Write-Host ("{0}: Bildschirm {1}" -f $targetLabel, $script:selectedScreen.index)
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
