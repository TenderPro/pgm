/* ------------------------------------------------------------------------- */
CREATE OR REPLACE FUNCTION pg_cast (
  a_type  TEXT
, a_value TEXT
) RETURNS TEXT LANGUAGE plpgsql STRICT AS
$_$
  -- a_type:  тип 
  -- a_value: значение
  DECLARE
  v_sql TEXT;
  BEGIN
    v_sql := format('SELECT $1::%s', a_type);
    EXECUTE v_sql USING a_value;
      RETURN NULL;
    EXCEPTION WHEN OTHERS THEN
      RETURN SQLSTATE;
  END;
$_$;
SELECT pg_c('f', 'pg_cast', 'Приведение значения к заданному типу');
