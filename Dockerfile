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
ENV REDIS_PASSWORD=admin
ENV REDIS_DATABASE=0

# Copiar el script de arranque
COPY entrypoint.sh /opt/smartpot/entrypoint.sh
RUN chmod +x /opt/smartpot/entrypoint.sh

# Puerto estándar
EXPOSE 6379

# Usar el entrypoint personalizado
ENTRYPOINT ["/opt/smartpot/entrypoint.sh"]