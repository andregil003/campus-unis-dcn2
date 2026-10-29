# Configuraciones — DCN2 Campus UNIS (Sede Norte / Grupo A)

Carpeta de **configuración como código**. Nada se escribe a mano dos veces.

```
configs/
├── generar-haps.py     genera los 9 hAP desde una tabla (no editar los .rsc a mano)
└── rsc/
    ├── GW-A.rsc        RB5009 Sede Norte  (WAN, NAT, OSPF ASBR, Pi-hole)
    ├── GW-B.rsc        RB5009 Sede Sur    (coordinación para Grupo B / AdGuard)
    ├── hAP-1A.rsc … hAP-5A.rsc   anillo Norte + red de usuarios
    └── hAP-1B.rsc … hAP-4B.rsc   anillo Sur
```

## 1. Antes de empezar (una sola vez)

1. Actualizar todos los equipos a la **misma versión** de RouterOS 7 (los `.rsc` usan `veth` y `container`,
   que requieren ≥ 7.16). `hAP ax lite` y `RB5009` son **arm64** → bajar el paquete `container-<ver>-arm64.npk`
   de `download.mikrotik.com` y subirlo a la raíz de Files.
2. Cambiar en los archivos **antes de pegar**:
   - `CambiarClaveAdmin2026` → clave real de admin.
   - `CambiarClaveWiFi2026` → clave real del WiFi (mínimo 8 caracteres, WPA2/WPA3).
   - `CambiarClavePihole2026` → clave del panel de Pi-hole.
3. Confirmar la IP del ISP (`100.64.1.1` / `100.64.2.1`). Si el catedrático entrega otro gateway,
   se cambia en **una** línea de cada GW (ruta `default ISP`).

## 2. Orden de aplicación

El orden importa: los hAP necesitan el `ether1` apuntando a un vecino que ya responde a OSPF.

| Paso | Equipo | Archivo | Tiempo |
|---|---|---|---|
| 1 | GW-A | `GW-A.rsc` **Fase A** | 10 min |
| 2 | hAP-1A | `hAP-1A.rsc` | 10 min |
| 3 | hAP-2A → hAP-5A | `hAP-2A.rsc` … `hAP-5A.rsc` | 10 min c/u |
| 4 | GW-B + hAP-1B…4B | equivalente en Sede Sur | — |
| 5 | GW-A / GW-B | **Fase B** (modo container) | 5 min + reboot |
| 6 | GW-A / GW-B | **Fase C** (contenedor DNS) | 15 min |

Forma de aplicar: arrastrar el `.rsc` a **Files** del equipo y en la terminal `import file-name=GW-A.rsc`,
o abrir el archivo y pegar el contenido en la terminal. En ambos casos, **una fase a la vez** y verificar
antes de seguir.

## 3. Verificación mínima por equipo

| Equipo | Comando | Esperado |
|---|---|---|
| GW-A / GW-B | `/routing ospf neighbor print` | 3 vecinos en `Full` |
| hAP | `/routing ospf neighbor print` | 2 vecinos en `Full` |
| hAP | `/ip firewall nat print` | **vacío** (Regla 8) |
| hAP | `/ip route print where dst-address=0.0.0.0/0` | default vía OSPF, `distance=110` |
| GW | `/ip route print where dst-address=0.0.0.0/0` | estática `distance=1` activa |
| Cliente | `ipconfig /all` | IP de `10.10.1x.0/24`, gateway `.1`, DNS `10.10.255.1` |
| Cliente | `ping 10.10.0.100` | responde (servidor de la sede) |
| Cliente Sur | `ping 10.10.0.100` | responde a través del inter-sede |

Total del campus: **12 adyacencias** (6 anillo Norte + 5 anillo Sur + 1 inter-sede).

## 4. Regenerar los hAP

```powershell
# editar la tabla SEDES en generar-haps.py (IPs, SSID, canal) y luego:
python configs\generar-haps.py
```

Los `.rsc` de los hAP se sobrescriben. Los GW (`GW-A.rsc`, `GW-B.rsc`) son manuales porque no son simétricos.

## 5. Lo que NO se toca

- **Ningún hAP lleva reglas NAT.** Si un compañero agrega un `masquerade` en un hAP, se pierden los
  8 puntos de OSPF aunque todo siga funcionando.
- Los puertos `ether1`/`ether2` son **tránsito L3**: no van al bridge `br-wifi`.
- El `SSID` no comparte bridge con la red de servidores (`10.10.0.0/24`), que cuelga de `hAP-1A ether3`.
