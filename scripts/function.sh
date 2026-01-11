#!/bin/bash

# shellcheck disable=SC2317,SC2129,SC1091,SC2120,SC2035,SC2016

enable_library() {
  LIBRARY_NAME="$1"
  VAR_NAME="enable_${LIBRARY_NAME//-/_}"
  export "$VAR_NAME"=y
  VAR_NAME="disable_${LIBRARY_NAME//-/_}"
  export "$VAR_NAME"=n
  echo "  [CONFIG] Enabling: $LIBRARY_NAME" >>"$LOG_FILE"
}

disable_library() {
  LIBRARY_NAME="$1"
  VAR_NAME="enable_${LIBRARY_NAME//-/_}"
  export "$VAR_NAME"=n
  VAR_NAME="disable_${LIBRARY_NAME//-/_}"
  export "$VAR_NAME"=y
  echo "  [CONFIG] Disabling: $LIBRARY_NAME" >>"$LOG_FILE"
}

is_library_enabled() {
  local LIBRARY_NAME="$1"
  local CLEAN_NAME="${LIBRARY_NAME//-/_}"
  
  local VAR_ENABLE="enable_${CLEAN_NAME}"
  local VAR_DISABLE="disable_${CLEAN_NAME}"
  
  if [[ "${!VAR_ENABLE}" == "1" && "${!VAR_DISABLE}" != "1" ]]; then
    return 0  # Library is Enabled
  else
    return 1  # Library is Disabled (or not set)
  fi
}

# 1. exit code
# 2. message
# shellcheck disable=SC2244
exit_message() {
	local code=$1
	shift 1
	local msg="$*"
	
	if truthy "$code"; then
		if [ "$msg" ]; then
			echo -e "\nERROR: $msg" | tee -a "$LOG_FILE"
		else
			echo -e "\nERROR: an error occured" | tee -a "$LOG_FILE"
		fi
	exit 1
	else
		if [ "$msg" ]; then
			echo -e "INFO: $msg" >>"$LOG_FILE"
		fi
	fi
}

# 1. info_msg
# 2. error_msg
# 3. no_exit
execute() {
	local info_msg="$1"
	local error_msg="$2"
	local no_exit="$3"
	shift 3
  # shellcheck disable=SC2244
	if [ ! "$error_msg" ]; then
		error_msg="error"
	fi
  echo "INFO: Executing: $*" >>"$LOG_FILE"
	if [[ $no_exit != "true" ]]; then
		eval "$*" 1>>"$LOG_FILE" 2>&1 || exit_message 1 "$error_msg, check $LOG_FILE for details"
	else
		echo -e "${info_msg}" >>"$LOG_FILE"
		eval "$*" 1>>"$LOG_FILE" 2>&1
	fi
}

# 1. path
create_dir() {
	local path="$1"

	echo -e "DEBUG: creating path ${path}" >>"$LOG_FILE"

	if [ -z "$path" ]; then
		exit_message 1 "ERROR: path argument is required"
	fi

	if [[ ! -d "$path" ]]; then
		execute "INFO: creating path: '$path'" "ERROR: unable to create directory '$path'" "true" \
			mkdir -pv "$path"
	else
		echo -e "DEBUG: directory already exists, skipping creation." >>"$LOG_FILE"
	fi
  execute "INFO: updating path permissions: '$path'" "ERROR: unable to update permissions on '$path'" "true" \
    chmod -R u+rwx "$path"
}
# 1. options
# @. paths
remove_path() {
    local recursive=false force=false other_options=()
    local paths=()
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -r|--recursive) recursive=true ;;
            -f|--force) force=true ;;
            --)
                shift
                paths+=("$@")
                break
                ;;
            -*) other_options+=("$1")
                [[ $1 == *"r"* ]] && recursive=true
                [[ $1 == *"f"* ]] && force=true
                ;;
            *) paths+=("$1") ;;
        esac
        shift
    done

    local rm_options=()
    [[ "$recursive" == true ]] && rm_options+=(-r)
    [[ "$force" == true ]] && rm_options+=(-f)
    rm_options+=("${other_options[@]}")

    if [ ${#paths[@]} -eq 0 ]; then
        echo -e "ERROR: at least one path argument is required" >>"$LOG_FILE"
        return 1
    fi

    for path in "${paths[@]}"; do
        if [[ -z "$path" ]]; then
            echo -e "ERROR: empty path argument" >>"$LOG_FILE"
            return 1
        fi
        
        if [[ "$path" == "/" || "$path" == "$HOME" || "$path" == "~" || "$path" == "." || "$path" == ".." ]]; then
            echo -e "ERROR: dangerous path '$path' - refusing to remove" >>"$LOG_FILE"
            return 1
        fi
    done

    # Process each path
    for path in "${paths[@]}"; do
        echo -e "DEBUG: removing path: '$path'" >>"$LOG_FILE"

        if [[ -e "$path" ]]; then
            # For directories, ensure recursive flag is set
            if [[ -d "$path" && "$recursive" != true ]]; then
                echo -e "WARNING: '$path' is a directory but recursive option not set. Adding -r flag for removal." >>"$LOG_FILE"
                rm_options+=(-r)
            fi
            execute "INFO: updating path permissions: '$path'" "ERROR: unable to update permissions on '$path'" "true" \
              chmod -R u+rwx "$path"
            execute "INFO: removing path: '$path'" "ERROR: unable to remove path '$path'" "true" \
                rm "${rm_options[@]}" "$path"
        else
            echo -e "INFO: path '$path' does not exist" >>"$LOG_FILE"
            if [[ "$force" != true ]]; then
                echo -e "WARNING: path '$path' not found and force flag not set" >>"$LOG_FILE"
            fi
        fi
    done
}

# 1. path
# 2. create if not exists
change_dir() {
	local path="$1"
	local create="$2"
	if [ -z "$path" ]; then
		exit_message 1 "ERROR: path argument is required"
	fi

	if [[ -e "$path" ]]; then
		execute "INFO: changing to path: '$(realpath "$path")'" "ERROR: unable to cd to directory '$(realpath "$path")'" "true" \
			cd "$path"
		if [[ ! -r "$path" ]] || [[ ! -w "$path" ]] || [[ ! -x "$path" ]]; then
      execute "INFO: updating path permissions: '$path'" "ERROR: unable to update permissions on '$path'" "true" \
        chmod -R u+rwx "$(pwd)"
		fi
	else
		echo -e "INFO: path '$path' does not exist" >>"$LOG_FILE"
		if [[ -n $create ]]; then
			echo -e "INFO: creating '$path'" >>"$LOG_FILE"
			create_dir "$path"
			change_dir "$path"
		fi
	fi
}

# 1. source_path
# 2. destination_path
# 3. options
# 4. skip_if_exists
copy_path() {
	local source_path="$1"
	local destination_path="$2"
	local options="${3:-}"             # Default to empty
	local skip_if_exists="${4:-false}" # Default to false

	echo -e "DEBUG: copying from ${source_path} to ${destination_path}" >>"$LOG_FILE"

	if [ -z "$source_path" ] || [ -z "$destination_path" ]; then
		exit_message 1 "ERROR: both source and destination path arguments are required"
	fi

	if [ ! -e "$source_path" ]; then
		echo -e "ERROR: source path '$source_path' does not exist" >>"$LOG_FILE"
		return 0
	fi

	# Check if destination already exists
	if [ "$skip_if_exists" = "true" ] && [ -e "$destination_path" ]; then
		echo -e "INFO: destination '$destination_path' already exists, skipping copy" >>"$LOG_FILE"
		return 0
	fi

	# Create destination directory if it doesn't exist
	local destination_dir
	destination_dir=$(dirname "$destination_path")

	if [ ! -d "$destination_dir" ]; then
		create_dir "$destination_dir"
	fi

	# Perform the copy operation
	if [ -n "$options" ]; then
		execute "INFO: copying path: '$source_path' to '$destination_path' with options '$options'" "ERROR: unable to copy '$source_path' to '$destination_path'" "false" \
			cp "$options" "$source_path" "$destination_path"
	else
		execute "INFO: copying path: '$source_path' to '$destination_path'" "ERROR: unable to copy '$source_path' to '$destination_path'" "false" \
			cp -r "$source_path" "$destination_path"
	fi

	# Update permissions on the copied path
  execute "INFO: updating path permissions: '$path'" "ERROR: unable to update permissions on '$path'" "true" \
    chmod -R u+rwx "$path"
}

# 1. skip_if_missing
check_files_exist() {
	local skip_if_missing="${1:-false}"
	shift 1
	local files=("$@")

	echo -e "DEBUG: checking ${#files[@]} files" >>"$LOG_FILE"

	if [ ${#files[@]} -eq 0 ]; then
		echo -e "ERROR: file list argument is required" >>"$LOG_FILE"
		return 1
	fi

	local missing_files=()

	for file in "${files[@]}"; do
		if [ ! -e "$file" ]; then
			missing_files+=("$file")
		fi
	done

	if [ ${#missing_files[@]} -gt 0 ]; then
		if [ "$skip_if_missing" = "true" ]; then
			echo -e "INFO: ${#missing_files[@]} files are missing" >>"$LOG_FILE"
			return 0
		else
			exit_message 1 "ERROR: ${#missing_files[@]} required files are missing: ${missing_files[*]}"
		fi
	else
		echo -e "INFO: all ${#files[@]} files exist" >>"$LOG_FILE"
	fi
}

require_sudo() {
	if [ "$EUID" -ne 0 ]; then
		echo "This script must be run with sudo" | tee -a "$LOG_FILE"
		echo "Usage: sudo $0 [OPTIONS]" | tee -a "$LOG_FILE"
		exit 1
	fi

	if [ -z "$SUDO_USER" ]; then
		echo "Warning: Running as root directly (not via sudo)" | tee -a "$LOG_FILE"
	else
		echo "Running with sudo privileges (user: $SUDO_USER)" | tee -a "$LOG_FILE"
	fi
}

is_integer() {
    local str="$1"
    if [[ "$str" =~ ^[-+]?[0-9]+$ ]]; then
        echo "0" # Is integer
    else
        echo "1" # Not integer
    fi
}

is_alpha() {
	local str="$1"
	if [[ "$str" =~ ^[a-zA-Z]+$ ]]; then
		echo "0" # Is integer
	else
		echo "1" # Not integer
	fi
}

array_index_of() {
	local search_string="$1"
	shift
	local array=("$@")

	for i in "${!array[@]}"; do
		if [[ "${array[i]}" == *"$search_string" ]]; then
			echo "$i" # Return the index
			return 0
		fi
	done
	exit_message 0 "ERROR: $search_string could not be found in array.\n $(print_build_steps)" | tee -a "$LOG_FILE"
	return 1
}

concat_array() {
    local array_name="$1"
    local separator="${2:- }"
    local -n arr="$array_name"
    
    if [ ${#arr[@]} -eq 0 ]; then
        echo ""
        return
    fi
    
    local result=""
    printf -v result "%s$separator" "${arr[@]}"
    echo "$result%$separator"
}

# Check if value is truthy
# Returns 0 (success) for truthy values, 1 (failure) for falsey values
truthy() {
  local value="$1"
  case "${value,,}" in
    y|yes|1|true|on) return 0 ;;
    *) return 1 ;;
  esac
}

# Check if value is falsey  
# Returns 0 (success) for falsey values, 1 (failure) for truthy values
falsey() {
  local value="$1"
  case "${value,,}" in
    y|yes|1|true|on) return 1 ;;
    *) return 0 ;;
  esac
}

#
# 1. source file
# 2. destination file
#
overwrite_file() {
	copy_path "$2" "$2.bak" # backup
	remove_path -f "$2" 2>>"$LOG_FILE"
	copy_path "$1" "$2" 2>>"$LOG_FILE"
}

prepare_inline_sed() {
	export SED_INLINE="sed -i"
}

setup_build_environment() {
    [[ -z $host_platform ]] && pick_host_platform
    [[ -z $host_arch ]] && pick_host_arch
    determine_distro
    export host_name="$host_platform-$host_arch"
    echo -e "\n************** Setting up environment for $host_name build... **************" | tee -a "$LOG_FILE"
    
    export bits_target=$(calculate_bits_target)
    export work_dir="$(realpath "$WORKDIR"/"$host_name")"
    
    # Common setup for all platforms
    export src_dir="${WORKDIR}/src"
    export install_pkgconfig_dir="${work_dir}/pkgconfig"
    export ffmpeg_source_dir=${ffmpeg_source_dir:-"${src_dir}/ffmpeg"}
    export ffmpeg_install_prefix="${work_dir}/$(get_ffmpeg_directory)"
    export ffmpeg_kit_install="${work_dir}/$(get_ffmpeg_kit_directory)"
    export ffmpeg_kit_bundle="${work_dir}/$(get_bundle_directory)"
    if [[ $host_platform == "windows" || $host_platform == "linux" ]]; then
      export ffmpeg_kit_src_dir="${BASEDIR}/desktop"
    else
      export ffmpeg_kit_src_dir="${BASEDIR}/$host_platform"
    fi
    
    case "$host_platform" in
        "windows") setup_windows_environment ;;
        "linux") setup_linux_environment ;;
        *) exit_message 1 "Unknown host platform '$host_platform'" ;;
    esac
    
    create_dir "$work_dir"
    change_dir "$work_dir" || exit
}

calculate_bits_target() {
    case "$host_arch" in
        "i686") echo "32" ;;
        "x86_64") echo "64" ;;
        *) exit_message 1 "Unknown host arch '$host_arch'" ;;
    esac
}

setup_windows_environment() {
    export PATCHDIR="$SCRIPTDIR/windows/patches"
    export host_target="$host_arch-w64-mingw32"
    export rust_target="$host_arch-pc-windows-gnu"
    export toolchain_root="mingw-w64-$host_arch"
    export dependency_install_prefix="$work_dir/libraries"
    #export dependency_install_prefix="$(realpath "$work_dir/cross_compilers/$toolchain_root/$host_target")"
    export toolchain_root_dir="/usr/"
    #export toolchain_root_dir="$(realpath "$work_dir/cross_compilers/$toolchain_root")"
    export toolchain_bin_path="/usr/bin/"
    #export toolchain_bin_path="$(realpath "$toolchain_root_dir"/bin)"
    export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:$dependency_install_prefix/lib/pkgconfig:$ffmpeg_install_prefix/lib/pkgconfig"
    export PATH="$toolchain_bin_path:$ffmpeg_install_prefix/bin:$original_path"
    export cross_prefix="/usr/local/mingw-w64/bin/$host_target-"
    #export cross_prefix="$toolchain_bin_path/$host_target-"
    
    # Common compiler flags for Windows
    export compiler_flags="CC=${cross_prefix}gcc \
AR=${cross_prefix}ar \
AS=${cross_prefix}as \
PREFIX=$dependency_install_prefix \
RANLIB=${cross_prefix}ranlib \
LD=${cross_prefix}ld \
STRIP=${cross_prefix}strip \
CXX=${cross_prefix}g++"
    
    export make_prefix_options="--cc=${cross_prefix}gcc \
--ar=${cross_prefix}ar) \
--as=${cross_prefix}as) \
--nm=${cross_prefix}nm) \
--ranlib=${cross_prefix}ranlib) \
--ld=${cross_prefix}ld) \
--strip=${cross_prefix}strip) \
--cxx=${cross_prefix}g++)"
    
    export windows_cflags="$original_cfflags -mtune=generic -O3 -pipe"
    export CFLAGS="$windows_cflags"
    export windows_cxxflags="$original_cxxflags"
    export CXXFLAGS="$windows_cxxflags"
    export windows_cppflags="$original_cppflags -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=3"
    export CPPFLAGS="$windows_cppflags"
    export windows_ldflags="$original_ldflags -L${dependency_install_prefix}/lib"
    export LDFLAGS="$windows_ldflags"
}

setup_linux_environment() {
    export PATCHDIR="$SCRIPTDIR/linux/patches"
    export host_target="$host_arch-$host_platform-gnu"
    export rust_target="$host_arch-unknown-linux-gnu"
    export dependency_install_prefix="$work_dir/libraries"
    export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:$dependency_install_prefix/share/pkgconfig:$dependency_install_prefix/lib/pkgconfig:$dependency_install_prefix/lib/$host_target/pkgconfig:$work_dir/pkgconfig:$ffmpeg_install_prefix/lib/pkgconfig:/usr/lib/$host_target/pkgconfig:/usr/lib/pkgconfig"
    export PATH="$ffmpeg_install_prefix/bin:$dependency_install_prefix/bin:$original_path"
    export linux_cflags="$original_cflags -I${dependency_install_prefix}/include"
    export CFLAGS="$linux_cflags"
    export linux_cppflags="$original_cppflags -I${dependency_install_prefix}/include -DLINUX"
    export CPPFLAGS="$linux_cppflags"
    export linux_cxxflags="$original_cxxflags -I${dependency_install_prefix}/include"
    export CXXFLAGS="$linux_cxxflags"
    export linux_ldflags="$original_ldflags -L${dependency_install_prefix}/lib -Wl,-rpath,${dependency_install_prefix}/lib"
    export LDFLAGS="$linux_ldflags"
    export LD_LIBRARY_PATH="${dependency_install_prefix}/lib:$LD_LIBRARY_PATH"
}

reset_cflags() {
  if [[ "$host_platform" == "windows" ]]; then
    export CFLAGS="$windows_cflags"
  elif [[ "$host_platform" == "linux" ]]; then
    export CFLAGS="$linux_cflags"
  elif [[ -n "$original_cflags" ]]; then
    export CFLAGS="$original_cflags"
  else
    unset CFLAGS
  fi
}

reset_cxxflags() {
	if [[ "$host_platform" == "windows" ]]; then
    export CXXFLAGS="$windows_cxxflags"
  elif [[ "$host_platform" == "linux" ]]; then
    export CXXFLAGS="$linux_cxxflags"
  elif [[ -n "$original_cxxflags" ]]; then
    export CXXFLAGS="$original_cxxflags"
  else
    unset CXXFLAGS
  fi
}

reset_cppflags() {
	if [[ "$host_platform" == "windows" ]]; then
    export CPPFLAGS="$windows_cppflags"
  elif [[ "$host_platform" == "linux" ]]; then
    export CPPFLAGS="$linux_cppflags"
  elif [[ -n "$original_cppflags" ]]; then
    export CPPFLAGS="$original_cppflags"
  else
    unset CPPFLAGS
  fi
}

reset_ldflags() {
	if [[ "$host_platform" == "windows" ]]; then
    export LDFLAGS="$windows_ldflags"
  elif [[ "$host_platform" == "linux" ]]; then
    export LDFLAGS="$linux_ldflags"
  elif [[ -n "$original_ldflags" ]]; then
    export LDFLAGS="$original_ldflags"
  else
    unset LDFLAGS
  fi
}

get_ffmpeg_directory() {
	local build_type=$1
  local dir_name="${host_name}"
	if [[ -z $build_type ]]; then
		dir_name+="-$build_ffmpeg_type"
  else
		dir_name+="-$build_type"
	fi
  if truthy "$do_debug_build"; then
    dir_name+="-debug"
  fi
  local is_small=""
  if truthy "$build_small"; then
    is_small="-small"
  fi
  local bundle_type=""
  if [[ -n $(get_bundle_type) ]]; then
    bundle_type="$(get_bundle_type)-"
  fi
  local is_gpl=""
  if truthy "$build_gpl"; then
    is_gpl="-gpl"
  fi
  local is_nonfree=""
  if truthy "$build_nonfree"; then
    is_nonfree="-nonfree"
  fi
  echo "ffmpeg-$bundle_type$dir_name$is_small$is_gpl$is_nonfree"
}

get_ffmpeg_kit_directory() {
  local dir_name="${host_name}-$build_ffmpeg_kit_type"
  if truthy "$do_debug_build"; then
    dir_name+="-debug"
	fi
  local is_small=""
  if truthy "$build_small"; then
    is_small="-small"
  fi
  local bundle_type=""
  if [[ -n $(get_bundle_type) ]]; then
    bundle_type="$(get_bundle_type)-"
  fi
  local is_gpl=""
  if truthy "$build_gpl"; then
    is_gpl="-gpl"
  fi
  local is_nonfree=""
  if truthy "$build_nonfree"; then
    is_nonfree="-nonfree"
  fi
	echo "ffmpeg-kit-$bundle_type$dir_name$is_small$is_gpl$is_nonfree"
}

get_bundle_directory() {
  local dir_name="${host_name}-$build_ffmpeg_kit_type"
  if truthy "$do_debug_build"; then
    dir_name+="-debug"
	fi
  local is_small=""
  if truthy "$build_small"; then
    is_small="-small"
  fi
  local bundle_type=""
  if [[ -n $(get_bundle_type) ]]; then
    bundle_type="$(get_bundle_type)-"
  fi
  local is_gpl=""
  if truthy "$build_gpl"; then
    is_gpl="-gpl"
  fi
  local is_nonfree=""
  if truthy "$build_nonfree"; then
    is_nonfree="-nonfree"
  fi
	echo "bundle-$bundle_type$dir_name$is_small$is_gpl$is_nonfree"
}

get_bundle_type() {
  if truthy "$audio_bundle"; then
    echo "audio"
  elif truthy "$video_bundle"; then
    echo "video"
  elif truthy "$audio_ai_bundle"; then
    echo "audio_ai"
  elif truthy "$video_ai_bundle"; then
    if truthy "$gpu_support"; then
      echo "video_ai_gpu_$gpu_type"
    else
      echo "video_ai_cpu"
    fi
  elif truthy "$video_hw_bundle"; then
    echo "video_hw"
  elif truthy "$video_ai_hw_bundle"; then
    if truthy "$gpu_support"; then
      echo "video_hw_ai_gpu_$gpu_type"
    else
      echo "video_hw_ai_cpu"
    fi
  elif truthy "$streaming_bundle"; then
    echo "streaming"
  elif truthy "$enable_full"; then
    echo "full"
  else
    echo "custom"
  fi
}

get_cpu_count() {
	echo -e "$cpu_count"
}

get_concurrent_proc() {
  # shellcheck disable=2046
  echo -e $(( $(get_cpu_count) / 3 ))
}

display_version() {
	COMMAND=$(echo -e "$0" | sed -e 's/\.\///g')

	echo -e "\
$COMMAND v$(get_ffmpeg_kit_version)
Copyright (c) 2025 Akash Patel\n\
License LGPLv3.0: GNU LGPL version 3 or later\n\
<https://www.gnu.org/licenses/lgpl-3.0.en.html>\n\
This is free software: you can redistribute it and/or modify it under the terms of the \
GNU Lesser General Public License as published by the Free Software Foundation, \
either version 3 of the License, or (at your option) any later version."
}

get_ffmpeg_libavcodec_version() {
	local MAJOR=$(grep -Eo ' LIBAVCODEC_VERSION_MAJOR .*' "${BASEDIR}"/src/ffmpeg/libavcodec/version_major.h | sed -e 's|LIBAVCODEC_VERSION_MAJOR||g;s| ||g')
	local MINOR=$(grep -Eo ' LIBAVCODEC_VERSION_MINOR .*' "${BASEDIR}"/src/ffmpeg/libavcodec/version.h | sed -e 's|LIBAVCODEC_VERSION_MINOR||g;s| ||g')
	local MICRO=$(grep -Eo ' LIBAVCODEC_VERSION_MICRO .*' "${BASEDIR}"/src/ffmpeg/libavcodec/version.h | sed -e 's|LIBAVCODEC_VERSION_MICRO||g;s| ||g')

	echo -e "${MAJOR}.${MINOR}.${MICRO}"
}

get_ffmpeg_libavcodec_major_version() {
	local MAJOR=$(grep -Eo ' LIBAVCODEC_VERSION_MAJOR .*' "${BASEDIR}"/src/ffmpeg/libavcodec/version_major.h | sed -e 's|LIBAVCODEC_VERSION_MAJOR||g;s| ||g')

	echo -e "${MAJOR}"
}

get_ffmpeg_libavdevice_version() {
	local MAJOR=$(grep -Eo ' LIBAVDEVICE_VERSION_MAJOR .*' "${BASEDIR}"/src/ffmpeg/libavdevice/version_major.h | sed -e 's|LIBAVDEVICE_VERSION_MAJOR||g;s| ||g')
	local MINOR=$(grep -Eo ' LIBAVDEVICE_VERSION_MINOR .*' "${BASEDIR}"/src/ffmpeg/libavdevice/version.h | sed -e 's|LIBAVDEVICE_VERSION_MINOR||g;s| ||g')
	local MICRO=$(grep -Eo ' LIBAVDEVICE_VERSION_MICRO .*' "${BASEDIR}"/src/ffmpeg/libavdevice/version.h | sed -e 's|LIBAVDEVICE_VERSION_MICRO||g;s| ||g')

	echo -e "${MAJOR}.${MINOR}.${MICRO}"
}

get_ffmpeg_libavdevice_major_version() {
	local MAJOR=$(grep -Eo ' LIBAVDEVICE_VERSION_MAJOR .*' "${BASEDIR}"/src/ffmpeg/libavdevice/version_major.h | sed -e 's|LIBAVDEVICE_VERSION_MAJOR||g;s| ||g')

	echo -e "${MAJOR}"
}

get_ffmpeg_libavfilter_version() {
	local MAJOR=$(grep -Eo ' LIBAVFILTER_VERSION_MAJOR .*' "${BASEDIR}"/src/ffmpeg/libavfilter/version_major.h | sed -e 's|LIBAVFILTER_VERSION_MAJOR||g;s| ||g')
	local MINOR=$(grep -Eo ' LIBAVFILTER_VERSION_MINOR .*' "${BASEDIR}"/src/ffmpeg/libavfilter/version.h | sed -e 's|LIBAVFILTER_VERSION_MINOR||g;s| ||g')
	local MICRO=$(grep -Eo ' LIBAVFILTER_VERSION_MICRO .*' "${BASEDIR}"/src/ffmpeg/libavfilter/version.h | sed -e 's|LIBAVFILTER_VERSION_MICRO||g;s| ||g')

	echo -e "${MAJOR}.${MINOR}.${MICRO}"
}

get_ffmpeg_libavfilter_major_version() {
	local MAJOR=$(grep -Eo ' LIBAVFILTER_VERSION_MAJOR .*' "${BASEDIR}"/src/ffmpeg/libavfilter/version_major.h | sed -e 's|LIBAVFILTER_VERSION_MAJOR||g;s| ||g')

	echo -e "${MAJOR}"
}

