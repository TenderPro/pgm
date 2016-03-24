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
    create - create DB objects
    make - compile code
    drop - drop DB objects
    erase - drop DB objects

    createdb - create database (if shell user granted)

    dump - dump schema SRC (Default: all)
    restore - restore dump from SRC

    PKG  - dirname(s) from sql. Default: "ws"

EOF
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
  dbd psql -X -P tuples_only -c "$sql" 2>> /dev/null | while read result ; do
    echo $result
  done
}

# ------------------------------------------------------------------------------
TEST_CNT="0"
TEST_TTL="0"

log() {
  local test_total=$1
  ret="0"
  while read data
  do
    d=${data#* WARNING:  ::}
    if [[ "$data" != "$d" ]] ; then
     [[ "$TEST_CNT" == "0" ]] || echo "Ok"
     TEST_CNT=$(($TEST_CNT+1))
     [[ "$d" ]] && echo -n "($TEST_CNT/$TEST_TTL) $d "
    else
      [[ "$TEST_CNT" == "0" ]] || echo "FAIL"
      echo "$data" >> ${LOGFILE}.err
      echo "$data"
      ret="1"
    fi
  done
  return $ret
}

# ------------------------------------------------------------------------------
db_run() {

  local run_op=$1 ; shift
  local file_mask=$1 ; shift
  local pkg=$@
  local use_flag

  [[ "$pkg" ]] || pkg=$PGM_PKG

  cat <<EOF
  DB Package:  $pkg
EOF
  db_show_logfile

  schema_mask="??_*"
  db_run_sql_begin $BLD/build.sql

  op_is_del=""
  [[ "$run_op" == "drop" || "$run_op" == "erase" ]] && op_is_del=1
  local path=$ROOT/sql

  pushd $path > /dev/null
  echo "Seeking dirs in '$pkg'..."
  local dirs=$BLD/build.dirs
  echo -n > $dirs
  for tag in $pkg ; do
    [ -d "$tag" ] || continue
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
  done
  echo "Seeking files..."
  local cat_cmd="cat"
  [[ "$op_is_del" ]] && cat_cmd=$TAC_BIN # Проходим каталоги в обратном порядке
  local p_pre=""
  echo -n "0" > $BLD/test.cnt
  $cat_cmd $dirs | while read p s ; do

    pn=${p%%/sql} # package name
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
      if [ -f "$f" ] ; then
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
          echo "DO \$_\$ BEGIN IF (SELECT count(1) FROM pg_namespace WHERE nspname = '$sn') > 0 THEN SET search_path = $sn, $PGM_SCHEMA, public; ELSE SET search_path = $PGM_SCHEMA, public; END IF; END; \$_\$;" >> $BLD/build.sql
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
      fi
    done
    if [[ ! "$op_is_del" ]] ; then
      # тесты для create и make
      echo "SET LOCAL search_path = $PGM_SCHEMA, public;" >> $BLD/build.sql
      # TODO: 01_require.sql
      [ -f 9?_*.macro.sql ] && cp 9?_*.macro.sql $BLD/$bd/
      for f in 9?_*.sql ; do
        [ -s "$f" ] || continue
        [[ "${f%.macro.sql}" == "$f" ]] || continue  # skip .macro.sql
        echo -n "."
        n=$(basename $f)
        debug "Found test: $f"
        echo "Processing file: $f" >> $LOGFILE
        c=$(grep -ciE "^\s*select\s+$PGM_SCHEMA.test\(" $f)
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
  echo -n "Create database \"$c\"..."
  dbd psql -X -P tuples_only -c "SELECT NULL" > /dev/null 2>> $LOGFILE && { echo "Database already exists" ; exit ; }
  dbl createdb -O $u -E UTF8 -T template0 --lc-collate=C --lc-ctype='ru_RU.UTF-8' \
    && dbl createlang plperl && echo "OK"
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
  h0=${CONN#*host=}     ; h=${h0%%;*}
  d0=${CONN#*dbname=}   ; d=${d0%%;*}
  u0=${CONN#*user=}     ; u=${u0%%;*}
  p0=${CONN#*password=} ; p=${p0%%;*}
  if [[ "$dbarg" == "last" ]] ; then
    last=$d ; pre=""
  else
    last="" ; pre="-d $d"
  fi
  arr=$@
  echo ${#arr[@]} >> $ROOT/var/log.sql
  echo $cmd -U $u -h $h $pre $@ $last >> $ROOT/var/log.sql
  [[ "$DO_SQL" ]] && PGPASSWORD=$p0 ${PG_BINDIR}$cmd -U $u -h $h $pre "$@" $last
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

cmd=$1
shift
pkg=$@

[[ "$PWD" == "/" ]] && ROOT="/var/log/supervisor"

if [ -z "$DB_NAME" ]; then
	cd $ROOT
	echo 'DB_NAME not configured, loading .config'
	[[ "$cmd" == "init" ]] && db_init
	. .config	
fi

CONN="dbname=$DB_NAME;user=$DB_NAME;host=$PG_HOST;password="

[[ "$CONN" ]] || { echo "Fatal: No DB connect info"; exit 1; }
[[ "$ROOT" ]] || ROOT=$PWD
DO_SQL=1
BLD=$ROOT/var/build

STAMP=$(date +%y%m%d-%H%m)-$$
LOGDIR=$ROOT/var/build/log
LOGFILE=$LOGDIR/$cmd-$STAMP.log
[ -d $LOGDIR ] || mkdir -p $LOGDIR

setup

PGM_PKG="ws"
PGM_SCHEMA="ws"
PGM_STORE="wsd"

[[ "$cmd" == "anno" ]] || cat <<EOF
  ---------------------------------------------------------
  PgM. Postgresql Database Manager
  Connect:  $CONN
  ---------------------------------------------------------
EOF

# ------------------------------------------------------------------------------

case "$cmd" in
  create)
    db_run create "[1-8]?_*.sql" "$pkg"
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
    db_help
    ;;
esac
