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
    printf("Version: %s\n", version);
    ASSERT_NE(version, nullptr);
    EXPECT_STRNE(version, "");
    printf("FFmpeg Version: %s\n", version);
    free(version);
}

TEST(FFmpegKitTest, SplitSessionExecution) {
    FFmpegSessionHandle session = ffmpeg_kit_create_session("-hide_banner -loglevel fatal -version");
    printf("Session: %p\n", session);
    ASSERT_NE(session, nullptr);

    FFmpegKitSessionState state = ffmpeg_kit_session_get_state(session);
    printf("State: %d\n", state);
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
    printf("State: %d\n", state);
    EXPECT_EQ(state, FFMPEG_KIT_SESSION_STATE_COMPLETED);
    
    // Cleanup
    ffmpeg_kit_handle_release(session);
}

TEST(FFmpegKitTest, DebugLog) {
    FFmpegSessionHandle session = ffmpeg_kit_create_session("-hide_banner -loglevel fatal -version");
    printf("Session: %p\n", session);
    ASSERT_NE(session, nullptr);

    FFmpegKitSessionState state = ffmpeg_kit_session_get_state(session);
    printf("State: %d\n", state);
    EXPECT_EQ(state, FFMPEG_KIT_SESSION_STATE_CREATED);

    ffmpeg_kit_config_enable_debug_log(session);
    printf("Debug log enabled: %d\n", ffmpeg_kit_config_is_debug_log_enabled(session));
    EXPECT_TRUE(ffmpeg_kit_config_is_debug_log_enabled(session));

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

    char *debugLog = ffmpeg_kit_config_get_debug_log(session);
    printf("Debug Log: %s\n", debugLog);
    EXPECT_NE(debugLog, nullptr);
    printf("Debug Log:\n%s\n", debugLog);
    free(debugLog);

    ffmpeg_kit_config_disable_debug_log(session);
    printf("Debug log enabled: %d\n", ffmpeg_kit_config_is_debug_log_enabled(session));
    EXPECT_FALSE(ffmpeg_kit_config_is_debug_log_enabled(session));

    ffmpeg_kit_config_clear_debug_log(session);
    debugLog = ffmpeg_kit_config_get_debug_log(session);
    printf("Debug Log: %s\n", debugLog);
    EXPECT_EQ(strlen(debugLog), 0);
    free(debugLog);
    printf("State: %d\n", state);
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
    printf("History size: %d\n", history_size);
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
        ffmpeg_kit_handle_release(s);
    }
    
    FFmpegSessionHandle *sessions = ffmpeg_kit_get_sessions();
    printf("Sessions: %p\n", sessions);
    ASSERT_NE(sessions, nullptr);
    
    int count = 0;
    while(sessions[count]) {
        ffmpeg_kit_handle_release(sessions[count]);
        count++;
    }
    free(sessions);
    printf("Count: %d, Initial Count: %d\n", count, initial_count);
    EXPECT_GT(count, initial_count); 
}

TEST (FFmpegKitTest, GenerateTestVideoFile) {
    FFmpegSessionHandle session = ffmpeg_kit_create_session("-hide_banner -loglevel fatal -f lavfi -i testsrc=duration=30:size=512x512:rate=30 -y " TEST_VIDEO_FILE);
    ffmpeg_kit_session_execute(session);
    printf("Session: %p\n", session);
    EXPECT_EQ(ffmpeg_kit_session_get_state(session), FFMPEG_KIT_SESSION_STATE_COMPLETED);
    ffmpeg_kit_handle_release(session);
    printf("File exists: %d\n", access(TEST_VIDEO_FILE, F_OK) == 0);
    EXPECT_TRUE(access(TEST_VIDEO_FILE, F_OK) == 0);
}

TEST (FFmpegKitTest, GenerateTestAudioFile) {
    FFmpegSessionHandle session = ffmpeg_kit_create_session("-hide_banner -loglevel fatal -f lavfi -i sine=frequency=1000:duration=5 -y " TEST_AUDIO_FILE);
    ffmpeg_kit_session_execute(session);
    printf("Session: %p\n", session);
    EXPECT_EQ(ffmpeg_kit_session_get_state(session), FFMPEG_KIT_SESSION_STATE_COMPLETED);
    ffmpeg_kit_handle_release(session);
    printf("File exists: %d\n", access(TEST_AUDIO_FILE, F_OK) == 0);
    EXPECT_TRUE(access(TEST_AUDIO_FILE, F_OK) == 0);
}

