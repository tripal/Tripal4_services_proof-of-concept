FROM ubuntu:latest

RUN ["apt-get", "update"]
RUN ["apt-get", "install", "-y", "vim"]
RUN ["apt-get", "install", "-y", "curl"]
RUN ["apt-get", "install", "-y", "git"]
## RUN apt-get update -y
RUN apt-get install -y python-pip python-dev build-essential
## RUN apt-get install -y vim

COPY . /app
WORKDIR /app
RUN pip install -r requirements.txt
ENTRYPOINT ["python"]
CMD ["service.py"]

