/*

    Copyright (c) 2010, 2012 Tender.Pro http://tender.pro.
    [SQL_LICENSE]

    Представления информации БД Postgresql
*/

/* ------------------------------------------------------------------------- */
do language plpgsql $$
declare
    pg_version integer;
begin

    select setting into pg_version from pg_settings where name = 'server_version_num';

    if pg_version < 90200 then
        CREATE OR REPLACE VIEW pg_sql AS SELECT
        datname
        , NOW() - query_start AS duration
        , application_name
        , procpid
        , current_query
        FROM pg_stat_activity
        WHERE current_query <> '<IDLE>'
        ORDER BY duration DESC
        ;
    else
        CREATE OR REPLACE VIEW pg_sql AS SELECT
        datname
        , NOW() - query_start AS duration
        , application_name
        , pid procpid
        , query current_query
        FROM pg_stat_activity
        WHERE query <> '<IDLE>'
        ORDER BY duration DESC
        ;
    end if;

    perform pg_c('v', 'pg_sql', 'Текущие запросы к БД')
    ;

end
$$;

/* ------------------------------------------------------------------------- */
CREATE OR REPLACE VIEW pg_const AS SELECT
  ws.pg_schema_by_oid(pronamespace) AS schema
, proname AS code
, pg_catalog.format_type(p.prorettype, NULL) AS type
, ws.pg_exec_func(ws.pg_schema_by_oid(pronamespace), proname) AS value
, obj_description(p.oid, 'pg_proc') AS anno
  FROM pg_catalog.pg_proc p
  WHERE p.proname LIKE 'const_%'
  ORDER BY 1, 2
;
SELECT pg_c('v', 'pg_const', 'Справочник внутренних констант пакетов');
