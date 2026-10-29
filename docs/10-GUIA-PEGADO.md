# 10 · Guía de pegado: configurar cada router en WinBox, paso a paso

**Para qué sirve este documento:** abrir WinBox, conectarse a un equipo, pegar un bloque, verificar, seguir.
Sin adivinar nada. Cada equipo tiene su archivo en `configs/rsc/` y aquí está el porqué de cada bloque.

---

## 1. Antes de tocar un solo router (15 min, una sola vez)

| # | Qué | Cómo se comprueba |
|---|---|---|
| 1 | Los 11 equipos tienen **la misma versión** de RouterOS 7 | `/system resource print` → `version:` |
| 2 | Versión **≥ 7.16** (los GW usan `veth` + `container`) | igual |
| 3 | Descargado el paquete `container-<version>-arm64.npk` | `download.mikrotik.com/routeros/<version>/` |
| 4 | Claves reales reemplazadas en los archivos | buscar `CambiarClave` en `configs/rsc/` |
| 5 | Un pendrive / carpeta con los `.rsc` a mano | para el plan B (§5) |

**Conectarse a un equipo recién sacado de la caja:** WinBox → pestaña **Neighbors** → aparece por MAC →
`Connect`. La primera vez entra **sin contraseña** y con la config de fábrica (`192.168.88.1`). No hay que
resetear nada: al pegar el BLOQUE 1 cambia nombre y clave.

> ⚠️ **Regla de oro del pegado:** un bloque por vez. El prompt tiene que volver
> (`[admin@GW-A] >`) **antes** de pegar el siguiente. Pegar 80 líneas de golpe es la forma más común de
> terminar con `bad command name` porque WinBox mete caracteres de más.

---

## 2. Método A — pegar bloques en la terminal (el que pidió André)

1. WinBox → **New Terminal**.
2. Abrir el `.rsc` del equipo en VS Code / Notepad.
3. Seleccionar **desde la línea `# BLOQUE n/7 · ...` hasta la línea en blanco anterior al bloque siguiente**.
4. Ctrl+C → clic en la terminal → Ctrl+V.
5. Esperar el prompt. Mirar si alguna línea dio error (§4).
6. Correr las verificaciones que están al final del bloque.
7. Siguiente bloque.

**Orden obligatorio:** GW-A (bloques 1-5) → hAP-1A → hAP-2A → hAP-3A → hAP-4A → hAP-5A → el mismo orden
en la Sede Sur. Los hAP necesitan que su vecino de `ether1` ya esté configurado para que OSPF levante.

---

## 3. Qué hace cada bloque (la explicación que hay que poder defender)

### En los GW (RB5009) — 7 bloques

| Bloque | Qué hace | Por qué |
|---|---|---|
| **1 · Sistema** | Identidad, clave, zona horaria, NTP, desactiva telnet/ftp/api, apaga IPv6 | Los logs con hora correcta son requisito de auditoría; telnet/ftp son agujeros |
| **2 · Puertos y listas** | Etiquetas de cable, listas `WAN`/`LAN`/`MGMT`, loopback `/32` | Las etiquetas son puntos de la defensa; `MGMT` es el **seguro anti-bloqueo** (si te conectás por ether4/5/6/8 nunca te quedás afuera al aplicar el firewall) |
| **3 · IPs y DNS** | 4 direcciones + loopback | Cada /30 es un enlace; el loopback es `router-id` estable y la IP de DNS del campus |
| **4 · NAT, default y firewall** | 1 sola regla `masquerade`, estática `distance=1`, input con DROP final | Una sola regla NAT en todo el campus (Regla 8). La estática gana sobre OSPF por distancia (1 vs 110) |
| **5 · OSPF** | Instancia, area 0, plantillas `ptp` con costo y timers, `originate-default=if-installed` | Es el corazón del failover: el default se anuncia **solo si existe** ruta por defecto instalada |
| **6 · Modo contenedor** | Manual: subir `.npk`, reboot, `device-mode update`, **botón reset físico** | Sin esto el contenedor no arranca. Es el único paso que exige tocar el fierro |
| **7 · Contenedor** | `veth` + Pi-hole/AdGuard + apuntar el DNS + `dst-nat` | DNS centralizado y filtrado; el `dst-nat` impide que un cliente se salte el filtro poniéndose 8.8.8.8 |

### En los hAP ax lite — 5 bloques

