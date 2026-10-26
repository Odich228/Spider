import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[3]

class UpdateInstallerTests(unittest.TestCase):
    @unittest.skipUnless(os.name == 'nt', 'Native Windows installer integration')
    def test_unicode_paths_preserve_backup_and_launch_updated_app(self):
        script_text = (ROOT / 'lib/features/profile/update_settings.dart').read_text(encoding='utf-8')
        match = re.search(r"await script.writeAsString\(r'''\n(param\(\[string\]\$ConfigPath\).*?)'''\);", script_text, re.S)
        self.assertIsNotNone(match)
        with tempfile.TemporaryDirectory(prefix='pautina-updater-test-') as temporary:
            root = Path(temporary)
            self.assertEqual(root.resolve().parent, Path(tempfile.gettempdir()).resolve())
            self.assertTrue(root.name.startswith('pautina-updater-test-'))
            source = root / 'new-новая версия'
            target = root / 'installed-установленная версия'
            for directory, content in [(source, 'new'), (target, 'old')]:
                (directory / 'data').mkdir(parents=True)
                (directory / 'pautina.exe').write_text(content)
                (directory / 'data/asset.txt').write_text(content)
            script = root / 'install.ps1'
            script.write_text(match.group(1), encoding='utf-8')
            config = root / 'install.json'
            config.write_text(json.dumps({'processId':2147483000,'source':str(source),'target':str(target),'executable':'pautina.exe'},ensure_ascii=False), encoding='utf-8')
            launch = root / 'launched.txt'
            wrapper = r'''
$ErrorActionPreference='Stop'
function Start-Process {
  param([string]$FilePath,[string]$WorkingDirectory)
  [IO.File]::WriteAllText($env:PAUTINA_TEST_LAUNCH,$FilePath)
}
& $env:PAUTINA_TEST_SCRIPT -ConfigPath $env:PAUTINA_TEST_CONFIG
'''
            result = subprocess.run([shutil.which('powershell.exe'),'-NoProfile','-ExecutionPolicy','Bypass','-Command',wrapper], env=dict(os.environ,PAUTINA_TEST_LAUNCH=str(launch),PAUTINA_TEST_SCRIPT=str(script),PAUTINA_TEST_CONFIG=str(config)),capture_output=True)
            self.assertEqual(result.returncode,0,result.stderr.decode(errors='replace'))
            self.assertFalse((root/'install-error.txt').exists())
            self.assertEqual((target/'pautina.exe').read_text(),'new')
            self.assertEqual((target/'data/asset.txt').read_text(),'new')
            self.assertEqual((root/'previous/pautina.exe').read_text(),'old')
            self.assertEqual((root/'previous/data/asset.txt').read_text(),'old')
            self.assertEqual(Path(launch.read_text(encoding='utf-8')),target/'pautina.exe')
