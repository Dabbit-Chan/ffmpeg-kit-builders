cd FFmpegKit/build
export ASAN_OPTIONS=detect_leaks=1:detect_odr_violation=0
./tests/ffmpegkit_tests > test.log 2>&1
echo "Test log saved to FFmpegKit/build/test.log"