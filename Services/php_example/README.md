## Example Using PHP Lumen Microframework 

This is intended as an example to run a Dockerized PHP service instead Python.

To start the container:

```bash
docker-compose up
docker ps   # to get the container's id
```

## Install the Dependencies

```bash
cd app && composer install
```

## To connect service to the gateway:

Test if service is up and on the network:
```
$ curl http://localhost:5002
$ docker network inspect tripal-kong
```

If the gateway is not already running, start it:
```
$ docker-compose up
```

Add the php-example service and create a route to it:
```
$ curl -i -X POST \
   --url http://localhost:8001/services/ \
   --data 'name=php-example' \
   --data 'url=http://localhost@php_example_app_1_[DOCKER'S UNIQUE ID]:80'

$ curl -i -X POST \
  --url http://localhost:8001/services/php-example/routes \
  --data 'paths[]=/php-example'
```

**NOTE**: verify that the service name matches the name displayed by `docker ps`. 
It usually has the directory prepended and a number appended to the service name.

Test if service can be accessed via the gateway:
```
$ curl http://localhost:8000/php-example
```
