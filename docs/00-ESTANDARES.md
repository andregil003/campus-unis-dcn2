# Estándares obligatorios del equipo — Sede Norte (Grupo A)

Un estándar es un criterio **verificable**, no un deseo. Si un estándar no se puede comprobar con un comando
o con la vista, no está bien escrito. Todos los equipos de la sede deben cumplir los 11 bloques siguientes
antes de considerarse "listos para ensayo".

---

## E-01 · Direccionamiento

| Bloque | Uso | Regla |
|---|---|---|
| `100.64.1.2/30` | WAN GW-A (ISP) | asignada por el catedrático, no se negocia |
| `10.99.0.0/30` | Enlace inter-sede | `.1` GW-A, `.2` GW-B · **las IPs van en los RB5009, no en los SXT** |
| `10.10.1.0/30` … `10.10.6.0/30` | Los 6 enlaces del anillo Norte | una /30 por enlace, sin bridges |
| `10.10.0.0/24` | Solo enlace hAP-1A `ether3` ↔ Raspberry Pi | hAP-1A `.1`, Pi `.100` |
| `192.168.1-5.0/24` | WiFi de hAP-1A…hAP-5A (GW `192.168.N.1`) | ver D-01 en `06-DECISIONES.md` |
| `10.10.254.0/24` | veth del container Pi-hole | Pi-hole `.53`, GW-A veth `.1` |
| `10.10.255.1/32` | Loopback GW-A = router-id = IP de DNS del DHCP | — |

**Criterio de aceptación:** cero subredes solapadas, cero /30 desperdiciada, cero IP fuera del bloque
asignado (excepción declarada: las `/24` de WiFi siguen el diagrama v3 — D-01).

---

## E-02 · Identidad de los equipos

`system identity` = nombre del equipo en el diagrama = etiqueta física (`GW-A`, `hAP-1A` … `hAP-5A`).
Sin excepciones: si el ing. pide "mostrame hAP-3A", el prompt debe decir `hAP-3A`.

---

## E-03 · OSPF (RouterOS v7 en todos los equipos, son ARM64)

- Una sola área: **area 0**.
- `router-id` manual = loopback (`10.10.255.x`). Nunca automático.
- Enlaces /30 declarados como **point-to-point**.
- WiFi, loopbacks y la LAN del servidor: **passive interface** (se anuncian, no forman vecinos).
- Costos deterministas: **1 Gbps = 10**, **inter-sede = 100**.
  El peor camino posible dentro de un anillo (4 saltos = 40, caso de enlace caído) sigue siendo menor que 100,
  así que 100 ya garantiza preferencia local sin ECMP. Los SXT son L2: no tienen costo propio.
- Prohibido resolver el tráfico interno con rutas estáticas (Regla 6).

**Criterio de aceptación:** GW-A ve **3 vecinos en Full** (hAP-1A, hAP-5A, GW-B); cada hAP ve 2;
el campus completo suma **12 adyacencias** (6 del anillo Norte + 5 del anillo Sur + 1 inter-sede).
Verificación: `/routing/ospf/neighbor print`.

---

## E-04 · NAT y salida a Internet (Reglas 1 y 8)

- Único NAT del campus: `masquerade` en la interfaz WAN de cada RB5009.
- **Los hAP no llevan ninguna regla NAT.** Si aparecen, se pierden los 8 puntos de OSPF aunque todo funcione.
- Salida preferida siempre local: el default propio pesa menos que el de la sede vecina. **Sin ECMP**
  (ECMP repartiría flujos por el enlace inter-sede y violaría la Regla 1).
- Auditoría previa a cada ensayo: `/ip/firewall/nat print` en al menos 2 hAP, esperando tabla vacía.

---

## E-05 · Failover y restauración

- Cada GW anuncia default por OSPF (`originate-default=if-installed`) y tiene una estática `distance=1`
  `check-gateway=arp` hacia el ISP. La estática siempre gana sobre OSPF (110).
- El default de la sede vecina llega con la métrica del enlace inter-sede sumada (10 + 100 = **110**),
  por lo que **nunca** se usa mientras la WAN propia está viva.
