## based on php:7.1-fpm-alpine
FROM drupal:7.61-fpm-alpine

ENV PGDATA /var/lib/postgresql/data
ENV PDEXP /pgexp
ENV PGUSER postgres

COPY nginx-drupal.conf /

RUN apk add --update --no-cache nginx postgresql && \
    apk add vim && \
    apk add git && \
    curl -L -o /usr/local/bin/drush https://github.com/drush-ops/drush/releases/download/8.1.18/drush.phar && \
    chmod +x /usr/local/bin/drush && \
    mkdir  "${PGDATA}" /var/run/postgresql && \
    chown postgres:postgres "${PGDATA}" /var/run/postgresql && \
    chmod 700 "${PGDATA}" && \
    # https://github.com/gliderlabs/docker-alpine/issues/185
    mkdir /var/run/nginx && chown nginx:nginx /var/run/nginx && \
    su postgres -c 'initdb --encoding=UTF8' && \
    su postgres -c 'pg_ctl start' && \
    su postgres -c 'createdb --encoding=UTF8 drupal' && \
    rm /etc/nginx/conf.d/default.conf && \
    printf 'listen = /var/run/php-fpm.sock\nlisten.group = nginx' > /usr/local/etc/php-fpm.d/zz-drupal.conf && \
    php-fpm -D && \
    mv /nginx-drupal.conf /etc/nginx/conf.d/ && \
    nginx && \
    drush si -y --db-url=pgsql://postgres@localhost/drupal --account-name=admin --account-pass=admin --site-mail=admin@gmail.com --site-name='Tripal V3' && \
    drush dl -y field_group field_group_table field_formatter_class field_formatter_settings ctools ckeditor date devel ds link entity libraries redirect token uuid jquery_update views webform tripal-7.x-3.0 && \
    drush en -y field_group field_group_table field_formatter_class field_formatter_settings ctools date devel ds link entity libraries redirect token uuid jquery_update views views_ui webform && \
    curl -L https://drupal.org/files/drupal.pgsql-bytea.27.patch | patch -p1 && \
    (cd sites/all/modules/views && patch -p1 < ../tripal/tripal_chado_views/views-sql-compliant-three-tier-naming-1971160-30.patch) && \
    drush en -y tripal tripal_chado tripal_chado_views tripal_ds tripal_ws && \
    drush eval "module_load_include('inc', 'tripal_chado', 'includes/tripal_chado.install'); tripal_chado_load_drush_submit('Install Chado v1.3');" && \
    drush trp-run-jobs --username=admin && \
    drush eval "module_load_include('inc', 'tripal_chado', 'includes/setup/tripal_chado.setup'); tripal_chado_prepare_drush_submit();" && \
    drush trp-run-jobs --username=admin && \
    rm -rf ~/.drush && \
    mkdir $PDEXP && \ 
    pg_dump -U postgres drupal > $PDEXP/drupalexport.pgsql 

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT /entrypoint.sh
