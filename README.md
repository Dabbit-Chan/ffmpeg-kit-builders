
# FFmpeg-Kit Builders

Cross-platform build system for FFmpeg and FFmpegKit supporting Linux and Windows platforms.

## Overview

This repository provides a comprehensive build system for FFmpeg and FFmpegKit that supports multiple platforms and architectures. The system handles the complete build pipeline from toolchain installation through dependency compilation to final bundle creation, with support for both native Linux builds and cross-compilation to Windows from Linux hosts.

## Platform Support

- **Linux**: Native builds for x86_64 and i686 architecture with shared libraries (.so) and static libraries (.a).
- **Windows**: Cross-compilation from Linux hosts using MinGW-w64 toolchain with shared libraries (.dll) and static mingw libraries (.a). 
  - *Note: MSVC ABI is not supported.*

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

|Library           |Description |Platform<sup>[1](#platform-info)</sup>|Extra<sup>[2](#extra-info)</sup>|Audio   |Video   |Streaming|Audio+AI|Video+AI|Video+AI+Hardware|
|------------------|------------|------------------------|-----|--------|--------|-------- |--------|--------|-----------------|
jni<sup>[8](#install-info)</sup>|JNI support|Android||x|x|x|x|x|x
appkit<sup>[8](#install-info)</sup>|Apple AppKit framework|Apple||x|x|x|x|x|x
avfoundation<sup>[8](#install-info)</sup>|Apple AVFoundation framework|Apple||x|x|x|x|x|x
pocketsphinx|PocketSphinx, needed for asr filter||||||x|x|x
whisper|whisper filter||||||x|x|x
audiotoolbox<sup>[8](#install-info)</sup>|Apple AudioToolbox code|Apple||x|x|x|x|x|x
alsa|ALSA support|Linux||x|x|x|x|x|x
chromaprint|audio fingerprinting with chromaprint||x|x|x|x|x|x|x
ladspa|LADSPA audio filtering||x|x|x|x|x|x|x
libbs2b|bs2b DSP library|||x|x|x|x|x|x
libcdio|audio CD grabbing with libcdio||x|x|x|x|x|x|x
libcelt|CELT decoding via libcelt|||x|x|x|x|x|x
libcodec2|codec2 en/decoding using libcodec2|||x|x|x|x|x|x
libfdk-aac|AAC de/encoding via libfdk-aac|||x|x|x|x|x|x
libflite|flite (voice synthesis) support via libflite||x|x|x|x|x|x|x
libgme|Game Music Emu via libgme||x|x|x|x|x|x|x
libgsm|GSM de/encoding via libgsm|||x|x|x|x|x|x
libilbc|iLBC de/encoding via libilbc|||x|x|x|x|x|x
libjack<sup>[8](#install-info)</sup>|JACK audio sound server||x|x|x|x|x|x|x
liblc3|LC3 de/encoding via liblc3|||x|x|x|x|x|x
libmodplug|ModPlug via libmodplug|||x|x|x|x|x|x
libmp3lame|MP3 encoding via libmp3lame|||x|x|x|x|x|x
libmysofa|libmysofa, needed for sofalizer filter||x|x|x|x|x|x|x
libopencore-amrnb|AMR-NB de/encoding via libopencore-amrnb|||x|x|x|x|x|x
libopencore-amrwb|AMR-WB decoding via libopencore-amrwb|||x|x|x|x|x|x
libopenmpt|decoding tracked files via libopenmpt|||x|x|x|x|x|x
libopus|Opus de/encoding via libopus|||x|x|x|x|x|x
libpulse<sup>[8](#install-info)</sup>|Pulseaudio input via libpulse|Linux|x|x|x|x|x|x|x
librubberband|rubberband needed for rubberband filter||x|x|x|x|x|x|x
libshine|fixed-point MP3 encoding via libshine||x|x|x|x|x|x|x
libsoxr|Include libsoxr resampling|||x|x|x|x|x|x
libspeex|Speex de/encoding via libspeex|||x|x|x|x|x|x
libtwolame|MP2 encoding via libtwolame|||x|x|x|x|x|x
libvo-amrwbenc|AMR-WB encoding via libvo-amrwbenc|||x|x|x|x|x|x
libvorbis|Vorbis en/decoding via libvorbis, native implementation exists|||x|x|x|x|x|x
lv2|LV2 audio filtering||x|x|x|x|x|x|x
openal|OpenAL 1.1 capture support|||x|x|x|x|x|x
sndio|software layer of the OpenBSD operating system that manages sound cards and MIDI ports||x|x|x|x|x|x|x
gcrypt|gcrypt, needed for rtmp(t)e support if openssl, librtmp or gmp is not used|[3](#rtmpte-info)
gmp|gmp, needed for rtmp(t)e support if openssl or librtmp is not used|[3](#rtmpte-info)
bzlib|For compressing and decompressing streams of data||x|x|x|x|x|x|x
iconv|Convert a string from one character encoding to another||x|x|x|x|x|x|x
libxml2|XML parsing using the C library libxml2, needed for dash and imf demuxing support||x|x|x|x|x|x|x
lzma|Lossless data compression algorithm||x|x|x|x|x|x|x
zlib|General-purpose lossless data-compression library||x|x|x|x|x|x|x
mediacodec<sup>[8](#install-info)</sup>|Android MediaCodec support|Android|||||||x
coreimage<sup>[8](#install-info)</sup>|Apple CoreImage framework|Apple|||||||x
metal<sup>[8](#install-info)</sup>|Apple Metal framework|Apple|||||||x
videotoolbox<sup>[8](#install-info)</sup>|VideoToolbox code|Apple|||||||x
amf|AMF video encoding code||||||||x
cuda-llvm<sup>[8](#install-info)</sup>|CUDA compilation using clang|Nvidia|||||||x
cuda-nvcc<sup>[8](#install-info)</sup>|Nvidia CUDA compiler|Nvidia|||||||x
cuvid<sup>[8](#install-info)</sup>|Nvidia CUVID support|Nvidia|||||||x
ffnvcodec|dynamically linked Nvidia code|Nvidia|||||||x
libdrm|DRM code (Linux)|Linux|||||||x
libglslang|GLSL->SPIRV compilation via libglslang||||||||x
libmfx|Intel MediaSDK (AKA Quick Sync Video) code via libmfx||||||||x
libnpp<sup>[8](#install-info)</sup>|Nvidia Performance Primitives-based code|Nvidia|||||||x
libplacebo|libplacebo library||||||||x
libshaderc|GLSL->SPIRV compilation via libshaderc||||||||x
libvpl|Intel oneVPL code via libvpl if libmfx is not used||||||||x
nvdec<sup>[8](#install-info)</sup>|Nvidia video decoding acceleration (via hwaccel)|Nvidia|||||||x
nvenc<sup>[8](#install-info)</sup>|Nvidia video encoding code|Nvidia|||||||x
opencl|OpenCL processing||||||||x
rkmpp|Rockchip Media Process Platform code|Linux|||||||x
v4l2-m2m|V4L2 mem2mem code|Linux|||||||x
vaapi|Video Acceleration API (mainly Unix/Intel) code|Linux|||||||x
vdpau<sup>[8](#install-info)</sup>|Nvidia Video Decode and Presentation API for Unix code|Nvidia|||||||x
vulkan|Vulkan code||||||||x
vulkan-static|statically link to libvulkan||||||||x
opengl|OpenGL rendering||||||||x
d3d11va<sup>[8](#install-info)</sup>|Microsoft Direct3D 11 video acceleration code|Windows|||||||x
d3d12va<sup>[8](#install-info)</sup>|Microsoft Direct3D 12 video acceleration code|Windows|||||||x
dxva2<sup>[8](#install-info)</sup>|Microsoft DirectX 9 video acceleration code|Windows|||||||x
mediafoundation<sup>[8](#install-info)</sup>|encoding via MediaFoundation|Windows|||||||x
ohcodec<sup>[8](#install-info)</sup>|OpenHarmony Codec support|HarmonyOS|||||||x
mmal|Broadcom Multi-Media Abstraction Layer (Raspberry Pi) via MMAL|Raspberry Pi|||||||x
omx|OpenMAX IL code|Raspberry Pi|||||||x
omx-rpi|OpenMAX IL code for Raspberry Pi|Raspberry Pi|||||||x
securetransport<sup>[8](#install-info)</sup>|Secure Transport, needed for TLS support on OSX if openssl and gnutls are not used|Apple||[4](#https-info)|[4](#https-info)|[4](#https-info)|[4](#https-info)|[4](#https-info)|[4](#https-info)|[4](#https-info)|
gnutls|gnutls, needed for https support if openssl, libtls or mbedtls is not used|||[4](#https-info)|[4](#https-info)|[4](#https-info)|[4](#https-info)|[4](#https-info)|[4](#https-info)|[4](#https-info)|
libtls|LibreSSL (via libtls), needed for https support if openssl, gnutls or mbedtls is not used|||[4](#https-info)|[4](#https-info)|[4](#https-info)|[4](#https-info)|[4](#https-info)|[4](#https-info)|[4](#https-info)|
mbedtls|mbedTLS, needed for https support if openssl, gnutls or libtls is not used|||[4](#https-info)|[4](#https-info)|[4](#https-info)|[4](#https-info)|[4](#https-info)|[4](#https-info)|[4](#https-info)|
openssl|openssl, needed for https support if gnutls, libtls or mbedtls is not used|||[4](#https-info)|[4](#https-info)|[4](#https-info)|[4](#https-info)|[4](#https-info)|[4](#https-info)|[4](#https-info)|
schannel<sup>[8](#install-info)</sup>|SChannel SSP, needed for TLS support on Windows if openssl and gnutls are not used|Windows||[4](#https-info)|[4](#https-info)|[4](#https-info)|[4](#https-info)|[4](#https-info)|[4](#https-info)|[4](#https-info)|
librabbitmq|RabbitMQ library||[5](#mq-info)
libzmq|message passing via libzmq||[5](#mq-info)
libsmbclient|Samba protocol via libsmbclient||[6](#smb-info)
libssh|SFTP protocol via libssh||[7](#ssh-info)
librist|RIST via librist|||||x
librtmp|RTMP[E] support via librtmp|||||x
libsrt|Haivision SRT protocol via libsrt|||||x
libopencv|video filtering via libopencv|||||||x|x
libopenvino<sup>[8](#install-info)</sup>|OpenVINO as a DNN module backend for DNN based filters like dnn_processing|||||||x|x
libquirc|QR decoding via libquirc|||||||x|x
libtensorflow<sup>[8](#install-info)</sup>|TensorFlow as a DNN module backend for DNN based filters like sr|||||||x|x
libtesseract|Tesseract, needed for ocr filter|||||||x|x
libtorch<sup>[8](#install-info)</sup>|Torch as one DNN backend|||||||x|x
sdl2|sdl2||||x|x||x|x
avisynth|reading of AviSynth script files||x||x|x||x|x
decklink|Blackmagic DeckLink I/O support||x||x|x||x|x
frei0r|frei0r video filtering||x||x|x||x|x
lcms2|ICC profile support via LittleCMS 2||||x|x||x|x
libaom|AV1 video encoding/decoding via libaom||||x|x||x|x
libaribb24|ARIB text and caption decoding via libaribb24||||x|x||x|x
libaribcaption|ARIB text and caption decoding via libaribcaption||||x|x||x|x
libass|libass subtitles rendering, needed for subtitles and ass filter||||x|x||x|x
libbluray|BluRay reading using libbluray||||x|x||x|x
libcaca|textual display using libcaca||||x|x||x|x
libdav1d|AV1 decoding via libdav1d||||x|x||x|x
libdavs2|AVS2 decoding via libdavs2||||x|x||x|x
libdc1394|IIDC-1394 grabbing using libdc1394 and libraw1394||||x|x||x|x
libdvdnav|libdvdnav, needed for DVD demuxing||||x|x||x|x
libdvdread|libdvdread, needed for DVD demuxing||||x|x||x|x
libfontconfig|libfontconfig, useful for drawtext filter||||x|x||x|x
libfreetype|libfreetype, needed for drawtext filter||||x|x||x|x
libfribidi|libfribidi, improves drawtext filter||||x|x||x|x
libharfbuzz|libharfbuzz, needed for drawtext filter||||x|x||x|x
libiec61883|iec61883 via libiec61883|Linux|||x|x||x|x
libjxl|JPEG XL de/encoding via libjxl||||x|x||x|x
libklvanc|Kernel Labs VANC processing||x||x|x||x|x
libkvazaar|HEVC encoding via libkvazaar||||x|x||x|x
liblcevc-dec|LCEVC decoding via liblcevc-dec||||x|x||x|x
liblensfun|lensfun lens correction||x||x|x||x|x
liboapv|APV encoding via liboapv||||x|x||x|x
libopenh264|H.264 encoding via OpenH264||||x|x||x|x
libopenjpeg|JPEG 2000 encoding via OpenJPEG||||x|x||x|x
libqrencode|QR encode generation via libqrencode||x||x|x||x|x
librav1e|AV1 encoding via rav1e||||x|x||x|x
librsvg|SVG rasterization via librsvg||||x|x||x|x
libsnappy|Snappy compression, needed for hap encoding||||x|x||x|x
libsvtav1|AV1 encoding via SVT||||x|x||x|x
libtheora|Theora encoding via libtheora||||x|x||x|x
libuavs3d|AVS3 decoding via libuavs3d||||x|x||x|x
libv4l2|libv4l2/v4l-utils|Linux|x||x|x||x|x
libvidstab|video stabilization using vid.stab||x||x|x||x|x
libvmaf|vmaf filter via libvmaf||x||x|x||x|x
libvpx|VP8 and VP9 de/encoding via libvpx||||x|x||x|x
libvvenc|H.266/VVC encoding via vvenc||||x|x||x|x
libwebp|WebP encoding via libwebp||||x|x||x|x
libx264|H.264 encoding via x264||||x|x||x|x
libx265|HEVC encoding via x265||||x|x||x|x
libxavs|AVS encoding via xavs||||x|x||x|x
libxavs2|AVS2 encoding via xavs2||||x|x||x|x
libxcb|X11 grabbing using XCB|Linux|x||x|x||x|x
libxcb-shape|X11 grabbing shape rendering|Linux|x||x|x||x|x
libxcb-shm|X11 grabbing shm communication|Linux|x||x|x||x|x
libxcb-xfixes|X11 grabbing mouse rendering|Linux|x||x|x||x|x
libxevd|EVC decoding via libxevd||||x|x||x|x
libxeve|EVC encoding via libxeve||||x|x||x|x
libxvid|Xvid encoding via xvidcore, native MPEG-4/Xvid encoder exists||||x|x||x|x
libzimg|z.lib, needed for zscale filter||||x|x||x|x
libzvbi|teletext support via libzvbi||||x|x||x|x
vapoursynth|VapourSynth demuxer||x||x|x||x|x
xlib|X Window System protocol client library written in the C programming language|Linux|x||x|x||x|x

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