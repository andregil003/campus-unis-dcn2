# 18 · Guía de demostración para la defensa — Campus UNIS DCN2

> Fecha: 06/11/2026 · Sede Norte (Grupo A) · Estado: **todo verificado en equipo físico**
>
> Esta guía te dice exactamente qué entrar, qué comandos correr y qué mostrarle al catedrático en cada momento de la defensa oral. Sigue el orden de los criterios de evaluación (40 puntos + 5 físicos).

---

## Antes de empezar — requisitos previos

| Cosa | Valor |
|------|-------|
| Laptop conectada a | WiFi `UNIS-A1` (Sede Norte) |
| Usuario admin routers | `admin` / clave en `configs/rsc/GW-A.rsc` bloque 1 |
| Contraseña WiFi | `UNIS2026` |
| Contraseña Pi-hole panel web | `UNIS2026` |

---

## Criterio 1 — OSPF funcionando (8 puntos)

**Qué mostrar:** Que todos los routers del campus tienen vecinos OSPF en estado `Full`.

### Desde GW-A:
```
/routing ospf neighbor print
```
**Esperado:** 3 vecinos `Full`:
- `10.10.1.2` (hAP-1A)
- `10.10.6.1` (hAP-5A)
- `10.99.0.2` (GW-B)

### Desde GW-B:
```
/routing ospf neighbor print
```
**Esperado:** 3 vecinos `Full`:
- `10.20.1.2` (hAP-1B)
- `10.20.5.1` (hAP-4B)
- `10.99.0.1` (GW-A)

### Desde cada hAP (ej. hAP-1A):
```
/routing ospf neighbor print
```
**Esperado:** 2 vecinos `Full` (uno hacia el GW, otro hacia el siguiente hAP del anillo).

**Qué decirle al catedrático:**
> *"Los 11 equipos del campus (2 RB5009 + 9 hAP ax lite) participan en OSPF área 0. El campus suma 12 adyacencias totales: 6 del anillo Norte, 5 del anillo Sur y 1 inter-sede. Todos los vecinos están en estado Full."*

---

## Criterio 2 — Conectividad inter-sede (6 puntos)

**Qué mostrar:** Que un cliente de Sede Norte alcanza el servidor de Sede Sur y viceversa.

### Desde tu laptop (PowerShell):
```powershell
Invoke-WebRequest http://10.20.0.100/health
```
**Esperado:** `StatusCode: 200`, `Content: ok`

```powershell
Invoke-WebRequest http://10.10.0.100/health
```
**Esperado:** `StatusCode: 200`, `Content: ok`

```powershell
Test-NetConnection -ComputerName 10.20.0.100
```
**Esperado:** `PingSucceeded: True`

**Qué decirle al catedrático:**
> *"El servidor de Sede Norte (10.10.0.100) y el de Sede Sur (10.20.0.100) se ven entre sí. Ambos responden en el puerto 80 con /health = ok. La conectividad inter-sede es permanente."*

---

## Criterio 3 — Filtrado DNS demostrable (4 puntos)

### 3a. Pi-hole — Sede Norte

**Desde tu navegador (conectado a WiFi `UNIS-A1`):**
1. Abrí: `http://10.10.254.53/admin`
2. Usuario: `admin` / Contraseña: `UNIS2026`
3. Menú izquierdo → **Dashboard** — mostrá consultas bloqueadas
4. Menú izquierdo → **Blacklist** — mostrá los dominios bloqueados (`valorant.com`, `claude.ai`, `chatgpt.com`, `perplexity.com`, etc.)
5. Menú izquierdo → **Query Log** — mostrá consultas en tiempo real

### Desde PowerShell (cliente en WiFi `UNIS-A1`):
```powershell
nslookup valorant.com 10.10.255.1
```
**Esperado:** `0.0.0.0` (bloqueado)

```powershell
nslookup google.com 10.10.255.1
```
**Esperado:** resuelve normalmente (no bloqueado)

