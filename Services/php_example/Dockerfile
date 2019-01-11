FROM php:7.2-fpm

RUN apt-get update && apt-get install -y --no-install-recommends \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libmcrypt-dev \
        libpng-dev \
        libxml2-dev \
        mysql-client \
        libmagickwand-dev

RUN docker-php-ext-install mbstring tokenizer mysqli pdo_mysql

RUN apt-get clean

WORKDIR /code

COPY entry.sh /usr/local/bin/entry.sh
RUN chmod +x /usr/local/bin/entry.sh

CMD ["entry.sh"]
