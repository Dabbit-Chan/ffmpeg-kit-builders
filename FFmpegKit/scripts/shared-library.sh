#!/usr/bin/env bash

set -e

FFMPEG_BUILD_DIR="$1"
FFMPEG_KIT_BUILD_DIR=$(pwd) # Typically the directory containing CMakeCache.txt

rm -f bundle_manifest.txt

echo "  [SHARED-LIB] Analyzing dependencies in $FFMPEG_BUILD_DIR..."

if [ ! -f "CMakeCache.txt" ]; then
	echo "ERROR: CMakeCache.txt not found in $FFMPEG_KIT_BUILD_DIR"
	exit 1
fi

export PKG_CONFIG_PATH="$FFMPEG_BUILD_DIR/lib/pkgconfig"
deps=$(pkg-config --static --libs libavdevice libavfilter libavformat libavcodec libswresample libswscale libavutil)

raw_libs_to_keep=""

is_system_path() {
	local p="$1"
	# Skip standard Linux system library directories
	[[ "$p" == "/usr/lib"* ]] ||
		[[ "$p" == "/lib"* ]] ||
		[[ "$p" == "/lib64"* ]] ||
		[[ "$p" == "/usr/lib64"* ]] ||
		[[ "$p" == *"/sysroot/usr/lib/"* ]]
}

for flag in $deps; do
	case "$flag" in
	-l*)
		name=${flag#-l}
		name=${name#:}
		name=${name%.a}

		if [[ "$name" =~ ^(m|c|pthread|dl|rt|stdc\+\+|gcc|gcc_s|atomic|z|log|android|ole32|shlwapi|gdi32|winmm|kernel32|setupapi|ws2_32)$ ]]; then
			raw_libs_to_keep="$raw_libs_to_keep -l$name"
			continue
		fi
		lib_path=$(grep -m1 "pkgcfg_lib_FFMPEG_${name}:FILEPATH=" CMakeCache.txt | cut -d'=' -f2 || echo "")

		if [[ -n "$lib_path" && "$lib_path" != *"NOTFOUND"* ]]; then
			if is_system_path "$lib_path"; then
				echo "  [SKIPPING SYSTEM] $lib_path"
				raw_libs_to_keep="$raw_libs_to_keep -l$name"
				continue
			fi
			filename=$(basename "$lib_path")
			dirname=$(dirname "$lib_path")
			extension="${filename##*.}"

			case "$extension" in
			so | dll | dylib)
				if [ -h "$lib_path" ]; then
					target=$(readlink -f "$lib_path")
					if [[ "$target" == *.a || "$target" == *.lib ]]; then
						echo "  [SKIPPING SYMLINK] $filename -> $target (Static target)"
						continue
					fi
				fi
				if is_system_path "$lib_path"; then
					raw_libs_to_keep="$raw_libs_to_keep -l$name"
				else
					real_path=$(readlink -f "$lib_path" 2>/dev/null || echo "$lib_path")
					echo "  [FOUND SHARED] $filename -> $real_path"
					echo "$real_path" >>bundle_manifest.txt
				fi
				;;
			a | lib)
				if [ -h "$lib_path" ]; then
					target=$(readlink -f "$lib_path")
					if [[ "$target" == *.so || "$target" == *.dll || "$target" == *.dylib ]]; then
						echo "  [FOUND SHARED VIA SYMLINK] $filename -> $(basename "$target")"
						echo "$target" >> bundle_manifest.txt
						raw_libs_to_keep="$raw_libs_to_keep -l$name"
						continue
					fi
				fi
				clean_name=$(echo "$filename" | sed -E 's/^lib//; s/\.(dll\.a|a|lib)$//; s/\.dll$//')

				bin_dir="$(dirname "$dirname")/bin"
				found_dll=""
				for d in "$bin_dir" "$dirname"; do
					if [ -f "$d/${clean_name}.dll" ]; then
						found_dll="$d/${clean_name}.dll"
						break
					elif [ -f "$d/lib${clean_name}.dll" ]; then
						found_dll="$d/lib${clean_name}.dll"
						break
					fi
				done

				if [ -n "$found_dll" ]; then
					real_path=$(readlink -f "$found_dll" 2>/dev/null || echo "$found_dll")
					echo "  [FOUND SHARED] $(basename "$found_dll") (via $filename)"
					echo "$real_path" >>bundle_manifest.txt
				else
					echo "  [STATIC MERGED] $filename"
				fi
				;;
			esac
		else
			raw_libs_to_keep="$raw_libs_to_keep -l$name"
		fi
		;;
	-Wl,* | -pthread)
		raw_libs_to_keep="$raw_libs_to_keep $flag"
		;;
	esac
done

if test -f bundle_manifest.txt; then
	sort -u bundle_manifest.txt -o bundle_manifest.txt
fi
clean_libs=$(echo "$raw_libs_to_keep" | awk '{for (i=1;i<=NF;i++) if (!seen[$i]++) printf("%s%s", $i, OFS)}' | sed 's/ *$//')
if test -f ffmpeg-kit.pc; then
	sed -i "s|FFMPEG_KIT_EXT_LIBS|$clean_libs|g" ffmpeg-kit.pc
fi
