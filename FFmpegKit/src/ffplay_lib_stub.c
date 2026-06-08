/*
 * Copyright (c) 2025 Akash Patel
 *
 * No-op stub implementations of the ffplay_* API. Compiled in place of
 * ffplay_lib.c when SDL2 is unavailable (e.g. OpenHarmony --enable-base
 * --disable-sdl2). All callers in FFmpegKitConfig.cpp / FFplaySession.cpp /
 * FFplayKit.cpp / ffmpegkit_wrapper.cpp keep linking, and the FFplay
 * functionality is silently disabled at runtime: init returns NULL, query
 * functions return zero/false, action functions return non-zero error codes.
 *
 * This file mirrors the declarations in ffplay_lib.h exactly.
 */

#include "ffplay_lib.h"
#include <stdlib.h>

struct FFplayContext { int unused; };

FFMPEG_API FFplayContext* ffplay_init(const char* args_string, const FFplayCallbacks *cb) {
    (void)args_string; (void)cb;
    return NULL;
}

FFMPEG_API int ffplay_start(FFplayContext* ctx)            { (void)ctx; return -1; }
FFMPEG_API int ffplay_step(FFplayContext* ctx)             { (void)ctx; return 1;  }
FFMPEG_API int ffplay_seek(FFplayContext* ctx, double seconds, double rel) {
    (void)ctx; (void)seconds; (void)rel; return -1;
}
FFMPEG_API int ffplay_pause(FFplayContext* ctx)            { (void)ctx; return -1; }
FFMPEG_API int ffplay_resume(FFplayContext* ctx)           { (void)ctx; return -1; }
FFMPEG_API int ffplay_stop(FFplayContext* ctx)             { (void)ctx; return -1; }

FFMPEG_API double ffplay_get_position(FFplayContext* ctx)  { (void)ctx; return 0.0; }
FFMPEG_API double ffplay_get_duration(FFplayContext* ctx)  { (void)ctx; return 0.0; }
FFMPEG_API int    ffplay_is_playing(FFplayContext* ctx)    { (void)ctx; return 0; }
FFMPEG_API int    ffplay_is_paused(FFplayContext* ctx)     { (void)ctx; return 0; }

FFMPEG_API void  ffplay_set_volume(FFplayContext* ctx, float volume) { (void)ctx; (void)volume; }
FFMPEG_API float ffplay_get_volume(FFplayContext* ctx)               { (void)ctx; return 0.0f; }

FFMPEG_API void  ffplay_set_audio_output_device(const char* device_name) { (void)device_name; }
FFMPEG_API char* ffplay_list_audio_devices(void)                         { return NULL; }

FFMPEG_API void  ffplay_get_video_size(FFplayContext* ctx, int *width, int *height) {
    (void)ctx;
    if (width)  *width  = 0;
    if (height) *height = 0;
}

FFMPEG_API void  ffplay_free(FFplayContext* ctx)           { (void)ctx; }
FFMPEG_API void  ffplay_close(FFplayContext* ctx)          { (void)ctx; }
FFMPEG_API int   ffplay_has_video_stream(const char *path) { (void)path; return -1; }

#ifdef __ANDROID__
FFMPEG_API void  ffplay_set_android_window(ANativeWindow *window) { (void)window; }
#endif

FFMPEG_API void  ffplay_set_frame_callback(FFplayFrameCallback callback, void *userdata) {
    (void)callback; (void)userdata;
}

FFMPEG_API void  ffplay_lib_on_frame(const uint8_t *pixels, int width, int height,
                                     int linesize, const char *pixel_format) {
    (void)pixels; (void)width; (void)height; (void)linesize; (void)pixel_format;
}
