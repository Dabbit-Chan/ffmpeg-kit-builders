/*
 * This file is part of FFmpeg.
 * Copyright (c) 2025 Akash Patel
 * Copyright (c) 2023 ARTHENICA LTD
 *
 * FFmpeg is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * FFmpeg is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with FFmpeg; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
 */

#ifndef FFTOOLS_FFMPEG_UTILS_H
#define FFTOOLS_FFMPEG_UTILS_H

#include <stdint.h>
#include "libavutil/rational.h"

typedef struct Timestamp {
    int64_t ts;
    AVRational tb;
} Timestamp;

/**
 * Merge two return codes.
 * Return the first one if it is negative, otherwise the second one.
 */
static inline int err_merge(int err, int new_err)
{
    if (err < 0)
        return err;
    return new_err;
}

#endif // FFTOOLS_FFMPEG_UTILS_H