#!/bin/bash

# shellcheck disable=SC2317,SC1091,SC1090,SC2120

find_all_build_exes() {
	local found=""
	# NB that we're currently in the prebuilt dir...
	for file in $(find . -name ffmpeg.exe) $(find . -name ffmpeg_g.exe) $(find . -name ffplay.exe) $(find . -name ffmpeg) $(find . -name ffplay) $(find . -name ffprobe) $(find . -name MP4Box.exe) $(find . -name mplayer.exe) $(find . -name mencoder.exe) $(find . -name avconv.exe) $(find . -name avprobe.exe) $(find . -name x264.exe) $(find . -name writeavidmxf.exe) $(find . -name writeaviddv50.exe) $(find . -name rtmpdump.exe) $(find . -name x265.exe) $(find . -name ismindex.exe) $(find . -name dvbtee.exe) $(find . -name boxdumper.exe) $(find . -name muxer.exe) $(find . -name remuxer.exe) $(find . -name timelineeditor.exe) $(find . -name lwcolor.auc) $(find . -name lwdumper.auf) $(find . -name lwinput.aui) $(find . -name lwmuxer.auf) $(find . -name vslsmashsource.dll); do
		found="$found $(readlink -f "$file")"
	done

	# bash recursive glob fails here again?
	for file in $(find . -name vlc.exe | grep -- -); do
		found="$found $(readlink -f "$file")"
	done
	echo -e "$found" # pseudo return value...
}

set_toolchain_paths() {
	export PATH="${PATH}:${toolchain_bin_path}:${dependency_install_prefix}/bin"
	export CC="${cross_prefix}gcc"
	export AR="$(realpath "${cross_prefix}ar")"
	export AS="$(realpath "${cross_prefix}as")"
	export NM="$(realpath "${cross_prefix}nm")"
	export RANLIB="$(realpath "${cross_prefix}ranlib")"
	export LD="$(realpath "${cross_prefix}ld")"
	export STRIP="$(realpath "${cross_prefix}strip")"
	export CXX="$(realpath "${cross_prefix}g++")"
}

check_cross_compiler_bin() {
	local gcc_bin="$toolchain_bin_path/$host_target-gcc"
	if [[ -f $gcc_bin ]]; then
		echo -e "INFO: MinGW compiler already installed for $host_name, not re-installing..." | tee -a "$LOG_FILE"
		return 0 # early exit they've selected at least some kind by this point...
	fi
	return 1
}

check_cross_compiler() {
	if [[ $(check_cross_compiler_bin) != 0 ]]; then
		install_cross_compiler
	fi
}

