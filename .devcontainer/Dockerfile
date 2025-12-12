# Use the Ubuntu 24.04 base image (Noble)
FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

# Avoid prompts from apt
ARG DEBIAN_FRONTEND=noninteractive

# Update and install all requested system packages
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
    g++ \
    gcc \
    gettext \
    help2man \
    libtool \
    p7zip-full \
    python3-venv \
    binutils \
    llvm \
    lld \
    xutils-dev \
    python3-numpy \
    cython3 \
    libssl-dev \
    zlib1g-dev \
    libglib2.0-dev \
    libglib2.0-dev-bin \
    mingw-w64 && \ 
    # Install Rust
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && \
    # Source environment for the CURRENT session to keep running commands
    . "$HOME/.cargo/env" && \
    # Add Windows Target
    rustup target add x86_64-pc-windows-gnu && \
    # Verify Installation
    rustc --version && \
    cargo --version && \
    # Install cargo-c (Standard compile from source)
    cargo install cargo-c && \
    #Install latest meson
    pip3 install --user meson --break-system-packages && \
    # Cleanup to keep image small
    apt-get clean -y && \
    rm -rf /var/lib/apt/lists/*

# Persist the PATH for future sessions (e.g. when you log in)
# Note: Since this is a devcontainer base, $HOME is usually /root for the build
# but users might log in as 'vscode'. If you need Rust for the 'vscode' user,
# you must switch USER or adjust permissions. Assuming root here:
ENV PATH="/root/.cargo/bin:${PATH}"

# --- INSTALL FLUTTER ---
# 1. Install dependencies (already covered by your apt-get, but curl/git/unzip are vital)
# 2. Clone Flutter to a system directory
RUN git clone https://github.com/flutter/flutter.git -b stable /usr/local/flutter

# 3. Set permissions so 'vscode' user can use/upgrade it
RUN chown -R root:users /usr/local/flutter && \
    chmod -R 775 /usr/local/flutter
# 4. Add to PATH permanently
ENV PATH="/usr/local/flutter/bin:${PATH}"

# 5. Mark directory as safe for Git (fixes "dubious ownership" error)
RUN git config --system --add safe.directory /usr/local/flutter