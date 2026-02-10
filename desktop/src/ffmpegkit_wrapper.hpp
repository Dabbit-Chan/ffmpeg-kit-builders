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

/**
 * Executes the given FFmpeg command.
 *
 * @param command the FFmpeg command to execute
 * @return the FFmpeg session handle
 */
FFMPEG_KIT_C_EXPORT FFmpegSessionHandle ffmpeg_kit_execute(const char *command);

/**
 * Executes the given FFmpeg command asynchronously.
 *
 * @param command the FFmpeg command to execute
 * @param complete_cb the callback to be called when the FFmpeg session is
 * completed
 * @param user_data the user data to be passed to the callback
 * @return the FFmpeg session handle
 */
FFMPEG_KIT_C_EXPORT FFmpegSessionHandle ffmpeg_kit_execute_async(
    const char *command, FFmpegKitCompleteCallback complete_cb,
    void *user_data);

/**
 * Executes the given FFmpeg command asynchronously.
 *
 * @param command the FFmpeg command to execute
 * @param complete_cb the callback to be called when the FFmpeg session is
 * completed
 * @param log_cb the callback to be called when a log is generated
 * @param stats_cb the callback to be called when statistics are generated
 * @param user_data the user data to be passed to the callback
 * @return the FFmpeg session handle
 */
FFMPEG_KIT_C_EXPORT FFmpegSessionHandle ffmpeg_kit_execute_async_full(
    const char *command, FFmpegKitCompleteCallback complete_cb,
    FFmpegKitLogCallback log_cb, FFmpegKitStatisticsCallback stats_cb,
    void *user_data);

/**
 * Cancels all running FFmpeg sessions.
 */
FFMPEG_KIT_C_EXPORT void ffmpeg_kit_cancel(void);

/**
 * Cancels the FFmpeg session with the given session ID.
 *
 * @param session_id the session ID of the FFmpeg session to cancel
 */
FFMPEG_KIT_C_EXPORT void ffmpeg_kit_cancel_session(long session_id);

/**
 * Returns a list of all running FFmpeg sessions.
 *
 * @return a list of all running FFmpeg sessions
 */
FFMPEG_KIT_C_EXPORT FFmpegSessionHandle ffmpeg_kit_list_sessions(
    void); // Returns a list/iterator handle? Simplified: returns
           // NULL/NotImplemented for now or need list API

// Session Creation and Execution Separation

/**
 * Creates a new FFmpeg session with the given command.
 *
 * @param command the FFmpeg command to execute
 * @return the FFmpeg session handle
 */
FFMPEG_KIT_C_EXPORT FFmpegSessionHandle
ffmpeg_kit_create_session(const char *command);

/**
 * Executes the FFmpeg session.
 *
 * @param session the FFmpeg session to execute
 */
FFMPEG_KIT_C_EXPORT void
ffmpeg_kit_session_execute(FFmpegSessionHandle session);

/**
 * Executes the FFmpeg session asynchronously.
 *
 * @param session the FFmpeg session to execute
 */
FFMPEG_KIT_C_EXPORT void
ffmpeg_kit_session_execute_async(FFmpegSessionHandle session);

/* FFprobeKit (FFprobe Execution) */

/**
 * Executes the given FFprobe command.
 *
 * @param command the FFprobe command to execute
 * @return the FFprobe session handle
 */
FFMPEG_KIT_C_EXPORT FFprobeSessionHandle
ffprobe_kit_execute(const char *command);

/**
 * Executes the given FFprobe command asynchronously.
 *
 * @param command the FFprobe command to execute
 * @param complete_cb the callback to be called when the FFprobe session is
 * completed
 * @param user_data the user data to be passed to the callback
 * @return the FFprobe session handle
 */
FFMPEG_KIT_C_EXPORT FFprobeSessionHandle ffprobe_kit_execute_async(
    const char *command, FFprobeKitCompleteCallback complete_cb,
    void *user_data);

/**
 * Cancels all running FFprobe sessions.
 */
FFMPEG_KIT_C_EXPORT void ffprobe_kit_cancel(void);

/**
 * Cancels the FFprobe session with the given session ID.
 *
 * @param session_id the session ID of the FFprobe session to cancel
 */
FFMPEG_KIT_C_EXPORT void ffprobe_kit_cancel_session(long session_id);

/**
 * Returns a list of all running FFprobe sessions.
 *
 * @return a list of all running FFprobe sessions
 */
FFMPEG_KIT_C_EXPORT FFprobeSessionHandle ffprobe_kit_list_sessions(
    void); // Returns a list/iterator handle? Simplified: returns
           // NULL/NotImplemented for now or need list API

