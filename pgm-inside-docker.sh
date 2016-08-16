# Скрипт для запуска pgm из bash внутри контейнера docker
#
# Пример вызова:
#    source .config && \
#      docker exec -ti "pgrest_${APP_SITE}_www" bash /home/app/pgm/pgm-inside-docker.sh /home/app $@

user=$APPUSER
[[ "$user" ]] || user=$USER

ROOT=$1
shift
cd $ROOT

PGM=pgm
[ -f pgm/pgm.sh ] && PGM=pgm/pgm.sh
gosu $user bash $PGM $@
