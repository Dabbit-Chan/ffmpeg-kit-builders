# Android Binary Publishing Pipeline

This document describes the Android binary publishing pipeline for FFmpegKit Extended.

## Overview

The Android publishing pipeline produces AAR (Android Archive) libraries and publishes them to Maven Central. It provides:

1. **AAR Libraries** - Native Android libraries with embedded JNI binaries
2. **Maven Central Distribution** - Published to Maven Central for easy Gradle integration
3. **Multi-ABI Support** - arm64-v8a, armeabi-v7a, x86_64 architectures
4. **GitHub Releases** - Binary distribution via GitHub Releases

## Architecture

```
prebuilt/
├── android-aarch64/                         # ARM64 build
├── android-armv7a/                          # ARMv7 build
├── android-x86_64/                          # x86_64 build
└── android/jniLibs/                         # Staging directory for AAR
    └── jniLibs/
        ├── arm64-v8a/                       # ARM64 native libraries
        │   └── libffmpegkit.so
        ├── armeabi-v7a/                     # ARMv7 native libraries
        │   └── libffmpegkit.so
        ├── x86_64/                          # x86_64 native libraries
        │   └── libffmpegkit.so
        ├── include/                         # C/C++ headers
        └── lib/pkgconfig/                   # pkg-config files
```

## Build Pipeline

### 1. Build FFmpegKit for Android

Build FFmpegKit for each Android architecture:

```bash
# Build for all Android architectures
sudo ./runner.sh --host=android --arch=aarch64 -y --full-bundle --kit --skip --release=local -f
sudo ./runner.sh --host=android --arch=armv7a -y --full-bundle --kit --skip --release=local -f
sudo ./runner.sh --host=android --arch=x86_64 -y --full-bundle --kit --skip --release=local -f
```

Or use the unified build script:

```bash
# Build all Android architectures at once
sudo ./scripts/build_all.sh \
  --platform=android \
  --bundles=base,audio,video,video_hw,full \
  --build=kit,bundle \
  -f
```

### 2. Assemble AAR Packages

After building all architectures, assemble AAR packages:

```bash
# Build AARs for all bundle types
sudo ./scripts/android/build_aar.sh \
  --platform=android-aarch64,android-armv7a,android-x86_64 \
  --bundles=base,audio,video,video_hw,full
```

This script:
- Collects `.so` files from each architecture build
- Copies headers and pkg-config files
- Assembles AAR using Gradle
- Publishes to Maven Central (or Maven Local)
- Creates GitHub release assets

### 3. Gradle Configuration

The build uses `tools/android/build.gradle` with the Maven Publish plugin:

```gradle
mavenPublishing {
    coordinates(
        'io.github.akashskypatel.ffmpegkit',
        'bundle-base-shared',
        '0.9.1'
    )
    publishToMavenCentral(true)
    signAllPublications()
}
```

## Maven Coordinates

Each AAR is published with the following Maven coordinates:

```
io.github.akashskypatel.ffmpegkit:bundle-{type}-shared[-small][-gpl][-debug]:{version}
```

Examples:
- `io.github.akashskypatel.ffmpegkit:bundle-base-shared:0.9.1`
- `io.github.akashskypatel.ffmpegkit:bundle-full-shared-gpl:0.9.1`
- `io.github.akashskypatel.ffmpegkit:bundle-audio-shared-small:0.9.1`
- `io.github.akashskypatel.ffmpegkit:bundle-video-shared-debug:0.9.1`

## Usage

### Gradle (Groovy DSL)

Add to your `build.gradle`:

```gradle
dependencies {
    // Base LGPL variant (recommended for most users)
    implementation 'io.github.akashskypatel.ffmpegkit:bundle-base-shared:0.9.1'
    
    // Full LGPL variant
    implementation 'io.github.akashskypatel.ffmpegkit:bundle-full-shared:0.9.1'
    
    // Audio LGPL variant
    implementation 'io.github.akashskypatel.ffmpegkit:bundle-audio-shared:0.9.1'
    
    // Video LGPL variant
    implementation 'io.github.akashskypatel.ffmpegkit:bundle-video-shared:0.9.1'
    
    // Video HW LGPL variant
    implementation 'io.github.akashskypatel.ffmpegkit:bundle-video_hw-shared:0.9.1'
    
    // GPL variants (require GPL compliance)
    implementation 'io.github.akashskypatel.ffmpegkit:bundle-base-shared-gpl:0.9.1'
    implementation 'io.github.akashskypatel.ffmpegkit:bundle-full-shared-gpl:0.9.1'
}
```

### Gradle (Kotlin DSL)

Add to your `build.gradle.kts`:

```kotlin
dependencies {
    // Base LGPL variant
    implementation("io.github.akashskypatel.ffmpegkit:bundle-base-shared:0.9.1")
    
    // Full GPL variant
    implementation("io.github.akashskypatel.ffmpegkit:bundle-full-shared-gpl:0.9.1")
}
```

### Manual Integration