// FFprobe Session Creation and Execution Separation

/**
 * Creates a new FFprobe session with the given command.
 *
 * @param command the FFprobe command to execute
 * @return the FFprobe session handle
 */
FFMPEG_KIT_C_EXPORT FFprobeSessionHandle
ffprobe_kit_create_session(const char *command);

/**
 * Executes the FFprobe session.
 *
 * @param session the FFprobe session to execute
 */
FFMPEG_KIT_C_EXPORT void
ffprobe_kit_session_execute(FFprobeSessionHandle session);

/**
 * Executes the FFprobe session asynchronously.
 *
 * @param session the FFprobe session to execute
 */
FFMPEG_KIT_C_EXPORT void
ffprobe_kit_session_execute_async(FFprobeSessionHandle session);

/**
 * Gets the media information for the given path.
 *
 * @param path the path of the media file
 * @return the media information session handle
 */
FFMPEG_KIT_C_EXPORT MediaInformationSessionHandle
ffprobe_kit_get_media_information(const char *path);

/**
 * Gets the media information for the given path asynchronously.
 *
 * @param path the path of the media file
 * @param complete_cb the callback to be called when the media information session is
 * completed
 * @param user_data the user data to be passed to the callback
 * @return the media information session handle
 */
FFMPEG_KIT_C_EXPORT MediaInformationSessionHandle
ffprobe_kit_get_media_information_async(
    const char *path, MediaInformationSessionCompleteCallback complete_cb,
    void *user_data);

/* FFplayKit (FFplay Execution) */

/**
 * Executes the given FFplay command.
 *
 * @param command the FFplay command to execute
 * @return the FFplay session handle
 */
FFMPEG_KIT_C_EXPORT FFplaySessionHandle
ffplay_kit_execute(const char *command);

/**
 * Executes the given FFplay command asynchronously.
 *
 * @param command the FFplay command to execute
 * @param complete_cb the callback to be called when the FFplay session is
 * completed
 * @param user_data the user data to be passed to the callback
 * @return the FFplay session handle
 */
FFMPEG_KIT_C_EXPORT FFplaySessionHandle ffplay_kit_execute_async(
    const char *command, FFplayKitCompleteCallback complete_cb,
    void *user_data);

// FFplay Session Creation and Execution Separation

/**
 * Creates a new FFplay session with the given command.
 *
 * @param command the FFplay command to execute
 * @return the FFplay session handle
 */
FFMPEG_KIT_C_EXPORT FFplaySessionHandle
ffplay_kit_create_session(const char *command);

/**
 * Executes the FFplay session.
 *
 * @param session the FFplay session to execute
 */
FFMPEG_KIT_C_EXPORT void
ffplay_kit_session_execute(FFplaySessionHandle session);

/**
 * Executes the FFplay session asynchronously.
 *
 * @param session the FFplay session to execute
 */
FFMPEG_KIT_C_EXPORT void
ffplay_kit_session_execute_async(FFplaySessionHandle session);

/**
 * Seeks to the given position in the FFplay session.
 *
 * @param session the FFplay session to seek
 * @param seconds the position to seek to
 */
FFMPEG_KIT_C_EXPORT void
ffplay_kit_session_seek(FFplaySessionHandle session, double seconds);

/**
 * Pauses the FFplay session.
 *
 * @param session the FFplay session to pause
 */
FFMPEG_KIT_C_EXPORT void
ffplay_kit_session_pause(FFplaySessionHandle session);

/**
 * Resumes the FFplay session.
 *
 * @param session the FFplay session to resume
 */
FFMPEG_KIT_C_EXPORT void
ffplay_kit_session_resume(FFplaySessionHandle session);

/**
 * Stops the FFplay session.
 *
 * @param session the FFplay session to stop
 */
FFMPEG_KIT_C_EXPORT void ffplay_kit_session_stop(FFplaySessionHandle session);

/**
 * Gets the position of the FFplay session.
 *
 * @param session the FFplay session to get the position of
 * @return the position of the FFplay session
 */
FFMPEG_KIT_C_EXPORT double
ffplay_kit_session_get_position(FFplaySessionHandle session);

/**
 * Gets the duration of the FFplay session.
 *
 * @param session the FFplay session to get the duration of
 * @return the duration of the FFplay session
 */
FFMPEG_KIT_C_EXPORT double
ffplay_kit_session_get_duration(FFplaySessionHandle session);

/**
 * Checks if the FFplay session is playing.
 *
 * @param session the FFplay session to check
 * @return 1 if the FFplay session is playing, 0 otherwise
 */
