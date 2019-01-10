#!/usr/bin/env sh
if [ "$( psql -U postgres postgres -tAc "SELECT 1 FROM pg_database WHERE datname='chado'" )" != '1' ]
then
    echo "Database chado does not exist, creating it"
    # su - postgres
    # createuser -P chado_user
    # createdb chado -O chado_user
    # ALTER USER chado_user WITH PASSWORD 'password';
    psql -U chado_user < /setup_sql/1_all_chado_tables.sql
    psql -U chado_user < /setup_sql/2_load_basic_tables.sql
    psql -U chado_user < /setup_sql/3_load_germplasm_1.sql
    /Library/PostgreSQL/9.6/bin/psql -U chado_user < /setup_sql/4_load_germplasm_2.sql
    if [ "$( psql -U postgres postgres -tAc "SELECT s.stock_id, s.name AS stockname, t.name AS stocktype, o.organism_id, o.common_name, o.genus, o.species, ARRAY_AGG(sc.name) AS collection FROM chado.stock s INNER JOIN chado.organism o ON o.organism_id=s.organism_id INNER JOIN chado.cvterm t ON t.cvterm_id=s.type_id LEFT JOIN chado.stockcollection_stock ss ON ss.stock_id=s.stock_id LEFT JOIN chado.stockcollection sc ON sc.stockcollection_id=ss.stockcollection_id GROUP BY s.stock_id, s.name, t.name, o.organism_id, o.common_name, o.genus, o.species ORDER BY s.name" )"]
    then
      echo "Germplasm was loaded succesfully"  
    fi
    /Library/PostgreSQL/9.6/bin/psql -U chado_user < /setup_sql/5_load_gene_model.sql
    if [ "$( psql -U postgres postgres -tAc "SELECT f.name, c.name, fl.fmin, fl.fmax, n.value AS note, gf.value AS gene_family FROM chado.feature f INNER JOIN chado.featureloc fl on fl.feature_id=f.feature_id INNER JOIN chado.feature c on c.feature_id=fl.srcfeature_id LEFT JOIN chado.featureprop n on n.feature_id=f.feature_id AND n.type_id=(SELECT cvterm_id FROM chado.cvterm where name='Note') LEFT JOIN featureprop gf on gf.feature_id=f.feature_id AND gf.type_id=(SELECT cvterm_id FROM chado.cvterm where name='gene family') WHERE f.type_id=(SELECT cvterm_id FROM chado.cvterm where name='gene')" )"]
    then
      echo "Gene Model was loaded succesfully"  
    fi
else
    echo "Database chado has already been configured"
fi
