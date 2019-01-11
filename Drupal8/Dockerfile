## based on php:7.1-fpm-alpine
FROM drupal:8-fpm-alpine

ENV PGDATA /var/lib/postgresql/data
ENV PDEXP /pgexp
ENV PGUSER postgres

COPY nginx-drupal.conf /

RUN apk add --update --no-cache nginx postgresql && \
    apk add vim && \
    apk add nano && \
    apk add git && \
    curl -L -o /usr/local/bin/drush https://github.com/drush-ops/drush/releases/download/8.1.18/drush.phar && \
    chmod +x /usr/local/bin/drush && \
    # curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer && \
    # HOME=/ /usr/local/bin/composer global require drush/drush:~8 && \
    # ln -s /.composer/vendor/drush/drush/drush /usr/local/bin/drush && \
    # composer require drupal/console:~1.0 --prefer-dist --optimize-autoloader && \
    # curl https://drupalconsole.com/installer -L -o /usr/local/bin/drupal && \
    # chmod +x /usr/local/bin/drupal && \
    # composer update && \
    # php --version; composer --version; drupal --version; drush --version && \
    # Postgres
    mkdir  "${PGDATA}" /var/run/postgresql && \
    chown postgres:postgres "${PGDATA}" /var/run/postgresql && \
    chmod 700 "${PGDATA}" && \
    # https://github.com/gliderlabs/docker-alpine/issues/185
    su postgres -c 'initdb --encoding=UTF8' && \
    su postgres -c 'pg_ctl start' && \
    su postgres -c 'createdb --encoding=UTF8 drupal' && \
    # NGINX
    mkdir /var/run/nginx && chown nginx:nginx /var/run/nginx && \
    rm /etc/nginx/conf.d/default.conf && \
    printf 'listen = /var/run/php-fpm.sock\nlisten.group = nginx' > /usr/local/etc/php-fpm.d/zz-drupal.conf && \
    php-fpm -D && \
    mv /nginx-drupal.conf /etc/nginx/conf.d/ && \
    nginx && \
    # Drupal Install
    drush si standard -y --db-url=pgsql://postgres@localhost/drupal --account-name=admin --account-pass=admin --site-mail=admin@gmail.com --site-name='Drupal D8' && \

    # composer create-project drupal-composer/drupal-project:8.x-dev / --stability dev --no-interaction && \
    # cd web && \
    # ../vendor/drush/drush/drush site-install standard \
    #   --db-url=pgsql://postgres@localhost/drupal \
    #   --account-mail="admin@example.com" \
    #   --account-name=admin \
    #   --account-pass=admin \
    #   --site-mail="admin@example.com" \
    #   --site-name="Drupal 8" && \
    mkdir $PDEXP && \ 
    pg_dump -U postgres drupal > $PDEXP/drupalexport.pgsql 

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT /entrypoint.sh
