#
#    Copyright (c) 2010, 2016 Tender.Pro http://tender.pro.
#
# pgm.sh - Postgresql schema control script
#
# ------------------------------------------------------------------------------

db_help() {
  cat <<EOF

  Usage:
    $0 COMMAND [PKG]

  Where COMMAND is one from
    check    - check for required programs presense
    init     - create .config file (if PKG not set)
    init     - create PKG skeleton files
    create   - create PKG objects
    creatif  - create PKG objects if not exists
    recreate - drop PKG objects if exists and create
    make     - compile PKG code
    drop     - drop PKG objects intender to rebuild
    erase    - drop all of PKG objects including persistent data

    createdb - create database (if shell user granted)

    dump     - dump schema SRC (Default: all)
    restore  - restore dump from SRC

    PKG      - package, dirname(s) inside sql/ dir. Default: "ws"

EOF
}

# ------------------------------------------------------------------------------
db_init() {
  local file=$1
  [ -f $file ] && return
  cat > $file <<EOF
#
# PGM config file
#

# Database name
DB_NAME=pgm01

# User name
DB_USER=op

# User password
DB_PASS=op_secret

# Database host
PG_HOST=localhost

# Template database
DB_TEMPLATE=tpro-template

# Project root
ROOT=\$PWD

# Directory of Postgresql binaries (psql, pg_dump, pg_restore, createdb, createlang)
# Empty if they are in search path
# Command to check: dirname "\$(whereis -b psql)"
PG_BINDIR=""

# Do not remove sql preprocess files (var/build)
KEEP_SQL="1"
EOF

}

sql_template() {
  cat <<EOF
/*
  pgm. $1
*/

-- ----------------------------------------------------------------------------

EOF
  case "$1" in
    drop)
      echo "DROP SCHEMA :SCH CASCADE;"
    ;;
    create)
      echo "CREATE SCHEMA :SCH;"
      echo "COMMENT ON SCHEMA :SCH IS 'created by pgm';"
    ;;
    test)
      echo "SELECT test('testname');"
      echo "SELECT TRUE AS result;"
    ;;
  esac
}

# ------------------------------------------------------------------------------
# copy of psql output
sql_template_test() {
  cat <<EOF
         test
-----------------------
  ***** testname *****

 result
--------
 t

EOF
}

# ------------------------------------------------------------------------------
db_init_pkg() {
  local dir=sql
  for p in $@ ; do
    echo $p
    [ -d $dir/$p ] || mkdir -p $dir/$p
    [ -f $dir/$p/02_drop.sql ] || sql_template drop > $dir/$p/02_drop.sql
    [ -f $dir/$p/11_create.sql ] || sql_template create > $dir/$p/11_create.sql
    [ -f $dir/$p/90_test.sql ] || sql_template test > $dir/$p/90_test.sql
    [ -f $dir/$p/90_test.out ] || sql_template_test > $dir/$p/90_test.out
  done
}

# ------------------------------------------------------------------------------
db_show_logfile() {
  cat <<EOF
  Logfile:     $LOGFILE
  ---------------------------------------------------------
EOF
}

# ------------------------------------------------------------------------------
db_run_sql_begin() {
  local file=$1
  cat > $file <<EOF
/* ------------------------------------------------------------------------- */
\qecho '-- _build.sql / BEGIN --'
\cd $ROOT/var/build

\timing on
\set ECHO all
BEGIN;
\set ON_ERROR_STOP 1
SET CLIENT_ENCODING TO 'utf-8';
-- SET CONSTRAINTS ALL DEFERRED;
EOF
  if [[ "$BUILD_DEBUG" ]] ; then
    echo "SET CLIENT_MIN_MESSAGES TO 'DEBUG';" >> $file
  else
    echo "SET CLIENT_MIN_MESSAGES TO 'WARNING';" >> $file
  fi
}

# ------------------------------------------------------------------------------
db_run_sql_end() {
  local file=$1
  cat >> $file <<EOF
COMMIT;

\qecho '-- _build.psql / END --'
/* ------------------------------------------------------------------------- */
EOF
}

# ------------------------------------------------------------------------------
db_run_test() {
  local bd=$1
  local test=$2
  local name=$3
  local point=$4
  local file=$5
  cat >> $file <<EOF
SAVEPOINT ${point}_test;
\set TEST $bd/$name
\o $bd/$name.out
\i $bd/$n
\o
ROLLBACK TO SAVEPOINT ${point}_test;
EOF
}

