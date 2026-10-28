# Registro de decisiones (ADR ligero)

Formato: una decisión por entrada, con estado, contexto y consecuencia.

---

## D-01 · Direccionamiento de las redes WiFi

- **Estado:** ABIERTA — requiere confirmación del catedrático
- **Contexto:** el enunciado dice que Sede Norte opera en `10.10.0.0/8`; el diagrama de referencia usa
  `192.168.1-5.0/24`, fuera de ese bloque (ver R-01).
- **Opciones:**
  - **A (recomendada):** `10.10.11.0/24` … `10.10.15.0/24`. Cumple la regla escrita, no colisiona con las /30
    ni con `10.10.0.0/24`, y deja espacio limpio para crecer.
  - **B:** `192.168.1.0/24` … `192.168.5.0/24`. Copia literal del diagrama; riesgo de objeción por la regla /8.
- **Consecuencia de A:** la tabla de `01-TABLA-IPs.md` queda vigente tal como está escrita.
- **Decisor:** André + catedrático (Ing. Morales).

---

## D-02 · Red del servidor separada del gateway

- **Estado:** TOMADA
- **Contexto:** el diagrama pone `10.10.0.1/24` en GW-A y `10.10.0.100/24` en la Pi, ambos en la misma /24
  pero en equipos distintos (R-02).
- **Decisión:** `10.10.0.0/24` se usa únicamente en el enlace `hAP-1A ether3 ↔ Raspberry Pi`. GW-A no tiene
  interfaz en esa red; usa loopback `10.10.255.1` y veth `10.10.254.1`.
- **Consecuencia:** la IP exigida `10.10.0.100` sigue siendo válida y se alcanza por OSPF.

---

## D-03 · Failover por default OSPF con asimetría de costo

- **Estado:** TOMADA (pendiente de validación en laboratorio)
- **Contexto:** la Regla 1 prohíbe que el tráfico cruce el enlace inter-sede con la WAN activa, y la Regla 6
  prohíbe el ruteo estático como solución principal.
- **Decisión:** cada GW anuncia su default por OSPF con métrica 10; el inter-sede tiene costo 1000, de modo que
  el default remoto llega con 1010 y solo se usa cuando el propio desaparece.
- **Consecuencia:** cero ECMP, cumplimiento de Regla 1 por diseño, y failover sin intervención manual.

---

## D-04 · Inter-sede como puente L2 con `ap-bridge` / `station-bridge`

- **Estado:** TOMADA
- **Contexto:** los SXT deben ser transparentes para OSPF (R-03).
- **Decisión:** SXT-A en `ap-bridge`, SXT-B en `station-bridge` (o WDS dinámico). IPs de `10.99.0.0/30` en los
  RB5009, no en las antenas.
- **Consecuencia:** un solo dominio de broadcast en el enlace; OSPF lo trata como punto a punto con costo 1000.

---

## D-05 · Prioridad del container Pi-hole

- **Estado:** TOMADA
- **Contexto:** el container tiene un requisito físico (`device-mode`) y es el mayor riesgo técnico (R-04).
- **Decisión:** se intenta el día 1 de la semana 13, con plan B documentado en R-05.
- **Consecuencia:** si falla el día 1, hay una semana para cambiar de estrategia sin sacrificar la nota de DNS.

---

## D-06 · Alcance de los extras

- **Estado:** ABIERTA
- **Contexto:** hay margen para Tier 1 (BFD, ntfy, dashboard, TLS) sin riesgo apreciable.
- **Opciones:** solo lo que da puntos / Tier 1 completo / Tier 1 + parte del Tier 2.
- **Decisor:** André.

---

## Plantilla

```
## D-XX · Título
- Estado: ABIERTA | TOMADA | DESCARTADA
- Contexto: ...
- Decisión: ...
- Consecuencia: ...
- Decisor: ...
```

---

## D-07 · Hardware real difiere del enunciado

- **Estado:** TOMADA (documentada para la defensa)
- **Contexto:** el enunciado asigna un RB5009UPr+S+; el equipo tiene RB5009UG+S+IN. La diferencia es el
  PoE-out (el UPr lo tiene, el UG no). Los hAP ax lite se alimentan por USB-C 5 V y **no aceptan PoE**, así que
  la diferencia no afecta la arquitectura.
- **Decisión:** se trabaja con RB5009UG+S+IN, documentando el modelo real y la razón por la que el PoE-out
  es irrelevante en este diseño.
- **Consecuencia:** el estándar físico exige regleta con tomas suficientes y una fuente por equipo (R-16).

---

## D-08 · Servidor de la sede: laptop Windows (Norte) + Raspberry Pi 4 (Sur)

- **Estado:** CERRADA — aprobada por el catedrático (27/10/2026)
- **Contexto:** el enunciado exige una Raspberry Pi con nginx. En Norte no hay SBC: solo un Pico (RP2040) que
  no puede ejecutar nginx. Sur sí dispone de una **Raspberry Pi 4 de 2 GB**.
- **Decisión:** Sede Norte usa **laptop con Windows + nginx/Windows**; Sede Sur usa su **Pi 4 + nginx**.
  El requisito se cumple en comportamiento (IP fija, HTTP 200, `/health`, alcanzable desde la otra sede,
  arranque automático), no en plataforma.
- **Consecuencia:** el estándar E-08 se reescribió neutral a plataforma (S-01…S-06) y se documentaron las
  trampas de Windows en `08-SERVIDOR.md` (§2.3: firewall, suspensión, doble NIC, arranque como servicio).
- **Riesgo residual:** si el catedrático exige Raspberry Pi física, se activa R-13 opción B2 (Pi prestada) o B4.
- **Decisor:** André (y confirmación del catedrático).
