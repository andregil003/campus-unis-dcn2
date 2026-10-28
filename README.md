# Campus UNIS Integrado — Proyecto Final DCN2

**Sede Norte / Grupo A** · Data Communication Networks 2 · Universidad del Istmo · Segundo Semestre 2026
Catedrático: Ing. Gustavo Adolfo Morales Xitamul
Valor: **40 puntos** + hasta **5 puntos** de instalación física · Defensa oral presencial en semana 15.

> Este repositorio **no contiene configuración**: contiene los estándares que el equipo se compromete a
> cumplir, el direccionamiento congelado, los resultados medibles, los riesgos conocidos y el inventario real.
> La configuración vive en el equipo físico (ver `docs/00-ESTANDARES.md` §E-09).

---

## Documentos

| Documento | Qué contiene |
|---|---|
| [`docs/00-ESTANDARES.md`](docs/00-ESTANDARES.md) | Los 11 estándares obligatorios del equipo (E-01…E-11) con criterio de aceptación |
| [`docs/01-TABLA-IPs.md`](docs/01-TABLA-IPs.md) | Tabla de direccionamiento completa, costos OSPF y vecinos esperados |
| [`docs/02-RESULTADOS-ESPERADOS.md`](docs/02-RESULTADOS-ESPERADOS.md) | 10 pruebas con criterio numérico + ensayos obligatorios |
| [`docs/03-EXTRAS.md`](docs/03-EXTRAS.md) | Extras opcionales por tier (costo / riesgo / beneficio) |
| [`docs/04-RIESGOS.md`](docs/04-RIESGOS.md) | Trampas del enunciado, contradicciones y planes B |
| [`docs/05-RESPONSABLES.md`](docs/05-RESPONSABLES.md) | Matriz de doble cobertura y reglas de trabajo |
| [`docs/06-DECISIONES.md`](docs/06-DECISIONES.md) | Registro de decisiones abiertas y tomadas (ADR ligero) |
| [docs/07-HARDWARE.md](docs/07-HARDWARE.md) | Inventario real, capacidades verificadas y consecuencias de diseño |
| [docs/08-SERVIDOR.md](docs/08-SERVIDOR.md) | Servidor de sede: estándar neutral S-01…S-06, montaje Windows y Pi 4, pruebas cruzadas |
| [`fuentes/`](fuentes/) | Enunciado y diagrama de referencia originales (PDF) |

---

## Hardware confirmado

| Equipo | Cantidad | Nota |
|---|---|---|
| MikroTik RB5009**UG+S+IN** | 2 | 1× 2.5G + 7× 1G + USB 3.0 · **sin PoE-out** |
| MikroTik hAP ax lite (`L41G-2axD`) | 9 | 4 puertos GbE · WiFi **solo 2.4 GHz** · USB-C 5 V |
| Laptop Windows (servidor Norte) | 1 | nginx/Windows + IP fija `10.10.0.100` — ver `docs/08-SERVIDOR.md` |
| Raspberry Pi 4 de 2 GB (servidor Sur) | 1 | nginx sobre Raspberry Pi OS Lite, `10.20.0.100` |
| Raspberry Pi **Pico** (RP2040) | 1 | microcontrolador: **no es servidor** — queda como extra opcional |

---

## Equipo (Grupo A — 5 integrantes)

Matriz de responsables con doble cobertura en [`docs/05-RESPONSABLES.md`](docs/05-RESPONSABLES.md).

---

## Estado

- [x] Lectura y análisis del enunciado y del diagrama de referencia
- [x] Estándares, direccionamiento y resultados esperados definidos
- [x] Inventario de hardware verificado contra ficha técnica
- [x] Servidor resuelto: laptop Windows + nginx en Norte, Pi 4 en Sur (D-08, falta validar con el catedrático)
- [ ] Confirmar direccionamiento WiFi con el catedrático (D-01)
- [ ] Implementación
- [ ] Documentación de entrega
