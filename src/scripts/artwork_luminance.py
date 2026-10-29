#!/usr/bin/env python3
"""Read average local artwork luminance; never fetch remote URLs."""
import json,sys
from pathlib import Path
from urllib.parse import unquote,urlparse
from PIL import Image,ImageStat

def measure(url):
    parsed=urlparse(url)
    if parsed.scheme not in ('','file') or parsed.netloc not in ('','localhost'):
        return .35
    path=Path(unquote(parsed.path))
    if not path.is_file() or path.stat().st_size > 32*1024*1024:
        return .35
    with Image.open(path) as image:
        image=image.convert('RGB');image.thumbnail((32,32))
        rgb=ImageStat.Stat(image).mean
        return sum(a*b for a,b in zip(rgb,(.2126,.7152,.0722)))/255
if __name__=='__main__':
    url=sys.argv[1]
    try: luminance=measure(url)
    except Exception: luminance=.35
    print(json.dumps({'url':url,'luminance':luminance}))
