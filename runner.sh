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

display_help() {
	echo -e "available option=value - [default_value] or (optional):
General Options:
	-h, --help                                                    display this help and exit
	-v, --version                                                 display version and exit
	-d, --debug                                                   build with debug information
	-f, --force                                                   force build
  -y                                                            accept all defaults and disables interactive prompts

Licensing options:
	--enable-gpl|--gpl                                            allow building GPL libraries, created libs will be 
	                                                              licensed under the GPLv3.0 [no]
	--enable-nonfree|--nonfree                                    build binaries will be non-redistributable

Feature Presets:
  --enable-full                                                 enable all available external libraries (based on gpl/non-gpl selection)
  --enable-small                                                exclude certain extra libraries from presets to reduce size (see --list-excluded)
  --enable-https                                                enable https libraries
  --enable-audio                                                enable all audio processing libraries
  --enable-audio-ai                                             enable all audio processing ai libraries
  --enable-video                                                enable all video processing libraries
  --enable-video-streaming                                      enable all video streaming libraries
  --enable-video-ai-cpu                                         enable all video ai cpu based libraries
  --enable-video-ai-gpu                                         enable all video ai gpu based libraries
  --enable-hardware                                             enable all hardware accel libraries
  --enable-ssh                                                  enable SSH/SFTP support
  --enable-smb                                                  enable SMB (SAMBA) file sharing protocol support
  --enable-mq                                                   enable distributed systems support

Bundle Presets (pre-defined collections of libraries to include in ffmpeg-kit bundle):
  --audio-bundle                                                contains https + audio only libraries in the final bundle
  --audio-ai-bundle                                             contains https + audio + audio only ai libraries in the final bundle
  --video-bundle                                                contains https + audio + video libraries in the final bundle
  --video-ai-cpu-bundle                                         contains https + audio + video + ai (cpu) libraries in the final bundle
  --video-ai-gpu-bundle                                         contains https + audio + video + ai (gpu) libraries in the final bundle
  --video-hw-bundle                                             contains https + audio + video + hardware libraries in the final bundle
  --video-ai-cpu-hw-bundle                                      contains https + audio + video + hardware + ai (cpu) libraries in the final bundle
  --video-ai-gpu-hw-bundle                                      contains https + audio + video + hardware + ai (gpu) libraries in the final bundle
  --streaming-bundle                                            contains https + audio + video + streaming libraries in the final bundle
  --full-bundle                                                 contains https + audio + video + hardware + ai + streaming + ssh + smb + mq libraries in the final bundle

Build Options:
	--host-platform=|--host=(linux|windows)                       where the compiled program will run
	--host-arch=|--arch=(i686|x86_64)                             host cpu architecture (32-bit or 64-bit)
	--lto                                                         enable Linktime optimization
	--ffmpeg-git-checkout-version=[release/8.0]                   if you want to build a particular version of FFmpeg, 
	                                                              ex: n3.1.1 or a specific git hash
                                                                WARNING: This will most likely break ffmpeg-kit libraries
                                                                if the fftools version it too old.
	--ffmpeg-git-checkout=[https://github.com/FFmpeg/FFmpeg.git]  if you want to clone FFmpeg from other repositories
	--ffmpeg-source-dir=[default empty]                           specify the directory of ffmpeg source code. When 
	                                                              specified, git will not be used.
	--cflags=$original_cflags                                     [default works on any cpu, see README for options]
	--git-get-latest=[y]                                          [do a git pull for latest code from repositories like 
	                                                              FFmpeg--can force a rebuild if changes are detected]
	--prefer-stable=[y]                                           build a few libraries from releases instead of git master
  --release                                                     create release zip of the bundled binaries to be distributed
	--enable-static|--static[default]                             build static ffmpeg and ffmpeg-kit binaries
	--enable-shared|--shared                                      build shared ffmpeg and ffmpeg-kit binaries
	--clean-builds                                                clean ffmpeg and ffmpeg-kit builds based on 
	                                                              [--enable-static|--enable-shared(default)] and exit

Advanced Dependency Control:
	--get-total-steps|--get-step-name=[*]                         get dependency steps and step name by index
	--build-only={0..} OR [library_name]                          build only specific dependency (e.g. --build-only=libx264)
	--build-from={0..} OR [library_name]                          start building dependencies from given step
	--build-dependencies=[y]                                      builds the ffmpeg dependencies. Disable when dependencies
	                                                              are already built to reduce time.
	--build-dependencies-only                                     Only build dependency binaries. Will not build ffmpeg or 
                                                                ffmpeg-kit binaries.
	--build-ffmpeg-only                                           build ffmpeg binaries only. Does not (re)build ext-library
                                                                dependencies. Missing dependencies will cause a failure
	--build-ffmpeg-kit-only                                       build ffmpeg-kit binaries and bundle only Does not (re)build 
                                                                ext-library dependencies. Missing dependencies will cause a failure
	--list-libraries                                              lists available ext-libraries that can be included

Dynamic Library Control:
	--enable-[library name]                                       enable specific library (e.g. --enable-libx264)
	--disable-[library name]                                      disable specific library (e.g. --disable-libxcb)
	--ff-*                                                        pass additional ffmpeg parameters directly to configure.
	                                                              Example: --ff-disable-network passed as --disable-network
"
}

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
	-f | --force)
    export build_force=1
    shift
		;;
  -y)
    export accept_defaults=1
    echo "Skipping interactive. Accepting defuly selections."
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
    export host_platform="${1#*=}"
    pick_host_platform "$host_platform"
    shift
    ;;
  --host-arch=*|--arch=*)
    export host_arch="${1#*=}"
    pick_host_arch "$host_arch"
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
	--enable-gpl | --gpl)
		export enable_gpl=1
		shift
		;;
  --enable-nonfree | --nonfree)
		export enable_nonfree=1
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
	--build-dependencies-only | --build-deps-only)
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
	--enable-full)
    export enable_full=1
    shift
    ;;
  --enable-small)
    export enable_small=1
    shift
    ;;
  --enable-https)
    export enable_https=1
    pick_ssl_type
    shift
    ;;
  --enable-audio)
    export enable_audio=1
    shift
    ;;
  --enable-video)
    export enable_video=1
    shift
    ;;
  --enable-streaming)
    export enable_streaming=1
    pick_ssl_type
    pick_cryto_lib
    shift
    ;;
  --enable-audio-ai)
    export enable_audio_ai=1
    shift
    ;;
  --enable-video-ai-cpu)
    export enable_video_ai=1
    export enable_audio_ai=1
    export gpu_support=0
    shift
    ;;
  --enable-video-ai-gpu)
    export enable_video_ai=1
    export enable_audio_ai=1
    export gpu_support=1
    pick_gpu_type
    shift
    ;;
  --enable-hardware)
    export enable_hardware=1
    shift
    ;;
  --enable-ssh)
    export enable_ssh=1
    shift
    ;;
  --enable-smb)
    export enable_smb=1
    shift
    ;;
  --enable-mq)
    pick_mq_lib
    shift
    ;;
  --audio-bundle)
    export audio_bundle=1
    shift
    ;;
  --video-bundle)
    export video_bundle=1
    shift
    ;;
  --audio-ai-bundle)
    export audio_ai_bundle=1
    shift
    ;;
  --video-ai-cpu-bundle)
    export video_ai_bundle=1
    export enable_audio_ai=1
    export gpu_support=0
    shift
    ;;
  --video-ai-gpu-bundle)
    export video_ai_bundle=1
    export enable_audio_ai=1
    export gpu_support=1
    pick_gpu_type
    shift
    ;;
  --video-hw-bundle)
    export video_hw_bundle=1
    shift
    ;;
  --video-ai-cpu-hw-bundle)
    export video_ai_hw_bundle=1
    export gpu_support=0
    shift
    ;;
  --video-ai-gpu-hw-bundle)
    export video_ai_hw_bundle=1
    export gpu_support=1
    shift
    ;;
  --streaming-bundle)
    export streaming_bundle=1
    shift
    ;;
	--enable-*)
    enable_library "${1#--enable-}"
    shift
    ;;
  --disable-*)
    disable_library "${1#--disable-}"
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
	echo -e "your box only has $box_memory_size_bytes, 512MB (only) 
  boxes crash when building cross compiler gcc, please add some swap" | tee -a "$LOG_FILE" # 1G worked OK however...
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

