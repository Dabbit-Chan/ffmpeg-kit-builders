# FFmpegKit Changelog

## Version 0.8.1

- **Race Condition Fixes**: Added `std::lock_guard<std::mutex>` protection to `getLogCallback()`, `getStatisticsCallback()`, and `getCompleteCallback()` across all session types (`AbstractSession`, `FFmpegSession`, `FFprobeSession`, `FFplaySession`, `MediaInformationSession`) to eliminate data races on callback accessor reads.
- **Callback Ordering Fix**: Moved `std::atomic_fetch_add` for `sessionInTransitMessageCountMap` to occur *before* enqueuing `CallbackData` in both `logCallbackDataAdd` and `statisticsCallbackDataAdd`, ensuring the in-transit counter is always incremented before the data is visible to the consumer thread.
- **MediaInformation Drain**: Added a `waitForAsynchronousMessagesInTransmit` call after `executeFFprobe` in `getMediaInformationExecute`, guaranteeing all pending log messages are processed before the session is marked complete.
- **New Setter APIs**: Exposed per-session callback setters for FFmpeg, FFprobe, FFplay, and MediaInformation sessions in the C API:
  - `ffmpeg_kit_set_log_callback`, `ffmpeg_kit_set_statistics_callback`, `ffmpeg_kit_set_complete_callback`, `ffmpeg_kit_set_callbacks`
  - `ffprobe_kit_set_log_callback`, `ffprobe_kit_set_complete_callback`, `ffprobe_kit_set_callbacks`
  - `ffplay_kit_set_log_callback`, `ffplay_kit_set_complete_callback`, `ffplay_kit_set_callbacks`
  - `media_information_kit_set_log_callback`, `media_information_kit_set_complete_callback`, `media_information_kit_set_callbacks`
- **Log Message Lifetime**: Changed log message capture in all lambda callbacks from `const std::string&` (dangling reference risk) to `std::string` by value, ensuring message lifetime is safe across async C callback boundaries.
- **Test Hardening**: Moved `CallbackTest` fixture definition after `CallbackCapturer` to fix declaration order; promoted `CallbackCapturer` to a `shared_ptr` member in the fixture to prevent use-after-free in async tests; added a `logs_mutex` to `CallbackCapturer` to protect concurrent `logs` vector writes; added `SessionCallbackStressTest` to verify concurrent callback swapping during active execution.

## Version 0.8.0

- **Memory Leak Fixes**: Pair `strdup_cpp` allocations with `malloc` instead of `new char[]` to ensure compatibility with C-style `free()` used in the wrapper and tests, resolving significant memory leaks detected by ASAN/LSAN.
- **Robust Handle Management**: Enhanced the C wrapper with handle recycling and validity checks. Asynchronous sessions now reuse their initial handles in callbacks, preventing handle leaks and ensuring safe cleanup.
- **Session API Enhancements**: Implemented missing `setCompleteCallback`, `setLogCallback`, and `setStatisticsCallback` methods across all session types (`FFmpegSession`, `FFprobeSession`, `FFplaySession`, `MediaInformationSession`) to support manual lifecycle configuration.
- **Null Safety**: Added comprehensive `nullptr` guards to all session utility functions in the C wrapper, preventing crashes when invalid or released handles are passed.
- **Handle Validation**: Improved `get_ptr_internal` to validate handles against an active handle registry and added support for using session IDs as "temporary" handles in global callbacks.
- **Improved Test Stability**: Updated the test suite to correctly manage the lifecycles of recycled handles and relaxed state checks for environmental failures, ensuring reliable CI runs under AddressSanitizer and ThreadSanitizer.
- **Extended Test Coverage**: Added new test suites for session creation with manual callback registration (`create_session_with_callbacks`) to verify the split creation-execution flow.

## Version 0.7.0

- **Thread Safety**: Fixed a critical data race issue by resolving shadowed mutex synchronization between `AbstractSession` and its subclasses. All session operations now share a unified, protected `_stateMutex`.
- **Statistics Callback**: Ensured statistics reporting is correctly initialized across worker threads by explicitly registering the thread-local `report_callback` during `executeFFmpeg`, `executeFFprobe`, and `executeFFplay`.
- **Snapshot Accessors**: Introduced `getLogsCount()`, `getLogAt()`, `getStatisticsCount()`, and `getStatisticsAt()` to the Session API. Updated the C wrapper to use these indexed accessors for more efficient and thread-safe data retrieval.
- **Improved Synchronization**: Refactored `getLogs()` and `getStatistics()` to return snapshot-style copies of internal data, preventing race conditions during concurrent iteration and modification.
- **Robust Shutdown**: Updated `FFmpegKitConfig::disableRedirection()` to perform a full `pthread_join()` on the background redirection thread, ensuring a clean shutdown and preventing use-after-free races during process termination.
- **Diagnostic Enhancements**: Added comprehensive `try/catch` handlers and a cross-platform (Windows bitwise stack trace and Linux backtrace) crash reporting mechanism to the C wrapper.
- **Windows Portability**: Added `dbghelp` linking to handle stack trace generation on Windows systems.

## Version 0.6.0

