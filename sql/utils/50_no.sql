/*
  Служебные функции
  Проверки отсутствия объектов БД
*/


/* ------------------------------------------------------------------------- */
CREATE OR REPLACE FUNCTION no_schema(name) RETURNS BOOL LANGUAGE 'sql' AS
$_$
  SELECT NOT EXISTS(SELECT 1 FROM information_schema.schemata WHERE schema_name = $1)
$_$;

/* ------------------------------------------------------------------------- */
CREATE OR REPLACE FUNCTION no_domain(name) RETURNS BOOL LANGUAGE 'sql' AS
$_$
  SELECT NOT EXISTS(SELECT 1 FROM information_schema.domains WHERE domain_schema = any(current_schemas(false)) AND domain_name = $1)
$_$;

/* ------------------------------------------------------------------------- */
CREATE OR REPLACE FUNCTION no_type(name) RETURNS BOOL LANGUAGE 'sql' AS
$_$
  SELECT NOT EXISTS(SELECT 1 FROM information_schema.user_defined_types WHERE user_defined_type_schema = any(current_schemas(false)) AND user_defined_type_name = $1)
$_$;

/* ------------------------------------------------------------------------- */
CREATE OR REPLACE FUNCTION no_table(name) RETURNS BOOL LANGUAGE 'sql' AS
$_$
  SELECT NOT EXISTS(SELECT 1 FROM information_schema.tables
    WHERE
       -- схема не задана - ищем среди доступных
       (split_part($1, '.', 2) = ''  AND table_schema = any(current_schemas(false)) AND table_name = $1 )
       -- схема задана, имя таблицы - после точки
    OR (split_part($1, '.', 2) <> '' AND table_schema = split_part($1, '.', 1) AND table_name = split_part($1, '.', 2)  )
  )
$_$;
SELECT pg_c('f', 'no_table', 'Проверка отсутствия таблицы');

/* ------------------------------------------------------------------------- */
CREATE OR REPLACE FUNCTION no_sequence(name) RETURNS BOOL LANGUAGE 'sql' AS
$_$
  SELECT NOT EXISTS(SELECT 1 FROM information_schema.sequences WHERE sequence_schema = any(current_schemas(false)) AND sequence_name = $1)
$_$;

/* ------------------------------------------------------------------------- */
CREATE OR REPLACE FUNCTION empty_table(name) RETURNS BOOL LANGUAGE 'plpgsql' AS
$_$
  DECLARE
    v_ret BOOL;
  BEGIN
    EXECUTE 'SELECT (SELECT 1 FROM ' || $1 || ' LIMIT 1) IS NULL' INTO v_ret;
    RETURN v_ret;
  END;
$_$;

/* ------------------------------------------------------------------------- */
CREATE OR REPLACE FUNCTION no_trigger(a_schema TEXT, a_table TEXT, a_name TEXT) 
RETURNS BOOL LANGUAGE 'sql' AS
$_$
  SELECT NOT EXISTS(SELECT 1 FROM information_schema.triggers
    WHERE trigger_schema = a_schema AND event_object_table = a_table
      AND trigger_name = a_name
  )
$_$;
/* ------------------------------------------------------------------------- */
