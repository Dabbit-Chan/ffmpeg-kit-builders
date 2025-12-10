#!/bin/bash

# shellcheck disable=SC2317,SC1091,SC1090,SC2120

get_common_cflags() {
  if [[ -n ${FFMPEG_KIT_LTS_BUILD} ]]; then
    case $1 in
    ffmpeg-kit)
      echo "${linux_cflags} -DFFMPEG_KIT_LTS ${LLVM_CONFIG_CFLAGS}"
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
  if truthy "$enable_lto"; then
    local LINK_TIME_OPTIMIZATION_FLAGS="-flto"
  else
    local LINK_TIME_OPTIMIZATION_FLAGS=""
  fi

  local ARCH_OPTIMIZATION=""
  case $host_arch in
  x86_64)
    case $1 in
    ffmpeg)
      ARCH_OPTIMIZATION="${LINK_TIME_OPTIMIZATION_FLAGS} -Os -ffunction-sections -fdata-sections"
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
  if truthy "$enable_lto"; then
    local LINK_TIME_OPTIMIZATION_FLAGS="-flto"
  else
    local LINK_TIME_OPTIMIZATION_FLAGS=""
  fi

  case $host_arch in
  x86_64)
    case $1 in
    ffmpeg)
      echo "${LINK_TIME_OPTIMIZATION_FLAGS} -O2 -ffunction-sections -fdata-sections -finline-functions"
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

  echo "${ARCH_FLAGS} ${APP_FLAGS} ${COMMON_FLAGS} ${OPTIMIZATION_FLAGS} ${COMMON_INCLUDES}"
}

get_cxxflags() {
  local ARCH_FLAGS="$(get_arch_specific_cflags)"
  if truthy "$enable_lto"; then
    local LINK_TIME_OPTIMIZATION_FLAGS="-flto"
  else
    local LINK_TIME_OPTIMIZATION_FLAGS=""
  fi

  if truthy "$do_debug_build"; then
    local OPTIMIZATION_FLAGS="-g"
  else
    local OPTIMIZATION_FLAGS="-Os -ffunction-sections -fdata-sections"
  fi

  local BUILD_DATE="-DFFMPEG_KIT_BUILD_DATE=$(date +%Y%m%d 2>>"${BASEDIR}"/build.log)"
  local COMMON_FLAGS="$(get_common_cxxflags) ${OPTIMIZATION_FLAGS} ${BUILD_DATE} $ARCH_FLAGS"

  case $1 in
  ffmpeg)
    if truthy "$do_debug_build"; then
      echo "-g $(get_common_cxxflags)"
    else
      echo "${LINK_TIME_OPTIMIZATION_FLAGS} $(get_common_cxxflags) -O2 -ffunction-sections -fdata-sections"
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
  reset_cflags
	reset_cppflags
  set_toolchain_paths
  
	local TYPE_POSTFIX="$(get_build_type)"
	local FFMPEG_KIT_VERSION=$(get_ffmpeg_kit_version)

	if truthy "$build_force"; then
		remove_path -rf "$ffmpeg_kit_src_dir"/already_configured_*
		remove_path -rf "$ffmpeg_kit_install"
	fi

	create_dir "$ffmpeg_kit_install"

	export PKG_CONFIG_PATH="${PKG_CONFIG_PATH}:${ffmpeg_install_prefix}/lib/pkgconfig"

	change_dir "${ffmpeg_kit_src_dir}"
	make distclean > >(redirect_output) 2>&1

	local touch_name=$(get_small_touchfile_name "already_autoreconf_${TYPE_POSTFIX}" "$FFMPEG_KIT_VERSION $CFLAGS $CXXFLAGS")
	if [ ! -f "$touch_name" ]; then
		remove_path -f "${ffmpeg_kit_src_dir}/already_autoreconf_${TYPE_POSTFIX}"*
		change_dir "${ffmpeg_kit_src_dir}"
		autoreconf_library "ffmpeg-kit" || exit_message 1 "could not autoreconf ffmpeg-kit. See $LOG_FILE for details."
		create_touch_file 0 "$touch_name"
	fi

	local config_options="--prefix=${ffmpeg_kit_install}"

	config_options+=" --host=${host_target}"
	if truthy "$build_ffmpeg_static"; then
		config_options+=" --enable-static"
		config_options+=" --disable-shared"
	else
		config_options+=" --enable-shared"
		config_options+=" --disable-static"
	fi
	change_dir "${ffmpeg_kit_src_dir}"
	do_configure "${config_options}" "./configure" "${TYPE_POSTFIX}" || exit_message 1 "unable to configure ffmpeg-kit. see $LOG_FILE for details."

	echo -e "INFO: Done configuring ffmpeg kit" | tee -a "$LOG_FILE"
}

