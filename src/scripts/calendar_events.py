#!/usr/bin/env python3
"""Local iCalendar import and bounded, timezone-aware upcoming event queries."""
import hashlib,itertools,json,os,sys,tempfile
from datetime import datetime,date,time,timedelta
from pathlib import Path
from urllib.parse import urlparse,unquote
from zoneinfo import ZoneInfo
from icalendar import Calendar
import recurring_ical_events
ROOT=Path(os.environ.get('QS_CALENDARS',str(Path.home()/'.local/share/serpantinum/calendars')))
def timezone():
 try:return ZoneInfo(str(Path('/etc/localtime').resolve().relative_to('/usr/share/zoneinfo')))
 except ValueError:return datetime.now().astimezone().tzinfo

def import_calendar(url):
 parsed=urlparse(url)
 if parsed.scheme and (parsed.scheme!='file' or parsed.netloc not in ['', 'localhost']):raise ValueError('Choose a local .ics file.')
 path=Path(unquote(parsed.path) if parsed.scheme else url)
 if not path.is_file() or path.suffix.lower()!='.ics' or path.stat().st_size>4*1024*1024:raise ValueError('Choose an .ics file smaller than 4 MB.')
 data=path.read_bytes();Calendar.from_ical(data)
 ROOT.mkdir(parents=True,mode=0o700,exist_ok=True)
 dest=ROOT/(hashlib.sha256(data).hexdigest()[:20]+'.ics')
 fd,temp=tempfile.mkstemp(dir=ROOT,prefix='.import-')
 try:
  with os.fdopen(fd,'wb') as out:out.write(data)
  os.replace(temp,dest)
 finally:
  if os.path.exists(temp):os.unlink(temp)

def upcoming(now=None):
 zone=timezone();now=now or datetime.now(zone);stop=now+timedelta(days=31);events=[];seen=set();errors=[]
 files=sorted(ROOT.glob('*.ics'))[:20]
 for folder in [Path.home()/'.local/share/evolution/calendar',Path.home()/'.cache/evolution/calendar']:
  if folder.is_dir():files.extend(list(folder.rglob('*.ics'))[:20])
 for path in files[:40]:
  try:
   if path.stat().st_size>4*1024*1024:continue
   cal=Calendar.from_ical(path.read_bytes())
   for event in itertools.islice(recurring_ical_events.of(cal,skip_bad_series=True).after(now),128):
    if str(event.get('STATUS','')).upper()=='CANCELLED':continue
    start=event.decoded('DTSTART');end=event.decoded('DTEND',start);all_day=not isinstance(start,datetime)
    if all_day:start=datetime.combine(start,time.min,zone)
    elif start.tzinfo is None:start=start.replace(tzinfo=zone)
    start=start.astimezone(zone)
    if not isinstance(end,datetime):end=datetime.combine(end,time.min,zone)
    elif end.tzinfo is None:end=end.replace(tzinfo=zone)
    if start>stop:break
    if end<=now and start<now:continue
    key=(str(event.get('UID','')),start.isoformat(),str(event.get('SUMMARY','')))
    if key in seen:continue
    seen.add(key);events.append({'title':str(event.get('SUMMARY','Untitled event'))[:200],'start':start.isoformat(),'allDay':all_day,'location':str(event.get('LOCATION',''))[:200]})
  except Exception:errors.append(path.name)
 return {'events':sorted(events,key=lambda e:e['start'])[:32],'calendars':len(files),'error':'Some calendar files could not be read.' if errors else ''}
if __name__=='__main__':
 try:
  if len(sys.argv)>1 and sys.argv[1]=='import':import_calendar(sys.argv[2])
  print(json.dumps(upcoming()))
 except Exception:print(json.dumps({'events':[],'error':'Could not read this calendar. Choose a valid local .ics file.'}))
