#include <gtest/gtest.h>
#include "ffmpegkit_wrapper.hpp"
#include <cstdio>
#include <cstdlib>
#include <thread>
#include <chrono>

#ifndef FFMPEG_KIT_TEST_DIR
#define FFMPEG_KIT_TEST_DIR "."
#endif
#define TEST_FILE FFMPEG_KIT_TEST_DIR "/dummy_video.mp4"

// Helper log callback for tests
void test_log_callback(FFmpegSessionHandle session, const char *message, void *data) {
    // Optional: verify log output if needed
    printf("Log: %s\n", message);
}

TEST(FFmpegKitTest, VersionCheck) {
    char *version = ffmpeg_kit_config_get_ffmpeg_version();
    ASSERT_NE(version, nullptr);
    EXPECT_STRNE(version, "");
    printf("FFmpeg Version: %s\n", version);
    free(version);
}

TEST(FFmpegKitTest, SplitSessionExecution) {
    FFmpegSessionHandle session = ffmpeg_kit_create_session("-hide_banner -loglevel fatal -version");
    ASSERT_NE(session, nullptr);

    FFmpegKitSessionState state = ffmpeg_kit_session_get_state(session);
    EXPECT_EQ(state, FFMPEG_KIT_SESSION_STATE_CREATED);

    ffmpeg_kit_session_execute(session);

    state = ffmpeg_kit_session_get_state(session);

    printf("Session state: %d\n", state);
    
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
    ffmpeg_kit_config_set_log_level(FFMPEG_KIT_LOG_LEVEL_QUIET);
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
        FFmpegSessionHandle s = ffmpeg_kit_create_session("-hide_banner -loglevel fatal -version");
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

    MediaInformationSessionHandle media_session = ffprobe_kit_execute("-hide_banner -loglevel fatal -show_format -i " TEST_FILE " -o media_info.txt");

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
    printf("Create Time: %ld\n", create_time);
    EXPECT_GT(create_time, 0);

    char *cmd = ffmpeg_kit_session_get_command(media_session);
    printf("Command: %s\n", cmd);
    EXPECT_NE(cmd, nullptr);
    free(cmd);
    
    // Logs
    int log_count = ffmpeg_kit_session_get_logs_count(media_session);
    printf("Log Count: %d\n", log_count);
    EXPECT_GE(log_count, 0);

    ffmpeg_kit_handle_release(media_session);
}

