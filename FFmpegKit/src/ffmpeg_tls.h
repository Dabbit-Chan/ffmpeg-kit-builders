#ifndef FFMPEG_TLS_H
#define FFMPEG_TLS_H

#if defined(_MSC_VER) || defined(__MINGW32__) || defined(__MINGW64__)
    #define FFMPEG_WEAK_SYMBOL __declspec(selectany)
#elif defined(__GNUC__) || defined(__clang__)
    #define FFMPEG_WEAK_SYMBOL __attribute__((weak))
#else
    #define FFMPEG_WEAK_SYMBOL
#endif

#if defined(_MSC_VER) || defined(__MINGW32__) || defined(__MINGW64__)
    #define FFMPEG_THREAD_LOCAL __declspec(thread)
#elif defined(__APPLE__)
    #define FFMPEG_THREAD_LOCAL __attribute__((visibility("hidden"))) _Thread_local
#elif defined(__STDC_VERSION__) && __STDC_VERSION__ >= 201112L
    #define FFMPEG_THREAD_LOCAL _Thread_local
#else
    #define FFMPEG_THREAD_LOCAL __thread
#endif

#endif
