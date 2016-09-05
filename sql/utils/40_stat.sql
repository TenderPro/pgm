
-- https://wiki.postgresql.org/wiki/Disk_Usage
CREATE OR REPLACE VIEW pg_table_size AS
  SELECT *, pg_size_pretty(total_bytes) AS total
    , pg_size_pretty(index_bytes) AS INDEX
    , pg_size_pretty(toast_bytes) AS toast
    , pg_size_pretty(table_bytes) AS TABLE
  FROM (
    SELECT *, total_bytes-index_bytes-COALESCE(toast_bytes,0) AS table_bytes FROM (
      SELECT c.oid,nspname AS table_schema, relname AS TABLE_NAME
              , c.reltuples AS row_estimate
              , pg_total_relation_size(c.oid) AS total_bytes
              , pg_indexes_size(c.oid) AS index_bytes
              , pg_total_relation_size(reltoastrelid) AS toast_bytes
          FROM pg_class c
          LEFT JOIN pg_namespace n ON n.oid = c.relnamespace
          WHERE relkind = 'r'
    ) a
  ) a
  ORDER BY total_bytes DESC
  LIMIT 20
;

CREATE OR REPLACE VIEW pg_db_size AS
  SELECT d.datname AS Name,  pg_catalog.pg_get_userbyid(d.datdba) AS Owner,
    CASE WHEN pg_catalog.has_database_privilege(d.datname, 'CONNECT')
        THEN pg_catalog.pg_size_pretty(pg_catalog.pg_database_size(d.datname))
        ELSE 'No Access'
    END AS SIZE
    FROM pg_catalog.pg_database d
    ORDER BY
      CASE WHEN pg_catalog.has_database_privilege(d.datname, 'CONNECT')
        THEN pg_catalog.pg_database_size(d.datname)
        ELSE NULL
      END DESC -- nulls first
    LIMIT 20
;

-- https://www.keithf4.com/a-large-database-does-not-mean-large-shared_buffers/
CREATE OR REPLACE VIEW pg_cached_size AS
  SELECT 
    c.relname
    , pg_size_pretty(count(*) * 8192) as buffered
    , round(100.0 * count(*) / ( SELECT setting FROM pg_settings WHERE name='shared_buffers')::integer,1) AS buffers_percent
    , round(100.0 * count(*) * 8192 / pg_relation_size(c.oid),1) AS percent_of_relation
    FROM pg_class c
    INNER JOIN pg_buffercache b ON b.relfilenode = c.relfilenode
    INNER JOIN pg_database d ON (b.reldatabase = d.oid AND d.datname = current_database())
    WHERE pg_relation_size(c.oid) > 0
    GROUP BY c.oid, c.relname
    ORDER BY 3 DESC
    LIMIT 10
;

-- our
CREATE OR REPLACE VIEW pg_sql AS
  SELECT
    datname
    , NOW() - query_start AS duration
    , application_name
    , pid procpid
    , query current_query
    FROM pg_stat_activity
    WHERE query <> '<IDLE>'
    ORDER BY duration DESC
;
