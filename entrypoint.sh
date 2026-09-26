#!/bin/sh
set -eu

: "${REDIS_PASSWORD:?Falta REDIS_PASSWORD}"
if [ "${#REDIS_PASSWORD}" -lt 16 ]; then
  echo "REDIS_PASSWORD debe tener al menos 16 caracteres."
  exit 1
fi

CONFIG="/tmp/redis.conf"
umask 077
# Caché sin persistencia: lo que se pierda al reiniciar se reconstruye desde la API.
cat > "$CONFIG" <<EOF
bind 0.0.0.0
port 6379
protected-mode yes
databases ${REDIS_DATABASES:-4}
maxmemory ${REDIS_MAXMEMORY:-128mb}
maxmemory-policy allkeys-lru
save ""
appendonly no
dir /tmp
requirepass ${REDIS_PASSWORD}
rename-command FLUSHALL ""
rename-command FLUSHDB ""
rename-command CONFIG ""
rename-command DEBUG ""
rename-command SHUTDOWN ""
EOF

echo "Redis listo: ${REDIS_MAXMEMORY:-128mb} de memoria, sin persistencia y con contraseña."
exec redis-server "$CONFIG"
