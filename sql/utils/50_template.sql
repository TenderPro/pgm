CREATE OR REPLACE FUNCTION template(tmpl TEXT, vars JSONB) RETURNS TEXT IMMUTABLE LANGUAGE 'plpgsql' AS
$_$
DECLARE
  r RECORD;
BEGIN
  FOR r IN SELECT * from jsonb_each_text(vars) LOOP
    tmpl := regexp_replace(tmpl,'{{\s*' || r.key || '\s*}}', r.value);
  END LOOP;
  RETURN tmpl;
END;
$_$;

/*
db-> SELECT template('{{ name}}, you win {{win}}!', '{"name":"John", "win":12345}');
       template       
----------------------
 John, you win 12345!
*/
