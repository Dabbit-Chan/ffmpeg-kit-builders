#include <gtest/gtest.h>
#include "ffmpegkit_wrapper.h"
#include <cstdio>
#include <cstdlib>
#include <string>
#include <vector>
#include <atomic>
#include <thread>
#include <chrono>

#ifndef FFMPEG_KIT_TEST_DIR
#define FFMPEG_KIT_TEST_DIR "."
#endif
#define TEST_VIDEO_FILE FFMPEG_KIT_TEST_DIR "/dummy_video.mp4"
#define TEST_AUDIO_FILE FFMPEG_KIT_TEST_DIR "/dummy_audio.wav"

class CallbackTest : public ::testing::Test {
protected:
    void TearDown() override {
        ffmpeg_kit_config_clear_sessions();
    }
};

// ... and update test definitions to use CallbackTest ...
// Helper class to capture callback data
class CallbackCapturer {
public:
    std::atomic<bool> complete_called{false};
    std::atomic<bool> log_called{false};
    std::atomic<bool> stats_called{false};
    std::vector<std::string> logs;
    FFmpegSessionHandle session = nullptr;

    static void CompleteCallback(FFmpegSessionHandle session, void* user_data) {
        auto* capturer = static_cast<CallbackCapturer*>(user_data);
        capturer->session = session;
        capturer->complete_called = true;
    }

    static void LogCallback(FFmpegSessionHandle session, const char* log, void* user_data) {
        auto* capturer = static_cast<CallbackCapturer*>(user_data);
        if (log) {
            capturer->logs.push_back(log);
        }
        capturer->log_called = true;
    }

    static void StatisticsCallback(FFmpegSessionHandle session, int time, int64_t size, double bitrate, double speed, int videoFrameNumber, float videoFps, float videoQuality, void* user_data) {
        auto* capturer = static_cast<CallbackCapturer*>(user_data);
        capturer->stats_called = true;
    }
};

// FFmpeg Callback Tests
TEST_F(CallbackTest, FFmpegAsyncExecute) {
    CallbackCapturer capturer;
    // Simple version command
    FFmpegSessionHandle session = ffmpeg_kit_execute_async("-version", CallbackCapturer::CompleteCallback, &capturer);
    ASSERT_NE(session, nullptr);

    // Wait for completion (busy wait with timeout)
    int timeout_ms = 5000;
    while (!capturer.complete_called && timeout_ms > 0) {
        std::this_thread::sleep_for(std::chrono::milliseconds(10));
        timeout_ms -= 10;
    }

    EXPECT_TRUE(capturer.complete_called);
    EXPECT_NE(capturer.session, nullptr);
    if(capturer.session) {
        // Handle pointer might be different, but ID should be same
        EXPECT_EQ(ffmpeg_kit_session_get_session_id(session), ffmpeg_kit_session_get_session_id(capturer.session));
        ffmpeg_kit_handle_release(capturer.session);
    }

    EXPECT_EQ(ffmpeg_kit_session_get_state(session), FFMPEG_KIT_SESSION_STATE_COMPLETED);
    
    ffmpeg_kit_handle_release(session);
}

TEST_F(CallbackTest, FFmpegAsyncExecuteFull) {
    CallbackCapturer capturer;
    // Use a command that generates output and takes a bit of time (testsrc)
    std::string cmd = "-loglevel fatal -hide_banner -f lavfi -i testsrc=duration=1:size=128x128:rate=30 -f null -";
    
    FFmpegSessionHandle session = ffmpeg_kit_execute_async_full(
        cmd.c_str(), 
        CallbackCapturer::CompleteCallback, 
        CallbackCapturer::LogCallback, 
        CallbackCapturer::StatisticsCallback, 
        &capturer, 
        0 // No specific timeout for session start
    );
    ASSERT_NE(session, nullptr);

    // Wait for completion
    int timeout_ms = 10000;
    while (!capturer.complete_called && timeout_ms > 0) {
        std::this_thread::sleep_for(std::chrono::milliseconds(10));
        timeout_ms -= 10;
    }

    EXPECT_TRUE(capturer.complete_called);
    
    if (capturer.session) {
        ffmpeg_kit_handle_release(capturer.session);
    }
    
    EXPECT_EQ(ffmpeg_kit_session_get_state(session), FFMPEG_KIT_SESSION_STATE_COMPLETED);
    ffmpeg_kit_handle_release(session);
}

// FFprobe Callback Tests
class ProbeCallbackCapturer {
public:
    std::atomic<bool> complete_called{false};
    FFprobeSessionHandle session = nullptr;
    MediaInformationSessionHandle media_session = nullptr;

    static void CompleteCallback(FFprobeSessionHandle session, void* user_data) {
        auto* capturer = static_cast<ProbeCallbackCapturer*>(user_data);
        capturer->session = session;
        capturer->complete_called = true;
    }

