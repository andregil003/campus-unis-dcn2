# 13 · Guía de verificación de configuración — Campus UNIS DCN2

> Fecha: 06/11/2026 · Estado: **todos los equipos verificados en vivo** · Rama: `main`
>
> Este documento es el runbook para entrar por SSH a cada router, ver que la configuración quedó bien y dejar evidencia antes de la defensa.

---

## 1. Acceso por SSH desde la laptop Windows

Desde PowerShell de tu laptop (`C:\Users\andregl\Documents\campus-unis-dcn2`):

```powershell
ssh admin@10.10.255.1     # GW-A  (Sede Norte)
ssh admin@10.10.255.11    # hAP-1A
ssh admin@10.10.255.12    # hAP-2A
ssh admin@10.10.255.13    # hAP-3A
ssh admin@10.10.255.14    # hAP-4A
ssh admin@10.10.255.15    # hAP-5A

ssh admin@10.20.255.1     # GW-B  (Sede Sur)
ssh admin@10.20.255.11    # hAP-1B
ssh admin@10.20.255.12    # hAP-2B
ssh admin@10.20.255.13    # hAP-3B
ssh admin@10.20.255.14    # hAP-4B

ssh admin@100.64.1.1      # ROUTER-ISP (laboratorio, hacia Norte)
ssh admin@100.64.2.1      # ROUTER-ISP (laboratorio, hacia Sur)
```

**Primera vez:** PowerShell te pregunta si confías en el fingerprint del host. Escribí `yes`.

> **Contraseñas:** no las escribimos acá por seguridad. Cada clave real está en el archivo `configs/rsc/<equipo>.rsc`, **BLOQUE 1 · Sistema**, en la línea que cambia la clave de admin. Buscá `ValoValoValo2026` y reemplacé por la clave real que pegaste en el equipo.

Si SSH no responde:
1. Entrá por WinBox → Neighbors (por MAC o IP).
2. New Terminal → `/ip service enable ssh`.
3. Volvé a intentar `ssh` desde PowerShell.

---

## 2. Acceso saltando de router en router (dentro de RouterOS)

Desde el prompt de cualquier router (`[admin@X] >`):

```
/system ssh 10.10.255.11 user=admin    # hAP-1A desde GW-A
/system ssh 10.10.255.12 user=admin    # hAP-2A desde hAP-1A
/system ssh 10.10.255.13 user=admin    # hAP-3A desde hAP-2A
/system ssh 10.10.255.14 user=admin    # hAP-4A desde hAP-3A
/system ssh 10.10.255.15 user=admin    # hAP-5A desde hAP-4A
/system ssh 10.10.255.1  user=admin    # GW-A desde hAP-5A (cierra el anillo)
```

Para volver un nivel atrás: `exit`

---

## 3. Comandos de verificación (copiar y pegar en cada equipo)

En **cada hAP**:

```
/routing ospf neighbor print       # debe mostrar 2 vecinos en estado Full
/ip firewall nat print             # debe estar VACÍO (Regla 8: ningún hAP lleva NAT)
/ip route print where dst-address=0.0.0.0/0  # 1 sola línea DAo, distance=110, sin '+'
/interface ethernet print          # puertos del anillo en estado R (RUNNING)
/export terse file=check-hAP-XA    # respaldo de configuración (cambiar XA por el nombre)
```

En **cada GW (GW-A, GW-B)**:

```
/routing ospf neighbor print       # debe mostrar 3 vecinos en estado Full
/ip firewall nat print             # 1 masquerade + 2 dst-nat DNS (Pi-hole / AdGuard)
/ip route print where dst-address=0.0.0.0/0  # estática dist=1 + OSPF dist=110
/interface ethernet print          # puertos usados en estado R
/container print                   # contenedor DNS en estado H (HEALTHY)
/export terse file=check-GW-X      # respaldo de configuración
```

---

## 4. Qué esperamos ver por equipo

### Sede Norte (Grupo A)

| Equipo | Vecinos OSPF esperados | IPs clave |
|--------|----------------------|-----------|
| GW-A | 3 Full: hAP-1A, hAP-5A, GW-B | ether7 WAN `100.64.1.2/30`, ether2 `10.10.1.1/30`, ether3 `10.10.6.2/30`, ether1 `10.99.0.1/30`, lo `10.10.255.1/32` |
| hAP-1A | 2 Full: GW-A, hAP-2A | ether1 `10.10.1.2/30`, ether2 `10.10.2.1/30`, ether3 `10.10.0.1/24`, br-wifi `192.168.1.1/24`, lo `10.10.255.11/32` |
| hAP-2A | 2 Full: hAP-1A, hAP-3A | ether1 `10.10.2.2/30`, ether2 `10.10.3.1/30`, br-wifi `192.168.2.1/24`, lo `10.10.255.12/32` |
| hAP-3A | 2 Full: hAP-2A, hAP-4A | ether1 `10.10.3.2/30`, ether2 `10.10.4.1/30`, br-wifi `192.168.3.1/24`, lo `10.10.255.13/32` |
| hAP-4A | 2 Full: hAP-3A, hAP-5A | ether1 `10.10.4.2/30`, ether2 `10.10.5.1/30`, br-wifi `192.168.4.1/24`, lo `10.10.255.14/32` |
| hAP-5A | 2 Full: hAP-4A, GW-A | ether1 `10.10.5.2/30`, ether2 `10.10.6.1/30`, br-wifi `192.168.5.1/24`, lo `10.10.255.15/32` |

