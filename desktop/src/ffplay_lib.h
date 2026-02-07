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

#ifndef FFPLAY_LIB_H
#define FFPLAY_LIB_H

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

typedef struct FFplayContext FFplayContext;

// Event callbacks for library integration
typedef struct FFplayCallbacks {
    void (*on_frame_displayed)(void *userdata, const uint8_t *data, int width, int height, int linesize);
    void (*on_audio_samples)(void *userdata, const uint8_t *data, int size);
    void (*on_seek_complete)(void *userdata, double position);
    void (*on_error)(void *userdata, const char *error);
    void *userdata;
} FFplayCallbacks;

// Initialize ffplay with command-line arguments as a string
// Returns NULL on error
FFMPEG_API FFplayContext* ffplay_init(const char* args_string, const FFplayCallbacks *cb);

// Start playback (non-blocking if possible, but ffplay architecture is thread-heavy)
// Returns 0 on success
FFMPEG_API int ffplay_start(FFplayContext* ctx);

// Process events (call regularly from your event loop)
// Returns 0 if running, 1 if quit/finished
FFMPEG_API int ffplay_step(FFplayContext* ctx);

// Control playback
FFMPEG_API int ffplay_seek(FFplayContext* ctx, double seconds);
FFMPEG_API int ffplay_pause(FFplayContext* ctx);
FFMPEG_API int ffplay_resume(FFplayContext* ctx);
FFMPEG_API int ffplay_stop(FFplayContext* ctx);

// Get playback state
FFMPEG_API double ffplay_get_position(FFplayContext* ctx);
FFMPEG_API double ffplay_get_duration(FFplayContext* ctx);
FFMPEG_API int ffplay_is_playing(FFplayContext* ctx);
FFMPEG_API int ffplay_is_paused(FFplayContext* ctx);

// Set volume (0.0 to 1.0)
FFMPEG_API void ffplay_set_volume(FFplayContext* ctx, float volume);

// Clean up resources
FFMPEG_API void ffplay_free(FFplayContext* ctx);

#ifdef __cplusplus
}
#endif

#endif // FFPLAY_LIB_H