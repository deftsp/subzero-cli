#!/bin/bash

# requires fswatch https://github.com/emcrisostomo/fswatch
# brew install fswatch

#BASEDIR=`realpath $(dirname $(realpath $0))/../`
BASEDIR=/project
source $BASEDIR/.env
OPENRESTY_CONTAINER=${COMPOSE_PROJECT_NAME}_openresty_1 
POSTGREST_CONTAINER=${COMPOSE_PROJECT_NAME}_postgrest_1 
PSQL_CMD="psql postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${DB_HOST}:5432/${DB_NAME}"
RESET_DB_SCRIPT=reset_db.sh
TIMESTAMP_FILE=${BASEDIR}/lastupdate.txt
RESET_DB_ALLOWED=${RESET_DB_ALLOWED:0}
PSQL_CMD="psql postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${DB_HOST}:5432"
# there are different monitors available for each system
# you can check the options for your system with "fswatch -M"
# if you notice a big delay between when changes are made and when they are detected
# try changing the monitor
# when you change the monitor type you might want to remove the -r option
FSWATCH_MONITOR="poll_monitor"

if [[ $RESET_DB_ALLOWED == 1 ]]; then
	echo "WARNING!!!"
	echo "DB reset mode enabled!"
	echo "If the execution of a sql script will fail, the database will be dropped and recreated"
fi;

(
	fswatch -m $FSWATCH_MONITOR -0 -r -e ".*" -Ii "\\.sql$"  $BASEDIR/sql |
	while read -d "" file; do (
${PSQL_CMD}/${DB_NAME} << EOF
\set QUIET on
\set ON_ERROR_STOP on
\echo -n Reloading ${file/${BASEDIR}\//} ...
begin;
\i ${file};
commit;
\echo Done
EOF
		rc=$?;
		if [[ $rc != 0 ]]; then
			if [[ $RESET_DB_ALLOWED == 1 ]]; then
				$RESET_DB_SCRIPT;
			else
				echo "Applying db change failed! You need to manually update your db!"
			fi;
		else
			docker kill -s "HUP" ${POSTGREST_CONTAINER} > /dev/null;
			docker kill -s "HUP" ${OPENRESTY_CONTAINER} > /dev/null;
		fi;
		date > $TIMESTAMP_FILE
	) done 
) &


(
	fswatch -m $FSWATCH_MONITOR -0 -r -e ".*" -Ii "\\.conf$" $BASEDIR/nginx |
	while read -d "" file; do (
		printf "Reloading: ${file/${BASEDIR}\//} ...";
		docker kill -s "HUP" ${OPENRESTY_CONTAINER} > /dev/null
		echo "Done"
		date > $TIMESTAMP_FILE
		) done
) &

(
	fswatch -m $FSWATCH_MONITOR -0 -r -e ".*" -Ii "\\.lua$" $BASEDIR/lua |
	while read -d "" file; do (
		printf "Reloading: ${file/${BASEDIR}\//} ...";
		docker kill -s "HUP" ${OPENRESTY_CONTAINER} > /dev/null
		echo "Done"
		date > $TIMESTAMP_FILE
		) done
) &


wait