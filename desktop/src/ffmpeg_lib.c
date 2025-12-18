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

#include "ffmpeg_lib.h"
#include "ffmpeg.h"
#include "ffmpeg_sched.h"
#include "libavutil/mem.h"
#include "libavutil/avstring.h"
#include "libavformat/avformat.h"
#include <string.h>
#include <stdlib.h>
#ifdef _WIN32
  #include <windows.h>
  #include <io.h>
#else
  #include <pthread.h>
  #include <unistd.h>
#endif

// Global lock to protect ffmpeg.c global variables
    
// --- MUTEX ABSTRACTION START ---
#ifdef _WIN32
  static CRITICAL_SECTION ffmpeg_lock;
  static volatile long ffmpeg_lock_initialized = 0;

  static void lock_init(void) {
      // Thread-safe one-time initialization
      if (InterlockedCompareExchange(&ffmpeg_lock_initialized, 1, 0) == 0) {
          InitializeCriticalSection(&ffmpeg_lock);
          InterlockedExchange(&ffmpeg_lock_initialized, 2);
      } else {
          // Wait for initialization to complete if another thread is doing it
          while (InterlockedCompareExchange(&ffmpeg_lock_initialized, 2, 2) != 2) {
              Sleep(1);
          }
      }
  }

  static void lib_mutex_lock(void) {
      if (ffmpeg_lock_initialized != 2) lock_init();
      EnterCriticalSection(&ffmpeg_lock);
  }

  static void lib_mutex_unlock(void) {
      LeaveCriticalSection(&ffmpeg_lock);
  }
#else
  // POSIX Implementation
  static pthread_mutex_t ffmpeg_lock = PTHREAD_MUTEX_INITIALIZER;

  static void lib_mutex_lock(void) {
      pthread_mutex_lock(&ffmpeg_lock);
  }

  static void lib_mutex_unlock(void) {
      pthread_mutex_unlock(&ffmpeg_lock);
  }
#endif
// --- MUTEX ABSTRACTION END ---

// External function requirements from your modified ffmpeg.c
extern int ffmpeg_run_internal(int argc, char **argv);
extern void ffmpeg_reset_internal_state(void);

struct FFmpegContext
{
  Scheduler *sch;
  int ret;
  int argc;
  char **argv;
  int cancelled;
  int files_parsed;
};

static int split_args(const char *args, char ***argv_out)
{
  if (!args || !argv_out)
    return -1;

  char *args_copy = av_strdup(args);
  if (!args_copy)
    return -1;

  int argc = 0;
  char *p = args_copy;
  int in_quotes = 0;

  // First pass: count arguments
  while (*p)
  {
    while (*p && !in_quotes && (*p == ' ' || *p == '\t' || *p == '\n'))
      p++;
    if (!*p)
      break;
    argc++;
    if (*p == '"')
    {
      in_quotes = 1;
      p++;
      while (*p && *p != '"')
        p++;
      if (*p)
        p++;
      in_quotes = 0;
    }
    else
    {
      while (*p && *p != ' ' && *p != '\t' && *p != '\n')
        p++;
    }
  }

  char **argv = av_mallocz(sizeof(char *) * (argc + 1));
  if (!argv)
  {
    av_free(args_copy);
    return -1;
  }

  // Second pass: extract arguments
  strcpy(args_copy, args);
  p = args_copy;
  int idx = 0;

  while (*p && idx < argc)
  {
    while (*p && (*p == ' ' || *p == '\t' || *p == '\n'))
      p++;
    if (!*p)
      break;

    char *start = p;
    if (*p == '"')
    {
      p++;
      start = p;
      while (*p && *p != '"')
        p++;
      if (*p)
        *p++ = '\0';
    }
    else
    {
      while (*p && *p != ' ' && *p != '\t' && *p != '\n')
        p++;
      if (*p)
        *p++ = '\0';
    }
    argv[idx] = av_strdup(start);
    if (!argv[idx])
    {
      // Memory allocation failure; clean up
      for (int i = 0; i < idx; i++)
        av_free(argv[i]);
      av_free(argv);
      av_free(args_copy);
      return -1;
    }
    idx++;
  }

  av_free(args_copy);
  *argv_out = argv;
  return argc;
}

FFmpegContext *ffmpeg_init(const char *args_string)
{
  if (!args_string)
    return NULL;

  FFmpegContext *ctx = av_mallocz(sizeof(FFmpegContext));
  if (!ctx)
    return NULL;

  // Only parse arguments here. Logic happens in run() to be atomic.
  ctx->argc = split_args(args_string, &ctx->argv);
  if (ctx->argc < 0)
  {
    av_free(ctx);
    return NULL;
  }

  return ctx;
}

int ffmpeg_run(FFmpegContext *ctx)
{
    if (!ctx) return AVERROR(EINVAL);

    // CRITICAL: Acquire lock
    lib_mutex_lock();

    // This handles sch_alloc, parse, transcode, and cleanup internally.
    ctx->ret = ffmpeg_run_internal(ctx->argc, ctx->argv);

    // If internal run succeeded, we assume files were parsed. 
    // However, since cleanup happened inside run_internal, accessing
    // globals like nb_output_files for progress AFTER this returns is risky
    // unless you modified cleanup to NOT zero them out immediately.
    ctx->files_parsed = (ctx->ret >= 0);

    // Release lock
    lib_mutex_unlock();

    return ctx->ret;
}

float ffmpeg_get_progress(FFmpegContext *ctx)
{
  if (!ctx || !ctx->files_parsed)
    return 0.0f;

  // nb_output_dumped and nb_output_files are globals in ffmpeg.c
  // strictly speaking, we should lock to read these if they change,
  // but for a simple progress bar, a torn read is usually acceptable risk.
  if (nb_output_files > 0)
  {
    return (float)nb_output_dumped / nb_output_files;
  }
  return 0.0f;
}

void ffmpeg_cancel(FFmpegContext *ctx)
{
  if (!ctx)
    return;
  ctx->cancelled = 1;

  // Signal scheduler if it exists
  if (ctx->sch)
  {
    sch_stop(ctx->sch, NULL);
  }
}

void ffmpeg_free(FFmpegContext *ctx)
{
  if (!ctx)
    return;

  // Wrapper context cleanup
  if (ctx->argv)
  {
    for (int i = 0; i < ctx->argc; i++)
    {
      av_free(ctx->argv[i]);
    }
    av_free(ctx->argv);
  }
  av_free(ctx);
}