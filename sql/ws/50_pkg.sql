/*

    Copyright (c) 2010, 2012 Tender.Pro http://tender.pro.
    [SQL_LICENSE]

    Компиляция и установка пакетов
*/

/* ------------------------------------------------------------------------- */
CREATE OR REPLACE FUNCTION compile_errors_chk() RETURNS TEXT STABLE LANGUAGE 'plpgsql' AS
$_$
  DECLARE
    v_t TIMESTAMP := CURRENT_TIMESTAMP;
  BEGIN
    SELECT INTO v_t stamp FROM ws.compile_errors WHERE stamp = v_t LIMIT 1;
      IF FOUND THEN
        RAISE EXCEPTION '***************** Errors found *****************';
      END IF;
    RETURN 'Ok';
  END;
$_$;
SELECT pg_c('f', 'compile_errors_chk', 'сообщение компиляции');

/* ------------------------------------------------------------------------- */
CREATE OR REPLACE FUNCTION test(a_code TEXT) RETURNS TEXT VOLATILE LANGUAGE 'plpgsql' AS
$_$
  -- a_code:  сообщение для теста
  BEGIN
    -- RAISE WARNING parsed for test output
    IF a_code IS NULL THEN
      RAISE WARNING '::';
    ELSE
      RAISE WARNING '::%', 't/'||a_code;
    END IF;
    -- RETURN saved to .md
    RETURN a_code;
  END;
$_$;
SELECT pg_c('f', 'test', 'метка теста');

/* ------------------------------------------------------------------------- */
CREATE OR REPLACE FUNCTION pkg(a_code TEXT) RETURNS ws.pkg STABLE LANGUAGE 'sql' AS
$_$
  -- a_code:  пакет
  SELECT * FROM ws.pkg WHERE code = $1;
$_$;
SELECT pg_c('f', 'pkg', 'актуальная информация о пакете');

