# =====================================================================
# GW-A  |  MikroTik RB5009UG+S+IN  |  RouterOS v7  |  Sede Norte
# DCN2 - Campus UNIS Integrado - Grupo A
# Rol: ABR/ASBR area 0, salida a Internet, DHCP/DNS del campus Norte,
#      gateway del segmento de servidores y host del contenedor Pi-hole.
#
# Orden de aplicacion:  FASE A (pegar todo)  ->  FASE B (manual, 2 min)
#                       ->  FASE C (contenedor)
# Cambiar antes de pegar: password de admin.
# =====================================================================
# MAPA DE PUERTOS
#   ether1  -> ISP / router del catedratico        100.64.1.2/30
#   ether2  -> hAP-1A ether1                        10.10.1.1/30
#   ether3  -> hAP-5A ether2                        10.10.6.2/30
#   ether7  -> GW-B ether7 (inter-sede)             10.99.0.1/30
#   sfp+    -> libre (reserva)
#   lo      -> loopback                             10.10.255.1/32
# =====================================================================

# ---------------------------------------------------------------------
# FASE A - BASE: sistema, direcciones, NAT, firewall, OSPF, default
# ---------------------------------------------------------------------

# --- Identidad y sistema ---------------------------------------------
/system identity set name=GW-A
/user set admin password="CambiarClaveAdmin2026"
/system clock set time-zone-name=America/Guatemala
/system note set show-at-login=no note="DCN2 Campus UNIS - Sede Norte - GW-A (RB5009)"
/system ntp client set enabled=yes servers=pool.ntp.org
/ip service disable telnet,ftp,api,api-ssl
/ipv6 settings set disable-ipv6=yes

# --- Etiquetas de cableado (puntos extra en la defensa) --------------
/interface ethernet
set ether1 comment="GW-A/ether1 -> ISP (WAN) 100.64.1.2/30"
set ether2 comment="GW-A/ether2 -> hAP-1A/ether1 10.10.1.1/30"
set ether3 comment="GW-A/ether3 -> hAP-5A/ether2 10.10.6.2/30"
set ether7 comment="GW-A/ether7 -> GW-B/ether7 10.99.0.1/30 (inter-sede)"
set sfp-sfpplus1 comment="libre / reserva"

# --- Listas de interfaces --------------------------------------------
/interface list add name=WAN
/interface list add name=LAN
/interface list member add list=WAN interface=ether1
/interface list member add list=LAN interface=ether2
/interface list member add list=LAN interface=ether3
/interface list member add list=LAN interface=ether7

# --- Loopback (router-id estable; sirve de DNS para todo el campus) --
/interface bridge add name=lo protocol-mode=none comment="loopback"
/ip address add address=10.10.255.1/32 interface=lo comment="loopback / router-id / DNS"

# --- Direcciones IP --------------------------------------------------
/ip address
add address=100.64.1.2/30 interface=ether1 comment="WAN"
add address=10.10.1.1/30 interface=ether2 comment="hAP-1A"
add address=10.10.6.2/30 interface=ether3 comment="hAP-5A (cierre del anillo)"
add address=10.99.0.1/30 interface=ether7 comment="enlace inter-sede"

# --- DNS del router (Fase C lo apunta al Pi-hole) --------------------
/ip dns set allow-remote-requests=yes servers=1.1.1.1,8.8.8.8

# --- NAT: una sola regla de salida (Regla 8) -------------------------
/ip firewall nat add chain=srcnat action=masquerade out-interface-list=WAN comment="Salida a Internet"

# --- Ruta por defecto (distance=1: gana siempre sobre OSPF 110) ------
# check-gateway=arp detecta el ISP caido y la retira -> OSPF toma el relevo.
/ip route add dst-address=0.0.0.0/0 gateway=100.64.1.1 distance=1 check-gateway=arp comment="default ISP (failover por OSPF)"

# --- Firewall: input con DROP final (Regla 4) ------------------------
/ip firewall filter
add chain=input action=accept connection-state=established,related,untracked comment="Established"
add chain=input action=drop connection-state=invalid comment="Invalid"
add chain=input action=accept protocol=icmp comment="ICMP (pruebas)"
add chain=input action=accept protocol=ospf comment="OSPF"
add chain=input action=accept in-interface-list=LAN comment="LAN, anillo e inter-sede"
add chain=input action=accept in-interface=lo comment="Loopback"
add chain=input action=drop comment="DROP final (Regla 4)"
add chain=forward action=accept connection-state=established,related comment="Forward established"
add chain=forward action=drop connection-state=invalid comment="Forward invalid"
# Politica de forward = accept: el campus debe rutear sin NAT (R-08 del informe).

# --- OSPF area 0 -----------------------------------------------------
# originate-default=if-installed: el default se anuncia SOLO si existe
# ruta por defecto instalada. Es el mecanismo de failover de la Regla 3/4.
/routing ospf instance add name=ospf version=2 router-id=10.10.255.1 originate-default=if-installed
/routing ospf area add name=backbone area-id=0.0.0.0 instance=ospf

