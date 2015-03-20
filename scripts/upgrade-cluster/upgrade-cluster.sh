#!/usr/bin/env bash

CONFIG=$(dirname $0)/$(basename $0 .sh).conf

[[ -f $CONFIG ]] || (echo "Config file ${CONFIG} does not exists..." && exit 1)

[[ -d log ]] || mkdir log
[[ -d dump ]] || mkdir dump
[[ -d sql ]] || mkdir sql

source $CONFIG

echo "[$(date "+%Y-%m-%d %H:%M:%S")] Dumping globals objects from 8.4 cluster"
$PGDUMPALL_FROM --globals-only > sql/globals-8.4.sql

echo "[$(date "+%Y-%m-%d %H:%M:%S")] Applying globals objects from 8.4 to 9.3 cluster"
$PGBIN_TO/psql -U postgres -h $PGHOST_TO -p $PGPORT_TO -f sql/globals-8.4.sql > /dev/null 2>&1

for database in $($PSQL_FROM postgres -At -c "$SQL_DATABASES")
do
  dump=dump/dump_${database}_$(date +%Y%m%d_%H%M%S).bkp
  log_dump=log/dump_${database}_$(date +%Y%m%d_%H%M%S).log
  log_restore=log/restore_${database}_$(date +%Y%m%d_%H%M%S).log
  log_analyze=log/analyze_${database}_$(date +%Y%m%d_%H%M%S).log
  log=log/log_${database}_$(date +%Y%m%d_%H%M%S).log

  echo "[$(date "+%Y-%m-%d %H:%M:%S")] Starting upgrade of database $database"

#  echo "[$(date "+%Y-%m-%d %H:%M:%S")] > Dropping CAST boolean AS text before dumping of database $database ..."
#  $PSQL_FROM $database -c "
#    DROP CAST IF EXISTS (boolean AS text) CASCADE;
#    DROP FUNCTION IF EXISTS public.text(boolean) CASCADE;" > $log 2>&1

  echo "[$(date "+%Y-%m-%d %H:%M:%S")] > Dumping database $database into file $dump"
  $PGDUMP_TO -Fd -f $dump -v $database > $log_dump 2>&1

  echo "[$(date "+%Y-%m-%d %H:%M:%S")] > Dropping database $database if exists..."
  $PSQL_TO template1 -c "DROP DATABASE IF EXISTS \"$database\";" > $log 2>&1

  echo "[$(date "+%Y-%m-%d %H:%M:%S")] > Creating database $database ..."
  $PSQL_TO template1 -c "CREATE DATABASE \"$database\";" > $log 2>&1

  echo "[$(date "+%Y-%m-%d %H:%M:%S")] > Restoring database $database ..."
  $PGRESTORE_TO -Fd -d $database -v $dump > $log_restore 2>&1

  echo "[$(date "+%Y-%m-%d %H:%M:%S")] > Analyzing database $database ..."
  $PSQL_TO $database -c "ANALYZE VERBOSE;" > $log_analyze 2>&1

#  echo "[$(date "+%Y-%m-%d %H:%M:%S")] > Creating operator || (ANYELEMENT, ANYELEMENT) into target database $database ..."
#  $PSQL_TO $database -c "
#    DROP OPERATOR IF EXISTS || (ANYELEMENT, ANYELEMENT);
#    CREATE OPERATOR || (PROCEDURE = fc_concat, LEFTARG = ANYELEMENT, RIGHTARG = ANYELEMENT);" > $log 2>&1

  echo "[$(date "+%Y-%m-%d %H:%M:%S")] Finished upgrade of database $database"
  echo
done



exit 0
