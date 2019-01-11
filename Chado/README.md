## Chado Database

The Chado Database is a stand-alone PostgreSQL server that houses test biological data needed for the proof of concept.  Microservices that access Chado will use this database.

To start the container:
```
$ docker-compose build
$ docker-compose up
```

To execute the container's shell:
```
$ docker ps   # to get the container's id
$ docker exec -it [container id] /bin/sh
```
