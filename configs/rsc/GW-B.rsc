# =====================================================================
# GW-B  |  MikroTik RB5009UG+S+IN  |  RouterOS v7  |  Sede Sur
# DCN2 - Campus UNIS Integrado - Grupo B
# Rol: ABR/ASBR area 0 de la Sede Sur, salida a Internet, DNS/host del
#      contenedor AdGuard y gateway de las redes internas del Sur.
#
# NOTA: configuracion de coordinacion generada por el Grupo A a partir del
# direccionamiento acordado. El Grupo B la valida antes de aplicarla.
#
# COMO APLICAR: WinBox > New Terminal, un bloque por vez.
#
# MAPA DE PUERTOS
#   ether1  -> ISP / router del catedratico        100.64.2.2/30
#   ether2  -> hAP-1B ether1                        10.20.1.1/30
#   ether3  -> hAP-4B ether2                        10.20.5.2/30
#   ether7  -> GW-A ether7 (inter-sede)             10.99.0.2/30
#   ether4/5/6/8 -> consola y libres (lista MGMT)
#   lo      -> loopback                             10.20.255.1/32
# =====================================================================


# ==================================================================
# BLOQUE 0/7 · Limpieza de la configuracion de fabrica
# ==================================================================
# Si el equipo trae bridgeLocal con todos los puertos, borrarlo primero.
# Idempotente: si ya esta limpio no hace nada.
/ip dhcp-client remove [find]
/interface bridge port remove [find bridge=bridgeLocal]
/interface bridge remove [find name=bridgeLocal]
# Verificar: /interface bridge print -> vacio | /ip address print -> vacio

# ==================================================================
# BLOQUE 1/7 · Sistema
# ==================================================================
/system identity set name=GW-B
/user set admin password="CambiarClaveAdmin2026"
/system clock set time-zone-name=America/Guatemala
/system note set show-at-login=no note="DCN2 Campus UNIS - Sede Sur - GW-B (RB5009)"
/system ntp client set enabled=yes servers=pool.ntp.org
/ip service disable telnet,ftp,api,api-ssl
/ipv6 settings set disable-ipv6=yes

# ==================================================================
# BLOQUE 2/7 · Puertos, listas y loopback
# ==================================================================
/interface ethernet
set ether1 comment="GW-B/ether1 -> ISP (WAN) 100.64.2.2/30"
set ether2 comment="GW-B/ether2 -> hAP-1B/ether1 10.20.1.1/30"
set ether3 comment="GW-B/ether3 -> hAP-4B/ether2 10.20.5.2/30"
set ether7 comment="GW-B/ether7 -> GW-A/ether7 10.99.0.2/30 inter-sede"
set ether4 comment="consola / libre"
set ether5 comment="consola / libre"
set ether6 comment="consola / libre"
set ether8 comment="consola / libre"
set sfp-sfpplus1 comment="libre / reserva"

/interface list add name=WAN
/interface list add name=LAN
/interface list add name=MGMT
/interface list member add list=WAN interface=ether1
/interface list member add list=LAN interface=ether2
/interface list member add list=LAN interface=ether3
/interface list member add list=LAN interface=ether7
/interface list member add list=MGMT interface=ether4
/interface list member add list=MGMT interface=ether5
/interface list member add list=MGMT interface=ether6
/interface list member add list=MGMT interface=ether8

/interface bridge add name=lo protocol-mode=none comment=loopback
/ip address add address=10.20.255.1/32 interface=lo comment=loopback-router-id-dns

# ==================================================================
# BLOQUE 3/7 · Direcciones IP y DNS
# ==================================================================
/ip address
add address=100.64.2.2/30 interface=ether1 comment=WAN
add address=10.20.1.1/30 interface=ether2 comment=hAP-1B
add address=10.20.5.2/30 interface=ether3 comment=hAP-4B-cierre-anillo
add address=10.99.0.2/30 interface=ether7 comment=inter-sede

/ip dns set allow-remote-requests=yes servers=1.1.1.1,8.8.8.8

# ==================================================================
# BLOQUE 4/7 · NAT, ruta por defecto y firewall
# ==================================================================
/ip firewall nat add chain=srcnat action=masquerade out-interface-list=WAN comment="salida a Internet"

