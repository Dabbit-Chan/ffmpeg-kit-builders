
# FFmpeg-Kit Builders

Cross-platform build system for FFmpeg and FFmpegKit supporting Linux and Windows platforms.

## Overview

This repository provides a comprehensive build system for FFmpeg and FFmpegKit that supports multiple platforms and architectures. The system handles the complete build pipeline from toolchain installation through dependency compilation to final bundle creation, with support for both native Linux builds and cross-compilation to Windows from Linux hosts.

## Platform Support

- **Linux**: Native builds for x86_64 and i686 architecture with shared libraries (.so) and static libraries (.a).
- **Windows**: Cross-compilation from Linux hosts using MinGW-w64 toolchain with shared libraries (.dll) and static mingw libraries (.a). 
  - *Note: MSVC ABI is not supported.*
- **Android**: Currently not support - WIP
- **Apple**: Apple platforms are not currently planned as I dont have one of those to develop and test. The framework is there so you are welcome to contribute!
  - **MacOS**: Not planned 
  - **iOS**: Not planned

## Quick Start

### Prerequisites

- **OS**: Linux host or WSL2 (Ubuntu 22.04+/Debian recommended).
- **RAM**: Minimum 600MB (Hard limit check in script), **4GB+ recommended** for linking static binaries.
- **Disk Space**: ~285GB available disk space for a full build with all dependencies and intermediate object files.
- **Tools**: `git`, `make`, `cmake`, `ninja`, `meson`, `pkg-config`, `curl`, `tar`, `unzip`, `sudo`.

### Using the Unified Entry Point

The `runner.sh` script is the unified entry point for all builds. It can be used interactively or with explicit command-line options. Note that the script requires `sudo` privileges to install system packages and configure the build environment.

### Common Build Scenarios

```bash
# Interactive mode - prompts for platform and architecture
sudo ./runner.sh

# Non-interactive mode: Build GPL version with audio libraries for Linux x86_64
sudo ./runner.sh --host=linux --arch=x86_64 -y --enable-gpl --enable-audio

# Cross-compile for Windows 64-bit (Shared Libs + Video Bundle)
sudo ./runner.sh --host=windows --arch=x86_64 --enable-gpl --enable-shared --video-bundle

# Build static libraries for Linux
sudo ./runner.sh --host=linux --arch=x86_64 --enable-static

# Build for Linux with specific additional libraries
sudo ./runner.sh --host=linux --arch=x86_64 --enable-fontconfig --enable-freetype

# Force re-build for Linux (all libraries + FFmpegKit) with hardware acceleration
sudo ./runner.sh --host=linux --arch=x86_64 -f --video-hw-bundle

# Create a redistributable release zip
sudo ./runner.sh --host=linux --arch=x86_64 --full-bundle --release
```

## Architecture

The build system implements a modular architecture:

1. **Unified Entry Point**: `runner.sh` handles platform selection, argument parsing, and environment checks.
2. **Orchestration**: `scripts/main-linux.sh` and `scripts/main-windows.sh` coordinate the dependency tree.
3. **Execution Primitives**: `scripts/function.sh` contains the core logic for downloading, configuring, and compiling generic C/C++ projects.
4. **Library Recipes**: `scripts/run-linux.sh` and `scripts/run-windows.sh` contain specific build instructions for 100+ libraries.

## Output Bundle Structure

Artifacts are generated in the `prebuilt/` directory.

```text
prebuilt/
├── {platform}-{arch}/                                # e.g., linux-x86_64
│   ├── bundle-{platform}-{arch}-{type}/              # Unpacked Bundle
│   │   └── ffmpeg-kit/
│   │       ├── include/                              # Headers
│   │       ├── lib/                                  # .so/.dll/.a files
│   │       ├── bin/                                  # ffmpeg/ffprobe executables
│   │       ├── pkgconfig/                            # .pc files for linkage
│   │       └── licenses/                             # Extracted licenses
│   └── releases/
│       └── bundle-{platform}-{arch}-{type}.zip       # Redistributable ZIP (if --release used)
```

## Build Phases

1. **Setup**: Initialize paths, environment variables (`CFLAGS`, `LDFLAGS`), and architecture settings.
2. **Toolchain**: Build or verify MinGW-w64 GCC 15+ toolchain (Windows targets only).
3. **Dependencies**: Compile enabled external libraries (e.g., x264, openssl, freetype) sequentially.
4. **FFmpeg**: Configure and build FFmpeg linking against the built dependencies.
5. **FFmpegKit**: Build the C++ wrapper library (`libffmpegkit`).
6. **Bundle**: Aggregate artifacts, fix paths in `pkg-config`, and collect licenses.

