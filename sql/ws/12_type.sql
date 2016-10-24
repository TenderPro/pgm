/*

    Copyright (c) 2010, 2012 Tender.Pro http://tender.pro.
    [SQL_LICENSE]

    Типы данных и домены
*/

/* ------------------------------------------------------------------------- */
CREATE DOMAIN d_id AS INTEGER;

CREATE DOMAIN d_code AS TEXT CHECK (VALUE ~ E'^[a-z\\d][a-z\\d\\.\\-_]*$') ;

CREATE DOMAIN d_errcode AS char(5) CHECK (VALUE ~ E'^Y\\d{4}$') ;

CREATE TYPE t_textarr as (fld TEXT[]);
