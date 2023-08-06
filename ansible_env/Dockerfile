FROM debian:11.6-slim

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update -y && \
    apt-get install -y \
	python3 \
	python3-pip \
	sudo \
	wget \
	curl \
	sshpass

RUN apt-get clean

RUN pip install --upgrade pip
RUN pip install ansible