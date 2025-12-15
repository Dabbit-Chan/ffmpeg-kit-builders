#!/usr/bin/env bash

# shellcheck disable=SC2317,SC1091,SC1090,SC2120,SC2250,SC2292

export BASEDIR="$(pwd)"
export SCRIPTDIR="${BASEDIR}/scripts"
export LOG_FILE="${BASEDIR}/build.log"

source "${SCRIPTDIR}/variable.sh"
source "${SCRIPTDIR}/function.sh"

require_sudo

chown -R "$USER:$USER" "$LOG_FILE"

remove_path -f "$LOG_FILE"

echo -e "INFO: Build options: $*\n" 1>>"$LOG_FILE" 2>&1

display_help() {
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
  --host-platform=*|--host=*                                    where the compiled program will run [linux|windows]
  --host-platform=*|--host=*                                    host cpu architecture [i686|x86_64] (32-bit or 64-bit)
  --lto                                                         enable Linktime optimization
  --lts                                                         enable long-term support build
	--ffmpeg-git-checkout-version=[release/8.0]                   if you want to build a particular version of FFmpeg, 
                                                                ex: n3.1.1 or a specific git hash
	--ffmpeg-git-checkout=[https://github.com/FFmpeg/FFmpeg.git]  if you want to clone FFmpeg from other repositories
	--ffmpeg-source-dir=[default empty]                           specifiy the directory of ffmpeg source code. When 
                                                                specified, git will not be used.
	--cflags=$original_cflags                                     [default works on any cpu, see README for options]
	--git-get-latest=[y]                                          [do a git pull for latest code from repositories like 
                                                                FFmpeg--can force a rebuild if changes are detected]
	--prefer-stable=[y]                                           build a few libraries from releases instead of git master
	--enable-gpl=[y]                                              set to n to do an lgpl build
	--get-total-steps|--get-step-name=[*]                         get dependency steps and step name by index
	--build-only={0..} OR step/library name from [get-all-steps]  [run get-total-steps|--get-step-name|get-all-steps for 
                                                                more info] build only specific dependency
	--build-from={0..} OR step/library name from [get-all-steps]  start building dependencies from given step
	--build-dependencies=[y]                                      [builds the ffmpeg dependencies. Disable it when the 
                                                                dependencies was built once and can greatly reduce build time. ]
	--build-dependencies-only                                     Only build dependency binaries. Will not build app binaries.
	--build-ffmpeg-only                                           build ffmpeg binaries only
	--build-ffmpeg-kit-only                                       build ffmpeg-kit binaries and bundle only
  --release                                                     create release zip files
	--enable-static|--static[default]                             build static ffmpeg and ffmpeg-kit binaries
	--enable-shared|--shared                                      build shared ffmpeg and ffmpeg-kit binaries
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
	echo -e "$(date)" | tee -a "$LOG_FILE" # for timestamping super long builds LOL
	if [[ ! -d $WORKDIR ]]; then
		echo -e
		echo -e "Building in $WORKDIR, will use ~ 285GB space!" | tee -a "$LOG_FILE"
		echo -e
	fi
	change_dir "$WORKDIR" 1 || exit 1
	echo -e "sit back, this may take awhile..." | tee -a "$LOG_FILE"
}

pick_host_platform() {
	if [[ -n $1 ]]; then
		export host_platform=$1
	fi
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
  1. Linux
  2. Windows
  3. Exit
EOF
		echo -e -n 'Input your choice [1-3]: '
		read -r host_platform
	done
	case "${host_platform,,}" in
	1|linux) export host_platform="linux"
  echo "$host_platform"
  return 0
  ;;
	2|windows) export host_platform="windows"
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
	if [[ -n $1 ]]; then
		export host_arch=$1
	fi
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
  1. x86_64 (64-bit)
  2. i686 (32-bit)
  3. Exit
EOF
		echo -e -n 'Input your choice [1-3]: '
		read -r host_arch
	done
	case "${host_arch,,}" in
	1|x86_64|x64) export host_arch="x86_64"
  echo "$host_arch"
  return 0
  ;;
	2|i686|x86|x32) export host_arch="i686"
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
		display_help
		shift
		;;
	-v | --version) 
  display_version
  shift
  exit 0
  break
  ;;
	-d | --debug)
    export do_debug_build=y
		set -x
		shift
		;;
	-s | --speed)
		export FFMPEG_KIT_OPTIMIZED_FOR_SPEED=1
		shift
		;;
	-l | --lts)
		export FFMPEG_KIT_LTS_BUILD="1"
    export LTS_BUILD_FLAG="-DFFMPEG_KIT_LTS"
    shift
		;;
	-f | --force)
		export build_force="1"
		shift
		;;
  --lto)
    export enable_lto="1"
    shift
		;;
  --release)
    export create_release=1
    shift
    ;;
  --host-platform=*|--host=*)
    pick_host_platform "${1#*=}"
    shift
    ;;
  --host-arch=*|--arch=*)
    pick_host_arch "${1#*=}"
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
		export enable_gpl="${1#*=}"
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
	--build-dependencies-only)
		export build_dependencies_only=1
		shift
		;;
	--build-ffmpeg-only)
		export build_ffmpeg_only=1
		shift
		;;
	--build-ffmpeg-kit-only)
		export build_ffmpeg_kit_only=1
		shift
		;;
	--build-ffmpeg-kit-bundle-only=*)
		export build_ffmpeg_kit_bundle_only="${1#*=}"
		shift
		;;
	--enable-static | --static)
		export build_static=y
		shift
		;;
	--enable-shared | --shared)
		export build_static=n
		shift
		;;
  --enable-nonfree | --nonfree)
		export enable_nonfree=" --enable-nonfree"
		shift
		;;
	--get-total-steps | --get-all-steps | --get-step-name=*) exit 0 ;; # Handled above, just consume and ignore here
	--clean-builds)
		export clean_builds=y
    shift
		;;
  --list-libraries)
    list_libraries
    shift
    ;;
  --run-only=*)
    export run_only="${1#*=}"
    shift
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

[[ -z $host_platform ]] && pick_host_platform
[[ -z $host_arch ]] && pick_host_arch

check_missing_packages # do this first since it's annoying to go through prompts then be rejected
intro                  # remember to always run the intro, since it adjust pwd

if [ -z "$(get_cpu_count)" ]; then
	cpu_count=$(sysctl -n hw.ncpu | tr -d '\n') # OS X cpu count
	if [ -z "$(get_cpu_count)" ]; then
		echo -e "warning, unable to determine cpu count, defaulting to 1" | tee -a "$LOG_FILE"
		cpu_count=1 # else default to just 1, instead of blank, which means infinite
	fi
fi

set_box_memory_size_bytes
if [[ $box_memory_size_bytes -lt 600000000 ]]; then
	echo -e "your box only has $box_memory_size_bytes, 512MB (only) boxes crash when building cross compiler gcc, please add some swap" | tee -a "$LOG_FILE" # 1G worked OK however...
	exit 1
fi

if [[ $box_memory_size_bytes -gt 2000000000 ]]; then
	gcc_cpu_count=$(get_cpu_count) # they can handle it seemingly...
else
	echo -e "low RAM detected so using only one cpu for gcc compilation" | tee -a "$LOG_FILE"
	gcc_cpu_count=1 # compatible low RAM...
fi

for arg in "$@"; do
	if [[ "$arg" == "--clean-builds" ]]; then
		clean_ffmpeg_builds
		exit 0
	fi
done
echo -e "$(date)" | tee -a "$LOG_FILE"

setup_build_environment

source "${SCRIPTDIR}/main-$host_platform.sh"
