#!/usr/bin/env python3
"""Observe the existing recorder's PID/start files without starting a recording."""
import json,os,sys,time
from pathlib import Path

def status(directory):
    try:
        directory=Path(directory)
        pid=int((directory/'rec_pid').read_text().strip())
        started=int((directory/'rec_start_epoch').read_text().strip())
        if pid<=1 or started<=0 or started>time.time()+5:return {'active':False,'started':0}
        os.kill(pid,0)
        # A terminated recorder can remain as a zombie until its parent reaps it.
        stat=Path('/proc')/str(pid)/'stat'
        if stat.exists() and stat.read_text().rsplit(')',1)[1].split()[0]=='Z':return {'active':False,'started':0}
        return {'active':True,'started':started}
    except (OSError,ValueError,IndexError):return {'active':False,'started':0}

def main():
    previous=None
    while True:
        current=status(sys.argv[1])
        if current!=previous:print(json.dumps(current),flush=True);previous=current
        time.sleep(.5)

if __name__=='__main__':main()