create_ffmpegkit_package_config() {
  local FFMPEGKIT_VERSION="$1"

  cat >"${install_pkgconfig_dir}/ffmpeg-kit.pc" <<EOF
prefix=${ffmpeg_kit_install}/ffmpeg-kit
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: ffmpeg-kit
Description: FFmpeg for applications
Version: ${FFMPEGKIT_VERSION}

Libs: -L\${libdir} -lstdc++ -lffmpegkit -lavutil
Requires: libavfilter, libswscale, libavformat, libavcodec, libswresample, libavutil
Cflags: -I\${includedir}
EOF
}

detect_clang_version() {
  # shellcheck disable=2046,2005
  echo $(clang -v 2>&1 | grep -oP 'Ubuntu clang version \K\d+\.\d+\.\d+' | cut -d. -f1)
}

set_toolchain_paths() {
  clang_version=$(detect_clang_version)

  if [[ $clang_version != "none" ]]; then
    local CLANG_POSTFIX="-$clang_version"
    export LLVM_CONFIG_CFLAGS=$(llvm-config-"$clang_version" --cflags 2>>"$LOG_FILE")
    export LLVM_CONFIG_INCLUDEDIR=$(llvm-config-"$clang_version" --includedir 2>>"$LOG_FILE")
    export LLVM_CONFIG_LDFLAGS=$(llvm-config-"$clang_version" --ldflags 2>>"$LOG_FILE")
  else
    local CLANG_POSTFIX=""
    export LLVM_CONFIG_CFLAGS=$(llvm-config --cflags 2>>"$LOG_FILE")
    export LLVM_CONFIG_INCLUDEDIR=$(llvm-config --includedir 2>>"$LOG_FILE")
    export LLVM_CONFIG_LDFLAGS=$(llvm-config --ldflags 2>>"$LOG_FILE")
  fi

  export CC=$(command -v "clang$CLANG_POSTFIX")
  export CXX=$(command -v "clang++$CLANG_POSTFIX")
  export AS=$(command -v "llvm-as$CLANG_POSTFIX")
  export AR=$(command -v "llvm-ar$CLANG_POSTFIX")
  export LD=$(command -v "ld.lld$CLANG_POSTFIX")
  export RANLIB=$(command -v "llvm-ranlib$CLANG_POSTFIX")
  export STRIP=$(command -v "llvm-strip$CLANG_POSTFIX")
  export NM=$(command -v "llvm-nm$CLANG_POSTFIX")
  export CFLAGS="$CFLAGS $(get_cflags "ffmpeg-kit") -I${ffmpeg_install_prefix}/include -I${dependency_install_prefix}/include -I${ffmpeg_source_dir} -I${ffmpeg_source_dir}/compat"
  export CXXFLAGS=" $CXXFLAGS $(get_cxxflags "ffmpeg-kit") -I${ffmpeg_install_prefix}/include -I${dependency_install_prefix}/include -I${ffmpeg_source_dir} -I${ffmpeg_source_dir}/compat"
  export LDFLAGS="$LDFLAGS $(get_ldflags "ffmpeg-kit") -L${ffmpeg_install_prefix}/lib -L${dependency_install_prefix}/lib -L${dependency_install_prefix}/lib/$host_target"
}