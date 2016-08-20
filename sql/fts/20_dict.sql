/*
  Настройка FTS
*/

  -- Тезаурус (словарь фраз-синонимов) ТПро
  CREATE TEXT SEARCH DICTIONARY public.russian_dict_thesaurus (
    Template =   thesaurus
  , DictFile =   russian_tpro_synonym_phrases
  , Dictionary = russian_stem
  );

  -- Морфологический словарь (русский)
  CREATE TEXT SEARCH DICTIONARY public.russian_dict (
    Template = ispell
  , DictFile = russian
  , AffFile = russian
  , StopWords = russian
  );

  -- Морфологический словарь (английский)
  CREATE TEXT SEARCH DICTIONARY public.english_dict (
    Template = ispell
  , DictFile = english
  , AffFile = english
  , StopWords = english
  );


