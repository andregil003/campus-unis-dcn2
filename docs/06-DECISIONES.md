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

---

## D-13 · Máquina concreta del servidor de Sede Norte (titular)

- **Estado:** CERRADA — 02/11/2026
- **Contexto:** D-08 aprobó "una laptop con Windows" pero sin identificar cuál. El enunciado (§4.4) pide una
  Raspberry Pi por sede; el grupo no tiene ningún SBC, así que la laptop ocupa su lugar en el diagrama, sin
  cambiar IP ni subred.
- **Decisión:** el servidor **titular** de Sede Norte es la laptop `DESKTOP-LKL1R8L`
  (Intel i5-5200U, 8 GB RAM, Windows 11 Enterprise 22621, NIC Ethernet Realtek PCIe GBE 1 Gbps).
  Despliegue nginx/Windows 1.30.6 en `C:\nginx`, IP `10.10.0.100/24` sobre la NIC Ethernet.
- **Consecuencia:** el puerto RJ45 es nativo (no hace falta adaptador USB-Ethernet ⇒ **W-8 descartado**).
  La máquina cumple S-01…S-06 por comportamiento; queda como *cold spare* descartada por ahora, porque
  esta misma laptop es el titular.
- **Verificación:** `servidor/windows/verificar.ps1`. Los ítems que dependen del cableado (S-01, S-02b, S-04,
  S-05) solo pueden pasar con el enlace `Ethernet → hAP-1A ether3` armado.
- **Decisor:** André.

---

## D-14 · Ruteo y ICMP del servidor Windows + DNS local sin WAN

- **Estado:** CERRADA — 02/11/2026 (verificado en el laboratorio con el anillo Norte convergido)
- **Contexto:** el anillo Norte quedó `Full` en los 6 saltos (GW-A ↔ hAP-1A ↔ hAP-2A ↔ hAP-3A ↔ hAP-4A ↔
  hAP-5A ↔ GW-A), las 6 direcciones del anillo respondían desde los routers, y sin embargo la laptop solo
  alcanzaba `10.10.0.1`. Dos causas independientes, ambas del lado Windows:
  1. Con WiFi y Ethernet conectados a la vez, Windows elegía la **ruta por defecto del WiFi** para todo
     destino `10.x` aunque la Ethernet tuviera mejor métrica (total 11 vs 55). La métrica de interfaz
     **no** fue suficiente.
  2. La **regla ICMP de entrada estaba deshabilitada**: el hAP-1A no podía hacer `ping` a `10.10.0.100`
     ni el GW-A podía responder (sin ruta de retorno percibida).
- **Decisión:**
  - `preparar-red.ps1` crea una ruta **persistente** `10.0.0.0/8 → 10.10.0.1` por la interfaz Ethernet.
    Cubre Norte (`10.10/16`), inter-sede (`10.99/30`) y Sur (`10.20/8`) con una sola entrada.
  - `preparar-red.ps1` crea la regla `Campus UNIS ICMPv4 echo` (tipo 8, perfiles Privado y Dominio).
  - `GW-A.rsc` agrega el registro DNS estático `prueba-dns.campus → 10.10.255.1` para que la prueba DNS
    de `verificar.ps1` pase **sin Internet y sin el Pi-hole**, ya que la WAN (`ether1` en ese momento,
    hoy `ether7` por D-16) todavía no tiene
    enlace y el paquete `container` no está instalado en GW-A.
- **Consecuencia:** la ruta `10.0.0.0/8` es una decisión de laboratorio: si la laptop se conecta a otra
  red que use `10.0.0.0/8`, hay que quitarla (`Remove-NetRoute -DestinationPrefix 10.0.0.0/8`). Queda
  documentada como W-9 en `08-SERVIDOR.md`.
- **Riesgo residual:** ninguna de las dos correcciones sustituye el cableado. S-05a/S-05b siguen
  requiriendo el enlace `GW-A ether1 ↔ SXT-A` (hoy **sin link**, `10.99.0.0/30` inactiva).
- **Decisor:** André.

---

## D-15 · El "Router ISP" del diagrama es un RB3011 propio

- **Estado:** CERRADA — 03/11/2026 (configurado y con Internet verificado en el laboratorio)
- **Contexto:** el diagrama v3 pone arriba del campus un "Router ISP (Catedrático)" con `e1: lab DHCP`,
  `e2: 100.64.1.1/30` y `e3: 100.64.2.1/30`. En el laboratorio ese papel lo cumple un **RB3011UiAS** del
  grupo, y su config de fábrica no tenía ninguna de las dos `/30`: solo una LAN `192.168.26.0/24` en
  `ether10` y un puerto asignado a otro grupo (`ether7`, `10.0.1.1/25`).
