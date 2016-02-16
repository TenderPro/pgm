/*

    Copyright (c) 2010, 2012 Tender.Pro http://tender.pro.
    [SQL_LICENSE]

    Схема изменяемых в процессе эксплуатации данных и ее базовые объекты
*/

/* ------------------------------------------------------------------------- */
CREATE SCHEMA wsd;
COMMENT ON SCHEMA wsd IS 'WebService (PGWS) realtime Data';

/* ------------------------------------------------------------------------- */
CREATE TABLE wsd.pkg_script_protected (
  pkg         name
, schema      name
, code        TEXT
, csum        TEXT NOT NULL
, created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
, CONSTRAINT  pkg_script_protected_pkey PRIMARY KEY (pkg, schema, code)
);
COMMENT ON TABLE wsd.pkg_script_protected IS 'Оперативные данные пакетов PGWS';


/* ------------------------------------------------------------------------- */
CREATE TABLE wsd.pkg_fkey_protected (
  pkg         name
, wsd_rel     name
, wsd_col     text
, rel         name
, is_active   bool NOT NULL DEFAULT FALSE
, schema      name -- NOT NULL только для 2й схемы пакета
, CONSTRAINT pkg_fkey_protected_pkey PRIMARY KEY (pkg, wsd_rel, wsd_col)
);

/* ------------------------------------------------------------------------- */
CREATE TABLE wsd.pkg_fkey_required_by (
  pkg         name 
, rel         name
, required_by name
, CONSTRAINT pkg_fkey_required_by_pkey PRIMARY KEY (pkg, rel, required_by)
);
-- TODO: В триггере на INSERT проверять, что в wsd.pkg_fkey_protected есть такая пара pkg,rel

/* ------------------------------------------------------------------------- */
CREATE TABLE wsd.pkg_default_protected (
  pkg         name
, wsd_rel     name NOT NULL
, wsd_col     text NOT NULL
, func        name
, is_active   bool NOT NULL DEFAULT FALSE
, schema      name NOT NULL DEFAULT 'ws' -- только для 1й схемы пакета ws
, CONSTRAINT pkg_default_protected_pkey PRIMARY KEY (pkg, wsd_rel, wsd_col)
);

/* ------------------------------------------------------------------------- */

INSERT INTO wsd.pkg_default_protected (pkg, wsd_rel, wsd_col, func) VALUES
  ('ws', 'pkg_script_protected',  'pkg',          'ws.pg_cs()')
, ('ws', 'pkg_script_protected',  'schema',       'ws.pg_cs()')
, ('ws', 'pkg_default_protected', 'pkg',          'ws.pg_cs()')
, ('ws', 'pkg_default_protected', 'schema',       'ws.pg_cs()')
, ('ws', 'pkg_fkey_protected',    'pkg',          'ws.pg_cs()')
, ('ws', 'pkg_fkey_protected',    'schema',       'ws.pg_cs()')
, ('ws', 'pkg_fkey_required_by',  'required_by',  'ws.pg_cs()')
;
/* ------------------------------------------------------------------------- */
