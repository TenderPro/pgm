DROP TEXT SEARCH DICTIONARY IF EXISTS public.russian_dict_thesaurus cascade;
DROP TEXT SEARCH DICTIONARY IF EXISTS public.russian_dict cascade;
DROP TEXT SEARCH DICTIONARY IF EXISTS public.english_dict cascade;

-- удаляется при каскадном удалении словарей только если они используются
DROP TEXT SEARCH CONFIGURATION IF EXISTS public.ru_en cascade;
