# 16 · Evidencia de pruebas verificadas en vivo — Campus UNIS DCN2

> Fecha: 06/11/2026 · Equipo: Sede Norte (Grupo A) · Estado: **verificado en equipo físico**

---

## Resumen de pruebas ejecutadas

| Prueba | Resultado | Detalle |
|--------|-----------|---------|
| Servidor Norte (nginx) | ✅ PASS | IP `10.10.0.100`, puerto 80, `/health` = `ok` |
| Servidor Sur (nginx) | ✅ PASS | IP `10.20.0.100`, `/health` = `ok` |
| Conectividad inter-sede | ✅ PASS | Ping cruzado 10.10.0.100 ↔ 10.20.0.100, 0% pérdida |
| OSPF vecinos (11 equipos) | ✅ PASS | 12 adyacencias (3 Full cada GW, 2 Full cada hAP) |
| NAT vacío en hAP | ✅ PASS | `/ip firewall nat print` vacío en los 9 hAP |
| Failover WAN Sede Norte | ✅ PASS | Desenchufar `GW-A ether7` → OSPF vía `10.99.0.2` toma el control |
| Restauración WAN Sede Norte | ✅ PASS | Reconectar → ruta estática propia recupera ACTIVE |
| Failover WAN Sede Sur | ✅ PASS | Desenchufar `GW-B ether7` → OSPF vía `10.99.0.1` toma el control |
| Restauración WAN Sede Sur | ✅ PASS | Reconectar → ruta estática propia recupera ACTIVE |
| Desconexión SXT (anillo interno) | ✅ PASS | Cada anillo sigue enrutando por su cuenta, sedes separadas |
| DNS filtrado por WiFi (DHCP) | ✅ PASS | `nslookup <bloqueado> 10.10.255.1` → `0.0.0.0` |
| DNS filtrado con DNS manual `8.8.8.8` | ⚠️ PENDIENTE | Requiere cliente conectado **únicamente** a la red de la sede (sin Tailscale, CloudflareWARP ni otro WiFi) |

---

## 1. Servidores institucionales (estándar E-08, S-01 a S-06)

### Sede Norte — Laptop Windows + nginx

```
IPAddress   InterfaceAlias
---------   --------------
10.10.0.100 Ethernet

Name    Id Path
----    -- ----
nginx 2204 C:\nginx\nginx.exe
nginx 9036 C:\nginx\nginx.exe
```

```
Test-NetConnection -ComputerName 127.0.0.1 -Port 80
TcpTestSucceeded : True

Invoke-WebRequest http://127.0.0.1/health
StatusCode        : 200
Content           : ok

Invoke-WebRequest http://10.10.0.100/health
StatusCode        : 200
Content           : ok

Test-NetConnection -ComputerName 10.10.0.100 -Port 80
TcpTestSucceeded : True
```

### Sede Sur — Raspberry Pi 4 + nginx

Verificado desde GW-A y GW-B:
- `/ping 10.20.0.100 count=3` → 0% pérdida
- `Invoke-WebRequest http://10.20.0.100/health` → `200 OK`, cuerpo `ok`

---

## 2. OSPF — 12 adyacencias (estándar E-03)

| Equipo | Vecinos esperados | Vecinos Full observados |
|--------|-------------------|-------------------------|
| GW-A | hAP-1A, hAP-5A, GW-B | 3 Full |
| GW-B | hAP-1B, hAP-4B, GW-A | 3 Full |
| hAP-1A | GW-A, hAP-2A | 2 Full |
| hAP-2A | hAP-1A, hAP-3A | 2 Full |
| hAP-3A | hAP-2A, hAP-4A | 2 Full |
| hAP-4A | hAP-3A, hAP-5A | 2 Full |
| hAP-5A | hAP-4A, GW-A | 2 Full |
| hAP-1B | GW-B, hAP-2B | 2 Full |
| hAP-2B | hAP-1B, hAP-3B | 2 Full |
| hAP-3B | hAP-2B, hAP-4B | 2 Full |
| hAP-4B | hAP-3B, GW-B | 2 Full |

**Total: 12 adyacencias** (6 Norte + 5 Sur + 1 inter-sede). ECMP corregido en hAP-3A/hAP-4A (costo del enlace L4 subido de 10 a 20).

---

## 3. NAT — Regla 8 (hAP sin NAT)

Todos los 9 hAP: `/ip firewall nat print` → tabla vacía.

GW-A: 1 masquerade + 2 dst-nat DNS (UDP/TCP puerto 53 → `10.10.254.53` Pi-hole).
GW-B: 1 masquerade + 2 dst-nat DNS (UDP/TCP puerto 53 → `10.20.254.53` AdGuard).

---

## 4. Failover WAN — Sede Norte (verificado en vivo)

```
Estado inicial (GW-A):
0  As  0.0.0.0/0    100.64.1.1   main  1      ← WAN propia ACTIVA
   D o  0.0.0.0/0    10.99.0.2%ether1  main  110  ← OSPF respaldo

Durante la caída (WAN desconectada):
0  Is  0.0.0.0/0    100.64.1.1   main  1      ← INACTIVE
   D o  0.0.0.0/0    10.99.0.2%ether1  main  110  ← solo OSPF vía inter-sede

/ping 10.20.0.100 count=3  → 0% pérdida (cruza inter-sede)
/ping 100.64.2.1 count=3   → 0% pérdida (ISP de Sur)

Restauración (WAN reconectada):
Vuelve a aparecer As 0.0.0.0/0 100.64.1.1 distance=1 (ACTIVE)
/ping 100.64.1.1 count=3   → responde
```

Reconvergencia observada en < 10 s (límite del curso: 30 s).

---

