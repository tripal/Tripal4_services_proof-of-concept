#!/usr/bin/env sh
echo "entrypoint.sh";
echo ${DB_HOST};
set -o xtrace
chmod 777 /var/www/html/web/sites/default/settings.php
ls -l /var/www/html/web/sites/default
sed -i "s/'database' => 'drupal'/'database' => '$DB_NAME'/g" /var/www/html/web/sites/default/settings.php
sed -i "s/'username' => 'postgres'/'username' => '$PGUSER'/g" /var/www/html/web/sites/default/settings.php
sed -i "s/'password' => ''/'password' => '$POSTGRES_PASSWORD'/g" /var/www/html/web/sites/default/settings.php
sed -i "s/'host' => 'localhost'/'host' => '$DB_HOST'/g" /var/www/html/web/sites/default/settings.php
sed -i "s/'port' => '' => 'port'/'$DB_PORT'/g" /var/www/html/web/sites/default/settings.php
chmod 444 /var/www/html/web/sites/default/settings.php

php-fpm -D
nginx -g 'daemon off;'
