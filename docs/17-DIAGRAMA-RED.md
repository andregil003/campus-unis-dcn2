# 17 · Diagrama de red — verificación contra el equipo físico

> Fecha: 06/11/2026 · Fuente: `docs/diagrama-red.drawio` (draw.io) · Estado: **verificado en vivo**

---

## 1. Qué contiene el diagrama

El archivo `diagrama-red.drawio` es un archivo draw.io (XML) con la topología completa del campus, incluyendo:

- Ambas sedes (Norte = Grupo A, Sur = Grupo B)
- ROUTER-ISP (RB3011, laboratorio del grupo)
- GW-A y GW-B (RB5009UG+S+IN)
- Los 9 hAP ax lite (5 Norte + 4 Sur)
- SXT-A y SXT-B (enlace inter-sede L2, sin IP)
- Servidores nginx (Norte: laptop Windows, Sur: Raspberry Pi 4)
- Contenedores DNS (Pi-hole Norte, AdGuard Sur)
- Todos los enlaces con puertos, IPs /30 y costos OSPF

---

## 2. Verificación elemento por elemento

### Sede Norte — Grupo A

| Elemento | Diagrama | Verificado en vivo | Estado |
|----------|----------|-------------------|--------|
| GW-A router-id | `10.10.255.1` | ✅ `/ip address print` | OK |
| GW-A Pi-hole DNS | `10.10.254.53` | ✅ Contenedor HEALTHY | OK |
| GW-A NAT | sí | ✅ masquerade + dst-nat | OK |
| hAP-1A loopback | `10.10.255.11` | ✅ `/ip address print` | OK |
| hAP-1A WiFi | `192.168.1.1/24` SSID UNIS-A1 | ✅ `/ip address print` + export | OK |
| hAP-2A loopback | `10.10.255.12` | ✅ | OK |
| hAP-2A WiFi | `192.168.2.1/24` SSID UNIS-A2 | ✅ | OK |
| hAP-3A loopback | `10.10.255.13` | ✅ | OK |
| hAP-3A WiFi | `192.168.3.1/24` SSID UNIS-A3 | ✅ | OK |
| hAP-4A loopback | `10.10.255.14` | ✅ | OK |
| hAP-4A WiFi | `192.168.4.1/24` SSID UNIS-A4 | ✅ | OK |
| hAP-5A loopback | `10.10.255.15` | ✅ | OK |
| hAP-5A WiFi | `192.168.5.1/24` SSID UNIS-A5 | ✅ | OK |
| Servidor-A nginx | `10.10.0.100` (laptop Windows) | ✅ `/health = ok` | OK |

### Enlace Servidor-A

| Diagrama | Verificado | Estado |
|----------|-----------|--------|
| hAP-1A e3 `10.10.0.1/24` → Servidor `10.10.0.100` | ✅ `/ip address print` + ping | OK |

### Enlace anillo Norte

| Enlace | Diagrama | Verificado | Estado |
|--------|----------|-----------|--------|
| GW-A e2 `10.10.1.1` ↔ hAP-1A e1 `10.10.1.2` | `10.10.1.0/30` | ✅ OSPF Full | OK |
| hAP-1A e2 `10.10.2.1` ↔ hAP-2A e1 `10.10.2.2` | `10.10.2.0/30` | ✅ OSPF Full | OK |
| hAP-2A e2 `10.10.3.1` ↔ hAP-3A e1 `10.10.3.2` | `10.10.3.0/30` | ✅ OSPF Full | OK |
| hAP-3A e2 `10.10.4.1` ↔ hAP-4A e1 `10.10.4.2` | `10.10.4.0/30` | ✅ OSPF Full | OK |
| hAP-4A e2 `10.10.5.1` ↔ hAP-5A e1 `10.10.5.2` | `10.10.5.0/30` | ✅ OSPF Full | OK |
| hAP-5A e2 `10.10.6.1` ↔ GW-A e3 `10.10.6.2` | `10.10.6.0/30` | ✅ OSPF Full | OK |

### Sede Sur — Grupo B

| Elemento | Diagrama | Verificado en vivo | Estado |
|----------|----------|-------------------|--------|
| GW-B router-id | `10.20.255.1` | ✅ `/ip address print` | OK |
| GW-B AdGuard DNS | `10.20.254.53` | ✅ Contenedor HEALTHY | OK |
| GW-B NAT | sí | ✅ masquerade + dst-nat | OK |
| hAP-1B loopback | `10.20.255.11` | ✅ | OK |
| hAP-1B WiFi | `192.168.11.1/24` SSID UNIS-B1 | ✅ | OK |
| hAP-2B loopback | `10.20.255.12` | ✅ | OK |
| hAP-2B WiFi | `192.168.12.1/24` SSID UNIS-B2 | ✅ | OK |
| hAP-3B loopback | `10.20.255.13` | ✅ | OK |
| hAP-3B WiFi | `192.168.13.1/24` SSID UNIS-B3 | ✅ | OK |
| hAP-4B loopback | `10.20.255.14` | ✅ | OK |
| hAP-4B WiFi | `192.168.14.1/24` SSID UNIS-B4 | ✅ | OK |
| Servidor-B nginx | `10.20.0.100` (Raspberry Pi 4) | ✅ `/health = ok` | OK |

