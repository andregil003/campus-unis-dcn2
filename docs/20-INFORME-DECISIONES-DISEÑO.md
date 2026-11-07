# Informe de Decisiones de Diseño y Problemas Encontrados

**Proyecto:** Campus UNIS Integrado — Proyecto Final DCN2  
**Curso:** Data Communication Networks 2 — Segundo Semestre 2026  
**Sede Norte / Grupo A** · Universidad del Istmo  
**Catedrático:** Ing. Gustavo Adolfo Morales Xitamul  
**Fecha:** 06 de noviembre de 2026  
**Repositorio:** `andregil003/campus-unis-dcn2`

---

## 1. Introducción

El proyecto consistió en diseñar, implementar y verificar una red de campus con dos sedes interconectadas mediante un enlace inalámbrico punto a punto (SXT Lite5), enrutamiento dinámico OSPF v7 en anillo, DNS filtrado por sede (Pi-hole en Norte, AdGuard Home en Sur), servidores institucionales nginx en ambas sedes, y failover automático de WAN entre sedes. Toda la configuración se versionó como código en el repositorio del proyecto bajo el estándar de configuración como código.

---

## 2. Decisiones de diseño tomadas

Las decisiones más relevantes, documentadas en `docs/06-DECISIONES.md` (D-01 a D-19), se resumen a continuación:

| Decisión | Qué se decidió | Motivo principal |
|----------|----------------|------------------|
| **D-01** | Direccionamiento WiFi según diagrama v3 (`192.168.1-5.0/24` Norte, `192.168.11-14.0/24` Sur) | Alineación con el diagrama de referencia del catedrático |
| **D-02** | Servidor en `10.10.0.0/24` solo en `hAP-1A ether3` (`10.10.0.1`), servidor en `.100` | Evitar duplicación de IP entre GW y servidor |
| **D-03** | Failover por default OSPF con asimetría de costo (estática `dist=1` + OSPF `dist=110`) | Cumplir Regla 1 (salida independiente por sede) sin ECMP |
| **D-04** | Inter-sede como puente L2 con SXT en `ap-bridge` / `station-bridge` | Transparencia para OSPF entre los RB5009 |
| **D-05** | Contenedor Pi-hole como prioridad en fase C | Mayor riesgo técnico; se implementó temprano |
| **D-06** | Extras acotados: etiquetas de puertos, dst-nat DNS, netwatch documentado, página `/health` | Enfocarse en la ruta crítica antes que extras no esenciales |
| **D-09** | Anillo secuencial `1→2→3→4→5→GW` | Cerrar correctamente el anillo Norte sin subredes desperdiciadas |
| **D-10** | Servidor y contenedor en redes separadas; servidor en `hAP-1A ether3` | Resolver contradicción de IP duplicada en el diseño original |
| **D-11** | Costo inter-sede 100; timers anillo 2s/8s, inter-sede 5s/20s | Evitar ECMP y tolerar inestabilidad del enlace inalámbrico |
| **D-13** | Servidor Norte = laptop Windows + nginx (no Raspberry Pi física) | No hay SBC disponible en Norte; cumple requisitos por comportamiento (S-01 a S-06) |
| **D-14** | Ruta persistente `10.0.0.0/8` hacia gateway en servidor Windows + regla ICMP | Corregir enrutamiento y ping bloqueado por firewall de Windows |
| **D-15** | ROUTER-ISP (RB3011) como router ISP del laboratorio | El equipo del laboratorio cumple el rol del ISP del diagrama |
| **D-16** | WAN en `ether7`, inter-sede en `ether1` (PoE-in alimenta el GW) | Aprovechar PoE-in del RB5009UG+S+IN en `ether1` para alimentar el GW con la antena |
| **D-17** | No hay PoE-out en RB5009UG+S+IN; antena se alimenta con su propio inyector | El modelo UG no entrega PoE; solo recibe PoE-in en `ether1` |
| **D-18** | Una sola clave WiFi para todo el campus: `UNIS2026` | Operación simple y coherencia entre sedes (desviación aceptada de ≥12 caracteres) |
| **D-19** | Pi-hole en Sede Norte, AdGuard Home en Sede Sur (asimétrico) | Cada sede desplegó su contenedor; documentado como está en el equipo real |

---

