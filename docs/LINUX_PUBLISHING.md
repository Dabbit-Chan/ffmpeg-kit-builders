# Linux Binary Publishing Pipeline

This document describes the Linux binary publishing pipeline for FFmpegKit Extended.

## Overview

The Linux publishing pipeline produces native Linux binaries for x86_64 architecture. It provides:

1. **Shared Libraries (.so)** - Dynamic link libraries for runtime loading
2. **Static Libraries (.a)** - Static libraries for linking
3. **Development Headers** - C/C++ headers for integration
4. **pkg-config Files** - Build configuration for easy integration
5. **GitHub Releases** - Binary distribution via GitHub Releases

## Architecture

```
prebuilt/
├── linux-x86_64/                            # Linux x86_64 build
│   ├── libraries/                           # Dependency libraries
│   │   ├── bin/                             # Dependency executables
│   │   ├── lib/                             # .so, .a files
│   │   └── include/                         # Dependency headers
│   ├── ffmpeg-kit-base-linux-x86_64-shared-lgpl/
│   │   ├── bin/                             # ffmpeg, ffprobe
│   │   ├── lib/
│   │   │   ├── libffmpegkit.so              # Shared library
│   │   │   ├── libffmpegkit.so.8            # Versioned symlink
│   │   │   └── libffmpegkit.a               # Static library (if built)
│   │   ├── include/                         # C/C++ headers
│   │   └── pkgconfig/                       # .pc files
│   ├── bundle-base-linux-x86_64-shared-lgpl/
│   │   ├── bin/                             # Bundled executables + libs
│   │   ├── lib/                             # Libraries
│   │   ├── include/                         # Headers
│   │   └── releases/
│   │       └── bundle-base-linux-x86_64-shared-lgpl.zip
```

## Build Pipeline

### 1. Build FFmpegKit for Linux

Build FFmpegKit natively on Linux:

```bash
# Build for Linux x86_64
sudo ./runner.sh --host=linux --arch=x86_64 -y --full-bundle --kit --skip --release=local -f
```

Or use the unified build script:

```bash
# Build Linux with all bundle types
sudo ./scripts/build_all.sh \
  --platform=linux \
  --bundles=base,audio,video,video_hw,full \
  --build=kit,bundle \
  -f
```

### 2. Create Release Archives

Release archives are automatically created when using `--release=local` or `--release=remote`:

```bash
# Create release ZIP
sudo ./runner.sh --host=linux --arch=x86_64 \
  -y --full-bundle --kit \
  --release=local -f
```

This creates:
- `bundle-{type}-linux-x86_64-shared-{license}.zip` - Complete bundle
- Contains: binaries, headers, libraries, pkg-config files, licenses

### 3. Publish to GitHub Releases

Releases are automatically published when using `--release=remote`:

```bash
# Build and publish to GitHub Releases
sudo ./runner.sh --host=linux --arch=x86_64 \
  -y --full-bundle --kit \
  --release=remote -f
```

## Usage

### C/C++ Integration

#### Using pkg-config (Recommended)

```bash
# Get compiler flags
pkg-config --cflags ffmpegkit
pkg-config --libs ffmpegkit
```

Example:
```cpp
#include <ffmpegkit_wrapper.h>
#include <iostream>

int main() {
    ffmpeg_kit_initialize();
    
    FFmpegSessionHandle session = ffmpeg_kit_execute("-i input.mp4 output.mov");
    
    return 0;
}
```

Compile:
```bash
g++ -o myapp myapp.cpp $(pkg-config --cflags --libs ffmpegkit)
```

#### Manual Linking

```bash
g++ -o myapp myapp.cpp \
  -Iprebuilt/linux-x86_64/bundle-full-linux-x86_64-shared-lgpl/include \
  -Lprebuilt/linux-x86_64/bundle-full-linux-x86_64-shared-lgpl/lib \
  -lffmpegkit
```

Set runtime path:
```bash
export LD_LIBRARY_PATH=prebuilt/linux-x86_64/bundle-full-linux-x86_64-shared-lgpl/lib:$LD_LIBRARY_PATH
```

### CMake Integration

