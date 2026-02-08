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

#ifndef FFMPEG_LIB_H
#define FFMPEG_LIB_H

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
extern "C" {
#endif

typedef struct FFmpegContext FFmpegContext;

/**
 * Initialize ffmpeg context by parsing the command line string.
 * This does not initialize the FFmpeg libraries or globals yet;
 * that happens during ffmpeg_run to ensure thread safety.
 *
 * @param args_string Space-separated command line arguments (e.g., "-i
 * input.mp4 out.mov")
 * @return Allocated context or NULL on failure.
 */
FFMPEG_API FFmpegContext *ffmpeg_init(const char *args_string);

/**
 * Execute the transcoding operation.
 * This function is thread-safe (uses a global mutex) but blocking.
 * Only one transcoding session can run at a time due to FFmpeg CLI global
 * state.
 *
 * @param ctx The context created by ffmpeg_init.
 * @return 0 on success, negative AVERROR code on failure.
 */
FFMPEG_API int ffmpeg_run(FFmpegContext *ctx);

/**
 * Get progress information.
 *
 * @param ctx The context.
 * @return Float between 0.0 and 1.0.
 */
FFMPEG_API float ffmpeg_get_progress(FFmpegContext *ctx);

/**
 * Signal the current operation to cancel.
 *
 * @param ctx The context.
 */
FFMPEG_API void ffmpeg_cancel(FFmpegContext *ctx);

/**
 * Free the context and associated resources.
 *
 * @param ctx The context.
 */
FFMPEG_API void ffmpeg_free(FFmpegContext *ctx);

#ifdef __cplusplus
}
#endif

#endif // FFMPEG_LIB_H