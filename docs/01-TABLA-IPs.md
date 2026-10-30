# Tabla de direccionamiento y costos OSPF

Estado: **vigente desde el 30/10/2026 — D-01 revisada: el WiFi sigue el diagrama v3 (`192.168.x`).**
Bloques obligatorios del enunciado respetados: Norte en `10.10.0.0/8`, Sur en `10.20.0.0/8`,
inter-sede `10.99.0.0/30`, WANs `100.64.1.0/30` y `100.64.2.0/30`.
Las `/24` de WiFi son la única excepción declarada: se copian del **diagrama de referencia v3**
(`192.168.1-5.0/24` y `192.168.11-14.0/24`), por decisión D-01 del 30/10/2026.

---

## 1. Sede Norte — Grupo A (nuestra responsabilidad)

### 1.1 GW-A · RB5009UG+S+IN

| Interfaz | Dirección | Rol |
|---|---|---|
| `ether1` (2.5G) | `100.64.1.2/30` | WAN hacia router ISP (gateway `100.64.1.1`) |
| `ether2` | `10.10.1.1/30` | enlace al anillo → hAP-1A |
| `ether3` | `10.10.6.2/30` | enlace al anillo → hAP-5A |
| `ether7` | `10.99.0.1/30` | hacia SXT-A (puente L2 inter-sede) |
| `loopback` | `10.10.255.1/32` | router-id OSPF + IP de DNS que entrega el DHCP |
| `veth1` | `10.10.254.1/24` | red del container |
| `usb1` | — | root-dir del container Pi-hole |
| — | `10.10.254.53` | Pi-hole (container) |

> Equipo real: `RB5009UG+S+IN` (1× 2.5G + 7× 1G, USB 3.0, **sin PoE-out**).
> `ether4-6` y `ether8` quedan libres como reserva.

### 1.2 Anillo Norte (6 nodos, 6 enlaces /30)

| Enlace | Subred | Extremo A | Extremo B |
|---|---|---|---|
| L1 | `10.10.1.0/30` | GW-A `.1` | hAP-1A `.2` |
| L2 | `10.10.2.0/30` | hAP-1A `.1` | hAP-2A `.2` |
| L3 | `10.10.3.0/30` | hAP-2A `.1` | hAP-3A `.2` |
| L4 | `10.10.4.0/30` | hAP-3A `.1` | hAP-4A `.2` |
| L5 | `10.10.5.0/30` | hAP-4A `.1` | hAP-5A `.2` |
| L6 | `10.10.6.0/30` | hAP-5A `.1` | GW-A `.2` |

### 1.3 Nodos hAP ax lite

| Nodo | ether1 (anillo) | ether2 (anillo) | WiFi | Loopback / router-id |
|---|---|---|---|---|
| hAP-1A | `10.10.1.2/30` | `10.10.2.1/30` | `192.168.1.1/24` | `10.10.255.11/32` |
| hAP-2A | `10.10.2.2/30` | `10.10.3.1/30` | `192.168.2.1/24` | `10.10.255.12/32` |
| hAP-3A | `10.10.3.2/30` | `10.10.4.1/30` | `192.168.3.1/24` | `10.10.255.13/32` |
| hAP-4A | `10.10.4.2/30` | `10.10.5.1/30` | `192.168.4.1/24` | `10.10.255.14/32` |
| hAP-5A | `10.10.5.2/30` | `10.10.6.1/30` | `192.168.5.1/24` | `10.10.255.15/32` |

`ether3` del **hAP-1A** = `10.10.0.1/24`, dedicado a la Raspberry Pi. Sin bridge: es un puerto enrutado.

### 1.4 Servidor y clientes

| Elemento | Dirección | Notas |
|---|---|---|
| Raspberry Pi A (nginx) | `10.10.0.100/24`, gw `10.10.0.1` | IP fija exigida por el enunciado |
| Pool DHCP WiFi | `192.168.N.10 – 192.168.N.250` | por nodo (N = número del hAP: Norte 1-5, Sur 11-14) |

---

## 2. Sede Sur — Grupo B (acuerdo entre grupos, no configuración nuestra)

| Elemento | Dirección |
|---|---|
| GW-B WAN | `100.64.2.2/30` (gateway `100.64.2.1`) |
| GW-B ↔ SXT-B | `10.99.0.2/30` |
| GW-B loopback | `10.20.255.1/32` |
| Anillo Sur (5 enlaces) | `10.20.1.0/30` … `10.20.5.0/30` |
| WiFi hAP-1B…4B | `192.168.11.1` … `192.168.14.1` (`.0/24` cada uno) |
| Raspberry Pi B (nginx) | `10.20.0.100/24` |
| AdGuard Home (container) | `10.20.254.53` |

> Pendiente de cerrar con Grupo B: confirmación de estos bloques y del direccionamiento WiFi (D-01).

---

## 3. Costos OSPF

| Tipo de enlace | Costo | Motivo |
|---|---|---|
| Ethernet 1 Gbps (anillo) | **10** | todos iguales ⇒ la topología de anillo decide el camino |
| Enlace inter-sede (SXT, 100 Mbps) | **100** | fuerza preferencia local y evita ECMP con el default remoto |
| Loopback / WiFi / LAN servidor | passive | se anuncian, no forman adyacencia |

Consecuencia buscada: el default local llega con métrica **10** y el remoto con **110**,
de modo que la Regla 1 se cumple por diseño, no por suerte. El valor 100 es suficiente porque el peor
camino intra-anillo (4 saltos con un enlace caído) es 40.

---

## 4. Vecinos OSPF esperados

| Equipo | Vecinos esperados | Total |
|---|---|---|
| GW-A | hAP-1A, hAP-5A, GW-B | 3 Full |
| hAP-1A … hAP-5A | 2 cada uno | 10 Full |
| GW-B | hAP-1B, hAP-4B, GW-A | 3 Full |
| hAP-1B … hAP-4B | 2 cada uno | 8 Full |
| **Campus** | — | **12 adyacencias** |

---

## 5. Nomenclatura física (para etiquetas y diagrama)

- Formato de etiqueta: `ORIGEN / PUERTO → DESTINO / PUERTO` (ej. `GW-A / ether2 → hAP-1A / ether1`).
- Identidad del equipo = nombre del diagrama = etiqueta del rack.
- SSID: `UNIS-A1` … `UNIS-A5` (Norte), `UNIS-B1` … `UNIS-B4` (Sur) — coincide con los `.rsc`.
