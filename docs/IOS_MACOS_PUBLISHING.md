# iOS/iOS-Simulator/macOS Binary Publishing Pipeline

This document describes the iOS, iOS Simulator, and macOS binary publishing pipeline for FFmpegKit Extended.

## Overview

The Apple platform publishing pipeline mirrors the Android AAR publishing system and provides:

1. **XCFramework Bundles** - Universal binaries combining iOS device, iOS simulator, and macOS builds
2. **Swift Package Manager (SPM)** - Native Swift package distribution
3. **CocoaPods** - Traditional Objective-C/Swift dependency management
4. **GitHub Releases** - Binary distribution via GitHub Releases

## Architecture

```
prebuilt/
├── ios-aarch64/                           # iOS device build
├── iphonesimulator-aarch64/               # iOS simulator build
├── macos-aarch64/                         # macOS Apple Silicon build
├── macos-x86_64/                          # macOS Intel build
└── apple/xcframeworks/                    # Output directory (per-platform XCFrameworks)
    ├── ffmpegkit-base-ios.xcframework.zip         # iOS: ios-arm64 + ios-arm64-simulator
    ├── ffmpegkit-base-gpl-ios.xcframework.zip     # iOS GPL variant
    ├── ffmpegkit-base-macos.xcframework.zip       # macOS: macos-arm64_x86_64 (universal)
    ├── ffmpegkit-base-gpl-macos.xcframework.zip   # macOS GPL variant
    ├── ffmpegkit-full-ios.xcframework.zip
    ├── ffmpegkit-full-gpl-ios.xcframework.zip
    ├── ffmpegkit-full-macos.xcframework.zip
    ├── ffmpegkit-full-gpl-macos.xcframework.zip
    ├── ffmpegkit-audio-ios.xcframework.zip
    ├── ffmpegkit-audio-macos.xcframework.zip
    └── ...
```

Each XCFramework contains **only one platform's architectures**:
- **iOS XCFrameworks**: Combine `ios-arm64` (device) + `ios-arm64-simulator` (simulator)
- **macOS XCFrameworks**: Combine `macos-arm64` + `macos-x86_64` into a universal binary

XCFrameworks do **not** span multiple platforms (iOS + macOS). This keeps bundles smaller and allows selective platform downloads.

## Build Pipeline

### 1. Build FFmpegKit for Apple Platforms

First, build FFmpegKit for all Apple platforms:

```bash
# Build all Apple platforms with all bundle types
sudo ./runner.sh --host=ios --arch=aarch64 -y --full-bundle --kit --skip --release=local -f
sudo ./runner.sh --host=iphonesimulator --arch=aarch64 -y --full-bundle --kit --skip --release=local -f
sudo ./runner.sh --host=macos --arch=aarch64 -y --full-bundle --kit --skip --release=local -f
sudo ./runner.sh --host=macos --arch=x86_64 -y --full-bundle --kit --skip --release=local -f
```

Or use the unified build script:

```bash
# Build all platforms at once
sudo ./scripts/build_all.sh \
  --platform=ios,iphonesimulator,macos \
  --bundles=base,audio,video,video_hw,full \
  --build=kit,bundle \
  -f
```

### 2. Create XCFrameworks

After building all platform-arch combinations, create XCFramework bundles:

```bash
# Create XCFrameworks for all Apple platforms (creates per-platform bundles)
sudo ./scripts/apple/build_xcframework.sh \
  --platform=ios,macos \
  --bundles=base,audio,video,video_hw,full
```

This will create:
- `ffmpegkit-base-ios.xcframework` - iOS device + simulator
- `ffmpegkit-base-macos.xcframework` - macOS universal (arm64 + x86_64)
- `ffmpegkit-full-ios.xcframework` - iOS device + simulator
- `ffmpegkit-full-macos.xcframework` - macOS universal (arm64 + x86_64)
- etc.

You can also target a single platform:

```bash
# Create only macOS XCFrameworks
sudo ./scripts/apple/build_xcframework.sh \
  --platform=macos \
  --bundles=full \
  --licenses=gpl
```

This script:
- Collects `.dylib` files from each platform build
- Creates per-platform XCFrameworks using `xcodebuild -create-xcframework`
- Packages XCFrameworks into ZIP archives
- Publishes to GitHub Releases automatically

### 3. Generate SPM and CocoaPods Files

Generate the Package.swift and FFmpegKit.podspec files:

```bash
# Generate Swift Package Manager and CocoaPods configuration
sudo ./scripts/apple/generate_spm_cocoapods.sh \
  --bundles=base,audio,video,video_hw,full
```

