#!/usr/bin/env bash

cp $PHP_INI_DIR/php.ini-$APP_ENV $PHP_INI_DIR/php.ini

php-fpm