TEST(FFmpegKitTest, MediaInformation) {
    ffmpeg_kit_config_set_log_level(FFMPEG_KIT_LOG_LEVEL_DEBUG);
    MediaInformationSessionHandle media_session = ffprobe_kit_get_media_information(TEST_VIDEO_FILE);
    printf("Media Session: %p\n", media_session);
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
    printf("State: %d\n", state);
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

    MediaInformationHandle info = media_information_session_get_media_information(media_session);
    printf("Media Information: %p\n", info);
    ASSERT_NE(info, nullptr);

    char *filename = media_information_get_filename(info);
    printf("Filename: %s\n", filename);
    EXPECT_NE(filename, nullptr);
    if(filename) free(filename);

    char *duration = media_information_get_duration(info);
    printf("Duration: %s\n", duration);
    EXPECT_NE(duration, nullptr);
    if(duration) free(duration);

    char *bitrate = media_information_get_bitrate(info);
    printf("Bitrate: %s\n", bitrate);
    EXPECT_NE(bitrate, nullptr);
    if(bitrate) free(bitrate);

    char *size = media_information_get_size(info);
    printf("Size: %s\n", size);
    EXPECT_NE(size, nullptr);
    if(size) free(size);

    int streams_count = media_information_get_streams_count(info);
    printf("Streams Count: %d\n", streams_count);
    EXPECT_GE(streams_count, 1);

    if (streams_count > 0) {
        StreamInformationHandle stream = media_information_get_stream_at(info, 0);
        printf("Stream: %p\n", stream);
        EXPECT_NE(stream, nullptr);
        
        long index = stream_information_get_index(stream);
        printf("Index: %ld\n", index);
        EXPECT_GE(index, 0);

        char *type = stream_information_get_type(stream);
        printf("Type: %s\n", type);
        EXPECT_NE(type, nullptr);
        if(type) free(type);

        char *codec = stream_information_get_codec(stream);
        printf("Codec: %s\n", codec);
        EXPECT_NE(codec, nullptr);
        if(codec) free(codec);

        char *codec_long = stream_information_get_codec_long(stream);
        printf("Codec Long: %s\n", codec_long);
        if(codec_long) free(codec_long);

        char *format = stream_information_get_format(stream);
        printf("Format: %s\n", format);
        if(format) free(format);

        char *bitrate_s = stream_information_get_bitrate(stream);
        printf("Bitrate: %s\n", bitrate_s);
        if(bitrate_s) free(bitrate_s);

        char *sample_rate = stream_information_get_sample_rate(stream);
        printf("Sample Rate: %s\n", sample_rate);
        if(sample_rate) free(sample_rate);

        int width = stream_information_get_width(stream);
        printf("Width: %d\n", width);
        EXPECT_GE(width, 0); 
        
        int height = stream_information_get_height(stream);
        printf("Height: %d\n", height);
        EXPECT_GE(height, 0);

        char *tags = stream_information_get_tags_json(stream);
        printf("Tags: %s\n", tags);
        if(tags) free(tags);

        char *sample_format = stream_information_get_sample_format(stream);
        printf("Sample Format: %s\n", sample_format);
        if(sample_format) free(sample_format);

        char *display_aspect_ratio = stream_information_get_display_aspect_ratio(stream);
        printf("Display Aspect Ratio: %s\n", display_aspect_ratio);
        if(display_aspect_ratio) free(display_aspect_ratio);

        char *avg_frame_rate = stream_information_get_average_frame_rate(stream);
        printf("Average Frame Rate: %s\n", avg_frame_rate);
        if(avg_frame_rate) free(avg_frame_rate);

        char *real_frame_rate = stream_information_get_real_frame_rate(stream);
        printf("Real Frame Rate: %s\n", real_frame_rate);
        if(real_frame_rate) free(real_frame_rate);

        char *time_base = stream_information_get_time_base(stream);
        printf("Time Base: %s\n", time_base);
        if(time_base) free(time_base);

        char *channel_layout = stream_information_get_channel_layout(stream);
        printf("Channel Layout: %s\n", channel_layout);
        if(channel_layout) free(channel_layout);

        char *sample_aspect_ratio = stream_information_get_sample_aspect_ratio(stream);
        printf("Sample Aspect Ratio: %s\n", sample_aspect_ratio);
        if(sample_aspect_ratio) free(sample_aspect_ratio);

        char *codec_time_base = stream_information_get_codec_time_base(stream);
        printf("Codec Time Base: %s\n", codec_time_base);
        if(codec_time_base) free(codec_time_base);

        char *string_property = stream_information_get_string_property(stream, "codec_name");
        printf("String Property: %s\n", string_property);
        if(string_property) free(string_property);

        long number_property = stream_information_get_number_property(stream, "index");
        printf("Number Property: %ld\n", number_property);
        EXPECT_GE(number_property, 0);

        char *all_props = stream_information_get_all_properties_json(stream);
        printf("All Props: %s\n", all_props);
        if(all_props) free(all_props);

        ffmpeg_kit_handle_release(stream);
    }

    int chapters_count = media_information_get_chapters_count(info);
    printf("Chapters Count: %d\n", chapters_count);
    EXPECT_GE(chapters_count, 0);
    //TODO generate or find video with chapters to test this
    if (chapters_count > 0) {
        ChapterHandle chapter = media_information_get_chapter_at(info, 0);
        printf("Chapter: %p\n", chapter);
        EXPECT_NE(chapter, nullptr);
        
        long id = chapter_get_id(chapter);
        printf("Chapter ID: %ld\n", id);
        EXPECT_GE(id, 0);
        
        char *start_time = chapter_get_start_time(chapter);
        printf("Chapter Start Time: %s\n", start_time);
        if(start_time) free(start_time);

        char *end_time = chapter_get_end_time(chapter);
        printf("Chapter End Time: %s\n", end_time);
        if(end_time) free(end_time);
        
        ffmpeg_kit_handle_release(chapter);
    }
    
    char* all_props = media_information_get_all_properties_json(info);
    printf("All Props: %s\n", all_props);
    EXPECT_NE(all_props, nullptr);
    if (all_props) free(all_props);

    ffmpeg_kit_handle_release(info);
    ffmpeg_kit_handle_release(media_session);
}

