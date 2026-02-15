# FFmpegKit Changelog

## Version 1.1.2

- Added `session_is_media_information_session()` C API function to check if a session is a MediaInformation session.

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