#!/usr/bin/env bash
set -e
small=""
force=""
default=""
platform=""
if [[ -n "$1" || -n "$2" ]]; then
  [[ "${1,,}${2,,}" == *s* ]] && small="--enable-small"
  [[ "${1,,}${2,,}" == *f* ]] && force="-f"
  [[ "${1,,}${2,,}" == *y* ]] && default="-y"
  [[ "${1,,}${2,,}" == *g* ]] && lic="--gpl"
  [[ "${1,,}${2,,}" == *n* ]] && lic="--nonfree"
  [[ "${1,,}${2,,}" == *l* ]] && platform="linux"
  [[ "${1,,}${2,,}" == *a* ]] && platform="android"
  [[ "${1,,}${2,,}" == *w* ]] && platform="windows"
  [[ "${1,,}${2,,}" == *m* ]] && platform="macos"
  [[ "${1,,}${2,,}" == *i* ]] && platform="ios"
fi

case "$1" in
  1)
  ./runner.sh --host=${platform} --arch=x86_64 $default --full-bundle --build-deps --skip --skip-pkg-check $small $force $lic
  exit 0
  ;;
  2)
  ./runner.sh --host=${platform} --arch=x86_64 $default --full-bundle --build-ffmpeg=static --skip --skip-pkg-check $small $force $lic
  exit 0
  ;;
  3)
  ./runner.sh --host=${platform} --arch=x86_64 $default --full-bundle --build-ffmpeg-kit=shared --release=remote --clean --skip --skip-pkg-check $small $force $lic
  exit 0
  ;;
  12)
  ./runner.sh --host=${platform} --arch=x86_64 $default --full-bundle --build-deps --build-ffmpeg=static  --skip --skip-pkg-check $small $force $lic
  exit 0
  ;;
  23)
  ./runner.sh --host=${platform} --arch=x86_64 $default --full-bundle --build-ffmpeg --build-ffmpeg-kit --clean --release=remote --skip --skip-pkg-check $small $force $lic
  exit 0
  ;;
  123)
  ./runner.sh --host=${platform} --arch=x86_64 $default --full-bundle --build-deps --build-ffmpeg --build-ffmpeg-kit --clean --release=remote --skip --skip-pkg-check $small $force $lic
  exit 0
  ;;
  *)
  ./runner.sh --host=${platform} --arch=x86_64 $default --full-bundle $small $force --release=remote --clean --skip --skip-pkg-check $lic
  exit 0
  ;;
esac