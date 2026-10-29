# =====================================================================
# SXT-B  |  MikroTik SXT Lite5  |  RouterOS v6/v7  |  Punta SUR
# DCN2 - Campus UNIS Integrado - enlace inter-sede (10.99.0.0/30)
#
# Rol: punta STATION del puente inalambrico transparente hacia la Sede Norte.
# NO tiene IP ni enruta: es un cable inalambrico (D-04).
# La gestion es por MAC: WinBox > Neighbors.
#
# COMO APLICAR: igual que SXT-A, un bloque por vez.
#
# El orden importa: primero SXT-A (AP) encendido y emitiendo, despues
# SXT-B (station) asocia. Si no asocia, revisar que ambos tengan el
# MISMO ssid, la MISMA clave y el MISMO canal.
# =====================================================================


# ==================================================================
# BLOQUE 0/4 · Limpieza (opcional, recomendado si es de fabrica)
# ==================================================================
# /system reset-configuration no-defaults=yes skip-backup=yes

# ==================================================================
# BLOQUE 1/4 · Sistema
# ==================================================================
/system identity set name=SXT-B
/user set admin password="ValoValoValo2026"
/system clock set time-zone-name=America/Guatemala
/system note set show-at-login=no note="DCN2 Campus UNIS - SXT-B punta Sur (enlace inter-sede)"
/system ntp client set enabled=yes servers=pool.ntp.org
/ip service disable telnet,ftp,api,api-ssl
/ipv6 settings set disable-ipv6=yes
/ip neighbor discovery-settings set discover-interface-list=all

# ==================================================================
# BLOQUE 2/4 · Radio 5 GHz  --  perfil de seguridad + modo station-bridge
# ==================================================================
/interface wireless security-profiles add name=ptp-unis mode=dynamic-keys authentication-types=wpa2-psk wpa2-pre-shared-key="CambiarClaveEnlace2026"
# station-bridge (no "station"): mantiene el bridge transparente y deja
# pasar MACs ajenas, que es lo que necesita OSPF entre sedes.
/interface wireless set wlan1 mode=station-bridge ssid=UNIS-PTP band=5ghz-only-n channel-width=20mhz frequency=5745 country=guatemala security-profile=ptp-unis disabled=no

# ==================================================================
# BLOQUE 3/4 · Puente transparente  --  ether1 + wlan1
# ==================================================================
/interface bridge add name=br-ptp protocol-mode=none comment="puente inalambrico inter-sede"
/interface bridge port add bridge=br-ptp interface=ether1
/interface bridge port add bridge=br-ptp interface=wlan1

# ==================================================================
# BLOQUE 4/4 · Verificacion
# ==================================================================
# /interface wireless print                      -> wlan1 running, mode=station-bridge
# /interface wireless registration-table print   -> AP con signal-strength y ccq
# /interface bridge print                        -> br-ptp, 2 puertos
# /ip address print                              -> VACIO (correcto)
#
# Prueba del enlace (desde GW-B, ya con la config puesta):
# /ping 10.99.0.1 count=20        -> ~0% de perdida
# /routing ospf neighbor print    -> GW-A en Full a traves del inalambrico
