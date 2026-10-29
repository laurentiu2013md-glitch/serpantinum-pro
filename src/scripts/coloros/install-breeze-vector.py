#!/usr/bin/env python3
from pathlib import Path
import json,shutil,xml.etree.ElementTree as ET,subprocess,tempfile,atexit
source=Path('/usr/share/icons/breeze_cursors');work=Path(tempfile.mkdtemp(prefix='breeze-vector-'));stage=work/'Breeze-Vector';stage.mkdir(exist_ok=True);atexit.register(shutil.rmtree,work,True)
(stage/'manifest.hl').write_text('name = Breeze-Vector\ndescription = KDE Breeze Dark, vector rendering with high-resolution fallback\nversion = 1\ncursors_directory = hyprcursors\n')
aliases={}
for p in (source/'cursors_scalable').iterdir():
 if p.is_symlink():aliases.setdefault(p.resolve().name,[]).append(p.name)
count=0
for p in (source/'cursors_scalable').iterdir():
 if not p.is_dir() or p.is_symlink():continue
 frames=json.loads((p/'metadata.json').read_text());target=stage/'hyprcursors'/p.name;target.mkdir(parents=True,exist_ok=True)
 svg=ET.parse(p/frames[0]['filename']).getroot();width=float(svg.attrib['width']);height=float(svg.attrib['height']);assert width==height
 f=frames[0];lines=['resize_algorithm = bilinear',f'hotspot_x = {f["hotspot_x"]/width}',f'hotspot_y = {f["hotspot_y"]/height}',f'nominal_size = {f["nominal_size"]/width}']
 for alias in aliases.get(p.name,[]):lines.append('define_override = '+alias)
 for frame in frames:
  shutil.copy2(p/frame['filename'],target/frame['filename']);lines.append('define_size = 0, '+frame['filename']+', '+str(frame.get('delay',0)))
 (target/'meta.hl').write_text('\n'.join(lines)+'\n');count+=1

if not (work/'theme_Breeze-Vector').exists():
 subprocess.run(['hyprcursor-util','--create',str(stage),'--output',str(work)],check=True,stdout=subprocess.DEVNULL)
dest=Path.home()/'.local/share/icons/Breeze-Vector';shutil.copytree(work/'theme_Breeze-Vector',dest,dirs_exist_ok=True)
if not (dest/'cursors_scalable').exists():shutil.copytree(source/'cursors_scalable',dest/'cursors_scalable',symlinks=True)
(dest/'index.theme').write_text('[Icon Theme]\nName=Breeze Dark Vector\nComment=KDE Breeze Dark artwork, scalable Hyprcursor with high-resolution XCursor fallback\nInherits=breeze_cursors\n')
# Render the same SVG artwork at native requested sizes for legacy clients.
import gi,struct,cairo
gi.require_version('Rsvg','2.0')
from gi.repository import Rsvg
for shape in (source/'cursors_scalable').iterdir():
 if shape.is_symlink() or not shape.is_dir():continue
 frames=json.loads((shape/'metadata.json').read_text());chunks=[];toc=[]
 for size in [24,32,48,64,72,96,108,144]:
  for frame in frames:
   svg=ET.parse(shape/frame['filename']).getroot();factor=size/frame['nominal_size'];width=round(float(svg.attrib['width'])*factor);height=round(float(svg.attrib['height'])*factor)
   image=cairo.ImageSurface(cairo.FORMAT_ARGB32,width,height);cr=cairo.Context(image)
   rect=Rsvg.Rectangle();rect.x=0;rect.y=0;rect.width=width;rect.height=height
   Rsvg.Handle.new_from_file(str(shape/frame['filename'])).render_document(cr,rect)
   image.flush();pixels=bytes(image.get_data())
   chunk=struct.pack('<9I',36,0xfffd0002,size,1,width,height,round(frame['hotspot_x']*factor),round(frame['hotspot_y']*factor),frame.get('delay',0))+pixels
   chunks.append((size,chunk))
 offset=16+len(chunks)*12
 for size,chunk in chunks:toc.append(struct.pack('<3I',0xfffd0002,size,offset));offset+=len(chunk)
 (dest/'cursors').mkdir(exist_ok=True)
 (dest/'cursors'/shape.name).write_bytes(struct.pack('<4I',0x72756358,16,0x10000,len(chunks))+b''.join(toc)+b''.join(chunk for size,chunk in chunks))
for target,names in aliases.items():
 for alias in names:
  path=dest/'cursors'/alias
  if not path.exists() and not path.is_symlink():path.symlink_to(target)
print(f'Built {count} SVG shapes and matching XCursor fallbacks in {dest}')