### Sede Sur (Grupo B)

| Equipo | Vecinos OSPF esperados | IPs clave |
|--------|----------------------|-----------|
| GW-B | 3 Full: GW-A, hAP-1B, hAP-4B | ether1 WAN `100.64.2.2/30`, ether2 `10.20.1.1/30`, ether3 `10.20.5.2/30`, ether7 `10.99.0.2/30`, lo `10.20.255.1/32` |
| hAP-1B | 2 Full: GW-B, hAP-2B | ether1 `10.20.1.2/30`, ether2 `10.20.2.1/30`, br-wifi `192.168.11.1/24`, lo `10.20.255.11/32` |
| hAP-2B | 2 Full: hAP-1B, hAP-3B | ether1 `10.20.2.2/30`, ether2 `10.20.3.1/30`, br-wifi `192.168.12.1/24`, lo `10.20.255.12/32` |
| hAP-3B | 2 Full: hAP-2B, hAP-4B | ether1 `10.20.3.2/30`, ether2 `10.20.4.1/30`, br-wifi/bridge-wifi `192.168.13.1/24`, ether3 `10.20.0.1/24`, lo `10.20.255.13/32` |
| hAP-4B | 2 Full: hAP-3B, GW-B | ether1 `10.20.4.2/30`, ether2 `10.20.5.1/30`, br-wifi `192.168.14.1/24`, lo `10.20.255.14/32` |

---

## 5. Checklist final del campus

```
[ ] GW-A  /routing ospf neighbor print   -> 3 Full (hAP-1A, hAP-5A, GW-B)
[ ] GW-B  /routing ospf neighbor print   -> 3 Full (hAP-1B, hAP-4B, GW-A)
[ ] los 9 hAP                            -> 2 Full cada uno  (total 12 adyacencias)
[ ] cualquier hAP /ip firewall nat print -> VACÍO (Regla 8)
[ ] /ip route print en un hAP            -> default por OSPF, distance=110, sin '+'
[ ] cliente Norte: ipconfig              -> 192.168.N.x, gw 192.168.N.1, dns 10.10.255.1
[ ] cliente Norte: ping 10.10.0.100      -> responde
[ ] cliente Sur:   ping 10.10.0.100      -> responde (cruza el inter-sede)
[ ] navegar http://10.10.0.100           -> 200 OK
[ ] /ip route print en un hAP            -> default por OSPF, distance=110
[ ] /container print en GW-A             -> Pi-hole H (HEALTHY)
[ ] /container print en GW-B             -> AdGuard H (HEALTHY)
```

**Total de adyacencias OSPF esperadas: 12** (6 anillo Norte + 5 anillo Sur + 1 inter-sede).

---

## 6. Comandos de prueba cruzada (desde cualquier equipo)

```powershell
# Desde hAP-1A o desde la laptop Windows:
Test-NetConnection -ComputerName 10.20.0.100   # debe responder (servidor Sur)
Invoke-WebRequest http://10.20.0.100/health    # debe devolver 'ok'

# Desde RouterOS (cualquier GW o hAP):
/ping 10.20.0.100 count=3
/ping 10.10.0.100 count=3
/ping 100.64.1.1 count=3
/ping 100.64.2.1 count=3
/ping 10.99.0.1 count=3
/ping 10.99.0.2 count=3
```

---

## 7. Notas del día (06/11/2026)

- **ECMP corregido en Sede Norte:** `hAP-3A` tenía dos rutas default iguales (costo 30 por ambos lados del anillo). Se subió el costo de `ether2` (hacia hAP-4A) de 10 a 20 en **hAP-3A** y el costo de `ether1` (hacia hAP-3A) de 10 a 20 en **hAP-4A**. Ahora cada uno tiene una sola ruta default por OSPF.
- **Contenedores DNS:** Pi-hole en `GW-A` (`10.10.254.53`) y AdGuard en `GW-B` (`10.20.254.53`), ambos en estado `HEALTHY`.
- **Servidores:** nginx arriba en `10.10.0.100` (Norte, laptop Windows) y `10.20.0.100` (Sur, Raspberry Pi 4). Ambos responden `/health` = `ok`.
- **DNS `10.10.255.1`:** todavía falla la resolución desde la laptop porque el contenedor Pi-hole aún no se está usando como resolver desde Windows (eso se configura en el DHCP del cliente, no en el router). No bloquea el enrutamiento.

---

## 8. Cómo guardar esta evidencia

```powershell
# En cada router, después de verificar:
/export terse file=check-hAP-1A
/export terse file=check-hAP-2A
# ... etc

# Luego, desde WinBox → Files, descargar los .rsc generados y guardarlos en el repo bajo configs/backups/
```

---

> **Regla de oro:** nunca configurar en vivo durante la defensa. La red se entrega funcionando. Si hacés un cambio, registrelo en `docs/06-DECISIONES.md` y actualice este archivo.