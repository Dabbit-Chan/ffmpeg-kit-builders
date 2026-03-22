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
 * Android JNI glue for FFmpegKit.
 *
 * Provides:
 *   - A retained ANativeWindow* that ffplay_lib.c uses via SDL_CreateWindowFrom()
 *     to render video to a Java Surface without requiring SDL's SDLActivity.
 *   - A JNI entry point callable from Java/Kotlin to set or clear the Surface.
 *
 * Audio is handled by SDL2's OpenSL ES backend (SDL_AUDIODRIVER=openslES set in
 * ffplay_lib.c), which is fully native and requires no Java interaction.
 *
 * Java usage:
 *   import com.akashskypatel.ffmpegkit.FFplayKitAndroid;
 *
 *   // Before starting playback:
 *   FFplayKitAndroid.setAndroidSurface(surfaceView.getHolder().getSurface());
 *
 *   // When SurfaceView is destroyed:
 *   FFplayKitAndroid.setAndroidSurface(null);
 */

#ifdef __ANDROID__

#include <jni.h>
#include <android/native_window.h>
#include <android/native_window_jni.h>
#include <android/log.h>

#define LOG_TAG "FFmpegKitAndroid"
#define ALOGI(...) __android_log_print(ANDROID_LOG_INFO,  LOG_TAG, __VA_ARGS__)
#define ALOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

/* Forward declaration — defined in ffplay_lib.c */
extern void ffplay_set_android_window(ANativeWindow *window);

/* Retained reference so the window stays valid during the entire playback
   session. Released when the caller passes NULL or a new Surface. */
static ANativeWindow *g_retained_window = NULL;

/*
 * Java signature:
 *
 *   package com.akashskypatel.ffmpegkit;
 *   public class FFplayKitAndroid {
 *       public static native void setAndroidSurface(android.view.Surface surface);
 *   }
 *
 * Registered automatically by the JVM via the Java_* naming convention;
 * no JNI_OnLoad / RegisterNatives call is required.
 */
JNIEXPORT void JNICALL
Java_com_akashskypatel_ffmpegkit_FFplayKitAndroid_setAndroidSurface(
        JNIEnv *env, jclass clazz, jobject surface)
{
    /* Release the previously retained window, if any */
    if (g_retained_window != NULL) {
        ANativeWindow_release(g_retained_window);
        g_retained_window = NULL;
    }

    if (surface != NULL) {
        g_retained_window = ANativeWindow_fromSurface(env, surface);
        if (g_retained_window == NULL) {
            ALOGE("setAndroidSurface: ANativeWindow_fromSurface returned NULL");
            ffplay_set_android_window(NULL);
            return;
        }
        ALOGI("setAndroidSurface: acquired ANativeWindow %p (%dx%d)",
              g_retained_window,
              ANativeWindow_getWidth(g_retained_window),
              ANativeWindow_getHeight(g_retained_window));
    } else {
        ALOGI("setAndroidSurface: surface cleared");
    }

    ffplay_set_android_window(g_retained_window);
}

#endif /* __ANDROID__ */
