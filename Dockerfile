FROM ubuntu:24.04
RUN apt-get update \
 && apt-get install -y cryptsetup e2fsprogs bsdextrautils \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /lab
