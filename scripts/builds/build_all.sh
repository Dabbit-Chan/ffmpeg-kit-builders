#!/usr/bin/env bash
set -e

# shellcheck disable=SC2317,SC2129,SC1091,SC2120,SC2035,SC2016,SC2310,SC2155,SC2154,SC2034

for arg; do
  case "${arg}" in
    linux|windows) 
      break
      shift;;
    *)
    echo "Invalid platform"
    exit 1;
  esac
done

sudo ./"${arg}"-64-full.sh 1 gfy

sudo ./scripts/builds/"${arg}"-64-full.sh 2 gfy
sudo ./scripts/builds/"${arg}"-64-full.sh 3 gfy
sudo ./scripts/builds/"${arg}"-64-full.sh 2 fy
sudo ./scripts/builds/"${arg}"-64-full.sh 3 fy
sudo ./scripts/builds/"${arg}"-64-full.sh 2 sgfy
sudo ./scripts/builds/"${arg}"-64-full.sh 3 sgfy
sudo ./scripts/builds/"${arg}"-64-full.sh 2 sfy
sudo ./scripts/builds/"${arg}"-64-full.sh 3 sfy
sudo ./scripts/builds/"${arg}"-64-audio.sh 2 gfy
sudo ./scripts/builds/"${arg}"-64-audio.sh 3 gfy
sudo ./scripts/builds/"${arg}"-64-audio.sh 2 fy
sudo ./scripts/builds/"${arg}"-64-audio.sh 3 fy
sudo ./scripts/builds/"${arg}"-64-audio.sh 2 sgfy
sudo ./scripts/builds/"${arg}"-64-audio.sh 3 sgfy
sudo ./scripts/builds/"${arg}"-64-audio.sh 2 sfy
sudo ./scripts/builds/"${arg}"-64-audio.sh 3 sfy
sudo ./scripts/builds/"${arg}"-64-video.sh 2 gfy
sudo ./scripts/builds/"${arg}"-64-video.sh 3 gfy
sudo ./scripts/builds/"${arg}"-64-video.sh 2 fy
sudo ./scripts/builds/"${arg}"-64-video.sh 3 fy
sudo ./scripts/builds/"${arg}"-64-video.sh 2 sgfy
sudo ./scripts/builds/"${arg}"-64-video.sh 3 sgfy
sudo ./scripts/builds/"${arg}"-64-video.sh 2 sfy
sudo ./scripts/builds/"${arg}"-64-video.sh 3 sfy
sudo ./scripts/builds/"${arg}"-64-streaming.sh 2 gfy
sudo ./scripts/builds/"${arg}"-64-streaming.sh 3 gfy
sudo ./scripts/builds/"${arg}"-64-streaming.sh 2 fy
sudo ./scripts/builds/"${arg}"-64-streaming.sh 3 fy
sudo ./scripts/builds/"${arg}"-64-streaming.sh 2 sgfy
sudo ./scripts/builds/"${arg}"-64-streaming.sh 3 sgfy
sudo ./scripts/builds/"${arg}"-64-streaming.sh 2 sfy
sudo ./scripts/builds/"${arg}"-64-streaming.sh 3 sfy
sudo ./scripts/builds/"${arg}"-64-video-hw.sh 2 gfy
sudo ./scripts/builds/"${arg}"-64-video-hw.sh 3 gfy
sudo ./scripts/builds/"${arg}"-64-video-hw.sh 2 fy
sudo ./scripts/builds/"${arg}"-64-video-hw.sh 3 fy
sudo ./scripts/builds/"${arg}"-64-video-hw.sh 2 sgfy
sudo ./scripts/builds/"${arg}"-64-video-hw.sh 3 sgfy
sudo ./scripts/builds/"${arg}"-64-video-hw.sh 2 sfy
sudo ./scripts/builds/"${arg}"-64-video-hw.sh 3 sfy