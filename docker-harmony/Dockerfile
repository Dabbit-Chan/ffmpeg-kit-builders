# Minimal image for building FFmpegKit for OpenHarmony / HarmonyOS.
# Strips Flutter, Wine, Android NDK, MinGW, ARM toolchain, Gradle, etc.
# The OpenHarmony Native SDK (clang + sysroot) is mounted in at run time.

FROM ubuntu:latest

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# Core build toolchain + sources for FFmpeg + meson/ninja + autotools + perl
# (openssl needs perl, libjsoncpp needs meson/ninja).
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates \
      build-essential \
      clang \
      lld \
      llvm \
      cmake \
      ninja-build \
      autoconf \
      autoconf-archive \
      automake \
      autogen \
      autopoint \
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
      subversion \
      cvs \
      wget \
      curl \
      nasm \
      yasm \
      ragel \
      ed \
      pax \
      bc \
      libglib2.0-dev \
      libglib2.0-dev-bin \
      lsb-release \
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

# Pin meson to a known-good version. Ubuntu 24.04+ ships PEP 668 (externally-
# managed Python), so pip needs --break-system-packages to install into the
# system interpreter inside the image.
RUN pip3 install --no-cache-dir --break-system-packages meson==1.5.1

# Match the 'vscode' user the runner scripts assume.
RUN useradd -m -s /bin/bash vscode && \
    echo "vscode ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

WORKDIR /workspace
