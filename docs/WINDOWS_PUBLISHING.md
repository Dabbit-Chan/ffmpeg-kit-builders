# Windows Binary Publishing Pipeline

This document describes the Windows binary publishing pipeline for FFmpegKit Extended.

## Overview

The Windows publishing pipeline produces native Windows binaries using MinGW-w64 cross-compilation from Linux hosts. It provides:

1. **Shared Libraries (.dll)** - Dynamic link libraries for runtime loading
2. **Static Libraries (.a)** - MinGW static libraries for linking
3. **Development Headers** - C/C++ headers for integration
4. **GitHub Releases** - Binary distribution via GitHub Releases

## Architecture

```
prebuilt/
├── windows-x86_64/                          # Windows x86_64 build
│   ├── libraries/                           # Dependency libraries
│   │   ├── bin/                             # Dependency executables
│   │   ├── lib/                             # .a, .dll.a files
│   │   └── include/                         # Dependency headers
│   ├── ffmpeg-kit-base-windows-x86_64-shared-lgpl/
│   │   ├── bin/                             # ffmpeg.exe, ffprobe.exe
│   │   ├── lib/
│   │   │   ├── libffmpegkit.dll             # Shared library
│   │   │   └── libffmpegkit.dll.a           # Import library
│   │   ├── include/                         # C/C++ headers
│   │   └── pkgconfig/                       # .pc files
│   ├── bundle-base-windows-x86_64-shared-lgpl/
│   │   ├── bin/                             # Bundled executables + DLLs
│   │   ├── lib/                             # Libraries
│   │   ├── include/                         # Headers
│   │   └── releases/
│   │       └── bundle-base-windows-x86_64-shared-lgpl.zip
```

## Build Pipeline

### 1. Build FFmpegKit for Windows

Build FFmpegKit using cross-compilation from Linux:

```bash
# Build for Windows x86_64
sudo ./runner.sh --host=windows --arch=x86_64 -y --full-bundle --kit --skip --release=local -f
```

Or use the unified build script:

```bash
# Build Windows with all bundle types
sudo ./scripts/build_all.sh \
  --platform=windows \
  --bundles=base,audio,video,video_hw,full \
  --build=kit,bundle \
  -f
```

### 2. Create Release Archives

Release archives are automatically created when using `--release=local` or `--release=remote`:

```bash
# Create release ZIP (included in kit/bundle build)
sudo ./runner.sh --host=windows --arch=x86_64 \
  -y --full-bundle --kit \
  --release=local -f
```

This creates:
- `bundle-{type}-windows-x86_64-shared-{license}.zip` - Complete bundle
- Contains: binaries, headers, libraries, pkg-config files, licenses

### 3. Publish to GitHub Releases

Releases are automatically published when using `--release=remote`:

```bash
# Build and publish to GitHub Releases
sudo ./runner.sh --host=windows --arch=x86_64 \
  -y --full-bundle --kit \
  --release=remote -f
```

## Usage

### C/C++ Integration

#### Dynamic Linking (DLL)

```cpp
#include <ffmpegkit_wrapper.h>
#include <iostream>

int main() {
    ffmpeg_kit_initialize();
    
    FFmpegSessionHandle session = ffmpeg_kit_execute("-i input.mp4 output.mov");
    
    return 0;
}
```

Compile with MinGW:
```bash
g++ -o myapp myapp.cpp \
  -Lprebuilt/windows-x86_64/bundle-full-windows-x86_64-shared-lgpl/lib \
  -lffmpegkit
```

#### Static Linking

```bash
g++ -static -o myapp myapp.cpp \
  -Lprebuilt/windows-x86_64/bundle-full-windows-x86_64-shared-lgpl/lib \
  -lffmpegkit -lavcodec -lavformat ...
```

### CMake Integration

