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
  
	reset_cflags
	reset_cppflags
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

	config_options+=" --host=${host_target}"
	if [[ "$build_ffmpeg_kit_type" == "static" ]]; then
		config_options+=" --enable-static"
		config_options+=" --disable-shared"
	else
		config_options+=" --enable-shared"
		config_options+=" --disable-static"
	fi
	change_dir "${ffmpeg_kit_src_dir}"
  export CFLAGS="${local_cflags}"
  export CXXFLAGS="${local_cxxfalgs}"
  export LDFLAGS="$LDFLAGS -lpthread"
	do_configure "${config_options}" "./configure" "$(get_bundle_directory)" || exit_message 1 "unable to configure ffmpeg-kit. see $LOG_FILE for details."

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
    # pkg-config might return multiple -I paths; we check them all.
    IFS=' ' read -r -a paths <<< "$inc_dirs"
    
    # Also add the default include root as a fallback
    paths+=("-I${INCLUDE_ROOT}")

    for path_flag in "${paths[@]}"; do
        # Strip the -I prefix
        local search_dir="${path_flag#-I}"
        [[ -d "$search_dir" ]] || continue

        # Look for the header (try "name.h", "libname.h", "name/name.h")
        local header_found=$(find "$search_dir" -maxdepth 2 \
            \( -name "${base_name}.h" -o -name "lib${base_name}.h" \) | head -n 1)
            
        if [[ -n "$header_found" ]]; then
            # Grep for the magic macro
            local macro=$(grep -E -o -h \
                "defined\([A-Z0-9_]+_(NODLL|STATIC|STATICLIB)\)" \
                "$header_found" | head -n 1)
                
            if [[ -n "$macro" ]]; then
                macro="${macro#defined(}" # Strip defined(
                macro="${macro%)}"        # Strip )
                echo "-D${macro}"
                return 0
            fi
        fi
    done
    return 1
}

