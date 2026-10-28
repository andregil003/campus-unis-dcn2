# Servidor de sede — diseño heterogéneo (Norte Windows / Sur Linux)

Decisión D-08: **Sede Norte usa una laptop con Windows + nginx**; **Sede Sur usa una Raspberry Pi 4 (2 GB)
con nginx**. El requisito del curso es que el servidor de cada sede sea alcanzable desde la otra sede y que
exista un servidor nginx por sede. Al ser plataformas distintas, el estándar se define por **comportamiento
observable**, no por sistema operativo.

---

## 1. Estándar neutral de plataforma (obligatorio en ambas sedes)

| # | Requisito | Criterio verificable |
|---|---|---|
| S-01 | IP fija y conocida | `10.10.0.100/24` (Norte) · `10.20.0.100/24` (Sur); responde `ping` |
| S-02 | nginx escuchando en el puerto 80 | `curl -I http://<ip>` → `HTTP/1.1 200` |
| S-03 | Página identificable | devuelve el nombre de la sede y del campus |
| S-04 | Endpoint `/health` | `curl http://<ip>/health` → `200` con cuerpo corto (`ok`) |
| S-05 | Alcanzable desde la otra sede | `curl` cruzado en ambos sentidos, sin NAT intermedio |
| S-06 | Arranque automático tras corte de energía | el servicio vuelve solo, sin login manual |

Todo lo demás (sistema operativo, cómo se instala, cómo se hace el arranque automático) es libre.

---

## 2. Sede Norte — laptop Windows

### 2.1 Topología

```
hAP-1A ether3 (10.10.0.1/24)  ──cable──  NIC Ethernet de la laptop (10.10.0.100/24, gw 10.10.0.1)
```

La laptop ocupa el lugar de la Raspberry Pi en el diagrama. **No cambia ninguna IP ni subred.**

### 2.2 Montaje de nginx

