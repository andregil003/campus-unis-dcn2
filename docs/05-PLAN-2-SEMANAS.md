# Plan de implementación (semanas 13-15) y matriz de responsables

## 1. Cronograma

| Día | Meta | Salida verificable | Responsable |
|---|---|---|---|
| 13.1 | Direccionamiento congelado + `device-mode` container + configuración base (identidad, NTP, IPs) | 6 equipos con IPs y vecinos ausentes aún | Arquitectura + Servicios |
| 13.2 | Anillo Norte con OSPF Full | 12 adyacencias internas (6 enlaces × 2) | OSPF |
| 13.3 | SXT en bridge + inter-sede | vecino GW-A ↔ GW-B en Full | Inter-sede |
| 13.4 | Default OSPF + failover/restauración medidos | prueba 5 y 6 del protocolo en verde | Arquitectura |
| 13.5 | Pi-hole + dst-nat 53 + bloqueo demostrable | dominio de prueba bloqueado | Servicios |
| 14.1 | nginx en Pi + curl cruzado | HTTP 200 desde Sede Sur | Servicios |
| 14.2 | WiFi, DHCP, SSID, auditoría de NAT | 5 SSID operativos, 0 reglas NAT en hAP | Acceso |
| 14.3 | Rack, etiquetas, organización de cables | foto del rack + etiquetas en ambos extremos | Acceso + todos |
| 14.4 | Documentación de entrega | diagrama + tabla IPs + doc 2 páginas | Inter-sede + Arquitectura |
| 14.5 | Ensayo general #1 + correcciones | registro de las 10 pruebas | Todos |
| 15 (previo) | Ensayo #2 y #3 + golden config congelado | config exportada y respaldada | Todos |
| Viernes 15 | Defensa | red funcionando, 5 personas respondiendo | Todos |

## 2. Matriz de responsables (doble cobertura obligatoria)

| Bloque | Titular | Suplente | Qué debe poder explicar cualquiera |
|---|---|---|---|
| Arquitectura y WAN/failover | _(A)_ | _(B)_ | por qué el default local gana, qué pasa al desenchufar |
| OSPF y anillo | _(B)_ | _(C)_ | costos, point-to-point, reconvergencia |
| Inter-sede y documentación | _(C)_ | _(A)_ | SXT en bridge, 10.99.0.0/30, diagrama |
| Servicios (DNS, nginx) | _(D)_ | _(E)_ | veth, dst-nat 53, upstream de Pi-hole |
| Acceso y físico | _(E)_ | _(D)_ | SSID, DHCP sin NAT, etiquetado |

> Completar con nombres reales del grupo antes del ensayo #1.

## 3. Reglas de trabajo

1. Un solo cambio a la vez, medido con el protocolo de `02-RESULTADOS-ESPERADOS.md`.
2. Export `.rsc` después de cada bloque terminado; nunca dejar un equipo "a medias" sin respaldo.
3. Nadie configura el equipo de otro sin avisar y sin dejar registro en `06-DECISIONES.md`.
4. La documentación se actualiza **el mismo día** del cambio, no después.
5. Prohibido tocar la red durante las 24 h previas a la defensa (solo verificaciones de lectura).

## 4. Entregables de la entrega documental (inicio semana 15)

- [ ] Diagrama de red con IPs y costos OSPF (PDF + fuente editable)
- [ ] Tabla de direccionamiento (`docs/01-TABLA-IPs.md` exportado a PDF)
- [ ] Documento de diseño, máximo 2 páginas (decisiones + problemas encontrados)
- [ ] Registro de ensayos con capturas y tiempos medidos
