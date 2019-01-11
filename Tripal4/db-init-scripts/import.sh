#!/usr/bin/env sh
psql -U tripal_user < /docker-entrypoint-initdb.d/sql/create_tables.sql