## 3. Problemas encontrados y soluciones aplicadas

### 3.1 ECMP en hAP-3A y hAP-4A (anillo Norte)
**Problema:** `hAP-3A` y `hAP-4A` tenían dos rutas default con el mismo costo (30 por cada lado del anillo), generando ECMP que violaba el camino determinista requerido por el estándar E-05.  
**Solución:** Se subió el costo del enlace L4 (`hAP-3A ether2` ↔ `hAP-4A ether1`) de 10 a 20 en ambos extremos. Ahora cada hAP tiene una sola ruta default por OSPF hacia GW-A.

### 3.2 SSH no disponible por defecto en RouterOS v7
**Problema:** Los equipos RouterOS v7 no traen SSH habilitado de fábrica, lo que impedía la administración remota desde la laptop.  
**Solución:** Habilitar SSH en cada equipo una sola vez mediante `/ip service enable ssh`, accesible luego desde PowerShell o WinBox.

### 3.3 Contraseña WiFi inconsistente en hAP-4A
**Problema:** `hAP-4A` tenía la clave placeholder `CambiarClaveWiFi2026` en lugar de `UNIS2026`, impidiendo la conexión de clientes.  
**Solución:** `/interface wifi security set sec-unis passphrase="UNIS2026"`. Verificado que un cliente se conecta exitosamente al WiFi `UNIS-A1`.

### 3.4 Señal saturada en el enlace SXT (-2 a -6 dBm)
**Problema:** Las antenas SXT-A y SXT-B estaban físicamente demasiado cerca (< 1 metro), generando señal de -3 a -6 dBm que satura los receptores.  
**Solución:** Se bajó el `tx-power` a `default` en ambos SXT. Para producción se recomienda separar físicamente las antennas 1-2 m o usar un atenuador coaxial 10-20 dB.

### 3.5 Contenedor Pi-hole sin almacenamiento persistente externo
**Problema:** No hay USB disponible en los RB5009, por lo que el `root-dir` del contenedor vive en la NAND interna. En Sur, sin mounts, un `container update` borra la configuración de AdGuard.  
**Solución:** Documentado como deuda (D-19). En Norte los mounts sí se mantienen fuera del root-dir. Si se consigue un pendrive, se mueve el `root-dir` al disco externo.

### 3.5 Servidor Windows: rutas y firewall ICMP
**Problema:** La laptop de Sede Norte no alcanzaba redes `10.x` debido a que Windows prefería la ruta por WiFi y el ICMP de entrada estaba deshabilitado.  
**Solución:** `preparar-red.ps1` crea una ruta persistente `10.0.0.0/8 → 10.10.0.1` por la interfaz Ethernet y una regla de firewall que permite ICMP entrante.

---

## 4. Conclusión

La red del campus UNIS está implementada y verificada en equipo físico. Todos los estándares obligatorios (E-01 a E-11) se cumplen: 12 adyacencias OSPF en Full, NAT exclusivo en los gateways, DNS filtrado demostrable en ambas sedes, failover y restauración automática de WAN en menos de 30 segundos, y servidores institucionales accesibles entre sedes. Toda la configuración está versionada como código en el repositorio, y la documentación de diseño, decisiones y problemas quedó registrada en este repositorio para su entrega y defensa.

---

**Documentos de soporte en el repositorio:**
- `docs/06-DECISIONES.md` — Registro completo de decisiones (ADR)
- `docs/01-TABLA-IPs.md` — Tabla de direccionamiento y costos OSPF
- `docs/13-GUIA-VERIFICACION.md` — Runbook de verificación SSH y comandos
- `docs/14-PIHOLE-DNS-FILTRADO.md` — Documento de Pi-hole DNS filtrado
- `docs/16-EVIDENCIA-PRUEBAS.md` — Evidencia de pruebas en vivo
- `docs/17-DIAGRAMA-RED.md` + `docs/diagrama-red.drawio` — Diagrama de red
- `docs/18-GUIA-DEMOSTRACION-DEFENSA.md` — Guía paso a paso para la defensa oral
- `docs/19-DOCUMENTACION-MASTER.md` — Documentación maestra consolidada

---

**Grupo A — Sede Norte**  
Campus UNIS — Proyecto Final DCN2 — Segundo Semestre 2026