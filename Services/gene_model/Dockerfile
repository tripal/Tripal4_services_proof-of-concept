#############################
# based on php:7.1-fpm-aline
FROM drupal:7.61-fpm-alpine

MAINTAINER Andrew Wilkey <awilkey@iastate.edu>
MAINTAINER Ethy Cannon <ekcannon@iastate.edu>


#Install flask env
COPY requirements.txt /tmp/requirements.txt
RUN apk add --no-cache py2-pip \
  && pip install --upgrade pip \
  && pip install flask \
  && pip install -r /tmp/requirements.txt

#Set up Flask
ENV APP_DIR /app
ENV FLASK_APP  gene_model_service.py
RUN mkdir ${APP_DIR}
COPY app ${APP_DIR}

VOLUME ${APP_DIR}

WORKDIR ${APP_DIR}
CMD ["/usr/bin/flask", "run", "--reload", "-h", " 0.0.0.0"]

#### Set up Postgres
ENV PGDATA /var/lib/postgresql/data
ENV PDEXP /pgexp
ENV PGUSER postgres

RUN apk add --update --no-cache nginx postgresql && \
    mkdir  "${PGDATA}" /var/run/postgresql && \
    chown postgres:postgres "${PGDATA}" /var/run/postgresql && \
    chmod 700 "${PGDATA}" && \
    # https://github.com/gliderlabs/docker-alpine/issues/185:
    mkdir /var/run/nginx && chown nginx:nginx /var/run/nginx && \
    su postgres -c 'initdb --encoding=UTF8' && \
    su postgres -c 'pg_ctl start' && \
    su postgres -c 'createdb --encoding=UTF8 drupal' && \
    rm /etc/nginx/conf.d/default.conf && \
    mkdir $PDEXP

#### vim
RUN apk add --no-cache vim

#### clean up
RUN rm -rf /.wh /root/.cache /var/cache /tmp/requirements.txt
