# 11 · Evidencia de validación — Enrutamiento OSPF inter-sede

**Proyecto:** DCN2 "Campus UNIS Integrado" — Sede Norte (Grupo A)
**Catedrático:** Ing. Gustavo Adolfo Morales Xitamul
**Fecha de captura:** 2026-10-29, ~01:00 (America/Guatemala)
**RouterOS:** 7.24.2 (stable), build 2026-09-03
**Equipos:** GW-A (RB5009UG+S+, serial HFB09D3DPSG) ↔ GW-B (RB5009UG+S+, serial HFB09DV2C04)
**Topología de la prueba:** cable UTP directo `GW-A ether7` ↔ `GW-B ether7` (enlace inter-sede, `10.99.0.0/30`). Sin ISP conectado en ninguno de los dos equipos.

> Este documento es el **anexo de pruebas** del capítulo de resultados. Todas las salidas
> fueron capturadas en vivo desde el terminal de WinBox, sin edición.

---

## 0. Resumen de resultados

| # | Prueba | Resultado | Estado |
|---|---|---|---|
| 1 | Adyacencia OSPF en ambos extremos | `state="Full"` | ✅ |
| 2 | Intercambio de LSAs (Router-LSA de cada extremo) | LSDB consistente en ambos | ✅ |
| 3 | Instalación de rutas OSPF | ruta al loopback remoto, distance 110 | ✅ |
| 4 | Alcance inter-sede (ICMP al loopback remoto) | 4/4, 0 % pérdida, ~0.6 ms | ✅ |
| 5 | Convergencia ante caída del enlace | recuperación automática en ~18–20 s | ✅ |
| 6 | Costos y temporizadores por tipo de enlace | 100 inter-sede (`5s/20s`), 10 anillo (`2s/8s`) | ✅ |

**Conclusión:** el enrutamiento dinámico entre sedes está **operativo y validado**.

---

## 1. Adyacencia OSPF

### GW-B

```
[admin@GW-B] > /routing ospf neighbor print
Flags: D - DYNAMIC
0 D instance=ospf area=backbone interface=ether7 address=10.99.0.1
    router-id=10.10.255.1 state="Full" state-changes=6 adjacency=13m33s
    timeout=18s
```

### GW-A

```
[admin@GW-A] > /routing ospf neighbor print
Flags: D - DYNAMIC
0 D instance=ospf area=backbone interface=ether7 address=10.99.0.2
    router-id=10.20.255.1 state="Full" state-changes=5 adjacency=14m45s
    timeout=15s
```

**Lectura:** cada router ve al otro en estado `Full` sobre `ether7`, en el área `backbone`,
con los `router-id` correctos (`10.10.255.1` en Norte, `10.20.255.1` en Sur). La adyacencia
se mantuvo estable durante más de 14 minutos.

---

## 2. Base de datos de estado de enlace (LSDB)

### GW-A

```
[admin@GW-A] > /routing ospf lsa print
Flags: S - SELF-ORIGINATED; D - DYNAMIC
0  SD instance=ospf area=backbone type="router" originator=10.10.255.1
      id=10.10.255.1 sequence=0x80000007 age=202 checksum=0xD525 body=
         options=E bits=E
             type=p2p id=10.20.255.1 data=10.99.0.1 metric=100
             type=stub id=10.10.6.0 data=255.255.255.252 metric=10
             type=stub id=10.10.255.1 data=255.255.255.255 metric=1
             type=stub id=10.99.0.0 data=255.255.255.252 metric=100

1   D instance=ospf area=backbone type="router" originator=10.20.255.1
      id=10.20.255.1 sequence=0x80000008 age=214 checksum=0x3ADB body=
         options=E bits=E
             type=p2p id=10.10.255.1 data=10.99.0.2 metric=100
             type=stub id=10.20.255.1 data=255.255.255.255 metric=1
             type=stub id=10.99.0.0 data=255.255.255.252 metric=100
```

**Lectura:**

- Cada router origina **su** Router-LSA (`S` = self-originated) y tiene la del vecino (`D`).
- El enlace inter-sede se describe como enlace **p2p** con métrica **100** (decisión D-11).
- GW-A anuncia su subred de anillo `10.10.6.0/30` (la de `ether3`, que tenía cable).
- GW-B **no** anuncia `10.20.5.0/30` porque su `ether3` estaba **sin link** en ese momento
  (el cable de consola se había movido al GW-A). **Ese es el comportamiento correcto:**
  OSPF solo origina la subred de una interfaz que está *running*.
- Ninguno anuncia `ether2` (`10.10.1.0/30` / `10.20.1.0/30`) porque todavía no hay hAP conectado.

---

## 3. Tabla de rutas

### GW-A — rutas hacia la Sede Sur

