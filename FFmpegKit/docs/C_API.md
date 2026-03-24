# FFmpegKit C API Wrapper

The C API wrapper provides a simplified interface for FFmpegKit, designed for ease of integration with C-based applications or FFIs in other languages.

## Concurrency Support

FFmpegKit supports **concurrent execution** of FFmpeg and FFprobe sessions.

- **Parallel Execution**: Multiple FFmpeg and FFprobe sessions can run simultaneously. Each session runs in its own thread with isolated state.
- **FFplay Singleton Policy**: Only one FFplay session can be active at a time. Starting a new FFplay session automatically signals the previous one to stop.
- **Asynchronous Callbacks**: Log, statistics, and completion callbacks are dispatched from a dedicated background thread.

## Opaque Handles

The API uses opaque pointers for resource management:
- `FFmpegSessionHandle`: Handle for an FFmpeg execution session.
- `FFprobeSessionHandle`: Handle for an FFprobe execution session.
- `FFplaySessionHandle`: Handle for an FFplay execution session.
- `MediaInformationSessionHandle`: Handle for a media metadata extraction session.
- `MediaInformationHandle`: Handle for extracted media metadata.
- `StreamInformationHandle`: Handle for metadata of a specific stream.
- `ChapterHandle`: Handle for metadata of a media chapter.
- `StatisticsHandle`: Handle for real-time execution statistics.

## Core Functions

### Initialization
- `ffmpeg_kit_initialize()`: Initialize FFmpegKit. Call once before any other API.
- `ffmpeg_kit_get_build_stamp()`: Returns a compile-time build stamp string (`__DATE__ __TIME__`). Useful for verifying the loaded DLL version.

### Session Execution
- `ffmpeg_kit_execute(const char *command)`: Synchronously execute an FFmpeg command.
- `ffmpeg_kit_execute_async(const char *command, FFmpegKitCompleteCallback complete_cb, void *user_data)`: Asynchronously execute an FFmpeg command.
- `ffprobe_kit_execute(const char *command)`: Synchronously execute an FFprobe command.
- `ffplay_kit_execute(const char *command, int64_t timeout)`: Start FFplay for a media file/command with an initialization timeout (milliseconds).

### Session Lifecycle & Control
- `ffmpeg_kit_create_session(const char *command)`: Create a session without executing it immediately.
- `ffmpeg_kit_session_execute(FFmpegSessionHandle session)`: Execute a previously created session.
- `ffmpeg_kit_cancel()` / `ffmpeg_kit_cancel_session(int64_t session_id)`: Cancel execution (global or by ID).
- `ffmpeg_kit_handle_release(void *handle)`: **Important!** Always release any handle obtained from the API. For active sessions, this also triggers a cancellation request.
- `ffmpeg_kit_close_session(FFmpegSessionHandle handle)`: Close and release a session handle.

### FFplay Session Controls

Per-session controls for an `FFplaySessionHandle`:
- `ffplay_kit_session_pause(FFplaySessionHandle session)`: Pause playback.
- `ffplay_kit_session_resume(FFplaySessionHandle session)`: Resume playback.
- `ffplay_kit_session_stop(FFplaySessionHandle session)`: Stop playback and signal session exit.
- `ffplay_kit_session_seek(FFplaySessionHandle session, double seconds)`: Seek to an absolute position.
- `ffplay_kit_session_set_position(FFplaySessionHandle session, double seconds)`: Set playback position.
- `ffplay_kit_session_get_position(FFplaySessionHandle session)`: Get current playback position in seconds.
- `ffplay_kit_session_get_duration(FFplaySessionHandle session)`: Get total media duration in seconds.
- `ffplay_kit_session_get_video_width(FFplaySessionHandle session)`: Get decoded video width in pixels (0 if no video stream).
- `ffplay_kit_session_get_video_height(FFplaySessionHandle session)`: Get decoded video height in pixels (0 if no video stream).
- `ffplay_kit_session_is_playing(FFplaySessionHandle session)`: Returns non-zero if currently playing.
- `ffplay_kit_session_is_paused(FFplaySessionHandle session)`: Returns non-zero if paused.
- `ffplay_kit_session_set_volume(FFplaySessionHandle session, double volume)`: Set volume (0.0 to 1.0).
- `ffplay_kit_session_get_volume(FFplaySessionHandle session)`: Get current volume (0.0 to 1.0).

