# Servidor de sede — despliegue y respaldo en cualquier computadora

Estándar: `docs/00-ESTANDARES.md` §E-08 (S-01…S-06) · Diseño: `docs/08-SERVIDOR.md`.
Este directorio es **portable**: copiarlo a cualquier PC con Windows o Linux y el servidor funciona igual.

```
servidor/
├─ html/index.html            página de la sede (compartida por ambas plataformas)
├─ windows/nginx.conf         config lista para nginx/Windows
├─ windows/verificar.ps1      verificación S-01…S-06 desde Windows
└─ linux/campus-unis.conf     config para nginx de Linux / Raspberry Pi
    linux/verificar.sh        verificación S-01…S-06 desde Linux
```

> **Norte** usa Windows (laptop). **Sur** usa Raspberry Pi 4. El procedimiento de respaldo (§4) sirve para
> cualquiera de las dos sedes: si un servidor falla, se levanta otra computadora con este mismo directorio.

---

## 1. Despliegue en Windows

```powershell
# 1. nginx oficial para Windows (zip) -> descomprimir en C:\nginx
# 2. copiar los archivos del repo
Copy-Item servidor\windows\nginx.conf C:\nginx\conf\nginx.conf -Force
Copy-Item servidor\html\index.html   C:\nginx\html\index.html -Force

# 3. IP fija (adaptar el nombre de la interfaz: Get-NetAdapter)
netsh interface ip set address name="Ethernet" static 10.10.0.100 255.255.255.0 10.10.0.1
netsh interface ip set dns     name="Ethernet" static 10.10.255.1

# 4. firewall: permitir 80 entrante
New-NetFirewallRule -DisplayName "Campus UNIS nginx 80" -Direction Inbound `
  -Protocol TCP -LocalPort 80 -Action Allow -Profile Private,Domain

# 5. arrancar (desde C:\nginx)
Start-Process .\nginx.exe
#    detener / recargar:
#    .\nginx.exe -s stop    ·    .\nginx.exe -s reload

# 6. verificar
powershell -ExecutionPolicy Bypass -File servidor\windows\verificar.ps1
```

**Arranque automático (S-06):** registrar nginx como servicio con NSSM o WinSW, o crear una tarea programada
"Al iniciar el sistema" que ejecute `C:\nginx\nginx.exe`. Sin esto, un corte de energía deja el servidor apagado.

**No olvidar:** plan de energía en "Nunca suspender", WiFi deshabilitado y red marcada como *Privada*.

---

## 2. Despliegue en Linux / Raspberry Pi

```bash
sudo apt update && sudo apt install -y nginx
sudo mkdir -p /var/www/campus
sudo cp servidor/html/index.html /var/www/campus/
sudo cp servidor/linux/campus-unis.conf /etc/nginx/sites-available/campus
sudo ln -sf /etc/nginx/sites-available/campus /etc/nginx/sites-enabled/campus
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl enable --now nginx
chmod +x servidor/linux/verificar.sh && ./servidor/linux/verificar.sh 10.20.0.100 10.10.0.100
```

IP fija en Raspberry Pi OS (Bookworm, NetworkManager):

```bash
sudo nmcli con mod "Wired connection 1" ipv4.method manual \
  ipv4.addresses 10.20.0.100/24 ipv4.gateway 10.20.0.1 ipv4.dns 10.20.255.1
sudo nmcli con up "Wired connection 1"
```

---

## 3. Comprobación rápida desde cualquier equipo

```bash
curl -I http://10.10.0.100          # 200
curl    http://10.10.0.100/health   # ok
curl -I http://10.20.0.100          # 200
```

---

## 4. Respaldo: levantar otra computadora (procedimiento de 5 minutos)

Se usa si el servidor de la sede no arranca o no responde durante la preparación o la defensa.
Aplica a Norte (otra laptop Windows) y a Sur (otra PC con Linux o Windows).

| Paso | Acción | Tiempo |
|---|---|---|
| 1 | Copiar la carpeta `servidor/` a la computadora de respaldo (USB o repo ya clonado) | 30 s |
| 2 | Instalar nginx (zip en Windows / `apt install nginx` en Linux) | 60 s |
| 3 | Copiar config + `index.html` según §1 o §2 | 30 s |
| 4 | Asignar **la misma IP** del servidor caído (`10.10.0.100` o `10.20.0.100`) | 60 s |
| 5 | Abrir el puerto 80 en el firewall de esa máquina | 30 s |
| 6 | Arrancar nginx y ejecutar el script de verificación | 60 s |
| 7 | **Desconectar el cable del servidor caído y conectarlo al de respaldo** | 30 s |
| 8 | `curl` cruzado desde la otra sede para confirmar | 30 s |

### Reglas del respaldo

1. **Nunca dos máquinas con la misma IP al mismo tiempo.** Primero se desconecta el cable del que falló,
   después se conecta el de respaldo. IP duplicada rompe ARP y tumba el segmento.
2. La máquina de respaldo debe estar **probada antes** de la defensa: no se estrena hardware en vivo.
3. Si la máquina de respaldo es Windows, aplican las mismas trampas de `docs/08-SERVIDOR.md` §2.3
   (firewall, suspensión, doble NIC, arranque automático).
4. Si se cambia de plataforma (Linux → Windows o al revés), no cambia nada de la red: misma IP, mismo puerto,
   mismo `/health`. Por eso el estándar es por comportamiento y no por sistema operativo.

---

## 5. Qué NO hace este servidor

- No hace DNS: el DNS filtrado es exclusivo del container del RB5009 (Pi-hole / AdGuard).
- No hace NAT ni ruteo: eso es del gateway de la sede.
- No es un servidor de archivos para el equipo: solo publica la página institucional y `/health`.