# Setup config variables

# disable libraries autodetected by default to prevent inadvertent bundling
disable_autodetected

apply_preset "$CONFIG_GENERAL"

if truthy "$audio_bundle"; then
  enable_audio=1
  enable_https=1
fi
if truthy "$audio_ai_bundle"; then
  enable_audio=1
  enable_audio_ai=1
  enable_https=1
fi
if truthy "$video_bundle"; then
  enable_audio=1
  enable_video=1
  enable_https=1
fi
if truthy "$video_ai_bundle"; then
  enable_audio=1
  enable_video=1
  enable_video_ai=1
  enable_https=1
fi
if truthy "$video_hw_bundle"; then
  enable_audio=1
  enable_video=1
  enable_hardware=1
  enable_https=1
fi
if truthy "$video_ai_hw_bundle"; then
  enable_audio=1
  enable_video=1
  enable_audio_ai=1
  enable_video_ai=1
  enable_hardware=1
  enable_https=1
fi
if truthy "$streaming_bundle"; then
  enable_audio=1
  enable_video=1
  enable_streaming=1
  enable_https=1
fi

if truthy "$enable_nonfree"; then
  echo "WARNING: Non-free licensing selected. Binaries will be 
  non-redistributable without proper licensing. You are responsible 
  for making sure you have the appropriate licensing to distribute 
  the binaries!" | tee -a "$LOG_FILE"

  truthy "$enable_audio" || truthy "$enable_full" && apply_preset "$CONFIG_AUDIO_NON_FREE"
  truthy "$enable_video" || truthy "$enable_full" && apply_preset "$CONFIG_VIDEO_NON_FREE"
  truthy "$enable_streaming" || truthy "$enable_full" && apply_preset "$CONFIG_STREAMING_NON_FREE"
  truthy "$enable_hardware" || truthy "$enable_full" && apply_preset "$CONFIG_HARDWARE_NON_FREE"
  truthy "$enable_audio_ai" || truthy "$enable_full" && apply_preset "$CONFIG_AUDIO_AI_NON_FREE"
  truthy "$enable_video_ai" || truthy "$enable_full" && apply_preset "$CONFIG_VIDEO_AI_NON_FREE"
  truthy "$enable_ssh" || truthy "$enable_full" && apply_preset "$CONFIG_SSH_NON_FREE"

  if [[ "${host_platform,,}" != "windows" ]]; then
    truthy "$enable_smb" || truthy "$enable_full" && apply_preset "$CONFIG_SMB_NON_FREE"
  fi

  case "${host_platform,,}" in
    linux)
    truthy "$enable_full" && apply_preset "$CONFIG_LINUX_NON_FREE"
    ;;
    windows)
    truthy "$enable_full" && apply_preset "$CONFIG_WINDOWS_NON_FREE"
    ;;
    android)
    truthy "$enable_full" && apply_preset "$CONFIG_ANDROID_NON_FREE"
    ;;
    apple)
    truthy "$enable_full" && apply_preset "$CONFIG_APPLE_NON_FREE"
    ;;
    rpi)
    truthy "$enable_full" && apply_preset "$CONFIG_RPI_NON_FREE"
    ;;
    oh|openharmony|open-harmony|open_harmony)
    truthy "$enable_full" && apply_preset "$CONFIG_OH_NON_FREE"
    ;;
    *)
    ;;
  esac
