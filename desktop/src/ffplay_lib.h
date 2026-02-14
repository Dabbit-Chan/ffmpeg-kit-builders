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
/**
 * Initializes ffplay with command-line arguments as a string.
 *
 * @param args_string the command-line arguments as a string
 * @param cb the callback
 * @return the ffplay context
 */
FFMPEG_API FFplayContext* ffplay_init(const char* args_string, const FFplayCallbacks *cb);

// Start playback (non-blocking if possible, but ffplay architecture is thread-heavy)
// Returns 0 on success
/**
 * Starts playback (non-blocking if possible, but ffplay architecture is thread-heavy).
 *
 * @param ctx the ffplay context
 * @return 0 on success
 */
FFMPEG_API int ffplay_start(FFplayContext* ctx);

// Process events (call regularly from your event loop)
// Returns 0 if running, 1 if quit/finished
/**
 * Processes events (call regularly from your event loop).
 *
 * @param ctx the ffplay context
 * @return 0 if running, 1 if quit/finished
 */
FFMPEG_API int ffplay_step(FFplayContext* ctx);

// Control playback
/**
 * Seeks to a specific position in the media.
 *
 * @param ctx the ffplay context
 * @param seconds the seconds to seek to
 * @param rel the relative position to seek to
 * @return 0 on success
 */
FFMPEG_API int ffplay_seek(FFplayContext* ctx, double seconds, double rel);

/**
 * Pauses playback.
 *
 * @param ctx the ffplay context
 * @return 0 on success
 */
FFMPEG_API int ffplay_pause(FFplayContext* ctx);

/**
 * Resumes playback.
 *
 * @param ctx the ffplay context
 * @return 0 on success
 */
FFMPEG_API int ffplay_resume(FFplayContext* ctx);

/**
 * Stops playback.
 *
 * @param ctx the ffplay context
 * @return 0 on success
 */
FFMPEG_API int ffplay_stop(FFplayContext* ctx);

// Get playback state
/**
 * Gets the playback position.
 *
 * @param ctx the ffplay context
 * @return the playback position
 */
FFMPEG_API double ffplay_get_position(FFplayContext* ctx);

/**
 * Gets the playback duration.
 *
 * @param ctx the ffplay context
 * @return the playback duration
 */
FFMPEG_API double ffplay_get_duration(FFplayContext* ctx);

/**
 * Checks if the playback is playing.
 *
 * @param ctx the ffplay context
 * @return 1 if playing, 0 otherwise
 */
FFMPEG_API int ffplay_is_playing(FFplayContext* ctx);

/**
 * Checks if the playback is paused.
 *
 * @param ctx the ffplay context
 * @return 1 if paused, 0 otherwise
 */
FFMPEG_API int ffplay_is_paused(FFplayContext* ctx);

// Set volume (0.0 to 1.0)
/**
 * Sets the volume.
 *
 * @param ctx the ffplay context
 * @param volume the volume
 */
FFMPEG_API void ffplay_set_volume(FFplayContext* ctx, float volume);

/**
 * Gets the volume.
 *
 * @param ctx the ffplay context
 * @return the volume
 */
FFMPEG_API float ffplay_get_volume(FFplayContext* ctx);

/**
 * Sets the audio output device.
 * null for default device
 *
 * @param device_name the name of the audio device
 */
FFMPEG_API void ffplay_set_audio_output_device(const char* device_name);

/**
 * Get all available audio devices.
 * format: null-terminated array of strings.
 * caller must free results with free() (and also free strings?)
 * No, let's keep it simple: Callback pattern?
 * Or: Returns a single string with names separated by \0, double null at end.
 * Actually, let's provide a callback based approach to avoid complex memory management across boundaries.
 */

// Better approach for wrapper: 
// Returns a single string with all device names delimited by ';'. (Assumes device names don't contain ';')
// Returns NULL if error. Caller must free.
FFMPEG_API char* ffplay_list_audio_devices(void);

// Clean up resources
/**
 * Cleans up resources.
 *
 * @param ctx the ffplay context
 */
FFMPEG_API void ffplay_free(FFplayContext* ctx);

/**
 * Closes the ffplay session.
 *
 * @param ctx the ffplay context
 */
FFMPEG_API void ffplay_close(FFplayContext* ctx);

#ifdef __cplusplus
}
#endif

#endif // FFPLAY_LIB_H