## Tripal 4 Services Proof-of-concept
Docker containers and experimental code for a services-driven approach to 
Tripal 4.  

**Stack:** Drupal7/Tripal3, Kong, Python/Flask, Nginx.
There may well be better stacks, but this will help us explore these elements 
with the hope of then knowing better how to assess alternatives.

Preliminary steps
1. Make sure you have at least 8Gb free on your laptop. (This is actually just 
a guess.)

2. Install Docker: https://docs.docker.com/v17.12/install. Note that you will
need to create a Docker account.

3. Consider also installing Kitematic for managing docker containers and images,
though this can also be done easily on the command. https://kitematic.com

4. Install the Insomnia REST client: https://insomnia.rest/download/ (or your 
prefered REST client test app). This will help with testing services.

5. Clone this repository:
    $ git clone https://github.com/tripal/Tripal4_services_proof-of-concept.git

This repository contains 3 base containers to get a Tripal services system
running on a local machine. You will need all three containers described 
below.

Launch all three containers before following the service setup instructions in
Gateway/README.md.


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

Tripal is listening to localhost:8888 (user: admin, password:admin)  
Adminer is listening to localhost:8080 (user:postgres, password:example)
  

### Services/
Docker image contains Envoy (API gateway), Flask, Python, sample Python web 
service scripts.

The starter/ Docker container is a barebones setup for running a Python/Flask 
service.

    $ cd Services/starter/

    Build the docker containers
    $ docker-compose build  
    
    Setup the Network
    $ docker network create tripal-kong
    
    Bring up the containers
    $ docker-compose up
    
    Test:
    $ docker ps
      Should see starter_starter_service
    $ curl http://localhost:5000
      Should see "Hello, World!"
    
    To enter container shell:
    $ docker ps   # to get CONTAINER ID
    $ docker exec -it [CONTAINER ID] /bin/sh
   

    
### Gateway/
Docker image contains Kong (gateway) + Konga (management gui) and Postgres 
(required backend) 

To Run:

    $ cd Gateway/
    $ docker-compose up

access on: http://127.0.0.1:8000  
admin: http://127.0.0.1:8001 

First time running it, the postgres volume needs to populated, so 
you may need to stop and restart the service once migrations are
completed.


**Instructions for getting started with Kong and how to create a sample toy 
service is in README.md in the Gateway/ directory.**




