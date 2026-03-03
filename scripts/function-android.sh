#!/bin/bash

# shellcheck disable=SC2317,SC2129,SC1091,SC2120,SC2035,SC2016,SC2310,SC2155,SC2154,SC2034,2312,2250,2292,2249

set_toolchain_paths() {
	export PATH="${PATH}:${toolchain_bin_path}:${dependency_install_prefix}/bin"
	export CC="${toolchain_bin_path}/${clang_target}${ANDROID_API_LEVEL}-clang"
    export CXX="${toolchain_bin_path}/${clang_target}${ANDROID_API_LEVEL}-clang++"
    export AR="${toolchain_bin_path}/llvm-ar"
    export AS="${toolchain_bin_path}/llvm-as"
    export NM="${toolchain_bin_path}/llvm-nm"
    export RANLIB="${toolchain_bin_path}/llvm-ranlib"
    export STRIP="${toolchain_bin_path}/llvm-strip"
    export LD="${toolchain_bin_path}/ld.lld"
}

configure_ffmpeg_kit() {
	echo -e "INFO: Configuring ffmpeg kit" | tee -a "$LOG_FILE"
	local type_postfix="$build_ffmpeg_kit_type"

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

	export CFLAGS="${local_cflags}"
	export CXXFLAGS="${local_cxxfalgs}"
	export LDFLAGS="${LDFLAGS//-static /} -static-libstdc++"

	local cmake_params="-DCMAKE_SYSTEM_NAME=Android \
-DCMAKE_C_COMPILER=$CC \
-DCMAKE_CXX_COMPILER=$CXX \
-DFFMPEG_SRC_DIR=\"$ffmpeg_source_dir\" \
-DFFMPEG_BUILD_DIR=\"$ffmpeg_install_prefix\" \
-DCMAKE_INSTALL_PREFIX=\"$ffmpeg_kit_install\" \
-DFFMPEG_KIT_BUNDLE_TYPE=\"$(get_bundle_type)\" \
-DFFMPEG_KIT_VERSION=\"$(get_latest_version_from_changelog)\""

	if [[ "$build_ffmpeg_kit_type" == "static" ]]; then
		cmake_params+=" -DBUILD_SHARED_LIBS=OFF -DBUILD_STATIC_LIBS=ON"
	else
		cmake_params+=" -DBUILD_SHARED_LIBS=ON -DBUILD_STATIC_LIBS=OFF"
	fi

	if truthy "$build_tests"; then
		cmake_params+=" -DBUILD_TESTS=ON"
	else
		cmake_params+=" -DBUILD_TESTS=OFF"
	fi

	if truthy "$enable_libplacebo"; then
    	cmake_params+=" -DENABLE_LIBPLACEBO=ON"
	else
    	cmake_params+=" -DENABLE_LIBPLACEBO=OFF"
	fi

	if truthy "$do_debug_build"; then
		cmake_params+=" -DCMAKE_BUILD_TYPE=Debug"
		CFLAGS+=" -g -fno-omit-frame-pointer -ggdb"
		CXXFLAGS+=" -g -fno-omit-frame-pointer -ggdb -D_GLIBCXX_DEBUG"
	else
		cmake_params+=" -DCMAKE_BUILD_TYPE=Release"
	fi

	change_dir "${ffmpeg_kit_src_dir}"
	
	change_dir "${ffmpeg_kit_src_dir}/build" 1
	
	do_cmake "$cmake_params" "$ffmpeg_kit_src_dir" "${type_postfix}" 1

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
Description: FFmpeg for applications on Android
Version: ${kit_version}

# Public dependencies that have their own .pc files
Requires: libavfilter, libswscale, libavformat, libavcodec, libswresample, libavutil

# Linker flags for the ffmpeg-kit library itself (includes jsoncpp if static)
Libs: -L\${libdir} -lffmpegkit

# Private dependencies needed for linking on Android
Libs.private: -lstdc++ -lws2_32 -lpsapi -lole32 -lshlwapi -lgdi32 -lbcrypt -luser32 -luuid -ljsoncpp

# Compiler flags for the ffmpeg-kit headers (includes jsoncpp headers if bundled)
Cflags: -I\${includedir}
EOF
}

# 1. variant
# @. custom values
# Usage: get_generic_cmake_toolchain [variant_suffix] [VAR="VALUE" ...]
get_generic_cmake_toolchain() {
		local variant="$1"
		local toolchain_filename="$host_name-toolchain.cmake"
		[[ -n "$variant" ]] && toolchain_filename="$host_name-toolchain-$variant.cmake"
		local toolchain_path="$src_dir/$toolchain_filename"
		[[ -n "$variant" ]] && toolchain_path="$(pwd)/$toolchain_filename"
		shift

		if [[ ! -e "$toolchain_path" ]]; then
				local abi="x86_64"
				case "$host_arch" in
						"x86_64") abi="x86_64" ;;
						"i686")   abi="x86" ;;
						"aarch64") abi="arm64-v8a" ;;
						"armv7a") abi="armeabi-v7a" ;;
				esac

				cat > "$toolchain_path" <<EOF
set(CMAKE_SYSTEM_NAME Android)
set(CMAKE_SYSTEM_VERSION $ANDROID_API_LEVEL)
set(CMAKE_ANDROID_ARCH_ABI $abi)
set(CMAKE_ANDROID_NDK $ANDROID_NDK_ROOT)
set(CMAKE_C_COMPILER $CC)
set(CMAKE_CXX_COMPILER $CXX)
set(CMAKE_AR $AR)
set(CMAKE_RANLIB $RANLIB)
set(CMAKE_STRIP $STRIP)
set(CMAKE_FIND_ROOT_PATH $dependency_install_prefix)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_C_FLAGS_INIT "-fPIC -D__ANDROID_API__=$ANDROID_API_LEVEL")
set(CMAKE_CXX_FLAGS_INIT "-fPIC -D__ANDROID_API__=$ANDROID_API_LEVEL")
EOF
				# Loop through remaining args in format KEY="VALUE"
				for arg in "$@"; do
						local key="${arg%%=*}"
						local value="${arg#*=}"
						echo "set($key \"$value\")" >> "$toolchain_path"
				done
		fi
		echo "$toolchain_path"
}

get_generic_meson_cross_file() {
	local variant_name="$1"      # e.g., "librist"
	local extra_content="$2"     # e.g., "[built-in options]..."
	local base_filename="$host_name-meson-cross.android.txt"
	local base_filepath="$src_dir/$base_filename"
	# 1. Generate the BASE file if it doesn't exist (Android Logic)
	local cpu_family="$host_arch"
	case "$host_arch" in
			"armv7a"|"arm") cpu_family="arm" ;;
			"i686"|"x86")   cpu_family="x86" ;;
	esac
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
c = '$CC'
cpp = '$CXX'
ld = '$LD'
ar = '$AR'
strip = '$STRIP'
nm = '$NM'
ranlib = '$RANLIB'
pkg-config = 'pkg-config'
cmake = 'cmake'

[host_machine]
system = 'android'
cpu_family = '$cpu_family'
cpu = '$host_arch'
endian = 'little'

[properties]
pkg_config_libdir = '$dependency_install_prefix/lib/pkgconfig'
needs_exe_wrapper = true
EOF
	# 2. Handle Custom Variant logic
	if [[ -n "$variant_name" ]]; then
			local custom_filepath="$(pwd)/$host_name-meson-cross.android.${variant_name}.txt"
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
