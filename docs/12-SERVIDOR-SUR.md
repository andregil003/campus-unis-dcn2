# Servidor Sede Sur — Raspberry Pi 4 · guía paso a paso

**Para:** Dharly (Sede Sur / Grupo B) · **Supervisa:** André (Grupo A)
**Objetivo:** dejar la Raspberry Pi 4 de Sur cumpliendo los 6 requisitos S-01…S-06 de
[`docs/08-SERVIDOR.md`](08-SERVIDOR.md) §1, con evidencia fotográfica y de terminal.
**Tiempo estimado:** 45–60 min la primera vez (sin contar la descarga de la imagen).
**Se hace UNA sola vez.** Si ya está instalada y solo hay que revisarla, salta a §9.

> **Regla de oro:** todo comando que empiece con `sudo` se corre en la Pi, no en la laptop.
> Copia y pega de una línea a la vez. Al final de cada paso hay una **verificación**: si no
> coincide con lo esperado, no sigas — resuelve con §11 antes de avanzar.

---

## 0. Resumen en una pantalla

| # | Paso | Qué deja listo | Verifica |
|---|---|---|---|
| 1 | Grabar la microSD | Pi OS Lite 64-bit + SSH + hostname `campus-sur` | §4 |
| 2 | Entrar por SSH | Acceso remoto sin monitor | `ssh` responde |
| 3 | Actualizar el sistema | Paquetes al día | `apt` sin errores |
| 4 | Instalar nginx + página | S-02, S-03, S-04 | `curl` local |
| 5 | IP fija `10.20.0.100` | S-01 | `ip -4 addr` |
| 6 | Firewall | puerto 80 abierto | `ufw status` |
| 7 | Arranque automático | S-06 | `systemctl is-enabled` |
| 8 | Prueba de corte de energía | S-06 de verdad | desenchufar/enchufar |
| 9 | Verificación completa | S-01…S-06 | `verificar.sh` |
| 10 | Prueba cruzada con Norte | S-05 | `curl` a `10.10.0.100` |

**Datos fijos que NO se negocian** (vienen de [`docs/01-TABLA-IPs.md`](01-TABLA-IPs.md) §2):

| Dato | Valor |
|---|---|
| Sede | Sur (Grupo B) |
| Hostname | `campus-sur` |
| IP del servidor | `10.20.0.100/24` |
| Gateway | `10.20.0.1` (= `hAP-3B` **ether3**) |
| DNS | `10.20.255.1` (= loopback de GW-B) |
| Interfaz | `eth0` (RJ45 de la Pi) |
| Puerto | `80/tcp` |
| Página | `/var/www/campus/index.html` |

**Materiales:** Pi 4 de 2 GB · microSD ≥ 8 GB (clase 10 / A1) · **fuente oficial 5 V / 3 A USB-C** ·
cable Ethernet · laptop con lector de SD · el cable que va al `hAP-3B` **ether3**.

---

## 1. Antes de tocar la Pi — dos decisiones

**1.1 ¿Hay monitor y teclado?**
- **Sí** → puedes saltarte la configuración de SSH del Imager y trabajar en la consola.
- **No (lo normal)** → el paso 1 activa SSH desde el Imager. No hay otra forma cómoda.

**1.2 ¿Cómo va a llegar la página a la Pi?**
- **Opción A (recomendada):** la Pi tiene internet un rato (cable al router de la casa o al
  WiFi del celular) y hace `git clone` del repo. El repo es **público** (D-12), no pide credenciales.
- **Opción B:** desde la laptop, con `scp`, copiando `servidor/` al home de la Pi.

Las dos funcionan; la guía usa la A y deja la B en §6.4.

---

## 2. Paso 1 — Grabar la microSD

1. Instala **Raspberry Pi Imager** (raspberrypi.com/software) en la laptop.
2. `Choose device` → **Raspberry Pi 4**.
3. `Choose OS` → **Raspberry Pi OS (other)** → **Raspberry Pi OS Lite (64-bit)**.
   - Debe decir **Debian 13 (trixie)**. Si dice *Bookworm*, estás usando una imagen vieja:
     descarga la actual. La de octubre 2026 es la vigente.
   - **Lite = sin escritorio.** Con 2 GB de RAM no queremos entorno gráfico.
