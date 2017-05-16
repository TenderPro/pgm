/*
  Служебные функции
  приведение имени типа к укороченной форме
*/

-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION type_name_normalize(a_type TEXT) RETURNS TEXT LANGUAGE 'sql' AS
$_$
  -- a_type:  тип
  SELECT CASE
    WHEN $1 ~ E'^timestamp[\\( ]' THEN
      'timestamp' -- clean "timestamp(0) without time zone"
    WHEN $1 ~ E'^time[\\( ]' THEN
      'time' -- clean "time without time zone"
    WHEN $1 ~ E'^numeric\\(' THEN
      'numeric' -- clean "numeric(14,4)"
    WHEN $1 ~ E'^double' THEN
      'double' -- clean "double precision"
    WHEN $1 ~ E'^character( varying)?' THEN
      'text' -- TODO: allow length
    ELSE
      $1
    END
$_$;
SELECT pg_c('f', 'type_name_normalize', 'нормализует название типа');
