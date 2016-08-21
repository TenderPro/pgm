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

SQLROOT=$dir gosu $user bash $PGM $@