## Compiler Toolchain

### Windows (Cross-Compile)
Windows builds use the MinGW-w64 GCC 15.x toolchain. If running on a native Linux host (not a pre-configured Docker container), you **must** install the toolchain manually:

```bash
# Run as root/sudo
apt update && apt install binutils

# Download MinGW-w64 GCC 15
wget https://github.com/xpack-dev-tools/mingw-w64-gcc-xpack/releases/download/v15.2.0-2/xpack-mingw-w64-gcc-15.2.0-2-linux-x64.tar.gz
mkdir -p tools
tar xf xpack-mingw-w64-gcc-15.2.0-2-linux-x64.tar.gz -C tools
rm xpack-mingw-w64-gcc-15.2.0-2-linux-x64.tar.gz

# Install to /usr/local
mv tools/xpack-mingw-w64-gcc-15.2.0-2 /usr/local/mingw-w64
chown -R root:users /usr/local/mingw-w64
chmod -R 775 /usr/local/mingw-w64
```

### Rust Toolchain
Many modern multimedia libraries (rav1e, dovi_tool) require Rust.

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
source $HOME/.cargo/env

# Add Windows target for cross-compilation
rustup target add x86_64-pc-windows-gnu
# rustup target add i686-pc-windows-gnu # Uncomment for 32-bit builds

cargo install cargo-c
```

## Command-Line Options

### General & Platform
| Option | Description |
|--------|-------------|
| `-h, --help` | Display help |
| `-d, --debug` | Build with debug symbols (`-g`) and no optimization |
| `-f, --force` | Force rebuild of all dependencies (cleans `already_built` flags) |
| `-y` | Non-interactive mode (accept defaults) |
| `--release` | Create a ZIP archive of the final bundle |
| `--host=*` | Target platform: `linux` or `windows` |
| `--arch=*` | Target architecture: `x86_64` or `i686` |

### Licensing
| Option | Description |
|--------|-------------|
| `--enable-gpl` | Enables GPL libraries (x264, xvid, etc.). Resulting binary is **GPLv3**. |
| `--enable-nonfree` | Enables non-free libraries (fdk-aac, decklink). Resulting binary is **Non-Redistributable**. |

### Feature presets
| Option | Description |
|--------|-------------|
|`--enable-full            `|enable all available external libraries (based on gpl/non-gpl selection)
|`--enable-small           `|exclude certain extra libraries from presets to reduce size (see --list-excluded)
|`--enable-https           `|enable https libraries
|`--enable-audio           `|enable all audio processing libraries
|`--enable-audio-ai        `|enable all audio processing ai libraries
|`--enable-video           `|enable all video processing libraries
|`--enable-video-streaming `|enable all video streaming libraries
|`--enable-video-ai-cpu    `|enable all video ai cpu based libraries
|`--enable-video-ai-gpu    `|enable all video ai gpu based libraries
|`--enable-hardware        `|enable all hardware accel libraries
|`--enable-ssh             `|enable SSH/SFTP support
|`--enable-smb             `|enable SMB (SAMBA) file sharing protocol support
|`--enable-mq              `|enable distributed systems support

### Bundle presets
| Option | Description |
|--------|-------------|
|`--audio-bundle           `|contains https + audio only libraries in the final bundle
|`--audio-ai-bundle        `|contains https + audio + audio only ai libraries in the final bundle
|`--video-bundle           `|contains https + audio + video libraries in the final bundle
|`--video-ai-cpu-bundle    `|contains https + audio + video + ai (cpu) libraries in the final bundle
|`--video-ai-gpu-bundle    `|contains https + audio + video + ai (gpu) libraries in the final bundle
|`--video-hw-bundle        `|contains https + audio + video + hardware libraries in the final bundle
|`--video-ai-cpu-hw-bundle `|contains https + audio + video + hardware + ai (cpu) libraries in the final bundle
|`--video-ai-gpu-hw-bundle `|contains https + audio + video + hardware + ai (gpu) libraries in the final bundle
|`--streaming-bundle       `|contains https + audio + video + streaming libraries in the final bundle
|`--full-bundle            `|contains https + audio + video + hardware + ai + streaming + ssh + smb + mq libraries in the final bundle

### Build Options

| Option | Default | Description |
|--------|---------|-------------|
| `--ffmpeg-git-checkout-version=`      | `release/8.0` | Build a particular version of FFmpeg (e.g., n3.1.1 or a specific git hash) |
| `--ffmpeg-git-checkout=`              | `https://github.com/FFmpeg/FFmpeg.git` | Clone FFmpeg from other repositories |
| `--ffmpeg-source-dir=`                | `[empty]` | Specify the directory of ffmpeg source code. When specified, git will not be used |
| `--cflags=`                           | `-mtune=generic -O3 -pipe` | Compiler flags (default works on any CPU) |
| `--git-get-latest=`                   |`y`| Do a git pull for latest code from repositories like FFmpeg |
| `--prefer-stable=`                    |`y`| Build a few libraries from releases instead of git master |
| `--build-only={0..} OR [library_name]`|   | Build only specific dependency (0.. or step/library name from get-all-steps) |
| `--build-from={0..} OR [library_name]`|   | Start building dependencies from given step (0.. or step/library name) |
| `--build-dependencies=[y]`            |`y`| Whether or not to skip building dependencies
| `--build-dependencies-only`           |   | Only build dependency binaries. Will not build app binaries |
| `--build-ffmpeg-only`                 |   | Build ffmpeg binaries only |
| `--build-ffmpeg-kit-only`             |   | Build ffmpeg-kit binaries and bundle only |
| `--enable-static\|--static`           |   | Build static ffmpeg and ffmpeg-kit binaries |
| `--enable-shared\|--shared`           | `default` | Build shared ffmpeg and ffmpeg-kit binaries |
| `--clean-builds`                      |   | Clean ffmpeg and ffmpeg-kit builds based on --enable-static/--enable-shared(default) and exit |
| `--list-libraries`                    |   | Lists ffmpeg configuration including extra libraries and exit |
| `--enable-[library name]`             |   | Enable extra ffmpeg libraries. Run --list-libraries and see under "External library support" |
| `--ff-*`                              |   | Pass additional ffmpeg parameters prefixed by ff-* to ffmpeg configure. No additional checks done |

