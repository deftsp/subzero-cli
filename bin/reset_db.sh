#!/bin/bash

# requires fswatch https://github.com/emcrisostomo/fswatch
# brew install fswatch

# BASEDIR=`realpath $(dirname $(realpath $0))/../`
BASEDIR=/project
source $BASEDIR/.env
export $(grep -v "#" $BASEDIR/.env | cut -d= -f1)
POSTGRES_DB=$DB_NAME
export POSTGRES_DB
OPENRESTY_CONTAINER=${COMPOSE_PROJECT_NAME}_openresty_1
POSTGREST_CONTAINER=${COMPOSE_PROJECT_NAME}_postgrest_1
RABBITMQ_CONTAINER=${COMPOSE_PROJECT_NAME}_rabbitmq_1 
PSQL_CMD="psql postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${DB_HOST}:5432"
echo "Starting DB reset process ==============="
$PSQL_CMD/postgres << EOF
	select pg_terminate_backend(pid) from pg_stat_activity where datname = '${DB_NAME}';
	drop database if exists ${DB_NAME};
	create database ${DB_NAME};
EOF
$PSQL_CMD/${DB_NAME} -v DIR=$BASEDIR/sql -f $BASEDIR/sql/init.sql

docker kill -s "HUP" ${POSTGREST_CONTAINER} > /dev/null
docker kill -s "HUP" ${OPENRESTY_CONTAINER} > /dev/null
#docker kill -s "HUP" ${RABBITMQ_CONTAINER} > /dev/null
docker restart ${RABBITMQ_CONTAINER} > /dev/null #rabbit crashes on pg disconnect, for the time being we just restart it
echo "Reset process complete =================="