## 5. Failover WAN — Sede Sur (verificado en vivo)

```
Estado inicial (GW-B):
0  As  0.0.0.0/0    100.64.2.1   main  1      ← WAN propia ACTIVA
   D o  0.0.0.0/0    10.99.0.1%ether7  main  110  ← OSPF respaldo

Durante la caída (WAN desconectada):
0  Is  0.0.0.0/0    100.64.2.1   main  1      ← INACTIVE
   D o  0.0.0.0/0    10.99.0.1%ether7  main  110  ← solo OSPF vía inter-sede

/ping 10.10.0.100 count=3  → 0% pérdida (Servidor Norte vía inter-sede)
/ping 100.64.1.1 count=3   → 0% pérdida (ISP de Norte)

Restauración (WAN reconectada):
Vuelve a aparecer As 0.0.0.0/0 100.64.2.1 distance=1 (ACTIVE)
/ping 100.64.2.1 count=3   → responde
```

---

## 6. Desconexión SXT — anillo interno sigue enrutando

```
GW-A antes de desconectar SXT: 3 Full (hAP-1A, hAP-5A, GW-B)
GW-A después de desconectar:   2 Full (hAP-1A, hAP-5A), GW-B desapareció
hAP-1B después de desconectar: 2 Full (GW-B, hAP-2B), GW-A desaparecido

/ping 10.20.0.100 desde GW-A → 100% pérdida (sedes separadas, correcto)
/ping 10.10.0.100 desde hAP-1B → 100% pérdida (sedes separadas, correcto)
/ping 10.20.0.100 desde hAP-1B → 0% pérdida (servidor Sur local, correcto)

Ruta default en GW-A tras SXT caído: solo estática dist=1 hacia 100.64.1.1
```

Reconectar el SXT restaura los 3 vecinos OSPF y el ping cruzado.

---

## 7. DNS filtrado — Pi-hole (Sede Norte) y AdGuard (Sede Sur)

### Contenedores

| Sede | Producto | IP | Estado |
|------|----------|-----|--------|
| Norte | Pi-hole v6 | `10.10.254.53` | HEALTHY |
| Sur | AdGuard Home | `10.20.254.53` | HEALTHY |

### Configuración

- DHCP entrega DNS `10.10.255.1` (Norte) / `10.20.255.1` (Sur), loopback del GW.
- Cada GW hace `dst-nat` UDP y TCP puerto 53 → su contenedor (anti-bypass).
- Upstreams: `1.1.1.1; 9.9.9.9`.
- Contraseña admin Pi-hole: `UNIS2026`.

### Dominios bloqueados en Pi-hole (Norte)

**Exactos (10):**
`valorant.com`, `playvalorant.com`, `riotgames.com`, `pvp.net`, `riotcdn.net`, `claude.ai`, `anthropic.com`, `chatgpt.com`, `openai.com`, `perplexity.com`

**Regex (5):**
`(\.|^)claude\.ai$`, `(\.|^)anthropic\.com$`, `(\.|^)chatgpt\.com$`, `(\.|^)openai\.com$`, `(\.|^)perplexity\.ai$`

### Verificación desde cliente WiFi `UNIS-A1` (DNS por DHCP → `10.10.255.1`)

```
nslookup valorant.com 10.10.255.1   → 0.0.0.0 (bloqueado)
nslookup playvalorant.com 10.10.255.1 → 0.0.0.0 (bloqueado)
nslookup riotgames.com 10.10.255.1 → 0.0.0.0 (bloqueado)
nslookup claude.ai 10.10.255.1 → 0.0.0.0 (bloqueado)
nslookup chatgpt.com 10.10.255.1 → 0.0.0.0 (bloqueado)
nslookup perplexity.ai 10.10.255.1 → 0.0.0.0 (bloqueado)
nslookup google.com 10.10.255.1 → resuelve normalmente (no bloqueado)
```

### Verificación con DNS manual `8.8.8.8` (PENDIENTE)

**Resultado previo (falló):** El cliente tenía múltiples interfaces activas (Ethernet `10.10.0.100`, WiFi `192.168.12.250`, CloudflareWARP `172.16.0.2`, Tailscale `100.65.166.48`). El tráfico DNS hacia `8.8.8.8` no pasó por GW-A, por lo que el `dst-nat` no lo atrapó.

**Requisito para la defensa:** Un cliente conectado **únicamente** al WiFi `UNIS-A1` (o cable Ethernet directo a un hAP de Sede Norte), sin Tailscale, sin CloudflareWARP, sin otro WiFi. Configurar DNS manual a `8.8.8.8` y verificar:
```
nslookup valorant.com 8.8.8.8   → debe responder 0.0.0.0 (bloqueado por dst-nat)
nslookup claude.ai 8.8.8.8      → debe responder 0.0.0.0 (bloqueado por dst-nat)
nslookup google.com 8.8.8.8     → debe resolver normalmente
```

---

## 8. Checklist final antes de la defensa

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
[ ] DNS filtrado con DNS manual 8.8.8.8 (requiere cliente aislado en red de la sede)
[ x ] Tabla de direccionamiento completa (docs/01-TABLA-IPs.md)
[ x ] Decisiones de diseño (docs/06-DECISIONES.md)
[ ] Diagrama de red con IPs y costos OSPF (falta crear)
[ ] Documento de ≤2 páginas (falta crear)
[ ] 05-RESPONSABLES.md con nombres reales (tiene placeholders)
[ ] Etiquetado físico de cables (ORIGEN / PUERTO → DESTINO / PUERTO)
```

---

> **Regla de oro:** nunca configurar en vivo durante la defensa. La red se entrega funcionando. Si hacés un cambio, registrelo en `docs/06-DECISIONES.md` y actualice este archivo.