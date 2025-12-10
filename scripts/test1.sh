#!/bin/bash

# shellcheck disable=SC2317,SC1091,SC1090,SC2120

# parse command line parameters, if any

ffmpeg_bin_path=""
LOG_FILE="$(realpath ..)/test.log"

while [ $# -gt 0 ]; do
	ffmpeg_bin_path="$1"
  shift 
  break
done

if [[ ! -f $ffmpeg_bin_path ]]; then
  echo "Invalid ffmpeg binary path" | tee -a "$LOG_FILE"
  exit 1
fi

# Expand the path
ffmpeg_bin_path=$(eval echo "$ffmpeg_bin_path")

# Check if the ffmpeg binary exists
if [ ! -f "$ffmpeg_bin_path" ]; then
    echo "Error: ffmpeg binary not found at $ffmpeg_bin_path"
    exit 1
fi

echo "--- FFmpeg Version and Configuration ---"
$ffmpeg_bin_path -loglevel warning -version

echo -e "\n--- Available Decoders ---" 
$ffmpeg_bin_path -loglevel warning -decoders 

echo -e "\n--- Available Encoders ---" 
$ffmpeg_bin_path -loglevel warning -encoders 

echo -e "\n--- Available Muxers ---" 
$ffmpeg_bin_path -loglevel warning -muxers 

echo -e "\n--- Available Demuxers ---" 
$ffmpeg_bin_path -loglevel warning -demuxers 

echo -e "\n--- Available Filters ---" 
$ffmpeg_bin_path -loglevel warning -filters 