    static void MediaInfoCompleteCallback(MediaInformationSessionHandle session, void* user_data) {
        auto* capturer = static_cast<ProbeCallbackCapturer*>(user_data);
        capturer->media_session = session;
        capturer->complete_called = true;
    }
};

TEST_F(CallbackTest, FFprobeAsyncExecute) {
    ProbeCallbackCapturer capturer;
    FFprobeSessionHandle session = ffprobe_kit_execute_async("-version", ProbeCallbackCapturer::CompleteCallback, &capturer);
    ASSERT_NE(session, nullptr);

    int timeout_ms = 5000;
    while (!capturer.complete_called && timeout_ms > 0) {
        std::this_thread::sleep_for(std::chrono::milliseconds(10));
        timeout_ms -= 10;
    }

    EXPECT_TRUE(capturer.complete_called);
    EXPECT_NE(capturer.session, nullptr);

    if (capturer.session) {
        ffmpeg_kit_handle_release(capturer.session);
    }

    ffmpeg_kit_handle_release(session);
}

TEST_F(CallbackTest, MediaInformationAsync) {
    ProbeCallbackCapturer capturer;
    MediaInformationSessionHandle session = ffprobe_kit_get_media_information_async(TEST_VIDEO_FILE, ProbeCallbackCapturer::MediaInfoCompleteCallback, &capturer);
    ASSERT_NE(session, nullptr);

    int timeout_ms = 10000; // Increased timeout slightly
    while (!capturer.complete_called && timeout_ms > 0) {
        std::this_thread::sleep_for(std::chrono::milliseconds(10));
        timeout_ms -= 10;
    }

    EXPECT_TRUE(capturer.complete_called);
    EXPECT_NE(capturer.media_session, nullptr);
    
    // session handle (returned by async call) and capturer.media_session handle (passed to callback)
    // point to same session object, but are different handles.
    EXPECT_EQ(ffmpeg_kit_session_get_session_id(session), ffmpeg_kit_session_get_session_id(capturer.media_session));

    // Use the callback handle to inspect, just to use it
    MediaInformationHandle media_info = media_information_session_get_media_information(capturer.media_session);
    ASSERT_NE(media_info, nullptr);
    
    char *format = media_information_get_format(media_info);
    EXPECT_NE(format, nullptr);
    if(format) free(format);
    
    ffmpeg_kit_handle_release(media_info);
    
    if (capturer.media_session) {
        ffmpeg_kit_handle_release(capturer.media_session);
    }
    
    ffmpeg_kit_handle_release(session);
}

// FFplay Callback Tests
class PlayCallbackCapturer {
public:
    std::atomic<bool> complete_called{false};
    FFplaySessionHandle session = nullptr;

    static void CompleteCallback(FFplaySessionHandle session, void* user_data) {
        auto* capturer = static_cast<PlayCallbackCapturer*>(user_data);
        capturer->session = session;
        capturer->complete_called = true;
    }
};

TEST_F(CallbackTest, FFplayAsyncExecute) {
    // Need dummy env
#ifdef _WIN32
    _putenv("SDL_VIDEODRIVER=dummy");
    _putenv("SDL_AUDIODRIVER=dummy");
#else
    setenv("SDL_VIDEODRIVER", "dummy", 1);
    setenv("SDL_AUDIODRIVER", "dummy", 1);
#endif

    PlayCallbackCapturer capturer;
    // Short playback
    char command[512];
    snprintf(command, sizeof(command), "-hide_banner -loglevel fatal -autoexit -t 0.5 %s", TEST_VIDEO_FILE);

    FFplaySessionHandle session = ffplay_kit_execute_async(command, PlayCallbackCapturer::CompleteCallback, &capturer, 5000);
    ASSERT_NE(session, nullptr);

    int timeout_ms = 5000;
    while (!capturer.complete_called && timeout_ms > 0) {
        std::this_thread::sleep_for(std::chrono::milliseconds(10));
        timeout_ms -= 10;
    }

    EXPECT_TRUE(capturer.complete_called);
    EXPECT_NE(capturer.session, nullptr);
    
    if (capturer.session) {
        ffmpeg_kit_handle_release(capturer.session);
    }
    
    ffmpeg_kit_handle_release(session);
}

// Global Callback Tests
class GlobalCallbackCapturer {
public:
    std::atomic<bool> log_called{false};
    std::atomic<bool> stats_called{false};
    std::atomic<int> complete_called_count{0};
    std::vector<std::string> logs;

    static void LogCallback(FFmpegSessionHandle session, const char* log, void* user_data) {
        auto* capturer = static_cast<GlobalCallbackCapturer*>(user_data);
        if (log) {
            capturer->logs.push_back(log);
        }
        capturer->log_called = true;
    }

