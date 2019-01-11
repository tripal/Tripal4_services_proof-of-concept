#!/usr/bin/env sh
if [ "$( psql -U postgres postgres -tAc "SELECT 1 FROM pg_database WHERE datname='chado'" )" != '1' ]
then
    echo "Database chado does not exist, creating it"
    # su - postgres
    # createuser -P chado_user
    # createdb chado -O chado_user
    # ALTER USER chado_user WITH PASSWORD 'password';
    psql -U chado_user < /docker-entrypoint-initdb.d/sql/1_all_chado_tables.sql
    psql -U chado_user < /docker-entrypoint-initdb.d/sql/2_load_basic_tables.sql
    psql -U chado_user < /docker-entrypoint-initdb.d/sql/3_load_germplasm_1.sql
    psql -U chado_user < /docker-entrypoint-initdb.d/sql/4_load_germplasm_2.sql
    psql -U chado_user < /docker-entrypoint-initdb.d/sql/5_load_gene_model.sql
else
    echo "Database chado has already been configured"
fi
