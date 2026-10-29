#!/usr/bin/env python3
"""
Generador de configuraciones RouterOS v7 para los hAP ax lite del campus.

Los .rsc generados estan pensados para PEGARSE en la terminal de WinBox
bloque por bloque (cada bloque <= 25 lineas, comandos en una sola linea)
o para importarse con /import.

Uso:  python configs/generar-haps.py
Salida: configs/rsc/hAP-NX.rsc  (9 archivos)
"""

import os

# ---------------------------------------------------------------------------
# Orden del anillo (D-09): GW -> 1 -> 2 -> 3 -> 4 -> 5 -> GW
# ---------------------------------------------------------------------------
SEDES = {
    "A": {
        "nombre": "Sede Norte",
        "gw": "GW-A",
        "dns": "10.10.255.1",
        "server": "10.10.0.1/24",
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
        "nombre": "Sede Sur",
        "gw": "GW-B",
        "dns": "10.20.255.1",
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


def bloques(sede_key: str, idx: int):
    """Devuelve [(titulo, nota, [lineas]), ...] para un nodo del anillo."""
    sede = SEDES[sede_key]
    nombre, eth1, eth2, wifi, canal, loop = sede["haps"][idx]
    prev = sede["gw"] if idx == 0 else sede["haps"][idx - 1][0]
    next_ = sede["gw"] if idx == len(sede["haps"]) - 1 else sede["haps"][idx + 1][0]

    gw_wifi, plen = wifi.split("/")
    prefijo = gw_wifi.rsplit(".", 1)[0]
    red = f"{prefijo}.0/{plen}"
    ssid = f"UNIS-{sede_key}{idx + 1}"
    es_servidor = idx == 0

    b1 = [
        f"/system identity set name={nombre}",
        f'/user set admin password="{ADMIN_PASS}"',
        "/system clock set time-zone-name=America/Guatemala",
        f'/system note set show-at-login=no note="DCN2 Campus UNIS - {sede["nombre"]} - {nombre}"',
        "/system ntp client set enabled=yes servers=pool.ntp.org",
        "/ip service disable telnet,ftp,api,api-ssl",
        "/ipv6 settings set disable-ipv6=yes",
    ]

    b2 = [
        f'set ether1 comment="{nombre}/ether1 -> {prev}/ether2"',
        f'set ether2 comment="{nombre}/ether2 -> {next_}/ether1"',
        f'set ether3 comment="{nombre}/ether3 -> {"servidor de sede" if es_servidor else "libre"}"',
        f'set ether4 comment="{nombre}/ether4 -> puerto de pruebas (opcional)"',
    ]
    b2 = ["/interface ethernet"] + b2 + [
        "",
        "/interface bridge add name=lo protocol-mode=none comment=loopback",
        f"/ip address add address={loop}/32 interface=lo comment=loopback-router-id",
        "",
        "/ip address",
        f"add address={eth1} interface=ether1 comment={prev}",
        f"add address={eth2} interface=ether2 comment={next_}",
    ]
    if es_servidor:
        b2.append(f'add address={sede["server"]} interface=ether3 comment="segmento del servidor"')

    b3 = [
        f'/interface wifi security add name=sec-unis authentication-types=wpa2-psk,wpa3-psk passphrase="{WIFI_PASS}"',
        f'/interface wifi configuration add name=cfg-wifi ssid="{ssid}" security=sec-unis country=Guatemala band=2ghz-ax channel.frequency={canal} channel.width=20mhz',
        "/interface wifi set wifi1 configuration=cfg-wifi disabled=no",
        "",
        "/interface bridge add name=br-wifi",
        "/interface bridge port add bridge=br-wifi interface=wifi1",
        '/interface bridge port add bridge=br-wifi interface=ether4 comment="puerto de pruebas"',
        "",
        "/ip address",
        f'add address={wifi} interface=br-wifi comment="red de usuarios {nombre}"',
        "",
        f"/ip pool add name=pool-wifi ranges={prefijo}.10-{prefijo}.250",
        "/ip dhcp-server add name=dhcp-wifi interface=br-wifi address-pool=pool-wifi lease-time=1h disabled=no",
        f"/ip dhcp-server network add address={red} gateway={gw_wifi} dns-server={sede['dns']}",
    ]

    b4 = [
        f"/routing ospf instance add name=ospf version=2 router-id={loop}",
        "/routing ospf area add name=backbone area-id=0.0.0.0 instance=ospf",
        "",
        "/routing ospf interface-template",
        "add area=backbone interfaces=ether1 type=ptp cost=10 hello-interval=2s dead-interval=8s",
        "add area=backbone interfaces=ether2 type=ptp cost=10 hello-interval=2s dead-interval=8s",
        'add area=backbone interfaces=br-wifi passive comment="se anuncia, no forma vecinos"',
        "add area=backbone interfaces=lo passive",
    ]
    if es_servidor:
        b4.append('add area=backbone interfaces=ether3 passive comment="segmento del servidor"')

    b5 = [
        "add chain=input action=accept connection-state=established,related,untracked",
        "add chain=input action=drop connection-state=invalid",
        "add chain=input action=accept protocol=icmp",
        "add chain=input action=accept protocol=ospf",
        'add chain=input action=accept in-interface=br-wifi comment="clientes WiFi"',
        "add chain=input action=accept in-interface=ether1",
        "add chain=input action=accept in-interface=ether2",
        'add chain=input action=accept in-interface=ether3 comment="servidor / consola (anti-bloqueo)"',
        "add chain=input action=accept in-interface=lo",
        "add chain=input action=drop",
        "add chain=forward action=accept connection-state=established,related",
        "add chain=forward action=drop connection-state=invalid",
    ]
    b5 = ["/ip firewall filter"] + b5

    return [
        ("Sistema", "identidad, clave, hora, servicios y IPv6", b1),
        ("Puertos, loopback e IPs", "etiquetas de cable + direccionamiento del anillo", b2),
        ("WiFi y DHCP", "SSID, seguridad, bridge, pool y DNS", b3),
        ("OSPF", "instancia, area 0 y plantillas de interfaz", b4),
        ("Firewall", "input con DROP final (el equipo NO lleva NAT)", b5),
    ], nombre, ssid


HEADER = """# =====================================================================
# {nombre}  |  MikroTik hAP ax lite (L41G-2axD)  |  RouterOS v7
# DCN2 - Campus UNIS Integrado - {sede}
# GENERADO por configs/generar-haps.py - NO editar a mano
#
# COMO APLICAR: WinBox > New Terminal. Pegar UN bloque por vez
# (desde la linea "BLOQUE n/5" hasta el final del bloque), esperar a que
# vuelva el prompt [admin@{nombre}] > y seguir con el siguiente.
# Si alguna linea "#" marca error, ignoralo: es solo comentario.
#
# Anillo: {prev} --ether1--> {nombre} --ether2--> {next}
# =====================================================================
"""

FOOTER = """
# =====================================================================
# VERIFICACION FINAL (copiar estos comandos uno por uno)
# =====================================================================
# /routing ospf neighbor print        -> 2 vecinos en state=Full
# /ip route print where dst-address=0.0.0.0/0
#                                     -> default por OSPF, distance=110
# /ip firewall nat print              -> TABLA VACIA (Regla 8)
# /ip dhcp-server lease print         -> clientes con DNS {dns}
# /interface wifi print               -> wifi1 running, ssid {ssid}
"""


def main() -> None:
    out_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "rsc")
    os.makedirs(out_dir, exist_ok=True)
    total = 0
    for sede_key in SEDES:
        for idx in range(len(SEDES[sede_key]["haps"])):
            lista, nombre, ssid = bloques(sede_key, idx)
            sede = SEDES[sede_key]
            prev = sede["gw"] if idx == 0 else sede["haps"][idx - 1][0]
            next_ = sede["gw"] if idx == len(sede["haps"]) - 1 else sede["haps"][idx + 1][0]
            out = [HEADER.format(nombre=nombre, sede=sede["nombre"], prev=prev, next=next_)]
            n = len(lista)
            for i, (titulo, nota, lineas) in enumerate(lista, start=1):
                out.append("")
                out.append("# " + "=" * 66)
                out.append(f"# BLOQUE {i}/{n} · {titulo}  --  {nota}")
                out.append("# " + "=" * 66)
                out.extend(lineas)
            out.append(FOOTER.format(dns=sede["dns"], ssid=ssid))
            path = os.path.join(out_dir, f"{nombre}.rsc")
            with open(path, "w", encoding="utf-8", newline="\r\n") as fh:
                fh.write("\n".join(out) + "\n")
            print(f"  {nombre}.rsc  ({len(out)} lineas)")
            total += 1
    print(f"{total} archivos generados en {out_dir}")


if __name__ == "__main__":
    main()
