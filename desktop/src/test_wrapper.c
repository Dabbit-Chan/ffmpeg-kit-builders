#include "ffmpegkit_wrapper.hpp"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

void log_callback(FFmpegSessionHandle session, const char *message,
                  void *data) {
  // printf("Global Log: %s", message);
}

void complete_cb(FFmpegSessionHandle session, void *user_data) {
  printf("Callback: Session completed.\n");
}

int main() {
  printf("Starting Comprehensive FFmpegKit C Wrapper Test...\n");

  // 0. Test Split Session Creation and Execution (New API)
  printf("Testing Split Session Creation and Execution...\n");
  FFmpegSessionHandle split_session = ffmpeg_kit_create_session("-version");
  if (split_session) {
    FFmpegKitSessionState state = ffmpeg_kit_session_get_state(split_session);
    printf("Split Session State (Created): %d\n",
           state); // Should be 0 (CREATED)

    ffmpeg_kit_session_execute(split_session);

    state = ffmpeg_kit_session_get_state(split_session);
    printf("Split Session State (Executed): %d\n",
           state); // Should be 2 (COMPLETED)

    ffmpeg_kit_handle_release(split_session);
  } else {
    printf("Failed to create split session.\n");
  }

  // 1. Config Test
  char *version = ffmpeg_kit_config_get_ffmpeg_version();
  printf("FFmpeg Version: %s\n", version);
  free(version);

  ffmpeg_kit_config_set_log_level(FFMPEG_KIT_LOG_LEVEL_INFO);
  ffmpeg_kit_config_enable_log_callback(log_callback, NULL);

  // Test Session History
  ffmpeg_kit_set_session_history_size(10);
  int history_size = ffmpeg_kit_get_session_history_size();
  printf("Session History Size: %d\n", history_size);

  // 2. FFprobe Test (Media Information)
  printf("Testing MediaInformation...\n");
  MediaInformationSessionHandle media_session =
      ffprobe_kit_get_media_information("dummy.mp4");

  FFmpegKitSessionState state = ffmpeg_kit_session_get_state(media_session);
  printf("Media Session State: %d\n", state);

  // Test Session Getters
  long create_time = ffmpeg_kit_session_get_create_time(media_session);
  printf("Session Create Time: %ld\n", create_time);

  char *cmd = ffmpeg_kit_session_get_command(media_session);
  if (cmd) {
    printf("Session Command: %s\n", cmd);
    free(cmd);
  }

  // Test Logs Access
  int log_count = ffmpeg_kit_session_get_logs_count(media_session);
  printf("Session Log Count: %d\n", log_count);

  // Media Information
  printf("Getting media information handle...\n");
  MediaInformationHandle media_info =
      media_information_session_get_media_information(media_session);
  printf("Media info handle: %p\n", media_info);

  if (media_info) {
    printf("Calling media_information_get_format...\n");
    char *format = media_information_get_format(media_info);
    printf("Format returned: %p\n", format);
    if (format) {
      printf("Format: %s\n", format);
      free(format);
    } else {
      printf("Format: (null)\n");
    }

    // Test new property getters
    printf("Calling media_information_get_start_time...\n");
    char *start_time = media_information_get_start_time(media_info);
    printf("Start Time returned: %p\n", start_time);
    if (start_time) {
      printf("Start Time: %s\n", start_time);
      free(start_time);
    }

    printf("Releasing media_info...\n");
    ffmpeg_kit_handle_release(media_info);
  } else {
    printf("Media info is NULL\n");
  }

  printf("Releasing media_session...\n");
  ffmpeg_kit_handle_release(media_session);

  // 3. Package Name
  char *pkg = ffmpeg_kit_packages_get_package_name();
  printf("Package Name: %s\n", pkg);
  free(pkg);

  // 4. Test Global Session Getters
  FFmpegSessionHandle *sessions = ffmpeg_kit_get_sessions();
  if (sessions) {
    int count = 0;
    while (sessions[count]) {
      FFmpegSessionHandle s = sessions[count];
      // release handle from list? The API creates new handles.
      ffmpeg_kit_handle_release(s);
      count++;
    }
    printf("Retrieved %d sessions from history.\n", count);
    free(sessions);
  }

  printf("Test Finished.\n");
  return 0;
}