### Enlace Servidor-B

| Diagrama | Verificado | Estado |
|----------|-----------|--------|
| hAP-3B e3 `10.20.0.1/24` → Servidor `10.20.0.100` | ✅ `/ip address print` + ping | OK |

### Enlace anillo Sur

| Enlace | Diagrama | Verificado | Estado |
|--------|----------|-----------|--------|
| GW-B e2 `10.20.1.1` ↔ hAP-1B e1 `10.20.1.2` | `10.20.1.0/30` | ✅ OSPF Full | OK |
| hAP-1B e2 `10.20.2.1` ↔ hAP-2B e1 `10.20.2.2` | `10.20.2.0/30` | ✅ OSPF Full | OK |
| hAP-2B e2 `10.20.3.1` ↔ hAP-3B e1 `10.20.3.2` | `10.20.3.0/30` | ✅ OSPF Full | OK |
| hAP-3B e2 `10.20.4.1` ↔ hAP-4B e1 `10.20.4.2` | `10.20.4.0/30` | ✅ OSPF Full | OK |
| hAP-4B e2 `10.20.5.1` ↔ GW-B e3 `10.20.5.2` | `10.20.5.0/30` | ✅ OSPF Full | OK |

### Enlace inter-sede (SXT)

| Elemento | Diagrama | Verificado | Estado |
|----------|----------|-----------|--------|
| SXT-A (sin IP, puente L2) | sin IP | ✅ `registration-table` asociada | OK |
| SXT-B (sin IP, puente L2) | sin IP | ✅ `registration-table` asociada | OK |
| GW-A e1 `10.99.0.1` ↔ SXT-A | `10.99.0.0/30` | ✅ ping OK | OK |
| SXT-B ↔ GW-B e7 `10.99.0.2` | `10.99.0.0/30` | ✅ ping OK | OK |
| SXT-A ↔ SXT-B | 5 GHz P2P L2 | ✅ señal -2 a -6 dBm (cerca, saturada) | OK |
| Costo OSPF inter-sede | 100 | ✅ `interface-template` costo 100 | OK |

### WAN (ROUTER-ISP)

| Elemento | Diagrama | Verificado | Estado |
|----------|----------|-----------|--------|
| ROUTER-ISP RB3011 | laboratorio | ✅ configurado y verificado | OK |
| GW-A e7 `100.64.1.2` ↔ ISP e2 `100.64.1.1` | `100.64.1.0/30` | ✅ ping OK | OK |
| GW-B e1 `100.64.2.2` ↔ ISP e5 `100.64.2.1` | `100.64.2.0/30` | ✅ ping OK | OK |
| masquerade por sfp1 | sí | ✅ 1 regla NAT | OK |

---

## 3. Diferencia documentada en el diagrama

La **leyenda del diagrama** indica explícitamente:

> "Pendiente: GW-B aun con e1 = ISP y e7 = antena (D-16 solo aplicado en GW-A)."

Esto es correcto y coincide con la realidad:

| Puerto | GW-A (D-16 aplicado) | GW-B (D-16 pendiente) |
|--------|---------------------|----------------------|
| ether1 | inter-sede `10.99.0.1/30` (PoE-in) | WAN `100.64.2.2/30` |
| ether7 | WAN `100.64.1.2/30` | inter-sede `10.99.0.2/30` |

El diagrama refleja fielmente este estado. Cuando se aplique D-16 también a GW-B, el diagrama deberá actualizarse (intercambiar e1/e7 en GW-B).

---

## 4. Costos OSPF

| Tipo | Diagrama | Verificado | Estado |
|------|----------|-----------|--------|
| Enlace anillo (1 Gbps) | costo 10 | ✅ `interface-template` costo 10 | OK |
| Inter-sede (100 Mbps) | costo 100 | ✅ `interface-template` costo 100 | OK |

---

## 5. Conclusión

El diagrama `diagrama-red.drawio` **coincide con la configuración real verificada en vivo** en los 11 equipos del campus. Todos los enlaces, IPs, puertos, costos OSPF, contenedores DNS y servidores están correctos.

La única observación pendiente es la nota de la leyenda sobre D-16 en GW-B (swap de puertos e1/e7), que es un cambio de puerto físico sin impacto en las IPs ni en la topología lógica.

**El diagrama está listo para entregar como parte de la documentación de la defensa (Regla 7 del enunciado).**

---

> **Regla de oro:** si se aplica D-16 a GW-B (cambiar puertos físicos), actualizar este diagrama y volver a verificar OSPF y failover.