```cmake
find_path(FFMPEG_KIT_INCLUDE_DIR ffmpegkit_wrapper.h
    PATHS "/opt/ffmpeg-kit/prebuilt/linux-x86_64/bundle-full-linux-x86_64-shared-lgpl/include")

find_library(FFMPEG_KIT_LIBRARY ffmpegkit
    PATHS "/opt/ffmpeg-kit/prebuilt/linux-x86_64/bundle-full-linux-x86_64-shared-lgpl/lib")

target_include_directories(MyApp PRIVATE ${FFMPEG_KIT_INCLUDE_DIR})
target_link_libraries(MyApp PRIVATE ${FFMPEG_KIT_LIBRARY})
```

### CMake with pkg-config

```cmake
find_package(PkgConfig REQUIRED)
pkg_check_modules(FFMPEG_KIT REQUIRED ffmpegkit)

target_include_directories(MyApp PRIVATE ${FFMPEG_KIT_INCLUDE_DIRS})
target_link_libraries(MyApp PRIVATE ${FFMPEG_KIT_LIBRARIES})
```

## Build Requirements

| Component | Version | Notes |
|-----------|---------|-------|
| GCC | 14.x+ | Modern C++ support |
| CMake | 3.16+ | Build system |
| Host OS | Linux | Ubuntu/Debian/CentOS |
| Target OS | Linux | x86_64 only |

### Dependencies

Install required packages:

```bash
sudo apt-get update
sudo apt-get install -qq --no-install-recommends \
  ragel pkg-config make autoconf automake yasm cvs flex bison \
  texinfo ed pax unzip patch wget xz-utils nasm gperf autogen \
  bzip2 clang bc autopoint zstd curl git subversion libtool-bin \
  build-essential cmake software-properties-common python3 \
  coreutils python3-pip apt-transport-https ca-certificates \
  python3-setuptools ninja-build autoconf-archive g++ gcc \
  gettext help2man libtool p7zip-full python3-venv binutils \
  llvm lld python3-numpy cython3 shellcheck xutils-dev \
  libssl-dev zlib1g-dev libglib2.0-dev libglib2.0-dev-bin \
  libgtkmm-3.0-dev libsdl2-dev
```

## Bundle Variants

| Bundle | Description | Size | License |
|--------|-------------|------|---------|
| `base` | Core FFmpeg + built-in codecs | ~40MB | LGPL |
| `audio` | Base + external audio codecs | ~70MB | LGPL |
| `video` | Audio + external video codecs | ~130MB | LGPL |
| `video_hw` | Video + hardware acceleration | ~140MB | LGPL |
| `full` | All features enabled | ~220MB | LGPL |
| `*-gpl` | GPL variants (x264, x265, etc.) | Varies | GPL |
| `*-small` | Size-optimized builds | Smaller | LGPL/GPL |

## Architecture Support

| Architecture | Status | Notes |
|-------------|--------|-------|
| x86_64 | ✅ Supported | 64-bit Linux |
| i686 | ❌ Not Supported | 32-bit deprecated |
| aarch64 | ❌ Not Supported | Future enhancement |

## Output Structure

### Shared Library Build

```
bundle-{type}-linux-x86_64-shared-{license}/
├── bin/
│   ├── ffmpeg                             # FFmpeg executable
│   ├── ffprobe                            # FFprobe executable
│   └── libffmpegkit.so                    # Main shared library
├── lib/
│   ├── libffmpegkit.so                    # Shared library
│   ├── libffmpegkit.so.8                  # Versioned symlink
│   └── *.a                                # Static dependencies
├── include/
│   ├── ffmpegkit_wrapper.h               # Main C API header
│   └── ...                                # Other headers
├── pkgconfig/
│   └── ffmpegkit.pc                      # pkg-config file
└── licenses/
    └── ...                                # License files
```

### Release ZIP Contents

```bash
# Extract
unzip bundle-full-linux-x86_64-shared-lgpl.zip

# Structure
bundle-full-linux-x86_64-shared-lgpl/
├── bin/
├── lib/
├── include/
├── pkgconfig/
└── licenses/
```

## Distribution Methods

### GitHub Releases

```bash
# Download latest
wget https://github.com/akashskypatel/ffmpeg-kit-builders/releases/latest/download/bundle-full-linux-x86_64-shared-lgpl.zip
```

### System Installation

