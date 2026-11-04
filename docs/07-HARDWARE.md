# Hardware real del equipo y consecuencias de diseño

Inventario confirmado (27/10/2026). Todo lo de esta página está verificado contra la ficha técnica
del fabricante, no contra suposiciones.

## 1. Inventario

| Equipo | Cantidad | Modelo real | Uso asignado |
|---|---|---|---|
| MikroTik RB5009 | 2 | `RB5009UG+S+` (sin PoE-out) | GW-A (Sede Norte) y GW-B (Sede Sur) — ver §1.1 |
| MikroTik hAP ax lite | **9** | `L41G-2axD` | 5 → anillo Norte · 4 → anillo Sur |
| Raspberry Pi **Pico** | 1 | RP2040, 264 KB RAM, Cortex-M0+ | **no sirve como servidor nginx** (ver R-13) |
| Antena SXT Lite5 | 2 | provistas por el catedrático | enlace inter-sede |
| MikroTik RB3011UiAS | 1 | `RB3011UiAS` (10× GbE + SFP) | **Router ISP** del laboratorio (D-15) — no viene del enunciado |
| Raspberry Pi (SBC) | **0** | — | **sustituida por laptop** (D-08 + D-13): Norte usa `DESKTOP-LKL1R8L` con nginx/Windows |

### 1.2 Router ISP del laboratorio (RB3011UiAS)

| Dato | Valor |
|---|---|
| Serial | `783E064858A9` |
| RouterOS | **7.24.5** |
| Identidad | `ROUTER-ISP` |
| Uplink | `sfp1` por DHCP (`172.18.4.18/24`, gateway `172.18.4.1`) |
| WAN Norte | `ether2` `100.64.1.1/30` → `GW-A ether7` |
| WAN Sur | `ether3` `100.64.2.1/30` → `GW-B ether7` |
| Reservado | `ether7` `10.0.1.1/25` (otro grupo) · `ether5` consola |
| Config | `configs/rsc/ROUTER-ISP.rsc` · backup en `configs/backups/` |

### 1.1 Las dos unidades físicas (verificado con `export`, 28/10/2026)

| Serial | Modelo reportado | RouterOS | Config de fábrica | Rol asignado |
|---|---|---|---|---|
| **HFB09DV2C04** | RB5009UG+S+ | **7.24.2** | **limpia** (solo `silent-boot`) | **GW-B (Sur)** — etiquetado `PENDIENTE-SUR` |
| HFB09D3DPSG | RB5009UG+S+ | **7.18.2** | sucia: `bridgeLocal` con **todos** los puertos + `dhcp-client` | **GW-A (Norte)** → `BLOQUE 0` + actualizar a 7.24.2 |

**Rol decidido por André (28/10/2026):** el equipo que estaba a mano (7.24.2) se etiquetó `PENDIENTE-SUR` y
se configura primero como **GW-B**. Las dos configuraciones son simétricas, así que el orden no afecta el
diseño; lo único que cambia es qué equipo necesita trabajo previo.

**Consecuencia de esta asignación:** el equipo de **Norte** (el que hospeda el Pi-hole) es el que está en
7.18.2, así que **debe** limpiarse con `BLOQUE 0` y actualizarse a 7.24.2 antes de montar el contenedor.
Con los dos en 7.24.2 se necesita **un solo** `container-7.24.2-arm64.npk` (R-17).

## 2. Capacidades verificadas

### RB5009UG+S+IN (×2)

| Característica | Dato | Consecuencia |
|---|---|---|
| Puertos Ethernet | 1× 2.5G (`ether1`) + 7× 1G (`ether2-8`) | puertos de sobra para anillo + SXT |
| SFP+ | 1 | no se usa |
| USB | 1× USB 3.0 tipo A (1.5 A) | **root-dir del container Pi-hole** |
| RAM / almacenamiento | 1 GB DDR4 / 1 GB NAND | suficiente para Pi-hole en container |
| PoE-out | **NO tiene** | los hAP no se alimentan desde el router (igual no lo necesitan, ver abajo) |
| PoE-in | 802.3af/at en `ether1` | se puede alimentar por PoE si se consigue un inyector |
| RouterOS | v7, licencia 5 | sintaxis v7 obligatoria |
| Consumo | 14 W típico / 25 W máx | fuente de 24 V incluida |

