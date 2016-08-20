
SELECT test(:'TEST');

SELECT 
       token
      ,dictionary
      ,lexemes
       FROM 
         ts_debug(const_search(),'words стальные листов листового остальные ксерокс existing operations')
       WHERE 
         lexemes IS NOT NULL
     ;

