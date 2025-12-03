#!/usr/bin/env bash

# shellcheck disable=SC2317,SC1091,SC1090,SC2120,SC2250,SC2292

# ffmpeg windows cross compile helper/download script, see github repo README
# Copyright (C) 2025 Akash Patel, the script is under the GPLv3, but output FFmpeg's executables aren't
# set -x

export BASEDIR="$(pwd)"
export target_platform="windows"
export SCRIPTDIR="${BASEDIR}/scripts"
export LOG_FILE="${BASEDIR}/build.log"

source "${SCRIPTDIR}/variable.sh"
source "${SCRIPTDIR}/function.sh"
source "${SCRIPTDIR}/function-windows.sh"
source "${SCRIPTDIR}/run-windows.sh"

require_sudo

chown -R "$USER:$USER" "$LOG_FILE"

remove_path -f "$LOG_FILE"

echo -e "INFO: Build options: $*\n" 1>>"$LOG_FILE" 2>&1

display_windows_help() {
	echo -e "available option=default_value:
General Options:
	-h, --help                                                    display this help and exit
  -v, --version                                                 display version and exit
	-d, --debug                                                   build with debug information
	-s, --speed                                                   optimize for speed instead of size
	-f, --force                                                   ignore warnings
Licensing options:
	--enable-gpl=[n]                                              allow building GPL libraries, created libs will be 
                                                                licensed under the GPLv3.0 [no]\n
Build Options:
	--ffmpeg-git-checkout-version=[release/8.0]                   if you want to build a particular version of FFmpeg, 
                                                                ex: n3.1.1 or a specific git hash
	--ffmpeg-git-checkout=[https://github.com/FFmpeg/FFmpeg.git]  if you want to clone FFmpeg from other repositories
	--ffmpeg-source-dir=[default empty]                           specifiy the directory of ffmpeg source code. When 
                                                                specified, git will not be used.
	--compiler-flavors=[multi|win32|win64]                        multi is both win32 and win64
	--cflags=$original_cflags                                     [default works on any cpu, see README for options]
	--git-get-latest=[y]                                          [do a git pull for latest code from repositories like 
                                                                FFmpeg--can force a rebuild if changes are detected]
	--prefer-stable=[y]                                           build a few libraries from releases instead of git master
	--debug                                                       Make this script  print out each line as it executes
	--enable-gpl=[y]                                              set to n to do an lgpl build
	--get-total-steps|--get-step-name=[*]                         get dependency steps and step name by index
	--build-only={0..} OR step/library name from [get-all-steps]  [run get-total-steps|--get-step-name|get-all-steps for 
                                                                more info] build only specific dependency
	--build-from={0..} OR step/library name from [get-all-steps]  start building dependencies from given step
	--build-dependencies=[y]                                      [builds the ffmpeg dependencies. Disable it when the 
                                                                dependencies was built once and can greatly reduce build time. ]
	--build-dependencies-only=[n]                                 Only build dependency binaries. Will not build app binaries.
	--build-ffmpeg-only=[n]                                       build ffmpeg binaries only
	--build-ffmpeg-kit-only=[n]                                   build ffmpeg-kit binaries and bundle only
	--enable-static|--static                                      build static ffmpeg and ffmpeg-kit binaries
	--enable-shared|--shared[default]                             build shared ffmpeg and ffmpeg-kit binaries
  --enable-nonfree|--nonfree                                    buil binaries will be non-redistributable
	--clean-builds                                                clean ffmpeg and ffmpeg-kit builds based on 
                                                                [--enable-static|--enable-shared(default)] and exit
  --list-libraries                                              lists ffmpeg configeration including extra libraries and exit
	--enable-[library name]                                       enable extra ffmpeg libraries. Run --list-libraries 
                                                                and see under \"External library support\" to get a list.
  --ff-*                                                        pass additional ffmpeg parameters prefixed by ff-[*] to 
                                                                pass them directly to ffmpeg configure build statement.
                                                                Be careful when using this. No additional checks are done 
                                                                to these flags and may conflict with other explicit flags
"
}

print_build_steps() {
	echo -e "Avaliable build steps: ${#BUILD_STEPS[@]}"
	for i in "${!BUILD_STEPS[@]}"; do
		echo "Index $i: ${BUILD_STEPS[i]}"
	done
}

# If --get-all-steps is passed, just print the array and exit.
for arg in "$@"; do
	if [[ "$arg" == "--get-all-steps" ]]; then
		print_build_steps
		exit 0
	fi
done

# If --get-total-steps is passed, just print the size of the array and exit.
for arg in "$@"; do
	if [[ "$arg" == "--get-total-steps" ]]; then
		echo -e ${#BUILD_STEPS[@]}
		exit 0
	fi
done

# If --get-step-name is passed, print the name at that index and exit.
for arg in "$@"; do
	if [[ "$arg" == --get-step-name=* ]]; then
		index="${1#*=}"
		echo -e "${BUILD_STEPS[$index]}"
		exit 0
	fi
done

ff_flags_raw=()    # Original arguments: --ff-something
ff_flags_values=() # Extracted values: something

# parse command line parameters, if any
while [ $# -gt 0 ]; do
	case $1 in
	-h | --help)
		display_windows_help
		shift
		;;
	-v | --version) 
  display_version
  shift
  exit 0
  break
  ;;
	-d | --debug)
		enable_debug
		set -x
		shift
		;;
	-s | --speed)
		optimize_for_speed
		shift
		;;
	-l | --lts)
		enable_lts_build
		shift
		;;
	-f | --force)
		export BUILD_FORCE="1"
		shift
		;;
	--no-output-redirection)
		no_output_redirection
		shift
		;;
	--no-workspace-cleanup-*)
		NO_WORKSPACE_CLEANUP_LIBRARY=$(echo -e "$1" | sed -e 's/^--[A-Za-z]*-[A-Za-z]*-[A-Za-z]*-//g')
		export NO_WORKSPACE_CLEANUP_LIBRARY
		no_workspace_cleanup_library "${NO_WORKSPACE_CLEANUP_LIBRARY}"
		shift
		;;
	--no-link-time-optimization)
		no_link_time_optimization
		shift
		;;
	--ffmpeg-git-checkout-version=*)
		export ffmpeg_git_checkout_version="${1#*=}"
		shift
		;;
	--ffmpeg-git-checkout=*)
		export ffmpeg_git_checkout="${1#*=}"
		shift
		;;
	--ffmpeg-source-dir=*)
		export ffmpeg_source_dir="${1#*=}"
		shift
		;;
	--cflags=*)
		export original_cflags="${1#*=}"
		echo -e "setting cflags as $original_cflags"
		shift
		;;
	--git-get-latest=*)
		export git_get_latest="${1#*=}"
		shift
		;;
	--prefer-stable=*)
		export prefer_stable="${1#*=}"
		shift
		;;
	--enable-gpl=*)
		export GPL_ENABLED="${1#*=}"
		shift
		;;
	--build-dependencies=*)
		export build_dependencies="${1#*=}"
		shift
		;;
	--build-only=*)
		export build_only="${1#*=}"
		shift
		;;
	--build-from=*)
		export build_from="${1#*=}"
		shift
		;;
	--build-dependencies-only=*)
		export build_dependencies_only="${1#*=}"
		shift
		;;
	--build-ffmpeg-only=*)
		export build_ffmpeg_only="${1#*=}"
		shift
		;;
	--build-ffmpeg-kit-only=*)
		export build_ffmpeg_kit_only="${1#*=}"
		shift
		;;
	--build-ffmpeg-kit-bundle-only=*)
		export build_ffmpeg_kit_bundle_only="${1#*=}"
		shift
		;;
	--compiler-flavors=*|--flavor=*)
		export compiler_flavors="${1#*=}"
		shift
		;;
	--enable-static | --static)
		export build_ffmpeg_static=y
		export build_ffmpeg_shared=n
		shift
		;;
	--enable-shared | --shared)
		export build_ffmpeg_static=n
		export build_ffmpeg_shared=y
		shift
		;;
  --enable-nonfree | --nonfree)
		export enable_nonfree=" --enable-nonfree"
		shift
		;;
	--enable-debug-build)
		export do_debug_build=y
		enable_debug
		shift
		;;
	--get-total-steps | --get-all-steps | --get-step-name=*) exit 0 ;; # Handled above, just consume and ignore here
	--clean-builds)
		export clean_builds=y
    shift
		break
		;;
  --list-libraries)
    list_libraries
    shift
    break
    ;;
  --run-only=*)
    export run_only="${1#*=}"
    shift
    break
    ;;
	--enable-*)
		LIBRARY_NAME="${1#--enable-}"
    VAR_NAME="enable_${LIBRARY_NAME//-/_}"
    declare "$VAR_NAME=1"
    shift
    ;;
  --disable-*)
		LIBRARY_NAME="${1#--disable-}"
    VAR_NAME="disable_${LIBRARY_NAME//-/_}"
    declare "$VAR_NAME=1"
    shift
    ;;
  --ff-*)
    # Store original
    ff_flags_raw+=("$1")
    # Store extracted value
    VALUE="${1#--ff-}"
    ff_flags_values+=("$VALUE")
    shift
    ;;
	--)
		shift
		break
		;;
	-*)
		echo -e "Error, unknown option: '$1'."
		exit 1
		;;
	*) break ;;
	esac
done

source "${SCRIPTDIR}/main-windows.sh"