```
[admin@GW-A] > /ip route print where dst-address~"10.20"
Flags: D - DYNAMIC; A - ACTIVE; o - OSPF
Columns: DST-ADDRESS, GATEWAY, ROUTING-TABLE, DISTANCE
    DST-ADDRESS     GATEWAY           ROUTING-TABLE  DISTANCE
DAo 10.20.255.1/32  10.99.0.2%ether7  main                110
```

### GW-B — rutas hacia la Sede Norte

```
[admin@GW-B] > /ip route print where dst-address~"10.10"
Flags: D - DYNAMIC; A - ACTIVE; o - OSPF
Columns: DST-ADDRESS, GATEWAY, ROUTING-TABLE, DISTANCE
    DST-ADDRESS     GATEWAY           ROUTING-TABLE  DISTANCE
DAo 10.10.255.1/32  10.99.0.1%ether7  main                110
```

**Lectura:** las rutas aparecen con flags `DAo` (dinámica, activa, OSPF), gateway apuntando
al otro extremo del enlace inter-sede y **distance 110** (la distancia administrativa estándar
de OSPF). La única ruta aprendida en esta prueba es la del loopback remoto, porque las demás
subredes del vecino dependen de interfaces que no estaban conectadas.

---

## 4. Parámetros OSPF por interfaz

### GW-A

```
[admin@GW-A] > /routing ospf interface print
Flags: D - DYNAMIC
0  D interface=lo address=10.10.255.1%lo area=backbone instance-id=0
     state=passive type=broadcast cost=1 priority=128 passive
     retransmit-interval=5s transmit-delay=1s hello-interval=10s
     dead-interval=40s

1  D interface=ether7 address=10.99.0.1%ether7 area=backbone instance-id=0
     state=ptp type=ptp cost=100 priority=128 retransmit-interval=5s
     transmit-delay=1s hello-interval=5s dead-interval=20s

2  D interface=ether3 address=10.10.6.2%ether3 area=backbone instance-id=0
     state=ptp type=ptp cost=10 priority=128 retransmit-interval=5s
     transmit-delay=1s hello-interval=2s dead-interval=8s
```

### GW-B

```
[admin@GW-B] > /routing ospf interface print
Flags: D - DYNAMIC
0  D interface=lo address=10.20.255.1%lo area=backbone instance-id=0
     state=passive type=broadcast cost=1 priority=128 passive
     retransmit-interval=5s transmit-delay=1s hello-interval=10s
     dead-interval=40s

1  D interface=ether7 address=10.99.0.2%ether7 area=backbone instance-id=0
     state=ptp type=ptp cost=100 priority=128 retransmit-interval=5s
     transmit-delay=1s hello-interval=5s dead-interval=20s

2  D interface=ether3 address=10.20.5.2%ether3 area=backbone instance-id=0
     state=ptp type=ptp cost=10 priority=128 retransmit-interval=5s
     transmit-delay=1s hello-interval=2s dead-interval=8s
```

| Interfaz | Tipo | Costo | Hello / Dead |
|---|---|---|---|
| `lo` (loopback) | passive | 1 | — (no envía hellos) |
| `ether7` (inter-sede) | ptp | **100** | **5 s / 20 s** |
| `ether2`, `ether3` (anillo) | ptp | **10** | **2 s / 8 s** |

Coincide exactamente con las decisiones **D-09** (anillo secuencial, redundancia) y
**D-11** (costo inter-sede 100 vs. 10 del anillo; temporizadores rápidos en el anillo,
lentos en el enlace de larga distancia).

---

## 5. Alcance inter-sede (ICMP)

```
[admin@GW-A] > /tool ping 10.20.255.1 count=4
  SEQ HOST                                     SIZE TTL TIME       STATUS
    0 10.20.255.1                                56  64 724us
    1 10.20.255.1                                56  64 533us
    2 10.20.255.1                                56  64 549us
    3 10.20.255.1                                56  64 544us
    sent=4 received=4 packet-loss=0% min-rtt=533us avg-rtt=587us max-rtt=724us
```

**Lectura:** GW-A alcanza el loopback de la Sede Sur a través de la ruta OSPF.
Latencia sub-milisegundo porque el enlace de la prueba es un cable directo; con los SXT
en el aire se espera sumar la latencia del radioenlace (documentar en la prueba de campo).

---

## 6. Prueba de convergencia (la prueba central)

**Método:** ping continuo de 20 paquetes cada 2 s. A mitad de la prueba se **desconectó
el cable de `ether7`** y luego se **reconectó**, sin tocar ninguna configuración.

