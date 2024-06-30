FROM python:3.12-slim-bookworm

RUN apt update && apt upgrade -y

WORKDIR /app

RUN pip install PyYaml

