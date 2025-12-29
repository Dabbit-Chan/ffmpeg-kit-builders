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
    shellcheck \
    libgtkmm-3.0-dev \
    libsdl2-dev

ENV PATH="/usr/local/mingw-w64/bin:${PATH}"

# Install xPack MinGW-w64 GCC 15.2.0-2
RUN wget https://github.com/xpack-dev-tools/mingw-w64-gcc-xpack/releases/download/v15.2.0-2/xpack-mingw-w64-gcc-15.2.0-2-linux-x64.tar.gz && \
    mkdir -p tools && \
    tar xf xpack-mingw-w64-gcc-15.2.0-2-linux-x64.tar.gz -C tools && \
    rm xpack-mingw-w64-gcc-15.2.0-2-linux-x64.tar.gz && \
    mv tools/xpack-mingw-w64-gcc-15.2.0-2 /usr/local/mingw-w64 && \
    chown -R root:users /usr/local/mingw-w64 && \
    chmod -R 775 /usr/local/mingw-w64

# 1. Force Rust to install globally (Best practice for Dev Containers)
ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH

# 2. Install Tools
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path && \
    # Source the global env file (not ${HOME})
    . /usr/local/cargo/env && \
    rustup target add x86_64-pc-windows-gnu && \
    # Verify Rust
    rustc --version && \
    cargo --version && \
    # Install cargo-c
    cargo install cargo-c && \
    ln -sf /usr/local/cargo/bin/* /usr/local/bin/ && \
    pip3 install meson --break-system-packages && \
    # Cleanup
    apt-get clean -y && \
    rm -rf /var/lib/apt/lists/*

# 3. CRITICAL: Allow 'vscode' user to use Cargo (install crates, update index, etc.)
RUN chmod -R a+w /usr/local/cargo /usr/local/rustup

# --- INSTALL FLUTTER ---
# 1. Clone Flutter to a system directory
RUN git clone https://github.com/flutter/flutter.git -b stable /usr/local/flutter

# 2. Set permissions: Give 'vscode' ownership so it can write cache/locks
#    (Assuming 'vscode' user exists; if using a standard devcontainer base, it does)
RUN chown -R vscode:vscode /usr/local/flutter

# 3. Add to PATH permanently
ENV PATH="/usr/local/flutter/bin:${PATH}"

# 4. Mark directory as safe for Git to suppress "dubious ownership" warnings
RUN git config --system --add safe.directory /usr/local/flutter

# 5. Pre-download development binaries (run as vscode to ensure permissions stay correct)
USER vscode
RUN flutter config --no-analytics && flutter precache
USER root

RUN dpkg --add-architecture i386

RUN mkdir -pm755 /etc/apt/keyrings && \
    wget -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key && \
    wget -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/ubuntu/dists/noble/winehq-noble.sources

RUN apt-get update && \
    apt-get install -y --install-recommends winehq-stable

# --- INSTALL ANDROID SDK ---
# 1. Install OpenJDK 17 (Required for Android SDK)
RUN apt-get update && apt-get install -y openjdk-17-jdk unzip

# 2. Set Environment Variables
ENV ANDROID_HOME=/usr/local/android-sdk
ENV PATH="${PATH}:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools"

# 3. Download Android Command Line Tools
#    (Note: The tool requires a specific folder structure: cmdline-tools/latest/bin)
RUN mkdir -p ${ANDROID_HOME}/cmdline-tools && \
    curl -o /tmp/cmdline-tools.zip -L https://dl.google.com/android/repository/commandlinetools-linux-13114758_latest.zip && \
    unzip -q /tmp/cmdline-tools.zip -d ${ANDROID_HOME}/cmdline-tools && \
    mv ${ANDROID_HOME}/cmdline-tools/cmdline-tools ${ANDROID_HOME}/cmdline-tools/latest && \
    rm /tmp/cmdline-tools.zip

# 4. Fix Permissions: Give 'vscode' ownership so it can write updates/licenses
RUN chown -R vscode:vscode ${ANDROID_HOME}

# 5. Accept Licenses & Install Basics (Run as vscode to keep permissions correct)
USER vscode
RUN yes | sdkmanager --licenses && \
    sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"
USER root

RUN git config --global --add safe.directory '*'