TEST(FFmpegKitTest, MediaInformationSessionAPIs) {
    char command[512];
    snprintf(command, sizeof(command), "-v error -hide_banner -print_format json -show_format -show_streams -show_chapters -i %s", TEST_VIDEO_FILE);
    MediaInformationSessionHandle session = media_information_create_session(command);
    printf("Media Information Session: %p\n", session);
    ASSERT_NE(session, nullptr);

    media_information_session_execute_async(session, 1000);
    std::this_thread::sleep_for(std::chrono::seconds(2));
    printf("Media Information Session State: %d\n", ffmpeg_kit_session_get_state(session));
    EXPECT_EQ(ffmpeg_kit_session_get_state(session), FFMPEG_KIT_SESSION_STATE_COMPLETED);
    MediaInformationHandle info = media_information_session_get_media_information(session);
    printf("Media Information: %p\n", info);
    ASSERT_NE(info, nullptr);
    char* all_props = media_information_get_all_properties_json(info);
    printf("All Props: %s\n", all_props);
    EXPECT_NE(all_props, nullptr);
    if (all_props) free(all_props);
    ffmpeg_kit_handle_release(info);
    ffmpeg_kit_handle_release(session);
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
    snprintf(command, sizeof(command), "-loglevel fatal -autoexit -t 2 %s", TEST_VIDEO_FILE);
    FFplaySessionHandle play_session = ffplay_kit_execute(command, 1000);
    printf("FFplay Session: %p\n", play_session);
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
    printf("State: %d\n", state);
    EXPECT_EQ(state, FFMPEG_KIT_SESSION_STATE_COMPLETED);
    printf("Return Code: %ld\n", ffmpeg_kit_session_get_return_code(play_session));
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
    snprintf(command, sizeof(command), "-loglevel fatal -i %s", video_file);
    const char *ext_libraries = ffmpeg_kit_packages_get_external_libraries();
    printf("Linked External Libraries: %s\n", ext_libraries);
    FFplaySessionHandle session = ffplay_kit_execute_async(command, nullptr, nullptr, 1000);
    printf("FFplay Session: %p\n", session);
    ASSERT_NE(session, nullptr);
    
    WaitForSeconds(2);
    printf("Is Playing: %d\n", ffplay_kit_session_is_playing(session));
    EXPECT_EQ(ffplay_kit_session_is_playing(session), 1);

    ffplay_kit_session_pause(session);
    WaitForSeconds(1);
    printf("Is Paused: %d\n", ffplay_kit_session_is_paused(session));
    EXPECT_EQ(ffplay_kit_session_is_paused(session), 1);

    ffplay_kit_session_resume(session);
    WaitForSeconds(1);
    printf("Is Paused: %d\n", ffplay_kit_session_is_paused(session));
    EXPECT_EQ(ffplay_kit_session_is_paused(session), 0);
    printf("Is Playing: %d\n", ffplay_kit_session_is_playing(session));
    EXPECT_EQ(ffplay_kit_session_is_playing(session), 1);

    // Stop session before cleanup to ensure all pending events are processed
    printf("Stopping session...\n");
    ffplay_kit_session_stop(session);
    WaitForSeconds(1);
    
    // Validate session completed
    FFmpegKitSessionState state = ffmpeg_kit_session_get_state(session);
    printf("State: %d\n", state);

    while (state == FFMPEG_KIT_SESSION_STATE_RUNNING) {
      state = ffmpeg_kit_session_get_state(session);
    }
    EXPECT_EQ(state, FFMPEG_KIT_SESSION_STATE_COMPLETED);
    ffmpeg_kit_handle_release(session);
    printf("Session released successfully\n");
}

TEST_F(FFplayKitInteractiveTest, Seek) {
    const char* video_file = TEST_VIDEO_FILE;
    char command[256];
    snprintf(command, sizeof(command), "-loglevel fatal -i %s", video_file);

    FFplaySessionHandle session = ffplay_kit_execute_async(command, nullptr, nullptr, 1000);
    printf("FFplay Session: %p\n", session);
    ASSERT_NE(session, nullptr);
    WaitForSeconds(2);

    // Validate session is in valid state before seeking
    FFmpegKitSessionState state = ffmpeg_kit_session_get_state(session);
    ASSERT_EQ(state, FFMPEG_KIT_SESSION_STATE_RUNNING);
    
    // Verify session is actually playing before seeking
    int is_playing = ffplay_kit_session_is_playing(session);
    ASSERT_TRUE(is_playing) << "Session must be playing before seek";

    // Seek Absolute - with validation
    printf("Seeking to position 10.0...\n");
    ffplay_kit_session_seek(session, 10.0);
    WaitForSeconds(2); // Increased wait time for seek to complete
    
    // Validate session is still valid after seek
    state = ffmpeg_kit_session_get_state(session);
    ASSERT_EQ(state, FFMPEG_KIT_SESSION_STATE_RUNNING);
    
    double pos = ffplay_kit_session_get_position(session);
    printf("Position after seek: %f\n", pos);
    EXPECT_GE(pos, 5.0); 

    // Seek Relative Backward - with validation
    printf("Seeking backward by 5.0...\n");
    ffplay_kit_session_seek(session, -5.0);
    WaitForSeconds(2); // Increased wait time for seek to complete
    
    // Validate session is still valid
    state = ffmpeg_kit_session_get_state(session);
    ASSERT_EQ(state, FFMPEG_KIT_SESSION_STATE_RUNNING);
    
    double new_pos = ffplay_kit_session_get_position(session);
    printf("New Position: %f\n", new_pos);
    EXPECT_LT(new_pos, pos);
    
    // Stop session before cleanup
    printf("Stopping session...\n");
    ffplay_kit_session_stop(session);
    WaitForSeconds(1); // Wait for stop to complete
    
    // Validate session completed
    state = ffmpeg_kit_session_get_state(session);
    EXPECT_EQ(state, FFMPEG_KIT_SESSION_STATE_COMPLETED);
    
    ffmpeg_kit_handle_release(session);
    printf("Session released successfully\n");
}

