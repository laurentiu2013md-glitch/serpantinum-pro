#!/usr/bin/env python3
"""BlueZ agent; all confirmations go to the shell, never automatically accepted."""
import dbus,dbus.service,dbus.mainloop.glib,json,sys,threading
from gi.repository import GLib
IFACE='org.bluez.Agent1'; pending={}; seq=0
class Rejected(dbus.DBusException):_dbus_error_name='org.bluez.Error.Rejected'
def emit(value):print(json.dumps(value),flush=True)
def request(kind,device,reply,error,**values):
    global seq
    seq+=1;pending.clear();pending[seq]=(kind,reply,error)
    emit(dict(type=kind,token=seq,device=str(device),**values))
class Agent(dbus.service.Object):
    @dbus.service.method(IFACE,in_signature='',out_signature='')
    def Release(self):emit({'type':'released'})
    @dbus.service.method(IFACE,in_signature='o',out_signature='s',async_callbacks=('reply','error'))
    def RequestPinCode(self,device,reply,error):request('pin',device,reply,error)
    @dbus.service.method(IFACE,in_signature='o',out_signature='u',async_callbacks=('reply','error'))
    def RequestPasskey(self,device,reply,error):request('passkey',device,reply,error)
    @dbus.service.method(IFACE,in_signature='ou',out_signature='',async_callbacks=('reply','error'))
    def RequestConfirmation(self,device,passkey,reply,error):request('confirm',device,reply,error,passkey=f'{int(passkey):06d}')
    @dbus.service.method(IFACE,in_signature='o',out_signature='',async_callbacks=('reply','error'))
    def RequestAuthorization(self,device,reply,error):request('authorize',device,reply,error)
    @dbus.service.method(IFACE,in_signature='os',out_signature='',async_callbacks=('reply','error'))
    def AuthorizeService(self,device,uuid,reply,error):request('authorize',device,reply,error,service=str(uuid))
    @dbus.service.method(IFACE,in_signature='os',out_signature='')
    def DisplayPinCode(self,device,pincode):emit({'type':'display','device':str(device),'passkey':str(pincode)})
    @dbus.service.method(IFACE,in_signature='ouq',out_signature='')
    def DisplayPasskey(self,device,passkey,entered):emit({'type':'display','device':str(device),'passkey':f'{int(passkey):06d}','entered':int(entered)})
    @dbus.service.method(IFACE,in_signature='',out_signature='')
    def Cancel(self):pending.clear();emit({'type':'cancel'})
def respond(data):
    item=pending.pop(data.get('token'),None)
    if not item:return False
    kind,reply,error=item
    if not data.get('accept'):error(Rejected('Rejected by user'))
    else:
        try:
            if kind=='pin':reply(str(data.get('value','')))
            elif kind=='passkey':reply(dbus.UInt32(int(data.get('value',''))))
            else:reply()
        except Exception:error(Rejected('Invalid pairing code'))
    emit({'type':'cancel'});return False
def stdin():
    for line in sys.stdin:
        try:GLib.idle_add(respond,json.loads(line))
        except Exception:pass
    GLib.idle_add(loop.quit)
dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
bus=dbus.SystemBus();agent=Agent(bus,'/org/serpantinum/ColorOSAgent')
try:
    manager=dbus.Interface(bus.get_object('org.bluez','/org/bluez'),'org.bluez.AgentManager1')
    manager.RegisterAgent('/org/serpantinum/ColorOSAgent','KeyboardDisplay');manager.RequestDefaultAgent('/org/serpantinum/ColorOSAgent')
    emit({'type':'ready'})
except Exception as e:emit({'type':'error','message':str(e)})
loop=GLib.MainLoop();threading.Thread(target=stdin,daemon=True).start();loop.run()
try:manager.UnregisterAgent('/org/serpantinum/ColorOSAgent')
except Exception:pass
