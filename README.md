## Tripal 4 Services Proof-of-concept
Experimental code for a services-driven approach to Tripal 4.  

This repository contains 3 base containers to get a Tripal services system
running on, for example, a laptop. You will need all three containers described 
below.

Launch all three containers before following the Konga instructions described 
below.


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
Docker image contains Envoy (API gateway), Flask, Python, sample Python web 
service scripts.

The starter Docker container is a barebones setup for running a Flask service.

    $ cd Services/starter/
    
    $ docker-compose build  
    $ docker-compose up
    
    Test:
    $ docker ps
      Should see starter_starter_service
    $ curl http://localhost:5000
      Should see "Hello, World!"
    
    Enter container shell:
    $ docker ps   # to get CONTAINER ID
    $ docker exec -it [CONTAINER ID] /bin/sh
   

    
### Gateway/
Docker image contains Kong (gateway) + Konga (management gui) and Postgres 
(required backend) 

To Run:

    $ cd Gateway/
    $ docker-compose up

Active on: http://127.0.0.1:8000/route  
Webadmin: http://127.0.0.1:1337 (default)

First time running it, the postgres volume needs to populated, so 
you may need to stop and restart the service once migrations are
completed.

Further documentation for getting started with Kong and a sample toy service 
is in README.md in the Gateway/ directory.




