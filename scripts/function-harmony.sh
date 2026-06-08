#!/bin/bash

# shellcheck disable=SC2317,SC2129,SC1091,SC2120,SC2035,SC2016,SC2310,SC2155,SC2154,SC2034,2312,2250,2292,2249

# OpenHarmony / HarmonyOS platform functions.
# Mirror of scripts/function-android.sh — Harmony shares the cross-compile
# model (clang + sysroot + custom triple) with Android NDK.

set_toolchain_paths() {
	export PATH="${PATH}:${toolchain_bin_path}:${dependency_install_prefix}/bin"
	export CC="$CC"
	export CXX="$CXX"
	export AR="$AR"
	export AS="$AS"
	export NM="$NM"
	export RANLIB="$RANLIB"
	export STRIP="$STRIP"
	export LD="$CC"
}

configure_ffmpeg_kit() {
	echo -e "INFO: Configuring ffmpeg kit" | tee -a "$LOG_FILE"
	local type_postfix="$build_ffmpeg_kit_type"

	if truthy "$build_force"; then
		remove_path -rf "$ffmpeg_kit_src_dir/build"
		remove_path -rf "$ffmpeg_kit_src_dir"/already_configured_*
		remove_path -rf "$ffmpeg_kit_install"
	fi

	create_dir "$ffmpeg_kit_install"

	export PKG_CONFIG_LIBDIR="${install_pkgconfig_dir}:${ffmpeg_install_prefix}/lib/pkgconfig"
	export PKG_CONFIG_SYSROOT_DIR="/"
	set_toolchain_paths

	reset_allflags
	local local_cflags="${CFLAGS} -I${ffmpeg_install_prefix}/include -L${ffmpeg_install_prefix}/lib -I${ffmpeg_source_dir} -I${ffmpeg_source_dir}/compat"
	local local_cxxflags="${CXXFLAGS} -I${ffmpeg_install_prefix}/include -L${ffmpeg_install_prefix}/lib -I${ffmpeg_source_dir} -I${ffmpeg_source_dir}/compat"

	change_dir "${ffmpeg_kit_src_dir}"
	make distclean > >(redirect_output) 2>&1

	export CFLAGS="${local_cflags}"
	export CXXFLAGS="${local_cxxflags}"
	export LDFLAGS="${LDFLAGS} -Wl,--allow-multiple-definition"
	export LDFLAGS="${LDFLAGS//-static /} -L${ffmpeg_install_prefix}/lib -L${dependency_install_prefix}/lib"

	local ohos_toolchain
	ohos_toolchain="$(get_generic_cmake_toolchain)"

	local cmake_params="-DCMAKE_SYSTEM_NAME=OHOS \
-DCMAKE_TOOLCHAIN_FILE=${ohos_toolchain} \
-DOHOS_PLATFORM=OHOS \
-DOHOS_ARCH=${ohos_abi} \
-DOHOS_STL=c++_static \
-DCMAKE_EXE_LINKER_FLAGS_INIT=\"-L${ffmpeg_install_prefix}/lib -L${dependency_install_prefix}/lib\" \
-DCMAKE_SHARED_LINKER_FLAGS_INIT=\"-L${ffmpeg_install_prefix}/lib -L${dependency_install_prefix}/lib\" \
-DCMAKE_MODULE_LINKER_FLAGS_INIT=\"-L${ffmpeg_install_prefix}/lib -L${dependency_install_prefix}/lib\" \
-DFFMPEG_SRC_DIR=\"$ffmpeg_source_dir\" \
-DFFMPEG_BUILD_DIR=\"$ffmpeg_install_prefix\" \
-DCMAKE_INSTALL_PREFIX=\"$ffmpeg_kit_install\" \
-DFFMPEG_KIT_BUNDLE_TYPE=\"$(get_bundle_type)\" \
-DCMAKE_SHARED_LINKER_FLAGS=\"-Wl,--allow-multiple-definition\" \
-DCMAKE_FIND_LIBRARY_SUFFIXES=\".a;.so\" \
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

	truthy "$enable_libplacebo" && cmake_params+=" -DENABLE_LIBPLACEBO=ON"

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

# OpenHarmony ships an official CMake toolchain at
# $OHOS_SDK_HOME/build/cmake/ohos.toolchain.cmake. We wrap it in a small
# shim that adds the dependency install prefix to CMAKE_FIND_ROOT_PATH and
# pins CMAKE_AR / CMAKE_RANLIB to the SDK's llvm tools (matching the
# environment exported by setup_harmony_environment).
get_generic_cmake_toolchain() {
	local variant="$1"
	local toolchain_filename="$host_name-toolchain.cmake"
	[[ -n "$variant" ]] && toolchain_filename="$host_name-toolchain-$variant.cmake"
	local toolchain_path="$src_dir/$toolchain_filename"
	[[ -n "$variant" ]] && toolchain_path="$(pwd)/$toolchain_filename"
	shift

	if [[ ! -e "$toolchain_path" ]]; then
		cat >"$toolchain_path" <<EOF
# OpenHarmony CMake toolchain shim. Delegates to the SDK's official
# ohos.toolchain.cmake and layers our dependency-install prefix on top.
set(OHOS TRUE)
set(OHOS_PLATFORM OHOS)
set(OHOS_ARCH ${ohos_abi})
set(OHOS_STL c++_static)

include("$OHOS_SDK_HOME/build/cmake/ohos.toolchain.cmake")

set(CMAKE_FIND_ROOT_PATH "$dependency_install_prefix" "$OHOS_SDK_HOME/sysroot")
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY BOTH)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE BOTH)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE BOTH)