4. `Choose storage` → tu microSD. **Ojo: se borra completa.**
5. Botón del engranaje ⚙️ (**Edit Settings**) → pestaña **General**:
   - `Set hostname` → **`campus-sur`**
   - `Set username and password` → usuario propio (ej. `dharly`) y contraseña que recuerdes.
     En Trixie **ya no existe** el usuario `pi`/`raspberry` por defecto.
   - `Configure wireless LAN` → **NO**. La Pi va por cable. Si configuras WiFi aquí, después
     tienes dos rutas y el servidor responde por la interfaz equivocada (trampa P-4).
   - `Set locale settings` → `America/Guatemala`, teclado `us` (o el que uses).
6. Pestaña **Services** → **Enable SSH** → *Use password authentication*. **Esto es obligatorio**
   si no vas a conectar monitor.
7. `Save` → `Write` → espera → `Continue`. Saca la SD de la laptop.

> **Trampa clásica:** el método viejo de crear `wpa_supplicant.conf` en la partición de arranque
> **ya no funciona** desde Bookworm. Y en Bookworm/Trixie la partición de arranque se llama
> `/boot/firmware`, no `/boot`. Si algún tutorial te dice lo contrario, es viejo.

---

## 3. Paso 2 — Primer arranque y acceso por SSH

1. Pon la microSD en la Pi.
2. Conecta el **cable Ethernet a un router que reparta DHCP** (el de tu casa, o el `hAP-3B` si
   tiene DHCP activo). **No** conectes todavía el cable al puerto definitivo si no sabes si
   reparte IP — primero queremos entrar, después fijamos la IP.
3. Conecta la **fuente oficial de 5 V / 3 A** al puerto USB-C. La Pi arranca sola (LED verde
   parpadeando = actividad de SD).
4. Espera **90 segundos** (el primer arranque es lento: expande el sistema de archivos).
5. Desde la laptop, busca la Pi:

```bash
ping -c 3 campus-sur.local
```

- Si responde → ya estás dentro del camino.
- Si dice *"no se pudo resolver"* → busca la IP en la tabla DHCP del router, o:

```bash
# Windows (PowerShell)
arp -a | Select-String "b8-27-eb|dc-a6-32|e4-5f-01|2c-cf-67"
# Linux / macOS
arp -a | grep -i "b8:27:eb\|dc:a6:32\|e4:5f:01\|2c:cf:67"
```

6. Entra:

```bash
ssh dharly@campus-sur.local
```

La primera vez pregunta por la huella (`yes`) y pide la contraseña (no se ve al escribir: es normal).

**✅ Verificación:** el prompt cambia a algo como `dharly@campus-sur:~ $`.

---

## 4. Paso 3 — Actualizar el sistema

```bash
sudo apt update
sudo apt full-upgrade -y
sudo reboot
```

Espera 60 s y vuelve a entrar por SSH.

```bash
cat /etc/os-release | grep -E "^(PRETTY_NAME|VERSION_CODENAME)"
uname -r
```

**✅ Verificación:** `PRETTY_NAME` dice **Debian GNU/Linux 13 (trixie)** (o 12 bookworm, ambas
sirven) y `uname -r` muestra un kernel 6.x.

---

## 5. Paso 4 — Instalar nginx, la página y la configuración

### 5.1 nginx

```bash
sudo apt install -y nginx
```

### 5.2 Traer el repo (Opción A)

```bash
sudo apt install -y git
sudo git clone https://github.com/andregil003/campus-unis-dcn2.git /opt/campus-unis
```

**✅ Verificación:** `ls /opt/campus-unis/servidor` muestra `html  linux  windows  README.md`.

### 5.3 Copiar la página y el sitio

