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

check_audiotoolbox() {
	# if [[ "$non_free" = "y" ]]; then
	#   build_fdk-aac # Uses dlfcn.
	#   build_AudioToolboxWrapper # This wrapper library enables FFmpeg to use AudioToolbox codecs on Windows, with DLLs shipped with iTunes.
	build_libdecklink # Error finding rpc.h in native builds even if it's available
	#fi
}

print_progress() {
	local current_step=$1
	local steps=$2
	local step_name=$3
	percent=$((current_step * 100 / steps))
	bars=$((percent * 40 / 100))

	bar_str=""
	for ((j = 0; j < bars; j++)); do bar_str="${bar_str}█"; done
	for ((j = bars; j < 40; j++)); do bar_str="${bar_str} "; done

	printf "\r\033[K[%s] %3d%% (%2d/%2d) | %s" "$bar_str" "$percent" "$current_step" "$steps" "$step_name"
}

build_all_ffmpeg_dependencies() {
	local start_from=$1
	local skip_mode=false
	# Create a clean array without empty elements
	local steps=0
	local current_step=0

	# Count non-empty steps first
	for step_name in "${BUILD_STEPS[@]}"; do
		if [[ -n "${step_name// /}" ]]; then
			((steps++))
		fi
	done

	# If start_from is empty, start from beginning
	if [[ -z "$start_from" ]]; then
		skip_mode=false
	else
		echo "INFO: Starting from step: $start_from" | tee -a "$LOG_FILE"
		skip_mode=true
	fi

	for step_name in "${BUILD_STEPS[@]}"; do
		if [[ -z "${step_name// /}" ]]; then
			continue
		fi
		# Handle skip mode
		if [[ "$skip_mode" == true ]]; then
			if [[ "$step_name" == "$start_from" ]]; then
				skip_mode=false
				echo "INFO: Building dependencies from: $step_name" | tee -a "$LOG_FILE"
			else
				((current_step++))
				continue
			fi
		fi
		((current_step++))
		print_progress "$current_step" "$steps" "$step_name"
		# percent=$((current_step * 100 / steps))
		# bars=$((percent * 40 / 100))

		# bar_str=""
		# for ((j = 0; j < bars; j++)); do bar_str="${bar_str}█"; done
		# for ((j = bars; j < 40; j++)); do bar_str="${bar_str} "; done

		# printf "\r\033[K[%s] %3d%% (%2d/%2d) | %s" "$bar_str" "$percent" "$current_step" "$steps" "$step_name"

		build_ffmpeg_dependency_only "$step_name" || echo | tee -a "$LOG_FILE"
	done
	printf "\r\033[KAll dependencies built successfully!\n"
}

build_ffmpeg_dependency_only() {
	step=$1
	if [[ -n "$step" ]]; then
		change_dir "$src_dir"
		if declare -F "$step" >/dev/null; then
			echo -e "\nINFO: --- Executing step: $step ---\n" | tee -a "$LOG_FILE"
			"$step" # Execute the function
			echo -e "\nINFO: --- Finished executing step: $step ---\n" | tee -a "$LOG_FILE"
		else
			echo -e "ERROR: Function '$step' not found." | tee -a "$LOG_FILE"
			return 1 # Indicate an error
		fi
	else
		echo -e "ERROR: Step argument is missing." | tee -a "$LOG_FILE"
		return 1 # Indicate an error
	fi
}

build_apps() {
	if [[ $build_dvbtee = "y" ]]; then
		build_dvbtee_app
	fi
	# now the things that use the dependencies...
	if [[ $build_libmxf = "y" ]]; then
		build_libMXF
	fi
	if [[ $build_mp4box = "y" ]]; then
		build_mp4box
	fi
	if [[ $build_mplayer = "y" ]]; then
		build_mplayer
	fi
	if [[ $build_ffmpeg_static = "y" ]]; then
		build_ffmpeg static
	fi
	if [[ $build_ffmpeg_shared = "y" ]]; then
		build_ffmpeg shared
	fi
	if [[ $build_vlc = "y" ]]; then
		build_vlc
	fi
	if [[ $build_lsw = "y" ]]; then
		build_lsw
	fi
}

# This new function centralizes the setup for each build target.
setup_build_environment() {
	compiler_flavors="$1"
	if [[ -z $compiler_flavors ]]; then
		pick_compiler_flavors
	fi
	target_platform=windows
	export target_platform
	echo -e "\n************** Setting up environment for $compiler_flavors build... **************" | tee -a "$LOG_FILE"
	if [[ $compiler_flavors == "win32" ]]; then
		export ARCH=$(get_arch_name "$(from_arch_name "$compiler_flavors")")
		export FULL_ARCH="i686"
		export target_name="$target_platform-$FULL_ARCH"
		export work_dir="$(realpath "$WORKDIR"/"$target_name")"
		export host_target="$FULL_ARCH-w64-mingw32"
		export toolchain_root="mingw-w64-$FULL_ARCH"
		export mingw_w64_x86_64_prefix="$(realpath "$work_dir/cross_compilers/$toolchain_root/$host_target")"
		export toolchain_root_dir="$(realpath "$work_dir/cross_compilers/$toolchain_root")"
		export mingw_bin_path="$(realpath "$toolchain_root_dir"/bin)"
		export PKG_CONFIG_PATH="$mingw_w64_x86_64_prefix/lib/pkgconfig"
		export PATH="$mingw_bin_path:$original_path"
		export bits_target=32
		export cross_prefix="$mingw_bin_path/$host_target-"
		export compiler_flags="CC=${cross_prefix}gcc \
AR=${cross_prefix}ar \
AS=${cross_prefix}as \
PREFIX=$mingw_w64_x86_64_prefix \
RANLIB=${cross_prefix}ranlib \
LD=${cross_prefix}ld \
STRIP=${cross_prefix}strip \
CXX=${cross_prefix}g++"
	elif [[ $compiler_flavors == "win64" ]]; then
		export ARCH=$(get_arch_name "$(from_arch_name "$compiler_flavors")")
		export FULL_ARCH="x86_64"
		export target_name="$target_platform-$FULL_ARCH"
		export work_dir="$(realpath "$WORKDIR"/"$target_name")"
		export host_target="$FULL_ARCH-w64-mingw32"
		export toolchain_root="mingw-w64-$FULL_ARCH"
		export mingw_w64_x86_64_prefix="$(realpath "$work_dir/cross_compilers/$toolchain_root/$host_target")"
		export toolchain_root_dir="$(realpath "$work_dir/cross_compilers/$toolchain_root")"
		export mingw_bin_path="$(realpath "$toolchain_root_dir"/bin)"
		export PKG_CONFIG_PATH="$mingw_w64_x86_64_prefix/lib/pkgconfig"
		export PATH="$mingw_bin_path:$original_path"
		export bits_target=64
		export cross_prefix="$mingw_bin_path/$host_target-"
		export compiler_flags="CC=${cross_prefix}gcc \
AR=${cross_prefix}ar \
AS=${cross_prefix}as \
PREFIX=$mingw_w64_x86_64_prefix \
RANLIB=${cross_prefix}ranlib \
LD=${cross_prefix}ld \
STRIP=${cross_prefix}strip \
CXX=${cross_prefix}g++"
	else
		exit_message 1 "Unknown compiler flavor '$compiler_flavors'"
	fi
	export make_prefix_options="--cc=${cross_prefix}gcc \
--ar=$(realpath "${cross_prefix}"ar) \
--as=$(realpath "${cross_prefix}"as) \
--nm=$(realpath "${cross_prefix}"nm) \
--ranlib=$(realpath "${cross_prefix}"ranlib) \
--ld=$(realpath "${cross_prefix}"ld) \
--strip=$(realpath "${cross_prefix}"strip) \
--cxx=$(realpath "${cross_prefix}"g++)"
	export src_dir="${WORKDIR}/src"
	export LIB_INSTALL_BASE="$work_dir"
	export INSTALL_PKG_CONFIG_DIR="${work_dir}/pkgconfig"
	export ffmpeg_source_dir="${src_dir}/ffmpeg"
	export install_prefix="${work_dir}/$(get_ffmpeg_directory)" # install them to their a separate dir
	export ffmpeg_kit_install="${work_dir}/$(get_ffmpeg_kit_directory)"
	export ffmpeg_kit_bundle="${work_dir}/$(get_bundle_directory)"
	export ffmpeg_kit_src_dir="${BASEDIR}/windows"
	create_dir "$work_dir"
	change_dir "$work_dir" || exit
}

get_arch_specific_ldflags() {
	case ${ARCH} in
	x86-64)
		echo -e "-march=x86-64 -Wl,-z,text"
		;;
	esac
}

get_ffmpeg_kit_directory() {
	local build_type=$1
	if [[ -z $build_type ]]; then
		echo -e "ffmpeg-kit-${target_name}_$(get_build_type)"
	else
		echo -e "ffmpeg-kit-${target_name}_$build_type"
	fi
}

get_ffmpeg_directory() {
	local build_type=$1
	if [[ -z $build_type ]]; then
		echo -e "ffmpeg-${target_name}_$(get_build_type)"
	else
		echo -e "ffmpeg-${target_name}_$build_type"
	fi
}

