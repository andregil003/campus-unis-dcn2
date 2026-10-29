# =====================================================================
# GW-A  |  MikroTik RB5009UG+S+IN  |  RouterOS v7  |  Sede Norte
# DCN2 - Campus UNIS Integrado - Grupo A
# Rol: ABR/ASBR area 0, salida a Internet, DNS/dispositivo Pi-hole y
#      gateway de las redes internas del campus Norte.
#
# COMO APLICAR: WinBox > New Terminal. Pegar UN bloque por vez y esperar
# el prompt [admin@GW-A] > antes de seguir. Los bloques 1 a 5 son la base;
# el 6 es manual (boton reset); el 7 es el contenedor.
# Cambiar antes de pegar: la clave de admin (BLOQUE 1).
#
# MAPA DE PUERTOS
#   ether1  -> ISP / router del catedratico        100.64.1.2/30
#   ether2  -> hAP-1A ether1                        10.10.1.1/30
#   ether3  -> hAP-5A ether2                        10.10.6.2/30
#   ether7  -> GW-B ether7 (inter-sede)             10.99.0.1/30
#   ether4/5/6/8 -> consola y libres (lista MGMT)
#   lo      -> loopback                             10.10.255.1/32
# =====================================================================


# ==================================================================
# BLOQUE 1/7 · Sistema  --  identidad, clave, hora, servicios y IPv6
# ==================================================================
/system identity set name=GW-A
/user set admin password="CambiarClaveAdmin2026"
/system clock set time-zone-name=America/Guatemala
/system note set show-at-login=no note="DCN2 Campus UNIS - Sede Norte - GW-A (RB5009)"
/system ntp client set enabled=yes servers=pool.ntp.org
/ip service disable telnet,ftp,api,api-ssl
/ipv6 settings set disable-ipv6=yes

# ==================================================================
# BLOQUE 2/7 · Puertos, listas y loopback
# ==================================================================
/interface ethernet
set ether1 comment="GW-A/ether1 -> ISP (WAN) 100.64.1.2/30"
set ether2 comment="GW-A/ether2 -> hAP-1A/ether1 10.10.1.1/30"
set ether3 comment="GW-A/ether3 -> hAP-5A/ether2 10.10.6.2/30"
set ether7 comment="GW-A/ether7 -> GW-B/ether7 10.99.0.1/30 inter-sede"
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
/ip address add address=10.10.255.1/32 interface=lo comment=loopback-router-id-dns

# ==================================================================
# BLOQUE 3/7 · Direcciones IP y DNS
# ==================================================================
/ip address
add address=100.64.1.2/30 interface=ether1 comment=WAN
add address=10.10.1.1/30 interface=ether2 comment=hAP-1A
add address=10.10.6.2/30 interface=ether3 comment=hAP-5A-cierre-anillo
add address=10.99.0.1/30 interface=ether7 comment=inter-sede

/ip dns set allow-remote-requests=yes servers=1.1.1.1,8.8.8.8

# ==================================================================
# BLOQUE 4/7 · NAT, ruta por defecto y firewall
# ==================================================================
# Una sola regla NAT en todo el campus (Regla 8).
/ip firewall nat add chain=srcnat action=masquerade out-interface-list=WAN comment="salida a Internet"

# distance=1 gana siempre sobre OSPF (110). check-gateway=arp la retira
# cuando el ISP desaparece -> el default de la sede vecina toma el relevo.
/ip route add dst-address=0.0.0.0/0 gateway=100.64.1.1 distance=1 check-gateway=arp comment=default-ISP

# MGMT va ANTES del DROP: si te conectas por ether4/5/6/8 no te bloqueas.
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

# ==================================================================
# BLOQUE 5/7 · OSPF  --  area 0 + anuncio del default
# ==================================================================
# originate-default=if-installed: el default se anuncia SOLO si hay ruta
# por defecto instalada. Es el mecanismo de failover de la Regla 3/4.
/routing ospf instance add name=ospf version=2 router-id=10.10.255.1 originate-default=if-installed
/routing ospf area add name=backbone area-id=0.0.0.0 instance=ospf

/routing ospf interface-template
add area=backbone interfaces=ether2 type=ptp cost=10 hello-interval=2s dead-interval=8s
add area=backbone interfaces=ether3 type=ptp cost=10 hello-interval=2s dead-interval=8s
add area=backbone interfaces=ether7 type=ptp cost=100 hello-interval=5s dead-interval=20s
add area=backbone interfaces=lo passive

