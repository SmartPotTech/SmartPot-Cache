# SmartPot-Cache (Valkey)

[English](#english) | [Español](#español)

---

<a id="english"></a>

## English

### Project Status

[![Cache Image CI](https://github.com/SmartPotTech/SmartPot-Cache/actions/workflows/ci.yml/badge.svg)](https://github.com/SmartPotTech/SmartPot-Cache/actions/workflows/ci.yml)
[![Publish Docker Images](https://github.com/SmartPotTech/SmartPot-Cache/actions/workflows/packaging.yml/badge.svg)](https://github.com/SmartPotTech/SmartPot-Cache/actions/workflows/packaging.yml)

### Description

SmartPot-Cache is SmartPot's in-memory cache layer built on **[Valkey](https://valkey.io/)**, the open-source fork of Redis maintained by the Linux Foundation under the **BSD-3-Clause** license. It replaces `SmartPot-Cache-Redis` (Redis), which moved away from open source starting in version 8. Valkey speaks the exact same wire protocol (RESP) and commands, so for [SmartPot-API](https://github.com/SmartPotTech/SmartPot-API) the transition is **transparent**: the same address, the same password, and the same client.

The API uses it for short-lived state shared across requests:

| Purpose                                        | Keys                                                          | TTL                                             |
|------------------------------------------------|---------------------------------------------------------------|-------------------------------------------------|
| Per-IP request rate limiting                   | `smartpot:rate:*`                                             | 1 minute                                        |
| Minimum telemetry interval per crop            | `smartpot:reading:*`                                          | 5 seconds                                       |
| Agent and alert cooldowns                      | `smartpot:agent:*`, `smartpot:notify:*`, `smartpot:ai-eval:*` | Minutes or hours                                |
| AI service crop profiles                       | `smartpot:ai:crop-profiles`                                   | 1 hour                                          |
| AI learning summary                            | `smartpot:ai:learning-status`                                 | 1 minute                                        |
| Single-use Telegram account link codes         | `smartpot:channel-link:telegram:*`                            | 10 minutes (deleted upon use)                   |
| Single-use Telegram crop share links           | `smartpot:crop-share:telegram:*`                              | 10 minutes (deleted upon use)                   |
| Local weather cache for each crop              | `smartpot:weather:{lat}:{lon}`                                | 10 minutes (2 minutes on upstream failure)      |

It is an **ephemeral cache without persistence**: if restarted, the API reconstructs everything on demand. If Valkey is unreachable, the API falls back to in-process memory for 30 seconds and retries automatically.

### Why Valkey

- **Open-source license.** Valkey preserves the BSD-3-Clause license under which Redis was originally released, whereas Redis 8 switched to source-available/restrictive licensing (AGPLv3 / SSPLv2 / RSALv2).
- **Drop-in replacement.** Same protocol, same commands, same port 6379, and identical configuration directives (`requirepass`, `maxmemory`, `rename-command`, etc.).
- **Environment variable compatibility.** The image accepts `VALKEY_PASSWORD` and falls back to `REDIS_PASSWORD` if only the legacy variable is provided.

### Security

- Mandatory password of at least 16 characters (`VALKEY_PASSWORD`, or `REDIS_PASSWORD` for compatibility); without it, the container refuses to start.
- Configuration is generated in `/tmp` at startup and never printed to logs.
- `FLUSHALL`, `FLUSHDB`, `CONFIG`, `DEBUG`, and `SHUTDOWN` are disabled.
- Runs as user `999`, with a read-only root filesystem and zero Linux capabilities.
- In production, no ports are exposed on the host: only the API reaches it over the internal Docker network.

### Project Structure

```text
SmartPot-Cache/
├── .github/
│   ├── dependabot.yml
│   └── workflows/
│       ├── ci.yml              # Builds the image and runs the security smoke test
│       ├── packaging.yml       # Publishes the image to GHCR with SBOM and provenance
│       └── deploy.yml          # Triggers central deployment in SmartPotTech/.github
├── docs/
│   ├── SmartPot_Cache_Documentation.md
│   └── diagrams/
├── lua/
│   ├── deadband.lua
│   ├── gcra_dedup.lua
│   └── smartpot_functions.lua
├── tests/
│   └── smoke.sh                # Auth, disabled commands, secret-free logs, and variable compatibility
├── compose.yaml
├── Dockerfile                  # Unprivileged valkey/valkey:9.1.2-alpine
├── entrypoint.sh               # Generates runtime config with environment password
└── .env.example
```

### Installation Guide

#### One-Command Deployment

The image is public: `ghcr.io/smartpottech/smartpot-cache-valkey`. You can launch the complete platform, including this service, with a single command and without cloning the code:

```bash
curl -fsSL https://raw.githubusercontent.com/SmartPotTech/.github/main/docker/demo-beta/compose.yaml | docker compose -f - up -d --wait
```

Open http://localhost:5173 and sign in with `demo@smartpot.app` / `SmartPot2026`. Stop it with `docker compose -p smartpot-demo-beta down` (add `-v` to remove data). See the [beta demo](https://github.com/SmartPotTech/.github/tree/main/docker/demo-beta) for details.

To run only this service from the published image:

```bash
docker run -d --name smartpot-cache --read-only --tmpfs /tmp --cap-drop ALL \
  -p 127.0.0.1:6379:6379 -e VALKEY_PASSWORD=<at-least-16-characters> \
  ghcr.io/smartpottech/smartpot-cache-valkey:latest
```

#### From Source with Docker Compose

```bash
cp .env.example .env    # set VALKEY_PASSWORD
docker compose up -d
```

| Variable           | Default | Description                                                  |
|--------------------|---------|--------------------------------------------------------------|
| `VALKEY_PASSWORD`  | —       | Required, minimum 16 characters (accepts `REDIS_PASSWORD`)   |
| `VALKEY_MAXMEMORY` | `128mb` | Maximum memory; evicts least recently used keys (`allkeys-lru`) |
| `VALKEY_DATABASES` | `4`     | Logical databases available                                  |

#### Smoke Test

```bash
docker build -t smartpot-cache-valkey:ci .
sh tests/smoke.sh smartpot-cache-valkey:ci
```

### Published Image

```bash
docker pull ghcr.io/smartpottech/smartpot-cache-valkey:latest
```

Every push to `main` runs through CI, publishes the image to GHCR (and mirrors it to Docker Hub when credentials are configured), and dispatches a rolling update to [SmartPotTech/.github](https://github.com/SmartPotTech/.github) with `/health` verification.

### Documentation

Valkey stores only ephemeral data: if lost, the platform continues operating. Component documentation is available in [`docs/`](docs/SmartPot_Cache_Documentation.md) (also in [DOCX](docs/SmartPot_Cache_Documentation.docx) and [PDF](docs/SmartPot_Cache_Documentation.pdf)), with diagrams in [`docs/diagrams`](docs/diagrams). The [technical documentation](https://github.com/SmartPotTech/.github/blob/main/docs/SmartPot_Technical_Documentation.md) explains how the API uses each key and how it behaves when the cache is unreachable:

- [Complete Architecture](https://github.com/SmartPotTech/.github/blob/main/docs/diagrams/SmartPot_Global_01_Architecture.svg): where the cache sits and which keys it holds
- [Data Lineage](https://github.com/SmartPotTech/.github/blob/main/docs/diagrams/SmartPot_Global_04_Data_Lineage.svg): when each flow reads or writes a cache key

### Industrial Roadmap: Multi-IO, UDS Transport, and Atomic Lua Functions

As part of the **Stack B Maximization Master Plan (`demo-beta`)**, `SmartPot-Cache` includes high-throughput tuning:

1. **Dual Listener (UDS and TCP)**:
   - Optional UNIX socket `/var/run/smartpot/valkey.sock` (permissions `770`) when `VALKEY_SOCKET` is set and its directory is writable, eliminating TCP loopback overhead in single-node deployments while preserving TCP port `6379`.
2. **Multi-Threaded I/O and Memory Hygiene**:
   - `io-threads 4` and `io-threads-do-reads yes` to parallelize socket reads and writes.
   - Asynchronous Jemalloc purge (`lazyfree-lazy-eviction yes`, `lazyfree-lazy-expire yes`, `activedefrag yes`).
3. **Atomic Lua Functions (`FUNCTION LOAD`)**:
   - Atomic deadband threshold evaluation (`deadband_check_and_update`).
   - MQTT packet deduplication by `sequence_id` and Generic Cell Rate Algorithm (GCRA) rate limiting (`mqtt_dedup_and_rate_limit`) in a single round-trip.

### License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

---

<a id="español"></a>

## Español

### Estado del Proyecto

[![Cache Image CI](https://github.com/SmartPotTech/SmartPot-Cache/actions/workflows/ci.yml/badge.svg)](https://github.com/SmartPotTech/SmartPot-Cache/actions/workflows/ci.yml)
[![Publish Docker Images](https://github.com/SmartPotTech/SmartPot-Cache/actions/workflows/packaging.yml/badge.svg)](https://github.com/SmartPotTech/SmartPot-Cache/actions/workflows/packaging.yml)

### Descripción

SmartPot-Cache es la caché de SmartPot sobre **[Valkey](https://valkey.io/)**, el derivado libre de Redis mantenido por la Linux Foundation bajo licencia **BSD-3-Clause**. Sustituye a `SmartPot-Cache-Redis` (Redis), que desde la versión 8 dejó de ser software libre y pasó a una licencia restringida. Valkey habla el mismo protocolo (RESP) y los mismos comandos, así que para la [API en Go](https://github.com/SmartPotTech/SmartPot-API) el cambio es **transparente**: la misma dirección, la misma contraseña y el mismo cliente.

La API la usa para datos cortos y compartidos entre peticiones:

| Uso                                              | Llaves                                                        | Vida                                    |
|--------------------------------------------------|---------------------------------------------------------------|-----------------------------------------|
| Límite de peticiones por IP                      | `smartpot:rate:*`                                             | 1 minuto                                |
| Frecuencia mínima de telemetría por cultivo      | `smartpot:reading:*`                                          | 5 segundos                              |
| Enfriamiento del agente y de las alertas         | `smartpot:agent:*`, `smartpot:notify:*`, `smartpot:ai-eval:*` | Minutos u horas                         |
| Perfiles de cultivo del servicio de IA           | `smartpot:ai:crop-profiles`                                   | 1 hora                                  |
| Resumen de lo aprendido por la IA                | `smartpot:ai:learning-status`                                 | 1 minuto                                |
| Códigos de un solo uso para vincular Telegram    | `smartpot:channel-link:telegram:*`                            | 10 minutos (se borran al usarse)        |
| Enlaces de un solo uso para compartir un cultivo | `smartpot:crop-share:telegram:*`                              | 10 minutos (se borran al usarse)        |
| Clima del lugar de cada cultivo                  | `smartpot:weather:{lat}:{lon}`                                | 10 minutos (2 si el clima no respondió) |

Es una caché **sin persistencia**: si se reinicia, la API reconstruye todo. Si Valkey no responde, la API sigue funcionando con memoria local durante 30 segundos y vuelve a intentar.

### Por qué Valkey

- **Licencia libre.** Valkey mantiene la licencia BSD-3-Clause con la que Redis era de código abierto; Redis 8 es ahora software con fuente disponible pero bajo licencia restringida (AGPLv3 / SSPLv2 / RSALv2).
- **Reemplazo directo.** Mismo protocolo, mismos comandos, mismo puerto 6379 y la misma configuración (`requirepass`, `maxmemory`, `rename-command`…). No cambia ningún contrato ni la forma en que la API la consulta.
- **Compatibilidad de variables.** La imagen acepta `VALKEY_PASSWORD` y, si solo existe `REDIS_PASSWORD`, también la usa, para que ningún despliegue existente se rompa durante el corte.

### Seguridad

- Contraseña obligatoria de al menos 16 caracteres (`VALKEY_PASSWORD`, o `REDIS_PASSWORD` por compatibilidad); sin ella el contenedor no arranca.
- La configuración se genera en `/tmp` al arrancar y nunca se imprime en los logs.
- `FLUSHALL`, `FLUSHDB`, `CONFIG`, `DEBUG` y `SHUTDOWN` están deshabilitados.
- Corre como el usuario `999`, con sistema de archivos de solo lectura y sin capacidades de Linux.
- En producción no publica puertos: solo la API lo alcanza por la red interna de Docker.

### Estructura del Proyecto

```text
SmartPot-Cache/
├── .github/
│   ├── dependabot.yml
│   └── workflows/
│       ├── ci.yml              # Construye la imagen y corre la prueba de seguridad
│       ├── packaging.yml       # Publica la imagen en GHCR con SBOM y procedencia (y en Docker Hub con credenciales)
│       └── deploy.yml          # Pide el despliegue al workflow central de SmartPotTech/.github
├── docs/
│   ├── SmartPot_Cache_Documentation.md
│   └── diagrams/
├── lua/
│   ├── deadband.lua
│   ├── gcra_dedup.lua
│   └── smartpot_functions.lua
├── tests/
│   └── smoke.sh                # Autenticación, comandos bloqueados, logs sin secretos y compatibilidad de variables
├── compose.yaml
├── Dockerfile                  # valkey/valkey:9.1.2-alpine sin privilegios
├── entrypoint.sh               # Genera la configuración con la contraseña del entorno
└── .env.example
```

### Guía de Instalación

#### Despliegue en un comando

La imagen es pública: `ghcr.io/smartpottech/smartpot-cache-valkey`. La plataforma completa, con este servicio incluido, se levanta con un solo comando y sin descargar el código:

```bash
curl -fsSL https://raw.githubusercontent.com/SmartPotTech/.github/main/docker/demo-beta/compose.yaml | docker compose -f - up -d --wait
```

Abre http://localhost:5173 e ingresa con `demo@smartpot.app` / `SmartPot2026`. Se detiene con `docker compose -p smartpot-demo-beta down` (con `-v` borra también los datos). Más detalle en la [demo beta](https://github.com/SmartPotTech/.github/tree/main/docker/demo-beta).

Solo este servicio, con la imagen publicada:

```bash
docker run -d --name smartpot-cache --read-only --tmpfs /tmp --cap-drop ALL \
  -p 127.0.0.1:6379:6379 -e VALKEY_PASSWORD=<mínimo-16-caracteres> \
  ghcr.io/smartpottech/smartpot-cache-valkey:latest
```

#### Desde el código con Docker Compose

```bash
cp .env.example .env    # define VALKEY_PASSWORD
docker compose up -d
```

| Variable           | Por defecto | Descripción                                                 |
|--------------------|-------------|-------------------------------------------------------------|
| `VALKEY_PASSWORD`  | —           | Obligatoria, mínimo 16 caracteres (acepta `REDIS_PASSWORD`) |
| `VALKEY_MAXMEMORY` | `128mb`     | Memoria máxima; se descartan las llaves menos usadas (LRU)  |
| `VALKEY_DATABASES` | `4`         | Bases lógicas disponibles                                   |

#### Prueba de humo

```bash
docker build -t smartpot-cache-valkey:ci .
sh tests/smoke.sh smartpot-cache-valkey:ci
```

### Imagen publicada

```bash
docker pull ghcr.io/smartpottech/smartpot-cache-valkey:latest
```

Cada cambio en `main` pasa por el CI, publica la imagen en GHCR (y en Docker Hub como réplica cuando el repositorio tiene credenciales) y pide el despliegue al workflow central de [SmartPotTech/.github](https://github.com/SmartPotTech/.github), que actualiza producción de a uno y verifica `/health`.

### Documentación

Valkey guarda solo datos efímeros: si se pierde, la plataforma sigue. Su documentación propia está en [`docs/`](docs/SmartPot_Cache_Documentation.md) (también en [DOCX](docs/SmartPot_Cache_Documentation.docx) y [PDF](docs/SmartPot_Cache_Documentation.pdf)), con sus diagramas en [`docs/diagrams`](docs/diagrams): el general de la imagen y el de las llaves. La [documentación técnica](https://github.com/SmartPotTech/.github/blob/main/docs/SmartPot_Technical_Documentation.md) explica para qué usa la API cada llave y cómo actúa si la caché no responde. Los diagramas generales muestran la plataforma completa en una sola imagen ampliable:

- [Arquitectura completa](https://github.com/SmartPotTech/.github/blob/main/docs/diagrams/SmartPot_Global_01_Architecture.svg): dónde vive la caché y qué llaves guarda
- [Linaje de los datos](https://github.com/SmartPotTech/.github/blob/main/docs/diagrams/SmartPot_Global_04_Data_Lineage.svg): en qué momento de cada flujo se consulta o se escribe una llave

### Hoja de Ruta Industrial: Multi-IO, Transporte UDS y Funciones Lua Atómicas

Como parte del **Plan Maestro de Maximización del Stack B (demo-beta)**, `SmartPot-Cache` incorpora afinaciones de rendimiento extremo:

1. **Listener Dual (UDS y TCP)**:
   - Configuración de socket UNIX `/var/run/smartpot/valkey.sock` con permisos 770 para comunicación sin sobrecarga TCP en despliegues mononodo (`demo-beta`), preservando el puerto TCP 6379 para escalado en red.
2. **Concurrencia Multi-Hilo y Memoria**:
   - `io-threads 4` e `io-threads-do-reads yes` para paralelizar la lectura y escritura de sockets.
   - Activación de purga asíncrona de Jemalloc (`lazyfree-lazy-eviction yes`, `lazyfree-lazy-expire yes`, `activedefrag yes`).
3. **Funciones Lua Atómicas (`FUNCTION LOAD`)**:
   - Evaluación atómica de umbrales del filtro de banda muerta agronómico.
   - Deduplicación de paquetes MQTT por `sequence_id`.
   - Algoritmo de tasa Generic Cell Rate Algorithm (GCRA) evaluado en una única transacción.

### Licencia

Este proyecto está bajo la licencia MIT. Consulta el archivo [LICENSE](LICENSE) para más detalles.
