# 14 · Pi-hole — DNS filtrado del campus (Sede Norte)

> Fecha: 06/11/2026 · Equipo: GW-A (RB5009, Sede Norte) · Contenedor: `pihole`

---

## 1. Qué es Pi-hole en este proyecto

**Pi-hole NO es el servidor web institucional.** Ese corre en la laptop Windows de Sede Norte (`10.10.0.100`, nginx).

Pi-hole es el **servidor DNS filtrado del campus Norte**. Vive como contenedor dentro del RB5009 de GW-A y se encarga de:

- Resolver consultas DNS de los clientes de la sede.
- Bloquear dominios en una lista negra (blacklist).
- Reenviar consultas no bloqueadas a upstreams externos (`1.1.1.1` y `9.9.9.9`).
- Evitar que un cliente se salte el filtrado configurando DNS manual (8.8.8.8, etc.) mediante `dst-nat` forzoso en el puerto 53.

---

## 2. Dónde corre y cómo se llega a él

| Dato | Valor |
|------|-------|
| Equipo | GW-A — RB5009UG+S+IN (Sede Norte) |
| Contenedor | `pihole` (imagen `pihole/pihole:latest`) |
| IP del contenedor | `10.10.254.53` (interfaz `veth1`) |
| IP del router (loopback/DNS campus) | `10.10.255.1` |
| Red del contenedor | `10.10.254.0/24` |
| Arranque automático | `start-on-boot=yes` (ya configurado) |
| Estado actual | `HEALTHY` (verificado con `/container print`) |

### Flujo de una consulta DNS

```
Cliente WiFi (192.168.N.x)
        │
        ▼
  DHCP entrega DNS = 10.10.255.1 (GW-A)
        │
        ▼
  GW-A recibe consulta en puerto 53
        │
        ▼
  dst-nat forzó UDP/TCP :53 → 10.10.254.53 (Pi-hole)
        │
        ▼
  Pi-hole responde o bloquea según blacklist
        │
        ▼
  Si no está bloqueado, Pi-hole consulta upstream 1.1.1.1 / 9.9.9.9
```

---

## 3. Qué ya está configurado (verificado en vivo)

Desde la configuración exportada de GW-A:

```
/container print
# NAME    ROOT-DIR       INTERFACE  MEMORY-CURRENT  CPU-USAGE
# pihole  /pihole6/root  veth1      50.9MiB         0.2
```

Variables de entorno del contenedor (`pihole_envs`):
- `DNSMASQ_USER=root`
- `FTLCONF_dns_listeningMode=all`
- `FTLCONF_dns_upstreams="1.1.1.1;9.9.9.9"`
- `FTLCONF_misc_etc_dnsmasq_d=true`
- `TZ=America/Guatemala`

Montajes persistentes:
- `/etc/pihole` → `/pihole6/etc`
- `/etc/dnsmasq.d` → `/pihole6/dnsmasq.d`

Reglas de firewall NAT en GW-A:
```
chain=dstnat action=dst-nat to-addresses=10.10.254.53 to-ports=53
  protocol=udp in-interface-list=LAN dst-port=53
chain=dstnat action=dst-nat to-addresses=10.10.254.53 to-ports=53
  protocol=tcp in-interface-list=LAN dst-port=53
```

DNS del router:
```
/ip dns set allow-remote-requests=yes servers=10.10.254.53
```

DHCP en los hAP de Sede Norte entrega DNS `10.10.255.1` (loopback de GW-A, que reenvía a Pi-hole).

---

## 4. Qué FALTA configurar / verificar para la defensa

Según el estándar **E-06**, el criterio de aceptación es:

> *"el dominio de prueba acordado con el catedrático queda bloqueado tanto desde WiFi como desde un cliente con DNS configurado a mano."*

### 4.1. Poner contraseña de administración de Pi-hole

En los archivos `.rsc` de `configs/rsc/` hay un placeholder `CambiarClavePihole2026`. Esa es la clave del panel web de Pi-hole. Tiene que cambiarse por la clave real antes de la defensa.

### 4.2. Bloquear el dominio de prueba

Hay que entrar al panel web de Pi-hole o por consola del contenedor y agregar el dominio que el catedrático acordó como prueba de filtrado.

Desde la terminal de GW-A, se puede entrar al contenedor:

```
/container shell pihole
```

Dentro del contenedor, usar `pihole` CLI para agregar a la blacklist:

```
pihole -w <dominio-a-bloquear>
```

O desde el panel web: `http://10.10.254.53/admin` (usuaria `admin`, clave real).

### 4.3. Verificar desde cliente WiFi

Conectar un celular/laptop al SSID `UNIS-A1`…`UNIS-A5` y probar:

```
nslookup <dominio-bloqueado> 10.10.255.1
```
**Esperado:** no resuelve o devuelve IP de Pi-hole (bloqueado).

```
nslookup google.com 10.10.255.1
```
**Esperado:** resuelve normalmente.

### 4.4. Verificar con DNS manual (cliente salta el filtrado)

Configurar en un cliente DNS manual `8.8.8.8` y probar:

```
nslookup <dominio-bloqueado> 8.8.8.8
```

**Esperado:** gracias al `dst-nat` en GW-A, la consulta se redirige a Pi-hole y el dominio sigue bloqueado. Esto demuestra que ningún cliente se salta el filtrado.

---

## 5. Comandos de verificación rápida

Desde GW-A:

```
/container print                     # pihole debe estar HEALTHY
/ip firewall nat print where dst-port=53   # 2 reglas dst-nat a 10.10.254.53
/ip dns print                        # servers=10.10.254.53, allow-remote-requests=yes
/ip route print where dst-address=0.0.0.0/0  # confirmar que el default sigue vivo
```

Desde un cliente en WiFi de Sede Norte:

```
nslookup google.com 10.10.255.1      # debe resolver
nslookup <dominio-bloqueado> 10.10.255.1   # debe estar bloqueado
```

---

## 6. Aclaración: Sede Norte no necesita Raspberry Pi física

Ya se confirmó con el catedrático que **no es necesario** una Raspberry Pi en Sede Norte. El servidor institucional de Sede Norte es la **laptop Windows con nginx** (`10.10.0.100`), y cumple los estándares S-01 a S-06:

| Estándar | Qué verifica | Estado |
|----------|--------------|--------|
| S-01 | IP fija `10.10.0.100/24` responde ping | ✅ PASS |
| S-02 | nginx en puerto 80 responde 200 | ✅ PASS |
| S-03 | Página identificable de la sede | ✅ PASS |
| S-04 | `/health` devuelve `200` + `ok` | ✅ PASS |
| S-05 | Alcanzable desde Sede Sur | ✅ PASS (curl cruzado) |
| S-06 | Arranque automático tras corte de energía | ✅ PASS (tarea programada) |

El contenedor Pi-hole es complementario (DNS filtrado), no reemplaza al servidor web.

---

> **Regla de oro:** nunca configurar en vivo durante la defensa. Si agregás un dominio a la blacklist o cambias la contraseña de Pi-hole, regístralo en `docs/06-DECISIONES.md`.