#!/bin/bash

# PARAMS
SRCDB=qwat
TESTDB=qwat_test
TESTCONFORMDB=qwat_test_conform
USER=postgres
HOST=localhost
QWATSERVICE=qwat
QWATSERVICETEST=qwat_test
QWATSERVICETESTCONFORM=qwat_test_conform

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

while [[ $# > 0 ]]; do
key="$1"
case $key in
    -h|--help)
        echo "Arguments:"
        echo -e "\t-h|--help\tShow this help screen"
        echo -e "\t-u|--upgrade\tUpgrade your real DB (perform all deltas on it)"
        exit 0
        ;;
    -u|--upgrade)
    UPGRADE_REAL_DB="$2"
    shift # past argument
    ;;
esac

shift
done


        # 1 Create DB test
        # 2 Launch init_qwat.sh on DB test
        # 4 Create DB test_conform
# 5 Get lastest tagged version of qwat     git describe  => ex: v1.2-2-g91fec13 , extract the latest tag version => NUM_TAG  # TODO if no tag, take the actual repository 
# 6 Switch on that branch and launch init_qwat.sh on test_conform    git checkout -b version2 v2.0.0
# 7 switch back on current branch, and launch delta > version tag (NUM_TAG)
# 8 Generate the results file for DB test and test_conform
# 9 Compare

# read -s  -p "Please enter the password for you DB user ($USER)": pwd
# export PGPASSWORD="$pwd"
# echo ""

echo "Getting current num version"
NUMVERSION=\"$(/usr/bin/psql --host $HOST --port 5432 --username "$USER" --no-password -d "$SRCDB" -c "COPY(SELECT version FROM qwat_sys.versions WHERE module='model.core') TO STDOUT")\"
printf "You are currently using qWat v${GREEN}$NUMVERSION${NC}\n"

echo "Droping existing qwat_test"
/usr/bin/dropdb "$TESTDB" --host $HOST --port 5432 --username "$USER" --no-password
#/usr/bin/dropdb -d "service=$QWATSERVICETEST"

echo "Creating DB (qwat_test)"
/usr/bin/createdb "$TESTDB" --host $HOST --port 5432 --username "$USER" --no-password
#/usr/bin/createdb -d "service=$QWATSERVICETEST"

echo "Initializing qwat DB in qwat_test"
cd ..
./init_qwat.sh -p $QWATSERVICETESTCONFORM -d > update/init_qwat.log
cd update

echo "Droping DB (qwat_test_conform)"
/usr/bin/dropdb "$TESTCONFORMDB" --host $HOST --port 5432 --username "$USER" --no-password
#/usr/bin/createdb -d "service=$QWATSERVICETEST"

echo "Creating DB (qwat_test_conform)"
/usr/bin/createdb "$TESTCONFORMDB" --host $HOST --port 5432 --username "$USER" --no-password
#/usr/bin/createdb -d "service=$QWATSERVICETEST"


echo "Getting lastest Tag num"
LASTEST_TAG=$(git describe)
#LASTEST_TAG=$($TRAVIS_BUILD_DIR/git describe)
printf "    Lastest tag = ${GREEN}$LASTEST_TAG${NC}\n"


EXITCODE=0
exit $EXITCODE



echo "Restoring in test DB"
/usr/bin/pg_restore --host $HOST --port 5432 --username "$USER" --dbname "$TESTDB" --no-password --single-transaction --exit-on-error "$TODAY""_current_qwat.backup"
#/usr/bin/pg_restore -d "service=$QWATSERVICETEST" --single-transaction --exit-on-error "$TODAY""_current_qwat.backup"

echo "Applying deltas on $TESTDB:"
for f in $DIR/delta/*.sql
do
    CURRENT_DELTA=$(basename "$f")
    CURRENT_DELTA_NUM_VERSION=$(echo $CURRENT_DELTA| cut -d'_' -f 2)
    if [[ $CURRENT_DELTA_NUM_VERSION > $NUMVERSION ]]; then
        printf "    Processing ${GREEN}$CURRENT_DELTA${NC}, num version = $CURRENT_DELTA_NUM_VERSION\n"
        /usr/bin/psql --host $HOST --port 5432 --username "$USER" --no-password -q -d "$TESTDB" -f $f
    else
        printf "    Bypassing  ${RED}$CURRENT_DELTA${NC}, num version = $CURRENT_DELTA_NUM_VERSION\n"
    fi
done


echo "Initializing qwat DB in qwat_test_conform"
cd ..
./init_qwat.sh -p $QWATSERVICETESTCONFORM -d > update/init_qwat.log
cd update

echo "Producing referential file for current qWat version (from $QWATSERVICETESTCONFORM)"
/usr/bin/psql --host $HOST --port 5432 --username "$USER" --no-password -d "$QWATSERVICETESTCONFORM" -f test_migration.sql > test_migration.expected.sql

echo "Performing conformity test"
STATUS=$(python test_migration.py --pg_service $QWATSERVICETEST)

if [[ $STATUS == "DataModel is OK" ]]; then
    printf "${GREEN}Migration TEST is successfull${NC}. You may now migrate your real DB\n"
else
    printf "${RED}Migration TEST has failed${NC}. Please contact qWat team and give them the following output :\n $STATUS \n\n"
fi

echo "Cleaning"
rm "$TODAY""_current_qwat.backup"
rm init_qwat.log

# TODO : dropping qwat_test
# TODO : dropping qwat_test_conform

EXITCODE=0
exit $EXITCODE
