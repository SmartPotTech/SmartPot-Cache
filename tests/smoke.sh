#!/bin/sh
# Arranca la imagen endurecida y valida autenticación, comandos bloqueados, ausencia de
# persistencia y la compatibilidad de variables con el Redis anterior.
set -eu

IMAGE="${1:-smartpot-cache-valkey:ci}"
NAME="smartpot-cache-valkey-smoke"
COMPAT="smartpot-cache-valkey-compat"
SOCKET="smartpot-cache-valkey-socket"
PASS="smoke-valkey-password-123"

cleanup() { docker rm -f "$NAME" "$COMPAT" "$SOCKET" >/dev/null 2>&1 || true; }
trap cleanup EXIT
cleanup

docker run -d --name "$NAME" --read-only --tmpfs /tmp --cap-drop ALL --security-opt no-new-privileges \
  -e VALKEY_PASSWORD="$PASS" "$IMAGE" >/dev/null

for _ in $(seq 1 20); do
  [ "$(docker inspect -f '{{.State.Health.Status}}' "$NAME")" = "healthy" ] && break
  sleep 1
done

cli() { docker exec "$NAME" valkey-cli -h 127.0.0.1 "$@" 2>&1; }
fail=0
check() { if eval "$2"; then echo "OK   $1"; else echo "FAIL $1"; fail=1; fi; }

check "container becomes healthy" '[ "$(docker inspect -f "{{.State.Health.Status}}" "$NAME")" = "healthy" ]'
check "unauthenticated ping is rejected" 'cli ping | grep -q NOAUTH'
check "wrong password is rejected" '! cli -a "$PASS-wrong" --no-auth-warning ping | grep -q PONG'
check "authenticated ping responds with PONG" 'cli -a "$PASS" --no-auth-warning ping | grep -q PONG'
check "image is Valkey, not Redis" 'cli -a "$PASS" --no-auth-warning info server | grep -qi "valkey_version"'
check "without VALKEY_SOCKET it does not open a UNIX socket" '! docker exec "$NAME" test -S /var/run/smartpot/valkey.sock'
check "stores and reads values" 'cli -a "$PASS" --no-auth-warning set smoke 1 >/dev/null && cli -a "$PASS" --no-auth-warning get smoke | grep -q 1'
check "DEL is idempotent" 'cli -a "$PASS" --no-auth-warning set smoke-idempotent 1 >/dev/null && [ "$(cli -a "$PASS" --no-auth-warning del smoke-idempotent)" = "1" ] && [ "$(cli -a "$PASS" --no-auth-warning del smoke-idempotent)" = "0" ]'
check "SETNX is idempotent" 'cli -a "$PASS" --no-auth-warning setnx smoke-lock 1 >/dev/null && [ "$(cli -a "$PASS" --no-auth-warning setnx smoke-lock 2)" = "0" ] && cli -a "$PASS" --no-auth-warning del smoke-lock >/dev/null'
check "keys expire with PX" 'cli -a "$PASS" --no-auth-warning set ephemeral 1 px 100 >/dev/null && sleep 1 && [ "$(cli -a "$PASS" --no-auth-warning exists ephemeral)" = "0" ]'
check "maxmemory policy is volatile-lru" 'cli -a "$PASS" --no-auth-warning info memory | grep -q "maxmemory_policy:volatile-lru"'
check "smartpot Lua functions are registered" 'cli -a "$PASS" --no-auth-warning function list | grep -q smartpot'
check "FLUSHALL is disabled" 'cli -a "$PASS" --no-auth-warning flushall | grep -qi "unknown command"'
check "CONFIG is disabled" 'cli -a "$PASS" --no-auth-warning config get dir | grep -qi "unknown command"'
check "KEYS is disabled" 'cli -a "$PASS" --no-auth-warning keys "*" | grep -qi "unknown command"'
check "SAVE is disabled" 'cli -a "$PASS" --no-auth-warning save | grep -qi "unknown command"'
check "BGSAVE is disabled" 'cli -a "$PASS" --no-auth-warning bgsave | grep -qi "unknown command"'
check "ACL is disabled" 'cli -a "$PASS" --no-auth-warning acl whoami | grep -qi "unknown command"'
check "MODULE is disabled" 'cli -a "$PASS" --no-auth-warning module list | grep -qi "unknown command"'
check "SCRIPT is disabled" 'cli -a "$PASS" --no-auth-warning script load "return 1" | grep -qi "unknown command"'
check "REPLICAOF is disabled" 'cli -a "$PASS" --no-auth-warning replicaof no one | grep -qi "unknown command"'
check "MIGRATE is disabled" 'cli -a "$PASS" --no-auth-warning migrate 127.0.0.1 6379 "" 0 1 | grep -qi "unknown command"'
check "password does not appear in logs" '! docker logs "$NAME" 2>&1 | grep -q "$PASS"'
check "container refuses to start without password" '! docker run --rm "$IMAGE" >/dev/null 2>&1'

# La caché no persiste por diseño: tras reiniciar, el estado se reconstruye desde la API.
docker restart "$NAME" >/dev/null
for _ in $(seq 1 20); do
  [ "$(docker inspect -f '{{.State.Health.Status}}' "$NAME")" = "healthy" ] && break
  sleep 1
done
check "container becomes healthy after a restart" '[ "$(docker inspect -f "{{.State.Health.Status}}" "$NAME")" = "healthy" ]'
check "cache is ephemeral across restarts" '! cli -a "$PASS" --no-auth-warning get smoke | grep -q 1'

# El socket UNIX es opcional y solo se abre con VALKEY_SOCKET en una carpeta escribible.
docker run -d --name "$SOCKET" --read-only --tmpfs /tmp --cap-drop ALL --security-opt no-new-privileges \
  --tmpfs /var/run/smartpot:rw,noexec,nosuid,size=1m,uid=999,gid=1000,mode=0770 \
  -e VALKEY_PASSWORD="$PASS" -e VALKEY_SOCKET=/var/run/smartpot/valkey.sock "$IMAGE" >/dev/null
for _ in $(seq 1 20); do
  [ "$(docker inspect -f '{{.State.Health.Status}}' "$SOCKET")" = "healthy" ] && break
  sleep 1
done
check "opens the optional UNIX socket" 'docker exec "$SOCKET" test -S /var/run/smartpot/valkey.sock'
check "UNIX socket accepts authenticated clients" 'docker exec "$SOCKET" valkey-cli -s /var/run/smartpot/valkey.sock -a "$PASS" --no-auth-warning ping | grep -q PONG'

# Compatibilidad drop-in: una API que aún envía REDIS_PASSWORD debe seguir funcionando.
docker run -d --name "$COMPAT" --read-only --tmpfs /tmp --cap-drop ALL --security-opt no-new-privileges \
  -e REDIS_PASSWORD="$PASS" "$IMAGE" >/dev/null
for _ in $(seq 1 20); do
  [ "$(docker inspect -f '{{.State.Health.Status}}' "$COMPAT")" = "healthy" ] && break
  sleep 1
done
check "accepts REDIS_PASSWORD (backward compatibility)" '[ "$(docker inspect -f "{{.State.Health.Status}}" "$COMPAT")" = "healthy" ]'

exit "$fail"
