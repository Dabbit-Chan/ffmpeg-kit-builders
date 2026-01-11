#!/usr/bin/env bash

small=""
force=""
default=""
gpl=""
if [[ -n "$1" || -n "$2" ]]; then
  [[ "${1,,}${2,,}" == *s* ]] && small="--enable-small"
  [[ "${1,,}${2,,}" == *f* ]] && force="-f"
  [[ "${1,,}${2,,}" == *y* ]] && default="-y"
  [[ "${1,,}${2,,}" == *g* ]] && gpl="--gpl"
fi
cd "$(pwd)/../../" || exit 1
case "$1" in
  1)
  ./runner.sh --host=linux --arch=x86_64 $default --audio-bundle --build-deps-only $small $force $gpl
  exit 0
  ;;
  2)
  ./runner.sh --host=linux --arch=x86_64 $default --audio-bundle --build-ffmpeg-only=static $small $force $gpl
  exit 0
  ;;
  3)
  ./runner.sh --host=linux --arch=x86_64 $default --audio-bundle --build-ffmpeg-kit-only=shared --release $small $force $gpl
  exit 0
  ;;
  *)
  ./runner.sh --host=linux --arch=x86_64 $default --audio-bundle $small $force --release $gpl
  exit 0
  ;;
esac