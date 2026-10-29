# Riesgos, trampas del enunciado y planes B

## R-01 · Contradicción de direccionamiento WiFi (crítica)

El texto del proyecto dice: *"Sede Norte opera subredes internas en el bloque 10.10.0.0/8"*.
El diagrama de referencia pone el WiFi en `192.168.1.0/24` … `192.168.5.0/24`, que queda **fuera** de ese bloque.

- **Riesgo:** un evaluador puede objetar el direccionamiento por no cumplir la regla escrita.
- **Propuesta:** WiFi en `10.10.11.0/24` … `10.10.15.0/24` (cumple la regla y no choca con las /30 ni con `10.10.0.0/24`).
- **Acción:** confirmar con el catedrático y anotar la decisión en `06-DECISIONES.md` (D-01).

## R-02 · Colisión de la red del servidor

El diagrama asigna `10.10.0.1/24` al GW-A **y** `10.10.0.100/24` a la Pi colgada del hAP-1A: misma /24 en dos
equipos distintos ⇒ conflicto de enrutamiento.

- **Solución adoptada:** `10.10.0.0/24` vive **solo** en el enlace `hAP-1A ether3 ↔ Pi` (hAP-1A = `.1`).
  GW-A no tiene interfaz en esa red; sus IPs propias son el loopback `10.10.255.1` y la veth `10.10.254.1`.

## R-03 · El SXT no lleva IP

Va en modo **bridge L2 transparente**; las IPs `10.99.0.1/.2` se configuran en los RB5009.
El enlace inalámbrico debe ser **ap-bridge ↔ station-bridge** (o WDS): en modo `station` normal el L2 no es
transparente para múltiples MAC y **OSPF nunca levanta**.

## R-04 · Container en RB5009: requisito físico

Habilitar containers requiere `device-mode` (`container=yes`) y eso se confirma **presionando el botón reset**
en una ventana de tiempo. Se hace en laboratorio, nunca el día de la defensa.
Además: paquete `container`, imagen arm64, root-dir persistente en USB/disco.
Es el punto de mayor riesgo técnico ⇒ **primer día de la semana 13**.

## R-05 · Plan B de DNS filtrado

Si el container no funciona a tiempo:

1. **B:** Pi-hole/AdGuard en la Raspberry Pi (contenedor dentro del Pi). Funciona, pero no cumple literalmente
   "container dentro del RB5009" ⇒ riesgo de criterio.
2. **C:** bloqueo por `address-list`/DNS static en RouterOS. Cumple el efecto demostrable, no el requisito
   de herramienta. Último recurso, con autorización del catedrático.

Decisión temprana, no en la víspera.

## R-06 · `check-gateway=ping` puede ser lento

RouterOS puede tardar ~20-30 s en declarar caído un gateway: demasiado cerca del límite de 30 s.

- La prueba oficial es **desconectar el cable** ⇒ link down ⇒ detección instantánea. Sin problema.
- Aun así: Netwatch de 1 s como respaldo para el caso "el ISP responde a ping pero no enruta".

## R-07 · Puertos del hAP ax lite — RESUELTO

Verificado: `L41G-2axD` tiene **4 puertos GbE**. El hAP-1A necesita 3 (anillo entra, anillo sale, Pi) y queda
1 libre para consola o pruebas. Sin riesgo. Plano completo en `07-HARDWARE.md`.

## R-08 · Sintaxis RouterOS v7

Todos los equipos son ARM64 (v7): OSPF vive en `/routing/ospf/instance|area|interface-template`, no en la
sintaxis v6 de los tutoriales antiguos. Los nombres exactos de parámetros (`distribute-default`,
`metric-default`, etc.) se confirman con `?` en el propio equipo, no de memoria.

## R-09 · Riesgo humano

2 puntos son preguntas individuales y "esa parte la hizo otro compañero" está vetado explícitamente.
⇒ Matriz de responsables con doble cobertura en cada bloque y simulacro de preguntas cruzadas.

## R-10 · Riesgo de calendario

