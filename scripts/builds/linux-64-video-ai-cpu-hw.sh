#!/usr/bin/env bash

small=""

case "${2,,}" in
  s|small|m|min)
    small="--enable-small"
    ;;
  *);;
esac
cd "$(pwd)/../../" || exit 1
case "$1" in
  1)
  ./runner.sh --host=linux --arch=x86_64 -y --video-ai-cpu-hw-bundle --build-deps-only $small
  exit 0
  ;;
  2)
  ./runner.sh --host=linux --arch=x86_64 -y --video-ai-cpu-hw-bundle --build-ffmpeg-only -f $small
  exit 0
  ;;
  3)
  ./runner.sh --host=linux --arch=x86_64 -y --video-ai-cpu-hw-bundle --build-ffmpeg-kit-only -f --release $small
  exit 0
  ;;
  *)
  ./runner.sh --host=linux --arch=x86_64 -y --video-ai-cpu-hw-bundle $small
  exit 0
  ;;
esac