```bash
sudo mkdir -p /var/www/campus
sudo cp /opt/campus-unis/servidor/html/sur/index.html /var/www/campus/index.html
sudo cp /opt/campus-unis/servidor/linux/campus-unis.conf /etc/nginx/sites-available/campus
sudo ln -sf /etc/nginx/sites-available/campus /etc/nginx/sites-enabled/campus
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
```

**✅ Verificación:** `nginx -t` debe decir exactamente:

```
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

> **Si `nginx -t` falla con `"user" directive is not allowed here`** estás usando un
> `campus-unis.conf` viejo (era un `nginx.conf` completo). Vuelve a clonar el repo: el archivo
> ya está corregido como archivo de sitio. Ver trampa **P-7**.

```bash
sudo systemctl restart nginx
sudo systemctl status nginx --no-pager
```

**✅ Verificación:** `Active: active (running)`.

### 5.4 Probar localmente (todavía sin IP fija)

```bash
curl -sI http://127.0.0.1/ | head -1
curl -s  http://127.0.0.1/health
curl -s  http://127.0.0.1/ | grep -o "Sede Sur" | head -1
```

**✅ Verificación esperada, línea por línea:**

```
HTTP/1.1 200 OK
ok
Sede Sur
```

Si `grep` no imprime `Sede Sur`, copiaste la página de Norte por error: repite §5.3.

### 5.5 Copiar los archivos sin internet en la Pi (Opción B, solo si aplica)

Desde la **laptop**, dentro del repo clonado:

```bash
scp servidor/html/sur/index.html dharly@campus-sur.local:/tmp/index.html
scp servidor/linux/campus-unis.conf dharly@campus-sur.local:/tmp/campus-unis.conf
```

Y en la **Pi**:

```bash
sudo cp /tmp/index.html /var/www/campus/index.html
sudo cp /tmp/campus-unis.conf /etc/nginx/sites-available/campus
sudo ln -sf /etc/nginx/sites-available/campus /etc/nginx/sites-enabled/campus
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl restart nginx
```

---

## 6. Paso 5 — IP fija `10.20.0.100` (S-01)

> ⚠️ **Haz este paso con el cable conectado al `hAP-3B` ether3, no al router de la casa.**
> Al pasar a IP fija, la IP vieja desaparece y tu sesión SSH se corta. Es normal: reconectas
> con la IP nueva. Si te quedas sin acceso, el plan B está en §11.1.

### 6.1 Ver el nombre exacto de la conexión

```bash
nmcli -t -f NAME,DEVICE connection show
```

Sale algo como `Wired connection 1:eth0`. **Ese nombre es el que va en el comando siguiente**
(si el tuyo es distinto, cámbialo).

### 6.2 Aplicar la IP fija

```bash
CON="Wired connection 1"
sudo nmcli con mod "$CON" ipv4.method manual
sudo nmcli con mod "$CON" ipv4.addresses 10.20.0.100/24
sudo nmcli con mod "$CON" ipv4.gateway 10.20.0.1
sudo nmcli con mod "$CON" ipv4.dns 10.20.255.1
sudo nmcli con mod "$CON" ipv4.ignore-auto-dns yes
sudo nmcli con up "$CON"
```

### 6.3 Verificar

```bash
ip -4 addr show eth0 | grep inet
ip route | grep default
ping -c 2 10.20.0.1
```

**✅ Verificación esperada:**

```
inet 10.20.0.100/24 brd 10.20.0.255 scope global noprefixroute eth0
default via 10.20.0.1 dev eth0 proto static metric 100
2 packets transmitted, 2 received, 0% packet loss
```

### 6.4 Reconectar por SSH

```bash
ssh dharly@10.20.0.100
```

**✅ Verificación:** entras con la IP nueva. Ya cumples **S-01**.

---

## 7. Paso 6 — Firewall

En Raspberry Pi OS Lite **ufw no viene instalado**, y por defecto nftables no bloquea nada
entrante: el puerto 80 ya está abierto. Solo hay que actuar **si ufw está presente y activo**.

```bash
sudo ufw status
```

- Si dice `Status: inactive` o `command not found` → **no hagas nada**, no bloquea. Sigue al §8.
- Si dice `Status: active` → abre el puerto:

```bash
sudo ufw allow 80/tcp
sudo ufw status numbered
```

**✅ Verificación:** aparece una regla `80/tcp  ALLOW  Anywhere`.

> No abras SSH a medias: si ufw está activo y cierras la sesión sin `ufw allow 22/tcp`,
> te quedas fuera. Ya está permitido si entraste por SSH con ufw activo, pero verifícalo.

---

## 8. Paso 7 — Arranque automático (S-06)

```bash
sudo systemctl enable nginx
systemctl is-enabled nginx
```

**✅ Verificación:** imprime `enabled`.

Opcional pero recomendado, para que el arranque no dependa de la red:

```bash
sudo systemctl enable systemd-timesyncd
timedatectl | grep -E "synchronized|Time zone"
```

**✅ Verificación:** `System clock synchronized: yes` y zona `America/Guatemala`.

### 8.1 La prueba que vale (S-06 de verdad)

No basta con `enabled`: hay que simular el corte de energía.

1. Con la Pi sirviendo (ya con IP fija), **desenchufa la fuente** directamente.
2. Espera 10 segundos.
3. Enchufa de nuevo. **No toques nada más.**
4. Espera **90 segundos**.
5. Desde la laptop:

```bash
curl -sI http://10.20.0.100/ | head -1
curl -s  http://10.20.0.100/health
```

**✅ Verificación:** `HTTP/1.1 200 OK` y `ok`, sin haber entrado por SSH ni iniciado sesión.

> Este paso también te dice si la fuente es insuficiente: si la Pi no vuelve o se reinicia en
> bucle, revisa la trampa **P-1**.

---

## 9. Paso 8 — Verificación completa (S-01…S-06)

```bash
chmod +x /opt/campus-unis/servidor/linux/verificar.sh
/opt/campus-unis/servidor/linux/verificar.sh 10.20.0.100 10.10.0.100
```

Salida esperada (los últimos dos pueden dar FAIL si Norte todavía no está montado — ver nota):

```
== Verificación del servidor 10.20.0.100 ==
PASS  S-01   IP 10.20.0.100 presente en el equipo
PASS  S-02a  puerto 80 en escucha
PASS  S-02b  HTTP GET / -> 200
PASS  S-03   página identifica la sede
PASS  S-04   /health -> 200 'ok'
PASS  S-05a  ping a 10.10.0.100
PASS  S-05b  HTTP /health a 10.10.0.100 -> 200
PASS  S-06   nginx habilitado en el arranque (enabled)
INFO  NTP    System clock synchronized: yes
TODO OK
```

**Cómo leerlo:**

| Resultado | Significado | Acción |
|---|---|---|
| `S-01…S-04`, `S-06` en PASS | El servidor de Sur está listo | ✅ |
| `S-05a` / `S-05b` en FAIL | Norte no está montado o el enlace inter-sede está caído | Se reintenta cuando Norte esté arriba; **no es falla de Sur** |
| Cualquier otro FAIL | Es de Sur | Ver §11 |

Si el script no está (Opción B sin repo), verifica a mano:

```bash
ip -4 addr show eth0 | grep 10.20.0.100
curl -sI http://10.20.0.100/ | head -1
curl -s  http://10.20.0.100/health
systemctl is-enabled nginx
```

---

## 10. Paso 9 — Prueba cruzada (S-05, T-1/T-2)

Estas dos pruebas necesitan **las dos sedes encendidas y el enlace inter-sede arriba**.

| Prueba | Desde | Comando | Esperado |
|---|---|---|---|
| T-2 | la Pi de Sur | `curl -sI http://10.10.0.100/ \| head -1` | `HTTP/1.1 200 OK` |
| T-1 | la laptop de Norte | `curl -sI http://10.20.0.100/ \| head -1` | `HTTP/1.1 200 OK` |

