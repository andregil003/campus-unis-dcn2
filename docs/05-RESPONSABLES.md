# Responsables y reglas de trabajo

Sin cronograma: el ritmo lo marca el grupo. Lo que sí es obligatorio es que **cada bloque tenga dos personas
capaces de explicarlo y repararlo**, porque la defensa incluye preguntas individuales y está vetado responder
"esa parte la hizo otro compañero".

## 1. Matriz de responsables (doble cobertura)

| Bloque | Titular | Suplente | Qué debe poder explicar cualquiera de los dos |
|---|---|---|---|
| Arquitectura, WAN y failover | _(A)_ | _(B)_ | por qué gana el default local, qué pasa al desenchufar el cable, cómo se restaura |
| OSPF y anillo | _(B)_ | _(C)_ | costos, por qué point-to-point, qué hace la reconvergencia |
| Inter-sede y documentación | _(C)_ | _(A)_ | SXT en bridge, por qué 10.99.0.0/30, cómo se lee el diagrama |
| Servicios (Pi-hole, nginx) | _(D)_ | _(E)_ | veth, dst-nat 53, upstream del DNS, dónde vive el root-dir |
| Acceso y físico | _(E)_ | _(D)_ | SSID, DHCP sin NAT, formato de etiquetas, orden del rack |

> Completar con nombres reales antes del primer ensayo general.

## 2. Reglas de trabajo

1. Un solo cambio a la vez, medido con el protocolo de `02-RESULTADOS-ESPERADOS.md`.
2. Export `.rsc` después de cada bloque terminado; nunca dejar un equipo a medias sin respaldo.
3. Nadie toca el equipo de otro sin avisar y sin registrar el cambio en `06-DECISIONES.md`.
4. La documentación se actualiza el mismo día del cambio, no después.
5. Prohibido reconfigurar en vivo el día de la defensa: la red se entrega funcionando.
6. Coordinación formal con Sede Sur: cualquier cambio que afecte el enlace inter-sede se acuerda por escrito
   (la nota es compartida).
