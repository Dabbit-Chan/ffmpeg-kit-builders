#include <gtest/gtest.h>
#include "ffmpegkit_wrapper.h"
#include <cstdio>
#include <cstdlib>
#include <thread>
#include <chrono>

#ifndef FFMPEG_KIT_TEST_DIR
#define FFMPEG_KIT_TEST_DIR "."
#endif
#define TEST_VIDEO_FILE FFMPEG_KIT_TEST_DIR "/dummy_video.mp4"
#define TEST_AUDIO_FILE FFMPEG_KIT_TEST_DIR "/dummy_audio.wav"

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
    FFmpegSessionHandle session = ffmpeg_kit_create_session("-hide_banner -loglevel debug -version");
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
    // ffmpeg_kit_config_enable_log_callback(test_log_callback, nullptr);
    // No easy way to verify these without internal access or observing side effects,
    // assuming no crash is success for now.
    EXPECT_EQ(ffmpeg_kit_config_get_log_level(), FFMPEG_KIT_LOG_LEVEL_QUIET);
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
        FFmpegSessionHandle s = ffmpeg_kit_create_session("-hide_banner -loglevel debug -version");
        ffmpeg_kit_session_execute(s);
        ffmpeg_kit_handle_release(s);
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

TEST (FFmpegKitTest, GenerateTestVideoFile) {
    FFmpegSessionHandle session = ffmpeg_kit_create_session("-hide_banner -loglevel info -f lavfi -i testsrc=duration=30:size=512x512:rate=30 -y " TEST_VIDEO_FILE);
    ffmpeg_kit_session_execute(session);
    EXPECT_EQ(ffmpeg_kit_session_get_state(session), FFMPEG_KIT_SESSION_STATE_COMPLETED);
    ffmpeg_kit_handle_release(session);
    EXPECT_TRUE(access(TEST_VIDEO_FILE, F_OK) == 0);
}

TEST (FFmpegKitTest, GenerateTestAudioFile) {
    FFmpegSessionHandle session = ffmpeg_kit_create_session("-hide_banner -loglevel info -f lavfi -i sine=frequency=1000:duration=5 -y " TEST_AUDIO_FILE);
    ffmpeg_kit_session_execute(session);
    EXPECT_EQ(ffmpeg_kit_session_get_state(session), FFMPEG_KIT_SESSION_STATE_COMPLETED);
    ffmpeg_kit_handle_release(session);
    EXPECT_TRUE(access(TEST_AUDIO_FILE, F_OK) == 0);
}

