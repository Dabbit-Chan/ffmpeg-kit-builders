#!/usr/bin/env bash

# shellcheck disable=SC2317,SC2129,SC1091,SC2120,SC2035,SC2016,SC2310,SC2155,SC2154,SC2034

# Build AARs for Android

# Update sudo timestamp to avoid interruption later
echo "Requesting administrative privileges..."
sudo -v

# State management configuration
export BASEDIR="${BASEDIR:-${PWD}}"
export LOG_FILE="${BASEDIR}/build.log"
export host_platform="android"
STATE_DIR="${STATE_DIR:-${BASEDIR}/.ffmpeg-kit-build-aar-state}"
STATE_FILE="${STATE_DIR}/build_aar.state"
LOCK_FILE="${STATE_DIR}/build_aar.lock"

source $BASEDIR/scripts/function.sh

[[ -f "$LOG_FILE" ]] && rm -f "$LOG_FILE"
[[ -f "$LOG_FILE" ]] && chmod -R a+rwx "$LOG_FILE" || true;

# Initialize state directory
mkdir -p "${STATE_DIR}"

# Cleanup function for lock file
cleanup() {
  rm -f "${LOCK_FILE}"
}
trap cleanup EXIT

# Check for existing lock
if [[ -f "${LOCK_FILE}" ]]; then
  echo "Error: Another build process is running (lock file exists: ${LOCK_FILE})"
  echo "If you're sure no other build is running, remove the lock file manually."
  exit 1
fi

# Create lock file
touch "${LOCK_FILE}"

# Keep the timestamp alive in the background for long-running builds
while true; do sudo -n v; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# Parse arguments
p=""
p_args=""
deps=""
reset_state=false
VALID_TYPES=("debug" "full" "base" "audio" "video" "video_hw")
VALID_ARCHS=("x86_64" "aarch64" "armv7a")
VALID_PLATFORM_ARCHS=("android-aarch64" "android-armv7a" "android-x86_64")
LICENSE_FLAGS=(" " "gpl")
SMALL_FLAGS=(" " "small")
declare -A PLATFORMS

parse_arch() {
    case "$1" in
        "x86_64")
            echo "x86_64"
            ;;
        "aarch64"|"arm64"|"arm64-v8a")
            echo "arm64-v8a"
            ;;
        "armv7a"|"arm"|"armeabi-v7a")
            echo "armeabi-v7a"
            ;;
        *)
            echo "parse_arch: Unsupported host arch '$1' for Android"
            exit 1
            ;;
    esac
}

parse_platforms() {
  p_args="${1}"
  # Ensure p_args is populated if empty
  if [[ -z "${p_args}" ]]; then
    p_args=$(IFS=,; echo "${VALID_PLATFORM_ARCHS[*]}")
  fi
  echo "DEBUG: p_args: ${p_args}"
  # Use IFS local to the read command
  IFS=',' read -ra P_ARRAY <<< "$p_args"
  for p in "${P_ARRAY[@]}"; do
    # Skip empty elements resulting from trailing/double commas
    [[ -z "$p" ]] && continue
    # Validate against whitelist
    local valid=false
    for valid_p in "${VALID_PLATFORM_ARCHS[@]}"; do
      [[ "$p" == "$valid_p" ]] && valid=true && break
    done
    if [[ "$valid" == false ]]; then
      echo "Error: Invalid platform and arch: ${p}"
      echo "Use --help for usage information"
      exit 1
    fi
    local key="${p%-*}"
    local value="${p#*-}"
    # Always quote the key within the brackets
    if [[ -z "${PLATFORMS["$key"]}" ]]; then
      PLATFORMS["$key"]="${value}"
    else
      PLATFORMS["$key"]="${PLATFORMS["$key"]},${value}"
    fi
  done
}