install_cross_compiler() {
	echo -e "INFO: Building (or already built) MinGW-w64 cross-compiler(s)..." | tee -a "$LOG_FILE"
	create_dir "$work_dir"/cross_compilers
	change_dir "$work_dir"/cross_compilers

	unset CFLAGS # don't want these "windows target" settings used the compiler itself since it creates executables to run on the local box (we have a parameter allowing them to set them for the script "all builds" basically)
	# pthreads version to avoid having to use cvs for it
	echo -e "Starting to download and build cross compile version of gcc [requires working internet access] with thread count $gcc_cpu_count..." >>"$LOG_FILE"
	echo -e "" >>"$LOG_FILE"

	# --disable-shared allows c++ to be distributed at all...which seemed necessary for some random dependency which happens to use/require c++...
	local zeranoe_script_name=mingw-w64-build
	local zeranoe_script_options="--gcc-branch=releases/gcc-14 --mingw-w64-branch=master --binutils-branch=binutils-2_44-branch" # --cached-sources"
	if iswindows && [[ ! -f ../$win32_gcc ]]; then
		echo -e "Building win32 cross compiler..." >>"$LOG_FILE"
		download_gcc_build_script "$zeranoe_script_name"
		if [[ "$(uname)" =~ (5.1) ]]; then # Avoid using secure API functions for compatibility with msvcrt.dll on Windows XP.
			sed -i "s/ --enable-secure-api//" "$zeranoe_script_name"
		fi
		# shellcheck disable=SC2086
		CFLAGS='-O2 -pipe' CXXFLAGS='-O2 -pipe' nice ./"$zeranoe_script_name" "$zeranoe_script_options" i686 || exit_message 1 "cannot set up i686 cross compiler script" # i686 option needs work to implement
		if [[ ! -f ../$win32_gcc ]]; then
			exit_message 1 "failure building 32 bit gcc? Recommend nuke prebuilt (rm -rf prebuilt) and start over..."
		fi
		if [[ ! -f ../cross_compilers/mingw-w64-i686/i686-w64-mingw32/lib/libmingwex.a ]]; then
			exit_message 1 "failure building mingwex? 32 bit"
		fi
		if [[ $host_arch == "x86_64" && ! -f ../$win64_gcc ]]; then
			echo -e "Building win64 x86_64 cross compiler..." >>"$LOG_FILE"
			download_gcc_build_script "$zeranoe_script_name"
			# shellcheck disable=SC2086
			CFLAGS='-O3 -pipe' CXXFLAGS='-O3 -pipe' nice ./"$zeranoe_script_name" "$zeranoe_script_options" x86_64 || exit_message 1 "could not update cross compiler script for x86_64"
			if [[ ! -f ../$win64_gcc ]]; then
				exit_message 1 "failure building 64 bit gcc? Recommend nuke prebuilt (rm -rf prebuilt) and start over..."
			fi
			if [[ ! -f ../cross_compilers/mingw-w64-x86_64/x86_64-w64-mingw32/lib/libmingwex.a ]]; then
				exit_message 1 "failure building mingwex? 64 bit"
			fi
		fi
		change_dir "$work_dir/cross_compilers/src"
	fi
	# rm -f build.log # leave resultant build log...sometimes useful...
	reset_cflags
	change_dir ..
	echo -e "INFO: Done building (or already built) MinGW-w64 cross-compiler(s) successfully..." | tee -a "$LOG_FILE"
}

configure_ffmpeg_kit() {
	run_valid_function "build_libjsoncpp"
	echo -e "INFO: Configuring ffmpeg kit" | tee -a "$LOG_FILE"
	local type_postfix="$build_ffmpeg_kit_type"
	local ffmpeg_kit_version=$(get_ffmpeg_kit_version)

	if truthy "$build_force"; then
		remove_path -rf "$ffmpeg_kit_src_dir"/already_configured_*
		remove_path -rf "$ffmpeg_kit_install"
	fi

	create_dir "$ffmpeg_kit_install"

	export PKG_CONFIG_PATH="${PKG_CONFIG_PATH}:${ffmpeg_install_prefix}/lib/pkgconfig"
	set_toolchain_paths

	reset_allflags
	local local_cflags="${CFLAGS} -I${ffmpeg_install_prefix}/include -L${ffmpeg_install_prefix}/lib -I${ffmpeg_source_dir} -I${ffmpeg_source_dir}/compat -DHAVE_W32PTHREADS_H=1"
	local local_cxxfalgs="${CXXFLAGS} -I${ffmpeg_install_prefix}/include -L${ffmpeg_install_prefix}/lib -I${ffmpeg_source_dir} -I${ffmpeg_source_dir}/compat"
	
	change_dir "${ffmpeg_kit_src_dir}"
	make distclean > >(redirect_output) 2>&1

	local touch_name=$(get_small_touchfile_name "already_autoreconf_${type_postfix}" "$ffmpeg_kit_version $local_cflags $local_cxxfalgs")
	if [ ! -f "$touch_name" ]; then
		remove_path -f "${ffmpeg_kit_src_dir}/already_autoreconf_${type_postfix}"*
		change_dir "${ffmpeg_kit_src_dir}"
		autoreconf_library "ffmpeg-kit" || exit_message 1 "could not autoreconf ffmpeg-kit. See $LOG_FILE for details."
		create_touch_file 0 "$touch_name"
	fi

	local config_options="--prefix=${ffmpeg_kit_install} --with-ffmpeg-src=$ffmpeg_source_dir --with-ffmpeg-build=$ffmpeg_install_prefix"
	local cmake_params="-DCMAKE_SYSTEM_NAME=Windows \
-DCMAKE_C_COMPILER=$CC \
-DCMAKE_CXX_COMPILER=$CXX \
-DFFMPEG_SRC_DIR=\"$ffmpeg_source_dir\" \
-DFFMPEG_BUILD_DIR=\"$ffmpeg_install_prefix\" \
-DCMAKE_INSTALL_PREFIX=\"$ffmpeg_kit_install\""

	config_options+=" --host=${host_target}"
	if [[ "$build_ffmpeg_kit_type" == "static" ]]; then
		config_options+=" --enable-static"
		config_options+=" --disable-shared"
		cmake_params+=" -DBUILD_SHARED_LIBS=OFF -DBUILD_STATIC_LIBS=ON"
	else
		config_options+=" --enable-shared"
		config_options+=" --disable-static"
		cmake_params+=" -DBUILD_SHARED_LIBS=ON -DBUILD_STATIC_LIBS=OFF"
	fi
	change_dir "${ffmpeg_kit_src_dir}"
	export CFLAGS="${local_cflags}"
	export CXXFLAGS="${local_cxxfalgs}"
	export LDFLAGS="${LDFLAGS//-static /} -static-libgcc -static-libstdc++"
	
	change_dir "${ffmpeg_kit_src_dir}/build" 1
	
	do_cmake "$cmake_params" "$ffmpeg_kit_src_dir"
	# do_configure "${config_options}" "./configure" "$(get_bundle_directory)" || exit_message 1 "unable to configure ffmpeg-kit. see $LOG_FILE for details."

	echo -e "INFO: Done configuring ffmpeg kit" | tee -a "$LOG_FILE"
}

