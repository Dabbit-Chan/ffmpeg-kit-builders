# FFmpegKit Build System

The FFmpegKit build system compiles FFmpeg and the FFmpegKit C/C++ wrapper for Linux, Windows, and Android, handling patches, dependencies, and shared library bundling.

## Overview

The build process is orchestrated by the top-level [`runner.sh`](../../runner.sh). The `FFmpegKit/` directory contains the CMake-based wrapper library and supporting scripts for all target platforms.

## Core Components

### 1. CMakeLists.txt
The [`CMakeLists.txt`](../CMakeLists.txt) is the heart of the build. It performs the following tasks:
- **Source Preparation**: Copies required `fftools` source files from the FFmpeg source tree.
- **Auto-Patching**: Automatically applies all `.patch` files found in the `patches/` directory.
- **Dependency Detection**: Uses `pkg-config` to find and link against the external libraries built by the main system.
- **Shared Library Bundling**: Triggers post-build scripts to identify and bundle runtime dependencies (DLLs for Windows, SOs for Linux).
- **Android (NDK)**: When cross-compiling for Android, builds SDL2 via CMake using the NDK toolchain and links the JNI glue layer (`ffmpeg_kit_android.c`).

### 2. Patch Management
Following the [Development Workflow](../DEVELOPMENT.md), patches are the source of truth for all modifications to the original FFmpeg tools.
- Patches are stored in `FFmpegKit/patches/`.
- They are applied by CMake during the configuration phase.
- **Tip**: Always generate patches against the `_orig` baseline using `scripts/generate_patch.sh`.

### 3. Bundling Scripts
- **Linux (`scripts/shared-library.sh`)**: Analyzes the generated shared library, identifies non-system dependencies, and creates a `bundle_manifest.txt`.
- **Windows (`scripts/static-library.sh`)**: Handles the merging of static archives when building static versions.

## Build Flow Integration

When you run `runner.sh --host=linux --arch=x86_64`, the system:
1. Installs the toolchain.
2. Builds 100+ dependency libraries.
3. Configures and builds FFmpeg.
4. **Invokes CMake on `FFmpegKit/`** to build `libffmpegkit` and the bundled artifacts.
5. Bundles everything into the `prebuilt/` directory.

For Android (`--host=android`), CMake additionally builds SDL2 via the NDK toolchain and compiles the JNI surface/audio glue before packaging into an AAR.

## Customizing the Build

To add or remove external libraries:
- Use the feature flags in `runner.sh` (e.g., `--enable-fontconfig`).
- The `CMakeLists.txt` will automatically pick up enabled libraries via `pkg-config` if they are included in the `FFMPEG` module detection logic.
