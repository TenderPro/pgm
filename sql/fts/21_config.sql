  -- Порядок применения словарей
  CREATE TEXT SEARCH CONFIGURATION public.ru_en(copy = english);

  ALTER TEXT SEARCH CONFIGURATION public.ru_en
    ALTER MAPPING FOR asciihword, asciiword, hword_asciipart
    WITH
      russian_dict_thesaurus		-- тезаурус (словарь фраз-синонимов)
    , english_dict			-- морфологический словарь английского языка
    , english_stem			-- системный словарь английского
  ;
  ALTER TEXT SEARCH CONFIGURATION public.ru_en
    ALTER MAPPING FOR hword, hword_part, word
    WITH
      russian_dict_thesaurus		-- тезаурус (словарь фраз-синонимов)
    , russian_dict			-- морфологический словарь русского языка
    , russian_stem			-- системный словарь русского
  ;
