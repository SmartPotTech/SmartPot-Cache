# SmartPot-Cache (Redis)

## Estado del Proyecto

[![Cache Image CI](https://github.com/SmartPotTech/SmartPot-Cache/actions/workflows/ci.yml/badge.svg)](https://github.com/SmartPotTech/SmartPot-Cache/actions/workflows/ci.yml)
[![Publish Docker Images](https://github.com/SmartPotTech/SmartPot-Cache/actions/workflows/packaging.yml/badge.svg)](https://github.com/SmartPotTech/SmartPot-Cache/actions/workflows/packaging.yml)

## Descripción

SmartPot-Cache es el **Redis** de SmartPot. [SmartPot-API](https://github.com/SmartPotTech/SmartPot-API) lo usa para datos cortos y compartidos entre peticiones:

| Uso | Llaves | Vida |
| --- | --- | --- |
| Límite de peticiones por IP | `smartpot:rate:*` | 1 minuto |
| Frecuencia mínima de telemetría por cultivo | `smartpot:reading:*` | 5 segundos |
| Enfriamiento del agente y de las alertas | `smartpot:agent:*`, `smartpot:notify:*`, `smartpot:ai-eval:*` | Minutos u horas |
| Perfiles de cultivo del servicio de IA | `smartpot:ai:crop-profiles` | 1 hora |
| Resumen de lo aprendido por la IA | `smartpot:ai:learning-status` | 1 minuto |
| Códigos de un solo uso para vincular Telegram | `smartpot:channel-link:telegram:*` | 10 minutos (se borran al usarse) |

Es una caché **sin persistencia**: si se reinicia, la API reconstruye todo. Si Redis no responde, la API sigue funcionando con memoria local durante 30 segundos y vuelve a intentar.

## Seguridad

- Contraseña obligatoria de al menos 16 caracteres (`REDIS_PASSWORD`); sin ella el contenedor no arranca.
- La configuración se genera en `/tmp` al arrancar y nunca se imprime en los logs.
- `FLUSHALL`, `FLUSHDB`, `CONFIG`, `DEBUG` y `SHUTDOWN` están deshabilitados.
- Corre como el usuario `999`, con sistema de archivos de solo lectura y sin capacidades de Linux.
- En producción no publica puertos: solo la API lo alcanza por la red interna de Docker.

## Estructura del Proyecto

```text
SmartPot-Cache/
├── .github/
│   ├── dependabot.yml
│   └── workflows/
│       ├── ci.yml              # Construye la imagen y corre la prueba de seguridad
│       ├── packaging.yml       # Publica la imagen en GHCR con SBOM y procedencia (y en Docker Hub con credenciales)
│       └── deploy.yml          # Pide el despliegue al workflow central de SmartPotTech/.github
├── tests/
│   └── smoke.sh                # Autenticación, comandos bloqueados y logs sin secretos
├── compose.yaml
├── Dockerfile                  # redis:8.8-alpine sin privilegios
├── entrypoint.sh               # Genera la configuración con la contraseña del entorno
└── .env.example
```

## Guía de Instalación

```bash
git clone https://github.com/SmartPotTech/SmartPot-Cache.git
cd SmartPot-Cache
cp .env.example .env    # define REDIS_PASSWORD
docker compose up -d
```

| Variable | Por defecto | Descripción |
| --- | --- | --- |
| `REDIS_PASSWORD` | — | Obligatoria, mínimo 16 caracteres |
| `REDIS_MAXMEMORY` | `128mb` | Memoria máxima; se descartan las llaves menos usadas (LRU) |
| `REDIS_DATABASES` | `4` | Bases lógicas disponibles |

### Prueba de humo

```bash
docker build -t smartpot-cache:ci .
sh tests/smoke.sh smartpot-cache:ci
```

## Imagen publicada

```bash
docker pull ghcr.io/smartpottech/smartpot-cache:latest
```

Cada cambio en `main` pasa por el CI, publica la imagen en GHCR (y en Docker Hub como réplica cuando el repositorio tiene credenciales) y pide el despliegue al workflow central de [SmartPotTech/.github](https://github.com/SmartPotTech/.github), que actualiza producción de a uno y verifica `/health`.

## Documentación

Redis guarda solo datos efímeros: si se pierde, la plataforma sigue. La [documentación técnica](https://github.com/SmartPotTech/.github/blob/main/docs/SmartPot_Technical_Documentation.md) explica para qué usa la API cada llave y cómo actúa si Redis no responde. Los superdiagramas muestran la plataforma completa en una sola imagen ampliable:

- [Arquitectura completa](https://github.com/SmartPotTech/.github/blob/main/docs/images/superdiagrams/SmartPot_Super_01_Architecture.svg): dónde vive Redis y qué llaves guarda
- [Linaje de los datos](https://github.com/SmartPotTech/.github/blob/main/docs/images/superdiagrams/SmartPot_Super_04_Data_Lineage.svg): en qué momento de cada flujo se consulta o se escribe una llave

## Licencia

Este proyecto está bajo la licencia MIT. Consulta el archivo [LICENSE](LICENSE) para más detalles.