TEST_F(FFplayKitInteractiveTest, ConcurrentSessions) {
    const char* video_file = TEST_VIDEO_FILE;
    char command[256];
    snprintf(command, sizeof(command), "-loglevel fatal -i %s", video_file);

    FFplaySessionHandle session1 = ffplay_kit_execute_async(command, nullptr, nullptr, 1000);
    printf("FFplay Session 1: %p\n", session1);
    ASSERT_NE(session1, nullptr);
    WaitForSeconds(2);

    // Session 2 should stop Session 1
    FFplaySessionHandle session2 = ffplay_kit_execute_async(command, nullptr, nullptr, 1000);
    printf("FFplay Session 2: %p\n", session2);
    ASSERT_NE(session2, nullptr);
    WaitForSeconds(2);

    FFmpegKitSessionState state1 = ffmpeg_kit_session_get_state(session1);
    printf("State 1: %d\n", state1);
    EXPECT_EQ(state1, FFMPEG_KIT_SESSION_STATE_COMPLETED);
    printf("Is Playing: %d\n", ffplay_kit_session_is_playing(session2));
    EXPECT_EQ(ffplay_kit_session_is_playing(session2), 1);

    ffmpeg_kit_handle_release(session1);
    ffmpeg_kit_handle_release(session2);
}

TEST_F(FFplayKitInteractiveTest, GlobalControls) {
    const char* video_file = TEST_VIDEO_FILE;
    char command[256];
    snprintf(command, sizeof(command), "-loglevel fatal -i %s", video_file);

    FFplaySessionHandle session = ffplay_kit_execute_async(command, nullptr, nullptr, 1000);
    printf("FFplay Session: %p\n", session);
    ASSERT_NE(session, nullptr);
    WaitForSeconds(2);

    ffplay_kit_pause();
    WaitForSeconds(1);
    printf("Is Paused: %d\n", ffplay_kit_is_paused());
    EXPECT_EQ(ffplay_kit_is_paused(), 1);

    ffplay_kit_resume();
    WaitForSeconds(1);
    printf("Is Paused: %d\n", ffplay_kit_is_paused());
    EXPECT_EQ(ffplay_kit_is_paused(), 0);

    ffplay_kit_stop();
    WaitForSeconds(1);
    FFmpegKitSessionState state = ffmpeg_kit_session_get_state(session);
    printf("State: %d\n", state);
    EXPECT_EQ(state, FFMPEG_KIT_SESSION_STATE_COMPLETED);

    ffmpeg_kit_handle_release(session);
}

TEST_F(FFplayKitInteractiveTest, GlobalSeek) {
    const char* video_file = TEST_VIDEO_FILE;
    char command[256];
    snprintf(command, sizeof(command), "-loglevel fatal -i %s", video_file);

    FFplaySessionHandle session = ffplay_kit_execute_async(command, nullptr, nullptr, 1000);
    printf("FFplay Session: %p\n", session);
    ASSERT_NE(session, nullptr);
    WaitForSeconds(2);

    // Validate session is in valid state before using global controls
    FFmpegKitSessionState state = ffmpeg_kit_session_get_state(session);
    ASSERT_EQ(state, FFMPEG_KIT_SESSION_STATE_RUNNING);

    // Global Set Position - with validation
    printf("Setting global position to 10.0...\n");
    ffplay_kit_set_position(10.0);
    WaitForSeconds(2); // Increased wait time
    
    double pos = ffplay_kit_get_position();
    printf("Position: %f\n", pos);
    EXPECT_GE(pos, 9.0); // Allow some tolerance

    // Global Seek - with validation
    printf("Global seeking backward by 5.0...\n");
    ffplay_kit_seek(-5.0);
    WaitForSeconds(2); // Increased wait time
    
    // Validate session is still valid
    state = ffmpeg_kit_session_get_state(session);
    ASSERT_EQ(state, FFMPEG_KIT_SESSION_STATE_RUNNING);
    
    double new_pos = ffplay_kit_get_position();
    printf("New Position: %f\n", new_pos);
    EXPECT_LT(new_pos, pos);

    // Stop session before cleanup
    printf("Stopping session...\n");
    ffplay_kit_stop();
    WaitForSeconds(1); // Wait for stop to complete
    
    // Validate session completed
    state = ffmpeg_kit_session_get_state(session);
    EXPECT_EQ(state, FFMPEG_KIT_SESSION_STATE_COMPLETED);
    
    ffmpeg_kit_handle_release(session);
    printf("Session released successfully\n");
}