get_ffmpeg_libavformat_version() {
	local MAJOR=$(grep -Eo ' LIBAVFORMAT_VERSION_MAJOR .*' "${BASEDIR}"/src/ffmpeg/libavformat/version_major.h | sed -e 's|LIBAVFORMAT_VERSION_MAJOR||g;s| ||g')
	local MINOR=$(grep -Eo ' LIBAVFORMAT_VERSION_MINOR .*' "${BASEDIR}"/src/ffmpeg/libavformat/version.h | sed -e 's|LIBAVFORMAT_VERSION_MINOR||g;s| ||g')
	local MICRO=$(grep -Eo ' LIBAVFORMAT_VERSION_MICRO .*' "${BASEDIR}"/src/ffmpeg/libavformat/version.h | sed -e 's|LIBAVFORMAT_VERSION_MICRO||g;s| ||g')

	echo -e "${MAJOR}.${MINOR}.${MICRO}"
}

get_ffmpeg_libavformat_major_version() {
	local MAJOR=$(grep -Eo ' LIBAVFORMAT_VERSION_MAJOR .*' "${BASEDIR}"/src/ffmpeg/libavformat/version_major.h | sed -e 's|LIBAVFORMAT_VERSION_MAJOR||g;s| ||g')

	echo -e "${MAJOR}"
}

get_ffmpeg_libavutil_version() {
	local MAJOR=$(grep -Eo ' LIBAVUTIL_VERSION_MAJOR .*' "${BASEDIR}"/src/ffmpeg/libavutil/version.h | sed -e 's|LIBAVUTIL_VERSION_MAJOR||g;s| ||g')
	local MINOR=$(grep -Eo ' LIBAVUTIL_VERSION_MINOR .*' "${BASEDIR}"/src/ffmpeg/libavutil/version.h | sed -e 's|LIBAVUTIL_VERSION_MINOR||g;s| ||g')
	local MICRO=$(grep -Eo ' LIBAVUTIL_VERSION_MICRO .*' "${BASEDIR}"/src/ffmpeg/libavutil/version.h | sed -e 's|LIBAVUTIL_VERSION_MICRO||g;s| ||g')

	echo -e "${MAJOR}.${MINOR}.${MICRO}"
}

get_ffmpeg_libavutil_major_version() {
	local MAJOR=$(grep -Eo ' LIBAVUTIL_VERSION_MAJOR .*' "${BASEDIR}"/src/ffmpeg/libavutil/version_major.h | sed -e 's|LIBAVUTIL_VERSION_MAJOR||g;s| ||g')

	echo -e "${MAJOR}"
}

get_ffmpeg_libswresample_version() {
	local MAJOR=$(grep -Eo ' LIBSWRESAMPLE_VERSION_MAJOR .*' "${BASEDIR}"/src/ffmpeg/libswresample/version_major.h | sed -e 's|LIBSWRESAMPLE_VERSION_MAJOR||g;s| ||g')
	local MINOR=$(grep -Eo ' LIBSWRESAMPLE_VERSION_MINOR .*' "${BASEDIR}"/src/ffmpeg/libswresample/version.h | sed -e 's|LIBSWRESAMPLE_VERSION_MINOR||g;s| ||g')
	local MICRO=$(grep -Eo ' LIBSWRESAMPLE_VERSION_MICRO .*' "${BASEDIR}"/src/ffmpeg/libswresample/version.h | sed -e 's|LIBSWRESAMPLE_VERSION_MICRO||g;s| ||g')

	echo -e "${MAJOR}.${MINOR}.${MICRO}"
}

get_ffmpeg_libswresample_major_version() {
	local MAJOR=$(grep -Eo ' LIBSWRESAMPLE_VERSION_MAJOR .*' "${BASEDIR}"/src/ffmpeg/libswresample/version_major.h | sed -e 's|LIBSWRESAMPLE_VERSION_MAJOR||g;s| ||g')

	echo -e "${MAJOR}"
}

get_ffmpeg_libswscale_version() {
	local MAJOR=$(grep -Eo ' LIBSWSCALE_VERSION_MAJOR .*' "${BASEDIR}"/src/ffmpeg/libswscale/version_major.h | sed -e 's|LIBSWSCALE_VERSION_MAJOR||g;s| ||g')
	local MINOR=$(grep -Eo ' LIBSWSCALE_VERSION_MINOR .*' "${BASEDIR}"/src/ffmpeg/libswscale/version.h | sed -e 's|LIBSWSCALE_VERSION_MINOR||g;s| ||g')
	local MICRO=$(grep -Eo ' LIBSWSCALE_VERSION_MICRO .*' "${BASEDIR}"/src/ffmpeg/libswscale/version.h | sed -e 's|LIBSWSCALE_VERSION_MICRO||g;s| ||g')

	echo -e "${MAJOR}.${MINOR}.${MICRO}"
}

get_ffmpeg_libswscale_major_version() {
	local MAJOR=$(grep -Eo ' LIBSWSCALE_VERSION_MAJOR .*' "${BASEDIR}"/src/ffmpeg/libswscale/version_major.h | sed -e 's|LIBSWSCALE_VERSION_MAJOR||g;s| ||g')

	echo -e "${MAJOR}"
}

#
# 1. LIBRARY NAME
#
get_ffmpeg_library_version() {
	case $1 in
	libavcodec)
		echo -e "$(get_ffmpeg_libavcodec_version)"
		;;
	libavdevice)
		echo -e "$(get_ffmpeg_libavdevice_version)"
		;;
	libavfilter)
		echo -e "$(get_ffmpeg_libavfilter_version)"
		;;
	libavformat)
		echo -e "$(get_ffmpeg_libavformat_version)"
		;;
	libavutil)
		echo -e "$(get_ffmpeg_libavutil_version)"
		;;
	libswresample)
		echo -e "$(get_ffmpeg_libswresample_version)"
		;;
	libswscale)
		echo -e "$(get_ffmpeg_libswscale_version)"
		;;
	esac
}

#
# 1. LIBRARY NAME
#
get_ffmpeg_library_major_version() {
	case $1 in
	libavcodec)
		echo -e "$(get_ffmpeg_libavcodec_major_version)"
		;;
	libavdevice)
		echo -e "$(get_ffmpeg_libavdevice_major_version)"
		;;
	libavfilter)
		echo -e "$(get_ffmpeg_libavfilter_major_version)"
		;;
	libavformat)
		echo -e "$(get_ffmpeg_libavformat_major_version)"
		;;
	libavutil)
		echo -e "$(get_ffmpeg_libavutil_major_version)"
		;;
	libswresample)
		echo -e "$(get_ffmpeg_libswresample_major_version)"
		;;
	libswscale)
		echo -e "$(get_ffmpeg_libswscale_major_version)"
		;;
	esac
}

#
# 1. <library name>
#
autoreconf_library() {
	echo -e "\nINFO: Running full autoreconf for $1\n" >>"$LOG_FILE"
	#rm -rf aclocal.m4 autom4te.cache configure Makefile.in src/Makefile.in m4
	# FORCE INSTALL
	autoreconf -fiv > >(redirect_output) 2>&1

	local EXTRACT_RC=$?
	if [[ ${EXTRACT_RC} -eq 0 ]]; then
		echo -e "\nDEBUG: autoreconf completed successfully for $1\n" >>"$LOG_FILE"
		return
	fi

	echo -e "\nDEBUG: Full autoreconf failed. Running full autoreconf with include for $1\n" >>"$LOG_FILE"
	#rm -rf aclocal.m4 autom4te.cache configure Makefile.in src/Makefile.in m4
	# FORCE INSTALL WITH m4
	autoreconf -fiv -I m4 > >(redirect_output) 2>&1

	EXTRACT_RC=$?
	if [[ ${EXTRACT_RC} -eq 0 ]]; then
		echo -e "\nDEBUG: autoreconf completed successfully for $1\n" >>"$LOG_FILE"
		return
	fi

	echo -e "\nDEBUG: Full autoreconf with include failed. Running autoreconf without force for $1\n" >>"$LOG_FILE"
	#rm -rf aclocal.m4 autom4te.cache configure Makefile.in src/Makefile.in m4
	# INSTALL WITHOUT FORCE
	autoreconf -iv > >(redirect_output) 2>&1

	EXTRACT_RC=$?
	if [[ ${EXTRACT_RC} -eq 0 ]]; then
		echo -e "\nDEBUG: autoreconf completed successfully for $1\n" >>"$LOG_FILE"
		return
	fi

	echo -e "\nDEBUG: Autoreconf without force failed. Running autoreconf without force with include for $1\n" >>"$LOG_FILE"
	#rm -rf aclocal.m4 autom4te.cache configure Makefile.in src/Makefile.in m4
	# INSTALL WITHOUT FORCE WITH m4
	autoreconf --iv -I m4 > >(redirect_output) 2>&1

	EXTRACT_RC=$?
	if [[ ${EXTRACT_RC} -eq 0 ]]; then
		echo -e "\nDEBUG: autoreconf completed successfully for $1\n" >>"$LOG_FILE"
		return
	fi

	echo -e "\nDEBUG: Autoreconf without force with include failed. Running default autoreconf for $1\n" >>"$LOG_FILE"
	#rm -rf aclocal.m4 autom4te.cache configure Makefile.in src/Makefile.in m4
	# INSTALL DEFAULT
	(autoreconf) > >(redirect_output) 2>&1

	EXTRACT_RC=$?
	if [[ ${EXTRACT_RC} -eq 0 ]]; then
		echo -e "\nDEBUG: autoreconf completed successfully for $1\n" >>"$LOG_FILE"
		return
	fi

	echo -e "\nDEBUG: Default autoreconf failed. Running default autoreconf with include for $1\n" >>"$LOG_FILE"
	#rm -rf aclocal.m4 autom4te.cache configure Makefile.in src/Makefile.in m4
	# INSTALL DEFAULT WITH m4
	autoreconf -v -I m4 > >(redirect_output) 2>&1

	EXTRACT_RC=$?
	if [[ ${EXTRACT_RC} -eq 0 ]]; then
		echo -e "\nDEBUG: autoreconf completed successfully for $1\n" >>"$LOG_FILE"
	else
		echo -e "\nDEBUG: Default autoreconf with include for $1 failed\n" >>"$LOG_FILE"
	fi
}

clean_ffmpeg_builds() {
	[[ -z $host_platform ]] && pick_host_platform
  [[ -z $host_arch ]] && pick_host_arch
	pick_clean_type
  if [[ -z $host_name ]]; then
		exit_message 1 "no build flavor provided"
	fi
	setup_build_environment
  clean_builds "$clean_type" "$host_name"
  exit_message 0 "INFO: Done cleaning builds"
}

clean_builds() {
	export clean_type=${1:-clean_type}
  local build_flavor=${2:-host_name}
  echo -e "WARNING: Executing clean for $clean_type and $host_name"
	if [[ ${clean_type,,} =~ ^("all"|"ffmpeg")$ ]]; then
		echo -e "INFO: Deleting ${ffmpeg_install_prefix}..."
		remove_path -rf "${ffmpeg_install_prefix}"
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

set_box_memory_size_bytes() {
	local ram_kilobytes=$(grep MemTotal /proc/meminfo | awk '{print $2}')
	local swap_kilobytes=$(grep SwapTotal /proc/meminfo | awk '{print $2}')
	box_memory_size_bytes=$((ram_kilobytes * 1024 + swap_kilobytes * 1024))
}

function sortable_version { echo -e "$@" | awk -F. '{ printf("%d%03d%03d%03d\n", $1,$2,$3,$4); }'; }

at_least_required_version() { # params: required actual
	local sortable_required=$(sortable_version "$1")
	sortable_required=$(echo -e "$sortable_required" | sed 's/^0*//') # remove preceding zeroes, which bash later interprets as octal or screwy
	local sortable_actual=$(sortable_version "$2")
	sortable_actual=$(echo -e "$sortable_actual" | sed 's/^0*//')
	[[ "$sortable_actual" -ge "$sortable_required" ]]
}

apt_not_installed() {
	for x in "$@"; do
		if ! check_package "$x"; then
			need_install="$need_install $x"
		fi
	done
	echo -e "$need_install"
}

check_package() {
  determine_distro
  local pkg_name="$1"
  local valid_name=""

  if hash "$pkg_name" &>/dev/null; then
    echo "INFO: $pkg_name already installed" >>"$LOG_FILE"
    return 0
  fi
  if $CHECK_INSTALLED_CMD "$pkg_name" &>/dev/null; then
    echo "INFO: $pkg_name already installed" >>"$LOG_FILE"
    return 0
  fi
  if valid_name=$(validate_package "$pkg_name"); then
    if $CHECK_INSTALLED_CMD "$valid_name" &>/dev/null; then
        echo "INFO: $valid_name already installed" >>"$LOG_FILE"
        return 0
    fi
  fi
  return 1
}

get_missing_packages() {
  local missing_packages=()
  for package in "$@"; do
		  if [[ -n $package ]] && ! check_package "$package"; then
        missing_packages+=("$package")
      fi
	done
  for pkg in "${missing_packages[@]}"; do
      echo "$pkg"
  done
}

check_missing_packages() {
  determine_distro
  # apt install autoconf-archive autoconf autogen automake autopoint bc bison bzip2 cargo clang cmake coreutils curl cvs ed ed flex g++ gcc gettext git gperf help2man libtool libtool-bin make meson nasm p7zip-full patch pax pkg-config python3 python3-setuptools python3-venv ragel subversion unzip wget xz-utils yasm zlib1g-dev libglib2.0-dev libglib2.0-dev-bin sudo apt install binutils llvm lld xutils-dev python3-numpy cython3
	# zeranoe's build scripts use wget, though we don't here...
	local check_packages=('ragel' 'curl' 'pkg-config' 'make' 'git' 'svn' 'gcc' 'autoconf' 'automake' 'yasm' 'cvs' 'flex' 'bison' 'makeinfo' 'g++' 'ed' 'pax' 'unzip' 'patch' 'wget' 'xz' 'nasm' 'gperf' 'autogen' 'bzip2' 'realpath' 'clang' 'python3' 'bc' 'autopoint' 'glib-mkenums' 'ld' 'ld.lld')
	
  # autoconf-archive is just for leptonica FWIW
	# I'm not actually sure if VENDOR being set to centos is a thing or not. On all the centos boxes I can test on it's not been set at all.
	# that being said, if it where set I would imagine it would be set to centos... And this contition will satisfy the "Is not initially set"
	# case because the above code will assign "redhat" all the time.
	if [ -z "${VENDOR}" ] || [ "${VENDOR}" != "redhat" ] && [ "${VENDOR}" != "centos" ]; then
		check_packages+=('cmake')
  elif [ "${VENDOR}" == "redhat" ]; then
    check_packages+=('libzstd-devel')
  elif [ "${VENDOR}" == "canonical" ]; then
    check_packages+=('zstd' 'cython3' 'xutils-dev' 'python3-venv' 'python3-numpy')
	fi
	# libtool check is wonky...
	check_packages+=('libtoolize') # the rest of the world
	# Use hash to check if the packages exist or not. Type is a bash builtin which I'm told behaves differently between different versions of bash.
	install_missing_packages=$(get_missing_packages "${check_packages[@]}")
  # for package in "${check_packages[@]}"; do
	# 	  check_package "$package" || missing_packages=("$package" "${missing_packages[@]}")
	# done
	if [ "${VENDOR}" = "redhat" ] || [ "${VENDOR}" = "centos" ]; then
		if [ -n "$(hash cmake 2>&1)" ] && [ -n "$(hash cmake3 2>&1)" ]; then missing_packages=('cmake' "${missing_packages[@]}"); fi
	fi

	if [[ ${#missing_packages[@]} -gt 0 ]]; then
		clear
		echo -e "DEBUG:" | tee -a "$LOG_FILE"
		echo -e "Could not find the following execs (svn is actually package subversion, makeinfo is actually package texinfo if you're missing them): ${missing_packages[*]}" | tee -a "$LOG_FILE"
		echo -e 'Install the missing packages before running this script.' | tee -a "$LOG_FILE"
		
		apt_pkgs='autoconf-archive autoconf autogen automake autopoint bc bison bzip2 cargo clang cmake coreutils curl cvs ed ed flex g++ gcc gettext git gperf help2man libtool libtool-bin make meson nasm p7zip-full patch pax pkg-config python3 python3-setuptools ragel subversion unzip wget xz-utils yasm zlib1g-dev libglib2.0-dev libglib2.0-dev-bin'

		[[ $DISTRO == "debian" ]] && apt_pkgs="$apt_pkgs libtool-bin ed" # extra for debian
		case "$DISTRO" in
		Ubuntu)
			echo -e "for ubuntu:" | tee -a "$LOG_FILE"
			echo -e "$ sudo $INSTALL_COMMAND update" | tee -a "$LOG_FILE"
			ubuntu_ver="$(lsb_release -rs)"
			if [ "$(sortable_version "$ubuntu_ver")" -lt "$(sortable_version "24.04")" ]; then
        echo "Ubuntu < 24.04 not supported."
      fi
			if at_least_required_version "22.04" "$ubuntu_ver"; then
				apt_pkgs="$apt_pkgs ninja-build" # needed
			fi
			echo -e "$ sudo $INSTALL_COMMAND install $apt_pkgs -y" | tee -a "$LOG_FILE"
			;;
		debian)
			echo -e "for debian:" | tee -a "$LOG_FILE"
			echo -e "$ sudo $INSTALL_COMMAND update" | tee -a "$LOG_FILE"
			# Debian version is always encoded in the /etc/debian_version
			# This file is deployed via the base-files package which is the essential one - deployed in all installations.
			# See their content for individual debian releases - https://sources.debian.org/src/base-files/
			# Stable releases contain a version number.
			# Testing/Unstable releases contain a textual codename description (e.g. bullseye/sid)
			#
			deb_ver="$(cat /etc/debian_version)"
			# Upcoming codenames taken from https://en.wikipedia.org/wiki/Debian_version_history
			#
			if [[ $deb_ver =~ bullseye ]]; then
				deb_ver="11"
			elif [[ $deb_ver =~ bookworm ]]; then
				deb_ver="12"
			elif [[ $deb_ver =~ trixie ]]; then
				deb_ver="13"
			fi
			if at_least_required_version "10" "$deb_ver"; then
				apt_pkgs="$apt_pkgs python3-distutils" # guess it's no longer built-in, lensfun requires it...
			fi
			if at_least_required_version "11" "$deb_ver"; then
				apt_pkgs="$apt_pkgs python-is-python3" # needed
			fi
			apt_missing="$(apt_not_installed "$apt_pkgs")"
			echo -e "$ sudo $INSTALL_COMMAND install $apt_missing -y" | tee -a "$LOG_FILE"
			;;
		*)
			exit_message 1 "Build platform not supported. Please use a container with Ubuntu >= 24.04 (noble)"
			;;
		esac
		exit_message 1
	fi

	export REQUIRED_CMAKE_VERSION="3.0.0"
	for cmake_binary in 'cmake' 'cmake3'; do
		# We need to check both binaries the same way because the check for installed packages will work if *only* cmake3 is installed or
		# if *only* cmake is installed.
		# On top of that we ideally would handle the case where someone may have patched their version of cmake themselves, locally, but if
		# the version of cmake required move up to, say, 3.1.0 and the cmake3 package still only pulls in 3.0.0 flat, then the user having manually
		# installed cmake at a higher version wouldn't be detected.
		if hash "$cmake_binary" &>/dev/null; then
			cmake_version="$("${cmake_binary}" --version | sed -e "s#${cmake_binary}##g" | head -n 1 | tr -cd '0-9.\n')"
			if at_least_required_version "${REQUIRED_CMAKE_VERSION}" "${cmake_version}"; then
				export cmake_command="${cmake_binary}"
				break
			else
				echo -e "ERROR: your ${cmake_binary} version is too old ${cmake_version} wanted ${REQUIRED_CMAKE_VERSION}" | tee -a "$LOG_FILE"
			fi
		fi
	done

	# If cmake_command never got assigned then there where no versions found which where sufficient.
	if [ -z "${cmake_command}" ]; then
		exit_message 1 "there where no appropriate versions of cmake found on your machine."
	else
		# If cmake_command is set then either one of the cmake's is adequate.
		if [[ $cmake_command != "cmake" ]]; then # don't echo -e if it's the normal default
			echo -e "DEBUG: cmake binary for this build will be ${cmake_command}" | tee -a "$LOG_FILE"
		fi
	fi

	if [[ ! -f /usr/include/zlib.h ]]; then
		echo -e "WARNING: you may need to install zlib development headers first if you want to build mp4-box [on ubuntu: $ $INSTALL_COMMAND install zlib1g-dev] [on redhat/fedora distros: $ yum install zlib-devel]" | tee -a "$LOG_FILE" # XXX do like configure does and attempt to compile and include zlib.h instead?
		sleep 1
	fi

	# TODO nasm version :|

	# doing the cut thing with an assigned variable dies on the version of yasm I have installed (which I'm pretty sure is the RHEL default)
	# because of all the trailing lines of stuff
	export REQUIRED_YASM_VERSION="1.2.0" # export ???
	local yasm_binary=yasm
	local yasm_version="$("${yasm_binary}" --version | sed -e "s#${yasm_binary}##g" | head -n 1 | tr -dc '0-9.\n')"
	if ! at_least_required_version "${REQUIRED_YASM_VERSION}" "${yasm_version}"; then
		exit_message 1 "your yasm version is too old $yasm_version wanted ${REQUIRED_YASM_VERSION}"
	fi
	# local meson_version=`meson --version`
	# if ! at_least_required_version "0.60.0" "${meson_version}"; then
	# echo -e "your meson version is too old $meson_version wanted 0.60.0"
	# exit_message 1
	# fi
	# also check missing "setup" so it's early LOL

	#check if WSL
	# check WSL for interop setting make sure its disabled
	# check WSL for kernel version look for version 4.19.128 current as of 11/01/2020
	if uname -a | grep -iq -- "-microsoft"; then
		# shellcheck disable=SC2002
		if cat /proc/sys/fs/binfmt_misc/WSLInterop | grep -q enabled; then
			echo -e "windows WSL detected: you must first disable 'binfmt' by running this
      sudo bash -c 'echo -e 0 > /proc/sys/fs/binfmt_misc/WSLInterop'
      then try again" | tee -a "$LOG_FILE"
			#exit_message 1
		fi
		export MINIMUM_KERNEL_VERSION="4.19.128"
		KERNVER=$(uname -a | awk -F'[ ]' '{ print $3 }' | awk -F- '{ print $1 }')

		if [ "$(sortable_version "$KERNVER")" -lt "$(sortable_version "$MINIMUM_KERNEL_VERSION")" ]; then
			echo -e "Windows Subsystem for Linux (WSL) detected - kernel not at minumum version required: $MINIMUM_KERNEL_VERSION
      Please update via windows update then try again" | tee -a "$LOG_FILE"
			#exit_message 1
		fi
	fi

}

determine_distro() {
  local os_id=""
  local os_id_like=""

  unset VENDOR
  unset INSTALL_COMMAND
  unset SEARCH_COMMAND

  if [ -f /etc/os-release ]; then
    . /etc/os-release
    os_id="$ID"
    os_id_like="$ID_LIKE"
  elif [ -f /etc/lsb-release ]; then
    . /etc/lsb-release
    os_id="$DISTRIB_ID"
  else
    os_id=$(uname -s | tr '[:upper:]' '[:lower:]')
  fi
  # shellcheck disable=2222,2221
  case "${os_id}|${os_id_like}" in
    *rhel*|*centos*|*fedora*|*rocky*|*almalinux*|*amzn*)
      export VENDOR="redhat"
      export INSTALL_COMMAND="dnf"
      export SEARCH_COMMAND="dnf list"
      export CHECK_INSTALLED_CMD="rpm -q"
      ;;
    *ubuntu*|*debian*|*mint*|*kali*|*pop*|*raspbian*)
      export VENDOR="canonical"
      export INSTALL_COMMAND="apt-get"
      export SEARCH_COMMAND="apt-cache show"
      export CHECK_INSTALLED_CMD="dpkg -s"
      ;;
    *arch*|*manjaro*|*endeavouros*)
      export VENDOR="arch"
      export INSTALL_COMMAND="pacman"
      export SEARCH_COMMAND="pacman -Ss"
      export CHECK_INSTALLED_CMD="pacman -Q"
      ;;
    *alpine*)
      export VENDOR="alpine"
      export INSTALL_COMMAND="apk"
      export SEARCH_COMMAND="apk search"
      export CHECK_INSTALLED_CMD="apk info -e"
      ;;
    *void*)
      export VENDOR="void"
      export INSTALL_COMMAND="xbps-install"
      export SEARCH_COMMAND="xbps-query -Rs"
      export CHECK_INSTALLED_CMD="xbps-query" 
      ;;
    *gentoo*)
      export VENDOR="gentoo"
      export INSTALL_COMMAND="emerge"
      export SEARCH_COMMAND="emerge --search"
      export CHECK_INSTALLED_CMD="qlist -I"
      ;;
    *freebsd*)
      export VENDOR="freebsd"
      export INSTALL_COMMAND="pkg"
      export SEARCH_COMMAND="pkg search"
      export CHECK_INSTALLED_CMD="pkg info"
      ;;
    *sles*|*suse*)
      export VENDOR="sles"
      export INSTALL_COMMAND="zypper"
      export SEARCH_COMMAND="zypper search"
      export CHECK_INSTALLED_CMD="rpm -q"
      ;;
    *nix*)
      export VENDOR="nix"
      export INSTALL_COMMAND="nix-env"
      export SEARCH_COMMAND="nix-env -qa"
      export CHECK_INSTALLED_CMD="nix-env -q"
      ;;
    *guix*)
      export VENDOR="guix"
      export INSTALL_COMMAND="guix"
      export SEARCH_COMMAND="guix package -A"
      export CHECK_INSTALLED_CMD="guix package -I"
      ;;
    *)
      export VENDOR="unknown"
      return 1
      ;;
  esac
}

package_exists() {
  determine_distro
  local pkg="$1"
  echo "Running $SEARCH_COMMAND $pkg" >>"$LOG_FILE"
  if eval "$SEARCH_COMMAND $pkg -y" >>"$LOG_FILE" 2>&1; then
    return 0
  fi
  return 1
}

validate_package() {
  local pkg="$1"
  local candidates=()

  if package_exists "$pkg"; then
    echo "$pkg"
    return 0
  fi
  if [[ "$pkg" == *-dev ]]; then
    candidates+=("${pkg%-dev}-devel")
  elif [[ "$pkg" == *-devel ]]; then
    candidates+=("${pkg%-devel}-dev")
  fi
  if [[ "$pkg" == lib* ]]; then
    candidates+=("${pkg#lib}")
  else
    candidates+=("lib${pkg}")
  fi
  for candidate in "${candidates[@]}"; do
    if package_exists "$candidate"; then
      [ -n "$LOG_FILE" ] && echo "DEBUG: Remapped '$pkg' to '$candidate'" >> "$LOG_FILE"
      echo "$candidate"
      return 0
    fi
  done
  return 1
}

