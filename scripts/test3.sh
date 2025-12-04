#!/bin/bash

# Path to your FFmpeg source directory
FFMPEG_SOURCE_PATH="~/ffmpeg_sources/ffmpeg"

# Path to the FATE samples directory
FATE_SAMPLES_PATH="~/fate-samples"

# --- DO NOT EDIT BELOW THIS LINE ---

# Expand the paths
FFMPEG_SOURCE_PATH=$(eval echo "$FFMPEG_SOURCE_PATH")
FATE_SAMPLES_PATH=$(eval echo "$FATE_SAMPLES_PATH")

# Check if the ffmpeg source directory exists
if [ ! -d "$FFMPEG_SOURCE_PATH" ]; then
    echo "Error: FFmpeg source directory not found at $FFMPEG_SOURCE_PATH"
    exit 1
fi

# Download FATE samples if they don't exist
if [ ! -d "$FATE_SAMPLES_PATH" ]; then
    echo "--- FATE samples not found. Cloning from git... ---"
    git clone https://git.ffmpeg.org/fate-samples.git "$FATE_SAMPLES_PATH"
fi

# Go to the FFmpeg source directory
cd "$FFMPEG_SOURCE_PATH"

# Run FATE
echo "--- Running FATE tests ---"
make V=1 SAMPLES="$FATE_SAMPLES_PATH" fate

echo "--- FATE tests finished ---"