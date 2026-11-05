# 2026-11-04 20:54:27 by RouterOS 7.24.5
# software id = 2TMF-DTCH
#
# model = RB3011UiAS
# serial number = 783E064858A9
/interface ethernet
set [ find default-name=ether2 ] comment=\
    "ISP/e2 -> GW-A/ether1 100.64.1.1/30 [Norte]"
set [ find default-name=ether3 ] comment="DANADO - no-link"
set [ find default-name=ether5 ] comment=\
    "ISP/e5 -> GW-B/ether1 100.64.2.1/30 [Sur] (ether3 danado)"
/interface wireless security-profiles
set [ find default=yes ] supplicant-identity=MikroTik
/ip address
add address=10.0.1.1/25 comment="Puerto 7 - Rodrigo Quiroa" interface=ether7 \
    network=10.0.1.0
add address=100.64.1.1/30 comment=WAN-Norte-GW-A interface=ether2 network=\
    100.64.1.0
add address=100.64.2.1/30 comment=WAN-Sur-GW-B interface=ether5 network=\
    100.64.2.0
/ip dhcp-client
add interface=sfp1 name=client1
/ip firewall nat
add action=masquerade chain=srcnat comment="salida a Internet (uplink lab)" \
    out-interface=sfp1
/lcd
set time-interval=hour
/system clock
set time-zone-name=America/Guatemala
/system identity
set name=ROUTER-ISP
