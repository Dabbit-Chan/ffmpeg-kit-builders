#!/usr/bin/env bash

lib_path="$1"

if [[ ! -d $lib_path && ! -f $lib_path ]]; then
  echo "Invalid path"
  exit 1
fi

if [[ -d $lib_path && -f "$lib_path/libffmpegkit.so" ]]; then
  lib_path="$lib_path/libffmpegkit.so"
fi

echo "Symbol count:"
nm -D --defined-only "$lib_path" | grep " T " | wc -l
echo "Text relocation check (blank = success):"
readelf -d "$lib_path" | grep TEXTREL
echo "Dependency check (system deps = success):"
ldd -r "$lib_path"
