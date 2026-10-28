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

## R-07 · Puertos del hAP ax lite

El hAP-1A necesita 3 puertos usables (anillo entra, anillo sale, Pi). Verificar el modelo físico y el conteo
real **antes** de imprimir etiquetas y armar el rack.

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