- **Decisión:**
  - `sfp1` (e1) = cliente DHCP hacia el laboratorio (`172.18.4.18/24`, gateway `172.18.4.1`).
  - `ether2` (e2) = `100.64.1.1/30` → `GW-A ether7` (`100.64.1.2/30`).
  - `ether3` (e3) = `100.64.2.1/30` → `GW-B ether7` (`100.64.2.2/30`).
  - Una sola regla NAT (`masquerade out-interface=sfp1`). **Sin** DHCP, DNS (`allow-remote-requests=no`),
    OSPF, firewall ni bridge: el equipo solo enruta y traduce.
  - Se elimina la LAN de fábrica (`192.168.26.1/24`, `dhcp_pool0`, `dhcp1` y su network).
  - `ether7` (`10.0.1.1/25`, "Puerto 7 - Rodrigo Quiroa") es de otro grupo y **no se toca**.
- **Consecuencia:** las configs de los GW **no cambian**: ya esperaban `100.64.1.1` / `100.64.2.1` como
  gateway. Hay doble NAT (cliente → GW → ISP → lab) y es intencional: el traceroute del failover mostrará
  dos saltos privados antes de salir al laboratorio.
- **Riesgo residual:** el uplink del laboratorio es único; si `sfp1` cae, el campus completo pierde
  Internet aunque las dos sedes estén sanas. El lease DHCP del lab (~20 min) puede cambiar de IP sin
  romper nada, porque el NAT es por interfaz y no por dirección.
- **Verificación realizada:** `ip address print` (172.18.4.18 + las dos `/30`), `ip route print`
  (`DAd` por 172.18.4.1, distance 1), una sola regla en `ip firewall nat print`,
  `tool ping 1.1.1.1` = 3/3 a ~2 ms.
- **Evidencia:** `configs/rsc/ROUTER-ISP.rsc` + `configs/backups/ROUTER-ISP-2026-11-03.{backup,rsc}`.
- **Decisor:** André.

---

## D-16 · La WAN sale por `ether7` y el inter-sede entra por `ether1` (PoE-in)

- **Estado:** TOMADA — 03/11/2026
- **Contexto:** el `RB5009UG+S+IN` tiene **PoE-in 802.3af/at en `ether1`** (el único puerto con esa
  capacidad; no tiene PoE-out). Las antenas SXT del enlace inter-sede vienen con su inyector PoE, así que
  el cable de la antena puede **alimentar el GW** y a la vez transportar el enlace inter-sede. Ese mismo
  cable estaba asignado a la WAN, lo que obligaba a mantener enchufada la fuente de 24 V y dejaba el PoE
  sin uso.
- **Decisión:**
  - `ether1` (2.5G) = **inter-sede** → SXT-A / SXT-B (`10.99.0.1/30` / `10.99.0.2/30`) y **PoE-in**
    alimentando el GW desde el inyector de la antena.
  - `ether7` (1G) = **WAN** → `ROUTER-ISP ether2` / `ether3` (`100.64.1.2/30` / `100.64.2.2/30`).
  - Las **direcciones IP no cambian**, solo el puerto físico. El lado del `ROUTER-ISP` **no se toca**
    (`ether2`/`ether3` siguen siendo las WAN de Norte y Sur).
  - Ajustes en los dos GW: `comment` de los puertos, miembros de las listas `WAN`/`LAN`, `ip address` y el
    `interface-template` de OSPF (el inter-sede pasa a `ether1`, mismo costo 100 y timers 5 s/20 s).
- **Por qué es seguro:** NAT, ruta por defecto, firewall, `originate-default`, costos y timers se mantienen
  idénticos; solo cambia el nombre de la interfaz. OSPF sigue viendo un `ptp` de costo 100 hacia la sede
  vecina y la WAN sigue en la lista `WAN` para el `masquerade`.
- **Consecuencia:** la WAN queda a **1 Gbps** (era 2.5G) y el inter-sede sube a 2.5G. Es irrelevante: el
  uplink del laboratorio y el enlace inalámbrico (~100 Mbps) son el cuello real.
- **Riesgo residual:** el RB5009 **no arranca con PoE pasivo de 24 V**; el inyector debe entregar
  802.3af/at (48 V). Si el inyector de la SXT es pasivo, se mantiene la fuente de 24 V en `ether1` y el
  diseño sigue funcionando igual (el puerto transporta datos sin importar quién alimenta).
- **Desviación del diagrama:** el diagrama v3 dibuja la antena en el puerto 7 y la WAN en el 1. Este cambio
  los invierte a propósito; si el catedrático pregunta, el argumento es el PoE-in del `ether1` (alimentar el
  GW con el cable de la antena y liberar una toma de corriente).
- **Nota sobre evidencia:** `docs/11-EVIDENCIA-OSPF.md` se conserva tal cual: la prueba se hizo con el
  mapa de puertos **anterior** (inter-sede en `ether7`). Al repetirla, el comando es el mismo pero sobre
  `ether1`.
- **Decisor:** André.