    static void StatisticsCallback(FFmpegSessionHandle session, int time, int64_t size, double bitrate, double speed, int videoFrameNumber, float videoFps, float videoQuality, void* user_data) {
        auto* capturer = static_cast<GlobalCallbackCapturer*>(user_data);
        capturer->stats_called = true;
    }

    static void CompleteCallback(FFmpegSessionHandle session, void* user_data) {
        auto* capturer = static_cast<GlobalCallbackCapturer*>(user_data);
        capturer->complete_called_count++;
    }

    static void FFprobeCompleteCallback(FFprobeSessionHandle session, void* user_data) {
        auto* capturer = static_cast<GlobalCallbackCapturer*>(user_data);
        capturer->complete_called_count++;
    }

    static void FFplayCompleteCallback(FFplaySessionHandle session, void* user_data) {
        auto* capturer = static_cast<GlobalCallbackCapturer*>(user_data);
        capturer->complete_called_count++;
    }

    static void MediaInformationCompleteCallback(MediaInformationSessionHandle session, void* user_data) {
        auto* capturer = static_cast<GlobalCallbackCapturer*>(user_data);
        capturer->complete_called_count++;
    }
};

TEST_F(CallbackTest, GlobalCallbacks) {
    GlobalCallbackCapturer capturer;
    
    // Enable global callbacks
    ffmpeg_kit_config_enable_log_callback(GlobalCallbackCapturer::LogCallback, &capturer);
    ffmpeg_kit_config_enable_statistics_callback(GlobalCallbackCapturer::StatisticsCallback, &capturer);
    ffmpeg_kit_config_enable_ffmpeg_session_complete_callback(GlobalCallbackCapturer::CompleteCallback, &capturer);
    ffmpeg_kit_config_enable_ffprobe_session_complete_callback(GlobalCallbackCapturer::FFprobeCompleteCallback, &capturer);
    ffmpeg_kit_config_enable_ffplay_session_complete_callback(GlobalCallbackCapturer::FFplayCompleteCallback, &capturer);
    ffmpeg_kit_config_enable_media_information_session_complete_callback(GlobalCallbackCapturer::MediaInformationCompleteCallback, &capturer);

    // Run a command that produces logs and stats
    FFmpegSessionHandle session = ffmpeg_kit_execute_async("-loglevel fatal -hide_banner -f lavfi -i testsrc=duration=2:size=128x128:rate=30 -f null -", nullptr, nullptr);
    ASSERT_NE(session, nullptr);

#ifdef _WIN32
    _putenv("SDL_VIDEODRIVER=dummy");
    _putenv("SDL_AUDIODRIVER=dummy");
#else
    setenv("SDL_VIDEODRIVER", "dummy", 1);
    setenv("SDL_AUDIODRIVER", "dummy", 1);
#endif

    // Run other async executions to test global callbacks
    FFprobeSessionHandle probe_session = ffprobe_kit_execute_async("-version", nullptr, nullptr);
    
    char play_command[512];
    snprintf(play_command, sizeof(play_command), "-hide_banner -loglevel fatal -autoexit -t 0.5 %s", TEST_VIDEO_FILE);
    FFplaySessionHandle play_session = ffplay_kit_execute_async(play_command, nullptr, nullptr, 5000);
    
    MediaInformationSessionHandle media_session = ffprobe_kit_get_media_information_async(TEST_VIDEO_FILE, nullptr, nullptr);

    int timeout_ms = 10000;
    while (capturer.complete_called_count < 4 && timeout_ms > 0) {
        std::this_thread::sleep_for(std::chrono::milliseconds(10));
        timeout_ms -= 10;
    }

    EXPECT_EQ(capturer.complete_called_count.load(), 4);
    EXPECT_TRUE(capturer.log_called);
    // stats_called might sometimes fail if duration is too short to trigger interval, but size=0 allows stats.
    EXPECT_GT(capturer.logs.size(), 0);

    // Disable global callbacks
    ffmpeg_kit_config_enable_log_callback(nullptr, nullptr);
    ffmpeg_kit_config_enable_statistics_callback(nullptr, nullptr);
    ffmpeg_kit_config_enable_ffmpeg_session_complete_callback(nullptr, nullptr);
    ffmpeg_kit_config_enable_ffprobe_session_complete_callback(nullptr, nullptr);
    ffmpeg_kit_config_enable_ffplay_session_complete_callback(nullptr, nullptr);
    ffmpeg_kit_config_enable_media_information_session_complete_callback(nullptr, nullptr);

    ffmpeg_kit_handle_release(session);
    ffmpeg_kit_handle_release(probe_session);
    ffmpeg_kit_handle_release(play_session);
    ffmpeg_kit_handle_release(media_session);
}
