# Minimal image for building FFmpegKit for OpenHarmony / HarmonyOS.
# Strips Flutter, Wine, Android NDK, MinGW, ARM toolchain, Gradle, etc.
# The OpenHarmony Native SDK (clang + sysroot) is mounted in at run time.

FROM --platform=linux/amd64 ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# Core build toolchain + sources for FFmpeg + meson/ninja + autotools + perl
# (openssl needs perl, libjsoncpp needs meson/ninja).
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates \
      build-essential \
      cmake \
      ninja-build \
      autoconf \
      autoconf-archive \
      automake \
      libtool \
      libtool-bin \
      m4 \
      pkg-config \
      patch \
      bison \
      flex \
      gperf \
      texinfo \
      gettext \
      git \
      wget \
      curl \
      nasm \
      yasm \
      python3 \
      python3-pip \
      python3-setuptools \
      perl \
      xz-utils \
      unzip \
      bzip2 \
      tar \
      file \
      sudo \
    && rm -rf /var/lib/apt/lists/*

# Pin meson to a known-good version (ubuntu 22.04 ships 0.61, some recipes prefer newer).
RUN pip3 install --no-cache-dir meson==1.5.1

# Match the 'vscode' user the runner scripts assume.
RUN useradd -m -s /bin/bash vscode && \
    echo "vscode ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

WORKDIR /workspace
