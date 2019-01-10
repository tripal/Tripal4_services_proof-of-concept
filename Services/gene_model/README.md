## Gene model service

This is intended to be a simple gene model service that responds to two requests:

/search/gene/[term]  
/record/gene/[gene model]


The python service can be executed directly for testing and development (if
the local OS has Python and Flask running) or within the container.

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

## To connect service to the gateway:

Test if service is up and on the network:
```
$ curl http://localhost:5001
$ docker network inspect tripal-kong
```

If the gateway is not already running, start it:
```
$ docker-compose up
```

Add the gene model service and create a route to it:
```
$ curl -i -X POST \
   --url http://localhost:8001/services/ \
   --data 'name=gene-model' \
   --data 'url=http://localhost@gene_model_tpl_gene_service_1:5000'

$ curl -i -X POST \
  --url http://localhost:8001/services/gene-model/routes \
  --data 'paths[]=/genemodel'
```
**NOTE**: verify that the service name matches the name displayed by `docker ps`. 
It usually has the directory prepended and a number appended to the service name.

Test if service can be accessed via the gateway:
```
$ curl http://localhost:8000/genemodel
```