- **Thread Safety**: Comprehensive refactoring of session management and global configurations to ensure thread-safe operations. Added mutex protection to `FFmpegSession`, `MediaInformationSession`, and global callback handlers to eliminate data races identified by ThreadSanitizer.
- **Memory Barriers**: Implemented explicit memory barriers in `AbstractSession` destructor to synchronize session lifecycle transitions across threads.
- **Singleton Initialization**: Introduced eager initialization of internal static managers in `ffmpegKitInitialize` to prevent lazy-loading race conditions during high-concurrency bursts.
- **FFplay Robustness**: Synchronized internal API access in the `ffplay` engine, ensuring safe interaction between the SDL event loop and external control commands.
- **Concurrency**: Improved handle management in the C wrapper with global synchronization, preventing use-after-free scenarios during rapid session destruction.

## Version 0.5.0

- **API Extensions**: Added new statistics getter functions to the C API (`ffmpeg_kit_statistics_get_video_frame_number`, `ffmpeg_kit_statistics_get_speed`, etc.) and session listing utilities (`ffmpeg_kit_list_sessions`, `ffprobe_kit_list_sessions`).
- **Performance**: Optimized `Log::getMessage()` to return a constant reference, reducing memory allocations and string copies during high-frequency log processing.
- **Bug Fixes**: Fixed `ffplay_get_volume` to correctly return a normalized float value (0.0 to 1.0) instead of raw SDL volume integers.
- **Test Coverage**: Expanded internal test suite with dedicated `config_test.cpp` and comprehensive validations for `MediaInformation`, global callbacks, and debug logging.

## Version 0.4.1

- **Concurrency**: Refactored `ffmpeg` and `ffplay` internal state variables from volatile to atomic types to ensure safer multi-threaded execution.
- **State Encapsulation**: Moved global display/filter contexts into the `VideoState` struct within `ffplay`, allowing for independent parallel session execution.
- **Thread Initialization**: Updated `ffmpeg_sched.c` to properly initialize Thread-Local Storage (TLS) options for spawned worker threads.
- **Documentation**: Updated `DEVELOPMENT.md` to list exactly which source files from `ffmpeg/fftools` fall under the concurrency patching workflow.

## Version 0.4.0

- **Memory Management**: Fixed a memory leak in log callbacks where message copies were not being freed. Log messages are now passed directly using internal pointers.
- **Robustness**: Modified `ffmpeg_kit_handle_release` to block destruction until the native background thread has gracefully exited. This prevents use-after-free crashes caused by asynchronous log callbacks under high load.
- **Diagnostic Coverage**: Updated integration tests to use `-loglevel debug` by default, ensuring better verification of asynchronous log handling logic.

## Version 0.3.0

- **Synchronization**: Added `wait()` and `waitFor(timeout)` methods to the `Session` interface for efficient, event-driven completion tracking.
- **Thread Safety**: Implemented mutex-protected state transitions in `AbstractSession` to ensure robust session lifecycle management.
- **FFplay Optimization**: Refactored `ffplayExecute` to use the new synchronization primitives instead of busy-wait polling for previous session cleanup.

## Version 0.2.0

- **Concurrency & Thread Safety**: Implemented automated AST-based refactoring to convert FFmpeg global state into Thread-Local Storage (TLS), enabling true multi-threaded execution within the same process.
- **Improved Development Workflow**: Renamed source snapshots (`_bak.c`/`_orig.c`) and introduced `DEVELOPMENT.md` detailing the new automated patching pipeline.
- **FFplay Stability**: Refactored `ffplay` to move engine state into `VideoState` and improved graph cleanup to prevent memory leaks during rapid session recycling.
- **Build System**: Added support for dynamic TLS and options patching directly within the CMake build sequence.
- **Architecture Documentation**: Added a comprehensive `ARCHITECTURE.md` at the project root.

## Version 0.1.4

- Added debug logging infrastructure to `FFmpegKitConfig` (`enableDebugLog`, `getDebugLog`, etc.) for troubleshooting session execution.
- Improved session log handling by ensuring all asynchronous messages are processed before session completion.
- Added `tlsSessionId` thread-local storage to better track sessions in concurrent environments.
- Added `opt_common.c.patch` to prevent `av_log_set_callback` from being overwritten during help/version commands.

## Version 0.1.3

- Transferred session handle ownership to completion callbacks in the C API, enabling manual lifecycle management.
- Updated log and statistics callbacks to include session handles for better progress tracking.
- Added detailed documentation for user data ownership and handle management in `ffmpegkit_wrapper.h`.
- Fixed potential null pointer dereference in internal handle creation logic.
- Ensured FFmpeg log callbacks are correctly initialized before execution.

## Version 0.1.2

- Added `session_is_media_information_session()` C API function to check if a session is a MediaInformation session.
- Fixed potential dangling pointer issues in `ffmpegkit_wrapper.cpp` log handling.
- Prevent potential null dereferences in log and statistics callbacks and introduce `ffmpeg_kit_free` utility function for ABI mismatch issues between C++ and C.

## Version 0.1.1

- Added `cmdutils.c.patch` to skip Win32 UTF-8 argument preparation when building as a DLL (`FFMPEG_KIT_BUILDING_DLL`), preventing host application argument corruption.

## Version 0.1.0

- Added support for listing and setting audio output devices in FFplay.
- Added C API functions to check session type (`session_is_ffmpeg_session`, `session_is_ffprobe_session`, `session_is_ffplay_session`).
- Added C API functions for audio device management.

## Version 0.0.1

- Initial release

## Version 0.0.0

- Repository created