Si el `ping` llega pero el HTTP no, el sospechoso número uno es el **firewall del servidor**
(`ufw` en Sur, W-1 en Norte), no el ruteo. Ver [`docs/08-SERVIDOR.md`](08-SERVIDOR.md) §4.

---

## 11. Evidencia que hay que entregar

Corre esto y **captura la salida completa** (o pégala en el chat del grupo):

```bash
{
  echo "=== FECHA ===";        date
  echo "=== SISTEMA ===";      cat /etc/os-release | head -2; uname -r
  echo "=== IP ===";           ip -4 addr show eth0 | grep inet; ip route | grep default
  echo "=== NGINX ===";        nginx -v 2>&1; systemctl is-enabled nginx; systemctl is-active nginx
  echo "=== HTTP ===";         curl -sI http://10.20.0.100/ | head -1
  echo "=== HEALTH ===";       curl -s http://10.20.0.100/health
  echo "=== SEDE ===";         curl -s http://10.20.0.100/ | grep -o "Sede Sur" | head -1
  echo "=== FIREWALL ===";     sudo ufw status
  echo "=== RELOJ ===";        timedatectl | grep -E "synchronized|Time zone"
  echo "=== VOLTAJE ===";      vcgencmd get_throttled
  echo "=== VERIFICAR ===";    /opt/campus-unis/servidor/linux/verificar.sh 10.20.0.100 10.10.0.100
} 2>&1 | tee ~/evidencia-sur.txt
```

