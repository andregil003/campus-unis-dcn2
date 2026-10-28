<#
  Verificación del servidor de sede (S-01..S-06) desde Windows.
  Uso:
    powershell -ExecutionPolicy Bypass -File verificar.ps1
    powershell -ExecutionPolicy Bypass -File verificar.ps1 -IP 10.20.0.100 -Peer 10.10.0.100
#>
param(
  [string]$IP   = "10.10.0.100",
  [string]$Peer = "10.20.0.100",
  [string]$DNS  = "10.10.255.1"
)

$ErrorActionPreference = "Continue"
$resultados = @()

function Registrar($id, $prueba, $ok, $detalle) {
  $script:resultados += [pscustomobject]@{
    Id      = $id
    Prueba  = $prueba
    Estado  = if ($ok) { "PASS" } else { "FAIL" }
    Detalle = $detalle
  }
}

Write-Host "== Verificacion del servidor $IP ==" -ForegroundColor Cyan

# S-01 · IP fija configurada en esta maquina
$ips = Get-NetIPAddress -AddressFamily IPv4 | Select-Object -ExpandProperty IPAddress
Registrar "S-01" "IP $IP presente en el equipo" ($ips -contains $IP) ($ips -join ", ")

# S-02 · nginx escuchando en :80
$escucha = Get-NetTCPConnection -LocalPort 80 -State Listen -ErrorAction SilentlyContinue
Registrar "S-02a" "Puerto 80 en escucha" ([bool]$escucha) $(if ($escucha) { "PID " + (($escucha | Select-Object -ExpandProperty OwningProcess) -join ",") } else { "nadie escucha en 80" })

try {
  $r = Invoke-WebRequest -Uri "http://$IP/" -UseBasicParsing -TimeoutSec 5
  Registrar "S-02b" "HTTP GET / responde 200" ($r.StatusCode -eq 200) "status $($r.StatusCode)"
  # S-03 · pagina identificable
  Registrar "S-03" "Pagina menciona la sede" ($r.Content -match "Sede Norte|Sede Sur") "len $($r.Content.Length)"
} catch {
  Registrar "S-02b" "HTTP GET / responde 200" $false $_.Exception.Message
  Registrar "S-03" "Pagina menciona la sede" $false "sin respuesta"
}

# S-04 · /health
try {
  $h = Invoke-WebRequest -Uri "http://$IP/health" -UseBasicParsing -TimeoutSec 5
  Registrar "S-04" "/health devuelve 200 + ok" (($h.StatusCode -eq 200) -and ($h.Content.Trim() -eq "ok")) "'$($h.Content.Trim())'"
} catch {
  Registrar "S-04" "/health devuelve 200 + ok" $false $_.Exception.Message
}

# S-05 · alcanzabilidad del peer
$ping = Test-Connection -ComputerName $Peer -Count 2 -Quiet -ErrorAction SilentlyContinue
Registrar "S-05a" "ping a $Peer" $ping "ICMP"
try {
  $c = Invoke-WebRequest -Uri "http://$Peer/health" -UseBasicParsing -TimeoutSec 5
  Registrar "S-05b" "HTTP /health a $Peer" ($c.StatusCode -eq 200) "'$($c.Content.Trim())'"
} catch {
  Registrar "S-05b" "HTTP /health a $Peer" $false $_.Exception.Message
}

# S-06 · nginx como servicio / tarea de arranque
$svc = Get-Service -Name "nginx*" -ErrorAction SilentlyContinue
$tarea = Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -match "nginx|campus" }
Registrar "S-06" "Arranque automatico configurado" (($svc -and $svc.Status -eq "Running") -or [bool]$tarea) `
  $(if ($svc) { "servicio " + ($svc.Name -join ",") + " -> " + ($svc.Status -join ",") } elseif ($tarea) { "tarea " + ($tarea.TaskName -join ",") } else { "sin servicio ni tarea" })

# Extra: regla de firewall para el puerto 80
$fw = @()
try {
  $fw = Get-NetFirewallRule -Direction Inbound -Enabled True -Action Allow -ErrorAction Stop |
        Where-Object { ($_ | Get-NetFirewallPortFilter -ErrorAction SilentlyContinue).LocalPort -eq 80 }
} catch { $fw = @() }
Registrar "W-1" "Regla de firewall entrante para :80" ([bool]$fw) $(if ($fw) { $fw.DisplayName -join ", " } else { "no hay regla explicita para el puerto 80" })

# Extra: DNS
try {
  $d = Resolve-DnsName -Name "prueba-dns.campus" -Server $DNS -ErrorAction Stop
  Registrar "DNS" "Resolver contra $DNS" $true (($d | Select-Object -First 1).IPAddress)
} catch {
  Registrar "DNS" "Resolver contra $DNS" $false $_.Exception.Message
}

# Extra: plan de energia (que no se suspenda)
$plan = powercfg /getactivescheme 2>$null
Write-Host "Plan de energia activo: $plan" -ForegroundColor DarkGray

$resultados | Format-Table -AutoSize
$fallos = ($resultados | Where-Object { $_.Estado -eq "FAIL" }).Count
Write-Host ""
if ($fallos -eq 0) {
  Write-Host "TODO OK ($($resultados.Count) comprobaciones)" -ForegroundColor Green
  exit 0
} else {
  Write-Host "$fallos comprobacion(es) en FAIL" -ForegroundColor Red
  exit 1
}
