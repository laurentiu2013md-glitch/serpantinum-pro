"""Exercise desktop palette output without changing the real desktop."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / 'src/scripts/coloros/sync-theme.py'


class DesktopPaletteTests(unittest.TestCase):
    def test_modes_preserve_kitty_background_and_install_scoped_nautilus_style(self):
        spec = importlib.util.spec_from_file_location('desktop_palette', SCRIPT)
        palette = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(palette)
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            kitty = home / '.config/kitty'
            kitty.mkdir(parents=True)
            (kitty / 'colors.conf').write_text('background #aabbcc\n')
            (kitty / 'kitty.conf').write_text('background_opacity 0.45\n')
            state = home / '.local/state/serpantinum/qs_matugen_colors.json'
            state.parent.mkdir(parents=True)
            with patch.object(palette, 'HOME', home), patch.object(palette.subprocess, 'run'):
                for background, foreground, mode in [('#202020', '#ffffff', 'dark'), ('#eeeeee', '#101010', 'light'), ('#202020', '#101010', 'gray')]:
                    settings = home / '.config/serpantinum/settings.json'
                    settings.parent.mkdir(parents=True, exist_ok=True)
                    settings.write_text(json.dumps({'theme': {'mode': mode}}))
                    state.write_text(json.dumps({'base': background, 'mauve': '#725188'}))
                    palette.main()
                    palette.main()
                    css = (home / '.config/gtk-4.0/nautilus-colors.css').read_text()
                    self.assertIn('alpha(#aabbcc, 0.45)', css)
                    self.assertIn('nautilus_fg ' + foreground, css)
                    if mode == 'gray':
                        self.assertIn('@define-color window_bg_color #808080;', (home / '.config/gtk-4.0/coloros-colors.css').read_text())
                    style = (home / '.config/gtk-4.0/coloros-nautilus.css').read_text()
                    self.assertIn('window.nautilus-window', style)
                    self.assertIn('backdrop-filter: blur(16px)', style)
                    gtk = (home / '.config/gtk-4.0/gtk.css').read_text()
                    self.assertEqual(gtk.count("@import 'coloros-nautilus.css';"), 1)
                    config = (kitty / 'kitty.conf').read_text()
                    self.assertIn('background_opacity 0.45', config)
                    self.assertEqual(config.count('include ~/.config/kitty/coloros-text.conf'), 1)
                    self.assertEqual((kitty / 'coloros-text.conf').read_text(), 'foreground ' + foreground + '\n')
                    self.assertEqual((kitty / 'colors.conf').read_text(), 'background #aabbcc\n')


if __name__ == '__main__':
    unittest.main()
