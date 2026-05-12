#include <gtest/gtest.h>
#include "ffmpegkit_wrapper.h"
#include <vector>
#include <atomic>
#include <chrono>
#include <functional>
#include <memory>

#ifdef _WIN32
#include <process.h>
#include <windows.h>
#else
#include <thread>
#endif

#ifndef FFMPEG_KIT_TEST_DIR
#define FFMPEG_KIT_TEST_DIR "."
#endif
#define TEST_VIDEO_FILE FFMPEG_KIT_TEST_DIR "/dummy_video.mp4"

class StressTest : public ::testing::Test {
protected:
    void SetUp() override {
        // Ensure environment for ffplay
        #ifdef _WIN32
            _putenv("SDL_VIDEODRIVER=dummy");
            _putenv("SDL_AUDIODRIVER=dummy");
        #else
            setenv("SDL_VIDEODRIVER", "dummy", 1);
            setenv("SDL_AUDIODRIVER", "dummy", 1);
        #endif
    }

    void TearDown() override {
        ffmpeg_kit_config_clear_sessions();
        ffmpeg_kit_config_enable_log_callback(nullptr, nullptr);
        ffmpeg_kit_config_enable_statistics_callback(nullptr, nullptr);
        ffmpeg_kit_config_enable_ffmpeg_session_complete_callback(nullptr, nullptr);
        ffmpeg_kit_config_enable_ffprobe_session_complete_callback(nullptr, nullptr);
        ffmpeg_kit_config_enable_ffplay_session_complete_callback(nullptr, nullptr);
        ffmpeg_kit_config_enable_media_information_session_complete_callback(nullptr, nullptr);
    }
};

#ifdef _WIN32
class TestThread {
public:
    TestThread() = default;

    template <typename Callable>
    explicit TestThread(Callable &&callable) {
        start(std::forward<Callable>(callable));
    }

    TestThread(const TestThread &) = delete;
    TestThread &operator=(const TestThread &) = delete;

    TestThread(TestThread &&other) noexcept : handle_(other.handle_) {
        other.handle_ = nullptr;
    }

    TestThread &operator=(TestThread &&other) noexcept {
        if (this != &other) {
            join();
            handle_ = other.handle_;
            other.handle_ = nullptr;
        }
        return *this;
    }

    ~TestThread() { join(); }

    template <typename Callable>
    void start(Callable &&callable) {
        using Task = std::function<void()>;
        auto *task = new Task(std::forward<Callable>(callable));
        unsigned thread_id = 0;
        handle_ = reinterpret_cast<HANDLE>(_beginthreadex(
            nullptr, 0, &TestThread::run, task, 0, &thread_id));
    }

    void join() {
        if (!handle_) {
            return;
        }
        WaitForSingleObject(handle_, INFINITE);
        CloseHandle(handle_);
        handle_ = nullptr;
    }

private:
    static unsigned __stdcall run(void *arg) {
        using Task = std::function<void()>;
        std::unique_ptr<Task> task(static_cast<Task *>(arg));
        (*task)();
        return 0;
    }

    HANDLE handle_{nullptr};
};
#else
using TestThread = std::thread;
#endif

static void sleep_for_ms(int milliseconds) {
#ifdef _WIN32
    Sleep(static_cast<DWORD>(milliseconds));
#else
    std::this_thread::sleep_for(std::chrono::milliseconds(milliseconds));
#endif
}

/**
 * Stress test: Rapidly execute many simple sync commands in serial.
 * Ensures that handle creation/release in a loop is stable.
 */
TEST_F(StressTest, SerialSyncHammer) {
    const int iterations = 50;
    for (int i = 0; i < iterations; ++i) {
        FFmpegSessionHandle session = ffmpeg_kit_execute("-version");
        ASSERT_NE(session, nullptr);
        EXPECT_EQ(ffmpeg_kit_session_get_state(session), FFMPEG_KIT_SESSION_STATE_COMPLETED);
        ffmpeg_kit_handle_release(session);
    }
}

/**
 * Stress test: Run many sync commands in parallel across multiple threads.
 * Tests thread safety of the global session history and handle management.
 */
