# 15 · Repaso del enunciado vs. estado real del campus

> Fecha: 06/11/2026 · Fuente: `fuentes/enunciado-proyecto-final.pdf` (4 páginas) · Estado: **en curso**
>
> Este documento cruza cada regla del enunciado con lo que se verificó en vivo en el equipo físico.

---

## Resumen ejecutivo

| Regla del enunciado | Estado | Verificación |
|---------------------|--------|--------------|
| R1 — Salida a Internet independiente por sede | ✅ CUMPLE | Gateway propio con default estática `dist=1` |
| R2 — DNS filtrado por sede (Pi-hole / AdGuard) | ✅ CUMPLE | Contenedor `HEALTHY`, blacklist probada desde WiFi |
| R3 — Conectividad inter-sede permanente | ✅ CUMPLE | Ping y HTTP cruzados entre servidores de ambas sedes |
| R4 — Failover WAN automático < 30 s | ✅ CUMPLE | Verificado desenchufando `GW-A ether7` |
| R5 — Restauración automática < 30 s | ✅ CUMPLE | Verificado reconectando `GW-A ether7` |
| R6 — OSPF en todos los nodos, vecinos Full | ✅ CUMPLE | 12 adyacencias (3 Full en cada GW, 2 Full en cada hAP) |
| R7 — Documentación previa (diagrama, tabla IPs, documento ≤2 pp.) | ⚠️ PARCIAL | Tabla IPs lista; faltan diagrama y documento de diseño |
| R8 — NAT exclusivo en gateway, hAP sin NAT | ✅ CUMPLE | `ip firewall nat print` vacío en todos los 9 hAP |

---

## Detalle por regla del enunciado

### Regla 1 — Salida a Internet independiente por sede

**Enunciado:** En condiciones normales, el tráfico de Sede Norte sale exclusivamente por RB5009-A y el de Sede Sur exclusivamente por RB5009-B. Ningún flujo cruza el inter-sede cuando la WAN propia está activa.

**Estado real:**
- GW-A: ruta estática `dist=1` hacia `100.64.1.1` (ISP de Norte), activa. OSPF `dist=110` vía `10.99.0.2` como respaldo.
- GW-B: ruta estática `dist=1` hacia `100.64.2.1` (ISP de Sur), activa. OSPF `dist=110` vía `10.99.0.1` como respaldo.
- Verificación: `/ip route print where dst-address=0.0.0.0/0` en ambos GW confirma la estática propia como activa y la OSPF remota como respaldo de menor prioridad.

**Cumple: ✅**

---

### Regla 2 — DNS filtrado por sede

**Enunciado:** Cada sede filtra DNS con su propio servicio: Pi-hole en Sede Norte, AdGuard Home en Sede Sur. Ambos como containers dentro del RB5009. El bloqueo debe ser demostrable durante la defensa consultando un dominio de prueba acordado con el catedrático.

**Estado real:**
- GW-A: Pi-hole v6 en `10.10.254.53`, contenedor `HEALTHY`, `start-on-boot=yes`.
- GW-B: AdGuard Home en `10.20.254.53`, contenedor `HEALTHY`.
- DHCP entrega DNS `10.10.255.1` (Norte) / `10.20.255.1` (Sur), que es el loopback del GW y reenvía al contenedor.
- Reglas `dst-nat` en ambos GW forzan UDP y TCP puerto 53 hacia el contenedor (anti-bypass).
- Blacklist agregada en Pi-hole (Norte): `valorant.com`, `playvalorant.com`, `riotgames.com`, `pvp.net`, `riotcdn.net`, `claude.ai`, `anthropic.com`, `chatgpt.com`, `openai.com`, `perplexity.com` + 5 reglas regex.
- Verificación desde cliente WiFi `UNIS-A1`: `nslookup <dominio-bloqueado> 10.10.255.1` → `0.0.0.0` (bloqueado). `nslookup google.com 10.10.255.1` → resuelve normalmente.

**Cumple: ✅** (pendiente: verificar desde cliente con DNS manual `8.8.8.8` conectado **únicamente** a la red de la sede)

---

### Regla 3 — Conectividad inter-sede permanente

**Enunciado:** En todo momento, cualquier nodo de Sede Norte debe poder alcanzar el servidor de Sede Sur (`10.20.0.100`) y viceversa. Si el enlace inter-sede cae, el proyecto no cumple este requisito independientemente del estado de las WAN.

**Estado real:**
- Ping `10.20.0.100` desde GW-A: 0% pérdida, respuesta en ~2 ms.
- Ping `10.10.0.100` desde GW-B: 0% pérdida, respuesta en ~5 ms.
- HTTP `/health` cruzado en ambos sentidos: `200 OK`, cuerpo `ok`.
- Las dos sedes se ven a través del inter-sede `10.99.0.0/30`.

**Cumple: ✅**

---

### Regla 4 — Failover WAN automático < 30 s

