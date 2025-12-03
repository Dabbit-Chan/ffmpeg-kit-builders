# Windows Build Process Documentation

## Overview

This document describes the Windows cross-compilation build system for FFmpeg and FFmpegKit. The system builds Windows binaries (DLLs and executables) on a Linux host using MinGW-w64 cross-compilers, handling the complete build pipeline from toolchain installation through dependency compilation to final bundle creation.

## Quick Start

### Prerequisites

- Linux host (Ubuntu/Debian recommended)
- Minimum 600MB RAM, 2GB+ recommended for parallel builds
- 285GB available disk space for full build with all dependencies 
- Basic build tools: git, make, cmake, ninja, meson, pkg-config

### Basic Usage

```bash
# Build for Windows 64-bit with shared libraries and force rebuild of dependencies
./windows.sh --compiler-flavors=win64 --enable-shared -f

# Build only 64-bit static libraries
./windows.sh --compiler-flavors=win64 --enable-static

# Build only 64-bit static libraries with chromaprint support
./windows.sh --compiler-flavors=win64 --enable-static --enable-chromaprint

# Build with GPL libraries
./windows.sh --enable-gpl=y --compiler-flavors=win64
```

## Build Architecture

The Windows build system consists of four primary script files implementing a six-phase build pipeline:

1. **windows.sh** - Entry point and argument parsing
2. **scripts/main-windows.sh** - Build orchestrator and phase coordination  
3. **scripts/function-windows.sh** - Windows-specific build functions
4. **scripts/run-windows.sh** - Individual library builders

### Build Phases

| Phase | Function | Purpose |
|-------|----------|---------|
| 1 | `setup_build_environment` | Initialize paths, environment variables, architecture settings |
| 2 | `install_cross_compiler` | Build or verify MinGW-w64 GCC 14 toolchain |
| 3 | `build_all_ffmpeg_dependencies` | Compile 100+ external libraries sequentially |
| 4 | `configure_ffmpeg`, `install_ffmpeg` | Configure and build FFmpeg with detected libraries |
| 5 | `configure_ffmpeg_kit`, `install_ffmpeg_kit` | Build FFmpegKit wrapper library |
| 6 | `create_windows_bundle` | Aggregate artifacts into relocatable bundle |

## Command-Line Options

### General Options

| Option | Default | Description |
|--------|---------|-------------|
| `-h, --help` | - | Display this help and exit |
| `-v, --version` | - | Display version and exit |
| `-d, --debug` | - | Build with debug information |
| `-s, --speed` | - | Optimize for speed instead of size |
| `-f, --force` | - | Ignore warnings |

### Licensing Options

| Option | Default | Description |
|--------|---------|-------------|
| `--enable-gpl=` | `n` | Allow building GPL libraries, created libs will be licensed under the GPLv3.0 |

### Build Options

| Option | Default | Description |
|--------|---------|-------------|
| `--ffmpeg-git-checkout-version=` | `release/8.0` | Build a particular version of FFmpeg (e.g., n3.1.1 or a specific git hash) |
| `--ffmpeg-git-checkout=` | `https://github.com/FFmpeg/FFmpeg.git` | Clone FFmpeg from other repositories |
| `--ffmpeg-source-dir=` | `[empty]` | Specify the directory of ffmpeg source code. When specified, git will not be used |
| `--compiler-flavors=\|--flavor=` | - | Target architecture (win32 or win64) |
| `--cflags=` | `-mtune=generic -O3 -pipe` | Compiler flags (default works on any CPU, see README for options) |
| `--git-get-latest=` | `y` | Do a git pull for latest code from repositories like FFmpeg (can force a rebuild if changes are detected) |
| `--prefer-stable=` | `y` | Build a few libraries from releases instead of git master |
| `--debug` | - | Make this script print out each line as it executes |
| `--enable-gpl=` | `y` | Set to n to do an LGPL build |
| `--get-total-steps\|--get-step-name=` | - | Get dependency steps and step name by index |
| `--build-only=` | - | Build only specific dependency (0.. or step/library name from get-all-steps) |
| `--build-from=` | - | Start building dependencies from given step (0.. or step/library name) |
| `--build-dependencies=` | `y` | Build the ffmpeg dependencies. Disable when dependencies were built once to reduce build time |
| `--build-dependencies-only=` | `n` | Only build dependency binaries. Will not build app binaries |
| `--build-ffmpeg-only=` | `n` | Build ffmpeg binaries only |
| `--build-ffmpeg-kit-only=` | `n` | Build ffmpeg-kit binaries and bundle only |
| `--enable-static\|--static` | - | Build static ffmpeg and ffmpeg-kit binaries |
| `--enable-shared\|--shared` | `default` | Build shared ffmpeg and ffmpeg-kit binaries |
| `--enable-nonfree\|--nonfree` | - | Build binaries will be non-redistributable |
| `--clean-builds` | - | Clean ffmpeg and ffmpeg-kit builds based on --enable-static/--enable-shared(default) and exit |
| `--list-libraries` | - | Lists ffmpeg configuration including extra libraries and exit |
| `--enable-[library name]` | - | Enable extra ffmpeg libraries. Run --list-libraries and see under "External library support" |
| `--ff-*` | - | Pass additional ffmpeg parameters prefixed by ff-* to ffmpeg configure. No additional checks done |

## Environment Setup

The build system configures architecture-specific paths and toolchain variables:

### Win32 (32-bit)
```bash
ARCH=x86
FULL_ARCH=i686
host_target=i686-w64-mingw32
bits_target=32
```

### Win64 (64-bit)
```bash
ARCH=x86-64
FULL_ARCH=x86_64
host_target=x86_64-w64-mingw32
bits_target=64
```

## Cross-Compiler Toolchain

The system uses MinGW-w64 GCC 14 toolchain with the following configuration:

- GCC version: 14.x (releases/gcc-14)
- MinGW-w64 headers: master branch
- Binutils: 2.44 (binutils-2_44-branch)
- Target: Windows with Win32 threads

The toolchain installation typically takes 30+ minutes and produces:
- GCC C/C++ compilers (`{host_target}-gcc`, `{host_target}-g++`)
- GNU Binutils (`{host_target}-ar`, `{host_target}-ld`, `{host_target}-strip`)
- MinGW-w64 runtime libraries

## Output Bundle Structure

The final Windows bundle contains a complete, relocatable distribution:

```
prebuilt/bundle-windows-{arch}/
├── ffmpeg-kit/
│   ├── include/          # FFmpeg and FFmpegKit headers
│   ├── lib/              # DLLs and import libraries
│   ├── bin/              # Executables (ffmpeg.exe, ffprobe.exe)
│   ├── pkgconfig/        # Pkg-config files with bundle-relative paths
│   └── LICENSE/          # All dependency licenses
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

## Troubleshooting

### Common Issues

1. **Insufficient Memory**: Build requires minimum 600MB RAM
2. **Toolchain Build Fails**: Ensure 30+ minutes available for GCC compilation
3. **Missing Dependencies**: Install required build tools on host system

### Build Logs

All build operations are logged to `build.log` in the repository root.

## Notes

- The build system only supports cross-compilation from Linux to Windows
- Static and shared builds cannot be mixed in a single build
- GPL-enabled builds produce GPLv3-licensed binaries
- Bundle is fully relocatable with no hardcoded absolute paths

## Notes

- Default values are shown in the tables where applicable
- Options marked with `-` have no default value (they are flags)
- The `--ff-*` options allow direct passthrough to FFmpeg's configure script but may conflict with other explicit flags
- Use `--list-libraries` to see all available external libraries that can be enabled with `--enable-[library name]`