FFMPEG_KIT_C_EXPORT int
ffplay_kit_session_is_playing(FFplaySessionHandle session);

/**
 * Checks if the FFplay session is paused.
 *
 * @param session the FFplay session to check
 * @return 1 if the FFplay session is paused, 0 otherwise
 */
FFMPEG_KIT_C_EXPORT int
ffplay_kit_session_is_paused(FFplaySessionHandle session);

/**
 * Sets the volume of the FFplay session.
 *
 * @param session the FFplay session to set the volume of
 * @param volume the volume to set
 */
FFMPEG_KIT_C_EXPORT void
ffplay_kit_session_set_volume(FFplaySessionHandle session, float volume);

/* FFplayKit Global Proxies */

/**
 * Seeks to the given position in the current FFplay session.
 *
 * @param seconds the position in seconds
 */
FFMPEG_KIT_C_EXPORT void ffplay_kit_seek(double seconds);

/**
 * Pauses the current FFplay session.
 */
FFMPEG_KIT_C_EXPORT void ffplay_kit_pause(void);

/**
 * Resumes the current FFplay session.
 */
FFMPEG_KIT_C_EXPORT void ffplay_kit_resume(void);

/**
 * Stops the current FFplay session.
 */
FFMPEG_KIT_C_EXPORT void ffplay_kit_stop(void);

/**
 * Returns the position of the current FFplay session.
 *
 * @return the position in seconds
 */
FFMPEG_KIT_C_EXPORT double ffplay_kit_get_position(void);

/**
 * Returns the duration of the current FFplay session.
 *
 * @return the duration in seconds
 */
FFMPEG_KIT_C_EXPORT double ffplay_kit_get_duration(void);

/**
 * Checks if the current FFplay session is playing.
 *
 * @return 1 if playing, 0 otherwise
 */
FFMPEG_KIT_C_EXPORT int ffplay_kit_is_playing(void);

/**
 * Checks if the current FFplay session is paused.
 *
 * @return 1 if paused, 0 otherwise
 */
FFMPEG_KIT_C_EXPORT int ffplay_kit_is_paused(void);

/**
 * Sets the volume of the current FFplay session.
 *
 * @param volume the volume (0.0 to 1.0)
 */
FFMPEG_KIT_C_EXPORT void ffplay_kit_set_volume(float volume);

/* Config & Global Functions */

/**
 * Enables redirection of FFmpeg output to files.
 */
FFMPEG_KIT_C_EXPORT void ffmpeg_kit_config_enable_redirection(void);

/**
 * Disables redirection of FFmpeg output to files.
 */
FFMPEG_KIT_C_EXPORT void ffmpeg_kit_config_disable_redirection(void);

/**
 * Sets the log level for FFmpegKit.
 *
 * @param level the log level to set
 */
FFMPEG_KIT_C_EXPORT void
ffmpeg_kit_config_set_log_level(FFmpegKitLogLevel level);

/**
 * Gets the log level for FFmpegKit.
 *
 * @return the log level for FFmpegKit
 */
FFMPEG_KIT_C_EXPORT FFmpegKitLogLevel ffmpeg_kit_config_get_log_level(void);

/**
 * Converts the log level to a string.
 *
 * @param level the log level to convert
 * @return the string representation of the log level
 */
FFMPEG_KIT_C_EXPORT char *
ffmpeg_kit_config_log_level_to_string(FFmpegKitLogLevel level);

/**
 * Sets the font directory for FFmpegKit.
 *
 * @param path the path to the font directory
 * @param name_mappings_json the name mappings JSON
 */
FFMPEG_KIT_C_EXPORT void ffmpeg_kit_config_set_font_directory(
    const char *path, const char *name_mappings_json); // Simplified mapping

/**
 * Sets an environment variable for FFmpegKit.
 *
 * @param name the name of the environment variable
 * @param value the value of the environment variable
 */
FFMPEG_KIT_C_EXPORT int
ffmpeg_kit_config_set_environment_variable(const char *name, const char *value);

/**
 * Ignores the given signal for FFmpegKit.
 *
 * @param signal the signal to ignore
 */
FFMPEG_KIT_C_EXPORT void
ffmpeg_kit_config_ignore_signal(FFmpegKitSignal signal);

/**
 * Gets the FFmpeg version.
 *
 * @return the FFmpeg version
 */
FFMPEG_KIT_C_EXPORT char *ffmpeg_kit_config_get_ffmpeg_version(void);

/**
 * Gets the version of FFmpegKit.
 *
 * @return the version of FFmpegKit
 */