### 3b. AdGuard Home — Sede Sur

**Desde tu navegador:**
1. Abrí: `http://10.20.254.53/admin`
2. Usuario y contraseña de AdGuard (configurados en GW-B)
3. Mostrá el dashboard y las listas de bloqueo

**Qué decirle al catedrático:**
> *"Cada sede tiene su propio servidor DNS filtrado: Pi-hole en Sede Norte y AdGuard Home en Sede Sur. Ambos corren como contenedores dentro del RB5009 de cada sede. Los dominios en la blacklist devuelven 0.0.0.0 (bloqueados), y el resto resuelve normalmente."*

---

## Criterio 4 — Failover WAN automático < 30 s (10 puntos)

### Paso 1 — Estado inicial (WAN conectada)
Desde **GW-A**:
```
/ip route print where dst-address=0.0.0.0/0
```
**Esperado:**
```
0  As  0.0.0.0/0    100.64.1.1   main  1      ← WAN propia ACTIVA
   D o  0.0.0.0/0    10.99.0.2%ether1  main  110  ← OSPF respaldo
```

### Paso 2 — Desenchufar la WAN
**Acción física:** Desenchufá el cable de **GW-A ether7** (el que va al ROUTER-ISP).
Esperá 10-20 segundos.

### Paso 3 — Verificar durante la caída
Desde **GW-A**:
```
/ip route print where dst-address=0.0.0.0/0
```
**Esperado:**
```
0  Is  0.0.0.0/0    100.64.1.1   main  1      ← INACTIVE
   D o  0.0.0.0/0    10.99.0.2%ether1  main  110  ← solo OSPF vía inter-sede
```

Desde tu laptop (PowerShell):
```powershell
Test-NetConnection -ComputerName 10.20.0.100
```
**Esperado:** `PingSucceeded: True` (el tráfico cruza por el inter-sede hacia Sede Sur)

### Paso 4 — Restaurar
**Acción física:** Volvé a enchufar el cable de **GW-A ether7**.
Esperá unos 20 segundos.

Desde **GW-A**:
```
/ip route print where dst-address=0.0.0.0/0
```
**Esperado:** Vuelve a aparecer `As 0.0.0.0/0 100.64.1.1 distance=1` (ACTIVE).

**Qué decirle al catedrático:**
> *"Cuando se cae la WAN de Sede Norte, el tráfico sale por el enlace inter-sede hacia Sede Sur en menos de 10 segundos. Cuando vuelve la WAN, el tráfico regresa automáticamente al camino propio. La reconvergencia es automática, sin intervención manual."*

> *(Lo mismo aplica para Sede Sur: desenchufar WAN de GW-B ether7, el tráfico sale por el inter-sede hacia GW-A, y al reconectar regresa solo.)*

---

## Criterio 5 — Restauración automática (6 puntos)

Ya queda demostrado en el paso 4 anterior: al reconectar el cable WAN, la ruta estática propia se reinstala como `ACTIVE` (distance=1) y el tráfico regresa solo por el camino preferido.

**Qué decirle al catedrático:**
> *"La restauración es automática. Al volver el enlace WAN, la ruta propia recupera prioridad (distance=1) sobre la ruta OSPF de la sede vecina (distance=110), y el tráfico regresa por el camino preferido."*

---

## Criterio 6 — NAT exclusivo en gateway (Regla 8)

**En cualquier hAP** (ej. hAP-1A):
```
/ip firewall nat print
```
**Esperado:** Tabla vacía (sin reglas).

**En GW-A:**
```
/ip firewall nat print
```
**Esperado:** 1 regla `masquerade` en WAN + 2 reglas `dst-nat` puerto 53 → Pi-hole (`10.10.254.53`).

**En GW-B:**
```
/ip firewall nat print
```
**Esperado:** 1 regla `masquerade` en WAN + 2 reglas `dst-nat` puerto 53 → AdGuard (`10.20.254.53`).

