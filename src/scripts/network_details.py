#!/usr/bin/env python3
"""Read live NetworkManager link details; create private, short-lived Wi-Fi QR images."""
import json,os,subprocess,sys
from pathlib import Path
from gi.repository import Gio,GLib
BUS='org.freedesktop.NetworkManager';BASE='/org/freedesktop/NetworkManager'
def get(bus,path,interface,key):
 return bus.call_sync(BUS,path,'org.freedesktop.DBus.Properties','Get',GLib.Variant('(ss)',(interface,key)),GLib.VariantType('(v)'),Gio.DBusCallFlags.NONE,4000,None).unpack()[0]
def escape(value):
 return ''.join('\\'+c if c in '\\;,:"' else c for c in value)
def payload(ssid,password,security,hidden=False):
 return f'WIFI:T:{security};S:{escape(ssid)};P:{escape(password)};H:{str(hidden).lower()};;'
def folder():
 path=Path(os.environ.get('XDG_RUNTIME_DIR','/tmp'))/f'serpantinum-wifi-{os.getuid()}';path.mkdir(mode=0o700,exist_ok=True);path.chmod(0o700);return path

def main(action):
 qr=folder()/'share.png'
 if action=='clear':qr.unlink(missing_ok=True);return {}
 bus=Gio.bus_get_sync(Gio.BusType.SYSTEM,None)
 devices=get(bus,BASE,BUS,'Devices')
 for device in devices:
  if get(bus,device,BUS+'.Device','DeviceType')!=2 or get(bus,device,BUS+'.Device','State')!=100:continue
  iface=get(bus,device,BUS+'.Device','Interface');ap=get(bus,device,BUS+'.Device.Wireless','ActiveAccessPoint')
  if ap=='/':continue
  ssid=bytes(get(bus,ap,BUS+'.AccessPoint','Ssid')).decode('utf-8','replace');result={'connected':True,'ssid':ssid,'interface':iface,'signal':get(bus,ap,BUS+'.AccessPoint','Strength'),'mbps':round(get(bus,device,BUS+'.Device.Wireless','Bitrate')/1000,1)}
  if action!='share':return result
  qr.unlink(missing_ok=True)
  active=get(bus,device,BUS+'.Device','ActiveConnection');connection=get(bus,active,BUS+'.Connection.Active','Connection')
  settings=bus.call_sync(BUS,connection,BUS+'.Settings.Connection','GetSettings',None,None,Gio.DBusCallFlags.NONE,4000,None).unpack()[0]
  security=settings.get('802-11-wireless-security',{});keymgmt=security.get('key-mgmt','');password='';kind='nopass'
  if keymgmt in ['wpa-psk','sae']:
   try:secrets=bus.call_sync(BUS,connection,BUS+'.Settings.Connection','GetSecrets',GLib.Variant('(s)',('802-11-wireless-security',)),None,Gio.DBusCallFlags.NONE,4000,None).unpack()[0]
   except GLib.Error:raise ValueError('The saved Wi-Fi password is not available for sharing.')
   password=secrets.get('802-11-wireless-security',{}).get('psk','');kind='WPA'
   if not password:raise ValueError('The saved Wi-Fi password is not available for sharing.')
  elif keymgmt:raise ValueError('QR sharing is available for personal WPA/WPA2/WPA3 and open networks.')
  data=payload(ssid,password,kind,bool(settings.get('802-11-wireless',{}).get('hidden',False)))
  # Credentials pass through stdin only; never command arguments or logs.
  with qr.open('wb') as out:
   qr.chmod(0o600);subprocess.run(['qrencode','-o','-','-t','PNG','-s','7','-m','3'],input=data.encode(),stdout=out,stderr=subprocess.DEVNULL,check=True,timeout=5)
  result['qr']=str(qr);return result
 return {'connected':False}
if __name__=='__main__':
 try:print(json.dumps(main(sys.argv[1] if len(sys.argv)>1 else 'info')))
 except (GLib.Error,ValueError,OSError,subprocess.SubprocessError):print(json.dumps({'error':'Unable to read connection details or share this saved network. Enterprise networks cannot be shared.'}))
