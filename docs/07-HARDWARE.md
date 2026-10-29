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
| Raspberry Pi (SBC) | **0** | — | **faltante crítico** (servidor de sede) |

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

## 3. Plano de puertos actualizado (GW-A)

| Interfaz | Uso |
|---|---|
| `ether1` (2.5G) | WAN al router ISP (`100.64.1.2/30`) |
| `ether2` | anillo → hAP-1A (`10.10.1.1/30`) |
| `ether3` | anillo → hAP-5A (`10.10.6.2/30`) |
| `ether7` | SXT-A (`10.99.0.1/30`) — coincide con el diagrama del catedrático |
| `ether4-6`, `ether8` | libres (reserva) |
| `usb1` | root-dir del container Pi-hole |

## 4. Consecuencias prácticas

1. **Energía:** no hay PoE en ningún punto de la cadena. Cada hAP con su fuente USB-C + el RB5009 con
   su fuente de 24 V + la Pi. Para el rack: **regleta con ≥ 6 tomas** y velcro para el cableado de poder.
2. **Repuestos:** 9 hAP = exactamente 5 + 4, **sin margen**. Si uno falla el día de la defensa, no hay
   sustituto (R-14).
3. **WiFi 2.4 GHz:** definir canales (1, 6, 11) entre los 5 nodos para no autointerferirse (R-15).
4. **Servidor:** el Pico no es un SBC. Falta una Raspberry Pi real o sustituto (R-13 / D-08).
