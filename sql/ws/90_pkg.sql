/*

    Copyright (c) 2010, 2016 Tender.Pro http://tender.pro.
    [SQL_LICENSE]

    Тестирование пакета ws
*/

/* ------------------------------------------------------------------------- */
SELECT ws.test('pg_store_proc'); -- BOT
/*
  Описание ф-и pg_store_proc_descr
*/
SELECT * FROM ws.pg_store_proc_descr('ws') WHERE name = 'pg_store_proc_descr' ORDER BY name ASC; -- EOT
/* ------------------------------------------------------------------------- */
