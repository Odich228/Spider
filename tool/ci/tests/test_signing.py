import importlib.util
import os
from pathlib import Path
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('signing', Path(__file__).resolve().parents[1] / 'signing.py')
signing = importlib.util.module_from_spec(spec)
spec.loader.exec_module(signing)

class SigningTests(unittest.TestCase):
    @patch.dict(os.environ, {}, clear=True)
    @patch.object(signing, 'execute')
    def test_windows_preview_never_touches_certificate_store(self, execute):
        self.assertEqual(signing.sign_windows(Path('missing-bundle')), 'unsigned-portable')
        execute.assert_not_called()

    @patch.dict(os.environ, {}, clear=True)
    @patch.object(signing, 'execute')
    def test_macos_preview_does_not_create_a_keychain(self, execute):
        with signing.mac_keychain() as identity:
            self.assertIsNone(identity)
        execute.assert_not_called()

    @patch.dict(os.environ, {'MACOS_NOTARY_KEY_ID':'key'}, clear=True)
    @patch.object(signing, 'execute')
    def test_incomplete_notary_configuration_fails_before_packaging(self, execute):
        with self.assertRaises(ValueError):
            signing.package_macos(Path('app'),Path('app.zip'),Path('.'))
        execute.assert_not_called()