parse_bundles() {
  bundles="${1}"
  # Ensure bundles is populated if empty
  if [[ -z "${bundles}" ]]; then
    bundles=$(IFS=,; echo "${VALID_TYPES[*]}")
  fi
  echo "DEBUG: bundles: ${bundles}"
  # Use IFS local to the read command
  IFS=',' read -ra BUNDLE_ARRAY <<< "${bundles}"
  for b in "${BUNDLE_ARRAY[@]}"; do
    # Skip empty elements resulting from trailing/double commas
    [[ -z "$b" ]] && continue
    # Validate against whitelist
    local valid=false
    for valid_b in "${VALID_TYPES[@]}"; do
      [[ "$b" == "$valid_b" ]] && valid=true && break
    done
    if [[ "$valid" == false ]]; then
      echo "Error: Invalid bundle type: ${b}"
      echo "Use --help for usage information"
      exit 1
    fi
  done
}

# Check if a build step is already completed
is_completed() {
  grep -qxF "$1" "${STATE_FILE}" 2>/dev/null
}

# Mark a build step as completed
mark_completed() {
  echo "$1" >> "${STATE_FILE}"
}

# Execute a build step with state tracking
execute_build() {
  local cmd_string="$1"
  if is_completed "${cmd_string}"; then
    echo "[SKIP] Already completed: ${cmd_string}"
    return 0
  fi
  
  echo "[BUILD] Starting: ${cmd_string}"
  
  if sudo -E bash -c "${cmd_string}"; then
    mark_completed "${cmd_string}"
    echo "[DONE] Completed: ${cmd_string}"
    return 0
  else
    local exit_code=$?
    echo "[FAIL] Failed: ${cmd_string} (exit code: ${exit_code})"
    echo ""
    echo "Build failed. You can:"
    echo "  1. Fix the issue and re-run this script to resume from this step"
    echo "  2. Use --reset to start from the beginning"
    exit ${exit_code}
  fi
}

create_jni_libs_dir() {
  local bundle_pfx=""
  local small_pfx=""
  local license_pfx=""
  local is_debug_pfx=""
  for arg in "$@"; do
    case "$arg" in
      -b=*)
        local bundle="${arg#*=}"
        local bundle_pfx="-${bundle}"
        ;;
      -s=*)
        local small="${arg#*=}"
        if [[ "${small}" == "small" ]]; then
            small_pfx="-small"
        fi
        ;;
      -l=*)
        local license="${arg#*=}"
        if [[ "${license}" == "gpl" ]]; then
            license_pfx="-gpl"
        fi
        ;;
      *)
        echo "create_jni_libs_dir: Unsupported arg '$arg'"
        exit 1
        ;;
    esac
  done
  if [[ "${bundle}" == "debug" ]]; then
    bundle_pfx="-base"
    is_debug_pfx="-debug"
  fi
  local jni_libs_dir="${BASEDIR}/prebuilt/android/jniLibs${bundle_pfx}${small_pfx}${is_debug_pfx}${license_pfx}/jniLibs"
  mkdir -p "${jni_libs_dir}"/{include,lib/pkgconfig,arm64-v8a,armeabi-v7a,x86,x86_64}
  chmod -R a+rwx "${jni_libs_dir}"
  echo "${jni_libs_dir}"
}

get_ffmpeg_kit_dir() {
  local arch_pfx=""
  local bundle_pfx=""
  local small_pfx=""
  local license_pfx=""
  local is_debug_pfx=""
  for arg in "$@"; do
    case "$arg" in
      -a=*)
        local arch="${arg#*=}"
        local arch_pfx="-${arch}"
        ;;
      -b=*)
        local bundle="${arg#*=}"
        local bundle_pfx="-${bundle}"
        ;;
      -s=*)
        local small="${arg#*=}"
        if [[ "${small}" == "small" ]]; then
            small_pfx="-small"
        fi
        ;;
      -l=*)
        local license="${arg#*=}"
        if [[ "${license}" == "gpl" ]]; then
            license_pfx="-gpl"
        fi
        ;;
      *)
        echo "get_ffmpeg_kit_dir: Unsupported arg '$arg'"
        exit 1
        ;;
    esac
  done
  if [[ "${bundle}" == "debug" ]]; then
    bundle_pfx="-base"
    is_debug_pfx="-debug"
  fi
    # ffmpeg-kit-base-android-x86_64-shared-debug-gpl or ffmpeg-kit-video_hw-android-x86_64-shared-small-gpl
    echo "${BASEDIR}/prebuilt/android-${arch}/ffmpeg-kit${bundle_pfx}-android${arch_pfx}-shared${small_pfx}${is_debug_pfx}${license_pfx}"
}

