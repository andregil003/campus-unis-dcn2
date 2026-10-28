#!/usr/bin/env bash
# Verificación del servidor de sede (S-01..S-06) desde Linux / Raspberry Pi OS.
# Uso: ./verificar.sh [IP_PROPIA] [IP_PEER]
set -u

IP="${1:-10.20.0.100}"
PEER="${2:-10.10.0.100}"
FALLOS=0

ok()   { printf 'PASS  %-6s %s\n' "$1" "$2"; }
fail() { printf 'FAIL  %-6s %s  (%s)\n' "$1" "$2" "${3:-}"; FALLOS=$((FALLOS+1)); }

echo "== Verificación del servidor $IP =="

# S-01 · IP presente en el equipo
if ip -4 addr show | grep -q "inet $IP/"; then
  ok "S-01" "IP $IP presente en el equipo"
else
  fail "S-01" "IP $IP presente en el equipo" "no está asignada"
fi

# S-02 · nginx escuchando (local, sin depender de la red)
if command -v ss >/dev/null 2>&1 && ss -ltn 2>/dev/null | grep -q ':80 '; then
  ok "S-02a" "puerto 80 en escucha"
elif command -v netstat >/dev/null 2>&1 && netstat -ltn 2>/dev/null | grep -q ':80 '; then
  ok "S-02a" "puerto 80 en escucha"
else
  fail "S-02a" "puerto 80 en escucha" "nadie escucha"
fi

# S-02b / S-03 · HTTP local
CODE=$(curl -s -o /tmp/_campus_index -w '%{http_code}' --max-time 5 "http://$IP/" || echo 000)
if [ "$CODE" = "200" ]; then ok "S-02b" "HTTP GET / -> 200"
else fail "S-02b" "HTTP GET / -> 200" "status $CODE"; fi

if grep -qiE 'Sede (Norte|Sur)' /tmp/_campus_index 2>/dev/null; then
  ok "S-03" "página identifica la sede"
else
  fail "S-03" "página identifica la sede" "contenido inesperado"
fi

# S-04 · /health
H=$(curl -s -w '|%{http_code}' --max-time 5 "http://$IP/health" || echo '|000')
HBODY="${H%|*}"; HCODE="${H#*|}"
if [ "$HCODE" = "200" ] && [ "$(printf '%s' "$HBODY" | tr -d '[:space:]')" = "ok" ]; then
  ok "S-04" "/health -> 200 'ok'"
else
  fail "S-04" "/health -> 200 'ok'" "status $HCODE cuerpo '$HBODY'"
fi

# S-05 · peer
if ping -c 2 -W 2 "$PEER" >/dev/null 2>&1; then ok "S-05a" "ping a $PEER"
else fail "S-05a" "ping a $PEER" "sin ICMP"; fi

PCODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "http://$PEER/health" || echo 000)
if [ "$PCODE" = "200" ]; then ok "S-05b" "HTTP /health a $PEER -> 200"
else fail "S-05b" "HTTP /health a $PEER -> 200" "status $PCODE"; fi

# S-06 · arranque automático
if systemctl is-enabled nginx >/dev/null 2>&1; then
  ok "S-06" "nginx habilitado en el arranque ($(systemctl is-enabled nginx))"
else
  fail "S-06" "nginx habilitado en el arranque" "systemctl is-enabled nginx != enabled"
fi

# Extras útiles
if command -v ufw >/dev/null 2>&1; then
  if ufw status 2>/dev/null | grep -q "80"; then ok "FW" "ufw permite el puerto 80"
  else fail "FW" "ufw permite el puerto 80" "revisar 'ufw status'"; fi
fi

timedatectl 2>/dev/null | grep -i "synchronized" | sed 's/^/INFO  NTP   /'

echo
if [ "$FALLOS" -eq 0 ]; then
  echo "TODO OK"
  exit 0
else
  echo "$FALLOS comprobación(es) en FAIL"
  exit 1
fi