get_size_optimization_ldflags() {
	if [[ -z ${NO_LINK_TIME_OPTIMIZATION} ]]; then
		local LINK_TIME_OPTIMIZATION_FLAGS="-flto"
	else
		local LINK_TIME_OPTIMIZATION_FLAGS=""
	fi

	case ${ARCH} in
	x86-64)
		case $1 in
		ffmpeg)
			echo -e "${LINK_TIME_OPTIMIZATION_FLAGS} -O2 -ffunction-sections -fdata-sections -finline-functions"
			;;
		*)
			echo -e "-Os -ffunction-sections -fdata-sections"
			;;
		esac
		;;
	esac
}

get_common_linked_libraries() {
	local COMMON_LIBRARIES=""

	case $1 in
	chromaprint | ffmpeg-kit | kvazaar | srt | zimg)
		echo -e "-stdlib=libstdc++ -lstdc++ -lc -lm ${COMMON_LIBRARIES}"
		;;
	*)
		echo -e "-lc -lm -ldl ${COMMON_LIBRARIES}"
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

	echo -e "${ARCH_FLAGS} ${OPTIMIZATION_FLAGS} ${COMMON_LINKED_LIBS} ${LLVM_CONFIG_LDFLAGS} -Wl,--hash-style=both -fuse-ld=lld"
}

get_cxxflags() {
	if [[ -z ${NO_LINK_TIME_OPTIMIZATION} ]]; then
		local LINK_TIME_OPTIMIZATION_FLAGS="-flto"
	else
		local LINK_TIME_OPTIMIZATION_FLAGS=""
	fi

	if [[ -z ${FFMPEG_KIT_DEBUG} ]]; then
		local OPTIMIZATION_FLAGS="-Os -ffunction-sections -fdata-sections"
	else
		local OPTIMIZATION_FLAGS="${FFMPEG_KIT_DEBUG}"
	fi

	local BUILD_DATE="-DFFMPEG_KIT_BUILD_DATE=$(date +%Y%m%d | tee -a "$LOG_FILE")"
	local COMMON_FLAGS="-stdlib=libstdc++ -std=c++11 ${OPTIMIZATION_FLAGS} ${BUILD_DATE} $(get_arch_specific_cflags)"

	case $1 in
	ffmpeg)
		if [[ -z ${FFMPEG_KIT_DEBUG} ]]; then
			echo -e "${LINK_TIME_OPTIMIZATION_FLAGS} -stdlib=libstdc++ -std=c++11 -O2 -ffunction-sections -fdata-sections"
		else
			echo -e "${FFMPEG_KIT_DEBUG} -stdlib=libstdc++ -std=c++11"
		fi
		;;
	ffmpeg-kit)
		echo -e "${COMMON_FLAGS}"
		;;
	srt | tesseract | zimg)
		echo -e "${COMMON_FLAGS} -fcxx-exceptions -fPIC"
		;;
	*)
		echo -e "${COMMON_FLAGS} -fno-exceptions -fno-rtti"
		;;
	esac
}

get_common_includes() {
	echo -e "-I${LLVM_CONFIG_INCLUDEDIR:-.}"
}

get_size_optimization_cflags() {
	if [[ -z ${NO_LINK_TIME_OPTIMIZATION} ]]; then
		local LINK_TIME_OPTIMIZATION_FLAGS="-flto"
	else
		local LINK_TIME_OPTIMIZATION_FLAGS=""
	fi

	local ARCH_OPTIMIZATION=""
	case ${ARCH} in
	x86-64 | x86_64)
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

	echo -e "${ARCH_OPTIMIZATION} ${LIB_OPTIMIZATION}"
}

get_common_cflags() {
	if [[ -n ${FFMPEG_KIT_LTS_BUILD} ]]; then
		local LTS_BUILD_FLAG="-DFFMPEG_KIT_LTS "
	fi

	echo -e "-fstrict-aliasing -fPIC -DWINDOWS ${LTS_BUILD_FLAG} ${LLVM_CONFIG_CFLAGS}"
}

get_app_specific_cflags() {
	local APP_FLAGS=""
	case $1 in
	ffmpeg)
		APP_FLAGS="-Wno-unused-function"
		;;
	ffmpeg-kit)
		APP_FLAGS="-Wno-unused-function -Wno-pointer-sign -Wno-switch -Wno-deprecated-declarations"
		;;
	kvazaar)
		APP_FLAGS="-std=gnu99 -Wno-unused-function"
		;;
	openh264)
		APP_FLAGS="-std=gnu99 -Wno-unused-function -fstack-protector-all"
		;;
	srt)
		APP_FLAGS="-Wno-unused-function"
		;;
	*)
		APP_FLAGS="-std=c99 -Wno-unused-function"
		;;
	esac

	echo -e "${APP_FLAGS}"
}

get_arch_specific_cflags() {
	case ${ARCH} in
	x86-64 | x86_64)
		echo -e "-target $(get_target) -DFFMPEG_KIT_X86_64"
		;;
	esac
}

get_cflags() {
	local ARCH_FLAGS=$(get_arch_specific_cflags)
	local APP_FLAGS=$(get_app_specific_cflags "$1")
	local COMMON_FLAGS=$(get_common_cflags)
	if [[ -z ${FFMPEG_KIT_DEBUG} ]]; then
		local OPTIMIZATION_FLAGS=$(get_size_optimization_cflags "$1")
	else
		local OPTIMIZATION_FLAGS="${FFMPEG_KIT_DEBUG}"
	fi
	local COMMON_INCLUDES=$(get_common_includes)

	echo -e "${ARCH_FLAGS} ${APP_FLAGS} ${COMMON_FLAGS} ${OPTIMIZATION_FLAGS} ${COMMON_INCLUDES}"
}

get_target_cpu() {
	case ${ARCH} in
	i686 | x86 | win32)
		echo -e "i686"
		;;
	x86-64 | x86_64 | win64)
		echo -e "x86_64"
		;;
	esac
}

get_build_directory() {
	local LTS_POSTFIX=""
	if [[ -n ${FFMPEG_KIT_LTS_BUILD} ]]; then
		LTS_POSTFIX="-lts"
	fi

	echo -e "windows-$(get_target_cpu)${LTS_POSTFIX}"
}

detect_clang_version() {
	if [[ -n ${FFMPEG_KIT_LTS_BUILD} ]]; then
		for clang_version in 6 .. 10; do
			if [[ $(command_exists "clang-$clang_version") -eq 0 ]]; then
				echo -e "$clang_version"
				return
			elif [[ $(command_exists "clang-$clang_version.0") -eq 0 ]]; then
				echo -e "$clang_version.0"
				return
			fi
		done
		echo -e "none"
	else
		for clang_version in 11 .. 20; do
			if [[ $(command_exists "clang-$clang_version") -eq 0 ]]; then
				echo -e "$clang_version"
				return
			elif [[ $(command_exists "clang-$clang_version.0") -eq 0 ]]; then
				echo -e "$clang_version.0"
				return
			fi
		done
		echo -e "none"
	fi
}

set_toolchain_paths() {
	export PATH="${PATH}:${mingw_bin_path}:${mingw_w64_x86_64_prefix}/bin"
	export CC="${cross_prefix}gcc"
	export AR="$(realpath "${cross_prefix}ar")"
	export AS="$(realpath "${cross_prefix}as")"
	export NM="$(realpath "${cross_prefix}nm")"
	export RANLIB="$(realpath "${cross_prefix}ranlib")"
	export LD="$(realpath "${cross_prefix}ld")"
	export STRIP="$(realpath "${cross_prefix}strip")"
	export CXX="$(realpath "${cross_prefix}g++")"
}

enable_lts_build() {
	export FFMPEG_KIT_LTS_BUILD="1"
}

install_pkg_config_file() {
	local FILE_NAME="$1"
	local SOURCE="${INSTALL_PKG_CONFIG_DIR}/${FILE_NAME}"
	local DESTINATION="${FFMPEG_KIT_BUNDLE_PKG_CONFIG_DIRECTORY}/${FILE_NAME}"

	# DELETE OLD FILE
	if ! remove_path -rf "$DESTINATION" >>"$LOG_FILE"; then
		exit_message 1 "DEBUG: failed\n\nSee $LOG_FILE for details"
	fi

	# INSTALL THE NEW FILE
	if ! copy_path "$SOURCE" "$DESTINATION" >>"$LOG_FILE"; then
		exit_message 1 "DEBUG: failed\n\nSee $LOG_FILE for details"
	fi

	prepare_inline_sed
	# UPDATE PATHS
	${SED_INLINE} "s|${ffmpeg_kit_install}|${ffmpeg_kit_bundle}|g" "$DESTINATION" || return 1
	${SED_INLINE} "s|${ffmpeg_source_dir}|${ffmpeg_kit_bundle}|g" "$DESTINATION" || return 1
}

get_ffmpeg_kit_version() {
	local FFMPEG_KIT_VERSION=$(grep -Eo 'FFmpegKitVersion = .*' "$ffmpeg_kit_src_dir/src/FFmpegKitConfig.h" | tee -a "$LOG_FILE" | grep -Eo ' \".*' | tr -d '"; ')

	echo -e "${FFMPEG_KIT_VERSION}"
}

