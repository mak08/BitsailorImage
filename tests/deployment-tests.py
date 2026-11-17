"""Exercise deployment in isolated staging trees; never invoke host systemctl.

Run with python3 tests/deployment-tests.py. The fixture dataset Makefile stands
in for downloading/generating large datasets; web-assets is also testable against
a real, already prepared Bitsailor checkout separately.
"""
from pathlib import Path
import subprocess
import tempfile
import unittest


MAKEFILE = Path(__file__).resolve().parents[1] / 'Makefile'


class DeploymentTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='bitsailor-deploy-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root / 'source'
        self.source.mkdir()
        self.stage = self.root / 'stage'
        self.checkout = self.root / 'checkout'
        self.checkout.mkdir()
        (self.checkout / 'Makefile').write_text('''
.PHONY: all
all:
	@test "$(FAIL_ASSETS)" != 1
	@mkdir -p web/bathymetry/channel-2024
	@printf 'generated tile' > web/bathymetry/channel-2024/0_100.bin.gz
	@printf '{}' > web/bathymetry/channel-2024/manifest.json
	@echo built >> builds.log
''')
        (self.checkout / 'web').mkdir(exist_ok=True)
        (self.checkout / 'web/router-fw.html').write_text('new webpage')
        for name in ('bitsailor.conf', 'server-config.cl', 'bitsailor.service', 'bitsailor.core'):
            (self.source / name).write_text('default ' + name)
        (self.source / 'polars').mkdir()
        (self.source / 'polars/boat.csv').write_text('default polar')
        for directory in ('land-polygons-split-4326', 'coastlines-split-4326'):
            (self.source / directory).mkdir()
            (self.source / directory / 'map.shp').write_text('map fixture')
        self.systemctl = self.root / 'systemctl'
        self.systemctl.write_text('#!/bin/sh\necho unexpected-systemctl >&2\nexit 99\n')
        self.systemctl.chmod(0o755)

    def make(self, target, *overrides, success=True):
        result = subprocess.run(
            ['make', '--no-print-directory', '-j4', '-f', str(MAKEFILE), target,
             f'BITSAILOR_DIR={self.checkout}', f'DESTDIR={self.stage}',
             f'SYSTEMCTL={self.systemctl}', *overrides],
            cwd=self.source, capture_output=True, text=True)
        if success:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0)
        return result

    def test_install_and_update_generate_copy_and_preserve(self):
        self.make('install')
        config = self.stage / 'etc/bitsailor'
        web = config / 'web'
        self.assertEqual((web / 'bathymetry/channel-2024/0_100.bin.gz').read_text(), 'generated tile')
        self.assertTrue((web / 'bathymetry/channel-2024/manifest.json').exists())
        self.assertTrue((self.stage / 'srv/bitsailor/map/land-polygons-split-4326/map.shp').exists())
        protected = [config / 'bitsailor.conf', config / 'server-config.cl',
                     config / 'polars/boat.csv', self.stage / 'etc/systemd/system/bitsailor.service']
        for path in protected:
            path.write_text('locally edited ' + path.name)
        before = {path: (path.read_bytes(), path.stat().st_mtime_ns) for path in protected}
        (web / 'local-file.txt').write_text('retain this')
        (web / 'router-fw.html').write_text('old webpage')
        (self.source / 'bitsailor.core').write_text('new core')
        (self.source / 'polars/new-boat.csv').write_text('new default polar')
        # update used to fail on this repository's absent races directory.
        self.make('update')
        self.assertEqual(before, {path: (path.read_bytes(), path.stat().st_mtime_ns) for path in protected})
        self.assertEqual((web / 'router-fw.html').read_text(), 'new webpage')
        self.assertEqual((web / 'local-file.txt').read_text(), 'retain this')
        self.assertEqual((config / 'polars/new-boat.csv').read_text(), 'new default polar')
        self.assertEqual((self.stage / 'usr/local/bitsailor/bitsailor.core').read_text(), 'new core')
        (self.source / 'races').mkdir()
        (self.source / 'races/course.txt').write_text('default course')
        self.make('install')
        (config / 'races/course.txt').write_text('custom course')
        self.make('update')
        self.assertEqual((config / 'races/course.txt').read_text(), 'custom course')
        self.assertEqual(before, {path: (path.read_bytes(), path.stat().st_mtime_ns) for path in protected})
        self.assertEqual((self.checkout / 'builds.log').read_text().count('built'), 4)

    def test_webfiles_builds_tiles_without_seeding_or_changing_configs(self):
        self.make('webfiles')
        config = self.stage / 'etc/bitsailor'
        self.assertTrue((config / 'web/bathymetry/channel-2024/manifest.json').exists())
        self.assertFalse((config / 'bitsailor.conf').exists())
        self.assertFalse((self.stage / 'usr').exists())

    def test_failed_preparation_stops_deployment(self):
        self.make('install', 'FAIL_ASSETS=1', success=False)
        self.assertFalse(self.stage.exists())
        self.make('install')
        core = self.stage / 'usr/local/bitsailor/bitsailor.core'
        web = self.stage / 'etc/bitsailor/web/router-fw.html'
        before = (core.read_bytes(), web.read_bytes())
        (self.source / 'bitsailor.core').write_text('must not deploy')
        (self.checkout / 'web/router-fw.html').write_text('must not deploy')
        self.make('update', 'FAIL_ASSETS=1', success=False)
        self.assertEqual(before, (core.read_bytes(), web.read_bytes()))

    def test_config_symlinks_are_preserved(self):
        config = self.stage / 'etc/bitsailor'
        config.mkdir(parents=True)
        (config / 'bitsailor.conf').symlink_to('operator.conf')
        (config / 'operator.conf').write_text('operator settings')
        (config / 'server-config.cl').symlink_to('not-yet-mounted.cl')
        self.make('install')
        self.assertTrue((config / 'bitsailor.conf').is_symlink())
        self.assertEqual((config / 'operator.conf').read_text(), 'operator settings')
        self.assertTrue((config / 'server-config.cl').is_symlink())
        self.assertFalse((config / 'not-yet-mounted.cl').exists())

    def test_old_checkout_fails_with_actionable_message(self):
        old = self.root / 'old-checkout'
        old.mkdir()
        result = self.make('webfiles', f'BITSAILOR_DIR={old}', success=False)
        self.assertIn('up-to-date Bitsailor checkout', result.stderr)
        self.assertFalse(self.stage.exists())

    def test_live_update_control_flow_uses_only_stub_systemctl(self):
        self.make('install')
        calls = self.root / 'service-calls'
        self.systemctl.write_text(f'#!/bin/sh\nprintf "%s\\n" "$*" >> "{calls}"\n')
        # Exercise the non-staged branch while redirecting every deployment
        # directory into the same disposable tree and systemctl to our stub.
        overrides = ['DESTDIR=',
                     f'BINDIR={self.stage}/usr/local/bitsailor',
                     f'CONFDIR={self.stage}/etc/bitsailor',
                     f'DATADIR={self.stage}/srv/bitsailor',
                     f'LOGDIR={self.stage}/var/log/bitsailor',
                     f'SYSTEMD_UNIT_DIR={self.stage}/etc/systemd/system']
        self.make('update', *overrides)
        self.assertEqual(calls.read_text().splitlines(), ['daemon-reload', 'restart bitsailor'])
        before = calls.read_text()
        self.make('update', *overrides, 'FAIL_ASSETS=1', success=False)
        self.assertEqual(calls.read_text(), before)


if __name__ == '__main__':
    unittest.main()
