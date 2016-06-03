#!/bin/bash
# ##########
#
# QWAT initilization script
# 10.07.2015
# Denis Rouzaud
#
# ##########

# Exit on error
set -e


usage() {
cat <<EOF
Usage: $0 [options]

-p| --pgservice      PG service to connect to the database.
                     If not given, use current one defined by PGSERVICE env. variable.
-s|--srid            PostGIS SRID. Default to 21781 (ch1903)
-d|--drop-schema     drop schemas (cascaded) if they exist
--demo               load some demo data (not complete yet)
-r|--create-roles    create roles in the database
-v|--verbose         be verbose
EOF

}

ARGS=$(getopt -o p:s:drv -l "pgservice:,srid:,drop-schema,create-roles,verbose,demo" -- "$@");
if [ $? -ne 0 ];
then
  usage
  exit 1
fi

eval set -- "$ARGS";

# Default values
SRID=21781
DROPSCHEMA=0
CREATEROLES=0
VERBOSE=0
DEMO=0

PGSERVICEGIVEN=0

while true; do
  case "$1" in
    -p|--pgservice)
      shift;
      if [ -n "$1" ]; then
        export PGSERVICE=$1
        PGSERVICEGIVEN=1
        shift;
      fi
      ;;
     -s|--srid)
      shift;
      if [ -n "$1" ]; then
        SRID=$1
        shift;
      fi
      ;;
    --demo)
      DEMO=1
      shift;
      ;;
    -d|--drop-schema)
      DROPSCHEMA=1
      shift;
      ;;
    -r|--create-roles)
      CREATEROLES=1
      shift;
      ;;
    -v|--verbose)
      VERBOSE=1
      shift;
      ;;
    --)
      shift;
      break;
      ;;
  esac
done


if [[ "$PGSERVICEGIVEN" -eq 0 ]] && [[ "$DROPSCHEMA" -eq 1 ]]; then
    if [[ -z "$PGSERVICE" ]]; then
		echo "No PG service given, default not defined."
	    usage
	    exit 0
	fi
    read -p "PG service is not explicitly given and schema will be dropped. Are you sure you want to continue ? (y/n) " response
    if [ $response != "y" ]
    then
        exit 0
    fi
fi


# Create extenstions
psql -v ON_ERROR_STOP=1 -c "CREATE EXTENSION IF NOT EXISTS postgis;"

# Ordinary data
psql -v ON_ERROR_STOP=1 -c "CREATE SCHEMA qwat_od;"
psql -v ON_ERROR_STOP=1 -v SRID=$SRID -f ordinary_data/db.sql

echo " *** QWAT was successfuly initialized! ***"

exit 0
