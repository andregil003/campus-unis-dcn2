#!/usr/bin/env python3
"""
Generador de configuraciones RouterOS v7 para los hAP ax lite del campus.

Uso:  python configs/generar-haps.py
Salida: configs/rsc/hAP-NX.rsc  (9 archivos)

No editar los .rsc a mano: se regeneran desde esta tabla.
"""

import os

# ---------------------------------------------------------------------------
# Tabla de nodos.  Cada nodo del anillo tiene exactamente 2 enlaces de transito
# (ether1 hacia atras, ether2 hacia adelante); el ultimo cierra contra el GW.
# Orden del anillo (decision D-09): GW -> 1 -> 2 -> 3 -> 4 -> 5 -> GW
# ---------------------------------------------------------------------------
SEDES = {
    "A": {
        "nombre": "Sede Norte (Grupo A)",
        "base": "10.10",
        "gw": "GW-A",
        "dns": "10.10.255.1",
        "lo_base": "10.10.255",
        "server": "10.10.0.1/24",       # solo hAP-1A: segmento del servidor
        "haps": [
            # nombre, ether1 (uplink), ether2 (downlink), wifi, canal, loopback
            ("hAP-1A", "10.10.1.2/30", "10.10.2.1/30", "10.10.11.1/24", 2412, "10.10.255.11"),
            ("hAP-2A", "10.10.2.2/30", "10.10.3.1/30", "10.10.12.1/24", 2437, "10.10.255.12"),
            ("hAP-3A", "10.10.3.2/30", "10.10.4.1/30", "10.10.13.1/24", 2462, "10.10.255.13"),
            ("hAP-4A", "10.10.4.2/30", "10.10.5.1/30", "10.10.14.1/24", 2412, "10.10.255.14"),
            ("hAP-5A", "10.10.5.2/30", "10.10.6.1/30", "10.10.15.1/24", 2437, "10.10.255.15"),
        ],
    },
    "B": {
        "nombre": "Sede Sur (Grupo B)",
        "base": "10.20",
        "gw": "GW-B",
        "dns": "10.20.255.1",
        "lo_base": "10.20.255",
        "server": "10.20.0.1/24",
        "haps": [
            ("hAP-1B", "10.20.1.2/30", "10.20.2.1/30", "10.20.11.1/24", 2412, "10.20.255.11"),
            ("hAP-2B", "10.20.2.2/30", "10.20.3.1/30", "10.20.12.1/24", 2437, "10.20.255.12"),
            ("hAP-3B", "10.20.3.2/30", "10.20.4.1/30", "10.20.13.1/24", 2462, "10.20.255.13"),
            ("hAP-4B", "10.20.4.2/30", "10.20.5.1/30", "10.20.14.1/24", 2412, "10.20.255.14"),
        ],
    },
}

WIFI_PASS = "CambiarClaveWiFi2026"
ADMIN_PASS = "CambiarClaveAdmin2026"

