/*

    Copyright (c) 2010, 2012 Tender.Pro http://tender.pro.
    [SQL_LICENSE]

    Таблицы для компиляции и установки пакетов
*/

/* ------------------------------------------------------------------------- */
CREATE TABLE compile_errors (
  data  TEXT
, stamp TIMESTAMP DEFAULT current_timestamp
, usr   TEXT DEFAULT current_user
, ip    INET DEFAULT inet_client_addr()
);
SELECT pg_c('r', 'compile_errors', 'Буфер хранения ошибок на этапе компиляции')
, pg_c('c', 'compile_errors.data', 'текст')
, pg_c('c', 'compile_errors.stamp', 'Момент компиляции')
, pg_c('c', 'compile_errors.usr', 'Имя пользователя соединения с БД')
, pg_c('c', 'compile_errors.ip', 'IP пользователя соединения с БД')
;

/* ------------------------------------------------------------------------- */
CREATE TABLE pkg_log (
  id          d_id PRIMARY KEY
, code        d_code NOT NULL DEFAULT 'ws'
, schemas     name[] NOT NULL
, op          t_pkg_op
, log_name    TEXT
, user_name   TEXT
, ssh_client  TEXT
, usr         TEXT DEFAULT current_user
, ip          INET DEFAULT inet_client_addr()
, stamp       TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

SELECT pg_c('r', 'pkg_log', 'Журнал изменений пакетов PGWS')
, pg_c('c', 'pkg_log.id',         'ID изменения')
, pg_c('c', 'pkg_log.code',       'Код пакета')
, pg_c('c', 'pkg_log.schemas',    'Список схем, созданных пакетом')
, pg_c('c', 'pkg_log.op',         'Код операции (create, drop, erase, make)')
, pg_c('c', 'pkg_log.log_name',   '$LOGNAME из сессии пользователя в ОС')
, pg_c('c', 'pkg_log.user_name',  '$USERNAME из сессии пользователя в ОС')
, pg_c('c', 'pkg_log.ssh_client', '$SSH_CLIENT из сессии пользователя в ОС')
, pg_c('c', 'pkg_log.usr',        'Имя пользователя соединения с БД')
, pg_c('c', 'pkg_log.ip',         'IP пользователя соединения с БД')
, pg_c('c', 'pkg_log.stamp',      'Момент выполнения изменения')
;

CREATE SEQUENCE pkg_id_seq;
ALTER TABLE pkg_log ALTER COLUMN id SET DEFAULT NEXTVAL('pkg_id_seq');

/* ------------------------------------------------------------------------- */
CREATE TABLE pkg (
  id          d_id NOT NULL UNIQUE
, code        d_code PRIMARY KEY -- для REFERENCES
, schemas     name[]
, op          t_pkg_op
, log_name    TEXT
, user_name   TEXT
, ssh_client  TEXT
, usr         TEXT DEFAULT current_user
, ip          INET DEFAULT inet_client_addr()
, stamp       TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
SELECT pg_c('r', 'pkg', 'Актуальные (последние) изменения пакетов PGWS')
, pg_c('c', 'pkg.id',         'ID изменения')
, pg_c('c', 'pkg.code',       'Код пакета')
, pg_c('c', 'pkg.schemas',    'Список схем, созданных пакетом')
, pg_c('c', 'pkg.op',         'Код крайней операции (create, drop, erase, make)')
, pg_c('c', 'pkg.log_name',   '$LOGNAME из сессии пользователя в ОС')
, pg_c('c', 'pkg.user_name',  '$USERNAME из сессии пользователя в ОС')
, pg_c('c', 'pkg.ssh_client', '$SSH_CLIENT из сессии пользователя в ОС')
, pg_c('c', 'pkg.usr',        'Имя пользователя соединения с БД')
, pg_c('c', 'pkg.ip',         'IP пользователя соединения с БД')
, pg_c('c', 'pkg.stamp',      'Момент выполнения изменения')
;

/* ------------------------------------------------------------------------- */
CREATE TABLE pkg_required_by (
  code        d_code REFERENCES ws.pkg
, required_by d_code DEFAULT ws.pg_cs()
, CONSTRAINT pkg_required_by_pkey PRIMARY KEY (code, required_by)
);
SELECT pg_c('r', 'pkg_required_by', 'Зависимоcть пакета от другого пакета')
, pg_c('c', 'pkg_required_by.code',         'Код пакета')
, pg_c('c', 'pkg_required_by.required_by',  'Код зависимого пакета')
;
