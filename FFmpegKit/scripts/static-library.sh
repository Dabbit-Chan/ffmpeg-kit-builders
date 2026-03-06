#!/usr/bin/env bash

set -e
OUTPUT_LIB="$1"
AR_CMD="$2"
RANLIB_CMD="$3"
FFMPEG_BUILD_DIR="$4"

echo "Generating monolithic static library: $OUTPUT_LIB"
rm -f lib.mri bundle_manifest.txt libs.txt

echo "CREATE $OUTPUT_LIB" >lib.mri
if [ -f "libffmpegkit.a" ]; then
	echo "ADDLIB libffmpegkit.a" >>lib.mri
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

		if [[ "$name" =~ ^(m|c|pthread|dl|rt|stdc\+\+|gcc|gcc_s|atomic|z|log|android|ole32|shlwapi|gdi32|winmm|kernel32|setupapi|ws2_32|advapi32|user32|shell32|bcrypt|ncrypt|psapi|resolv|selinux|sepol|util|X11|xcb|Xext|Xau|Xdmcp)$ ]]; then
			raw_libs_to_keep="$raw_libs_to_keep -l$name"
			continue
		fi

		lib_path=$(grep -m1 "pkgcfg_lib_FFMPEG_${name}:FILEPATH=" CMakeCache.txt | cut -d'=' -f2 || echo "")

		if [[ -n "$lib_path" && "$lib_path" != *"NOTFOUND" ]]; then
			if is_system_path "$lib_path"; then
				echo "  [SKIPPING SYSTEM] $lib_path"
				raw_libs_to_keep="$raw_libs_to_keep -l$name"
				continue
			fi

			filename=$(basename "$lib_path")
			dirname=$(dirname "$lib_path")
			extension="${filename##*.}"

			case "$extension" in
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
				lib_base="${filename%.*}"
				lib_base="${lib_base%.dll}"
				base_name="${lib_base#lib}"
				bin_dir="$(dirname "$dirname")/bin"
				found_dll=""

				for d in "$bin_dir" "$dirname"; do
					if [ -f "$d/${base_name}.dll" ]; then
						found_dll="$d/${base_name}.dll"
						break
					elif [ -f "$d/lib${base_name}.dll" ]; then
						found_dll="$d/lib${base_name}.dll"
						break
					fi
				done

				if [ -n "$found_dll" ]; then
					echo "  [FOUND SHARED] $(basename "$found_dll")"
					echo "$(readlink -f "$found_dll" 2>/dev/null || echo "$found_dll")" >>bundle_manifest.txt
					raw_libs_to_keep="$raw_libs_to_keep -l$name"
				else
					echo "  [MERGING STATIC] $filename"
					echo "ADDLIB $lib_path" >>lib.mri
				fi
				;;
			so | dll | dylib)
				if [ -h "$lib_path" ]; then
					target=$(readlink -f "$lib_path")
					if [[ "$target" == *.a || "$target" == *.lib ]]; then
						echo "  [SKIPPING SYMLINK] $filename -> $target (Static target)"
						continue
					fi
				fi
				echo "  [FOUND SHARED] $filename"
				echo "$(readlink -f "$lib_path" 2>/dev/null || echo "$lib_path")" >>bundle_manifest.txt
				raw_libs_to_keep="$raw_libs_to_keep -l$name"
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

echo "SAVE" >>lib.mri
echo "END" >>lib.mri
$AR_CMD -M <lib.mri
$RANLIB_CMD "$OUTPUT_LIB"
rm -f lib.mri

clean_libs=$(echo "$raw_libs_to_keep" | awk '{for (i=1;i<=NF;i++) if (!seen[$i]++) printf("%s%s", $i, OFS)}' | sed 's/ *$//')
if test -f ffmpeg-kit.pc; then
	sed -i "s|FFMPEG_KIT_EXT_LIBS|$clean_libs|g" ffmpeg-kit.pc
fi
