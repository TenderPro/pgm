/*

    Copyright (c) 2010, 2012 Tender.Pro http://tender.pro.
    [SQL_LICENSE]

    Вспомогательные таблицы
*/


/* ------------------------------------------------------------------------- */
CREATE TABLE error_data (
  code        d_errcode PRIMARY KEY
);
SELECT pg_c('r', 'error_data', 'Коды ошибок (без строк локализации)')
, pg_c('c', 'error_data.code',   'Код ошибки')
;

