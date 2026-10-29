#!/usr/bin/env python3
"""Manage only shelf-owned files in the user's private RAM directory."""
import json,os,re,subprocess,sys,time,uuid
from pathlib import Path
from urllib.parse import unquote,urlparse
ROOT=Path('/dev/shm')/('serpantinum-image-links-'+re.sub(r'[^A-Za-z0-9_.-]','_',os.environ.get('USER','user')))
def owned(uri):
 parsed=urlparse(uri)
 if parsed.scheme!='file' or parsed.netloc not in ('','localhost'):return None
 path=Path(unquote(parsed.path))
 return path if path.parent==ROOT and path.name.startswith('dropshelf-') else None
def marker(path):return path.with_name('.'+path.name+'.expiry')
def erase(path):
 path.unlink(missing_ok=True);Path(str(path)+'.preview.png').unlink(missing_ok=True);marker(path).unlink(missing_ok=True)
def apply(action,uris):
 ROOT.mkdir(mode=0o700,parents=True,exist_ok=True)
 if ROOT.is_symlink() or ROOT.stat().st_uid!=os.getuid():raise ValueError('RAM directory is not owned by this user')
 ROOT.chmod(0o700)
 if action=='expire':
  uri,token,deadline=uris;time.sleep(max(0,deadline-time.time()));path=owned(uri)
  if path and marker(path).exists() and marker(path).read_text()==token:erase(path)
  return {}
 if action=='clear':
  return apply('schedule',[p.as_uri() for p in ROOT.glob('dropshelf-*') if p.is_file() or p.is_symlink()])
 if action in ('remove','schedule','cancel'):
  for uri in uris:
   path=owned(uri)
   if not path:continue
   if action=='cancel':marker(path).unlink(missing_ok=True)
   elif action=='remove':erase(path)
   elif path.exists():
    token=uuid.uuid4().hex;expiry=marker(path)
    if expiry.is_symlink():expiry.unlink()
    expiry.write_text(token);expiry.chmod(0o600)
    subprocess.Popen([sys.executable,str(Path(__file__).resolve()),'expire',json.dumps([uri,token,time.time()+5])],stdin=subprocess.DEVNULL,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,start_new_session=True,close_fds=True)
  return {}
 return {'missing':[uri for uri in uris if owned(uri) and not owned(uri).is_file()]}
if __name__=='__main__':
 try:print(json.dumps(apply(sys.argv[1],json.loads(sys.argv[2]) if len(sys.argv)>2 else [])))
 except (OSError,ValueError):
  print(json.dumps({'error':'RAM media cleanup failed'}));sys.exit(1)
