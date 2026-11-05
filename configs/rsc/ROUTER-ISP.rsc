# =====================================================================
# ROUTER-ISP  |  MikroTik RB3011UiAS  |  RouterOS 7.24.5  |  Laboratorio
# DCN2 - Campus UNIS Integrado  -  "Router ISP" del diagrama v3
# Serial: 783E064858A9   |   Config verificada en vivo: 03/11/2026 16:43
#
# ROL: simula el ISP del catedratico. NO habla OSPF, NO hace DHCP,
#      NO hace DNS, NO filtra. Solo enruta y hace NAT hacia el uplink.
#
# MAPA DE PUERTOS (coincide con el diagrama: e1/e2/e3)
#   sfp1    -> uplink al laboratorio, DHCP              (e1: lab DHCP)
#   ether2  -> GW-A ether7   100.64.1.1/30              (e2: Norte; el cable va al ether7 de GW-A)
#   ether3  -> DANADO (sin enlace). No usar.
#   ether5  -> GW-B ether1   100.64.2.1/30              (e5: Sur, reemplaza al ether3 danado)
#   ether7  -> 10.0.1.1/25 "Puerto 7 - Rodrigo Quiroa"  (OTRO GRUPO - no tocar)
#   ether10 -> libre (se elimino la LAN de fabrica 192.168.26.0/24)
#
# COMO APLICAR: WinBox > New Terminal, un bloque por vez.
# =====================================================================


# ==================================================================
# BLOQUE 0/3 · Limpieza de la configuracion de fabrica
# ==================================================================
# El equipo sale con una LAN 192.168.26.1/24 + pool + DHCP server que
# no tienen nada que ver con el rol de ISP. Idempotente.
/ip dhcp-server remove [find]
/ip pool remove [find]
/ip dhcp-server network remove [find]
/ip address remove [find interface=ether10]
/ip dns set allow-remote-requests=no
# Verificar: /ip pool print -> vacio | /ip dhcp-server print -> vacio

# ==================================================================
# BLOQUE 1/3 · Sistema
# ==================================================================
/system identity set name=ROUTER-ISP
/system clock set time-zone-name=America/Guatemala
/system note set show-at-login=no note="DCN2 Campus UNIS - ROUTER-ISP (RB3011) - e2=Norte 100.64.1.1/30 / e5=Sur 100.64.2.1/30"

# ==================================================================
# BLOQUE 2/3 · Uplink, una /30 por sede y NAT
# ==================================================================
# e1 = lab DHCP. add-default-route=yes instala 0.0.0.0/0 distance=1.
/ip dhcp-client add interface=sfp1 name=client1

/interface ethernet
set ether2 comment="ISP/e2 -> GW-A/ether7 100.64.1.1/30 [Norte]"
set ether3 comment="DANADO - no-link"
set ether5 comment="ISP/e5 -> GW-B/ether1 100.64.2.1/30 [Sur] (ether3 danado)"

/ip address
add address=100.64.1.1/30 interface=ether2 comment="WAN-Norte-GW-A"
add address=100.64.2.1/30 interface=ether5 comment="WAN-Sur-GW-B"

# Una sola regla NAT en el ISP, hacia el uplink del laboratorio.
/ip firewall nat add chain=srcnat action=masquerade out-interface=sfp1 comment="salida a Internet (uplink lab)"

# ==================================================================
# BLOQUE 3/3 · Verificacion
# ==================================================================
# /ip address print
#   -> 172.18.4.x/24 (D, sfp1) + 100.64.1.1/30 (ether2) + 100.64.2.1/30 (ether3)
# /ip route print where dst-address=0.0.0.0/0
#   -> DAd  via <gateway del lab>  distance=1
# /ip firewall nat print
#   -> exactamente 1 regla masquerade
# /tool ping 1.1.1.1 count=3        -> internet del laboratorio OK
# /tool ping 100.64.1.2 count=3     -> GW-A responde (cable en ether2)
# /tool ping 100.64.2.2 count=3     -> GW-B responde (cable en ether5)
#
# NOTA: si las rutas 100.64.x.0/30 salen con la letra I (INACTIVE) es
# porque el puerto no tiene link. Se activan solas al conectar el GW.
#
# NOTA: doble NAT (cliente -> GW -> ISP) es intencional. El traceroute
# del failover mostrara dos saltos privados antes de salir al lab.


# =====================================================================
# BACKUP Y RESTAURACION
# =====================================================================
# En el equipo (crea DOS archivos en Files, descargarlos por WinBox):
#   /system backup save name=ROUTER-ISP-2026-11-03 dont-encrypt=yes
#   /export file=ROUTER-ISP-2026-11-03
#
# Restaurar el binario (SOLO misma version de RouterOS, 7.24.5):
#   /system backup load name=ROUTER-ISP-2026-11-03.backup
#
# Restaurar desde texto (portable, sirve en cualquier 7.x):
#   /import file-name=ROUTER-ISP-2026-11-03.rsc
#
# Equipo inaccesible: WinBox > Neighbors > conectar por MAC y reimportar,
# o netinstall como ultimo recurso.
# =====================================================================
