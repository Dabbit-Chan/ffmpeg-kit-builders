#include <gtest/gtest.h>
#include "ffmpegkit_wrapper.hpp"
#include <unistd.h>
#include <cstdio>
#include <cstdlib>
#include <string>

// Helper log callback for tests
void test_log_callback(FFmpegSessionHandle session, const char *message, void *data) {
    // Optional: verify log output if needed
}

TEST(FFmpegKitTest, VersionCheck) {
    char *version = ffmpeg_kit_config_get_ffmpeg_version();
    ASSERT_NE(version, nullptr);
    EXPECT_STRNE(version, "");
    // printf("FFmpeg Version: %s\n", version);
    free(version);
}

TEST(FFmpegKitTest, SplitSessionExecution) {
    FFmpegSessionHandle session = ffmpeg_kit_create_session("-version");
    ASSERT_NE(session, nullptr);

    FFmpegKitSessionState state = ffmpeg_kit_session_get_state(session);
    EXPECT_EQ(state, FFMPEG_KIT_SESSION_STATE_CREATED);

    ffmpeg_kit_session_execute(session);

    state = ffmpeg_kit_session_get_state(session);
    
    if (state != FFMPEG_KIT_SESSION_STATE_COMPLETED) {
        printf("Session failed with state: %d\n", state);
        // Print return code
        int returnCode = ffmpeg_kit_session_get_return_code(session);
        printf("Return Code: %d\n", returnCode);
        
        // Print logs
        char *logs = ffmpeg_kit_session_get_logs_as_string(session);
        if (logs) {
            printf("Logs:\n%s\n", logs);
            free(logs);
        }
        
        char *failStackTrace = ffmpeg_kit_session_get_fail_stack_trace(session);
        if (failStackTrace) {
            printf("Fail Stack Trace:\n%s\n", failStackTrace);
            free(failStackTrace);
        }
    }

    EXPECT_EQ(state, FFMPEG_KIT_SESSION_STATE_COMPLETED);
    
    // Cleanup
    ffmpeg_kit_handle_release(session);
}

TEST(FFmpegKitTest, ConfigurationSetters) {
    ffmpeg_kit_config_set_log_level(FFMPEG_KIT_LOG_LEVEL_INFO);
    ffmpeg_kit_config_enable_log_callback(test_log_callback, nullptr);
    // No easy way to verify these without internal access or observing side effects,
    // assuming no crash is success for now.
}

TEST(FFmpegKitTest, SessionHistory) {
    ffmpeg_kit_set_session_history_size(10);
    int history_size = ffmpeg_kit_get_session_history_size();
    EXPECT_EQ(history_size, 10);
    
    // Create a few sessions to populate history
    int initial_count = 0;
    FFmpegSessionHandle *initial_sessions = ffmpeg_kit_get_sessions();
    if (initial_sessions) {
         while(initial_sessions[initial_count]) {
             ffmpeg_kit_handle_release(initial_sessions[initial_count]);
             initial_count++;
         }
         free(initial_sessions);
    }

    for(int i=0; i<3; i++) {
        FFmpegSessionHandle s = ffmpeg_kit_create_session("-version");
        ffmpeg_kit_session_execute(s);
    }
    
    FFmpegSessionHandle *sessions = ffmpeg_kit_get_sessions();
    ASSERT_NE(sessions, nullptr);
    
    int count = 0;
    while(sessions[count]) {
        ffmpeg_kit_handle_release(sessions[count]);
        count++;
    }
    free(sessions);
    EXPECT_GT(count, initial_count); 
}

TEST(FFmpegKitTest, MediaInformation) {
    // Create a dummy video file using ffmpeg
    // ----use existing dummy_video.mp4 instead of generating ----
    // This ensures we have a valid video file for ffprobe to analyze
    // FFmpegSessionHandle create_session = ffmpeg_kit_execute("-f lavfi -i testsrc=duration=1:size=128x128:rate=1 -y dummy.mp4");
    
    // Wait for creation to finish (it is synchronous but good practice to check logic)
    // EXPECT_EQ(ffmpeg_kit_session_get_state(create_session), FFMPEG_KIT_SESSION_STATE_COMPLETED);
    // ffmpeg_kit_handle_release(create_session);

    MediaInformationSessionHandle media_session = ffprobe_kit_get_media_information("desktop/tests/dummy_video.mp4");
    ASSERT_NE(media_session, nullptr);
    
    FFmpegKitSessionState state = ffmpeg_kit_session_get_state(media_session);
    
    if (state != FFMPEG_KIT_SESSION_STATE_COMPLETED) {
         printf("Media Session failed with state: %d\n", state);
         char *logs = ffmpeg_kit_session_get_logs_as_string(media_session);
         if (logs) {
             printf("Logs:\n%s\n", logs);
             free(logs);
         }
    }

    EXPECT_EQ(state, FFMPEG_KIT_SESSION_STATE_COMPLETED); 
    
    long create_time = ffmpeg_kit_session_get_create_time(media_session);
    EXPECT_GT(create_time, 0);

    char *cmd = ffmpeg_kit_session_get_command(media_session);
    EXPECT_NE(cmd, nullptr);
    free(cmd);
    
    // Logs
    int log_count = ffmpeg_kit_session_get_logs_count(media_session);
    // EXPECT_GE(log_count, 0);

    ffmpeg_kit_handle_release(media_session);
}

TEST(FFmpegKitTest, FFplaySession) {
    // Set SDL drivers to dummy for headless execution
    // This allows ffplay to initializing audio/video "devices" without a real display/speaker
    setenv("SDL_VIDEODRIVER", "dummy", 1);
    setenv("SDL_AUDIODRIVER", "dummy", 1);
    setenv("DISPLAY", ":0", 1);
    // 2. Run ffplay
    // -autoexit: exit when done
    // -t 2: limit duration just in case
    // We remove -nodisp and -an because with dummy drivers, we WANT it to try to play
    FFplaySessionHandle play_session = ffplay_kit_execute("-autoexit -t 2 desktop/tests/dummy_video.mp4");
    ASSERT_NE(play_session, nullptr);

    FFmpegKitSessionState state = ffmpeg_kit_session_get_state(play_session);
    if (state != FFMPEG_KIT_SESSION_STATE_COMPLETED) {
        printf("FFplay Session failed with state: %d\n", state);
        char *logs = ffmpeg_kit_session_get_logs_as_string(play_session);
        if (logs) {
            printf("Logs:\n%s\n", logs);
            free(logs);
        }
    }
    EXPECT_EQ(state, FFMPEG_KIT_SESSION_STATE_COMPLETED);
    EXPECT_EQ(ffmpeg_kit_session_get_return_code(play_session), 0);

    ffmpeg_kit_handle_release(play_session);
}

TEST(FFmpegKitTest, PackageName) {
    char *pkg = ffmpeg_kit_packages_get_package_name();
    // Default might be "ffmpeg-kit" or similar
    EXPECT_NE(pkg, nullptr);
    EXPECT_STRNE(pkg, "");
    free(pkg);
}
