#!/usr/bin/env bash

small=""
force=""
gpu=""
default=""
gpl=""
if [[ -n "$1" || -n "$2" ]]; then
  [[ "${1,,}${2,,}" == *s* ]] && small="--enable-small"
  [[ "${1,,}${2,,}" == *f* ]] && force="-f"
  [[ "${1,,}${2,,}" == *y* ]] && default="-y"
  [[ "${1,,}${2,,}" == *g* ]] && gpl="--gpl"
  if [[ "${1,,}${2,,}" == *c* ]]; then 
    gpu="-cuda"
  elif [[ "${1,,}${2,,}" == *r* ]]; then
    gpu="-rocm"
  fi
fi
cd "$(pwd)/../../" || exit 1
case "$1" in
  1)
  ./runner.sh --host=linux --arch=x86_64 $default --video-hw-ai-gpu$gpu-bundle --build-deps-only $small $force $gpl
  exit 0
  ;;
  2)
  ./runner.sh --host=linux --arch=x86_64 $default --video-hw-ai-gpu$gpu-bundle --build-ffmpeg-only=static $small $force $gpl
  exit 0
  ;;
  3)
  ./runner.sh --host=linux --arch=x86_64 $default --video-hw-ai-gpu$gpu-bundle --build-ffmpeg-kit-only=shared --release $small $force $gpl
  exit 0
  ;;
  *)
  ./runner.sh --host=linux --arch=x86_64 $default --video-hw-ai-gpu$gpu-bundle $small $force --release $gpl
  exit 0
  ;;
esac