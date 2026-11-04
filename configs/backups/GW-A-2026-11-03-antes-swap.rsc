
########## /export
# 2026-09-02 04:13:22 by RouterOS 7.24.2

# software id = 8V88-MAFF

#

# model = RB5009UG+S+

# serial number = HFB09D3DPSG

/interface ethernet

set [ find default-name=ether1 ] comment=\

    "GW-A/ether1 -> ISP (WAN) 100.64.1.2/30"

set [ find default-name=ether2 ] comment=\

    "GW-A/ether2 -> hAP-1A/ether1 10.10.1.1/30"

set [ find default-name=ether3 ] comment=\

    "GW-A/ether3 -> hAP-5A/ether2 10.10.6.2/30"

set [ find default-name=ether4 ] comment="consola / libre"

set [ find default-name=ether5 ] comment="consola / libre"

set [ find default-name=ether6 ] comment="consola / libre"

set [ find default-name=ether7 ] comment=\

    "GW-A/ether7 -> GW-B/ether7 10.99.0.1/30 inter-sede"

set [ find default-name=ether8 ] comment="consola / libre"

set [ find default-name=sfp-sfpplus1 ] comment="libre / reserva"

/interface list

add name=WAN

add name=LAN

add name=MGMT

/interface wireless security-profiles

set [ find default=yes ] supplicant-identity=MikroTik

/routing ospf instance

add name=ospf originate-default=if-installed router-id=10.10.255.1

/routing ospf area

add instance=ospf name=backbone

/ipv6 settings

set disable-ipv6=yes

/interface list member

add interface=ether1 list=WAN

add interface=ether2 list=LAN

add interface=ether3 list=LAN

add interface=ether7 list=LAN

add interface=ether4 list=MGMT

add interface=ether5 list=MGMT

add interface=ether6 list=MGMT

add interface=ether8 list=MGMT

/ip address

add address=10.10.255.1 comment=loopback-router-id-dns interface=lo network=\

    10.10.255.1

add address=100.64.1.2/30 comment=WAN interface=ether1 network=100.64.1.0

add address=10.10.1.1/30 comment=hAP-1A interface=ether2 network=10.10.1.0

add address=10.10.6.2/30 comment=hAP-5A-cierre-anillo interface=ether3 \

    network=10.10.6.0

add address=10.99.0.1/30 comment=inter-sede interface=ether7 network=\

    10.99.0.0

/ip dns

set allow-remote-requests=yes servers=1.1.1.1,8.8.8.8

/ip dns static

add address=10.10.255.1 comment=prueba-local-DNS name=prueba-dns.campus type=\

    A

/ip firewall filter

add action=accept chain=input connection-state=established,related,untracked

add action=drop chain=input connection-state=invalid

add action=accept chain=input protocol=icmp

add action=accept chain=input protocol=ospf

add action=accept chain=input comment="consola (anti-bloqueo)" \

    in-interface-list=MGMT

add action=accept chain=input in-interface-list=LAN

add action=accept chain=input in-interface=lo

add action=drop chain=input comment="DROP final"

add action=accept chain=forward connection-state=established,related

add action=drop chain=forward connection-state=invalid

/ip firewall nat

add action=masquerade chain=srcnat comment="salida a Internet" \

    out-interface-list=WAN

/ip firewall raw

add action=notrack chain=prerouting protocol=ospf

add action=notrack chain=output protocol=ospf

/ip route

add check-gateway=arp comment=default-ISP distance=1 dst-address=0.0.0.0/0 \

    gateway=100.64.1.1

/ip service

set ftp disabled=yes

set telnet disabled=yes

set api disabled=yes

set api-ssl disabled=yes

/routing ospf interface-template

add area=backbone cost=10 dead-interval=8s hello-interval=2s interfaces=\

    ether2 type=ptp

add area=backbone cost=10 dead-interval=8s hello-interval=2s interfaces=\

    ether3 type=ptp

add area=backbone cost=100 dead-interval=20s hello-interval=5s interfaces=\

    ether7 type=ptp

add area=backbone interfaces=lo passive

/system clock

set time-zone-name=America/Guatemala

/system identity

set name=GW-A

/system note

set note="DCN2 Campus UNIS - Sede Norte - GW-A (RB5009)" show-at-login=no

/system ntp client

set enabled=yes

/system ntp client servers

add address=pool.ntp.org
