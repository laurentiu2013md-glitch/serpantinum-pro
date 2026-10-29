#!/usr/bin/env python3
"""Stream low-cost live sysfs power readings while the battery view is open."""
import json,os,time
from pathlib import Path
ROOT=Path(os.environ.get('QS_BATTERY_SYSFS','/sys/class/power_supply'))
def number(path):
 try:return float(path.read_text().strip())
 except (OSError,ValueError):return None

def sample(root=ROOT):
 batteries=[]
 for battery in root.glob('*'):
  try:
   if (battery/'type').read_text().strip()!='Battery':continue
  except OSError:continue
  watts=number(battery/'power_now')
  if watts is not None:watts=abs(watts)/1e6
  else:
   current=number(battery/'current_now');voltage=number(battery/'voltage_now')
   watts=abs(current*voltage)/1e12 if current is not None and voltage is not None else None
  if watts is not None:batteries.append(watts)
 return {'watts':round(sum(batteries),3) if batteries else None}
if __name__=='__main__':
 try:
  while True:
   print(json.dumps(sample()),flush=True);time.sleep(.5)
 except (BrokenPipeError,KeyboardInterrupt):pass
