# fts:90_debug

## fts/90_debug

```sql
SELECT
  token
, dictionary
, lexemes
FROM
  ts_debug(const_search(),'words стальные листов листового остальные ксерокс existing operations')
WHERE
  lexemes IS NOT NULL
;
```
   token    |       dictionary       |     lexemes      
------------|------------------------|------------------
 words      | english_dict           | {word}
 стальные   | russian_dict           | {стальной}
 листов     | russian_dict           | {лист}
 листового  | russian_dict           | {листовой}
 остальные  | russian_dict           | {остальной}
 ксерокс    | russian_dict_thesaurus | {xerox}
 existing   | english_dict           | {existing,exist}
 operations | english_dict           | {operate}