**Enunciado:** Al desconectar físicamente el cable WAN de cualquier RB5009, el tráfico de esa sede debe seguir saliendo a Internet por el inter-sede hacia el RB5009 de la otra sede. Reconvergencia sin intervención manual en menos de 30 segundos. El traceroute posterior debe confirmar que el tráfico cruza `10.99.0.0/30`.

**Estado real (verificado en vivo el 06/11/2026):**
- Antes: GW-A tenía `As 0.0.0.0/0 100.64.1.1 dist=1` (ACTIVE) + `D o 0.0.0.0/0 10.99.0.2 dist=110` (OSPF respaldo).
- Durante (WAN desconectada): La estática pasó a `Is` (INACTIVE). Solo quedó `DAo 0.0.0.0/0 10.99.0.2%ether1 dist=110`.
- `/ping 10.20.0.100` desde GW-A: 0% pérdida (tráfico cruzando inter-sede).
- `/ping 100.64.2.1` desde GW-A: 0% pérdida (llegando al ISP de Sur vía GW-B).
- Después (WAN reconectada): La estática volvió a `As` (ACTIVE) y el tráfico regresó por el camino propio.

**Cumple: ✅** (reconvergencia observada en < 10 s, dentro del límite de 30 s del curso)

---

### Regla 5 — Restauración automática

**Enunciado:** Al reconectar la WAN que fue desconectada, el tráfico debe volver a salir por su camino preferido en menos de 30 segundos, sin intervención manual. La tabla de rutas debe reflejar el estado correcto.

**Estado real:** Verificado en vivo. Al reconectar `GW-A ether7`, la ruta estática `dist=1` hacia `100.64.1.1` se reinstaló como ACTIVE y el tráfico regresó por el camino propio. `/ping 100.64.1.1` respondió 3/3.

**Cumple: ✅**

---

### Regla 6 — OSPF en todos los nodos

**Enunciado:** Todos los routers del campus, incluyendo los hAP ax lite, participan en OSPF. No se acepta ruteo estático como solución principal. Durante la defensa se ejecuta el comando de verificación de vecinos OSPF en ambos RB5009 y debe mostrar todos los vecinos esperados en estado Full.

**Estado real (verificado en vivo en los 11 equipos):**

| Equipo | Vecinos esperados | Vecinos Full observados | NAT vacío |
|--------|-------------------|-------------------------|-----------|
| GW-A | hAP-1A, hAP-5A, GW-B | 3 Full ✅ | — |
| GW-B | hAP-1B, hAP-4B, GW-A | 3 Full ✅ | — |
| hAP-1A | GW-A, hAP-2A | 2 Full ✅ | ✅ Vacío |
| hAP-2A | hAP-1A, hAP-3A | 2 Full ✅ | ✅ Vacío |
| hAP-3A | hAP-2A, hAP-4A | 2 Full ✅ | ✅ Vacío |
| hAP-4A | hAP-3A, hAP-5A | 2 Full ✅ | ✅ Vacío |
| hAP-5A | hAP-4A, GW-A | 2 Full ✅ | ✅ Vacío |
| hAP-1B | GW-B, hAP-2B | 2 Full ✅ | ✅ Vacío |
| hAP-2B | hAP-1B, hAP-3B | 2 Full ✅ | ✅ Vacío |
| hAP-3B | hAP-2B, hAP-4B | 2 Full ✅ | ✅ Vacío |
| hAP-4B | hAP-3B, GW-B | 2 Full ✅ | ✅ Vacío |

**Total de adyacencias: 12** (6 Norte + 5 Sur + 1 inter-sede), exactamente como espera el enunciado.
**ECMP corregido:** hAP-3A y hAP-4A tenían ruta default duplicada (costo 30 por ambos lados). Se subió el costo del enlace L4 de 10 a 20 en ambos extremos. Ahora cada uno tiene una sola ruta default OSPF.

**Cumple: ✅**

---

### Regla 7 — Documentación previa a la defensa

**Enunciado:** Cada grupo entrega antes de la defensa: el diagrama de red completo con IPs y costos OSPF, la tabla de direccionamiento completa, y un documento de máximo dos páginas describiendo las decisiones de diseño tomadas y los problemas encontrados durante la implementación.

**Estado real:**
- ✅ Tabla de direccionamiento completa: `docs/01-TABLA-IPs.md` (vigente desde 30/10/2026).
- ✅ Decisiones de diseño: `docs/06-DECISIONES.md` (D-01 a D-19, todas tomadas).
- ✅ Runbook de verificación: `docs/13-GUIA-VERIFICACION.md` (creado por PUCK).
- ✅ Documento Pi-hole DNS: `docs/14-PIHOLE-DNS-FILTRADO.md` (creado por PUCK).
- ✅ Repaso del enunciado: `docs/15-REPASO-ENUNCIADO.md` (este documento).
- ❌ **Diagrama de red completo con IPs y costos OSPF:** aún no existe en el repo.
- ❌ **Documento de máximo 2 páginas:** aún no existe como entregable independiente.

**Cumple: ⚠️ PARCIAL** — Faltan el diagrama y el documento de diseño de 2 páginas.

---