create_ffmpegkit_package_config() {
	local kit_version="$1"
	local location_prefix="$2"
	create_dir "${location_prefix}/lib/pkgconfig"
	cat >"${location_prefix}/lib/pkgconfig/ffmpeg-kit.pc" <<EOF
prefix=${ffmpeg_kit_install}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: ffmpeg-kit
Description: FFmpeg for applications on Windows
Version: ${kit_version}

# Public dependencies that have their own .pc files
Requires: libavfilter, libswscale, libavformat, libavcodec, libswresample, libavutil

# Linker flags for the ffmpeg-kit library itself (includes jsoncpp if static)
Libs: -L\${libdir} -lffmpegkit

# Private dependencies needed for linking on Windows
Libs.private: -lstdc++ -lws2_32 -lpsapi -lole32 -lshlwapi -lgdi32 -lbcrypt -luser32 -luuid -ljsoncpp

# Compiler flags for the ffmpeg-kit headers (includes jsoncpp headers if bundled)
Cflags: -I\${includedir}
EOF
}

get_static_macro_from_header() {
		local base_name="$1"
		local inc_dirs="$2"
		# 1. Gather all possible header paths
		IFS=' ' read -r -a paths <<< "$inc_dirs"
		paths+=("-I${INCLUDE_ROOT}")
		for path_flag in "${paths[@]}"; do
				local search_dir="${path_flag#-I}"
				[[ -d "$search_dir" ]] || continue
				# Look for the header
				local header_found=$(find "$search_dir" -maxdepth 2 \
						\( -name "${base_name}.h" -o -name "lib${base_name}.h" \) | head -n 1)
				if [[ -n "$header_found" ]]; then
						# 2a. Check for 'defined(MACRO)'
						# We use sed -nE to match the pattern and print ONLY the capture group (\1)
						local macro=$(sed -nE 's/.*defined\(([A-Z0-9_]+_(NODLL|STATIC|STATICLIB|STATIC_LIB))\).*/\1/p' "$header_found" | head -n 1)
						if [[ -n "$macro" ]]; then
								echo "-D${macro}"
								return 0
						fi
						# 2b. Fallback: Check for '#ifdef MACRO'
						# Matches: #ifdef MACRO, # ifdef MACRO, etc.
						# Captures the MACRO name into \1 and prints it.
						local ifdef_macro=$(sed -nE 's/^\s*#\s*ifdef\s+([A-Z0-9_]+_(NODLL|STATIC|STATICLIB|STATIC_LIB)).*/\1/p' "$header_found" | head -n 1)
						if [[ -n "$ifdef_macro" ]]; then
								 echo "-D${ifdef_macro}"
								 return 0
						fi
				fi
		done
		return 1
}

