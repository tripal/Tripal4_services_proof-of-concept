#!/usr/bin/env sh
psql -U chado_user < /docker-entrypoint-initdb.d/sql/1_all_chado_tables.sql
psql -U chado_user < /docker-entrypoint-initdb.d/sql/2_load_basic_tables.sql
psql -U chado_user < /docker-entrypoint-initdb.d/sql/3_load_germplasm_1.sql
psql -U chado_user < /docker-entrypoint-initdb.d/sql/4_load_germplasm_2.sql
psql -U chado_user < /docker-entrypoint-initdb.d/sql/5_load_gene_model.sql