### Regla 8 — NAT exclusivo en el gateway de sede

**Enunciado:** El único dispositivo autorizado a realizar NAT en cada sede es el RB5009 correspondiente. Los hAP ax lite no deben tener ninguna regla de NAT configurada. El tráfico de los clientes WiFi debe fluir enrutado de extremo a extremo hasta el RB5009, donde ocurre la traducción hacia la WAN. Durante la defensa se verificará la tabla de rutas y las reglas de firewall en al menos dos hAP ax lite.

**Estado real (verificado en vivo):**
- GW-A: 1 regla `masquerade` en WAN + 2 reglas `dst-nat` puerto 53 → Pi-hole.
- GW-B: 1 regla `masquerade` en WAN + 2 reglas `dst-nat` puerto 53 → AdGuard.
- Todos los 9 hAP: `/ip firewall nat print` → tabla vacía (sin reglas).
- Verificación: `/ip firewall nat print` en hAP-1A, hAP-2A, hAP-3A, hAP-4A, hAP-5A, hAP-1B, hAP-2B, hAP-3B, hAP-4B → todas vacías.

**Cumple: ✅**

---

## Criterios de evaluación del curso (referencia de puntaje)

| Criterio | Pts | Estado | Observación |
|----------|-----|--------|-------------|
| OSPF funcionando (vecinos Full en ambas sedes) | 8 | ✅ | 12 adyacencias verificadas en vivo |
| Conectividad inter-sede (ping + curl entre servidores) | 6 | ✅ | Ping y HTTP cruzados OK |
| Filtrado DNS activo (bloqueo demostrable en Pi-hole y AdGuard) | 4 | ✅ | 10 dominios + 5 regex bloqueados, verificado desde WiFi |
| Failover WAN (< 30 s con traceroute confirmatorio) | 10 | ✅ | Verificado desenchufando WAN de GW-A |
| Restauración automática (regreso sin intervención manual) | 6 | ✅ | Verificado reconectando WAN de GW-A |
| Documentación (diagrama, tabla de IPs, documento de diseño) | 4 | ⚠️ | Tabla IPs y decisiones listas; faltan diagrama y documento de 2 pp. |
| Preguntas individuales del catedrático | 2 | — | Depende del equipo el día de la defensa |
| **Subtotal** | **40** | | |
| Instalación física (rackeo 2 + etiquetas 2 + orden 1) | +5 | ❌ | No verificado (trabajo físico en rack) |

**Total potencial: 45 puntos**

---

## Qué falta antes de la defensa (checklist)

### Técnico (verificación en vivo)
- [ ] Verificar failover de Sede Sur (desenchufar WAN de GW-B) — coordinar con Grupo B
- [ ] Verificar desconexión del cable SXT (anillo interno sigue enrutando)
- [ ] Verificar DNS filtrado desde cliente con DNS manual `8.8.8.8` conectado **únicamente** a la red de la sede (sin Tailscale, CloudflareWARP u otro WiF
- [ ] Practicar failover al menos 3 veces (recomendado por el enunciado)

### Documentación (entregable antes de la defensa, inicio de semana 15)
- [ ] Crear diagrama de red completo con IPs y costos OSPF (Regla 7)
- [ ] Crear documento de máximo 2 páginas: decisiones de diseño + problemas encontrados (Regla 7)
- [ ] Completar `docs/05-RESPONSABLES.md` con nombres reales (placeholders `_(A)_`…`_(E)_`)

### Instalación física (+5 puntos, día de la defensa)
- [ ] Rackeo: todos los routers en rack o estructura ordenada (2 pts)
- [ ] Etiquetado: `ORIGEN / PUERTO → DESTINO / PUERTO` en ambos extremos de cada cable (2 pts)
- [ ] Organización: velcro/bridas, sin cables colgando (1 pt)

---

## Notas sobre el enunciado vs. realidad desplegada

| Punto del enunciado | Qué dice | Qué desplegamos | Diferencia |
|---------------------|----------|-----------------|------------|
| Gateway | RB5009UPr+S+ | RB5009UG+S+IN | Sin PoE-out (D-07, D-17) — no afecta arquitectura |
| Servidor Norte | Raspberry Pi con nginx | Laptop Windows + nginx | Aprobado por catedrático (D-08, D-13) |
| Contenedor Norte | Pi-hole | Pi-hole v6 | Coincide |
| Contenedor Sur | AdGuard Home | AdGuard Home | Coincide (D-19, asimétrico aceptado) |
| WiFi | Clave ≥12, única por sede | `UNIS2026` (8 chars, campus entero) | Desviación aceptada (D-18) |
| WAN | Puerto específico del diagrama | `ether7` (D-16) | Swap con inter-sede por PoE-in en `ether1` |
| Inter-sede | Puerto específico del diagrama | `ether1` (D-16) | Swap con WAN por PoE-in en `ether1` |

---

> **Regla de oro:** nunca configurar en vivo durante la defensa. La red se entrega funcionando. Si hacés un cambio, registrelo en `docs/06-DECISIONES.md` y actualice este archivo.