### Global FFplay Controls

Convenience wrappers that operate on the currently active FFplay session:
- `ffplay_kit_pause()` / `ffplay_kit_resume()` / `ffplay_kit_stop()` / `ffplay_kit_close()`
- `ffplay_kit_seek(double seconds)` / `ffplay_kit_set_position(double seconds)`
- `ffplay_kit_get_position()` / `ffplay_kit_get_duration()`
- `ffplay_kit_is_playing()` / `ffplay_kit_is_paused()`
- `ffplay_kit_set_volume(double volume)` / `ffplay_kit_get_volume()`
- `ffplay_kit_get_current_session()`: Returns the active `FFplaySessionHandle`.

### Video Stream Detection
- `ffplay_kit_has_video_stream(const char *path)`: Probes a file or URL for a video stream without decoding. Returns `1` (video present), `0` (audio-only), or `-1` (error). Thread-safe.

### Platform-Specific: Android Surface
- `ffplay_kit_set_android_surface_ptr(int64_t native_window_ptr)`: Set the `ANativeWindow*` (as `int64_t`) for video output. Must be called before session execution. No-op on non-Android.
- `ffplay_kit_clear_android_surface()`: Clear the registered `ANativeWindow`. Call when the Java `Surface` is destroyed. No-op on non-Android.

### Platform-Specific: Desktop Frame Callback (Linux / Windows)
- `ffplay_kit_register_frame_callback(FFplayKitFrameCallback callback, void *userdata)`: Register a callback fired on each decoded video frame. Delivers RGBA8888 pixels for use with a Flutter `Texture` or similar. No-op on Android.
- `ffplay_kit_unregister_frame_callback()`: Clear the registered frame callback. No-op on Android.

`FFplayKitFrameCallback` signature: `void cb(void *userdata, const uint8_t *pixels, int width, int height, int linesize)`

## Session History & Management

- `ffmpeg_kit_get_sessions()`: Returns a null-terminated array of all session handles.
- `ffmpeg_kit_get_session(int64_t session_id)`: Retrieve a specific session by ID.
- `ffmpeg_kit_get_last_session()`: Get the most recently created session.
- `ffmpeg_kit_set_session_history_size(int64_t size)`: Set how many completed sessions to keep in memory (default: 10).
- `ffmpeg_kit_clear_sessions()`: Clear all session history and cancel any active sessions.

## Callbacks

Asynchronous execution supports several callback types:
- `FFmpegKitCompleteCallback`: Called when a session finishes.
- `FFmpegKitLogCallback`: Called for every log line generated.
- `FFmpegKitStatisticsCallback`: Called when new performance statistics (bitrate, speed, frame count) are available.

## Configuration & Utils

- `ffmpeg_kit_config_set_log_level(FFmpegKitLogLevel level)`: Set global log verbosity.
- `ffmpeg_kit_config_get_log_level()`: Get current log level.
- `ffmpeg_kit_config_set_audio_output_device(const char *device_name)`: Select audio output device for FFplay.
- `ffmpeg_kit_config_list_audio_output_devices()`: Returns a `';'`-delimited string of available audio output device names. Caller must free with `ffmpeg_kit_free`.
- `ffmpeg_kit_config_enable_debug_log(void *session)`: Enable verbose internal debugging logs for a session (pass `NULL` for global).
- `ffmpeg_kit_config_register_new_ffmpeg_pipe()`: Create a named pipe for streaming data into FFmpeg. Returns the pipe path; caller must free with `ffmpeg_kit_free`.

## Handle Management

> [!TIP]
> All handles returned by the API (sessions, MediaInformation, etc.) are reference-counted pointers. Calling `ffmpeg_kit_handle_release` decrements the count and frees the resource when it reaches zero. For strings returned by the API (e.g., `ffmpeg_kit_session_get_output`), use `ffmpeg_kit_free`.
