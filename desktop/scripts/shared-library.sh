#!/usr/bin/env bash

set -e

# Arguments passed from Makefile.am:
FFMPEG_BUILD_DIR="$1"

rm -f bundle_manifest.txt

echo "  [SHARED-LIB] Analyzing dependencies in $FFMPEG_BUILD_DIR..."

# 1. Get dependencies via pkg-config
# We look for the ffmpeg libraries to see what ffmpeg linked against.
export PKG_CONFIG_PATH="$FFMPEG_BUILD_DIR/lib/pkgconfig"
pkg-config --static --libs libavdevice libavfilter libavformat libavcodec libswresample libswscale libavutil > libs.txt

# 2. Parse libraries
raw_libs_to_keep=""
deps=$(cat libs.txt)
search_paths=""

# First pass: Collect search paths (-L)
for flag in $deps; do
  case "$flag" in
    -L*)
      path=${flag#-L}
      search_paths="$search_paths $path"
      ;;
  esac
done

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
        # --- Category D: Bundled Libraries ---
        *)
          found=no
          for dir in $search_paths; do
            bin_dir="$(dirname "$dir")/bin"
            target_lib=""
            
            # --- SEARCH LOGIC ---
            # Priority 1: Windows DLLs (in bin/ or lib/)
            if [ -f "$bin_dir/lib$name.dll" ]; then
                target_lib="$bin_dir/lib$name.dll"
            elif [ -f "$bin_dir/$name.dll" ]; then
                target_lib="$bin_dir/$name.dll"
            elif [ -f "$dir/lib$name.dll" ]; then
                target_lib="$dir/lib$name.dll"
            elif [ -f "$dir/$name.dll" ]; then
                target_lib="$dir/$name.dll"
            # Priority 2: Linux/macOS Shared Objects (if not on Windows)
            elif [ -f "$dir/lib$name.so" ]; then
                target_lib="$dir/lib$name.so"
            elif [ -f "$dir/lib$name.dylib" ]; then
                target_lib="$dir/lib$name.dylib"
            fi

            if [ -n "$target_lib" ]; then
                real_lib=$(readlink -f "$target_lib")
                # STRICT CHECK: Do not bundle .a files as "Shared"
                if [[ "$real_lib" == *.a ]]; then
                    # It's a static lib (misidentified or symlinked). Ignore it.
                    # This tells the linker to use it statically (merge it), not bundle it.
                    continue
                fi
                echo "  [FOUND SHARED] $name -> $real_lib"
                echo "$real_lib" >> bundle_manifest.txt
                found=yes
                break
            fi
          done

          # If not found in our custom search paths, assume it's system or handled elsewhere
          # and keep the flag for the consumer.
          if test "$found" = "no"; then
              raw_libs_to_keep="$raw_libs_to_keep -l$name"
          fi
          ;;
      esac
      ;;
  esac
done

# 3. Clean up duplicate flags for the .pc file
clean_libs=$(echo "$raw_libs_to_keep" | awk '{for (i=1;i<=NF;i++) if (!seen[$i]++) printf("%s%s", $i, OFS)}' | sed 's/ *$//')

if test -f bundle_manifest.txt; then
    # Sort unique to prevent double copying
    sort -u bundle_manifest.txt -o bundle_manifest.txt
fi

if test -f ffmpeg-kit.pc; then
    sed -i "s|FFMPEG_KIT_EXT_LIBS|$clean_libs|g" ffmpeg-kit.pc
fi