| Paso | Qué se hace |
|---|---|
| 1 | Descargar el build **nginx/Windows** oficial (zip) y descomprimir en una ruta corta sin espacios, ej. `C:\nginx` |
| 2 | `conf/nginx.conf`: `listen 80;`, `root C:/nginx/html;` (barras normales, no `\`) y una `location = /health { return 200 "ok"; }` |
| 3 | Verificar que el puerto 80 esté libre (IIS, Skype, agentes de impresora suelen ocuparlo): `netstat -ano | findstr :80` |
| 4 | Arrancar con `nginx.exe` y confirmar localmente con `curl` antes de conectar el cable |
| 5 | Dejarlo como **servicio** (NSSM o WinSW) o tarea programada "al iniciar el sistema" ⇒ cumple S-06 |

### 2.3 Trampas específicas de Windows (esto es lo que hunde la demo)

| Id | Riesgo | Mitigación |
|---|---|---|
| W-1 | **Firewall de Windows** bloquea el puerto 80 entrante desde la red del campus | Regla de entrada explícita TCP 80 para el perfil de red activo, y marcar la red como **Privada**, no Pública |
| W-2 | **La laptop se suspende** y el servidor desaparece en plena defensa | Plan de energía: "Nunca suspender", "Nunca apagar pantalla", tapa cerrada = no hacer nada |
| W-3 | **Doble NIC**: WiFi encendido + Ethernet conectado ⇒ ruteo asimétrico o respuesta por la interfaz equivocada | Deshabilitar WiFi durante la defensa o subir la métrica de la interfaz Ethernet a prioridad |
| W-4 | IP tomada por DHCP o cambiada por "obtener automáticamente" | IP estática `10.10.0.100/24`, gw `10.10.0.1`, DNS apuntando solo a `10.10.255.1` |
| W-5 | nginx no arranca al reiniciar (nadie inicia sesión) | Servicio con NSSM/WinSW, no acceso manual |
| W-6 | `nginx/Windows` no es el build Linux: usa `select()` y es menos eficiente | Irrelevante para una demo: pocas conexiones. No usar para benchmarks |
| W-7 | Reloj desfasado ⇒ logs sin valor probatorio | Sincronización NTP de Windows activa y zona horaria correcta |
| W-8 | La laptop no tiene puerto RJ45 | Adaptador USB-Ethernet documentado en el inventario antes de armar el rack |

### 2.4 Aprobación del catedrático — REGISTRADA

Se consultó al Ing. Morales y **la laptop con nginx fue aceptada** como servidor de la sede de Norte.
Queda constancia de que el requisito se cumple por comportamiento (IP fija, nginx, HTTP 200, `/health`,
alcanzable desde la otra sede), no por plataforma.

La misma autorización habilita el **servidor de respaldo en otra computadora** (ver §6): si el servidor
titular no arranca, se levanta otra máquina con el mismo estándar y la misma IP.

---

## 3. Sede Sur — Raspberry Pi 4 (2 GB)

No es nuestra configuración, pero se coordina porque la nota es compartida.

| Aspecto | Recomendación (para acordar con Grupo B) |
|---|---|
| Sistema | Raspberry Pi OS **Lite** (sin escritorio: 2 GB de RAM dan para más sin entorno gráfico) |
| IP | `10.20.0.100/24`, gw `10.20.0.1`, en `eth0` hacia `hAP-1B ether3` |
| Servicio | nginx del repositorio, `systemctl enable --now nginx` ⇒ cumple S-06 |
| Página y `/health` | mismo esquema que S-03/S-04 para que el `curl` cruzado sea comparable |
| NTP | `systemd-timesyncd` activo |
| Cuidado | la Pi 4 necesita fuente oficial de 5 V/3 A; con fuente débil aparecen reinicios por caída de tensión |

---

## 4. Pruebas cruzadas del bloque servidores

| Prueba | Desde | Hacia | Esperado |
|---|---|---|---|
| T-1 | `10.10.0.100` (laptop) | `10.20.0.100` (Pi) | `HTTP/1.1 200` |
| T-2 | `10.20.0.100` (Pi) | `10.10.0.100` (laptop) | `HTTP/1.1 200` |
| T-3 | un cliente WiFi de Norte | `10.20.0.100` | `HTTP/1.1 200` |
| T-4 | un cliente WiFi de Sur | `10.10.0.100` | `HTTP/1.1 200` |
| T-5 | `10.10.0.100` | `/health` | `200` + cuerpo `ok` |

Si T-3 o T-4 fallan, el problema casi siempre es de **firewall/servicio HTTP** y no de ruteo: se confirma con
`ping` y `traceroute` antes de tocar la configuración del servidor. Si el ping llega y el HTTP no, el sospechoso
número uno es el firewall del servidor (W-1 en Norte, `ufw` en Sur).

---

## 5. Impacto en el resto del diseño

- **Tabla de IPs:** sin cambios (`10.10.0.100` sigue siendo la IP del servidor de Norte).
- **E-08:** reescrito en términos de comportamiento (S-01…S-06).
- **R-13:** pasa de "riesgo abierto" a "riesgo mitigado con validación pendiente del catedrático".
- **Pico RP2040:** queda libre como extra opcional (por ejemplo, semáforo LED del estado OSPF), nunca como servidor.

---

## 6. Servidor de respaldo (cold spare)

Como el estándar es por comportamiento, **cualquier computadora con nginx puede reemplazar al servidor titular**
en minutos. Los artefactos listos para desplegar viven en la carpeta servidor/ de este repositorio.

| Aspecto | Regla |
|---|---|
| Máquina de respaldo | cualquier PC con Windows o Linux (Norte y Sur pueden intercambiar plataforma) |
| Configuración | copiar servidor/, instalar nginx, aplicar config y página |
| Dirección | **la misma IP del servidor caído** (10.10.0.100 o 10.20.0.100) |
| Tiempo objetivo de recuperación | **≤ 5 minutos**, medido en ensayo |
| Regla de oro | **nunca dos máquinas con la misma IP encendidas a la vez**: primero se desconecta el cable del servidor caído |
| Requisito previo | la máquina de respaldo se prueba **antes** de la defensa, no se estrena en vivo |

Procedimiento paso a paso: [servidor/README.md](../servidor/README.md) §4.
Verificación automática: servidor/windows/verificar.ps1 (Windows) o servidor/linux/verificar.sh (Linux).