FFMPEG_KIT_C_EXPORT char *ffmpeg_kit_config_get_version(void);

/* Packages */

/**
 * Gets the name of the package.
 *
 * @return the name of the package
 */
FFMPEG_KIT_C_EXPORT char *ffmpeg_kit_packages_get_package_name(void);

/**
 * Gets the external libraries for the package.
 *
 * @return the external libraries for the package
 */
FFMPEG_KIT_C_EXPORT char *ffmpeg_kit_packages_get_external_libraries(
    void); // Returns concatenated string or JSON

/* Session Management (Base) */

/**
 * Gets the session ID.
 *
 * @param session_handle the session handle
 * @return the session ID
 */
FFMPEG_KIT_C_EXPORT long
ffmpeg_kit_session_get_session_id(void *session_handle);

/**
 * Gets the state of the session.
 *
 * @param session_handle the session handle
 * @return the state of the session
 */
FFMPEG_KIT_C_EXPORT FFmpegKitSessionState
ffmpeg_kit_session_get_state(void *session_handle);

/**
 * Gets the return code of the session.
 *
 * @param session_handle the session handle
 * @return the return code of the session
 */
FFMPEG_KIT_C_EXPORT int
ffmpeg_kit_session_get_return_code(void *session_handle);

/**
 * Gets the output of the session.
 *
 * @param session_handle the session handle
 * @return the output of the session
 */
FFMPEG_KIT_C_EXPORT char *ffmpeg_kit_session_get_output(void *session_handle);

/**
 * Gets the logs of the session as a string.
 *
 * @param session_handle the session handle
 * @return the logs of the session as a string
 */
FFMPEG_KIT_C_EXPORT char *
ffmpeg_kit_session_get_logs_as_string(void *session_handle);

/**
 * Gets the fail stack trace of the session.
 *
 * @param session_handle the session handle
 * @return the fail stack trace of the session
 */
FFMPEG_KIT_C_EXPORT char *
ffmpeg_kit_session_get_fail_stack_trace(void *session_handle);

// Generic release for any opaque handle created by this wrapper
/**
 * Releases the handle.
 *
 * @param handle the handle to release
 */
FFMPEG_KIT_C_EXPORT void ffmpeg_kit_handle_release(void *handle);

/* MediaInformation Session specific */

/**
 * Gets the media information from the session.
 *
 * @param session the session to get the media information from
 * @return the media information
 */
FFMPEG_KIT_C_EXPORT MediaInformationHandle
media_information_session_get_media_information(
    MediaInformationSessionHandle session);

/* MediaInformation */

/**
 * Gets the filename of the media information.
 *
 * @param handle the media information handle
 * @return the filename of the media information
 */
FFMPEG_KIT_C_EXPORT char *
media_information_get_filename(MediaInformationHandle handle);

/**
 * Gets the format of the media information.
 *
 * @param handle the media information handle
 * @return the format of the media information
 */
FFMPEG_KIT_C_EXPORT char *
media_information_get_format(MediaInformationHandle handle);

/**
 * Gets the long format of the media information.
 *
 * @param handle the media information handle
 * @return the long format of the media information
 */
FFMPEG_KIT_C_EXPORT char *
media_information_get_long_format(MediaInformationHandle handle);

/**
 * Gets the duration of the media information.
 *
 * @param handle the media information handle
 * @return the duration of the media information
 */
FFMPEG_KIT_C_EXPORT char *
media_information_get_duration(MediaInformationHandle handle);

/**
 * Gets the bitrate of the media information.
 *
 * @param handle the media information handle
 * @return the bitrate of the media information
 */
FFMPEG_KIT_C_EXPORT char *
media_information_get_bitrate(MediaInformationHandle handle);

/**
 * Gets the size of the media information.
 *
 * @param handle the media information handle
 * @return the size of the media information
 */
FFMPEG_KIT_C_EXPORT char *
media_information_get_size(MediaInformationHandle handle);

/**
 * Gets the tags of the media information as a JSON string.
 *
 * @param handle the media information handle
 * @return the tags of the media information as a JSON string
 */
FFMPEG_KIT_C_EXPORT char *media_information_get_tags_json(
    MediaInformationHandle handle); // Returns JSON string

/**
 * Gets the number of streams in the media information.
 *
 * @param handle the media information handle
 * @return the number of streams in the media information
 */
FFMPEG_KIT_C_EXPORT int
media_information_get_streams_count(MediaInformationHandle handle);

/**
 * Gets the stream at the given index.
 *
 * @param handle the media information handle
 * @param index the index of the stream
 * @return the stream at the given index
 */