Y una **foto** de: la Pi encendida con el cable en `hAP-3B ether3`, y la pantalla del celular
o laptop mostrando `http://10.20.0.100` en el navegador.

**Checklist de entrega:**

- [ ] `~/evidencia-sur.txt` completo
- [ ] Foto del `curl` a `http://10.20.0.100/health` devolviendo `ok`
- [ ] Foto del cable en `hAP-3B ether3`
- [ ] `vcgencmd get_throttled` = `throttled=0x0`
- [ ] Prueba de corte de energía hecha (§8.1)
- [ ] T-2 (Sur → Norte) y T-1 (Norte → Sur) con `200 OK`

---

## 12. Trampas de la Raspberry Pi (esto es lo que hunde la demo)

| Id | Riesgo | Cómo se detecta | Mitigación |
|---|---|---|---|
| **P-1** | **Fuente débil** (cargador de celular de 5 V/2 A): reinicios aleatorios, SD corrupta | `vcgencmd get_throttled` ≠ `0x0`; LED rojo intermitente | Fuente oficial 5 V/3 A. Es el requisito de la ficha de la Pi 4 |
| **P-2** | **microSD barata o lenta**: se cuelga al escribir logs | `dmesg \| grep -i mmc`; el sistema se congela | SD clase 10 / A1 de marca. Apagar siempre con `sudo shutdown -h now` |
| **P-3** | **ufw activo** bloquea el 80 sin avisar | `ufw status` = active sin regla 80 | `sudo ufw allow 80/tcp` |
| **P-4** | **WiFi + Ethernet a la vez**: dos rutas, responde por la interfaz equivocada | `ip route` con dos `default` | `sudo nmcli radio wifi off` y borra la conexión WiFi |
| **P-5** | **IP duplicada** `10.20.0.100` | `arping 10.20.0.100` responde desde otra MAC | Una sola máquina con esa IP encendida |
| **P-6** | Sigue la página *"Welcome to nginx"* | `curl /` no dice `Sede Sur` | Falta `rm /etc/nginx/sites-enabled/default` |
| **P-7** | `nginx -t` → `"user" directive is not allowed here` | error explícito | `campus-unis.conf` viejo (era un nginx.conf completo). Reclonar el repo |
| **P-8** | Tutoriales viejos de WiFi/SSH | `wpa_supplicant.conf` no hace nada; `/boot/ssh` no existe | En Trixie: Imager → Services → SSH. Partición `/boot/firmware` |
| **P-9** | **Reloj desfasado** → logs sin valor probatorio | `timedatectl` → `synchronized: no` | `systemd-timesyncd` activo (viene por defecto) |
| **P-10** | Cable malo / puerto equivocado | `ip -br link` dice `NO-CARRIER` en eth0 | Probar otro cable; el puerto es `hAP-3B` **ether3** |
| **P-11** | Desenchufar sin apagar → SD corrupta | no arranca tras el corte | `sudo shutdown -h now` antes de mover la Pi |
| **P-12** | Alimentar por GPIO en vez de USB-C | no arranca o arranca inestable | Solo USB-C con la fuente oficial |

