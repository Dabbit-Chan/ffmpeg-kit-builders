/*
 * Android Binder handler
 *
 * Copyright (c) 2025 Dmitrii Okunev
 *
 * This file is part of FFmpeg.
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


#if defined(__ANDROID__)

#include <dlfcn.h>
#include <pthread.h>
#include <stdint.h>
#include <stdlib.h>

#include "libavutil/log.h"
#include "binder.h"

static pthread_once_t binder_threadpool_once = PTHREAD_ONCE_INIT;

static void *dlopen_libbinder_ndk(void)
{
    /*
     * libbinder_ndk.so often does not contain the functions we need, so making
     * this dependency optional, thus using dlopen/dlsym instead of linking.
     *
     * See also: https://source.android.com/docs/core/architecture/aidl/aidl-backends
     */

    void *h = dlopen("libbinder_ndk.so", RTLD_NOW | RTLD_LOCAL);
    if (h != NULL)
        return h;

    av_log(NULL, AV_LOG_WARNING,
           "android/binder: unable to load libbinder_ndk.so: '%s'; skipping binder threadpool init (MediaCodec likely won't work)\n",
           dlerror());
    return NULL;
}

static void android_binder_threadpool_init(void)
{
    typedef void (*start_thread_pool_fn)(void);

    start_thread_pool_fn start_thread_pool = NULL;

    void *h = dlopen_libbinder_ndk();
    if (h == NULL)
        return;
    start_thread_pool =
        (start_thread_pool_fn) dlsym(h, "ABinderProcess_startThreadPool");

    if (start_thread_pool == NULL) {
        av_log(NULL, AV_LOG_WARNING,
               "android/binder: ABinderProcess_startThreadPool not found; skipping threadpool init (MediaCodec likely won't work)\n");
        return;
    }

    av_log(NULL, AV_LOG_DEBUG,
           "android/binder: using the platform default binder threadpool size; skipping ABinderProcess_setThreadPoolMaxThreadCount to avoid Android 15+ aborts when the binder pool was already started by the host process\n");
    start_thread_pool();
    av_log(NULL, AV_LOG_DEBUG,
           "android/binder: ABinderProcess_startThreadPool() called\n");
}

void android_binder_threadpool_init_if_required(void)
{
#if __ANDROID_API__ >= 24
    if (android_get_device_api_level() < 35) {
        // the issue with the thread pool was introduced in Android 15 (API 35)
        av_log(NULL, AV_LOG_DEBUG,
               "android/binder: API<35, thus no need to initialize a thread pool\n");
        return;
    }
    pthread_once(&binder_threadpool_once, android_binder_threadpool_init);
#else
    // android_get_device_api_level was introduced in API 24, so we cannot use it
    // to detect the API level in API<24. For simplicity we just assume
    // libbinder_ndk.so on the system running this code would have API level < 35;
    av_log(NULL, AV_LOG_DEBUG,
           "android/binder: is built with API<24, assuming this is not Android 15+\n");
#endif
}

#endif                          /* __ANDROID__ */