for arg; do
  case "${arg}" in
    --platform=*)
     # input format: platform-arch ex: linux-x86_64 or android-aarch64. Comma separated (without spaces) list of platforms.
     # output format: platform ex: linux or android
     p_args="${arg#*=}"
     parse_platforms "${p_args}"
     shift;;
    --reset)
      reset_state=true
      shift;;
    --help)
      echo "Usage: $0 [--platform=linux-x86_64|windows-x86_64|android-aarch64|android-armv7a|android-x86_64] [--reset] [--bundles=*) ] [--help]"
      echo ""
      echo "Options:"
      echo "  --platform=*  Comma separated (without spaces) list of platforms and architectures (e.g. --platform=linux-x86_64,windows-x86_64,android-aarch64,android-armv7a,android-x86_64)"
      echo "                Valid platforms: ${VALID_PLATFORMS[*]}"
      echo "                Valid architectures: ${VALID_ARCHS[*]}"
      echo "                Valid platform and arch combinations: ${VALID_PLATFORM_ARCHS[*]}"
      echo "  --reset       Reset build state and start from beginning"
      echo "  --bundles=*   Comma separated (without spaces) list of bundles to build (e.g. --bundles=debug,full,base,audio,video,video_hw)"
      echo "                Valid bundles: ${VALID_TYPES[*]}"
      echo "  --help        Show this help message"
      echo ""
      echo "State file location: ${STATE_FILE}"
      exit 0;;
    --bundles=*) 
      #comma separated list of bundles to build
      parse_bundles "${arg#*=}"
      shift;;
    --snapshot)
      SNAPSHOT=true
      shift;;
    *)  
      echo "Invalid argument: ${arg}"
      echo "Use --help for usage information"
      exit 1;;
  esac
done

