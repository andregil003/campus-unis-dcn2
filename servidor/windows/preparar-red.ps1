<#
  Preparacion de red del servidor de Sede Norte - Campus UNIS (DCN2)

  Deja la NIC Ethernet lista para el ensayo con el hAP-1A:
    1. revisa que el cable este puesto
    2. marca la red como Privada (Windows la pone en Publica y bloquea el puerto 80)
    3. asegura la regla de firewall TCP 80
    4. asegura IP estatica, gateway y DNS del estandar S-01
    5. asegura que nginx este escuchando (tarea "Campus UNIS nginx")
    6. corre la verificacion S-01..S-06

  Es idempotente: se puede correr las veces que haga falta.

  Uso (PowerShell como Administrador):
    powershell -ExecutionPolicy Bypass -File preparar-red.ps1
    powershell -ExecutionPolicy Bypass -File preparar-red.ps1 -Interface "Ethernet" -IP 10.10.0.100
    powershell -ExecutionPolicy Bypass -File preparar-red.ps1 -SkipVerify

  Revertir:
    netsh interface ip set address name="Ethernet" dhcp
    netsh interface ip set dns     name="Ethernet" dhcp
#>
param(
  [string]$Interface = "Ethernet",
  [string]$IP        = "10.10.0.100",
  [int]   $Prefix    = 24,
  [string]$Gateway   = "10.10.0.1",
  [string]$DNS       = "10.10.255.1",
  [string]$Peer      = "10.20.0.100",
  [int]   $Metric    = 10,
  [switch]$SkipVerify
)

$ErrorActionPreference = "Continue"

function Paso($n, $txt) { Write-Host ""; Write-Host "[$n] $txt" -ForegroundColor Cyan }
function OK($txt)   { Write-Host "    OK    $txt" -ForegroundColor Green }
function AVISO($txt){ Write-Host "    AVISO $txt" -ForegroundColor Yellow }
function FALLO($txt){ Write-Host "    FALLO $txt" -ForegroundColor Red }

function Get-Mascara([int]$p) {
  $bits = ('1' * $p) + ('0' * (32 - $p))
  $partes = @()
  for ($i = 0; $i -lt 32; $i += 8) { $partes += [Convert]::ToInt32($bits.Substring($i, 8), 2) }
  return ($partes -join '.')
}

# ------------------------------------------------------------------ 0. admin
$identidad = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identidad)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  FALLO "Este script necesita PowerShell como Administrador."
  exit 1
}

$bloqueos = @()

# ------------------------------------------------------- 1. adaptador y cable
Paso 1 "Adaptador '$Interface'"
$nic = Get-NetAdapter -Name $Interface -ErrorAction SilentlyContinue
if (-not $nic) {
  FALLO "No existe un adaptador llamado '$Interface'. Adaptadores disponibles:"
  Get-NetAdapter | Select-Object Name, Status | Format-Table -AutoSize
  exit 1
}
OK "$($nic.InterfaceDescription)"
OK "estado: $($nic.Status)  velocidad: $($nic.LinkSpeed)"

if ($nic.Status -ne "Up") {
  AVISO "El enlace esta caido: no hay cable, o el hAP-1A esta apagado."
  AVISO "Conecta el cable a hAP-1A puerto ether3 para que S-01, S-02b, S-04 y S-05 pasen."
  $bloqueos += "cable Ethernet -> hAP-1A ether3"
}

# ------------------------------------------- 2. red como Privada (trampa W-1)
Paso 2 "Marcar la red como Privada (W-1: en Publica el firewall bloquea el 80)"
if ($nic.Status -ne "Up") {
  AVISO "sin enlace no hay perfil de red que cambiar. Se omite por ahora."
  $bloqueos += "red marcada como Privada"
} else {
  $perfil = $null
  for ($i = 0; $i -lt 5 -and -not $perfil; $i++) {
    $perfil = Get-NetConnectionProfile -InterfaceAlias $Interface -ErrorAction SilentlyContinue
    if (-not $perfil) { Start-Sleep -Seconds 2 }
  }
  if (-not $perfil) {
    AVISO "Windows aun no identifica la red. Espera unos segundos y vuelve a correr el script."
    $bloqueos += "red marcada como Privada"
  } elseif ($perfil.NetworkCategory -eq "Private") {
    OK "ya estaba en Privada"
  } else {
    Set-NetConnectionProfile -InterfaceAlias $Interface -NetworkCategory Private -ErrorAction SilentlyContinue
    $despues = Get-NetConnectionProfile -InterfaceAlias $Interface -ErrorAction SilentlyContinue
    if ($despues.NetworkCategory -eq "Private") {
      OK "cambiada de $($perfil.NetworkCategory) a Privada"
    } else {
      FALLO "no se pudo cambiar (sigue en $($despues.NetworkCategory))"
      $bloqueos += "red marcada como Privada"
    }
  }
}