```cmake
find_path(FFMPEG_KIT_INCLUDE_DIR ffmpegkit_wrapper.h
    PATHS "C:/ffmpeg-kit/prebuilt/windows-x86_64/bundle-full-windows-x86_64-shared-lgpl/include")

find_library(FFMPEG_KIT_LIBRARY ffmpegkit
    PATHS "C:/ffmpeg-kit/prebuilt/windows-x86_64/bundle-full-windows-x86_64-shared-lgpl/lib")

target_include_directories(MyApp PRIVATE ${FFMPEG_KIT_INCLUDE_DIR})
target_link_libraries(MyApp PRIVATE ${FFMPEG_KIT_LIBRARY})
```

## Build Requirements

| Component | Version | Notes |
|-----------|---------|-------|
| MinGW-w64 GCC | 15.x | Cross-compiler from Linux |
| Host OS | Linux | Ubuntu/Debian recommended |
| Target OS | Windows 8+ | x86_64 only |

### Installing MinGW-w64

```bash
wget https://github.com/xpack-dev-tools/mingw-w64-gcc-xpack/releases/download/v15.2.0-2/xpack-mingw-w64-gcc-15.2.0-2-linux-x64.tar.gz
mkdir -p tools
tar xf xpack-mingw-w64-gcc-15.2.0-2-linux-x64.tar.gz -C tools
mv tools/xpack-mingw-w64-gcc-15.2.0-2 /usr/local/mingw-w64
```

## Bundle Variants

| Bundle | Description | Size | License |
|--------|-------------|------|---------|
| `base` | Core FFmpeg + built-in codecs | ~50MB | LGPL |
| `audio` | Base + external audio codecs | ~80MB | LGPL |
| `video` | Audio + external video codecs | ~150MB | LGPL |
| `video_hw` | Video + hardware acceleration | ~160MB | LGPL |
| `full` | All features enabled | ~250MB | LGPL |
| `*-gpl` | GPL variants (x264, x265, etc.) | Varies | GPL |

## Architecture Support

| Architecture | Status | Notes |
|-------------|--------|-------|
| x86_64 | ✅ Supported | 64-bit Windows |
| i686 | ❌ Deprecated | 32-bit not supported |
| arm64 | ❌ Not Supported | Future enhancement |

**Note**: MSVC compilation is **not supported**. Use MinGW-w64 only.

## Output Structure

```
bundle-{type}-windows-x86_64-shared-{license}/
├── bin/
│   ├── libffmpegkit.dll              # Main shared library
│   ├── ffmpeg.exe                     # FFmpeg executable
│   ├── ffprobe.exe                    # FFprobe executable
│   └── *.dll                          # Runtime dependencies
├── lib/
│   ├── libffmpegkit.dll.a            # Import library for linking
│   └── *.a                            # Static dependencies
├── include/
│   ├── ffmpegkit_wrapper.h           # Main C API header
│   └── ...                            # Other headers
├── pkgconfig/
│   └── ffmpegkit.pc                  # pkg-config file
└── licenses/
    └── ...                            # License files
```

## Distribution

### GitHub Releases

```bash
# Download latest
wget https://github.com/akashskypatel/ffmpeg-kit-builders/releases/latest/download/bundle-full-windows-x86_64-shared-lgpl.zip
```

### Local Build

```bash
sudo ./runner.sh --host=windows --arch=x86_64 \
  -y --enable-full --enable-gpl \
  --kit --release=local -f
```

## Troubleshooting

### DLL Not Found

**Solution**: Place `libffmpegkit.dll` in same directory as executable or add to PATH.

### Linker Errors

**Solution**: Link against `.dll.a` import library for DLL builds or `.a` for static builds.

### MSVC Compatibility

**Solution**: MSVC not supported. Use MinGW-w64 builds and link via C interface only.

## Future Enhancements

- [ ] MSVC build support
- [ ] ARM64 Windows support
- [ ] vcpkg/Conan/NuGet packages
- [ ] Code signing certificates

## Support

- **Issues**: [GitHub Issues](https://github.com/akashskypatel/ffmpeg-kit-builders/issues)
- **Build System**: [FFmpegKit/docs/BUILD_SYSTEM.md](FFmpegKit/docs/BUILD_SYSTEM.md)

## License

- LGPL variants: LGPL 3.0
- GPL variants: GPL 3.0
