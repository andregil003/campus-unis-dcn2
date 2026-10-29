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

### 1.1 Inventario: qué archivo va en qué equipo (13 equipos)

| # | Equipo | Modelo | Archivo | Rol en la topología |
|---|---|---|---|---|
| 1 | GW-A | RB5009UG+S+IN | `configs/rsc/GW-A.rsc` | WAN Norte, NAT, OSPF, Pi-hole |
| 2 | GW-B | RB5009UG+S+IN | `configs/rsc/GW-B.rsc` | WAN Sur, NAT, OSPF, AdGuard |
| 3-7 | hAP-1A…5A | hAP ax lite | `configs/rsc/hAP-NA.rsc` | anillo Norte + 5 redes WiFi |
| 8-11 | hAP-1B…4B | hAP ax lite | `configs/rsc/hAP-NB.rsc` | anillo Sur + 4 redes WiFi |
| 12 | SXT-A | SXT Lite5 | `configs/rsc/SXT-A.rsc` | punta **AP** del enlace inter-sede |
| 13 | SXT-B | SXT Lite5 | `configs/rsc/SXT-B.rsc` | punta **station-bridge** del enlace |

**No llevan `.rsc` porque no son MikroTik o no se configuran así:** el servidor Norte (laptop + nginx) y el
servidor Sur (Pi 4 + nginx) → `servidor/`; el Pico RP2040 → extra opcional.

> Los 2 SXT **no tienen IP a propósito** (D-04): son un cable inalámbrico, las IPs de `10.99.0.0/30` viven en
> los RB5009. Se administran por MAC desde WinBox → Neighbors. Por eso el `.rsc` activa
> `discover-interface-list=all`: sin eso, un equipo sin IP no aparece y no hay forma de entrar.

### 1.2 ¿Dónde se pega y dónde se verifica?

**Para pegar:** WinBox → menú izquierdo **New Terminal** (o el botón `>_` de la barra superior).
**No** uses `System → Scripts`: ahí el texto queda guardado como script y no se ejecuta en el momento.

**Para verificar** hay tres niveles, de menos a más:

| Nivel | Cómo | Para qué |
|---|---|---|
| 1 · Rápido | Los comandos `print` que están al final de cada bloque | Confirmar que ese bloque quedó bien antes de seguir |
| 2 · Medio | `/export terse` | Ver toda la config viva del equipo en una pantalla; se puede pegar en el chat para que yo la compare |
| 3 · Exacto | `/export file=check` → descargar `check.rsc` por WinBox → comparar con el archivo del repo | Auditoría final antes de la defensa |

> `/export` **no** va a salir idéntico al `.rsc`: RouterOS no escribe lo que está en valor por defecto y
> ordena los bloques distinto. Sirve para confirmar que están las piezas, no para un diff literal.

**Las 4 verificaciones que de verdad importan (por equipo):**

```
/interface bridge print                 -> los bridges esperados, sin bridgeLocal
/ip address print                       -> las IPs del equipo, cada una en SU puerto
/ip route print where dst-address=0.0.0.0/0
                                        -> GW: estática distance=1 | hAP: OSPF distance=110
/routing ospf neighbor print            -> GW: 3 Full | hAP: 2 Full
```

### 1.3 Limpiar la config de fábrica (BLOQUE 0)

Los RB5009 **no vienen limpios**: salen con un `bridgeLocal` que contiene **todos** los puertos
(`ether1…ether8` + `sfp-sfpplus1`) y un `dhcp-client` sobre ese bridge. Si pegás la config sin borrar eso,
las IPs de `ether1/2/3/7` caen en puertos **esclavos** del bridge y el ruteo no funciona.

```
/ip dhcp-client remove [find]
/interface bridge port remove [find bridge=bridgeLocal]
/interface bridge remove [find name=bridgeLocal]
```

Es idempotente (si ya está limpio, no hace nada). Después: `/interface ethernet print` debe mostrar
`ether1…ether8` **sin** la letra `S` (slave) y `/interface bridge print` debe estar vacío.

> Si preferís empezar de cero absoluto: `/system reset-configuration no-defaults=yes skip-backup=yes`
> (borra todo, incluida la IP, y se vuelve a entrar por MAC desde WinBox → Neighbors).

### 1.4 Versiones: los dos RB5009 NO están iguales

| Equipo | Serial | RouterOS | Acción |
|---|---|---|---|
| GW-A | HFB09D3DPSG | **7.18.2** | actualizar a 7.24.2 |
| GW-B | HFB09DV2C04 | **7.24.2** | dejar |

Unificar en **7.24.2** (la más nueva, con `veth`/`container` maduros). Razones: el paquete
`container-<version>-arm64.npk` tiene que ser **exactamente** la versión del equipo — con versiones
distintas necesitás dos `.npk` y es un error fácil de cometer el día de la defensa. Y una diferencia de
6 versiones menores entre los dos GW es una variable que no querés explicando un fallo en vivo.

