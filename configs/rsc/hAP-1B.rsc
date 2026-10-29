# =====================================================================
# hAP-1B  |  MikroTik hAP ax lite (L41G-2axD)  |  RouterOS v7
# DCN2 - Campus UNIS Integrado - Sede Sur
# GENERADO por configs/generar-haps.py - NO editar a mano
#
# COMO APLICAR: WinBox > New Terminal. Pegar UN bloque por vez
# (desde la linea "BLOQUE n/5" hasta el final del bloque), esperar a que
# vuelva el prompt [admin@hAP-1B] > y seguir con el siguiente.
# Si alguna linea "#" marca error, ignoralo: es solo comentario.
#
# Anillo: GW-B --ether1--> hAP-1B --ether2--> hAP-2B
# =====================================================================


# ==================================================================
# BLOQUE 1/5 · Sistema  --  identidad, clave, hora, servicios y IPv6
# ==================================================================
/system identity set name=hAP-1B
/user set admin password="ValoValoValo2026"
/system clock set time-zone-name=America/Guatemala
/system note set show-at-login=no note="DCN2 Campus UNIS - Sede Sur - hAP-1B"
/system ntp client set enabled=yes servers=pool.ntp.org
/ip service disable telnet,ftp,api,api-ssl
/ipv6 settings set disable-ipv6=yes

# ==================================================================
# BLOQUE 2/5 · Puertos, loopback e IPs  --  etiquetas de cable + direccionamiento del anillo
# ==================================================================
/interface ethernet
set ether1 comment="hAP-1B/ether1 -> GW-B/ether2"
set ether2 comment="hAP-1B/ether2 -> hAP-2B/ether1"
set ether3 comment="hAP-1B/ether3 -> servidor de sede"
set ether4 comment="hAP-1B/ether4 -> puerto de pruebas (opcional)"

# 'lo' ya existe: es el loopback interno de RouterOS (visible desde ~7.14).
# NO crear un bridge con ese nombre: da 'already have interface with name lo'.
# Si algun equipo no lo tuviera, crear el reemplazo:
#   /interface bridge add name=lo-dummy  y  usar interface=lo-dummy
/ip address add address=10.20.255.11/32 interface=lo comment=loopback-router-id

/ip address
add address=10.20.1.2/30 interface=ether1 comment=GW-B
add address=10.20.2.1/30 interface=ether2 comment=hAP-2B
add address=10.20.0.1/24 interface=ether3 comment="segmento del servidor"

# ==================================================================
# BLOQUE 3/5 · WiFi y DHCP  --  SSID, seguridad, bridge, pool y DNS
# ==================================================================
/interface wifi security add name=sec-unis authentication-types=wpa2-psk,wpa3-psk passphrase="CambiarClaveWiFi2026"
/interface wifi configuration add name=cfg-wifi ssid="UNIS-B1" security=sec-unis country=Guatemala channel.band=2ghz-ax channel.frequency=2412 channel.width=20mhz
/interface wifi set wifi1 configuration=cfg-wifi disabled=no

/interface bridge add name=br-wifi
/interface bridge port add bridge=br-wifi interface=wifi1
/interface bridge port add bridge=br-wifi interface=ether4 comment="puerto de pruebas"

/ip address
add address=10.20.11.1/24 interface=br-wifi comment="red de usuarios hAP-1B"

/ip pool add name=pool-wifi ranges=10.20.11.10-10.20.11.250
/ip dhcp-server add name=dhcp-wifi interface=br-wifi address-pool=pool-wifi lease-time=1h disabled=no
/ip dhcp-server network add address=10.20.11.0/24 gateway=10.20.11.1 dns-server=10.20.255.1

# ==================================================================
# BLOQUE 4/5 · OSPF  --  instancia, area 0 y plantillas de interfaz
# ==================================================================
/routing ospf instance add name=ospf version=2 router-id=10.20.255.11
/routing ospf area add name=backbone area-id=0.0.0.0 instance=ospf

/routing ospf interface-template
add area=backbone interfaces=ether1 type=ptp cost=10 hello-interval=2s dead-interval=8s
add area=backbone interfaces=ether2 type=ptp cost=10 hello-interval=2s dead-interval=8s
add area=backbone interfaces=br-wifi passive comment="se anuncia, no forma vecinos"
add area=backbone interfaces=lo passive
add area=backbone interfaces=ether3 passive comment="segmento del servidor"

# ==================================================================
# BLOQUE 5/5 · Firewall  --  input con DROP final (el equipo NO lleva NAT)
# ==================================================================
/ip firewall filter
add chain=input action=accept connection-state=established,related,untracked
add chain=input action=drop connection-state=invalid
add chain=input action=accept protocol=icmp
add chain=input action=accept protocol=ospf
add chain=input action=accept in-interface=br-wifi comment="clientes WiFi"
add chain=input action=accept in-interface=ether1
add chain=input action=accept in-interface=ether2
add chain=input action=accept in-interface=ether3 comment="servidor / consola (anti-bloqueo)"
add chain=input action=accept in-interface=lo
add chain=input action=drop
add chain=forward action=accept connection-state=established,related
add chain=forward action=drop connection-state=invalid

# =====================================================================
# VERIFICACION FINAL (copiar estos comandos uno por uno)
# =====================================================================
# /routing ospf neighbor print        -> 2 vecinos en state=Full
# /ip route print where dst-address=0.0.0.0/0
#                                     -> default por OSPF, distance=110
# /ip firewall nat print              -> TABLA VACIA (Regla 8)
# /ip dhcp-server lease print         -> clientes con DNS 10.20.255.1
# /interface wifi print               -> wifi1 running, ssid UNIS-B1

