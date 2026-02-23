/*
 * Copyright (c) 2025 Akash Patel
 *
 * This file is part of FFmpegKit.
 *
 * FFmpegKit is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * FFmpegKit is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with FFmpegKit.  If not, see <http://www.gnu.org/licenses/>.
 */

#include "ffmpegkit_wrapper.h"
#include "AbstractSession.hpp"
#include "Chapter.hpp"
#include "FFmpegKit.hpp"
#include "FFmpegKitConfig.hpp"
#include "FFplayKit.hpp"
#include "FFprobeKit.hpp"
#include "MediaInformation.hpp"
#include "MediaInformationSession.hpp"
#include "Packages.hpp"
#include "StreamInformation.hpp"
#include "FFmpegKitObject.hpp"
#include "Statistics.hpp"
#include <cstring>
#include <thread>
#include <set>
#include <iostream>

#ifdef _WIN32
    #include <windows.h>
    #include <dbghelp.h>
    // Note: Link with -ldbghelp
#else
    #include <execinfo.h>
    #include <unistd.h>
#endif

// Macro to wrap the call with a header
#define PRINT_STACK_TRACE() \
    do { \
        std::cerr << "--- STACK TRACE TRIGGERED [" << __FILE__ << ":" << __LINE__ << "] ---" << std::endl; \
        internal_print_stack_trace(); \
    } while (0)

void internal_print_stack_trace() {
#ifdef _WIN32
    void* stack[100];
    HANDLE process = GetCurrentProcess();
    
    // Initialize symbols for the current process
    SymInitialize(process, NULL, TRUE);

    // Capture the backtrace
    WORD frames = CaptureStackBackTrace(0, 100, stack, NULL);
    
    SYMBOL_INFO* symbol = (SYMBOL_INFO*)calloc(1, sizeof(SYMBOL_INFO) + 256 * sizeof(char));
    symbol->MaxNameLen = 255;
    symbol->SizeOfStruct = sizeof(SYMBOL_INFO);

    for (WORD i = 0; i < frames; i++) {
        SymFromAddr(process, (DWORD64)(stack[i]), 0, symbol);
        std::cerr << i << ": " << symbol->Name << " - 0x" << symbol->Address << std::endl;
    }

    free(symbol);
    // Note: SymCleanup(process) is omitted here so symbols stay cached for future crashes
#else
    void* array[20];
    size_t size = backtrace(array, 20);
    
    // backtrace_symbols_fd writes directly to a file descriptor (2 = stderr)
    // This is the safest way during a crash because it avoids malloc
    backtrace_symbols_fd(array, size, STDERR_FILENO);
#endif
}

using namespace ffmpegkit;

static std::mutex g_handle_mutex;
static std::set<void *> g_active_handles;


// ---- Helpers ----

static char *strdup_cpp(const std::string &str) {
  char *copy = (char *)malloc(str.size() + 1);
  if (copy) {
    std::strcpy(copy, str.c_str());
  }
  return copy;
}

static char *strdup_safe_ptr(std::shared_ptr<std::string> strPtr) {
  if (!strPtr)
    return nullptr;
  return strdup_cpp(*strPtr);
}

template <typename T> static std::shared_ptr<T> get_ptr_internal(void *handle) {
  if (!handle || g_active_handles.find(handle) == g_active_handles.end())
    return nullptr;
  auto obj_ptr = *static_cast<std::shared_ptr<FFmpegKitObject> *>(handle);
  return std::dynamic_pointer_cast<T>(obj_ptr);
}

template <typename T> static std::shared_ptr<T> get_ptr(void *handle) {
  std::lock_guard<std::mutex> lock(g_handle_mutex);
  return get_ptr_internal<T>(handle);
}

template <typename T> static void *create_handle(std::shared_ptr<T> ptr) {
  if (!ptr)
    return nullptr;
  std::lock_guard<std::mutex> lock(g_handle_mutex);
  // Cast to FFmpegKitObject shared_ptr to allow dynamic casting later
  void *handle = new std::shared_ptr<FFmpegKitObject>(
      std::static_pointer_cast<FFmpegKitObject>(ptr));
  g_active_handles.insert(handle);
  return handle;
}

template <typename T>
static void **
list_to_handle_array(std::shared_ptr<std::list<std::shared_ptr<T>>> list) {
  try {
  if (!list)
    return nullptr;
  size_t size = list->size();
  void **array = (void **)malloc((size + 1) * sizeof(void *));
  if (!array)
    return nullptr;

  size_t i = 0;
  for (auto &item : *list) {
    array[i++] = create_handle(item);
  }
  array[i] = nullptr;
  return array;
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in list_to_handle_array: " << e.what() << std::endl;
    PRINT_STACK_TRACE();
    return nullptr;
  }
}

