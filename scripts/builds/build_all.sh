#!/usr/bin/env bash
set -e

# shellcheck disable=SC2317,SC2129,SC1091,SC2120,SC2035,SC2016,SC2310,SC2155,SC2154,SC2034
p=""
for arg; do
  case "${arg}" in
    linux|windows) 
      p="${arg:0:1}"
      break
      shift;;
    *)
    echo "Invalid platform"
    exit 1;
  esac
done

# sudo ./scripts/builds/64-full.sh 1 gfy${p}

# sudo ./scripts/builds/64-base.sh 23 gfy${p}
# sudo ./scripts/builds/64-base.sh 23 fy${p}
# sudo ./scripts/builds/64-base.sh 23 sgfy${p}
# sudo ./scripts/builds/64-base.sh 23 sfy${p}
# sudo ./scripts/builds/64-full.sh 23 gfy${p}
sudo ./scripts/builds/64-full.sh 23 fy${p}
sudo ./scripts/builds/64-full.sh 23 sgfy${p}
sudo ./scripts/builds/64-full.sh 23 sfy${p}
sudo ./scripts/builds/64-audio.sh 23 gfy${p}
sudo ./scripts/builds/64-audio.sh 23 fy${p}
sudo ./scripts/builds/64-audio.sh 23 sgfy${p}
sudo ./scripts/builds/64-audio.sh 23 sfy${p}
sudo ./scripts/builds/64-video.sh 23 gfy${p}
sudo ./scripts/builds/64-video.sh 23 fy${p}
sudo ./scripts/builds/64-video.sh 23 sgfy${p}
sudo ./scripts/builds/64-video.sh 23 sfy${p}
sudo ./scripts/builds/64-streaming.sh 23 gfy${p}
sudo ./scripts/builds/64-streaming.sh 23 fy${p}
sudo ./scripts/builds/64-streaming.sh 23 sgfy${p}
sudo ./scripts/builds/64-streaming.sh 23 sfy${p}
sudo ./scripts/builds/64-video-hw.sh 23 gfy${p}
sudo ./scripts/builds/64-video-hw.sh 23 fy${p}
sudo ./scripts/builds/64-video-hw.sh 23 sgfy${p}
sudo ./scripts/builds/64-video-hw.sh 23 sfy${p}