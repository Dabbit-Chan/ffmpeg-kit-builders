#!/usr/bin/env bash

set -e
OUTPUT_LIB="$1"
AR_CMD="$2"
RANLIB_CMD="$3"
FFMPEG_BUILD_DIR="$4"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$(realpath "$SCRIPT_DIR/../..")"

echo "Generating monolithic static library: $OUTPUT_LIB"
rm -f lib.mri bundle_manifest.txt
echo "CREATE $OUTPUT_LIB" > lib.mri
echo "ADDLIB libffmpegkit.a" >> lib.mri
# 1. Get dependencies via pkg-config
PKG_CONFIG_PATH="$FFMPEG_BUILD_DIR/lib/pkgconfig"
pkg-config --static --libs libavdevice libavfilter libavformat libavcodec libswresample libswscale libavutil > libs.txt
# 2. Parse libraries - ONE CONTINUOUS SHELL COMMAND
raw_libs_to_keep=""
deps=$(cat libs.txt)
search_paths=""

# First pass: Collect search paths (-L)
echo "  [STATIC MONOLITH GENERATOR]: Checking for dependency flags first pass..."
for flag in $deps; do
  case "$flag" in
    -L*)
      path=${flag#-L}
      # [FIX] Dynamic Path Sanitization
      if [ ! -d "$path" ]; then
          if [[ "$path" == *"/prebuilt/"* ]]; then
              # shellcheck disable=2001
              path_suffix="$(echo "$path" | sed 's|.*/prebuilt/|/prebuilt/|')"
              fixed_path="${PROJECT_ROOT}${path_suffix}"
              if [ -d "$fixed_path" ]; then
                  path="$fixed_path"
              fi
          fi
      fi
      search_paths="$search_paths $path"
      ;;
  esac
done
echo "  [STATIC MONOLITH GENERATOR]: Checking for dependency flags second pass..."
# Second pass: Process libraries (-l)
for flag in $deps; do
  case "$flag" in
    -l*)
      name=${flag#-l}
      case "$name" in
        # --- Category A: System Libraries (Skip) ---
        m|c|pthread|dl|rt|stdc++|gcc|gcc_s|atomic|z)
          raw_libs_to_keep="$raw_libs_to_keep -l$name"
          ;;
        # --- Category B: Windows System Libraries (Skip) ---
        mingw*|ws2_32|gdi32|winmm|ole32|crypt32|advapi32|user32|kernel32|shell32|glu32)
          raw_libs_to_keep="$raw_libs_to_keep -l$name"
          ;;
        iphlpapi|secur32|setupapi|mfuuid|strmiids|bcrypt|ncrypt|psapi|version|shlwapi)
          raw_libs_to_keep="$raw_libs_to_keep -l$name"
          ;;
        wldap32|imagehlp|d3d11|dxgi|opengl32|imm32|oleaut32|mfplat|gomp|userenv)
          raw_libs_to_keep="$raw_libs_to_keep -l$name"
          ;;
        mfreadwrite|mf|dsound|ksuser|uuid|comdlg32|avrt|dnsapi|msimg32|ntdll|dwrite)
          raw_libs_to_keep="$raw_libs_to_keep -l$name"
          ;;
        # --- Category C: Linux Utils (Skip) ---
        blkid|util|mount|selinux|sepol|resolv)
          raw_libs_to_keep="$raw_libs_to_keep -l$name"
          ;;
        # --- Category D: Test Utils (Skip) ---
        gtest|gtest_main|gmock|gmock_main)
          raw_libs_to_keep="$raw_libs_to_keep -l$name"
          ;;
        # --- Category E: Bundled Libraries ---
        *)
          found=no
          for dir in $search_paths; do
            # 1. Try to find Static Library (.a)
            if test -f "$dir/lib$name.a"; then
              echo "ADDLIB $dir/lib$name.a" >> lib.mri
              found=yes
              break
            fi
            # 2. If static not found, look for Shared Library (.so)
            # We use 'ls' inside $(...) to correctly expand wildcards in the shell
            shared_lib=$(ls "$dir/lib$name.so" 2>/dev/null || \
                         ls "$dir/lib$name.dylib" 2>/dev/null || \
                         ls "$dir/$name.dll" 2>/dev/null || \
                         ls "$dir/lib$name.dll" 2>/dev/null || true)
            if test -n "$shared_lib"; then
                echo "	[FOUND SHARED] $shared_lib (Queued for bundle)"
                echo "$shared_lib" >> bundle_manifest.txt
                found=yes
                break
            fi
          done
          # 3. If neither found, keep the linker flag for the consumer to resolve
          if test "$found" = "no"; then
              raw_libs_to_keep="$raw_libs_to_keep -l$name"
          fi
          ;;
      esac
      ;;
  esac
done
echo "SAVE" >> lib.mri
echo "END" >> lib.mri
$AR_CMD -M < lib.mri
$RANLIB_CMD "$OUTPUT_LIB"
rm -f lib.mri libs.txt
# Clean up duplicate flags
clean_libs=$(echo "$raw_libs_to_keep" | awk '{for (i=1;i<=NF;i++) if (!seen[$i]++) printf("%s%s", $i, OFS)}' | sed 's/ *$//')
echo "Created $OUTPUT_LIB"
if test -f bundle_manifest.txt; then
    echo "Shared libraries queued for install: $(cat bundle_manifest.txt)"
fi
if test -f ffmpeg-kit.pc; then
    sed -i "s|FFMPEG_KIT_EXT_LIBS|$clean_libs|g" ffmpeg-kit.pc
fi