install_missing_packages() {
  determine_distro
  # shellcheck disable=2086,2048
  mapfile -t missing_packages < <(get_missing_packages $*)
  if [[ "${#missing_packages[*]}" -gt 0 ]]; then
    echo "INFO: Missing packages: ${missing_packages[*]}" >>"$LOG_FILE"
    for package in "${missing_packages[@]}"; do
      new_pkg="$(validate_package "$package")"
      if [[ -n $new_pkg ]]; then
        echo -e "INFO: Installing validated package: $new_pkg\n  running: \"$INSTALL_COMMAND install ${new_pkg} -y\"" >>"$LOG_FILE"
        eval "$INSTALL_COMMAND install ${new_pkg} -y" > >(redirect_output) 2>&1 || true;
      else
        echo "DEBUG: No validated package found for $package" >>"$LOG_FILE"
      fi
    done
  fi
}

# made into a method so I don't/don't have to download this script every time if only doing just 32 or just6 64 bit builds...
download_gcc_build_script() {
	local zeranoe_script_name=$1
	cp "$PATCHDIR"/"$zeranoe_script_name" "$PATCHDIR"/"$zeranoe_script_name".bak
	cp "$PATCHDIR"/"$zeranoe_script_name" "$zeranoe_script_name"
	#rm -f $PATCHDIR/$zeranoe_script_name || exit_message 1
	#curl -4 https://raw.githubusercontent.com/Zeranoe/mingw-w64-build/refs/heads/master/mingw-w64-build -O --fail || exit_message 1
	chmod -R u+rwx "$zeranoe_script_name"
}

# helper methods for downloading and building projects that can take generic input

do_svn_checkout() {
	repo_url="$1"
	to_dir="$2"
	desired_revision="$3"
	if [ ! -d "$to_dir" ]; then
		echo -e "INFO: svn checking out to $to_dir" >>"$LOG_FILE"
		if [[ -z "$desired_revision" ]]; then
			svn checkout "$repo_url" "$to_dir".tmp --non-interactive --trust-server-cert > >(redirect_output) 2>&1 || exit_message 1 "could not checkout $repo_url"
		else
			svn checkout -r "$desired_revision" "$repo_url" "$to_dir".tmp > >(redirect_output) 2>&1 || exit_message 1 "could not checkout $desired_revision $repo_url"
		fi
		mv "$to_dir".tmp "$to_dir" 2>>"$LOG_FILE"
    chmod -R u+rwx "$to_dir" 2>>"$LOG_FILE"
	else
    if truthy "$build_force"; then
      echo -e "INFO: Force requested, resetting repository" >>"$LOG_FILE"
      svn_hard_reset "$to_dir"
		elif truthy "$git_get_latest"; then
      echo -e "INFO: Fetching git instead" >>"$LOG_FILE"
			svn update > >(redirect_output) 2>&1 # want this for later...
		else
      chmod -R u+rwx "$to_dir" 2>>"$LOG_FILE"
      change_dir "$to_dir"
      change_dir ..
    fi
	fi
}

svn_hard_reset() {
    # Get the absolute path of the target
    local target_path
    if command -v realpath >/dev/null 2>&1; then
        target_path=$(realpath "$1" 2>/dev/null) || return
    else
        # Fallback for systems without realpath (like macOS)
        target_path=$(cd -- "$1" && pwd 2>/dev/null) || return
    fi
    
    [ -z "$target_path" ] && return
    
    # Get current directory
    local current_path
    current_path=$(pwd)
    
    # Only proceed if we're in the target directory
    if [ "$current_path" = "$target_path" ]; then
        # Ensure we're in a git repository
        if svn info >/dev/null 2>&1; then
            svn revert -R . > >(redirect_output) 2>&1                                  # Revert all tracked changes
            svn status | grep '^?' | cut -c9- | xargs rm -rf > >(redirect_output) 2>&1 # Remove untracked files
            svn update > >(redirect_output) 2>&1                                       # Get latest from repo
        else
            echo "ERROR: Not a git repository" >&2
            return 1
        fi
    else
        echo "ERROR: Current directory is not the target directory" >&2
        echo "  Current: $current_path" >&2
        echo "  Target:  $target_path" >&2
        return 1
    fi
}

get_git_command() {
  local repo_url="$1"
  local name="$2"
  local to_dir="$3"
  local type="$4"
  case "${type,,}" in
    commit)
    echo "git clone \"$repo_url\" \"$to_dir\" --recurse-submodules --single-branch && cd \"$to_dir\" && git checkout \"$name\""
    return 0
    ;;
    branch)
    echo "git clone --depth 1 --branch \"$name\" \"$repo_url\" \"$to_dir\" --recurse-submodules --single-branch"
    return 0
    ;;
    tag)
    echo "git clone --depth 1 --branch \"$name\" \"$repo_url\" \"$to_dir\" --recurse-submodules --single-branch"
    return 0
    ;;
    *)
    exit_message 1 "invalid git ref type $type"
    exit 1
    ;;
  esac
}

get_valid_remote() {
  local repo_url="$1"
  local name="$2"

  echo "DEBUG: Starting search for '$name' in $repo_url" >>"$LOG_FILE"
  
  # Get all refs at once
  local all_refs
  if ! all_refs=$(git ls-remote "$repo_url" 2>/dev/null); then
    echo -e "DEBUG: Cannot access repository: $repo_url" >>"$LOG_FILE"
    return 1
  fi
  echo "DEBUG: Repository is accessible" >>"$LOG_FILE"

  # Check as commit SHA
  echo "DEBUG: Checking if '$name' is a commit SHA..."  >>"$LOG_FILE"
  if [[ "$name" =~ ^[0-9a-f]{7,40}$ ]]; then
    echo "DEBUG: '$name' matches SHA pattern" >>"$LOG_FILE"
    if echo "$all_refs" | grep -q "^$name"; then
      echo "DEBUG: Found '$name' as a valid commit" >>"$LOG_FILE"
      echo "commit $name"
      return 0
    else
      echo "DEBUG: '$name' matches SHA pattern but not found in remote" >>"$LOG_FILE"
    fi
  fi
  
  # Check as branch
  echo "DEBUG: Checking if '$name' is a branch..." >>"$LOG_FILE"
  if echo "$all_refs" | grep -q "refs/heads/$name"; then
    echo "DEBUG: Found '$name' as a branch" >>"$LOG_FILE"
    echo "branch $name"
    return 0
  fi
  
  # Check as tag
  echo "DEBUG: Checking if '$name' is a tag..." >>"$LOG_FILE"
  if echo "$all_refs" | grep -q "refs/tags/$name"; then
    echo "DEBUG: Found '$name' as a tag" >>"$LOG_FILE"
    echo "tag $name"
    return 0
  fi
  
  # Fallbacks
  echo "DEBUG: Checking fallback branches..." >>"$LOG_FILE"
  for branch in main master; do
    if echo "$all_refs" | grep -q "refs/heads/$branch"; then
      echo "DEBUG: Found fallback branch '$branch'" >>"$LOG_FILE"
      echo "branch $branch"
      return 0
    fi
  done
  
  echo -e "DEBUG: No valid branch/tag/commit found in $repo_url (tried: $name, main, master)" >>"$LOG_FILE"
  return 1
}

# params: git url, to_dir
retry_git_or_die() { # originally from https://stackoverflow.com/a/76012343/32453
	local RETRIES_NO=50
	local RETRY_DELAY=30
	local repo_url="$1"
	local to_dir="$2"
	local desired_branch="$3"
  # shellcheck disable=2248,2207
  local valid_remote=($(get_valid_remote "$repo_url" "$desired_branch"))
  local remote_type="${valid_remote[0]}"
  local remote_name="${valid_remote[*]:1}"
  local git_command="$(get_git_command "$repo_url" "$remote_name" "$to_dir.tmp" "$remote_type")"
	for i in $(seq 1 $RETRIES_NO); do
    if [[ -n $git_command ]]; then
      echo -e "INFO: Downloading (via git clone) branch, tag, or commit: $desired_branch to $to_dir from $repo_url" >>"$LOG_FILE"
      remove_path -rf "$to_dir.tmp" # just in case it was interrupted previously...not sure if necessary...
      create_dir "$to_dir.tmp"
      echo -e "DEBUG: Evaluating \"$git_command\"\n" >>"$LOG_FILE"
      # shellcheck disable=SC2086
      eval "$git_command" > >(redirect_output) 2>&1 && chmod -R u+rwx "$to_dir.tmp" && break
    else
      exit_message 1 "Could not generate git command for $repo_url $remote_type $remote_name $to_dir"
    fi
		#git clone --depth 1 -b "$desired_branch" "$repo_url" "$to_dir.tmp" --recurse-submodules --single-branch && break
		# get here -> failure
		[[ $i -eq $RETRIES_NO ]] && exit_message 1 "DEBUG: Failed to execute git cmd $repo_url $to_dir after $RETRIES_NO retries"
		echo -e "DEBUG: sleeping before retry git" >>"$LOG_FILE"
		sleep "${RETRY_DELAY}"
	done
	# prevent partial checkout confusion by renaming it only after success
	#mv $to_dir.tmp $to_dir
	echo -e "INFO: done git cloning branch $desired_branch to $to_dir" >>"$LOG_FILE"
}

is_valid_git_dir() {
    local dir="$1"
    if (GIT_DIR="$dir/.git" git rev-parse --git-dir > /dev/null 2>&1); then
        return 0
    else
        return 1
    fi
}