/routing ospf interface-template
# Anillo: enlaces punto a punto Gigabit, costo 10
add area=backbone interfaces=ether2 type=ptp cost=10 hello-interval=2s dead-interval=8s
add area=backbone interfaces=ether3 type=ptp cost=10 hello-interval=2s dead-interval=8s
# Inter-sede: costo 100 (> 50 = peor camino posible dentro del anillo)
add area=backbone interfaces=ether7 type=ptp cost=100 hello-interval=5s dead-interval=20s
# Pasivas: se anuncian sus redes pero no forman vecinos
add area=backbone interfaces=lo passive

# --- Verificacion Fase A ---------------------------------------------
# /routing ospf neighbor print            -> GW-A con 3 vecinos Full (hAP-1A, hAP-5A, GW-B)
# /ip route print where dst-address=0.0.0.0/0   -> 1 estatica (distance 1) + 1 ospf (110) si GW-B anuncia
# /ip firewall nat print                  -> exactamente 1 regla (masquerade)
# /ip address print                       -> 4 IPs + loopback /32

# ---------------------------------------------------------------------
# FASE B - CONTENEDOR: habilitar modo container (MANUAL, 2 minutos)
# ---------------------------------------------------------------------
# 1) Subir el paquete extra 'container' de la arquitectura arm64
#    (download.mikrotik.com/routeros/<version>/container-<version>-arm64.npk)
#    a la raiz de Files, luego:
#        /system reboot
# 2) Habilitar el modo container y confirmar con el boton RESET fisico
#    (el equipo pide pulsar reset; si no, cold reboot desenchufando):
#        /system device-mode update container=yes
# 3) Comprobar:
#        /system device-mode print     -> container: yes
#        /container print              -> tabla vacia, sin errores
#
# ---------------------------------------------------------------------
# FASE C - CONTENEDOR: Pi-hole (DNS del campus Norte)
# ---------------------------------------------------------------------
# Pinear la imagen ANTES de la defensa: cambiar el tag por el que confirmen
# con '/container print' tras el primer pull. No dejar :latest en produccion.
:local img "pihole/pihole:latest"

# Carpetas persistentes (sobreviven al reinicio del contenedor)
/container mounts
add name=pihole_etc src=/pihole/etc dst=/etc/pihole
add name=pihole_dnsmasq src=/pihole/dnsmasq.d dst=/etc/dnsmasq.d

# Variables de entorno de Pi-hole v6
/container envs
add name=pihole_envs key=TZ value=America/Guatemala
add name=pihole_envs key=FTLCONF_webserver_api_password value="CambiarClavePihole2026"
add name=pihole_envs key=FTLCONF_dns_upstreams value="1.1.1.1;8.8.8.8"
add name=pihole_envs key=FTLCONF_dns_listeningMode value=all
add name=pihole_envs key=FTLCONF_misc_etc_dnsmasq_d value=true

# veth: .53 es el contenedor, .1 es el router (extremo del host)
/interface veth add name=veth1 address=10.10.254.53/24 gateway=10.10.254.1
/ip address add address=10.10.254.1/24 interface=veth1 comment="red del contenedor"

# Crear y arrancar (verificar el nombre del disco con /disk print)
/container add remote-image=$img interface=veth1 root-dir=disk1/pihole/root \
    hostname=pihole envlist=pihole_envs mounts=pihole_etc,pihole_dnsmasq \
    start-on-boot=yes logging=yes comment="Pi-hole (DNS campus Norte)"
/container start [find]

# Esperar ~60 s a que arranque, luego apuntar el DNS al Pi-hole:
/ip dns set servers=10.10.254.53

# Forzar el DNS de los clientes hacia el Pi-hole (anti-bypass, +extra):
# solo afecta a quien intente usar otro DNS; los clientes ya reciben 10.10.255.1
/ip firewall nat
add chain=dstnat action=dst-nat to-addresses=10.10.254.53 to-ports=53 protocol=udp dst-port=53 in-interface-list=LAN comment="Forzar DNS -> Pi-hole (UDP)"
add chain=dstnat action=dst-nat to-addresses=10.10.254.53 to-ports=53 protocol=tcp dst-port=53 in-interface-list=LAN comment="Forzar DNS -> Pi-hole (TCP)"

# --- Verificacion Fase C ---------------------------------------------
# /container print                    -> running
# /ip address print                   -> 10.10.254.1/24 en veth1
# Desde una laptop: nslookup unis.edu.gt 10.10.255.1   -> responde
# Navegar: http://10.10.254.53/admin                  -> panel de Pi-hole
# /ip firewall nat print              -> 1 masquerade + 2 dst-nat
#
# LIMITACION CONOCIDA (documentada en docs/04-RIESGOS.md R-07):
# check-gateway=arp detecta caida de ENLACE. Si el ISP cae pero el cable
# sigue arriba, el default no se retira. Mitigacion opcional (Netwatch):
#   /tool netwatch add host=1.1.1.1 interval=10s timeout=2s \
#       down-script="/ip route disable [find comment=\"default ISP\"]" \
#       up-script="/ip route enable [find comment=\"default ISP\"]"
