# =====================================================================
# GW-B  |  MikroTik RB5009UG+S+IN  |  RouterOS v7  |  Sede Sur
# DCN2 - Campus UNIS Integrado - Grupo B
# Rol: ABR/ASBR area 0 de la sede Sur, salida a Internet, DHCP/DNS,
#      gateway del segmento de servidores y host del contenedor AdGuard.
#
# NOTA: archivo de coordinacion generado por el Grupo A a partir del
# direccionamiento acordado. El Grupo B lo valida y lo adapta antes de
# aplicarlo: es su equipo y su defensa.
#
# Orden: FASE A -> FASE B (manual) -> FASE C
# =====================================================================
# MAPA DE PUERTOS
#   ether1  -> ISP / router del catedratico        100.64.2.2/30
#   ether2  -> hAP-1B ether1                        10.20.1.1/30
#   ether3  -> hAP-4B ether2                        10.20.5.2/30
#   ether7  -> GW-A ether7 (inter-sede)             10.99.0.2/30
#   lo      -> loopback                             10.20.255.1/32
# =====================================================================

# ---------------------------------------------------------------------
# FASE A - BASE
# ---------------------------------------------------------------------
/system identity set name=GW-B
/user set admin password="CambiarClaveAdmin2026"
/system clock set time-zone-name=America/Guatemala
/system note set show-at-login=no note="DCN2 Campus UNIS - Sede Sur - GW-B (RB5009)"
/system ntp client set enabled=yes servers=pool.ntp.org
/ip service disable telnet,ftp,api,api-ssl
/ipv6 settings set disable-ipv6=yes

/interface ethernet
set ether1 comment="GW-B/ether1 -> ISP (WAN) 100.64.2.2/30"
set ether2 comment="GW-B/ether2 -> hAP-1B/ether1 10.20.1.1/30"
set ether3 comment="GW-B/ether3 -> hAP-4B/ether2 10.20.5.2/30"
set ether7 comment="GW-B/ether7 -> GW-A/ether7 10.99.0.2/30 (inter-sede)"
set sfp-sfpplus1 comment="libre / reserva"

/interface list add name=WAN
/interface list add name=LAN
/interface list member add list=WAN interface=ether1
/interface list member add list=LAN interface=ether2
/interface list member add list=LAN interface=ether3
/interface list member add list=LAN interface=ether7

/interface bridge add name=lo protocol-mode=none comment="loopback"
/ip address add address=10.20.255.1/32 interface=lo comment="loopback / router-id / DNS"

/ip address
add address=100.64.2.2/30 interface=ether1 comment="WAN"
add address=10.20.1.1/30 interface=ether2 comment="hAP-1B"
add address=10.20.5.2/30 interface=ether3 comment="hAP-4B (cierre del anillo)"
add address=10.99.0.2/30 interface=ether7 comment="enlace inter-sede"

/ip dns set allow-remote-requests=yes servers=1.1.1.1,8.8.8.8

/ip firewall nat add chain=srcnat action=masquerade out-interface-list=WAN comment="Salida a Internet"

/ip route add dst-address=0.0.0.0/0 gateway=100.64.2.1 distance=1 check-gateway=arp comment="default ISP (failover por OSPF)"

/ip firewall filter
add chain=input action=accept connection-state=established,related,untracked comment="Established"
add chain=input action=drop connection-state=invalid comment="Invalid"
add chain=input action=accept protocol=icmp comment="ICMP (pruebas)"
add chain=input action=accept protocol=ospf comment="OSPF"
add chain=input action=accept in-interface-list=LAN comment="LAN, anillo e inter-sede"
add chain=input action=accept in-interface=lo comment="Loopback"
add chain=input action=drop comment="DROP final"
add chain=forward action=accept connection-state=established,related comment="Forward established"
add chain=forward action=drop connection-state=invalid comment="Forward invalid"

# --- OSPF area 0 -----------------------------------------------------
/routing ospf instance add name=ospf version=2 router-id=10.20.255.1 originate-default=if-installed
/routing ospf area add name=backbone area-id=0.0.0.0 instance=ospf

/routing ospf interface-template
add area=backbone interfaces=ether2 type=ptp cost=10 hello-interval=2s dead-interval=8s
add area=backbone interfaces=ether3 type=ptp cost=10 hello-interval=2s dead-interval=8s
add area=backbone interfaces=ether7 type=ptp cost=100 hello-interval=5s dead-interval=20s
add area=backbone interfaces=lo passive

# --- Verificacion Fase A ---------------------------------------------
# /routing ospf neighbor print      -> 3 vecinos Full (hAP-1B, hAP-4B, GW-A)
# /ip route print where dst-address=0.0.0.0/0

# ---------------------------------------------------------------------
# FASE B - CONTENEDOR: habilitar modo container (MANUAL)
# ---------------------------------------------------------------------
# 1) Subir el .npk 'container' arm64 de la version exacta del RouterOS,
#    reiniciar, y luego:
#        /system device-mode update container=yes      (confirmar con RESET)
# 2) /system device-mode print     -> container: yes

# ---------------------------------------------------------------------
# FASE C - CONTENEDOR: AdGuard Home (DNS de la sede Sur)
# ---------------------------------------------------------------------
# Pinear el tag antes de la defensa (no dejar :latest).
:local img "adguard/adguardhome:latest"

/container mounts
add name=adguard_work src=/adguard/work dst=/opt/adguardhome/work
add name=adguard_conf src=/adguard/conf dst=/opt/adguardhome/conf

/interface veth add name=veth1 address=10.20.254.53/24 gateway=10.20.254.1
/ip address add address=10.20.254.1/24 interface=veth1 comment="red del contenedor"

/container add remote-image=$img interface=veth1 root-dir=disk1/adguard/root \
    hostname=adguard mounts=adguard_work,adguard_conf start-on-boot=yes logging=yes \
    comment="AdGuard Home (DNS sede Sur)"
/container start [find]

# Asistente inicial: http://10.20.254.53:3000   (crear usuario admin)
# Dejar el DNS escuchando en el puerto 53 tras el asistente. Luego:
/ip dns set servers=10.20.254.53

/ip firewall nat
add chain=dstnat action=dst-nat to-addresses=10.20.254.53 to-ports=53 protocol=udp dst-port=53 in-interface-list=LAN comment="Forzar DNS -> AdGuard (UDP)"
add chain=dstnat action=dst-nat to-addresses=10.20.254.53 to-ports=53 protocol=tcp dst-port=53 in-interface-list=LAN comment="Forzar DNS -> AdGuard (TCP)"

# --- Verificacion Fase C ---------------------------------------------
# /container print                  -> running
# http://10.20.254.53:3000          -> asistente / panel
# nslookup unis.edu.gt 10.20.255.1  -> responde