fix_pkgconfig_flags() {
	local ORIG_PKG_CONFIG_PATH=$PKG_CONFIG_PATH
	local ORIG_PKG_CONFIG_LIBDIR=$PKG_CONFIG_LIBDIR
	local ORIG_PKG_CONFIG_SYSROOT_DIR=$PKG_CONFIG_SYSROOT_DIR

	export PKG_CONFIG_PATH=""
	export PKG_CONFIG_LIBDIR="$install_pkgconfig_dir"
	export PKG_CONFIG_SYSROOT_DIR="$dependency_install_prefix"

	echo "INFO: Scanning .pc files in $PKG_CONFIG_LIBDIR..."

	for pc_file in "$PKG_CONFIG_LIBDIR"/*.pc; do
			[[ -e "$pc_file" ]] || continue
			pkg_name=$(basename "$pc_file" .pc)
			# Get Libs
			lib_flags=$(pkg-config --static --libs-only-l "$pkg_name" 2>/dev/null)
			clean_lib_name=$(echo "$lib_flags" | awk '{print $1}' | sed 's/^-l//')
			[[ -z "$clean_lib_name" ]] && continue
			# Get Cflags (Include Paths)
			inc_flags=$(pkg-config --static --cflags-only-I "$pkg_name" 2>/dev/null)
			search_name="${clean_lib_name#lib}"
			# --- STRATEGY 1: EXCEPTION MAP ---
			local flag=""
			case "$pkg_name" in
					kvazaar) flag="-DKVZ_STATIC_LIB" ;;
					lc3)     flag="-DLC3_STATIC" ;;
			esac
			# --- STRATEGY 2: HEADER SCAN ---
			if [[ -z "$flag" ]]; then
					flag=$(get_static_macro_from_header "$search_name" "$inc_flags")
			fi
			# --- STRATEGY 3: FALLBACK GUESSING ---
			if [[ -z "$flag" ]]; then
					local upper=$(echo "$search_name" | tr '[:lower:]-' '[:upper:]_')
					local guess="-D${upper}_STATIC"
					if [[ "$search_name" == "ssh" || "$search_name" == "twolame" ]]; then
							guess="-DLIB${upper}_STATIC"
					fi
					flag="$guess"
			fi
			# --- 5. DUPLICATION CHECK (UPDATED) ---
			# CRITICAL FIX: Only grep the 'Cflags:' line, not the whole file.
			# This allows adding the flag to Cflags even if it already exists in Cflags.private.
			if grep "^Cflags:" "$pc_file" | grep -Fq -e "$flag"; then
					 echo "  [OK]    $pkg_name: Already has flag $flag in Cflags" >>"$LOG_FILE"
					 continue
			fi
			# 6. APPLY PATCH
			cp -fv "$pc_file" "$pc_file.bak" >>"$LOG_FILE" 2>&1
			if [[ -n "$flag" ]]; then
					echo "  [FIX]   $pkg_name: Appending $flag to $pc_file" >>"$LOG_FILE"
					add_libs_to_pkg -t="$pc_file" -c="$flag"
			fi
	done

	export PKG_CONFIG_PATH="$ORIG_PKG_CONFIG_PATH"
	export PKG_CONFIG_LIBDIR="$ORIG_PKG_CONFIG_LIBDIR"
	export PKG_CONFIG_SYSROOT_DIR="$ORIG_PKG_CONFIG_SYSROOT_DIR"
	echo "INFO: Update Complete."
}

# WARNING: For pure C libraries only. Anything else will result in seg fault due to ABI mismatch
# Usage: install_msvc_binary -n="libname" -v="1.0" -s="src_dir" -p="Install prefix" -I="include_path" -L="lib_path" -B="bin_path" -d="Library desc" -m="Install manifest"
install_msvc_binary() {
    local lib_name="" version="" src_root="" inc_sub="" lib_sub="" bin_sub="" desc="Prebuilt MSVC Library"
    local manifest=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n=*) lib_name="${1#*=}"; shift ;;
            -v=*) version="${1#*=}"; shift ;;
            -s=*) src_root="${1#*=}"; shift ;;
            -p=*) install_dir="${1#*=}"; shift ;;
            -I=*) inc_sub="${1#*=}"; shift ;;
            -L=*) lib_sub="${1#*=}"; shift ;;
            -B=*) bin_sub="${1#*=}"; shift ;;
            -d=*) desc="${1#*=}"; shift ;;
            -m=*) manifest="${1#*=}"; shift ;;
            *) shift ;;
        esac
    done
    [[ -z "$install_dir" ]] && install_dir="$dependency_install_prefix"
    create_dir "$install_dir/{lib,bin,include}"
    local install_lib="$install_dir/lib"
    local install_bin="$install_dir/bin"
    local install_inc="$install_dir/include"
    [[ -z "$manifest" ]] && manifest="$install_pkgconfig_dir/${lib_name}_manifest"
    [[ ! -f "$manifest" ]] && touch "$manifest"
    echo "INFO: Installing Prebuilt $lib_name ($version)..." >>"$LOG_FILE"
    local gendef_tool="${cross_prefix}gendef"
    local dll_tool="${cross_prefix}dlltool"
    local objdump_tool="${cross_prefix}objdump"
    [[ ! -x "$(command -v "$gendef_tool")" ]] && gendef_tool="gendef"
    [[ ! -x "$(command -v "$dll_tool")" ]] && dll_tool="dlltool"
    # Use cross-objdump if available, otherwise llvm-objdump, otherwise system objdump
    if [[ ! -x "$(command -v "$objdump_tool")" ]]; then
        if command -v llvm-objdump >/dev/null 2>&1; then
            objdump_tool="llvm-objdump"
        else
            objdump_tool="objdump"
        fi
    fi
    local pkg_scan_dir=$(mktemp -d)
    # 1. Install Includes
    if [[ -d "$src_root/$inc_sub" && -n "$inc_sub" ]]; then
        cp -rfv "$src_root/$inc_sub/"* "$install_inc/" >>"$LOG_FILE"
        find "$src_root/$inc_sub" -mindepth 1 -print0 | while IFS= read -r -d '' f; do
            local rel_path="${f#"$src_root/$inc_sub/"}"
            mkdir -p "$(dirname "$install_inc/$rel_path")"
            cp -rfv "$f" "$install_inc/$rel_path" >>"$LOG_FILE"
            echo "$install_inc/$rel_path" >>"$manifest"
            echo "  [Installed]: $install_inc/$rel_path" >>"$LOG_FILE"
        done
    fi
    # 2. Install Binaries and Generate Import Libs
    if [[ -n "$bin_sub" && -d "$src_root/$bin_sub" ]]; then
        local tmp_def_dir=$(mktemp -d)
        find "$src_root/$bin_sub" -name "*.dll" -print0 | while IFS= read -r -d '' f; do
            local fname=$(basename "$f")
            local libname="${fname%.dll}"
            # Install the DLL to bin/
            cp -rfv "$f" "$install_bin/" >>"$LOG_FILE"
            echo "$install_bin/$fname" >> "$manifest"
            echo "  [Installed]: $install_bin/$fname" >>"$LOG_FILE"
            pushd "$tmp_def_dir" >/dev/null || return 1
            local def_file="$tmp_def_dir/$libname.def"
            local def_generated=false
            # --- STRATEGY SELECTION (FILE SIZE) ---
            # gendef crashes on large files (>100MB). We check size safely.
            local prefer_objdump=false
            local fsize=0
            if command -v stat >/dev/null 2>&1; then
                fsize=$(stat -c%s "$f" 2>/dev/null || stat -f%z "$f" 2>/dev/null || echo 0)
            else
                fsize=$(wc -c < "$f" | tr -d ' ')
            fi
            # THRESHOLD: 50MB (52428800 bytes)
            if [ "$fsize" -gt 52428800 ]; then
                prefer_objdump=true
            fi
            # --- ATTEMPT 1: OBJDUMP (Prioritized for large libs) ---
            if [ "$prefer_objdump" = true ] && command -v "$objdump_tool" >/dev/null 2>&1; then
                echo "  [Warning]: File $fname is large ($((fsize/1024/1024)) MB). Skipping gendef to prevent crash. Using $objdump_tool..." >>"$LOG_FILE"
                echo "LIBRARY \"$fname\"" > "$def_file"
                echo "EXPORTS" >> "$def_file"
                # FIXED PARSING LOGIC: Exclude "Export RVA" and "Ordinal Base" garbage lines
                if "$objdump_tool" -p "$f" | grep "\[ *[0-9]*\]" | grep -v "Export RVA" | grep -v "Ordinal Base" | awk '{print $NF}' >> "$def_file"; then
                    if [[ -s "$def_file" ]]; then def_generated=true; fi
                fi
            fi
            # --- ATTEMPT 2: GENDEF (Standard) ---
            if [ "$def_generated" = false ]; then
                set +e
                ("$gendef_tool" "$f" >/dev/null 2>&1)
                local rc=$?
                set -e
                if [ $rc -eq 0 ] && [[ -f "$def_file" ]]; then
                    def_generated=true
                fi
            fi
            # --- ATTEMPT 3: OBJDUMP (Fallback) ---
            if [ "$def_generated" = false ] && [ "$prefer_objdump" = false ] && command -v "$objdump_tool" >/dev/null 2>&1; then
                echo "  [INFO]: gendef failed/crashed for $fname. Retrying with $objdump_tool..." >>"$LOG_FILE"
                echo "LIBRARY \"$fname\"" > "$def_file"
                echo "EXPORTS" >> "$def_file"
                # FIXED PARSING LOGIC: Same as above
                if "$objdump_tool" -p "$f" | grep "\[ *[0-9]*\]" | grep -v "Export RVA" | grep -v "Ordinal Base" | awk '{print $NF}' >> "$def_file"; then
                    if [[ -s "$def_file" ]]; then def_generated=true; fi
                fi
            fi
            # --- PROCESS RESULT ---
            if [ "$def_generated" = true ]; then
                echo "INFO: Generated MinGW import lib for $fname" >>"$LOG_FILE"
                "$dll_tool" -d "$def_file" -D "$fname" -l "$install_lib/lib$libname.dll.a"
                echo "$install_lib/lib$libname.dll.a" >> "$manifest"
                cp -rfv "$install_lib/lib$libname.dll.a" "$pkg_scan_dir/" >>"$LOG_FILE"
                rm -f "$install_lib/lib$libname.a"
                echo "  [Installed]: $install_lib/lib$libname.dll.a" >>"$LOG_FILE"
            else
                echo "  [WARNING]: Failed to generate def file for $fname. Using direct DLL linking." >>"$LOG_FILE"
                cp -fv "$f" "$install_lib/lib$libname.dll" >>"$LOG_FILE"
                echo "$install_lib/lib$libname.dll" >> "$manifest"
                cp -fv "$f" "$pkg_scan_dir/lib$libname.dll" >>"$LOG_FILE"
            fi
            popd >/dev/null || return 1
        done
        rm -rf "$tmp_def_dir"
        find "$src_root/$bin_sub" -type f \( -not -name "*.dll" \) -print0 | while IFS= read -r -d '' f; do
            cp -rfv "$f" "$install_bin/" >>"$LOG_FILE"
            echo "$install_bin/$(basename "$f")" >> "$manifest"
            echo "  [Installed]: $install_bin/$(basename "$f")" >>"$LOG_FILE"
        done
    fi
    # 3. Install Existing Libs (if any)
    if [[ -d "$src_root/$lib_sub" && -n "$lib_sub" ]]; then
        find "$src_root/$lib_sub" \( -name "*.lib" -o -name "*.dll.a" \) -print0 | while IFS= read -r -d '' f; do
            local fname=$(basename "$f")
            local libname="${fname%.lib}"
            cp -rfv "$f" "$install_lib/$fname" >>"$LOG_FILE"
            echo "$install_lib/$fname" >> "$manifest"
            echo "  [Installed]: $install_lib/$fname" >>"$LOG_FILE"
            if [[ "$fname" == *.lib ]]; then
                if [[ -f "$install_lib/lib$libname.dll.a" || -f "$install_lib/lib$libname.dll" ]]; then
                    : 
                else
                    echo "  [SKIP]: Skipping incompatible MSVC static library: $fname" >>"$LOG_FILE"
                    continue
                fi
            fi
        done
    fi
    generate_pkg_config -t="$pkg_scan_dir" \
        -o="$install_pkgconfig_dir/$lib_name.pc" \
        -i="$install_dir" \
        -v="$version" -n="$lib_name" -d="$desc" >/dev/null 2>&1
    rm -rf "$pkg_scan_dir"
    echo "$install_pkgconfig_dir/$lib_name.pc" >> "$manifest"
    echo "  [Installed]: $install_pkgconfig_dir/$lib_name.pc" >>"$LOG_FILE"
    return 0
}

# 1. variant
# @. custom values
# Usage: get_generic_windows_cmake_toolchain [variant_suffix] [VAR="VALUE" ...]
# Example: get_generic_windows_cmake_toolchain "rabbitmq" CMAKE_C_FLAGS_INIT="-static -Wno-error"
get_generic_windows_cmake_toolchain() {
		local variant="$1"
		local base_filename="$host_name-toolchain.cmake"
		local base_filepath="$src_dir/$base_filename"
		shift
		# Determine filename based on variant presence
		local toolchain_filename="$host_name-toolchain.cmake"
		if [[ -n "$variant" ]]; then
			toolchain_filename="$host_name-toolchain-$variant.cmake"
			local toolchain_path="$(pwd)/$toolchain_filename"
		else
			toolchain_filename="$host_name-toolchain.cmake"
			local toolchain_path="$src_dir/$toolchain_filename"
		fi
		# Only generate if it doesn't exist
		if [[ ! -e "$toolchain_path" ]]; then
				local cpu_family="x86_64"
				if [ "$bits_target" = 32 ]; then
						cpu_family="x86"
				fi
				declare -A cmake_config
				# System info
				cmake_config["CMAKE_SYSTEM_NAME"]="Windows"
				cmake_config["CMAKE_SYSTEM_PROCESSOR"]="${target_proc:-$cpu_family}"
				# Toolchain locations
				cmake_config["TOOLCHAIN_PREFIX"]="${host_target}"
				cmake_config["TOOLCHAIN_ROOT"]="${toolchain_root_dir}"
				# Compilers
				cmake_config["CMAKE_C_COMPILER"]="${cross_prefix}gcc"
				cmake_config["CMAKE_CXX_COMPILER"]="${cross_prefix}g++"
				# cmake_config["CMAKE_RC_COMPILER"]="${cross_prefix}windres"
				cmake_config["CMAKE_AR"]="${cross_prefix}ar"
				cmake_config["CMAKE_RANLIB"]="${cross_prefix}ranlib"
				cmake_config["CMAKE_STRIP"]="${cross_prefix}strip"
				# Search Paths
				cmake_config["CMAKE_FIND_ROOT_PATH"]="${dependency_install_prefix}"
				cmake_config["CMAKE_FIND_ROOT_PATH_MODE_PROGRAM"]="NEVER"
				cmake_config["CMAKE_FIND_ROOT_PATH_MODE_LIBRARY"]="ONLY"
				cmake_config["CMAKE_FIND_ROOT_PATH_MODE_INCLUDE"]="ONLY"
				# Flags (Using INIT to allow appending later)
				cmake_config["CMAKE_C_FLAGS_INIT"]="-static -static-libgcc -static-libstdc++"
				cmake_config["CMAKE_CXX_FLAGS_INIT"]="-static -static-libgcc -static-libstdc++"
				cmake_config["CMAKE_EXE_LINKER_FLAGS_INIT"]="-static -static-libgcc -static-libstdc++"
				# Loop through remaining args in format KEY="VALUE"
				for arg in "$@"; do
						local key="${arg%%=*}"
						local value="${arg#*=}"
						echo "DEBUG: adding KEY:$key and VALUE:$value to cmake toolchain file for $variant" >>"$LOG_FILE"
						cmake_config["$key"]="$value"
				done
				echo "# Generated via get_generic_windows_cmake_toolchain" > "$toolchain_path"
				# Write CMAKE_SYSTEM_NAME first (convention)
				echo "set(CMAKE_SYSTEM_NAME \"${cmake_config[CMAKE_SYSTEM_NAME]}\")" >> "$toolchain_path"
				unset 'cmake_config[CMAKE_SYSTEM_NAME]'
				# Write the rest
				for key in "${!cmake_config[@]}"; do
						echo "set($key \"${cmake_config[$key]}\")" >> "$toolchain_path"
				done
		fi
		echo "$toolchain_path"
}

get_generic_windows_meson_cross_file() {
		local variant_name="$1"      # e.g., "librist"
		local extra_content="$2"     # e.g., "[built-in options]..."
		local base_filename="$host_name-meson-cross.mingw.txt"
		local base_filepath="$src_dir/$base_filename"
		# 1. Generate the BASE file if it doesn't exist (Standard Logic)
		if [[ ! -e "$base_filepath" ]]; then
				local cpu_family="x86_64"
				if [ "$bits_target" = 32 ]; then
						cpu_family="x86"
				fi
				cat >"$base_filepath" <<EOF
[built-in options]
buildtype = 'release'
wrap_mode = 'nofallback'
default_library = 'static'
prefer_static = 'true'
backend = 'ninja'
prefix = '$dependency_install_prefix'
libdir = '$dependency_install_prefix/lib'
b_staticpic = 'true'

[binaries]
c = '${cross_prefix}gcc'
cpp = '${cross_prefix}g++'
ld = '${cross_prefix}ld'
ar = '${cross_prefix}ar'
strip = '${cross_prefix}strip'
nm = '${cross_prefix}nm'
dlltool = '${cross_prefix}dlltool'
windres = '/usr/bin/true'
pkg-config = 'pkg-config'
nasm = 'nasm'
cmake = 'cmake'

[host_machine]
system = 'windows'
cpu_family = '$cpu_family'
cpu = '$cpu_family'
endian = 'little'

[properties]
sys_root = '$dependency_install_prefix'
pkg_config_sysroot_dir = '$dependency_install_prefix'
pkg_config_libdir = '$pkg_config_sysroot_dir/lib/pkgconfig'
needs_exe_wrapper = true
EOF
		fi
		# 2. Handle Custom Variant logic
		if [[ -n "$variant_name" ]]; then
				local custom_filepath="$(pwd)/$host_name-meson-cross.mingw.${variant_name}.txt"
				# Always overwrite the variant with a fresh copy of the base
				cp "$base_filepath" "$custom_filepath" 2>"$LOG_FILE"
				# Append custom options if provided
				if [[ -n "$extra_content" ]]; then
						# Add a newline for safety
						echo "" >> "$custom_filepath"
						echo -e "$extra_content" >> "$custom_filepath"
				fi
				# Return the path to the NEW custom file
				echo "$custom_filepath"
		else
				# No customization requested, return the standard base file
				echo "$base_filepath"
		fi
}

ffmpeg_windows_patches() {
	if iswindows; then
		echo "INFO: Patching ffmpeg for qindows Mingw quirks..." >>"$LOG_FILE"
		if [[ -f "$ffmpeg_source_dir/libavfilter/dnn/dnn_backend_tf.c" ]]; then
			sed -i 's/ctx->options.async/ctx->async/g' "$ffmpeg_source_dir/libavfilter/dnn/dnn_backend_tf.c"
		fi
		echo "INFO: Done patching ffmpeg for qindows Mingw quirks." >>"$LOG_FILE"
	fi
}