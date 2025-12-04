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

# Generate a 10-second test video
echo "--- Generating test video ---"
$FFMPEG_PATH -f lavfi -i testsrc=duration=10:size=1280x720:rate=30 -y test_input.mp4

# Check if the input video was created
if [ ! -f "test_input.mp4" ]; then
    echo "Error: Failed to generate test input video."
    exit 1
fi

# Transcode the video to a different format (e.g., WebM)
echo "--- Transcoding to WebM ---"
$FFMPEG_PATH -i test_input.mp4 -c:v libvpx -b:v 1M -c:a libvorbis -y test_output.webm

# Check if the output video was created
if [ ! -f "test_output.webm" ]; then
    echo "Error: Failed to transcode video."
    exit 1
fi

echo "--- Transcoding test successful! ---"
echo "Generated files: test_input.mp4, test_output.webm"

# Clean up the generated files
# To keep the files, comment out the next line
rm test_input.mp4 test_output.webm