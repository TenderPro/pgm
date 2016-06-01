/*

    Copyright (c) 2010, 2012 Tender.Pro http://tender.pro.
    [SQL_LICENSE]

    Типы данных и домены
*/

/* ------------------------------------------------------------------------- */
CREATE DOMAIN d_id AS INTEGER;
SELECT pg_c('d','d_id', 'Идентификатор');

CREATE DOMAIN d_code AS TEXT CHECK (VALUE ~ E'^[a-z\\d][a-z\\d\\.\\-_]*$') ;
SELECT pg_c('d','d_code', 'Имя переменной');

CREATE DOMAIN d_errcode AS char(5) CHECK (VALUE ~ E'^Y\\d{4}$') ;
SELECT pg_c('d','d_errcode', 'Код ошибки');

CREATE TYPE t_textarr as (fld TEXT[]);
SELECT pg_c('t','t_textarr', 'Вспомогательный тип данных для ф-ции pg_store_proc_descr');