**Qué decirle al catedrático:**
> *"El único dispositivo autorizado a hacer NAT en cada sede es el RB5009 gateway. Los hAP ax lite no tienen ninguna regla de NAT. El tráfico de los clientes WiFi fluye enrutado de extremo a extremo hasta el RB5009, donde ocurre el masquerade hacia Internet."*

---

## Criterio 7 — Documentación (4 puntos)

**Qué mostrar:**
- Tabla de direccionamiento completa: `docs/01-TABLA-IPs.md`
- Decisiones de diseño: `docs/06-DECISIONES.md` (D-01 a D-19)
- Diagrama de red con IPs y costos OSPF: `docs/diagrama-red.drawio` (archivo draw.io) + `docs/17-DIAGRAMA-RED.md`
- Runbook de verificación: `docs/13-GUIA-VERIFICACION.md`
- Evidencia de pruebas: `docs/16-EVIDENCIA-PRUEBAS.md`

**Qué decirle al catedrático:**
> *"Toda la documentación está versionada en el repositorio: tabla de direccionamiento, decisiones de diseño (19 ADR), diagrama de red con draw.io, runbook de verificación y evidencia de todas las pruebas en vivo."*

---

## Criterio 8 — Preguntas individuales (2 puntos)

Cualquier integrante del grupo debe poder responder sobre cualquier parte de la configuración. Repasá estos puntos clave:

| Pregunta posible | Respuesta corta |
|------------------|-----------------|
| ¿Cuántos vecinos OSPF tiene GW-A? | 3: hAP-1A, hAP-5A, GW-B |
| ¿Cuánto cuesta el enlace inter-sede? | 100 |
| ¿Cuánto cuesta un enlace del anillo? | 10 |
| ¿Qué IP tiene Pi-hole? | 10.10.254.53 |
| ¿Qué IP tiene AdGuard? | 10.20.254.53 |
| ¿Qué IP tiene el servidor Norte? | 10.10.0.100 |
| ¿Qué IP tiene el servidor Sur? | 10.20.0.100 |
| ¿Qué pasa si se cae la WAN de un GW? | El tráfico sale por el inter-sede hacia el otro GW |
| ¿Los hAP tienen NAT? | No, ningún hAP lleva reglas NAT |
| ¿Qué clave tiene el WiFi? | UNIS2026 |

---

## Comandos "cheat sheet" — copiar y pegar en la defensa

### Desde PowerShell (laptop):
```powershell
Invoke-WebRequest http://10.10.0.100/health
Invoke-WebRequest http://10.20.0.100/health
Test-NetConnection -ComputerName 10.20.0.100
nslookup valorant.com 10.10.255.1
nslookup valorant.com 8.8.8.8
nslookup google.com 8.8.8.8
```

### Desde cualquier router (WinBox → New Terminal):
```
/routing ospf neighbor print
/ip firewall nat print
/ip route print where dst-address=0.0.0.0/0
/tool netwatch print
```

---

## Estado actual del proyecto (resumen para el catedrático)

| Ítem | Estado |
|------|--------|
| 12 adyacencias OSPF | ✅ Verificado |
| NAT vacío en hAP | ✅ Verificado |
| Failover WAN Norte + Sur | ✅ Verificado |
| Restauración automática | ✅ Verificado |
| DNS filtrado Pi-hole + AdGuard | ✅ Verificado |
| DNS forzado con 8.8.8.8 | ✅ Verificado |
| Servidores Norte y Sur arriba | ✅ Verificado |
| Diagrama de red draw.io | ✅ Listo |
| Decisiones de diseño (D-01 a D-19) | ✅ Listo |
| Documento de 2 páginas | ❌ Pendiente |
| Responsables con nombres | ❌ Pendiente |
| Etiquetado físico de cables | ❌ Pendiente (día de la defensa) |

---

> **Regla de oro:** nunca configurar en vivo durante la defensa. La red se entrega funcionando. Si hacés un cambio, registrelo en `docs/06-DECISIONES.md` y actualice este archivo.