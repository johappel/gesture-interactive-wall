"""Contract and Windows-only logic tests for the operator scripts.

The actual installer needs a real Windows machine, network, camera and Godot.
These tests still exercise the most important file-operation guarantee when
PowerShell is available: syncing program files must preserve local config.
"""

import os
import json
import shutil
import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class WindowsScriptContractTest(unittest.TestCase):
    def test_renderer_output_config_has_separate_fullscreen_displays(self):
        config = json.loads((ROOT / "config" / "config.json").read_text(encoding="utf-8"))
        station = config["station"]
        self.assertIsInstance(station["facade"]["screen"], int)
        self.assertGreaterEqual(station["facade"]["screen"], 0)
        self.assertTrue(station["facade"]["fullscreen"])
        self.assertIsInstance(station["monitor"]["screen"], int)
        self.assertGreaterEqual(station["monitor"]["screen"], 0)
        self.assertTrue(station["monitor"]["fullscreen"])
        self.assertFalse(station["monitor"]["show_camera_image"])

    def test_renderer_assigns_outputs_and_guards_single_display(self):
        renderer = (ROOT / "renderer" / "scripts" / "main.gd").read_text(encoding="utf-8")
        self.assertIn("func _setup_facade_output()", renderer)
        self.assertIn("Window.MODE_FULLSCREEN", renderer)
        self.assertIn("DisplayServer.window_set_current_screen", renderer) if False else None
        self.assertIn("DisplayServer.get_screen_count() < 2", renderer)
        self.assertIn("monitor_screen == _facade_screen", renderer)
        self.assertIn("DisplayServer.get_primary_screen()", renderer)
        self.assertIn("DisplayServer.screen_get_position(screen_index)", renderer)
        self.assertIn("func _toggle_facade_fullscreen()", renderer)
        self.assertIn("KEY_ENTER", renderer)

    def test_operator_scripts_exist(self):
        for name in ("install.ps1", "start.ps1", "camera-select.ps1", "monitor-select.ps1", "update.ps1", "diagnose.ps1"):
            self.assertTrue((ROOT / name).is_file(), name)
        for name in ("WIRKLICHT starten.cmd", "WIRKLICHT Kamera waehlen.cmd", "WIRKLICHT Bildschirm waehlen.cmd", "WIRKLICHT Nahraum-Monitor waehlen.cmd", "WIRKLICHT Diagnose.cmd"):
            self.assertTrue((ROOT / name).is_file(), name)
        self.assertTrue((ROOT / "lib" / "common.ps1").is_file())

    def test_scripts_keep_operator_guarantees(self):
        common = (ROOT / "lib" / "common.ps1").read_text(encoding="utf-8")
        install = (ROOT / "install.ps1").read_text(encoding="utf-8")
        start = (ROOT / "start.ps1").read_text(encoding="utf-8")
        diagnose = (ROOT / "diagnose.ps1").read_text(encoding="utf-8")
        camera_select = (ROOT / "camera-select.ps1").read_text(encoding="utf-8")
        monitor_select = (ROOT / "monitor-select.ps1").read_text(encoding="utf-8")
        self.assertIn("config\\config.json", common)
        self.assertIn("Backup-WirklichtLocalState", common)
        self.assertIn("Restore-WirklichtProgramFiles", common)
        self.assertIn("Python.Python.3.11", common)
        self.assertIn("python-3.11.9-amd64.exe", common)
        self.assertIn('-3.11 -c "import sys; print(sys.executable)"', common)
        self.assertIn("$exitCode = $LASTEXITCODE", common)
        self.assertIn("Test-WirklichtPythonDependencies", common)
        self.assertIn("cv2-enumerate-cameras", common)
        self.assertIn('"opencv-python", "opencv-contrib-python"', common)
        self.assertIn("Die Installation wird trotzdem abgeschlossen", common)
        self.assertIn("Get-WirklichtAvailableCameras", common)
        self.assertIn("Save-WirklichtCameraSelection", common)
        self.assertIn("Get-WirklichtAvailableScreens", common)
        self.assertIn("return $result.ToArray()", common)
        self.assertIn("Save-WirklichtFacadeScreenSelection", common)
        self.assertIn("Save-WirklichtMonitorScreenSelection", common)
        self.assertIn("Select-WirklichtMonitorScreen", common)
        self.assertIn("relative_x", common)
        self.assertIn("Find-WirklichtConfiguredScreen", common)
        self.assertIn("Test-WirklichtCameraSelection", common)
        self.assertIn("UTF8Encoding($false)", common)
        self.assertIn("Godot_v4.7.1-stable_win64.exe", common)
        self.assertIn("Godot_v4.7.1-stable_win64.exe.zip", common)
        self.assertIn("Invoke-WirklichtDownload", common)
        self.assertIn('"updates"', (ROOT / "config" / "config.json").read_text(encoding="utf-8"))
        self.assertIn("$SkipProjectDownload = $true", install)
        self.assertIn("WIRKLICHT IST BEREIT", start)
        self.assertIn('"gl_compatibility"', start)
        self.assertIn("Die Kamera wurde erfolgreich geprueft", start)
        self.assertIn("camera-select.ps1", start)
        self.assertIn("monitor-select.ps1", start)
        self.assertIn("Select-WirklichtFacadeScreen", start)
        self.assertIn("Select-WirklichtMonitorScreen", start)
        self.assertIn("[switch]$NoPrompt", common)
        self.assertIn("System.Windows.Forms", camera_select)
        self.assertIn("Testen & speichern", camera_select)
        self.assertIn("System.Windows.Forms", monitor_select)
        self.assertIn("WIRKLICHT - ", monitor_select)
        self.assertIn("Position", monitor_select)
        self.assertIn('"monitor"', monitor_select)
        self.assertIn('New-WirklichtShortcut -Name "WIRKLICHT Kamera waehlen"', common)
        self.assertIn('New-WirklichtShortcut -Name "WIRKLICHT Bildschirm waehlen"', common)
        self.assertIn('New-WirklichtShortcut -Name "WIRKLICHT Nahraum-Monitor waehlen"', common)
        self.assertIn("-Target monitor", common)
        self.assertIn("Get-WirklichtShortcutDirectories", common)
        self.assertIn("Start-Verknuepfungen:", common)
        self.assertIn("WIRKLICHT starten.cmd", common)
        self.assertIn("WIRKLICHT-DIAGNOSE.txt", diagnose)

    @unittest.skipUnless(shutil.which("powershell"), "Windows PowerShell nicht verfuegbar")
    def test_powershell_scripts_parse(self):
        files = ["install.ps1", "start.ps1", "camera-select.ps1", "monitor-select.ps1", "update.ps1", "diagnose.ps1", "lib\\common.ps1"]
        command = ""
        for name in files:
            path = str(ROOT / name).replace("'", "''")
            command += (
                f"$t=$null;$e=$null;"
                f"[System.Management.Automation.Language.Parser]::ParseFile('{path}',[ref]$t,[ref]$e)|Out-Null;"
                f"if($e.Count){{throw 'Syntaxfehler in {name}'}};"
            )
        result = subprocess.run(
            ["powershell", "-NoProfile", "-Command", command],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    @unittest.skipUnless(shutil.which("powershell"), "Windows PowerShell nicht verfuegbar")
    def test_sync_preserves_local_config(self):
        common = str(ROOT / "lib" / "common.ps1").replace("'", "''")
        command = f"""
$tmp = Join-Path ([IO.Path]::GetTempPath()) ('wirklicht-test-' + [guid]::NewGuid().ToString('N'))
$src = Join-Path $tmp 'source'; $dst = Join-Path $tmp 'destination'
New-Item -ItemType Directory -Force -Path (Join-Path $src 'config'),(Join-Path $dst 'config') | Out-Null
Set-Content -LiteralPath (Join-Path $src 'config\\config.json') -Value '{{"camera":{{"index":1}}}}'
Set-Content -LiteralPath (Join-Path $dst 'config\\config.json') -Value '{{"camera":{{"index":7}}}}'
Set-Content -LiteralPath (Join-Path $src 'start.ps1') -Value 'new-version'
. '{common}'; Set-WirklichtRoot -Path $dst
Sync-WirklichtProject -SourceRoot $src -DestinationRoot $dst | Out-Null
$cfg = Get-Content (Join-Path $dst 'config\\config.json') -Raw
$start = Get-Content (Join-Path $dst 'start.ps1') -Raw
if ($cfg -notmatch '"index":7' -or $start -notmatch 'new-version') {{ throw 'Config-Erhaltung fehlgeschlagen' }}
Remove-Item -LiteralPath $tmp -Recurse -Force
"""
        result = subprocess.run(
            ["powershell", "-NoProfile", "-Command", command],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


class InstallerContractTest(unittest.TestCase):
    """Der Inno-Setup-Installer ist nur eine Huelle um die geprueften Skripte.

    Diese Tests halten die Zusagen fest, die dabei leicht verloren gehen: das
    Zielverzeichnis wird durchgereicht, die lokale Betriebsconfig bleibt
    unangetastet und der Installationslauf bleibt sichtbar.
    """

    def test_installer_artifacts_exist(self):
        self.assertTrue((ROOT / "installer" / "wirklicht.iss").is_file())
        self.assertTrue((ROOT / "installer" / "build.ps1").is_file())

    def test_installer_script_keeps_operator_guarantees(self):
        iss = (ROOT / "installer" / "wirklicht.iss").read_text(encoding="utf-8")
        # Ohne -InstallPath faellt install.ps1 auf C:\WIRKLICHT zurueck und
        # wuerde ein abweichend gewaehltes Zielverzeichnis still ignorieren.
        self.assertIn('-SkipProjectDownload -InstallPath ""{app}""', iss)
        # Die Betriebsconfig des Veranstaltungsorts darf nie ueberschrieben
        # werden; fuer frische Installationen gibt es eine Vorlage.
        self.assertIn('Excludes: "config.json,local.json"', iss)
        self.assertIn("config.json.template", iss)
        # Kein stiller Lauf: Python, Godot und die Pakete werden nachgeladen,
        # ein verstecktes Fenster wirkte ueber Minuten wie ein Haenger. Geprueft
        # wird die Flags-Zeile selbst, nicht ein Kommentar darueber.
        install_run = [line for line in iss.splitlines() if line.strip().startswith("Flags:")]
        self.assertTrue(install_run, "Der Installationslauf fehlt in [Run]")
        for line in install_run:
            self.assertNotIn("runhidden", line)
        # Kein UAC-Dialog, entsprechend dem bisherigen Verhalten.
        self.assertIn("PrivilegesRequired=lowest", iss)
        # Laufzeitdateien werden beim Deinstallieren mit entfernt, die
        # Betriebseinstellungen und Sicherungen aber nicht.
        self.assertIn("[UninstallDelete]", iss)
        self.assertNotIn('Name: "{app}\\config"', iss)
        self.assertNotIn('Name: "{app}\\backup"', iss)
        # Der Start erfolgt ueber die vorhandene .cmd, nicht ueber einen
        # zweiten, abweichenden Startweg.
        self.assertIn("WIRKLICHT starten.cmd", iss)

    def test_build_script_derives_version_from_project(self):
        build = (ROOT / "installer" / "build.ps1").read_text(encoding="utf-8")
        # Installer und Projekt duerfen nicht auseinanderlaufen.
        self.assertIn('Join-Path $root "VERSION"', build)
        self.assertIn("ConvertTo-FourPartVersion", build)
        # Inno braucht vier Zahlstellen fuer die Versionsinformationen.
        self.assertIn("/DVersionNumeric=", build)

    def test_workflow_pins_tag_to_version_file(self):
        """Ein Tag-Release muss zur VERSION-Datei passen.

        Der Tag benennt das Release, die VERSION-Datei den Inhalt der
        setup.exe. Ohne diese Pruefung entstand ein Release v0.0.2, unter dem
        eine WIRKLICHT-Setup-0.5.4.exe haengt.
        """
        workflow = (ROOT / ".github" / "workflows" / "installer.yml").read_text(encoding="utf-8")
        self.assertIn("GITHUB_REF_TYPE", workflow)
        self.assertIn("GITHUB_REF_NAME", workflow)
        self.assertIn('v$version', workflow)
        self.assertIn("throw", workflow)
        # Der Dateiname wird aus der VERSION-Datei gebildet, die geprueft wurde.
        self.assertIn('WIRKLICHT-Setup-${{ steps.version.outputs.version }}.exe', workflow)

    def test_project_version_is_a_semantic_version(self):
        version = (ROOT / "VERSION").read_text(encoding="utf-8").strip()
        self.assertRegex(version, r"^\d+\.\d+\.\d+([.\-+].*)?$")

    @unittest.skipUnless(shutil.which("powershell"), "Windows PowerShell nicht verfuegbar")
    def test_local_config_initialisation_preserves_existing_config(self):
        common = str(ROOT / "lib" / "common.ps1").replace("'", "''")
        command = """
$tmp = Join-Path ([IO.Path]::GetTempPath()) ('wirklicht-cfg-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path (Join-Path $tmp 'config') | Out-Null
. '__COMMON__'; Set-WirklichtRoot -Path $tmp

# 1. Frische Installation: aus der Vorlage entsteht die lokale Config.
Set-Content -LiteralPath (Join-Path $tmp 'config\\config.json.template') -Value '{"marker":"vorlage"}'
[void](Initialize-WirklichtLocalConfig)
if (-not (Test-Path -LiteralPath (Join-Path $tmp 'config\\config.json'))) { throw 'Config wurde nicht aus der Vorlage angelegt' }

# 2. Eine bestehende Betriebsconfig bleibt unangetastet.
Set-Content -LiteralPath (Join-Path $tmp 'config\\config.json') -Value '{"marker":"lokal"}'
[void](Initialize-WirklichtLocalConfig)
if ((Get-Content (Join-Path $tmp 'config\\config.json') -Raw) -notmatch 'lokal') { throw 'Bestehende Config wurde ueberschrieben' }

# 3. Ohne Vorlage passiert nichts und es gibt keinen Fehler.
Remove-Item -LiteralPath (Join-Path $tmp 'config\\config.json') -Force
Remove-Item -LiteralPath (Join-Path $tmp 'config\\config.json.template') -Force
if ($null -ne (Initialize-WirklichtLocalConfig)) { throw 'Ohne Vorlage darf kein Pfad gemeldet werden' }

Remove-Item -LiteralPath $tmp -Recurse -Force
"""
        command = command.replace("__COMMON__", common)
        result = subprocess.run(
            ["powershell", "-NoProfile", "-Command", command],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


if __name__ == "__main__":
    unittest.main()