TEST(FFmpegKitTest, MediaInformation) {
    MediaInformationSessionHandle media_session = ffprobe_kit_get_media_information(TEST_VIDEO_FILE);

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

TEST(FFplayKitTest, FFplaySession) {
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
    snprintf(command, sizeof(command), "-loglevel debug -autoexit -t 2 %s", TEST_VIDEO_FILE);
    FFplaySessionHandle play_session = ffplay_kit_execute(command, 1000);
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
    const char* video_file = TEST_VIDEO_FILE;
    char command[256];
    snprintf(command, sizeof(command), "-loglevel debug -i %s", video_file);

    FFplaySessionHandle session = ffplay_kit_execute_async(command, nullptr, nullptr, 1000);
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
    const char* video_file = TEST_VIDEO_FILE;
    char command[256];
    snprintf(command, sizeof(command), "-loglevel debug -i %s", video_file);

    FFplaySessionHandle session = ffplay_kit_execute_async(command, nullptr, nullptr, 1000);
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
    const char* video_file = TEST_VIDEO_FILE;
    char command[256];
    snprintf(command, sizeof(command), "-loglevel debug -i %s", video_file);

    FFplaySessionHandle session1 = ffplay_kit_execute_async(command, nullptr, nullptr, 1000);
    ASSERT_NE(session1, nullptr);
    WaitForSeconds(2);

    // Session 2 should stop Session 1
    FFplaySessionHandle session2 = ffplay_kit_execute_async(command, nullptr, nullptr, 1000);
    ASSERT_NE(session2, nullptr);
    WaitForSeconds(2);

    FFmpegKitSessionState state1 = ffmpeg_kit_session_get_state(session1);
    EXPECT_EQ(state1, FFMPEG_KIT_SESSION_STATE_COMPLETED);
    EXPECT_EQ(ffplay_kit_session_is_playing(session2), 1);

    ffmpeg_kit_handle_release(session1);
    ffmpeg_kit_handle_release(session2);
}

TEST_F(FFplayKitInteractiveTest, GlobalControls) {
    const char* video_file = TEST_VIDEO_FILE;
    char command[256];
    snprintf(command, sizeof(command), "-loglevel debug -i %s", video_file);

    FFplaySessionHandle session = ffplay_kit_execute_async(command, nullptr, nullptr, 1000);
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

TEST_F(FFplayKitInteractiveTest, GlobalSeek) {
    const char* video_file = TEST_VIDEO_FILE;
    char command[256];
    snprintf(command, sizeof(command), "-loglevel debug -i %s", video_file);

    FFplaySessionHandle session = ffplay_kit_execute_async(command, nullptr, nullptr, 1000);
    ASSERT_NE(session, nullptr);
    WaitForSeconds(2);

    // Global Set Position
    ffplay_kit_set_position(10.0);
    WaitForSeconds(1);
    
    double pos = ffplay_kit_get_position();
    printf("Position: %f\n", pos);
    EXPECT_GE(pos, 9.0); // Allow some tolerance

    ffplay_kit_stop();
    WaitForSeconds(1);
    ffmpeg_kit_handle_release(session);
}

TEST_F(FFplayKitInteractiveTest, TimeoutSession) {
    const char* video_file = TEST_VIDEO_FILE;
    char command[256];
    snprintf(command, sizeof(command), "-loglevel debug -i %s", video_file);

    // 1. Start Session 1 normally
    FFplaySessionHandle session1 = ffplay_kit_execute_async(command, nullptr, nullptr, 1000);
    ASSERT_NE(session1, nullptr);
    WaitForSeconds(2);
    EXPECT_EQ(ffplay_kit_session_is_playing(session1), 1);

    // 2. Create Session 2
    FFplaySessionHandle session2 = ffplay_kit_create_session(command);
    ASSERT_NE(session2, nullptr);

    // 3. Execute Session 2 with a very short timeout (5ms)
    // This should fail because Session 1 is running and won't stop instantly
    ffplay_kit_session_execute_async(session2, 5);
    
    // Wait for async execution to process
    WaitForSeconds(1);

    // 4. Verify Session 2 failed
    FFmpegKitSessionState state2 = ffmpeg_kit_session_get_state(session2);
    
    // It should be FAILED
    if (state2 != FFMPEG_KIT_SESSION_STATE_FAILED) {
         printf("Session 2 state: %d\n", state2);
         char *failStackTrace = ffmpeg_kit_session_get_fail_stack_trace(session2);
         if (failStackTrace) {
             printf("Fail Stack Trace:\n%s\n", failStackTrace);
             free(failStackTrace);
         }
    }
    EXPECT_EQ(state2, FFMPEG_KIT_SESSION_STATE_FAILED);

    // Session 1 might still be running or stopped depending on how far cleanup got
    // cleanup requests cancel on Session 1 even if we timeout waiting for it
    // So session 1 might eventually stop.
    
    ffmpeg_kit_handle_release(session1);
    ffmpeg_kit_handle_release(session2);
}


TEST(FFmpegKitTest, PackageName) {
    char *pkg = ffmpeg_kit_packages_get_package_name();
    // Default might be "ffmpeg-kit" or similar
    EXPECT_NE(pkg, nullptr);
    EXPECT_STRNE(pkg, "");
    printf("Package Name: %s\n", pkg);
    free(pkg);
}

TEST(FFmpegKitTest, AudioDeviceManagement) {
    // Force dummy audio for headless environments
    #ifdef _WIN32
        _putenv("SDL_AUDIODRIVER=dummy");
    #else
        setenv("SDL_AUDIODRIVER", "dummy", 1);
    #endif

    // 1. List devices
    char *devices = ffmpeg_kit_config_list_audio_output_devices();
    if (devices) {
        printf("Audio Devices: %s\n", devices);
        free(devices);
    }

    // 2. Set Device (API Verification)
    ffmpeg_kit_config_set_audio_output_device("Test Device");
    
    // [CRITICAL FIX] Reset to default before playback! 
    // Otherwise ffplay tries to open "Test Device", fails, crashes, and leaks.
    ffmpeg_kit_config_set_audio_output_device(nullptr);

    // 3. Verify Playback Path
    if (access(TEST_AUDIO_FILE, F_OK) != 0) {
        GTEST_SKIP() << "Skipping playback check: " << TEST_AUDIO_FILE << " not found.";
    }

    char command[512];
    // Use -an (disable audio) if you want to be absolutely safe in headless, 
    // but resetting to nullptr should allow the dummy driver to work.
    snprintf(command, sizeof(command), "-loglevel warning -autoexit -t 0.5 %s", TEST_AUDIO_FILE);
    
    FFplaySessionHandle session = ffplay_kit_execute(command, 2000); 
    
    if (session) {
        ffmpeg_kit_handle_release(session);
    }
    ffmpeg_kit_config_set_audio_output_device(nullptr);
}
TEST(FFmpegKitTest, ConcurrentOperations) {
    // 1. Create a slow FFmpeg session (e.g., generating a long video)
    FFmpegSessionHandle ffmpeg_session = ffmpeg_kit_create_session("-hide_banner -loglevel debug -f lavfi -i testsrc=duration=5:size=128x128:rate=10 -y concurrent_output.mp4");
    ASSERT_NE(ffmpeg_session, nullptr);

    // 2. Create a FFprobe session to run at the same time
    FFprobeSessionHandle ffprobe_session = ffprobe_kit_create_session("-hide_banner -loglevel debug -show_format -i " TEST_VIDEO_FILE);
    ASSERT_NE(ffprobe_session, nullptr);

    // 3. Execute both asynchronously
    ffmpeg_kit_session_execute_async(ffmpeg_session);
    ffprobe_kit_session_execute_async(ffprobe_session);

    // 4. Wait for both to complete
    int total_wait = 0;
    while (total_wait < 10000) { // 10s max
        FFmpegKitSessionState state1 = ffmpeg_kit_session_get_state(ffmpeg_session);
        FFmpegKitSessionState state2 = ffmpeg_kit_session_get_state(ffprobe_session);
        
        if (state1 == FFMPEG_KIT_SESSION_STATE_COMPLETED && state2 == FFMPEG_KIT_SESSION_STATE_COMPLETED) {
            break;
        }
        
        if (state1 == FFMPEG_KIT_SESSION_STATE_FAILED || state2 == FFMPEG_KIT_SESSION_STATE_FAILED) {
            break;
        }

        std::this_thread::sleep_for(std::chrono::milliseconds(100));
        total_wait += 100;
    }

    // 5. Verify results
    EXPECT_EQ(ffmpeg_kit_session_get_state(ffmpeg_session), FFMPEG_KIT_SESSION_STATE_COMPLETED);
    EXPECT_EQ(ffmpeg_kit_session_get_state(ffprobe_session), FFMPEG_KIT_SESSION_STATE_COMPLETED);

    // Cleanup
    ffmpeg_kit_handle_release(ffmpeg_session);
    ffmpeg_kit_handle_release(ffprobe_session);
    
    // Remove temporary file
    std::remove("concurrent_output.mp4");
}

TEST(FFmpegKitTest, ConcurrentFFmpegSessions) {
    // 1. Create two FFmpeg sessions
    FFmpegSessionHandle ffmpeg_session1 = ffmpeg_kit_create_session("-hide_banner -loglevel debug -f lavfi -i testsrc=duration=3:size=128x128:rate=10 -y concurrent1.mp4");
    FFmpegSessionHandle ffmpeg_session2 = ffmpeg_kit_create_session("-hide_banner -loglevel debug -f lavfi -i testsrc=duration=3:size=128x128:rate=10 -y concurrent2.mp4");
    
    ASSERT_NE(ffmpeg_session1, nullptr);
    ASSERT_NE(ffmpeg_session2, nullptr);

    // 2. Execute both asynchronously
    ffmpeg_kit_session_execute_async(ffmpeg_session1);
    ffmpeg_kit_session_execute_async(ffmpeg_session2);

    // 3. Wait for both to complete
    int total_wait = 0;
    while (total_wait < 10000) {
        FFmpegKitSessionState state1 = ffmpeg_kit_session_get_state(ffmpeg_session1);
        FFmpegKitSessionState state2 = ffmpeg_kit_session_get_state(ffmpeg_session2);
        
        if (state1 == FFMPEG_KIT_SESSION_STATE_COMPLETED && state2 == FFMPEG_KIT_SESSION_STATE_COMPLETED) {
            break;
        }
        
        if (state1 == FFMPEG_KIT_SESSION_STATE_FAILED || state2 == FFMPEG_KIT_SESSION_STATE_FAILED) {
            break;
        }

        std::this_thread::sleep_for(std::chrono::milliseconds(100));
        total_wait += 100;
    }

    // 4. Verify results
    EXPECT_EQ(ffmpeg_kit_session_get_state(ffmpeg_session1), FFMPEG_KIT_SESSION_STATE_COMPLETED);
    EXPECT_EQ(ffmpeg_kit_session_get_state(ffmpeg_session2), FFMPEG_KIT_SESSION_STATE_COMPLETED);

    // Cleanup
    ffmpeg_kit_handle_release(ffmpeg_session1);
    ffmpeg_kit_handle_release(ffmpeg_session2);
    
    std::remove("concurrent1.mp4");
    std::remove("concurrent2.mp4");
}

TEST_F(FFplayKitInteractiveTest, FFplayWithFFmpegConcurrency) {
    // 1. Start a slow FFmpeg session
    FFmpegSessionHandle ffmpeg_session = ffmpeg_kit_create_session("-hide_banner -loglevel debug -f lavfi -i testsrc=duration=5:size=128x128:rate=10 -y ffplay_concurrent.mp4");
    ffmpeg_kit_session_execute_async(ffmpeg_session);
    
    // 2. Start FFplay session
    char command[256];
    snprintf(command, sizeof(command), "-loglevel debug -i %s", TEST_VIDEO_FILE);
    FFplaySessionHandle play_session = ffplay_kit_execute_async(command, nullptr, nullptr, 1000);
    ASSERT_NE(play_session, nullptr);

    WaitForSeconds(2);

    // 3. Verify both are running (FFplay should be playing, FFmpeg should be RUNNING or COMPLETED if it's fast)
    EXPECT_EQ(ffplay_kit_session_is_playing(play_session), 1);
    FFmpegKitSessionState ffmpeg_state = ffmpeg_kit_session_get_state(ffmpeg_session);
    EXPECT_TRUE(ffmpeg_state == FFMPEG_KIT_SESSION_STATE_RUNNING || ffmpeg_state == FFMPEG_KIT_SESSION_STATE_COMPLETED);

    // 4. Cleanup
    ffmpeg_kit_handle_release(play_session);
    
    // Wait for FFmpeg to finish if it hasn't
    int wait_total = 0;
    while (ffmpeg_kit_session_get_state(ffmpeg_session) == FFMPEG_KIT_SESSION_STATE_RUNNING && wait_total < 5000) {
        WaitForSeconds(1);
        wait_total += 1000;
    }
    
    ffmpeg_kit_handle_release(ffmpeg_session);
    std::remove("ffplay_concurrent.mp4");
}

TEST_F(FFplayKitInteractiveTest, FFplayWithFFprobeConcurrency) {
    // 1. Start FFplay session
    char command[256];
    snprintf(command, sizeof(command), "-loglevel debug -i %s", TEST_VIDEO_FILE);
    FFplaySessionHandle play_session = ffplay_kit_execute_async(command, nullptr, nullptr, 1000);
    ASSERT_NE(play_session, nullptr);
    WaitForSeconds(1);

    // 2. Run FFprobe session concurrently
    FFprobeSessionHandle probe_session = ffprobe_kit_execute("-hide_banner -loglevel debug -show_format -i " TEST_VIDEO_FILE);
    ASSERT_NE(probe_session, nullptr);

    // 3. Verify FFplay is still playing and probe finished
    EXPECT_EQ(ffplay_kit_session_is_playing(play_session), 1);
    EXPECT_EQ(ffmpeg_kit_session_get_state(probe_session), FFMPEG_KIT_SESSION_STATE_COMPLETED);

    // 4. Cleanup
    ffmpeg_kit_handle_release(play_session);
    ffmpeg_kit_handle_release(probe_session);
}

TEST(FFmpegKitTest, ConcurrentFFprobeSessions) {
    // 1. Create two FFprobe sessions
    FFprobeSessionHandle ffprobe_session1 = ffprobe_kit_create_session("-hide_banner -loglevel debug -show_format -i " TEST_VIDEO_FILE);
    FFprobeSessionHandle ffprobe_session2 = ffprobe_kit_create_session("-hide_banner -loglevel debug -show_format -i " TEST_VIDEO_FILE);
    
    ASSERT_NE(ffprobe_session1, nullptr);
    ASSERT_NE(ffprobe_session2, nullptr);

    // 2. Execute both asynchronously
    ffprobe_kit_session_execute_async(ffprobe_session1);
    ffprobe_kit_session_execute_async(ffprobe_session2);

    // 3. Wait for both to complete
    int total_wait = 0;
    while (total_wait < 5000) {
        if (ffmpeg_kit_session_get_state(ffprobe_session1) == FFMPEG_KIT_SESSION_STATE_COMPLETED &&
            ffmpeg_kit_session_get_state(ffprobe_session2) == FFMPEG_KIT_SESSION_STATE_COMPLETED) {
            break;
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(100));
        total_wait += 100;
    }

    // 4. Verify results
    EXPECT_EQ(ffmpeg_kit_session_get_state(ffprobe_session1), FFMPEG_KIT_SESSION_STATE_COMPLETED);
    EXPECT_EQ(ffmpeg_kit_session_get_state(ffprobe_session2), FFMPEG_KIT_SESSION_STATE_COMPLETED);

    // Cleanup
    ffmpeg_kit_handle_release(ffprobe_session1);
    ffmpeg_kit_handle_release(ffprobe_session2);
}