1. Download AAR from [GitHub Releases](https://github.com/akashskypatel/ffmpeg-kit-builders/releases)
2. Add to your project's `libs/` directory
3. Add to `build.gradle`:
   ```gradle
   repositories {
       flatDir {
           dirs 'libs'
       }
   }
   
   dependencies {
       implementation(name: 'bundle-base-shared-release', ext: 'aar')
   }
   ```

## Publishing to Maven Central

### Prerequisites

1. **OSSRH Account**: Register at [Sonatype OSSRH](https://issues.sonatype.org/)
2. **GPG Keys**: Generate signing keys:
   ```bash
   gpg --gen-key
   gpg --keyserver keyserver.ubuntu.com --send-keys YOUR_KEY_ID
   ```
3. **Credentials File**: Create `/home/vscode/.config/keystore/github`:
   ```
   OSSRH_USERNAME=your-sonatype-username
   OSSRH_PASSWORD=your-sonatype-password
   ```

### Publishing Process

1. **Local Testing**:
   ```bash
   ./gradlew publishToMavenLocal
   ```

2. **Publish to Maven Central**:
   ```bash
   # Automatically done by build_aar.sh
   ./gradlew publishToMavenCentral
   ```

3. **Release to Maven Central**:
   - Log in to [Sonatype Nexus](https://oss.sonatype.org/)
   - Close and release the staging repository
   - Or use the Gradle plugin's automatic release

## Bundle Variants

| Bundle | Description | Architectures | License |
|--------|-------------|---------------|---------|
| `base` | Core FFmpeg + built-in codecs | All | LGPL |
| `audio` | Base + external audio codecs | All | LGPL |
| `video` | Audio + external video codecs | All | LGPL |
| `video_hw` | Video + hardware acceleration | All | LGPL |
| `full` | All features enabled | All | LGPL |
| `*-gpl` | GPL variants (x264, x265, etc.) | All | GPL |
| `*-small` | Size-optimized builds | All | LGPL/GPL |
| `debug` | Debug symbols, no optimization | All | LGPL |

## Architecture Support

| Architecture | ABI | Target Devices | Status |
|-------------|-----|----------------|--------|
| arm64-v8a | aarch64 | Modern 64-bit devices | ✅ Supported |
| armeabi-v7a | armv7a | Legacy/budget devices, IoT | ✅ Supported |
| x86_64 | x86_64 | Emulators, ChromeOS | ✅ Supported |
| x86 | i686 | Legacy (removed) | ❌ Deprecated |

## Platform Requirements

| Component | Minimum Version |
|-----------|----------------|
| Android SDK | 26 (Android 8.0) |
| Android NDK | 29.0.14206865 |
| Gradle | 8.0+ |
| Android Gradle Plugin | 8.0+ |
| Java | 11+ |
| minSdkVersion | 26 |
| targetSdkVersion | 33 |

## Build Script Details

### `scripts/android/build_aar.sh`

Key functions:
- `create_jni_libs_dir()` - Creates staging directory structure
- `get_ffmpeg_kit_dir()` - Locates prebuilt binaries
- `parse_arch()` - Maps architecture names to Android ABI names

### `tools/android/build.gradle`

Key configurations:
- `mavenPublishing` - Maven Central publishing setup
- `android.sourceSets` - JNI library paths
- `publishToMavenCentral` - Publishing task

## Troubleshooting

### AAR Assembly Fails

**Issue**: Gradle build fails with "No native binaries found"

**Solutions**:
- Verify prebuilt `.so` files exist in `prebuilt/android-{arch}/`
- Check `FFMPEG_KIT_JNI_LIBS_DIR` path is correct
- Ensure all architectures completed building

### Missing Architectures

**Issue**: AAR only contains some architectures

**Solutions**:
- Build all architectures before assembling AAR
- Check `FFMPEG_KIT_ARCHES` Gradle property
- Verify `.so` files in each `prebuilt/android-{arch}/` directory

### Maven Central Publishing Fails

**Issue**: Authentication or signature errors

**Solutions**:
- Verify OSSRH credentials in keystore file
- Ensure GPG keys are uploaded to keyserver
- Check that all publications are signed

### ABI Filter Issues

**Issue**: App only includes specific ABIs

**Solutions**:
```gradle
android {
    defaultConfig {
        ndk {
            abiFilters 'arm64-v8a', 'armeabi-v7a', 'x86_64'
        }
    }
}
```

## Testing Checklist

Before publishing to Maven Central:

- [ ] All architectures build successfully
- [ ] AAR contains all native libraries
- [ ] Headers exported correctly
- [ ] Maven coordinates are correct
- [ ] GPG signatures valid
- [ ] POM metadata complete
- [ ] GitHub release assets uploaded
- [ ] Version numbers consistent

## Integration with Main Build System

The Android publishing pipeline integrates with `build_all.sh`:

```bash
# This automatically triggers AAR building
sudo ./scripts/build_all.sh \
  --platform=android \
  --bundles=base,full \
  --build=kit,bundle \
  -f
```

The `build_aars` flag is automatically set when Android platforms are detected.

## Future Enhancements

- [ ] Add Android TV specific builds
- [ ] Add ChromeOS optimizations
- [ ] NDK version flexibility
- [ ] Automatic Maven Central release in CI
- [ ] AndroidX migration
- [ ] Kotlin multiplatform support
- [ ] Compose integration examples

## Support

- **Issues**: [GitHub Issues](https://github.com/akashskypatel/ffmpeg-kit-builders/issues)
- **Build System**: [FFmpegKit/docs/BUILD_SYSTEM.md](FFmpegKit/docs/BUILD_SYSTEM.md)
- **Main README**: [README.md](../README.md)

## License

The Android publishing pipeline is part of FFmpegKit Extended:
- LGPL variants: LGPL 3.0
- GPL variants: GPL 3.0

Choose the appropriate variant based on your project's licensing requirements.
