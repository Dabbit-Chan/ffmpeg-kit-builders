# FFmpeg-Kit Builders

Cross-platform build system for FFmpeg and FFmpegKit supporting Linux and Windows platforms.

## Overview

This repository provides a comprehensive build system for FFmpeg and FFmpegKit that supports multiple platforms and architectures. The system handles the complete build pipeline from toolchain installation through dependency compilation to final bundle creation, with support for both native Linux builds and cross-compilation to Windows from Linux hosts.

## Platform Support

- **Linux**: Native builds for x86_64 and i686 architecture with shared libraries (.so) and static libraries (.a)
- **Windows**: Cross-compilation from Linux hosts using MinGW-w64 toolchain with shared libraries (.dll) and static mingw libraries (.a). Note that MSVC ABI is not supported.

## Quick Start

### Prerequisites

- Linux host or WSL (Ubuntu/Debian recommended)
- Minimum 600MB RAM, 2GB+ recommended for parallel builds
- 285GB available disk space for full build with all dependencies 
- Basic build tools: git, make, cmake, ninja, meson, pkg-config

### Using the Unified Entry Point

The `runner.sh` script is the unified entry point for all builds. It can be used interactively or with explicit command-line options.

```bash
# Interactive mode - prompts for platform and architecture
./runner.sh

# Non-interactive mode with explicit options
./runner.sh --host-platform=linux --host-arch=x86_64 --enable-gpl=y

# Build for Windows 64-bit with shared libraries
./runner.sh --host-platform=windows --host-arch=x86_64 --enable-shared

# Build static libraries for Linux
./runner.sh --host-platform=linux --host-arch=x86_64 --enable-static
```

### Common Build Scenarios

#### Linux Native Builds
```bash
# Build for Linux with additional libraries
./runner.sh --host-platform=linux --host-arch=x86_64 --enable-fontconfig --enable-gpl

# Build static libraries only
./runner.sh --host-platform=linux --host-arch=x86_64 --enable-static

# Build with debug information
./runner.sh --host-platform=linux --host-arch=x86_64 --debug
```

#### Windows Cross-Compilation Builds
```bash
# Build for Windows 64-bit with shared libraries and force rebuild of dependencies
./runner.sh --host-platform=windows --host-arch=x86_64 --enable-shared -f

# Build only 64-bit static libraries
./runner.sh --host-platform=windows --host-arch=x86_64 --enable-static

# Build only 64-bit static libraries with chromaprint support
./runner.sh --host-platform=windows --host-arch=x86_64 --enable-static --enable-chromaprint

# Build with GPL libraries
./runner.sh --host-platform=windows --host-arch=x86_64 --enable-gpl=y
```

## Architecture

This repository implements a three-tier build architecture with platform abstraction.

The architecture consists of:
1. **Unified Entry Point** - `runner.sh` script that handles platform selection and argument parsing 
2. **Build Orchestration** - `scripts/main-linux.sh`, `scripts/main-windows.sh` that coordinate build phases
3. **Execution Primitives** - `scripts/function.sh` and platform-specific extensions that implement common build functions
4. **Build Execution** - `scripts/run-linux.sh`, `scripts/run-windows.sh` that executes individual library builders

## Repository Structure

- `README.md` - This overview document
- `runner.sh` - Unified build entry point for all platforms
- `scripts/` - Shared build orchestration and functions
  - `main-linux.sh`, `main-windows.sh` - Platform orchestrators
  - `function.sh` - Cross-platform build primitives
  - `function-linux.sh`, `function-windows.sh` - Platform-specific extensions
  - `variable.sh` - Build configuration and targets
  - `run-linux.sh`, `run-windows.sh` - Individual library builders

## Build Phases

The build system implements a six-phase build pipeline:

| Phase | Function | Purpose |
|-------|----------|---------|
| 1 | `setup_build_environment` | Initialize paths, environment variables, architecture settings |
| 2 | `install_cross_compiler` | Build or verify MinGW-w64 GCC 14 toolchain (Windows only) |
| 3 | `build_all_ffmpeg_dependencies` | Compile 100+ external libraries sequentially |
| 4 | `configure_ffmpeg`, `install_ffmpeg` | Configure and build FFmpeg with detected libraries |
| 5 | `configure_ffmpeg_kit`, `install_ffmpeg_kit` | Build FFmpegKit wrapper library |
| 6 | `create_*_bundle` | Aggregate artifacts into relocatable bundle |

## Command-Line Options

### General Options

| Option | Default | Description |
|--------|---------|-------------|
| `-h, --help` | - | Display this help and exit |
| `-v, --version` | - | Display version and exit |
| `-d, --debug` | - | Build with debug information |
| `-s, --speed` | - | Optimize for speed instead of size |
| `-f, --force` | - | Force rebuild of all dependencies |

