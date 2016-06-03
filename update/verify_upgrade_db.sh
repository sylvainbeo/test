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
        # 2 Launch init_qwat.sh on DB test (QWAT_TEST will be the good DB)
        # 4 Create DB test_conform
# 5 Get lastest tagged version of qwat     git describe  => ex: v1.2-2-g91fec13 , extract the latest tag version => NUM_TAG  # TODO if no tag, take the actual repository 
# 6 Switch on that branch and launch init_qwat.sh on test_conform    git checkout -b version2 v2.0.0
# 7 switch back on current branch, and launch delta > version tag (NUM_TAG)
# 8 Generate the results file for DB test and test_conform
# 9 Compare

# read -s  -p "Please enter the password for you DB user ($USER)": pwd
# export PGPASSWORD="$pwd"
# echo ""

# echo "Getting current num version"
# NUMVERSION=\"$(/usr/bin/psql --host $HOST --port 5432 --username "$USER" --no-password -d "$SRCDB" -c "COPY(SELECT version FROM qwat_sys.versions WHERE module='model.core') TO STDOUT")\"
# printf "You are currently using qWat v${GREEN}$NUMVERSION${NC}\n"

echo "Droping existing qwat_test"
/usr/bin/dropdb "$TESTDB" --host $HOST --port 5432 --username "$USER" --no-password
#/usr/bin/dropdb -d "service=$QWATSERVICETEST"

echo "Creating DB (qwat_test)"
/usr/bin/createdb "$TESTDB" --host $HOST --port 5432 --username "$USER" --no-password
#/usr/bin/createdb -d "service=$QWATSERVICETEST"

echo "Initializing qwat DB in qwat_test"
./init_qwat.sh -p $QWATSERVICETEST -d > init_qwat.log

echo "Droping DB (qwat_test_conform)"
/usr/bin/dropdb "$TESTCONFORMDB" --host $HOST --port 5432 --username "$USER" --no-password
#/usr/bin/createdb -d "service=$QWATSERVICETEST"

echo "Creating DB (qwat_test_conform)"
/usr/bin/createdb "$TESTCONFORMDB" --host $HOST --port 5432 --username "$USER" --no-password
#/usr/bin/createdb -d "service=$QWATSERVICETEST"

echo "Getting lastest Tag num"
cd $DIR
LATEST_TAG=$(git describe)
#PROPER_LATEST_TAG=$(echo $LATEST_TAG| cut -d'-' -f 1)
SHORT_LATEST_TAG=$(echo $LATEST_TAG| cut -c 1)
printf "    Latest tag = ${GREEN}$SHORT_LATEST_TAG${NC}\n"


# !!!!!!!!!    TODO We need to execute init_qwat.sh from the lastest TAG version in $QWATSERVICETESTCONFORM
# Saving current branch
echo "Saving current branch"
#CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
CURRENT_BRANCH=$TRAVIS_BRANCH
printf "    Current branch = ${GREEN}$CURRENT_BRANCH${NC}\n"

PROPER_LATEST_TAG=$SHORT_LATEST_TAG".0.0"
echo "Switching on lastest tag major version ($PROPER_LATEST_TAG)"
git checkout tags/$PROPER_LATEST_TAG

cd ..
echo "Initializing qwat DB in qwat_test_conform"
./init_qwat.sh -p $QWATSERVICETESTCONFORM -d > init_qwat.log

echo "Switching back to current branch ($CURRENT_BRANCH)"
git checkout $CURRENT_BRANCH


echo "Applying deltas on $TESTCONFORMDB:"
for f in $DIR/delta/*.sql
do
    CURRENT_DELTA=$(basename "$f")
    #CURRENT_DELTA_NUM_VERSION=$(echo $CURRENT_DELTA| cut -d'_' -f 2)
    CURRENT_DELTA_NUM_VERSION=$(echo $CURRENT_DELTA| cut -c 7)
    if [[ $CURRENT_DELTA_NUM_VERSION > $SHORT_LATEST_TAG || $CURRENT_DELTA_NUM_VERSION = $SHORT_LATEST_TAG || $SHORT_LATEST_TAG = '' ]]; then
        printf "    Processing ${GREEN}$CURRENT_DELTA${NC}, num version = $CURRENT_DELTA_NUM_VERSION\n"
        /usr/bin/psql --host $HOST --port 5432 --username "$USER" --no-password -q -d "$TESTCONFORMDB" -f $f
    else
        printf "    Bypassing  ${RED}$CURRENT_DELTA${NC}, num version = $CURRENT_DELTA_NUM_VERSION\n"
    fi
done

echo "Producing referential file for test_qwat DB (from $QWATSERVICETEST)"
cd $DIR
/usr/bin/psql --host $HOST --port 5432 --username "$USER" --no-password -d "$QWATSERVICETEST" -f test_migration.sql > test_migration.expected.sql


#  By the way, this cannot work if there is no TAG version


echo "Performing conformity test"
STATUS=$(python test_migration.py --pg_service $QWATSERVICETESTCONFORM)

if [[ $STATUS == "DataModel is OK" ]]; then
    printf "${GREEN}Migration TEST is successfull${NC}. You may now migrate your real DB\n"
    EXITCODE=0
else
    printf "${RED}Migration TEST has failed${NC}. Please contact qWat team and give them the following output :\n $STATUS \n\n"
    EXITCODE=1
fi

exit $EXITCODE


# 
# echo "Cleaning"
# rm "$TODAY""_current_qwat.backup"
# rm init_qwat.log
# 
# # TODO : dropping qwat_test
# # TODO : dropping qwat_test_conform
