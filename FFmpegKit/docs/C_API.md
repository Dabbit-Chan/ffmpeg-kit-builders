# FFmpegKit C API Wrapper

The C API wrapper provides a simplified interface for FFmpegKit, designed for ease of integration with C-based applications or FFIs in other languages.

## Concurrency Support

FFmpegKit for Desktop now supports **concurrent execution** of FFmpeg and FFprobe sessions.

- **Parallel Execution**: You can start multiple FFmpeg and FFprobe sessions simultaneously. Each session runs in its own thread with isolated state.
- **FFplay Singleton Policy**: For playback stability, only one FFplay session can be active at a time. Starting a new FFplay session will automatically signal the previous one to stop.
- **Asynchronous Callbacks**: Callbacks (log, statistics, completion) are dispatched from a dedicated background thread to ensure they don't block the execution engine.

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

### Session Execution
- `ffmpeg_kit_execute(const char *command)`: Synchronously execute an FFmpeg command.
- `ffmpeg_kit_execute_async(const char *command, FFmpegKitCompleteCallback complete_cb, void *user_data)`: Asynchronously execute an FFmpeg command.
- `ffprobe_kit_execute(const char *command)`: Synchronously execute an FFprobe command.
- `ffplay_kit_execute(const char *command, int timeout)`: Start FFplay for a media file/command with an initialization timeout.

### Session Lifecycle & Control
- `ffmpeg_kit_create_session(const char *command)`: Create a session without executing it immediately.
- `ffmpeg_kit_session_execute(FFmpegSessionHandle session)`: Execute a previously created session.
- `ffmpeg_kit_cancel()` / `ffmpeg_kit_cancel_session(long session_id)`: Cancel execution (global or by ID).
- `ffmpeg_kit_handle_release(void *handle)`: **Important!** Always release any handle obtained from the API. For active sessions, this also triggers a cancellation request.

### FFplay Controls
Interactive controls for playback sessions:
- `ffplay_kit_session_pause(FFplaySessionHandle session)`: Pause playback.
- `ffplay_kit_session_resume(FFplaySessionHandle session)`: Resume playback.
- `ffplay_kit_session_seek(FFplaySessionHandle session, double seconds)`: Seek to a position.
- `ffplay_kit_session_set_volume(FFplaySessionHandle session, float volume)`: Set volume (0.0 to 1.0).
- `ffplay_kit_session_get_position(FFplaySessionHandle session)`: Get current position in seconds.

## Session History & Management

You can query and manage session history:
- `ffmpeg_kit_get_sessions()`: Returns a null-terminated array of all session handles.
- `ffmpeg_kit_get_session(long session_id)`: Retrieve a specific session by ID.
- `ffmpeg_kit_get_last_session()`: Get the most recently created session.
- `ffmpeg_kit_set_session_history_size(int size)`: Set how many completed sessions to keep in memory (default is 10).
- `ffmpeg_kit_clear_sessions()`: Clear all session history and cancel any active sessions.

## Callbacks

Asynchronous execution supports several callback types:
- `FFmpegKitCompleteCallback`: Called when a session finishes.
- `FFmpegKitLogCallback`: Called for every log line generated.
- `FFmpegKitStatisticsCallback`: Called when new performance statistics (bitrate, speed, frame count) are available.

## Configuration & Utils

- `ffmpeg_kit_config_set_log_level(FFmpegKitLogLevel level)`: Set global log verbosity.
- `ffmpeg_kit_config_set_audio_output_device(const char* device_name)`: Select audio output for FFplay.
- `ffmpeg_kit_config_list_audio_output_devices()`: List available audio devices.
- `ffmpeg_kit_config_enable_debug_log()`: Enable verbose internal debugging logs for FFmpegKit itself.
- `ffmpeg_kit_config_register_new_ffmpeg_pipe()`: Create a named pipe for streaming data.

## Handle Management Tip

> [!TIP]
> All handles returned by the API (Sessions, MediaInformation, etc.) are reference-counted pointers. Calling `ffmpeg_kit_handle_release` decrements the count and frees the resource when it reaches zero. For strings returned by the API (e.g., `ffmpeg_kit_session_get_output`), use `ffmpeg_kit_free`.
