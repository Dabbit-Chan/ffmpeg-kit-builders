#!/usr/bin/env bash
set -e
small=""
force=""
default=""
lic=""
if [[ -n "$1" || -n "$2" ]]; then
  [[ "${1,,}${2,,}" == *s* ]] && small="--enable-small"
  [[ "${1,,}${2,,}" == *f* ]] && force="-f"
  [[ "${1,,}${2,,}" == *y* ]] && default="-y"
  [[ "${1,,}${2,,}" == *g* ]] && lic="--gpl"
  [[ "${1,,}${2,,}" == *n* ]] && lic="--nonfree"
fi

case "$1" in
  1)
  ./runner.sh --host=windows --arch=x86_64 $default --audio-bundle --build-deps-only --skip --skip-pkg-check $small $force $lic
  exit 0
  ;;
  2)
  ./runner.sh --host=windows --arch=x86_64 $default --audio-bundle --build-ffmpeg-only=static --skip --skip-pkg-check $small $force $lic
  exit 0
  ;;
  3)
  ./runner.sh --host=windows --arch=x86_64 $default --audio-bundle --build-ffmpeg-kit-only=shared --release-and-clean --skip --skip-pkg-check $small $force $lic
  exit 0
  ;;
  *)
  ./runner.sh --host=windows --arch=x86_64 $default --audio-bundle $small $force --release-and-clean --skip --skip-pkg-check $lic
  exit 0
  ;;
esac