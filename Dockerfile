FROM ubuntu:24.04
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      cryptsetup e2fsprogs bsdextrautils binutils \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /lab
