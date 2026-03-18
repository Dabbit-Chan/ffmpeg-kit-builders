#ifndef FFMPEG_TLS_H
#define FFMPEG_TLS_H

#if defined(_MSC_VER) || defined(__MINGW32__) || defined(__MINGW64__)
    #define FFMPEG_THREAD_LOCAL __declspec(thread)
#elif defined(__STDC_VERSION__) && __STDC_VERSION__ >= 201112L
    #define FFMPEG_THREAD_LOCAL _Thread_local
#else
    #define FFMPEG_THREAD_LOCAL __thread
#endif

#endif