fi

truthy "$enable_audio" || truthy "$enable_full" && apply_preset "$CONFIG_AUDIO"
truthy "$enable_video" || truthy "$enable_full" && apply_preset "$CONFIG_VIDEO"
truthy "$enable_streaming" || truthy "$enable_full" && apply_preset "$CONFIG_STREAMING"
truthy "$enable_hardware" || truthy "$enable_full" && apply_preset "$CONFIG_HARDWARE"
truthy "$enable_audio_ai" || truthy "$enable_full" && apply_preset "$CONFIG_AUDIO_AI"
truthy "$enable_video_ai" || truthy "$enable_full" && apply_preset "$CONFIG_VIDEO_AI"
truthy "$enable_ssh" || truthy "$enable_full" && apply_preset "$CONFIG_SSH"

if [[ "${host_platform,,}" != "windows" ]]; then
  truthy "$enable_smb" || truthy "$enable_full" && apply_preset "$CONFIG_SMB"
fi

case "${host_platform,,}" in
  linux)
    truthy "$enable_full" && apply_preset "$CONFIG_LINUX"
    ;;
    windows)
    truthy "$enable_full" && apply_preset "$CONFIG_WINDOWS"
    ;;
    android)
    truthy "$enable_full" && apply_preset "$CONFIG_ANDROID"
    ;;
    apple)
    truthy "$enable_full" && apply_preset "$CONFIG_APPLE"
    ;;
    rpi)
    truthy "$enable_full" && apply_preset "$CONFIG_RPI"
    ;;
    oh|openharmony|open-harmony|open_harmony)
    truthy "$enable_full" && apply_preset "$CONFIG_OH"
    ;;
    *)
  ;;
esac

if ! truthy "$enable_small"; then
  truthy "$enable_audio" || truthy "$enable_full" && apply_preset "$CONFIG_AUDIO_EXTRA"
  truthy "$enable_video" || truthy "$enable_full" && apply_preset "$CONFIG_VIDEO_EXTRA"
fi

if truthy "$enable_https"; then
  if [[ -z "$ssl_type" ]]; then
    pick_ssl_type
    case "${ssl_type,,}" in
      openssl)
        disable_library "gnutls"
        disable_library "mbedtls"
        disable_library "libtls"
        ;;
      gnutls)
        disable_library "mbedtls"
        disable_library "libtls"
        disable_library "openssl"
        ;;
      mbedtls)
        disable_library "gnutls"
        disable_library "libtls"
        disable_library "openssl"
        ;;
      libtls)
        disable_library "gnutls"
        disable_library "mbedtls"
        disable_library "openssl"
        ;;
    esac
  fi
fi

if truthy "$enable_streaming"; then
  if ! truthy "$enable_openssl" && truthy "$disable_openssl" && ! truthy "$enable_librtmp" && truthy "$disable_librtmp"; then
    if [[ -z "$crypto_type" ]]; then
      pick_cryto_lib
    fi
  fi
fi

# strict gpl libraries
check_gpl_libraries

resolve_collisions

source "${SCRIPTDIR}/main-$host_platform.sh"
