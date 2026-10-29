# 09 · Revisión de las configuraciones del compañero (Fletes) y correcciones

**Fecha:** 28/10/2026 · **Revisado:** `GW-A_RB5009_SedeNorte.rsc`, `GW-B_RB5009_SedeSur.rsc`,
`Configuracion_Sede_Norte_DCN2.docx` · **Corregido en:** `configs/rsc/` (11 archivos)

---

## 1. Veredicto

La base de Fletes es **correcta en lo estructural**: esqueleto de OSPF v7, loopback como `router-id`,
`type=ptp` en los /30, `passive` en WiFi, una sola regla `masquerade`, `check-gateway=arp` en el default
y una única área. No hay que rehacer nada: hay que **completar lo que falta** y **corregir cuatro
contradicciones** que sí rompen requisitos del enunciado.

Lo más grave no es un error de sintaxis: es que **el WiFi no existe** en ninguna plantilla de hAP y que
**el servidor no tiene puerto asignado**.

---

## 2. Hallazgos y estado

### Bloqueantes (rompen un requisito)

| ID | Hallazgo | Estado |
|---|---|---|
| **B1** | Orden del anillo contradictorio: el `.rsc` cierra en `hAP-5A` (`10.10.6.0/30`) y el `.docx` encadena `1-2-5-3-4` cerrando en `hAP-4A`, dejando un /30 sin usar | **RESUELTO** — D-09: orden secuencial `1→2→3→4→5→GW` |
| **B2** | `10.10.0.0/24` en GW-A **y** en el servidor a la vez; el servidor no tiene interfaz en el `.docx` | **RESUELTO** — D-10: la /24 vive solo en `hAP-1A ether3`; GW-A usa loopback `10.10.255.1` |
| **B3** | Las plantillas de hAP **no configuran WiFi** (sin `security`, sin `configuration`, sin `ssid`) ⇒ no hay red de usuarios | **RESUELTO** — bloque WiFi en los 9 hAP |
| **B4** | Las redes WiFi nunca se anuncian por OSPF ⇒ un cliente de hAP-3A no alcanza el servidor de la sede | **RESUELTO** — `interfaces=br-wifi passive` |

### Importantes (restan puntos o fallan en la demo)

| ID | Hallazgo | Estado |
|---|---|---|
| **I1** | Sin `dst-nat` de DNS: un cliente con DNS manual se salta el filtrado (extra perdido) | **RESUELTO** — 2 reglas dst-nat en cada GW |
| **I2** | Sin NTP: los logs y la defensa de "hora sincronizada" quedan sin respaldo | **RESUELTO** — `ntp client` en los 11 equipos |
| **I3** | `hello=1s dead=4s` también en el enlace wireless: reintentos por pérdida de paquetes | **RESUELTO** — 2s/8s en anillo, 5s/20s inter-sede (D-11) |
| **I4** | Imagen del contenedor en `:latest`: un cambio de upstream puede romper la demo el día de la defensa | **MITIGADO** — tag como variable `:local img` al inicio de la Fase C, con instrucción de pinear |
| **I5** | El `.docx` pone el Pi-hole en `10.10.6.0/30` (una subred de tránsito) | **RESUELTO** — contenedor en `10.10.254.53` (D-10) |
| **I6** | `interfaces=` **y** `networks=` a la vez en el mismo template | **RESUELTO** — solo `interfaces=` (determinista; la doc de MikroTik lo permite, pero es ambiguo si cambian las IPs) |
| **I7** | `gateway=192.168.1.1/24` con máscara en el DHCP network | **RESUELTO** — gateway sin máscara |
| **I8** | Sin firewall en los hAP (equipo abierto a quien se conecte al WiFi) | **RESUELTO** — input mínimo con `DROP` final |
| **I9** | `originate-default` sin verificar | **VERIFICADO** — `if-installed` es el parámetro correcto en v7 (solo en los GW; los hAP lo dejan en `never`) |

### Menores

- Costo inter-sede 1000 → **100** (D-11): mismo resultado, menos desviación del trabajo ya hecho.
- Falta `comment` en puertos, IPs y reglas ⇒ se pierden los puntos de documentación en el equipo.
- Falta `bridge` para el loopback: se usaba `lo` como interfaz virtual sin crearla.
- Los `SSID` no estaban definidos por nodo: ahora `UNIS-A1…A5` / `UNIS-B1…B4`.
- Canales 2.4 GHz sin planificar: ahora 1 / 6 / 11 rotando para evitar solapamiento.

---

## 3. Qué se corrigió en concreto

| Cambio | Antes (Fletes) | Ahora |
|---|---|---|
| Servidor de la sede | `10.10.0.100/24` en una red inexistente o duplicada | `hAP-1A ether3 = 10.10.0.1/24`, servidor `.100` |
| Red del contenedor | `10.10.0.0/24` compartida con el servidor | `10.10.254.0/24` en `veth1` (contenedor `.53`, router `.1`) |
| `bridge-lan` de GW-A | Bridge con `10.10.0.1/24` | **eliminado** (no hace falta) |
| DNS entregado por DHCP | `10.10.0.1` (duplicado) | `10.10.255.1` (loopback del GW → Pi-hole) |
| Anuncio del default | `originate-default=if-installed` (correcto, sin verificar) | igual + estática `distance=1` documentada como parte del failover |
| WiFi en hAP | inexistente | `security` + `configuration` + `bridge` + `DHCP` |
| Costo inter-sede | 1000 | 100 |
| Timers inter-sede | 1s/4s | 5s/20s |

---

## 4. Riesgos que quedan abiertos

| Riesgo | Impacto | Mitigación |
|---|---|---|
| `device-mode container=yes` exige pulsar **reset físico** | Alto (bloquea el DNS del campus) | Fase B el día 1; plan B en R-05 (DNS en el servidor) |
| `check-gateway=arp` no detecta "ISP caído con cable arriba" | Medio | Netwatch documentado al final de `GW-A.rsc` |
| Rotulado físico de los cables (la defensa lo pide) | Bajo | `comment` ya puesto en cada puerto; falta la etiqueta de papel |
| Nombres y roles del equipo | Medio | `05-RESPONSABLES.md` sigue con placeholders |

---

## 5. Pendiente de confirmar con el catedrático

1. **D-01** — WiFi en `10.10.11-15.0/24` (regla escrita) vs `192.168.1-5.0/24` (diagrama).
   Se implementó la primera; el cambio a la segunda es regenerar los hAP (2 min).
2. Gateway y bloque WAN reales (`100.64.1.1` / `100.64.2.1`).
3. Si exige Raspberry Pi **física** en Norte (R-13 → opción B2/B4).