TEMPLATE = """\
# =====================================================================
# {nombre}  |  MikroTik hAP ax lite (L41G-2axD)  |  RouterOS v7
# DCN2 - Campus UNIS Integrado - {sede}
# GENERADO por configs/generar-haps.py - NO editar a mano
# Anillo: {prev} --ether1--> {nombre} --ether2--> {next}
# Puertos: ether1/ether2 = transito L3 (sin bridge) | ether3/ether4 = acceso
# Sin NAT en este equipo (Regla 8) - verificado al final del archivo
# =====================================================================

# --- Identidad y sistema ---------------------------------------------
/system identity set name={nombre}
/user set admin password="{admin}"
/system clock set time-zone-name=America/Guatemala
/system note set show-at-login=no note="DCN2 Campus UNIS - {sede} - {nombre}"
/system ntp client set enabled=yes servers=pool.ntp.org
/ip service disable telnet,ftp,api,api-ssl
/ipv6 settings set disable-ipv6=yes

# --- Etiquetas de cableado (puntos extra) ----------------------------
/interface ethernet
set ether1 comment="{nombre}/ether1 -> {prev}/ether2"
set ether2 comment="{nombre}/ether2 -> {next}/ether1"
{ether3_comment}set ether4 comment="{nombre}/ether4 -> laptop de pruebas (opcional)"

# --- Loopback (router-id estable + IP de gestion) --------------------
/interface bridge add name=lo protocol-mode=none comment="loopback"
/ip address add address={loopback}/32 interface=lo comment="loopback / router-id"

# --- WiFi ------------------------------------------------------------
# NOTA: paquete 'wifi' (no 'wireless'). Verificar nombres con '?' en tu version.
/interface wifi security
add name=sec-unis authentication-types=wpa2-psk,wpa3-psk passphrase="{wifi_pass}"
/interface wifi configuration
add name=cfg-wifi ssid="{ssid}" security=sec-unis country=Guatemala \\
    band=2ghz-ax channel.frequency={canal} channel.width=20mhz
/interface wifi set wifi1 configuration=cfg-wifi disabled=no

/interface bridge add name=br-wifi
/interface bridge port
add bridge=br-wifi interface=wifi1
add bridge=br-wifi interface=ether4 comment="puerto de pruebas (opcional)"

# --- Direcciones IP --------------------------------------------------
/ip address
add address={wifi} interface=br-wifi comment="red de usuarios {nombre}"
add address={eth1} interface=ether1 comment="{prev}"
add address={eth2} interface=ether2 comment="{next}"
{ether3_addr}
# --- DHCP (sin NAT: el trafico sale enrutado hasta el GW de la sede) --
/ip pool add name=pool-wifi ranges={pool_ini}-{pool_fin}
/ip dhcp-server add name=dhcp-wifi interface=br-wifi address-pool=pool-wifi lease-time=1h disabled=no
/ip dhcp-server network add address={red_wifi} gateway={gw_wifi} dns-server={dns_server}

# --- OSPF area 0 -----------------------------------------------------
/routing ospf instance add name=ospf version=2 router-id={loopback}
/routing ospf area add name=backbone area-id=0.0.0.0 instance=ospf
/routing ospf interface-template
add area=backbone interfaces=ether1 type=ptp cost=10 hello-interval=2s dead-interval=8s
add area=backbone interfaces=ether2 type=ptp cost=10 hello-interval=2s dead-interval=8s
add area=backbone interfaces=br-wifi passive comment="red de usuarios: se anuncia, no forma vecinos"
add area=backbone interfaces=lo passive
{ospf_extra}
# --- Firewall minimo -------------------------------------------------
/ip firewall filter
add chain=input action=accept connection-state=established,related,untracked comment="Established"
add chain=input action=drop connection-state=invalid comment="Invalid"
add chain=input action=accept protocol=icmp comment="ICMP (pruebas de conectividad)"
add chain=input action=accept protocol=ospf comment="OSPF"
add chain=input action=accept in-interface=br-wifi comment="Clientes WiFi"
add chain=input action=accept in-interface=ether1 comment="Transito (gestion)"
add chain=input action=accept in-interface=ether2 comment="Transito (gestion)"
{ether3_fw}add chain=input action=accept in-interface=lo comment="Loopback"
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
# /ip dhcp-server lease print           -> clientes con IP y DNS {dns_server}
"""


def render(sede_key: str, idx: int) -> tuple[str, str]:
    sede = SEDES[sede_key]
    nombre, eth1, eth2, wifi, canal, loop = sede["haps"][idx]

    prev = sede["gw"] if idx == 0 else sede["haps"][idx - 1][0]
    next_ = sede["gw"] if idx == len(sede["haps"]) - 1 else sede["haps"][idx + 1][0]

    # segmento del servidor solo en el primer nodo de la sede
    es_servidor = idx == 0
    if es_servidor:
        ether3_comment = f'set ether3 comment="{nombre}/ether3 -> servidor de sede"\n'
        ether3_addr = f'add address={sede["server"]} interface=ether3 comment="segmento del servidor"\n'
        ether3_fw = 'add chain=input action=accept in-interface=ether3 comment="Servidor"\n'
        ospf_extra = 'add area=backbone interfaces=ether3 passive comment="segmento del servidor"\n'
    else:
        ether3_comment = f'set ether3 comment="{nombre}/ether3 -> libre"\n'
        ether3_addr = ""
        ether3_fw = ""
        ospf_extra = ""

    # wifi viene como "10.10.11.1/24"
    gw_wifi, plen = wifi.split("/")
    prefijo = gw_wifi.rsplit(".", 1)[0]      # "10.10.11"
    red_wifi = f"{prefijo}.0/{plen}"         # "10.10.11.0/24"
    pool_ini = f"{prefijo}.10"
    pool_fin = f"{prefijo}.250"

    txt = TEMPLATE.format(
        nombre=nombre,
        sede=sede["nombre"],
        prev=prev,
        next=next_,
        admin=ADMIN_PASS,
        wifi_pass=WIFI_PASS,
        ssid="UNIS-" + sede_key + str(idx + 1),
        canal=canal,
        loopback=loop,
        eth1=eth1,
        eth2=eth2,
        wifi=wifi,
        red_wifi=red_wifi,
        gw_wifi=gw_wifi,
        pool_ini=pool_ini,
        pool_fin=pool_fin,
        dns_server=sede["dns"],
        ether3_comment=ether3_comment,
        ether3_addr=ether3_addr,
        ether3_fw=ether3_fw,
        ospf_extra=ospf_extra,
    )
    return nombre, txt


def main() -> None:
    out_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "rsc")
    os.makedirs(out_dir, exist_ok=True)
    total = 0
    for sede_key in SEDES:
        for idx in range(len(SEDES[sede_key]["haps"])):
            nombre, txt = render(sede_key, idx)
            path = os.path.join(out_dir, f"{nombre}.rsc")
            with open(path, "w", encoding="utf-8", newline="\r\n") as fh:
                fh.write(txt)
            print(f"  {nombre}.rsc  ({len(txt)} bytes)")
            total += 1
    print(f"{total} archivos generados en {out_dir}")


if __name__ == "__main__":
    main()