## Bundle Matrix

|Feature  |Audio   |Video   |Streaming|Audio+AI|Video+AI|Video+AI+Hardware|
|---------|--------|--------|-------- |--------|--------|-----------------|
|Video    ||x|x||x|x|
|Audio    |x|x|x|x|x|x|
|Streaming|||x||||
|AI       ||||x|x|x|
|Hardware ||||||x|
|HTTPS    |x|x|x|x|x|x|

## Supported External Libraries

You can also get the full list of supported external libraries by running `--list-libraries`
| Library            | Description | Platform<sup>[1](https://www.google.com/search?q=%23platform-info)</sup> | Extra<sup>[2](https://www.google.com/search?q=%23extra-info)</sup> | Audio    | Video    | Streaming | Audio+AI | Video+AI | Video+AI+Hardware |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| jni<sup>[8](https://www.google.com/search?q=%23install-info)</sup> | Enables Java Native Interface interactions on Android | Android |  | x | x | x | x | x | x |
| appkit<sup>[8](https://www.google.com/search?q=%23install-info)</sup> | Accesses AppKit for screen and window capture | Apple |  | x | x | x | x | x | x |
| avfoundation<sup>[8](https://www.google.com/search?q=%23install-info)</sup> | Captures input from AVFoundation devices (cameras/mics) | Apple |  | x | x | x | x | x | x |
| pocketsphinx | Performs offline speech-to-text conversion |  |  |  |  |  | x | x | x |
| whisper | Integrates OpenAI Whisper for speech recognition |  |  |  |  |  | x | x | x |
| audiotoolbox<sup>[8](https://www.google.com/search?q=%23install-info)</sup> | Accesses AudioToolbox for native codec support | Apple |  | x | x | x | x | x | x |
| alsa | Accesses ALSA for audio input and output | Linux |  | x | x | x | x | x | x |
| chromaprint | Calculates audio fingerprints for identification |  | x | x | x | x | x | x | x |
| ladspa | Loads LADSPA plugins for audio filtering |  | x | x | x | x | x | x | x |
| libbs2b | Simulates binaural audio via DSP |  |  | x | x | x | x | x | x |
| libcdio | Reads and extracts audio from CDs |  | x | x | x | x | x | x | x |
| libcelt | Decodes CELT audio streams |  |  | x | x | x | x | x | x |
| libcodec2 | Encodes and decodes Codec2 speech format |  |  | x | x | x | x | x | x |
| libfdk-aac | Encodes and decodes high-quality AAC audio |  |  | x | x | x | x | x | x |
| libflite | Synthesizes speech from text (TTS) filter |  | x | x | x | x | x | x | x |
| libgme | Emulates and plays video game music formats |  | x | x | x | x | x | x | x |
| libgsm | Encodes and decodes GSM audio |  |  | x | x | x | x | x | x |
| libilbc | Encodes and decodes iLBC audio |  |  | x | x | x | x | x | x |
| libjack<sup>[8](https://www.google.com/search?q=%23install-info)</sup> | Connects to the JACK audio connection kit |  | x | x | x | x | x | x | x |
| liblc3 | Encodes and decodes LC3 (Bluetooth LE) audio |  |  | x | x | x | x | x | x |
| libmodplug | Decodes module music formats (MOD, etc.) |  |  | x | x | x | x | x | x |
| libmp3lame | Encodes MP3 audio |  |  | x | x | x | x | x | x |
| libmysofa | Reads HRTF files for the sofalizer filter |  | x | x | x | x | x | x | x |
| libopencore-amrnb | Encodes and decodes AMR-NB audio |  |  | x | x | x | x | x | x |
| libopencore-amrwb | Decodes AMR-WB audio |  |  | x | x | x | x | x | x |
| libopenmpt | Decodes tracked music files (OpenMPT based) |  |  | x | x | x | x | x | x |
| libopus | Encodes and decodes Opus audio |  |  | x | x | x | x | x | x |
| libpulse<sup>[8](https://www.google.com/search?q=%23install-info)</sup> | Captures audio via PulseAudio server | Linux | x | x | x | x | x | x | x |
| librubberband | Performs high-quality time stretching/pitch shifting |  | x | x | x | x | x | x | x |
| libshine | Encodes MP3 using fixed-point math |  | x | x | x | x | x | x | x |
| libsoxr | Resamples audio using the SoX library |  |  | x | x | x | x | x | x |
| libspeex | Encodes and decodes Speex audio |  |  | x | x | x | x | x | x |
| libtwolame | Encodes MP2 audio |  |  | x | x | x | x | x | x |
| libvo-amrwbenc | Encodes AMR-WB audio |  |  | x | x | x | x | x | x |
| libvorbis | Encodes and decodes Vorbis audio |  |  | x | x | x | x | x | x |
| lv2 | Loads LV2 plugins for audio filtering |  | x | x | x | x | x | x | x |
| openal | Captures audio via OpenAL 1.1 |  |  | x | x | x | x | x | x |
| sndio | Accesses sndio for audio I/O on OpenBSD |  | x | x | x | x | x | x | x |
| gcrypt | Provides crypto functions for RTMP/RTMPE | [3](https://www.google.com/search?q=%23rtmpte-info) |  |  |  |  |  |  |  |
| gmp | Provides math functions for crypto contexts | [3](https://www.google.com/search?q=%23rtmpte-info) |  |  |  |  |  |  |  |
| bzlib | Compresses and decompresses bzip2 streams |  | x | x | x | x | x | x | x |
| iconv | Converts character encodings for text/subtitles |  | x | x | x | x | x | x | x |
| libxml2 | Parses XML for DASH, IMF, and other formats |  | x | x | x | x | x | x | x |
| lzma | Provides LZMA lossless data compression |  | x | x | x | x | x | x | x |
| zlib | Provides Deflate/zlib lossless data compression |  | x | x | x | x | x | x | x |
| mediacodec<sup>[8](https://www.google.com/search?q=%23install-info)</sup> | Accesses Android MediaCodec hardware acceleration | Android |  |  |  |  |  |  | x |
| coreimage<sup>[8](https://www.google.com/search?q=%23install-info)</sup> | Applies video filters via Apple CoreImage | Apple |  |  |  |  |  |  | x |
| metal<sup>[8](https://www.google.com/search?q=%23install-info)</sup> | Utilizes Apple Metal for GPU acceleration | Apple |  |  |  |  |  |  | x |
| videotoolbox<sup>[8](https://www.google.com/search?q=%23install-info)</sup> | Accesses VideoToolbox for hardware encoding/decoding | Apple |  |  |  |  |  |  | x |
| amf | Accesses AMD Advanced Media Framework (GPU encoding) |  |  |  |  |  |  |  |  |
| cuda-llvm<sup>[8](https://www.google.com/search?q=%23install-info)</sup> | Compiles CUDA kernels at runtime using Clang | Nvidia |  |  |  |  |  |  | x |
| cuda-nvcc<sup>[8](https://www.google.com/search?q=%23install-info)</sup> | Compiles CUDA kernels using NVCC | Nvidia |  |  |  |  |  |  | x |
| cuvid<sup>[8](https://www.google.com/search?q=%23install-info)</sup> | Accesses Nvidia CUVID for decoding (Legacy) | Nvidia |  |  |  |  |  |  | x |
| ffnvcodec | Provides headers for Nvidia codec API integration | Nvidia |  |  |  |  |  |  | x |
| libdrm | Accesses Direct Rendering Manager for Linux GPU buffer | Linux |  |  |  |  |  |  | x |
| libglslang | Compiles GLSL shaders to SPIR-V for Vulkan filters |  |  |  |  |  |  |  |  |
| libmfx | Accesses Intel Quick Sync Video (QSV) via MediaSDK |  |  |  |  |  |  |  |  |
| libnpp<sup>[8](https://www.google.com/search?q=%23install-info)</sup> | Uses Nvidia Performance Primitives for image processing | Nvidia |  |  |  |  |  |  | x |
| libplacebo | Applies high-quality GPU video processing filters |  |  |  |  |  |  |  |  |
| libshaderc | Compiles GLSL shaders to SPIR-V (Google implementation) |  |  |  |  |  |  |  |  |
| libvpl | Accesses Intel oneVPL video processing library |  |  |  |  |  |  |  |  |
| nvdec<sup>[8](https://www.google.com/search?q=%23install-info)</sup> | Accesses Nvidia NVDEC for hardware decoding | Nvidia |  |  |  |  |  |  | x |
| nvenc<sup>[8](https://www.google.com/search?q=%23install-info)</sup> | Accesses Nvidia NVENC for hardware encoding | Nvidia |  |  |  |  |  |  | x |
| opencl | Enables OpenCL-based video filtering |  |  |  |  |  |  |  |  |
| rkmpp | Accesses Rockchip Media Process Platform for HW codecs | Linux |  |  |  |  |  |  | x |
| v4l2-m2m | Accesses V4L2 Memory-to-Memory hardware codecs | Linux |  |  |  |  |  |  | x |
| vaapi | Accesses Video Acceleration API for HW codecs | Linux |  |  |  |  |  |  | x |
| vdpau<sup>[8](https://www.google.com/search?q=%23install-info)</sup> | Accesses VDPAU for hardware decoding on Unix | Nvidia |  |  |  |  |  |  | x |
| vulkan | Enables Vulkan-based filtering and rendering |  |  |  |  |  |  |  |  |
| vulkan-static | Links libvulkan statically |  |  |  |  |  |  |  |  |
| opengl | Enables OpenGL-based rendering and filtering |  |  |  |  |  |  |  |  |
| d3d11va<sup>[8](https://www.google.com/search?q=%23install-info)</sup> | Accesses Direct3D 11 for video acceleration | Windows |  |  |  |  |  |  | x |
| d3d12va<sup>[8](https://www.google.com/search?q=%23install-info)</sup> | Accesses Direct3D 12 for video acceleration | Windows |  |  |  |  |  |  | x |
| dxva2<sup>[8](https://www.google.com/search?q=%23install-info)</sup> | Accesses DirectX 9 for video acceleration | Windows |  |  |  |  |  |  | x |
| mediafoundation<sup>[8](https://www.google.com/search?q=%23install-info)</sup> | Accesses Windows Media Foundation for encoding | Windows |  |  |  |  |  |  | x |
| ohcodec<sup>[8](https://www.google.com/search?q=%23install-info)</sup> | Accesses OpenHarmony multimedia codec capabilities | HarmonyOS |  |  |  |  |  |  | x |
| mmal | Accesses Broadcom MMAL for Raspberry Pi multimedia | Raspberry Pi |  |  |  |  |  |  | x |
| omx | Accesses OpenMAX IL for hardware acceleration | Raspberry Pi |  |  |  |  |  |  | x |
| omx-rpi | Accesses OpenMAX IL implementation for Raspberry Pi | Raspberry Pi |  |  |  |  |  |  | x |
| securetransport<sup>[8](https://www.google.com/search?q=%23install-info)</sup> | Provides TLS/SSL support via Apple Secure Transport | Apple |  | [4](https://www.google.com/search?q=%23https-info) | [4](https://www.google.com/search?q=%23https-info) | [4](https://www.google.com/search?q=%23https-info) | [4](https://www.google.com/search?q=%23https-info) | [4](https://www.google.com/search?q=%23https-info) | [4](https://www.google.com/search?q=%23https-info) |
| gnutls | Provides TLS/SSL support via GnuTLS |  |  | [4](https://www.google.com/search?q=%23https-info) | [4](https://www.google.com/search?q=%23https-info) | [4](https://www.google.com/search?q=%23https-info) | [4](https://www.google.com/search?q=%23https-info) | [4](https://www.google.com/search?q=%23https-info) | [4](https://www.google.com/search?q=%23https-info) |
| libtls | Provides TLS/SSL support via LibreSSL |  |  | [4](https://www.google.com/search?q=%23https-info) | [4](https://www.google.com/search?q=%23https-info) | [4](https://www.google.com/search?q=%23https-info) | [4](https://www.google.com/search?q=%23https-info) | [4](https://www.google.com/search?q=%23https-info) | [4](https://www.google.com/search?q=%23https-info) |
| mbedtls | Provides TLS/SSL support via mbedTLS |  |  | [4](https://www.google.com/search?q=%23https-info) | [4](https://www.google.com/search?q=%23https-info) | [4](https://www.google.com/search?q=%23https-info) | [4](https://www.google.com/search?q=%23https-info) | [4](https://www.google.com/search?q=%23https-info) | [4](https://www.google.com/search?q=%23https-info) |
| openssl | Provides TLS/SSL support via OpenSSL |  |  | [4](https://www.google.com/search?q=%23https-info) | [4](https://www.google.com/search?q=%23https-info) | [4](https://www.google.com/search?q=%23https-info) | [4](https://www.google.com/search?q=%23https-info) | [4](https://www.google.com/search?q=%23https-info) | [4](https://www.google.com/search?q=%23https-info) |
| schannel<sup>[8](https://www.google.com/search?q=%23install-info)</sup> | Provides TLS/SSL support via Windows SChannel | Windows |  | [4](https://www.google.com/search?q=%23https-info) | [4](https://www.google.com/search?q=%23https-info) | [4](https://www.google.com/search?q=%23https-info) | [4](https://www.google.com/search?q=%23https-info) | [4](https://www.google.com/search?q=%23https-info) | [4](https://www.google.com/search?q=%23https-info) |
| librabbitmq | Enables AMQP protocol support (RabbitMQ) |  | [5](https://www.google.com/search?q=%23mq-info) |  |  |  |  |  |  |
| libzmq | Enables ZeroMQ message passing protocol |  | [5](https://www.google.com/search?q=%23mq-info) |  |  |  |  |  |  |
| libsmbclient | Enables SMB/CIFS protocol support |  | [6](https://www.google.com/search?q=%23smb-info) |  |  |  |  |  |  |
| libssh | Enables SFTP protocol support |  | [7](https://www.google.com/search?q=%23ssh-info) |  |  |  |  |  |  |
| librist | Enables Reliable Internet Stream Transport (RIST) |  |  |  |  | x |  |  |  |
| librtmp | Enables RTMP and RTMPE stream support |  |  |  |  | x |  |  |  |
| libsrt | Enables Secure Reliable Transport (SRT) protocol |  |  |  |  | x |  |  |  |
| libopencv | Applies computer vision filters via OpenCV |  |  |  |  |  |  | x | x |
| libopenvino<sup>[8](https://www.google.com/search?q=%23install-info)</sup> | Runs DNN-based filters using Intel OpenVINO backend |  |  |  |  |  |  | x | x |
| libquirc | Decodes QR codes from video streams |  |  |  |  |  |  | x | x |
| libtensorflow<sup>[8](https://www.google.com/search?q=%23install-info)</sup> | Runs DNN-based filters using TensorFlow backend |  |  |  |  |  |  | x | x |
| libtesseract | Performs Optical Character Recognition (OCR) |  |  |  |  |  |  | x | x |
| libtorch<sup>[8](https://www.google.com/search?q=%23install-info)</sup> | Runs DNN-based filters using PyTorch backend |  |  |  |  |  |  | x | x |
| sdl2 | Outputs audio/video to window using SDL2 |  |  |  | x | x |  | x | x |
| avisynth | Reads and demuxes AviSynth script files |  | x |  | x | x |  | x | x |
| decklink | Captures/Outputs via Blackmagic DeckLink devices |  | x |  | x | x |  | x | x |
| frei0r | Loads Frei0r plugins for video filtering |  | x |  | x | x |  | x | x |
| lcms2 | Applies ICC color profiles using LittleCMS 2 |  |  |  | x | x |  | x | x |
| libaom | Encodes and decodes AV1 video |  |  |  | x | x |  | x | x |
| libaribb24 | Decodes ARIB STD-B24 captions |  |  |  | x | x |  | x | x |
| libaribcaption | Decodes ARIB captions (alternative library) |  |  |  | x | x |  | x | x |
| libass | Renders ASS/SSA subtitles |  |  |  | x | x |  | x | x |
| libbluray | Reads Blu-ray playlists and protocols |  |  |  | x | x |  | x | x |
| libcaca | Renders video as ASCII characters |  |  |  | x | x |  | x | x |
| libdav1d | Decodes AV1 video (high performance) |  |  |  | x | x |  | x | x |
| libdavs2 | Decodes AVS2 video |  |  |  | x | x |  | x | x |
| libdc1394 | Captures video from FireWire cameras |  |  |  | x | x |  | x | x |
| libdvdnav | Navigates and demuxes DVD menus/content |  |  |  | x | x |  | x | x |
| libdvdread | Reads DVD filesystem structures |  |  |  | x | x |  | x | x |
| libfontconfig | Configures and locates fonts for text rendering |  |  |  | x | x |  | x | x |
| libfreetype | Renders fonts for text overlays |  |  |  | x | x |  | x | x |
| libfribidi | Handles bi-directional text logic |  |  |  | x | x |  | x | x |
| libharfbuzz | Shapes complex text for subtitles |  |  |  | x | x |  | x | x |
| libiec61883 | Captures DV/HDV via FireWire | Linux |  |  | x | x |  | x | x |
| libjxl | Encodes and decodes JPEG XL images |  |  |  | x | x |  | x | x |
| libklvanc | Processes Vertical Ancillary Data (VANC) |  | x |  | x | x |  | x | x |
| libkvazaar | Encodes HEVC video |  |  |  | x | x |  | x | x |
| liblcevc-dec | Decodes LCEVC video enhancement layers |  |  |  | x | x |  | x | x |
| liblensfun | Corrects lens distortion using Lensfun |  | x |  | x | x |  | x | x |
| liboapv | Encodes OAPV (Open Advanced Photos/Video) |  |  |  | x | x |  | x | x |
| libopenh264 | Encodes H.264 video (Cisco implementation) |  |  |  | x | x |  | x | x |
| libopenjpeg | Encodes and decodes JPEG 2000 images |  |  |  | x | x |  | x | x |
| libqrencode | Generates QR codes as video sources |  | x |  | x | x |  | x | x |
| librav1e | Encodes AV1 video (Rust implementation) |  |  |  | x | x |  | x | x |
| librsvg | Renders SVG files for overlays |  |  |  | x | x |  | x | x |
| libsnappy | Compresses data for the Hap codec |  |  |  | x | x |  | x | x |
| libsvtav1 | Encodes AV1 video (SVT implementation) |  |  |  | x | x |  | x | x |
| libtheora | Encodes Theora video |  |  |  | x | x |  | x | x |
| libuavs3d | Decodes AVS3 video |  |  |  | x | x |  | x | x |
| libv4l2 | Accesses V4L2 devices and utilities | Linux | x |  | x | x |  | x | x |
| libvidstab | Stabilizes video using motion analysis |  | x |  | x | x |  | x | x |
| libvmaf | Calculates VMAF video quality scores |  | x |  | x | x |  | x | x |
| libvpx | Encodes and decodes VP8 and VP9 video |  |  |  | x | x |  | x | x |
| libvvenc | Encodes H.266/VVC video |  |  |  | x | x |  | x | x |
| libwebp | Encodes WebP images |  |  |  | x | x |  | x | x |
| libx264 | Encodes H.264/AVC video |  |  |  | x | x |  | x | x |
| libx265 | Encodes HEVC/H.265 video |  |  |  | x | x |  | x | x |
| libxavs | Encodes AVS video |  |  |  | x | x |  | x | x |
| libxavs2 | Encodes AVS2 video |  |  |  | x | x |  | x | x |
| libxcb | Captures screen content via XCB | Linux | x |  | x | x |  | x | x |
| libxcb-shape | Handles X11 shapes during capture | Linux | x |  | x | x |  | x | x |
| libxcb-shm | Uses shared memory for X11 capture | Linux | x |  | x | x |  | x | x |
| libxcb-xfixes | Fixes cursor rendering in X11 capture | Linux | x |  | x | x |  | x | x |
| libxevd | Decodes EVC video |  |  |  | x | x |  | x | x |
| libxeve | Encodes EVC video |  |  |  | x | x |  | x | x |
| libxvid | Encodes MPEG-4 video (Xvid) |  |  |  | x | x |  | x | x |
| libzimg | Performs scaling and color conversion (zscale) |  |  |  | x | x |  | x | x |
| libzvbi | Decodes VBI teletext data |  |  |  | x | x |  | x | x |
| vapoursynth | Demuxes VapourSynth script frames |  | x |  | x | x |  | x | x |
| xlib | Captures screen content via Xlib | Linux | x |  | x | x |  | x | x |

<sup>1</sup> Platform specific libraries are enabled by default for target platform and bundle.<a id="platform-info"></a>

<sup>2</sup> Extra libraries are enabled on non-small bundles.<a id="extra-info"></a>

<sup>3</sup> RTMP(T)E support requires either gcrypt or gmp if the requires SSL library is not selected in the bundle.<a id="rtmpte-info"></a>

<sup>4</sup> HTTPS feature in FFmpeg supports multiple SSL libraries. By default OpenSSL is selected unless you build a custom bundle with a specific supported library.<a id="https-info"></a>

<sup>5</sup> MQ libraries are not enabled by default in any bundle. A custom build must be deployed to enable them using `--enable-mq` OR `--enable-librabbitmq` and `--enable-libzmq`.<a id="mq-info"></a>

<sup>6</sup> SAMBA (SMB protocol) library is not enabled by default in any bundle (except on Windows, which supports SMB by default). A custom build must be deployed to enable them using `--enable-smb` OR `--enable-libsmbclient`.<a id="smb-info"></a>

<sup>7</sup> SSH library is not enabled by default in any bundle. A custom build must be deployed to enable them using `--enable-ssh` OR `--enable-libssh`.<a id="ssh-info"></a>

<sup>8</sup> These libraries cannot be built statically. If you deploy a static build with these libraries they will not be bundled with FFmpegKit wrapper bundle. The target system will need these libraries installed or running the wrapper may crash immediately. <a id="install-info"></a>

## Troubleshooting

1.  **WSL Issues**:
    *   If using WSL, **WSL 2** is strongly recommended for build performance.
    *   If cross-compiling, you may need to disable binfmt interop:
        ```bash
        sudo bash -c 'echo 0 > /proc/sys/fs/binfmt_misc/WSLInterop'
        ```
2.  **Insufficient Memory**:
    *   Linking static `libtensorflow` or `libtorch` requires significant RAM. If the build crashes during the final link step, increase swap space or allocated RAM to at least 8GB.
3.  **Missing "Configure"**:
    *   If a library fails because it cannot find `./configure`, ensure `autoconf`, `automake`, and `libtool` are installed. The script attempts to generate them via `autoreconf -fiv` if missing.

## License

The build scripts in this repository are licensed under the MIT License or Apache 2.0 (refer to `LICENSE` file). 

**Important**: The **binaries** you build will be subject to the licenses of the enabled libraries. 
*   Enabling `--enable-gpl` makes the resulting FFmpeg binary **GPLv3**.
*   Enabling `--enable-nonfree` makes the resulting binary **unredistributable** in many jurisdictions.
*   Check the `prebuilt/.../licenses` folder in your output bundle for details on dependencies used.## Troubleshooting

1.  **WSL Issues**:
    *   If using WSL, **WSL 2** is strongly recommended for build performance.
    *   If cross-compiling, you may need to disable binfmt interop:
        ```bash
        sudo bash -c 'echo 0 > /proc/sys/fs/binfmt_misc/WSLInterop'
        ```
2.  **Insufficient Memory**:
    *   Linking static `libtensorflow` or `libtorch` requires significant RAM. If the build crashes during the final link step, increase swap space or allocated RAM to at least 8GB.
3.  **Missing "Configure"**:
    *   If a library fails because it cannot find `./configure`, ensure `autoconf`, `automake`, and `libtool` are installed. The script attempts to generate them via `autoreconf -fiv` if missing.

## License

The build scripts in this repository are licensed under the MIT License or Apache 2.0 (refer to `LICENSE` file). 

**Important**: The **binaries** you build will be subject to the licenses of the enabled libraries. 
*   Enabling `--enable-gpl` makes the resulting FFmpeg binary **GPLv3**.
*   Enabling `--enable-nonfree` makes the resulting binary **unredistributable** in many jurisdictions.
*   Check the `prebuilt/.../licenses` folder in your output bundle for details on dependencies used.