TEST(FFmpegKitTest, FFplaySession) {
    // Set SDL drivers to dummy for headless execution
    // This allows ffplay to initializing audio/video "devices" without a real display/speaker
#ifdef _WIN32
    _putenv("SDL_VIDEODRIVER=dummy");
    _putenv("SDL_AUDIODRIVER=dummy");
    _putenv("DISPLAY=:0");
#else
    setenv("SDL_VIDEODRIVER", "dummy", 1);
    setenv("SDL_AUDIODRIVER", "dummy", 1);
    setenv("DISPLAY", ":0", 1);
#endif
    // 2. Run ffplay
    // -autoexit: exit when done
    // -t 2: limit duration just in case
    // We remove -nodisp and -an because with dummy drivers, we WANT it to try to play
    char command[512];
    snprintf(command, sizeof(command), "-loglevel fatal -autoexit -t 2 %s", TEST_FILE);
    FFplaySessionHandle play_session = ffplay_kit_execute(command);
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


class FFplayKitInteractiveTest : public ::testing::Test {
protected:
    void SetUp() override {
#ifdef _WIN32
        _putenv("SDL_VIDEODRIVER=dummy");
        _putenv("SDL_AUDIODRIVER=dummy");
        _putenv("DISPLAY=:0");
#else
        setenv("SDL_VIDEODRIVER", "dummy", 1);
        setenv("SDL_AUDIODRIVER", "dummy", 1);
        setenv("DISPLAY", ":0", 1);
#endif
    }

    void TearDown() override {
        ffplay_kit_stop();
    }

    void WaitForSeconds(int seconds) {
        std::this_thread::sleep_for(std::chrono::seconds(seconds));
    }
};

TEST_F(FFplayKitInteractiveTest, PlayPauseResume) {
    const char* video_file = TEST_FILE;
    char command[256];
    snprintf(command, sizeof(command), "-loglevel fatal -i %s", video_file);

    FFplaySessionHandle session = ffplay_kit_execute_async(command, nullptr, nullptr);
    ASSERT_NE(session, nullptr);
    
    WaitForSeconds(2);
    EXPECT_EQ(ffplay_kit_session_is_playing(session), 1);

    ffplay_kit_session_pause(session);
    WaitForSeconds(1);
    EXPECT_EQ(ffplay_kit_session_is_paused(session), 1);

    ffplay_kit_session_resume(session);
    WaitForSeconds(1);
    EXPECT_EQ(ffplay_kit_session_is_paused(session), 0);
    EXPECT_EQ(ffplay_kit_session_is_playing(session), 1);

    ffmpeg_kit_handle_release(session);
}

TEST_F(FFplayKitInteractiveTest, Seek) {
    const char* video_file = TEST_FILE;
    char command[256];
    snprintf(command, sizeof(command), "-loglevel fatal -i %s", video_file);

    FFplaySessionHandle session = ffplay_kit_execute_async(command, nullptr, nullptr);
    ASSERT_NE(session, nullptr);
    WaitForSeconds(2);

    // Seek Absolute
    ffplay_kit_session_seek(session, 10.0);
    WaitForSeconds(1);
    double pos = ffplay_kit_session_get_position(session);
    printf("Position: %f\n", pos);
    EXPECT_GE(pos, 5.0); 

    // Seek Relative Backward
    ffplay_kit_session_seek(session, -5.0);
    WaitForSeconds(1);
    double new_pos = ffplay_kit_session_get_position(session);
    printf("New Position: %f\n", new_pos);
    EXPECT_LT(new_pos, pos);
    
    ffmpeg_kit_handle_release(session);
}

TEST_F(FFplayKitInteractiveTest, ConcurrentSessions) {
    const char* video_file = TEST_FILE;
    char command[256];
    snprintf(command, sizeof(command), "-loglevel fatal -i %s", video_file);

    FFplaySessionHandle session1 = ffplay_kit_execute_async(command, nullptr, nullptr);
    ASSERT_NE(session1, nullptr);
    WaitForSeconds(2);

    // Session 2 should stop Session 1
    FFplaySessionHandle session2 = ffplay_kit_execute_async(command, nullptr, nullptr);
    ASSERT_NE(session2, nullptr);
    WaitForSeconds(2);

    FFmpegKitSessionState state1 = ffmpeg_kit_session_get_state(session1);
    EXPECT_EQ(state1, FFMPEG_KIT_SESSION_STATE_COMPLETED);
    EXPECT_EQ(ffplay_kit_session_is_playing(session2), 1);

    ffmpeg_kit_handle_release(session1);
    ffmpeg_kit_handle_release(session2);
}

TEST_F(FFplayKitInteractiveTest, GlobalControls) {
    const char* video_file = TEST_FILE;
    char command[256];
    snprintf(command, sizeof(command), "-loglevel fatal -i %s", video_file);

    FFplaySessionHandle session = ffplay_kit_execute_async(command, nullptr, nullptr);
    ASSERT_NE(session, nullptr);
    WaitForSeconds(2);

    ffplay_kit_pause();
    WaitForSeconds(1);
    EXPECT_EQ(ffplay_kit_is_paused(), 1);

    ffplay_kit_resume();
    WaitForSeconds(1);
    EXPECT_EQ(ffplay_kit_is_paused(), 0);

    ffplay_kit_stop();
    WaitForSeconds(1);
    FFmpegKitSessionState state = ffmpeg_kit_session_get_state(session);
    EXPECT_EQ(state, FFMPEG_KIT_SESSION_STATE_COMPLETED);

    ffmpeg_kit_handle_release(session);
}

TEST(FFmpegKitTest, PackageName) {
    char *pkg = ffmpeg_kit_packages_get_package_name();
    // Default might be "ffmpeg-kit" or similar
    EXPECT_NE(pkg, nullptr);
    EXPECT_STRNE(pkg, "");
    printf("Package Name: %s\n", pkg);
    free(pkg);
}
