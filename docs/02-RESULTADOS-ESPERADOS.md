# Resultados esperados y protocolo de verificación

Cada prueba tiene criterio numérico y un responsable. Si una prueba no se puede medir, no cuenta.

## 1. Batería de pruebas (previa a cada ensayo)

| # | Prueba | Objetivo | Cómo se mide |
|---|---|---|---|
| 1 | Vecinos OSPF | 3 Full en GW-A, 3 Full en GW-B, 0 `Init`/`2-Way` | `/routing/ospf/neighbor print` |
| 2 | Ping inter-sede | 0 % pérdida desde Pi-A a `10.20.0.100` | `ping` |
| 3 | HTTP inter-sede | `curl` 200 en ambos sentidos | `curl -I` |
| 4 | DNS filtrado | dominio de prueba bloqueado (0.0.0.0 o NXDOMAIN) | `nslookup` / `dig` |
| 5 | Failover Norte | Internet en ≤ 10 s, traceroute con `10.99.0.x` | cronómetro + `traceroute` |
| 6 | Restauración Norte | vuelve al ISP en ≤ 10 s, tabla correcta | cronómetro + `/ip/route print` |
| 7 | Failover Sur | mismo criterio, desde la otra sede | coordinado con Grupo B |
| 8 | Anillo tolerante | al cortar un enlace del anillo, el campus sigue enrutando | ping continuo + vecinos |
| 9 | Auditoría NAT | `/ip/firewall/nat print` vacío en 2 hAP | vista |
| 10 | Preguntas cruzadas | los 5 responden cualquier bloque | ensayo interno |

## 2. Valores de referencia esperados

- **Convergencia OSPF intra-sede:** < 5 s tras cortar un enlace del anillo.
- **Failover WAN:** < 10 s (límite del curso: 30 s).
- **Latencia inter-sede:** 1–5 ms típico sobre SXT Lite5 en 5 GHz.
- **Pérdida durante failover:** aceptable ≤ 5 paquetes ICMP continuos.
- **Cero** reglas NAT en hAP, en cualquier momento.

## 3. Ensayos obligatorios antes de la defensa

1. Desconectar WAN de Sede Norte → medir → reconectar → medir.
2. Desconectar WAN de Sede Sur (coordinado) → medir → reconectar → medir.
3. Desconectar el cable del SXT → verificar que el anillo interno sigue enrutando
   (el requisito de conectividad inter-sede se pierde por diseño: es la prueba de resiliencia interna).

Cada ensayo se registra: hora, quién, resultado, capturas. Sin registro = no se hizo.

## 4. Criterios de evaluación del curso (referencia de puntaje)

| Criterio | Pts |
|---|---|
| OSPF con vecinos Full en ambas sedes | 8 |
| Conectividad inter-sede (ping + curl) | 6 |
| Filtrado DNS demostrable | 4 |
| Failover WAN < 30 s con traceroute | 10 |
| Restauración automática | 6 |
| Documentación | 4 |
| Preguntas individuales | 2 |
| **Subtotal** | **40** |
| Instalación física (rack 2 + etiquetas 2 + orden 1) | +5 |

Penalización explícita: NAT encontrado en un hAP ⇒ se pierden los 8 pts de OSPF.
