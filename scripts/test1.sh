#!/bin/bash

# Path to your custom ffmpeg binary
FFMPEG_PATH="/home/devcontainers/ffmpeg-kit-builders/prebuilt/windows-x86_64/bundle-windows-x86_64-static/bin/ffmpeg.exe"

# --- DO NOT EDIT BELOW THIS LINE ---

# Expand the path
FFMPEG_PATH=$(eval echo "$FFMPEG_PATH")

# Check if the ffmpeg binary exists
if [ ! -f "$FFMPEG_PATH" ]; then
    echo "Error: ffmpeg binary not found at $FFMPEG_PATH"
    exit 1
fi

echo "--- FFmpeg Version and Configuration ---"
$FFMPEG_PATH -version

echo -e "\n--- Available Decoders ---"
$FFMPEG_PATH -decoders | head -n 10

echo -e "\n--- Available Encoders ---"
$FFMPEG_PATH -encoders | head -n 10

echo -e "\n--- Available Muxers ---"
$FFMPEG_PATH -muxers | head -n 10

echo -e "\n--- Available Demuxers ---"
$FFMPEG_PATH -demuxers | head -n 10

echo -e "\n--- Available Filters ---"
$FFMPEG_PATH -filters | head -n 10