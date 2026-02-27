#!/usr/bin/env bash
set -e

# shellcheck disable=SC2317,SC2129,SC1091,SC2120,SC2035,SC2016,SC2310,SC2155,SC2154,SC2034

# State management configuration
STATE_DIR="${STATE_DIR:-${HOME}/.ffmpeg-kit-build-state}"
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

# Parse arguments
p=""
deps=""
reset_state=false

for arg; do
  case "${arg}" in
    linux|windows) 
      p="${arg:0:1}"
      shift;;
    d) 
      deps="y"
      shift;;
    --reset)
      reset_state=true
      shift;;
    --help)
      echo "Usage: $0 [linux|windows] [d] [--reset] [--help]"
      echo ""
      echo "Options:"
      echo "  linux|windows  Target platform (required)"
      echo "  d              Build dependencies first"
      echo "  --reset        Reset build state and start from beginning"
      echo "  --help         Show this help message"
      echo ""
      echo "State file location: ${STATE_FILE}"
      exit 0;;
    *)  
      echo "Invalid argument: ${arg}"
      echo "Use --help for usage information"
      exit 1;;
  esac
done

# Validate platform selection
if [[ -z "$p" ]]; then
  echo "Error: Platform (linux|windows) is required"
  echo "Use --help for usage information"
  exit 1
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
  local script="$1"
  local args="$2"
  grep -qxF "${script} ${args}" "${STATE_FILE}" 2>/dev/null
}

# Mark a build step as completed
mark_completed() {
  local script="$1"
  local args="$2"
  echo "${script} ${args}" >> "${STATE_FILE}"
}

# Execute a build step with state tracking
execute_build() {
  local script="$1"
  local args="$2"
  local step_name="${script} ${args}"
  
  if is_completed "${script}" "${args}"; then
    echo "[SKIP] Already completed: ${step_name}"
    return 0
  fi
  
  echo "[BUILD] Starting: ${step_name}"
  
  if sudo "${script}" ${args}; then
    mark_completed "${script}" "${args}"
    echo "[DONE] Completed: ${step_name}"
    return 0
  else
    local exit_code=$?
    echo "[FAIL] Failed: ${step_name} (exit code: ${exit_code})"
    echo ""
    echo "Build failed. You can:"
    echo "  1. Fix the issue and re-run this script to resume from this step"
    echo "  2. Use --reset to start from the beginning"
    exit ${exit_code}
  fi
}

# Define all build steps
declare -a BUILD_STEPS

# Dependencies (optional)
if [[ -n "$deps" ]]; then
  BUILD_STEPS+=("./scripts/builds/64-full.sh|1 gfy${p}")
fi

# Debug builds
BUILD_STEPS+=(
  "./scripts/builds/64-debug.sh|23 gfy${p}"
  "./scripts/builds/64-debug.sh|23 fy${p}"
)

# Base builds
BUILD_STEPS+=(
  "./scripts/builds/64-base.sh|23 gfy${p}"
  "./scripts/builds/64-base.sh|23 fy${p}"
  "./scripts/builds/64-base.sh|23 sgfy${p}"
  "./scripts/builds/64-base.sh|23 sfy${p}"
)

# Audio builds
BUILD_STEPS+=(
  "./scripts/builds/64-audio.sh|23 gfy${p}"
  "./scripts/builds/64-audio.sh|23 fy${p}"
  "./scripts/builds/64-audio.sh|23 sgfy${p}"
  "./scripts/builds/64-audio.sh|23 sfy${p}"
)

# Video builds
BUILD_STEPS+=(
  "./scripts/builds/64-video.sh|23 gfy${p}"
  "./scripts/builds/64-video.sh|23 fy${p}"
  "./scripts/builds/64-video.sh|23 sgfy${p}"
  "./scripts/builds/64-video.sh|23 sfy${p}"
)

# Streaming builds
BUILD_STEPS+=(
  "./scripts/builds/64-streaming.sh|23 gfy${p}"
  "./scripts/builds/64-streaming.sh|23 fy${p}"
  "./scripts/builds/64-streaming.sh|23 sgfy${p}"
  "./scripts/builds/64-streaming.sh|23 sfy${p}"
)

# Video hardware builds
BUILD_STEPS+=(
  "./scripts/builds/64-video-hw.sh|23 gfy${p}"
  "./scripts/builds/64-video-hw.sh|23 fy${p}"
  "./scripts/builds/64-video-hw.sh|23 sgfy${p}"
  "./scripts/builds/64-video-hw.sh|23 sfy${p}"
)

# Full builds
BUILD_STEPS+=(
  "./scripts/builds/64-full.sh|23 gfy${p}"
  "./scripts/builds/64-full.sh|23 fy${p}"
  "./scripts/builds/64-full.sh|23 sgfy${p}"
  "./scripts/builds/64-full.sh|23 sfy${p}"
)

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
echo "Platform: ${p}"
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
  script="${step%%|*}"
  args="${step#*|}"
  
  echo ""
  echo "========================================"
  echo "Step ${current_step}/${total_steps}"
  echo "========================================"
  
  execute_build "${script}" "${args}"
done

echo ""
echo "========================================"
echo "All builds completed successfully!"
echo "========================================"
echo "State file: ${STATE_FILE}"
echo "You can use --reset to clear the state for a fresh build."