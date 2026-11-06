#!/bin/sh
set -eu

# Valkey (reemplazo libre de Redis) acepta su propia variable VALKEY_PASSWORD y,
# por compatibilidad con despliegues anteriores, también REDIS_PASSWORD.
PASSWORD="${VALKEY_PASSWORD:-${REDIS_PASSWORD:-}}"
: "${PASSWORD:?Missing VALKEY_PASSWORD}"
if [ "${#PASSWORD}" -lt 16 ]; then
  echo "VALKEY_PASSWORD must be at least 16 characters."
  exit 1
fi

MAXMEMORY="${VALKEY_MAXMEMORY:-${REDIS_MAXMEMORY:-128mb}}"
DATABASES="${VALKEY_DATABASES:-${REDIS_DATABASES:-4}}"

CONFIG="/tmp/valkey.conf"
umask 077
# Caché sin persistencia: lo que se pierda al reiniciar se reconstruye desde la API.
cat > "$CONFIG" <<EOF
bind 0.0.0.0
port 6379
protected-mode yes
tcp-backlog 511
timeout 300
tcp-keepalive 60
databases ${DATABASES}
maxmemory ${MAXMEMORY}
maxmemory-policy allkeys-lru
save ""
appendonly no
dir /tmp
requirepass ${PASSWORD}
io-threads ${VALKEY_IO_THREADS:-4}
io-threads-do-reads yes
activedefrag yes
lazyfree-lazy-eviction yes
lazyfree-lazy-expire yes
lazyfree-lazy-server-del yes
rename-command FLUSHALL ""
rename-command FLUSHDB ""
rename-command CONFIG ""
rename-command DEBUG ""
rename-command SHUTDOWN ""
# Superficie administrativa y de movimiento de datos que la API no usa (M-10).
rename-command KEYS ""
rename-command SAVE ""
rename-command BGSAVE ""
rename-command ACL ""
rename-command MODULE ""
rename-command SCRIPT ""
rename-command REPLICAOF ""
rename-command MIGRATE ""
EOF

# Socket UNIX opcional, además de TCP 6379: solo si se pide con VALKEY_SOCKET y su carpeta es un volumen escribible
# (con la raíz de solo lectura, la carpeta de la imagen no sirve y Valkey no arrancaría).
if [ -n "${VALKEY_SOCKET:-}" ]; then
  SOCKET_DIR="$(dirname "$VALKEY_SOCKET")"
  if touch "$SOCKET_DIR/.smartpot-probe" 2>/dev/null; then
    rm -f "$SOCKET_DIR/.smartpot-probe"
    printf 'unixsocket %s\nunixsocketperm 770\n' "$VALKEY_SOCKET" >> "$CONFIG"
    echo "UNIX socket enabled at ${VALKEY_SOCKET} (permissions 770)."
  else
    echo "Warning: ${SOCKET_DIR} is not writable; Valkey is listening only on TCP 6379."
  fi
fi

# Carga en segundo plano de la librería de funciones Lua atómicas al arrancar el servicio
LUA_LIB="/usr/local/share/valkey/smartpot_functions.lua"
if [ -f "$LUA_LIB" ]; then
  (
    for _ in $(seq 1 40); do
      if REDISCLI_AUTH="$PASSWORD" valkey-cli -p 6379 ping 2>/dev/null | grep -q PONG; then
        REDISCLI_AUTH="$PASSWORD" valkey-cli -p 6379 FUNCTION LOAD REPLACE "$(cat "$LUA_LIB")" >/dev/null 2>&1 || true
        echo "Atomic Lua function library (smartpot) preloaded successfully."
        break
      fi
      sleep 0.1
    done
  ) &
fi

echo "Valkey ready: ${MAXMEMORY} memory, ${VALKEY_IO_THREADS:-4} I/O threads, no persistence, password enabled."
exec valkey-server "$CONFIG"
