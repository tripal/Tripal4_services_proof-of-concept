## Files to preload Chado with some example data

### Create the chado schema and tables
1- Create a schema named "chado" and all of the Chado tables:
```
$ psql -U [username] < 1_all_chado_tables.sql
``` 
(There will likely be several errors, but these _appear_ to be harmless.)

### Load sample germplasm data
2- Load several tables that the germplasm data relies on:
```
$ psql -U [username] < 2_load_germplasm_1.sql
```
(Again, there may be several does or does not exist errors)

3- Load data into several germplasm tables:
```
$ /Library/PostgreSQL/9.4/bin/psql -U postgres < 3_load_germplasm_2.sql
``` 
4- Start up psql:
```
$ psql -U [username]
``` 
and test data with:

    SELECT s.stock_id, s.name AS stockname, t.name AS stocktype,
           o.organism_id, o.common_name, o.genus, o.species,
           ARRAY_AGG(sc.name) AS collection
    FROM chado.stock s
      INNER JOIN chado.organism o ON o.organism_id=s.organism_id
      INNER JOIN chado.cvterm t ON t.cvterm_id=s.type_id
      LEFT JOIN chado.stockcollection_stock ss ON ss.stock_id=s.stock_id
      LEFT JOIN chado.stockcollection sc ON sc.stockcollection_id=ss.stockcollection_id
    GROUP BY s.stock_id, s.name, t.name, o.organism_id, o.common_name, o.genus, o.species
    ORDER BY s.name;

### To add some gene model data, complete the steps above, then:
5- Load gene model data:
```
$ /Library/PostgreSQL/9.4/bin/psql -U postgres < 4_load_gene_model.sql
```
6- Start up psql:
```
    $ psql -U [username]
```
and test data with:

    SELECT f.name, c.name, fl.fmin, fl.fmax, n.value AS note,
           gf.value AS gene_family
    FROM chado.feature f
      INNER JOIN chado.featureloc fl on fl.feature_id=f.feature_id 
      INNER JOIN chado.feature c on c.feature_id=fl.srcfeature_id
      LEFT JOIN chado.featureprop n on n.feature_id=f.feature_id
        AND n.type_id=(SELECT cvterm_id FROM chado.cvterm where name='Note')
      LEFT JOIN featureprop gf on gf.feature_id=f.feature_id
        AND gf.type_id=(SELECT cvterm_id FROM chado.cvterm where name='gene family')
    WHERE f.type_id=(SELECT cvterm_id FROM chado.cvterm where name='gene');
