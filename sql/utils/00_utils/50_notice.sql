/* ------------------------------------------------------------------------- */
CREATE OR REPLACE FUNCTION raise (
  a_lvl TEXT DEFAULT 'EXCEPTION'
, a_msg TEXT DEFAULT 'Default error msg.'
) RETURNS void LANGUAGE plpgsql STRICT AS
$_$
  -- a_lvl: способ вызова
  -- a_msg: сообщение
  BEGIN
     a_msg := COALESCE(a_msg, 'Default error msg.');
     CASE upper(a_lvl)
         WHEN 'EXCEPTION' THEN RAISE EXCEPTION '%', a_msg;
         WHEN 'WARNING'   THEN RAISE WARNING   '%', a_msg;
         WHEN 'NOTICE'    THEN RAISE NOTICE    '%', a_msg;
         WHEN 'DEBUG'     THEN RAISE DEBUG     '%', a_msg;
         WHEN 'LOG'       THEN RAISE LOG       '%', a_msg;
         WHEN 'INFO'      THEN RAISE INFO      '%', a_msg;
         ELSE RAISE EXCEPTION 'ws.raise(): unexpected raise-level: "%"', a_lvl;
     END CASE;
  END;
$_$;
SELECT pg_c('f', 'raise', 'Вызов RAISE из SQL запросов', $_$/*
Метод позволяет вызывать RAISE из SQL-запросов и скриптов psql.
В отличие от прямого вызова, при таком выводится контекст 
(см. http://dba.stackexchange.com/questions/7214/generate-an-exception-with-a-context)
*/$_$);

/* ------------------------------------------------------------------------- */
CREATE OR REPLACE FUNCTION notice (a_text TEXT) RETURNS VOID LANGUAGE 'sql' AS
$_$
  -- a_text: сообщение
  SELECT utils.raise('NOTICE', $1);
$_$ ;
SELECT pg_c('f', 'notice', 'Вывод предупреждения посредством RAISE NOTICE', $_$/*
Метод позволяет вызывать NOTICE из SQL-запросов и скриптов psql.
Кроме прочего, используется в скриптах 9?_*.sql для передачи в pgctl.sh названия теста
*/$_$);

