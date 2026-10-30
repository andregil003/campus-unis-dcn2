# Registro de decisiones (ADR ligero)

Formato: una decisión por entrada, con estado, contexto y consecuencia.

---

## D-01 · Direccionamiento de las redes WiFi

- **Estado:** REVISADA el 30/10/2026 — se adopta la **opción B**, alineada al diagrama de referencia v3
- **Contexto:** el diagrama del catedrático (`fuentes/diagrama-referencia-campus-unis-v3.pdf`) dibuja el WiFi
  en `192.168.1-5.0/24` (Norte) y `192.168.11-14.0/24` (Sur), con el gateway en `.1`. El texto del enunciado
  pide las subredes internas en `10.10.0.0/8` / `10.20.0.0/8` (ver R-01).
- **Cambio de criterio:** la decisión del 28/10/2026 implementaba `10.10.11-15.0/24`; el equipo lo observó
  en la revisión del 30/10/2026 y se alinea con el diagrama.
- **Decisión:** WiFi **exactamente como el diagrama v3**:
  - Norte: hAP-1A `192.168.1.1/24`, hAP-2A `192.168.2.1/24`, hAP-3A `192.168.3.1/24`,
    hAP-4A `192.168.4.1/24`, hAP-5A `192.168.5.1/24`.
  - Sur: hAP-1B `192.168.11.1/24`, hAP-2B `192.168.12.1/24`, hAP-3B `192.168.13.1/24`,
    hAP-4B `192.168.14.1/24`.
  - Pool por nodo `192.168.N.10 – 192.168.N.250`, gateway `192.168.N.1`, DNS = loopback del GW de la sede.
- **Por qué es seguro:** las redes WiFi son `passive` en OSPF: no forman vecinos ni tocan el failover,
  el DNS ni el NAT. El cambio son los 9 bloques 3/5 (WiFi y DHCP) y nada más.
- **Lo que NO cambia:** anillo `10.10.1-6.0/30` y `10.20.1-5.0/30`, inter-sede `10.99.0.0/30`, LAN del
  servidor `10.10.0.0/24` / `10.20.0.0/24`, contenedores `10.10.254.0/24` / `10.20.254.0/24` y loopbacks.
  La regla del bloque `/8` se sigue cumpliendo en todo lo que enruta el campus.
- **Riesgo abierto:** si el DHCP del laboratorio (puerto `e1` del router del catedrático) usa `192.168.1-14`,
  habría solapamiento. Confirmarlo antes del ensayo; si choca, se vuelve a la opción A regenerando los hAP
  en 2 minutos (`configs/generar-haps.py`).
- **Decisor:** André (30/10/2026), a partir del reporte del equipo.

---

## D-02 · Red del servidor separada del gateway

- **Estado:** TOMADA
- **Contexto:** el diagrama pone `10.10.0.1/24` en GW-A y `10.10.0.100/24` en la Pi, ambos en la misma /24
  pero en equipos distintos (R-02).
- **Decisión:** `10.10.0.0/24` se usa únicamente en el enlace `hAP-1A ether3 ↔ Raspberry Pi`. GW-A no tiene
  interfaz en esa red; usa loopback `10.10.255.1` y veth `10.10.254.1`.
- **Consecuencia:** la IP exigida `10.10.0.100` sigue siendo válida y se alcanza por OSPF.

---

## D-03 · Failover por default OSPF con asimetría de costo

- **Estado:** TOMADA (pendiente de validación en laboratorio)
- **Contexto:** la Regla 1 prohíbe que el tráfico cruce el enlace inter-sede con la WAN activa, y la Regla 6
  prohíbe el ruteo estático como solución principal.
- **Decisión:** cada GW tiene una estática `distance=1 check-gateway=arp` hacia el ISP y la anuncia por OSPF
  con `originate-default=if-installed`; el inter-sede tiene costo 100, de modo que el default remoto llega
  con 110 y solo se usa cuando el propio desaparece.
- **Consecuencia:** cero ECMP, cumplimiento de Regla 1 por diseño, y failover sin intervención manual.

---

