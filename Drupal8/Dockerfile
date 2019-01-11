## based on php:7.1-fpm-alpine
FROM composer:1.8

COPY nginx-drupal.conf /

RUN apk add --update --no-cache nginx postgresql && \
    apk add vim && \
    apk add nano && \
    apk add git

# Install Drush
RUN curl -L -o /usr/local/bin/drush \
    https://github.com/drush-ops/drush/releases/download/8.1.18/drush.phar && \
    chmod +x /usr/local/bin/drush

# NGINX
RUN mkdir /var/run/nginx && \
    chown nginx:nginx /var/run/nginx && \
    rm /etc/nginx/conf.d/default.conf && \
    printf 'listen = /var/run/php-fpm.sock\nlisten.group = nginx' > /usr/local/etc/php-fpm.d/zz-drupal.conf && \
    php-fpm -D && \
    mv /nginx-drupal.conf /etc/nginx/conf.d/ && \
    nginx


COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT /entrypoint.sh