- Cable WAN desconectado ⇒ link down ⇒ se retira la ruta conectada ⇒ se retira el default propio ⇒
  entra el default remoto.
- **Objetivo interno ≤ 10 s** (el límite del curso son 30 s).
- Restauración: al volver el link, la ruta propia se reinstala con mejor métrica y el tráfico regresa solo.
- Verificación: `traceroute` posterior debe mostrar el salto `10.99.0.x`.

---

## E-06 · DNS filtrado (Pi-hole en container dentro del RB5009-A)

- Container con IP fija `10.10.254.53`, root-dir en USB/disco (persistente).
- DHCP entrega DNS = **`10.10.255.1`** (GW-A).
- GW-A hace `dst-nat` UDP y TCP puerto 53 → Pi-hole, para que ningún cliente lo esquive con 8.8.8.8.
- Upstream de Pi-hole **distinto** de GW-A (1.1.1.1 / 9.9.9.9) para evitar loop de resolución.
- **Criterio de aceptación:** el dominio de prueba acordado con el catedrático queda bloqueado tanto desde
  WiFi como desde un cliente con DNS configurado a mano.

---

## E-07 · WiFi y DHCP

- SSID `UNIS-A1` … `UNIS-A5` (Sur: `UNIS-B1` … `UNIS-B4`), WPA2/WPA3 PSK (≥12 caracteres), clave única por sede.
- Un /24 por nodo, DHCP en el propio hAP, gateway = el hAP, **sin NAT**, DNS = GW-A.
- IPv6 deshabilitado (o habilitado de forma consistente en todo el campus; nunca a medias).
- hAP ax lite usa `/interface/wifi` (paquete *wifi*), **no** `/interface/wireless`.

---

## E-08 · Servidores (estándar neutral de plataforma)

El servidor de cada sede puede ser distinto: **Norte = laptop Windows + nginx**, **Sur = Raspberry Pi 4 + nginx**.
Por eso el estándar se define por comportamiento observable (detalle en `08-SERVIDOR.md`):

| # | Requisito | Criterio |
|---|---|---|
| S-01 | IP fija `10.10.0.100/24` (Norte) / `10.20.0.100/24` (Sur) | responde `ping` |
| S-02 | nginx en puerto 80 | `curl -I` → `200` |
| S-03 | Página identificable de la sede | contenido correcto |
| S-04 | `/health` → `200` con cuerpo `ok` | verificable |
| S-05 | Alcanzable desde la otra sede | `curl` cruzado en ambos sentidos |
| S-06 | Arranque automático tras corte de energía | servicio habilitado, sin login manual |

- Prohibido: servidor que dependa de que alguien inicie sesión o abra una ventana.
- NTP activo en ambas sedes (logs con fecha = evidencia en la defensa).
- **Criterio global:** `curl` cruzado devuelve 200 en menos de 1 s, en los dos sentidos.

---

## E-09 · Gestión de configuración

- Export por equipo: `/export terse show-sensitive` versionado fuera del router + `backup` binario en USB.
- Un "golden config" congelado al final de la semana 14. Después de congelar: solo cambios registrados.
- NTP habilitado en los 11 equipos del campus.
- Prohibido configurar en vivo durante la defensa. La red se entrega funcionando.

---

## E-10 · Instalación física (+5 puntos)

| Ítem | Pts | Estándar |
|---|---|---|
| Rackeo | 2 | todos los routers en rack o estructura equivalente (soportes 3D de Printables) |
| Etiquetado | 2 | `ORIGEN / PUERTO → DESTINO / PUERTO` en **ambos** extremos del cable |
| Organización | 1 | velcro/bridas, sin cables colgando ni cruces innecesarios |

**Criterio de oro:** el catedrático sigue cualquier cable a ojo, sin tocarlo.

---

## E-11 · Documentación

Entregable antes de la defensa (inicio de semana 15, sin tolerancia):

1. Diagrama de red completo con IPs **y costos OSPF**.
2. Tabla de direccionamiento completa (este repo, `01-TABLA-IPs.md`).
3. Documento de **máximo 2 páginas**: decisiones de diseño + problemas encontrados.

Extras nuestros (no exigidos, suman impresión profesional): tabla de cables, matriz de responsables,
runbook de defensa.