## D-04 · Inter-sede como puente L2 con `ap-bridge` / `station-bridge`

- **Estado:** TOMADA
- **Contexto:** los SXT deben ser transparentes para OSPF (R-03).
- **Decisión:** SXT-A en `ap-bridge`, SXT-B en `station-bridge` (o WDS dinámico). IPs de `10.99.0.0/30` en los
  RB5009, no en las antenas.
- **Consecuencia:** un solo dominio de broadcast en el enlace; OSPF lo trata como punto a punto con costo 100.

---

## D-05 · Prioridad del container Pi-hole

- **Estado:** TOMADA
- **Contexto:** el container tiene un requisito físico (`device-mode`) y es el mayor riesgo técnico (R-04).
- **Decisión:** se intenta el día 1 de la semana 13, con plan B documentado en R-05.
- **Consecuencia:** si falla el día 1, hay una semana para cambiar de estrategia sin sacrificar la nota de DNS.

---

## D-06 · Alcance de los extras

- **Estado:** TOMADA — Tier 1 acotado (PUCK, 28/10/2026)
- **Contexto:** hay margen para extras, pero cada uno consume tiempo de la fase crítica (armado + ensayo).
- **Decisión — se hace:**
  1. Etiquetas de cableado en cada puerto (`comment`) — ya incluidas en las 11 configs.
  2. `dst-nat` DNS anti-bypass hacia Pi-hole/AdGuard — ya incluidas en los GW.
  3. Netwatch opcional documentado para detectar "ISP caído con cable arriba" (R-07).
  4. Página `/health` del servidor (ya implementada en `servidor/`).
- **No se hace salvo que sobre tiempo:** BFD (los timers 2s/8s dan ~8 s de convergencia), ntfy,
  TLS en el servidor, dashboard grafana.
- **Consecuencia:** los extras no bloquean la ruta crítica; se documentan como puntos de la defensa oral.

---

## D-09 · Orden del anillo: secuencial 1→2→3→4→5→GW

- **Estado:** TOMADA (PUCK, 28/10/2026)
- **Contexto:** el `.rsc` de GW-A asume `ether3 → hAP-5A` con `10.10.6.0/30`, y el `.docx` de Fletes
  encadena `1-2-5-3-4` cerrando en hAP-4A, dejando `10.10.6.0/30` sin usar (bloqueante B1).
- **Decisión:** orden **secuencial**: `GW-A ↔ hAP-1A ↔ hAP-2A ↔ hAP-3A ↔ hAP-4A ↔ hAP-5A ↔ GW-A`.
  La subred `10.10.N.0/30` es siempre el enlace entre el nodo `N-1` y el nodo `N`, y `10.10.6.0/30`
  cierra el anillo contra GW-A.
- **Consecuencia:** los 6 bloques /30 quedan usados, las etiquetas son predecibles y solo hay que corregir
  el encadenamiento del `.docx`; el `.rsc` de GW-A ya era correcto y no cambia.

---

## D-10 · Esquema de servidor y contenedor (resuelve R-02)

- **Estado:** TOMADA (PUCK, 28/10/2026)
- **Contexto:** `10.10.0.0/24` aparecía a la vez en GW-A y en el servidor, y el servidor no tenía puerto
  asignado en el `.docx` (bloqueante B2).
- **Decisión:**
  - `10.10.0.0/24` vive **solo** en `hAP-1A ether3` (`10.10.0.1/24`), con el servidor en `10.10.0.100/24`.
  - GW-A **no** tiene interfaz en esa red: no hace falta, llega por OSPF.
  - Contenedor en `10.10.254.0/24` sobre un `veth` (contenedor `.53`, router `.1`), **sin bridge**.
  - El DNS del campus se entrega como `10.10.255.1` (loopback del GW), que reenvía al Pi-hole.
- **Consecuencia:** desaparece el `bridge-lan` de GW-A y su IP `.1/24` duplicada; la IP exigida
  `10.10.0.100` sigue válida y ahora tiene un puerto físico real.

---

## D-11 · Costo inter-sede 100 y timers OSPF

