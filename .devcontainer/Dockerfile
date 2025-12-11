# Use the Ubuntu 24.04 base image (Noble)
FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

# Avoid prompts from apt
ARG DEBIAN_FRONTEND=noninteractive

# Update and install all requested system packages
# - build-essential covers: gcc, g++
# - texinfo covers: makeinfo
# - xz-utils covers: xz
RUN apt-get update && \
    apt-get install -qq --no-install-recommends \
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
    binutils \
    llvm \
    lld \
    xutils-dev \
    python3-numpy \
    cython3 \
    zlib1g-dev \
    libglib2.0-dev \
    libglib2.0-dev-bin && \
    # Cleanup to keep image small
    apt-get clean -y && \
    rm -rf /var/lib/apt/lists/*