```bash
# Extract to /opt
sudo mkdir -p /opt/ffmpeg-kit
sudo unzip bundle-full-linux-x86_64-shared-lgpl.zip -d /opt/ffmpeg-kit/

# Set up environment
echo 'export PATH=/opt/ffmpeg-kit/bundle-full-linux-x86_64-shared-lgpl/bin:$PATH' >> ~/.bashrc
echo 'export LD_LIBRARY_PATH=/opt/ffmpeg-kit/bundle-full-linux-x86_64-shared-lgpl/lib:$LD_LIBRARY_PATH' >> ~/.bashrc
echo 'export PKG_CONFIG_PATH=/opt/ffmpeg-kit/bundle-full-linux-x86_64-shared-lgpl/pkgconfig:$PKG_CONFIG_PATH' >> ~/.bashrc
source ~/.bashrc
```

### Package Managers (Future)

- [ ] Debian/Ubuntu .deb package
- [ ] RHEL/CentOS .rpm package
- [ ] Arch Linux AUR package
- [ ] Snap package
- [ ] Flatpak integration

## Library Validation

### Check Shared Library

```bash
# Verify library exports
nm -D --defined-only lib/libffmpegkit.so | grep " T "

# Check dependencies
ldd lib/libffmpegkit.so

# Check for text relocations (should be blank)
readelf -d lib/libffmpegkit.so | grep TEXTREL
```

### Test Execution

```bash
# Test FFmpeg
./bin/ffmpeg -version

# Test FFprobe
./bin/ffprobe -version

# Test FFplay (if included)
./bin/ffplay -version
```

## Troubleshooting

### Library Not Found

**Issue**: `libffmpegkit.so: cannot open shared object file`

**Solutions**:
```bash
# Add to LD_LIBRARY_PATH
export LD_LIBRARY_PATH=/path/to/ffmpeg-kit/lib:$LD_LIBRARY_PATH

# Or add to system ldconfig
echo "/path/to/ffmpeg-kit/lib" | sudo tee /etc/ld.so.conf.d/ffmpeg-kit.conf
sudo ldconfig
```

### pkg-config Not Found

**Issue**: `Package ffmpegkit was not found`

**Solutions**:
```bash
export PKG_CONFIG_PATH=/path/to/ffmpeg-kit/pkgconfig:$PKG_CONFIG_PATH
pkg-config --modversion ffmpegkit
```

### Missing Dependencies

**Issue**: Missing system libraries

**Solutions**:
```bash
# Check missing dependencies
ldd lib/libffmpegkit.so | grep "not found"

# Install missing packages
sudo apt-get install libssl-dev zlib1g-dev
```

### Build Fails

**Issue**: Compilation errors

**Solutions**:
- Verify all build dependencies installed
- Check GCC version (14.x+ recommended)
- Clean build directory and rebuild

## Integration with Main Build System

Linux builds integrate with `build_all.sh`:

```bash
# Build Linux alongside other platforms
sudo ./scripts/build_all.sh \
  --platform=linux,windows \
  --bundles=base,full \
  --build=kit,bundle \
  -f
```

## Platform-Specific Notes

### Distro Compatibility

Binaries built on older distributions should work on newer ones (forward compatibility):

- **Recommended Build Distro**: Ubuntu 20.04 LTS or CentOS 7
- **Manylinux**: Can use [manylinux](https://quay.io/organization/pypa) Docker images for maximum compatibility

### RPATH Configuration

For portable binaries, consider setting RPATH:

```bash
# Set RPATH to $ORIGIN/../lib
patchelf --set-rpath '$ORIGIN/../lib' lib/libffmpegkit.so
```

### Stripping Binaries

Reduce binary size:

```bash
strip --strip-unneeded lib/libffmpegkit.so
```

## Future Enhancements

- [ ] ARM64 (aarch64) Linux support
- [ ] Debian/Ubuntu packages (.deb)
- [ ] RHEL/CentOS packages (.rpm)
- [ ] Snap package
- [ ] Flatpak integration
- [ ] AppImage distribution
- [ ] System library integration
- [ ] Wayland support improvements

## Support

- **Issues**: [GitHub Issues](https://github.com/akashskypatel/ffmpeg-kit-builders/issues)
- **Build System**: [FFmpegKit/docs/BUILD_SYSTEM.md](FFmpegKit/docs/BUILD_SYSTEM.md)
- **Main README**: [README.md](../README.md)

## License

The Linux publishing pipeline is part of FFmpegKit Extended:
- LGPL variants: LGPL 3.0
- GPL variants: GPL 3.0

Choose the appropriate variant based on your project's licensing requirements.
