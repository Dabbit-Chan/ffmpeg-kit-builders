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

#include "ffprobe_lib.h"
#include "ffprobe.c"
#include "ffmpeg_kit_assert_override.h"
#include "libavutil/mem.h"
#include "libavutil/bprint.h"
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#ifdef _WIN32
  #include <windows.h>
  #include <io.h>
#else
  #include <pthread.h>
  #include <unistd.h>
#endif

// Forward declare the auto-generated TLS initializer
extern void ffprobe_tls_init_options(void);

extern int ffprobe_run_internal(int argc, char **argv, AVBPrint *output_buf);
extern void ffprobe_reset_internal_state(void);

struct FFprobeContext
{
  int ret;
  int argc;
  char **argv;
  AVBPrint output;
  char *output_filename;
};

// Convert string to argc/argv format with proper quoting
static int split_args(const char *args, char ***argv_out)
{
  if (!args || !argv_out)
    return -1;

  char *args_copy = av_strdup(args);
  if (!args_copy)
    return -1;

  // Count arguments first
  int argc = 0;
  char *p = args_copy;
  int in_quotes = 0;

  while (*p)
  {
    // Skip whitespace
    while (*p && !in_quotes && (*p == ' ' || *p == '\t' || *p == '\n'))
      p++;
    if (!*p)
      break;

    argc++;
    // Find end of argument
    if (*p == '"')
    {
      in_quotes = 1;
      p++;
      while (*p && *p != '"')
        p++;
      if (*p)
        p++;
    }
    else
    {
      while (*p && *p != ' ' && *p != '\t' && *p != '\n')
        p++;
    }
  }

  // Allocate argv array
  char **argv = av_mallocz(sizeof(char *) * (argc + 1));
  if (!argv)
  {
    av_free(args_copy);
    return -1;
  }

  // Extract arguments
  strcpy(args_copy, args);
  p = args_copy;
  int idx = 0;

  while (*p && idx < argc)
  {
    // Skip whitespace
    while (*p && (*p == ' ' || *p == '\t' || *p == '\n'))
      p++;
    if (!*p)
      break;

    char *start = p;

    if (*p == '"')
    {
      p++; // Skip opening quote
      start = p;
      while (*p && *p != '"')
        p++;
      if (*p)
        *p++ = '\0'; // Replace closing quote
    }
    else
    {
      while (*p && *p != ' ' && *p != '\t' && *p != '\n')
        p++;
      if (*p)
        *p++ = '\0';
    }

    argv[idx++] = av_strdup(start);
  }

  av_free(args_copy);
  *argv_out = argv;
  return argc;
}

// Custom writer that captures output to AVBPrint
static int write_packet(void *opaque, const uint8_t *buf, int buf_size)
{
  AVBPrint *bp = (AVBPrint *)opaque;
  av_bprint_append_data(bp, (const char *)buf, buf_size);
  return buf_size;
}

FFprobeContext *ffprobe_init(const char *args_string)
{
  if (!args_string)
    return NULL;

  FFprobeContext *ctx = av_mallocz(sizeof(FFprobeContext));
  if (!ctx)
    return NULL;

  // Initialize output buffer
  av_bprint_init(&ctx->output, 0, AV_BPRINT_SIZE_UNLIMITED);

  // Convert string to argc/argv
  ctx->argc = split_args(args_string, &ctx->argv);
  if (ctx->argc < 0)
  {
    ffprobe_free(ctx);
    return NULL;
  }

  // Initialize FFmpeg libraries
  avformat_network_init();

  // Set up custom output capture
  ctx->output_filename = av_strdup("buffer:");
  if (!ctx->output_filename)
  {
    ffprobe_free(ctx);
    return NULL;
  }

  return ctx;
}

int ffprobe_run(FFprobeContext *ctx)
{
  if (!ctx)
    return AVERROR(EINVAL);

  ffmpeg_kit_assert_triggered = 0;

  // Establish recovery point for av_assert0 failures inside ffprobe internals.
  if (setjmp(ffmpeg_kit_assert_jmp) != 0) {
    av_log(NULL, AV_LOG_ERROR,
           "[ffmpeg-kit] ffprobe_run: recovered from internal assertion failure. "
           "Session will be marked as failed.\n");
    return AVERROR_EXIT;
  }

  ffprobe_tls_init_options();

  ctx->ret = ffprobe_run_internal(ctx->argc, ctx->argv, &ctx->output);

  return ctx->ret;
}

char *ffprobe_get_output(FFprobeContext *ctx)
{
  if (!ctx || !ctx->output.str)
    return NULL;

  // Finalize the buffer and return a copy
  if (!av_bprint_is_complete(&ctx->output))
  {
    // If truncation occurred, we still want to return what we have
    // but av_bprint_finalize would be needed if we wanted to free internal buffers
    // Here we just duplicate what we have.
  }

  return av_strdup(ctx->output.str);
}

size_t ffprobe_get_output_size(FFprobeContext *ctx)
{
  if (!ctx)
    return 0;
  return ctx->output.len;
}

void ffprobe_free(FFprobeContext *ctx)
{
  if (!ctx)
    return;

  // Free argv array
  if (ctx->argv)
  {
    for (int i = 0; i < ctx->argc; i++)
    {
      av_free(ctx->argv[i]);
    }
    av_free(ctx->argv);
  }

  // Free output buffer
  av_bprint_finalize(&ctx->output, NULL);

  // Free output filename
  av_freep(&ctx->output_filename);

  // Clean up FFmpeg
  avformat_network_deinit();

  av_free(ctx);
}