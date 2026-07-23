# Dockerfile
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive

# Instalação de dependências de build e runtime
# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    libncurses5-dev \
    libncurses6 \
    libtinfo6 \
    libssl-dev \
    libudev-dev \
    libtirpc-dev \
    bison \
    pkg-config \
    wget \
    tar \
    bzip2 \
    ncurses-term \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /root/build
COPY build.sh .
RUN chmod +x build.sh

# Define que o build rodará automaticamente ao iniciar o container
ENV CI_BUILD=1
CMD ["./build.sh"]