**Faltan las versiones de los 9 hAP** (`/system resource print` en cada uno). Si alguno está por debajo de
7.16, el bloque del contenedor no aplica y hay que actualizarlo.

---

### 1.5 Internet en casa vs. en el laboratorio

En casa, `ether1` va a un **router doméstico** que entrega `192.168.0.x` por DHCP: el WAN del plan
(`100.64.2.2/30`) queda sin usar y la ruta `default-ISP` aparece con la bandera `I` (inactiva). **Eso es
lo correcto**, no un error de configuración.

Para tener internet mientras se configura (bajar el `.npk` del contenedor, sincronizar NTP):

```
/ip dhcp-client add interface=ether1 disabled=no use-peer-dns=no use-peer-ntp=no comment="PROVISIONAL"
```

`use-peer-dns=no` es obligatorio en la práctica: si no, el ISP reemplaza los DNS `1.1.1.1,8.8.8.8` del
diseño por los suyos, en silencio.

**Antes de llevarse el equipo al laboratorio (obligatorio):**

```
/ip dhcp-client remove [find comment="PROVISIONAL"]
```

Con el cliente DHCP vivo, el router del catedrático podría entregar otra IP y el WAN del plan quedaría
ignorado sin ningún mensaje de error.

---

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
| `input does not match any value of band` | El parámetro correcto es `channel.band` | Ya está corregido en los archivos; si lo ves, es que pegaste una versión vieja |
| `input does not match any value of country` | Tu build no reconoce `Guatemala` | Probar `country=guatemala` en minúscula, o quitar el parámetro |
| `no such item` en `/interface wifi` | El equipo usa el paquete `wireless` viejo (no `wifi`) | Solo en equipos que no son ax lite; el hAP ax **siempre** usa `wifi1` |
| `failure: already have such address` | Estás re-aplicando | Ignorar: es idempotente donde importa |
| `failure: already have interface with name lo` | **Normal**: `lo` es el loopback **interno** de RouterOS, visible desde ~7.14 | Ya está corregido en los archivos (no se crea el bridge). La IP `/32` sobre el `lo` existente funciona igual |
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
| 7 | SXT-A / SXT-B | `SXT-A.rsc` / `SXT-B.rsc` | 0-4 | 15 min c/u | `registration-table` con ccq > 90% |
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

---

## 8. Verificación contra la documentación oficial (28/10/2026)

Todo lo que se pudo contrastar se contrastó contra `help.mikrotik.com` (docs de `/routing/ospf` y del
paquete WiFi 6), no contra memoria.

| Qué se verificó | Resultado |
|---|---|
| `/routing ospf instance originate-default=if-installed` | ✅ existe en v7 (`always \| if-installed \| never`) y es el mecanismo correcto para failover |
| `/routing ospf area instance=` | ✅ `instance` es **obligatorio** — el archivo lo usa bien |
| `interface-template`: `interfaces`, `area`, `type=ptp`, `cost`, `hello-interval`, `dead-interval`, `passive` | ✅ los 7 parámetros existen con esos nombres exactos |
| `type=ptp` en enlaces /30 | ✅ es el tipo recomendado para punto a punto (no elige DR/BDR) |
| `/interface wifi security … authentication-types=wpa2-psk,wpa3-psk passphrase=` | ✅ correcto |
| `/interface wifi configuration … ssid / security / country / mode` | ✅ correcto (`mode` es `ap` por defecto) |
| **`band=` en la configuración WiFi** | ❌ **BUG ENCONTRADO:** el parámetro real es `channel.band=` (el `band` suelto solo existe en el menú `/interface wifi channel`). **Corregido en los 9 hAP** |
| `channel.frequency` / `channel.width` | ✅ correctos, con `frequency` en MHz (2412/2437/2462) |
| `/interface veth address= gateway=` + `/ip address` en el extremo del host | ✅ patrón correcto (el `address` es del contenedor, el router necesita su propia IP) |
| `device-mode update container=yes` → confirmar con **reset físico** o cold reboot | ✅ confirmado en la doc de Container |
| `#` como comentario al pegar | ✅ válido ("A comment starts with a hash character and ends at the end of the line") |

**Lo que no se puede verificar sin el equipo y hay que probar en el laboratorio:**

1. Que `country=Guatemala` exista en la tabla regulatoria de ese build (si falla, §4).
2. Nombre exacto del disco para `root-dir=` (`/disk print`).
3. Que el `hAP ax lite` acepte `2ghz-ax` (su radio es 802.11ax, debería; si no, `2ghz-n`).
4. `SXT Lite5`: confirmar que la versión de RouterOS que trae soporta `station-bridge`
   (sí en v6 y v7; es lo que exige el diseño L2 transparente).