# ------------------------------------------------------------------------------
db_run_test_end() {
  local file=$1
  cat >> $file <<EOF
\o
delete from $PGM_SCHEMA.compile_errors;
\copy $PGM_SCHEMA.compile_errors(data) from errors.diff
\! cat errors.diff
select $PGM_SCHEMA.compile_errors_chk();
EOF
}

# ------------------------------------------------------------------------------
file_protected_csum() {
  local pkg=$1
  local schema=$2
  local file=$3
  local sql="SELECT csum FROM $PGM_STORE.pkg_script_protected WHERE pkg = '$pkg' AND schema = '$schema' AND code = '$file'"
  #PGPASSWORD=$DB_NAME ${PG_BINDIR}$cmd -U $u -h $h $pre "$@" $last

  dbd psql -X -P tuples_only -c "$sql" 2>> /dev/null | while read result ; do
    echo $result
  done
}

# ------------------------------------------------------------------------------
TEST_CNT="0"
TEST_TTL="0"

log() {
  local test_total=$1
  local filenew
  local fileold
  ret="0"
  echo "1..$test_total"
  while read data
  do
    d=${data#* WARNING:  ::}
    if [[ "$data" != "$d" ]] ; then
     [[ "$TEST_CNT" == "0" ]] || echo " done"
     filenew=${data%.sql*}
     filenew=${filenew#*psql:}
     if [[ "$fileold" != "$filenew" ]] ; then
      tput setaf 2         #set green color
      [[ "$TEST_CNT" == "0" ]] || echo "ok $out"
      TEST_CNT=$(($TEST_CNT+1))
      [[ "$filenew" ]] && out="$TEST_CNT - ${filenew%.macro}.sql"
      fileold=$filenew
      tput setaf 9             #set default color
     fi
     [[ "$d" ]] && echo -n "#$d"  
    else
      tput setaf 1         #set red color
      [[ "$ret" != "0" ]] || echo -e "\nnot ok $out"
      echo "$data" >> ${LOGFILE}.err
      echo "$data"
      ret="1"
    fi
  done 
  tput setaf 9             #set default color
  return $ret
}

# ------------------------------------------------------------------------------
generate_build_sql() {
  echo "Seeking files..."
  local cat_cmd="cat"
  [[ "$op_is_del" ]] && cat_cmd=$TAC_BIN # Проходим каталоги в обратном порядке
  local p_pre=""
  echo -n "0" > $BLD/test.cnt
  $cat_cmd $dirs | while read p s ; do

  pn=${p%%/sql} # package name without suffix
  sn=${s#??_}   # schema name
  bd=$pn     # build dir
  if [[ "$sn" ]] ; then
    bd=$bd-$sn
  else
    sn=$pn
  fi
  debug " ********* $pn / $sn / $bd "
  if [[ "$p" != "$p_pre" ]] ; then
    echo -n "$pn: "
    echo "\\qecho '-- ******* Package: $pn --'" >> $BLD/build.sql
    echo "\\set PKG $pn" >> $BLD/build.sql
  fi
  echo "\\set SCH $sn" >> $BLD/build.sql
  echo "\\qecho '-- ------- Schema: $sn'" >> $BLD/build.sql
  if [[ "$pn:$sn" != "$PGM_PKG:$PGM_SCHEMA" || "$run_op" != "create" ]] ; then
    # начало выполнения операции (не вызывается только для create схемы $PGM_SCHEMA пакета $PGM_PKG)
    echo "SELECT $PGM_SCHEMA.pkg_op_before('$run_op', '$pn', '$sn', '$LOGNAME', '$USERNAME', '$SSH_CLIENT');" >> $BLD/build.sql
  fi

  [ -d "$BLD/$bd" ] || mkdir $BLD/$bd
  echo -n > $BLD/errors.diff
  pushd $p > /dev/null
  [[ "$s" ]] && pushd $s > /dev/null
  local search_set=""
  debug "Search $file_mask in $PWD"
  for f in $file_mask ; do
    [ -f "$f" ] || continue
    echo -n "."
    n=$(basename $f)
    debug "Found: $s/$f ($n)"
    echo "Processing file: $s/$f" >> $LOGFILE
    local csum=""
    if test $f -nt $BLD/$bd/$n ; then
      # $f is newer than $BLD/$bd/$n

      csum0=$($CSUM_BIN $f)
      csum=${csum0%  *}
      echo "\\qecho '----- ($csum) $pn:$sn:$n -----'">> $BLD/build.sql
      # вариант с заменой 1го вхождения + поддержка plperl
      $AWK_BIN "{ print gensub(/(\\\$_\\\$)($| +#?)/, \"\\\1\\\2 /* $pn:$sn:\" FILENAME \" / \" FNR \" */ \",\"g\")};" $f > $BLD/$bd/$n
      # вариант без удаления прошлых комментариев
      # awk "{gsub(/\\\$_\\\$(\$| #?)/, \"/* $pn:$sn:$n / \" FNR \" */ \$_\$ /* $pn:$sn:$n / \" FNR \" */ \")}; 1" $f > $BLD/$bd/$n
      # вариант с удалением прошлых комментариев
      # awk "{gsub(/(\/\* .+ \/ [0-9]+ \*\/ )?\\\$_\\\$( \/\* .+ \/ [0-9]+ \*\/)?/, \"/* $pn:$sn:$n / \" FNR \" */ \$_\$ /* $pn:$sn:$n / \" FNR \" */ \")}; 1" $f > $BLD/$bd/$n
    fi
    # настройка search_path для create и make
    if [[ ! "$search_set" ]] && [[ "$n" > "12_00" ]]; then
      echo "DO \$_\$ BEGIN IF (SELECT count(1) FROM pg_namespace WHERE nspname = '$sn') > 0 AND '$sn' <> '$PGM_SCHEMA' THEN SET search_path = $sn, $PGM_SCHEMA, public; ELSE SET search_path = $PGM_SCHEMA, public; END IF; END; \$_\$;" >> $BLD/build.sql
      search_set=1
    fi

    local db_csum=""
    local skip_file=""
    if [[ "$n" =~ .+_${PGM_STORE}_[0-9]{3}\.sql ]]; then  # old bash: ${X%_wsd_[0-9][0-9][0-9].sql}
      # protected script
      [[ "$csum" == "" ]] && csum0=$($CSUM_BIN $f) && csum=${csum0%  *}
      local db_csum=$(file_protected_csum $pn $sn $n)

      debug "$f protected: $db_csum /$csum"
      if [[ "$db_csum" ]]; then
        if [[ "$db_csum" != "$csum" ]]; then
          echo "!!!WARNING!!! Changed control sum of protected file $f. Use 'db erase' or 'git checkout -- $f'"
          skip_file=1
        else
          # already installed. Skip
          skip_file=1
        fi
      else
        # save csum
        db_csum=$csum
      fi
    fi
    # однократный запуск PROTECTED
    if [[ ! "$skip_file" ]]; then
      echo "\\set FILE $n" >> $BLD/build.sql
      echo "\i $bd/$n" >> $BLD/build.sql
      [[ "$db_csum" ]] && echo "INSERT INTO $PGM_STORE.pkg_script_protected (pkg, schema, code, csum) VALUES ('$pn', '$sn', '$n', '$db_csum');" >> $BLD/build.sql
    else
      echo "\\qecho '----- SKIPPED PROTECTED FILE  -----'" >> $BLD/build.sql
      [[ "$db_csum" != "$csum" ]] && echo "\\qecho '!!!WARNING!!! db csum $db_csum <> file csum $csum'" >> $BLD/build.sql
    fi
  done
  if [[ ! "$op_is_del" ]] ; then
    # тесты для create и make
    echo "SET LOCAL search_path = $PGM_SCHEMA, public;" >> $BLD/build.sql
    # TODO: 01_require.sql
    # файлы 9?_*.macro.sql просто копируем - они вспомогательные
    if ls 9?_*.macro.sql 1> /dev/null 2>&1; then
      cp 9?_*.macro.sql $BLD/$bd/
    fi

    #  если есть каталог с данными - создаем симлинк
    [ -d data ] && [ ! -L $BLD/$bd/data ] && ln -s $PWD/data $BLD/$bd/data
    c="1"
    for f in 9?_*.sql ; do
      [ -s "$f" ] || continue
      [[ "${f%.macro.sql}" == "$f" ]] || continue  # skip .macro.sql
      echo -n "."
      n=$(basename $f)
      debug "Found test: $f"
      echo "Processing file: $f" >> $LOGFILE
      [[ "$c" ]] && echo -n "+$c" >> $BLD/test.cnt
      cp -p $f $BLD/$bd/$n # no replaces in test file
      n1=${n%.sql} # remove ext
      db_run_test $bd $n $n1 $sn $BLD/build.sql
      cp $n1.out $BLD/$bd/$n1.out.orig 2>>  $BLD/errors.diff
      echo "\! diff -c $bd/$n1.out.orig $bd/$n1.out | tr \"\t\" \" \" >> errors.diff" >> $BLD/build.sql
      db_run_test_end $BLD/build.sql
    done
  fi
  [[ "$s" ]] && popd > /dev/null # $s
  popd > /dev/null # $p

  [[ "KEEP_SQL" ]] || echo "\! rm -rf $bd" >> $BLD/build.sql

  # завершение выполнения операции (не вызывается только для drop/erase схемы $PGM_SCHEMA пакета $PGM_PKG)
  ( [[ "$pn:$sn" != "$PGM_PKG:$PGM_SCHEMA" ]] || [[ ! "$op_is_del" ]] ) \
    && echo "SELECT $PGM_SCHEMA.pkg_op_after('$run_op', '$pn', '$sn', '$LOGNAME', '$USERNAME', '$SSH_CLIENT');" >> $BLD/build.sql
  p_pre=$p
  echo .
  done
}

# ------------------------------------------------------------------------------
is_pkg_exists() {
  local sql="SELECT EXISTS(SELECT id FROM ws.pkg WHERE code='$1');"
  echo -n $(dbd psql -X -P tuples_only -c "$sql" 2>> /dev/null)
}

# ------------------------------------------------------------------------------
lookup_dirs() {
  local mask=$1
  local tag=$2
  # look for
  # A: tag/*.sql (if schema = tag)
  # B: tag/sql/NN_schema/*.sql
  # C: tag/NN_schema/*.sql
  local s=""
  for f in $tag/*.sql; do
    # A: tag/*.sql (if schema = tag)
    [ -e "$f" ] && s=$tag
    break
  done

  if [[ "$s" ]]; then
    echo "Found: $s"
    echo "$tag" >> $dirs
  else
    [ -d sql ] && tag=$tag/sql # B: tag/sql/NN_schema/*.sql
    for s in $tag/$schema_mask ; do
      echo "Found: $s"
      echo "$tag ${s#*/}" >> $dirs
    done
  fi
}

# ------------------------------------------------------------------------------
db_run() {

  local run_op_arg=$1 ; shift
  local file_mask=$1 ; shift
  local file_mask_ext=none
  if test "$#" -eq 2; then
    # осталось два аргумента, первый - маска файлов для второго прохода
    file_mask_ext=$1 ; shift
  fi

  local pkg=$@
  local use_flag

  local run_op=$run_op_arg

  [[ "$pkg" ]] || pkg=$PGM_PKG

  cat <<EOF
  DB Package:  $pkg
EOF
  db_show_logfile
  schema_mask="??_*"
  db_run_sql_begin $BLD/build.sql

  op_is_del=""
  [[ "$run_op" == "drop" || "$run_op" == "erase" ]] && op_is_del=1
  local path=$ROOT/$SQLROOT

  pushd $path > /dev/null
  echo "Seeking dirs in $pkg..."
  local dirs=$BLD/build.dirs
  local mask_create=""
  local skip_step1="" # no skip 1st by default
  [[ "$run_op_arg" == "recreate" ]] && skip_step1="1" # skip 1st by default

  echo -n > $dirs
  for tag in $pkg ; do
    [ -d "$tag" ] || continue # TODO: Warning for unknown tag

    if [[ "$run_op_arg" == "creatif" ]] ; then
      echo -n "Check if package $tag exists: "
      # do nothing if pkg exists, create otherwise
      local exists=$(is_pkg_exists $tag)
      if [[ $exists == "t" ]] ; then
        echo "Yes, skip"
        continue
      else
        # Will create atleast one
        echo "No"
        run_op="create"
      fi
    fi

    if [[ "$run_op_arg" == "recreate" ]] ; then
      echo -n "Check if package $tag exists: "
      local exists=$(is_pkg_exists $tag)
      if [[ $exists == "t" ]] ; then
        # Will drop atleast one
        echo "Yes, will drop"
        run_op="drop"
        op_is_del=1
        skip_step1="" # no skip 1st
      else
        echo "No, just create"
        continue
      fi
    fi
    lookup_dirs $schema_mask $tag
  done

  [[ "$skip_step1" ]] || generate_build_sql

  if [[ "$run_op_arg" == "recreate" ]] ; then
    # pkg dropped, create it
    op_is_del=""
    run_op="create"
    file_mask=$file_mask_ext

    echo "Recreate: 1st step dirs:" && cat $dirs
    echo -n > $dirs
    for tag in $pkg ; do
      [ -d "$tag" ] || continue

      lookup_dirs $schema_mask $tag
    done

    generate_build_sql
  fi

  test_op=$(cat $BLD/test.cnt)
  TEST_TTL=$(($test_op))
  rm $BLD/test.cnt
  popd > /dev/null

  db_run_sql_end $BLD/build.sql
  # print last "Ok"
  [[ "$op_is_del" ]] || echo "SELECT $PGM_SCHEMA.test(NULL);" >> $BLD/build.sql
  pushd $BLD > /dev/null

  echo "Running build.sql..."

  dbd psql -X -P footer=off -f build.sql 3>&1 1>$LOGFILE 2>&3 | log $TEST_TTL

  RETVAL=$?
  popd > /dev/null
  if [[ $RETVAL -eq 0 ]] ; then
    [ -f "$BLD/errors.diff" ] && rm "$BLD/errors.diff"
    echo "Complete"
  elif [ -s "$BLD/errors.diff" ] ; then
    echo "*** Diff:" ; cat "$BLD/errors.diff"
    exit 1
  else
    echo "*** Error(s) found"
    exit 1
  fi

}

# ------------------------------------------------------------------------------
db_dump() {
  local schema=$1
  local format=$2
  [[ "$schema" ]] || schema="all"
  [[ "$format" == "t" ]] || format="p --inserts -O"
  local ext=".tar"
  [[ "$format" == "t" ]] || ext=".sql"
  local key=$(date "+%y%m%d_%H%M")
  local file=$ROOT/var/dump-$schema-$key$ext
  [ -f $file ] && rm -f $file
  local schema_arg="-n $schema"
  [[ "$schema" == "all" ]] && schema_arg=""
  echo "  Dumping  $file .."
  dbl pg_dump -F $format -f $file $schema_arg --no-tablespaces -E UTF-8;
  echo "  Gzipping $file.gz .."
  gzip -9 $file
  echo "  Dump of $schema schema(s) complete"
}

# ------------------------------------------------------------------------------
db_restore() {
  local key=$1
  local file=$ROOT/var/$key

  [ -f "$file" ] || { echo "Error: Dump file $file not found. " ; exit 1 ; }

  db_show_logfile

  [[ "$key" != ${key%.gz} ]] && { gunzip $file ; file=${file%.gz} ; }
  # [ -L $file.gz ] && { filegz=$(readlink $file.gz); file=${filegz%.gz} ; }
  echo "Restoring schema from $file.."
  if [[ "$file" != ${file%.tar} ]] ; then
    dbd pg_restore --single-transaction -O $file > $LOGFILE 2>&1
    RETVAL=$?
  else
    dbd psql -X -P footer=off -f $file > $LOGFILE 2>&1
    RETVAL=$?
  fi
  if [[ $RETVAL -eq 0 ]] ; then
    echo "Restore complete."
  else
    echo "*** Errors:"
    grep ERROR $LOGFILE || echo "    None."
  fi
}

# ------------------------------------------------------------------------------
db_create() {

  local bin="createdb"
  local has_bin=$(whereis -b $bin)
  if [[ "$has_bin" == "$bin:" ]] ; then
    echo "$bin must be in search path to use this feature"
    exit
  fi
  echo -n "Create database '$DB_NAME' ..."
  dbd psql -X -P tuples_only -c "SELECT NULL" > /dev/null 2>> $LOGFILE && { echo "Database already exists" ; exit ; }
  dbl createdb -O $u -E UTF8 -T $DB_TEMPLATE && echo "OK"
  #  && dbl createlang plperl
  # TODO: ALTER DATABASE $c SET lc_messages='en_US.utf8';
}

# ------------------------------------------------------------------------------
# Имя БД передается последним аргументом
dbl() {
  do_db last $@
}

# Имя БД передается как -d
dbd() {
  do_db arg "$@"
}

do_db() {

  dbarg=$1 ; shift
  cmd=$1   ; shift
  h=$PG_HOST
  d=$DB_NAME
  u=$DB_USER
  if [[ "$dbarg" == "last" ]] ; then
    last=$d ; pre=""
  else
    last="" ; pre="-d $d"
  fi
  arr=$@
  #echo ${#arr[@]} >> $ROOT/var/log.sql
  #echo $cmd -U $u -h $h $pre $@ $last >> $ROOT/var/log.sql
  [[ "$DO_SQL" ]] && PGPASSWORD=$DB_PASS ${PG_BINDIR}$cmd -U $u -h $h $pre "$@" $last
}

debug() {
  [[ "$DEBUG" ]] && echo "[DEBUG]: " $@
}

# ------------------------------------------------------------------------------
setup() {

  AWK_BIN=gawk
  CSUM_BIN=sha1sum

  TAC_BIN="tac"
  local is_tac=$(whereis -b $TAC_BIN)
  [[ "$is_tac" == "$cat_cmd:" ]] && cat_cmd="tail -r" # TODO check if tail exists

}
# ------------------------------------------------------------------------------
do_check() {
  local bad=""
  echo "Checking used programs.."
  for app in gawk psql createdb pg_dump pg_restore gzip ; do
    echo -n "  $app.."
     printf '%*.*s' 0 $((20 - ${#app})) "......................"
    if command -v $app > /dev/null 2>&1 ; then
      echo " Ok"
    else
      echo " Does not exists"
      bad="1"
    fi
  done
  if [[ "$bad" ]] ; then
    echo "Some used programs are not installed. This may cause errors"
    exit 1
  fi
  exit 0
}
# ------------------------------------------------------------------------------

cmd=$1
shift
pkg=$@

[[ "$cmd" == "check" ]] && do_check

ROOT=$PWD
[[ "$PWD" == "/" ]] && ROOT="/var/log/supervisor"

if [ -z "$DB_NAME" ]; then
  cd $ROOT
  echo 'DB_NAME not configured, loading .config'
  if [[ "$cmd" == "init" ]] ; then
    if [[ "$pkg" ]] ; then
      db_init_pkg $pkg
    else
      db_init .config
    fi
    echo "Init complete"
    exit 0
  fi
  . .config
fi

[[ "$DB_USER" ]] || DB_USER=$DB_NAME
[[ "$DB_TEMPLATE" ]] || DB_TEMPLATE=template0

[[ "$ROOT" ]] || ROOT=$PWD
DO_SQL=1
BLD=$ROOT/var/build

STAMP=$(date +%y%m%d-%H%m)-$$
LOGDIR=$ROOT/var/build/log
LOGFILE=$LOGDIR/$cmd-$STAMP.log
[ -d $LOGDIR ] || mkdir -p $LOGDIR

# Where sql packages are
[[ "$SQLROOT" ]] || SQLROOT=sql

setup

PGM_PKG="ws"
PGM_SCHEMA="ws"
PGM_STORE="wsd"

[[ "$cmd" == "anno" ]] || cat <<EOF
  ---------------------------------------------------------
  PgM. Postgresql Database Manager
  Connect: "dbname=$DB_NAME;user=$DB_NAME;host=$PG_HOST;password="
  Command: $cmd
  ---------------------------------------------------------
EOF

# ------------------------------------------------------------------------------

case "$cmd" in
  create)
    db_run create "[1-8]?_*.sql" "$pkg"
    ;;
  creatif)
    db_run creatif "[1-8]?_*.sql" "$pkg"
    ;;
  recreate)
    db_run recreate "00_*.sql 02_*.sql" "[1-8]?_*.sql" "$pkg"
    ;;
  drop)
    db_run drop "00_*.sql 02_*.sql" "$pkg"
    ;;
  erase)
    db_run erase "0?_*.sql" "$pkg"
    ;;
  make)
    db_run make "1[4-9]_*.sql [3-6]?_*.sql" "$pkg"
    ;;
  dump)
    db_dump $src $@
    ;;
  restore)
    db_restore $src $@
    ;;
  createdb)
    db_create
    ;;
  anno)
    db_anno
    ;;
  *)
    echo "Unknown command"
    db_help
    ;;
esac
