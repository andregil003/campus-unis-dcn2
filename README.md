# Campus UNIS Integrado — Proyecto Final DCN2

**Sede Norte / Grupo A** · Data Communication Networks 2 · Universidad del Istmo · Segundo Semestre 2026
Catedrático: Ing. Gustavo Adolfo Morales Xitamul
Valor: **40 puntos** + hasta **5 puntos** de instalación física · Defensa oral presencial en semana 15.

> Este repositorio **no contiene configuración**: contiene los estándares que el equipo se compromete a
> cumplir, el direccionamiento congelado, los resultados medibles, los riesgos conocidos y el plan de defensa.
> La configuración vive en el equipo físico (ver `docs/00-ESTANDARES.md` §E-09).

---

## Documentos

| Documento | Qué contiene |
|---|---|
| [`docs/00-ESTANDARES.md`](docs/00-ESTANDARES.md) | Los 11 estándares obligatorios del equipo (E-01…E-11) con criterio de aceptación |
| [`docs/01-TABLA-IPs.md`](docs/01-TABLA-IPs.md) | Tabla de direccionamiento completa, costos OSPF y plano de puertos |
| [`docs/02-RESULTADOS-ESPERADOS.md`](docs/02-RESULTADOS-ESPERADOS.md) | 10 pruebas con criterio numérico + ensayos obligatorios |
| [`docs/03-EXTRAS.md`](docs/03-EXTRAS.md) | Extras opcionales por tier (costo / riesgo / beneficio) |
| [`docs/04-RIESGOS.md`](docs/04-RIESGOS.md) | Trampas del enunciado, contradicciones y planes B |
| [`docs/05-PLAN-2-SEMANAS.md`](docs/05-PLAN-2-SEMANAS.md) | Cronograma semana 13-15 y matriz de responsables |
| [`docs/06-DECISIONES.md`](docs/06-DECISIONES.md) | Registro de decisiones abiertas y tomadas (ADR ligero) |

---

## Equipo (Grupo A — 5 integrantes)

| Rol | Bloque que domina | Suplente |
|---|---|---|
| Responsable de arquitectura y WAN/failover | Defaults OSPF, NAT, Reglas 1/4/5 | _(completar)_ |
| Responsable de OSPF y anillo | Adyacencias, costos, reconvergencia | _(completar)_ |
| Responsable de inter-sede y documentación | SXT, puente L2, diagrama + tabla IPs | _(completar)_ |
| Responsable de servicios | Pi-hole, nginx, Raspberry Pi | _(completar)_ |
| Responsable de acceso y físico | WiFi, DHCP, rackeo, etiquetado | _(completar)_ |

Regla del equipo: **todos los bloques tienen doble cobertura** (Regla de 2 puntos individuales + prohibido
responder "esa parte la hizo otro compañero").

---

## Estado

- [x] Lectura y análisis del enunciado y del diagrama de referencia
- [x] Estándares, direccionamiento y resultados esperados definidos
- [ ] Confirmar decisión de direccionamiento WiFi con el catedrático (ver `docs/06-DECISIONES.md` D-01)
- [ ] Inventario físico real (equipos, puertos, cables)
- [ ] Implementación (semana 13)
- [ ] Documentación de entrega (inicio semana 15)
