#!/bin/bash

# shellcheck disable=SC2317,SC2129,SC1091,SC2120,SC2035,SC2016,SC2310,SC2155,SC2154,SC2034,2250,2249,2312,2292

get_common_cflags() {
  if [[ -n ${FFMPEG_KIT_LTS_BUILD} ]]; then
    case $1 in
    ffmpeg-kit)
      echo "${linux_cflags} ${LLVM_CONFIG_CFLAGS}"
      ;;
    *)
      echo "${linux_cflags} ${LLVM_CONFIG_CFLAGS}"
      ;;
    esac
  fi
}

get_common_cxxflags() {
  echo "$linux_cxxflags"
}

get_size_optimization_cflags() {
  local ARCH_OPTIMIZATION=""
  case $host_arch in
  x86_64)
    case $1 in
    ffmpeg)
      ARCH_OPTIMIZATION="-flto -Os -ffunction-sections -fdata-sections"
      ;;
    *)
      ARCH_OPTIMIZATION="-Os -ffunction-sections -fdata-sections"
      ;;
    esac
    ;;
  esac

  local LIB_OPTIMIZATION=""

  echo "${ARCH_OPTIMIZATION} ${LIB_OPTIMIZATION}"
}

get_size_optimization_ldflags() {
  case $host_arch in
  x86_64)
    case $1 in
    ffmpeg)
      echo "-flto -O2 -ffunction-sections -fdata-sections -finline-functions"
      ;;
    *)
      echo "-Os -ffunction-sections -fdata-sections"
      ;;
    esac
    ;;
  esac
}

get_arch_specific_cflags() {
  local ARCH_FLAGS=""
  case $host_arch in
  x86_64)
    ARCH_FLAGS="-march=x86-64 -msse4.2 -mpopcnt -m64 -DFFMPEG_KIT_X86_64"
    ;;
  esac
  echo "$ARCH_FLAGS"
}

get_arch_specific_ldflags() {
  case $host_arch in
  x86_64)
    echo "-march=x86-64 -Wl,-z,text"
    ;;
  esac
}

get_common_linked_libraries() {
  case $1 in
  ffmpeg-kit)
    echo "-lc -lm"
    ;;
  *)
    echo "-lc -lm -ldl"
    ;;
  esac
}

get_cflags() {
  local ARCH_FLAGS="$(get_arch_specific_cflags)"
  local APP_FLAGS=""
  case $1 in
  ffmpeg)
    APP_FLAGS="-Wno-unused-function"
    ;;
  ffmpeg-kit)
    APP_FLAGS="-Wno-unused-function -Wno-pointer-sign -Wno-switch -Wno-deprecated-declarations"
    ;;
  *)
    APP_FLAGS="-std=c99 -Wno-unused-function"
    ;;
  esac
  local COMMON_FLAGS="$(get_common_cflags)"

  if [[ -z ${FFMPEG_KIT_DEBUG} ]]; then
    local OPTIMIZATION_FLAGS=$(get_size_optimization_cflags "$1")
  else
    local OPTIMIZATION_FLAGS="${FFMPEG_KIT_DEBUG}"
  fi
  local COMMON_INCLUDES=$LLVM_CONFIG_INCLUDEDIR

  echo "${ARCH_FLAGS} ${APP_FLAGS} ${COMMON_FLAGS} ${OPTIMIZATION_FLAGS} ${COMMON_INCLUDES} -DFFMPEG_DATADIR=${ffmpeg_install_prefix}/\$(datadir)/ffmpeg"
}

get_cxxflags() {
  local ARCH_FLAGS="$(get_arch_specific_cflags)"

  if truthy "$do_debug_build"; then
    local OPTIMIZATION_FLAGS="-g"
  else
    local OPTIMIZATION_FLAGS="-Os -ffunction-sections -fdata-sections"
  fi

  local COMMON_FLAGS="$(get_common_cxxflags) ${OPTIMIZATION_FLAGS} $ARCH_FLAGS "

  case $1 in
  ffmpeg)
    if truthy "$do_debug_build"; then
      echo " -g $(get_common_cxxflags)"
    else
      echo " -flto $(get_common_cxxflags) -O2 -ffunction-sections -fdata-sections"
    fi
    ;;
  ffmpeg-kit)
    echo "${COMMON_FLAGS}"
    ;;
  *)
    echo "${COMMON_FLAGS} -fno-exceptions -fno-rtti"
    ;;
  esac
}

get_ldflags() {
  local ARCH_FLAGS=$(get_arch_specific_ldflags)
  if [[ -z ${FFMPEG_KIT_DEBUG} ]]; then
    local OPTIMIZATION_FLAGS="$(get_size_optimization_ldflags "$1")"
  else
    local OPTIMIZATION_FLAGS="${FFMPEG_KIT_DEBUG}"
  fi
  local COMMON_LINKED_LIBS=$(get_common_linked_libraries "$1")

  echo "${ARCH_FLAGS} ${OPTIMIZATION_FLAGS} ${COMMON_LINKED_LIBS} ${LLVM_CONFIG_LDFLAGS} -Wl,--hash-style=both"
}

