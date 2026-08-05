FROM ghcr.io/tom-tan/ldc:latest

ENV DEBIAN_FRONTEND=noninteractive

# Install packages and headers required to build Qt from source
RUN apt-get update && apt-get install -y \
    build-essential \
    && rm -rf /var/lib/apt/lists/*