FFMPEG_KIT_C_EXPORT StreamInformationHandle
media_information_get_stream_at(MediaInformationHandle handle, int index);

/**
 * Gets the number of chapters in the media information.
 *
 * @param handle the media information handle
 * @return the number of chapters in the media information
 */
FFMPEG_KIT_C_EXPORT int
media_information_get_chapters_count(MediaInformationHandle handle);

/**
 * Gets the chapter at the given index.
 *
 * @param handle the media information handle
 * @param index the index of the chapter
 * @return the chapter at the given index
 */
FFMPEG_KIT_C_EXPORT ChapterHandle
media_information_get_chapter_at(MediaInformationHandle handle, int index);

/* StreamInformation */

/**
 * Gets the index of the stream information.
 *
 * @param handle the stream information handle
 * @return the index of the stream information
 */
FFMPEG_KIT_C_EXPORT int
stream_information_get_index(StreamInformationHandle handle);

/**
 * Gets the type of the stream information.
 *
 * @param handle the stream information handle
 * @return the type of the stream information
 */
FFMPEG_KIT_C_EXPORT char *
stream_information_get_type(StreamInformationHandle handle);

/**
 * Gets the codec of the stream information.
 *
 * @param handle the stream information handle
 * @return the codec of the stream information
 */
FFMPEG_KIT_C_EXPORT char *
stream_information_get_codec(StreamInformationHandle handle);

/**
 * Gets the long codec of the stream information.
 *
 * @param handle the stream information handle
 * @return the long codec of the stream information
 */
FFMPEG_KIT_C_EXPORT char *
stream_information_get_codec_long(StreamInformationHandle handle);

/**
 * Gets the format of the stream information.
 *
 * @param handle the stream information handle
 * @return the format of the stream information
 */
FFMPEG_KIT_C_EXPORT char *
stream_information_get_format(StreamInformationHandle handle);

/**
 * Gets the width of the stream information.
 *
 * @param handle the stream information handle
 * @return the width of the stream information
 */
FFMPEG_KIT_C_EXPORT int
stream_information_get_width(StreamInformationHandle handle);

/**
 * Gets the height of the stream information.
 *
 * @param handle the stream information handle
 * @return the height of the stream information
 */
FFMPEG_KIT_C_EXPORT int
stream_information_get_height(StreamInformationHandle handle);

/**
 * Gets the bitrate of the stream information.
 *
 * @param handle the stream information handle
 * @return the bitrate of the stream information
 */
FFMPEG_KIT_C_EXPORT char *
stream_information_get_bitrate(StreamInformationHandle handle);

/**
 * Gets the sample rate of the stream information.
 *
 * @param handle the stream information handle
 * @return the sample rate of the stream information
 */
FFMPEG_KIT_C_EXPORT char *
stream_information_get_sample_rate(StreamInformationHandle handle);

/**
 * Gets the sample format of the stream information.
 *
 * @param handle the stream information handle
 * @return the sample format of the stream information
 */
FFMPEG_KIT_C_EXPORT char *
stream_information_get_sample_format(StreamInformationHandle handle);

/**
 * Gets the display aspect ratio of the stream information.
 *
 * @param handle the stream information handle
 * @return the display aspect ratio of the stream information
 */
FFMPEG_KIT_C_EXPORT char *
stream_information_get_display_aspect_ratio(StreamInformationHandle handle);

/**
 * Gets the average frame rate of the stream information.
 *
 * @param handle the stream information handle
 * @return the average frame rate of the stream information
 */
FFMPEG_KIT_C_EXPORT char *
stream_information_get_average_frame_rate(StreamInformationHandle handle);

/**
 * Gets the real frame rate of the stream information.
 *
 * @param handle the stream information handle
 * @return the real frame rate of the stream information
 */
FFMPEG_KIT_C_EXPORT char *
stream_information_get_real_frame_rate(StreamInformationHandle handle);

/**
 * Gets the time base of the stream information.
 *
 * @param handle the stream information handle
 * @return the time base of the stream information
 */
FFMPEG_KIT_C_EXPORT char *
stream_information_get_time_base(StreamInformationHandle handle);

/**
 * Gets the tags of the stream information as a JSON string.
 *
 * @param handle the stream information handle
 * @return the tags of the stream information as a JSON string
 */
FFMPEG_KIT_C_EXPORT char *
stream_information_get_tags_json(StreamInformationHandle handle);

/* Chapter */

/**
 * Gets the ID of the chapter.
 *
 * @param handle the chapter handle
 * @return the ID of the chapter
 */
