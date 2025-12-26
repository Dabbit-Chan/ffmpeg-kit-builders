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
	if [[ $host_platform == "windows" && ! -f ../$win32_gcc ]]; then
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
    if ! check_pkg_config_batch "$dependency_install_prefix/lib/pkgconfig/libpcre*.pc" > >(redirect_output) 2>&1; then
      change_dir "$work_dir/cross_compilers/src"
      download_and_unpack_file "https://repo.msys2.org/mingw/mingw64/mingw-w64-x86_64-pcre-8.45-1-any.pkg.tar.zst" "mingw-pcre"
      change_dir "$work_dir/cross_compilers/src/mingw-pcre/mingw64"
      [[ -d "bin" ]] && (cp -rv bin/* "$dependency_install_prefix/bin/" > >(redirect_output) 2>&1 || exit_message 1 "could not install mingw-pcre bin")
      [[ -d "include" ]] && (cp -rv include/* "$dependency_install_prefix/include/" > >(redirect_output) 2>&1 || exit_message 1 "could not install mingw-pcre include")
      [[ -d "lib" ]] && (cp -rv lib/* "$dependency_install_prefix/lib/" > >(redirect_output) 2>&1 || exit_message 1 "could not install mingw-pcre lib")
      [[ -d "share" ]] && (cp -rv share/* "$dependency_install_prefix/share/" > >(redirect_output) 2>&1 || exit_message 1 "could not install mingw-pcre share")
    fi
    if ! check_pkg_config_batch "$dependency_install_prefix/lib/pkgconfig/sndfile*.pc" > >(redirect_output) 2>&1; then
      change_dir "$work_dir/cross_compilers/src"
      download_and_unpack_file "https://repo.msys2.org/mingw/mingw64/mingw-w64-x86_64-libsndfile-1.2.2-1-any.pkg.tar.zst" "mingw-libsndfile"
      change_dir "$work_dir/cross_compilers/src/mingw-libsndfile/mingw64"
      [[ -d "bin" ]] && (cp -rv bin/* "$dependency_install_prefix/bin/" > >(redirect_output) 2>&1 || exit_message 1 "could not install mingw-libsndfile bin")
      [[ -d "include" ]] && (cp -rv include/* "$dependency_install_prefix/include/" > >(redirect_output) 2>&1 || exit_message 1 "could not install mingw-libsndfile include")
      [[ -d "lib" ]] && (cp -rv lib/* "$dependency_install_prefix/lib/" > >(redirect_output) 2>&1 || exit_message 1 "could not install mingw-libsndfile lib")
      [[ -d "share" ]] && (cp -rv share/* "$dependency_install_prefix/share/" > >(redirect_output) 2>&1 || exit_message 1 "could not install mingw-libsndfile share")
    fi
    if [[ ! -f "$dependency_install_prefix/bin/msys-intl-8.dll" ]]; then
      change_dir "$work_dir/cross_compilers/src"
      download_and_unpack_file "https://mirror.msys2.org/msys/x86_64/libintl-0.22.5-1-x86_64.pkg.tar.zst" "mingw-libintl"
      change_dir "$work_dir/cross_compilers/src/mingw-libintl/usr"
      [[ -d "bin" ]] && (cp -rv bin/* "$dependency_install_prefix/bin/" > >(redirect_output) 2>&1 || exit_message 1 "could not install mingw-libintl bin")
    fi
    if ! check_pkg_config_batch "$dependency_install_prefix/lib/pkgconfig/iconv*.pc" > >(redirect_output) 2>&1; then
      change_dir "$work_dir/cross_compilers/src"
      download_and_unpack_file "https://repo.msys2.org/mingw/mingw64/mingw-w64-x86_64-libiconv-1.17-4-any.pkg.tar.zst" "mingw-libiconv"
      change_dir "$work_dir/cross_compilers/src/mingw-libiconv/mingw64"
      [[ -d "bin" ]] && (cp -rv bin/* "$dependency_install_prefix/bin/" > >(redirect_output) 2>&1 || exit_message 1 "could not install mingw-libiconv bin")
      [[ -d "include" ]] && (cp -rv include/* "$dependency_install_prefix/include/" > >(redirect_output) 2>&1 || exit_message 1 "could not install mingw-libiconv include")
      [[ -d "lib" ]] && (cp -rv lib/* "$dependency_install_prefix/lib/" > >(redirect_output) 2>&1 || exit_message 1 "could not install mingw-libiconv lib")
      [[ -d "share" ]] && (cp -rv share/* "$dependency_install_prefix/share/" > >(redirect_output) 2>&1 || exit_message 1 "could not install mingw-libiconv share")
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
  build_libjsoncpp
	local type_postfix="$(get_build_type)"
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
	if truthy "$build_static"; then
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
	do_configure "${config_options}" "./configure" "${type_postfix}" || exit_message 1 "unable to configure ffmpeg-kit. see $LOG_FILE for details."

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
