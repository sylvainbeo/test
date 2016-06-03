#!/bin/bash


# Exit on error
set -e


# schematic
psql -v ON_ERROR_STOP=1 -v SRID=$SRID -f ordinary_data/views/view_db.sql