```
[admin@GW-A] > /tool ping 10.20.255.1 count=20 interval=2
  SEQ HOST                                     SIZE TTL TIME       STATUS
    0 10.20.255.1                                56  64 667us
    1 10.20.255.1                                56  64 570us
    2 10.20.255.1                                56  64 596us
    3 10.20.255.1                                56  64 548us
    4 10.20.255.1                                56  64 614us
    5 10.20.255.1                                56  64 558us
    6 10.20.255.1                                56  64 613us
    7 10.20.255.1                                56  64 539us
    8 10.20.255.1                                56  64 542us
    9 10.20.255.1                                56  64 564us
   10                                                              no route to...
   11                                                              no route to...
   12                                                              no route to...
   13                                                              no route to...
   14                                                              no route to...
   15                                                              no route to...
   16                                                              no route to...
   17                                                              no route to...
   18                                                              no route to...
   19 10.20.255.1                                56  64 693us
    sent=20 received=11 packet-loss=45% min-rtt=539us avg-rtt=591us
   max-rtt=693us
```

### Análisis

| Fase | Paquetes | Tiempo | Qué demuestra |
|---|---|---|---|
| Antes del corte | seq 0–9 | 0–18 s | Enlace sano, ruta OSPF instalada |
| Corte | seq 10–18 | 20–36 s | `no route to host` en **0 s**: al caer el link, la ruta desaparece **inmediatamente** |
| Recuperación | seq 19 | ~38 s | El vecino vuelve a formarse solo y la ruta OSPF se reinstala |

- La **pérdida total es del 45 %** (9 de 20 paquetes), acotada al intervalo de indisponibilidad.
- El mensaje `no route to host` (en vez de `timeout`) demuestra que la **convergencia local
  es instantánea**: la ruta conectada y la ruta OSPF se retiran en el mismo momento en que
  el kernel detecta el link caído. No hay tráfico "blackholeado" por una ruta obsoleta.
- La recuperación tomó **~18–20 s**, consistente con el `dead-interval=20s` configurado en
  `ether7`: el vecino declara muerta la adyacencia al vencer ese temporizador y la reconstruye
  con los hellos siguientes (5 s).
- **No se tocó ninguna configuración durante la prueba.** La red volvió sola.

> Nota para la defensa: este intervalo explica por qué el anillo usa `2s/8s` (recuperación en
> ~8 s) y el enlace inter-sede `5s/20s` (más tolerante a microcortes del radioenlace).

---

## 7. Notas del log (GW-B)

Evidencia complementaria capturada del `Log` de GW-B:

```
2026-09-02 09:58:12 system,error,critical login failure for user admin from 00:0E:4C:68:47:E8 via winbox
...  (6 intentos entre 09:58:12 y 09:59:27)
2026-10-29 00:50:55 system,clock,critical,info ntp change time Sep/02/2026 04:34:44 => Oct/29/2026 00:50:55
2026-10-29 00:50:57 system,error,critical router rebooted without proper shutdown, probably power outage
```

**Lectura:**

1. Los `login failure` son los intentos de WinBox con contraseña incorrecta **antes** de que
   se aplicara la clave única del proyecto (el reloj del equipo estaba en septiembre, por eso
   el timestamp viejo). No indican un problema de configuración.
2. El salto de reloj de `Sep/02` a `Oct/29` es el ajuste NTP cuando el equipo tuvo salida a
   Internet; sin ISP el reloj queda desactualizado hasta que se conecte el enlace del
   laboratorio.
3. `router rebooted without proper shutdown` corresponde a un **corte de energía**, no a un
   reinicio por software. Recomendación operativa: apagar siempre con `/system shutdown` y
   **nunca** usar el botón *reset* durante la configuración (borra la configuración aplicada).

---

## 8. Cómo reproducir esta prueba

1. Conectar un cable UTP entre `ether7` del GW-A y `ether7` del GW-B.
2. En cada equipo: `/routing ospf neighbor print` → debe aparecer 1 vecino en `Full`.
3. En cada equipo: `/ip route print where dst-address~"10.<otra-sede>"` → ruta `DAo` distance 110.
4. Desde GW-A: `/tool ping 10.20.255.1 count=4` → 4/4.
5. Convergencia: `/tool ping 10.20.255.1 count=20 interval=2` y desconectar/reconectar `ether7`
   a mitad de la prueba.

---

## 9. Estado tras esta validación

| Elemento | Estado |
|---|---|
| GW-A (Norte) — bloques 0 a 5 | ✅ aplicados y auditados |
| GW-B (Sur) — bloques 0 a 5 | ✅ aplicados y auditados |
| Enlace inter-sede OSPF | ✅ validado (adyacencia, LSDB, rutas, convergencia) |
| `ether2` / `ether3` hacia los hAP | ⬜ pendiente (sin equipos conectados) |
| `default-ISP` y `originate-default` | ⬜ pendiente (requiere enlace a Internet) |
| Modo contenedor / Pi-hole / AdGuard (bloques 6–7) | ⬜ pendiente |

**Siguiente hito:** conectar el primer hAP (`hAP-1A`, el que aloja el servidor) y validar
la adyacencia OSPF sobre `ether2` con costo 10 y temporizadores `2s/8s`.