is_empty_dir() {
    local dir="$1"
    if [[ -d "$dir" ]] && [[ -z "$(find "$dir" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
        return 0  # empty
    else
        return 1  # not empty
    fi
}

# Get the current branch name (e.g., "main" or "feature/login")
get_git_branch() {
  git branch --show-current 2>/dev/null
}

# Get the most recent tag (e.g., "v1.0.4")
get_git_tag() {
  git describe --tags --abbrev=0 2>/dev/null
}

# Get the "release" (The tag + how many commits ahead of it you are)
get_git_release() {
  git describe --tags 2>/dev/null
}

# Get the short hash (e.g., "a1b2c3d")
get_git_commit() {
  git rev-parse HEAD 2>/dev/null
}

# Get the short commit hash (e.g., "a1b2c3d")
get_git_commit_short() {
  git rev-parse --short HEAD 2>/dev/null
}

is_current_git_ref() {
    local input="$1"
    
    [ -z "$input" ] && return 1

    # 1. Check against current Branch name
    local current_branch=$(get_git_branch)
    local all_refs=$(git ls-remote "$repo_url" 2>/dev/null)
    echo "DEBUG: Checking branch $current_branch against $input" >>"$LOG_FILE"
    if [[ "$input" == "$current_branch" ]]; then
      echo "DEBUG: Matched branch $input == $current_branch" >>"$LOG_FILE"
      return 0
    fi
    # 2. Check against current exact Tag
    # (Checking if HEAD is exactly at this tag)
    local current_tag=$(get_git_tag)
    echo "DEBUG: Checking tag $current_tag against $input" >>"$LOG_FILE"
    if [[ "$input" == "$current_tag" ]]; then
      echo "DEBUG: Matched tag $input == $current_tag" >>"$LOG_FILE"
      return 0
    fi

    # 3. Check against current Release string 
    # (e.g., v1.0.4-5-g7f2)
    local current_release=$(get_git_release)
    echo "DEBUG: Checking release $current_release against $input" >>"$LOG_FILE"
    if [[ "$input" == "$current_release" ]]; then 
      echo "DEBUG: Matched release $input == $current_release" >>"$LOG_FILE"
      return 0
    fi

    # 4. Check against current Commit (Long and Short)
    local long_commit=$(get_git_commit)
    local short_commit=$(get_git_commit_short)
    echo "DEBUG: Checking comit $long_commit against $input" >>"$LOG_FILE"
    echo "DEBUG: Checking release $short_commit against $input" >>"$LOG_FILE"
    if [[ "$input" == "$long_commit" ]]; then
      echo "DEBUG: Matched long commit $input == $long_commit" >>"$LOG_FILE"
      return 0
    elif [[ "$input" == "$short_commit" ]]; then
      echo "DEBUG: Matched short commit $input == $short_commit" >>"$LOG_FILE"
      return 0
    fi
    echo "DEBUG: $input is not current git ref" >>"$LOG_FILE"
    return 1
}

# 1. repo_url
# 2. to_dir
# 3. desired_branch
do_git_checkout() {
	local repo_url="$1"
	local to_dir="$2"
	if [[ -n "$3" ]]; then
		desired_branch="$3"
	else
		desired_branch="master"
	fi
	echo -e "INFO: Starting git checkout $repo_url" >>"$LOG_FILE"
	if [[ -z $to_dir ]]; then
		to_dir=$(basename "$repo_url" | sed 's/\.git$//; s/[?#].*$//') # http://y/abc.git -> abc
	fi
	if [ -d "$to_dir" ] && is_valid_git_dir "$to_dir"; then
    echo -e "INFO: Directory already exists $to_dir." >>"$LOG_FILE"
		change_dir "$to_dir"
    if ! is_current_git_ref "$desired_branch"; then
      git_hard_reset "$(pwd)"
      eval "git fetch --unshallow" >>"$LOG_FILE" 2>/dev/null
      eval "git config remote.origin.fetch \"+refs/heads/*:refs/remotes/origin/*\"" >>"$LOG_FILE" 2>/dev/null
      eval "git fetch --all --tags" >>"$LOG_FILE" 2>/dev/null
      local valid_remote=("$(get_valid_remote "$repo_url" "$desired_branch")")
      local remote_type="${valid_remote[0]}"
      local remote_name="${valid_remote[*]:1}"
      eval "git checkout $remote_name" >>"$LOG_FILE" || exit_message 1 "could not checkout $remote_name from $repo_url"
    fi
    if truthy "$build_force"; then
      echo -e "INFO: Force requested, resetting repository" >>"$LOG_FILE"
      git_hard_reset "$(pwd)"
		fi
    if truthy "$git_get_latest"; then
      echo -e "INFO: Fetching git instead" >>"$LOG_FILE"
			git fetch --quiet >>"$LOG_FILE" # want this for later...
		else
			echo -e "INFO: not doing git get latest pull for latest code $to_dir" >>"$LOG_FILE" # too slow'ish...
		fi
	else
    if [[ -d "$to_dir" ]] && is_empty_dir "$to_dir"; then
      echo -e "INFO: Empty directory already exists at $to_dir. Deleting before downloading." >>"$LOG_FILE"
      remove_path -rf "$to_dir"
    fi
		echo -e "INFO: Downloading $repo_url $desired_branch into $to_dir" >>"$LOG_FILE"
		retry_git_or_die "$repo_url" "$to_dir" "$desired_branch" || exit_message 1 "could not checkout $desired_branch from $repo_url"
    mv "$to_dir.tmp" "$to_dir" 2>>"$LOG_FILE"
		chmod -R u+rwx "$to_dir" 2>>"$LOG_FILE"
    change_dir "$to_dir"
	fi
}

do_git_sparse_checkout() {
  local repo_url="$1"
	local to_dir="$2"
  local path="$3"
	echo -e "INFO: Starting git checkout $repo_url" >>"$LOG_FILE"
	if [[ -z $to_dir ]]; then
		to_dir=$(basename "$repo_url" | sed 's/\.git$//; s/[?#].*$//') # http://y/abc.git -> abc
	fi
	if [ -d "$to_dir" ] && is_valid_git_dir "$to_dir"; then
    echo -e "INFO: Directory already exists $to_dir." >>"$LOG_FILE"
		change_dir "$to_dir"
    if truthy "$build_force"; then
      echo -e "INFO: Force requested, resetting repository" >>"$LOG_FILE"
      git_hard_reset "$(pwd)"
      git sparse-checkout init --cone > >(redirect_output) 2>&1 || exit_message 1 "could not re-init sparse-checkout"
      git sparse-checkout set "$path" > >(redirect_output) 2>&1 || exit_message 1 "could not set sparse-checkout path"
      git checkout > >(redirect_output) 2>&1 || exit_message 1 "could not checkout"
		elif truthy "$git_get_latest"; then
      echo -e "INFO: Fetching git instead" >>"$LOG_FILE"
			git fetch --quiet >>"$LOG_FILE" # want this for later...
      git sparse-checkout set "$path" > >(redirect_output) 2>&1
      git checkout > >(redirect_output) 2>&1 || exit_message 1 "could not checkout after fetch"
		else
			echo -e "INFO: not doing git get latest pull for latest code $to_dir" >>"$LOG_FILE" # too slow'ish...
      git sparse-checkout set "$path" > >(redirect_output) 2>&1
		fi
	else
    [[ -d "$to_dir.tmp" ]] && (remove_path -rf "$to_dir.tmp"; true) # just in case it failed previously
    if [[ -d "$to_dir" ]] && is_empty_dir "$to_dir"; then
      echo -e "INFO: Empty directory already exists at $to_dir. Deleting before downloading." >>"$LOG_FILE"
      remove_path -rf "$to_dir"
    fi
		echo -e "INFO: Downloading $repo_url into $to_dir" >>"$LOG_FILE"
		git clone --no-checkout "$repo_url" "$to_dir.tmp" > >(redirect_output) 2>&1 || exit_message 1 "could not \"git clone --no-checkout\" $repo_url"
    change_dir "$to_dir.tmp"
    git sparse-checkout init --cone > >(redirect_output) 2>&1 || exit_message 1 "could not \"git sparse-checkout init --cone\" $repo_url"
    git sparse-checkout set "$path" > >(redirect_output) 2>&1 || exit_message 1 "could not \"git sparse-checkout set $path\" $repo_url"
    git checkout > >(redirect_output) 2>&1 || exit_message 1 "could not \"git checkout\" $repo_url"
    change_dir ..
    mv "$to_dir.tmp" "$to_dir" 2>>"$LOG_FILE"
		chmod -R u+rwx "$to_dir" 2>>"$LOG_FILE"
    change_dir "$to_dir"
	fi
  echo -e "INFO: Successfully checked out $path from $repo_url into $(pwd)" >>"$LOG_FILE"
}

git_hard_reset() {
    # Get the absolute path of the target
    local target_path
    if command -v realpath >/dev/null 2>&1; then
        target_path=$(realpath "$1" 2>/dev/null) || return
    else
        # Fallback for systems without realpath (like macOS)
        target_path=$(cd -- "$1" && pwd 2>/dev/null) || return
    fi
    
    [ -z "$target_path" ] && return
    
    # Get current directory
    local current_path
    current_path=$(pwd)
    
    # Only proceed if we're in the target directory
    if [ "$current_path" = "$target_path" ]; then
        # Ensure we're in a git repository
        if git rev-parse --git-dir >/dev/null 2>&1; then
            git reset --hard > >(redirect_output) 2>&1
            git clean -fd > >(redirect_output) 2>&1
        else
            echo "ERROR: Not a git repository" >&2
            return 1
        fi
    else
        echo "ERROR: Current directory is not the target directory" >&2
        echo "  Current: $current_path" >&2
        echo "  Target:  $target_path" >&2
        return 1
    fi
}

# 1. exit_code
# 2. file_name
create_touch_file() {
	local exit_code="$1"
  local file_name="$2"
  echo -e "INFO: creating touch file $file_name" >>"$LOG_FILE"
	if truthy "$exit_code"; then
		touch "$file_name" >>"$LOG_FILE" || exit_message 1 "unable to create touch file $file_name"
	else
		touch "$file_name" >>"$LOG_FILE" || echo -e "DEBUG: unable to create touch file $file_name" | tee -a "$LOG_FILE"
	fi
}

get_small_touchfile_name() { # have to call with assignment like a=$(get_small...)
	local beginning="$1"
	local extra_stuff="$2"
	local touch_name="${beginning}_$(echo -e -- "$extra_stuff" | /usr/bin/env md5sum)" # md5sum to make it smaller, cflags to force rebuild if changes
	touch_name=$(echo -e "$touch_name" | sed "s/ //g")                                                      # md5sum introduces spaces, remove them
	echo -e "$touch_name.touch"                                                                                   # bash cruddy return system LOL
}

redirect_output() {
	local term_width="${COLUMNS:-80}"
  local max_length=$((term_width > 10 ? term_width - 2 : 78))
  while IFS= read -r line; do
		if [[ "$line" == *$'\n'* ]]; then
      IFS=$'\n' read -ra parts <<< "$line"
      for part in "${parts[@]}"; do
				if [ "${#part}" -gt "$max_length" ]; then
        	part="${part:0:$max_length}…"
      	fi
        printf "\r\033[K%s" "$part"
      done
    else
			part=$line
			if [ "${#part}" -gt "$max_length" ]; then
        part="${part:0:$max_length}…"
      fi
			printf "\r\033[K%s" "$part"
		fi
		echo "$line" 1>>"$LOG_FILE" 2>&1
	done
}
# use if cargo build needs it
confirm_libgcc_eh() {
    local search_dir="$1"
    [[ -d "$search_dir" ]] || return 1
    
    # Exit early if any libgcc_eh.a exists
    find "$search_dir" -name "libgcc_eh.a" -quit 2>/dev/null && \
        { return 0; }
    
    while IFS= read -r -d '' file; do
        cp "$file" "${file%/*}/libgcc_eh.a" && echo "Created: ${file%/*}/libgcc_eh.a"
    done < <(find "$search_dir" -name "libgcc.a" -type f -print0 2>/dev/null)
}
# 1. configure_options
# 2. configure_name
# 2. configure_env
# 4. touch_postfix
do_python() {
	local configure_options="$1"
	local configure_name=$2
	local configure_env="$3"
	local touch_postfix=""
	[[ -n $4 ]] && touch_postfix="_${4}_" || touch_postfix="_"
	if [[ -z "${configure_name[*]}" ]]; then
		configure_name=("./waf" "configure -v")
	fi
  if [[ "${configure_name[*]}" == *"waf"* ]]; then
    remove_path -rf .waf3*
    remove_path -rf __pycache__
    [[ -d "waflib" ]] && remove_path -rf waflib
    echo -e "DEBUG: updating waf to latest version..." >>"$LOG_FILE"
    wget https://waf.io/waf-2.1.9 -O waf > >(redirect_output) 2>&1
    chmod +x waf
  fi
  # shellcheck disable=SC2206,SC2128
  configure_command=(python3 ${configure_name[*]})
	local cur_dir2=$(pwd)
	local english_name=$(basename "$cur_dir2")
  local touch_prefix="${host_name}${touch_postfix}already"
	local touch_name=$(get_small_touchfile_name "${touch_prefix}_python_$(basename "${configure_name[*]}")" "$configure_options")
	if truthy "$build_force"; then
		reset_touch "$cur_dir2"
    { eval "python3 ./waf clean" > >(redirect_output) 2>&1 || true; }
    { eval "python3 ./waf uninstall" > >(redirect_output) 2>&1 || true; }
	fi
	if [ ! -f "$touch_name" ]; then
    remove_path -f "${touch_prefix}_python_$(basename "${configure_name[*]}")"*
		echo -e "INFO: Using python:\n  DIR=$cur_dir2\n  PATH=$PATH\n  PKG_CONFIG_PATH=$PKG_CONFIG_PATH\n  CFLAGS:$CFLAGS\n  CXXFLAGS:$CXXFLAGS\n  CPPFLAGS:$CPPFLAGS\n  LDFLAGS:$LDFLAGS\n  $english_name ($PWD) as PATH=$PATH ${configure_env}\n ${configure_command[*]} $configure_options" >>"$LOG_FILE"
		# shellcheck disable=SC1078,SC2086
		eval "${configure_command[*]} $configure_options" > >(redirect_output) 2>&1 || exit_message 1 "could not run configure ${configure_command[*]}"
		create_touch_file 0 "$touch_name"
	else
		echo -e "INFO: Already used python $(basename "$cur_dir2")" >>"$LOG_FILE"
	fi
}
# shellcheck disable=SC2086
# 1. extra_build_args
# 2. extra_install_args
cargo_build_and_install() {
	local extra_build_args="$1"
	local extra_install_args="$2"
	do_cargo_build "$extra_build_args"
	do_cargo_install "$extra_install_args"
}

# shellcheck disable=SC2086
# 1. extra_build_args
do_cargo_build() {
	local extra_build_args="$1"
  local touch_postfix=""
  [[ -n $2 ]] && touch_postfix="_${2}_" || touch_postfix="_"
	local cur_dir2=$(pwd)
  local touch_prefix="${host_name}${touch_postfix}already"
	local touch_name=$(get_small_touchfile_name "${touch_prefix}_cargo_build" "cargo build $extra_build_args")
	if truthy "$build_force"; then
		reset_touch "$cur_dir2"
    { cargo uninstall >>"$LOG_FILE" 2>&1 || true; }
    { cargo clean --release >>"$LOG_FILE" 2>&1 || true; }
	fi
	if [ ! -f "$touch_name" ]; then
    remove_path -f "${touch_prefix}_cargo_build"*
    { cargo clean --release >>"$LOG_FILE" 2>&1 || true; }
    export RUSTFLAGS+=" -C relocation-model=pic"
		echo -e "INFO: Running cargo build with:\n  DIR=$cur_dir2\n  RUSTFLAGS=$RUSTFLAGS\n  PATH=$PATH\n  PKG_CONFIG_PATH=$PKG_CONFIG_PATH\n  CFLAGS:$CFLAGS\n  CXXFLAGS:$CXXFLAGS\n  CPPFLAGS:$CPPFLAGS\n  LDFLAGS:$LDFLAGS\n  \"cargo build --target $rust_target $extra_build_args\"" >>"$LOG_FILE"
    rustup target add $rust_target > >(redirect_output) 2>&1
		cargo build --target "$rust_target" $extra_build_args > >(redirect_output) 2>&1 || {
			exit_message 1 "failed cargo build with $extra_build_args\n see $LOG_FILE for more details"
		}
		create_touch_file 0 "$touch_name"
		echo -e "INFO: Done with cargo build" >>"$LOG_FILE"
	else
		echo -e "INFO: Cargo already build" >>"$LOG_FILE"
	fi
}

# shellcheck disable=SC2086
# 1. extra_install_args
do_cargo_install() {
	local extra_install_args="$1"
  local touch_postfix=""
  [[ -n $2 ]] && touch_postfix="_${2}_" || touch_postfix="_"
	local cur_dir2=$(pwd)
  local touch_prefix="${host_name}${touch_postfix}already"
	local touch_name=$(get_small_touchfile_name "${touch_prefix}_cargo_install" "cargo install $extra_install_args")
	if truthy "$build_force"; then
		reset_touch "$cur_dir2"
	fi
	if [ ! -f "$touch_name" ]; then
    remove_path -f "${touch_prefix}_cargo_install"*
    export RUSTFLAGS+=" -C relocation-model=pic"
		echo -e "INFO: Running cargo install cargo-c" >>"$LOG_FILE"
    echo -e "INFO: Running cargo cinstall with:\n  DIR=$cur_dir2\n  RUSTFLAGS=$RUSTFLAGS\n  PATH=$PATH\n  PKG_CONFIG_PATH=$PKG_CONFIG_PATH\n  CFLAGS:$CFLAGS\n  CXXFLAGS:$CXXFLAGS\n  CPPFLAGS:$CPPFLAGS\n  LDFLAGS:$LDFLAGS\n  \"cargo cinstall --prefix=$dependency_install_prefix --target $rust_target $extra_install_args\"" >>"$LOG_FILE"
    cargo cinstall --prefix="$dependency_install_prefix" --target "$rust_target" $extra_install_args > >(redirect_output) 2>&1 || {
			exit_message 1 "failed cargo cinstall with $extra_install_args\n see $LOG_FILE for more details"
		}
		create_touch_file 0 "$touch_name"
		echo -e "INFO: Done with cargo cinstall" >>"$LOG_FILE"
	else
		echo -e "INFO: Cargo already installed" >>"$LOG_FILE"
	fi
}

# 1. configure_options
# 2. configure_name
# 3. touch_postfix
# shellcheck disable=2178,2128
do_configure() {
	local configure_options="$1"
	local configure_name="$2"
	local touch_postfix=""
	[[ -n $3 ]] && touch_postfix="_${3}_" || touch_postfix="_"
	if [[ -z "$configure_name" ]]; then
    if [[ -f Configure ]]; then
      configure_name="./Configure"
    else
      configure_name="./configure"
    fi
	fi
	local cur_dir2=$(pwd)
	local english_name=$(basename "$cur_dir2")
  local touch_prefix="${host_name}${touch_postfix}already"
	local touch_name=$(get_small_touchfile_name "${touch_prefix}_configure" "$configure_options $configure_name")
	if truthy "$build_force"; then
		reset_touch "$cur_dir2"
    { nice make clean -j"$(get_concurrent_proc)" > >(redirect_output) 2>&1 || true; }
    [[ -f ninja.build ]] && { nice ninja uninstall > >(redirect_output) 2>&1 || true; }
    [[ -f Makefile ]] && { nice make uninstall > >(redirect_output) 2>&1 || true; }
	fi
	if [ ! -f "$touch_name" ]; then
    remove_path -f "${touch_prefix}_configure"*
    { nice make clean -j"$(get_concurrent_proc)" > >(redirect_output) 2>&1 || true; }
		# make uninstall # does weird things when run under ffmpeg src so disabled for now...
		echo -e "INFO: configuring $english_name ($PWD) $configure_name $configure_options" >>"$LOG_FILE" # say it now in case bootstrap fails etc.
		echo -e "INFO: all touch files ${touch_prefix}_configure* touchname= $touch_name" >>"$LOG_FILE"
		echo -e "INFO: config options $configure_name $configure_options" >>"$LOG_FILE"
    if [ -f bootstrap ]; then
			./bootstrap > >(redirect_output) 2>&1 # some need this to create ./configure :|
		fi
		if [[ ! -f $configure_name && -f bootstrap.sh ]]; then # fftw wants to only run this if no configure :|
			./bootstrap.sh > >(redirect_output) 2>&1
		fi
    if [[ ! -f $configure_name && -f configure.ac ]]; then
      echo -e "INFO: Configure not found. Running autoreconf with existing configure.ac..." >>"$LOG_FILE"
			autoreconf_library # a handful of them require this to create ./configure :|
    fi
    if [[ ! -f Makefile.in && ! -f Makefile ]]; then
      echo -e "INFO: Makefile and Makefile.in not found. running autoreconf and automake..." >>"$LOG_FILE"
      autoreconf_library # a handful of them require this to create ./configure :|
      automake --force-missing --add-missing > >(redirect_output) 2>&1
    fi
		if [[ ! -f $configure_name ]]; then
      if [[ -f gitsub.sh ]]; then
        echo "INFO: gitsub.sh found. Running gitsub.sh..."
        ./gitsub.sh pull
      fi
      if [ -f autogen.sh ]; then
        echo "INFO: autogen.sh found. Running autogen.sh..."
			  ./autogen.sh > >(redirect_output) 2>&1 # some need this to create ./configure :|
		  fi
		fi
    if [[ ! -f config.h.in ]]; then
      echo -e "INFO: config.h.in not found. Running autoheader..." >>"$LOG_FILE"
      autoheader > >(redirect_output) 2>&1
    fi
		chmod -R u+rwx "$configure_name" # In non-windows environments, with devcontainers, the configuration file doesn't have execution permissions
		echo -e "INFO: do_configure() with:\n  DIR=$cur_dir2\n  PATH=$PATH\n  PKG_CONFIG_PATH=$PKG_CONFIG_PATH\n  CFLAGS:$CFLAGS\n  CXXFLAGS:$CXXFLAGS\n  CPPFLAGS:$CPPFLAGS\n  LDFLAGS:$LDFLAGS\n nice running: \"$configure_name $configure_options\"" >>"$LOG_FILE"
		eval "nice -n 5 $configure_name $configure_options" > >(redirect_output) 2>&1 || {
			exit_message 1 "failed configure $english_name \n see $(find "$(pwd)" -name "config.log" -print)"
		} # less nicey than make (since single thread, and what if you're running another ffmpeg nice build elsewhere?)
		create_touch_file 0 "$touch_name"
	else
	 echo -e "DEBUG: already configured $(basename "$cur_dir2")" >>"$LOG_FILE"
	fi
}
# 1. extra config options
# 2. configure_name
# 3. touch_postfix
# shellcheck disable=2128,2178
generic_configure() {
	build_triple="${build_triple:-$(gcc -dumpmachine)}"
	local extra_configure_options="$1"
  local configure_name="$2"
  local touch_postfix="$3"
	local options=$extra_configure_options
	if [[ -n $build_triple ]]; then extra_configure_options+=" --build=$build_triple"; fi
  options+=" --disable-shared --enable-static"
	do_configure "--host=$host_target --prefix=$dependency_install_prefix $options" "$configure_name" "$touch_postfix"
}
# 1. extra_build_args
# 2. touch_postfix
# shellcheck disable=SC2086
do_autogen() {
  local extra_build_args="$1"
	local cur_dir2=$(pwd)
  [[ -n $2 ]] && touch_postfix="_${2}_" || touch_postfix="_"
  local touch_prefix="${host_name}${touch_postfix}already"
	local touch_name=$(get_small_touchfile_name "${touch_prefix}_autogen" "autogen $extra_build_args")
	if truthy "$build_force"; then
		reset_touch "$cur_dir2"
	fi
	if [ ! -f "$touch_name" ]; then
    remove_path -f "${touch_prefix}_autogen"*
		echo -e "INFO: Running ./autogen.sh with:\n  DIR=$cur_dir2\n  \"./autogen.sh --build-"w$bits_target" $extra_build_args\"" >>"$LOG_FILE"
		./autogen.sh --build-"w$bits_target" $extra_build_args > >(redirect_output) 2>&1 || {
			exit_message 1 "failed ./autogen.sh with $extra_build_args\n see $LOG_FILE for more details"
		}
		create_touch_file 0 "$touch_name"
		echo -e "INFO: Done with ./autogen.sh" >>"$LOG_FILE"
	else
		echo -e "INFO: ./autogen.sh already ran" >>"$LOG_FILE"
	fi
}
# 1. extra_make_options
# 2. touch_postfix
do_make() {
	local extra_make_options="$1"
	local touch_postfix=""
	[[ -n $2 ]] && touch_postfix="_${2}_" || touch_postfix="_"
	extra_make_options="-j$(get_concurrent_proc) $extra_make_options"
	local cur_dir2=$(pwd)
  local touch_prefix="${host_name}${touch_postfix}already"
	local touch_name=$(get_small_touchfile_name "${touch_prefix}_make_make" "make $extra_make_options")
	if truthy "$build_force"; then
		reset_touch "$cur_dir2"
    { nice make clean -j"$(get_concurrent_proc)" > >(redirect_output) 2>&1 || true; }
    [[ -f ninja.build ]] && { nice ninja uninstall > >(redirect_output) 2>&1 || true; }
    [[ -f Makefile ]] && { nice make uninstall > >(redirect_output) 2>&1 || true; }
	fi
	if [ ! -f "$touch_name" ]; then
    remove_path -f "${touch_prefix}_make_make"*
    { nice make clean -j"$(get_concurrent_proc)" > >(redirect_output) 2>&1 || true; }
		echo -e "INFO: Making $cur_dir2 as $ PATH=$PATH make $extra_make_options" >>"$LOG_FILE"
		echo -e "INFO: do_make()with:\n  DIR=$cur_dir2\n  PATH=$PATH\n  PKG_CONFIG_PATH=$PKG_CONFIG_PATH\n  CFLAGS:$CFLAGS\n  CXXFLAGS:$CXXFLAGS\n  CPPFLAGS:$CPPFLAGS\n  LDFLAGS:$LDFLAGS\n  nice running: \"make $extra_make_options\"" >>"$LOG_FILE"
		eval "nice make $extra_make_options" > >(redirect_output) 2>&1 || exit_message 1 "could not make with $extra_make_options"
		create_touch_file 0 "$touch_name" # only touch if the build was OK
	else
		echo -e "INFO: Already made $(dirname "$cur_dir2") $(basename "$cur_dir2") ..." >>"$LOG_FILE"
	fi
}
generic_make() {
  extra_make_options="$1"
  touch_postfix="$2"
  do_make "$extra_make_options PREFIX=$dependency_install_prefix" "$touch_postfix"
}
generic_make_install() {
  extra_install_options="$1"
  touch_postfix="$2"
  do_make_install "$extra_install_options PREFIX=$dependency_install_prefix" "" "$touch_postfix"
}
# 1. extra_make_options
# 2. extra_install_options
# 3. touch_postfix
do_make_and_make_install() {
	extra_make_options="$1"
	extra_install_options="$2"
	touch_postfix="$3"
	generic_make "$extra_make_options" "$touch_postfix"
	do_make_install "$extra_install_options" "" "$touch_postfix"
}
# 1. extra_make_install_options
# 2. override_make_install_options
# 3. touch_postfix
do_make_install() {
	local extra_make_install_options="$1"
	local override_make_install_options="$2" # startingly, some need/use something different than just 'make install'
	local touch_postfix=""
  local cur_dir2=$(pwd)
	[[ -n $3 ]] && touch_postfix="_${3}_" || touch_postfix="_"
	if [[ -z $override_make_install_options ]]; then
		local make_install_options="install $extra_make_install_options"
	else
		local make_install_options="$override_make_install_options $extra_make_install_options"
	fi
  local touch_prefix="${host_name}${touch_postfix}already"
	local touch_name=$(get_small_touchfile_name "${touch_prefix}_make_install" "make install $make_install_options")
	if truthy "$build_force"; then
		reset_touch "$cur_dir2"
    [[ -f ninja.build ]] && { nice ninja uninstall > >(redirect_output) 2>&1 || true; }
    [[ -f Makefile ]] && { nice make uninstall > >(redirect_output) 2>&1 || true; }
	fi
	if [ ! -f "$touch_name" ]; then
    remove_path -f "${touch_prefix}_make_install"*
		echo -e "INFO: do_make_install() with:\n  DIR=$(pwd)\n  PATH=$PATH\n  PKG_CONFIG_PATH=$PKG_CONFIG_PATH\n  CFLAGS:$CFLAGS\n  CXXFLAGS:$CXXFLAGS\n  CPPFLAGS:$CPPFLAGS\n  LDFLAGS:$LDFLAGS\n  nice running: \"make $make_install_options\"" >>"$LOG_FILE"
		eval "nice make -j$(get_concurrent_proc) $make_install_options" > >(redirect_output) 2>&1 || exit_message 1 "could not make with $make_install_options"
		create_touch_file 0 "$touch_name"
	fi
}

# Usage example:
clean_cmake_cache() {
    local build_dir="${1:-./build}"
    local source_dir="${2:-$(pwd)}"
    do_clean_steps() {
        if [[ -f build.ninja || -f ninja.build ]]; then
             echo "  Running ninja clean..." >>"$LOG_FILE"
             nice ninja -t clean >/dev/null 2>&1 || true
        fi
        if [[ -f Makefile ]]; then
             echo "  Running make clean..." >>"$LOG_FILE"
             nice make clean -j"$(get_concurrent_proc)" >/dev/null 2>&1 || true
             nice make distclean -j"$(get_concurrent_proc)" >/dev/null 2>&1 || true
        fi
        echo "  Force removing CMake artifacts..." >>"$LOG_FILE"
        rm -rf CMakeCache.txt CMakeFiles cmake_install.cmake Makefile build.ninja ninja.build
    }
    if [[ "$(realpath "$build_dir")" == "$(realpath "$source_dir")" ]]; then
        echo "DEBUG: clean_cmake_cache: In-source build detected." >>"$LOG_FILE"
        do_clean_steps
    else
        echo "DEBUG: clean_cmake_cache: Out-of-source build in $build_dir" >>"$LOG_FILE"
        if [ -d "$build_dir" ]; then
            ( cd "$build_dir" && do_clean_steps )
        fi
    fi
}

# 1. extra_args
# 2. source_dir
# 3. touch_postfix
do_cmake() {
	extra_args="$1"
	local source_dir="$2"
	local touch_postfix=""
  local cur_dir2=$(pwd)
	[[ -n $3 ]] && touch_postfix="_${3}_" || touch_postfix="_"
	if [[ -z $source_dir ]]; then
		source_dir="$cur_dir2"
	fi
  local touch_prefix="${host_name}${touch_postfix}already"
	local touch_name=$(get_small_touchfile_name "${touch_prefix}_cmake" "cmake $extra_args")
	if truthy "$build_force"; then
		reset_touch "$cur_dir2"
    [[ -f ninja.build ]] && { nice ninja uninstall > >(redirect_output) 2>&1 || true; }
    [[ -f Makefile ]] && { nice make uninstall > >(redirect_output) 2>&1 || true; }
    { clean_cmake_cache "$cur_dir2" "$(realpath "$source_dir")" || true; }
	fi
	if [ ! -f "$touch_name" ]; then
    remove_path -f "${touch_prefix}_cmake"*
    [[ -f ninja.build ]] && { nice ninja uninstall > >(redirect_output) 2>&1 || true; }
    [[ -f Makefile ]] && { nice make uninstall > >(redirect_output) 2>&1 || true; }
    { clean_cmake_cache "$cur_dir2" "$(realpath "$source_dir")" || true; }
    [[ ! -d "$cur_dir2" ]] && create_dir "$cur_dir2"
		local config_options=""
		if [ "$bits_target" = 32 ]; then
			local config_options+="-DCMAKE_SYSTEM_PROCESSOR=x86"
		else
			local config_options+="-DCMAKE_SYSTEM_PROCESSOR=AMD64"
		fi
    local command="${source_dir} -DCMAKE_MESSAGE_LOG_LEVEL=ERROR"
		command+=" $extra_args"
		echo -e "INFO: do_cmake() nice running:\n  DIR=$cur_dir2\n  PATH=$PATH\n  PKG_CONFIG_PATH=$PKG_CONFIG_PATH\n  CFLAGS:$CFLAGS\n  CXXFLAGS:$CXXFLAGS\n  CPPFLAGS:$CPPFLAGS\n  LDFLAGS:$LDFLAGS\n  \"${cmake_command} -G\"Unix Makefiles\" $command\"" >>"$LOG_FILE"
		# shellcheck disable=SC2086
		eval "nice -n 5 ${cmake_command} -G\"Unix Makefiles\" $command" > >(redirect_output) 2>&1 || exit_message 1 "could not run nice: \"${cmake_command} -G\"Unix Makefiles\" $command\""
		create_touch_file 0 "$touch_name"
	fi
}
generic_cmake() {
  # 1. extra_args
  # 2. source_dir
  # 3. touch_postfix
  extra_args="$1"
  source_dir="$2"
	touch_postfix="$3"
  if [[ $host_platform == "windows" ]]; then
      extra_args+=" -DENABLE_STATIC_RUNTIME=1 \
-DCMAKE_SYSTEM_NAME=Windows \
-DCMAKE_RANLIB=${cross_prefix}ranlib \
-DCMAKE_C_COMPILER=${cross_prefix}gcc \
-DCMAKE_CXX_COMPILER=${cross_prefix}g++ \
-DCMAKE_RC_COMPILER=${cross_prefix}windres"
  fi
		extra_args+=" -DCMAKE_FIND_ROOT_PATH=$dependency_install_prefix \
-DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
-DCMAKE_INSTALL_LIBDIR=$dependency_install_prefix/lib \
-DCMAKE_INSTALL_PREFIX=$dependency_install_prefix \
$config_options"
  [[ $extra_args != *"-DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY"* ]] && extra_args+=" -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY"
  [[ $extra_args != *"-DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE"* ]] && extra_args+=" -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY"
  [[ $extra_args != *"-DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE"* ]] && extra_args+=" -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY"
  extra_args+=" -DBUILD_STATIC_LIBS=1 -DENABLE_STATIC=1"
  extra_args+=" -DCMAKE_POSITION_INDEPENDENT_CODE=1"
  do_cmake "$extra_args" "$source_dir" "$touch_postfix"
}
# 1. source_dir
# 2. extra_args
# 3. touch_postfix
do_cmake_from_build_dir() { # some sources don't allow it, weird XXX combine with the above :)
	source_dir="$1"
	extra_args="$2"
	touch_postfix="$3"
	generic_cmake "$extra_args" "$source_dir" "$touch_postfix"
}
# 1. extra_args
# 2. source_dir
# 3. touch_postfix
do_cmake_and_install() {
	extra_args="$1"
	source_dir="$2"
	touch_postfix="$3"
	generic_cmake "$extra_args" "$source_dir" "$touch_postfix"
	do_make_and_make_install "" "" "$touch_postfix"
}

activate_meson() {
	echo -e "INFO: Activating meson" >>"$LOG_FILE"
	change_dir "$src_dir" # requires python3-full
	if [[ ! -e meson_git ]]; then
		do_git_checkout https://github.com/mesonbuild/meson.git meson "1.9.1"
	fi
	change_dir "$src_dir/meson"
	export local_meson="$src_dir/meson/meson.py"
	if [ ! -e tutorial_env ] && [ -f "$src_dir/meson/tutorial_env/bin/activate" ]; then
		python3 -m venv tutorial_env
		# shellcheck disable=SC1090
		source "$src_dir/meson/tutorial_env/bin/activate"
		python3 -m pip install meson
	fi
	change_dir "$src_dir"
}
# 1. configure_options
# 2. configure_name
# 2. configure_env
# 4. touch_postfix
# shellcheck disable=2178
do_meson() {
	local configure_options="$1"
	local configure_name="$2"
	local configure_env="$3"
	local touch_postfix=""
	[[ -n $4 ]] && touch_postfix="_${4}_" || touch_postfix="_"
	if [[ -z "${configure_command[*]}" || "${configure_command[*]}" == "setup build" ]]; then
		configure_name=("setup" "build")
		configure_options+=" --unity=off --warnlevel=0"
	fi
	if [[ -e "$local_meson" ]]; then
    # shellcheck disable=SC2206,SC2128
    configure_command=(python3 "$local_meson" ${configure_name[*]})
	else
		configure_command=(meson)
	fi
	local cur_dir2=$(pwd)
	local english_name=$(basename "$cur_dir2")
  local touch_prefix="${host_name}${touch_postfix}already"
	local touch_name=$(get_small_touchfile_name "${touch_prefix}_meson_${configure_name[*]}" "meson $configure_options")
	if truthy "$build_force"; then
		reset_touch "$cur_dir2"
    [[ -f ninja.build ]] && { nice ninja uninstall > >(redirect_output) 2>&1 || true; }
    [[ -f Makefile ]] && { nice make uninstall > >(redirect_output) 2>&1 || true; }
    { python3 "$local_meson" compile --clean -C build > >(redirect_output) 2>&1 || true; }
	fi
	if [ ! -f "$touch_name" ]; then
		if [[ -n "${configure_command[*]}" && -d "$(pwd)/build" && "${configure_name[*]}" == "setup build" ]]; then
      remove_path -f "${touch_prefix}_meson_${configure_name[*]}"*
      { python3 "$local_meson" compile --clean -C build > >(redirect_output) 2>&1 || true; }
			echo -e "INFO: Adding --reconfigure to meson config because there is an existing previous build" >>"$LOG_FILE"
			configure_options+=" --reconfigure"
		fi
		echo -e "INFO: Using meson:\n  DIR=$cur_dir2\n  PATH=$PATH\n  PKG_CONFIG_PATH=$PKG_CONFIG_PATH\n  CFLAGS:$CFLAGS\n  CXXFLAGS:$CXXFLAGS\n  CPPFLAGS:$CPPFLAGS\n  LDFLAGS:$LDFLAGS\n  ${configure_command[*]} $configure_options" >>"$LOG_FILE"
		#env
		export MESON_BUILD_ROOT="$(pwd)/build"
		export MESON_SOURCE_ROOT="$(pwd)"
		#create_dir "$(pwd)/build"
		# shellcheck disable=SC2086
		# shellcheck disable=SC1078
		eval "${configure_command[*]} $configure_options" > >(redirect_output) 2>&1 || exit_message 1 "could not run configure ${configure_command[*]}"
		create_touch_file 0 "$touch_name"
	else
		echo -e "INFO: Already used meson $(basename "$cur_dir2")" >>"$LOG_FILE"
	fi
}
# 1. extra_args
# 2. touch_postfix
generic_meson() {
	local extra_configure_options="$1"
	local touch_postfix="$2"
	#create_dir "$(pwd)/build"
  extra_configure_options+=" -Dprefix=${dependency_install_prefix} -Dlibdir=${dependency_install_prefix}/lib -Dbuildtype=release"
  extra_configure_options+=" --default-library=static -Db_staticpic=true"
	do_meson "$extra_configure_options" "setup build" "$touch_postfix" # --cross-file=$(get_meson_cross_file)
}
# 1. extra_args
# 2. touch_postfix
generic_meson_ninja_install() {
	generic_meson "$1" "$2"
	do_ninja_and_ninja_install "$1" "$2"
}
# 1. extra_args
# 2. touch_postfix
do_ninja_and_ninja_install() {
	local extra_ninja_options="$1"
	local touch_postfix=""
  local cur_dir2=$(pwd)
	[[ -n $2 ]] && touch_postfix="_${2}_" || touch_postfix="_"
	do_ninja "$extra_ninja_options" "$touch_postfix"
  local touch_prefix="${host_name}${touch_postfix}already"
	local touch_name=$(get_small_touchfile_name "${touch_prefix}_ninja_install" "ninja install $extra_ninja_options")
	if truthy "$build_force"; then
		reset_touch "$cur_dir2"
	fi
	if [ ! -f "$touch_name" ]; then
    remove_path -f "${touch_prefix}_ninja_install"* # reset
		echo -e "INFO: do_ninja() with:\n  DIR=$cur_dir2\n  PATH=$PATH\n  PKG_CONFIG_PATH=$PKG_CONFIG_PATH\n  CFLAGS:$CFLAGS\n  CXXFLAGS:$CXXFLAGS\n  CPPFLAGS:$CPPFLAGS\n  LDFLAGS:$LDFLAGS\n  in $(pwd) ninja running: \"build $extra_make_options\"" >>"$LOG_FILE"
		ninja -C build install > >(redirect_output) 2>&1 || exit_message 1 "could not do_ninja() in $(pwd) ninja running: \"build $extra_make_options\""
		create_touch_file 0 "$touch_name"
	fi
}

# 1. touch_postfix
do_ninja() {
	local touch_postfix=""
	[[ -n $1 ]] && touch_postfix="_${1}_" || touch_postfix="_"
	local extra_make_options=" -j $(get_concurrent_proc)"
	local cur_dir2=$(pwd)
  local touch_prefix="${host_name}${touch_postfix}already"
	local touch_name=$(get_small_touchfile_name "${touch_prefix}_ninja_build" "ninja build $extra_make_options")
	if truthy "$build_force"; then
		reset_touch "$cur_dir2"
    [[ -f ninja.build ]] && { nice ninja uninstall > >(redirect_output) 2>&1 || true; }
    [[ -f Makefile ]] && { nice make uninstall > >(redirect_output) 2>&1 || true; }
	fi
	if [ ! -f "$touch_name" ]; then
    remove_path -f "${touch_prefix}_ninja_build"*
		echo -e "INFO: ninja-ing $cur_dir2 as PATH=$PATH ninja -C build $extra_make_options" >>"$LOG_FILE"
		echo -e "INFO: do_ninja() ninja running:\n  DIR=$cur_dir2\n  PATH=$PATH\n  PKG_CONFIG_PATH=$PKG_CONFIG_PATH\n  CFLAGS:$CFLAGS\n  CXXFLAGS:$CXXFLAGS\n  CPPFLAGS:$CPPFLAGS\n  LDFLAGS:$LDFLAGS\n  \"build $extra_make_options\"" >>"$LOG_FILE"
		# shellcheck disable=SC2086
		ninja -C build ${extra_make_options} > >(redirect_output) 2>&1 || exit_message 1 "could not do_ninja() ninja running: \"build $extra_make_options\""
		create_touch_file 0 "$touch_name" # only touch if the build was OK
	else
		echo -e "INFO: already did ninja $(basename "$cur_dir2")" >>"$LOG_FILE"
	fi
}

# 1. url
# 2. patch_type
# 3. extra_args
apply_patch() {
	local url=$1 # if you want it to use a local file instead of a url one [i.e. local file with local modifications] specify it like file://localhost/full/path/to/filename.patch
	local patch_type=$2
	local extra_args=$3
	if [[ -z $patch_type ]]; then
		patch_type="-p0" # some are -p1 unfortunately, git's default
	fi
	local patch_name=$(basename "$url")
	local patch_done_name="$patch_name.done"
	local touch_name=
	if [[ ! -e $patch_done_name ]]; then
		if [[ -f $patch_name ]]; then
			remove_path -rf "$patch_name" || exit_message 1 # remove old version in case it has been since updated on the server...
		fi
		curl -4 --retry 5 "$url" -O --fail || exit_message 1 "unable to download patch file $url"
		echo -e "INFO: applying patch $patch_name" >>"$LOG_FILE"
		# shellcheck disable=SC2086
		patch "$patch_type" $extra_args <"$patch_name" > >(redirect_output) 2>&1 || exit_message 1 "unable apply patch file $url"
		create_touch_file 1 "$patch_done_name"
		# too crazy, you can't do do_configure then apply a patch?
		# rm -f already_ran* # if it's a new patch, reset everything too, in case it's really really really new
	#else
	#  echo -e "patch $patch_name already applied" # too chatty
	fi
}

# takes a url, output_dir as params, output_dir optional
download_and_unpack_file() {
    local url="$1"
    local dest_folder="$2"
    local filename
    filename=$(basename "$url")
    if [[ -n "$dest_folder" ]]; then
        if [ ! -d "$dest_folder" ]; then
            create_dir "$dest_folder" || exit_message 1 "could not create dir $dest_folder"
            chmod -R u+rwx "$dest_folder"
        fi
    fi
    local touch_name="${dest_folder}/$(get_small_touchfile_name "already_unpacked_successfully" "$url $dest_folder")"
    if [ ! -f "$touch_name" ]; then
        echo "INFO: Downloading $url into $dest_folder" >>"$LOG_FILE"
        if [[ "$filename" == *.zst ]] && ! command -v zstd &> /dev/null; then
             exit_message 1 "zstd is not installed. Run: sudo $INSTALL_COMMAND install zstd"
        fi
        if [[ -f "$filename" ]]; then
            rm -f "$filename"
        fi
        curl -4 "$url" --retry 50 -o "$filename" -L --fail > >(redirect_output) 2>&1 || {
            exit_message 1 "unable to download $url"
        }
        echo "INFO: Unzipping $filename inside $dest_folder ..." >>"$LOG_FILE"
        if [[ "${filename,,}" =~ \.(zip|whl)$ ]]; then
            extract_zip "$filename" "$dest_folder" > >(redirect_output) 2>&1
            #unzip -o "$filename" > >(redirect_output) 2>&1 || exit_message 1 "unzip failed"
        else
            extract_tar "$filename" "$dest_folder" > >(redirect_output) 2>&1
            #tar -xf "$filename" > >(redirect_output) 2>&1 || exit_message 1 "tar failed"
        fi
        remove_path -f "$filename"
        chmod -R u+rwx "$dest_folder"
        create_touch_file 0 "$touch_name"
    else
      echo "DEBUG: Archive already downloaded and extracted at $dest_folder" >>"$LOG_FILE"
      chmod -R u+rwx "$dest_folder"
    fi
}
extract_tar() {
    local archive="$1"
    local dest_dir=${2:-"$(basename "$archive" | sed s/\.tar\.*//)"}
    
    # Get unique top-level items using mapfile
    local top_items
    mapfile -t top_items < <(tar -tf "$archive" --strip-components=0 | cut -d/ -f1 | sort -u)
    
    if [[ ${#top_items[@]} -eq 1 ]]; then
        # Single top-level directory
        tar -xf "$archive" -C "$dest_dir" --strip-components=1
    else
        # Multiple items at root
        tar -xf "$archive" -C "$dest_dir"
    fi
}
extract_zip() {
    local archive="$1"
    local dest_dir=${2:-"$(basename "$archive" | sed s/\.zip//)"}
    
    # Get unique top-level items using mapfile
    local top_items
    mapfile -t top_items < <(unzip -Z -1 "$archive" | cut -d/ -f1 | sort -u)
    
    if [[ ${#top_items[@]} -eq 1 ]]; then
        # Single top-level directory
        mkdir -p "$dest_dir"
        # Extract everything then move contents up one level
        unzip -o "$archive" -d "$dest_dir"
        # Move contents up one level
        shopt -s dotglob  # Include hidden files
        mv "$dest_dir/${top_items[0]}/"* "$dest_dir/" 2>/dev/null || true
        shopt -u dotglob
        rmdir "$dest_dir/${top_items[0]}" 2>/dev/null || true
    else
        # Multiple items: normal extraction
        unzip -o "$archive" -d "$dest_dir"
    fi
}

# 1. url, 
# 2. optional to_dir
# 3. extra_configure_options
generic_download_and_make_and_install() {
	local url="$1"
	local to_dir=${2:-"$(basename "$url" | sed s/\.tar\.*//)"}
	local extra_configure_options="$3"
	change_dir "$src_dir"
  download_and_unpack_file "$url" "$to_dir"
	change_dir "$src_dir/$to_dir"
	generic_configure "$extra_configure_options"
	do_make_and_make_install
	change_dir "$src_dir"
}

# 1. extra_config_args
# 2. configure_name
# 3. extra_make_options
# 4. extra_install_options
# 5. touch_postfix
# shellcheck disable=2128,2178
generic_configure_make_install() {
	local extra_config_args="$1"
  local configure_name="$2"
	local extra_make_options="$3"
	local extra_install_options="$4"
	local touch_postfix="$5"
	generic_configure "$extra_config_args" "$configure_name" "$touch_postfix" # no parameters, force myself to break it up if needed
	do_make_and_make_install "$extra_make_options" "$extra_install_options" "$touch_postfix"
}
# 1. git url
# 2. optional to_dir
# 3. version
do_git_checkout_and_make_install() {
	local url=$1
	local git_checkout_name=${2:-"$(basename "$url" | sed s/\.git//)"} # http://y/abc.git -> abc
  local git_version="$3"
  change_dir "$src_dir"
	do_git_checkout "$url" "$git_checkout_name" "$git_version"
	change_dir "$src_dir/$git_checkout_name"
	generic_configure_make_install
	change_dir "$src_dir"
}

# 1. lib
# 2. lib_s
gen_ld_script() {
	library=$dependency_install_prefix/lib/$1
	lib_s="$2"
	if [[ ! -f $dependency_install_prefix/lib/lib$lib_s.a ]]; then
		echo -e "Generating linker script $library: $2 $3" >>"$LOG_FILE"
		mv -f "$library" "$dependency_install_prefix"/lib/lib"$lib_s".a
		echo -e "GROUP ( -l$lib_s $3 )" >"$library"
	fi
}

install_local_dependency() {
  eval "$INSTALL_COMMAND update && sudo $INSTALL_COMMAND install -y $*" > >(redirect_output) 2>&1 || exit_message 1 "failed to install required dependencies"
}

# Usage: convert_msvc_to_mingw -t=<directory_to_scan> -c=<toolchain_prefix> -o=<output_pc_file> -i=<install dir> -v=<version> -n=<descriptive name> -d=<description>
# Example: convert_msvc_to_mingw -t=./openvino_dist -c=x86_64-w64-mingw32- -o=libopenvino.pc -i=build -v=1.0 -n="OpenVINO Toolkit"  -d="Open-source software toolkit for optimizing and deploying deep learning models"
convert_msvc_to_mingw() {
    local TARGET_DIR=""
    local TOOLCHAIN_PREFIX=""
    local LIB_NAME=""
    local LIB_INSTALL_DIR=""
    local LOG_FILE="${LOG_FILE:-/dev/null}"

    # 1. Parse Arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -t=*|--target=*) TARGET_DIR="${1#*=}"; shift ;;
            -c=*|--toolchain=*) TOOLCHAIN_PREFIX="${1#*=}"; shift ;;
            -o=*|--libname=*) LIB_NAME="${1#*=}"; shift ;;
            -i=*|--install=*) LIB_INSTALL_DIR="${1#*=}"; shift ;;
            -v=*|--version=*) LIB_VERSION="${1#*=}"; shift ;;
            -n=*|--name=*) LIB_DESC_NAME="${1#*=}"; shift ;;
            -d=*|--desc=*) LIB_DESC="${1#*=}"; shift ;;
            --) shift; break ;;
            *) echo "ERROR: Unknown option '$1'"; return 1 ;;
        esac
    done

    # 2. Validation
    if [[ -z "$TARGET_DIR" || -z "$TOOLCHAIN_PREFIX" || -z "$LIB_NAME" ]]; then
        echo "Usage: convert_msvc_to_mingw -t=<source_dir> -c=<prefix> -o=<pkg_name> [-i=<install_dir>]"
        return 1
    fi

    # 3. Setup Install Directory
    if [[ -z "$LIB_INSTALL_DIR" ]]; then
        LIB_INSTALL_DIR="$(pwd)/mingw_bundle"
    fi
    
    # Create standard hierarchy
    # Note: Added 'lib/cmake' for cmake config files
    mkdir -p "$LIB_INSTALL_DIR"/{lib/pkgconfig,include,bin,lib/cmake}

    local PKG_CFG_FILE="$LIB_INSTALL_DIR/lib/pkgconfig/$LIB_NAME.pc"

    # 4. Check Tools
    local DLLTOOL="${TOOLCHAIN_PREFIX}dlltool"
    # Allow fallback if the specific variable isn't set, but prefer the explicit path
    local GENDEF="${dependency_install_prefix:-/usr}/bin/gendef"
    
    if [ ! -f "$GENDEF" ]; then
        # Try generic path if explicit path fails
        GENDEF="gendef"
    fi

    if ! command -v "$DLLTOOL" &> /dev/null; then echo "Error: $DLLTOOL not found"; return 1; fi
    if ! command -v "$GENDEF" &> /dev/null; then echo "Error: 'gendef' not found."; return 1; fi

    echo "INFO --- Converting artifacts from: $TARGET_DIR ---" | tee -a "$LOG_FILE"
    echo "INFO --- Installing to bundle: $LIB_INSTALL_DIR ---" | tee -a "$LOG_FILE"

    # 5. COPY HEADERS
    local SOURCE_INC=""
    # Check common locations
    if [ -d "$TARGET_DIR/runtime/include" ]; then SOURCE_INC="$TARGET_DIR/runtime/include";
    elif [ -d "$TARGET_DIR/include" ]; then SOURCE_INC="$TARGET_DIR/include"; fi

    if [ -n "$SOURCE_INC" ]; then
        echo "  Copying headers from $SOURCE_INC..." >> "$LOG_FILE"
        cp -r "$SOURCE_INC/"* "$LIB_INSTALL_DIR/include/"
    else
        echo "WARNING: No include directory found in $TARGET_DIR" | tee -a "$LOG_FILE"
    fi

    local LIBS_FLAG=""

    # 6. Process DLLs (Generate Import Libs)
    echo "  Scanning for DLLs to convert..." >> "$LOG_FILE"
    while IFS= read -r -d '' dll_file; do
        local base_name=$(basename "$dll_file" .dll)
        local def_file="${LIB_INSTALL_DIR}/lib/${base_name}.def"
        local a_file="${LIB_INSTALL_DIR}/lib/lib${base_name}.a"
        local dll_dest="${LIB_INSTALL_DIR}/bin/${base_name}.dll"

        echo "    Processing: $base_name.dll"
        
        # Copy runtime DLL to bin
        cp -f "$dll_file" "$dll_dest"

        # A. Generate .def
        "$GENDEF" "$dll_file" > /dev/null 2>&1
        # gendef outputs to local dir, move it to dest
        if [ -f "${base_name}.def" ]; then mv "${base_name}.def" "$def_file"; fi

        # B. Generate .a lib
        local def_line_count=0
        [ -f "$def_file" ] && def_line_count=$(wc -l < "$def_file")
        
        if [ "$def_line_count" -gt 2 ] && "$DLLTOOL" -d "$def_file" -l "$a_file" -D "$(basename "$dll_file")"; then
            echo "    -> Created import lib: $a_file" >> "$LOG_FILE"
            rm "$def_file"
            LIBS_FLAG="$LIBS_FLAG -l${base_name}"
        else
             echo "    WARNING: Failed to create valid lib for $base_name (No exports?)" >> "$LOG_FILE"
             rm -f "$def_file" "$a_file"
        fi

    done < <(find "$TARGET_DIR" -type f -name "*.dll" -print0)

    # 7. COPY ADDITIONAL ARTIFACTS
    echo "  Copying additional artifacts..." >> "$LOG_FILE"

    # 7a. Executables (.exe) -> bin/
    find "$TARGET_DIR" -type f -name "*.exe" -print0 | while IFS= read -r -d '' exe_file; do
        echo "    Copying Executable: $(basename "$exe_file")" >> "$LOG_FILE"
        cp -f "$exe_file" "$LIB_INSTALL_DIR/bin/"
    done

    # 7b. Static/Import Libraries (.lib) -> lib/
    # (Optional: preserves original MSVC libs if needed by other tools)
    find "$TARGET_DIR" -type f -name "*.lib" -print0 | while IFS= read -r -d '' lib_file; do
        cp -f "$lib_file" "$LIB_INSTALL_DIR/lib/"
    done

    # 7c. Auxiliary Files (Configs, CMake, Plugins) -> bin/ or lib/cmake/
    #   - *.cmake -> lib/cmake/
    #   - *.xml, *.lst, *.ini, *.cache -> bin/ (Runtime configs usually must sit next to DLLs)
    
    # CMake Configs
    find "$TARGET_DIR" -type f -name "*.cmake" -print0 | while IFS= read -r -d '' cmake_file; do
        cp -f "$cmake_file" "$LIB_INSTALL_DIR/lib/cmake/"
    done

    # Runtime Configs (e.g. plugins.xml for OpenVINO)
    find "$TARGET_DIR" -type f \( -name "*.xml" -o -name "*.lst" -o -name "*.ini" -o -name "*.cache" -o -name "*.json" \) -print0 | while IFS= read -r -d '' cfg_file; do
        # We copy these to bin/ because that is where the DLLs are.
        # Windows/MinGW apps typically look in the executable directory for config files.
        cp -f "$cfg_file" "$LIB_INSTALL_DIR/bin/"
    done

    # 8. Generate Pkg-Config
    cat > "$PKG_CFG_FILE" <<EOF
prefix=${LIB_INSTALL_DIR}
exec_prefix=\${prefix}
libdir=\${prefix}/lib
includedir=\${prefix}/include
bindir=\${prefix}/bin

Name: ${LIB_DESC_NAME}
Description: ${LIB_DESC}
Version: $LIB_VERSION
Libs: -L\${libdir} ${LIBS_FLAG} -lstdc++
Cflags: -I\${includedir}
EOF
    echo "  Pkg-config saved to: $PKG_CFG_FILE" >> "$LOG_FILE"
}

