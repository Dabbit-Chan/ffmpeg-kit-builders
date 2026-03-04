#ifndef FFMPEG_TLS_H
#define FFMPEG_TLS_H

#if defined(_MSC_VER)
    #define FFMPEG_THREAD_LOCAL __declspec(thread)
#else
    #define FFMPEG_THREAD_LOCAL __thread
#endif

#endif
