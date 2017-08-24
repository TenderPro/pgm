# Скрипт для запуска pgm из bash внутри контейнера docker
#
# Пример вызова:
#    source .config && \
#      docker exec -ti "pgrest_${APP_SITE}_www" bash /home/app/pgm/pgm-inside-docker.sh /home/app $@
#
#  работа с пакетами из DIR/sql (каталог опознается по суффиксу /sql)
#      docker exec -ti "pgrest_${APP_SITE}_www" bash /home/app/pgm/pgm-inside-docker.sh /home/app DIR/sql $@

user=$APPUSER
[[ "$user" ]] || user=$USER

ROOT=$1
shift
cd $ROOT

PGM=pgm
[ -f pgm/pgm.sh ] && PGM=pgm/pgm.sh

dir=""
arg=$1
if [[ "$arg" != "${arg%/sql}" ]]; then
  dir=$arg
  shift
fi

# Run script and ROLLBACK at the end
#NO_COMMIT=1 SQLROOT=$dir gosu $user bash $PGM $@

# Send "notify xxx" after COMMIT
# NOTIFY=xxx SQLROOT=$dir gosu $user bash $PGM $@

# Send "notify dbrpc_reset" after COMMIT
# This signal will instruct [dbrpc](https://github.com/LeKovr/dbrpc) to reset its cache
SQLROOT=$dir gosu $user bash $PGM $@
