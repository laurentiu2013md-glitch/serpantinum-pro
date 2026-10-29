#!/usr/bin/env python3
"""Advanced saved-network settings, without shell interpolation or credential output."""
import ipaddress,json,subprocess,sys,uuid
from gi.repository import Gio,GLib
BUS='org.freedesktop.NetworkManager';ROOT='/org/freedesktop/NetworkManager/Settings';IFACE=BUS+'.Settings.Connection'
def connections():
 bus=Gio.bus_get_sync(Gio.BusType.SYSTEM,None)
 paths=bus.call_sync(BUS,ROOT,BUS+'.Settings','ListConnections',None,None,Gio.DBusCallFlags.NONE,5000,None).unpack()[0];items=[]
 for path in paths:
  try:d=bus.call_sync(BUS,path,IFACE,'GetSettings',None,None,Gio.DBusCallFlags.NONE,5000,None).unpack()[0]
  except GLib.Error:continue
  c=d.get('connection',{});ip=d.get('ipv4',{})
  if c.get('type') not in ['802-11-wireless','802-3-ethernet']:continue
  addresses=ip.get('address-data',[]);dns=ip.get('dns-data',[])
  if not dns:dns=[str(ipaddress.IPv4Address(int(value).to_bytes(4,sys.byteorder))) for value in ip.get('dns',[])]
  items.append({'uuid':c['uuid'],'name':c.get('id','Network'),'type':c['type'],'autoconnect':c.get('autoconnect',True),'metered':c.get('metered',0)==1,'manual':ip.get('method')=='manual','addresses':', '.join(str(a['address'])+'/'+str(a['prefix']) for a in addresses),'gateway':ip.get('gateway',''),'dns':', '.join(dns)})
 return sorted(items,key=lambda c:c['name'].casefold())
def save(data):
 ident=str(uuid.UUID(data['uuid']))
 if not any(c['uuid']==ident for c in connections()):raise ValueError('The selected connection no longer exists.')
 addresses=[a.strip() for a in data.get('addresses','').split(',') if a.strip()];dns=[d.strip() for d in data.get('dns','').split(',') if d.strip()];gateway=data.get('gateway','').strip()
 if data.get('manual'):
  if not addresses:raise ValueError('Enter at least one IPv4 address and prefix, such as 192.168.1.10/24.')
  for addr in addresses:ipaddress.IPv4Interface(addr)
 if gateway:ipaddress.IPv4Address(gateway)
 for server in dns:ipaddress.IPv4Address(server)
 args=['nmcli','--wait','10','connection','modify','uuid',ident,'connection.autoconnect','yes' if data.get('autoconnect') else 'no','connection.metered','yes' if data.get('metered') else 'no','ipv4.method','manual' if data.get('manual') else 'auto','ipv4.addresses',','.join(addresses) if data.get('manual') else '','ipv4.gateway',gateway if data.get('manual') else '','ipv4.dns',','.join(dns),'ipv4.ignore-auto-dns','yes' if dns else 'no']
 result=subprocess.run(args,text=True,capture_output=True,timeout=15)
 if result.returncode:raise ValueError('NetworkManager could not save the connection. Check your permissions and address settings.')
 return {'connections':connections(),'status':'Saved. Reconnect to apply these settings.'}
if __name__=='__main__':
 try:
  action=sys.argv[1] if len(sys.argv)>1 else 'list'
  if action=='save':result=save(json.loads(sys.argv[2]))
  elif action=='reconnect':
   ident=str(uuid.UUID(sys.argv[2]));r=subprocess.run(['nmcli','--wait','30','connection','up','uuid',ident],capture_output=True,timeout=35);result={'status':'Connected' if not r.returncode else 'Connection failed. Review the saved connection settings.'}
  else:result={'connections':connections()}
  print(json.dumps(result))
 except (ValueError,KeyError,GLib.Error,subprocess.SubprocessError):print(json.dumps({'error':'Check the IPv4 address, prefix, gateway and DNS values, then try again.'}))
