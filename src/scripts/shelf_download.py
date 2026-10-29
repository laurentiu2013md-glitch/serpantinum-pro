#!/usr/bin/env python3
"""Download bounded image/video media, including media embedded in a linked page, to RAM."""
import mimetypes, os, signal, subprocess, sys, tempfile, time
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urljoin, urlparse
from urllib.request import Request, urlopen, build_opener, HTTPRedirectHandler
from shelf_ram import ROOT, apply
MAX_BYTES = 128 * 1024 * 1024

class MediaPage(HTMLParser):
    def __init__(self):
        super().__init__(); self.videos=[]; self.images=[]
    def handle_starttag(self, tag, attrs):
        a=dict(attrs)
        if tag=='meta':
            key=a.get('property',a.get('name','')).lower(); value=a.get('content','')
            if key in ('og:video','og:video:url','og:video:secure_url','twitter:player:stream'): self.videos.append(value)
            if key in ('og:image','og:image:url','og:image:secure_url','twitter:image'): self.images.append(value)
        if tag in ('video','source') and a.get('src'): self.videos.append(a['src'])
        if tag=='img' and a.get('src'): self.images.append(a['src'])

class WebRedirects(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        if urlparse(newurl).scheme not in ('http','https'): raise ValueError('Unsupported redirect')
        return super().redirect_request(req,fp,code,msg,headers,newurl)


def download(url, referer='', depth=0, deadline=None):
    deadline=deadline or time.monotonic()+45
    if urlparse(url).scheme not in ('http','https') or depth>1: raise ValueError('Use a direct media link')
    apply('ensure',[])
    request=Request(url,headers={'User-Agent':'Mozilla/5.0','Referer':referer or url})
    with build_opener(WebRedirects()).open(request,timeout=max(1,min(15,deadline-time.monotonic()))) as response:
        content_type=response.headers.get_content_type()
        if content_type in ('text/html','application/xhtml+xml'):
            if depth: raise ValueError('No downloadable media found')
            page=MediaPage(); page.feed(response.read(2*1024*1024).decode(response.headers.get_content_charset() or 'utf-8','replace'))
            for source in (page.videos+page.images)[:6]:
                try:return download(urljoin(response.url,source),response.url,depth+1,deadline)
                except (ValueError,OSError):continue
            raise ValueError('No downloadable image or video found')
        limit=min(MAX_BYTES,max(0,int(os.statvfs(ROOT).f_bavail*os.statvfs(ROOT).f_frsize*.5)))
        if int(response.headers.get('Content-Length','0'))>limit: raise ValueError('Media exceeds RAM download limit')
        fd,name=tempfile.mkstemp(prefix='dropshelf-',dir=ROOT); path=Path(name)
        try:
            total=0
            with os.fdopen(fd,'wb') as output:
                while True:
                    if time.monotonic()>deadline: raise ValueError('Download timed out')
                    chunk=response.read(128*1024)
                    if not chunk:break
                    total+=len(chunk)
                    if total>limit:raise ValueError('Media exceeds RAM download limit')
                    output.write(chunk)
            mime=subprocess.check_output(['file','-Lb','--mime-type',str(path)],text=True,timeout=3).strip()
            if not mime.startswith(('image/','video/')):raise ValueError('Link is not an image or video')
            extension={'image/jpeg':'.jpg','video/quicktime':'.mov','image/svg+xml':'.svg'}.get(mime) or mimetypes.guess_extension(mime) or '.media'
            final=path.with_name(path.name+extension); path.rename(final); return final
        finally:path.unlink(missing_ok=True)

if __name__=='__main__':
    def cancel(*_):raise InterruptedError('Cancelled')
    signal.signal(signal.SIGTERM,cancel)
    try:print(download(sys.argv[1],sys.argv[2] if len(sys.argv)>2 else ''))
    except (ValueError,OSError,subprocess.SubprocessError):sys.exit(65)