# ------------------------------------------ 3. regla de firewall para el :80
Paso 3 "Regla de firewall entrante TCP 80"
$nombreRegla = "Campus UNIS nginx 80"
$regla = Get-NetFirewallRule -DisplayName $nombreRegla -ErrorAction SilentlyContinue
if ($regla) {
  OK "ya existe (perfiles: $($regla.Profile), habilitada: $($regla.Enabled))"
} else {
  New-NetFirewallRule -DisplayName $nombreRegla `
    -Description "Servidor Sede Norte - nginx puerto 80 (proyecto DCN2)" `
    -Direction Inbound -Protocol TCP -LocalPort 80 -Action Allow `
    -Profile Private, Domain -ErrorAction SilentlyContinue | Out-Null
  if (Get-NetFirewallRule -DisplayName $nombreRegla -ErrorAction SilentlyContinue) {
    OK "creada"
  } else {
    FALLO "no se pudo crear la regla"
    $bloqueos += "regla de firewall :80"
  }
}

# ------------------------------------------------- 4. IP estatica, gw y DNS (S-01)
Paso 4 "IP estatica $IP/$Prefix  gw $Gateway  dns $DNS"
$mascara = Get-Mascara $Prefix
$actual = Get-NetIPAddress -InterfaceAlias $Interface -AddressFamily IPv4 -ErrorAction SilentlyContinue |
          Where-Object { $_.IPAddress -eq $IP }
if ($actual) {
  OK "IP ya asignada ($($actual.IPAddress)/$($actual.PrefixLength))"
} else {
  netsh interface ip set address name="$Interface" static $IP $mascara $Gateway | Out-Null
  if (Get-NetIPAddress -InterfaceAlias $Interface -AddressFamily IPv4 -ErrorAction SilentlyContinue |
      Where-Object { $_.IPAddress -eq $IP }) {
    OK "IP asignada"
  } else {
    FALLO "no se pudo asignar la IP"
    $bloqueos += "IP $IP"
  }
}

Set-NetIPInterface -InterfaceAlias $Interface -AddressFamily IPv4 -Dhcp Disabled -ErrorAction SilentlyContinue
OK "DHCP deshabilitado en la interfaz (no puede pisar la IP estatica)"

Set-NetIPInterface -InterfaceAlias $Interface -AddressFamily IPv4 -InterfaceMetric $Metric -ErrorAction SilentlyContinue
OK "metrica de interfaz = $Metric (gana sobre el WiFi cuando hay cable)"

$dnsActual = (Get-DnsClientServerAddress -InterfaceAlias $Interface -AddressFamily IPv4 -ErrorAction SilentlyContinue).ServerAddresses
if ($dnsActual -contains $DNS) {
  OK "DNS $DNS ya configurado"
} else {
  netsh interface ip set dns name="$Interface" static $DNS | Out-Null
  OK "DNS $DNS configurado"
}

# ------------------------------------------------ 5. nginx (S-02a) y arranque (S-06)
Paso 5 "nginx en el puerto 80 y arranque automatico (S-06)"
$tarea = Get-ScheduledTask -TaskName "Campus UNIS nginx" -ErrorAction SilentlyContinue
if ($tarea) {
  OK "tarea 'Campus UNIS nginx' presente ($($tarea.State))"
} else {
  AVISO "no existe la tarea; se crea ahora"
  $accion   = New-ScheduledTaskAction -Execute "C:\nginx\nginx.exe" -WorkingDirectory "C:\nginx"
  $disparo  = New-ScheduledTaskTrigger -AtStartup
  $cuenta   = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
  $ajustes  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
                -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 3 `
                -RestartInterval (New-TimeSpan -Minutes 1) -StartWhenAvailable
  Register-ScheduledTask -TaskName "Campus UNIS nginx" `
    -Description "Servidor Sede Norte (DCN2) - nginx puerto 80" `
    -Action $accion -Trigger $disparo -Principal $cuenta -Settings $ajustes -Force -ErrorAction SilentlyContinue | Out-Null
  if (Get-ScheduledTask -TaskName "Campus UNIS nginx" -ErrorAction SilentlyContinue) { OK "tarea creada" }
  else { FALLO "no se pudo crear la tarea"; $bloqueos += "tarea de arranque" }
}

$escucha = Get-NetTCPConnection -LocalPort 80 -State Listen -ErrorAction SilentlyContinue
if ($escucha) {
  OK "puerto 80 escuchando (PID $($escucha[0].OwningProcess))"
} else {
  AVISO "nadie escucha en el 80; arrancando nginx por la tarea"
  Start-ScheduledTask -TaskName "Campus UNIS nginx" -ErrorAction SilentlyContinue
  Start-Sleep -Seconds 4
  $escucha = Get-NetTCPConnection -LocalPort 80 -State Listen -ErrorAction SilentlyContinue
  if ($escucha) { OK "puerto 80 escuchando (PID $($escucha[0].OwningProcess))" }
  else { FALLO "nginx no arranco"; $bloqueos += "nginx escuchando en :80" }
}

# ------------------------------------------------------ 6. verificacion S-01..S-06
Paso 6 "Verificacion S-01..S-06"
if ($SkipVerify) {
  AVISO "omitida (-SkipVerify)"
} else {
  $verificador = Join-Path $PSScriptRoot "verificar.ps1"
  if (Test-Path $verificador) {
    & powershell -ExecutionPolicy Bypass -File $verificador -IP $IP -Peer $Peer -DNS $DNS
  } else {
    AVISO "no se encontro verificar.ps1 junto a este script"
  }
}

# ------------------------------------------------------------------- resumen
Write-Host ""
if ($bloqueos.Count -eq 0) {
  Write-Host "Sin bloqueos conocidos: la maquina esta lista para el ensayo." -ForegroundColor Green
  exit 0
} else {
  Write-Host "Pendiente para cerrar el ensayo:" -ForegroundColor Yellow
  foreach ($b in ($bloqueos | Select-Object -Unique)) { Write-Host "  - $b" -ForegroundColor Yellow }
  exit 2
}