download_ffmpeg() {
	local output_dir="$src_dir/ffmpeg"
	local desired_version="$ffmpeg_git_checkout_version"

	if [[ -z $desired_version ]]; then
		desired_version="master"
	fi

	do_git_checkout "$ffmpeg_git_checkout" "$output_dir" "$desired_version" || exit_message 1 "could not git $ffmpeg_git_checkout $output_dir $desired_version"
	ffmpeg_source_dir=$output_dir
}

check_cross_compiler_bin() {
	local gcc_bin="$mingw_bin_path/$host_target-gcc"
	if [[ -f $gcc_bin ]]; then
		echo -e "INFO: MinGW compiler already installed for $compiler_flavors, not re-installing..." | tee -a "$LOG_FILE"
		return 0 # early exit they've selected at least some kind by this point...
	fi
	return 1
}

check_cross_compiler() {
	setup_build_environment "$compiler_flavors"
	if [[ $compiler_flavors == "multi" || -z $compiler_flavors ]]; then
		setup_build_environment "win32"
		if [[ $(check_cross_compiler_bin) != 0 ]]; then
			install_cross_compiler
		fi
		setup_build_environment "win64"
		if [[ $(check_cross_compiler_bin) != 0 ]]; then
			install_cross_compiler
		fi
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
	if [[ ($compiler_flavors == "win32" || $compiler_flavors == "multi") && ! -f ../$win32_gcc ]]; then
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
	fi
	if [[ ($compiler_flavors == "win64" || $compiler_flavors == "multi") && ! -f ../$win64_gcc ]]; then
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
      if ! check_pkg_config_batch "$mingw_w64_x86_64_prefix/lib/pkgconfig/libpcre*.pc" > >(redirect_output) 2>&1; then
        change_dir "$work_dir/cross_compilers/src"
        download_and_unpack_file "https://repo.msys2.org/mingw/mingw64/mingw-w64-x86_64-pcre-8.45-1-any.pkg.tar.zst" "mingw-pcre"
        change_dir "$work_dir/cross_compilers/src/mingw-pcre/mingw64"
        [[ -d "bin" ]] && (cp -rv bin/* "$mingw_w64_x86_64_prefix/bin/" > >(redirect_output) 2>&1 || exit_message 1 "could not install mingw-pcre bin")
        [[ -d "include" ]] && (cp -rv include/* "$mingw_w64_x86_64_prefix/include/" > >(redirect_output) 2>&1 || exit_message 1 "could not install mingw-pcre include")
        [[ -d "lib" ]] && (cp -rv lib/* "$mingw_w64_x86_64_prefix/lib/" > >(redirect_output) 2>&1 || exit_message 1 "could not install mingw-pcre lib")
        [[ -d "share" ]] && (cp -rv share/* "$mingw_w64_x86_64_prefix/share/" > >(redirect_output) 2>&1 || exit_message 1 "could not install mingw-pcre share")
      fi
      if ! check_pkg_config_batch "$mingw_w64_x86_64_prefix/lib/pkgconfig/sndfile*.pc" > >(redirect_output) 2>&1; then
        change_dir "$work_dir/cross_compilers/src"
        download_and_unpack_file "https://repo.msys2.org/mingw/mingw64/mingw-w64-x86_64-libsndfile-1.2.2-1-any.pkg.tar.zst" "mingw-libsndfile"
        change_dir "$work_dir/cross_compilers/src/mingw-libsndfile/mingw64"
        [[ -d "bin" ]] && (cp -rv bin/* "$mingw_w64_x86_64_prefix/bin/" > >(redirect_output) 2>&1 || exit_message 1 "could not install mingw-libsndfile bin")
        [[ -d "include" ]] && (cp -rv include/* "$mingw_w64_x86_64_prefix/include/" > >(redirect_output) 2>&1 || exit_message 1 "could not install mingw-libsndfile include")
        [[ -d "lib" ]] && (cp -rv lib/* "$mingw_w64_x86_64_prefix/lib/" > >(redirect_output) 2>&1 || exit_message 1 "could not install mingw-libsndfile lib")
        [[ -d "share" ]] && (cp -rv share/* "$mingw_w64_x86_64_prefix/share/" > >(redirect_output) 2>&1 || exit_message 1 "could not install mingw-libsndfile share")
      fi
      if [[ ! -f "$mingw_w64_x86_64_prefix/bin/msys-intl-8.dll" ]]; then
        change_dir "$work_dir/cross_compilers/src"
        download_and_unpack_file "https://mirror.msys2.org/msys/x86_64/libintl-0.22.5-1-x86_64.pkg.tar.zst" "mingw-libintl"
        change_dir "$work_dir/cross_compilers/src/mingw-libintl/usr"
        [[ -d "bin" ]] && (cp -rv bin/* "$mingw_w64_x86_64_prefix/bin/" > >(redirect_output) 2>&1 || exit_message 1 "could not install mingw-libintl bin")
      fi
      if ! check_pkg_config_batch "$mingw_w64_x86_64_prefix/lib/pkgconfig/iconv*.pc" > >(redirect_output) 2>&1; then
        change_dir "$work_dir/cross_compilers/src"
        download_and_unpack_file "https://repo.msys2.org/mingw/mingw64/mingw-w64-x86_64-libiconv-1.17-4-any.pkg.tar.zst" "mingw-libiconv"
        change_dir "$work_dir/cross_compilers/src/mingw-libiconv/mingw64"
        [[ -d "bin" ]] && (cp -rv bin/* "$mingw_w64_x86_64_prefix/bin/" > >(redirect_output) 2>&1 || exit_message 1 "could not install mingw-libiconv bin")
        [[ -d "include" ]] && (cp -rv include/* "$mingw_w64_x86_64_prefix/include/" > >(redirect_output) 2>&1 || exit_message 1 "could not install mingw-libiconv include")
        [[ -d "lib" ]] && (cp -rv lib/* "$mingw_w64_x86_64_prefix/lib/" > >(redirect_output) 2>&1 || exit_message 1 "could not install mingw-libiconv lib")
        [[ -d "share" ]] && (cp -rv share/* "$mingw_w64_x86_64_prefix/share/" > >(redirect_output) 2>&1 || exit_message 1 "could not install mingw-libiconv share")
      fi
      change_dir "$work_dir/cross_compilers/src"
	fi

	# rm -f build.log # leave resultant build log...sometimes useful...
	reset_cflags
	change_dir ..
	echo -e "INFO: Done building (or already built) MinGW-w64 cross-compiler(s) successfully..." | tee -a "$LOG_FILE"
}



check_builds() {
	shared_build_exists=0
	static_build_exists=0

	# Check shared build
	local build_dir="$work_dir/$(get_ffmpeg_directory shared)" #install_prefix
	echo -e "INFO: Checking $build_dir" >>"$LOG_FILE"
	if [[ -d "$build_dir" && -d "$build_dir/bin" ]]; then
		echo -e "INFO: Checking binaries in $build_dir/bin..." >>"$LOG_FILE"
		check_binaries=0
		if find "$build_dir/bin" -maxdepth 1 -type f \( -name '*.a' -o -name '*.dll' -o -name '*.so' -o -name '*.dylib' -o -name '*.lib' -o -name '*.exe' \) -print -quit | grep -q .; then
			check_binaries=1
		fi
		[[ $check_binaries -eq 1 ]] && shared_build_exists=1
	fi
	build_dir="$work_dir/$(get_ffmpeg_directory static)" #install_prefix
	echo -e "INFO: Checking $build_dir" >>"$LOG_FILE"
	# Check static build
	if [[ -d "$build_dir" && -d "$build_dir/bin" ]]; then
		echo -e "INFO: Checking binaries in $build_dir/bin..." >>"$LOG_FILE"
		check_binaries=0
		if find "$build_dir/bin" -maxdepth 1 -type f \( -name '*.a' -o -name '*.dll' -o -name '*.so' -o -name '*.dylib' -o -name '*.lib' -o -name '*.exe' \) -print -quit | grep -q .; then
			check_binaries=1
		fi
		[[ $check_binaries -eq 1 ]] && static_build_exists=1
	fi

	echo -e "INFO: Checking if build already exists..." | tee -a "$LOG_FILE"

	if truthy "$build_ffmpeg_static"; then
		echo -e "INFO: Static build requested..." | tee -a "$LOG_FILE"
		if [[ $static_build_exists == 0 || "$BUILD_FORCE" -eq 1 ]]; then
			build_dir="$work_dir/$(get_ffmpeg_directory static)" #install_prefix
			echo -e "INFO: Static build does not exist or force requested. (Re-)configuring Ffmpeg for static build..." | tee -a "$LOG_FILE"
			# shellcheck disable=SC2129
			remove_path -rf "$build_dir" 
			remove_path -f "${ffmpeg_source_dir}/already_"* 
			configure_ffmpeg 
		else
			echo -e "INFO: Static build already exists at $build_dir" | tee -a "$LOG_FILE"
		fi
	elif truthy "$build_ffmpeg_shared"; then
		echo -e "INFO: Shared build requested..." | tee -a "$LOG_FILE"
		if [[ $shared_build_exists == 0 || "$BUILD_FORCE" -eq 1 ]]; then
			build_dir="$work_dir/$(get_ffmpeg_directory shared)" #install_prefix
			echo -e "INFO: Shared build does not exist or force requested. (Re-)configuring Ffmpeg for shared build..." | tee -a "$LOG_FILE"
			# shellcheck disable=SC2129
			remove_path -rf "$build_dir" 
			remove_path -f "${ffmpeg_source_dir}/already_"* 
			configure_ffmpeg
		else
			echo -e "INFO: Shared build already exists at $build_dir" | tee -a "$LOG_FILE"
		fi
	fi
}

install_ffmpeg() {
	check_builds
	echo -e "INFO: Installing ffmpeg if not installed" | tee -a "$LOG_FILE"
	change_dir "$ffmpeg_source_dir"

	echo -e "INFO: Making Ffmpeg $(pwd)" | tee -a "$LOG_FILE"

	create_dir "$install_prefix"

	do_make_and_make_install "" "" "$(get_build_type)"

	echo -e "INFO: Moving all binaries" | tee -a "$LOG_FILE"

	{	
    shopt -s nullglob
    mv -- */*.a */*.dylib */*.lib */*.dll *.exe *.so "${install_prefix}/bin" 2>/dev/null || true
	} >>"$LOG_FILE"

	echo -e "INFO: Done installing ffmpeg" | tee -a "$LOG_FILE"

	install_ffmpeg_pkg
}

install_ffmpeg_pkg() {
	echo -e "INFO: Checking deployment files..." | tee -a "$LOG_FILE"

	required_files=(
		"${install_prefix}/lib/pkgconfig/libavformat.pc"
		"${install_prefix}/lib/pkgconfig/libswresample.pc"
		"${install_prefix}/lib/pkgconfig/libswscale.pc"
		"${install_prefix}/lib/pkgconfig/libavdevice.pc"
		"${install_prefix}/lib/pkgconfig/libavfilter.pc"
		"${install_prefix}/lib/pkgconfig/libavcodec.pc"
		"${install_prefix}/lib/pkgconfig/libavutil.pc")

	check_files_exist "false" "${required_files[@]}"

	echo -e "INFO: Done checking deployment files." | tee -a "$LOG_FILE"

	echo -e "INFO: Installing ffmpeg pkg-config" | tee -a "$LOG_FILE"

	create_dir "$INSTALL_PKG_CONFIG_DIR"

	# MANUALLY COPY PKG-CONFIG FILES
	overwrite_file "${install_prefix}"/lib/pkgconfig/libavformat.pc "${INSTALL_PKG_CONFIG_DIR}/libavformat.pc" || return 1
	overwrite_file "${install_prefix}"/lib/pkgconfig/libswresample.pc "${INSTALL_PKG_CONFIG_DIR}/libswresample.pc" || return 1
	overwrite_file "${install_prefix}"/lib/pkgconfig/libswscale.pc "${INSTALL_PKG_CONFIG_DIR}/libswscale.pc" || return 1
	overwrite_file "${install_prefix}"/lib/pkgconfig/libavdevice.pc "${INSTALL_PKG_CONFIG_DIR}/libavdevice.pc" || return 1
	overwrite_file "${install_prefix}"/lib/pkgconfig/libavfilter.pc "${INSTALL_PKG_CONFIG_DIR}/libavfilter.pc" || return 1
	overwrite_file "${install_prefix}"/lib/pkgconfig/libavcodec.pc "${INSTALL_PKG_CONFIG_DIR}/libavcodec.pc" || return 1
	overwrite_file "${install_prefix}"/lib/pkgconfig/libavutil.pc "${INSTALL_PKG_CONFIG_DIR}/libavutil.pc" || return 1

	# # MANUALLY ADD REQUIRED HEADERS
	{
		mkdir -p "${install_prefix}"/include/libavutil/x86
		mkdir -p "${install_prefix}"/include/libavutil/arm
		mkdir -p "${install_prefix}"/include/libavutil/aarch64
		mkdir -p "${install_prefix}"/include/libavcodec/x86
		mkdir -p "${install_prefix}"/include/libavcodec/arm
		overwrite_file "${ffmpeg_source_dir}"/config.h "${install_prefix}"/include/config.h
		overwrite_file "${ffmpeg_source_dir}"/libavcodec/mathops.h "${install_prefix}"/include/libavcodec/mathops.h
		overwrite_file "${ffmpeg_source_dir}"/libavcodec/x86/mathops.h "${install_prefix}"/include/libavcodec/x86/mathops.h
		overwrite_file "${ffmpeg_source_dir}"/libavcodec/arm/mathops.h "${install_prefix}"/include/libavcodec/arm/mathops.h
		overwrite_file "${ffmpeg_source_dir}"/libavformat/network.h "${install_prefix}"/include/libavformat/network.h
		overwrite_file "${ffmpeg_source_dir}"/libavformat/os_support.h "${install_prefix}"/include/libavformat/os_support.h
		overwrite_file "${ffmpeg_source_dir}"/libavformat/url.h "${install_prefix}"/include/libavformat/url.h
		overwrite_file "${ffmpeg_source_dir}"/libavutil/attributes_internal.h "${install_prefix}"/include/libavutil/attributes_internal.h
		overwrite_file "${ffmpeg_source_dir}"/libavutil/bprint.h "${install_prefix}"/include/libavutil/bprint.h
		overwrite_file "${ffmpeg_source_dir}"/libavutil/getenv_utf8.h "${install_prefix}"/include/libavutil/getenv_utf8.h
		overwrite_file "${ffmpeg_source_dir}"/libavutil/internal.h "${install_prefix}"/include/libavutil/internal.h
		overwrite_file "${ffmpeg_source_dir}"/libavutil/libm.h "${install_prefix}"/include/libavutil/libm.h
		overwrite_file "${ffmpeg_source_dir}"/libavutil/reverse.h "${install_prefix}"/include/libavutil/reverse.h
		overwrite_file "${ffmpeg_source_dir}"/libavutil/thread.h "${install_prefix}"/include/libavutil/thread.h
		overwrite_file "${ffmpeg_source_dir}"/libavutil/timer.h "${install_prefix}"/include/libavutil/timer.h
		overwrite_file "${ffmpeg_source_dir}"/libavutil/x86/asm.h "${install_prefix}"/include/libavutil/x86/asm.h
		overwrite_file "${ffmpeg_source_dir}"/libavutil/x86/timer.h "${install_prefix}"/include/libavutil/x86/timer.h
		overwrite_file "${ffmpeg_source_dir}"/libavutil/arm/timer.h "${install_prefix}"/include/libavutil/arm/timer.h
		overwrite_file "${ffmpeg_source_dir}"/libavutil/aarch64/timer.h "${install_prefix}"/include/libavutil/aarch64/timer.h
		overwrite_file "${ffmpeg_source_dir}"/compat/w32pthreads.h "${install_prefix}"/include/libavutil/compat/w32pthreads.h
		overwrite_file "${ffmpeg_source_dir}"/libavutil/wchar_filename.h "${install_prefix}"/include/libavutil/wchar_filename.h
	} >>"$LOG_FILE"

	echo -e "INFO: Done installing ffmpeg pkg-config" | tee -a "$LOG_FILE"
}

# shellcheck disable=SC2120
configure_ffmpeg() {
	echo -e "INFO: Configuring ffmpeg" | tee -a "$LOG_FILE"
	
	change_dir "$ffmpeg_source_dir" || return 1

	if truthy "$BUILD_FORCE"; then
		remove_path -f "${ffmpeg_source_dir}/already_configured_$(get_build_type)"*
	fi

	change_dir "$ffmpeg_source_dir" || exit
	apply_patch file://"$WINPATCHDIR"/frei0r_load-shared-libraries-dynamically.diff
	if [ "$bits_target" = "32" ]; then
		local arch=x86
	else
		local arch=amd64
	fi

	local postpend_configure_opts=""
	local init_options=""

	[[ $target_platform == "windows" ]] && init_options+=" --target-os=mingw32"
  init_options+=" --pkg-config=pkg-config"
	init_options+=" --pkg-config-flags=--static"
	init_options+=" --enable-version3"
	init_options+=" --arch=$arch"
	init_options+=" --cross-prefix=$cross_prefix"
	init_options+=" --prefix=$install_prefix"
	init_options+=" --extra-cflags=-DLIBTWOLAME_STATIC"
	init_options+=" --extra-cflags=-DMODPLUG_STATIC"
	init_options+=" --extra-cflags=-DCACA_STATIC"
	init_options+=" --extra-cflags=-DWIN32_LEAN_AND_MEAN"
	init_options+=" --extra-cflags=-DWIN32_ANSI_API"
	init_options+=" --extra-cflags=-DHAVE_WCHAR_FILENAME_H=0"
	init_options+=" --extra-ldflags=-lole32"
	init_options+=" --extra-ldflags=-lshlwapi"
	init_options+=" --extra-ldflags=-static-libgcc"
	init_options+=" --extra-ldflags=-static-libstdc++"
	init_options+=" --extra-cflags=-mtune=generic"
	init_options+=" --extra-cflags=-O3"
	init_options+=" --extra-cflags=-pipe"
	init_options+=" --enable-pic"
	init_options+=" --enable-swscale"
	init_options+=" --enable-optimizations"
	init_options+=" --enable-small"
	init_options+=" --enable-cross-compile"
	init_options+=" --enable-w32threads"

	# can't mix and match --enable-static --enable-shared unfortunately, or the final executable seems to just use shared if the're both present
	if truthy "$build_ffmpeg_shared"; then
		postpend_configure_opts=" --enable-shared --disable-static" # I guess this doesn't have to be at the end...
	else
		postpend_configure_opts=" --enable-static --disable-shared"
	fi

	local config_options=""
	config_options+=" --disable-doc"
	config_options+=" --disable-htmlpages"
  config_options+=" --disable-manpages"
  config_options+=" --disable-podpages"
  config_options+=" --disable-txtpages"
	config_options+=" --disable-schannel"
	config_options+=" --disable-openssl"
	config_options+=" --disable-outdev=fbdev"
  config_options+=" --disable-indev=fbdev"
  config_options+="$enable_nonfree"
  #------------------------------------------------------------------------------     
  # ----------------------------- android features ------------------------------     
  #------------------------------------------------------------------------------      
  if [[ $target_platform == "android" ]]; then
  truthy "$disable_jni" && config_options+=" --disable-jni"                           # enable JNI support [no]
  truthy "$disable_ladspa" && config_options+=" --disable-ladspa"                     # enable LADSPA audio filtering [no]
  truthy "$disable_mediacodec" && config_options+=" --disable-mediacodec"             # enable Android MediaCodec support [no]
  truthy "$enable_libsmbclient" && config_options+=" --enable-libsmbclient"           # enable Samba protocol via libsmbclient [no]
  fi
  #------------------------------------------------------------------------------    
  # ----------------------------- harmony features ------------------------------     
  #------------------------------------------------------------------------------    
  if [[ $target_platform == "harmony" ]]; then
  truthy "$disable_ohcodec" && config_options+=" --disable-ohcodec"                   # enable OpenHarmony Codec support [no]
  truthy "$enable_libsmbclient" && config_options+=" --enable-libsmbclient"           # enable Samba protocol via libsmbclient [no]
  fi
  #------------------------------------------------------------------------------    
  # --------------------------- linux/unix features -----------------------------     
  #------------------------------------------------------------------------------    
  if [[ $target_platform == "linux" ]]; then
  truthy "$disable_alsa" && config_options+=" --disable-alsa"                         # disable ALSA support [autodetect]
  truthy "$enable_libdc1394" && config_options+=" --enable-libdc1394"                 # enable IIDC-1394 grabbing using libdc1394 and libraw1394 [no]
  truthy "$disable_libdrm" && config_options+=" --disable-libdrm"                     # disable DRM code (Linux) [autodetect]
  truthy "$enable_libiec61883" && config_options+=" --enable-libiec61883"             # enable iec61883 via libiec61883 [no]
  truthy "$enable_libv4l2" && config_options+=" --enable-libv4l2"                     # enable libv4l2/v4l-utils [no]
  truthy "$enable_libxcb_shape" && config_options+=" --enable-libxcb-shape"           # enable X11 grabbing shape rendering [autodetect]
  truthy "$enable_libxcb_shm" && config_options+=" --enable-libxcb-shm"               # enable X11 grabbing shm communication [autodetect]
  truthy "$enable_libxcb_xfixes" && config_options+=" --enable-libxcb-xfixes"         # enable X11 grabbing mouse rendering [autodetect]
  truthy "$enable_libxcb" && config_options+=" --enable-libxcb"                       # enable X11 grabbing using XCB [autodetect]
  truthy "$disable_rkmpp" && config_options+=" --enable-rkmpp"                        # enable Rockchip Media Process Platform code [no]
  truthy "$disable_v4l2_m2m" && config_options+=" --disable-v4l2-m2m"                 # disable V4L2 mem2mem code [autodetect]
  truthy "$disable_vaapi" && config_options+=" --disable-vaapi"                       # disable Video Acceleration API (mainly Unix/Intel) code [autodetect]
  truthy "$disable_xlib" && config_options+=" --disable-xlib"                         # disable xlib [autodetect]
  truthy "$enable_libsmbclient" && config_options+=" --enable-libsmbclient"           # enable Samba protocol via libsmbclient [no]
  fi
  #------------------------------------------------------------------------------
  # ----------------------------- hardware features ----------------------------- 
  #------------------------------------------------------------------------------
  truthy "$disable_amf" && config_options+=" --disable-amf"                           # disable AMF video encoding code [autodetect]
  truthy "$disable_vulkan" && config_options+=" --disable-vulkan"                     # disable Vulkan code [autodetect]
  truthy "$enable_libmfx" && config_options+=" --enable-libmfx"                       # enable Intel MediaSDK (AKA Quick Sync Video) code via libmfx [no]
  truthy "$enable_libvpl" && config_options+=" --enable-libvpl"                       # enable Intel oneVPL code via libvpl if libmfx is not used [no]
  truthy "$enable_omx" && config_options+=" --enable-omx"                             # enable OpenMAX IL code [no]
  truthy "$enable_vulkan_static" && config_options+=" --enable-vulkan-static"         # enable statically link to libvulkan [no]
  #------------------------------------------------------------------------------
  # ----------------------------- windows features ------------------------------ 
  #------------------------------------------------------------------------------
  if [[ $target_platform == "windows" ]]; then
  truthy "$enable_avisynth" && config_options+=" --enable-avisynth"                   # enable reading of AviSynth script files [no]
  fi
  #------------------------------------------------------------------------------
  # -------------------------- cross-platform features --------------------------
  #------------------------------------------------------------------------------ 
# XXX --disable-sndio MinGW/Windows not supported 
# truthy "$disable_sndio" && config_options+=" --disable-sndio"                       # disable sndio support [autodetect]
# TODO --enable-libjack
# truthy "$enable_libjack" && config_options+=" --enable-libjack"                     # enable JACK audio sound server [no]
# XXX --enable-libtorch ABI mismatch
# truthy "$enable_libtorch" && config_options+=" --enable-libtorch"                   # enable Torch as one DNN backend [no]
  truthy "$disable_bzlib" && config_options+=" --disable-bzlib"                       # disable bzlib [autodetect]
  truthy "$disable_iconv" && config_options+=" --disable-iconv"                       # disable iconv [autodetect]
  truthy "$disable_lzma" && config_options+=" --disable-lzma"                         # disable lzma [autodetect]
  truthy "$disable_sdl2" && config_options+=" --disable-sdl2"                         # disable sdl2 [autodetect]
  truthy "$disable_zlib" && config_options+=" --disable-zlib"                         # disable zlib [autodetect]
  truthy "$enable_libvo_amrwbenc" && config_options+=" --enable-libvo-amrwbenc"       # enable AMR-WB encoding via libvo-amrwbenc [no]
  truthy "$enable_libopencore_amrnb" && config_options+=" --enable-libopencore-amrnb" # enable AMR-NB de/encoding via libopencore-amrnb [no]
  truthy "$enable_libopencore_amrwb" && config_options+=" --enable-libopencore-amrwb" # enable AMR-WB decoding via libopencore-amrwb [no]
  truthy "$enable_liblcevc_dec" && config_options+=" --enable-liblcevc-dec"           # enable LCEVC decoding via liblcevc-dec [no]
  truthy "$enable_chromaprint" && config_options+=" --enable-chromaprint"             # enable audio fingerprinting with chromaprint [no]
  truthy "$enable_frei0r" && config_options+=" --enable-frei0r"                       # enable frei0r video filtering [no]
  truthy "$enable_gcrypt" && config_options+=" --enable-gcrypt"                       # enable gcrypt, needed for rtmp(t)e support if openssl, librtmp or gmp is not used [no]
  truthy "$enable_gmp" && config_options+=" --enable-gmp"                             # enable gmp, needed for rtmp(t)e support if openssl or librtmp is not used [no]
  truthy "$enable_gnutls" && config_options+=" --enable-gnutls"                       # enable gnutls, needed for https support if openssl, libtls or mbedtls is not used [no]
  truthy "$enable_lcms2" && config_options+=" --enable-lcms2"                         # enable ICC profile support via LittleCMS 2 [no]
  truthy "$enable_libaom" && config_options+=" --enable-libaom"                       # enable AV1 video encoding/decoding via libaom [no]
  truthy "$enable_libaribb24" && config_options+=" --enable-libaribb24"               # enable ARIB text and caption decoding via libaribb24 [no]
  truthy "$enable_libaribcaption" && config_options+=" --enable-libaribcaption"       # enable ARIB text and caption decoding via libaribcaption [no]
  truthy "$enable_libass" && config_options+=" --enable-libass"                       # enable libass subtitles rendering, needed for subtitles and ass filter [no]
  truthy "$enable_libbluray" && config_options+=" --enable-libbluray"                 # enable BluRay reading using libbluray [no]
  truthy "$enable_libbs2b" && config_options+=" --enable-libbs2b"                     # enable bs2b DSP library [no]
  truthy "$enable_libcaca" && config_options+=" --enable-libcaca"                     # enable textual display using libcaca [no]
  truthy "$enable_libcdio" && config_options+=" --enable-libcdio"                     # enable audio CD grabbing with libcdio [no]
  truthy "$enable_libcelt" && config_options+=" --enable-libcelt"                     # enable CELT decoding via libcelt [no]
  truthy "$enable_libcodec2" && config_options+=" --enable-libcodec2"                 # enable codec2 en/decoding using libcodec2 [no]
  truthy "$enable_libdav1d" && config_options+=" --enable-libdav1d"                   # enable AV1 decoding via libdav1d [no]
  truthy "$enable_libdavs2" && config_options+=" --enable-libdavs2"                   # enable AVS2 decoding via libdavs2 [no]
  truthy "$enable_libdvdnav" && config_options+=" --enable-libdvdnav"                 # enable libdvdnav, needed for DVD demuxing [no]
  truthy "$enable_libdvdread" && config_options+=" --enable-libdvdread"               # enable libdvdread, needed for DVD demuxing [no]
  truthy "$enable_libflite" && config_options+=" --enable-libflite"                   # enable flite (voice synthesis) support via libflite [no]
  truthy "$enable_libfontconfig" && config_options+=" --enable-libfontconfig"         # enable libfontconfig, useful for drawtext filter [no]
  truthy "$enable_libfreetype" && config_options+=" --enable-libfreetype"             # enable libfreetype, needed for drawtext filter [no]
  truthy "$enable_libfribidi" && config_options+=" --enable-libfribidi"               # enable libfribidi, improves drawtext filter [no]
  truthy "$enable_libglslang" && config_options+=" --enable-libglslang"               # enable GLSL->SPIRV compilation via libglslang [no]
  truthy "$enable_libgme" && config_options+=" --enable-libgme"                       # enable Game Music Emu via libgme [no]
  truthy "$enable_libgsm" && config_options+=" --enable-libgsm"                       # enable GSM de/encoding via libgsm [no]
  truthy "$enable_libharfbuzz" && config_options+=" --enable-libharfbuzz"             # enable libharfbuzz, needed for drawtext filter [no]
  truthy "$enable_libilbc" && config_options+=" --enable-libilbc"                     # enable iLBC de/encoding via libilbc [no]
  truthy "$enable_libjxl" && config_options+=" --enable-libjxl"                       # enable JPEG XL de/encoding via libjxl [no]
  truthy "$enable_libklvanc" && config_options+=" --enable-libklvanc"                 # enable Kernel Labs VANC processing [no]
  truthy "$enable_libkvazaar" && config_options+=" --enable-libkvazaar"               # enable HEVC encoding via libkvazaar [no]
  truthy "$enable_liblc3" && config_options+=" --enable-liblc3"                       # enable LC3 de/encoding via liblc3 [no]
  truthy "$enable_liblensfun" && config_options+=" --enable-liblensfun"               # enable lensfun lens correction [no]
  truthy "$enable_libmodplug" && config_options+=" --enable-libmodplug"               # enable ModPlug via libmodplug [no]
  truthy "$enable_libmp3lame" && config_options+=" --enable-libmp3lame"               # enable MP3 encoding via libmp3lame [no]
  truthy "$enable_libmysofa" && config_options+=" --enable-libmysofa"                 # enable libmysofa, needed for sofalizer filter [no]
  truthy "$enable_liboapv" && config_options+=" --enable-liboapv"                     # enable APV encoding via liboapv [no]
  truthy "$enable_libopencv" && config_options+=" --enable-libopencv"                 # enable video filtering via libopencv [no]
  truthy "$enable_libopenh264" && config_options+=" --enable-libopenh264"             # enable H.264 encoding via OpenH264 [no]
  truthy "$enable_libopenjpeg" && config_options+=" --enable-libopenjpeg"             # enable JPEG 2000 encoding via OpenJPEG [no]
  truthy "$enable_libopenmpt" && config_options+=" --enable-libopenmpt"               # enable decoding tracked files via libopenmpt [no]
  truthy "$enable_libopenvino" && config_options+=" --enable-libopenvino"             # enable OpenVINO as a DNN module backend for DNN based filters like dnn_processing [no]
  truthy "$enable_libopus" && config_options+=" --enable-libopus"                     # enable Opus de/encoding via libopus [no]
  truthy "$enable_libplacebo" && config_options+=" --enable-libplacebo"               # enable libplacebo library [no]
  truthy "$enable_libpulse" && config_options+=" --enable-libpulse"                   # enable Pulseaudio input via libpulse [no]
  truthy "$enable_libqrencode" && config_options+=" --enable-libqrencode"             # enable QR encode generation via libqrencode [no]
  truthy "$enable_libquirc" && config_options+=" --enable-libquirc"                   # enable QR decoding via libquirc [no]
  truthy "$enable_librabbitmq" && config_options+=" --enable-librabbitmq"             # enable RabbitMQ library [no]
  truthy "$enable_librav1e" && config_options+=" --enable-librav1e"                   # enable AV1 encoding via rav1e [no]
  truthy "$enable_librist" && config_options+=" --enable-librist"                     # enable RIST via librist [no]
  truthy "$enable_librsvg" && config_options+=" --enable-librsvg"                     # enable SVG rasterization via librsvg [no]
  truthy "$enable_librtmp" && config_options+=" --enable-librtmp"                     # enable RTMP[E] support via librtmp [no]
  truthy "$enable_librubberband" && config_options+=" --enable-librubberband"         # enable rubberband needed for rubberband filter [no]
  truthy "$enable_libshaderc" && config_options+=" --enable-libshaderc"               # enable GLSL->SPIRV compilation via libshaderc [no]
  truthy "$enable_libshine" && config_options+=" --enable-libshine"                   # enable fixed-point MP3 encoding via libshine [no]
  truthy "$enable_libsnappy" && config_options+=" --enable-libsnappy"                 # enable Snappy compression, needed for hap encoding [no]
  truthy "$enable_libsoxr" && config_options+=" --enable-libsoxr"                     # enable Include libsoxr resampling [no]
  truthy "$enable_libspeex" && config_options+=" --enable-libspeex"                   # enable Speex de/encoding via libspeex [no]
  truthy "$enable_libsrt" && config_options+=" --enable-libsrt"                       # enable Haivision SRT protocol via libsrt [no]
  truthy "$enable_libssh" && config_options+=" --enable-libssh"                       # enable SFTP protocol via libssh [no]
  truthy "$enable_libsvtav1" && config_options+=" --enable-libsvtav1"                 # enable AV1 encoding via SVT [no]
  truthy "$enable_libtensorflow" && config_options+=" --enable-libtensorflow"         # enable TensorFlow as a DNN module backend for DNN based filters like sr [no]
  truthy "$enable_libtesseract" && config_options+=" --enable-libtesseract"           # enable Tesseract, needed for ocr filter [no]
  truthy "$enable_libtheora" && config_options+=" --enable-libtheora"                 # enable Theora encoding via libtheora [no]
  truthy "$enable_libtls" && config_options+=" --enable-libtls"                       # enable LibreSSL (via libtls), needed for https support if openssl, gnutls or mbedtls is not used [no]
  truthy "$enable_libtwolame" && config_options+=" --enable-libtwolame"               # enable MP2 encoding via libtwolame [no]
  truthy "$enable_libuavs3d" && config_options+=" --enable-libuavs3d"                 # enable AVS3 decoding via libuavs3d [no]
  truthy "$enable_libvidstab" && config_options+=" --enable-libvidstab"               # enable video stabilization using vid.stab [no]
  truthy "$enable_libvmaf" && config_options+=" --enable-libvmaf"                     # enable vmaf filter via libvmaf [no]
  truthy "$enable_libvorbis" && config_options+=" --enable-libvorbis"                 # enable Vorbis en/decoding via libvorbis, native implementation exists [no]
  truthy "$enable_libvpx" && config_options+=" --enable-libvpx"                       # enable VP8 and VP9 de/encoding via libvpx [no]
  truthy "$enable_libvvenc" && config_options+=" --enable-libvvenc"                   # enable H.266/VVC encoding via vvenc [no]
  truthy "$enable_libwebp" && config_options+=" --enable-libwebp"                     # enable WebP encoding via libwebp [no]
  truthy "$enable_libx264" && config_options+=" --enable-libx264"                     # enable H.264 encoding via x264 [no]
  truthy "$enable_libx265" && config_options+=" --enable-libx265"                     # enable HEVC encoding via x265 [no]
  truthy "$enable_libxavs" && config_options+=" --enable-libxavs"                     # enable AVS encoding via xavs [no]
  truthy "$enable_libxavs2" && config_options+=" --enable-libxavs2"                   # enable AVS2 encoding via xavs2 [no]
  truthy "$enable_libxevd" && config_options+=" --enable-libxevd"                     # enable EVC decoding via libxevd [no]
  truthy "$enable_libxeve" && config_options+=" --enable-libxeve"                     # enable EVC encoding via libxeve [no]
  truthy "$enable_libxml2" && config_options+=" --enable-libxml2"                     # enable XML parsing using the C library libxml2, needed for dash and imf demuxing support [no]
  truthy "$enable_libxvid" && config_options+=" --enable-libxvid"                     # enable Xvid encoding via xvidcore, native MPEG-4/Xvid encoder exists [no]
  truthy "$enable_libzimg" && config_options+=" --enable-libzimg"                     # enable z.lib, needed for zscale filter [no]
  truthy "$enable_libzmq" && config_options+=" --enable-libzmq"                       # enable message passing via libzmq [no]
  truthy "$enable_libzvbi" && config_options+=" --enable-libzvbi"                     # enable teletext support via libzvbi [no]
  truthy "$enable_lv2" && config_options+=" --enable-lv2"                             # enable LV2 audio filtering [no]
  truthy "$enable_mbedtls" && config_options+=" --enable-mbedtls"                     # enable mbedTLS, needed for https support if openssl, gnutls or libtls is not used [no]
  truthy "$enable_openal" && config_options+=" --enable-openal"                       # enable OpenAL 1.1 capture support [no]
  truthy "$enable_opencl" && config_options+=" --enable-opencl"                       # enable OpenCL processing [no]
  truthy "$enable_opengl" && config_options+=" --enable-opengl"                       # enable OpenGL rendering [no]
  truthy "$enable_openssl" && config_options+=" --enable-openssl"                     # enable openssl, needed for https support if gnutls, libtls or mbedtls is not used [no]
  truthy "$enable_pocketsphinx" && config_options+=" --enable-pocketsphinx"           # enable PocketSphinx, needed for asr filter [no]
  truthy "$enable_vapoursynth" && config_options+=" --enable-vapoursynth"             # enable VapourSynth demuxer [no]
  truthy "$enable_whisper" && config_options+=" --enable-whisper"                     # enable whisper filter [no]

  # add any additional ff prefixed flags 
  ff_flags=$(concat_array "$ff_flags_values" " ")
  config_options+=" $ff_flags"

	if truthy "$GPL_ENABLED"; then
		config_options+=" --enable-gpl"
  elif [[ -n $enable_nonfree ]]; then 
    #------------------------------------------------------------------------------
    # ------------------------ non-free non-gpl libraries -------------------------
    #------------------------------------------------------------------------------ 
    truthy "$enable_decklink" && config_options+=" --enable-decklink"                   # enable Blackmagic DeckLink I/O support [no]
    truthy "$enable_libfdk_aac" && config_options+=" --enable-libfdk-aac"               # enable AAC de/encoding via libfdk-aac [no]
    # ----------------------------- hardware features ----------------------------- 
    truthy "$enable_cuda_llvm" && config_options+=" --enable-cuda-llvm"                 # enable CUDA compilation using clang [autodetect]
    truthy "$enable_cuvid" && config_options+=" --enable-cuvid"                         # enable Nvidia CUVID support [autodetect]
    truthy "$enable_ffnvcodec" && config_options+=" --enable-ffnvcodec"                 # enable dynamically linked Nvidia code [autodetect]
    truthy "$enable_nvdec" && config_options+=" --enable-nvdec"                         # enable Nvidia video decoding acceleration (via hwaccel) [autodetect]
    truthy "$enable_nvenc" && config_options+=" --enable-nvenc"                         # enable Nvidia video encoding code [autodetect]
    truthy "$enable_vdpau" && config_options+=" --enable-vdpau"                         # enable Nvidia Video Decode and Presentation API for Unix code [autodetect]
    truthy "$enable_cuda_nvcc" && config_options+=" --enable-cuda-nvcc"                 # enable Nvidia CUDA compiler [no]
    truthy "$enable_libnpp" && config_options+=" --enable-libnpp"                       # enable Nvidia Performance Primitives-based code [no]
    # --------------------------- linux/unix features -----------------------------    
    if [[ $target_platform == "linux" ]]; then
    truthy "$disable_mmal" && config_options+=" --disable-mmal"                         # enable Broadcom Multi-Media Abstraction Layer (Raspberry Pi) via MMAL [no]
    truthy "$disable_omx_rpi" && config_options+=" --disable-omx-rpi"                   # enable OpenMAX IL code for Raspberry Pi [no]
    fi
    # ----------------------------- windows features ------------------------------ 
    if [[ $target_platform == "windows" ]]; then
    truthy "$enable_d3d11va" && config_options+=" --enable-d3d11va"                     # enable Microsoft Direct3D 11 video acceleration code [autodetect]
    truthy "$enable_d3d12va" && config_options+=" --enable-d3d12va"                     # enable Microsoft Direct3D 12 video acceleration code [autodetect]
    truthy "$enable_dxva2" && config_options+=" --enable-dxva2"                         # enable Microsoft DirectX 9 video acceleration code [autodetect]
    truthy "$enable_schannel" && config_options+=" --enable-schannel"                   # enable SChannel SSP, needed for TLS support on Windows if openssl and gnutls are not used [autodetect]
    ! truthy "$disable_mediafoundation" && config_options+=" --enable-mediafoundation"  # enable encoding via MediaFoundation [auto]
    fi
    # ------------------------------ apple features -------------------------------     
    if [[ $target_platform == "apple" ]]; then
    truthy "$enable_avfoundation" && config_options+=" --enable-avfoundation"           # enable Apple AVFoundation framework [autodetect]
    truthy "$enable_appkit" && config_options+=" --enable-appkit"                       # enable Apple AppKit framework [autodetect]
    truthy "$enable_audiotoolbox" && config_options+=" --enable-audiotoolbox"           # enable Apple AudioToolbox code [autodetect]
    truthy "$enable_coreimage" && config_options+=" --enable-coreimage"                 # enable Apple CoreImage framework [autodetect]
    truthy "$enable_metal" && config_options+=" --enable-metal"                         # enable Apple Metal framework [autodetect]
    truthy "$enable_securetransport" && config_options+=" --enable-securetransport"     # enable Secure Transport, needed for TLS support on OSX if openssl and gnutls are not used [autodetect]
    truthy "$enable_videotoolbox" && config_options+=" --enable-videotoolbox"           # enable VideoToolbox code [autodetect]
    fi
	fi

	if [[ "$do_debug_build" == "y" || -n $FFMPEG_KIT_DEBUG ]]; then
		postpend_configure_opts+=" --disable-stripping --disable-optimizations --extra-cflags=-Og --extra-cflags=-fno-omit-frame-pointer --enable-debug=3 --extra-cflags=-fno-inline"
	else
		postpend_configure_opts+=" --disable-debug"
	fi
	export PKG_CONFIG_PATH="$mingw_w64_x86_64_prefix/lib/pkgconfig"
	export PATH="$mingw_bin_path:$original_path"
	do_configure "$init_options$config_options$postpend_configure_opts" "./configure" "$(get_build_type)" || exit_message 1 "unable to configure ffmpeg. see $LOG_FILE for details."

	echo -e "INFO: Done configuering ffmpeg" | tee -a "$LOG_FILE"
}

configure_ffmpeg_kit() {
	echo -e "INFO: Configuring ffmpeg kit" | tee -a "$LOG_FILE"
	local TYPE_POSTFIX="$(get_build_type)"
	local FFMPEG_KIT_VERSION=$(get_ffmpeg_kit_version)

	if truthy "$BUILD_FORCE"; then
		remove_path -rf "${BASEDIR}"/windows/already_configured_*
		remove_path -rf "$ffmpeg_kit_install"
	fi

	create_dir "$ffmpeg_kit_install"

	export PKG_CONFIG_PATH="${PKG_CONFIG_PATH}:${install_prefix}/lib/pkgconfig"
	set_toolchain_paths

	reset_cflags
	reset_cppflags
	local local_cflags="${CFLAGS} -I${install_prefix}/include -L${install_prefix}/bin -L${install_prefix}/lib -I${ffmpeg_source_dir} -I${ffmpeg_source_dir}/compat -DHAVE_W32PTHREADS_H=1"
	local local_cxxfalgs="${CXXFLAGS} -I${install_prefix}/include -L${install_prefix}/bin -L${install_prefix}/lib -I${ffmpeg_source_dir} -I${ffmpeg_source_dir}/compat"

	change_dir "${ffmpeg_kit_src_dir}"
	make distclean > >(redirect_output) 2>&1

	local touch_name=$(get_small_touchfile_name "already_autoreconf_${TYPE_POSTFIX}" "$FFMPEG_KIT_VERSION $local_cflags $local_cxxfalgs")
	if [ ! -f "$touch_name" ]; then
		remove_path -f "${BASEDIR}/windows/already_autoreconf_${TYPE_POSTFIX}"*
		change_dir "${ffmpeg_kit_src_dir}"
		autoreconf_library "ffmpeg-kit" || exit_message 1 "could not autoreconf ffmpeg-kit. See $LOG_FILE for details."
		create_touch_file 0 "$touch_name"
		local BUILD_DATE="-DFFMPEG_KIT_BUILD_DATE=$(date +%Y%m%d 2>>"${BASEDIR}"/build.log)"
		export CFLAGS="${local_cflags} ${BUILD_DATE}"
		export CXXFLAGS="${local_cxxfalgs} ${BUILD_DATE}"
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

	cat >"${INSTALL_PKG_CONFIG_DIR}/ffmpeg-kit.pc" <<EOF
prefix=${ffmpeg_kit_install}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: ffmpeg-kit
Description: FFmpeg for applications on Windows
Version: ${FFMPEGKIT_VERSION}

# Public dependencies that have their own .pc files
Requires: libavfilter, libswscale, libavformat, libavcodec, libswresample, libavutil

# Linker flags for the ffmpeg-kit library itself (includes jsoncpp if static)
Libs: -L\${libdir} -lffmpegkit

# Private dependencies needed for linking on Windows
Libs.private: -lstdc++ -lws2_32 -lpsapi -lole32 -lshlwapi -lgdi32 -lbcrypt -luser32 -luuid

# Compiler flags for the ffmpeg-kit headers (includes jsoncpp headers if bundled)
Cflags: -I\${includedir}
EOF
}

install_ffmpeg_kit() {
	echo -e "INFO: Installing ffmpeg kit to ${ffmpeg_kit_install}" | tee -a "$LOG_FILE"

	change_dir "${ffmpeg_kit_src_dir}"
	do_make_and_make_install "" "" "$(get_build_type)" || exit_message 1 "unable to make ffmpeg-kit. see $LOG_FILE for details."

	create_ffmpegkit_package_config "$(get_ffmpeg_kit_version)" || return 1

	echo -e "INFO: Done installing ffmpeg kit to ${ffmpeg_kit_install}" | tee -a "$LOG_FILE"
}

get_bundle_directory() {
	local LTS_POSTFIX=""
	if [[ -n ${FFMPEG_KIT_LTS_BUILD} ]]; then
		LTS_POSTFIX="-lts"
	fi
	local TYPE_POSTFIX="$(get_build_type)"
	echo -e "bundle-${target_name}-${TYPE_POSTFIX}${LTS_POSTFIX}"
}

create_windows_bundle() {
	echo -e "INFO: Creating bundle" | tee -a "$LOG_FILE"
	local TYPE_POSTFIX="$(get_build_type)"
	local FFMPEG_KIT_VERSION=$(get_ffmpeg_kit_version)

	if [[ $BUILD_FORCE == "1" ]]; then
		remove_path -rf "${BASEDIR}/windows/already_bundled_${TYPE_POSTFIX}"*
	fi

	local touch_name=$(get_small_touchfile_name "already_bundled_${TYPE_POSTFIX}" "$FFMPEG_KIT_VERSION $ffmpeg_kit_bundle")
	if [ ! -f "$touch_name" ]; then
		export FFMPEG_KIT_BUNDLE_INCLUDE_DIRECTORY="${ffmpeg_kit_bundle}/include"
		export FFMPEG_KIT_BUNDLE_LIB_DIRECTORY="${ffmpeg_kit_bundle}/lib"
		export FFMPEG_KIT_BUNDLE_BIN_DIRECTORY="${ffmpeg_kit_bundle}/bin"
		export FFMPEG_KIT_BUNDLE_PKG_CONFIG_DIRECTORY="${ffmpeg_kit_bundle}/pkgconfig"
		remove_path "-rf" "${ffmpeg_kit_bundle}"
		create_dir "${ffmpeg_kit_bundle}"
		create_dir "${FFMPEG_KIT_BUNDLE_INCLUDE_DIRECTORY}"
		create_dir "${FFMPEG_KIT_BUNDLE_LIB_DIRECTORY}"
		create_dir "${FFMPEG_KIT_BUNDLE_BIN_DIRECTORY}"
		create_dir "${FFMPEG_KIT_BUNDLE_PKG_CONFIG_DIRECTORY}"
		{
			# COPY HEADERS
			cp -rP "${ffmpeg_kit_install}/include/"* "${FFMPEG_KIT_BUNDLE_INCLUDE_DIRECTORY}"
			cp -rP "${install_prefix}/include/"* "${FFMPEG_KIT_BUNDLE_INCLUDE_DIRECTORY}"

			# COPY LIBS
			cp -rP "${ffmpeg_kit_install}/lib/"* "${FFMPEG_KIT_BUNDLE_LIB_DIRECTORY}"
			cp -rP "${install_prefix}/lib/"* "${FFMPEG_KIT_BUNDLE_LIB_DIRECTORY}"

			# COPY BINARIES
			cp -rP "${ffmpeg_kit_install}/bin/"* "${FFMPEG_KIT_BUNDLE_BIN_DIRECTORY}"
			cp -rP "${install_prefix}/bin/"* "${FFMPEG_KIT_BUNDLE_BIN_DIRECTORY}"
		} >>"$LOG_FILE"

		install_pkg_config_file "libavformat.pc"
		install_pkg_config_file "libswresample.pc"
		install_pkg_config_file "libswscale.pc"
		install_pkg_config_file "libavdevice.pc"
		install_pkg_config_file "libavfilter.pc"
		install_pkg_config_file "libavcodec.pc"
		install_pkg_config_file "libavutil.pc"
		install_pkg_config_file "ffmpeg-kit.pc"

		local LICENSE_BASEDIR="${ffmpeg_kit_bundle}/licenses"

		create_dir "${LICENSE_BASEDIR}"

		echo -e "INFO: Copying licenses..." | tee -a "$LOG_FILE"
		bash "${SCRIPTDIR}/extract_licenses.sh" "${src_dir}" "${LICENSE_BASEDIR}" > >(redirect_output) 2>&1
		echo -e "INFO: Done copying licenses" | tee -a "$LOG_FILE"

		copy_path "${BASEDIR}"/tools/source/SOURCE "${LICENSE_BASEDIR}/source.txt"
		copy_path "${BASEDIR}"/tools/license/LICENSE.GPLv3 "${LICENSE_BASEDIR}"/license.txt
		create_touch_file 0 "$touch_name"
	fi
	echo -e "INFO: Done creating bundle" | tee -a "$LOG_FILE"
}

pick_clean_type() {
	while [[ ! "$clean_type" =~ ^([1-5]|all|ffmpeg|ffmpeg-kit|ffmpeg-kit-bundle)$ ]]; do
		# shellcheck disable=SC2199
		if [[ -n "${unknown_opts[@]}" ]]; then
			echo -e -n 'Unknown option(s)'
			for unknown_opt in "${unknown_opts[@]}"; do
				echo -e -n " '$unknown_opt'"
			done
			echo -e ', ignored.'
			echo
		fi
		cat <<'EOF'
What would you like to clean?
  1. all
  2. ffmpeg
  3. ffmpeg-kit
  4. ffmpeg-kit-bundle
  5. Exit
EOF
		echo -e -n 'Input your choice [1-5]: '
		read -r clean_type
	done
	case "$clean_type" in
	1) export clean_type="all" ;;
	2) export clean_type="ffmpeg" ;;
	3) export clean_type="ffmpeg-kit" ;;
	4) export clean_type="ffmpeg-kit-bundle" ;;
	all) export clean_type="all" ;;
	ffmpeg) export clean_type="ffmpeg" ;;
	ffmpeg-kit) export clean_type="ffmpeg-kit" ;;
	ffmpeg-kit-bundle) export clean_type="ffmpeg-kit-bundle" ;;
	5)
		exit_message 0 "exiting"
		;;
	*)
		echo -e 'Your choice was not valid, please try again.'
		echo
		;;
	esac
}

clean_ffmpeg_builds() {
	if [[ -z $compiler_flavors ]]; then
		pick_compiler_flavors
	fi
	pick_clean_type
	if [[ ${compiler_flavors,,} =~ ^(multi)$ ]]; then
		clean_builds "win32"
		clean_builds "win64"
	else
		clean_builds "$compiler_flavors"
		exit_message 0 "INFO: Done cleaning builds"
	fi
}

clean_builds() {
	local build_flavor=$1
	if [[ -z $build_flavor ]]; then
		exit_message 1 "no build flavor provided"
	fi
	pick_compiler_flavors "$build_flavor"
	setup_build_environment "$compiler_flavors"
	if [[ ${clean_type,,} =~ ^("all"|"ffmpeg")$ ]]; then
		echo -e "INFO: Deleting ${install_prefix}..."
		remove_path -rf "${install_prefix}"
	fi
	if [[ ${clean_type,,} =~ ^("all"|"ffmpeg-kit")$ ]]; then
		echo -e "INFO: Deleting ${ffmpeg_kit_install}..."
		remove_path -rf "${ffmpeg_kit_install}"
	fi
	if [[ ${clean_type,,} =~ ^("all"|"ffmpeg-kit-bundle")$ ]]; then
		echo -e "INFO: Deleting ${ffmpeg_kit_bundle}..."
		remove_path -rf "${ffmpeg_kit_bundle}"
	fi
}

list_libraries() {
  download_ffmpeg
  change_dir "$src_dir/ffmpeg"
  ./configure --help
  exit 0
}
