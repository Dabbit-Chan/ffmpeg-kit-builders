# FFmpegKit Changelog

## Version 1.2.0

- **Concurrency & Thread Safety**: Implemented automated AST-based refactoring to convert FFmpeg global state into Thread-Local Storage (TLS), enabling true multi-threaded execution within the same process.
- **Improved Development Workflow**: Renamed source snapshots (`_bak.c`/`_orig.c`) and introduced `DEVELOPMENT.md` detailing the new automated patching pipeline.
- **FFplay Stability**: Refactored `ffplay` to move engine state into `VideoState` and improved graph cleanup to prevent memory leaks during rapid session recycling.
- **Build System**: Added support for dynamic TLS and options patching directly within the CMake build sequence.
- **Architecture Documentation**: Added a comprehensive `ARCHITECTURE.md` at the project root.

## Version 1.1.4

- Added debug logging infrastructure to `FFmpegKitConfig` (`enableDebugLog`, `getDebugLog`, etc.) for troubleshooting session execution.
- Improved session log handling by ensuring all asynchronous messages are processed before session completion.
- Added `tlsSessionId` thread-local storage to better track sessions in concurrent environments.
- Added `opt_common.c.patch` to prevent `av_log_set_callback` from being overwritten during help/version commands.

## Version 1.1.3

- Transferred session handle ownership to completion callbacks in the C API, enabling manual lifecycle management.
- Updated log and statistics callbacks to include session handles for better progress tracking.
- Added detailed documentation for user data ownership and handle management in `ffmpegkit_wrapper.h`.
- Fixed potential null pointer dereference in internal handle creation logic.
- Ensured FFmpeg log callbacks are correctly initialized before execution.

## Version 1.1.2

- Added `session_is_media_information_session()` C API function to check if a session is a MediaInformation session.
- Fixed potential dangling pointer issues in `ffmpegkit_wrapper.cpp` log handling.
- Prevent potential null dereferences in log and statistics callbacks and introduce `ffmpeg_kit_free` utility function for ABI mismatch issues between C++ and C.

## Version 1.1.1

- Added `cmdutils.c.patch` to skip Win32 UTF-8 argument preparation when building as a DLL (`FFMPEG_KIT_BUILDING_DLL`), preventing host application argument corruption.

## Version 1.1.0

- Added support for listing and setting audio output devices in FFplay.
- Added C API functions to check session type (`session_is_ffmpeg_session`, `session_is_ffprobe_session`, `session_is_ffplay_session`).
- Added C API functions for audio device management.

## Version 1.0.0

- Latest release

## Version 0.0.1

- Initial release

## Version 0.0.0

- Repository created