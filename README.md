
pgm. Postgresql manager
=======================

pgm - это shell-скрипт для создания, обновления и удаления объектов БД.
В текущей версии скрипт поддерживает только СУБД Postgresql.

## Быстрый старт

Выполняется после установки [pg-skel](http://git.it.tender.pro/iac/pg-skel).

Текущий каталог - место для нового sql-проекта.

Создаем в нем подкаталог (или подмодуль или симлинк) pgm:
```
git clone git@git.it.tender.pro:iac/pgm.git
```

Проверяем наличие используемых программ
```
bash pgm/pgm.sh check
```
Если не все Ок - надо установить недостающее штатными средствами ОС.

Создаем файл настроек .config
```
bash pgm/pgm.sh init
```

Редактируем .config. Надо прописать пользователя с правами создания БД. Его можно создать, используя [Доступ к БД под суперпользователем](http://git.it.tender.pro/iac/pg-skel#--psql--).

В параметре **DB_TEMPLATE** надо указать имя шаблона БД, созданного с помощью [pg-skel](http://git.it.tender.pro/iac/pg-skel).

Создание БД
```
bash pgm/pgm.sh createdb
```

Создание объектов pgm
```
SQLROOT=pgm/sql bash pgm/pgm.sh creatif ws utils
```

Создание файлов пакета demo
```
bash pgm/pgm.sh init demo
```
После этой операции будут созданы первичные файлы в каталоге `sql/`. (См ниже [Размещение SQL-кода](#-sql-)).

Загрузка пакета demo в БД
```
bash pgm/pgm.sh make demo
```

## Структура БД

Работа с БД является развитием идеи разделения БД на три составляющих:

1. Оперативные данные (ОД) - таблицы, которые изменяются в процессе эксплуатации
2. Внешние связи этих таблиц (FOREIGN KEY, DEFAULT)
3. Все остальные объекты (изменяются только в процессе разработки)

Разделение оперативных (вводимых в процессе эксплуатации) и справочных (вводимых в процессе разработки системы) данных реализовано следующим образом:

1. Все таблицы оперативных данных создаются в схеме `wsd`
2. Справочные данные создаются в индивидуальных схемах 
3. Весь код поддержки изменения данных (и их чтения) создается в индивидуальных схемах

Кроме этого, код и данные поддержки pgm размещаются в схеме `ws`.

Такая реализация позволяет полностью удалить весь код пакета (методы, триггеры, справочные данные), сохранив оперативные данные (команда `drop`) или удалив и их (команда `erase`), т.е. не нужно писать скрипт обновления версии А до версии В, достаточно удалить пакет (или все), обновить ПО (`git pull`) и создать пакет(ы) заново (`create`).

Под **схемой** понимается схема БД (создаваемая командой `CREATE SCHEMA`).
Весь код создания объектов схемы размещается в одноименном схеме каталоге.

**Пакет** - логическое объединение нескольких схем. Может состоять и из одной схемы.

## Команды pgm

Скрипт pgm реализует выполнение в БД операций:

* init PKGS - создать .config по шаблону
* create PKGS - создать объекты БД
* creatif PKGS - создать объекты БД, если их нет
* recreate PKGS - создать объекты БД, предварительно удалив
* make PKGS - выполнить компилируемый код (CREATE OR REPLACE)
* drop PKGS - удалить объектв БД (кроме wsd)
* erase PKGS - очистить бд (включая удаление wsd)
* createdb - создать БД
* dump SCHEMA - дамп заданной схемы
* restore SCHEMA - восстановление дампа

где

* PKGS - список имен пакетов в порядке создания
* SCHEMA - имя схемы БД

Работа скрипта заключается в формировании соответствующего файла var/build/build.sql и выполнении его в psql

## Размещение SQL-кода

SQL-код размещается в каталогах схемы

* sql/PKG/NN_SCHEMA/ (NN - с порядковый номер обработки схемы при обработке пакета)
* sql/PKG/ (если SCHEMA=PKG)

Каталог схемы содержит .sql файлы
Формат имени .sql файла - `MM_descr.sql` - файл с типом MM и описанием descr

тип MM имеет значения:

* 00 - drop/erase: удаление связей текущей схемы с другими схемами
* 01 - erase: удаление защищенных объектов из других схем (wsd)
* 02 - drop/erase: удаление текущей схемы (02_drop)
* 10 - init: инициализация до создания схемы
* 11 - init: создание схемы, после выполнения 11* имя схемы из имени каталога добавится в путь поиска
* 12 - init: зависимости от других пакетов, создание доменов и типов
* 1[4-9] - общие файлы для init и make, код, не имеющий зависимостей от объектов, может использоваться при создании таблиц
* 2x - создание таблиц
* 3x - ф-и для представлений
* 4x - представления
* 5x - основной код функций
* 6x - код триггеров
* 7x - создание триггеров
* 8x - наполнение таблиц
* 9x - тесты

Файлы выполняются в порядке сортировки имен.

Для каждой из операций выбираются файлы по соответствующей маске:

* init:   [1-9]?_*.sql
* make:   1[4-9]_*.sql, [3-6]?_*.sql, 9?_*.sql
* drop:   00_*.sql, 02_*.sql
* erase:  0?_*.sql

## Код, меняющий схему wsd

В каждом пакете код, который производит изменения в схеме оперативных данных (wsd), решает одну из следующих задач:

* **инициализация**, создание таблиц в схеме wsd (20_wsd_000.sql)
* **привязка** объектов пакета в схеме wsd (создание внешних ключей и триггеров - 8?_*_wsd_000.sql)
* **очистка** схемы wsd от объектов пакета (01_drop_wsd.sql)
* **удаление** связей объектов схемы wsd с объектами пакета (00_cleanup.sql)

Задачи **привязка** и **удаление** выполняются при стандартном обновлении пакета (`create` и `drop` соответственно), **очистка** выполняется при полном удалении пакета (`erase`), а **инициализация** должна выполняться только перед привязкой, которая производится впервые или после очистки.

Особенности **инициализации** реализованы следующим образом:

* Файл, содержащий команды **инициализации**, имеет в имени суффикс `_wsd_NNN.sql`
* При первом выполнении файла с таким суффиксом (по команде `create` ), его атрибуты (включая контрольную сумму) сохраняются в таблице `wsd.pkg_script_protected`
* При наличии файла в этой таблице, при выполнении `create` (после `drop`) его повторный запуск не производится. При изменении контрольной суммы выводится уведомление об этом.
* Удаление строки из `wsd.pkg_script_protected` производится при выполнении `erase pkg` автоматически.

## Обновление версий

Используемая техника создания объектов БД позволяет обновлять все схемы БД посредством цепочки `drop`, `git update`, `create`. 
Задача обновления схемы wsd решается следующим образом:

* После установки релиза прекращается изменение существующих файлов `*_wsd_000.sql`
* Для изменений схемы wsd создаются новые файлы, (`*_wsd_001.sql` итд)
* При обновлении системы каждый такой файл отработает на БД однократно

## Зависимости пакетов

Согласно принятой архитектуре, любой пакет ничего не знает о пакетах, которые будут добавлены в БД после него.
Т.е., если есть *pkg_B*, использующий данные (или код) из *pkg_A*, то *pkg_A* об этом ничего не знает. 
Это порождает необходимость существования механизма, который бы

* Запретил установку *pkg_B* при отсутствии установленного *pkg_A*
* Запретил удаление *pkg_A* при наличии установленного *pkg_B*

Этот механизм реализовывается добавлением в sql-каталог *Пакета_В* файла `12_deps.sql`, содержащего инструкцию вида

```sql
INSERT INTO ws.pkg_required_by(code) VALUES ('Пакет_А');
```

## Внешние ключи

В некоторых случаях пакетам необходимо менять внутренние данные в схемах других пакетов (например, справочники файл-сервера). Т.е. возникает ситуация, когда

* 1. *pkg_A* создает таблицу `wsd.T1`, которая ссылается на таблицу пакета `pkg_A.T2` внешним ключом `FK1`

Пример:

```
Пакет FS создает wsd.file_link, поля которой (class_id, folder_code) REFERENCES fs.folder(class_id, code)
```

* 2. *pkg_B* для работы с `wsd.T1` добавляет строки в `pkg_A.T2`

Пример:

```
Пакет wiki добавляет в fs.folder(class_id, code) VALUES (12, 'files') - папку для файлов wiki
```
 
* 3. В процессе эксплуатации происходит наполнение данными таблицы `wsd.Т1`

В результате возникают вопросы

* удалять ли внешний ключ `FK1`, если удаляются пакеты *pkg_A* или *pkg_B*, но остаются данные в `wsd.T1`?
* создавать ли внешний ключ `FK1` при повторном создании *pkg_A* или *pkg_B*?

Эти вопросы решаются следующим образом:

* регистрируется зависимость *pkg_B* от *pkg_A*
```sql
INSERT INTO ws.pkg_required_by(code) VALUES ('fs');
```
, чем запрещается 
* создание pkg_B при отсутствии pkg_A
* удаление pkg_A при наличии pkg_B

* pkg_A не создает внешний ключ FK1, а регистрирует его в таблице wsd.pkg_fkey_protected
```sql
INSERT INTO wsd.pkg_fkey_protected (rel, wsd_rel, wsd_col) VALUES
  ('fs.folder', 'file_link',  'class_id, folder_code')
;
```

* регистрируется зависимость данных pkg_B от внешнего ключа pkg_A
```sql
INSERT INTO wsd.pkg_fkey_required_by (pkg, rel) VALUES ('fs','fs.folder');
```

В результате внешний ключ `FK1`

* удаляется перед удалением первого же зависящего от него пакета
* при наличии данных в wsd, создается после создания всех зависящих от него пакетов

Т.е. при удалении *pkg_B* можно удалять строки из `pkg_A.T2`, а при создании - добавлять:

* После создания пакета - создаются все еще несуществующие зарегистрированные FK присоединенных пакетом таблиц 
* Перед удалением пакета - удаляются все зарегистрированные пакетом зависимости FK

## Значения по умолчанию

Со значениями по умолчанию, если они заданы функцией, имеет место картина, аналогичная внешним ключам:

* 1. pkg_A создает таблицу wsd.T1, у которой поле F1 имеет DEFAULT - результат вызова функции из некоторого пакета pkg_C

Пример:

Таблица acc.permission имеет поле `pkg DEFAULT ws.pg_pkg()`

В результате возникают вопросы

* Как избежать удаления поля F1 при удалении схемы pkg_C?
* Как восстановить DEFAULT при повторном создании пакета pkg_C?

Эти вопросы решаются следующим образом:

* pkg_A не задает DEFAULT, а регистрирует его в таблице wsd.pkg_default_protected

```sql
INSERT INTO wsd.pkg_default_protected (pkg, schema, wsd_rel, wsd_col, func) VALUES ('acc', 'acc', 'permission', 'pkg', 'ws.pg_pkg()');
```
, в результате этого

  * После создания пакета, этот DEFAULT создается автоматически
  * Перед удалением пакета, DEFAULT автоматически удаляется.


## Тесты

Тесты размещаются в файлах 9?_*.sql и выполняются внутри транзакций `init` и `make`. Вывод теста сравнивается с содержимым файла 9?_*.out и при несовпадении возникает ошибка.

Наличие ошибок тестов отменяет выполнение основной команды

### Именование тестов 9X_name.sql.

Номер нужен только для того, чтобы гарантировать порядок выполнения. В тестах он вообще не важен, поэтому все они могут иметь префикс "90_". 91 или 92 - это ни о чем не говорит. В файле должен быть комментарий о том, что тестируется. Также надо смысл теста оформить краткой фразой в латиннице (DESCRIPTION) в соответствии с типом ws.d_code и применить ее дважды:

1. в имени файла - `90_DESCRIPTION.sql`
2. внутри файла, написав `SELECT ws.test('DESCRIPTION');`

Чтобы наделить 9Х хоть каким-то смыслом, есть рекомендация: Номер 90 использовать для тестов, не связанных с проверкой наличия в БД данных (когда объекты создаются и тут же удаляются), 91 - для проверки корректности данных в БД.

## Работа с pgm из Makefile-а

pgm.sh может быть запущен двумя способами: прямым обращением, либо запуском внутри контейнера. При интерактивном подключении к контейнеру pgrest, текущий рабочий каталог ссылается на директорию в которой содержатся Makefile и pgm.sh (то есть директорию iac).
Из файла .conf  pgm использует следующие переменные:

```
DB_NAME=iac1
PG_HOST=127.0.0.1
PG_PORT=5432
```

а так же DB_PASS.

Переменные объявленные в fidm.yml в блоке env:

```
- DB_NAME=prtpro_v0
- DB_PASS=SET_DB_PASS_HERE_OR_IN_fidm.yml
- PG_PORT=5432
...
```

при запуске команд будут переопределены на те, которые содержатся в файле .conf. Т.е. если в .conf не содержится DB_PASS, то его значение будет взято из fidm.yml и пароль будет задан в виде строки равной 'SET_DB_PASS_HERE_OR_IN_fidm.yml'

Для того, чтобы в Makefile-е подключиться к конкретному контейнеру pgrest, необходимо использовать имя в формате pgrest_$${APP_SITE}_www, где APP_SITE - это имя сайта.

Пример вызова pgm.sh внутри контейнера: 

```
	@source $(CFG) && \
docker exec -i "pgrest_$${APP_SITE}_www" /bin/bash pgm.sh drop iac rest
```

Для корретной работы необходимо передавать переменные из файла конфигурации $(CFG).

## TODO

* вылетать по ошибке если в пакете при выполнении drop/create не найдено файлов
* добавить команду test
* добавить команду bench
* перенести код в из ws в pgm

* sql/upd - код обновления версий:

Содержит подкаталоги с именами, соответствующими номеру обновления(версии)

NNN/ - каталог обновления
    MM-* - файл с обновлением
Файлы выполняются в порядке сортировки имен, в рамках одной транзакции, однократно.

License
-------

This project is under the MIT License. See the [LICENSE](LICENSE) file for the full license text.

Copyright (c) 2010 - 2016 [Tender.Pro](http://www.tender.pro)
