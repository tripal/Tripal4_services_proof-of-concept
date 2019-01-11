# ## based on php:7.1-fpm-alpine
FROM drupal:8.6.5-fpm-alpine

ENV PGDATA /var/lib/postgresql/data
ENV PDEXP /pgexp
ENV PGUSER postgres

COPY nginx-drupal.conf /

RUN apk add --update --no-cache nginx postgresql && \
    apk add vim && \
    apk add nano && \
    apk add git 

# Install Composer, drush and drupal console
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer \
    && HOME=/ /usr/local/bin/composer global require drush/drush:~8 \
    && ln -s /.composer/vendor/drush/drush/drush /usr/local/bin/drush \
    && curl https://drupalconsole.com/installer -L -o /usr/local/bin/drupal \
    && chmod +x /usr/local/bin/drupal \
    && php --version; composer --version; drupal --version; drush --version

# NGINX and Postgres
RUN mkdir  "${PGDATA}" /var/run/postgresql && \
    chown postgres:postgres "${PGDATA}" /var/run/postgresql && \
    chmod 700 "${PGDATA}" && \
    mkdir /var/run/nginx && chown nginx:nginx /var/run/nginx && \
    su postgres -c 'initdb --encoding=UTF8' && \
    su postgres -c 'pg_ctl start' && \
    su postgres -c 'createdb --encoding=UTF8 drupal -O postgres' && \
    rm /etc/nginx/conf.d/default.conf && \
    printf 'listen = /var/run/php-fpm.sock\nlisten.group = nginx' > /usr/local/etc/php-fpm.d/zz-drupal.conf && \
    php-fpm -D && \
    mv /nginx-drupal.conf /etc/nginx/conf.d/ && \
    nginx

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT /entrypoint.sh
CMD ["postgres"]