This script:
- Calculates SHA256 checksums for each XCFramework ZIP
- Updates `Package.swift` with correct URLs and checksums
- Updates `FFmpegKit.podspec` with the current version

## Usage

### Swift Package Manager

Add the following to your `Package.swift`:

```swift
let package = Package(
    name: "YourApp",
    platforms: [.iOS(.v13), .macOS(.v10_15)],
    dependencies: [
        .package(
            url: "https://github.com/akashskypatel/ffmpeg-kit-builders.git",
            from: "0.9.1"
        )
    ],
    targets: [
        .target(
            name: "YourTarget",
            dependencies: [
                .product(name: "FFmpegKitBase", package: "ffmpeg-kit-builders")
            ]
        )
    ]
)
```

Available SPM products:
- `FFmpegKitBase` - Base LGPL variant
- `FFmpegKit` - Full LGPL variant
- `FFmpegKitAudio` - Audio LGPL variant
- `FFmpegKitVideo` - Video LGPL variant
- `FFmpegKitVideoHW` - Video HW LGPL variant
- `FFmpegKitBaseGPL` - Base GPL variant
- `FFmpegKitGPL` - Full GPL variant
- `FFmpegKitAudioGPL` - Audio GPL variant
- `FFmpegKitVideoGPL` - Video GPL variant
- `FFmpegKitVideoHWGPL` - Video HW GPL variant

### CocoaPods

Add to your `Podfile`:

```ruby
# Base LGPL variant (recommended for most users)
pod 'FFmpegKit/Base', '~> 0.9.1'

# Full LGPL variant
pod 'FFmpegKit/Full', '~> 0.9.1'

# Audio LGPL variant
pod 'FFmpegKit/Audio', '~> 0.9.1'

# Video LGPL variant
pod 'FFmpegKit/Video', '~> 0.9.1'

# GPL variants (require GPL compliance)
pod 'FFmpegKit/BaseGPL', '~> 0.9.1'
pod 'FFmpegKit/FullGPL', '~> 0.9.1'
```

Then install:

```bash
pod install
```

### Manual Integration

