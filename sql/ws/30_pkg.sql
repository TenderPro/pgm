/*

    Copyright (c) 2010, 2012 Tender.Pro http://tender.pro.
    [SQL_LICENSE]

    Функции, которые используют таблицы
    и могут использоваться представлениями
*/

/* ------------------------------------------------------------------------- */
CREATE OR REPLACE FUNCTION pkg_current() RETURNS SETOF TEXT STABLE LANGUAGE 'sql' AS
$_$
  SELECT code FROM ws.pkg WHERE op = 'create';
$_$;
SELECT pg_c('f', 'pkg_current', 'текущий инициализирующийся пакет');

/* ------------------------------------------------------------------------- */
CREATE OR REPLACE FUNCTION pg_pkg() RETURNS TEXT STABLE LANGUAGE 'plpgsql' AS
$_$
  DECLARE
    v_pkg TEXT;
  BEGIN
    SELECT INTO v_pkg * FROM ws.pkg_current();
    IF NOT FOUND THEN
      v_pkg := ws.pg_cs();
    END IF;
    RETURN v_pkg;
  END
$_$;
SELECT pg_c('f', 'pg_pkg', 'текущая схема');
