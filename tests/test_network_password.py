"""Verify authentication gates access and credentials stay out of arguments."""
import importlib.util
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch
try:
    spec = importlib.util.spec_from_file_location('network_password', Path(__file__).resolve().parents[1] / 'src/scripts/network_password.py')
    helper = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(helper)
except ImportError:
    helper = None

@unittest.skipIf(helper is None, 'PyGObject is required')
class NetworkPasswordTests(unittest.TestCase):
    ident = 'f8197ee4-51aa-4ea0-ac32-d313aa5ad482'

    def test_failed_auth_never_reads_password(self):
        with patch.object(helper, 'verify_root', return_value=False), patch.object(helper, 'saved_password') as read:
            self.assertIn('error', helper.reveal({'uuid': self.ident, 'password': 'fixture'}))
            read.assert_not_called()

    def test_verified_auth_reads_only_selected_connection(self):
        with patch.object(helper, 'verify_root', return_value=True), patch.object(helper, 'saved_password', return_value={'password': 'fixture'}) as read:
            self.assertEqual(helper.reveal({'uuid': self.ident, 'password': 'test-only'}), {'password': 'fixture'})
            read.assert_called_once_with(self.ident)

    def test_auth_uses_private_stdin_and_fixed_command(self):
        with patch.object(helper.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0)) as run:
            self.assertTrue(helper.verify_root('test-only'))
            args = run.call_args
            self.assertNotIn('test-only', str(args.args))
            self.assertEqual(args.kwargs['input'], 'test-only\n')
            self.assertEqual(args.args[0][-3:], ['--command', '/usr/bin/true', 'root'])
            self.assertEqual(args.kwargs['stdout'], subprocess.DEVNULL)
            self.assertNotIn('ENV', args.kwargs['env'])

    def test_invalid_input_never_starts_auth(self):
        with patch.object(helper.subprocess, 'run') as run:
            for value in ['', 'a\nb', 'a\rb', 'a\x00b', 'x' * 4097]:
                self.assertFalse(helper.verify_root(value))
            run.assert_not_called()
        with patch.object(helper, 'verify_root') as auth:
            with self.assertRaises(ValueError):
                helper.reveal({'uuid': 'invalid', 'password': 'fixture'})
            auth.assert_not_called()
