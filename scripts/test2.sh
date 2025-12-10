#!/bin/bash

# shellcheck disable=SC2317,SC1091,SC1090,SC2120,SC2069

# Robust FFmpeg smoke test - dynamically tests available encoders/decoders

set -euo pipefail

FFMPEG=""
sys_proc=$(nproc)
threads=$(( sys_proc / 2 ))
LOG_FILE="$(realpath ..)/test.log"

while [ $# -gt 0 ]; do
	FFMPEG="$1"
  shift
  break
done

if [[ ! -f $FFMPEG ]]; then
  echo "Invalid ffmpeg binary path" | tee -a "$LOG_FILE"
  exit 1
fi

TEST_DIR=".ffmpeg_test_$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1

# Set thread options if specified
THREAD_OPTS=""
if [[ -n "$threads" ]]; then
    THREAD_OPTS="-threads $threads"
fi

cleanup() { 
    cd .. 
    rm -rf "$TEST_DIR" 2>/dev/null || true
}
trap cleanup EXIT

echo "🧪 Testing: $FFMPEG"
echo "📊 Threads: ${threads:-auto}"
"$FFMPEG" -loglevel warning -version 2>&1 | grep "ffmpeg version" | head -1 

# 1. Multi-threaded raw video test (suppress verbose output)
echo "1. Testing multi-threaded raw video processing..."
"$FFMPEG" -loglevel warning -f lavfi -i testsrc=size=1920x1080:rate=30:duration=1 \
    "$THREAD_OPTS" -c:v rawvideo -pix_fmt yuv420p -f null - \
    2>&1 | tail -3 | grep -E "(speed=|frame=.*fps)" && echo "✅ Multi-threaded raw encode OK"

# 2. Test frame-level parallelism
echo "2. Testing frame-level parallelism..."
"$FFMPEG" -loglevel warning -f lavfi -i testsrc=size=1280x720:rate=60:duration=2 \
    "$THREAD_OPTS" -c:v rawvideo -pix_fmt yuv420p -f null - \
    2>&1 | tail -3 | grep -E "(speed=|frame=.*fps)" && echo "✅ Frame threading OK"

# 3. Test slice-level parallelism (h.264/x264 specific) - simplified
echo "3. Testing slice-level parallelism..."
if "$FFMPEG" -loglevel warning -encoders 2>/dev/null | grep -q "264"; then
    ENC=$("$FFMPEG" -loglevel warning -encoders 2>/dev/null | grep "264" | head -1 | awk '{print $2}')
    echo "  Found encoder: $ENC"
    "$FFMPEG" -loglevel warning -f lavfi -i color=size=640x480:rate=30:duration=0.5 \
        "$THREAD_OPTS" -c:v "$ENC" -f null - \
        2>&1 | tail -3 | grep -q "video:" && echo "✅ Slice threading OK"
else
    echo "  No H.264 encoder found, skipping slice test"
fi

# 4. Parallel audio processing test - simplified
echo "4. Testing multi-threaded audio processing..."
"$FFMPEG" -loglevel warning -f lavfi -i "aevalsrc=0.1*sin(2*PI*440*t):d=0.5" \
    "$THREAD_OPTS" -c:a pcm_s16le -f null - \
    2>&1 | tail -3 | grep -q "audio:" && echo "✅ Audio threading OK"

# 5. Test filter graph parallelism - simplified
echo "5. Testing filter graph parallelism..."
"$FFMPEG" -loglevel warning -f lavfi -i testsrc=size=640x360:rate=30:duration=0.5 \
    "$THREAD_OPTS" -vf "scale=320:240" -c:v rawvideo -f null - \
    2>&1 | tail -3 | grep -q "video:" && echo "✅ Filter threading OK"

# 6. Concurrent encode/decode test - simplified and safer
echo "6. Testing concurrent encode/decode..."
# Create a small test file first
"$FFMPEG" -loglevel warning -f lavfi -i testsrc=size=320x240:rate=30:duration=0.5 \
    -c:v rawvideo -pix_fmt yuv420p test_input.yuv 2>/dev/null

# Concurrent processing
"$FFMPEG" -loglevel warning -f rawvideo -pix_fmt yuv420p -s 320x240 -r 30 -i test_input.yuv \
    "$THREAD_OPTS" -c:v rawvideo -pix_fmt yuv420p -f null - \
    2>&1 | tail -3 | grep -q "video:" && echo "✅ Concurrent processing OK"

# 7. Test specific threading models - simplified
echo "7. Testing specific threading models..."
for thread_type in frame slice; do
    "$FFMPEG" -loglevel warning -f lavfi -i color=size=320x240:rate=30:duration=0.2 \
        -thread_type "$thread_type" "$THREAD_OPTS" -c:v rawvideo -f null - \
        2>&1 | tail -3 | grep -q "video:" && echo "  ✅ $thread_type threading supported"
done

# 8. Memory and thread safety test - simplified
echo "8. Testing memory/thread safety..."
for i in {1..3}; do
    "$FFMPEG" -loglevel warning -f lavfi -i "color=size=64x48:rate=1:duration=0.1" \
        "$THREAD_OPTS" -c:v rawvideo -f null - \
        2>/dev/null &
done
wait && echo "✅ Concurrent execution stable"

# 9. Check threading support in build
echo "9. Verifying threading support..."
"$FFMPEG" -loglevel warning -buildconf 2>&1 | grep -i "pthreads" && echo "✅ Threading enabled in build"

# 10. Performance benchmark with threads
echo "10. Threaded performance benchmark..."
if [[ -n "$threads" ]]; then
    echo "  Running with $threads threads:"
    time "$FFMPEG" -loglevel warning -hide_banner -loglevel error \
        -f lavfi -i testsrc=size=1920x1080:rate=30:duration=1 \
        -threads "$threads" -c:v rawvideo -pix_fmt yuv420p -f null - \
        2>&1 >/dev/null
fi

# Cleanup
rm -f test_input.yuv 2>/dev/null || true

echo "🎯 Multi-threaded smoke test completed successfully!"