# ---------------------------------------------------------------------
# VERIFICACION DE LA BASE (copiar uno por uno)
# ---------------------------------------------------------------------
# /routing ospf neighbor print     -> 3 vecinos Full (hAP-1A, hAP-5A, GW-B)
#                                  (GW-B aparece cuando se configure la Sede Sur)
# /ip address print                -> 4 IPs + 10.10.255.1/32 en lo
# /ip firewall nat print           -> exactamente 1 regla (masquerade)
# /ip route print where dst-address=0.0.0.0/0   -> default-ISP distance=1 activa

# ==================================================================
# BLOQUE 6/7 · Modo contenedor  --  MANUAL, requiere tocar el equipo
# ==================================================================
# 1) Descargar de download.mikrotik.com el paquete de LA MISMA version
#    que tiene el equipo: container-<version>-arm64.npk
# 2) WinBox > Files: arrastrar el .npk a la raiz del router.
# 3) /system reboot     (esperar ~2 min y reconectar)
# 4) Ejecutar esta linea y CONFIRMAR CON EL BOTON RESET FISICO:
#        /system device-mode update container=yes
#    (el router pide pulsar reset; si no aparece el aviso, desenchufar
#     y volver a enchufar la corriente = cold reboot)
# 5) Comprobar:
#        /system device-mode print      -> container: yes
#        /container print               -> tabla vacia, sin errores

# ==================================================================
# BLOQUE 7/7 · Contenedor Pi-hole (DNS del campus Norte)
# ==================================================================
# PINEAR LA IMAGEN ANTES DE LA DEFENSA: cambiar "latest" por el tag que
# aparezca en /container print tras el primer pull. Un cambio de upstream
# el dia de la defensa rompe el DNS de todo el campus.
/container mounts add name=pihole_etc src=/pihole/etc dst=/etc/pihole
/container mounts add name=pihole_dnsmasq src=/pihole/dnsmasq.d dst=/etc/dnsmasq.d

/container envs add name=pihole_envs key=TZ value=America/Guatemala
/container envs add name=pihole_envs key=FTLCONF_webserver_api_password value="CambiarClavePihole2026"
/container envs add name=pihole_envs key=FTLCONF_dns_upstreams value="1.1.1.1;8.8.8.8"
/container envs add name=pihole_envs key=FTLCONF_dns_listeningMode value=all
/container envs add name=pihole_envs key=FTLCONF_misc_etc_dnsmasq_d value=true

# veth: .53 = contenedor, .1 = extremo del router. Verificar el disco
# con /disk print (normalmente disk1).
/interface veth add name=veth1 address=10.10.254.53/24 gateway=10.10.254.1
/ip address add address=10.10.254.1/24 interface=veth1 comment=red-contenedor

/container add remote-image=pihole/pihole:latest interface=veth1 root-dir=disk1/pihole/root hostname=pihole envlist=pihole_envs mounts=pihole_etc,pihole_dnsmasq start-on-boot=yes logging=yes comment="Pi-hole DNS campus Norte"
/container start [find comment="Pi-hole DNS campus Norte"]

# ---------------------------------------------------------------------
# ESPERAR ~60 SEGUNDOS (mirar /container print hasta que diga running)
# y recien entonces pegar este bloque: apunta el DNS al Pi-hole.
# ---------------------------------------------------------------------
/ip dns set servers=10.10.254.53
/ip firewall nat add chain=dstnat action=dst-nat to-addresses=10.10.254.53 to-ports=53 protocol=udp dst-port=53 in-interface-list=LAN comment="forzar DNS UDP a Pi-hole"
/ip firewall nat add chain=dstnat action=dst-nat to-addresses=10.10.254.53 to-ports=53 protocol=tcp dst-port=53 in-interface-list=LAN comment="forzar DNS TCP a Pi-hole"

# ---------------------------------------------------------------------
# VERIFICACION FINAL
# ---------------------------------------------------------------------
# /container print                 -> running
# /ip dns print                    -> servers: 10.10.254.53
# /ip firewall nat print           -> 1 masquerade + 2 dst-nat
# Desde una laptop:  nslookup unis.edu.gt 10.10.255.1     -> responde
# Panel:             http://10.10.254.53/admin
#
# LIMITACION CONOCIDA (R-07): check-gateway=arp detecta caida de ENLACE.
# Si el ISP cae pero el cable sigue arriba, el default no se retira.
# Mitigacion opcional:
#   /tool netwatch add host=1.1.1.1 interval=10s timeout=2s down-script="/ip route disable [find comment=\"default-ISP\"]" up-script="/ip route enable [find comment=\"default-ISP\"]"