extern "C" {

void ffmpeg_kit_handle_release(void *handle) {
  try {
  if (handle) {
    std::shared_ptr<Session> session;

    {
      std::lock_guard<std::mutex> lock(g_handle_mutex);
      auto it = g_active_handles.find(handle);
      if (it == g_active_handles.end()) {
        return;
      }

      // Safely check if it's a session before calling cancel
      session = get_ptr_internal<Session>(handle);

      // Remove from active handles immediately to prevent double-release or use during shutdown
      g_active_handles.erase(it);
    }

    if (session) {
      session->cancel();
      /**
       * Block destruction until the native background thread has gracefully exited.
       * Prevents use-after-free crashes caused by asynchronous log callbacks
       * (especially under high I/O like -loglevel debug) attempting to access
       * destroyed session structures or mutexes.
       */
      while (session->getState() == SessionStateRunning) {
        std::this_thread::sleep_for(std::chrono::milliseconds(10));
      }
    }

    delete static_cast<std::shared_ptr<FFmpegKitObject> *>(handle);
  }
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_handle_release: " << e.what() << std::endl;
    PRINT_STACK_TRACE();
  }
}

void ffmpeg_kit_config_clear_sessions() { 
  try {
    FFmpegKitConfig::clearSessions();
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_config_clear_sessions: " << e.what() << std::endl;
    PRINT_STACK_TRACE();
  }
}

/* FFmpegKit */

FFmpegSessionHandle ffmpeg_kit_execute(const char *command) {
  try {
  if (!command)
    return nullptr;
  auto session = FFmpegKit::execute(std::string(command));
  return create_handle(session);
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_execute: " << e.what() << std::endl;
    PRINT_STACK_TRACE();
    return nullptr;
  }
}

FFmpegSessionHandle
ffmpeg_kit_execute_async(const char *command,
                         FFmpegKitCompleteCallback complete_cb,
                         void *user_data) {
  try {
  if (!command)
    return nullptr;
  auto lambda = [complete_cb, user_data](std::shared_ptr<Session> s) {
    if (complete_cb) {
      auto handle = create_handle(std::dynamic_pointer_cast<FFmpegSession>(s));
      complete_cb(handle, user_data);
      // Handle ownership transferred to Dart callback
    }
  };
  auto session = FFmpegKit::executeAsync(std::string(command), lambda);
  return create_handle(session);
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_execute_async: " << e.what() << std::endl;
    PRINT_STACK_TRACE();
    return nullptr;
  }
}

FFmpegSessionHandle ffmpeg_kit_execute_async_full(
    const char *command, FFmpegKitCompleteCallback complete_cb,
    FFmpegKitLogCallback log_cb, FFmpegKitStatisticsCallback stats_cb,
    void *user_data, int64_t waitTimeout) {
  try {
  if (!command)
    return nullptr;
  auto complete = [complete_cb, user_data](std::shared_ptr<Session> s) {
    if (complete_cb) {
      auto handle = create_handle(std::dynamic_pointer_cast<FFmpegSession>(s));
      complete_cb(handle, user_data);
      // Handle ownership transferred to Dart callback
    }
  };
  auto log = [log_cb, user_data](std::shared_ptr<Log> l) {
    if (log_cb && l) {
      const std::string& message = l->getMessage();
      
      // Pass ID as pointer (Hack to avoid allocation/threading issues)
      void *session_handle = (void *)(uintptr_t)l->getSessionId();

      log_cb(session_handle, message.c_str(), user_data);
    }
  };
  auto stats = [stats_cb, user_data](std::shared_ptr<Statistics> s) {
    if (stats_cb && s) {
      // Pass ID as pointer (Hack to avoid allocation/threading issues)
      void *session_handle = (void *)(uintptr_t)s->getSessionId();

      stats_cb(session_handle, s->getTime(), s->getSize(), s->getBitrate(),
               s->getSpeed(), s->getVideoFrameNumber(), s->getVideoFps(),
               s->getVideoQuality(), user_data);
    }
  };

  auto session =
      FFmpegKit::executeAsync(std::string(command), complete, log, stats);
  return create_handle(session);
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_execute_async_full: " << e.what() << std::endl;
    PRINT_STACK_TRACE();
    return nullptr;
  }
}

FFmpegSessionHandle ffmpeg_kit_create_session(const char *command) {
  try {
  if (!command)
    return nullptr;
  auto arguments = FFmpegKitConfig::parseArguments(command);
  auto session = FFmpegSession::create(arguments);
  return create_handle(session);
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_create_session: " << e.what() << std::endl;
    PRINT_STACK_TRACE();
    return nullptr;
  }
}

void ffmpeg_kit_session_execute(FFmpegSessionHandle session) {
  try {
  auto ptr = get_ptr<FFmpegSession>(session);
  if (ptr) {
    FFmpegKitConfig::ffmpegExecute(ptr);
  }
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_session_execute: " << e.what() << std::endl;
    PRINT_STACK_TRACE();
  }
}

void ffmpeg_kit_session_execute_async(FFmpegSessionHandle session) {
  try {
  auto ptr = get_ptr<FFmpegSession>(session);
  if (ptr) {
    FFmpegKitConfig::asyncFFmpegExecute(ptr);
  }
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_session_execute_async: " << e.what() << std::endl;
    PRINT_STACK_TRACE();
  }
}

void ffmpeg_kit_cancel(void) { 
  try {
    FFmpegKit::cancel();
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_cancel: " << e.what() << std::endl;
    PRINT_STACK_TRACE();
  }
}

void ffmpeg_kit_cancel_session(int64_t session_id) {
  try {
    FFmpegKit::cancel(session_id);
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_cancel_session: " << e.what() << std::endl;
    PRINT_STACK_TRACE();
  }
}

/* FFprobeKit */

FFprobeSessionHandle ffprobe_kit_execute(const char *command) {
  try {
  if (!command)
    return nullptr;
  auto session = FFprobeKit::execute(std::string(command));
  return create_handle(session);
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffprobe_kit_execute: " << e.what() << std::endl;
    PRINT_STACK_TRACE();
    return nullptr;
  }
}

FFprobeSessionHandle
ffprobe_kit_execute_async(const char *command,
                          FFprobeKitCompleteCallback complete_cb,
                          void *user_data) {
  try {
  if (!command)
    return nullptr;
  auto lambda = [complete_cb, user_data](std::shared_ptr<Session> s) {
    if (complete_cb) {
      auto handle = create_handle(std::dynamic_pointer_cast<FFprobeSession>(s));
      complete_cb(handle, user_data);
      // Handle ownership transferred to Dart callback
    }
  };
  auto session = FFprobeKit::executeAsync(std::string(command), lambda);
  return create_handle(session);
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffprobe_kit_execute_async: " << e.what() << std::endl;
    PRINT_STACK_TRACE();
    return nullptr;
  }
}

FFprobeSessionHandle ffprobe_kit_create_session(const char *command) {
  try {
  if (!command)
    return nullptr;
  auto arguments = FFmpegKitConfig::parseArguments(command);
  auto session = FFprobeSession::create(arguments);
  return create_handle(session);
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffprobe_kit_create_session: " << e.what() << std::endl;
    PRINT_STACK_TRACE();
    return nullptr;
  }
}

void ffprobe_kit_session_execute(FFprobeSessionHandle session) {
  try {
  auto ptr = get_ptr<FFprobeSession>(session);
  if (ptr) {
    FFmpegKitConfig::ffprobeExecute(ptr);
  }
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffprobe_kit_session_execute: " << e.what() << std::endl;
    PRINT_STACK_TRACE();
  }
}

void ffprobe_kit_session_execute_async(FFprobeSessionHandle session) {
  try {
  auto ptr = get_ptr<FFprobeSession>(session);
  if (ptr) {
    FFmpegKitConfig::asyncFFprobeExecute(ptr);
  }
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffprobe_kit_session_execute_async: " << e.what() << std::endl;
    PRINT_STACK_TRACE();
  }
}

MediaInformationSessionHandle
ffprobe_kit_get_media_information(const char *path) {
  try {
  if (!path)
    return nullptr;
  auto session = FFprobeKit::getMediaInformation(std::string(path));
  return create_handle(session);
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffprobe_kit_get_media_information: " << e.what() << std::endl;
    PRINT_STACK_TRACE();
    return nullptr;
  }
}

MediaInformationSessionHandle ffprobe_kit_get_media_information_async(
    const char *path, ::MediaInformationSessionCompleteCallback complete_cb,
    void *user_data) {
  try {
  if (!path)
    return nullptr;
  auto lambda = [complete_cb,
                 user_data](std::shared_ptr<MediaInformationSession> s) {
    if (complete_cb) {
      auto handle = create_handle(s);
      complete_cb(handle, user_data);
      // Handle ownership transferred to Dart callback
    }
  };
  auto session =
      FFprobeKit::getMediaInformationAsync(std::string(path), lambda);
  return create_handle(session);
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffprobe_kit_get_media_information_async: " << e.what() << std::endl;
    PRINT_STACK_TRACE();
    return nullptr;
  }
}

/* FFplayKit */

FFplaySessionHandle ffplay_kit_execute(const char *command, int64_t timeout) {
  try {
  if (!command)
    return nullptr;
  auto session = FFplayKit::execute(std::string(command), timeout);
  return create_handle(session);
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffplay_kit_execute: " << e.what() << std::endl;
    PRINT_STACK_TRACE();
    return nullptr;
  }
}

FFplaySessionHandle
ffplay_kit_execute_async(const char *command,
                         FFplayKitCompleteCallback complete_cb,
                         void *user_data, int64_t waitTimeout) {
  try {
  if (!command)
    return nullptr;
  auto lambda = [complete_cb, user_data](std::shared_ptr<Session> s) {
    if (complete_cb) {
      auto handle = create_handle(std::dynamic_pointer_cast<FFplaySession>(s));
      complete_cb(handle, user_data);
      // Handle ownership transferred to Dart callback
    }
  };
  auto session = FFplayKit::executeAsync(std::string(command), lambda, waitTimeout);
  return create_handle(session);
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffplay_kit_execute_async: " << e.what() << std::endl;
    PRINT_STACK_TRACE();
    return nullptr;
  }
}

FFplaySessionHandle ffplay_kit_create_session(const char *command) {
  try {
  if (!command)
    return nullptr;
  auto arguments = FFmpegKitConfig::parseArguments(command);
  auto session = FFplaySession::create(arguments);
  return create_handle(session);
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffplay_kit_create_session: " << e.what() << std::endl;
    PRINT_STACK_TRACE();
    return nullptr;
  }
}

void ffplay_kit_session_execute(FFplaySessionHandle session, int64_t timeout) {
  try {
  auto ptr = get_ptr<FFplaySession>(session);
  if (ptr) {  
    FFmpegKitConfig::ffplayExecute(ptr, timeout);
  }
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffplay_kit_session_execute: " << e.what() << std::endl;
    PRINT_STACK_TRACE();
  }
}

FFplaySessionHandle ffplay_kit_get_current_session(void) {
  try {
  auto session = FFmpegKitConfig::getActiveFFplaySession();
  return create_handle(std::dynamic_pointer_cast<FFplaySession>(session));
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffplay_kit_get_current_session: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}

void ffplay_kit_session_execute_async(FFplaySessionHandle session, int64_t timeout) {
  try {
  auto ptr = get_ptr<FFplaySession>(session);
  if (ptr) {
    FFmpegKitConfig::asyncFFplayExecute(ptr, timeout);
  }
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffplay_kit_session_execute_async: " << e.what() << std::endl;
    PRINT_STACK_TRACE();  }
}

void ffplay_kit_session_seek(FFplaySessionHandle session, double seconds) {
  try {
  auto ptr = get_ptr<FFplaySession>(session);
  if (ptr) {
    ptr->seek(seconds);
  }
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffplay_kit_session_seek: " << e.what() << std::endl;
    PRINT_STACK_TRACE();  }
}

void ffplay_kit_session_pause(FFplaySessionHandle session) {
  try {
  auto ptr = get_ptr<FFplaySession>(session);
  if (ptr) {
    ptr->pause();
  }
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffplay_kit_session_pause: " << e.what() << std::endl;
    PRINT_STACK_TRACE();  }
}

void ffplay_kit_session_start(FFplaySessionHandle session) {
  try {
  auto ptr = get_ptr<FFplaySession>(session);
  if (ptr) {
    ptr->start();
  }
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffplay_kit_session_start: " << e.what() << std::endl;
    PRINT_STACK_TRACE();  }
}

void ffplay_kit_session_resume(FFplaySessionHandle session) {
  try {
  auto ptr = get_ptr<FFplaySession>(session);
  if (ptr) {
    ptr->resume();
  }
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffplay_kit_session_resume: " << e.what() << std::endl;
    PRINT_STACK_TRACE();  }
}

void ffplay_kit_session_stop(FFplaySessionHandle session) {
  try {
  auto ptr = get_ptr<FFplaySession>(session);
  if (ptr) {
    ptr->stop();
  }
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffplay_kit_session_stop: " << e.what() << std::endl;
    PRINT_STACK_TRACE();  }
}

void ffplay_kit_session_close(FFplaySessionHandle session) {
  try {
  auto ptr = get_ptr<FFplaySession>(session);
  if (ptr) {
    ptr->close();
  }
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffplay_kit_session_close: " << e.what() << std::endl;
    PRINT_STACK_TRACE();  }
}

double ffplay_kit_session_get_position(FFplaySessionHandle session) {
  try {
  auto ptr = get_ptr<FFplaySession>(session);
  if (ptr) {
    return ptr->getPosition();
  }
  return 0.0;
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffplay_kit_session_get_position: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return -1.0;
  }
}

void ffplay_kit_session_set_position(FFplaySessionHandle session, double seconds) {
  try {
  auto ptr = get_ptr<FFplaySession>(session);
  if (ptr) {
    ptr->setPosition(seconds);
  }
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffplay_kit_session_set_position: " << e.what() << std::endl;
    PRINT_STACK_TRACE();  }
}

double ffplay_kit_session_get_duration(FFplaySessionHandle session) {
  try {
  auto ptr = get_ptr<FFplaySession>(session);
  if (ptr) {
    return ptr->getDuration();
  }
  return 0.0;
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffplay_kit_session_get_duration: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return -1.0;
  }
}

bool ffplay_kit_session_is_playing(FFplaySessionHandle session) {
  try {
  auto ptr = get_ptr<FFplaySession>(session);
  if (ptr) {
    return ptr->isPlaying();
  }
  return false;
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffplay_kit_session_is_playing: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return false;
  }
}

bool ffplay_kit_session_is_paused(FFplaySessionHandle session) {
  try {
  auto ptr = get_ptr<FFplaySession>(session);
  if (ptr) {
    return ptr->isPaused();
  }
  return false;
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffplay_kit_session_is_paused: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return false;
  }
}

void ffplay_kit_session_set_volume(FFplaySessionHandle session, double volume) {
  try {
  auto ptr = get_ptr<FFplaySession>(session);
  if (ptr) {
    ptr->setVolume(volume);
  }
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffplay_kit_session_set_volume: " << e.what() << std::endl;
    PRINT_STACK_TRACE();  }
}

double ffplay_kit_session_get_volume(FFplaySessionHandle session) {
  try {
  auto ptr = get_ptr<FFplaySession>(session);
  if (ptr) {
    return ptr->getVolume();
  }
  return 0.0;
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffplay_kit_session_get_volume: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return -1.0;
  }
}

void ffplay_kit_seek(double seconds) { 
  try {
  FFplayKit::seek(seconds); 
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffplay_kit_seek: " << e.what() << std::endl;
    PRINT_STACK_TRACE();  }
}

void ffplay_kit_start(void) { 
  try {
  FFplayKit::start(); 
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffplay_kit_start: " << e.what() << std::endl;
    PRINT_STACK_TRACE();  }
}

void ffplay_kit_pause(void) { 
  try {
  FFplayKit::pause(); 
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffplay_kit_pause: " << e.what() << std::endl;
    PRINT_STACK_TRACE();  }
}

void ffplay_kit_resume(void) { 
  try {
  FFplayKit::resume(); 
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffplay_kit_resume: " << e.what() << std::endl;
    PRINT_STACK_TRACE();  }
}

void ffplay_kit_stop(void) { 
  try {
  FFplayKit::stop(); 
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffplay_kit_stop: " << e.what() << std::endl;
    PRINT_STACK_TRACE();  }
}

void ffplay_kit_close(void) { 
  try {
  FFplayKit::close(); 
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffplay_kit_close: " << e.what() << std::endl;
    PRINT_STACK_TRACE();  }
}

double ffplay_kit_get_position(void) { 
  try {
  return FFplayKit::getPosition(); 
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffplay_kit_get_position: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return -1.0;
  }
}

void ffplay_kit_set_position(double seconds) { 
  try {
  FFplayKit::setPosition(seconds); 
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffplay_kit_set_position: " << e.what() << std::endl;
    PRINT_STACK_TRACE();  }
}

double ffplay_kit_get_duration(void) { 
  try {
  return FFplayKit::getDuration(); 
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffplay_kit_get_duration: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return -1.0;
  }
}

bool ffplay_kit_is_playing(void) { 
  try {
  return FFplayKit::isPlaying(); 
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffplay_kit_is_playing: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return false;
  }
}

bool ffplay_kit_is_paused(void) { 
  try {
  return FFplayKit::isPaused(); 
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffplay_kit_is_paused: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return false;
  }
}

void ffplay_kit_set_volume(double volume) { 
  try {
  FFplayKit::setVolume(volume); 
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffplay_kit_set_volume: " << e.what() << std::endl;
    PRINT_STACK_TRACE();  }
}

double ffplay_kit_get_volume(void) { 
  try {
  return FFplayKit::getVolume(); 
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffplay_kit_get_volume: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return -1.0;
  }
}

/* Config */

void ffmpeg_kit_config_enable_redirection(void) {
  try {
  FFmpegKitConfig::enableRedirection();
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_config_enable_redirection: " << e.what() << std::endl;
    PRINT_STACK_TRACE();  }
}

void ffmpeg_kit_config_disable_redirection(void) {
  try {
  FFmpegKitConfig::disableRedirection();
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_config_disable_redirection: " << e.what() << std::endl;
    PRINT_STACK_TRACE();  }
}

void ffmpeg_kit_config_set_log_level(FFmpegKitLogLevel level) {
  try {
  FFmpegKitConfig::setLogLevel((Level)level);
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_config_set_log_level: " << e.what() << std::endl;
    PRINT_STACK_TRACE();  }
}

FFmpegKitLogLevel ffmpeg_kit_config_get_log_level(void) {
  try {
  return (FFmpegKitLogLevel)FFmpegKitConfig::getLogLevel();
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_config_get_log_level: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return FFmpegKitLogLevel::FFMPEG_KIT_LOG_LEVEL_INFO;
  }
}

char *ffmpeg_kit_config_log_level_to_string(FFmpegKitLogLevel level) {
  try {
  return strdup_cpp(FFmpegKitConfig::logLevelToString((Level)level));
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_config_log_level_to_string: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return strdup_cpp(FFmpegKitConfig::logLevelToString(Level::LevelAVLogInfo));
  }
}

void ffmpeg_kit_config_set_font_directory(const char *path,
                                          const char *name_mappings_json) {
  try {
  // Mapping JSON parsing omitted for brevity/simplicity as it requires a JSON
  // parser. Passing empty map for now if null.
  std::map<std::string, std::string> map;
  FFmpegKitConfig::setFontDirectory(path ? std::string(path) : "", map);
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_config_set_font_directory: " << e.what() << std::endl;
    PRINT_STACK_TRACE();  }
}

int64_t ffmpeg_kit_config_set_environment_variable(const char *name,
                                               const char *value) {
  try {
  if (!name || !value)
    return -1;
  return FFmpegKitConfig::setEnvironmentVariable(std::string(name),
                                                 std::string(value));
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_config_set_environment_variable: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return -1;
  }
}

void ffmpeg_kit_config_ignore_signal(FFmpegKitSignal signal) {
  try {
  FFmpegKitConfig::ignoreSignal((Signal)signal);
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_config_ignore_signal: " << e.what() << std::endl;
    PRINT_STACK_TRACE();  }
}

char *ffmpeg_kit_config_get_ffmpeg_version(void) {
  try {
  return strdup_cpp(FFmpegKitConfig::getFFmpegVersion());
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_config_get_ffmpeg_version: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}

char *ffmpeg_kit_config_get_ffmpeg_architecture(void) {
  try {
  return strdup_cpp(FFmpegKitConfig::getFFmpegArchitecture());
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_config_get_ffmpeg_architecture: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}

char *ffmpeg_kit_config_get_version(void) {
  try {
  return strdup_cpp(FFmpegKitConfig::getVersion());
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_config_get_version: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}

void ffmpeg_kit_config_set_audio_output_device(const char* device_name) {
  try {
  FFmpegKitConfig::setAudioOutputDevice(device_name ? std::string(device_name) : "");
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_config_set_audio_output_device: " << e.what() << std::endl;
    PRINT_STACK_TRACE();  }
}

char* ffmpeg_kit_config_list_audio_output_devices(void) {
  try {
  return strdup_cpp(FFmpegKitConfig::listAudioOutputDevices());
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_config_list_audio_output_devices: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}

/* Packages */

char *ffmpeg_kit_packages_get_package_name(void) {
  try {
  return strdup_cpp(Packages::getPackageName());
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_packages_get_package_name: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}

char *ffmpeg_kit_packages_get_bundled_libraries(void) {
  try {
  auto libs = Packages::getExternalLibraries();
  std::string result = "";
  for (const auto &lib : *libs) {
    if (!result.empty())
      result += ", ";
    result += lib;
  }
  return strdup_cpp(result);
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_packages_get_bundled_libraries: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}

char *ffmpeg_kit_packages_get_external_libraries(void) {
  try {
  auto libs = Packages::getExternalLibraries();
  std::string result = "";
  for (const auto &lib : *libs) {
    if (!result.empty())
      result += ", ";
    result += lib;
  }
  return strdup_cpp(result);
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_packages_get_external_libraries: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}

/* Session Management */

int64_t ffmpeg_kit_session_get_session_id(void *session_handle) {
  try {
  if (!session_handle)
    return -1;
  return get_ptr<Session>(session_handle)->getSessionId();
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_session_get_session_id: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return -1;
  }
}

FFmpegKitSessionState ffmpeg_kit_session_get_state(void *session_handle) {
  try {
  if (!session_handle)
    return FFMPEG_KIT_SESSION_STATE_CREATED;
  return (FFmpegKitSessionState)get_ptr<Session>(session_handle)->getState();
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_session_get_state: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return FFMPEG_KIT_SESSION_STATE_FAILED;
  }
}

int64_t ffmpeg_kit_session_get_return_code(void *session_handle) {
  try {
  if (!session_handle)
    return -1;
  auto obj = get_ptr<Session>(session_handle)->getReturnCode();
  return obj ? obj->getValue() : -1;
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_session_get_return_code: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return -1;
  }
}

char *ffmpeg_kit_session_get_output(void *session_handle) {
  try {
  if (!session_handle)
    return nullptr;
  return strdup_cpp(get_ptr<Session>(session_handle)->getOutput());
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_session_get_output: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}

char *ffmpeg_kit_session_get_logs_as_string(void *session_handle) {
  try {
  if (!session_handle)
    return nullptr;
  return strdup_cpp(get_ptr<Session>(session_handle)->getLogsAsString());
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_session_get_logs_as_string: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}

char *ffmpeg_kit_session_get_fail_stack_trace(void *session_handle) {
  try {
  if (!session_handle)
    return nullptr;
  return strdup_cpp(get_ptr<Session>(session_handle)->getFailStackTrace());
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_session_get_fail_stack_trace: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}

/* Media Information Session Specific */

MediaInformationSessionHandle media_information_create_session(
    const char *command) {
  try {
  if (!command)
    return nullptr;
  auto arguments = FFmpegKitConfig::parseArguments(command);
  auto session = MediaInformationSession::create(arguments);
  return create_handle(session);
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in media_information_create_session: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}

void media_information_session_execute(MediaInformationSessionHandle session, int64_t timeout) {
  try {
  auto ptr = get_ptr<MediaInformationSession>(session);
  if (ptr) {
    FFmpegKitConfig::getMediaInformationExecute(ptr, timeout);
  }
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in media_information_session_execute: " << e.what() << std::endl;
    PRINT_STACK_TRACE();  }
}

void media_information_session_execute_async(
    MediaInformationSessionHandle session, int64_t timeout) {
  try {
  auto ptr = get_ptr<MediaInformationSession>(session);
  if (ptr) {
    FFmpegKitConfig::asyncGetMediaInformationExecute(ptr, timeout);
  }
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in media_information_session_execute_async: " << e.what() << std::endl;
    PRINT_STACK_TRACE();  }
}

MediaInformationHandle media_information_session_get_media_information(
    MediaInformationSessionHandle session) {
  try {
  if (!session)
    return nullptr;
  auto info = get_ptr<MediaInformationSession>(session)->getMediaInformation();
  return create_handle(info);
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in media_information_session_get_media_information: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}

/* Media Information */

char *media_information_get_filename(MediaInformationHandle handle) {
  try {
  auto ptr = get_ptr<MediaInformation>(handle);
  return ptr ? strdup_safe_ptr(ptr->getFilename()) : nullptr;
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in media_information_get_filename: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}
char *media_information_get_format(MediaInformationHandle handle) {
  try {
  auto ptr = get_ptr<MediaInformation>(handle);
  return ptr ? strdup_safe_ptr(ptr->getFormat()) : nullptr;
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in media_information_get_format: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}
char *media_information_get_long_format(MediaInformationHandle handle) {
  try {
  auto ptr = get_ptr<MediaInformation>(handle);
  return ptr ? strdup_safe_ptr(ptr->getLongFormat()) : nullptr;
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in media_information_get_long_format: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}
char *media_information_get_duration(MediaInformationHandle handle) {
  try {
  auto ptr = get_ptr<MediaInformation>(handle);
  return ptr ? strdup_safe_ptr(ptr->getDuration()) : nullptr;
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in media_information_get_duration: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}
char *media_information_get_bitrate(MediaInformationHandle handle) {
  try {
  auto ptr = get_ptr<MediaInformation>(handle);
  return ptr ? strdup_safe_ptr(ptr->getBitrate()) : nullptr;
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in media_information_get_bitrate: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}
char *media_information_get_size(MediaInformationHandle handle) {
  try {
  auto ptr = get_ptr<MediaInformation>(handle);
  return ptr ? strdup_safe_ptr(ptr->getSize()) : nullptr;
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in media_information_get_size: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}
char *media_information_get_tags_json(MediaInformationHandle handle) {
  try {
  auto ptr = get_ptr<MediaInformation>(handle);
  if (!ptr)
    return nullptr;
  auto tags = ptr->getTags();
  return tags ? strdup_cpp(tags->toStyledString()) : nullptr;
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in media_information_get_tags_json: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}

int64_t media_information_get_streams_count(MediaInformationHandle handle) {
  try {
  if (!handle)
    return 0;
  auto streams = get_ptr<MediaInformation>(handle)->getStreams();
  return streams ? streams->size() : 0;
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in media_information_get_streams_count: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return -1;
  }
}

StreamInformationHandle
media_information_get_stream_at(MediaInformationHandle handle, int64_t index) {
  try {
  if (!handle)
    return nullptr;
  auto streams = get_ptr<MediaInformation>(handle)->getStreams();
  if (streams && index >= 0 && index < streams->size()) {
    return create_handle(streams->at(index));
  }
  return nullptr;
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in media_information_get_stream_at: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}

int64_t media_information_get_chapters_count(MediaInformationHandle handle) {
  try {
  if (!handle)
    return 0;
  auto chapters = get_ptr<MediaInformation>(handle)->getChapters();
  return chapters ? chapters->size() : 0;
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in media_information_get_chapters_count: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return -1;
  }
}

ChapterHandle media_information_get_chapter_at(MediaInformationHandle handle,
                                               int64_t index) {
  try {
  if (!handle)
    return nullptr;
  auto chapters = get_ptr<MediaInformation>(handle)->getChapters();
  if (chapters && index >= 0 && index < chapters->size()) {
    return create_handle(chapters->at(index));
  }
  return nullptr;
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in media_information_get_chapter_at: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}

/* Stream Information */

#define STREAM_GETTER(Func, Type)                                              \
  Type *stream_information_get_##Func(StreamInformationHandle handle) {        \
    return strdup_safe_ptr(get_ptr<StreamInformation>(handle)->get##Func());   \
  }

char *stream_information_get_type(StreamInformationHandle handle) {
  try {
  return strdup_safe_ptr(get_ptr<StreamInformation>(handle)->getType());
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in stream_information_get_type: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}
char *stream_information_get_codec(StreamInformationHandle handle) {
  try {
  return strdup_safe_ptr(get_ptr<StreamInformation>(handle)->getCodec());
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in stream_information_get_codec: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}
char *stream_information_get_codec_long(StreamInformationHandle handle) {
  try {
  return strdup_safe_ptr(get_ptr<StreamInformation>(handle)->getCodecLong());
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in stream_information_get_codec_long: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}
char *stream_information_get_format(StreamInformationHandle handle) {
  try {
  return strdup_safe_ptr(get_ptr<StreamInformation>(handle)->getFormat());
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in stream_information_get_format: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}
char *stream_information_get_bitrate(StreamInformationHandle handle) {
  try {
  return strdup_safe_ptr(get_ptr<StreamInformation>(handle)->getBitrate());
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in stream_information_get_bitrate: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}
char *stream_information_get_sample_rate(StreamInformationHandle handle) {
  try {
  return strdup_safe_ptr(get_ptr<StreamInformation>(handle)->getSampleRate());
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in stream_information_get_sample_rate: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}
char *stream_information_get_sample_format(StreamInformationHandle handle) {
  try {
  return strdup_safe_ptr(get_ptr<StreamInformation>(handle)->getSampleFormat());
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in stream_information_get_sample_format: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}
char *
stream_information_get_display_aspect_ratio(StreamInformationHandle handle) {
  try {
  return strdup_safe_ptr(
      get_ptr<StreamInformation>(handle)->getDisplayAspectRatio());
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in stream_information_get_display_aspect_ratio: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}
char *
stream_information_get_average_frame_rate(StreamInformationHandle handle) {
  try {
  return strdup_safe_ptr(
      get_ptr<StreamInformation>(handle)->getAverageFrameRate());
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in stream_information_get_average_frame_rate: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}
char *stream_information_get_real_frame_rate(StreamInformationHandle handle) {
  try {
  return strdup_safe_ptr(
      get_ptr<StreamInformation>(handle)->getRealFrameRate());
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in stream_information_get_real_frame_rate: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}
char *stream_information_get_time_base(StreamInformationHandle handle) {
  try {
  return strdup_safe_ptr(get_ptr<StreamInformation>(handle)->getTimeBase());
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in stream_information_get_time_base: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}

int64_t stream_information_get_width(StreamInformationHandle handle) {
  try {
  if (!handle)
    return 0;
  auto val = get_ptr<StreamInformation>(handle)->getWidth();
  return val ? *val : 0;
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in stream_information_get_width: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return -1;
  }
}
int64_t stream_information_get_height(StreamInformationHandle handle) {
  try {
  if (!handle)
    return 0;
  auto val = get_ptr<StreamInformation>(handle)->getHeight();
  return val ? *val : 0;
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in stream_information_get_height: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return -1;
  }
}
int64_t stream_information_get_index(StreamInformationHandle handle) {
  try {
  if (!handle)
    return -1;
  auto val = get_ptr<StreamInformation>(handle)->getIndex();
  return val ? *val : -1;
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in stream_information_get_index: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return -1;
  }
}
char *stream_information_get_tags_json(StreamInformationHandle handle) {
  try {
  auto tags = get_ptr<StreamInformation>(handle)->getTags();
  return tags ? strdup_cpp(tags->toStyledString()) : nullptr;
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in stream_information_get_tags_json: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}

/* Chapter */
int64_t chapter_get_id(ChapterHandle handle) {
  try {
  if (!handle)
    return -1;
  auto val = get_ptr<Chapter>(handle)->getId();
  return val ? *val : -1;
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in chapter_get_id: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return -1;
  }
}
char *chapter_get_time_base(ChapterHandle handle) {
  try {
  return strdup_safe_ptr(get_ptr<Chapter>(handle)->getTimeBase());
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in chapter_get_time_base: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}
int64_t chapter_get_start(ChapterHandle handle) {
  try {
  if (!handle)
    return -1;
  auto val = get_ptr<Chapter>(handle)->getStart();
  return val ? *val : -1;
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in chapter_get_start: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return -1;
  }
}
char *chapter_get_start_time(ChapterHandle handle) {
  try {
  return strdup_safe_ptr(get_ptr<Chapter>(handle)->getStartTime());
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in chapter_get_start_time: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}
int64_t chapter_get_end(ChapterHandle handle) {
  try {
  if (!handle)
    return -1;
  auto val = get_ptr<Chapter>(handle)->getEnd();
  return val ? *val : -1;
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in chapter_get_end: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return -1;
  }
}
char *chapter_get_end_time(ChapterHandle handle) {
  try {
  return strdup_safe_ptr(get_ptr<Chapter>(handle)->getEndTime());
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in chapter_get_end_time: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}
char *chapter_get_tags_json(ChapterHandle handle) {
  try {
  auto tags = get_ptr<Chapter>(handle)->getTags();
  return tags ? strdup_cpp(tags->toStyledString()) : nullptr;
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in chapter_get_tags_json: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}

/* Session History */
FFmpegSessionHandle *ffmpeg_kit_get_sessions(void) {
  try {
  return (FFmpegSessionHandle *)list_to_handle_array(
      FFmpegKitConfig::getSessions());
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_get_sessions: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}
FFmpegSessionHandle *ffmpeg_kit_list_sessions(void) {
  try {
  return ffmpeg_kit_get_sessions();
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_list_sessions: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}

FFmpegSessionHandle *ffmpeg_kit_get_ffmpeg_sessions(void) {
  try {
  return (FFmpegSessionHandle *)list_to_handle_array(
      FFmpegKitConfig::getFFmpegSessions());
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_get_ffmpeg_sessions: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}

FFprobeSessionHandle *ffmpeg_kit_get_ffprobe_sessions(void) {
  try {
  return (FFprobeSessionHandle *)list_to_handle_array(
      FFmpegKitConfig::getFFprobeSessions());
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_get_ffprobe_sessions: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}
FFprobeSessionHandle *ffprobe_kit_list_sessions(void) {
  try {
  return ffmpeg_kit_get_ffprobe_sessions();
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffprobe_kit_list_sessions: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}

FFplaySessionHandle *ffmpeg_kit_get_ffplay_sessions(void) {
  try {
  return (FFplaySessionHandle *)list_to_handle_array(
      FFmpegKitConfig::getFFplaySessions());
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_get_ffplay_sessions: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}

MediaInformationSessionHandle *ffmpeg_kit_get_media_information_sessions(void) {
  try {
  return (MediaInformationSessionHandle *)list_to_handle_array(
      FFmpegKitConfig::getMediaInformationSessions());
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_get_media_information_sessions: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}
MediaInformationSessionHandle *media_information_kit_list_sessions(void) {
  try {
  return ffmpeg_kit_get_media_information_sessions();
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in media_information_kit_list_sessions: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}

FFmpegSessionHandle ffmpeg_kit_get_session(int64_t session_id) {
  try {
  return create_handle(FFmpegKitConfig::getSession(session_id));
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_get_session: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}

FFmpegSessionHandle ffmpeg_kit_get_last_session(void) {
  try {
  return create_handle(FFmpegKitConfig::getLastSession());
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_get_last_session: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}

FFmpegSessionHandle ffmpeg_kit_get_last_ffmpeg_session(void) {
  try {
  return create_handle(FFmpegKitConfig::getLastFFmpegSession());
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_get_last_ffmpeg_session: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}

FFprobeSessionHandle ffmpeg_kit_get_last_ffprobe_session(void) {
  try {
  return create_handle(FFmpegKitConfig::getLastFFprobeSession());
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_get_last_ffprobe_session: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}
FFprobeSessionHandle ffprobe_kit_get_last_session(void) {
  try {
  return ffmpeg_kit_get_last_ffprobe_session();
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffprobe_kit_get_last_session: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}
FFprobeSessionHandle ffprobe_kit_get_last_completed_session(void) {
  // Simplification: return last completed regardless of type or find first ffprobe from end
  // For now return last completed if it is ffprobe
  try {
  auto session = FFmpegKitConfig::getLastCompletedSession();
  if (session && session->isFFprobe()) {
      return create_handle(session);
  }
  return nullptr;
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffprobe_kit_get_last_completed_session: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}

FFplaySessionHandle ffmpeg_kit_get_last_ffplay_session(void) {
  try {
  return create_handle(FFmpegKitConfig::getLastFFplaySession());
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_get_last_ffplay_session: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}

MediaInformationSessionHandle ffmpeg_kit_get_last_media_information_session(void) {
  try {
  return create_handle(FFmpegKitConfig::getLastMediaInformationSession());
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_get_last_media_information_session: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}

FFmpegSessionHandle ffmpeg_kit_get_last_completed_session(void) {
  try {
  return create_handle(FFmpegKitConfig::getLastCompletedSession());
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_get_last_completed_session: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}

int64_t ffmpeg_kit_get_session_history_size(void) {
  try {
  return FFmpegKitConfig::getSessionHistorySize();
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_get_session_history_size: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return -1;
  }
}

void ffmpeg_kit_set_session_history_size(int64_t size) {
  try {
  FFmpegKitConfig::setSessionHistorySize(size);
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_set_session_history_size: " << e.what() << std::endl;
    PRINT_STACK_TRACE();  }
}

void ffmpeg_kit_clear_sessions(void) {
  try {
  FFmpegKitConfig::clearSessions();
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_clear_sessions: " << e.what() << std::endl;
    PRINT_STACK_TRACE();  }
}

} /* End extern "C" */

/* Global Callbacks */
// Static storage for callbacks
static FFmpegKitLogCallback g_log_callback = nullptr;
static void *g_log_user_data = nullptr;

static FFmpegKitStatisticsCallback g_stats_callback = nullptr;
static void *g_stats_user_data = nullptr;

static FFmpegKitCompleteCallback g_ffmpeg_complete_callback = nullptr;
static void *g_ffmpeg_complete_user_data = nullptr;

static FFprobeKitCompleteCallback g_ffprobe_complete_callback = nullptr;
static void *g_ffprobe_complete_user_data = nullptr;

static FFplayKitCompleteCallback g_ffplay_complete_callback = nullptr;
static void *g_ffplay_complete_user_data = nullptr;

static ::MediaInformationSessionCompleteCallback g_media_complete_callback =
    nullptr;
static void *g_media_complete_user_data = nullptr;

extern "C" {
void ffmpeg_kit_config_enable_log_callback(FFmpegKitLogCallback log_cb,
                                           void *user_data) {
  try {
  g_log_callback = log_cb;
  g_log_user_data = user_data;
  if (log_cb) {
    FFmpegKitConfig::enableLogCallback([](std::shared_ptr<Log> log) {
      if (g_log_callback && log) {
        const std::string& message = log->getMessage();

        // Pass ID as pointer (Hack to avoid allocation/threading issues)
        void *session_handle = (void *)(uintptr_t)log->getSessionId();

        g_log_callback(session_handle, message.c_str(), g_log_user_data);
      }
    });
  } else {
    FFmpegKitConfig::enableLogCallback(nullptr);
  }
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_config_enable_log_callback: " << e.what() << std::endl;
    PRINT_STACK_TRACE();  }
}

void ffmpeg_kit_config_enable_statistics_callback(
    FFmpegKitStatisticsCallback stats_cb, void *user_data) {
  try {
  g_stats_callback = stats_cb;
  g_stats_user_data = user_data;
  if (stats_cb) {
    FFmpegKitConfig::enableStatisticsCallback(
        [](std::shared_ptr<Statistics> s) {
          if (g_stats_callback && s) {
            // Pass ID as pointer (Hack to avoid allocation/threading issues)
            void *session_handle = (void *)(uintptr_t)s->getSessionId();

            g_stats_callback(session_handle, s->getTime(), s->getSize(),
                             s->getBitrate(), s->getSpeed(),
                             s->getVideoFrameNumber(), s->getVideoFps(),
                             s->getVideoQuality(), g_stats_user_data);
          }
        });
  } else {
    FFmpegKitConfig::enableStatisticsCallback(nullptr);
  }
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_config_enable_statistics_callback: " << e.what() << std::endl;
    PRINT_STACK_TRACE();  }
}

void ffmpeg_kit_config_enable_ffmpeg_session_complete_callback(
    FFmpegKitCompleteCallback complete_cb, void *user_data) {
  try {
  g_ffmpeg_complete_callback = complete_cb;
  g_ffmpeg_complete_user_data = user_data;
  if (complete_cb) {
    FFmpegKitConfig::enableFFmpegSessionCompleteCallback(
        [](std::shared_ptr<FFmpegSession> title) {
          if (g_ffmpeg_complete_callback) {
            auto handle = create_handle(title);
            g_ffmpeg_complete_callback(handle, g_ffmpeg_complete_user_data);
            // Handle ownership transferred to Dart callback
          }
        });
  } else {
    FFmpegKitConfig::enableFFmpegSessionCompleteCallback(nullptr);
  }
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_config_enable_ffmpeg_session_complete_callback: " << e.what() << std::endl;
    PRINT_STACK_TRACE();  }
}

void ffmpeg_kit_config_enable_ffprobe_session_complete_callback(
    FFprobeKitCompleteCallback complete_cb, void *user_data) {
  try {
  g_ffprobe_complete_callback = complete_cb;
  g_ffprobe_complete_user_data = user_data;
  if (complete_cb) {
    FFmpegKitConfig::enableFFprobeSessionCompleteCallback(
        [](std::shared_ptr<FFprobeSession> title) {
          if (g_ffprobe_complete_callback) {
            auto handle = create_handle(title);
            g_ffprobe_complete_callback(handle, g_ffprobe_complete_user_data);
            // Handle ownership transferred to Dart callback
          }
        });
  } else {
    FFmpegKitConfig::enableFFprobeSessionCompleteCallback(nullptr);
  }
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_config_enable_ffprobe_session_complete_callback: " << e.what() << std::endl;
    PRINT_STACK_TRACE();  }
}

void ffmpeg_kit_config_enable_ffplay_session_complete_callback(
    FFplayKitCompleteCallback complete_cb, void *user_data) {
  try {
  g_ffplay_complete_callback = complete_cb;
  g_ffplay_complete_user_data = user_data;
  if (complete_cb) {
    FFmpegKitConfig::enableFFplaySessionCompleteCallback(
        [](std::shared_ptr<FFplaySession> title) {
          if (g_ffplay_complete_callback) {
            auto handle = create_handle(title);
            g_ffplay_complete_callback(handle, g_ffplay_complete_user_data);
            // Handle ownership transferred to Dart callback
          }
        });
  } else {
    FFmpegKitConfig::enableFFplaySessionCompleteCallback(nullptr);
  }
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_config_enable_ffplay_session_complete_callback: " << e.what() << std::endl;
    PRINT_STACK_TRACE();  }
}

void ffmpeg_kit_config_enable_media_information_session_complete_callback(
    ::MediaInformationSessionCompleteCallback complete_cb, void *user_data) {
  try {
  g_media_complete_callback = complete_cb;
  g_media_complete_user_data = user_data;
  if (complete_cb) {
    FFmpegKitConfig::enableMediaInformationSessionCompleteCallback(
        [](std::shared_ptr<MediaInformationSession> title) {
          if (g_media_complete_callback) {
            auto handle = create_handle(title);
            g_media_complete_callback(handle, g_media_complete_user_data);
            // Handle ownership transferred to Dart callback
          }
        });
  } else {
    FFmpegKitConfig::enableMediaInformationSessionCompleteCallback(nullptr);
  }
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_config_enable_media_information_session_complete_callback: " << e.what() << std::endl;
    PRINT_STACK_TRACE();  }
}

/* Utils */
char *ffmpeg_kit_config_register_new_ffmpeg_pipe(void) {
  try {
  return strdup_safe_ptr(FFmpegKitConfig::registerNewFFmpegPipe());
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_config_register_new_ffmpeg_pipe: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}

void ffmpeg_kit_config_close_ffmpeg_pipe(const char *pipe_path) {
  try {
  if (pipe_path) {
    FFmpegKitConfig::closeFFmpegPipe(std::string(pipe_path));
  }
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_config_close_ffmpeg_pipe: " << e.what() << std::endl;
    PRINT_STACK_TRACE();  }
}

void ffmpeg_kit_config_set_font_directory_list(const char **font_directory_list,
                                               int64_t list_size,
                                               const char *name_mappings_json) {
  try {
  std::list<std::string> fonts;
  if (font_directory_list) {
    for (int64_t i = 0; i < list_size; i++) {
      if (font_directory_list[i]) {
        fonts.push_back(std::string(font_directory_list[i]));
      }
    }
  }
  std::map<std::string, std::string> map;
  FFmpegKitConfig::setFontDirectoryList(fonts, map);
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_config_set_font_directory_list: " << e.what() << std::endl;
    PRINT_STACK_TRACE();  }
}

char *ffmpeg_kit_config_get_build_date(void) {
  try {
  return strdup_cpp(FFmpegKitConfig::getBuildDate());
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_config_get_build_date: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}

char *ffmpeg_kit_config_session_state_to_string(FFmpegKitSessionState state) {
  try {
  return strdup_cpp(FFmpegKitConfig::sessionStateToString((SessionState)state));
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_config_session_state_to_string: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}

char **ffmpeg_kit_config_parse_arguments(const char *command, int64_t *arg_count) {
  try {
  if (!command)
    return nullptr;
  auto list = FFmpegKitConfig::parseArguments(std::string(command));
  if (arg_count)
    *arg_count = list.size();

  char **array = (char **)malloc((list.size() + 1) * sizeof(char *));
  if (!array)
    return nullptr;

  size_t i = 0;
  for (const auto &arg : list) {
    array[i++] = strdup_cpp(arg);
  }
  array[i] = nullptr;
  return array;
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_config_parse_arguments: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}

char *ffmpeg_kit_config_arguments_to_string(char **arguments, int64_t arg_count) {
  try {
  if (!arguments)
    return nullptr;
  auto list = std::make_shared<std::list<std::string>>();
  for (int64_t i = 0; i < arg_count; i++) {
    if (arguments[i]) {
      list->push_back(std::string(arguments[i]));
    }
  }
  return strdup_cpp(FFmpegKitConfig::argumentsToString(list));
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_config_arguments_to_string: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}

int64_t ffmpeg_kit_config_messages_in_transmit(int64_t session_id) {
  try {
  return FFmpegKitConfig::messagesInTransmit(session_id);
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_config_messages_in_transmit: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return -1;
  }
}

/* Session Management Extended */
int64_t ffmpeg_kit_session_get_create_time(void *session_handle) {
  try {
  if (!session_handle)
    return 0;
  auto tp = get_ptr<Session>(session_handle)->getCreateTime();
  return std::chrono::duration_cast<std::chrono::milliseconds>(
             tp.time_since_epoch())
      .count();
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_session_get_create_time: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return -1;
  }
}

int64_t ffmpeg_kit_session_get_start_time(void *session_handle) {
  try {
  if (!session_handle)
    return 0;
  auto tp = get_ptr<Session>(session_handle)->getStartTime();
  return std::chrono::duration_cast<std::chrono::milliseconds>(
             tp.time_since_epoch())
      .count();
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_session_get_start_time: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return -1;
  }
}

int64_t ffmpeg_kit_session_get_end_time(void *session_handle) {
  try {
  if (!session_handle)
    return 0;
  auto tp = get_ptr<Session>(session_handle)->getEndTime();
  return std::chrono::duration_cast<std::chrono::milliseconds>(
             tp.time_since_epoch())
      .count();
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_session_get_end_time: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return -1;
  }
}

int64_t ffmpeg_kit_session_get_duration(void *session_handle) {
  try {
  if (!session_handle)
    return 0;
  return get_ptr<Session>(session_handle)->getDuration();
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_session_get_duration: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return -1;
  }
}

char *ffmpeg_kit_session_get_command(void *session_handle) {
  try {
  if (!session_handle)
    return nullptr;
  return strdup_cpp(get_ptr<Session>(session_handle)->getCommand());
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_session_get_command: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}

int64_t ffmpeg_kit_session_get_logs_count(void *session_handle) {
  try {
  if (!session_handle)
    return 0;
  return get_ptr<Session>(session_handle)->getLogsCount();
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_session_get_logs_count: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return -1;
  }
}

char *ffmpeg_kit_session_get_log_at(void *session_handle, int64_t index) {
  try {
  if (!session_handle)
    return nullptr;
  auto log = get_ptr<Session>(session_handle)->getLogAt(index);
  if (log) {
    const std::string& message = log->getMessage();
    return strdup_cpp(message);
  }
  return nullptr;
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_session_get_log_at: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}

int64_t ffmpeg_kit_session_get_log_level_at(void *session_handle, int64_t index) {
  try {
  if (!session_handle)
    return 0;
  auto log = get_ptr<Session>(session_handle)->getLogAt(index);
  if (log) {
    return (int64_t)log->getLevel();
  }
  return 0;
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_session_get_log_level_at: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return -1;
  }
}

int64_t ffmpeg_kit_session_get_statistics_count(void *session_handle) {
  try {
  if (!session_handle)
    return 0;
  return get_ptr<FFmpegSession>(session_handle)->getStatisticsCount();
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_session_get_statistics_count: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return -1;
  }
}

StatisticsHandle ffmpeg_kit_session_get_statistics_at(void *session_handle,
                                                      int64_t index) {
  try {
  if (!session_handle)
    return nullptr;
  auto stats = get_ptr<FFmpegSession>(session_handle)->getStatisticsAt(index);
  if (stats) {
    return create_handle(stats);
  }
  return nullptr;
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_session_get_statistics_at: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}


/* Statistics Getters */
int64_t ffmpeg_kit_statistics_get_video_frame_number(StatisticsHandle handle) {
  try {
  return get_ptr<Statistics>(handle)->getVideoFrameNumber();
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_statistics_get_video_frame_number: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return -1;
  }
}
double ffmpeg_kit_statistics_get_video_fps(StatisticsHandle handle) {
  try {
  return get_ptr<Statistics>(handle)->getVideoFps();
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_statistics_get_video_fps: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return -1;
  }
}
double ffmpeg_kit_statistics_get_video_quality(StatisticsHandle handle) {
  try {
  return get_ptr<Statistics>(handle)->getVideoQuality();
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_statistics_get_video_quality: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return -1;
  }
}
int64_t ffmpeg_kit_statistics_get_size(StatisticsHandle handle) {
  try {
  return (int64_t)get_ptr<Statistics>(handle)->getSize();
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_statistics_get_size: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return -1;
  }
}
double ffmpeg_kit_statistics_get_time(StatisticsHandle handle) {
  try {
  return get_ptr<Statistics>(handle)->getTime();
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_statistics_get_time: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return -1;
  }
}
double ffmpeg_kit_statistics_get_bitrate(StatisticsHandle handle) {
  try {
  return get_ptr<Statistics>(handle)->getBitrate();
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_statistics_get_bitrate: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return -1;
  }
}
double ffmpeg_kit_statistics_get_speed(StatisticsHandle handle) {
  try {
  return get_ptr<Statistics>(handle)->getSpeed();
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_statistics_get_speed: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return -1;
  }
}

/* Entity Properties Extended */

char *media_information_get_start_time(MediaInformationHandle handle) {
  try {
  auto ptr = get_ptr<MediaInformation>(handle);
  return ptr ? strdup_safe_ptr(ptr->getStartTime()) : nullptr;
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in media_information_get_start_time: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}

char *media_information_get_string_property(MediaInformationHandle handle,
                                            const char *key) {
  try {
  return strdup_safe_ptr(
      get_ptr<MediaInformation>(handle)->getStringProperty(key));
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in media_information_get_string_property: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}

int64_t media_information_get_number_property(MediaInformationHandle handle,
                                           const char *key) {
  try {
  auto val = get_ptr<MediaInformation>(handle)->getNumberProperty(key);
  return val ? *val : -1;
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in media_information_get_number_property: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return -1;
  }
}

char *media_information_get_all_properties_json(MediaInformationHandle handle) {
  try {
  auto props = get_ptr<MediaInformation>(handle)->getAllProperties();
  return props ? strdup_cpp(props->toStyledString()) : nullptr;
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in media_information_get_all_properties_json: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}

// StreamInformation
char *stream_information_get_channel_layout(StreamInformationHandle handle) {
  try {
  return strdup_safe_ptr(
      get_ptr<StreamInformation>(handle)->getChannelLayout());
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in stream_information_get_channel_layout: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}

char *
stream_information_get_sample_aspect_ratio(StreamInformationHandle handle) {
  try {
  return strdup_safe_ptr(
      get_ptr<StreamInformation>(handle)->getSampleAspectRatio());
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in stream_information_get_sample_aspect_ratio: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}

char *stream_information_get_codec_time_base(StreamInformationHandle handle) {
  try {
  return strdup_safe_ptr(
      get_ptr<StreamInformation>(handle)->getCodecTimeBase());
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in stream_information_get_codec_time_base: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}

char *stream_information_get_string_property(StreamInformationHandle handle,
                                             const char *key) {
  try {
  return strdup_safe_ptr(
      get_ptr<StreamInformation>(handle)->getStringProperty(key));
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in stream_information_get_string_property: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}

int64_t stream_information_get_number_property(StreamInformationHandle handle,
                                            const char *key) {
  try {
  auto val = get_ptr<StreamInformation>(handle)->getNumberProperty(key);
  return val ? *val : -1;
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in stream_information_get_number_property: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return -1;
  }
}

char *
stream_information_get_all_properties_json(StreamInformationHandle handle) {
  try {
  auto props = get_ptr<StreamInformation>(handle)->getAllProperties();
  return props ? strdup_cpp(props->toStyledString()) : nullptr;
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in stream_information_get_all_properties_json: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}

// Chapter
char *chapter_get_string_property(ChapterHandle handle, const char *key) {
  try {
  return strdup_safe_ptr(get_ptr<Chapter>(handle)->getStringProperty(key));
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in chapter_get_string_property: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}

int64_t chapter_get_number_property(ChapterHandle handle, const char *key) {
  try {
  auto val = get_ptr<Chapter>(handle)->getNumberProperty(key);
  return val ? *val : -1;
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in chapter_get_number_property: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return -1;
  }
}

char *chapter_get_all_properties_json(ChapterHandle handle) {
  try {
  auto props = get_ptr<Chapter>(handle)->getAllProperties();
  return props ? strdup_cpp(props->toStyledString()) : nullptr;
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in chapter_get_all_properties_json: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}

bool session_is_ffmpeg_session(void *session) {
  try {
  if (!session)
    return false;
  return get_ptr<AbstractSession>(session)->isFFmpeg();
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in session_is_ffmpeg_session: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return false;
  }
}

bool session_is_ffprobe_session(void *session) {
  try {
  if (!session)
    return false;
  return get_ptr<AbstractSession>(session)->isFFprobe();
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in session_is_ffprobe_session: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return false;
  }
}

bool session_is_ffplay_session(void *session) {
  try {
  if (!session)
    return false;
  return get_ptr<AbstractSession>(session)->isFFplay();
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in session_is_ffplay_session: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return false;
  }
}

bool session_is_media_information_session(void *session) {
  try {
  if (!session)
    return false;
  return get_ptr<AbstractSession>(session)->isMediaInformation();
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in session_is_media_information_session: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return false;
  }
}

void ffmpeg_kit_free(void *ptr) {
  try {
  if (ptr) {
    free(ptr);
  }
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_free: " << e.what() << std::endl;
    PRINT_STACK_TRACE();  }
}

void session_enable_debug_log(void *session) {
  try {
  if (!session)
    return;
  get_ptr<AbstractSession>(session)->enableDebugLog();
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in session_enable_debug_log: " << e.what() << std::endl;
    PRINT_STACK_TRACE();  }
}

void session_disable_debug_log(void *session) {
  try {
  if (!session)
    return;
  get_ptr<AbstractSession>(session)->disableDebugLog();
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in session_disable_debug_log: " << e.what() << std::endl;
    PRINT_STACK_TRACE();  }
}

bool session_is_debug_log_enabled(void *session) {
  try {
  if (!session)
    return false;
  return get_ptr<AbstractSession>(session)->isDebugLogEnabled();
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in session_is_debug_log_enabled: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return false;
  }
}

char *session_get_debug_log(void *session) {
  try {
  if (!session)
    return nullptr;
  return strdup_cpp(get_ptr<AbstractSession>(session)->getDebugLog());
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in session_get_debug_log: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}

void session_clear_debug_log(void *session) {
  try {
  if (!session)
    return;
  get_ptr<AbstractSession>(session)->clearDebugLog();
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in session_clear_debug_log: " << e.what() << std::endl;
    PRINT_STACK_TRACE();  }
}

void ffmpeg_kit_config_enable_debug_log(void *session) {
  try {
  if (!session)
    return;
  get_ptr<AbstractSession>(session)->enableDebugLog();
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_config_enable_debug_log: " << e.what() << std::endl;
    PRINT_STACK_TRACE();  }
}

void ffmpeg_kit_config_disable_debug_log(void *session) {
  try {
  if (!session)
    return;
  get_ptr<AbstractSession>(session)->disableDebugLog();
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_config_disable_debug_log: " << e.what() << std::endl;
    PRINT_STACK_TRACE();  }
}

bool ffmpeg_kit_config_is_debug_log_enabled(void *session) {
  try {
  if (!session)
    return false;
  return get_ptr<AbstractSession>(session)->isDebugLogEnabled();
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_config_is_debug_log_enabled: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return false;
  }
}

char *ffmpeg_kit_config_get_debug_log(void *session) {
  try {
  if (!session)
    return nullptr;
  return strdup_cpp(get_ptr<AbstractSession>(session)->getDebugLog());
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_config_get_debug_log: " << e.what() << std::endl;
    PRINT_STACK_TRACE();    return nullptr;
  }
}

void ffmpeg_kit_config_clear_debug_log(void *session) {
  try {
  if (!session)
    return;
  get_ptr<AbstractSession>(session)->clearDebugLog();
  } catch (const std::exception &e) {
    // Handle or log the exception
    std::cerr << "[Exception] in ffmpeg_kit_config_clear_debug_log: " << e.what() << std::endl;
    PRINT_STACK_TRACE();  }
}
}