TEST_F(StressTest, ParallelSyncHammer) {
    const int thread_count = 10;
    const int iterations_per_thread = 10;
    std::vector<TestThread> threads;

    for (int t = 0; t < thread_count; ++t) {
        threads.emplace_back([iterations_per_thread]() {
            for (int i = 0; i < iterations_per_thread; ++i) {
                FFprobeSessionHandle session = ffprobe_kit_execute("-version");
                if (session) {
                    ffmpeg_kit_handle_release(session);
                }
            }
        });
    }

    for (auto& thread : threads) {
        thread.join();
    }
}

/**
 * Stress test: Fire a large burst of asynchronous executions.
 */
TEST_F(StressTest, AsyncBurstHammer) {
    const int burst_size = 50;
    std::atomic<int> completed_count{0};
    
    auto callback = [](FFmpegSessionHandle session, void* user_data) {
        auto* counter = static_cast<std::atomic<int>*>(user_data);
        (*counter)++;
        ffmpeg_kit_handle_release(session);
    };

    std::vector<FFmpegSessionHandle> handles;
    for (int i = 0; i < burst_size; ++i) {
        FFmpegSessionHandle session = ffmpeg_kit_execute_async("-version", callback, &completed_count);
        if (session) {
            handles.push_back(session);
        }
    }

    // Wait for all to complete with timeout
    auto start = std::chrono::steady_clock::now();
    while (completed_count < burst_size) {
        sleep_for_ms(100);
        auto elapsed = std::chrono::steady_clock::now() - start;
        if (elapsed > std::chrono::seconds(30)) {
            break;
        }
    }

    EXPECT_EQ(completed_count.load(), burst_size);

    for (auto handle : handles) {
        ffmpeg_kit_handle_release(handle);
    }
}

/**
 * Stress test: Rapidly create and clear session history while sessions are potentially active.
 */
TEST_F(StressTest, SessionHistoryConcurrency) {
    std::atomic<bool> stop{false};
    std::mutex handles_mutex;
    std::vector<FFmpegSessionHandle> handles;
    
    // Thread 1: Constantly creating sessions
    TestThread creator([&stop, &handles, &handles_mutex]() {
        while (!stop) {
            FFmpegSessionHandle s = ffmpeg_kit_execute_async("-version", nullptr, nullptr);
            if (s) {
                std::lock_guard<std::mutex> lock(handles_mutex);
                handles.push_back(s);
            }
            sleep_for_ms(2);
        }
    });

    // Run for a few seconds
    sleep_for_ms(5000);
    stop = true;
    creator.join();

    // Wait for any created sessions to leave RUNNING before clearing history.
    for (auto handle : handles) {
        int waited = 0;
        while (waited < 5000 &&
               ffmpeg_kit_session_get_state(handle) == FFMPEG_KIT_SESSION_STATE_RUNNING) {
            sleep_for_ms(50);
            waited += 50;
        }
    }

    ffmpeg_kit_config_clear_sessions();

    // Release all handles
    for (auto handle : handles) {
        ffmpeg_kit_handle_release(handle);
    }
}

/**
 * Stress test: Hammer FFplay creation/destruction.
 */
TEST_F(StressTest, FFplaySessionRecycling) {
    const int iterations = 10;
    for (int i = 0; i < iterations; ++i) {
        char cmd[512];
        snprintf(cmd, sizeof(cmd), "-autoexit -t 0.1 %s", TEST_VIDEO_FILE);
        
        FFplaySessionHandle session = ffplay_kit_execute(cmd, 1000);
        if (session) {
            ffmpeg_kit_handle_release(session);
        }
    }
}

/**
 * Stress test: Mixed Session Types.
 */
TEST_F(StressTest, MixedHammer) {
    const int iterations = 20;
    for (int i = 0; i < iterations; ++i) {
        // Launch one of each
        FFmpegSessionHandle s1 = ffmpeg_kit_execute_async("-version", nullptr, nullptr);
        FFprobeSessionHandle s2 = ffprobe_kit_execute_async("-version", nullptr, nullptr);
        MediaInformationSessionHandle s3 = ffprobe_kit_get_media_information_async(TEST_VIDEO_FILE, nullptr, nullptr);
        
        sleep_for_ms(50);
        
        if (s1) ffmpeg_kit_handle_release(s1);
        if (s2) ffmpeg_kit_handle_release(s2);
        if (s3) ffmpeg_kit_handle_release(s3);
    }
}
