/*

    Copyright (c) 2010, 2016 Tender.Pro http://tender.pro.
    [SQL_LICENSE]

    Тестирование пакета ws
*/

/* ------------------------------------------------------------------------- */
-- test1
SELECT ws.test('pg_store_proc');
SELECT * FROM ws.pg_store_proc_descr('ws') WHERE name = 'pg_store_proc_descr' ORDER BY name ASC; -- EOT
/* ------------------------------------------------------------------------- */