### Platform Selection Options

| Option | Default | Description |
|--------|---------|-------------|
| `--host-platform=*|--host=*` | - | Target platform [linux|windows] |
| `--host-arch=*|--arch=*` | - | Host CPU architecture [i686|x86_64] (32-bit or 64-bit) |

### Licensing Options

| Option | Default | Description |
|--------|---------|-------------|
| `--enable-gpl=` | `n` | Allow building GPL libraries, created libs will be licensed under the GPLv3.0 |
| `--enable-nonfree\|--nonfree` | - | Build binaries will be non-redistributable |

### Build Options

| Option | Default | Description |
|--------|---------|-------------|
| `--ffmpeg-git-checkout-version=` | `release/8.0` | Build a particular version of FFmpeg (e.g., n3.1.1 or a specific git hash) |
| `--ffmpeg-git-checkout=` | `https://github.com/FFmpeg/FFmpeg.git` | Clone FFmpeg from other repositories |
| `--ffmpeg-source-dir=` | `[empty]` | Specify the directory of ffmpeg source code. When specified, git will not be used |
| `--cflags=` | `-mtune=generic -O3 -pipe` | Compiler flags (default works on any CPU) |
| `--git-get-latest=` | `y` | Do a git pull for latest code from repositories like FFmpeg |
| `--prefer-stable=` | `y` | Build a few libraries from releases instead of git master |
| `--build-only=` | - | Build only specific dependency (0.. or step/library name from get-all-steps) |
| `--build-from=` | - | Start building dependencies from given step (0.. or step/library name) |
| `--build-dependencies-only=` | `n` | Only build dependency binaries. Will not build app binaries |
| `--build-ffmpeg-only=` | `n` | Build ffmpeg binaries only |
| `--build-ffmpeg-kit-only=` | `n` | Build ffmpeg-kit binaries and bundle only |
| `--enable-static\|--static` | - | Build static ffmpeg and ffmpeg-kit binaries |
| `--enable-shared\|--shared` | `default` | Build shared ffmpeg and ffmpeg-kit binaries |
| `--clean-builds` | - | Clean ffmpeg and ffmpeg-kit builds based on --enable-static/--enable-shared(default) and exit |
| `--list-libraries` | - | Lists ffmpeg configuration including extra libraries and exit |
| `--enable-[library name]` | - | Enable extra ffmpeg libraries. Run --list-libraries and see under "External library support" |
| `--ff-*` | - | Pass additional ffmpeg parameters prefixed by ff-* to ffmpeg configure. No additional checks done |

## Cross-Compiler Toolchain

For Windows builds, the system uses MinGW-w64 GCC 14 toolchain with the following configuration:

- GCC version: 14.x (releases/gcc-14)
- MinGW-w64 headers: master branch
- Binutils: 2.44 (binutils-2_44-branch)
- Target: Windows with Win32 threads

The toolchain installation typically takes 30+ minutes and produces:
- GCC C/C++ compilers (`{host_target}-gcc`, `{host_target}-g++`)
- GNU Binutils (`{host_target}-ar`, `{host_target}-ld`, `{host_target}-strip`)
- MinGW-w64 runtime libraries

## Output Bundle Structure

The final bundle contains a complete, relocatable distribution:

```
prebuilt/
├── {platform}-{arch}
│     └──bundle-{platform}-{arch}-{build-type}/
│         └──ffmpeg-kit/
│            ├── include/                           # FFmpeg and FFmpegKit headers
│            ├── lib/                               # Shared libraries (.so) or (.a) and import libraries
│            ├── bin/                               # Executables (ffmpeg, ffprobe) or (ffmpeg.exe, ffprobe.exe)
│            ├── pkgconfig/                         # Pkg-config files with bundle-relative paths
│            └── LICENSE/                           # All dependency licenses
```

## Supported Libraries

The build system supports 100+ external libraries including:

### Core Libraries
- zlib, bzip2, lzma - Compression
- libx264, libx265 - Video encoding
- libopus, libvorbis - Audio encoding
- libass - Subtitle support
- And more...

### Advanced Features
- chromaprint - Audio fingerprinting
- frei0r - Video filters
- libvidstab - Video stabilization
- librubberband - Audio time-stretching
- And more...

For a full list of supported libraries run `--list-libraries`

## Troubleshooting

### Common Issues

1. **Insufficient Memory**: Build requires minimum 600MB RAM
2. **Toolchain Build Fails**: Ensure 30+ minutes available for GCC compilation (Windows builds)
3. **Missing Dependencies**: Install required build tools on host system

### Build Logs

All build operations are logged to `build.log` in the repository root.
