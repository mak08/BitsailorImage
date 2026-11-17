"""Verify standalone SBCL startup using the service's actual runtime arguments."""
from pathlib import Path
import os
import shlex
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SBCL = shutil.which(os.environ.get('SBCL', 'sbcl'))


class StandaloneRuntimeTests(unittest.TestCase):
    @unittest.skipUnless(SBCL, 'SBCL is required for the runtime smoke test')
    def test_service_runs_embedded_runtime(self):
        line = next(line for line in (ROOT / 'bitsailor.service').read_text().splitlines()
                    if line.startswith('ExecStart='))
        command = shlex.split(line.partition('=')[2])
        self.assertEqual(command[0], '/usr/local/bitsailor/bitsailor.core')
        self.assertNotIn('--core', command)
        with tempfile.TemporaryDirectory(prefix='bitsailor-runtime-') as directory:
            image = Path(directory) / 'smoke.core'
            script = Path(directory) / 'save.lisp'
            script.write_text('''
(sb-ext:save-lisp-and-die "smoke.core" :executable t
  :toplevel (lambda () (format t "EMBEDDED-RUNTIME-OK~%") (sb-ext:exit :code 0)))
''')
            built = subprocess.run([SBCL, '--noinform', '--script', str(script)],
                                   cwd=directory, capture_output=True, text=True, timeout=60)
            self.assertEqual(built.returncode, 0, built.stdout + built.stderr)
            started = subprocess.run([str(image), *command[1:]], cwd=directory,
                                     capture_output=True, text=True, timeout=30)
            self.assertEqual(started.returncode, 0, started.stdout + started.stderr)
            self.assertIn('EMBEDDED-RUNTIME-OK', started.stdout)


if __name__ == '__main__':
    unittest.main()