configure_ffmpeg_kit() {
  echo -e "INFO: Configuring ffmpeg kit" | tee -a "$LOG_FILE"
  reset_allflags
  set_toolchain_paths
  
	local type_postfix="$build_ffmpeg_kit_type"

	if truthy "$build_force"; then
		remove_path -rf "$ffmpeg_kit_src_dir"/already_configured_*
		remove_path -rf "$ffmpeg_kit_install"
	fi

	create_dir "$ffmpeg_kit_install"

	export PKG_CONFIG_PATH="${PKG_CONFIG_PATH}:${ffmpeg_install_prefix}/lib/pkgconfig"

  export CFLAGS="$CFLAGS"
  export CXXFLAGS="$CXXFLAGS"
  export LDFLAGS="$LDFLAGS"

	change_dir "${ffmpeg_kit_src_dir}"
	make distclean > >(redirect_output) 2>&1

  local cmake_params="-DCMAKE_SYSTEM_NAME=Linux \
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

	truthy "$enable_libplacebo" && cmake_params+=" -DENABLE_LIBPLACEBO=ON"
  truthy "$enable_libtensorflow" && cmake_params+=" -DENABLE_LIBTENSORFLOW=ON"
  truthy "$enable_libopenvino" && cmake_params+=" -DENABLE_OPENVINO=ON"
  truthy "$enable_libtorch" && cmake_params+=" -DENABLE_LIBTORCH=ON"

	if truthy "$do_debug_build"; then
		cmake_params+=" -DCMAKE_BUILD_TYPE=Debug"
    CFLAGS+=" -Og -fno-omit-frame-pointer -ggdb"
    CXXFLAGS+=" -Og -fno-omit-frame-pointer -ggdb -D_GLIBCXX_DEBUG"
    case "$test_type" in
      tsan)
        CFLAGS+=" -fsanitize=thread"
        CXXFLAGS+=" -fsanitize=thread"
        LDFLAGS+=" -fsanitize=thread"
        ;;
      asan)
        CFLAGS+=" -fsanitize=address"
        CXXFLAGS+=" -fsanitize=address"
        LDFLAGS+=" -fsanitize=address"
        ;;
      undefined)
        CFLAGS+=" -fsanitize=undefined"
        CXXFLAGS+=" -fsanitize=undefined"
        LDFLAGS+=" -fsanitize=undefined"
        ;;
    esac
	else
		cmake_params+=" -DCMAKE_BUILD_TYPE=Release"
	fi

	change_dir "${ffmpeg_kit_src_dir}/build" 1
  
  do_cmake "$cmake_params" "$ffmpeg_kit_src_dir" "${type_postfix}" 1

	echo -e "INFO: Done configuring ffmpeg kit" | tee -a "$LOG_FILE"
}

detect_clang_version() {
  # shellcheck disable=2046,2005
  echo $(clang -v 2>&1 | grep -oP 'Ubuntu clang version \K\d+\.\d+\.\d+' | cut -d. -f1)
}

set_toolchain_paths() {
  export CC="$(xcrun --sdk macosx --find clang)"
  export CXX="$(xcrun --sdk macosx --find clang++)"
  export AR="$(xcrun --sdk macosx --find ar)"
  export AS="$(xcrun --sdk macosx --find as)"
  export RANLIB="$(xcrun --sdk macosx --find ranlib)"
  export LD="$(xcrun --sdk macosx --find ld)"
  export STRIP="$(xcrun --sdk macosx --find strip)"
  export NM="$(xcrun --sdk macosx --find nm)"
  export CFLAGS="$CFLAGS -I${ffmpeg_source_dir} -I${ffmpeg_source_dir}/compat"
  export CXXFLAGS="$CXXFLAGS -I${ffmpeg_source_dir} -I${ffmpeg_source_dir}/compat"
  export LDFLAGS="$LDFLAGS -ljsoncpp -L${ffmpeg_install_prefix}/lib"
}

ffmpeg_patches() {
	if ismacos; then
		echo "INFO: Patching ffmpeg for macOS quirks..." >>"$LOG_FILE"
    if truthy "$enable_vulkan"; then
      sed -i'.bak' '/#include <SDL_vulkan.h>/a\
#include "libavutil/hwcontext.h"\
#include "libavutil/hwcontext_vulkan.h"' "$ffmpeg_source_dir/fftools/ffplay_renderer.c"
    fi
		echo "INFO: Done patching ffmpeg for macOS quirks." >>"$LOG_FILE"
	fi
}


get_generic_meson_cross_file() {
	local variant_name="$1"      # e.g., "librist"
	local extra_content="$2"     # e.g., "[built-in options]..."
	local base_filename="$host_name-meson-cross.mingw.txt"
	local base_filepath="$src_dir/$base_filename"
	# 1. Generate the BASE file if it doesn't exist (Standard Logic)
	local cpu_family="x86_64"
	if [ "$bits_target" = 32 ]; then
			cpu_family="x86"
	fi
	cat >"$base_filepath" <<EOF
[binaries]
c = '$CC'
cpp = '$CXX'
ld = '$LD'
ar = '$AR'
strip = '$STRIP'
nm = '$NM'
objc = '$CC'
objcpp = '$CXX'
pkgconfig = 'pkg-config'

[built-in options]
buildtype = 'release'
wrap_mode = 'nofallback'
default_library = 'static'
prefer_static = true
backend = 'ninja'
b_lto = false
b_staticpic = true
c_args = ['-I${dependency_install_prefix}/include', '-arch', 'x86_64', '-isysroot', '${SDKROOT}']
c_link_args = ['-L${dependency_install_prefix}/lib', '-arch', 'x86_64', '-isysroot', '${SDKROOT}']
cpp_args = ['-I${dependency_install_prefix}/include', '-arch', 'x86_64', '-DGLIB_STATIC_COMPILATION', '-isysroot', '${SDKROOT}']
cpp_link_args = ['-L${dependency_install_prefix}/lib', '-arch', 'x86_64', '-DGLIB_STATIC_COMPILATION', '-isysroot', '${SDKROOT}']
prefix = '$dependency_install_prefix'
libdir = '$dependency_install_prefix/lib'
pkg_config_path = '$PKG_CONFIG_PATH'

[host_machine]
system = 'darwin'
cpu_family = 'x86_64'
cpu = 'x86_64'
endian = 'little'

EOF
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