set(CMAKE_C_FLAGS_INIT "-fPIC")
set(CMAKE_CXX_FLAGS_INIT "-fPIC")

set(CMAKE_AR "$AR" CACHE FILEPATH "Archiver")
set(CMAKE_RANLIB "$RANLIB" CACHE FILEPATH "Ranlib")
set(CMAKE_STRIP "$STRIP" CACHE FILEPATH "Strip")
EOF
		for arg in "$@"; do
			local key="${arg%%=*}"
			local value="${arg#*=}"
			echo "set($key \"$value\")" >>"$toolchain_path"
		done
	fi
	echo "$toolchain_path"
}

get_generic_meson_cross_file() {
	local variant_name="$1"
	local extra_content="$2"
	local base_filename="$host_name-meson-cross.harmony.txt"
	local base_filepath="$src_dir/$base_filename"
	local cpu_family="$host_arch"
	case "$host_arch" in
		"armv7a" | "arm") cpu_family="arm" ;;
		"i686" | "x86") cpu_family="x86" ;;
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
system = 'linux'
cpu_family = '$cpu_family'
cpu = '$host_arch'
endian = 'little'

[properties]
pkg_config_libdir = '$dependency_install_prefix/lib/pkgconfig'
needs_exe_wrapper = true
sys_root = '$SYSROOT'
EOF
	if [[ -n "$variant_name" ]]; then
		local custom_filepath="$(pwd)/$host_name-meson-cross.harmony.${variant_name}.txt"
		cp "$base_filepath" "$custom_filepath" 2>"$LOG_FILE"
		if [[ -n "$extra_content" ]]; then
			echo "" >>"$custom_filepath"
			echo -e "$extra_content" >>"$custom_filepath"
		fi
		echo "$custom_filepath"
	else
		echo "$base_filepath"
	fi
}

fix_pkgconfig_flags() {
	echo "INFO: Fixing pkgconfig files for OpenHarmony in $install_pkgconfig_dir"
	find "$install_pkgconfig_dir" -name "*.pc" -exec sed -i -E \
		-e 's/(^|[[:space:]])-lrt([[:space:]]|$)/ /g' \
		-e 's/(^|[[:space:]])-lpthread([[:space:]]|$)/ -pthread /g' \
		-e 's/(^|[[:space:]])-l([[:space:]]|$)/ /g' "{}" + \
		2>>"$LOG_FILE"
	find "$dependency_install_prefix/lib" -name "*.la*" -delete
}

ffmpeg_patches() {
	if isharmony; then
		echo "INFO: No OpenHarmony-specific FFmpeg patches required at this stage." >>"$LOG_FILE"
	fi
}
