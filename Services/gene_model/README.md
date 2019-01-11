## Tripal v4 Database

The Tripal v4 Database is a stand-alone PostgreSQL server that houses tables used by Tripal v4 for managing entities and fields.  It is used by Tripal microservices.

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