FFMPEG_KIT_C_EXPORT long chapter_get_id(ChapterHandle handle);

/**
 * Gets the time base of the chapter.
 *
 * @param handle the chapter handle
 * @return the time base of the chapter
 */
FFMPEG_KIT_C_EXPORT char *chapter_get_time_base(ChapterHandle handle);

/**
 * Gets the start of the chapter.
 *
 * @param handle the chapter handle
 * @return the start of the chapter
 */
FFMPEG_KIT_C_EXPORT long chapter_get_start(ChapterHandle handle);

/**
 * Gets the start time of the chapter.
 *
 * @param handle the chapter handle
 * @return the start time of the chapter
 */
FFMPEG_KIT_C_EXPORT char *chapter_get_start_time(ChapterHandle handle);

/**
 * Gets the end of the chapter.
 *
 * @param handle the chapter handle
 * @return the end of the chapter
 */
FFMPEG_KIT_C_EXPORT long chapter_get_end(ChapterHandle handle);

/**
 * Gets the end time of the chapter.
 *
 * @param handle the chapter handle
 * @return the end time of the chapter
 */
FFMPEG_KIT_C_EXPORT char *chapter_get_end_time(ChapterHandle handle);

/**
 * Gets the tags of the chapter as a JSON string.
 *
 * @param handle the chapter handle
 * @return the tags of the chapter as a JSON string
 */
FFMPEG_KIT_C_EXPORT char *chapter_get_tags_json(ChapterHandle handle);

/* Session History */

/**
 * Gets the sessions.
 *
 * @return the sessions
 */
FFMPEG_KIT_C_EXPORT FFmpegSessionHandle *ffmpeg_kit_get_sessions(void);

/**
 * Gets the FFmpeg sessions.
 *
 * @return the FFmpeg sessions
 */
FFMPEG_KIT_C_EXPORT FFmpegSessionHandle *ffmpeg_kit_get_ffmpeg_sessions(void);

/**
 * Gets the FFmpeg sessions.
 *
 * @return the FFmpeg sessions
 */
FFMPEG_KIT_C_EXPORT FFmpegSessionHandle *ffmpeg_kit_get_ffmpeg_sessions(void);

/**
 * Gets the FFprobe sessions.
 *
 * @return the FFprobe sessions
 */
FFMPEG_KIT_C_EXPORT FFprobeSessionHandle *ffmpeg_kit_get_ffprobe_sessions(void);

/**
 * Gets the FFplay sessions.
 *
 * @return the FFplay sessions
 */
FFMPEG_KIT_C_EXPORT FFplaySessionHandle *ffmpeg_kit_get_ffplay_sessions(void);

/**
 * Gets the media information sessions.
 *
 * @return the media information sessions
 */
FFMPEG_KIT_C_EXPORT MediaInformationSessionHandle *
ffmpeg_kit_get_media_information_sessions(void);

/**
 * Gets the session.
 *
 * @param session_id the session ID
 * @return the session
 */
FFMPEG_KIT_C_EXPORT FFmpegSessionHandle ffmpeg_kit_get_session(long session_id);

/**
 * Gets the last session.
 *
 * @return the last session
 */
FFMPEG_KIT_C_EXPORT FFmpegSessionHandle ffmpeg_kit_get_last_session(void);

/**
 * Gets the last completed session.
 *
 * @return the last completed session
 */
FFMPEG_KIT_C_EXPORT FFmpegSessionHandle
ffmpeg_kit_get_last_completed_session(void);

/**
 * Gets the session history size.
 *
 * @return the session history size
 */
FFMPEG_KIT_C_EXPORT int ffmpeg_kit_get_session_history_size(void);

/**
 * Sets the session history size.
 *
 * @param size the session history size
 */
FFMPEG_KIT_C_EXPORT void ffmpeg_kit_set_session_history_size(int size);

/**
 * Clears the sessions.
 */
FFMPEG_KIT_C_EXPORT void ffmpeg_kit_clear_sessions(void);

/* Global Callbacks */

/**
 * Enables the log callback.
 *
 * @param log_cb the log callback
 * @param user_data the user data
 */
FFMPEG_KIT_C_EXPORT void
ffmpeg_kit_config_enable_log_callback(FFmpegKitLogCallback log_cb,
                                      void *user_data);

/**
 * Enables the statistics callback.
 *
 * @param stats_cb the statistics callback
 * @param user_data the user data
 */
FFMPEG_KIT_C_EXPORT void ffmpeg_kit_config_enable_statistics_callback(
    FFmpegKitStatisticsCallback stats_cb, void *user_data);

