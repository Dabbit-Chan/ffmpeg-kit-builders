# Use the Ubuntu 24.04 base image (Noble)
FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive

# Update and install all requested system packages
# - build-essential covers: gcc, g++
# - texinfo covers: makeinfo
# - xz-utils covers: xz
RUN sudo apt-get update && apt-get install -y --no-install-recommends \
    ragel \
    pkg-config \
    make \
    autoconf \
    automake \
    yasm \
    cvs \
    flex \
    bison \
    texinfo \
    ed \
    pax \
    unzip \
    patch \
    wget \
    xz-utils \
    nasm \
    gperf \
    autogen \
    bzip2 \
    clang \
    bc \
    autopoint \
    zstd \
    curl \
    git \
    subversion \
    libtool-bin \
    build-essential \
    cmake \
    software-properties-common \
    python3 \
    coreutils \
    python3-pip \
    apt-transport-https \
    ca-certificates \
    python3-setuptools \
    ninja-build \
    autoconf-archive \
    cargo \
    g++ \
    gcc \
    gettext \
    help2man \
    libtool \
    meson \
    p7zip-full \
    python3-venv \
    zlib1g-dev \
    libglib2.0-dev \
    libglib2.0-dev-bin \
    sudo \
    apt \
    install \
    binutils \
    llvm \
    lld \
    xutils-dev \
    python3-numpy \
    cython3
    # Cleanup to keep image small
    && sudo apt-get clean -y && sudo rm -rf /var/lib/apt/lists/*

# copy the entire git dir into the new docker container
#COPY . ./ffmpeg-kit-builders

WORKDIR /ffmpeg-kit-builders
#ENTRYPOINT [ "bash", "./docker/docker-entry.sh" ]
