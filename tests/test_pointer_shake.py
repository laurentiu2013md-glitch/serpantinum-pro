"""Verify pointer zones and the native-renderer control contract without a compositor."""
import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch
path=Path(__file__).resolve().parents[1]/'src/quickshell/bar/pointer-zone.py'
spec=importlib.util.spec_from_file_location('pointer_zone',path)
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)

class PointerTests(unittest.TestCase):
    monitor={'name':'screen','x':0,'y':0,'width':2560,'height':1600,'scale':2}
    def test_scaled_monitor_boundary(self):
        self.assertTrue(module.zones([self.monitor],{'x':400,'y':70})['screen'])
        self.assertFalse(module.zones([self.monitor],{'x':400,'y':90})['screen'])
    def test_boundary_hysteresis(self):
        self.assertTrue(module.zones([self.monitor],{'x':400,'y':82},{'screen':True})['screen'])
        self.assertFalse(module.zones([self.monitor],{'x':400,'y':78},{'screen':False})['screen'])
    def test_disabled_monitor_is_ignored(self):
        self.assertEqual(module.zones([dict(self.monitor,disabled=True)],{'x':0,'y':0}),{})
    def test_native_control_never_changes_cursor_theme(self):
        with patch.object(module,'query',return_value=[{'name':'dynamic-cursors'}]),patch.object(module,'command') as command:
            effect=module.NativeCursorEffect(None);effect.enable(True);effect.locate();effect.enable(False)
            calls=[c.args[1] for c in command.call_args_list]
            self.assertTrue(any('dsp_magnify' in c and 'size=3.0' in c for c in calls))
            self.assertTrue(any('size=1.0' in c for c in calls));self.assertIn('enabled=false',calls[-1])
            self.assertFalse(any('setcursor' in c for c in calls))
            self.assertEqual(effect.scale,1)
    def test_missing_plugin_does_not_fake_enlargement(self):
        with patch.object(module,'query',return_value=[]),patch.object(module,'command') as command:
            effect=module.NativeCursorEffect(None);effect.enable(True);effect.locate()
            command.assert_not_called();self.assertFalse(effect.available)
    def test_native_toggle_is_idempotent(self):
        with patch.object(module,'query',return_value=[{'name':'dynamic-cursors'}]),patch.object(module,'command') as command:
            effect=module.NativeCursorEffect(None);effect.enable(False);effect.enable(False)
            self.assertEqual(command.call_count,2)