Semanas 13-14 implementación; inicio de semana 15 entrega de documentación; viernes defensa.
Sin entregas tardías: sin diagrama ni tabla de IPs se pierden 4 puntos antes de encender un equipo.
⇒ La documentación avanza en paralelo a la implementación, no al final.

## R-11 · Dependencia con Sede Sur

La nota es compartida: si la conectividad inter-sede falla, ambos grupos son penalizados.
⇒ Coordinación formal con Grupo B: direccionamiento acordado por escrito y una prueba conjunta antes de la defensa.

## R-12 · Confianza en el ISP del catedrático

La WAN usa rango CGNAT `100.64.0.0/10` (sin IP pública). No hay port-forwarding posible: cualquier servicio
debe ser alcanzable **por dentro** del campus (que es justo lo que evalúa el proyecto).

## R-13 · Servidor de la sede — RESUELTO

El Pico RP2040 **no** puede ser servidor (microcontrolador sin SO). La sede resuelve el servicio con una
**laptop Windows + nginx**, aprobada por el catedrático el 27/10/2026. Sur usa su **Raspberry Pi 4 (2 GB)**.

- Artefactos listos en `servidor/` (config Windows, config Linux, página, scripts de verificación).
- Riesgos propios de Windows (firewall, suspensión, doble NIC, arranque como servicio) mitigados en
  `08-SERVIDOR.md` §2.3.
- Respaldo: cualquier computadora con nginx puede ocupar el lugar en ≤ 5 min (`08-SERVIDOR.md` §6).
- Riesgo residual: **bajo**. Solo queda probar la máquina de respaldo antes de la defensa.

## R-14 · Sin repuestos de hAP

9 hAP ax lite = exactamente 5 (Norte) + 4 (Sur). **No hay margen.** Si uno falla el día de la defensa no hay
sustituto: mismo modelo, mismo RouterOS, misma versión.

- Mitigación: identificar el hAP con más probabilidad de falla (el que más se manipula), dejarlo con config
  exportada al día y tener la fuente USB-C de repuesto (son estándar y baratas).
- Mitigación 2: acordar con Sede Sur que, en emergencia, su nodo menos crítico se reasigna.

## R-15 · WiFi solo 2.4 GHz

Los hAP ax lite no tienen 5 GHz. Con 5 nodos encendidos en un laboratorio lleno de redes 2.4 GHz hay riesgo
real de interferencia y de que las pruebas de latencia se vean sucias.

- Mitigación: plan de canales fijo 1 / 6 / 11 alternado entre nodos, ancho de canal 20 MHz (no 40),
  y potencia de transmisión moderada para reducir solapamiento.
- No afecta al enlace inter-sede: el SXT Lite5 trabaja en 5 GHz.

## R-16 · Energía: no hay PoE en la cadena

El RB5009UG+S+IN no tiene PoE-out y el hAP ax lite no acepta PoE (se alimenta por USB-C 5 V). Cada equipo
necesita su propia fuente.

- Necesario para el rack: **regleta con ≥ 6 tomas**, 5 fuentes USB-C (vienen en la caja), fuente de 24 V del
  RB5009, fuente de la Pi y velcro para agrupar el cableado de poder.
- Si falta una toma, es un punto de falla el día de la defensa: probar el rack completo en el laboratorio
  antes, no en casa.


## R-17 - Los dos RB5009 estan en versiones distintas de RouterOS

GW-A reporta **7.18.2** y GW-B **7.24.2** (verificado en el export del 28/10/2026). No rompe nada hoy,
pero introduce dos problemas concretos:

- El paquete `container-<version>-arm64.npk` debe coincidir **exactamente** con la version del equipo:
  con versiones distintas hacen falta dos archivos y es un error facil de cometer en plena defensa.
- Una diferencia de 6 versiones menores entre los dos GW es una variable que nadie quiere explicando un
  fallo en vivo (comportamiento de OSPF, del firewall o del wifi puede variar).

- **Accion:** actualizar GW-A a 7.24.2 y verificar la version de los 9 hAP y de los 2 SXT antes de armar el
  rack. Registrar la version final de los 13 equipos en `07-HARDWARE.md`.