/**
 * Enables the FFmpeg session complete callback.
 *
 * @param complete_cb the FFmpeg session complete callback
 * @param user_data the user data
 */
FFMPEG_KIT_C_EXPORT void
ffmpeg_kit_config_enable_ffmpeg_session_complete_callback(
    FFmpegKitCompleteCallback complete_cb, void *user_data);

/**
 * Enables the FFprobe session complete callback.
 *
 * @param complete_cb the FFprobe session complete callback
 * @param user_data the user data
 */
FFMPEG_KIT_C_EXPORT void
ffmpeg_kit_config_enable_ffprobe_session_complete_callback(
    FFprobeKitCompleteCallback complete_cb, void *user_data);

/**
 * Enables the FFplay session complete callback.
 *
 * @param complete_cb the FFplay session complete callback
 * @param user_data the user data
 */
FFMPEG_KIT_C_EXPORT void
ffmpeg_kit_config_enable_ffplay_session_complete_callback(
    FFplayKitCompleteCallback complete_cb, void *user_data);

/**
 * Enables the media information session complete callback.
 *
 * @param complete_cb the media information session complete callback
 * @param user_data the user data
 */
FFMPEG_KIT_C_EXPORT void
ffmpeg_kit_config_enable_media_information_session_complete_callback(
    MediaInformationSessionCompleteCallback complete_cb, void *user_data);

/* Utils */

/**
 * Registers a new FFmpeg pipe.
 *
 * @return the pipe path
 */
FFMPEG_KIT_C_EXPORT char *ffmpeg_kit_config_register_new_ffmpeg_pipe(void);

/**
 * Closes the FFmpeg pipe.
 *
 * @param pipe_path the pipe path
 */
FFMPEG_KIT_C_EXPORT void
ffmpeg_kit_config_close_ffmpeg_pipe(const char *pipe_path);

/**
 * Sets the font directory list.
 *
 * @param font_directory_list the font directory list
 * @param list_size the list size
 * @param name_mappings_json the name mappings JSON
 */
FFMPEG_KIT_C_EXPORT void
ffmpeg_kit_config_set_font_directory_list(const char **font_directory_list,
                                          int list_size,
                                          const char *name_mappings_json);

/**
 * Checks if the build is LTS.
 *
 * @return true if the build is LTS, false otherwise
 */
FFMPEG_KIT_C_EXPORT int ffmpeg_kit_config_is_lts_build(void);

/**
 * Gets the build date.
 *
 * @return the build date
 */
FFMPEG_KIT_C_EXPORT char *ffmpeg_kit_config_get_build_date(void);

/**
 * Gets the session state to string.
 *
 * @param state the session state
 * @return the session state to string
 */
FFMPEG_KIT_C_EXPORT char *
ffmpeg_kit_config_session_state_to_string(FFmpegKitSessionState state);

/**
 * Parses the arguments.
 *
 * @param command the command
 * @param arg_count the argument count
 * @return the parsed arguments
 */
FFMPEG_KIT_C_EXPORT char **
ffmpeg_kit_config_parse_arguments(const char *command, int *arg_count);

/**
 * Converts the arguments to string.
 *
 * @param arguments the arguments
 * @param arg_count the argument count
 * @return the arguments to string
 */
FFMPEG_KIT_C_EXPORT char *
ffmpeg_kit_config_arguments_to_string(char **arguments, int arg_count);

/**
 * Gets the messages in transmit.
 *
 * @param session_id the session ID
 * @return the messages in transmit
 */
FFMPEG_KIT_C_EXPORT int ffmpeg_kit_config_messages_in_transmit(long session_id);

/* Session Management Extended */

/**
 * Gets the create time.
 *
 * @param session_handle the session handle
 * @return the create time
 */
FFMPEG_KIT_C_EXPORT long
ffmpeg_kit_session_get_create_time(void *session_handle);

/**
 * Gets the start time.
 *
 * @param session_handle the session handle
 * @return the start time
 */
FFMPEG_KIT_C_EXPORT long
ffmpeg_kit_session_get_start_time(void *session_handle);

/**
 * Gets the end time.
 *
 * @param session_handle the session handle
 * @return the end time
 */
FFMPEG_KIT_C_EXPORT long ffmpeg_kit_session_get_end_time(void *session_handle);

/**
 * Gets the duration.
 *
 * @param session_handle the session handle
 * @return the duration
 */
FFMPEG_KIT_C_EXPORT long ffmpeg_kit_session_get_duration(void *session_handle);

/**
 * Gets the command.
 *
 * @param session_handle the session handle
 * @return the command
 */
