/*
  Вспомогательные функции общего назначения

*/

/* ------------------------------------------------------------------------- */
CREATE OR REPLACE FUNCTION ws.array_remove(
  a ANYARRAY
, b ANYELEMENT
) RETURNS ANYARRAY IMMUTABLE LANGUAGE 'sql' AS
$_$
  -- a: массив
  -- b: элемент
SELECT array_agg(x) FROM unnest($1) x WHERE x <> $2;
$_$;
SELECT pg_c('f', 'array_remove', 'удаляет элемент из массива', 'Используется в pkg_op_after');



/* ------------------------------------------------------------------------- */
CREATE OR REPLACE FUNCTION pg_exec_func(a_name TEXT) RETURNS TEXT STABLE LANGUAGE 'plpgsql' AS
$_$
  -- a_name:  имя функции
  DECLARE
    v TEXT;
  BEGIN
    EXECUTE 'SELECT * FROM ' || a_name || '()' INTO v;
    RETURN v;
  END;
$_$;
SELECT pg_c('f', 'pg_exec_func', 'Вернуть текстовый результат функции, вызвав ее по имени', 'Используется VIEW pg_const');

/* ------------------------------------------------------------------------- */
CREATE OR REPLACE FUNCTION pg_exec_func(
  a_schema TEXT
, a_name   TEXT
) RETURNS TEXT STABLE LANGUAGE 'sql' AS
$_$
  -- a_schema: название пакета
  -- a_name:   имя функции
  SELECT ws.pg_exec_func($1 || '.' || $2)
$_$;
SELECT pg_c('f', 'pg_exec_func', 'Вернуть текстовый результат функции, вызвав ее по имени', 'Используется VIEW pg_const');



/* ------------------------------------------------------------------------- */
CREATE OR REPLACE FUNCTION pg_schema_by_oid(a_oid oid) RETURNS TEXT STABLE LANGUAGE 'sql' AS
$_$
  -- a_oid:  OID
  SELECT nspname::TEXT FROM pg_namespace WHERE oid = $1
$_$;
SELECT pg_c('f', 'pg_schema_by_oid',         'получить название пакета по OID-у', 'Используется VIEW pg_const');

/* ------------------------------------------------------------------------- */
CREATE OR REPLACE FUNCTION pg_comment (
  a_table text
, a_comment text default ''
, a_cols json default null
) RETURNS TEXT LANGUAGE 'plpgsql' AS
$_$
  -- a_table: имя таблицы (схема.таблица)
  -- a_comment: комментарий таблицы
  -- a_cols: json хэш комментариев полей вида {field: comment ,..}
DECLARE 
  v_ret TEXT;
  v_c TEXT; -- table comment
  v_s TEXT; -- columnt comment string
  r RECORD;
BEGIN
  IF a_comment <> '' THEN
    -- save table comment
    EXECUTE 'COMMENT ON TABLE ' || a_table || ' IS ' || quote_literal(a_comment);
  END IF;
  FOR r IN SELECT * FROM json_each_text(a_cols)
  LOOP
    -- save column comment
    RAISE NOTICE 'comment % with %', r.key, r.value;
    EXECUTE 'COMMENT ON COLUMN ' || a_table || '.' || r.key || ' IS ' || quote_literal(r.value);
  END LOOP;

  -- read column comments
  SELECT INTO v_s
    string_agg(
      '"' || attname || '": ' || to_json(COALESCE(col_description(attrelid, attnum), '')) || E'\n'
      , ',') 
    FROM pg_catalog.pg_attribute 
    WHERE attrelid = a_table::regclass 
      AND attnum > 0 
      AND NOT attisdropped
    ;
  
  v_c := COALESCE(obj_description(a_table::regclass, 'pg_class'), '');  
  v_ret := format(E'SELECT ws.pg_comment(\'%s\', %s,\'{\n %s}\');',a_table, quote_literal(v_c), v_s);
  RETURN v_ret ;
END

$_$;
SELECT pg_c('f', 'pg_comment', 'чтение/запись комментариев полей таблицы');

/* ------------------------------------------------------------------------- */
CREATE OR REPLACE FUNCTION ws.now0() RETURNS TIMESTAMPTZ(0) STABLE LANGUAGE 'sql' AS
$_$
SELECT now()::TIMESTAMPTZ(0);
$_$;
SELECT pg_c('f', 'now0', 'текущее время, округленное до секунды', 'См РМ #31126');