# Usage: check_pkg_config_files <path_to_file.pc>
check_pkg_config_files() {
    local PC_FILE_PATH="$1"

    if [ -z "$PC_FILE_PATH" ]; then
        echo "DEBUG: Usage: check_pkg_config_files <path_to_file.pc>" | tee -a "$LOG_FILE"
        return 1
    fi

    # 1. Setup Environment
    # Temporarily add the .pc file's directory to PKG_CONFIG_PATH so the tool can read it
    local PC_DIR
    PC_DIR=$(dirname "$(realpath "$PC_FILE_PATH")")
    local PC_NAME
    PC_NAME=$(basename "$PC_FILE_PATH" .pc)

    export PKG_CONFIG_PATH="$PC_DIR:$PKG_CONFIG_PATH"
    echo -e "DEBUG: PKG_CONFIG_PATH:\n$PKG_CONFIG_PATH" >>"$LOG_FILE"

    echo "INFO: --- Inspecting: $PC_NAME ---" >>"$LOG_FILE"

    # 2. Check Include Directories (-I)
    echo "  Checking Include Paths:"
    local cflags
    if ! cflags=$(pkg-config --cflags-only-I "$PC_NAME" 2>/dev/null); then
        echo "  [Error] Could not parse Cflags. Syntax error in .pc file?" | tee -a "$LOG_FILE"
        return 1
    fi

    for flag in $cflags; do
        # Remove -I prefix
        local dir="${flag#-I}"
        if [ -d "$dir" ]; then
            echo "  [OK] Found dir: $dir" >>"$LOG_FILE"
        else
            echo "  [MISSING] Directory not found: $dir" >>"$LOG_FILE"
        fi
    done

    # 3. Check Library Directories (-L)
    echo "  Checking Library Paths:" >>"$LOG_FILE"
    local ldflags
    ldflags=$(pkg-config --libs-only-L "$PC_NAME")
    # Create an array of search paths
    local search_paths=()
    for flag in $ldflags; do
        local dir="${flag#-L}"
        if [ -d "$dir" ]; then
            echo "  [OK] Found dir: $dir" >>"$LOG_FILE"
            search_paths+=("$dir")
        else
            echo "  [MISSING] Library Path not found: $dir" >>"$LOG_FILE"
        fi
    done

    # 4. Check Individual Libraries (-l)
    echo "  Checking Libraries:" >>"$LOG_FILE"
    local libs
    libs=$(pkg-config --libs-only-l "$PC_NAME")
    
    for library in $libs; do
        local lib_name="${library#-l}"
        local found=false
        
        # Search in all -L paths found earlier
        for path in "${search_paths[@]}"; do
            # Check for MinGW/Linux naming conventions
            # 1. libNAME.a (Static MinGW/Linux)
            # 2. libNAME.dll.a (Import MinGW)
            # 3. NAME.lib (MSVC style, sometimes used by lld)
            # 4. libNAME.so (Linux shared)
            
            if   [ -f "$path/lib${lib_name}.a" ]; then found=true; found_path="$path/lib${lib_name}.a"
            elif [ -f "$path/lib${lib_name}.dll.a" ]; then found=true; found_path="$path/lib${lib_name}.dll.a"
            elif [ -f "$path/${lib_name}.lib" ]; then found=true; found_path="$path/${lib_name}.lib"
            elif [ -f "$path/lib${lib_name}.so" ]; then found=true; found_path="$path/lib${lib_name}.so"
            fi
            
            if [ "$found" = true ]; then
                break
            fi
        done

        if [ "$found" = true ]; then
            echo "  [OK] Found -l$lib_name -> $found_path" >>"$LOG_FILE"
        else
            echo "  [MISSING] Could not find library for '-l$lib_name' in any search path." >>"$LOG_FILE"
            return 1
        fi
    done
    return 0
}

