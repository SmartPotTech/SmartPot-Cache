#!/bin/sh
# Arranca la imagen endurecida y valida autenticación, comandos bloqueados y ausencia de persistencia.
set -eu

IMAGE="${1:-smartpot-cache:ci}"
NAME="smartpot-cache-smoke"
PASS="smoke-redis-password-123"

cleanup() { docker rm -f "$NAME" >/dev/null 2>&1 || true; }
trap cleanup EXIT
cleanup

docker run -d --name "$NAME" --read-only --tmpfs /tmp --cap-drop ALL --security-opt no-new-privileges \
  -e REDIS_PASSWORD="$PASS" "$IMAGE" >/dev/null

for _ in $(seq 1 20); do
  [ "$(docker inspect -f '{{.State.Health.Status}}' "$NAME")" = "healthy" ] && break
  sleep 1
done

cli() { docker exec "$NAME" redis-cli -h 127.0.0.1 "$@" 2>&1; }
fail=0
check() { if eval "$2"; then echo "OK   $1"; else echo "FAIL $1"; fail=1; fi; }

check "el contenedor queda sano" '[ "$(docker inspect -f "{{.State.Health.Status}}" "$NAME")" = "healthy" ]'
check "sin contraseña se rechaza" 'cli ping | grep -q NOAUTH'
check "con contraseña responde" 'cli -a "$PASS" --no-auth-warning ping | grep -q PONG'
check "guarda y lee valores" 'cli -a "$PASS" --no-auth-warning set smoke 1 >/dev/null && cli -a "$PASS" --no-auth-warning get smoke | grep -q 1'
check "FLUSHALL está deshabilitado" 'cli -a "$PASS" --no-auth-warning flushall | grep -qi "unknown command"'
check "CONFIG está deshabilitado" 'cli -a "$PASS" --no-auth-warning config get dir | grep -qi "unknown command"'
check "la contraseña no aparece en los logs" '! docker logs "$NAME" 2>&1 | grep -q "$PASS"'
check "sin contraseña el contenedor no arranca" '! docker run --rm "$IMAGE" >/dev/null 2>&1'

exit "$fail"
