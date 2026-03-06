#!/usr/bin/env bash
set -e

# shellcheck disable=SC2317,SC2129,SC1091,SC2120,SC2035,SC2016,SC2310,SC2155,SC2154,SC2034

# State management configuration
STATE_DIR="${STATE_DIR:-${PWD}/.ffmpeg-kit-build-state}"
STATE_FILE="${STATE_DIR}/build_all.state"
LOCK_FILE="${STATE_DIR}/build_all.lock"

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

# Update sudo timestamp to avoid interruption later
echo "Requesting administrative privileges..."
sudo -v

# Keep the timestamp alive in the background for long-running builds
while true; do sudo -n v; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# Parse arguments
p=""
p_args=""
deps=""
reset_state=false
VALID_TYPES=("debug" "full" "base" "audio" "video" "video_hw")
VALID_PLATFORMS=("linux" "windows" "android")
VALID_ARCHS=("x86_64" "aarch64" "armv7a")
VALID_PLATFORM_ARCHS=("linux-x86_64" "windows-x86_64" "android-aarch64" "android-armv7a" "android-x86_64")
declare -A PLATFORMS

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

for arg; do
  case "${arg}" in
    --platform=*)
     # input format: platform-arch ex: linux-x86_64 or android-aarch64. Comma separated (without spaces) list of platforms.
     # output format: platform ex: linux or android
     p_args="${arg#*=}"
     parse_platforms "${p_args}"
     shift;;
    --deps) 
      deps="--deps"
      build_deps=true
      shift;;
    --reset)
      reset_state=true
      shift;;
    --help)
      echo "Usage: $0 [--platform=linux-x86_64|windows-x86_64|android-aarch64|android-armv7a|android-x86_64] [--deps] [--reset] [--bundles=*) ] [--help]"
      echo ""
      echo "Options:"
      echo "  --platform=*  Comma separated (without spaces) list of platforms and architectures (e.g. --platform=linux-x86_64,windows-x86_64,android-aarch64,android-armv7a,android-x86_64)"
      echo "                Valid platforms: ${VALID_PLATFORMS[*]}"
      echo "                Valid architectures: ${VALID_ARCHS[*]}"
      echo "                Valid platform and arch combinations: ${VALID_PLATFORM_ARCHS[*]}"
      echo "  --deps        Build dependencies first"
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

# Define all build steps
declare -a BUILD_STEPS

for key in "${!PLATFORMS[@]}"; do
  platform=${key}
  # comma separated list of architectures
  IFS=',' read -ra arch_array <<< "${PLATFORMS[$key]}"
  for arch in "${arch_array[@]}"; do
    for bundle in "${BUNDLE_ARRAY[@]}"; do
      if [[ "${bundle}" == "debug" ]]; then
        BUILD_STEPS+=("./runner.sh --host=${platform} --arch=${arch} -y ${deps} --base-bundle --build-debug --build-ffmpeg --build-ffmpeg-kit --clean --release=remote --skip --gpl -f")
        BUILD_STEPS+=("./runner.sh --host=${platform} --arch=${arch} -y ${deps} --base-bundle --build-debug --build-ffmpeg --build-ffmpeg-kit --clean --release=remote --skip -f")
      else
        BUILD_STEPS+=("./runner.sh --host=${platform} --arch=${arch} -y ${deps} --${bundle}-bundle --build-ffmpeg --build-ffmpeg-kit --clean --release=remote --skip --gpl -f")
        BUILD_STEPS+=("./runner.sh --host=${platform} --arch=${arch} -y ${deps} --${bundle}-bundle --build-ffmpeg --build-ffmpeg-kit --clean --release=remote --skip -f")
        BUILD_STEPS+=("./runner.sh --host=${platform} --arch=${arch} -y ${deps} --${bundle}-bundle --build-ffmpeg --build-ffmpeg-kit --clean --release=remote --skip --gpl -f --small")
        BUILD_STEPS+=("./runner.sh --host=${platform} --arch=${arch} -y ${deps} --${bundle}-bundle --build-ffmpeg --build-ffmpeg-kit --clean --release=remote --skip -f --small")
      fi
    done
  done
done

# Calculate progress
total_steps=${#BUILD_STEPS[@]}
completed_steps=$(wc -l < "${STATE_FILE}" | tr -d ' ')
# Subtract header lines
completed_steps=$((completed_steps - 2))
if [[ ${completed_steps} -lt 0 ]]; then
  completed_steps=0
fi

echo "========================================"
echo "FFmpeg Kit Build All - State Management"
echo "========================================"
echo "Platform: ${p_args}"
echo "Bundles: ${bundles}"
echo "Dependencies: ${deps:-no}"
echo "Total steps: ${total_steps}"
echo "Completed steps: ${completed_steps}"
echo "Remaining steps: $((total_steps - completed_steps))"
echo "State file: ${STATE_FILE}"
echo "========================================"
echo ""

# Execute all build steps
current_step=0
for step in "${BUILD_STEPS[@]}"; do
  current_step=$((current_step + 1))
  echo ""
  echo "========================================"
  echo "Step ${current_step}/${total_steps}"
  echo "========================================"
  echo "Executing ${step}"
  [[ -z "${step}" ]] && continue
  execute_build "${step}"
done

echo ""
echo "========================================"
echo "All builds completed successfully!"
echo "========================================"
echo "State file: ${STATE_FILE}"
echo "You can use --reset to clear the state for a fresh build."