# Imagen base oficial de Redis Stack Server
FROM redis/redis-stack-server:latest

LABEL maintainer="smartpottech@gmail.com" \
      version="1.0.0" \
      description="Imagen personalizada de Redis Stack para SmartPot" \
      license="MIT" \
      created="2025-01-11" \
      repository="https://github.com/SmartPotTech/SmartPot-Cache" \
      environment="local"

# Variables de entorno por defecto
ENV REDIS_USER=admin
ENV REDIS_PASSWORD=admin
ENV REDIS_DATABASE=0

# Expone el puerto estándar de Redis
EXPOSE 6379

# Copiar script de inicialización
COPY init-data.sh /docker-entrypoint-initdb.d/init-data.sh

# Dar permisos
RUN chmod +x /docker-entrypoint-initdb.d/init-data.sh