TEST_F(FFplayKitInteractiveTest, SessionAPIs) {
    const char* video_file = TEST_VIDEO_FILE;
    char command[256];
    snprintf(command, sizeof(command), "-loglevel fatal -i %s", video_file);

    FFplaySessionHandle session = ffplay_kit_create_session(command);
    printf("Session: %p\n", session);
    ASSERT_NE(session, nullptr);

    ffplay_kit_session_execute_async(session, 1000);
    WaitForSeconds(2);

    ffplay_kit_session_set_volume(session, 0.5f);
    WaitForSeconds(1); // Wait for async event loop to process volume change
    printf("Volume: %f\n", ffplay_kit_session_get_volume(session));
    EXPECT_FLOAT_EQ(ffplay_kit_session_get_volume(session), 0.5f);

    ffplay_kit_session_set_position(session, 5.0);
    WaitForSeconds(1);
    printf("Position: %f\n", ffplay_kit_session_get_position(session));
    EXPECT_GE(ffplay_kit_session_get_position(session), 4.0);
    
    printf("Duration: %f\n", ffplay_kit_session_get_duration(session));
    EXPECT_GT(ffplay_kit_session_get_duration(session), 0.0);

    ffplay_kit_session_stop(session);
    WaitForSeconds(1);
    printf("State: %d\n", ffmpeg_kit_session_get_state(session));
    EXPECT_EQ(ffmpeg_kit_session_get_state(session), FFMPEG_KIT_SESSION_STATE_COMPLETED);

    // Call close (no-op or similar cleanup in some contexts, but verifies it doesn't crash)
    ffplay_kit_session_close(session);
    
    // Create and manual start test
    FFplaySessionHandle session2 = ffplay_kit_create_session(command);
    printf("Session2: %p\n", session2);
    ASSERT_NE(session2, nullptr);
    ffplay_kit_session_execute_async(session2, 1000);
    WaitForSeconds(2);
    ffplay_kit_session_pause(session2);
    WaitForSeconds(1);
    ffplay_kit_session_resume(session2);
    WaitForSeconds(1);
    printf("Session2 is playing: %d\n", ffplay_kit_session_is_playing(session2));
    EXPECT_EQ(ffplay_kit_session_is_playing(session2), 1);
    ffmpeg_kit_handle_release(session2);

    ffmpeg_kit_handle_release(session);
}

TEST_F(FFplayKitInteractiveTest, GlobalAPIs) {
    const char* video_file = TEST_VIDEO_FILE;
    char command[256];
    snprintf(command, sizeof(command), "-loglevel fatal -i %s", video_file);

    FFplaySessionHandle session = ffplay_kit_execute_async(command, nullptr, nullptr, 1000);
    printf("Session: %p\n", session);
    ASSERT_NE(session, nullptr);
    WaitForSeconds(2);

    ffplay_kit_set_volume(0.5f);
    WaitForSeconds(1);
    printf("Volume: %f\n", ffplay_kit_get_volume());
    EXPECT_FLOAT_EQ(ffplay_kit_get_volume(), 0.5f);

    printf("Duration: %f\n", ffplay_kit_get_duration());
    EXPECT_GT(ffplay_kit_get_duration(), 0.0);

    // Since it's already running, start() is a no-op or resume. Test no crash.
    ffplay_kit_start();
    WaitForSeconds(1);

    // Stop to end process
    ffplay_kit_stop();
    WaitForSeconds(1);

    ffplay_kit_close();

    ffmpeg_kit_handle_release(session);
}

TEST_F(FFplayKitInteractiveTest, TimeoutSession) {
    const char* video_file = TEST_VIDEO_FILE;
    char command[256];
    snprintf(command, sizeof(command), "-loglevel fatal -i %s", video_file);

    // 1. Start Session 1 normally
    FFplaySessionHandle session1 = ffplay_kit_execute_async(command, nullptr, nullptr, 1000);
    printf("Session 1: %p\n", session1);
    ASSERT_NE(session1, nullptr);
    WaitForSeconds(2);
    printf("Session 1 is playing: %d\n", ffplay_kit_session_is_playing(session1));
    EXPECT_EQ(ffplay_kit_session_is_playing(session1), 1);

    // 2. Create Session 2
    FFplaySessionHandle session2 = ffplay_kit_create_session(command);
    printf("Session 2: %p\n", session2);
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
    printf("State 2: %d\n", state2);
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
    printf("Package Name: %s\n", pkg);
    EXPECT_NE(pkg, nullptr);
    EXPECT_STRNE(pkg, "");
    printf("Package Name: %s\n", pkg);
    free(pkg);
}

