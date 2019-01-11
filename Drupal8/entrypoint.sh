#!/usr/bin/env sh
# Drupal Install

#drush si -y --db-url=pgsql://drupal8_user@drupal8_db/drupal --account-name=admin --account-pass=admin --site-mail=admin@gmail.com --site-name='Drupal D8'

# echo "entrypoint.sh";
# echo ${DB_HOST};
# set -o xtrace
# chmod 777 /var/www/html/web/sites/default/settings.php
# ls -l /var/www/html/web/sites/default
# sed -i "s/'database' => 'drupal'/'database' => '$DB_NAME'/g" /var/www/html/web/sites/default/settings.php
# sed -i "s/'username' => 'drupal8_user'/'username' => '$PGUSER'/g" /var/www/html/web/sites/default/settings.php
# sed -i "s/'password' => 'example'/'password' => '$POSTGRES_PASSWORD'/g" /var/www/html/web/sites/default/settings.php
# sed -i "s/'host' => 'drupal8_db'/'host' => '$DB_HOST'/g" /var/www/html/web/sites/default/settings.php
# sed -i "s/'port' => '5432' => 'port'/'$DB_PORT'/g" /var/www/html/web/sites/default/settings.php
# chmod 444 /var/www/html/web/sites/default/settings.php

# php-fpm -D
# nginx -g 'daemon off;'
