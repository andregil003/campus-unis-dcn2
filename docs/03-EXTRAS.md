# Extras opcionales (todo gratis y local)

Regla del proyecto: primero se aseguran los 40 puntos, después se decora. Un extra que puede tumbar la red
el día de la defensa **no se hace**.

## Tier 1 — baratos, alto retorno (recomendado)

| Extra | Beneficio | Riesgo | Costo |
|---|---|---|---|
| BFD en OSPF | detección sub-segundo, demuestra dominio avanzado | bajo | $0 |
| Netwatch 1 s + alerta ntfy | reacciona al caso "ISP vivo pero no enruta" | bajo | $0 (ntfy.sh) |
| Página nginx con `/health` y TLS autofirmado | se ve profesional en la demo | bajo | $0 |
| Dashboard en vivo de vecinos/rutas | la defensa se vuelve demostración | bajo | $0 |
| Etiquetas impresas + plano de rack pegado | asegura los 2 pts de etiquetado | nulo | $0 (impresora) |
| Backup automático de config a la Pi | recuperación en minutos si algo se rompe | bajo | $0 |

## Tier 2 — ambiciosos (solo con Tier 1 estable y ≥3 días de margen)

| Extra | Beneficio | Riesgo | Nota |
|---|---|---|---|
| VLAN de invitados + SSID separado con firewall | segmentación real | medio | requiere rehacer DHCP/WiFi |
| freeRADIUS en container (WPA-Enterprise) | nivel universitario | alto | segundo container en el RB5009 |
| SNMP + Zabbix/LibreNMS | gráficas históricas | medio | free tier con límite de hosts; documentar el límite |
| IPv6 | modernidad | alto | el enunciado no lo pide; solo si domina todo el equipo |
| IPAM exportable (planilla) | tabla de IPs viva | nulo | se puede hacer desde este repo |

## Tier 3 — no hacer

BGP, VRRP, ECMP multi-path, port-forwarding (la WAN es CGNAT `100.64/10`, no hay IP pública),
cualquier cosa que agregue un punto único de falla nuevo durante la defensa.

## Criterio de decisión

Se acepta un extra solo si: (1) alguien del equipo puede explicarlo y deshacerlo en < 5 min,
(2) no cambia la tabla de direccionamiento congelada, (3) se prueba antes del ensayo general.