TEST(FFmpegKitTest, AudioDeviceManagement) {
    // Force dummy audio for headless environments
    #ifdef _WIN32
        _putenv("SDL_AUDIODRIVER=dummy");
        _putenv("SDL_VIDEODRIVER=dummy");
        _putenv("DISPLAY=:0");
    #else
        setenv("SDL_AUDIODRIVER", "dummy", 1);
        setenv("SDL_VIDEODRIVER", "dummy", 1);  // <-- ADD THIS
        setenv("DISPLAY", ":0", 1);             // <-- ADD THIS
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
    snprintf(command, sizeof(command), "-loglevel fatal -autoexit -t 0.5 %s", TEST_AUDIO_FILE);
    
    FFplaySessionHandle session = ffplay_kit_execute(command, 2000); 
    
    if (session) {
        ffmpeg_kit_handle_release(session);
    }
    ffmpeg_kit_config_set_audio_output_device(nullptr);
    SUCCEED();
}
TEST(FFmpegKitTest, ConcurrentOperations) {
    // 1. Create a slow FFmpeg session (e.g., generating a long video)
    FFmpegSessionHandle ffmpeg_session = ffmpeg_kit_create_session("-hide_banner -loglevel fatal -f lavfi -i testsrc=duration=5:size=128x128:rate=10 -y concurrent_output.mp4");
    printf("FFmpeg Session: %p\n", ffmpeg_session);
    ASSERT_NE(ffmpeg_session, nullptr);

    // 2. Create a FFprobe session to run at the same time
    FFprobeSessionHandle ffprobe_session = ffprobe_kit_create_session("-hide_banner -loglevel fatal -show_format -i " TEST_VIDEO_FILE);
    printf("FFprobe Session: %p\n", ffprobe_session);
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
    printf("FFmpeg Session State: %d\n", ffmpeg_kit_session_get_state(ffmpeg_session));
    printf("FFprobe Session State: %d\n", ffmpeg_kit_session_get_state(ffprobe_session));
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
    FFmpegSessionHandle ffmpeg_session1 = ffmpeg_kit_create_session("-hide_banner -loglevel fatal -f lavfi -i testsrc=duration=3:size=128x128:rate=10 -y concurrent1.mp4");
    FFmpegSessionHandle ffmpeg_session2 = ffmpeg_kit_create_session("-hide_banner -loglevel fatal -f lavfi -i testsrc=duration=3:size=128x128:rate=10 -y concurrent2.mp4");
    printf("FFmpeg Session 1: %p\n", ffmpeg_session1);
    printf("FFmpeg Session 2: %p\n", ffmpeg_session2);
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
    printf("FFmpeg Session 1 State: %d\n", ffmpeg_kit_session_get_state(ffmpeg_session1));
    printf("FFmpeg Session 2 State: %d\n", ffmpeg_kit_session_get_state(ffmpeg_session2));
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
    FFmpegSessionHandle ffmpeg_session = ffmpeg_kit_create_session("-hide_banner -loglevel fatal -f lavfi -i testsrc=duration=5:size=128x128:rate=10 -y ffplay_concurrent.mp4");
    ffmpeg_kit_session_execute_async(ffmpeg_session);
    
    // 2. Start FFplay session
    char command[256];
    snprintf(command, sizeof(command), "-loglevel fatal -i %s", TEST_VIDEO_FILE);
    FFplaySessionHandle play_session = ffplay_kit_execute_async(command, nullptr, nullptr, 1000);
    printf("FFplay Session: %p\n", play_session);
    ASSERT_NE(play_session, nullptr);

    WaitForSeconds(2);

    // 3. Verify both are running (FFplay should be playing, FFmpeg should be RUNNING or COMPLETED if it's fast)
    printf("FFplay Session State: %d\n", ffplay_kit_session_is_playing(play_session));
    EXPECT_EQ(ffplay_kit_session_is_playing(play_session), 1);
    FFmpegKitSessionState ffmpeg_state = ffmpeg_kit_session_get_state(ffmpeg_session);
    printf("FFmpeg Session State: %d\n", ffmpeg_state);
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
    snprintf(command, sizeof(command), "-loglevel fatal -i %s", TEST_VIDEO_FILE);
    FFplaySessionHandle play_session = ffplay_kit_execute_async(command, nullptr, nullptr, 1000);
    printf("FFplay Session: %p\n", play_session);
    ASSERT_NE(play_session, nullptr);
    WaitForSeconds(1);

    // 2. Run FFprobe session concurrently
    FFprobeSessionHandle probe_session = ffprobe_kit_execute("-hide_banner -loglevel fatal -show_format -i " TEST_VIDEO_FILE);
    printf("FFprobe Session: %p\n", probe_session);
    ASSERT_NE(probe_session, nullptr);

    // 3. Verify FFplay is still playing and probe finished
    printf("FFplay Session State: %d\n", ffplay_kit_session_is_playing(play_session));
    EXPECT_EQ(ffplay_kit_session_is_playing(play_session), 1);
    printf("FFprobe Session State: %d\n", ffmpeg_kit_session_get_state(probe_session));
    EXPECT_EQ(ffmpeg_kit_session_get_state(probe_session), FFMPEG_KIT_SESSION_STATE_COMPLETED);

    // 4. Cleanup
    ffmpeg_kit_handle_release(play_session);
    ffmpeg_kit_handle_release(probe_session);
}

TEST(FFmpegKitTest, ConcurrentFFprobeSessions) {
    // 1. Create two FFprobe sessions
    FFprobeSessionHandle ffprobe_session1 = ffprobe_kit_create_session("-hide_banner -loglevel fatal -show_format -i " TEST_VIDEO_FILE);
    FFprobeSessionHandle ffprobe_session2 = ffprobe_kit_create_session("-hide_banner -loglevel fatal -show_format -i " TEST_VIDEO_FILE);
    printf("FFprobe Session 1: %p\n", ffprobe_session1);
    ASSERT_NE(ffprobe_session1, nullptr);
    printf("FFprobe Session 2: %p\n", ffprobe_session2);
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
    printf("FFprobe Session 1 State: %d\n", ffmpeg_kit_session_get_state(ffprobe_session1));
    EXPECT_EQ(ffmpeg_kit_session_get_state(ffprobe_session1), FFMPEG_KIT_SESSION_STATE_COMPLETED);
    printf("FFprobe Session 2 State: %d\n", ffmpeg_kit_session_get_state(ffprobe_session2));
    EXPECT_EQ(ffmpeg_kit_session_get_state(ffprobe_session2), FFMPEG_KIT_SESSION_STATE_COMPLETED);

    // Cleanup
    ffmpeg_kit_handle_release(ffprobe_session1);
    ffmpeg_kit_handle_release(ffprobe_session2);
}

