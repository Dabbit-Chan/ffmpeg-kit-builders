/*
 * Copyright (c) 2025 Akash Patel
 *
 * This file is part of FFmpegKit.
 *
 * FFmpegKit is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * FFmpegKit is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with FFmpegKit.  If not, see <http://www.gnu.org/licenses/>.
 */

#ifndef FFPROBE_LIB_H
#define FFPROBE_LIB_H

#include <stddef.h>
#include <stdint.h>

#if defined(_WIN32)
  #ifdef FFMPEG_KIT_BUILDING_DLL
    #define FFMPEG_API __declspec(dllexport)
  #else
    #define FFMPEG_API __declspec(dllimport)
  #endif
#else
  #define FFMPEG_API __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C"
{
#endif

  typedef struct FFprobeContext FFprobeContext;

  /**
   * Initialize ffprobe context.
   *
   * @param args_string Command line arguments (e.g., "-show_streams input.mp4")
   * @return Context or NULL.
   */
  FFMPEG_API FFprobeContext *ffprobe_init(const char *args_string);

  /**
   * Run ffprobe.
   * Thread-safe (mutex locked), blocking.
   *
   * @param ctx The context.
   * @return 0 on success, <0 on error.
   */
  FFMPEG_API int ffprobe_run(FFprobeContext *ctx);

  /**
   * Retrieve the captured output string.
   * Caller must free the returned string.
   *
   * @param ctx The context.
   * @return Malloc'd string or NULL.
   */
  FFMPEG_API char *ffprobe_get_output(FFprobeContext *ctx);

  /**
   * Get the size of the output buffer.
   */
  FFMPEG_API size_t ffprobe_get_output_size(FFprobeContext *ctx);

  /**
   * Free resources.
   */
  FFMPEG_API void ffprobe_free(FFprobeContext *ctx);

#ifdef __cplusplus
}
#endif

#endif // FFPROBE_LIB_H