check_pkg_config_batch() {
    # 1. Collect files from arguments (handling wildcards)
    local files=()
    
    # Check if no arguments provided
    if [ $# -eq 0 ]; then
        echo "DEBUG: Usage: check_pkg_config_batch \"/path/to/*.pc\"" | tee -a "$LOG_FILE"
        return 1
    fi

    for arg in "$@"; do
        # Check if argument contains a wildcard (*)
        if [[ "$arg" == *"*"* ]]; then
            # If it's a quoted glob pattern, expand it safely using compgen
            # This handles filenames with spaces correctly
            while IFS= read -r file; do
                files+=("$file")
            done < <(compgen -G "$arg")
        else
            # Otherwise, it's a specific file or shell-expanded path
            files+=("$arg")
        fi
    done

    # 2. Check if we found anything
    if [ ${#files[@]} -eq 0 ]; then
        echo "DEBUG: No .pc files found matching your input." | tee -a "$LOG_FILE"
        return 1
    fi

    echo "INFO: Found ${#files[@]} file(s). Starting checks..." >>"$LOG_FILE"
    echo "  ==========================================" >>"$LOG_FILE"

    # 3. Iterate and check
    for pc_file in "${files[@]}"; do
        if [ -f "$pc_file" ]; then
            check_pkg_config_files "$pc_file"
            echo "  ------------------------------------------" >>"$LOG_FILE"
        else
            echo "  Skipping invalid file: $pc_file" >>"$LOG_FILE"
        fi
    done
}

download_ffmpeg() {
	local output_dir="$ffmpeg_source_dir"
	local desired_version="$ffmpeg_git_checkout_version"

	if [[ -z $desired_version ]]; then
		desired_version="master"
	fi
  if ! is_valid_git_dir "$ffmpeg_source_dir"; then
	  do_git_checkout "$ffmpeg_git_checkout" "$output_dir" "$desired_version" || exit_message 1 "could not git $ffmpeg_git_checkout $output_dir $desired_version"
    ffmpeg_source_dir=$output_dir
	fi
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

run_valid_build_functions() {
	local start_from=$1
	local skip_mode=${2:-false}
	# Create a clean array without empty elements
	local steps=0
	local current_step=0
  export LDFLAGS+=" -static-libgcc -static-libstdc++"
  if [[ -n "$start_from" && "$start_from" == build_* ]] && ! array_index_of "$start_from" "${BUILD_STEPS[@]}" >/dev/null; then
    run_valid_function "$start_from"
  elif [[ -n "$start_from" && "$start_from" == build_* ]] && truthy "$skip_mode"; then
    run_valid_function "$start_from"
  else
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
      echo -e "INFO: Starting from step: $start_from" | tee -a "$LOG_FILE"
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
          echo -e "INFO: Building dependencies from: $step_name" | tee -a "$LOG_FILE"
        else
          ((current_step++))
          continue
        fi
      fi
      ((current_step++))
      print_progress "$current_step" "$steps" "$step_name"
      run_valid_function "$step_name" || echo | tee -a "$LOG_FILE"
    done
    printf "\r\033[KAll dependencies built successfully!\n"
  fi
  check_static_pic "$dependency_install_prefix/lib/pkgconfig"
  reset_ldflags
}

run_valid_function() {
	step=$1
	if [[ -n "$step" ]]; then
		change_dir "$src_dir"
		if declare -F "$step" >/dev/null; then
			echo -e "INFO: --- Executing step: $step ---" >>"$LOG_FILE"
			"$step" # Execute the function
			echo -e "INFO: --- Finished executing step: $step ---" >>"$LOG_FILE"
		else
			echo -e "ERROR: Function '$step' not found." | tee -a "$LOG_FILE"
			return 1 # Indicate an error
		fi
	else
		echo -e "ERROR: Step argument is missing." | tee -a "$LOG_FILE"
		return 1 # Indicate an error
	fi
}

# shellcheck disable=SC2120
configure_ffmpeg() {
	echo -e "INFO: Configuring ffmpeg" | tee -a "$LOG_FILE"
	
	change_dir "$ffmpeg_source_dir" || return 1

	if truthy "$build_force"; then
		remove_path -f "${ffmpeg_source_dir}/already_configured_$build_ffmpeg_type"*
	fi

	change_dir "$ffmpeg_source_dir" || exit
	[[ $host_platform == "windows" ]] && apply_patch file://"$PATCHDIR"/frei0r_load-shared-libraries-dynamically.diff
	if [ "$bits_target" = "32" ]; then
		local arch=x86
	else
		local arch=amd64
	fi

	local postpend_configure_opts=""
	local init_options=""

  if [[ $host_platform == "windows" ]]; then
	  init_options+=" --target-os=mingw32"
    init_options+=" --enable-w32threads"
  else
    init_options+=" --target-os=$host_platform"
    init_options+=" --enable-pthreads"
  fi

  init_options+=" --pkg-config=pkg-config"
	init_options+=" --pkg-config-flags=--static"
	init_options+=" --enable-version3"
	init_options+=" --arch=$arch"
	init_options+=" --prefix=$ffmpeg_install_prefix"
  init_options+=" --extra-ldflags=\"-Wl,--allow-multiple-definition\""
	init_options+=" --enable-pic"
	init_options+=" --enable-swscale"
  init_options+=" --extra-libs=\"-lm -lstdc++ -lrt -ldl\""
  init_options+=" --extra-cflags=\"-ffunction-sections -fdata-sections\""
  init_options+=" --extra-cxxflags=\"-ffunction-sections -fdata-sections\""
	truthy "$enable_lto" && init_options+=" --enable-optimizations"
	truthy "$build_small" && init_options+=" --enable-small"

	if [[ $host_platform != "linux" ]]; then
    init_options+=" --enable-cross-compile"
    init_options+=" --cross-prefix=$cross_prefix"
  else
    init_options+=" --extra-libs=\"-lpthread\""
  fi

  if [[ $host_platform == "windows" ]]; then
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
  fi

	# can't mix and match --enable-static --enable-shared unfortunately, or the final executable seems to just use shared if the're both present
	if [[ $build_ffmpeg_type == "static" ]]; then
		postpend_configure_opts=" --enable-static --disable-shared --enable-pic"
    init_options+=" --extra-cflags=\"-fPIC -DPIC\""
    init_options+=" --extra-cxxflags=\"-fPIC -DPIC\""
    init_options+=" --env=\"X86ASMFLAGS=-DPIC\""
	else
    postpend_configure_opts=" --enable-shared --disable-static"
	fi

	local config_options=""
	config_options+=" --disable-doc"
	config_options+=" --disable-htmlpages"
  config_options+=" --disable-manpages"
  config_options+=" --disable-podpages"
  config_options+=" --disable-txtpages"
	config_options+=" --disable-outdev=fbdev"
  config_options+=" --disable-indev=fbdev"

  #------------------------------------------------------------------------------     
  # ----------------------------- android features ------------------------------     
  #------------------------------------------------------------------------------      
  if [[ $host_platform == "android" ]]; then
  truthy "$disable_jni" && config_options+=" --disable-jni"                           # enable JNI support [no]
  truthy "$disable_ladspa" && config_options+=" --disable-ladspa"                     # enable LADSPA audio filtering [no]
  truthy "$disable_mediacodec" && config_options+=" --disable-mediacodec"             # enable Android MediaCodec support [no]
  fi
  #------------------------------------------------------------------------------    
  # --------------------------- OpenHarmony features ----------------------------     
  #------------------------------------------------------------------------------    
  if [[ $host_platform == "harmony" ]]; then
  truthy "$enable_ohcodec" && config_options+=" --enable-ohcodec"                     # enable OpenHarmony Codec support [no]
  fi
  #------------------------------------------------------------------------------    
  # --------------------------- linux/unix features -----------------------------     
  #------------------------------------------------------------------------------    
  if [[ $host_platform == "linux" ]]; then
  truthy "$disable_alsa" && config_options+=" --disable-alsa"                         # disable ALSA support [autodetect]
  truthy "$enable_libdc1394" && config_options+=" --enable-libdc1394 \
  --extra-libs=\"-lusb-1.0\""                                                         # enable IIDC-1394 grabbing using libdc1394 and libraw1394 [no]
  truthy "$disable_libdrm" && config_options+=" --disable-libdrm"                     # disable DRM code (Linux) [autodetect]
  truthy "$enable_libiec61883" && config_options+=" --enable-libiec61883 \
  --extra-libs=\"-liec61883 -lavc1394 -lrom1394 -lraw1394\""                          # enable iec61883 via libiec61883 [no]
  truthy "$disable_libv4l2" && config_options+=" --disable-libv4l2"                   # enable libv4l2/v4l-utils [no]
  truthy "$disable_libxcb_shape" && config_options+=" --disable-libxcb-shape"         # enable X11 grabbing shape rendering [autodetect]
  truthy "$disable_libxcb_shm" && config_options+=" --disable-libxcb-shm"             # enable X11 grabbing shm communication [autodetect]
  truthy "$disable_libxcb_xfixes" && config_options+=" --disable-libxcb-xfixes"       # enable X11 grabbing mouse rendering [autodetect]
  truthy "$disable_libxcb" && config_options+=" --disable-libxcb"                     # enable X11 grabbing using XCB [autodetect]
  truthy "$enable_rkmpp" && config_options+=" --enable-rkmpp"                         # enable Rockchip Media Process Platform code [no]
  truthy "$disable_v4l2_m2m" && config_options+=" --disable-v4l2-m2m"                 # disable V4L2 mem2mem code [autodetect]
  truthy "$disable_vaapi" && config_options+=" --disable-vaapi"                       # disable Video Acceleration API (mainly Unix/Intel) code [autodetect]
  truthy "$disable_xlib" && config_options+=" --disable-xlib"                         # disable xlib [autodetect]
                                                                                      # XXX --disable-sndio MinGW/Windows not supported 
  truthy "$disable_sndio" && config_options+=" --disable-sndio"                       # disable sndio support [autodetect]
                                                                                      # XXX --enable-libtorch ABI mismatch on windows
  truthy "$enable_libtorch" && config_options+=" --enable-libtorch \
  --extra-cflags=\"\
  -I${dependency_install_prefix}/libtorch/include/torch/csrc/api/include \
  -I${dependency_install_prefix}/libtorch/include\" \
  --extra-cxxflags=\"\
  -I${dependency_install_prefix}/libtorch/include/torch/csrc/api/include \
  -I${dependency_install_prefix}/libtorch/include\" \
  --extra-ldflags=\"-L${dependency_install_prefix}/libtorch/lib\""
                                                                                      # enable Torch as one DNN backend [no]
  fi
  #------------------------------------------------------------------------------
  # ----------------------------- hardware features ----------------------------- 
  #------------------------------------------------------------------------------
  truthy "$disable_amf" && config_options+=" --disable-amf"                           # disable AMF video encoding code [autodetect]
  truthy "$disable_vulkan" && config_options+=" --disable-vulkan"                     # disable Vulkan code [autodetect]
  truthy "$enable_libmfx" && config_options+=" --enable-libmfx"                       # enable Intel MediaSDK (AKA Quick Sync Video) code via libmfx [no]
  truthy "$enable_libvpl" && config_options+=" --enable-libvpl"                       # enable Intel oneVPL code via libvpl if libmfx is not used [no]
  truthy "$enable_vulkan_static" && config_options+=" --enable-vulkan-static"         # enable statically link to libvulkan [no]
  truthy "$enable_cuda_llvm" && config_options+=" --enable-cuda-llvm"                 # enable CUDA compilation using clang [autodetect]
  truthy "$enable_cuvid" && config_options+=" --enable-cuvid"                         # enable Nvidia CUVID support [autodetect]
  truthy "$enable_ffnvcodec" && config_options+=" --enable-ffnvcodec"                 # enable dynamically linked Nvidia code [autodetect]
  truthy "$enable_nvdec" && config_options+=" --enable-nvdec"                         # enable Nvidia video decoding acceleration (via hwaccel) [autodetect]
  truthy "$enable_nvenc" && config_options+=" --enable-nvenc"                         # enable Nvidia video encoding code [autodetect]
  truthy "$enable_vdpau" && config_options+=" --enable-vdpau"                         # enable Nvidia Video Decode and Presentation API for Unix code [autodetect]
  truthy "$enable_cuda_nvcc" && config_options+=" --enable-cuda-nvcc \
  --nvccflags=\"-gencode arch=compute_86,code=sm_86 -O2\""                             # enable Nvidia CUDA compiler [no]
  truthy "$enable_libnpp" && config_options+=" --enable-libnpp"                       # enable Nvidia Performance Primitives-based code [no]
  #------------------------------------------------------------------------------
  # ----------------------------- windows features ------------------------------ 
  #------------------------------------------------------------------------------
  if [[ $host_platform == "windows" ]]; then
  truthy "$enable_avisynth" && config_options+=" --enable-avisynth"                   # enable reading of AviSynth script files [no]
  fi
  #------------------------------------------------------------------------------
  # -------------------------- cross-platform features --------------------------
  #------------------------------------------------------------------------------ 
  if [[ $host_platform != "windows" ]]; then
  truthy "$enable_libsmbclient" && config_options+=" --enable-libsmbclient \
  --extra-cflags=\"-I/usr/include/samba-4.0\" \
  --extra-cxxflags=\"-I/usr/include/samba-4.0\" \
  --extra-libs=\"-lsmbclient\" \
  --extra-ldflags=\"-L/usr/lib64 -lsmbclient\""                                       # enable Samba protocol via libsmbclient [no]
  fi
  truthy "$disable_bzlib" && config_options+=" --disable-bzlib"                       # disable bzlib [autodetect]
  truthy "$disable_iconv" && config_options+=" --disable-iconv"                       # disable iconv [autodetect]
  truthy "$disable_lzma" && config_options+=" --disable-lzma"                         # disable lzma [autodetect]
  truthy "$disable_sdl2" && config_options+=" --disable-sdl2"                         # disable sdl2 [autodetect]
  truthy "$disable_zlib" && config_options+=" --disable-zlib"                         # disable zlib [autodetect]
  truthy "$enable_libvo_amrwbenc" && config_options+=" --enable-libvo-amrwbenc"       # enable AMR-WB encoding via libvo-amrwbenc [no]
  truthy "$enable_libopencore_amrnb" && config_options+=" --enable-libopencore-amrnb" # enable AMR-NB de/encoding via libopencore-amrnb [no]
  truthy "$enable_libopencore_amrwb" && config_options+=" --enable-libopencore-amrwb" # enable AMR-WB decoding via libopencore-amrwb [no]
  truthy "$enable_liblcevc_dec" && config_options+=" --enable-liblcevc-dec"           # enable LCEVC decoding via liblcevc-dec [no]
  truthy "$enable_chromaprint" && config_options+=" --enable-chromaprint \
  --extra-libs=\"-lfftw3\""                                                           # enable audio fingerprinting with chromaprint [no]
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
  # libcelt depercated - use libopus instead
  truthy "$enable_libcelt" && config_options+=" --enable-libopus"                     # enable CELT decoding via libcelt [no]
  truthy "$enable_libcodec2" && config_options+=" --enable-libcodec2"                 # enable codec2 en/decoding using libcodec2 [no]
  truthy "$enable_libdav1d" && config_options+=" --enable-libdav1d"                   # enable AV1 decoding via libdav1d [no]
  truthy "$enable_libdavs2" && config_options+=" --enable-libdavs2"                   # enable AVS2 decoding via libdavs2 [no]
  truthy "$enable_libdvdnav" && config_options+=" --enable-libdvdnav"                 # enable libdvdnav, needed for DVD demuxing [no]
  truthy "$enable_libdvdread" && config_options+=" --enable-libdvdread"               # enable libdvdread, needed for DVD demuxing [no]
  truthy "$enable_libflite" && config_options+=" --enable-libflite \
  --extra-libs=\"-lasound\""                                                          # enable flite (voice synthesis) support via libflite [no]
  truthy "$enable_libfontconfig" && config_options+=" --enable-libfontconfig\
  --extra-libs=\"-lxml2 -liconv\""                                                    # enable libfontconfig, useful for drawtext filter [no]
  truthy "$enable_libfreetype" && config_options+=" --enable-libfreetype"             # enable libfreetype, needed for drawtext filter [no]
  truthy "$enable_libfribidi" && config_options+=" --enable-libfribidi"               # enable libfribidi, improves drawtext filter [no]
  truthy "$enable_libglslang" && config_options+=" --enable-libglslang"               # enable GLSL->SPIRV compilation via libglslang [no]
  truthy "$enable_libgme" && config_options+=" --enable-libgme"                       # enable Game Music Emu via libgme [no]
  truthy "$enable_libgsm" && config_options+=" --enable-libgsm"                       # enable GSM de/encoding via libgsm [no]
  truthy "$enable_libharfbuzz" && config_options+=" --enable-libharfbuzz"             # enable libharfbuzz, needed for drawtext filter [no]
  truthy "$enable_libilbc" && config_options+=" --enable-libilbc"                     # enable iLBC de/encoding via libilbc [no]
  truthy "$enable_libjack" && config_options+=" --enable-libjack \
  --extra-libs=\"-lxcb -liconv\""                                                     # enable JACK audio sound server [no]
  truthy "$enable_libjxl" && config_options+=" --enable-libjxl"                       # enable JPEG XL de/encoding via libjxl [no]
  truthy "$enable_libklvanc" && config_options+=" --enable-libklvanc"                 # enable Kernel Labs VANC processing [no]
  truthy "$enable_libkvazaar" && config_options+=" --enable-libkvazaar"               # enable HEVC encoding via libkvazaar [no]
  truthy "$enable_liblc3" && config_options+=" --enable-liblc3"                       # enable LC3 de/encoding via liblc3 [no]
  truthy "$enable_liblensfun" && config_options+=" --enable-liblensfun"               # enable lensfun lens correction [no]
  truthy "$enable_libmodplug" && config_options+=" --enable-libmodplug"               # enable ModPlug via libmodplug [no]
  truthy "$enable_libmp3lame" && config_options+=" --enable-libmp3lame"               # enable MP3 encoding via libmp3lame [no]
  truthy "$enable_libmysofa" && config_options+=" --enable-libmysofa"                 # enable libmysofa, needed for sofalizer filter [no]
  truthy "$enable_liboapv" && config_options+=" --enable-liboapv"                     # enable APV encoding via liboapv [no]
  truthy "$enable_libopencv" && config_options+=" --enable-libopencv\
  --extra-libs=\"-lsharpyuv\""                                                        # enable video filtering via libopencv [no]
  truthy "$enable_libopenh264" && config_options+=" --enable-libopenh264"             # enable H.264 encoding via OpenH264 [no]
  truthy "$enable_libopenjpeg" && config_options+=" --enable-libopenjpeg"             # enable JPEG 2000 encoding via OpenJPEG [no]
  truthy "$enable_libopenmpt" && config_options+=" --enable-libopenmpt"               # enable decoding tracked files via libopenmpt [no]
  truthy "$enable_libopenvino" && config_options+=" --enable-libopenvino"             # enable OpenVINO as a DNN module backend for DNN based filters like dnn_processing [no]
  truthy "$enable_libopus" && config_options+=" --enable-libopus"                     # enable Opus de/encoding via libopus [no]
  truthy "$enable_libplacebo" && config_options+=" --enable-libplacebo"               # enable libplacebo library [no]
  truthy "$enable_libpulse" && config_options+=" --enable-libpulse\
  --extra-libs=\"-lxcb -lXau -lX11 -liconv -lXdmcp\""                                 # enable Pulseaudio input via libpulse [no]
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
  truthy "$enable_libtesseract" && config_options+=" --enable-libtesseract \
  --extra-libs=\"-Wl,--start-group -ltesseract -lleptonica -ltiff -lpng16 -ljpeg \
  -lopenjp2 -ljbig -lLerc -ldeflate -lzstd -llzma -lwebpmux -lwebp -lgif -lcurl \
  -lnghttp2 -lssl -lcrypto -lpsl -lbrotlidec -lbrotlicommon -larchive -lbz2 -lz \
  -lexpat -liconv -Wl,--end-group\""                                                  # enable Tesseract, needed for ocr filter [no]
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
  truthy "$enable_lv2" && config_options+=" --enable-lv2\
  --extra-libs=\"-Wl,--start-group -lsratom -lsord \
  -lzix -lserd -llilv -Wl,--end-group\""                                                 # enable LV2 audio filtering [no]
  truthy "$enable_mbedtls" && config_options+=" --enable-mbedtls"                     # enable mbedTLS, needed for https support if openssl, gnutls or libtls is not used [no]
  truthy "$enable_openal" && config_options+=" --enable-openal"                       # enable OpenAL 1.1 capture support [no]
  truthy "$enable_opencl" && config_options+=" --enable-opencl"                       # enable OpenCL processing [no]
  truthy "$enable_opengl" && config_options+=" --enable-opengl"                       # enable OpenGL rendering [no]
  truthy "$enable_openssl" && config_options+=" --enable-openssl"                     # enable openssl, needed for https support if gnutls, libtls or mbedtls is not used [no]
  truthy "$enable_pocketsphinx" && config_options+=" --enable-pocketsphinx"           # enable PocketSphinx, needed for asr filter [no]
  truthy "$enable_vapoursynth" && config_options+=" --enable-vapoursynth"             # enable VapourSynth demuxer [no]
  truthy "$enable_whisper" && config_options+=" --enable-whisper \
  --extra-libs=\"-lwhisper -lggml -lggml-cpu -lggml-base -lgomp\""                    # enable whisper filter [no]

  # add any additional ff prefixed flags 
  if [[ -n $ff_flags_values ]]; then
    ff_flags=$(concat_array "$ff_flags_values" " ")
    config_options+=" $ff_flags"
  fi

	if truthy "$build_gpl"; then
		config_options+=" --enable-gpl"
  fi
  if truthy "$build_nonfree"; then 
    config_options+=" --enable-nonfree"
    #------------------------------------------------------------------------------
    # ------------------------ non-free non-gpl libraries -------------------------
    #------------------------------------------------------------------------------ 
    truthy "$enable_decklink" && config_options+=" --enable-decklink"                   # enable Blackmagic DeckLink I/O support [no]
    truthy "$enable_libfdk_aac" && config_options+=" --enable-libfdk-aac"               # enable AAC de/encoding via libfdk-aac [no]
    # --------------------------- linux/unix features -----------------------------    
    if [[ $host_platform == "rpi" ]]; then
    truthy "$enable_mmal" && config_options+=" --enable-mmal"                           # enable Broadcom Multi-Media Abstraction Layer (Raspberry Pi) via MMAL [no]
    truthy "$enable_omx" && config_options+=" --enable-omx"                             # enable OpenMAX IL code [no]
    truthy "$enable_omx_rpi" && config_options+=" --enable-omx-rpi"                     # enable OpenMAX IL code for Raspberry Pi [no]
    fi
    # ----------------------------- windows features ------------------------------ 
    if [[ $host_platform == "windows" ]]; then
    truthy "$enable_d3d11va" && config_options+=" --enable-d3d11va"                     # enable Microsoft Direct3D 11 video acceleration code [autodetect]
    truthy "$enable_d3d12va" && config_options+=" --enable-d3d12va"                     # enable Microsoft Direct3D 12 video acceleration code [autodetect]
    truthy "$enable_dxva2" && config_options+=" --enable-dxva2"                         # enable Microsoft DirectX 9 video acceleration code [autodetect]
    truthy "$enable_schannel" && config_options+=" --enable-schannel"                   # enable SChannel SSP, needed for TLS support on Windows if openssl and gnutls are not used [autodetect]
    truthy "$enable_mediafoundation" && config_options+=" --enable-mediafoundation"     # enable encoding via MediaFoundation [auto]
    fi
    # ------------------------------ apple features -------------------------------     
    if [[ $host_platform == "apple" ]]; then
    truthy "$enable_avfoundation" && config_options+=" --enable-avfoundation"           # enable Apple AVFoundation framework [autodetect]
    truthy "$enable_appkit" && config_options+=" --enable-appkit"                       # enable Apple AppKit framework [autodetect]
    truthy "$enable_audiotoolbox" && config_options+=" --enable-audiotoolbox"           # enable Apple AudioToolbox code [autodetect]
    truthy "$enable_coreimage" && config_options+=" --enable-coreimage"                 # enable Apple CoreImage framework [autodetect]
    truthy "$enable_metal" && config_options+=" --enable-metal"                         # enable Apple Metal framework [autodetect]
    truthy "$enable_securetransport" && config_options+=" --enable-securetransport"     # enable Secure Transport, needed for TLS support on OSX if openssl and gnutls are not used [autodetect]
    truthy "$enable_videotoolbox" && config_options+=" --enable-videotoolbox"           # enable VideoToolbox code [autodetect]
    fi
	fi

	if truthy "$do_debug_build"; then
		postpend_configure_opts+=" --disable-stripping --disable-optimizations --extra-cflags=-Og --extra-cflags=-fno-omit-frame-pointer --enable-debug=3 --extra-cflags=-fno-inline"
	else
		postpend_configure_opts+=" --disable-debug"
	fi

	do_configure "$init_options$config_options$postpend_configure_opts" "./configure" "$(get_ffmpeg_directory)" || exit_message 1 "unable to configure ffmpeg. see $LOG_FILE for details."

	echo -e "INFO: Done configuering ffmpeg" | tee -a "$LOG_FILE"
}

build_exists() {
	shared_build_exists=n
	static_build_exists=n

	# Check shared build
	local build_dir="$work_dir/$(get_ffmpeg_directory shared)" #ffmpeg_install_prefix
	echo -e "INFO: Checking $build_dir" >>"$LOG_FILE"
	if [[ -d "$build_dir" && -d "$build_dir/bin" ]]; then
		echo -e "INFO: Checking binaries in $build_dir/bin..." >>"$LOG_FILE"
		check_binaries=n
		if find "$build_dir/bin" -maxdepth 1 -type f \( -name '*.a' -o -name '*.dll' -o -name '*.so' -o -name '*.dylib' -o -name '*.lib' -o -name '*.exe' \) -print -quit | grep -q .; then
			check_binaries=y
		fi
		truthy "$check_binaries" && shared_build_exists=y
	fi
	build_dir="$work_dir/$(get_ffmpeg_directory static)" #ffmpeg_install_prefix
	echo -e "INFO: Checking $build_dir" >>"$LOG_FILE"
	# Check static build
	if [[ -d "$build_dir" && -d "$build_dir/bin" ]]; then
		echo -e "INFO: Checking binaries in $build_dir/bin..." >>"$LOG_FILE"
		check_binaries=n
		if find "$build_dir/bin" -maxdepth 1 -type f \( -name '*.a' -o -name '*.dll' -o -name '*.so' -o -name '*.dylib' -o -name '*.lib' -o -name '*.exe' \) -print -quit | grep -q .; then
			check_binaries=y
		fi
		truthy "$check_binaries" && static_build_exists=y
	fi

	echo -e "INFO: Checking if build already exists..." | tee -a "$LOG_FILE"

	if [[ $build_ffmpeg_type == "static" ]]; then
		echo -e "INFO: Static build requested..." | tee -a "$LOG_FILE"
		if ! truthy "$static_build_exists" || truthy "$build_force"; then
			build_dir="$work_dir/$(get_ffmpeg_directory static)" #ffmpeg_install_prefix
			echo -e "INFO: Static build does not exist or force requested. (Re-)configuring Ffmpeg for static build..." | tee -a "$LOG_FILE"
			# shellcheck disable=SC2129
			remove_path -rf "$build_dir" 
			remove_path -f "${ffmpeg_source_dir}/"*.touch
			return 1
		else
			echo -e "INFO: Static build already exists at $build_dir" | tee -a "$LOG_FILE"
      return 0
		fi
	elif [[ $build_ffmpeg_type == "static" ]]; then
		echo -e "INFO: Shared build requested..." | tee -a "$LOG_FILE"
		if ! truthy "$shared_build_exists" || truthy "$build_force"; then
			build_dir="$work_dir/$(get_ffmpeg_directory shared)" #ffmpeg_install_prefix
			echo -e "INFO: Shared build does not exist or force requested. (Re-)configuring Ffmpeg for shared build..." | tee -a "$LOG_FILE"
			# shellcheck disable=SC2129
			remove_path -rf "$build_dir" 
			remove_path -f "${ffmpeg_source_dir}/"*.touch
			return 1
		else
			echo -e "INFO: Shared build already exists at $build_dir" | tee -a "$LOG_FILE"
      return 0
		fi
	fi
}

install_ffmpeg() {
	echo -e "INFO: Installing ffmpeg if not installed" | tee -a "$LOG_FILE"
	change_dir "$ffmpeg_source_dir"

	echo -e "INFO: Making Ffmpeg $(pwd)" | tee -a "$LOG_FILE"
  if truthy "$build_force"; then
    remove_path -rf "$ffmpeg_install_prefix"
  fi
	create_dir "$ffmpeg_install_prefix"

	do_make_and_make_install "" "" "$(get_ffmpeg_directory)"

	echo -e "INFO: Moving all binaries" | tee -a "$LOG_FILE"

	{	
    shopt -s nullglob
    mv -v -- */*.a */*.dylib */*.lib */*.dll *.exe *.so "${ffmpeg_install_prefix}/bin" > >(redirect_output) 2>&1 || true
	} >>"$LOG_FILE"

	echo -e "INFO: Done installing ffmpeg" | tee -a "$LOG_FILE"
  chmod -R u+rwx "$work_dir"
	install_ffmpeg_pkg
  if [[ $build_ffmpeg_type == "static" ]]; then
    check_static_pic "${ffmpeg_install_prefix}/lib/pkgconfig" "$(create_linker_script)"
  fi
}

install_ffmpeg_pkg() {
	echo -e "INFO: Checking deployment files..." | tee -a "$LOG_FILE"
  local touch_postfix="$(get_ffmpeg_directory)"
	local FFMPEG_KIT_VERSION=$(get_ffmpeg_kit_version)

  local touch_prefix="${touch_postfix}_already"
	local touch_name=$(get_small_touchfile_name "${touch_prefix}_pkgconfig" "ffmpeg $(get_ffmpeg_directory)")
	
  if truthy "$build_force"; then
		remove_path -rf "${ffmpeg_source_dir}/${touch_prefix}_pkgconfig"*.touch
	fi
  if [[ ! -f "${ffmpeg_source_dir}/$touch_name" ]]; then
    required_files=(
      "${ffmpeg_install_prefix}/lib/pkgconfig/libavformat.pc"
      "${ffmpeg_install_prefix}/lib/pkgconfig/libswresample.pc"
      "${ffmpeg_install_prefix}/lib/pkgconfig/libswscale.pc"
      "${ffmpeg_install_prefix}/lib/pkgconfig/libavdevice.pc"
      "${ffmpeg_install_prefix}/lib/pkgconfig/libavfilter.pc"
      "${ffmpeg_install_prefix}/lib/pkgconfig/libavcodec.pc"
      "${ffmpeg_install_prefix}/lib/pkgconfig/libavutil.pc")

    check_files_exist "false" "${required_files[@]}"

    echo -e "INFO: Done checking deployment files." | tee -a "$LOG_FILE"

    echo -e "INFO: Installing ffmpeg pkg-config" | tee -a "$LOG_FILE"

    create_dir "$install_pkgconfig_dir"

    # MANUALLY COPY PKG-CONFIG FILES
    overwrite_file "${ffmpeg_install_prefix}"/lib/pkgconfig/libavformat.pc "${install_pkgconfig_dir}/libavformat.pc" || return 1
    overwrite_file "${ffmpeg_install_prefix}"/lib/pkgconfig/libswresample.pc "${install_pkgconfig_dir}/libswresample.pc" || return 1
    overwrite_file "${ffmpeg_install_prefix}"/lib/pkgconfig/libswscale.pc "${install_pkgconfig_dir}/libswscale.pc" || return 1
    overwrite_file "${ffmpeg_install_prefix}"/lib/pkgconfig/libavdevice.pc "${install_pkgconfig_dir}/libavdevice.pc" || return 1
    overwrite_file "${ffmpeg_install_prefix}"/lib/pkgconfig/libavfilter.pc "${install_pkgconfig_dir}/libavfilter.pc" || return 1
    overwrite_file "${ffmpeg_install_prefix}"/lib/pkgconfig/libavcodec.pc "${install_pkgconfig_dir}/libavcodec.pc" || return 1
    overwrite_file "${ffmpeg_install_prefix}"/lib/pkgconfig/libavutil.pc "${install_pkgconfig_dir}/libavutil.pc" || return 1

    # # MANUALLY ADD REQUIRED HEADERS
    {
      mkdir -p "${ffmpeg_install_prefix}"/include/libavutil/{x86,arm,aarch64}
      mkdir -p "${ffmpeg_install_prefix}"/include/libavcodec/{x86,arm}
      overwrite_file "${ffmpeg_source_dir}"/config.h "${ffmpeg_install_prefix}"/include/config.h
      overwrite_file "${ffmpeg_source_dir}"/libavcodec/mathops.h "${ffmpeg_install_prefix}"/include/libavcodec/mathops.h
      overwrite_file "${ffmpeg_source_dir}"/libavcodec/x86/mathops.h "${ffmpeg_install_prefix}"/include/libavcodec/x86/mathops.h
      overwrite_file "${ffmpeg_source_dir}"/libavcodec/arm/mathops.h "${ffmpeg_install_prefix}"/include/libavcodec/arm/mathops.h
      overwrite_file "${ffmpeg_source_dir}"/libavformat/network.h "${ffmpeg_install_prefix}"/include/libavformat/network.h
      overwrite_file "${ffmpeg_source_dir}"/libavformat/os_support.h "${ffmpeg_install_prefix}"/include/libavformat/os_support.h
      overwrite_file "${ffmpeg_source_dir}"/libavformat/url.h "${ffmpeg_install_prefix}"/include/libavformat/url.h
      overwrite_file "${ffmpeg_source_dir}"/libavutil/attributes_internal.h "${ffmpeg_install_prefix}"/include/libavutil/attributes_internal.h
      overwrite_file "${ffmpeg_source_dir}"/libavutil/bprint.h "${ffmpeg_install_prefix}"/include/libavutil/bprint.h
      overwrite_file "${ffmpeg_source_dir}"/libavutil/getenv_utf8.h "${ffmpeg_install_prefix}"/include/libavutil/getenv_utf8.h
      overwrite_file "${ffmpeg_source_dir}"/libavutil/internal.h "${ffmpeg_install_prefix}"/include/libavutil/internal.h
      overwrite_file "${ffmpeg_source_dir}"/libavutil/libm.h "${ffmpeg_install_prefix}"/include/libavutil/libm.h
      overwrite_file "${ffmpeg_source_dir}"/libavutil/reverse.h "${ffmpeg_install_prefix}"/include/libavutil/reverse.h
      overwrite_file "${ffmpeg_source_dir}"/libavutil/thread.h "${ffmpeg_install_prefix}"/include/libavutil/thread.h
      overwrite_file "${ffmpeg_source_dir}"/libavutil/timer.h "${ffmpeg_install_prefix}"/include/libavutil/timer.h
      overwrite_file "${ffmpeg_source_dir}"/libavutil/x86/asm.h "${ffmpeg_install_prefix}"/include/libavutil/x86/asm.h
      overwrite_file "${ffmpeg_source_dir}"/libavutil/x86/timer.h "${ffmpeg_install_prefix}"/include/libavutil/x86/timer.h
      overwrite_file "${ffmpeg_source_dir}"/libavutil/arm/timer.h "${ffmpeg_install_prefix}"/include/libavutil/arm/timer.h
      overwrite_file "${ffmpeg_source_dir}"/libavutil/aarch64/timer.h "${ffmpeg_install_prefix}"/include/libavutil/aarch64/timer.h
      overwrite_file "${ffmpeg_source_dir}"/compat/w32pthreads.h "${ffmpeg_install_prefix}"/include/libavutil/compat/w32pthreads.h
      overwrite_file "${ffmpeg_source_dir}"/compat/stdbit/stdbit.h "${ffmpeg_install_prefix}"/include/stdbit/stdbit.h
      overwrite_file "${ffmpeg_source_dir}"/libavutil/wchar_filename.h "${ffmpeg_install_prefix}"/include/libavutil/wchar_filename.h
    } >>"$LOG_FILE"
    chmod -R u+rwx "$work_dir"
    echo -e "INFO: Done installing ffmpeg pkg-config" | tee -a "$LOG_FILE"
  fi
}

install_ffmpeg_kit() {
	echo -e "INFO: Installing ffmpeg kit to ${ffmpeg_kit_install}" | tee -a "$LOG_FILE"
  
	change_dir "${ffmpeg_kit_src_dir}"

  if truthy "$build_force"; then
    remove_path -rf "$ffmpeg_kit_install"
  fi
  
  do_make "PREFIX=$ffmpeg_kit_install" "$(get_ffmpeg_kit_directory)" || exit_message 1 "unable to make ffmpeg-kit. see $LOG_FILE for details."
  do_make_install "PREFIX=$ffmpeg_kit_install" "" "$(get_ffmpeg_kit_directory)" || exit_message 1 "unable to make install ffmpeg-kit. see $LOG_FILE for details."
	
  chmod -R u+rwx "$work_dir"
	echo -e "INFO: Done installing ffmpeg kit to ${ffmpeg_kit_install}" | tee -a "$LOG_FILE"
}

install_pkg_config_file() {
	local FILE_NAME="$1"
  local location_prefix="$2"
	local SOURCE="${install_pkgconfig_dir}/${FILE_NAME}"
	local DESTINATION="${FFMPEG_KIT_BUNDLE_PKG_CONFIG_DIRECTORY}/${FILE_NAME}"

	# DELETE OLD FILE
	if ! remove_path -rf "$DESTINATION" >>"$LOG_FILE"; then
		exit_message 1 "DEBUG: failed\n\nSee $LOG_FILE for details"
	fi

	# INSTALL THE NEW FILE
	if ! copy_path "$SOURCE" "$DESTINATION" >>"$LOG_FILE"; then
		exit_message 1 "DEBUG: failed\n\nSee $LOG_FILE for details"
	fi

	# UPDATE PATHS
	sed -i "s|${ffmpeg_kit_install}|${location_prefix}|g" "$DESTINATION" || return 1
  sed -i "s|libdir=${ffmpeg_kit_install}|libdir=\${prefix}/lib|g" "$DESTINATION" || return 1
  sed -i "s|includedir=${ffmpeg_kit_install}|includedir=\${prefix}/include|g" "$DESTINATION" || return 1

	sed -i "s|${ffmpeg_source_dir}|${location_prefix}|g" "$DESTINATION" || return 1
  sed -i "s|libdir=${ffmpeg_source_dir}|libdir=\${prefix}/lib|g" "$DESTINATION" || return 1
  sed -i "s|includedir=${ffmpeg_source_dir}|includedir=\${prefix}/include|g" "$DESTINATION" || return 1

  chmod -R u+rwx "$work_dir"
}

get_ffmpeg_kit_version() {
	local FFMPEG_KIT_VERSION=$(grep -Eo 'FFmpegKitVersion = .*' "$ffmpeg_kit_src_dir/src/FFmpegKitConfig.h" | tee -a "$LOG_FILE" | grep -Eo ' \".*' | tr -d '"; ')

	echo -e "${FFMPEG_KIT_VERSION}"
}

create_ffmpeg_kit_bundle() {
	echo -e "INFO: Creating bundle" | tee -a "$LOG_FILE"
	local touch_postfix="$(get_bundle_directory)"
	local FFMPEG_KIT_VERSION=$(get_ffmpeg_kit_version)

  local touch_prefix="${touch_postfix}_already"
	local touch_name=$(get_small_touchfile_name "${touch_prefix}_bundled" "ffmpeg-kit-bundle $(get_bundle_directory)")
	
  if truthy "$build_force"; then
		remove_path -rf "${ffmpeg_kit_src_dir}/${touch_prefix}_bundled"*.touch
    remove_path -rf "${ffmpeg_kit_bundle}"
	fi
	if [ ! -f "$touch_name" ]; then
		export FFMPEG_KIT_BUNDLE_INCLUDE_DIRECTORY="${ffmpeg_kit_bundle}/include"
		export FFMPEG_KIT_BUNDLE_LIB_DIRECTORY="${ffmpeg_kit_bundle}/lib"
		export FFMPEG_KIT_BUNDLE_BIN_DIRECTORY="${ffmpeg_kit_bundle}/bin"
		
		create_dir "${ffmpeg_kit_bundle}"
		create_dir "${FFMPEG_KIT_BUNDLE_INCLUDE_DIRECTORY}"
		create_dir "${FFMPEG_KIT_BUNDLE_LIB_DIRECTORY}"
		create_dir "${FFMPEG_KIT_BUNDLE_BIN_DIRECTORY}"
		
		{
			# COPY HEADERS
			[[ -d "${ffmpeg_kit_install}/include" ]] && cp -rP "${ffmpeg_kit_install}/include/"* "${FFMPEG_KIT_BUNDLE_INCLUDE_DIRECTORY}"
			# [[ -d "${ffmpeg_kit_install}/include" ]] && cp -rP "${ffmpeg_install_prefix}/include/"* "${FFMPEG_KIT_BUNDLE_INCLUDE_DIRECTORY}"

			# COPY LIBS
			[[ -d "${ffmpeg_kit_install}/lib" ]] && cp -rP "${ffmpeg_kit_install}/lib/"* "${FFMPEG_KIT_BUNDLE_LIB_DIRECTORY}"
			# [[ -d "${ffmpeg_kit_install}/lib" ]] && cp -rP "${ffmpeg_install_prefix}/lib/"* "${FFMPEG_KIT_BUNDLE_LIB_DIRECTORY}"

			# COPY BINARIES
			[[ -d "${ffmpeg_kit_install}/bin" ]] && cp -rP "${ffmpeg_kit_install}/bin/"* "${FFMPEG_KIT_BUNDLE_BIN_DIRECTORY}"
			# [[ -d "${ffmpeg_kit_install}/bin" ]] && cp -rP "${ffmpeg_install_prefix}/bin/"* "${FFMPEG_KIT_BUNDLE_BIN_DIRECTORY}"
		} >>"$LOG_FILE"

    sed -i "s|prefix=.*|prefix=${ffmpeg_kit_bundle}|g" "${ffmpeg_kit_bundle}/lib/pkgconfig/"*.pc || return 1
    sed -i "s|exec_prefix=.*|exec_prefix=\${prefix}|g" "${ffmpeg_kit_bundle}/lib/pkgconfig/"*.pc || return 1
    sed -i "s|libdir=.*|libdir=\${prefix}/lib|g" "${ffmpeg_kit_bundle}/lib/pkgconfig/"*.pc || return 1
    sed -i "s|includedir=.*|includedir=\${prefix}/include|g" "${ffmpeg_kit_bundle}/lib/pkgconfig/"*.pc || return 1

		local LICENSE_BASEDIR="${ffmpeg_kit_bundle}/licenses"

		create_dir "${LICENSE_BASEDIR}"
		
		get_licenses

		copy_path "${BASEDIR}"/tools/source/SOURCE "${LICENSE_BASEDIR}/source.txt"
		copy_path "${BASEDIR}"/tools/license/LICENSE.GPLv3 "${LICENSE_BASEDIR}"/license.txt
		create_touch_file 0 "$touch_name"
    echo -e "INFO: Done creating bundle at $ffmpeg_kit_bundle" | tee -a "$LOG_FILE"
	fi
  if truthy "$create_release"; then
    echo -e "INFO: Creating release bundle" | tee -a "$LOG_FILE"
    create_dir "$work_dir/releases"
    local out_dir=$(basename "$ffmpeg_kit_bundle")
    zip_dir "$ffmpeg_kit_bundle" "$work_dir/releases/$out_dir"
    echo -e "INFO: Done creating release bundle at $work_dir/releases/$out_dir.zip" | tee -a "$LOG_FILE"
    clean_builds "all"
  fi
  chmod -R u+rwx "$work_dir"
}
uninstall_manifest() {
  local manifest="$1"
  if [[ -f "$manifest" ]]; then
    echo "WARNING: found $manifest. Uninstalling files from $manifest if installed"
    xargs --verbose -d '\n' rm -rf < "$manifest"
    echo
    remove_path -f "$manifest"
  else
    echo "WARNING: $manifest not found."
  fi
}
pick_gpu_support() {
    if truthy "$accept_defaults"; then
      export gpu_support=n
      return 0
    fi
    export gpu_support=${1:-gpu_support}
    while [[ ! "${gpu_support,,}" =~ ^([0-1]|yes|y|no|n)$ ]]; do
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
Do you want to enable GPU support for TensorFlow?
  1. yes
  2. no [default]
EOF
        local timeout=10
        export gpu_support=""
        echo -ne 'Input your choice [0-1] (defaulting to "no" in 10 seconds): '
        for ((i=timeout; i>0; i--)); do
            if read -r -t 1 gpu_support; then
                break
            fi
            if (( i > 1 )); then
                echo -ne "\rInput your choice [0-1] (defaulting to \"no\" in $((i-1)) seconds): "
            else
                echo -ne "\rInput your choice [0-1] (defaulting to \"no\" in 0 seconds): "
            fi
        done
        
        # Check if timeout occurred
        if [[ -z "$gpu_support" ]] && { (( i == 0 )) || truthy "$accept_defaults"; }; then
            echo "No input received within 10 seconds. Defaulting to 'no'."
            export gpu_support=n
        fi
    done
    case "${gpu_support,,}" in
        1|yes|y) 
            export gpu_support=y
            return 0
            ;;
        0|no|n|"") 
            export gpu_support=n
            return 1
            ;;
        *)
            echo -e 'Your choice was not valid, please try again.'
            echo
            ;;
    esac
}

# Minimal zip folder function - supports only .zip format
# Usage: zip_dir <input_folder> [output_name]
zip_dir() {
    # Check for zip command
    if ! command -v zip >/dev/null 2>&1; then
        echo "Error: 'zip' command not found. Install with: $INSTALL_COMMAND install zip / yum install zip / brew install zip" | tee -a "$LOG_FILE"
        return 1
    fi
    
    # Validate arguments
    if [[ $# -lt 1 ]] || [[ $# -gt 2 ]]; then
        echo "Usage: zip_folder <input_folder> [output_name]"
        return 1
    fi
    
    local input_folder="$1"
    local output_name="${2:-}"
    
    # Validate input folder exists
    if [[ ! -d "$input_folder" ]]; then
        echo "Error: Input folder '$input_folder' not found" | tee -a "$LOG_FILE"
        return 1
    fi
    
    # Set default output name if not provided
    if [[ -z "$output_name" ]]; then
        local folder_name=$(basename "$input_folder")
        # Remove trailing slash if present
        folder_name="${folder_name%/}"
        output_name="${folder_name}.zip"
    fi
    
    # Ensure .zip extension
    if [[ "$output_name" != *.zip ]]; then
        output_name="${output_name}.zip"
    fi
    
    if [[ -f $output_name ]]; then
      echo "INFO: '$output_name' already exists. Deleting it first..."
      remove_path -f "$output_name"
    fi
    
    # Create the zip archive
    echo "INFO: Creating '$output_name' from '$input_folder'..."
    cd "$(realpath "$input_folder")" || exit_message 1 "could not find $input_folder"
    local input_name=$(basename "$input_folder")
    cd ..
    if (zip -rq "$output_name" "$input_name"); then
        echo "INFO: [Success] Created '$output_name'"
        return 0
    else
        echo "DEBUG: [Error] Failed to create zip archive" | tee -a "$LOG_FILE"
        # Clean up partial output if created
        [[ -f "$output_name" ]] && rm -f "$output_name"
        return 1
    fi
}

LAST_TS=$(date +%s)

ts() {
  local NOW=$(date +%s)
  local DIFF=$((NOW - LAST_TS))
  LAST_TS=$NOW

  # Convert seconds to HH:MM:SS
  local ELAPSED=$(printf '%02d:%02d:%02d' $((DIFF/3600)) $((DIFF%3600/60)) $((DIFF%60)))
  
  echo "$(date +"[%Y-%m-%d %H:%M:%S]") (Elapsed: $ELAPSED)"
}

intro() {
	cat <<EOL
     ##################### Welcome ######################
  Welcome to the ffmpeg and ffmpeg-kit builder-helper script.
  Downloads and builds will be installed to directories within $WORKDIR
  If this is not ok, then exit now, and cd to the directory where you'd
  like them installed, then run this script again from there.
  Note that once you build your compilers, you can no longer rename/move
  the $sandbox directory, since it will have some hard coded paths in there.
  You can, of course, rebuild ffmpeg from within it, etc.
EOL
	echo -e "$(ts)" | tee -a "$LOG_FILE"
	if [[ ! -d $WORKDIR ]]; then
		echo -e
		echo -e "Building in $WORKDIR, will use ~ 285GB space!" | tee -a "$LOG_FILE"
		echo -e
	fi
	change_dir "$WORKDIR" 1 || exit 1
	echo -e "sit back, this may take awhile..." | tee -a "$LOG_FILE"
}

apply_preset() {
    local PRESET_STRING="$1"
    # Split string by space into array
    # This handles multiline strings correctly if they are unquoted or space-separated
    if [[ -n "$PRESET_STRING" ]]; then
      for FLAG in $PRESET_STRING; do
          if [[ "$FLAG" == --enable-* ]]; then
              enable_library "${FLAG#--enable-}"
          elif [[ "$FLAG" == --disable-* ]]; then
              disable_library "${FLAG#--disable-}"
          fi
      done
    fi
}

pick_clean_type() {
  if truthy "$accept_defaults"; then
    export clean_type="all"
    echo "$clean_type"
    return 0
  fi
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
  1. all [default]
  2. ffmpeg
  3. ffmpeg-kit
  4. ffmpeg-kit-bundle
  5. Exit
EOF
		local timeout=10
    export clean_type=""
    echo -ne 'Input your choice [1-5] (defaulting to "all" in 10 seconds): '
    for ((i=timeout; i>0; i--)); do
        if read -r -t 1 clean_type; then
            break
        fi
        if (( i > 1 )); then
            echo -ne "\rInput your choice [1-5] (defaulting to \"all\" in $((i-1)) seconds): "
        else
            echo -ne "\rInput your choice [1-5] (defaulting to \"all\" in 0 seconds): "
        fi
    done
    
    # Check if timeout occurred
    if [[ -z "$clean_type" ]] && { (( i == 0 )) || truthy "$accept_defaults"; }; then
        echo "No input received within 10 seconds. Defaulting to 'all'."
        export clean_type="all"
    fi
	done
	case "$clean_type" in
	1|all) export clean_type="all" ;;
	2|ffmpeg) export clean_type="ffmpeg" ;;
	3|ffmpeg-kit) export clean_type="ffmpeg-kit" ;;
	4|ffmpeg-kit-bundle) export clean_type="ffmpeg-kit-bundle" ;;
	5)
		exit_message 0 "exiting"
		;;
	*)
		echo -e 'Your choice was not valid, please try again.'
		echo
		;;
	esac
}

