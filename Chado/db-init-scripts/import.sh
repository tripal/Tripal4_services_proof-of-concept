if [ "$( pqsl -U postgres postgres -tAc "SELECT 1 FROM pg_database WHERE datname='drupal'" )" != '1' ]
then
    echo "Database drupal does not exist, creating it"
    createdb -U postgres drupal
    psql -U postgres drupal < /pgexp/drupalexport.pgsql
else
    echo "Database drupal has already been configured"
fi
