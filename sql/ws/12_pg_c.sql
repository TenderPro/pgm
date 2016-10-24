/*

    Copyright (c) 2010, 2012 Tender.Pro http://tender.pro.
    [SQL_LICENSE]

    Подсистема комментирования объектов БД
*/

/* ------------------------------------------------------------------------- */
CREATE DOMAIN d_pg_argtypes AS oidvector; -- pg_catalog.pg_proc.proargtypes
CREATE DOMAIN d_pg_argnames AS TEXT[];    -- pg_catalog.pg_proc.proargnames

/* ------------------------------------------------------------------------- */
CREATE TYPE t_pg_object AS ENUM ('h', 'r', 'v', 'c', 't', 'd', 'f', 'a', 's'); -- see pg_comment
CREATE TYPE t_pkg_op AS ENUM ('create', 'make', 'drop', 'erase', 'done'); -- see 50_pkg.sql

/* ------------------------------------------------------------------------- */
CREATE TYPE t_pg_proc_info AS (
  schema      TEXT
, name        TEXT
, anno        TEXT
, rt_oid      oid
, rt_name     TEXT
, is_set      BOOL
, args        TEXT
, args_pub    TEXT
);
        
/* ------------------------------------------------------------------------- */
CREATE TYPE t_pg_view_info AS (
  rel         TEXT  -- имя view из аргументов ф-и (схема.объект)
, code        TEXT  -- имя столбца (без значения rel)
, rel_src     TEXT  -- имя (схема.объект) источника комментария без имени столбца)
, rel_src_col TEXT  -- имя столбца источника комментария
, status_id   INT   -- результат поиска (1 - найден коммент, 2 - у источника коммент не задан, 3 - расчетное поле, 4 - ошибка, 5 - неподдерживаемый формат поля в представлении) 
, anno        TEXT  -- зависит от status_d: 1 - комментарий, 2 - null, 3 - текст формулы, 4- описание "иного" 
);