pick_host_platform() {
	if truthy "$accept_defaults"; then
    export host_platform="linux"
    echo "$host_platform"
    return 0
  fi
  export host_platform=${1:-host_platform}
	while [[ ! "${host_platform,,}" =~ ^([1-3]|linux|windows)$ ]]; do
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
Which host platform are you trying to build, update, or clean for?
  1. Linux [default]
  2. Windows
  3. Exit
EOF
		echo -e -n 'Input your choice [1-3]: '
		read -r host_platform
	done
  if [[ -z "$host_platform" ]] && truthy "$accept_defaults"; then
      echo "Defaulting to 'linux'."
      export host_platform="linux"
  fi
	case "${host_platform,,}" in
	1|linux) export host_platform="linux"
  apply_preset "$CONFIG_LINUX"
  echo "$host_platform"
  return 0
  ;;
	2|windows) export host_platform="windows"
  apply_preset "$CONFIG_WINDOWS"
  echo "$host_platform"
  return 0
  ;;
	3|exit)
		echo -e "exiting"
		exit 0
		;;
	*)
		echo -e 'Your choice was not valid, please try again.'
		echo
		;;
	esac
}

pick_host_arch() {
	if truthy "$accept_defaults"; then
    export host_arch="x86_64"
    echo "$host_arch"
    return 0
  fi
  export host_arch=${1:-host_arch}
	while [[ ! "${host_arch,,}" =~ ^([1-3]|i686|x86_64|x86|x64|x32)$ ]]; do
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
Which host platform are you trying to build, update, or clean for?
  1. x86_64 (64-bit) [default]
  2. i686 (32-bit)
  3. Exit
EOF
		echo -e -n 'Input your choice [1-3]: '
		read -r host_arch
	done
  if [[ -z "$host_arch" ]] && truthy "$accept_defaults"; then
      echo "Defaulting to 'x86_64'."
      export host_arch="x86_64"
  fi
	case "${host_arch,,}" in
	1|x86_64|x64) export host_arch="x86_64"
  echo "$host_arch"
  return 0
  ;;
	2|i386|i686|x86|x32) export host_arch="i686"
  echo "$host_arch"
  return 0
  ;;
	3|exit)
		echo -e "exiting"
		exit 0
		;;
	*)
		echo -e 'Your choice was not valid, please try again.'
		echo
		;;
	esac
}

pick_gpu_type() {
    if truthy "$accept_defaults"; then
      export gpu_type="cuda"
      return 0
    fi
    export gpu_type=${1:-gpu_type}
    while [[ ! "${gpu_type,,}" =~ ^([1-2]|cuda|nvdia|rocm|amd)$ ]]; do
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
Which GPU compute platform?
  1. CUDA (Nvidia) [default]
  2. ROCm (AMD)
EOF
        local timeout=10
        export gpu_type=""
        echo -ne 'Input your choice [1-2] (defaulting to "CUDA (Nvidia)" in 10 seconds): '
        for ((i=timeout; i>0; i--)); do
            if read -r -t 1 gpu_type; then
                break
            fi
            if (( i > 1 )); then
                echo -ne "\rInput your choice [1-2] (defaulting to \"CUDA (Nvidia)\" in $((i-1)) seconds): "
            else
                echo -ne "\rInput your choice [1-2] (defaulting to \"CUDA (Nvidia)\" in 0 seconds): "
            fi
        done
        
        # Check if timeout occurred
        if [[ -z "$gpu_type" ]] && { (( i == 0 )) || truthy "$accept_defaults"; }; then
            echo "No input received within 10 seconds. Defaulting to 'CUDA (Nvidia)'."
            export gpu_type="cuda"
        fi
    done
    case "${gpu_type,,}" in
        1|cuda|nvidia|"") 
            export gpu_type="cuda"
            return 0
            ;;
        2|rocm|amd) 
            export gpu_type="rocm"
            return 1
            ;;
        *)
            echo -e 'Your choice was not valid, please try again.'
            echo
            ;;
    esac
}

pick_ssl_type() {
  if truthy "$accept_defaults"; then
    export ssl_type="openssl"
    enable_library "openssl"
    disable_library "gnutls"
    disable_library "libtls"
    disable_library "mbedtls"
    return 0
  fi
  export ssl_type=${1:-ssl_type}
    while [[ ! "${ssl_type,,}" =~ ^([1-4]|openssl|gnutls|libtls|mbedtls)$ ]]; do
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
Which TLS/SSL library needed for https do you want to include?
  1. openssl [default]
  2. gnutls
  3. libtls
  4. mbedtls
EOF
        local timeout=10
        export ssl_type=""
        echo -ne 'Input your choice [1-4] (defaulting to "OpenSSL" in 10 seconds): '
        for ((i=timeout; i>0; i--)); do
            if read -r -t 1 ssl_type; then
                break
            fi
            if (( i > 1 )); then
                echo -ne "\rInput your choice [1-4] (defaulting to \"OpenSSL\" in $((i-1)) seconds): "
            else
                echo -ne "\rInput your choice [1-4] (defaulting to \"OpenSSL\" in 0 seconds): "
            fi
        done
        
        # Check if timeout occurred
        if [[ -z "$ssl_type" ]] && { (( i == 0 )) || truthy "$accept_defaults"; }; then
            echo "No input received within 10 seconds. Defaulting to 'OpenSSL'."
            enable_library "openssl"
            disable_library "gnutls"
            disable_library "libtls"
            disable_library "mbedtls"
        fi
    done
    case "${ssl_type,,}" in
        1|openssl|"") 
            enable_library "openssl"
            ;;
        2|gnutls) 
            enable_library "gnutls"
            ;;
        3|libtls) 
            enable_library "libtls"
            ;;
        4|mbedtls) 
            enable_library "mbedtls"
            ;;
        *)
            echo -e 'Your choice was not valid, please try again.'
            echo
            ;;
    esac
}

pick_cryto_lib() {
    if truthy "$accept_defaults"; then
      export crypto_type="gcrypt"
      enable_library "gcrypt"
      disable_library "gmp"
      return 0
    fi
    export crypto_type=${1:-crypto_type}
    while [[ ! "${crypto_type,,}" =~ ^([1-2]|gcrypt|gmp)$ ]]; do
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
Which cryptography library needed for secure streaming do you want to include?
  1. gcrypt [default]
  2. gmp
EOF
        local timeout=10
        export crypto_type=""
        echo -ne 'Input your choice [1-2] (defaulting to "gcrypt" in 10 seconds): '
        for ((i=timeout; i>0; i--)); do
            if read -r -t 1 crypto_type; then
                break
            fi
            if (( i > 1 )); then
                echo -ne "\rInput your choice [1-2] (defaulting to \"gcrypt\" in $((i-1)) seconds): "
            else
                echo -ne "\rInput your choice [1-2] (defaulting to \"gcrypt\" in 0 seconds): "
            fi
        done
        
        # Check if timeout occurred
        if [[ -z "$crypto_type" ]] && { (( i == 0 )) || truthy "$accept_defaults"; }; then
            echo "No input received within 10 seconds. Defaulting to 'gcrypt'."
            enable_library "gcrypt"
            disable_library "gmp"
        fi
    done
    case "${crypto_type,,}" in
        1|gcrypt|"") 
            enable_library "gcrypt"
            disable_library "gmp"
            ;;
        2|gmp) 
            enable_library "gmp"
            disable_library "gcrypt"
            ;;
        *)
            echo -e 'Your choice was not valid, please try again.'
            echo
            ;;
    esac
}

pick_mq_lib() {
    if truthy "$accept_defaults"; then
      export mq_type="both"
      enable_library "librabbitmq"
      enable_library "libzmq"
      return 0
    fi
    export mq_type=${1:-mq_type}
    while [[ ! "${mq_type,,}" =~ ^([1-3]|rabbitmq|zeromq|librabbitmq|libzmq)$ ]]; do
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
Which MQ library do you want to include?
  1. RabbitMQ 
  2. ZeroMQ
  3. Both [default]
EOF
        local timeout=10
        export mq_type=""
        echo -ne 'Input your choice [1-2] (defaulting to "Both" in 10 seconds): '
        for ((i=timeout; i>0; i--)); do
            if read -r -t 1 mq_type; then
                break
            fi
            if (( i > 1 )); then
                echo -ne "\rInput your choice [1-2] (defaulting to \"Both\" in $((i-1)) seconds): "
            else
                echo -ne "\rInput your choice [1-2] (defaulting to \"Both\" in 0 seconds): "
            fi
        done
        
        # Check if timeout occurred
        if [[ -z "$mq_type" ]] && { (( i == 0 )) || truthy "$accept_defaults"; }; then
            echo "No input received within 10 seconds. Defaulting to 'gcrypt'."
            enable_library "librabbitmq"
            enable_library "libzmq"
        fi
    done
    case "${crypto_type,,}" in
        1|librabbitmq|rabbitmq) 
            enable_library "librabbitmq"
            disable_library "libzmq"
            ;;
        2|libzmq|zeromq|zmq) 
            enable_library "libzmq"
            disable_library "librabbitmq"
            ;;
        3|both|"")
            enable_library "librabbitmq"
            enable_library "libzmq"
            ;;
        *)
            echo -e 'Your choice was not valid, please try again.'
            echo
            ;;
    esac
}

print_build_steps() {
	echo -e "Avaliable build steps: ${#BUILD_STEPS[@]}"
	for i in "${!BUILD_STEPS[@]}"; do
		echo "Index $i: ${BUILD_STEPS[i]}"
	done
}

check_and_resolve() {
    local PREF="$1"
    local REDUNDANT="$2"
    
    local VAR_PREF="enable_${PREF//-/_}"
    local VAR_REDUNDANT="enable_${REDUNDANT//-/_}"

    # If both are marked as enabled (1)
    if truthy "${!VAR_PREF}" && truthy "${!VAR_REDUNDANT}"; then
        echo "  [RESOLVE] Collision detected between $PREF and $REDUNDANT. Preferring $PREF." >> "$LOG_FILE"
        disable_library "$REDUNDANT"
    fi
}

resolve_collisions() {
    echo -e "\n  [CONFIG] Resolving library collisions and preferences..." >> "$LOG_FILE"

    check_and_resolve "libvpl" "libmfx"
    check_and_resolve "libshaderc" "libglslang"

    if is_library_enabled "openssl"; then
        is_library_enabled "gnutls" && disable_library "gnutls"
        is_library_enabled "mbedtls" && disable_library "mbedtls"
        is_library_enabled "libtls" && disable_library "libtls"
    elif is_library_enabled "gnutls"; then
        is_library_enabled "mbedtls" && disable_library "mbedtls"
        is_library_enabled "libtls" && disable_library "libtls"
    fi
}

