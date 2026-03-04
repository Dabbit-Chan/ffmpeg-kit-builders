# FFmpegKit Desktop Build System

The desktop build system is designed to compile FFmpeg and FFmpegKit for Linux and Windows, handling patches, dependencies, and shared library bundling.

## Overview

The desktop build process is a sub-phase of the overall [FFmpegKit Builders build system](../../README.md). While the top-level `runner.sh` orchestrates the entire pipeline, the `desktop/` directory contains the logic for building the C++/C wrapper libraries and programs for desktop environments.

## Core Components

### 1. CMakeLists.txt
The [CMakeLists.txt](../CMakeLists.txt) is the heart of the desktop build. It performs the following tasks:
- **Source Preparation**: Copies required `fftools` source files from the FFmpeg source tree.
- **Auto-Patching**: Automatically applies all `.patch` files found in the `patches/` directory.
- **Dependency Detection**: Uses `pkg-config` to find and link against the external libraries built by the main system.
- **Shared Library Bundling**: Triggers post-build scripts to identify and bundle runtime dependencies (DLLs for Windows, SOs for Linux).

### 2. Patch Management
Following the [Development Workflow](../ARCHITECTURE.md#development-workflow), patches are the source of truth for all modifications to the original FFmpeg tools.
- Patches are stored in `desktop/patches/`.
- They are applied by CMake during the configuration phase.
- **Tip**: Always generate patches against the `_orig` baseline.

### 3. Bundling Scripts
- **Linux (`scripts/shared-library.sh`)**: Analyzes the generated shared library, identifies non-system dependencies, and creates a `bundle_manifest.txt`.
- **Windows (`scripts/static-library.sh`)**: Handles the merging of static archives when building static versions.

## Build Flow Integration

When you run `runner.sh --host=linux --arch=x86_64`, the system:
1. Installs the toolchain.
2. Builds 100+ dependency libraries.
3. Configures and builds FFmpeg.
4. **Invokes CMake on `desktop/`** to build `libffmpegkit` and the bundled artifacts.
5. Bundles everything into the `prebuilt/` directory.

## Customizing the Build

To add or remove external libraries:
- Use the feature flags in `runner.sh` (e.g., `--enable-fontconfig`).
- The `CMakeLists.txt` will automatically pick up enabled libraries via `pkg-config` if they are included in the `FFMPEG` module detection logic.
