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

/*
 * Implementation of the DLL-safe av_assert0 override.
 * Compiled as a normal translation unit where all FFmpeg headers
 * are available, so av_log and AV_LOG_PANIC are fully declared.
 */

#include "ffmpeg_kit_assert_override.h"

/* FFmpeg headers are safe to include here - this is not force-included */
#include "libavutil/log.h"

#include <setjmp.h>
#include <stddef.h>

/* Thread-local storage definitions - exactly one TU must define these */
FFMPEG_THREAD_LOCAL jmp_buf ffmpeg_kit_assert_jmp;
FFMPEG_THREAD_LOCAL int     ffmpeg_kit_assert_triggered = 0;

void ffmpeg_kit_assert_log(const char *cond, const char *file, int line) {
    av_log(NULL, AV_LOG_PANIC,
           "[ffmpeg-kit] Assertion '%s' failed at %s:%d — recovering, "
           "session will be marked as failed.\n",
           cond, file, line);
}
