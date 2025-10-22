#!/bin/bash
set -e
echo "Inicializando datos en Redis para SmartPot..."

AUTH_CMD=""
if [ -n "$REDIS_PASSWORD" ]; then
  AUTH_CMD="-a $REDIS_PASSWORD"
fi

# Base de datos
DB_CMD="-n ${REDIS_DATABASE:-0}"

# Datos iniciales (JSON simulando la lista de usuarios)
USERS_JSON='[
  {"id": "1", "name": "Sebastián López", "email": "sebastian@smartpot.com"},
  {"id": "2", "name": "María Gómez", "email": "maria@smartpot.com"},
  {"id": "3", "name": "Juan Pérez", "email": "juan@smartpot.com"}
]'

# Insertar la lista serializada en Redis bajo la misma clave que usa tu @Cacheable
redis-cli $AUTH_CMD $DB_CMD SET "users::all_users" "$USERS_JSON"

echo "Datos iniciales cargados en Redis:"
redis-cli $AUTH_CMD $DB_CMD GET "users::all_users"