- **Estado:** TOMADA (PUCK, 28/10/2026)
- **Contexto:** el diseño original usaba costo 1000 (documentado); Fletes usó 100. Con 100 el resultado es
  el mismo y hay menos desviación respecto del trabajo ya hecho.
- **Decisión:** inter-sede = **100**; anillo = 10. Timers: anillo `hello=2s dead=8s` (Ethernet),
  inter-sede `hello=5s dead=20s` (wireless, más tolerante).
- **Consecuencia:** default local 10 vs remoto 110 ⇒ sin ECMP; el peor camino intra-anillo (40) sigue siendo
  menor que 100, así que un enlace caído nunca hace que el tráfico salga por la otra sede.
  Convergencia del anillo ~8 s, dentro del objetivo interno ≤10 s y del límite de 30 s del curso.

---

## D-12 · Claves en texto plano y repositorio público

- **Estado:** TOMADA (André, 29/10/2026)
- **Contexto:** los `.rsc` se pegan tal cual en la terminal, así que la clave de `admin` y el PSK del WiFi
  viajan dentro de los archivos. André pidió además que el repo sea **público** para poder mostrar el
  trabajo (defensa y portafolio).
- **Decisión:** clave de `admin` única y **igual en los 13 equipos**: `ValoValoValo2026`, escrita en los
  `.rsc` que se pegan. Repositorio `campus-unis-dcn2` **público**.
- **Consecuencia:** cualquiera que abra el repo ve la topología completa, la clave del `admin` y el PSK del
  WiFi. Se acepta porque es un entorno de **laboratorio académico** y las claves se pueden rotar sin costo.
- **Riesgo residual:** una vez publicada, la clave queda en el **historial de git** de forma permanente.
  Ocultarla después exige reescribir la historia (`git filter-repo`) y rotar la clave en los 13 equipos.
  Si el diseño se reutilizara fuera del laboratorio, mover las claves a un archivo fuera del repo.
- **Decisor:** André.

---

## Plantilla

```
## D-XX · Título
- Estado: ABIERTA | TOMADA | DESCARTADA
- Contexto: ...
- Decisión: ...
- Consecuencia: ...
- Decisor: ...
```

---

## D-07 · Hardware real difiere del enunciado

- **Estado:** TOMADA (documentada para la defensa)
- **Contexto:** el enunciado asigna un RB5009UPr+S+; el equipo tiene RB5009UG+S+IN. La diferencia es el
  PoE-out (el UPr lo tiene, el UG no). Los hAP ax lite se alimentan por USB-C 5 V y **no aceptan PoE**, así que
  la diferencia no afecta la arquitectura.
- **Decisión:** se trabaja con RB5009UG+S+IN, documentando el modelo real y la razón por la que el PoE-out
  es irrelevante en este diseño.
- **Consecuencia:** el estándar físico exige regleta con tomas suficientes y una fuente por equipo (R-16).

---

## D-08 · Servidor de la sede: laptop Windows (Norte) + Raspberry Pi 4 (Sur)

- **Estado:** CERRADA — aprobada por el catedrático (27/10/2026)
- **Contexto:** el enunciado exige una Raspberry Pi con nginx. En Norte no hay SBC: solo un Pico (RP2040) que
  no puede ejecutar nginx. Sur sí dispone de una **Raspberry Pi 4 de 2 GB**.
- **Decisión:** Sede Norte usa **laptop con Windows + nginx/Windows**; Sede Sur usa su **Pi 4 + nginx**.
  El requisito se cumple en comportamiento (IP fija, HTTP 200, `/health`, alcanzable desde la otra sede,
  arranque automático), no en plataforma.
- **Consecuencia:** el estándar E-08 se reescribió neutral a plataforma (S-01…S-06) y se documentaron las
  trampas de Windows en `08-SERVIDOR.md` (§2.3: firewall, suspensión, doble NIC, arranque como servicio).
- **Riesgo residual:** si el catedrático exige Raspberry Pi física, se activa R-13 opción B2 (Pi prestada) o B4.
- **Decisor:** André (y confirmación del catedrático).