/* ------------------------------------------------------------------------- */
CREATE OR REPLACE FUNCTION pkg_references(
  a_is_on  BOOL
, a_pkg    name
, a_schema name DEFAULT NULL
) RETURNS SETOF TEXT VOLATILE LANGUAGE 'plpgsql' AS
$_$
  -- a_is_on:  флаг активности
  -- a_pkg:    пакет
  -- a_schema: связанная схема
  DECLARE
    r              RECORD;
    v_sql          TEXT;
    v_self_default TEXT;
  BEGIN
    -- defaults
    FOR r IN SELECT * 
      FROM wsd.pkg_default_protected
      WHERE pkg = a_pkg
        AND schema IS NOT DISTINCT FROM a_schema
        AND is_active = NOT a_is_on
    LOOP
      v_sql := CASE WHEN a_is_on THEN
        format('ALTER TABLE wsd.%s ALTER COLUMN %s SET DEFAULT %s'
          , quote_ident(r.wsd_rel) 
          , quote_ident(r.wsd_col) 
          , r.func
          )
      ELSE       
        format('ALTER TABLE wsd.%s ALTER COLUMN %s DROP DEFAULT'
        , quote_ident(r.wsd_rel) 
        , quote_ident(r.wsd_col) 
        )
      END;
      IF r.wsd_rel = 'pkg_default_protected' THEN
        v_self_default := v_sql; -- мы внутри цикла по этой же таблице
      ELSE
        EXECUTE v_sql;
      END IF;
      RETURN NEXT v_sql;
    END LOOP;
    IF v_self_default IS NOT NULL THEN
      EXECUTE v_self_default;
    END IF;
    UPDATE wsd.pkg_default_protected SET is_active = a_is_on
      WHERE pkg = a_pkg
        AND schema IS NOT DISTINCT FROM a_schema
        AND is_active = NOT a_is_on
    ;
    
    -- fkeys
    
        -- Перед удалением пакета - удаление всех присоединенных пакетом зарегистрированных FK
        -- rel in (select rel from wsd.pkg_fkey_required_by where required_by = a_pkg
        -- После создания пакета - создание всех еще несуществующих зарегистрированных FK присоединенных пакетом таблиц 
      --  NOT is_active AND rel not in (select rel from wsd.pkg_fkey_required_by where required_by not in (select code from ws.pkg)
    
    v_self_default := NULL;
    FOR r IN SELECT * 
      FROM wsd.pkg_fkey_protected
      WHERE is_active = NOT a_is_on
        AND CASE WHEN a_is_on THEN
          rel NOT IN (SELECT rel FROM wsd.pkg_fkey_required_by WHERE required_by NOT IN (SELECT code FROM ws.pkg))
            AND EXISTS (SELECT 1 FROM ws.pkg WHERE code = pkg) and EXISTS (SELECT 1 FROM ws.pkg where schemas @> array[pkg_fkey_protected.schema]::name[])
          ELSE
          (pkg = a_pkg AND schema IS NOT DISTINCT FROM a_schema)
          OR rel IN (SELECT rel FROM wsd.pkg_fkey_required_by WHERE required_by = a_pkg)
        END
    LOOP
      v_sql := CASE WHEN a_is_on THEN
        format('ALTER TABLE wsd.%s ADD CONSTRAINT %s FOREIGN KEY (%s) REFERENCES %s'
          , quote_ident(r.wsd_rel)
          , r.wsd_rel || '_' || replace(regexp_replace(r.wsd_col, E'\\s','','g'), ',', '_') || '_fkey'
          , r.wsd_col -- может быть список колонок через запятую 
          , r.rel
          )
      ELSE       
        format('ALTER TABLE wsd.%s DROP CONSTRAINT %s'
          , quote_ident(r.wsd_rel)
          , r.wsd_rel || '_' || replace(regexp_replace(r.wsd_col, E'\\s','','g'), ',', '_') || '_fkey'
        )
      END;
      IF r.wsd_rel = 'pkg_fkey_protected' THEN
        v_self_default := v_sql; -- мы внутри цикла по этой же таблице
      ELSE
        EXECUTE v_sql;
      END IF;
      RETURN NEXT v_sql;
    END LOOP;
    IF v_self_default IS NOT NULL THEN
      EXECUTE v_self_default;
    END IF;
    UPDATE wsd.pkg_fkey_protected SET is_active = a_is_on
      WHERE is_active = NOT a_is_on
        AND CASE WHEN a_is_on THEN
          rel NOT IN (SELECT rel FROM wsd.pkg_fkey_required_by WHERE required_by NOT IN (SELECT code FROM ws.pkg))
            AND EXISTS (SELECT 1 FROM ws.pkg WHERE code = pkg) and EXISTS (SELECT 1 FROM ws.pkg where schemas @> array[pkg_fkey_protected.schema]::name[])
          ELSE
          (pkg = a_pkg AND schema IS NOT DISTINCT FROM a_schema)
          OR rel IN (SELECT rel FROM wsd.pkg_fkey_required_by WHERE required_by = a_pkg)
        END
    ;
    RETURN;
  END;
$_$;
SELECT pg_c('f', 'pkg_references', 'обработка пакета и связанных схем');

/* ------------------------------------------------------------------------- */
CREATE OR REPLACE FUNCTION pkg_op_before(
  a_op         t_pkg_op
, a_code       name
, a_schema     name
, a_log_name   TEXT
, a_user_name  TEXT
, a_ssh_client TEXT
) RETURNS TEXT VOLATILE LANGUAGE 'plpgsql' AS
$_$
  -- a_op:          стадия
  -- a_code:        пакет 
  -- a_schema:      список схем
  -- a_log_name:    имя 
  -- a_user_name:   имя пользователя 
  -- a_ssh_client:  ключ
  DECLARE
    r_pkg          ws.pkg%ROWTYPE;
    r              RECORD;
    v_sql          TEXT;
    v_self_default TEXT;
    v_pkgs         TEXT;
  BEGIN
    r_pkg := ws.pkg(a_code);
    CASE a_op
      WHEN 'create' THEN
        IF r_pkg IS NOT NULL AND a_schema = ANY(r_pkg.schemas)THEN
          RAISE EXCEPTION '***************** Package % schema % installed already at % (%) *****************'
          , a_code, a_schema, r_pkg.stamp, r_pkg.id
          ;
        END IF;
        IF r_pkg IS NULL THEN
          INSERT INTO ws.pkg (id, code, schemas, log_name, user_name, ssh_client, op) VALUES 
            (NEXTVAL('ws.pkg_id_seq'), a_code, ARRAY[a_schema], a_log_name, a_user_name, a_ssh_client, a_op)
            RETURNING * INTO r_pkg
          ;
        ELSE 
          UPDATE ws.pkg SET
            id          = NEXTVAL('ws.pkg_id_seq') -- runs after rule
          , schemas     = array_append(schemas, a_schema)
          , log_name    = a_log_name
          , user_name   = a_user_name
          , ssh_client  = a_ssh_client
          , stamp       = now()
          , op          = a_op
          WHERE code = a_code
            RETURNING * INTO r_pkg
          ;
        END IF;
        r_pkg.schemas = ARRAY[a_schema]; -- save schema in log
        INSERT INTO ws.pkg_log VALUES (r_pkg.*);
      WHEN 'make' THEN
        UPDATE ws.pkg SET
          id            = NEXTVAL('ws.pkg_id_seq') -- runs after rule
        , log_name    = a_log_name
        , user_name   = a_user_name
        , ssh_client  = a_ssh_client
        , stamp       = now()
        , op          = a_op
        WHERE code = a_code
          RETURNING * INTO r_pkg
        ;
        IF NOT FOUND THEN
          RAISE EXCEPTION '***************** Package % schema % does not found *****************'
          , a_code, a_schema
          ;
        END IF;
        r_pkg.schemas = ARRAY[a_schema]; -- save schema in log
        INSERT INTO ws.pkg_log VALUES (r_pkg.*);
      WHEN 'drop', 'erase' THEN
        SELECT INTO v_pkgs
          array_to_string(array_agg(required_by::TEXT),', ')
          FROM ws.pkg_required_by 
          WHERE code = a_code
        ;
        IF v_pkgs IS NOT NULL THEN
          RAISE EXCEPTION '***************** Package % is required by others (%) *****************', a_code, v_pkgs;
        END IF;
        PERFORM ws.pkg_references(FALSE, a_code, a_schema);
        IF a_schema <> 'ws' OR a_code = 'ws' THEN
          -- удаляем описания ошибок, заданные в этой схеме
          -- кроме случая удаления схемы ws не в пакете ws
          DELETE FROM ws.error_data ed USING ws.pg_const c 
            WHERE c.code LIKE 'const_error%' 
              AND c.schema = a_schema
              AND ed.code = c.value
          ;
        END IF;

    END CASE;
    RETURN 'Ok';
  END;
$_$;
SELECT pg_c('f', 'pkg_op_before', 'обработка пакета до');

/* ------------------------------------------------------------------------- */
CREATE OR REPLACE FUNCTION pkg_op_after(
  a_op         t_pkg_op
, a_code       name
, a_schema     name
, a_log_name   TEXT
, a_user_name  TEXT
, a_ssh_client TEXT
) RETURNS TEXT VOLATILE LANGUAGE 'plpgsql' AS
$_$
  -- a_op:           стадия
  -- a_code:         пакет
  -- a_schema:       список схем
  -- a_log_name:     имя
  -- a_user_name:    имя пользователя
  -- a_ssh_client:   ключ
  DECLARE
    r_pkg          ws.pkg%ROWTYPE;
    r              RECORD;
    v_sql          TEXT;
    v_self_default TEXT;
  BEGIN
    r_pkg := ws.pkg(a_code);
    CASE a_op
      WHEN 'create' THEN
        IF a_code = 'ws' AND a_schema = 'ws' THEN
          INSERT INTO ws.pkg (id, code, schemas, log_name, user_name, ssh_client, op) VALUES 
            (NEXTVAL('ws.pkg_id_seq'), a_code, ARRAY[a_schema], a_log_name, a_user_name, a_ssh_client, a_op)
            RETURNING * INTO r_pkg
          ;
          r_pkg.schemas = ARRAY[a_schema]; -- save schema in log
          INSERT INTO ws.pkg_log VALUES (r_pkg.*);
        END IF;
        PERFORM ws.pkg_references(TRUE, a_code, a_schema);
        UPDATE ws.pkg SET op = 'done' WHERE code = a_code;
      WHEN 'drop', 'erase' THEN
        INSERT INTO ws.pkg_log (id, code, schemas, log_name, user_name, ssh_client, op)
          VALUES (NEXTVAL('ws.pkg_id_seq'), a_code, ARRAY[a_schema], a_log_name, a_user_name, a_ssh_client, a_op)
        ;
/* TODO: trigger ON ws.pkg
        IF a_schema <> 'ws' THEN
          DELETE FROM ws.method           WHERE pkg = a_schema;
          DELETE FROM ws.page_data        WHERE pkg = a_schema;
          -- удалить классы пакета
          DELETE FROM ws.class WHERE pkg = a_schema;
        END IF;  
        -- удалить неиспользуемые группы
        DELETE FROM i18n_def.page_group pg WHERE NOT EXISTS(SELECT code FROM ws.page_data WHERE group_id = pg.id);
*/

        IF a_op = 'erase' AND a_schema <> 'ws' THEN
          DELETE FROM wsd.pkg_script_protected  WHERE pkg = a_schema;
          DELETE FROM wsd.pkg_default_protected WHERE pkg = a_schema;
          DELETE FROM wsd.pkg_fkey_protected    WHERE pkg = a_schema;
          DELETE FROM wsd.pkg_fkey_required_by  WHERE required_by = a_schema;
        END IF;
        DELETE FROM ws.pkg_required_by  WHERE required_by = a_schema;
        IF r_pkg.schemas = ARRAY[a_schema] THEN
          -- last/single schema
          DELETE FROM ws.pkg WHERE code = a_code;
        ELSE  
          UPDATE ws.pkg SET
            schemas = ws.array_remove(schemas, a_schema)
            WHERE code = a_code
          ;
        END IF;
      WHEN 'make' THEN
        NULL;
    END CASE;
    RETURN 'Ok';
  END;
$_$;
SELECT pg_c('f', 'pkg_op_after', 'обработка пакета после');

/* ------------------------------------------------------------------------- */
CREATE OR REPLACE FUNCTION pkg_require(a_code TEXT) RETURNS TEXT STABLE LANGUAGE 'plpgsql' AS
$_$
  -- a_code:
  BEGIN
    RAISE NOTICE 'TODO: function needs code';
    RETURN NULL;
  END
$_$;
SELECT pg_c('f', 'pkg_require', '..');
/* ------------------------------------------------------------------------- */
CREATE OR REPLACE FUNCTION pg_store_proc_descr(a_schema TEXT)
  RETURNS TABLE(name TEXT, comment TEXT, args JSON, result JSON) LANGUAGE sql STABLE AS
$_$
  -- a_schema:       название схемы
  SELECT R.proname
  , R.description
  , (
      CASE WHEN ( SUBSTRING( LTRIM( (R.params)::text ), 1, 1 ) = '"' ) --если скаляр
      THEN R.params
      ELSE (
        SELECT json_agg( T.v ) FROM (
          SELECT json_array_elements(R.params)->'fld' as v
        ) T
      ) end
  )
  , (
      CASE WHEN ( SUBSTRING( LTRIM( (R.result)::text ), 1, 1 ) = '"' ) --если скаляр
      THEN R.result
      ELSE (
        SELECT json_agg( T.v ) FROM (
          SELECT json_array_elements(R.result)->'fld' as v
        ) T
      ) end
  )
  FROM (
    SELECT p.proname::TEXT
    , pd.description
    , (
        SELECT array_to_json( (
          SELECT array_agg(DISTINCT ROW(T.elem)::ws.t_textarr) ) ) 
          FROM (
            SELECT ARRAY[a, b/*, row_number() over()*/]::TEXT[] as elem --порядковый номер аргумента отключен
            FROM (
              SELECT UNNEST( p.proargnames ) AS a
                , UNNEST( ( 
                    SELECT array_agg( J.type_name)
                    FROM ( 
                      SELECT ( 
                        SELECT ws.pg_type_name(T.type) 
                      ) as type_name 
                      FROM (
                        SELECT UNNEST(p.proargtypes) as type
                      ) T 
                    ) J ) 
                  ) AS b
            ) x LIMIT pronargs
          ) T 
      ) as params
    , (
        CASE WHEN p.proretset
        THEN (
          SELECT array_to_json( (
            SELECT array_agg(DISTINCT ROW(T.elem)::ws.t_textarr) ) )
            FROM (
              SELECT ARRAY[a, b/*, ( row_number() over() ) - pronargs*/]::TEXT[] as elem  --порядковый номер аргумента отключен
              FROM (
                SELECT UNNEST( p.proargnames ) AS a
                  , UNNEST( ( 
                      SELECT array_agg(J.type_name)
                        FROM (
                          SELECT ( 
                            SELECT ws.pg_type_name(T.type) 
                          ) as type_name 
                          FROM (
                            SELECT UNNEST(p.proallargtypes) as type
                          ) T
                        ) J ) 
                      ) AS b
              ) x offset pronargs
            ) T 
        )
        ELSE
          to_json(pg_catalog.format_type(p.prorettype, NULL))
        END 
      ) as result
    FROM pg_catalog.pg_proc p
      JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
      LEFT JOIN pg_description pd ON pd.objoid = p.oid
    WHERE n.nspname = a_schema
  ) R
$_$;
SELECT pg_c('f', 'pg_store_proc_descr', 'получить описание аргументов и параметров хранимых процедур в указанной схеме');
/* ------------------------------------------------------------------------- */