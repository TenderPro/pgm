CREATE OR REPLACE FUNCTION public.const_search() RETURNS regconfig IMMUTABLE LANGUAGE 'sql' AS
$_$
  SELECT 'public.ru_en'::regconfig
$_$;
COMMENT ON FUNCTION public.const_search() IS 'Имя схемы FTS по умолчанию';
