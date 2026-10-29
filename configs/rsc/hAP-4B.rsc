# =====================================================================
# hAP-4B  |  MikroTik hAP ax lite (L41G-2axD)  |  RouterOS v7
# DCN2 - Campus UNIS Integrado - Sede Sur (Grupo B)
# GENERADO por configs/generar-haps.py - NO editar a mano
# Anillo: hAP-3B --ether1--> hAP-4B --ether2--> GW-B
# Puertos: ether1/ether2 = transito L3 (sin bridge) | ether3/ether4 = acceso
# Sin NAT en este equipo (Regla 8) - verificado al final del archivo
# =====================================================================

# --- Identidad y sistema ---------------------------------------------
/system identity set name=hAP-4B
/user set admin password="CambiarClaveAdmin2026"
/system clock set time-zone-name=America/Guatemala
/system note set show-at-login=no note="DCN2 Campus UNIS - Sede Sur (Grupo B) - hAP-4B"
/system ntp client set enabled=yes servers=pool.ntp.org
/ip service disable telnet,ftp,api,api-ssl
/ipv6 settings set disable-ipv6=yes

# --- Etiquetas de cableado (puntos extra) ----------------------------
/interface ethernet
set ether1 comment="hAP-4B/ether1 -> hAP-3B/ether2"
set ether2 comment="hAP-4B/ether2 -> GW-B/ether1"
set ether3 comment="hAP-4B/ether3 -> libre"
set ether4 comment="hAP-4B/ether4 -> laptop de pruebas (opcional)"

# --- Loopback (router-id estable + IP de gestion) --------------------
/interface bridge add name=lo protocol-mode=none comment="loopback"
/ip address add address=10.20.255.14/32 interface=lo comment="loopback / router-id"

# --- WiFi ------------------------------------------------------------
# NOTA: paquete 'wifi' (no 'wireless'). Verificar nombres con '?' en tu version.
/interface wifi security
add name=sec-unis authentication-types=wpa2-psk,wpa3-psk passphrase="CambiarClaveWiFi2026"
/interface wifi configuration
add name=cfg-wifi ssid="UNIS-B4" security=sec-unis country=Guatemala \
    band=2ghz-ax channel.frequency=2412 channel.width=20mhz
/interface wifi set wifi1 configuration=cfg-wifi disabled=no

/interface bridge add name=br-wifi
/interface bridge port
add bridge=br-wifi interface=wifi1
add bridge=br-wifi interface=ether4 comment="puerto de pruebas (opcional)"

# --- Direcciones IP --------------------------------------------------
/ip address
add address=10.20.14.1/24 interface=br-wifi comment="red de usuarios hAP-4B"
add address=10.20.4.2/30 interface=ether1 comment="hAP-3B"
add address=10.20.5.1/30 interface=ether2 comment="GW-B"

# --- DHCP (sin NAT: el trafico sale enrutado hasta el GW de la sede) --
/ip pool add name=pool-wifi ranges=10.20.14.10-10.20.14.250
/ip dhcp-server add name=dhcp-wifi interface=br-wifi address-pool=pool-wifi lease-time=1h disabled=no
/ip dhcp-server network add address=10.20.14.0/24 gateway=10.20.14.1 dns-server=10.20.255.1

# --- OSPF area 0 -----------------------------------------------------
/routing ospf instance add name=ospf version=2 router-id=10.20.255.14
/routing ospf area add name=backbone area-id=0.0.0.0 instance=ospf
/routing ospf interface-template
add area=backbone interfaces=ether1 type=ptp cost=10 hello-interval=2s dead-interval=8s
add area=backbone interfaces=ether2 type=ptp cost=10 hello-interval=2s dead-interval=8s
add area=backbone interfaces=br-wifi passive comment="red de usuarios: se anuncia, no forma vecinos"
add area=backbone interfaces=lo passive

# --- Firewall minimo -------------------------------------------------
/ip firewall filter
add chain=input action=accept connection-state=established,related,untracked comment="Established"
add chain=input action=drop connection-state=invalid comment="Invalid"
add chain=input action=accept protocol=icmp comment="ICMP (pruebas de conectividad)"
add chain=input action=accept protocol=ospf comment="OSPF"
add chain=input action=accept in-interface=br-wifi comment="Clientes WiFi"
add chain=input action=accept in-interface=ether1 comment="Transito (gestion)"
add chain=input action=accept in-interface=ether2 comment="Transito (gestion)"
add chain=input action=accept in-interface=lo comment="Loopback"
add chain=input action=drop comment="Drop final"
add chain=forward action=accept connection-state=established,related comment="Forward established"
add chain=forward action=drop connection-state=invalid comment="Forward invalid"

# --- PROHIBIDO NAT EN ESTE EQUIPO (Regla 8) --------------------------
# Si esta tabla tiene algo, se pierden los 8 puntos de OSPF.
/ip firewall nat print

# --- Verificacion ----------------------------------------------------
# /routing ospf neighbor print          -> 2 vecinos en Full
# /ip route print where dst-address=0.0.0.0/0   -> default aprendido por OSPF
# /ip firewall nat print                -> VACIO
# /ip dhcp-server lease print           -> clientes con IP y DNS 10.20.255.1
