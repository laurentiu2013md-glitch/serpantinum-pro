#!/usr/bin/env python3
"""Display only battery components actually exposed by BlueZ."""
import json,re
from gi.repository import Gio,GLib

def read():
    bus=Gio.bus_get_sync(Gio.BusType.SYSTEM,None)
    data=bus.call_sync('org.bluez','/','org.freedesktop.DBus.ObjectManager','GetManagedObjects',None,GLib.VariantType.new('(a{oa{sa{sv}}})'),Gio.DBusCallFlags.NONE,3000,None).unpack()[0]
    result={}
    for path,interfaces in data.items():
        device=interfaces.get('org.bluez.Device1')
        if not device:continue
        cells=[]
        for child,parts in data.items():
            battery=parts.get('org.bluez.Battery1')
            if not battery or not (child==path or child.startswith(path+'/')):continue
            value=battery.get('Percentage')
            if value is None:continue
            source=str(battery.get('Source',''))+' '+str(parts.get('org.bluez.Device1',{}).get('Alias',''))
            label=next((label for pattern,label in [(r'\bleft\b','Left'),(r'\bright\b','Right'),(r'\bcase\b','Case')] if re.search(pattern,source,re.I)),'Battery')
            cells.append({'label':label,'percentage':max(0,min(100,int(value)))})
        if cells:result[device['Address']]=cells
    return result
if __name__=='__main__':
    try: print(json.dumps(read()))
    except Exception: print('{}')