TEST(FFmpegKitTest, SessionManagement) {
    ffmpeg_kit_clear_sessions();
    
    // Create multiple types of sessions
    FFmpegSessionHandle ffmpeg = ffmpeg_kit_create_session("-version");
    FFprobeSessionHandle ffprobe = ffprobe_kit_create_session("-version");
    FFplaySessionHandle ffplay = ffplay_kit_create_session("-version");
    char media_cmd[512];
    snprintf(media_cmd, sizeof(media_cmd), "-v error -hide_banner -print_format json -show_format -show_streams -show_chapters -i %s", TEST_VIDEO_FILE);
    MediaInformationSessionHandle media = media_information_create_session(media_cmd);

    // Check last session
    FFmpegSessionHandle last = ffmpeg_kit_get_last_session();
    printf("Last Session: %p\n", last);
    EXPECT_NE(last, nullptr);
    if(last) ffmpeg_kit_handle_release(last);

    FFmpegSessionHandle last_ffmpeg = ffmpeg_kit_get_last_ffmpeg_session();
    printf("Last FFmpeg Session: %p\n", last_ffmpeg);
    EXPECT_NE(last_ffmpeg, nullptr);
    if(last_ffmpeg) ffmpeg_kit_handle_release(last_ffmpeg);

    FFprobeSessionHandle last_ffprobe = ffmpeg_kit_get_last_ffprobe_session();
    printf("Last FFprobe Session: %p\n", last_ffprobe);
    EXPECT_NE(last_ffprobe, nullptr);
    if(last_ffprobe) ffmpeg_kit_handle_release(last_ffprobe);

    FFplaySessionHandle last_ffplay = ffmpeg_kit_get_last_ffplay_session();
    printf("Last FFplay Session: %p\n", last_ffplay);
    EXPECT_NE(last_ffplay, nullptr);
    if(last_ffplay) ffmpeg_kit_handle_release(last_ffplay);

    MediaInformationSessionHandle last_media = ffmpeg_kit_get_last_media_information_session();
    printf("Last Media Information Session: %p\n", last_media);
    EXPECT_NE(last_media, nullptr);
    if(last_media) ffmpeg_kit_handle_release(last_media);

    // List sessions
    FFmpegSessionHandle *sessions = ffmpeg_kit_get_sessions();
    int count = 0;
    if (sessions) {
        while(sessions[count]) {
            ffmpeg_kit_handle_release(sessions[count]);
            count++;
        }
        free(sessions);
    }
    printf("Session Count: %d\n", count);
    EXPECT_GE(count, 4);

    FFmpegSessionHandle *ffmpeg_sessions = ffmpeg_kit_get_ffmpeg_sessions();
    int ffmpeg_count = 0;
    if (ffmpeg_sessions) {
        while(ffmpeg_sessions[ffmpeg_count]) {
            ffmpeg_kit_handle_release(ffmpeg_sessions[ffmpeg_count]);
            ffmpeg_count++;
        }
        free(ffmpeg_sessions);
    }
    printf("FFmpeg Session Count: %d\n", ffmpeg_count);
    EXPECT_GE(ffmpeg_count, 1);

    // Cleanup
    ffmpeg_kit_handle_release(ffmpeg);
    ffmpeg_kit_handle_release(ffprobe);
    ffmpeg_kit_handle_release(ffplay);
    ffmpeg_kit_handle_release(media);
}

TEST(FFmpegKitTest, LastCompletedSession) {
    ffmpeg_kit_clear_sessions();
    
    FFmpegSessionHandle session = ffmpeg_kit_execute("-version");
    ASSERT_NE(session, nullptr);
    
    FFmpegSessionHandle last_completed = ffmpeg_kit_get_last_completed_session();
    EXPECT_NE(last_completed, nullptr);
    
    if (last_completed) {
        EXPECT_EQ(ffmpeg_kit_session_get_state(last_completed), FFMPEG_KIT_SESSION_STATE_COMPLETED);
        ffmpeg_kit_handle_release(last_completed);
    }
    
    ffmpeg_kit_handle_release(session);
}

TEST(FFmpegKitTest, SessionProperties) {
    FFmpegSessionHandle session = ffmpeg_kit_execute("-hide_banner -loglevel fatal -f lavfi -i sine=frequency=1000:duration=1 -y test_props.wav");
    ASSERT_NE(session, nullptr);

    long create_time = ffmpeg_kit_session_get_create_time(session);
    long start_time = ffmpeg_kit_session_get_start_time(session);
    long end_time = ffmpeg_kit_session_get_end_time(session);
    long duration = ffmpeg_kit_session_get_duration(session);

    printf("Create Time: %ld\n", create_time);
    printf("Start Time: %ld\n", start_time);
    printf("End Time: %ld\n", end_time);
    printf("Duration: %ld\n", duration);

    EXPECT_GT(create_time, 0);
    EXPECT_GT(start_time, 0);
    EXPECT_GT(end_time, 0);
    EXPECT_GE(end_time, start_time);
    EXPECT_GE(duration, 0);

    ffmpeg_kit_handle_release(session);
    remove("test_props.wav");
}

TEST(FFmpegKitTest, Statistics) {
    // Generate a file and check statistics
    FFmpegSessionHandle session = ffmpeg_kit_execute("-hide_banner -loglevel fatal -f lavfi -i testsrc=duration=2:size=128x128:rate=30 -vcodec mpeg4 -y test_stats.mp4");
    ASSERT_NE(session, nullptr);

    int stats_count = ffmpeg_kit_session_get_statistics_count(session);
    printf("Statistics Count: %d\n", stats_count);
    
    if (stats_count > 0) {
        StatisticsHandle stats = ffmpeg_kit_session_get_statistics_at(session, 0);
        EXPECT_NE(stats, nullptr);
        
        int frame_number = ffmpeg_kit_statistics_get_video_frame_number(stats);
        float fps = ffmpeg_kit_statistics_get_video_fps(stats);
        double time = ffmpeg_kit_statistics_get_time(stats);
        
        printf("Frame Number: %d\n", frame_number);
        printf("FPS: %f\n", fps);
        printf("Time: %f\n", time);
        
        EXPECT_GE(frame_number, 0);
        EXPECT_GE(fps, 0.0f);
        EXPECT_GE(time, 0.0);
        
        ffmpeg_kit_handle_release(stats);
    }

    ffmpeg_kit_handle_release(session);
    remove("test_stats.mp4");
}

