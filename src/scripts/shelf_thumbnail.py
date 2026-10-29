#!/usr/bin/env python3
"""Bounded local previews for shelf files. Originals are never modified."""
import hashlib,json,mimetypes,os,subprocess,sys,tempfile,zipfile
from pathlib import Path
from urllib.parse import urlparse,unquote
from xml.etree import ElementTree
from PIL import Image,ImageDraw,ImageFont,ImageOps

def text_preview(text,out):
    image=Image.new('RGB',(256,180),'#252830');draw=ImageDraw.Draw(image)
    try: font=ImageFont.truetype('/usr/share/fonts/TTF/DejaVuSans.ttf',12)
    except OSError: font=ImageFont.load_default()
    for i,line in enumerate(text.splitlines()[:10]): draw.text((12,10+i*16),line[:34],font=font,fill='#e8edf4')
    image.save(out)

def preview(uri):
    parsed=urlparse(uri)
    if parsed.scheme!='file' or parsed.netloc not in ('','localhost'):return {'uri':uri,'path':'','kind':''}
    path=Path(unquote(parsed.path));stat=path.stat()
    if not path.is_file() or stat.st_size>512*1024*1024:raise ValueError('Unsupported size')
    mime=mimetypes.guess_type(path.name)[0] or ''
    key=hashlib.sha256(f'v1:{path}:{stat.st_mtime_ns}:{stat.st_size}'.encode()).hexdigest()
    ram=path.parent.parent==Path('/dev/shm') and path.parent.name.startswith('serpantinum-image-links-')
    cache=path.parent if ram else Path(os.environ.get('XDG_CACHE_HOME',Path.home()/'.cache'))/'serpantinum/shelf-thumbnails'
    cache.mkdir(parents=True,exist_ok=True)
    output=Path(str(path)+'.preview.png') if ram else cache/(key+'.png')
    kind='image' if mime.startswith('image/') else 'video' if mime.startswith('video/') else 'document'
    if output.is_file():return {'uri':uri,'path':output.as_uri(),'kind':kind}
    with tempfile.TemporaryDirectory(dir=cache) as directory:
        temp=Path(directory)/'preview.png'
        if mime.startswith('image/'):
            with Image.open(path) as image:
                image=ImageOps.exif_transpose(image).convert('RGB');image.thumbnail((256,180));image.save(temp)
        elif mime.startswith('video/'):
            subprocess.run(['ffmpeg','-v','error','-nostdin','-y','-ss','0','-i',str(path),'-frames:v','1','-vf','scale=256:180:force_original_aspect_ratio=decrease',str(temp)],check=True,timeout=12,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        elif path.suffix.lower()=='.pdf':
            subprocess.run(['pdftoppm','-f','1','-singlefile','-scale-to','256','-png',str(path),str(temp.with_suffix(''))],check=True,timeout=12,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        elif path.suffix.lower() in ('.docx','.odt'):
            member='word/document.xml' if path.suffix.lower()=='.docx' else 'content.xml'
            with zipfile.ZipFile(path) as archive:
                if archive.getinfo(member).file_size>2*1024*1024:raise ValueError('Document too large')
                xml=ElementTree.fromstring(archive.read(member));text='\n'.join(t for t in xml.itertext() if t.strip())
            text_preview(text,temp)
        elif mime.startswith('text/') or path.suffix.lower() in ('.md','.json','.yaml','.toml','.log'):
            with path.open('r',errors='replace') as stream:text=stream.read(8192)
            text_preview(text,temp)
        else:raise ValueError('No preview handler')
        if ram and not path.exists():raise ValueError("Temporary media expired")
        temp.replace(output)
    return {'uri':uri,'path':output.as_uri(),'kind':kind}
if __name__=='__main__':
    uri=sys.argv[1]
    try: result=preview(uri)
    except Exception: result={'uri':uri,'path':'','kind':''}
    print(json.dumps(result))
