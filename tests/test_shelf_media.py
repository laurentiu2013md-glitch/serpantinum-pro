"""Only shelf-owned RAM media may be expired; ordinary files must survive."""
from pathlib import Path
import json,sys,tempfile,time,unittest
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'src/scripts'))
import shelf_ram
import shelf_download

class ShelfMediaTests(unittest.TestCase):
    def test_page_media_candidates(self):
        page=shelf_download.MediaPage()
        page.feed('<meta property="og:image" content="/preview.png"><video><source src="/clip.mp4"></video>')
        self.assertEqual(page.videos,['/clip.mp4']);self.assertEqual(page.images,['/preview.png'])

    def test_rejects_non_web_sources(self):
        for url in ['file:///etc/passwd','ftp://localhost/video.mp4','data:text/html,hello']:
            with self.assertRaises(ValueError):shelf_download.download(url)

    def test_expiry_is_delayed_cancellable_and_scoped(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(shelf_ram.subprocess,'Popen') as spawn:
            root=Path(directory)/'ram';root.mkdir();media=root/'dropshelf-fixture.mp4';media.write_bytes(b'fixture')
            original=Path(directory)/'original.mp4';original.write_bytes(b'original')
            with patch.object(shelf_ram,'ROOT',root):
                shelf_ram.apply('schedule',[media.as_uri(),original.as_uri()]);spawn.assert_called_once()
                payload=json.loads(spawn.call_args.args[0][3]);self.assertGreater(payload[2],time.time()+4)
                self.assertTrue(media.exists());shelf_ram.apply('cancel',[media.as_uri()])
                shelf_ram.apply('expire',[media.as_uri(),payload[1],0]);self.assertTrue(media.exists())
                shelf_ram.marker(media).write_text('valid');preview=Path(str(media)+'.preview.png');preview.write_bytes(b'preview')
                shelf_ram.apply('expire',[media.as_uri(),'valid',0])
                self.assertFalse(media.exists());self.assertFalse(preview.exists());self.assertTrue(original.exists())

    def test_clear_schedules_only_owned_files(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(shelf_ram.subprocess,'Popen') as spawn:
            root=Path(directory);media=root/'dropshelf-fixture.png';media.write_bytes(b'fixture');other=root/'original.png';other.write_bytes(b'original')
            with patch.object(shelf_ram,'ROOT',root):shelf_ram.apply('clear',[])
            spawn.assert_called_once();self.assertTrue(media.exists());self.assertTrue(other.exists())
