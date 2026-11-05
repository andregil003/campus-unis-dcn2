# 2026-01-30 00:42:02 by RouterOS 7.20.8
# software id = 3K5Y-CV59
#
# model = L41G-2axD
# serial number = HMH0B01K6VG
/interface bridge add name=br-wifi
/interface bridge add admin-mac=D0:EA:11:AD:7F:99 auto-mac=no comment=defconf name=bridgeLocal
/interface ethernet set [ find default-name=ether1 ] comment="hAP-5A/ether1 -> hAP-4A/ether2"
/interface ethernet set [ find default-name=ether2 ] comment="hAP-5A/ether2 -> GW-A/ether3"
/interface ethernet set [ find default-name=ether3 ] comment="hAP-5A/ether3 -> libre"
/interface ethernet set [ find default-name=ether4 ] comment="hAP-5A/ether4 -> puerto de pruebas (opcional)"
/interface wifi datapath add bridge=bridgeLocal comment=defconf disabled=no name=capdp
/interface wifi security add authentication-types=wpa2-psk,wpa3-psk name=sec-unis passphrase=CambiarClaveWiFi2026
/interface wifi configuration add channel.band=2ghz-ax .frequency=2437 .width=20mhz country=Guatemala name=cfg-wifi security=sec-unis ssid=UNIS-A5
/interface wifi
# no connection to CAPsMAN
set [ find default-name=wifi1 ] configuration=cfg-wifi configuration.manager=capsman datapath=capdp disabled=no
/ip pool add name=pool-wifi ranges=192.168.5.10-192.168.5.250
/routing ospf instance add disabled=no name=ospf router-id=10.10.255.15
/routing ospf area add disabled=no instance=ospf name=backbone
/interface bridge port add bridge=bridgeLocal comment=defconf interface=ether3
/interface bridge port add bridge=br-wifi comment=defconf interface=ether4
/interface bridge port add bridge=br-wifi interface=wifi1
/ipv6 settings set disable-ipv6=yes
/interface wifi cap set discovery-interfaces=bridgeLocal enabled=yes slaves-datapath=capdp
/ip address add address=10.10.255.15 comment=loopback-router-id interface=lo network=10.10.255.15
/ip address add address=10.10.5.2/30 comment=hAP-4A interface=ether1 network=10.10.5.0
/ip address add address=10.10.6.1/30 comment=GW-A interface=ether2 network=10.10.6.0
/ip address add address=192.168.5.1/24 comment="red de usuarios hAP-5A" interface=br-wifi network=192.168.5.0
/ip dhcp-client add comment=defconf interface=bridgeLocal
/ip dhcp-server add address-pool=pool-wifi interface=br-wifi lease-time=1h name=dhcp-wifi
/ip dhcp-server network add address=192.168.5.0/24 dns-server=10.10.255.1 gateway=192.168.5.1
/ip firewall filter add action=accept chain=input connection-state=established,related,untracked
/ip firewall filter add action=drop chain=input connection-state=invalid
/ip firewall filter add action=accept chain=input protocol=icmp
/ip firewall filter add action=accept chain=input protocol=ospf
/ip firewall filter add action=accept chain=input comment="clientes WiFi" in-interface=br-wifi
/ip firewall filter add action=accept chain=input in-interface=ether1
/ip firewall filter add action=accept chain=input in-interface=ether2
/ip firewall filter
# in/out-interface matcher not possible when interface (ether3) is slave - use master instead (bridgeLocal)
add action=accept chain=input comment="servidor / consola (anti-bloqueo)" in-interface=ether3
/ip firewall filter add action=accept chain=input in-interface=lo
/ip firewall filter add action=drop chain=input
/ip firewall filter add action=accept chain=forward connection-state=established,related
/ip firewall filter add action=drop chain=forward connection-state=invalid
/ip service set ftp disabled=yes
/ip service set telnet disabled=yes
/ip service set api disabled=yes
/ip service set api-ssl disabled=yes
/routing ospf interface-template add area=backbone cost=10 dead-interval=8s disabled=no hello-interval=2s interfaces=ether1 type=ptp
/routing ospf interface-template add area=backbone cost=10 dead-interval=8s disabled=no hello-interval=2s interfaces=ether2 type=ptp
/routing ospf interface-template add area=backbone comment="se anuncia, no forma vecinos" disabled=no interfaces=br-wifi passive
/routing ospf interface-template add area=backbone disabled=no interfaces=lo passive
/system clock set time-zone-name=America/Guatemala
/system identity set name=hAP-5A
/system note set note="DCN2 Campus UNIS - Sede Norte - hAP-5A" show-at-login=no
/system ntp client set enabled=yes
/system ntp client servers add address=pool.ntp.org
