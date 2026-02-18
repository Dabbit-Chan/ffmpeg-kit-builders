# FFmpeg Kit Builders Architecture

## Overview
FFmpeg Kit Builders is a comprehensive build system designed to produce cross-platform binaries of FFmpeg and the FFmpegKit C++ wrapper. It supports multiple host platforms (Linux, Windows via MinGW/WSL, Android, etc.) and provides a highly configurable pipeline for including various external libraries and feature presets.

## Build Architecture

### Core Toolchain
The build system utilizes a bash-based orchestration layer that manages dependency resolution, source retrieval, and compilation.
- **Orchestrator**: `runner.sh` is the primary entry point, handling global configuration and platform-specific dispatch.
- **Build Engine**: CMake (`desktop/CMakeLists.txt`) is used for the final assembly of the `ffmpeg-kit` wrapper library.
- **Cross-Compilation**: Supports MinGW-w64 for Windows targets and various toolchains for other platforms.

### Build Sequence
1.  **Argument Parsing**: `runner.sh` parses CLI flags to determine feature sets (Presets like `full`, `audio`, `video`, etc.) and target platform/architecture.
2.  **Environment Setup**: `scripts/variable.sh` defines default compiler flags (`CFLAGS`, `CXXFLAGS`), library versions, and configuration presets.
3.  **Dependency Build**: `scripts/deps-<platform>.sh` downloads and builds external C/C++ libraries (e.g., x264, OpenSSL) statically.
4.  **FFmpeg Build**: `scripts/run-<platform>.sh` clones the specified FFmpeg version and compiles it, linking the previously built static dependencies.
5.  **Wrapper Assembly**:
    - The `desktop/CMakeLists.txt` copies `fftools` from the FFmpeg source.
    - Applies custom patches from `desktop/patches/`.
    - Compiles the `ffmpegkit` wrapper sources (`desktop/src/`).
    - Links against the built FFmpeg libraries and external dependencies (jsoncpp, sdl2).
    - Produces shared (`.dll`/`.so`) or static (`.lib`/`.a`) artifacts.

## Key Dependencies
Notable external libraries being linked include:
- **Core**: FFmpeg (libavcodec, libavformat, libavfilter, libavdevice, libswscale, libswresample, libavutil).
- **Communication/Security**: OpenSSL, GnuTLS, libssh, libsmbclient.
- **Codecs**: x264, x265, libvpx, libopus, libaom, libdav1d, libfdk-aac (non-free).
- **Processing**: libplacebo, libzimg, libass, OpenCV.
- **Support**: libjsoncpp (for metadata parsing), SDL2 (for FFplay support).

## Environment Variables
Crucial variables for the build environment:
- `BASEDIR`: Root of the repository.
- `WORKDIR` (`prebuilt/`): Sandbox for intermediate build objects and final artifacts.
- `SCRIPTDIR`: Path to the bash logic (`scripts/`).
- `FFMPEG_SRC_DIR`: Path to the cloned FFmpeg source tree.
- `FFMPEG_BUILD_DIR`: Path to the compiled FFmpeg libraries and headers.
- `CFLAGS` / `CXXFLAGS`: Global compiler optimization and security flags.

## Component Map

| Directory | Description |
| :--- | :--- |
| `scripts/` | Core build pipeline logic, platform-specific functions, and dependency build steps. |
| `desktop/src/` | FFmpegKit C++ wrapper source code and modified FFmpeg tool sources (`ffmpeg.c`, `ffplay.c`, etc.). |
| `desktop/patches/` | Upstream FFmpeg patches applied during the build process to enable wrapper features. |
| `prebuilt/` | Default location for downloaded sources and compiled binaries (Excluded from source control). |
| `tools/` | Utility scripts and binaries required for the build process (e.g., specific toolchain helpers). |

## Implementation Notes
- **FFI Bindings**: The wrapper implementation in `ffmpegkit_wrapper.h` uses `extern "C"` with explicit export visibility, serving as the high-level FFI entry point for Dart/Flutter or other high-level languages.
- **Static vs. Shared**: While dependencies are typically built statically to minimize runtime issues, the final `ffmpeg-kit` library can be produced as a shared object to be bundled with applications.
- **Custom Patches**: Any modifications to original FFmpeg tool behavior (like progress reporting or cancellation) are maintained as `.patch` files and applied dynamically.
