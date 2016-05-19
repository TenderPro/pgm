/*

    Copyright (c) 2016 Tender.Pro http://tender.pro.
    [SQL_LICENSE]

    Пример хранимой функции
*/

/* ------------------------------------------------------------------------- */
CREATE OR REPLACE FUNCTION echo(a_text TEXT) RETURNS TEXT LANGUAGE 'sql' AS
$_$
  -- a_text:  текст для повторения
  SELECT $1
$_$;
SELECT pg_c('f', 'echo', 'Эхосервис');