FFMPEG_KIT_C_EXPORT char *ffmpeg_kit_session_get_command(void *session_handle);

/**
 * Gets the logs count.
 *
 * @param session_handle the session handle
 * @return the logs count
 */
FFMPEG_KIT_C_EXPORT int ffmpeg_kit_session_get_logs_count(void *session_handle);

/**
 * Gets the log at.
 *
 * @param session_handle the session handle
 * @param index the index
 * @return the log at
 */
FFMPEG_KIT_C_EXPORT char *
ffmpeg_kit_session_get_log_at(void *session_handle,
                              int index); // Returns log message

/**
 * Gets the log level at.
 *
 * @param session_handle the session handle
 * @param index the index
 * @return the log level at
 */
FFMPEG_KIT_C_EXPORT int
ffmpeg_kit_session_get_log_level_at(void *session_handle, int index);

/**
 * Gets the statistics count.
 *
 * @param session_handle the session handle
 * @return the statistics count
 */
FFMPEG_KIT_C_EXPORT int
ffmpeg_kit_session_get_statistics_count(void *session_handle);

/**
 * Gets the statistics at.
 *
 * @param session_handle the session handle
 * @param index the index
 * @return the statistics at
 */
FFMPEG_KIT_C_EXPORT StatisticsHandle
ffmpeg_kit_session_get_statistics_at(void *session_handle, int index);

/* Entity Properties Extended */

/**
 * Gets the start time.
 *
 * @param handle the handle
 * @return the start time
 */
FFMPEG_KIT_C_EXPORT char *
media_information_get_start_time(MediaInformationHandle handle);

/**
 * Gets the string property.
 *
 * @param handle the handle
 * @param key the key
 * @return the string property
 */
FFMPEG_KIT_C_EXPORT char *
media_information_get_string_property(MediaInformationHandle handle,
                                      const char *key);

/**
 * Gets the number property.
 *
 * @param handle the handle
 * @param key the key
 * @return the number property
 */
FFMPEG_KIT_C_EXPORT long
media_information_get_number_property(MediaInformationHandle handle,
                                      const char *key);

/**
 * Gets the all properties JSON.
 *
 * @param handle the handle
 * @return the all properties JSON
 */
FFMPEG_KIT_C_EXPORT char *
media_information_get_all_properties_json(MediaInformationHandle handle);

/**
 * Gets the channel layout.
 *
 * @param handle the handle
 * @return the channel layout
 */
FFMPEG_KIT_C_EXPORT char *
stream_information_get_channel_layout(StreamInformationHandle handle);

/**
 * Gets the sample aspect ratio.
 *
 * @param handle the handle
 * @return the sample aspect ratio
 */
FFMPEG_KIT_C_EXPORT char *
stream_information_get_sample_aspect_ratio(StreamInformationHandle handle);

/**
 * Gets the codec time base.
 *
 * @param handle the handle
 * @return the codec time base
 */
FFMPEG_KIT_C_EXPORT char *
stream_information_get_codec_time_base(StreamInformationHandle handle);

/**
 * Gets the string property.
 *
 * @param handle the handle
 * @param key the key
 * @return the string property
 */
FFMPEG_KIT_C_EXPORT char *
stream_information_get_string_property(StreamInformationHandle handle,
                                       const char *key);

/**
 * Gets the number property.
 *
 * @param handle the handle
 * @param key the key
 * @return the number property
 */
FFMPEG_KIT_C_EXPORT long
stream_information_get_number_property(StreamInformationHandle handle,
                                       const char *key);

/**
 * Gets the all properties JSON.
 *
 * @param handle the handle
 * @return the all properties JSON
 */
FFMPEG_KIT_C_EXPORT char *
stream_information_get_all_properties_json(StreamInformationHandle handle);

/**
 * Gets the string property.
 *
 * @param handle the handle
 * @param key the key
 * @return the string property
 */
FFMPEG_KIT_C_EXPORT char *chapter_get_string_property(ChapterHandle handle,
                                                      const char *key);

/**
 * Gets the number property.
 *
 * @param handle the handle
 * @param key the key
 * @return the number property
 */
FFMPEG_KIT_C_EXPORT long chapter_get_number_property(ChapterHandle handle,
                                                     const char *key);

/**
 * Gets the all properties JSON.
 *
 * @param handle the handle
 * @return the all properties JSON
 */
FFMPEG_KIT_C_EXPORT char *chapter_get_all_properties_json(ChapterHandle handle);

#ifdef __cplusplus
}
#endif

#endif // FFMPEG_KIT_WRAPPER_H
