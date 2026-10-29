"""Recorder markers must track live recorder state and clear stale PID files."""
import importlib.util,os,tempfile,time,unittest
from pathlib import Path
spec=importlib.util.spec_from_file_location('recording_status',Path(__file__).resolve().parents[1]/'src/scripts/recording_status.py')
helper=importlib.util.module_from_spec(spec);spec.loader.exec_module(helper)

class RecordingStatusTests(unittest.TestCase):
    def test_live_recording_and_stop(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);started=int(time.time())-8
            (root/'rec_pid').write_text(str(os.getpid()));(root/'rec_start_epoch').write_text(str(started))
            self.assertEqual(helper.status(root),{'active':True,'started':started})
            (root/'rec_pid').unlink();self.assertFalse(helper.status(root)['active'])

    def test_missing_invalid_and_dead_recorder(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);self.assertFalse(helper.status(root)['active'])
            (root/'rec_start_epoch').write_text(str(int(time.time())))
            for pid in ['invalid','1','0','-1','2147483647']:
                (root/'rec_pid').write_text(pid);self.assertFalse(helper.status(root)['active'])

    def test_future_timestamp_does_not_claim_recording(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);(root/'rec_pid').write_text(str(os.getpid()));(root/'rec_start_epoch').write_text(str(int(time.time())+600))
            self.assertFalse(helper.status(root)['active'])