update_dependency_pkgconfig() {
  local ORIG_PKG_CONFIG_PATH=$PKG_CONFIG_PATH
  local ORIG_PKG_CONFIG_LIBDIR=$PKG_CONFIG_LIBDIR
  local ORIG_PKG_CONFIG_SYSROOT_DIR=$PKG_CONFIG_SYSROOT_DIR

  # Isolate pkg-config to strictly look at our cross-compiled environment
  export PKG_CONFIG_PATH=""
  export PKG_CONFIG_LIBDIR="$install_pkgconfig_dir"
  export PKG_CONFIG_SYSROOT_DIR="$dependency_install_prefix"

  echo "INFO: Scanning .pc files in $PKG_CONFIG_LIBDIR..."

  for pc_file in "$PKG_CONFIG_LIBDIR"/*.pc; do
      [[ -e "$pc_file" ]] || continue

      # 1. Get the package name from the filename
      pkg_name=$(basename "$pc_file" .pc)

      # 2. ASK PKG-CONFIG: "What libraries does this link against?"
      # --libs-only-l: Returns "-lz -lpng" etc.
      lib_flags=$(pkg-config --static --libs-only-l "$pkg_name" 2>/dev/null)
      
      # Extract the main library name (remove -l)
      clean_lib_name=$(echo "$lib_flags" | awk '{print $1}' | sed 's/^-l//')
      
      # If pkg-config failed or returned nothing (header-only lib), skip
      if [[ -z "$clean_lib_name" ]]; then
          continue
      fi

      # 3. GET HEADERS: "Where are the headers?"
      inc_flags=$(pkg-config --static --cflags-only-I "$pkg_name" 2>/dev/null)

      # 4. DETERMINE THE FLAG
      # Hunt for the macro or fallback
      search_name="${clean_lib_name#lib}"
      
      flag=$(get_static_macro_from_header "$search_name" "$inc_flags")

      # If auto-detection failed, use the fallback guess
      if [[ -z "$flag" ]]; then
          sanitized=$(echo "$search_name" | tr '[:lower:]-' '[:upper:]_')
          flag="-D${sanitized}_STATIC"
      fi

      # 5. DUPLICATION CHECK
      # Read the raw file content to see if the SPECIFIC flag exists.
      # We check the file directly because pkg-config output might be messy or reorganized.
      if grep -Fq -e "$flag" "$pc_file"; then
           echo "  [OK]   $pkg_name: Already has flag $flag in $pc_file" >>"$LOG_FILE"
           continue
      fi

      # 6. APPLY PATCH
      # Create backup only if we are actually modifying it
      cp -fv "$pc_file" "$pc_file.bak" >>"$LOG_FILE" 2>&1
      
      if [[ -n "$flag" ]]; then
          echo "  [FIX]  $pkg_name: Appending $flag to $pc_file" >>"$LOG_FILE"
          sed -i "/^Cflags:/ s|$| $flag|" "$pc_file"
      fi
  done

  # Restore original environment
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
    [[ ! -x "$(command -v "$gendef_tool")" ]] && gendef_tool="gendef"
    [[ ! -x "$(command -v "$dll_tool")" ]] && dll_tool="dlltool"
    local pkg_scan_dir=$(mktemp -d)
    if [[ -d "$src_root/$inc_sub" && -n "$inc_sub" ]]; then
        cp -rfv "$src_root/$inc_sub"* "$install_inc/" >>"$LOG_FILE"
        
        find "$src_root/$inc_sub" -mindepth 1 -print0 | while IFS= read -r -d '' f; do
            local rel_path="${f#"$src_root/$inc_sub/"}"
            echo "$install_inc/$rel_path" >> "$manifest"
            echo "  [Installed]: $install_inc/$rel_path" >>"$LOG_FILE"
        done
    fi
    if [[ -n "$bin_sub" && -d "$src_root/$bin_sub" ]]; then
        local tmp_def_dir=$(mktemp -d)
        find "$src_root/$bin_sub" -name "*.dll" -print0 | while IFS= read -r -d '' f; do
            local fname=$(basename "$f")
            local libname="${fname%.dll}"
            cp -rfv "$f" "$install_bin/" >>"$LOG_FILE"
            echo "$install_bin/$fname" >> "$manifest"
            echo "  [Installed]: $install_inc/$fname" >>"$LOG_FILE"
            pushd "$tmp_def_dir" >/dev/null || return 1
            "$gendef_tool" "$f" >/dev/null 2>&1
            local def_file="$tmp_def_dir/$libname.def"
            popd >/dev/null || return 1
            if [[ -f "$def_file" ]]; then
                echo "INFO: Generated MinGW import lib for $fname" >>"$LOG_FILE"
                "$dll_tool" -d "$def_file" -D "$fname" -l "$install_lib/lib$libname.dll.a"
                echo "$install_lib/lib$libname.dll.a" >> "$manifest"
                cp -rfv "$install_lib/lib$libname.dll.a" "$pkg_scan_dir/" >>"$LOG_FILE"
                rm -f "$install_lib/lib$libname.a"
                echo "  [Installed]: $install_lib/lib$libname.dll.a" >>"$LOG_FILE"
            else
                echo "  [WARNING]: Failed to generate def file for $fname" >>"$LOG_FILE"
            fi
        done
        rm -rf "$tmp_def_dir"
        find "$src_root/$bin_sub" -type f \( -not -name "*.dll" \) -print0 | while IFS= read -r -d '' f; do
            cp -rfv "$f" "$install_bin/" >>"$LOG_FILE"
            echo "$install_bin/$(basename "$f")" >> "$manifest"
            echo "  [Installed]: $install_bin/$(basename "$f")" >>"$LOG_FILE"
        done
    fi
    if [[ -d "$src_root/$lib_sub" && -n "$lib_sub" ]]; then
        find "$src_root/$lib_sub" \( -name "*.lib" -o -name "*.dll.a" \) -print0 | while IFS= read -r -d '' f; do
            local fname=$(basename "$f")
            local libname="${fname%.lib}"
            cp -rfv "$f" "$install_lib/$fname" >>"$LOG_FILE"
            echo "$install_lib/$fname" >> "$manifest"
            echo "  [Installed]: $install_bin/$fname" >>"$LOG_FILE"
            if [[ "$fname" == *.lib ]]; then
                if [[ -f "$install_lib/lib$libname.dll.a" ]]; then
                    : # We have a good import lib, do nothing
                else
                    cp -rfv "$f" "$install_lib/lib$libname.a" >>"$LOG_FILE"
                    echo "$install_lib/lib$libname.a" >> "$manifest"
                    cp -rfv "$install_lib/lib$libname.a" "$pkg_scan_dir/" >>"$LOG_FILE"
                    echo "  [Installed]: $install_lib/lib$libname.a" >>"$LOG_FILE"
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