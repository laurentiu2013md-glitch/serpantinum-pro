"""Preview helpers only read generated test files and write to an isolated cache."""
import importlib.util,json,os,shutil,subprocess,tempfile,unittest,zipfile
from pathlib import Path
from unittest.mock import patch
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
def load(name):
    spec=importlib.util.spec_from_file_location(name,ROOT/'src/scripts'/(name+'.py'))
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);return module
thumbnail=load('shelf_thumbnail');art=load('artwork_luminance')

class PreviewTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.root=Path(self.temp.name)
        self.env=patch.dict(os.environ,{'XDG_CACHE_HOME':str(self.root/'cache')});self.env.start()
    def tearDown(self):self.env.stop();self.temp.cleanup()
    def test_image_orientation_size_and_cache(self):
        path=self.root/'photo.png';Image.new('RGB',(500,300),'red').save(path)
        result=thumbnail.preview(path.as_uri());out=Path(result['path'].removeprefix('file://'))
        with Image.open(out) as image:self.assertLessEqual(image.width,256);self.assertLessEqual(image.height,180)
        before=out.stat().st_mtime_ns;thumbnail.preview(path.as_uri());self.assertEqual(before,out.stat().st_mtime_ns)
    def test_remote_urls_are_not_fetched(self):
        self.assertEqual(thumbnail.preview('https://invalid.example/photo.png')['path'],'')
        self.assertEqual(art.measure('https://invalid.example/photo.png'),.35)
    def test_text_and_document_previews(self):
        text=self.root/'note.md';text.write_text('Readable document\nSecond line\n')
        self.assertEqual(thumbnail.preview(text.as_uri())['kind'],'document')
        doc=self.root/'paper.docx'
        with zipfile.ZipFile(doc,'w') as archive:archive.writestr('word/document.xml','<document><p>Hello from a document</p></document>')
        self.assertTrue(thumbnail.preview(doc.as_uri())['path'])
    @unittest.skipUnless(shutil.which('ffmpeg'),'ffmpeg unavailable')
    def test_video_frame_preview(self):
        video=self.root/'sample.mp4'
        subprocess.run(['ffmpeg','-v','error','-y','-f','lavfi','-i','color=c=blue:s=48x32:d=0.2','-pix_fmt','yuv420p',str(video)],check=True)
        self.assertEqual(thumbnail.preview(video.as_uri())['kind'],'video')
    @unittest.skipUnless(shutil.which('pdftoppm'),'pdftoppm unavailable')
    def test_pdf_first_page_preview(self):
        objects=[b'<< /Type /Catalog /Pages 2 0 R >>',b'<< /Type /Pages /Kids [3 0 R] /Count 1 >>',b'<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] /Contents 4 0 R >>',b'<< /Length 0 >>\nstream\n\nendstream']
        data=bytearray(b'%PDF-1.4\n');offsets=[0]
        for i,obj in enumerate(objects,1):offsets.append(len(data));data.extend(f'{i} 0 obj\n'.encode()+obj+b'\nendobj\n')
        xref=len(data);data.extend(f'xref\n0 {len(offsets)}\n0000000000 65535 f \n'.encode())
        for offset in offsets[1:]:data.extend(f'{offset:010d} 00000 n \n'.encode())
        data.extend(f'trailer\n<< /Root 1 0 R /Size {len(offsets)} >>\nstartxref\n{xref}\n%%EOF\n'.encode())
        pdf=self.root/'page.pdf';pdf.write_bytes(data)
        self.assertTrue(thumbnail.preview(pdf.as_uri())['path'])
    def test_luminance_distinguishes_bright_and_dark_art(self):
        white=self.root/'white.png';black=self.root/'black.png'
        Image.new('RGB',(10,10),'white').save(white);Image.new('RGB',(10,10),'black').save(black)
        self.assertAlmostEqual(art.measure(white.as_uri()),1);self.assertEqual(art.measure(black.as_uri()),0)
