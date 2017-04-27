/*
  Служебные функции
  Операции с search_path
*/

-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION search_path_set(a_path TEXT) RETURNS VOID LANGUAGE 'plpgsql' AS
$_$
  -- a_path: путь поиска
  DECLARE
    v_sql TEXT;
  BEGIN
    v_sql := 'SET LOCAL search_path = ' || a_path;
    EXECUTE v_sql;
  END;
$_$;
SELECT pg_c('f', 'search_path_set', 'установить переменную search_path');

-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION lang_set(a_lang TEXT DEFAULT NULL) RETURNS TEXT LANGUAGE 'plpgsql' AS
$_$
  -- a_lang:  язык
  DECLARE
    v_lang     TEXT;
    v_path_old TEXT;
    v_path_new TEXT;
  BEGIN
    v_lang := COALESCE(NULLIF(a_lang, 'ru'), 'def');
    EXECUTE 'SHOW search_path' INTO v_path_old;
    IF v_path_old ~ E'i18n_\w+' THEN
      v_path_new := regexp_replace(v_path_old, E'i18n_\\w+', 'i18n_' || v_lang);
    ELSE
      v_path_new := 'i18n_' || v_lang || ', '|| v_path_old;
    END IF;
    PERFORM utils.search_path_set(v_path_new);
    RETURN v_path_old;
  END;
$_$;
SELECT pg_c('f', 'lang_set', 'установить локаль и вернуть search_path до изменения');
