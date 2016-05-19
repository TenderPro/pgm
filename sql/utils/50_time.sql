/* ------------------------------------------------------------------------- */
CREATE OR REPLACE FUNCTION epoch2timestamp(a_epoch INTEGER DEFAULT 0) RETURNS TIMESTAMP IMMUTABLE LANGUAGE 'sql' AS
$_$
  -- a_epoch: количество секунд
SELECT CASE
  WHEN $1 = 0 THEN NULL
  ELSE timezone(
    (SELECT setting FROM pg_settings WHERE name = 'TimeZone')
    , (TIMESTAMPTZ 'epoch' + $1 * INTERVAL '1 second')::timestamptz
    )
END;
$_$;
SELECT pg_c('f', 'epoch2timestamp', 'преобразование секунд к типу TIMESTAMP');