### hAP ax lite L41G-2axD (×9)

| Característica | Dato | Consecuencia |
|---|---|---|
| Puertos Ethernet | **4× GbE** | hAP-1A usa 3 (anillo ×2 + Pi), queda 1 libre de consola |
| WiFi | **solo 2.4 GHz**, 802.11b/g/n/ax (Wi-Fi 6, 574 Mbit/s) | no hay 5 GHz: la banda está congestionada en laboratorio (R-15) |
| Alimentación | **USB-C 5 V / 2.4 A, sin PoE** | cada hAP necesita su propia fuente USB-C (viene en la caja) |
| RAM / storage | 256 MB / 128 MB NAND | suficiente para router de anillo, **no** para containers |
| RouterOS | v7, licencia 4 | `/interface/wifi` (paquete *wifi*), no `/interface/wireless` |
| Consumo | 8 W máx | 5 equipos ≈ 40 W |

### PoE: qué se puede y qué no (verificado 03/11/2026)

| Pregunta | Respuesta | Fuente |
|---|---|---|
| ¿El GW puede **alimentar** la antena? | **No.** El `RB5009UG+S+IN` no tiene PoE-out y el menú `/interface ethernet poe` no existe en ese equipo | Doc oficial *PoE-Out*, tabla de PSE (lista al `RB5009UPr+S+`, no al UG) |
| ¿El GW puede **recibir** energía por PoE? | Sí, **solo `ether1`**, 802.3af/at (48 V) | Ficha del RB5009UG+S+IN |
| ¿El inyector de la SXT puede alimentar el GW? | **No.** El inyector pasivo va *router → inyector → antena*; el puerto de datos no entrega PoE al router | Diseño del inyector pasivo |
| ¿Hay que configurar algo en RouterOS para el PoE del UG? | **Nada.** No existe el menú; cualquier `poe-out=` da `bad command name poe` | Probado por sintaxis |

**Si algún día se cambia a `RB5009UPr+S+`** (sí tiene 8 puertos PoE-out), el comando es:

```
/interface ethernet poe set ether1 poe-out=forced-on poe-priority=10
/interface ethernet poe monitor ether1
```

`forced-on` porque la SXT usa **PoE pasivo** (no negocia 802.3af); con `auto-on` el PSE no la detectaría.
Con fuente de 24 V entrega ~24 V (dentro del rango de la SXT); **con fuente de 48 V no conectar la SXT**.
Ese bloque queda comentado al final de `GW-A.rsc` / `GW-B.rsc`.

## 3. Plano de puertos actualizado (GW-A)

| Interfaz | Uso |
|---|---|
| `ether7` | WAN al router ISP (`100.64.1.2/30`) — **D-16** |
| `ether2` | anillo → hAP-1A (`10.10.1.1/30`) |
| `ether3` | anillo → hAP-5A (`10.10.6.2/30`) |
| `ether1` (2.5G) | SXT-A (`10.99.0.1/30`) · PoE-in alimenta el GW — **D-16** |
| `ether4-6`, `ether8` | libres (reserva) |
| `usb1` | root-dir del container Pi-hole |

## 4. Consecuencias prácticas

1. **Energía:** los hAP no aceptan PoE (fuente USB-C cada uno). Los **GW sí** van alimentados por
   **PoE-in en `ether1`** desde el inyector de la antena SXT (D-16), así que su fuente de 24 V queda de
   repuesto. Para el rack: **regleta con ≥ 6 tomas** y velcro para el cableado de poder.
   *Verificar que el inyector entregue 802.3af/at (48 V): el RB5009 no arranca con PoE pasivo de 24 V.*
2. **Repuestos:** 9 hAP = exactamente 5 + 4, **sin margen**. Si uno falla el día de la defensa, no hay
   sustituto (R-14).
3. **WiFi 2.4 GHz:** definir canales (1, 6, 11) entre los 5 nodos para no autointerferirse (R-15).
4. **Servidor:** el Pico no es un SBC. Norte resuelve con laptop + nginx/Windows (D-08, D-13); Sur con su
   Raspberry Pi 4 de 2 GB. El sustituto está desplegado y verificado con `servidor/windows/verificar.ps1`.
