# 19 · DOCUMENTACIÓN MASTER — Campus UNIS DCN2

> Fecha: 06/11/2026 · Sede Norte (Grupo A) · Estado: **TODO VERIFICADO EN EQUIPO FÍSICO**
>
> Este es el documento único de referencia. Contiene: arquitectura completa, configuración de cada equipo, para qué sirve cada cosa, y cómo verificar cada cosa paso a paso para la defensa oral.
>
> Único archivo que necesitás tener abierto durante la defensa.

---

## TABLA DE CONTENIDO

1. [Arquitectura general del campus](#1-arquitectura-general)
2. [Direccionamiento completo](#2-direccionamiento-completo)
3. [Equipos y sus configuraciones](#3-equipos-y-configuraciones)
4. [Cómo verificar cada cosa (comandos paso a paso)](#4-como-verificar-cada-cosa)
5. [Para qué sirve cada cosa](#5-para-que-sirve-cada-cosa)
6. [Estados verificados en vivo](#6-estados-verificados-en-vivo)
7. [Checklist final para la defensa](#7-checklist-final-para-la-defensa)
8. [Comandos cheat sheet](#8-comandos-cheat-sheet)

---

# 1 · ARQUITECTURA GENERAL DEL CAMPUS

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           INTERNET / LABORATORIO                            │
│                           (Router ISP - RB3011)                             │
│                    sfp1: 172.18.4.18 (DHCP lab)                             │
│                    ether2: 100.64.1.1/30  ← WAN Norte                       │
│                    ether3: 100.64.2.1/30  ← WAN Sur                         │
└────────────────────────┬────────────────────────┬───────────────────────────┘
                         │                        │
                   100.64.1.0/30          100.64.2.0/30
                         │                        │
          ┌──────────────▼──────────────┐  ┌─────▼──────────────┐
          │     GW-A · RB5009           │  │     GW-B · RB5009  │
          │   Sede Norte (Grupo A)      │  │   Sede Sur (Grupo B)│
          │                             │  │                    │
          │  ether7: 100.64.1.2/30      │  │  ether1: 100.64.2.2/30│
          │  ether1: 10.99.0.1/30       │  │  ether7: 10.99.0.2/30│
          │  (WAN)      ←→  inter-sede  │  │  (WAN)      ←→  inter-sede│
          │  loopback: 10.10.255.1      │  │  loopback: 10.20.255.1│
          │  DNS: 10.10.254.53 (Pi-hole)│  │  DNS: 10.20.254.53 (AdGuard)│
          │  NAT: masquerade WAN        │  │  NAT: masquerade WAN        │
          └──────────────┬──────────────┘  └─────────────┬──────────────┘
                         │                                │
                    10.10.1.0/30                   10.20.1.0/30
                         │                                │
          ┌──────────────┴──────────────┐  ┌─────────────┴──────────────┐
          │  ANILLO NORTE (5 hAP ax lite)│  │  ANILLO SUR (4 hAP ax lite)│
          │                             │  │                            │
          │ hAP-1A: 10.10.255.11        │  │ hAP-1B: 10.20.255.11       │
          │ hAP-2A: 10.10.255.12        │  │ hAP-2B: 10.20.255.12       │
          │ hAP-3A: 10.10.255.13        │  │ hAP-3B: 10.20.255.13       │
          │ hAP-4A: 10.10.255.14        │  │ hAP-4B: 10.20.255.14       │
          │ hAP-5A: 10.10.255.15        │  │                            │
          │                             │  │                            │
          │ WiFi: 192.168.1-5.0/24      │  │ WiFi: 192.168.11-14.0/24   │
          │ SSID: UNIS-A1...A5          │  │ SSID: UNIS-B1...B4         │
          │                             │  │                            │
          │ Servidor Norte:             │  │ Servidor Sur:              │
          │ 10.10.0.100 (laptop Win)    │  │ 10.20.0.100 (Raspberry Pi) │
          │ nginx puerto 80             │  │ nginx puerto 80            │
          └─────────────────────────────┘  └────────────────────────────┘
                           │
                    10.99.0.0/30 (inter-sede L2 vía SXT-A ↔ SXT-B)
                           │
                    SXT-A (ap-bridge) ←→ SXT-B (station-bridge)
                    (sin IP, puente transparente 5 GHz)
```

**Topología:** Anillo OSPF en cada sede + enlace inter-sede punto a punto entre los dos GW.

**Reglas del enunciado cumplidas:**
- R1: Salida a Internet independiente por sede (WAN propia gana)
- R2: DNS filtrado por sede (Pi-hole Norte, AdGuard Sur)
- R3: Conectividad inter-sede permanente (servidores se ven entre sí)
- R4: Failover WAN automático < 30 s
- R5: Restauración automática < 30 s
- R6: OSPF en todos los nodos, vecinos Full
- R7: Documentación previa (este repo)
- R8: NAT exclusivo en gateway, hAP sin NAT

---

# 2 · DIRECCIONAMIENTO COMPLETO

## 2.1 Router ISP (laboratorio)

| Interfaz | Dirección | Rol |
|----------|-----------|-----|
| sfp1 (e1) | 172.18.4.18/24 (DHCP) | Uplink al laboratorio |
| ether2 (e2) | 100.64.1.1/30 | WAN Sede Norte |
| ether3 (e3) | 100.64.2.1/30 | WAN Sede Sur |
| ether7 | 10.0.1.1/25 | Otro grupo (no tocar) |

## 2.2 Sede Norte — GW-A (RB5009UG+S+IN)

| Interfaz | Dirección | Comentario |
|----------|-----------|------------|
| ether7 | 100.64.1.2/30 | WAN hacia ISP (gateway 100.64.1.1) |
| ether2 | 10.10.1.1/30 | Anillo → hAP-1A |
| ether3 | 10.10.6.2/30 | Anillo → hAP-5A (cierre) |
| ether1 | 10.99.0.1/30 | Inter-sede → SXT-A (PoE-in alimenta el GW) |
| loopback | 10.10.255.1/32 | router-id OSPF + IP DNS DHCP |
| veth1 | 10.10.254.1/24 | Red del contenedor Pi-hole |
| — | 10.10.254.53 | Pi-hole (contenedor) |

## 2.3 Sede Norte — Anillo (5 hAP ax lite)

| Nodo | ether1 (anillo) | ether2 (anillo) | WiFi | Loopback |
|------|-----------------|-----------------|------|----------|
| hAP-1A | 10.10.1.2/30 | 10.10.2.1/30 | 192.168.1.1/24 | 10.10.255.11/32 |
| hAP-2A | 10.10.2.2/30 | 10.10.3.1/30 | 192.168.2.1/24 | 10.10.255.12/32 |
| hAP-3A | 10.10.3.2/30 | 10.10.4.1/30 | 192.168.3.1/24 | 10.10.255.13/32 |
| hAP-4A | 10.10.4.2/30 | 10.10.5.1/30 | 192.168.4.1/24 | 10.10.255.14/32 |
| hAP-5A | 10.10.5.2/30 | 10.10.6.1/30 | 192.168.5.1/24 | 10.10.255.15/32 |

**Servidor Norte:** 10.10.0.100/24 (conectado a hAP-1A ether3 = 10.10.0.1/24)

## 2.4 Sede Sur — GW-B (RB5009UG+S+IN)

| Interfaz | Dirección | Comentario |
|----------|-----------|------------|
| ether1 | 100.64.2.2/30 | WAN hacia ISP (gateway 100.64.2.1) |
| ether2 | 10.20.1.1/30 | Anillo → hAP-1B |
| ether3 | 10.20.5.2/30 | Anillo → hAP-4B (cierre) |
| ether7 | 10.99.0.2/30 | Inter-sede → SXT-B |
| loopback | 10.20.255.1/32 | router-id OSPF + IP DNS DHCP |
| veth1 | 10.20.254.1/24 | Red del contenedor AdGuard |
| — | 10.20.254.53 | AdGuard Home (contenedor) |

## 2.5 Sede Sur — Anillo (4 hAP ax lite)

| Nodo | ether1 (anillo) | ether2 (anillo) | WiFi | Loopback |
|------|-----------------|-----------------|------|----------|
| hAP-1B | 10.20.1.2/30 | 10.20.2.1/30 | 192.168.11.1/24 | 10.20.255.11/32 |
| hAP-2B | 10.20.2.2/30 | 10.20.3.1/30 | 192.168.12.1/24 | 10.20.255.12/32 |
| hAP-3B | 10.20.3.2/30 | 10.20.4.1/30 | 192.168.13.1/24 | 10.20.255.13/32 |
| hAP-4B | 10.20.4.2/30 | 10.20.5.1/30 | 192.168.14.1/24 | 10.20.255.14/32 |

**Servidor Sur:** 10.20.0.100/24 (conectado a hAP-3B ether3 = 10.20.0.1/24)

## 2.6 Enlaces inter-sede

| Enlace | Dirección | Comentario |
|--------|-----------|------------|
| GW-A ether1 ↔ SXT-A | 10.99.0.1/30 | Inter-sede, PoE-in alimenta GW-A |
| SXT-A ↔ SXT-B | (sin IP) | Puente L2 transparente 5 GHz |
| SXT-B ↔ GW-B ether7 | 10.99.0.2/30 | Inter-sede |

**Costos OSPF:** Anillo = 10, Inter-sede = 100

---

# 3 · EQUIPOS Y SUS CONFIGURACIONES

## 3.1 GW-A (RB5009UG+S+IN) — Sede Norte

### Qué hace:
- Gateway de salida a Internet de Sede Norte
- Router-id OSPF = 10.10.255.1
- Anuncia default por OSPF (originate-default=if-installed)
- Tiene una ruta estática distance=1 hacia el ISP (gana sobre OSPF)
- Contenedor Pi-hole (DNS filtrado) en 10.10.254.53
- Hace NAT (masquerade) hacia la WAN
- Hace dst-nat del puerto 53 (DNS) a Pi-hole para que ningún cliente se salte el filtrado

### Configuración clave (ver configs/rsc/GW-A.rsc):
```
/ip address add address=100.64.1.2/30 interface=ether7   # WAN
/ip address add address=10.10.1.1/30 interface=ether2     # hAP-1A
/ip address add address=10.10.6.2/30 interface=ether3     # hAP-5A
/ip address add address=10.99.0.1/30 interface=ether1     # inter-sede
/ip address add address=10.10.255.1/32 interface=lo       # loopback
/ip address add address=10.10.254.1/24 interface=veth1    # contenedor
/routing ospf instance add router-id=10.10.255.1 originate-default=if-installed
/ip route add distance=1 gateway=100.64.1.1 check-gateway=arp
/ip firewall nat add chain=srcnat action=masquerade out-interface-list=WAN
/ip firewall nat add chain=dstnat action=dst-nat to-addresses=10.10.254.53 protocol=udp dst-port=53
/ip firewall nat add chain=dstnat action=dst-nat to-addresses=10.10.254.53 protocol=tcp dst-port=53
/container add name=pihole interface=veth1 remote-image=pihole/pihole:latest root-dir=/pihole6/root start-on-boot=yes
```

### Cómo verificar:
```
/routing ospf neighbor print        # 3 Full: hAP-1A, hAP-5A, GW-B
/ip firewall nat print              # masquerade + 2 dst-nat DNS
/ip route print where dst-address=0.0.0.0/0   # estática dist=1 + OSPF dist=110
/container print                    # pihole HEALTHY
/ping 10.10.0.100 count=3           # servidor Norte responde
/ping 10.20.0.100 count=3           # servidor Sur responde (cruza inter-sede)
```

---

## 3.2 GW-B (RB5009UG+S+IN) — Sede Sur

### Qué hace:
- Gateway de salida a Internet de Sede Sur
- Router-id OSPF = 10.20.255.1
- Anuncia default por OSPF (originate-default=if-installed)
- Tiene una ruta estática distance=1 hacia el ISP (gana sobre OSPF)
- Contenedor AdGuard Home (DNS filtrado) en 10.20.254.53
- Hace NAT (masquerade) hacia la WAN
- Hace dst-nat del puerto 53 (DNS) a AdGuard

### Configuración clave (ver configs/rsc/GW-B.rsc):
```
/ip address add address=100.64.2.2/30 interface=ether1    # WAN
/ip address add address=10.20.1.1/30 interface=ether2     # hAP-1B
/ip address add address=10.20.5.2/30 interface=ether3     # hAP-4B
/ip address add address=10.99.0.2/30 interface=ether7     # inter-sede
/ip address add address=10.20.255.1/32 interface=lo       # loopback
/ip address add address=10.20.254.1/24 interface=veth1    # contenedor
/routing ospf instance add router-id=10.20.255.1 originate-default=if-installed
/ip route add distance=1 gateway=100.64.2.1 check-gateway=arp
/ip firewall nat add chain=srcnat action=masquerade out-interface-list=WAN
/ip firewall nat add chain=dstnat action=dst-nat to-addresses=10.20.254.53 protocol=udp dst-port=53
/ip firewall nat add chain=dstnat action=dst-nat to-addresses=10.20.254.53 protocol=tcp dst-port=53
/container add name=adguard interface=veth1 ... start-on-boot=yes
```

### Cómo verificar:
```
/routing ospf neighbor print        # 3 Full: hAP-1B, hAP-4B, GW-A
/ip firewall nat print              # masquerade + 2 dst-nat DNS
/ip route print where dst-address=0.0.0.0/0   # estática dist=1 + OSPF dist=110
/container print                    # adguard HEALTHY
/ping 10.20.0.100 count=3           # servidor Sur responde
/ping 10.10.0.100 count=3           # servidor Norte responde (cruza inter-sede)
```

---

## 3.3 hAP ax lite (9 equipos) — Anillos Norte y Sur

### Qué hacen:
- Forman el anillo OSPF punto a punto entre sí y con el GW
- Proporcionan WiFi a los clientes (SSID UNIS-A1...A5 / UNIS-B1...B4)
- Sirven como gateway DHCP para los clientes WiFi
- **NO llevan ninguna regla NAT** (Regla 8)
- Anuncian su red WiFi por OSPF como pasiva (no forman vecinos en WiFi)

### Configuración clave por hAP (ver configs/rsc/hAP-NA.rsc, hAP-NB.rsc):
```
/ip address add address=10.10.1.2/30 interface=ether1   # anillo hacia GW-A
/ip address add address=10.10.2.1/30 interface=ether2   # anillo hacia hAP-2A
/ip address add address=192.168.1.1/24 interface=br-wifi # WiFi usuarios
/ip address add address=10.10.255.11/32 interface=lo     # loopback
/routing ospf instance add router-id=10.10.255.11
/routing ospf interface-template add interfaces=ether1 type=ptp cost=10
/routing ospf interface-template add interfaces=ether2 type=ptp cost=10
/routing ospf interface-template add interfaces=br-wifi passive
/routing ospf interface-template add interfaces=lo passive
/ip firewall filter add chain=input action=drop   # DROP final (seguridad)
/ip dhcp-server add interface=br-wifi address-pool=pool-wifi
/ip dhcp-server network add address=192.168.1.0/24 gateway=192.168.1.1 dns-server=10.10.255.1
```

### Cómo verificar (en CUALQUIER hAP):
```
/routing ospf neighbor print        # 2 Full
/ip firewall nat print              # VACÍO (Regla 8)
/ip route print where dst-address=0.0.0.0/0   # default OSPF distance=110
/interface ethernet print           # puertos del anillo en estado R
```

---

## 3.4 SXT-A y SXT-B — Enlace inter-sede

### Qué hacen:
- Puente L2 transparente entre las dos sedes
- SXT-A en modo ap-bridge, SXT-B en modo station-bridge
- **No tienen IP** (se administran por MAC desde WinBox → Neighbors)
- Las IPs 10.99.0.0/30 viven en los RB5009, no en las SXT

### Cómo verificar:
Desde WinBox → Neighbors → conectar a SXT-A y SXT-B:
```
/interface wireless registration-table print
```
**Esperado:** Ver al otro SXT con señal y ccq > 90%

---

## 3.5 Servidores Institucionales

### Servidor Norte — Laptop Windows + nginx
- **IP:** 10.10.0.100/24
- **Puerto:** 80 (nginx)
- **Endpoint:** /health devuelve "ok"
- **Arranque automático:** Tarea programada "Campus UNIS nginx"
- **Verificación:** `http://10.10.0.100/health`

### Servidor Sur — Raspberry Pi 4 + nginx
- **IP:** 10.20.0.100/24
- **Puerto:** 80 (nginx)
- **Endpoint:** /health devuelve "ok"
- **Arranque automático:** Servicio habilitado
- **Verificación:** `http://10.20.0.100/health`

---

# 4 · CÓMO VERIFICAR CADA COSA (COMANDOS PASO A PASO)

## 4.1 Verificación rápida en cualquier equipo

Correr estos 4 comandos en cada router:

```
/routing ospf neighbor print
/ip firewall nat print
/ip route print where dst-address=0.0.0.0/0
/interface ethernet print
```

## 4.2 Verificación completa de Sede Norte

### En GW-A:
```
/routing ospf neighbor print          # Esperado: 3 Full (hAP-1A, hAP-5A, GW-B)
/ip firewall nat print                # Esperado: masquerade + 2 dst-nat DNS
/ip route print where dst-address=0.0.0.0/0   # Esperado: estática dist=1 + OSPF dist=110
/container print                      # Esperado: pihole HEALTHY
/ping 10.20.0.100 count=3             # Esperado: 0% pérdida (cruza inter-sede)
```

### En cada hAP Norte (hAP-1A a hAP-5A):
```
/routing ospf neighbor print          # Esperado: 2 Full
/ip firewall nat print                # Esperado: vacío
/ip route print where dst-address=0.0.0.0/0   # Esperado: default OSPF distance=110
```

### Desde laptop (PowerShell):
```powershell
Invoke-WebRequest http://10.10.0.100/health     # 200 OK
Invoke-WebRequest http://10.20.0.100/health     # 200 OK (cruza inter-sede)
Test-NetConnection -ComputerName 10.20.0.100    # responde
nslookup valorant.com 10.10.255.1              # 0.0.0.0 (bloqueado)
nslookup valorant.com 8.8.8.8                   # 0.0.0.0 (bloqueado, dst-nat)
```

---

## 4.3 Verificación completa de Sede Sur

### En GW-B:
```
/routing ospf neighbor print          # Esperado: 3 Full (hAP-1B, hAP-4B, GW-A)
/ip firewall nat print                # Esperado: masquerade + 2 dst-nat DNS
/ip route print where dst-address=0.0.0.0/0   # Esperado: estática dist=1 + OSPF dist=110
/container print                      # Esperado: adguard HEALTHY
/ping 10.10.0.100 count=3             # Esperado: 0% pérdida (cruza inter-sede)
```

### En cada hAP Sur (hAP-1B a hAP-4B):
```
/routing ospf neighbor print          # Esperado: 2 Full
/ip firewall nat print                # Esperado: vacío
/ip route print where dst-address=0.0.0.0/0   # Esperado: default OSPF distance=110
```

---

## 4.4 Verificación de failover WAN (Sede Norte)

### Paso 1 — Estado inicial (GW-A):
```
/ip route print where dst-address=0.0.0.0/0
```
Esperado: `As` hacia 100.64.1.1 (ACTIVE) + `D o` hacia 10.99.0.2 (dist=110)

### Paso 2 — Desenchufar WAN de GW-A (ether7)
Esperar 10-20 segundos.

### Paso 3 — Durante la caída (GW-A):
```
/ip route print where dst-address=0.0.0.0/0
```
Esperado: `Is` hacia 100.64.1.1 (INACTIVE) + `DAo` hacia 10.99.0.2 (ACTIVE)

```
/ping 10.20.0.100 count=3
```
Esperado: 0% pérdida (tráfico cruza inter-sede)

### Paso 4 — Reconectar WAN de GW-A
Esperar 20 segundos.

```
/ip route print where dst-address=0.0.0.0/0
```
Esperado: `As` hacia 100.64.1.1 vuelve a ACTIVE

```
/ping 100.64.1.1 count=3
```
Esperado: responde

---

## 4.5 Verificación de desconexión SXT

### Desde GW-A (antes):
```
/routing ospf neighbor print          # 3 Full
```

**Desenchufar el cable SXT en GW-A ether1** (o GW-B ether7). Esperar 15 s.

### Desde GW-A (después):
```
/routing ospf neighbor print          # 2 Full (solo hAP-1A, hAP-5A)
/ip route print where dst-address=0.0.0.0/0   # solo estática propia, sin OSPF inter-sede
/ping 10.20.0.100 count=3             # 100% pérdida (correcto, sedes separadas)
/ping 10.10.0.100 count=3             # responde (servidor local)
```

### Desde hAP-1B (después):
```
/routing ospf neighbor print          # 2 Full (solo GW-B, hAP-2B)
/ping 10.10.0.100 count=3             # 100% pérdida (no puede ir a Norte)
/ping 10.20.0.100 count=3             # responde (servidor Sur local)
```

**Volver a enchufar SXT. Esperar 20 s.**
```
/routing ospf neighbor print   # volver a 3 Full en GW-A
```

---

# 5 · PARA QUÉ SIRVE CADA COSA

| Componente | Para qué sirve |
|------------|---------------|
| **GW-A / GW-B (RB5009)** | Gateway de salida a Internet, router-id OSPF, anuncia default, hace NAT, hace dst-nat DNS, aloja el contenedor DNS |
| **hAP ax lite** | Nodos del anillo OSPF, proporcionan WiFi a clientes, gateway DHCP para WiFi, anuncian su red por OSPF pasiva |
| **SXT-A / SXT-B** | Puente L2 transparente entre sedes (inter-sede inalámbrico 5 GHz) |
| **Pi-hole (contenedor en GW-A)** | DNS filtrado de Sede Norte — bloquea dominios en blacklist |
| **AdGuard Home (contenedor en GW-B)** | DNS filtrado de Sede Sur — bloquea dominios en blacklist |
| **Servidor Norte (laptop Windows + nginx)** | Página institucional de Sede Norte, endpoint /health |
| **Servidor Sur (Raspberry Pi 4 + nginx)** | Página institucional de Sede Sur, endpoint /health |
| **Loopback (10.10.255.1 / 10.20.255.1)** | router-id de OSPF, IP de DNS que entrega el DHCP a los clientes |
| **veth1 (10.10.254.1 / 10.20.254.1)** | Red de interconexión entre el router y el contenedor DNS |
| **OSPF área 0** | Protocolo de enrutamiento dinámico que permite que todos los routers se conozcan y elijan el mejor camino |
| **Ruta estática distance=1** | Ruta propia hacia el ISP, siempre preferida sobre OSPF |
| **Ruta OSPF distance=110** | Ruta de respaldo por el inter-sede, solo se usa si cae la WAN propia |
| **dst-nat puerto 53** | Fuerza todo el tráfico DNS a pasar por el contenedor de la sede, nadie se salta el filtrado con 8.8.8.8 |
| **Netwatch** | Monitorea la WAN y, al volver, limpia la tabla de conexiones (conntrack) para que el tráfico se recupere solo |

---

# 6 · ESTADOS VERIFICADOS EN VIVO

Todos los siguientes fueron verificados en los equipos físicos el 06/11/2026:

| Equipo | /routing ospf neighbor print | /ip firewall nat print | /ip route default | /container print |
|--------|-----------------------------|------------------------|-------------------|------------------|
| GW-A | 3 Full | masquerade + 2 dst-nat | estática dist=1 + OSPF dist=110 | pihole HEALTHY |
| GW-B | 3 Full | masquerade + 2 dst-nat | estática dist=1 + OSPF dist=110 | adguard HEALTHY |
| hAP-1A | 2 Full | vacío | default OSPF dist=110 | — |
| hAP-2A | 2 Full | vacío | default OSPF dist=110 | — |
| hAP-3A | 2 Full | vacío | default OSPF dist=110 | — |
| hAP-4A | 2 Full | vacío | default OSPF dist=110 | — |
| hAP-5A | 2 Full | vacío | default OSPF dist=110 | — |
| hAP-1B | 2 Full | vacío | default OSPF dist=110 | — |
| hAP-2B | 2 Full | vacío | default OSPF dist=110 | — |
| hAP-3B | 2 Full | vacío | default OSPF dist=110 | — |
| hAP-4B | 2 Full | vacío | default OSPF dist=110 | — |

**Total de adyacencias OSPF: 12** (6 Norte + 5 Sur + 1 inter-sede)

**Servidores:**
- `http://10.10.0.100/health` → 200 OK, cuerpo "ok"
- `http://10.20.0.100/health` → 200 OK, cuerpo "ok"

**Ping cruzado:**
- 10.10.0.100 desde GW-A: responde
- 10.20.0.100 desde GW-A: responde
- 10.10.0.100 desde GW-B: responde
- 10.20.0.100 desde GW-B: responde

**DNS filtrado:**
- `nslookup valorant.com 10.10.255.1` → 0.0.0.0
- `nslookup claude.ai 10.10.255.1` → 0.0.0.0
- `nslookup google.com 10.10.255.1` → resuelve normalmente
- `nslookup valorant.com 8.8.8.8` → 0.0.0.0 (dst-nat funciona)

**Failover:**
- Desenchufar WAN de GW-A → estática INACTIVE, OSPF vía 10.99.0.2 ACTIVE
- Reconectar WAN de GW-A → estática ACTIVE de vuelta
- Desenchufar WAN de GW-B → estática INACTIVE, OSPF vía 10.99.0.1 ACTIVE
- Reconectar WAN de GW-B → estática ACTIVE de vuelta

**SXT:**
- Desconectar SXT → cada anillo sigue funcionando, sedes separadas (correcto)
- Reconectar SXT → vuelven los 3 vecinos OSPF en cada GW

---

# 7 · CHECKLIST FINAL PARA LA DEFENSA

## Técnico (verificado en vivo)

```
[ x ] Servidor Norte (nginx, 10.10.0.100, /health = ok)
[ x ] Servidor Sur (nginx, 10.20.0.100, /health = ok)
[ x ] Conectividad inter-sede (ping + HTTP cruzados)
[ x ] 12 adyacencias OSPF (3 Full cada GW, 2 Full cada hAP)
[ x ] NAT vacío en todos los 9 hAP
[ x ] Failover WAN Sede Norte (desconexión + restauración)
[ x ] Failover WAN Sede Sur (desconexión + restauración)
[ x ] Desconexión SXT (anillos internos independientes)
[ x ] DNS filtrado desde WiFi (DHCP → 10.10.255.1)
[ x ] DNS filtrado con DNS manual 8.8.8.8
[ x ] Tabla de direccionamiento completa
[ x ] Decisiones de diseño (D-01 a D-19)
[ x ] Diagrama de red con IPs y costos OSPF
[ x ] Netwatch limpieza de conntrack (GW-A y GW-B)
[ x ] Guía de demostración paso a paso
```

## Documentación (entregable inicio de semana 15)

```
[ ] Documento de ≤2 páginas (decisiones de diseño + problemas encontrados)
[ ] 05-RESPONSABLES.md con nombres reales
```

## Instalación física (+5 puntos, día de la defensa)

```
[ ] Rackeo: todos los routers en rack o estructura ordenada
[ ] Etiquetado: ORIGEN / PUERTO → DESTINO / PUERTO en ambos extremos de cada cable
[ ] Organización: velcro/bridas, sin cables colgando
```

---

# 8 · COMANDOS CHEAT SHEET

## Desde PowerShell (laptop Windows):
```powershell
Invoke-WebRequest http://10.10.0.100/health
Invoke-WebRequest http://10.20.0.100/health
Test-NetConnection -ComputerName 10.20.0.100
nslookup valorant.com 10.10.255.1
nslookup valorant.com 8.8.8.8
nslookup google.com 10.10.255.1
nslookup google.com 8.8.8.8
ipconfig /flushdns
```

### Desde cualquier router (WinBox → New Terminal):
```
/routing ospf neighbor print
/ip firewall nat print
/ip route print where dst-address=0.0.0.0/0
/interface ethernet print
/container print
/tool netwatch print
/ping 10.10.0.100 count=3
/ping 10.20.0.100 count=3
```

### Desde WinBox (para SXT, sin IP):
- Neighbors → conectar a SXT-A y SXT-B por MAC
- New Terminal: `/interface wireless registration-table print`

---

## ARCHIVOS DE CONFIGURACIÓN EN EL REPO

| Equipo | Archivo |
|--------|---------|
| GW-A | `configs/rsc/GW-A.rsc` |
| GW-B | `configs/rsc/GW-B.rsc` |
| hAP-1A…5A | `configs/rsc/hAP-1A.rsc` … `hAP-5A.rsc` |
| hAP-1B…4B | `configs/rsc/hAP-1B.rsc` … `hAP-4B.rsc` |
| SXT-A | `configs/rsc/SXT-A.rsc` |
| SXT-B | `configs/rsc/SXT-B.rsc` |
| ROUTER-ISP | `configs/rsc/ROUTER-ISP.rsc` |
| Servidores | `servidor/` (nginx Windows + Linux) |

---

> **Regla de oro:** nunca configurar en vivo durante la defensa. La red se entrega funcionando. Si hacés un cambio, registrelo en `docs/06-DECISIONES.md` y actualice este archivo.
>
> **Repo:** `https://github.com/andregil003/campus-unis-dcn2` (rama `main`)