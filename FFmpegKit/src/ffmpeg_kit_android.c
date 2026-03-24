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

/* Stored by JNI_OnLoad; used by Android_JNI_SetupThread to attach worker
 * threads (e.g. the SDL OpenSL ES audio thread) to the JVM. */
static JavaVM *g_javaVM = NULL;

/* Overrides SDL2's JNI_OnLoad, which crashes by calling FindClass for
 * "org/libsdl/app/SDLActivity" (absent here). Stores the JavaVM for
 * Android_JNI_SetupThread. */
JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM *vm, void *reserved)
{
    (void)reserved;
    g_javaVM = vm;
    return JNI_VERSION_1_6;
}

/* Overrides SDL2's Android_JNI_* helpers from SDL_android.c.
 * SDL's versions dereference mJavaVM (populated only by SDL's own JNI_OnLoad,
 * which we suppress above), causing null-deref crashes on audio threads.
 * We use g_javaVM instead. */

/* Called at audio thread start — attach the thread to the JVM. */
void Android_JNI_SetupThread(void)
{
    if (g_javaVM == NULL) return;
    JNIEnv *env;
    (*g_javaVM)->AttachCurrentThread(g_javaVM, (void **)&env, NULL);
}

/* Called by SDL audio internals to get the JNIEnv for the current thread.
 * Attaches the thread first if it isn't already. */
JNIEnv *Android_JNI_GetEnv(void)
{
    if (g_javaVM == NULL) return NULL;
    JNIEnv *env = NULL;
    jint status = (*g_javaVM)->GetEnv(g_javaVM, (void **)&env, JNI_VERSION_1_6);
    if (status == JNI_EDETACHED) {
        if ((*g_javaVM)->AttachCurrentThread(g_javaVM, (void **)&env, NULL) != JNI_OK)
            return NULL;
    } else if (status != JNI_OK) {
        return NULL;
    }
    return env;
}

/* Called at audio thread exit — detach the thread from the JVM. */
void Android_JNI_DetachCurrentThread(void)
{
    if (g_javaVM == NULL) return;
    (*g_javaVM)->DetachCurrentThread(g_javaVM);
}

/* No-op: SDL's version crashes (mAudioManagerClass is NULL without SDLActivity).
 * OpenSLES manages its own thread scheduling. */
void Android_JNI_AudioSetThreadPriority(int iscapture, int device_id)
{
    (void)iscapture;
    (void)device_id;
}

/* Retained reference so the window stays valid during the entire playback
   session. Released when the caller passes NULL or a new Surface. */
static ANativeWindow *g_retained_window = NULL;

/* Java: public static native void setAndroidSurface(Surface surface); */
JNIEXPORT void JNICALL
Java_com_akashskypatel_ffmpegkit_FFplayKitAndroid_setAndroidSurface(
        JNIEnv *env, jclass clazz, jobject surface)
{
    /* Clear the global pointer BEFORE releasing so ffplay_step never sees a
       freed window. ffplay_set_android_window is mutex-protected in ffplay_lib.c
       and ffplay_step acquires a ref under that same mutex, so once the global
       is NULL no new blit can start on the old window. */
    if (g_retained_window != NULL) {
        ffplay_set_android_window(NULL);
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

/* Java: public static native long getNativeWindowPtr(Surface surface);
 * Returns ANativeWindow* as int64 for ffplay_kit_set_android_surface_ptr().
 * Caller must pair with releaseNativeWindowPtr() to release the retained ref. */
JNIEXPORT jlong JNICALL
Java_com_akashskypatel_ffmpegkit_FFplayKitAndroid_getNativeWindowPtr(
        JNIEnv *env, jclass clazz, jobject surface)
{
    if (!surface) {
        ALOGE("getNativeWindowPtr: surface is null");
        return 0;
    }
    ANativeWindow *nw = ANativeWindow_fromSurface(env, surface);
    if (!nw) {
        ALOGE("getNativeWindowPtr: ANativeWindow_fromSurface returned NULL");
        return 0;
    }
    /* fromSurface already gives us ownership (refcount=1); no extra acquire needed.
     * releaseNativeWindowPtr() releases this single reference. */
    ALOGI("getNativeWindowPtr: surface=%p => nw=%p (%dx%d)",
          (void*)surface, nw,
          ANativeWindow_getWidth(nw),
          ANativeWindow_getHeight(nw));
    return (jlong)(uintptr_t)nw;
}

/* Java: public static native void releaseNativeWindowPtr(long ptr);
 * Releases the ANativeWindow ref acquired by getNativeWindowPtr(). */
JNIEXPORT void JNICALL
Java_com_akashskypatel_ffmpegkit_FFplayKitAndroid_releaseNativeWindowPtr(
        JNIEnv *env, jclass clazz, jlong ptr)
{
    if (ptr == 0) return;
    ANativeWindow *nw = (ANativeWindow *)(uintptr_t)ptr;
    ALOGI("releaseNativeWindowPtr: nw=%p", nw);
    ANativeWindow_release(nw);
}

#endif /* __ANDROID__ */