1. Download XCFramework ZIP from [GitHub Releases](https://github.com/akashskypatel/ffmpeg-kit-builders/releases)
2. Extract the `.xcframework` bundle
3. Add to your Xcode project:
   - Drag `FFmpegKit.xcframework` into your project's "Frameworks, Libraries, and Embedded Content"
   - Set embedding to "Embed & Sign"
4. Link required system frameworks:
   - **iOS**: AVFoundation, CoreMedia, CoreVideo, AudioToolbox, VideoToolbox
   - **macOS**: CoreMedia, CoreVideo, AudioToolbox, VideoToolbox

## Publishing to Package Managers

### Code Signing and Notarization

All iOS and macOS binaries must be code-signed and notarized for distribution. FFmpegKit provides automated signing scripts.

#### Prerequisites

1. **Apple Developer Account**: Enroll in the [Apple Developer Program](https://developer.apple.com/programs/)
2. **Developer ID Application Certificate**: Create in [Apple Developer Portal](https://developer.apple.com/account/resources/certificates/list)
3. **App-Specific Password**: Generate at [appleid.apple.com](https://appleid.apple.com/account/manage)

#### Setup Signing Environment

Use the interactive setup helper:

```bash
./scripts/apple/setup_signing.sh
```

This will guide you through:
- Importing your code signing certificate
- Validating signing identities
- Configuring notarization credentials
- Testing the signing environment

#### Sign and Notarize XCFrameworks

After building XCFrameworks, sign and notarize them:

```bash
# Full signing and notarization
sudo ./scripts/apple/code_sign.sh \
  --bundles=base,full \
  --signing-identity="Developer ID Application: Your Company (TEAM123)" \
  --team-id=TEAM123 \
  --apple-id=developer@example.com \
  --app-specific-password=abcd-efgh-ijkl-mnop
```

**Sign only (skip notarization)**:
```bash
sudo ./scripts/apple/code_sign.sh \
  --bundles=base,full \
  --signing-identity="Developer ID Application: Your Company (TEAM123)" \
  --skip-notarization
```

**Notarize only (already signed)**:
```bash
sudo ./scripts/apple/code_sign.sh \
  --bundles=base,full \
  --apple-id=developer@example.com \
  --app-specific-password=abcd-efgh-ijkl-mnop \
  --team-id=TEAM123 \
  --notarize-only
```

#### What Gets Signed

Each XCFramework contains multiple platform slices:
- iOS device (`ios-arm64`)
- iOS Simulator (`ios-arm64-simulator`)  
- macOS Apple Silicon (`macos-arm64`)
- macOS Intel (`macos-x86_64`)

The signing script automatically:
1. Signs all `libffmpegkit.dylib` binaries in each slice
2. Applies hardened runtime (`--options runtime`)
3. Adds secure timestamp (`--timestamp`)
4. Submits to Apple's notarization service
5. Waits for notarization completion (up to 30 minutes)
6. Staples notarization tickets (macOS only)

#### Verification

Verify signatures after signing:

```bash
# Check signature
codesign --verify --verbose prebuilt/apple/xcframeworks/ffmpegkit-base-ios.xcframework
codesign --verify --verbose prebuilt/apple/xcframeworks/ffmpegkit-base-macos.xcframework

# Check notarization status
spctl --assess --type execute prebuilt/apple/xcframeworks/ffmpegkit-base-ios.xcframework
spctl --assess --type execute prebuilt/apple/xcframeworks/ffmpegkit-base-macos.xcframework
```

### CocoaPods Trunk

1. Ensure you have CocoaPods trunk access:
   ```bash
   pod trunk register akashskypatel@example.com 'Akash Patel'
   ```

2. Push the podspec:
   ```bash
   pod trunk push FFmpegKit.podspec --allow-warnings
   ```

### Swift Package Registry

The Package.swift is automatically configured and can be used directly from the Git repository. For a standalone Swift package registry:

1. Tag the release:
   ```bash
   git tag v0.9.1
   git push origin v0.9.1
   ```

2. SPM will automatically detect the release when users add the package URL.

## Bundle Variants

| Bundle | Description | Size | License |
|--------|-------------|------|---------|
| `base` | Core FFmpeg functionality | Small | LGPL |
| `audio` | Base + Audio codecs (MP3, AAC, Opus, etc.) | Medium | LGPL |
| `video` | Audio + Video codecs (H.264, H.265, VP9, AV1, etc.) | Large | LGPL |
| `video_hw` | Video + Hardware acceleration | Large | LGPL |
| `full` | All features enabled | Largest | LGPL |
| `*-gpl` | GPL variants (include GPL-licensed codecs like x264) | Varies | GPL |

## Platform Support

| Platform | Architecture | Min Version | Status |
|----------|-------------|-------------|--------|
| iOS | arm64 (aarch64) | 13.0 | ✅ Supported |
| iOS Simulator | arm64 (aarch64) | 13.0 | ✅ Supported |
| macOS | arm64 (Apple Silicon) | 13.0 | ✅ Supported |
| macOS | x86_64 (Intel) | 13.0 | ✅ Supported |

## Troubleshooting

### XCFramework Creation Fails

**Issue**: `xcodebuild -create-xcframework` fails

**Solutions**:
- Ensure all platform builds completed successfully
- Check that `.dylib` files exist in each platform's `lib/` directory
- Verify headers exist in each platform's `include/` directory
- Run on macOS (required for `xcodebuild`)

### Checksum Mismatch

**Issue**: SPM reports checksum mismatch

**Solutions**:
- Re-run `generate_spm_cocoapods.sh` to recalculate checksums
- Ensure the XCFramework ZIP hasn't been modified after checksum calculation

### Missing Symbols

**Issue**: Linker errors about missing symbols

**Solutions**:
- Ensure all required system frameworks are linked
- Check that the correct bundle variant is being used
- Verify architecture matches your target (arm64 vs x86_64)

## Files Created

| File | Purpose |
|------|---------|
| `scripts/apple/build_xcframework.sh` | XCFramework creation and GitHub publishing |
| `scripts/apple/generate_spm_cocoapods.sh` | SPM and CocoaPods file generation |
| `Package.swift` | Swift Package Manager configuration |
| `Package.swift.template` | Template for SPM generation |
| `FFmpegKit.podspec` | CocoaPods specification |
| `FFmpegKit.podspec.template` | Template for podspec generation |

## Integration with Main Build System

The Apple publishing pipeline integrates with the main `build_all.sh` script:

```bash
# This automatically triggers XCFramework building
sudo ./scripts/build_all.sh \
  --platform=ios,iphonesimulator,macos \
  --bundles=base,full \
  --build=ffmpeg,kit,bundle \
  -f
```

The `build_xcframeworks` flag is automatically set when Apple platforms are detected in the build.

## Future Enhancements

- [ ] Add tvOS support
- [ ] Add watchOS support
- [ ] VisionOS (xrOS) support
- [ ] Bitcode support (if re-enabled by Apple)
- [ ] dSYM generation for crash symbolication
- [ ] Automated CocoaPods trunk publishing in CI
- [ ] Swift package registry hosting
