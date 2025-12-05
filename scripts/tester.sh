#!/bin/bash

# shellcheck disable=SC2317,SC1091,SC1090,SC2120

# parse command line parameters, if any

ffmpeg_bin_path=""
LOG_FILE="$(realpath ..)/test.log"

chown -R "$USER:$USER" "$LOG_FILE"

rm -f "$LOG_FILE"

echo "" >"$LOG_FILE"

while [ $# -gt 0 ]; do
	ffmpeg_bin_path="$1"
  shift
  ffmpeg_test_num="$1"
  break
done

if [[ ! -f $ffmpeg_bin_path ]]; then
  echo "Invalid ffmpeg binary path" | tee -a "$LOG_FILE"
  exit 1
fi

if [[ -z $ffmpeg_test_num ]]; then
  echo "Invalid ffmpeg test number" | tee -a "$LOG_FILE"
  exit 1
fi

"./test$ffmpeg_test_num.sh" "$ffmpeg_bin_path" >&2 >>"$LOG_FILE"

echo -e "See test.log for test results"