TEST(FFprobeKitTest, LastSessionAliases) {
    ffmpeg_kit_clear_sessions();
    
    FFprobeSessionHandle session = ffprobe_kit_execute("-hide_banner -version");
    ASSERT_NE(session, nullptr);
    
    FFprobeSessionHandle last = ffprobe_kit_get_last_session();
    EXPECT_NE(last, nullptr);
    if(last) ffmpeg_kit_handle_release(last);
    
    FFprobeSessionHandle last_comp = ffprobe_kit_get_last_completed_session();
    EXPECT_NE(last_comp, nullptr);
    if(last_comp) ffmpeg_kit_handle_release(last_comp);
    
    ffmpeg_kit_handle_release(session);
}

TEST(FFmpegKitTest, SessionListingAliases) {
    ffmpeg_kit_clear_sessions();

    // 1. FFmpeg Listing
    FFmpegSessionHandle ffmpeg = ffmpeg_kit_create_session("-version");
    FFmpegSessionHandle *ffmpeg_list = ffmpeg_kit_list_sessions();
    int ffmpeg_count = 0;
    if (ffmpeg_list) {
        while (ffmpeg_list[ffmpeg_count]) {
            ffmpeg_kit_handle_release(ffmpeg_list[ffmpeg_count]);
            ffmpeg_count++;
        }
        free(ffmpeg_list);
    }
    EXPECT_GE(ffmpeg_count, 1);
    printf("FFmpeg List Count: %d\n", ffmpeg_count);

    // 2. FFprobe Listing
    FFprobeSessionHandle ffprobe = ffprobe_kit_create_session("-version");
    FFprobeSessionHandle *ffprobe_list = ffprobe_kit_list_sessions();
    int ffprobe_count = 0;
    if (ffprobe_list) {
        while (ffprobe_list[ffprobe_count]) {
            ffmpeg_kit_handle_release(ffprobe_list[ffprobe_count]);
            ffprobe_count++;
        }
        free(ffprobe_list);
    }
    EXPECT_GE(ffprobe_count, 1);
    printf("FFprobe List Count: %d\n", ffprobe_count);

    // 3. Media Information Listing
    char media_cmd[512];
    snprintf(media_cmd, sizeof(media_cmd), "-v error -i %s", TEST_VIDEO_FILE);
    MediaInformationSessionHandle media = media_information_create_session(media_cmd);
    MediaInformationSessionHandle *media_list = media_information_kit_list_sessions();
    int media_count = 0;
    if (media_list) {
        while (media_list[media_count]) {
            ffmpeg_kit_handle_release(media_list[media_count]);
            media_count++;
        }
        free(media_list);
    }
    EXPECT_GE(media_count, 1);
    printf("Media Info List Count: %d\n", media_count);

    // Cleanup
    ffmpeg_kit_handle_release(ffmpeg);
    ffmpeg_kit_handle_release(ffprobe);
    ffmpeg_kit_handle_release(media);
}

TEST(FFmpegKitTest, HandleManagement) {
    // 1. Create a session and get a handle
    FFmpegSessionHandle session = ffmpeg_kit_create_session("-version");
    ASSERT_NE(session, nullptr);

    // 2. First release - should work normally
    ffmpeg_kit_handle_release(session);
    SUCCEED();

    // 3. Second release (Double Free) - should be caught by protection and NOT crash
    ffmpeg_kit_handle_release(session);
    SUCCEED();

    // 4. Release nullptr - should be no-op
    ffmpeg_kit_handle_release(nullptr);
    SUCCEED();
}

TEST(FFmpegKitTest, ConcurrentHandleRelease) {
    // Create a session
    FFmpegSessionHandle session = ffmpeg_kit_create_session("-version");
    ASSERT_NE(session, nullptr);

    // Multiple threads trying to release the SAME handle simultaneously
    const int thread_count = 10;
    std::vector<std::thread> threads;
    for (int i = 0; i < thread_count; ++i) {
        threads.emplace_back([session]() {
            ffmpeg_kit_handle_release(session);
        });
    }

    for (auto& t : threads) {
        t.join();
    }

    // If we reached here without crashing/hanging, the test passed
    SUCCEED();
}

TEST(FFmpegKitTest, RobustnessTest) {
    // 1. Create a session and execute it to ensure it's in history
    FFmpegSessionHandle session = ffmpeg_kit_create_session("-version");
    ASSERT_NE(session, nullptr);
    ffmpeg_kit_session_execute(session);
    
    // 2. Get session ID
    int64_t id = ffmpeg_kit_session_get_session_id(session);
    EXPECT_GT(id, 0);
    
    // 3. Release handle
    ffmpeg_kit_handle_release(session);
    
    // 4. Try to use released handle (should NOT crash)
    // It should return -1 or nullptr because the handle is no longer in g_active_handles
    // and it's too large to be a "fake" ID.
    EXPECT_EQ(ffmpeg_kit_session_get_session_id(session), -1);
    EXPECT_EQ(ffmpeg_kit_session_get_output(session), nullptr);
    
    // 5. Try with "fake" handle (ID as pointer)
    // This should work because get_ptr_internal now supports looking up by ID in history
    void* fake_handle = (void*)(uintptr_t)id;
    EXPECT_EQ(ffmpeg_kit_session_get_session_id(fake_handle), id);
    
    char* output = ffmpeg_kit_session_get_output(fake_handle);
    EXPECT_NE(output, nullptr);
    if (output) {
        printf("Output from fake handle: %s\n", output);
        free(output);
    }
}
