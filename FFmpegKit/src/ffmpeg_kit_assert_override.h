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

#ifndef FFMPEG_KIT_ASSERT_OVERRIDE_H
#define FFMPEG_KIT_ASSERT_OVERRIDE_H

#include <setjmp.h>
#include "ffmpeg_tls.h"

/* avassert.h is a C header. When force-included into C++ translation units
 * it must be wrapped in extern "C" to prevent name mangling of av_log_*
 * symbols, which would cause linker failures against the C-compiled libavutil. */
#ifdef __cplusplus
extern "C" {
#endif

#include "libavutil/avassert.h"

#ifdef __cplusplus
}
#endif

/* Override — runs after avassert.h so this is always the final definition. */
#undef av_assert0
#define av_assert0(cond) do {                               \
    if (!(cond)) {                                          \
        ffmpeg_kit_assert_log(#cond, __FILE__, __LINE__);   \
        ffmpeg_kit_assert_triggered = 1;                    \
        longjmp(ffmpeg_kit_assert_jmp, 1);                  \
    }                                                       \
} while (0)

#ifdef __cplusplus
extern "C" {
#endif

extern FFMPEG_THREAD_LOCAL jmp_buf ffmpeg_kit_assert_jmp;
extern FFMPEG_THREAD_LOCAL int     ffmpeg_kit_assert_triggered;
void ffmpeg_kit_assert_log(const char *cond, const char *file, int line);

#ifdef __cplusplus
}
#endif

#endif /* FFMPEG_KIT_ASSERT_OVERRIDE_H */