/ip route add dst-address=0.0.0.0/0 gateway=100.64.2.1 distance=1 check-gateway=arp comment=default-ISP

/ip firewall filter
add chain=input action=accept connection-state=established,related,untracked
add chain=input action=drop connection-state=invalid
add chain=input action=accept protocol=icmp
add chain=input action=accept protocol=ospf
add chain=input action=accept in-interface-list=MGMT comment="consola (anti-bloqueo)"
add chain=input action=accept in-interface-list=LAN
add chain=input action=accept in-interface=lo
add chain=input action=drop comment="DROP final"
add chain=forward action=accept connection-state=established,related
add chain=forward action=drop connection-state=invalid

# Conntrack puede dejar la adyacencia OSPF colgada en Init/ExStart (doc oficial,
# "Basic RAW example"): marcar los paquetes OSPF como untracked lo evita.
/ip firewall raw
add chain=prerouting protocol=ospf action=notrack
add chain=output protocol=ospf action=notrack

# ==================================================================
# BLOQUE 5/7 · OSPF  --  area 0 + anuncio del default
# ==================================================================
/routing ospf instance add name=ospf version=2 router-id=10.20.255.1 originate-default=if-installed
/routing ospf area add name=backbone area-id=0.0.0.0 instance=ospf

/routing ospf interface-template
add area=backbone interfaces=ether2 type=ptp cost=10 hello-interval=2s dead-interval=8s
add area=backbone interfaces=ether3 type=ptp cost=10 hello-interval=2s dead-interval=8s
add area=backbone interfaces=ether7 type=ptp cost=100 hello-interval=5s dead-interval=20s
add area=backbone interfaces=lo passive

# ---------------------------------------------------------------------
# VERIFICACION DE LA BASE
# ---------------------------------------------------------------------
# /routing ospf neighbor print     -> 3 vecinos Full (hAP-1B, hAP-4B, GW-A)
# /ip firewall nat print           -> exactamente 1 regla (masquerade)

# ==================================================================
# BLOQUE 6/7 · Modo contenedor  --  MANUAL
# ==================================================================
# 1) Subir container-<version>-arm64.npk a la raiz de Files.
# 2) /system reboot
# 3) /system device-mode update container=yes   -> confirmar con RESET
# 4) /system device-mode print                  -> container: yes

# ==================================================================
# BLOQUE 7/7 · Contenedor AdGuard Home (DNS de la Sede Sur)
# ==================================================================
# PINEAR LA IMAGEN antes de la defensa (cambiar "latest" por un tag fijo).
/container mounts add name=adguard_work src=/adguard/work dst=/opt/adguardhome/work
/container mounts add name=adguard_conf src=/adguard/conf dst=/opt/adguardhome/conf

/interface veth add name=veth1 address=10.20.254.53/24 gateway=10.20.254.1
/ip address add address=10.20.254.1/24 interface=veth1 comment=red-contenedor

/container add remote-image=adguard/adguardhome:latest interface=veth1 root-dir=disk1/adguard/root hostname=adguard mounts=adguard_work,adguard_conf start-on-boot=yes logging=yes comment="AdGuard DNS sede Sur"
/container start [find comment="AdGuard DNS sede Sur"]

# ---------------------------------------------------------------------
# ESPERAR ~60 SEGUNDOS y hacer el asistente:
#   http://10.20.254.53:3000   (crear usuario admin, dejar DNS en el 53)
# Despues pegar esto:
# ---------------------------------------------------------------------
/ip dns set servers=10.20.254.53
/ip firewall nat add chain=dstnat action=dst-nat to-addresses=10.20.254.53 to-ports=53 protocol=udp dst-port=53 in-interface-list=LAN comment="forzar DNS UDP a AdGuard"
/ip firewall nat add chain=dstnat action=dst-nat to-addresses=10.20.254.53 to-ports=53 protocol=tcp dst-port=53 in-interface-list=LAN comment="forzar DNS TCP a AdGuard"

# ---------------------------------------------------------------------
# VERIFICACION FINAL
# ---------------------------------------------------------------------
# /container print                 -> running
# http://10.20.254.53:3000         -> panel de AdGuard
# nslookup unis.edu.gt 10.20.255.1 -> responde
