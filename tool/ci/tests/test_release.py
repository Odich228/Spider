import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

CI = Path(__file__).resolve().parents[1]
def load(name):
    spec = importlib.util.spec_from_file_location(name, CI / f'{name}.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module
release = load('release')
build = load('build')

class ReleaseTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='pautina-release-test-')
        self.directory = Path(self.temp.name)
        for platform in release.PLATFORMS:
            artifact = self.directory / f'{platform}.zip'
            artifact.write_bytes(platform.encode())
            data = {'platform': platform, 'version': '0.1.0', 'build_number': 7, 'commit': 'abc', 'signing': 'preview', 'files': [{'name': artifact.name, 'sha256': hashlib.sha256(artifact.read_bytes()).hexdigest()}]}
            (self.directory / f'manifest-{platform}.json').write_text(json.dumps(data))
    def tearDown(self):
        # Validate the absolute, task-owned temporary directory before deletion.
        target = self.directory.resolve()
        parent = Path(tempfile.gettempdir()).resolve()
        self.assertEqual(target.parent, parent)
        self.assertTrue(target.name.startswith('pautina-release-test-'))
        self.temp.cleanup()
    def test_complete_artifacts_are_accepted(self):
        self.assertEqual(len(release.validate(self.directory, 7, 'abc')), 4)
    def test_missing_platform_blocks_release(self):
        (self.directory / 'manifest-ios.json').unlink()
        with self.assertRaises(ValueError): release.validate(self.directory, 7, 'abc')
    def test_mismatched_commit_blocks_release(self):
        with self.assertRaises(ValueError): release.validate(self.directory, 7, 'other')
    def test_corrupted_binary_blocks_release(self):
        (self.directory / 'windows.zip').write_bytes(b'corrupt')
        with self.assertRaises(ValueError): release.validate(self.directory, 7, 'abc')
    def test_path_traversal_blocks_release(self):
        file = self.directory / 'manifest-ios.json'
        data = json.loads(file.read_text())
        data['files'][0]['name'] = '../ios.zip'
        file.write_text(json.dumps(data))
        with self.assertRaises(ValueError): release.validate(self.directory, 7, 'abc')
    def test_java_property_password_escaping(self):
        self.assertEqual(build.property_escape('a b:c\\d\n'), 'a\\ b\\:c\\\\d\\n')
        self.assertEqual(build.property_escape('паук'), r'\u043f\u0430\u0443\u043a')
    def test_empty_native_bundle_blocks_packaging(self):
        with self.assertRaises(ValueError):
            build.zip_tree(self.directory / 'missing-bundle', self.directory / 'empty.zip')

if __name__ == '__main__': unittest.main()