# Check if the number of elements is 0
if [[ ${#PLATFORMS[@]} -eq 0 ]]; then
  parse_platforms ""
fi

if [[ ${#BUNDLE_ARRAY[@]} -eq 0 ]]; then
  parse_bundles ""
fi

# Reset state if requested
if [[ "$reset_state" == true ]]; then
  echo "Resetting build state..."
  rm -f "${STATE_FILE}"
fi

# Initialize state file if it doesn't exist
if [[ ! -f "${STATE_FILE}" ]]; then
  echo "# Build state file - DO NOT EDIT MANUALLY" > "${STATE_FILE}"
  echo "# Format: <script> <args>" >> "${STATE_FILE}"
fi

ANDROID_HOME="/usr/local/android-sdk"
latest_ndk=$(ls -v "$ANDROID_HOME/ndk" 2>/dev/null | tail -n 1)
ANDROID_API_LEVEL="26"
GITHUB_USERNAME="$(get_github_owner)"
GITHUB_REPO="$(get_github_repo)"
GITHUB_PASSWORD="$(get_github_token)"
GITHUB_PASSWORD_CLASSIC="$(get_github_token_classic)"
OSSRH_USERNAME="$(get_maven_username)"
OSSRH_PASSWORD="$(get_maven_password)"
GRADLE_COMMAND="publishToMavenCentral"
USER_HOME="/home/vscode"
GRADLE_USER_HOME="${USER_HOME}/.gradle"

if [[ ! -f "${GRADLE_USER_HOME}/gradle.properties" && ! -f "${USER_HOME}/.gnupg/secring.gpg" ]]; then
  GRADLE_COMMAND="publishReleasePublicationToMavenLocal"
fi

# FFMPEG_KIT_VERSION: from version file
if [[ "$SNAPSHOT" == true ]]; then
  FFMPEG_KIT_VERSION="$(cat "${BASEDIR}/version")-SNAPSHOT"
else
  FFMPEG_KIT_VERSION="$(cat "${BASEDIR}/version")"
fi
echo "sdk.dir=$ANDROID_HOME" > local.properties

# Define all build steps
declare -a BUILD_STEPS

if [[ ! -f gradlew ]]; then
  echo "RUNNING: gradle wrapper --distribution-type all"
  gradle wrapper --distribution-type all || { echo "Failed to create Gradle wrapper"; exit 1; }
fi
chmod +x gradlew

for key in "${!PLATFORMS[@]}"; do
  platform=${key}
  # comma separated list of architectures
  IFS=',' read -ra arch_array <<< "${PLATFORMS[$key]}"
  for bundle in "${BUNDLE_ARRAY[@]}"; do
      for license in "${LICENSE_FLAGS[@]}"; do
          for small in "${SMALL_FLAGS[@]}"; do
              jni_libs_dir="$(create_jni_libs_dir -b="${bundle}" -l="${license}" -s="${small}")"
              BUILD_STEPS=()
              license_flag=""
              if [[ "${license}" == "gpl" ]]; then
                  license_flag="--gpl"
              fi
              small_flag=""
              if [[ "${small}" == "small" ]]; then
                  small_flag="--small"
              fi
              for arch in "${arch_array[@]}"; do
                  # execute_build "${step}"
                  ffmpeg_kit_dir="$(get_ffmpeg_kit_dir -b="${bundle}" -l="${license}" -s="${small}" -a="${arch}")"
                  ffmpeg_kit_include_dir="${ffmpeg_kit_dir}/include"
                  abi_arch="$(parse_arch "${arch}")"
                  # copy to jniLibs
                  if [[ -d "${ffmpeg_kit_include_dir}" ]]; then
                    echo "Copying include directory to jniLibs" > >(redirect_output)
                    cp -r "${ffmpeg_kit_include_dir}" "${jni_libs_dir}" > >(redirect_output)
                  fi
                  if [[ -d "${ffmpeg_kit_dir}/lib" ]]; then
                    echo "Copying lib directory to jniLibs" > >(redirect_output)
                    find "${ffmpeg_kit_dir}/lib" \( -name "*.so*" -o -name "*.a*" \) -exec cp -fv {} "${jni_libs_dir}/${abi_arch}" \; > >(redirect_output)
                  fi
                  if [[ -d "${ffmpeg_kit_dir}/lib/pkgconfig" ]]; then
                    echo "Copying pkgconfig directory to jniLibs" > >(redirect_output)
                    cp -r "${ffmpeg_kit_dir}/lib/pkgconfig" "${jni_libs_dir}/lib" > >(redirect_output)
                  fi
                  chmod -R a+rwx "${jni_libs_dir}"
              done
              # assemble aar from prebuilt ffmpeg-kit
              # path to prebuilt ffmpeg-kit: ${BASEDIR}/prebuilt/android-${arch}/ffmpeg-kit-${bundle}-${arch}-shared-${small}-${license}
              # path to prebuilt ffmpeg-kit include: ${BASEDIR}/prebuilt/android-${arch}/ffmpeg-kit-${bundle}-${arch}-shared-${small}-${license}/include
              # gradle variables:
              # FFMPEG_KIT_NAMESPACE: io.github.akashskypatel.ffmpegkit
              FFMPEG_KIT_NAMESPACE="io.github.akashskypatel.ffmpegkit"
              # ANDROID_NDK: ${latest_ndk}
              ANDROID_NDK="${latest_ndk}"
              # ANDROID_API_LEVEL: ${ANDROID_API_LEVEL}
              ANDROID_API_LEVEL="${ANDROID_API_LEVEL}"
              # FFMPEG_KIT_VERSION_CODE: current date as int like 20260305
              FFMPEG_KIT_VERSION_CODE="$(date +%Y%m%d)"
              # FFMPEG_KIT_JNI_LIBS_DIR: ${jni_libs_dir}/jniLibs
              FFMPEG_KIT_JNI_LIBS_DIR=$(realpath "${jni_libs_dir}")
              if [[ ! -d "${FFMPEG_KIT_JNI_LIBS_DIR}" ]]; then
                echo "DEBUG: Failed to resolve jniLibs directory"
                continue
              fi
              small_pfx=""
              if [[ "${small}" == "small" ]]; then
                  small_pfx="-small"
              fi
              license_pfx=""
              if [[ "${license}" == "gpl" ]]; then
                  license_pfx="-gpl"
              else
                  license_pfx="-lgpl"
              fi
              assemble_type="Release"
              bundle_pfx="$bundle"
              debug_pfx=""
              if [[ "${bundle}" == "debug" ]]; then
                  bundle_pfx="base"
                  debug_pfx="-debug"
              fi
              # FFMPEG_KIT_OUTPUT_NAME: bundle-${bundle}-${arch}-shared-${small}-${license}
              FFMPEG_KIT_OUTPUT_NAME="bundle-${bundle_pfx}-shared${debug_pfx}${small_pfx}${license_pfx}"
              package_name="${FFMPEG_KIT_NAMESPACE}.${FFMPEG_KIT_OUTPUT_NAME}"
              echo "${FFMPEG_KIT_JNI_LIBS_DIR}" > >(redirect_output)
              if find "${FFMPEG_KIT_JNI_LIBS_DIR}" -type f \( -name "*.so" -o -name "*.a" \) | read -r; then
                if check_maven_package_status "${FFMPEG_KIT_OUTPUT_NAME}" "$FFMPEG_KIT_VERSION"; then
                  echo "Package ${FFMPEG_KIT_NAMESPACE}-${FFMPEG_KIT_OUTPUT_NAME} version $FFMPEG_KIT_VERSION already exists, skipping..." > >(redirect_output)
                else
                  { ./gradlew :tools:android:${GRADLE_COMMAND} \
                  --no-daemon --info --warning-mode all --gradle-user-home /home/vscode/.gradle \
                  -PFFMPEG_KIT_NAMESPACE="${FFMPEG_KIT_NAMESPACE}" \
                  -PANDROID_NDK="${ANDROID_NDK}" \
                  -PANDROID_API_LEVEL="${ANDROID_API_LEVEL}" \
                  -PFFMPEG_KIT_VERSION_CODE="${FFMPEG_KIT_VERSION_CODE}" \
                  -PFFMPEG_KIT_VERSION="${FFMPEG_KIT_VERSION}" \
                  -PFFMPEG_KIT_JNI_LIBS_DIR="${FFMPEG_KIT_JNI_LIBS_DIR}" \
                  -PFFMPEG_KIT_OUTPUT_NAME="${FFMPEG_KIT_OUTPUT_NAME}" \
                  -POSSRH_USERNAME="${OSSRH_USERNAME}" \
                  -POSSRH_PASSWORD="${OSSRH_PASSWORD}" > >(redirect_output); }  || { echo "Failed to publish AAR for ${FFMPEG_KIT_OUTPUT_NAME}"; exit 1; }
                fi
                release_asset=$(realpath "${BASEDIR}/tools/android/build/outputs/aar/${FFMPEG_KIT_OUTPUT_NAME}-${assemble_type,,}.aar")
                if [[ -f "${release_asset}" ]]; then
                  echo "Publishing release asset ${release_asset} ..."
                  create_github_release "${release_asset}"
                fi
              fi
          done
      done
  done
done

echo ""
echo "========================================"
echo "All builds completed successfully!"
echo "========================================"

rm -f "${STATE_FILE}"