# =====================================================================
# hAP-3B  |  MikroTik hAP ax lite (L41G-2axD)  |  RouterOS v7
# DCN2 - Campus UNIS Integrado - Sede Sur
# GENERADO por configs/generar-haps.py - NO editar a mano
#
# COMO APLICAR: WinBox > New Terminal. Pegar UN bloque por vez
# (desde la linea "BLOQUE n/5" hasta el final del bloque), esperar a que
# vuelva el prompt [admin@hAP-3B] > y seguir con el siguiente.
# Si alguna linea "#" marca error, ignoralo: es solo comentario.
#
# Anillo: hAP-2B --ether1--> hAP-3B --ether2--> hAP-4B
# =====================================================================


# ==================================================================
# BLOQUE 1/5 · Sistema  --  identidad, clave, hora, servicios y IPv6
# ==================================================================
/system identity set name=hAP-3B
/user set admin password="ValoValoValo2026"
/system clock set time-zone-name=America/Guatemala
/system note set show-at-login=no note="DCN2 Campus UNIS - Sede Sur - hAP-3B"
/system ntp client set enabled=yes servers=pool.ntp.org
/ip service disable telnet,ftp,api,api-ssl
/ipv6 settings set disable-ipv6=yes

# ==================================================================
# BLOQUE 2/5 · Puertos, loopback e IPs  --  etiquetas de cable + direccionamiento del anillo
# ==================================================================
/interface ethernet
set ether1 comment="hAP-3B/ether1 -> hAP-2B/ether2"
set ether2 comment="hAP-3B/ether2 -> hAP-4B/ether1"
set ether3 comment="hap-3B/ether3 -> Raspberry Pi B"
set ether4 comment="hAP-3B/ether4 -> puerto de pruebas (opcional)"

# 'lo' ya existe: es el loopback interno de RouterOS (visible desde ~7.14).
# NO crear un bridge con ese nombre: da 'already have interface with name lo'.
# Si algun equipo no lo tuviera, crear el reemplazo:
#   /interface bridge add name=lo-dummy  y  usar interface=lo-dummy
/ip address add address=10.20.255.13/32 interface=lo comment=loopback-router-id

/ip address
add address=10.20.3.2/30 interface=ether1 comment="a hAP-2B"
add address=10.20.4.1/30 interface=ether2 comment="a hAP-4B"
add address=10.20.0.1/24 interface=ether3 comment="segmento del servidor"

# ==================================================================
# BLOQUE 3/5 · WiFi y DHCP  --  SSID, seguridad, bridge, pool y DNS
# ==================================================================
# hAP-3B configura la WiFi directo en wifi1 (sin perfiles cfg-wifi / sec-unis)
/interface wifi set wifi1 channel.band=2ghz-ax channel.frequency=2462 channel.width=20mhz configuration.country=Guatemala configuration.mode=ap configuration.ssid="UNIS-B3" security.authentication-types=wpa2-psk,wpa3-psk security.passphrase="CambiarClaveWiFi2026" disabled=no

/interface bridge add name=bridge-wifi
/interface bridge port add bridge=bridge-wifi interface=wifi1 comment="WiFi usuarios 3B"
/interface bridge port add bridge=bridge-wifi interface=ether4 comment="Laptop admin 3B"

/ip address
add address=192.168.13.1/24 interface=bridge-wifi comment="Gateway WiFi 3B"

/ip pool add name=pool-wifi ranges=192.168.13.10-192.168.13.200
/ip dhcp-server add name=dhcp-wifi interface=bridge-wifi address-pool=pool-wifi lease-time=1h disabled=no
/ip dhcp-server network add address=192.168.13.0/24 gateway=192.168.13.1 dns-server=10.20.255.1 comment="Red WiFi 3B"

# ==================================================================
# BLOQUE 4/5 · OSPF  --  instancia, area 0 y plantillas de interfaz
# ==================================================================
/routing ospf instance add name=ospf-sur version=2 router-id=10.20.255.13 comment="OSPF hAP-3B"
/routing ospf area add name=backbone area-id=0.0.0.0 instance=ospf-sur comment="Area 0 campus"

/routing ospf interface-template
add area=backbone interfaces=ether1,ether2 type=ptp cost=10 hello-interval=2s dead-interval=8s comment="Enlaces anillo 3B"
add area=backbone networks=192.168.13.0/24 passive cost=1 comment="Red WiFi 3B pasiva"
add area=backbone interfaces=lo passive cost=1 comment="loopback 3B"
add area=backbone interfaces=ether3 passive cost=1 comment="segmento del servidor"

# ==================================================================
# BLOQUE 5/5 · Firewall  --  input con DROP final (el equipo NO lleva NAT)
# ==================================================================
/ip firewall filter
add chain=input action=accept connection-state=established,related,untracked comment="aceptar establecidas"
add chain=input action=drop connection-state=invalid comment="drop invalidas"
add chain=input action=accept protocol=icmp comment="aceptar ping"
add chain=input action=accept protocol=ospf comment="aceptar OSPF"
add chain=input action=accept in-interface=bridge-wifi comment="clientes WiFi"
add chain=input action=accept in-interface=ether1 comment="anillo hAP-2B"
add chain=input action=accept in-interface=ether2 comment="anillo hAP-4B"
add chain=input action=accept in-interface=ether3 comment="servidor / consola (anti-bloqueo)"
add chain=input action=accept in-interface=lo comment=loopback
add chain=input action=drop comment="DROP final"
add chain=forward action=accept connection-state=established,related comment="forward establecidas"
add chain=forward action=drop connection-state=invalid comment="forward drop invalidas"

# =====================================================================
# VERIFICACION FINAL (copiar estos comandos uno por uno)
# =====================================================================
# /routing ospf neighbor print        -> 2 vecinos en state=Full
# /ip route print where dst-address=0.0.0.0/0
#                                     -> default por OSPF, distance=110
# /ip firewall nat print              -> TABLA VACIA (Regla 8)
# /ip dhcp-server lease print         -> clientes con DNS 10.20.255.1
# /interface wifi print               -> wifi1 running, ssid UNIS-B3

