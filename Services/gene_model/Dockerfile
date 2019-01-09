FROM alpine
MAINTAINER Andrew Wilkey <awilkey@iastate.edu>


#Install flask env
COPY requirements.txt /tmp/requirements.txt
RUN apk add --no-cache py2-pip \
  && pip install --upgrade pip \
  && pip install flask \
  && pip install -r /tmp/requirements.txt

#Setup Flask
ENV APP_DIR /app
ENV FLASK_APP  gene_model_service.py
RUN mkdir ${APP_DIR}
COPY app ${APP_DIR}

VOLUME ${APP_DIR}

#clean
RUN rm -rf /.wh /root/.cache /var/cache /tmp/requirements.txt

WORKDIR ${APP_DIR}
CMD ["/usr/bin/flask", "run", "--reload", "-h", " 0.0.0.0"]