get_pip_download_link() {
  local package="$1"
  local result
  
  # 1. Capture the output
  result=$(python3 -m pip install "$package" --dry-run --no-deps --ignore-installed --report - -q 2>/dev/null)
  
  # 2. Check if pip actually succeeded before trying to parse
  if [ $? -ne 0 ] || [ -z "$result" ]; then
      echo "Error: Could not find package '$package'" >&2
      return 1
  fi

  # 3. Parse and print URL
  echo "$result" | python3 -c "import sys, json; print(json.load(sys.stdin)['install'][0]['download_info']['url'])"
}

unversion_library() {
TARGET_DIR="$1"
  find "$TARGET_DIR" -maxdepth 1 -name "*.so.*" | sort -Vr | while read -r full_path; do
    filename=$(basename "$full_path")
    # shellcheck disable=2001
    base_name=$(echo "$filename" | sed 's/\.so\..*/.so/')
    dest_path="$TARGET_DIR/$base_name"
    if [ -e "$dest_path" ]; then
        echo "Skipping $filename -> Target $base_name already exists." >>"$LOG_FILE"
    else
        echo "Renaming $filename -> $base_name" >>"$LOG_FILE"
        mv "$full_path" "$dest_path"
    fi
  done
}

check_gpl_libraries() {
  echo -e "\n  [CONFIG] Checling libraries for GPL conflicts..." >>"$LOG_FILE"
  if truthy "$build_gpl"; then
    truthy "$enable_libx264" && enable_library "libx264"
    truthy "$enable_libx265" && enable_library "libx265"
    truthy "$enable_libxvid" && enable_library "libxvid"
    truthy "$enable_frei0r" && enable_library "frei0r"
    truthy "$enable_libdvdread" && enable_library "libdvdread"
    truthy "$enable_v4l2_m2m" && enable_library "v4l2-m2m"
    truthy "$enable_avisynth" && enable_library "avisynth"
    truthy "$enable_libjack" && enable_library "libjack"
    truthy "$enable_libbs2b" && enable_library "libbs2b"
    truthy "$enable_libcdio" && enable_library "libcdio"
    truthy "$enable_libdvdnav" && enable_library "libdvdnav"
    truthy "$enable_librubberband" && enable_library "librubberband"
    truthy "$enable_libsmbclient" && enable_library "libsmbclient"
    truthy "$enable_libvidstab" && enable_library "libvidstab"
    truthy "$enable_libdavs2" && enable_library "libdavs2"
    truthy "$enable_libxavs" && enable_library "libxavs"
    truthy "$enable_libxavs2" && enable_library "libxavs2"
    truthy "$enable_libaribb24" && enable_library "libaribb24"
  else
    disable_library "libx264"
    disable_library "libx265"
    disable_library "libxvid"
    disable_library "frei0r"
    disable_library "libdvdread"
    disable_library "v4l2-m2m"
    disable_library "avisynth"
    disable_library "libjack"
    disable_library "libbs2b"
    disable_library "libcdio"
    disable_library "libdvdnav"
    disable_library "librubberband"
    disable_library "libsmbclient"
    disable_library "libvidstab"
    disable_library "libdavs2"
    disable_library "libxavs"
    disable_library "libxavs2"
    disable_library "libaribb24"
  fi
}

# disable libraries autodetected by default to prevent inadvertent bundling
disable_autodetected() {
  echo -e "\n  [CONFIG] Disabling libraries autodetected by default to prevent inadvertent bundling..." >>"$LOG_FILE"
  disable_library "alsa"
  disable_library "libdc1394"
  disable_library "libdrm"
  disable_library "libxcb-shape"
  disable_library "libxcb-shm"
  disable_library "libxcb-xfixes"
  disable_library "cuda-llvm"
  disable_library "v4l2-m2m"
  disable_library "libxcb"
  disable_library "vaapi"
  disable_library "xlib"
  disable_library "amf"
  disable_library "vulkan"
  disable_library "bzlib"
  disable_library "iconv"
  disable_library "lzma"
  disable_library "sdl2"
  disable_library "sndio"
  disable_library "zlib"
  disable_library "cuvid"
  disable_library "ffnvcodec"
  disable_library "nvdec"
  disable_library "nvenc"
  disable_library "vdpau"
  disable_library "d3d11va"
  disable_library "d3d12va"
  disable_library "dxva2"
  disable_library "schannel"
  disable_library "mediafoundation"
  disable_library "avfoundation"
  disable_library "appkit"
  disable_library "audiotoolbox"
  disable_library "coreimage"
  disable_library "metal"
  disable_library "securetransport"
  disable_library "videotoolbox"
}

add_src_dir() {
  local dir="$1"
  local dir_file="$install_pkgconfig_dir/$(get_bundle_directory).txt"
  if [[ -f "$dir_file" ]]; then
    if ! grep -q "$dir" "$dir_file"; then
      echo "$dir" >> "$dir_file"
      echo "INFO: Added $dir to license src dir list $dir_file" >> "$LOG_FILE"
    fi
  else
    echo -n "" > "$dir_file"
    chmod -R u+rwx "$dir_file"
  fi
}

get_licenses() {
  local dir_file="$install_pkgconfig_dir/$(get_bundle_directory).txt"
  [[ ! -f "$dir_file" ]] && { echo -e "DEBUG: could not find license src dir list file $dir_file\n  No licenses copied."; return 1; }
  mapfile -t license_dir_list < "$install_pkgconfig_dir/$(get_bundle_directory).txt"
  for dir in "${license_dir_list[@]}"; do
    [[ -z "$dir" ]] && continue
    [[ ! -d "$dir" ]] && continue
    bash "${SCRIPTDIR}/extract_licenses.sh" "${dir}" "${LICENSE_BASEDIR}/$(basename "$dir")" > >(redirect_output) 2>&1
  done
}

reset_and_clean() {
  local src_path="$1"
  local dirs=()
  # reset_touch "$src_path"
  if [[ -z "$1" ]]; then
    shopt -s nullglob
    dirs+=( "$src_dir"/*/ )
    shopt -u nullglob
  else
    dirs+=("$src_path")
  fi
  activate_meson
  for dir in "${dirs[@]}"; do
    if [[ -n "$dir" ]]; then
      cd "$dir" || continue
      mapfile -t sub_dirs < <(find "$dir" -name "Makefile" -exec dirname {} \; | sort -u 2>/dev/null)
      for sub_dir in "${sub_dirs[@]}"; do
        cd "$sub_dir" || continue
        if [[ -f Makefile ]]; then
          echo "Cleaning Makefile artifacts at $sub_dir..." > >(redirect_output)
          { nice make clean -j"$(get_concurrent_proc)" > >(redirect_output) 2>&1 || true; }
          { nice make distclean -j"$(get_concurrent_proc)" > >(redirect_output) 2>&1 || true; }
        fi
      done
      mapfile -t sub_dirs < <(find "$dir" -name "CMakeList.txt" -exec dirname {} \; | sort -u 2>/dev/null)
      for sub_dir in "${sub_dirs[@]}"; do
        cd "$sub_dir" || continue
        if [[ -f CMakeList.txt ]]; then
          echo "Cleaning CMake artifacts at $sub_dir..." > >(redirect_output)
          clean_cmake_cache "$(pwd)"
        fi
      done
      mapfile -t sub_dirs < <(find "$dir" -name "CMakeList.txt" -exec dirname {} \; | sort -u 2>/dev/null)
      for sub_dir in "${sub_dirs[@]}"; do
        cd "$sub_dir" || continue
        if [[ -f Cargo.toml ]]; then
          echo "Cleaning Cargo artifacts at $sub_dir..." > >(redirect_output)
          { cargo clean --release > >(redirect_output) 2>&1 || true; }
        fi
      done
      mapfile -t sub_dirs < <(find "$dir" -name "CMakeList.txt" -exec dirname {} \; | sort -u 2>/dev/null)
      for sub_dir in "${sub_dirs[@]}"; do
        cd "$sub_dir" || continue
        if [[ -f meson.build ]]; then
          echo "Cleaning meson artifacts at $sub_dir..." > >(redirect_output)
          { python3 "$local_meson" compile --clean -C build > >(redirect_output) 2>&1 || true; }
        fi
      done
      mapfile -t sub_dirs < <(find "$dir" -name "CMakeList.txt" -exec dirname {} \; | sort -u 2>/dev/null)
      for sub_dir in "${sub_dirs[@]}"; do
        cd "$sub_dir" || continue
        if [[ -f waf ]]; then
          echo "Cleaning waf artifacts at $sub_dir..." > >(redirect_output)
          { eval "python3 ./waf clean" > >(redirect_output) 2>&1 || true; }
        fi
      done
    fi
  done
}

reset_touch() {
  shopt -s nullglob
  if [[ -n "$1" ]]; then
    echo -e "INFO: Resetting $1" >>"$LOG_FILE"
    find -D stat "$(realpath "$1")" -maxdepth 3 \( -name "*.touch" -o -name "*already_*" \) -delete > >(redirect_output) 2>&1
  else
    echo -e "INFO: No directory provided. Resetting all src directories in prebuilt/src/" >>"$LOG_FILE"
    find -D stat "$(realpath "${BASEDIR}/prebuilt/src")" -maxdepth 3 \( -name "*.touch" -o -name "*already_*" \) -delete > >(redirect_output) 2>&1
  fi
  echo -e "INFO: Done resetting source directories touch files." >>"$LOG_FILE"
  shopt -u nullglob
}

disable_nonessential() {
  local src_dir="$1"
  shift

  if [ -z "$src_dir" ] || [ ! -d "$src_dir" ]; then
    echo "ERROR: Please provide a valid source directory." >>"$LOG_FILE"
    return 1
  fi

  echo "INFO: Searching for non-essential Makefiles in: $src_dir" >>"$LOG_FILE"

  # 1. Use an Array to build the find arguments
  local find_args=()
  
  # Start the grouping for logical OR
  find_args+=( \( )
  
  # Add default patterns
  find_args+=( -name "doc*" -o )
  find_args+=( -name "test*" -o )
  find_args+=( -name "example*" -o )
  find_args+=( -name "sample*" -o )
  find_args+=( -name "program*" -o )
  find_args+=( -name "app*" -o )

  # Add dynamic patterns passed as arguments
  for ptrn in "$@"; do
    find_args+=( -name "$ptrn" -o )
  done

  # Add the final pattern (no trailing -o)
  find_args+=( -name "tool*" )
  
  # Close the grouping
  find_args+=( \) )

  # 2. Use Process Substitution to avoid subshell issues
  # 3. Use -print0 and read -d '' to handle strange directory names
  while IFS= read -r -d '' subdir; do
    disable_makefile "$subdir/Makefile"
    disable_meson "$subdir/meson.build"
  done < <(find "$src_dir" -type d "${find_args[@]}" -print0)
}

disable_makefile() {
  local mkfile="$1"
  if [ -f "$mkfile" ]; then
    echo "  Disabling: $mkfile" >>"$LOG_FILE"
    
    # Using a literal tab variable for clarity
    local tab
    tab="$(printf '\t')"

    # Use > to overwrite the file cleanly
    cat <<EOF > "$mkfile"
.SUFFIXES:
all install install-strip check test clean mostlyclean distclean realclean:
${tab}@echo "Target \$@ disabled: $mkfile"
.DEFAULT:
${tab}@echo "Target \$@ ignored: $mkfile"
EOF
  fi
}

disable_meson() {
  local mfile="$1"
  if [ -f "$mfile" ]; then
    echo "  Disabling Meson: $mfile" >>"$LOG_FILE"
    
    # Overwrite with a valid Meson script that just prints a message
    cat <<EOF > "$mfile"
message('Build disabled for being non-essential')
EOF
  fi
}

check_custom_install() {
  local install_dir="$1"
  local lib_name="$2"

  if [ -z "$install_dir" ] || [ -z "$lib_name" ]; then
      echo "Usage: check_custom_install /path/to/custom/location library_name"
      return 1
  fi

  local lib_path="$install_dir/lib"
  local pc_path="$lib_path/pkgconfig"
  local include_path="$install_dir/include"

  echo "INFO: --- Checking Installation for: $lib_name ---"

  # 1. Check for .pc file (The Metadata)
  if [ -f "$pc_path/$lib_name.pc" ]; then
      echo "  [OK] Found pkg-config file: $pc_path/$lib_name.pc"
  else
      echo "  [ERROR] Missing .pc file. pkg-config will not find this library."
  fi

  # 2. Check for Static Library (.a)
  # Note: Using find to account for versioned names or subdirs
  local static_lib=$(find "$lib_path" -name "lib${lib_name}.a" -o -name "lib${lib_name}-*.a" | head -n 1)
  if [ -n "$static_lib" ]; then
      echo "  [OK] Found static archive: $static_lib"
  else
      echo "  [ERROR] Could not find lib${lib_name}.a in $lib_path"
  fi

  # 3. Validate Dependencies via pkg-config
  echo "  [INFO] Querying dependencies for $lib_name..."
  
  # We set PKG_CONFIG_LIBDIR to force it to ONLY look in your custom folder
  # We use PKG_CONFIG_PATH as a secondary to ensure it finds everything
  local deps=$(PKG_CONFIG_LIBDIR="$pc_path" PKG_CONFIG_PATH="$pc_path" pkg-config --print-requires-private --static "$lib_name" 2>/dev/null)
  
  if [ $? -eq 0 ]; then
      echo "  [OK] Dependency tree resolved:"
      echo "     $deps"
      
      # Check if each dependency actually exists in our custom folder
      for dep in $deps; do
          # Remove version constraints (e.g., glib-2.0 >= 2.80 -> glib-2.0)
          dep_clean=$(echo "$dep" | awk '{print $1}')
          if [ ! -f "$pc_path/$dep_clean.pc" ]; then
              echo "     [!] WARNING: Dependency '$dep_clean' not found in custom pkgconfig folder."
          fi
      done
  else
      echo "  [ERROR] pkg-config failed to resolve dependencies for $lib_name."
      echo "        Ensure all required .pc files are in $pc_path"
  fi

  # 4. Check for Headers
  if [ -d "$include_path" ] && [ -n "$(ls -A "$include_path" 2>/dev/null)" ]; then
      echo "  [OK] Headers directory is not empty: $include_path"
  else
      echo "  [WARNING] Headers directory is missing or empty."
  fi
  echo ""
}

# Usage: copy_and_link <destination> <link_to> <source_file_1> [source_file_2 ...]
copy_and_link() {
    # 1. Log the call for debugging
    echo "DEBUG: copy_and_link - $*" >>"$LOG_FILE"
    
    local destination="$1"
    local link_to="$2"
    shift 2

    # 2. Validation
    if [[ -z "$destination" || -z "$link_to" ]]; then
        echo "ERROR: destination and link_to are required." >&2
        return 1
    fi

    # Assuming create_dir is defined elsewhere in your script
    create_dir "$destination" || return 1
    create_dir "$link_to" || return 1

    local error_count=0

    for file in "$@"; do
        # Handle glob fail (e.g. if the glob literal is passed because no files matched)
        if [[ ! -e "$file" ]]; then
            echo "  [Error] Failed to find $file" >&2
            continue
        fi

        local filename
        filename=$(basename "$file")
        local dest_full_path="${destination}/${filename}"
        local link_full_path="${link_to}/${filename}"

        # 3. Copy
        if ! cp -rf "$file" "$destination/"; then
            echo "  [Error] Failed to copy $file" >&2
            ((error_count++))
            continue
        fi

        # 4. Clean existing link/dir
        if [[ -e "$link_full_path" || -L "$link_full_path" ]]; then
            if ! rm -rf "$link_full_path"; then
                echo "  [Error] Failed to clear existing $link_full_path" >&2
                ((error_count++))
                continue
            fi
        fi

        # 5. Link (Removed -v to keep manifest clean)
        if ! ln -sf "$dest_full_path" "$link_full_path"; then
             echo "  [Error] Failed to link $filename" >&2
             ((error_count++))
             continue
        fi

        # 6. Output to Manifest (Standard Output)
        echo "$dest_full_path" >&1
        # Uncomment below if you REALLY want the symlink in the manifest too:
        # echo "$link_full_path" >&1
    done

    # 7. Final Exit Code Check
    # This ensures your '|| exit_message' works correctly
    if [[ "$error_count" -gt 0 ]]; then
        return 1
    fi
}

# shellcheck disable=2206
# Usage: check_static_pic "/path/to/lib.pc" OR "/path/to/pkgconfig"
check_static_pic() {
    # 0. Pre-check
    if truthy "$skip_validation"; then
        echo
        echo "WARNING: Skipping check for Static + PIC (Linker Test)"
        return 0
    fi

    local input_path="$1" map_file="$2"
    local use_map=false
    [[ -n "$map_file" && -f "$map_file" ]] && use_map=true

    # --------------------------------------------------------------------------
    # HELPER: Check System Pkg Fallback
    # --------------------------------------------------------------------------
    _csp_check_system_pkg() {
        local pc_file="$1" log_file="$2"
        local system_paths="/usr/lib64/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig:/usr/local/lib/pkgconfig:/opt/python/cp312-cp312/lib/pkgconfig"
        export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:$system_paths"
        pkg-config --static --libs "$pc_file" 2>>"$log_file"
    }

    # --------------------------------------------------------------------------
    # HELPER: Find Targets (.pc and .a files)
    # --------------------------------------------------------------------------
    _csp_find_targets() {
        local path="$1"
        local -n targets_ref="$2" # Output array via nameref
        
        if [ -f "$path" ]; then
            if [[ "$path" == *.pc || "$path" == *.a ]]; then
                targets_ref+=("$path")
            else
                echo "ERROR: File '$path' is not a .pc or .a file." >&2
                return 1
            fi
        elif [ -d "$path" ]; then
            local pcfg_dir="$path"
            [ -d "$path/lib/pkgconfig" ] && pcfg_dir="$path/lib/pkgconfig"
            
            # Find .pc files
            if [ -d "$pcfg_dir" ]; then
                while IFS= read -r -d '' f; do targets_ref+=("$f"); done < <(find "$pcfg_dir" -maxdepth 1 -name "*.pc" -print0)
            fi
            # Find .a files (recursive)
            while IFS= read -r -d '' f; do targets_ref+=("$f"); done < <(find "$path" -type f -name "*.a" -print0)
        else
            echo "ERROR: Input '$path' is not a valid file or directory." >&2
            return 1
        fi
    }

    # --------------------------------------------------------------------------
    # HELPER: Resolve Libraries (Pkg-Config -> File Paths)
    # --------------------------------------------------------------------------
    _csp_resolve_libs() {
        local target="$1" log_file="$2"
        local -n res_libs="$3" res_stats="$4" # Outputs

        # A. Handle Static Lib Direct
        if [[ "$target" == *.a ]]; then
            res_libs="$target"
            res_stats[0]=1 # static_count
            return 0
        fi

        # B. Handle Pkg-Config
        local pcfg_dir=$(dirname "$target")
        local fallback_base=$(dirname "$(dirname "$pcfg_dir")")
        local pkg_prefix=$(pkg-config --variable=prefix "$target" 2>/dev/null)
        local search_base="${pkg_prefix:-$fallback_base}"
        
        export PKG_CONFIG_PATH="$pcfg_dir"
        
        local raw_flags
        if ! raw_flags=$(pkg-config --static --libs "$target" 2>"$log_file"); then
            if ! raw_flags=$(_csp_check_system_pkg "$target" "$log_file"); then
                return 1 # Parse failure
            fi
        fi

        # Parse Flags
        local search_paths=("${search_base}/lib")
        local final_libs=""
        
        for flag in $raw_flags; do
            if [[ "$flag" == -L* ]]; then
                search_paths+=("${flag#-L}")
            elif [[ "$flag" == /*.a ]]; then
                final_libs="$final_libs $flag"
                res_stats[0]=$((res_stats[0] + 1))
            elif [[ "$flag" == -l* ]]; then
                local lib="${flag#-l}"
                # Filter system libs
                if [[ "$lib" =~ ^(m|c|dl|rt|pthread|stdc\+\+|gcc|gcc_s|atomic|glu|gl|GLEW|X11|Xext)$ ]]; then
                    res_stats[2]=$((res_stats[2] + 1)) # system_count
                    continue
                fi
                # Resolve -l to file
                for path in "${search_paths[@]}"; do
                    if [ -f "${path}/lib${lib}.a" ]; then
                        final_libs="$final_libs ${path}/lib${lib}.a"
                        res_stats[0]=$((res_stats[0] + 1))
                        break
                    elif v_lib=$(find "${path}" -maxdepth 1 -name "lib${lib}.a.*" -print -quit 2>/dev/null) && [ -n "$v_lib" ]; then
                        final_libs="$final_libs $v_lib"
                        res_stats[0]=$((res_stats[0] + 1))
                        break
                    elif [ -f "${path}/lib${lib}.so" ]; then
                        final_libs="$final_libs ${path}/lib${lib}.so"
                        res_stats[1]=$((res_stats[1] + 1)) # shared_count
                        break
                    fi
                done
            fi
        done
        res_libs="$final_libs"
        return 0
    }

    # --------------------------------------------------------------------------
    # HELPER: Verify Binary (GCC Link Test)
    # --------------------------------------------------------------------------
    _csp_verify_binary() {
        local libs="$1" name="$2" tmp="$3" log="$4"
        local out_bin="${tmp}/${name}.so"
        
        local cmd=(gcc -shared -fPIC -o "$out_bin")
        cmd+=("-Wl,--whole-archive")
        cmd+=($libs)
        cmd+=("-Wl,--no-whole-archive")
        
        if [ "$use_map" = true ]; then
            cmd+=("-Wl,--version-script=$map_file" "-Wl,-Bsymbolic")
        fi
        cmd+=("-Wl,--allow-multiple-definition" "-Wl,--unresolved-symbols=ignore-all")

        if "${cmd[@]}" > "$log" 2>&1 && [[ -f "$out_bin" ]]; then
            du -h "$out_bin" | cut -f1
            return 0
        fi
        return 1
    }

    # --------------------------------------------------------------------------
    # HELPER: Print Report
    # --------------------------------------------------------------------------
    _csp_print_report() {
        local -n succ="$1" skip="$2" fail="$3"
        
        # Success Table
        if [ ${#succ[@]} -gt 0 ]; then
            echo -e "\n  [ VERIFIED PACKAGES ]"
            printf "  %-8s %-30s %-12s %-12s %-12s\n" "SIZE" "PACKAGE" "STATIC" "SHARED" "SYSTEM"
            echo "  --------------------------------------------------------------------------------"
            printf "%s\n" "${succ[@]}"
        fi

        # Skipped Table
        if [ ${#skip[@]} -gt 0 ]; then
            echo -e "\n  [ SKIPPED PACKAGES ]"
            printf "  %-30s %s\n" "PACKAGE" "REASON"
            echo "  --------------------------------------------------------------------------------"
            printf "%s\n" "${skip[@]}"
        fi

        # Failed Table
        if [ ${#fail[@]} -gt 0 ]; then
            echo -e "\n  [ FAILED PACKAGES ]"
            echo "  --------------------------------------------------------------------------------"
            printf "%b\n" "${fail[@]}"
        fi

        # Summary
        echo -e "\n--------------------------------------------------------------------------------"
        local total=$((${#succ[@]} + ${#skip[@]} + ${#fail[@]}))
        if [ ${#fail[@]} -eq 0 ]; then
            echo "SUCCESS: Checked $total pkgs. Verified: ${#succ[@]}, Skipped: ${#skip[@]}, Failed: 0."
            return 0
        else
            echo "FAILURE: Checked $total pkgs. Verified: ${#succ[@]}, Skipped: ${#skip[@]}, Failed: ${#fail[@]}."
            return 1
        fi
    }

    # ==========================================================================
    # MAIN LOGIC
    # ==========================================================================
    {
        echo
        echo "VERIFYING BUILD: Checking for Static + PIC (Linker Test)"
        
        local targets=()
        if ! _csp_find_targets "$input_path" targets; then
            return 1
        fi

        local tmp_dir=$(mktemp -d)
        local a_success=() a_skipped=() a_failed=()
        local total=${#targets[@]} count=0

        if [ "$total" -eq 0 ]; then
            echo "WARNING: No targets found in $input_path"
            rm -rf "$tmp_dir"
            return 0
        fi

        # Hide Cursor
        printf "\033[?25l"

        for target in "${targets[@]}"; do
            count=$((count + 1))
            local pkg_name=$(basename "$target")
            [[ "$target" == *.pc ]] && pkg_name=$(basename "$target" .pc)
            
            local log_file="${tmp_dir}/${pkg_name}_error.log"
            printf "\r\033[K[ %d / %d ] Checking: %s..." "$count" "$total" "$pkg_name" >&2

            # 1. Resolve Libraries
            local resolved_libs=""
            local -a stats=(0 0 0) # static, shared, system
            
            if ! _csp_resolve_libs "$target" "$log_file" resolved_libs stats; then
                local err=$(sed 's/^/        | /' "$log_file")
                a_failed+=("  [FAIL] $pkg_name (Config Parse Error)\n$err")
                continue
            fi

            # 2. Skip Logic (Header only or System only)
            if [[ -z "$resolved_libs" ]]; then
                if [ "${stats[2]}" -gt 0 ]; then
                    a_skipped+=("$(printf "  %-30s %s" "$pkg_name" "System/External Libs Only (${stats[2]})")")
                else
                    a_skipped+=("$(printf "  %-30s %s" "$pkg_name" "Header-only / No Libs")")
                fi
                continue
            fi

            # 3. Verify Binary
            local bin_size
            if bin_size=$(_csp_verify_binary "$resolved_libs" "$pkg_name" "$tmp_dir" "$log_file"); then
                a_success+=("$(printf "  %-8s %-30s %-12d %-12d %-12d" "$bin_size" "$pkg_name" "${stats[0]}" "${stats[1]}" "${stats[2]}")")
            else
                local err=$(sed 's/^/        | /' "$log_file")
                a_failed+=("  [FAIL] $pkg_name (Linker Error)\n         Libraries: $resolved_libs\n$err")
            fi
        done

        # Reset Cursor & Cleanup
        printf "\r\033[K" >&2
        printf "\033[?25h"
        rm -rf "$tmp_dir"

        # 4. Report
        _csp_print_report a_success a_skipped a_failed

    } | tee -a "${LOG_FILE}"
}

create_linker_script() {
  local script="$ffmpeg_source_dir/ffmpeg-linker-script.map"
  if [[ ! -f "$script" ]]; then
  cat > "$script" << EOF
{
    global:
        av*;
        postproc_*;
        pp_*;
        swr_*;
        swresample_*;
        swscale_*;
        sws_*;
    local:
        *;
};
EOF
  fi
  echo "$script"
}

