"""Contract and Windows-only logic tests for the operator scripts.

The actual installer needs a real Windows machine, network, camera and Godot.
These tests still exercise the most important file-operation guarantee when
PowerShell is available: syncing program files must preserve local config.
"""

import os
import shutil
import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class WindowsScriptContractTest(unittest.TestCase):
    def test_operator_scripts_exist(self):
        for name in ("install.ps1", "start.ps1", "camera-select.ps1", "update.ps1", "diagnose.ps1"):
            self.assertTrue((ROOT / name).is_file(), name)
        self.assertTrue((ROOT / "lib" / "common.ps1").is_file())

    def test_scripts_keep_operator_guarantees(self):
        common = (ROOT / "lib" / "common.ps1").read_text(encoding="utf-8")
        install = (ROOT / "install.ps1").read_text(encoding="utf-8")
        start = (ROOT / "start.ps1").read_text(encoding="utf-8")
        diagnose = (ROOT / "diagnose.ps1").read_text(encoding="utf-8")
        camera_select = (ROOT / "camera-select.ps1").read_text(encoding="utf-8")
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
        self.assertIn("[switch]$NoPrompt", common)
        self.assertIn("System.Windows.Forms", camera_select)
        self.assertIn("Testen & speichern", camera_select)
        self.assertIn('New-WirklichtShortcut -Name "WIRKLICHT Kamera waehlen"', common)
        self.assertIn("WIRKLICHT-DIAGNOSE.txt", diagnose)

    @unittest.skipUnless(shutil.which("powershell"), "Windows PowerShell nicht verfuegbar")
    def test_powershell_scripts_parse(self):
        files = ["install.ps1", "start.ps1", "camera-select.ps1", "update.ps1", "diagnose.ps1", "lib\\common.ps1"]
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


if __name__ == "__main__":
    unittest.main()