---

## 13. Si algo falla

### 13.1 Me quedé sin SSH después de la IP fija

1. Conecta la Pi a un monitor con **micro-HDMI** (la Pi 4 usa micro-HDMI, no HDMI normal) y teclado USB.
2. Entra con tu usuario y contraseña.
3. Devuelve la interfaz a DHCP:

```bash
sudo nmcli con mod "Wired connection 1" ipv4.method auto
sudo nmcli con mod "Wired connection 1" ipv4.addresses ""
sudo nmcli con mod "Wired connection 1" ipv4.gateway ""
sudo nmcli con up "Wired connection 1"
```

4. Repite §6 con el cable ya en el `hAP-3B`.

### 13.2 Tabla síntoma → causa → arreglo

| Síntoma | Causa más probable | Arreglo |
|---|---|---|
| `ping 10.20.0.100` sin respuesta desde la Pi misma | IP no aplicada | `nmcli con show "Wired connection 1" \| grep ipv4` |
| La Pi no aparece en la red | Cable en puerto sin DHCP / `NO-CARRIER` | Otro cable, otro puerto, revisar LED del puerto |
| `curl /` → 200 pero página de nginx | sitio `default` activo | `sudo rm -f /etc/nginx/sites-enabled/default && sudo systemctl reload nginx` |
| `curl /health` → 404 | falta el `location = /health` | `sudo nginx -T \| grep health` para confirmar qué config está cargada |
| Acentos rotos en el navegador | `charset` ausente | ya está en `campus-unis.conf`; `sudo nginx -t && sudo systemctl reload nginx` |
| `curl` a Norte da timeout pero `ping` funciona | firewall de Norte (W-1) | avisar a André: regla TCP 80 entrante en Windows |
| `curl` a Norte da timeout y `ping` tampoco | enlace inter-sede / OSPF caído | es de routers, no de la Pi |
| La Pi no vuelve tras el corte | fuente débil (P-1) | fuente 5 V/3 A |
| `systemctl is-enabled nginx` → `disabled` | faltó el `enable` | `sudo systemctl enable nginx` |

---

## 14. Si la Pi no arranca el día de la defensa

No se improvisa: está el procedimiento de respaldo en
[`servidor/README.md`](../servidor/README.md) §4. Cualquier computadora con Linux o Windows
puede reemplazarla en ≤ 5 minutos **con la misma IP `10.20.0.100`**, porque el estándar es por
comportamiento (S-01…S-06) y no por sistema operativo.

**Regla que no se rompe:** nunca dos máquinas con `10.20.0.100` encendidas a la vez. Primero se
desconecta el cable de la que falló.

---

## 15. Referencias

- Estándar de comportamiento S-01…S-06 → [`docs/08-SERVIDOR.md`](08-SERVIDOR.md) §1
- Direccionamiento → [`docs/01-TABLA-IPs.md`](01-TABLA-IPs.md) §2
- Pruebas cruzadas T-1…T-5 → [`docs/08-SERVIDOR.md`](08-SERVIDOR.md) §4
- Despliegue y respaldo → [`servidor/README.md`](../servidor/README.md)
- Config del sitio → [`servidor/linux/campus-unis.conf`](../servidor/linux/campus-unis.conf)
- Página de Sur → [`servidor/html/sur/index.html`](../servidor/html/sur/index.html)
- Script de verificación → [`servidor/linux/verificar.sh`](../servidor/linux/verificar.sh)
