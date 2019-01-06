## Tripal 4 Services Proof-of-concept
Experimental code for a services-driven approach to Tripal 4

### Tripal3/
Stripped down Docker image of Tripal 3, populated with 
experimental gene model, marker, germplasm, and organism data. Nginix is the
web server. Adminer Postgres client included.

This Docker container uses Alpine Linux and Alpine Linux Package Manager.

    $ cd Tripal3/
    $ docker-compose build
    $ docker-compose up

    Test
    $ docker ps
      Should see tripal3_web, adminer, and postgres:10-alpine
    
    Enter container shell
    $ docker ps   # to get CONTAINER ID
    $ docker exec -it [CONTAINER ID] /bin/sh

Docker is listening to localhost:8888 (user: admin, password:admin)  
Adminer is listening to localhost:8080 (user:postgres, password:example)



### Services/
Docker image containing Envoy (API gateway), Flask, Python, sample Python web 
service scripts.

The starter Docker container is a barebones setup for running a Flask service.

    $ cd Services/starter/
    
    $ docker-compose build  
    $ docker-compose up
    
    Test
    $ docker ps
      Should see starter_starter_service
    $ curl http://localhost:5000
      Should see "Hello, World!"
    
    Enter container shell
    $ docker ps   # to get CONTAINER ID
    $ docker exec -it [CONTAINER ID] /bin/sh
   
###/Gateway
Kong (gateway) + Konga (management gui) and Postgres (required backend) 

To Run:
    $ cd Gateway/
    $ docker-compose up

First time running it, the postgres volume needs to populate, so 
you may need to stop and restart the service once migrations are
completed.

The webadmin can then be accessed at port 1337 (default)

Further documentation may be found in the README.md in the director.
