#!/bin/sh
set -e

echo "Generando configuración dinámica de Redis..."

# Archivo temporal de configuración
CONFIG_FILE="/usr/local/etc/redis/redis.conf"

# Crear archivo de configuración con los parámetros dinámicos
cat <<EOF > $CONFIG_FILE
bind 0.0.0.0
port 6379
databases ${REDIS_DATABASE}
requirepass ${REDIS_PASSWORD}
EOF

echo "Configuración generada:"
cat $CONFIG_FILE

# Iniciar Redis con la configuración generada
echo "Iniciando Redis con la contraseña definida..."
exec redis-server $CONFIG_FILE