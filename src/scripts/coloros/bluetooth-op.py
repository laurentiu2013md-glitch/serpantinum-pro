#!/usr/bin/env python3
import dbus,json,sys
try:
    action,path=sys.argv[1:3]; bus=dbus.SystemBus();obj=bus.get_object('org.bluez',path)
    props=dbus.Interface(obj,'org.freedesktop.DBus.Properties')
    if action=='power-on' or action=='power-off': props.Set('org.bluez.Adapter1','Powered',dbus.Boolean(action=='power-on'))
    elif action=='scan': dbus.Interface(obj,'org.bluez.Adapter1').StartDiscovery(timeout=8)
    elif action=='stop-scan': dbus.Interface(obj,'org.bluez.Adapter1').StopDiscovery(timeout=8)
    elif action=='forget':
        adapter=props.Get('org.bluez.Device1','Adapter')
        dbus.Interface(bus.get_object('org.bluez',adapter),'org.bluez.Adapter1').RemoveDevice(dbus.ObjectPath(path),timeout=12)
    else:
        dev=dbus.Interface(obj,'org.bluez.Device1')
        if action=='pair':
            dev.Pair(timeout=45)
            props.Set('org.bluez.Device1','Trusted',dbus.Boolean(True))
            dev.Connect(timeout=30)
        elif action=='connect':dev.Connect(timeout=30)
        elif action=='disconnect':dev.Disconnect(timeout=15)
        else:raise ValueError('Unsupported Bluetooth action')
    print(json.dumps({'ok':True,'action':action}))
except Exception as e:print(json.dumps({'ok':False,'error':str(e)}));sys.exit(1)
