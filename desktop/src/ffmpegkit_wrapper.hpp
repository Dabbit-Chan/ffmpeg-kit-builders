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

#ifndef FFMPEG_KIT_WRAPPER_H
#define FFMPEG_KIT_WRAPPER_H

#ifdef __cplusplus
extern "C" {
#endif

#if defined(_WIN32)
#if defined(FFMPEG_KIT_BUILDING_DLL)
#define FFMPEG_KIT_C_EXPORT __declspec(dllexport)
#else
#define FFMPEG_KIT_C_EXPORT __declspec(dllimport)
#endif
#else
#define FFMPEG_KIT_C_EXPORT __attribute__((visibility("default")))
#endif

#include <stdint.h>

// Opaque handles
typedef void *FFmpegSessionHandle;
typedef void *FFprobeSessionHandle;
typedef void *FFplaySessionHandle;
typedef void *MediaInformationSessionHandle;
typedef void *MediaInformationHandle;
typedef void *StreamInformationHandle;
typedef void *ChapterHandle;
typedef void *StatisticsHandle;

// Callback function types
typedef void (*FFmpegKitCompleteCallback)(FFmpegSessionHandle session,
                                          void *user_data);
typedef void (*FFmpegKitLogCallback)(FFmpegSessionHandle session,
                                     const char *log, void *user_data);
typedef void (*FFmpegKitStatisticsCallback)(FFmpegSessionHandle session,
                                            int time, int64_t size,
                                            double bitrate, double speed,
                                            int videoFrameNumber,
                                            float videoFps, float videoQuality,
                                            void *user_data);
typedef void (*FFprobeKitCompleteCallback)(FFprobeSessionHandle session,
                                           void *user_data);
typedef void (*FFplayKitCompleteCallback)(FFplaySessionHandle session,
                                          void *user_data);
typedef void (*MediaInformationSessionCompleteCallback)(
    MediaInformationSessionHandle session, void *user_data);

// Enums
typedef enum {
  FFMPEG_KIT_SESSION_STATE_CREATED = 0,
  FFMPEG_KIT_SESSION_STATE_RUNNING = 1,
  FFMPEG_KIT_SESSION_STATE_COMPLETED = 2,
  FFMPEG_KIT_SESSION_STATE_FAILED = 3
} FFmpegKitSessionState;

typedef enum {
  FFMPEG_KIT_LOG_LEVEL_STDERR = -16,
  FFMPEG_KIT_LOG_LEVEL_QUIET = -8,
  FFMPEG_KIT_LOG_LEVEL_PANIC = 0,
  FFMPEG_KIT_LOG_LEVEL_FATAL = 8,
  FFMPEG_KIT_LOG_LEVEL_ERROR = 16,
  FFMPEG_KIT_LOG_LEVEL_WARNING = 24,
  FFMPEG_KIT_LOG_LEVEL_INFO = 32,
  FFMPEG_KIT_LOG_LEVEL_VERBOSE = 40,
  FFMPEG_KIT_LOG_LEVEL_DEBUG = 48,
  FFMPEG_KIT_LOG_LEVEL_TRACE = 56,
  FFMPEG_KIT_LOG_LEVEL_AV_LOG_MAX_OFFSET = 10
} FFmpegKitLogLevel;

typedef enum {
  FFMPEG_KIT_LOG_REDIRECTION_STRATEGY_ALWAYS_PRINT_LOGS = 0,
  FFMPEG_KIT_LOG_REDIRECTION_STRATEGY_PRINT_LOGS_WHEN_NO_CALLBACK_DEFINED = 1,
  FFMPEG_KIT_LOG_REDIRECTION_STRATEGY_PRINT_LOGS_WHEN_GLOBAL_CALLBACK_NOT_DEFINED =
      2,
  FFMPEG_KIT_LOG_REDIRECTION_STRATEGY_PRINT_LOGS_WHEN_SESSION_CALLBACK_NOT_DEFINED =
      3,
  FFMPEG_KIT_LOG_REDIRECTION_STRATEGY_NEVER_PRINT_LOGS = 4
} FFmpegKitLogRedirectionStrategy;

typedef enum {
  FFMPEG_KIT_SIGNAL_SIGINT,
  FFMPEG_KIT_SIGNAL_SIGQUIT,
  FFMPEG_KIT_SIGNAL_SIGPIPE,
  FFMPEG_KIT_SIGNAL_SIGTERM,
  FFMPEG_KIT_SIGNAL_SIGXCPU
} FFmpegKitSignal;

/* FFmpegKit (FFmpeg Execution) */

FFMPEG_KIT_C_EXPORT FFmpegSessionHandle ffmpeg_kit_execute(const char *command);
FFMPEG_KIT_C_EXPORT FFmpegSessionHandle ffmpeg_kit_execute_async(
    const char *command, FFmpegKitCompleteCallback complete_cb,
    void *user_data);
FFMPEG_KIT_C_EXPORT FFmpegSessionHandle ffmpeg_kit_execute_async_full(
    const char *command, FFmpegKitCompleteCallback complete_cb,
    FFmpegKitLogCallback log_cb, FFmpegKitStatisticsCallback stats_cb,
    void *user_data);
FFMPEG_KIT_C_EXPORT void ffmpeg_kit_cancel(void);
FFMPEG_KIT_C_EXPORT void ffmpeg_kit_cancel_session(long session_id);
FFMPEG_KIT_C_EXPORT FFmpegSessionHandle ffmpeg_kit_list_sessions(
    void); // Returns a list/iterator handle? Simplified: returns
           // NULL/NotImplemented for now or need list API

// Session Creation and Execution Separation
FFMPEG_KIT_C_EXPORT FFmpegSessionHandle
ffmpeg_kit_create_session(const char *command);
FFMPEG_KIT_C_EXPORT void
ffmpeg_kit_session_execute(FFmpegSessionHandle session);
FFMPEG_KIT_C_EXPORT void
ffmpeg_kit_session_execute_async(FFmpegSessionHandle session);

/* FFprobeKit (FFprobe Execution) */

FFMPEG_KIT_C_EXPORT FFprobeSessionHandle
ffprobe_kit_execute(const char *command);
FFMPEG_KIT_C_EXPORT FFprobeSessionHandle ffprobe_kit_execute_async(
    const char *command, FFprobeKitCompleteCallback complete_cb,
    void *user_data);

// FFprobe Session Creation and Execution Separation
FFMPEG_KIT_C_EXPORT FFprobeSessionHandle
ffprobe_kit_create_session(const char *command);
FFMPEG_KIT_C_EXPORT void
ffprobe_kit_session_execute(FFprobeSessionHandle session);
FFMPEG_KIT_C_EXPORT void
ffprobe_kit_session_execute_async(FFprobeSessionHandle session);
FFMPEG_KIT_C_EXPORT MediaInformationSessionHandle
ffprobe_kit_get_media_information(const char *path);
FFMPEG_KIT_C_EXPORT MediaInformationSessionHandle
ffprobe_kit_get_media_information_async(
    const char *path, MediaInformationSessionCompleteCallback complete_cb,
    void *user_data);

/* FFplayKit (FFplay Execution) */

FFMPEG_KIT_C_EXPORT FFplaySessionHandle
ffplay_kit_execute(const char *command);
FFMPEG_KIT_C_EXPORT FFplaySessionHandle ffplay_kit_execute_async(
    const char *command, FFplayKitCompleteCallback complete_cb,
    void *user_data);

// FFplay Session Creation and Execution Separation
FFMPEG_KIT_C_EXPORT FFplaySessionHandle
ffplay_kit_create_session(const char *command);
FFMPEG_KIT_C_EXPORT void
ffplay_kit_session_execute(FFplaySessionHandle session);
FFMPEG_KIT_C_EXPORT void
ffplay_kit_session_execute_async(FFplaySessionHandle session);

/* Config & Global Functions */

FFMPEG_KIT_C_EXPORT void ffmpeg_kit_config_enable_redirection(void);
FFMPEG_KIT_C_EXPORT void ffmpeg_kit_config_disable_redirection(void);
FFMPEG_KIT_C_EXPORT void
ffmpeg_kit_config_set_log_level(FFmpegKitLogLevel level);
FFMPEG_KIT_C_EXPORT FFmpegKitLogLevel ffmpeg_kit_config_get_log_level(void);
FFMPEG_KIT_C_EXPORT char *
ffmpeg_kit_config_log_level_to_string(FFmpegKitLogLevel level);
FFMPEG_KIT_C_EXPORT void ffmpeg_kit_config_set_font_directory(
    const char *path, const char *name_mappings_json); // Simplified mapping
FFMPEG_KIT_C_EXPORT int
ffmpeg_kit_config_set_environment_variable(const char *name, const char *value);
FFMPEG_KIT_C_EXPORT void
ffmpeg_kit_config_ignore_signal(FFmpegKitSignal signal);
FFMPEG_KIT_C_EXPORT char *ffmpeg_kit_config_get_ffmpeg_version(void);
FFMPEG_KIT_C_EXPORT char *ffmpeg_kit_config_get_version(void);

/* Packages */
FFMPEG_KIT_C_EXPORT char *ffmpeg_kit_packages_get_package_name(void);
FFMPEG_KIT_C_EXPORT char *ffmpeg_kit_packages_get_external_libraries(
    void); // Returns concatenated string or JSON

/* Session Management (Base) */

FFMPEG_KIT_C_EXPORT long
ffmpeg_kit_session_get_session_id(void *session_handle);
FFMPEG_KIT_C_EXPORT FFmpegKitSessionState
ffmpeg_kit_session_get_state(void *session_handle);
FFMPEG_KIT_C_EXPORT int
ffmpeg_kit_session_get_return_code(void *session_handle);
FFMPEG_KIT_C_EXPORT char *ffmpeg_kit_session_get_output(void *session_handle);
FFMPEG_KIT_C_EXPORT char *
ffmpeg_kit_session_get_logs_as_string(void *session_handle);
FFMPEG_KIT_C_EXPORT char *
ffmpeg_kit_session_get_fail_stack_trace(void *session_handle);
// Generic release for any opaque handle created by this wrapper
FFMPEG_KIT_C_EXPORT void ffmpeg_kit_handle_release(void *handle);

/* MediaInformation Session specific */

FFMPEG_KIT_C_EXPORT MediaInformationHandle
media_information_session_get_media_information(
    MediaInformationSessionHandle session);

/* MediaInformation */

FFMPEG_KIT_C_EXPORT char *
media_information_get_filename(MediaInformationHandle handle);
FFMPEG_KIT_C_EXPORT char *
media_information_get_format(MediaInformationHandle handle);
FFMPEG_KIT_C_EXPORT char *
media_information_get_long_format(MediaInformationHandle handle);
FFMPEG_KIT_C_EXPORT char *
media_information_get_duration(MediaInformationHandle handle);
FFMPEG_KIT_C_EXPORT char *
media_information_get_bitrate(MediaInformationHandle handle);
FFMPEG_KIT_C_EXPORT char *
media_information_get_size(MediaInformationHandle handle);
FFMPEG_KIT_C_EXPORT char *media_information_get_tags_json(
    MediaInformationHandle handle); // Returns JSON string
// Streams
FFMPEG_KIT_C_EXPORT int
media_information_get_streams_count(MediaInformationHandle handle);
FFMPEG_KIT_C_EXPORT StreamInformationHandle
media_information_get_stream_at(MediaInformationHandle handle, int index);
// Chapters
FFMPEG_KIT_C_EXPORT int
media_information_get_chapters_count(MediaInformationHandle handle);
FFMPEG_KIT_C_EXPORT ChapterHandle
media_information_get_chapter_at(MediaInformationHandle handle, int index);

/* StreamInformation */

FFMPEG_KIT_C_EXPORT int
stream_information_get_index(StreamInformationHandle handle);
FFMPEG_KIT_C_EXPORT char *
stream_information_get_type(StreamInformationHandle handle);
FFMPEG_KIT_C_EXPORT char *
stream_information_get_codec(StreamInformationHandle handle);
FFMPEG_KIT_C_EXPORT char *
stream_information_get_codec_long(StreamInformationHandle handle);
FFMPEG_KIT_C_EXPORT char *
stream_information_get_format(StreamInformationHandle handle);
FFMPEG_KIT_C_EXPORT int
stream_information_get_width(StreamInformationHandle handle);
FFMPEG_KIT_C_EXPORT int
stream_information_get_height(StreamInformationHandle handle);
FFMPEG_KIT_C_EXPORT char *
stream_information_get_bitrate(StreamInformationHandle handle);
FFMPEG_KIT_C_EXPORT char *
stream_information_get_sample_rate(StreamInformationHandle handle);
FFMPEG_KIT_C_EXPORT char *
stream_information_get_sample_format(StreamInformationHandle handle);
FFMPEG_KIT_C_EXPORT char *
stream_information_get_display_aspect_ratio(StreamInformationHandle handle);
FFMPEG_KIT_C_EXPORT char *
stream_information_get_average_frame_rate(StreamInformationHandle handle);
FFMPEG_KIT_C_EXPORT char *
stream_information_get_real_frame_rate(StreamInformationHandle handle);
FFMPEG_KIT_C_EXPORT char *
stream_information_get_time_base(StreamInformationHandle handle);
FFMPEG_KIT_C_EXPORT char *
stream_information_get_tags_json(StreamInformationHandle handle);

/* Chapter */
FFMPEG_KIT_C_EXPORT long chapter_get_id(ChapterHandle handle);
FFMPEG_KIT_C_EXPORT char *chapter_get_time_base(ChapterHandle handle);
FFMPEG_KIT_C_EXPORT long chapter_get_start(ChapterHandle handle);
FFMPEG_KIT_C_EXPORT char *chapter_get_start_time(ChapterHandle handle);
FFMPEG_KIT_C_EXPORT long chapter_get_end(ChapterHandle handle);
FFMPEG_KIT_C_EXPORT char *chapter_get_end_time(ChapterHandle handle);
FFMPEG_KIT_C_EXPORT char *chapter_get_tags_json(ChapterHandle handle);

/* Session History */
FFMPEG_KIT_C_EXPORT FFmpegSessionHandle *ffmpeg_kit_get_sessions(void);
FFMPEG_KIT_C_EXPORT FFmpegSessionHandle *ffmpeg_kit_get_ffmpeg_sessions(void);
FFMPEG_KIT_C_EXPORT FFmpegSessionHandle *ffmpeg_kit_get_ffmpeg_sessions(void);
FFMPEG_KIT_C_EXPORT FFprobeSessionHandle *ffmpeg_kit_get_ffprobe_sessions(void);
FFMPEG_KIT_C_EXPORT FFplaySessionHandle *ffmpeg_kit_get_ffplay_sessions(void);
FFMPEG_KIT_C_EXPORT MediaInformationSessionHandle *
ffmpeg_kit_get_media_information_sessions(void);
FFMPEG_KIT_C_EXPORT FFmpegSessionHandle ffmpeg_kit_get_session(long session_id);
FFMPEG_KIT_C_EXPORT FFmpegSessionHandle ffmpeg_kit_get_last_session(void);
FFMPEG_KIT_C_EXPORT FFmpegSessionHandle
ffmpeg_kit_get_last_completed_session(void);
FFMPEG_KIT_C_EXPORT int ffmpeg_kit_get_session_history_size(void);
FFMPEG_KIT_C_EXPORT void ffmpeg_kit_set_session_history_size(int size);
FFMPEG_KIT_C_EXPORT void ffmpeg_kit_clear_sessions(void);

/* Global Callbacks */
FFMPEG_KIT_C_EXPORT void
ffmpeg_kit_config_enable_log_callback(FFmpegKitLogCallback log_cb,
                                      void *user_data);
FFMPEG_KIT_C_EXPORT void ffmpeg_kit_config_enable_statistics_callback(
    FFmpegKitStatisticsCallback stats_cb, void *user_data);
FFMPEG_KIT_C_EXPORT void
ffmpeg_kit_config_enable_ffmpeg_session_complete_callback(
    FFmpegKitCompleteCallback complete_cb, void *user_data);
FFMPEG_KIT_C_EXPORT void
ffmpeg_kit_config_enable_ffprobe_session_complete_callback(
    FFprobeKitCompleteCallback complete_cb, void *user_data);
FFMPEG_KIT_C_EXPORT void
ffmpeg_kit_config_enable_ffplay_session_complete_callback(
    FFplayKitCompleteCallback complete_cb, void *user_data);
FFMPEG_KIT_C_EXPORT void
ffmpeg_kit_config_enable_media_information_session_complete_callback(
    MediaInformationSessionCompleteCallback complete_cb, void *user_data);

/* Utils */
FFMPEG_KIT_C_EXPORT char *ffmpeg_kit_config_register_new_ffmpeg_pipe(void);
FFMPEG_KIT_C_EXPORT void
ffmpeg_kit_config_close_ffmpeg_pipe(const char *pipe_path);
FFMPEG_KIT_C_EXPORT void
ffmpeg_kit_config_set_font_directory_list(const char **font_directory_list,
                                          int list_size,
                                          const char *name_mappings_json);
FFMPEG_KIT_C_EXPORT int ffmpeg_kit_config_is_lts_build(void);
FFMPEG_KIT_C_EXPORT char *ffmpeg_kit_config_get_build_date(void);
FFMPEG_KIT_C_EXPORT char *
ffmpeg_kit_config_session_state_to_string(FFmpegKitSessionState state);
FFMPEG_KIT_C_EXPORT char **
ffmpeg_kit_config_parse_arguments(const char *command, int *arg_count);
FFMPEG_KIT_C_EXPORT char *
ffmpeg_kit_config_arguments_to_string(char **arguments, int arg_count);
FFMPEG_KIT_C_EXPORT int ffmpeg_kit_config_messages_in_transmit(long session_id);

/* Session Management Extended */
FFMPEG_KIT_C_EXPORT long
ffmpeg_kit_session_get_create_time(void *session_handle);
FFMPEG_KIT_C_EXPORT long
ffmpeg_kit_session_get_start_time(void *session_handle);
FFMPEG_KIT_C_EXPORT long ffmpeg_kit_session_get_end_time(void *session_handle);
FFMPEG_KIT_C_EXPORT long ffmpeg_kit_session_get_duration(void *session_handle);
FFMPEG_KIT_C_EXPORT char *ffmpeg_kit_session_get_command(void *session_handle);
// List accessors for Logs
FFMPEG_KIT_C_EXPORT int ffmpeg_kit_session_get_logs_count(void *session_handle);
FFMPEG_KIT_C_EXPORT char *
ffmpeg_kit_session_get_log_at(void *session_handle,
                              int index); // Returns log message
FFMPEG_KIT_C_EXPORT int
ffmpeg_kit_session_get_log_level_at(void *session_handle, int index);
// List accessors for Statistics
FFMPEG_KIT_C_EXPORT int
ffmpeg_kit_session_get_statistics_count(void *session_handle);
FFMPEG_KIT_C_EXPORT StatisticsHandle
ffmpeg_kit_session_get_statistics_at(void *session_handle, int index);

/* Entity Properties Extended */
// MediaInformation
FFMPEG_KIT_C_EXPORT char *
media_information_get_start_time(MediaInformationHandle handle);
FFMPEG_KIT_C_EXPORT char *
media_information_get_string_property(MediaInformationHandle handle,
                                      const char *key);
FFMPEG_KIT_C_EXPORT long
media_information_get_number_property(MediaInformationHandle handle,
                                      const char *key);
FFMPEG_KIT_C_EXPORT char *
media_information_get_all_properties_json(MediaInformationHandle handle);

// StreamInformation
FFMPEG_KIT_C_EXPORT char *
stream_information_get_channel_layout(StreamInformationHandle handle);
FFMPEG_KIT_C_EXPORT char *
stream_information_get_sample_aspect_ratio(StreamInformationHandle handle);
FFMPEG_KIT_C_EXPORT char *
stream_information_get_codec_time_base(StreamInformationHandle handle);
FFMPEG_KIT_C_EXPORT char *
stream_information_get_string_property(StreamInformationHandle handle,
                                       const char *key);
FFMPEG_KIT_C_EXPORT long
stream_information_get_number_property(StreamInformationHandle handle,
                                       const char *key);
FFMPEG_KIT_C_EXPORT char *
stream_information_get_all_properties_json(StreamInformationHandle handle);

// Chapter
FFMPEG_KIT_C_EXPORT char *chapter_get_string_property(ChapterHandle handle,
                                                      const char *key);
FFMPEG_KIT_C_EXPORT long chapter_get_number_property(ChapterHandle handle,
                                                     const char *key);
FFMPEG_KIT_C_EXPORT char *chapter_get_all_properties_json(ChapterHandle handle);

#ifdef __cplusplus
}
#endif

#endif // FFMPEG_KIT_WRAPPER_H
