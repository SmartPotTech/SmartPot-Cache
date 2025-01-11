# Uso de imagen oficial de Redis Stack
FROM redis/redis-stack-server:latest

# Establecimiento de configuración redis
COPY redis.conf /usr/local/etc/redis/redis.conf

# Expone el puerto 6379
EXPOSE 6379

# Ejecuta Redis usando el archivo de configuración personalizado
CMD ["redis-server", "/usr/local/etc/redis/redis.conf"]