| Bloque | Qué hace | Por qué |
|---|---|---|
| **1 · Sistema** | Igual que en el GW | Consistencia de flota |
| **2 · Puertos, loopback e IPs** | `ether1`/`ether2` = tránsito L3 **sin bridge**, loopback, IPs del anillo | Si `ether1/ether2` fueran al bridge, el anillo sería L2 y OSPF no formaría vecinos correctos |
| **3 · WiFi y DHCP** | `security` + `configuration` + `bridge` + pool + DHCP | Es lo que **faltaba** en las plantillas del compañero: sin esto no hay red de usuarios |
| **4 · OSPF** | Instancia, area 0, `ether1/ether2` como `ptp`, `br-wifi` y `lo` **passive** | `passive` anuncia la red al resto del campus sin intentar formar vecinos en el WiFi |
| **5 · Firewall** | Input con `DROP` final | El equipo deja de estar abierto a cualquiera que se conecte al SSID |

---

## 4. Errores esperables y qué hacer

| Mensaje | Qué significa | Qué hacer |
|---|---|---|
| `bad command name` / caracteres raros | El pegado se corrompió | Repegar ese bloque **de a 5 líneas**. Si sigue, usar el plan B (§5) |
| `no such item` en `set ether4` | Tu hAP tiene menos puertos | Ignorar esa línea y borrar el `bridge port` de `ether4` |
| `expected end of command` en el bloque WiFi | Tu versión usa otra sintaxis de `wifi` | `/interface wifi print` y adaptar: en 7.13+ es `security` + `configuration` (lo que usa el archivo) |
| `input does not match any value of band` | Tu build no acepta `2ghz-ax` | Cambiar a `band=2ghz-n` (funciona igual, más lento) |
| `failure: already have such address` | Estás re-aplicando | Ignorar: es idempotente donde importa |
| Después del firewall perdiste WinBox | Te conectaste por un puerto no permitido | Conectar por `ether3`, `ether4` o el WiFi |

---

## 5. Plan B — importar el archivo (más robusto que pegar)

1. WinBox → **Files** → arrastrar el `.rsc` a la raíz del router.
2. En la terminal: `/import file-name=hAP-1A.rsc`
3. Si hay errores, primero en seco: `/import file-name=hAP-1A.rsc verbose=yes dry-run`

Funciona igual porque los comentarios `#` son válidos en RouterOS, pero pierde el control bloque por bloque
(no ves en qué punto falló).

---

## 6. Orden completo y tiempo estimado

| # | Equipo | Archivo | Bloques | Tiempo | Verificación clave |
|---|---|---|---|---|---|
| 1 | GW-A | `GW-A.rsc` | 1-5 | 15 min | 2 vecinos (hAP-1A, hAP-5A) |
| 2 | hAP-1A | `hAP-1A.rsc` | 1-5 | 10 min | 2 vecinos + DHCP entrega IP |
| 3 | hAP-2A | `hAP-2A.rsc` | 1-5 | 8 min | 2 vecinos |
| 4 | hAP-3A | `hAP-3A.rsc` | 1-5 | 8 min | 2 vecinos |
| 5 | hAP-4A | `hAP-4A.rsc` | 1-5 | 8 min | 2 vecinos |
| 6 | hAP-5A | `hAP-5A.rsc` | 1-5 | 8 min | **GW-A ve 3 vecinos** (anillo cerrado) |
| 7 | SXT-A / SXT-B | — | — | 15 min | `ap-bridge` / `station-bridge` |
| 8 | GW-B | `GW-B.rsc` | 1-5 | 15 min | 3 vecinos (incluye GW-A) |
| 9 | hAP-1B…4B | `hAP-1B.rsc`… | 1-5 | 8 min c/u | 12 adyacencias totales |
| 10 | Servidor | `servidor/` | — | 20 min | `http://10.10.0.100/health` |
| 11 | GW-A / GW-B | bloques 6 y 7 | — | 25 min c/u | `/container print` → running |

**Hito de control:** cuando GW-A vea 3 vecinos `Full` y el resto 2, el enrutamiento del campus está
terminado. Todo lo que sigue (contenedor, servidor, extras) ya no puede romper OSPF.

---

## 7. Checklist final del campus

```
[ ] GW-A  /routing ospf neighbor print   -> 3 Full
[ ] GW-B  /routing ospf neighbor print   -> 3 Full
[ ] los 9 hAP                            -> 2 Full cada uno  (total 12 adyacencias)
[ ] cualquier hAP /ip firewall nat print -> VACÍO (Regla 8)
[ ] cliente Norte: ipconfig              -> 10.10.1x.x, gw .1, dns 10.10.255.1
[ ] cliente Norte: ping 10.10.0.100      -> responde
[ ] cliente Sur:   ping 10.10.0.100      -> responde (cruza el inter-sede)
[ ] navegar http://10.10.0.100           -> 200 OK
[ ] /ip route print en un hAP            -> default por OSPF, distance=110
[ ] desenchufar WAN de GW-A              -> el tráfico sale por GW-B en < 30 s
[ ] volver a enchufar                    -> regresa a GW-A en < 20 s
[ ] /tool traceroute 8.8.8.8 desde GW-B  -> primer salto 100.64.2.1
```
