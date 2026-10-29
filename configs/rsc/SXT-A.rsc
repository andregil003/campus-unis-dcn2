# =====================================================================
# SXT-A  |  MikroTik SXT Lite5  |  RouterOS v6/v7  |  Punta NORTE
# DCN2 - Campus UNIS Integrado - enlace inter-sede (10.99.0.0/30)
#
# Rol: punta AP del puente inalambrico transparente hacia la Sede Sur.
# NO tiene IP ni enruta: es un cable inalambrico (D-04). Las IPs del
# enlace (10.99.0.1 y 10.99.0.2) viven en los RB5009.
# La gestion es por MAC: WinBox > Neighbors (no hace falta IP).
#
# COMO APLICAR: conectar al SXT por ether1 (PoE-in), WinBox > Neighbors
# > MAC, y pegar un bloque por vez en New Terminal.
#
# Importante: el SXT sale de fabrica con la config por defecto
# (192.168.88.1, bridge propio, DHCP). El BLOQUE 0 la borra. Si el equipo
# ya esta limpio, saltar el bloque 0.
# =====================================================================


# ==================================================================
# BLOQUE 0/4 · Limpieza (opcional, recomendado si es de fabrica)
# ==================================================================
# Borra TODA la config, incluida la IP por defecto. Despues de esto solo
# se entra por MAC (WinBox > Neighbors). Requiere acceso fisico.
# /system reset-configuration no-defaults=yes skip-backup=yes

# ==================================================================
# BLOQUE 1/4 · Sistema
# ==================================================================
/system identity set name=SXT-A
/user set admin password="CambiarClaveAdmin2026"
/system clock set time-zone-name=America/Guatemala
/system note set show-at-login=no note="DCN2 Campus UNIS - SXT-A punta Norte (enlace inter-sede)"
/system ntp client set enabled=yes servers=pool.ntp.org
/ip service disable telnet,ftp,api,api-ssl
/ipv6 settings set disable-ipv6=yes
# Sin IP no hay a donde conectarse: que se vea por MAC en WinBox.
/ip neighbor discovery-settings set discover-interface-list=all

# ==================================================================
# BLOQUE 2/4 · Radio 5 GHz  --  perfil de seguridad + modo AP
# ==================================================================
/interface wireless security-profiles add name=ptp-unis mode=dynamic-keys authentication-types=wpa2-psk wpa2-pre-shared-key="CambiarClaveEnlace2026"
# 5745 MHz (canal 149) evita los canales DFS: no hay espera de radar.
/interface wireless set wlan1 mode=ap-bridge ssid=UNIS-PTP band=5ghz-only-n channel-width=20mhz frequency=5745 country=guatemala security-profile=ptp-unis disabled=no

# ==================================================================
# BLOQUE 3/4 · Puente transparente  --  ether1 + wlan1
# ==================================================================
# protocol-mode=none: sin STP, el anillo lo controla OSPF en los RB5009.
# El puente NO lleva IP a proposito.
/interface bridge add name=br-ptp protocol-mode=none comment="puente inalambrico inter-sede"
/interface bridge port add bridge=br-ptp interface=ether1
/interface bridge port add bridge=br-ptp interface=wlan1

# ==================================================================
# BLOQUE 4/4 · Verificacion
# ==================================================================
# /interface wireless print             -> wlan1 running, mode=ap-bridge
# /interface wireless registration-table print   -> (vacio hasta que SXT-B asocie)
# /interface bridge print               -> br-ptp, 2 puertos
# /ip address print                     -> VACIO (correcto: sin IP)
#
# Ajuste fino de alineacion (hacer con SXT-B ya asociado):
# /interface wireless monitor wlan1     -> signal-strength, ccq
# Objetivo: -60 dBm o mejor y ccq > 90%. Con 20 MHz el enlace da ~80-100 Mbps.
