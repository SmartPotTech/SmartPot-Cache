-- gcra_dedup.lua
-- KEYS[1] = llave de deduplicación (p. ej. "dedup:{client_id}:{seq_id}")
-- KEYS[2] = llave GCRA (p. ej. "gcra:{client_id}")
-- ARGV[1] = sequence_id (string)
-- ARGV[2] = tasa por segundo (float, por defecto 10.0)
-- ARGV[3] = capacidad de ráfaga (float, por defecto 20.0)
-- ARGV[4] = marca de tiempo actual (float)
-- Devuelve:
--   1: Permitido
--   0: Limitado por tasa
--   2: Paquete duplicado

local dedup_key = KEYS[1]
local gcra_key = KEYS[2]
local seq_id = ARGV[1]
local rate = tonumber(ARGV[2]) or 10.0
local burst = tonumber(ARGV[3]) or 20.0
local now = tonumber(ARGV[4]) or os.time()

-- Verificar deduplicación por secuencia
if seq_id and seq_id ~= '' and seq_id ~= '0' then
    local exists = redis.call('EXISTS', dedup_key)
    if exists == 1 then
        return 2 -- Duplicado
    end
end

-- Algoritmo de cubo con fugas GCRA
local emission_interval = 1.0 / rate
local delay_tolerance = burst * emission_interval
local tat = tonumber(redis.call('GET', gcra_key)) or now

local new_tat = math.max(tat, now) + emission_interval
local allow_at = new_tat - delay_tolerance

if now < allow_at then
    return 0 -- Limitado por tasa
end

redis.call('SET', gcra_key, tostring(new_tat), 'EX', math.ceil(delay_tolerance + 10))

if seq_id and seq_id ~= '' and seq_id ~= '0' then
    redis.call('SET', dedup_key, '1', 'EX', 60)
end

return 1 -- Permitido
