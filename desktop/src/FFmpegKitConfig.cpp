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

#include <sys/stat.h>
#include <sys/types.h>

extern "C" {
#include "libavutil/bprint.h"
#include "libavutil/ffversion.h"
#include "libavutil/log.h"
#include "libavutil/mem.h"
}
#include "ffmpeg_lib.h"
#include "ffprobe_lib.h"
#include "ffmpeg_tls.h"

#include "ArchDetect.hpp"
#include "FFmpegKitConfig.hpp"
#include "FFmpegSession.hpp"
#include "FFprobeSession.hpp"
#include "Level.hpp"
#include "LogRedirectionStrategy.hpp"
#include "MediaInformationJsonParser.hpp"
#include "MediaInformationSession.hpp"
#include "MediaInformationSession.hpp"
#include "FFplaySession.hpp"
#include "Packages.hpp"
#include "SessionState.hpp"
#include "ffplay_lib.h"
#include <algorithm>
#include <atomic>
#include <condition_variable>
#include <fstream>
#include <iostream>
#include <mutex>
#include <signal.h>
#include <thread>


extern "C" {
void set_report_callback(void (*callback)(int, float, float, int64_t, double,
                                          double, double));
void cancel_operation(long id);
}

/**
 * Generates ids for named ffmpeg kit pipes.
 */
static std::atomic<long> pipeIndexGenerator(1);

/* Session history variables */
static int sessionHistorySize;
static std::recursive_mutex &getSessionMutex() {
  static std::recursive_mutex *instance = new std::recursive_mutex();
  return *instance;
}
static std::map<long, std::shared_ptr<ffmpegkit::Session>> &
getSessionHistoryMap() {
  static auto *instance = new std::map<long, std::shared_ptr<ffmpegkit::Session>>();
  return *instance;
}
static std::list<std::shared_ptr<ffmpegkit::Session>> &getSessionHistoryList() {
  static auto *instance = new std::list<std::shared_ptr<ffmpegkit::Session>>();
  return *instance;
}
static std::atomic<long> activeFFplaySessionId(0);

/** Session control variables */
#define SESSION_MAP_SIZE 1000
static std::atomic<short> sessionMap[SESSION_MAP_SIZE];
static std::atomic<int> sessionInTransitMessageCountMap[SESSION_MAP_SIZE];

/** Holds callback defined to redirect logs */
static ffmpegkit::LogCallback logCallback;

/** Holds callback defined to redirect statistics */
static ffmpegkit::StatisticsCallback statisticsCallback;

/** Holds complete callbacks defined to redirect asynchronous execution results
 */
static ffmpegkit::FFmpegSessionCompleteCallback ffmpegSessionCompleteCallback;
static ffmpegkit::FFprobeSessionCompleteCallback ffprobeSessionCompleteCallback;
static ffmpegkit::FFplaySessionCompleteCallback ffplaySessionCompleteCallback;
static ffmpegkit::MediaInformationSessionCompleteCallback
    mediaInformationSessionCompleteCallback;

static ffmpegkit::LogRedirectionStrategy globalLogRedirectionStrategy;

/** Redirection control variables */
static int redirectionEnabled;
static std::recursive_mutex &getCallbackDataMutex() {
  static std::recursive_mutex *instance = new std::recursive_mutex();
  return *instance;
}
static std::recursive_mutex &getGlobalCallbacksMutex() {
  static std::recursive_mutex *instance = new std::recursive_mutex();
  return *instance;
}
static std::mutex &getCallbackMutex() {
  static std::mutex *instance = new std::mutex();
  return *instance;
}
static std::condition_variable &getCallbackMonitor() {
  static std::condition_variable *instance = new std::condition_variable();
  return *instance;
}
class CallbackData;
static std::list<CallbackData *> &getCallbackDataList() {
  static auto *instance = new std::list<CallbackData *>();
  return *instance;
}

/** Fields that control the handling of SIGNALs */
volatile int handleSIGQUIT = 1;
volatile int handleSIGINT = 1;
volatile int handleSIGTERM = 1;
volatile int handleSIGXCPU = 1;
volatile int handleSIGPIPE = 1;

/** Holds the default log level */
int configuredLogLevel = ffmpegkit::LevelAVLogInfo;

#ifdef __cplusplus
extern "C" {
#endif

/** Forward declaration for function defined in ffmpeg.c */
int ffmpeg_execute(int argc, char **argv);

/** Forward declaration for function defined in ffprobe.c */
int ffprobe_execute(int argc, char **argv);

void ffmpegkit_log_callback_function(void *ptr, int level, const char *format,
                                     va_list vargs);

#ifdef __cplusplus
}
#endif

static std::atomic<long> globalSessionId(0);
static thread_local std::shared_ptr<ffmpegkit::Session> tlsSession = nullptr;

static std::once_flag ffmpegKitInitializerFlag;
static pthread_t callbackThread;

void *ffmpegKitInitialize();

const void *_ffmpegKitConfigInitializer{ffmpegKitInitialize()};

enum CallbackType { LogType, StatisticsType };

static bool fs_exists(const std::string &s, const bool isFile,
                      const bool isDirectory) {
  struct stat dir_info;

  if (stat(s.c_str(), &dir_info) == 0) {
    if (isFile && S_ISREG(dir_info.st_mode)) {
      return true;
    }
    if (isDirectory && S_ISDIR(dir_info.st_mode)) {
      return true;
    }
  }

  return false;
}

static bool fs_create_dir(const std::string &s) {
  if (!fs_exists(s, false, true)) {
    bool mkdirSuccess = false;
#ifdef _WIN32
    mkdirSuccess = (mkdir(s.c_str()) != 0);
#else
    mkdirSuccess = (mkdir(s.c_str(), S_IRWXU | S_IRWXG | S_IROTH) != 0);
#endif
    if (mkdirSuccess) {
      std::cout << "Failed to create directory: " << s
                << ". Operation failed with " << errno << "." << std::endl;
      return false;
    }
  }
  return true;
}

void deleteExpiredSessions() {
  while (getSessionHistoryList().size() > sessionHistorySize) {
    auto first = getSessionHistoryList().front();
    if (first != nullptr) {
      getSessionHistoryList().pop_front();
      getSessionHistoryMap().erase(first->getSessionId());
    }
  }
}

void addSessionToSessionHistory(
    const std::shared_ptr<ffmpegkit::Session> session) {
  std::unique_lock<std::recursive_mutex> lock(getSessionMutex(), std::defer_lock);

  const long sessionId = session->getSessionId();

  lock.lock();

  /*
   * ASYNC SESSIONS CALL THIS METHOD TWICE
   * THIS CHECK PREVENTS ADDING THE SAME SESSION AGAIN
   */
  if (getSessionHistoryMap().count(sessionId) == 0) {
    getSessionHistoryMap().insert({sessionId, session});
    getSessionHistoryList().push_back(session);
    deleteExpiredSessions();
  }

  lock.unlock();
}

/**
 * Callback data class.
 */
class CallbackData {
public:
  CallbackData(const long sessionId, const int logLevel, const AVBPrint *data)
      : _type{LogType}, _sessionId{sessionId}, _logLevel{logLevel} {
    av_bprint_init(&_logData, 0, AV_BPRINT_SIZE_UNLIMITED);
    av_bprintf(&_logData, "%s", data->str);
  }

  CallbackData(const long sessionId, const int videoFrameNumber,
               const float videoFps, const float videoQuality,
               const int64_t size, const double time, const double bitrate,
               const double speed)
      : _type{StatisticsType}, _sessionId{sessionId},
        _statisticsFrameNumber{videoFrameNumber}, _statisticsFps{videoFps},
        _statisticsQuality{videoQuality}, _statisticsSize{size},
        _statisticsTime{time}, _statisticsBitrate{bitrate},
        _statisticsSpeed{speed} {}

  ~CallbackData() {
    if (_type == LogType) {
      av_bprint_finalize(&_logData, NULL);
    }
  }


  CallbackType getType() { return _type; }

  long getSessionId() { return _sessionId; }

  int getLogLevel() { return _logLevel; }

  AVBPrint *getLogData() { return &_logData; }

  int getStatisticsFrameNumber() { return _statisticsFrameNumber; }

  float getStatisticsFps() { return _statisticsFps; }

  float getStatisticsQuality() { return _statisticsQuality; }

  int64_t getStatisticsSize() { return _statisticsSize; }

  double getStatisticsTime() { return _statisticsTime; }

  double getStatisticsBitrate() { return _statisticsBitrate; }

  double getStatisticsSpeed() { return _statisticsSpeed; }

private:
  CallbackType _type;
  long _sessionId; // session id

  int _logLevel;     // log level
  AVBPrint _logData; // log data

  int _statisticsFrameNumber; // statistics frame number
  float _statisticsFps;       // statistics fps
  float _statisticsQuality;   // statistics quality
  int64_t _statisticsSize;    // statistics size
  double _statisticsTime;     // statistics time
  double _statisticsBitrate;  // statistics bitrate
  double _statisticsSpeed;    // statistics speed
};

/**
 * Waits on the callback semaphore for the given time.
 *
 * @param milliSeconds wait time in milliseconds
 */
static void callbackWait(int milliSeconds) {
  std::unique_lock<std::mutex> callbackLock{getCallbackMutex()};
  getCallbackMonitor().wait_for(callbackLock,
                                std::chrono::milliseconds(milliSeconds));
}

/**
 * Notifies threads waiting on callback semaphore.
 */
static void callbackNotify() { getCallbackMonitor().notify_one(); }

static const char *avutil_log_get_level_str(int level) {
  switch (level) {
  case AV_LOG_QUIET:
    return "quiet";
  case AV_LOG_DEBUG:
    return "debug";
  case AV_LOG_VERBOSE:
    return "verbose";
  case AV_LOG_INFO:
    return "info";
  case AV_LOG_WARNING:
    return "warning";
  case AV_LOG_ERROR:
    return "error";
  case AV_LOG_FATAL:
    return "fatal";
  case AV_LOG_PANIC:
    return "panic";
  default:
    return "";
  }
}

static void avutil_log_format_line(void *avcl, int level, const char *fmt,
                                   va_list vl, AVBPrint part[4],
                                   int *print_prefix) {
  int flags = av_log_get_flags();
  AVClass *avc = avcl ? *(AVClass **)avcl : NULL;
  av_bprint_init(part + 0, 0, 1);
  av_bprint_init(part + 1, 0, 1);
  av_bprint_init(part + 2, 0, 1);
  av_bprint_init(part + 3, 0, 65536);

  if (*print_prefix && avc) {
    if (avc->parent_log_context_offset) {
      AVClass **parent =
          *(AVClass ***)(((uint8_t *)avcl) + avc->parent_log_context_offset);
      if (parent && *parent) {
        av_bprintf(part + 0, "[%s @ %p] ", (*parent)->item_name(parent),
                   parent);
      }
    }
    av_bprintf(part + 1, "[%s @ %p] ", avc->item_name(avcl), avcl);
  }

  if (*print_prefix && (level > AV_LOG_QUIET) && (flags & AV_LOG_PRINT_LEVEL))
    av_bprintf(part + 2, "[%s] ", avutil_log_get_level_str(level));

  av_vbprintf(part + 3, fmt, vl);

  if (*part[0].str || *part[1].str || *part[2].str || *part[3].str) {
    char lastc = part[3].len && part[3].len <= part[3].size
                     ? part[3].str[part[3].len - 1]
                     : 0;
    *print_prefix = lastc == '\n' || lastc == '\r';
  }
}

static void avutil_log_sanitize(char *line) {
  while (*line) {
    if (*line < 0x08 || (*line > 0x0D && *line < 0x20))
      *line = '?';
    line++;
  }
}

/**
 * Adds log data to the end of callback data list.
 *
 * @param level log level
 * @param data log data
 */
static void logCallbackDataAdd(int level, AVBPrint *data) {
  std::shared_ptr<ffmpegkit::Session> currentSession = tlsSession;
  if (currentSession == nullptr) {
      currentSession = ffmpegkit::FFmpegKitConfig::getSession(globalSessionId.load());
  }

  long sessionId = (currentSession != nullptr) ? currentSession->getSessionId() : 0;

  if (currentSession != nullptr) {
    currentSession->debugLog("[NATIVE LOG] sessionId: %ld level: %d msg: %s", sessionId, level, (data->str ? data->str : "NULL"));
  }

  std::unique_lock<std::recursive_mutex> lock(getCallbackDataMutex(),
                                              std::defer_lock);
  CallbackData *callbackData = new CallbackData(sessionId, level, data);

  lock.lock();
  getCallbackDataList().push_back(callbackData);
  lock.unlock();

  callbackNotify();

  std::atomic_fetch_add(
      &sessionInTransitMessageCountMap[sessionId % SESSION_MAP_SIZE], 1);
}

/**
 * Adds statistics data to the end of callback data list.
 */
static void statisticsCallbackDataAdd(int frameNumber, float fps, float quality,
                                      int64_t size, double time, double bitrate,
                                      double speed) {
  std::shared_ptr<ffmpegkit::Session> currentSession = tlsSession;
  if (currentSession == nullptr) {
      currentSession = ffmpegkit::FFmpegKitConfig::getSession(globalSessionId.load());
  }

  long sessionId = (currentSession != nullptr) ? currentSession->getSessionId() : 0;

  std::unique_lock<std::recursive_mutex> lock(getCallbackDataMutex(),
                                              std::defer_lock);
  CallbackData *callbackData = new CallbackData(
      sessionId, frameNumber, fps, quality, size, time, bitrate, speed);

  lock.lock();
  getCallbackDataList().push_back(callbackData);
  lock.unlock();

  callbackNotify();

  std::atomic_fetch_add(
      &sessionInTransitMessageCountMap[sessionId % SESSION_MAP_SIZE], 1);
}

/**
 * Removes head of callback data list.
 */
static CallbackData *callbackDataRemove() {
  std::unique_lock<std::recursive_mutex> lock(getCallbackDataMutex(),
                                              std::defer_lock);
  CallbackData *newData = nullptr;

  lock.lock();
  if (getCallbackDataList().size() > 0) {
    newData = getCallbackDataList().front();
    getCallbackDataList().pop_front();
  }
  lock.unlock();

  return newData;
}

/**
 * Registers a session id to the session map.
 *
 * @param sessionId session id
 */
static void registerSessionId(long sessionId) {
  std::atomic_store(&sessionMap[sessionId % SESSION_MAP_SIZE], (short)1);
}

/**
 * Removes a session id from the session map.
 *
 * @param sessionId session id
 */
static void removeSession(long sessionId) {
  std::atomic_store(&sessionMap[sessionId % SESSION_MAP_SIZE], (short)0);
}

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Adds a cancel session request to the session map.
 *
 * @param sessionId session id
 */
void cancelSession(long sessionId) {
  std::atomic_store(&sessionMap[sessionId % SESSION_MAP_SIZE], (short)2);
}

/**
 * Checks whether a cancel request for the given session id exists in the
 * session map.
 *
 * @param sessionId session id
 * @return 1 if exists, false otherwise
 */
int cancelRequested(long sessionId) {
  if (std::atomic_load(&sessionMap[sessionId % SESSION_MAP_SIZE]) == 2) {
    return 1;
  } else {
    return 0;
  }
}

FFMPEG_THREAD_LOCAL void (*report_callback)(int, float, float, int64_t, double, double,
                        double) = NULL;
extern void sigterm_handler(int sig);

void set_report_callback(void (*callback)(int, float, float, int64_t, double,
                                          double, double)) {
  report_callback = callback;
}

void cancel_operation(long id) {
  if (id == 0) {
    sigterm_handler(SIGINT);
  } else {
    cancelSession(id);
  }
}

#ifdef __cplusplus
}
#endif

/**
 * Resets the number of messages in transmit for this session.
 *
 * @param sessionId session id
 */
static void resetMessagesInTransmit(long sessionId) {
  std::atomic_store(
      &sessionInTransitMessageCountMap[sessionId % SESSION_MAP_SIZE], 0);
}

/**
 * Callback function for FFmpeg/FFprobe logs.
 *
 * @param ptr pointer to AVClass struct
 * @param level log level
 * @param format format string
 * @param vargs arguments
 */
void ffmpegkit_log_callback_function(void *ptr, int level, const char *format,
                                     va_list vargs) {
  std::shared_ptr<ffmpegkit::Session> currentSession = tlsSession;
  if (currentSession == nullptr) {
      currentSession = ffmpegkit::FFmpegKitConfig::getSession(globalSessionId.load());
  }

  long sessionId = (currentSession != nullptr) ? currentSession->getSessionId() : 0;

  AVBPrint fullLine;
  AVBPrint part[4];
  int print_prefix = 1;

  // DO NOT PROCESS UNWANTED LOGS
  if (level >= 0) {
    level &= 0xff;
  }
  int activeLogLevel = av_log_get_level();

  // LevelAVLogStdErr logs are always redirected
  if ((activeLogLevel == ffmpegkit::LevelAVLogQuiet &&
       level != ffmpegkit::LevelAVLogStdErr) ||
      (level > activeLogLevel)) {
    return;
  }

  av_bprint_init(&fullLine, 0, AV_BPRINT_SIZE_UNLIMITED);

  avutil_log_format_line(ptr, level, format, vargs, part, &print_prefix);
  avutil_log_sanitize(part[0].str);
  avutil_log_sanitize(part[1].str);
  avutil_log_sanitize(part[2].str);
  avutil_log_sanitize(part[3].str);

  // COMBINE ALL 4 LOG PARTS
  av_bprintf(&fullLine, "%s%s%s%s", part[0].str, part[1].str, part[2].str,
             part[3].str);

  if (fullLine.len > 0) {
    logCallbackDataAdd(level, &fullLine);
  }

  av_bprint_finalize(part, NULL);
  av_bprint_finalize(part + 1, NULL);
  av_bprint_finalize(part + 2, NULL);
  av_bprint_finalize(part + 3, NULL);
  av_bprint_finalize(&fullLine, NULL);
}

/**
 * Callback function for FFmpeg statistics.
 *
 * @param frameNumber last processed frame number
 * @param fps frames processed per second
 * @param quality quality of the output stream (video only)
 * @param size size in bytes
 * @param time processed output duration
 * @param bitrate output bit rate in kbits/s
 * @param speed processing speed = processed duration / operation duration
 */
void ffmpegkit_statistics_callback_function(int frameNumber, float fps,
                                            float quality, int64_t size,
                                            double time, double bitrate,
                                            double speed) {
  statisticsCallbackDataAdd(frameNumber, fps, quality, size, time, bitrate,
                            speed);
}

static void process_log(long sessionId, int levelValueInt,
                        AVBPrint *logMessage) {
  int activeLogLevel = av_log_get_level();
  ffmpegkit::Level levelValue = static_cast<ffmpegkit::Level>(levelValueInt);
  std::shared_ptr<ffmpegkit::Log> log =
      std::make_shared<ffmpegkit::Log>(sessionId, levelValue, logMessage->str);
  bool globalCallbackDefined = false;
  bool sessionCallbackDefined = false;
  ffmpegkit::LogRedirectionStrategy activeLogRedirectionStrategy =
      globalLogRedirectionStrategy;

  // LevelAVLogStdErr logs are always redirected
  if ((activeLogLevel == ffmpegkit::LevelAVLogQuiet &&
       levelValue != ffmpegkit::LevelAVLogStdErr) ||
      (levelValue > activeLogLevel)) {
    // LOG NEITHER PRINTED NOR FORWARDED
    return;
  }

  auto session = ffmpegkit::FFmpegKitConfig::getSession(sessionId);
  if (session != nullptr) {
    activeLogRedirectionStrategy = session->getLogRedirectionStrategy();
    session->addLog(log);

    ffmpegkit::LogCallback sessionLogCallback = session->getLogCallback();
    if (sessionLogCallback != nullptr) {
      sessionCallbackDefined = true;

      try {
        // NOTIFY SESSION CALLBACK DEFINED
        sessionLogCallback(log);
      } catch (const std::exception &exception) {
        std::cout << "Exception thrown inside session log callback. "
                  << exception.what() << std::endl;
      }
    }
  }

  {
    std::lock_guard<std::recursive_mutex> lock(getGlobalCallbacksMutex());
    if (logCallback != nullptr) {
      globalCallbackDefined = true;

      try {
        // NOTIFY GLOBAL CALLBACK DEFINED
        logCallback(log);
      } catch (const std::exception &exception) {
        std::cout << "Exception thrown inside global log callback. "
                  << exception.what() << std::endl;
      }
    }
  }

  // EXECUTE THE LOG STRATEGY
  switch (activeLogRedirectionStrategy) {
  case ffmpegkit::LogRedirectionStrategyNeverPrintLogs: {
    return;
  }
  case ffmpegkit::LogRedirectionStrategyPrintLogsWhenGlobalCallbackNotDefined: {
    if (globalCallbackDefined) {
      return;
    }
  } break;
  case ffmpegkit::
      LogRedirectionStrategyPrintLogsWhenSessionCallbackNotDefined: {
    if (sessionCallbackDefined) {
      return;
    }
  } break;
  case ffmpegkit::LogRedirectionStrategyPrintLogsWhenNoCallbacksDefined: {
    if (globalCallbackDefined || sessionCallbackDefined) {
      return;
    }
  } break;
  case ffmpegkit::LogRedirectionStrategyAlwaysPrintLogs: {
  } break;
  }

  // PRINT LOGS
  switch (levelValue) {
  case ffmpegkit::LevelAVLogQuiet:
    // PRINT NO OUTPUT
    break;
  default:
    // WRITE TO STDOUT
    std::cout << ffmpegkit::FFmpegKitConfig::logLevelToString(levelValue)
              << ": " << logMessage->str;
    break;
  }
}

void process_statistics(long sessionId, int videoFrameNumber, float videoFps,
                        float videoQuality, long size, double time,
                        double bitrate, double speed) {
  std::shared_ptr<ffmpegkit::Statistics> statistics =
      std::make_shared<ffmpegkit::Statistics>(sessionId, videoFrameNumber,
                                              videoFps, videoQuality, size,
                                              time, bitrate, speed);

  auto session = ffmpegkit::FFmpegKitConfig::getSession(sessionId);
  if (session != nullptr && session->isFFmpeg()) {
    std::shared_ptr<ffmpegkit::FFmpegSession> ffmpegSession =
        std::static_pointer_cast<ffmpegkit::FFmpegSession>(session);
    ffmpegSession->addStatistics(statistics);

    ffmpegkit::StatisticsCallback sessionStatisticsCallback =
        ffmpegSession->getStatisticsCallback();
    if (sessionStatisticsCallback != nullptr) {
      try {
        sessionStatisticsCallback(statistics);
      } catch (const std::exception &exception) {
        std::cout << "Exception thrown inside session statistics callback. "
                  << exception.what() << std::endl;
      }
    }
  }

  {
    std::lock_guard<std::recursive_mutex> lock(getGlobalCallbacksMutex());
    if (statisticsCallback != nullptr) {
      try {
        statisticsCallback(statistics);
      } catch (const std::exception &exception) {
        std::cout << "Exception thrown inside global statistics callback. "
                  << exception.what() << std::endl;
      }
    }
  }
}

/**
 * Forwards asynchronous messages to Callbacks.
 */
void *callbackThreadFunction(void *pointer) {
  int activeLogLevel = av_log_get_level();
  if ((activeLogLevel != ffmpegkit::LevelAVLogQuiet) &&
      (ffmpegkit::LevelAVLogDebug <= activeLogLevel)) {
    std::cout << "Async callback block started." << std::endl;
  }

  while (redirectionEnabled) {
    try {
      CallbackData *callbackData = callbackDataRemove();

      if (callbackData != nullptr) {

        if (callbackData->getType() == LogType) {
          process_log(callbackData->getSessionId(), callbackData->getLogLevel(),
                      callbackData->getLogData());
        } else {

          process_statistics(callbackData->getSessionId(),
                             callbackData->getStatisticsFrameNumber(),
                             callbackData->getStatisticsFps(),
                             callbackData->getStatisticsQuality(),
                             callbackData->getStatisticsSize(),
                             callbackData->getStatisticsTime(),
                             callbackData->getStatisticsBitrate(),
                             callbackData->getStatisticsSpeed());
        }

        std::atomic_fetch_sub(
            &sessionInTransitMessageCountMap[callbackData->getSessionId() %
                                             SESSION_MAP_SIZE],
            1);

        delete callbackData;
      } else {

        callbackWait(100);
      }

    } catch (const std::exception &exception) {
      activeLogLevel = av_log_get_level();
      if ((activeLogLevel != ffmpegkit::LevelAVLogQuiet) &&
          (ffmpegkit::LevelAVLogWarning <= activeLogLevel)) {
        std::cout << "Async callback block received error: " << exception.what()
                  << std::endl;
      }
    }
  }

  activeLogLevel = av_log_get_level();
  if ((activeLogLevel != ffmpegkit::LevelAVLogQuiet) &&
      (ffmpegkit::LevelAVLogDebug <= activeLogLevel)) {
    std::cout << "Async callback block stopped." << std::endl;
  }

  return NULL;
}

/**
 * Helper to reconstruct command string from argument list for the new _lib
 * APIs.
 */
static std::string
buildCommandString(const char *toolName,
                   const std::shared_ptr<std::list<std::string>> &arguments) {
  std::string cmd = toolName;
  for (const auto &arg : *arguments) {
    cmd += " ";
    // Basic quote handling: if arg has space, wrap in quotes
    if (arg.find(' ') != std::string::npos) {
      cmd += "\"" + arg + "\"";
    } else {
      cmd += arg;
    }
  }
  return cmd;
}

static int
executeFFmpeg(const long sessionId,
              const std::shared_ptr<std::list<std::string>> arguments) {
  auto session = ffmpegkit::FFmpegKitConfig::getSession(sessionId);
  tlsSession = session;
  globalSessionId = sessionId;

  registerSessionId(sessionId);
  resetMessagesInTransmit(sessionId);

  av_log_set_level(configuredLogLevel);
  av_log_set_callback(ffmpegkit_log_callback_function);
  set_report_callback(ffmpegkit_statistics_callback_function);
  
  // 1. Construct command string for the library init
  std::string fullCommand = buildCommandString("ffmpeg", arguments);

  // 2. Initialize Wrapper Context
  FFmpegContext *ctx = ffmpeg_init(fullCommand.c_str());
  if (!ctx) {
    auto session = ffmpegkit::FFmpegKitConfig::getSession(sessionId);
    removeSession(sessionId);
    tlsSession = nullptr;
    return -1; // ENOMEM or parse error
  }

  // 3. RUN
  // This blocks until transcoding is finished
  int returnCode = ffmpeg_run(ctx);

  // ALWAYS REMOVE THE ID FROM THE MAP
  removeSession(sessionId);

  // 4. CLEANUP
  ffmpeg_free(ctx);

  tlsSession = nullptr;
  return returnCode;
}

int executeFFprobe(const long sessionId,
                   const std::shared_ptr<std::list<std::string>> arguments) {
  auto session = ffmpegkit::FFmpegKitConfig::getSession(sessionId);
  tlsSession = session;
  globalSessionId = sessionId;

  registerSessionId(sessionId);
  resetMessagesInTransmit(sessionId);

  // SETS DEFAULT LOG LEVEL BEFORE STARTING A NEW RUN
  av_log_set_level(configuredLogLevel);
  av_log_set_callback(ffmpegkit_log_callback_function);
  set_report_callback(ffmpegkit_statistics_callback_function);

  // 1. Construct command string
  std::string fullCommand = buildCommandString("ffprobe", arguments);

  // 2. Initialize Wrapper Context
  FFprobeContext *ctx = ffprobe_init(fullCommand.c_str());
  if (!ctx) {
    auto session = ffmpegkit::FFmpegKitConfig::getSession(sessionId);
    removeSession(sessionId);
    tlsSession = nullptr;
    return -1;
  }

  // 3. RUN
  // This blocks until probe is finished.
  // Output is captured into ctx->output (AVBPrint) inside the lib.
  int returnCode = ffprobe_run(ctx);

  // 4. BRIDGE OUTPUT
  // MediaInformationSession expects the JSON output to appear in the logs
  // (specifically as LevelAVLogStdErr or via the log system).
  // Since ffprobe_lib.c no longer writes to stdout/stderr, we must manually
  // inject the captured buffer into the log system.
  if (ctx) {
    char *output = ffprobe_get_output(ctx);
    if (output) {
      AVBPrint bprint;
      av_bprint_init(&bprint, 0, AV_BPRINT_SIZE_UNLIMITED);
      av_bprintf(&bprint, "%s", output);

      // Inject into the log system so MediaInformationJsonParser can find it
      // Use LevelAVLogStdErr as that is what MediaInformationSession listens
      // for
      logCallbackDataAdd(ffmpegkit::LevelAVLogStdErr, &bprint);

      av_bprint_finalize(&bprint, NULL);
      av_free(output);
    } else {
      auto session = ffmpegkit::FFmpegKitConfig::getSession(sessionId);
      if (session != nullptr) {
        session->debugLog("[PROBE OUTPUT] sessionId: %ld was NULL", sessionId);
      }
    }
  }

  // ALWAYS REMOVE THE ID FROM THE MAP
  removeSession(sessionId);

  tlsSession = nullptr;
  // 5. CLEANUP
  ffprobe_free(ctx);

  return returnCode;
}

int executeFFplay(const long sessionId,
                  const std::shared_ptr<std::list<std::string>> arguments) {
  auto session = ffmpegkit::FFmpegKitConfig::getSession(sessionId);
  tlsSession = session;
  globalSessionId = sessionId;

  if (tlsSession != nullptr) {
    tlsSession->debugLog("[EXECUTE FFPLAY] sessionId: %ld tls Bound", sessionId);
  }
  registerSessionId(sessionId);
  resetMessagesInTransmit(sessionId);

  // SETS DEFAULT LOG LEVEL BEFORE STARTING A NEW RUN
  av_log_set_level(configuredLogLevel);
  av_log_set_callback(ffmpegkit_log_callback_function);
  set_report_callback(ffmpegkit_statistics_callback_function);

  // 1. Construct command string
  std::string fullCommand = buildCommandString("ffplay", arguments);

  // 2. Initialize Wrapper Context
  FFplayContext *ctx = ffplay_init(fullCommand.c_str(), nullptr);
  if (!ctx) {
    if (tlsSession != nullptr) {
      tlsSession->debugLog("[EXECUTE FFPLAY] sessionId: %ld ffplay_init FAILED", sessionId);
    }
    removeSession(sessionId);
    tlsSession = nullptr;
    globalSessionId = 0;
    return -1;
  }

  if (tlsSession != nullptr) {
    tlsSession->debugLog("[EXECUTE FFPLAY] sessionId: %ld ffplay_init SUCCESS", sessionId);
  }

  // BRIDGE: Set context on session for external control
  if (session && session->isFFplay()) {
    std::static_pointer_cast<ffmpegkit::FFplaySession>(session)->setContext(ctx);
  }

  // 3. RUN
  int returnCode = ffplay_start(ctx);
  if (returnCode == 0) {
    if (tlsSession != nullptr) {
      tlsSession->debugLog("[EXECUTE FFPLAY] sessionId: %ld ffplay_start SUCCESS", sessionId);
    }
    while (ffplay_step(ctx) == 0) {
      if (cancelRequested(sessionId)) {
        ffplay_stop(ctx);
        break;
      }
      std::this_thread::sleep_for(std::chrono::milliseconds(10));
    }
  }

  // BRIDGE: Clear context on session
  if (session && session->isFFplay()) {
    std::static_pointer_cast<ffmpegkit::FFplaySession>(session)->setContext(nullptr);
  }

  // ALWAYS REMOVE THE ID FROM THE MAP
  removeSession(sessionId);

  // 4. CLEANUP
  ffplay_free(ctx);

  tlsSession = nullptr;
  globalSessionId = 0;

  return returnCode;
}

void *ffmpegKitInitialize() {
  std::call_once(ffmpegKitInitializerFlag, []() {
    std::cout << "Loading ffmpeg-kit." << std::endl;

    // Eagerly initialize all Meyers Singletons to establish a strict 
    // happens-before edge prior to spawning any background threads. 
    // This prevents ThreadSanitizer from flagging data races during 
    // the lazy initialization of these static pointers.
    (void)getSessionMutex();
    (void)getSessionHistoryMap();
    (void)getSessionHistoryList();
    (void)getCallbackDataMutex();
    (void)getGlobalCallbacksMutex();
    (void)getCallbackMutex();
    (void)getCallbackMonitor();
    (void)getCallbackDataList();

    sessionHistorySize = 10;

    for (int i = 0; i < SESSION_MAP_SIZE; i++) {
      std::atomic_init(&sessionMap[i], (short)0);
      std::atomic_init(&sessionInTransitMessageCountMap[i], 0);
    }

    logCallback = nullptr;
    statisticsCallback = nullptr;
    ffmpegSessionCompleteCallback = nullptr;
    ffprobeSessionCompleteCallback = nullptr;
    ffplaySessionCompleteCallback = nullptr;
    mediaInformationSessionCompleteCallback = nullptr;

    globalLogRedirectionStrategy =
        ffmpegkit::LogRedirectionStrategyPrintLogsWhenNoCallbacksDefined;

    redirectionEnabled = 0;

    ffmpegkit::FFmpegKitConfig::enableRedirection();

    std::cout << "Loaded ffmpeg-kit-" << ffmpegkit::Packages::getPackageName() << "-" 
              << ffmpegkit::ArchDetect::getArch() << "-"
              << (ffmpegkit::Packages::getIsGpl() ? "gpl" : ffmpegkit::Packages::getIsNonFree() ? "nonfree" : "lgpl") << "-"
              << ffmpegkit::FFmpegKitConfig::getVersion() << "-"
              << ffmpegkit::FFmpegKitConfig::getBuildDate() << "." << std::endl;
  });

  std::lock_guard<std::recursive_mutex> lock(getCallbackDataMutex());

  return NULL;
}

void ffmpegkit::FFmpegKitConfig::enableRedirection() {
  std::unique_lock<std::recursive_mutex> lock(getCallbackDataMutex(),
                                              std::defer_lock);
  lock.lock();

  if (redirectionEnabled != 0) {
    lock.unlock();
    return;
  }
  redirectionEnabled = 1;

  lock.unlock();

  int rc = pthread_create(&callbackThread, NULL, callbackThreadFunction, NULL);
  if (rc != 0) {
    std::cout << "Failed to create async callback block: %d" << rc << std::endl;
    lock.unlock();
    return;
  }

  av_log_set_callback(ffmpegkit_log_callback_function);
  set_report_callback(ffmpegkit_statistics_callback_function);
}

void ffmpegkit::FFmpegKitConfig::disableRedirection() {
  std::unique_lock<std::recursive_mutex> lock(getCallbackDataMutex(),
                                              std::defer_lock);

  lock.lock();

  if (redirectionEnabled == 0) {
    lock.unlock();
    return;
  }
  redirectionEnabled = 0;

  lock.unlock();

  callbackNotify();

  if (callbackThread != 0) {
    pthread_join(callbackThread, NULL);
    callbackThread = 0;
  }

  av_log_set_callback(av_log_default_callback);
  set_report_callback(NULL);
}

int ffmpegkit::FFmpegKitConfig::setFontconfigConfigurationPath(
    const std::string &path) {
  return ffmpegkit::FFmpegKitConfig::setEnvironmentVariable("FONTCONFIG_PATH",
                                                            path);
}

void ffmpegkit::FFmpegKitConfig::setFontDirectory(
    const std::string &fontDirectoryPath,
    const std::map<std::string, std::string> &fontNameMapping) {
  ffmpegkit::FFmpegKitConfig::setFontDirectoryList(
      std::list<std::string>{fontDirectoryPath}, fontNameMapping);
}

void ffmpegkit::FFmpegKitConfig::setFontDirectoryList(
    const std::list<std::string> &fontDirectoryList,
    const std::map<std::string, std::string> &fontNameMapping) {
  int validFontNameMappingCount = 0;

  const char *parentDirectory = std::getenv("HOME");
  if (parentDirectory == NULL) {
    parentDirectory = std::getenv("TMPDIR");
    if (parentDirectory == NULL) {
      parentDirectory = ".";
    }
  }

  std::string cacheDir = std::string(parentDirectory) + "/.cache";
  std::string ffmpegKitDir = cacheDir + "/ffmpegkit";
  auto tempConfigurationDirectory = ffmpegKitDir + "/fontconfig";
  auto fontConfigurationFile =
      std::string(tempConfigurationDirectory) + "/fonts.conf";

  if (!fs_create_dir(cacheDir) || !fs_create_dir(ffmpegKitDir) ||
      !fs_create_dir(tempConfigurationDirectory)) {
    return;
  }
  std::cout << "Created temporary font conf directory: TRUE." << std::endl;

  if (fs_exists(fontConfigurationFile, true, false)) {
    bool fontConfigurationDeleted = std::remove(fontConfigurationFile.c_str());
    std::cout << "Deleted old temporary font configuration: "
              << (fontConfigurationDeleted == 0 ? "TRUE" : "FALSE") << "."
              << std::endl;
  }

  /* PROCESS MAPPINGS FIRST */
  std::string fontNameMappingBlock = "";
  for (auto const &pair : fontNameMapping) {
    if ((pair.first.size() > 0) && (pair.second.size() > 0)) {

      fontNameMappingBlock += "    <match target=\"pattern\">\n";
      fontNameMappingBlock += "        <test qual=\"any\" name=\"family\">\n";
      fontNameMappingBlock += "                <string>";
      fontNameMappingBlock += pair.first;
      fontNameMappingBlock += "</string>\n";
      fontNameMappingBlock += "        </test>\n";
      fontNameMappingBlock +=
          "        <edit name=\"family\" mode=\"assign\" binding=\"same\">\n";
      fontNameMappingBlock += "            <string>";
      fontNameMappingBlock += pair.second;
      fontNameMappingBlock += "</string>\n";
      fontNameMappingBlock += "        </edit>\n";
      fontNameMappingBlock += "    </match>\n";

      validFontNameMappingCount++;
    }
  }

  std::string fontConfiguration;
  fontConfiguration += "<?xml version=\"1.0\"?>\n";
  fontConfiguration += "<!DOCTYPE fontconfig SYSTEM \"fonts.dtd\">\n";
  fontConfiguration += "<fontconfig>\n";
  fontConfiguration += "    <dir prefix=\"cwd\">.</dir>\n";

  for (const auto &fontDirectoryPath : fontDirectoryList) {
    fontConfiguration += "    <dir>";
    fontConfiguration += fontDirectoryPath;
    fontConfiguration += "</dir>\n";
  }
  fontConfiguration += fontNameMappingBlock;
  fontConfiguration += "</fontconfig>\n";

  std::ofstream fontConfigurationStream(fontConfigurationFile,
                                        std::ios::out | std::ios::trunc);
  if (fontConfigurationStream) {
    fontConfigurationStream << fontConfiguration;
  }
  if (fontConfigurationStream.bad()) {
    std::cout << "Failed to set font directory. Error received while saving "
                 "font configuration: "
              << fontConfigurationStream.rdbuf() << "." << std::endl;
  }
  fontConfigurationStream.close();

  std::cout << "Saved new temporary font configuration with "
            << validFontNameMappingCount << " font name mappings." << std::endl;

  ffmpegkit::FFmpegKitConfig::setFontconfigConfigurationPath(
      tempConfigurationDirectory.c_str());

  for (const auto &fontDirectoryPath : fontDirectoryList) {
    std::cout << "Font directory " << fontDirectoryPath
              << " registered successfully." << std::endl;
  }
}

std::shared_ptr<std::string>
ffmpegkit::FFmpegKitConfig::registerNewFFmpegPipe() {
  const char *parentDirectory = std::getenv("HOME");
  if (parentDirectory == NULL) {
    parentDirectory = std::getenv("TMPDIR");
    if (parentDirectory == NULL) {
      parentDirectory = ".";
    }
  }

  // PIPES ARE CREATED UNDER THE PIPES DIRECTORY
  std::string cacheDir = std::string(parentDirectory) + "/.cache";
  std::string ffmpegKitDir = cacheDir + "/ffmpegkit";
  std::string pipesDir = ffmpegKitDir + "/pipes";

  if (!fs_create_dir(cacheDir) || !fs_create_dir(ffmpegKitDir) ||
      !fs_create_dir(pipesDir)) {
    return nullptr;
  }

  std::shared_ptr<std::string> newFFmpegPipePath =
      std::make_shared<std::string>(pipesDir + "/" + FFmpegKitNamedPipePrefix +
                                    std::to_string(pipeIndexGenerator++));

  // FIRST CLOSE OLD PIPES WITH THE SAME NAME
  ffmpegkit::FFmpegKitConfig::closeFFmpegPipe(newFFmpegPipePath->c_str());
  int rc = 0;
#ifdef _WIN32
  // Windows doesn't support mkfifo - use named pipes API
  HANDLE hPipe =
      CreateNamedPipeA(newFFmpegPipePath->c_str(), PIPE_ACCESS_DUPLEX,
                       PIPE_TYPE_BYTE | PIPE_WAIT,
                       1,    // Number of instances
                       1024, // Out buffer size
                       1024, // In buffer size
                       0,    // Default timeout
                       NULL  // Default security attributes
      );

  if (hPipe == INVALID_HANDLE_VALUE) {
    rc = -1;
  } else {
    CloseHandle(hPipe);
    rc = 0;
  }
#else
  rc = mkfifo(newFFmpegPipePath->c_str(), S_IRWXU | S_IRWXG | S_IROTH);
#endif

  if (rc == 0) {
    return newFFmpegPipePath;
  } else {
    std::cout << "Failed to register new FFmpeg pipe " << newFFmpegPipePath
              << ". Operation failed with rc=" << rc << "." << std::endl;
    return nullptr;
  }
}

void ffmpegkit::FFmpegKitConfig::closeFFmpegPipe(
    const std::string &ffmpegPipePath) {
  std::remove(ffmpegPipePath.c_str());
}

std::string ffmpegkit::FFmpegKitConfig::getFFmpegVersion() {
  return FFMPEG_VERSION;
}

std::string ffmpegkit::FFmpegKitConfig::getFFmpegArchitecture() {
  return ffmpegkit::ArchDetect::getArch();
}

std::string ffmpegkit::FFmpegKitConfig::getVersion() {
  return FFmpegKitVersion;
}

std::string ffmpegkit::FFmpegKitConfig::getBuildDate() {
  char buildDate[10];
  sprintf(buildDate, "%d", FFMPEG_KIT_BUILD_DATE);
  return std::string(buildDate);
}

int ffmpegkit::FFmpegKitConfig::setEnvironmentVariable(
    const std::string &variableName, const std::string &variableValue) {
#ifdef _WIN32
  return _putenv_s(variableName.c_str(), variableValue.c_str());
#else
  return setenv(variableName.c_str(), variableValue.c_str(), 1);
#endif
}

void ffmpegkit::FFmpegKitConfig::ignoreSignal(const ffmpegkit::Signal signal) {
  if (signal == ffmpegkit::SignalQuit) {
    handleSIGQUIT = 0;
  } else if (signal == ffmpegkit::SignalInt) {
    handleSIGINT = 0;
  } else if (signal == ffmpegkit::SignalTerm) {
    handleSIGTERM = 0;
  } else if (signal == ffmpegkit::SignalXcpu) {
    handleSIGXCPU = 0;
  } else if (signal == ffmpegkit::SignalPipe) {
    handleSIGPIPE = 0;
  }
}

void ffmpegkit::FFmpegKitConfig::ffmpegExecute(
    const std::shared_ptr<ffmpegkit::FFmpegSession> ffmpegSession) {
  ffmpegSession->startRunning();
  tlsSession = ffmpegSession;

  try {
    int returnCodeValue = executeFFmpeg(ffmpegSession->getSessionId(),
                                   ffmpegSession->getArguments());

    // Wait for all logs/stats to be processed by the callback thread
    // Wait BEFORE completing so that the final output is ready when complete callbacks fire
    ffmpegSession->waitForAsynchronousMessagesInTransmit(AbstractSession::DefaultTimeoutForAsynchronousMessagesInTransmit);

    auto returnCode = std::make_shared<ffmpegkit::ReturnCode>(returnCodeValue);
    ffmpegSession->complete(returnCode);
    ffmpegSession->debugLog("[EXECUTE] sessionId: %ld complete", ffmpegSession->getSessionId());
    tlsSession = nullptr;
  } catch (const std::exception &exception) {
    if (ffmpegSession != nullptr) {
      ffmpegSession->debugLog("[EXECUTE] sessionId: %ld exception: %s", ffmpegSession->getSessionId(), exception.what());
    }
    ffmpegSession->fail(exception.what());
    std::cout << "FFmpeg execute failed: "
              << ffmpegkit::FFmpegKitConfig::argumentsToString(
                     ffmpegSession->getArguments())
              << "." << exception.what() << std::endl;
    tlsSession = nullptr;
  }
}

void ffmpegkit::FFmpegKitConfig::ffprobeExecute(
    const std::shared_ptr<ffmpegkit::FFprobeSession> ffprobeSession) {
  ffprobeSession->startRunning();
  tlsSession = ffprobeSession;

  try {
    int returnCodeValue = executeFFprobe(ffprobeSession->getSessionId(),
                                   ffprobeSession->getArguments());

    // Wait for all logs/stats to be processed by the callback thread
    ffprobeSession->waitForAsynchronousMessagesInTransmit(AbstractSession::DefaultTimeoutForAsynchronousMessagesInTransmit);

    auto returnCode = std::make_shared<ffmpegkit::ReturnCode>(returnCodeValue);
    ffprobeSession->complete(returnCode);
    ffprobeSession->debugLog("[EXECUTE PROBE] sessionId: %ld complete", ffprobeSession->getSessionId());
    tlsSession = nullptr;
  } catch (const std::exception &exception) {
    if (ffprobeSession != nullptr) {
      ffprobeSession->debugLog("[EXECUTE PROBE] sessionId: %ld exception: %s", ffprobeSession->getSessionId(), exception.what());
    }
    ffprobeSession->fail(exception.what());
    std::cout << "FFprobe execute failed: "
              << ffmpegkit::FFmpegKitConfig::argumentsToString(
                     ffprobeSession->getArguments())
              << "." << exception.what() << std::endl;
    tlsSession = nullptr;
  }
}

void ffmpegkit::FFmpegKitConfig::ffplayExecute(
    const std::shared_ptr<ffmpegkit::FFplaySession> ffplaySession, int waitTimeout) {

  // 1. START THE SESSION
  ffplaySession->startRunning();
  tlsSession = ffplaySession;

  long sessionId = ffplaySession->getSessionId();

  // SINGLE SESSION ENFORCEMENT
  long previousSessionId = activeFFplaySessionId.exchange(sessionId);
  if (previousSessionId != 0) {
    cancelSession(previousSessionId);

    // Wait for previous session to fully complete cleanup
    auto prevSession = getSession(previousSessionId);
    if (prevSession) {
        if (!prevSession->waitFor(waitTimeout)) {
            std::cout << "FFplay execute failed: Timed out waiting for previous FFplay session " << previousSessionId << " to complete." << std::endl;
            activeFFplaySessionId.compare_exchange_strong(sessionId, 0);
            ffplaySession->fail("Timed out waiting for previous session to complete");
            return;
        }
    }
  }

  // 2. RUN
  try {
    int returnCodeValue = executeFFplay(sessionId, ffplaySession->getArguments());

    // RESET ACTIVE SESSION ID IF IT'S STILL US
    activeFFplaySessionId.compare_exchange_strong(sessionId, 0);

    // Wait for all logs/stats to be processed by the callback thread
    ffplaySession->waitForAsynchronousMessagesInTransmit(AbstractSession::DefaultTimeoutForAsynchronousMessagesInTransmit);

    auto returnCode = std::make_shared<ffmpegkit::ReturnCode>(returnCodeValue);
    ffplaySession->complete(returnCode);
    tlsSession = nullptr;
  } catch (const std::exception &exception) {
    if (ffplaySession != nullptr) {
      ffplaySession->debugLog("[EXECUTE FFPLAY] sessionId: %ld exception: %s", sessionId, exception.what());
    }
    activeFFplaySessionId.compare_exchange_strong(sessionId, 0);
    ffplaySession->fail(exception.what());
    std::cout << "FFplay execute failed: " << exception.what() << std::endl;
    tlsSession = nullptr;
  }
}

void ffmpegkit::FFmpegKitConfig::getMediaInformationExecute(
    const std::shared_ptr<ffmpegkit::MediaInformationSession>
        mediaInformationSession,
    const int waitTimeout) {
  mediaInformationSession->startRunning();

  try {
    int returnCodeValue =
        executeFFprobe(mediaInformationSession->getSessionId(),
                       mediaInformationSession->getArguments());
    auto returnCode = std::make_shared<ffmpegkit::ReturnCode>(returnCodeValue);
    mediaInformationSession->complete(returnCode);
    if (returnCode->isValueSuccess()) {
      auto allLogs =
          mediaInformationSession->getAllLogsWithTimeout(waitTimeout);
      std::string ffprobeJsonOutput;
      std::for_each(allLogs->cbegin(), allLogs->cend(),
                    [&](std::shared_ptr<ffmpegkit::Log> log) {
                      if (log->getLevel() == LevelAVLogStdErr || log->getLevel() == LevelAVLogInfo) {
                        ffprobeJsonOutput.append(log->getMessage());
                      }
                    });
      
      mediaInformationSession->debugLog("[GET MEDIA INFO] sessionId: %ld JSON length: %d", mediaInformationSession->getSessionId(), (int)ffprobeJsonOutput.length());
      
      auto mediaInformation =
          ffmpegkit::MediaInformationJsonParser::fromWithError(
              ffprobeJsonOutput.c_str());
      mediaInformationSession->setMediaInformation(mediaInformation);
      
      if (mediaInformation != nullptr) {
          mediaInformationSession->debugLog("[GET MEDIA INFO] sessionId: %ld parsing SUCCESS", mediaInformationSession->getSessionId());
      }
    }
  } catch (const std::exception &exception) {
    mediaInformationSession->debugLog("[GET MEDIA INFO] sessionId: %ld exception: %s", mediaInformationSession->getSessionId(), exception.what());
    mediaInformationSession->fail(exception.what());
    std::cout << "Get media information execute failed: "
              << ffmpegkit::FFmpegKitConfig::argumentsToString(
                     mediaInformationSession->getArguments())
              << "." << exception.what() << std::endl;
  }
}

void ffmpegkit::FFmpegKitConfig::asyncFFmpegExecute(
    const std::shared_ptr<ffmpegkit::FFmpegSession> ffmpegSession) {
  auto thread = std::thread([ffmpegSession]() {
    ffmpegkit::FFmpegKitConfig::ffmpegExecute(ffmpegSession);

    ffmpegkit::FFmpegSessionCompleteCallback completeCallback =
        ffmpegSession->getCompleteCallback();
    if (completeCallback != nullptr) {
      try {
        // NOTIFY SESSION CALLBACK DEFINED
        ffmpegSession->debugLog("[GET MEDIA INFO] sessionId: %ld NOTIFY SESSION CALLBACK DEFINED", ffmpegSession->getSessionId());
        completeCallback(ffmpegSession);
      } catch (const std::exception &exception) {
        ffmpegSession->debugLog("[GET MEDIA INFO] sessionId: %ld exception: %s", ffmpegSession->getSessionId(), exception.what());
        std::cout << "Exception thrown inside session complete callback. "
                  << exception.what() << std::endl;
      }
    }

    {
      std::lock_guard<std::recursive_mutex> lock(getGlobalCallbacksMutex());
      ffmpegkit::FFmpegSessionCompleteCallback
          globalFFmpegSessionCompleteCallback =
              ffmpegkit::FFmpegKitConfig::getFFmpegSessionCompleteCallback();
      if (globalFFmpegSessionCompleteCallback != nullptr) {
        try {
          // NOTIFY SESSION CALLBACK DEFINED
          ffmpegSession->debugLog("[GET MEDIA INFO] sessionId: %ld NOTIFY GLOBAL SESSION CALLBACK DEFINED", ffmpegSession->getSessionId());
          globalFFmpegSessionCompleteCallback(ffmpegSession);
        } catch (const std::exception &exception) {
          ffmpegSession->debugLog("[GET MEDIA INFO] sessionId: %ld exception: %s", ffmpegSession->getSessionId(), exception.what());
          std::cout << "Exception thrown inside global complete callback. "
                    << exception.what() << std::endl;
        }
      }
    }
  });

  thread.detach();
}

void ffmpegkit::FFmpegKitConfig::asyncFFprobeExecute(
    const std::shared_ptr<ffmpegkit::FFprobeSession> ffprobeSession) {
  auto thread = std::thread([ffprobeSession]() {
    ffmpegkit::FFmpegKitConfig::ffprobeExecute(ffprobeSession);

    ffmpegkit::FFprobeSessionCompleteCallback completeCallback =
        ffprobeSession->getCompleteCallback();
    if (completeCallback != nullptr) {
      try {
        // NOTIFY SESSION CALLBACK DEFINED
        ffprobeSession->debugLog("[GET MEDIA INFO] sessionId: %ld NOTIFY SESSION CALLBACK DEFINED", ffprobeSession->getSessionId());
        completeCallback(ffprobeSession);
      } catch (const std::exception &exception) {
        ffprobeSession->debugLog("[GET MEDIA INFO] sessionId: %ld exception: %s", ffprobeSession->getSessionId(), exception.what());
        std::cout << "Exception thrown inside session complete callback. "
                  << exception.what() << std::endl;
      }
    }

    {
      std::lock_guard<std::recursive_mutex> lock(getGlobalCallbacksMutex());
      ffmpegkit::FFprobeSessionCompleteCallback
          globalFFprobeSessionCompleteCallback =
              ffmpegkit::FFmpegKitConfig::getFFprobeSessionCompleteCallback();
      if (globalFFprobeSessionCompleteCallback != nullptr) {
        try {
          // NOTIFY SESSION CALLBACK DEFINED
          ffprobeSession->debugLog("[GET MEDIA INFO] sessionId: %ld NOTIFY GLOBAL SESSION CALLBACK DEFINED", ffprobeSession->getSessionId());
          globalFFprobeSessionCompleteCallback(ffprobeSession);
        } catch (const std::exception &exception) {
          ffprobeSession->debugLog("[GET MEDIA INFO] sessionId: %ld exception: %s", ffprobeSession->getSessionId(), exception.what());
          std::cout << "Exception thrown inside global complete callback. "
                    << exception.what() << std::endl;
        }
      }
    }
  });

  thread.detach();
}

void ffmpegkit::FFmpegKitConfig::asyncFFplayExecute(
    const std::shared_ptr<ffmpegkit::FFplaySession> ffplaySession, int waitTimeout = 500) {
  auto thread = std::thread([ffplaySession, waitTimeout]() {
    ffmpegkit::FFmpegKitConfig::ffplayExecute(ffplaySession, waitTimeout);

    ffmpegkit::FFplaySessionCompleteCallback completeCallback =
        ffplaySession->getCompleteCallback();
    if (completeCallback != nullptr) {
      try {
        // NOTIFY SESSION CALLBACK DEFINED
        ffplaySession->debugLog("[GET MEDIA INFO] sessionId: %ld NOTIFY SESSION CALLBACK DEFINED", ffplaySession->getSessionId());
        completeCallback(ffplaySession);
      } catch (const std::exception &exception) {
        ffplaySession->debugLog("[GET MEDIA INFO] sessionId: %ld exception: %s", ffplaySession->getSessionId(), exception.what());
        std::cout << "Exception thrown inside session complete callback. "
                  << exception.what() << std::endl;
      }
    }

    {
      std::lock_guard<std::recursive_mutex> lock(getGlobalCallbacksMutex());
      ffmpegkit::FFplaySessionCompleteCallback
          globalFFplaySessionCompleteCallback =
              ffmpegkit::FFmpegKitConfig::getFFplaySessionCompleteCallback();
      if (globalFFplaySessionCompleteCallback != nullptr) {
        try {
          // NOTIFY SESSION CALLBACK DEFINED
          ffplaySession->debugLog("[GET MEDIA INFO] sessionId: %ld NOTIFY GLOBAL SESSION CALLBACK DEFINED", ffplaySession->getSessionId());
          globalFFplaySessionCompleteCallback(ffplaySession);
        } catch (const std::exception &exception) {
          ffplaySession->debugLog("[GET MEDIA INFO] sessionId: %ld exception: %s", ffplaySession->getSessionId(), exception.what());
          std::cout << "Exception thrown inside global complete callback. "
                    << exception.what() << std::endl;
        }
      }
    }
  });

  thread.detach();
}

void ffmpegkit::FFmpegKitConfig::asyncGetMediaInformationExecute(
    const std::shared_ptr<ffmpegkit::MediaInformationSession>
        mediaInformationSession,
    const int waitTimeout) {
  auto thread = std::thread([mediaInformationSession, waitTimeout]() {
    ffmpegkit::FFmpegKitConfig::getMediaInformationExecute(
        mediaInformationSession, waitTimeout);

    ffmpegkit::MediaInformationSessionCompleteCallback completeCallback =
        mediaInformationSession->getCompleteCallback();
    if (completeCallback != nullptr) {
      try {
        // NOTIFY SESSION CALLBACK DEFINED
        mediaInformationSession->debugLog("[GET MEDIA INFO] sessionId: %ld NOTIFY SESSION CALLBACK DEFINED", mediaInformationSession->getSessionId());
        completeCallback(mediaInformationSession);
      } catch (const std::exception &exception) {
        mediaInformationSession->debugLog("[GET MEDIA INFO] sessionId: %ld exception: %s", mediaInformationSession->getSessionId(), exception.what());
        std::cout << "Exception thrown inside session complete callback. "
                  << exception.what() << std::endl;
      }
    }

    {
      std::lock_guard<std::recursive_mutex> lock(getGlobalCallbacksMutex());
      ffmpegkit::MediaInformationSessionCompleteCallback
          globalMediaInformationSessionCompleteCallback = ffmpegkit::
              FFmpegKitConfig::getMediaInformationSessionCompleteCallback();
      if (globalMediaInformationSessionCompleteCallback != nullptr) {
        try {
          // NOTIFY SESSION CALLBACK DEFINED
          mediaInformationSession->debugLog("[GET MEDIA INFO] sessionId: %ld NOTIFY GLOBAL SESSION CALLBACK DEFINED", mediaInformationSession->getSessionId());
          globalMediaInformationSessionCompleteCallback(mediaInformationSession);
        } catch (const std::exception &exception) {
          mediaInformationSession->debugLog("[GET MEDIA INFO] sessionId: %ld exception: %s", mediaInformationSession->getSessionId(), exception.what());
          std::cout << "Exception thrown inside global complete callback. "
                    << exception.what() << std::endl;
        }
      }
    }
  });

  thread.detach();
}

void ffmpegkit::FFmpegKitConfig::enableLogCallback(
    const ffmpegkit::LogCallback callback) {
  std::lock_guard<std::recursive_mutex> lock(getGlobalCallbacksMutex());
  logCallback = callback;
}

void ffmpegkit::FFmpegKitConfig::enableStatisticsCallback(
    const ffmpegkit::StatisticsCallback callback) {
  std::lock_guard<std::recursive_mutex> lock(getGlobalCallbacksMutex());
  statisticsCallback = callback;
}

void ffmpegkit::FFmpegKitConfig::enableFFmpegSessionCompleteCallback(
    const FFmpegSessionCompleteCallback completeCallback) {
  std::lock_guard<std::recursive_mutex> lock(getGlobalCallbacksMutex());
  ffmpegSessionCompleteCallback = completeCallback;
}

ffmpegkit::FFmpegSessionCompleteCallback
ffmpegkit::FFmpegKitConfig::getFFmpegSessionCompleteCallback() {
  std::lock_guard<std::recursive_mutex> lock(getGlobalCallbacksMutex());
  return ffmpegSessionCompleteCallback;
}

void ffmpegkit::FFmpegKitConfig::enableFFprobeSessionCompleteCallback(
    const FFprobeSessionCompleteCallback completeCallback) {
  std::lock_guard<std::recursive_mutex> lock(getGlobalCallbacksMutex());
  ffprobeSessionCompleteCallback = completeCallback;
}

ffmpegkit::FFprobeSessionCompleteCallback
ffmpegkit::FFmpegKitConfig::getFFprobeSessionCompleteCallback() {
  std::lock_guard<std::recursive_mutex> lock(getGlobalCallbacksMutex());
  return ffprobeSessionCompleteCallback;
}

void ffmpegkit::FFmpegKitConfig::enableFFplaySessionCompleteCallback(
    const FFplaySessionCompleteCallback completeCallback) {
  std::lock_guard<std::recursive_mutex> lock(getGlobalCallbacksMutex());
  ffplaySessionCompleteCallback = completeCallback;
}

ffmpegkit::FFplaySessionCompleteCallback
ffmpegkit::FFmpegKitConfig::getFFplaySessionCompleteCallback() {
  std::lock_guard<std::recursive_mutex> lock(getGlobalCallbacksMutex());
  return ffplaySessionCompleteCallback;
}

void ffmpegkit::FFmpegKitConfig::enableMediaInformationSessionCompleteCallback(
    const MediaInformationSessionCompleteCallback completeCallback) {
  std::lock_guard<std::recursive_mutex> lock(getGlobalCallbacksMutex());
  mediaInformationSessionCompleteCallback = completeCallback;
}

ffmpegkit::MediaInformationSessionCompleteCallback
ffmpegkit::FFmpegKitConfig::getMediaInformationSessionCompleteCallback() {
  std::lock_guard<std::recursive_mutex> lock(getGlobalCallbacksMutex());
  return mediaInformationSessionCompleteCallback;
}

ffmpegkit::Level ffmpegkit::FFmpegKitConfig::getLogLevel() {
  return static_cast<ffmpegkit::Level>(configuredLogLevel);
}

void ffmpegkit::FFmpegKitConfig::setLogLevel(const ffmpegkit::Level level) {
  configuredLogLevel = level;
  av_log_set_level((int)level);
}

std::string
ffmpegkit::FFmpegKitConfig::logLevelToString(const ffmpegkit::Level level) {
  switch (level) {
  case ffmpegkit::LevelAVLogStdErr:
    return "STDERR";
  case ffmpegkit::LevelAVLogTrace:
    return "TRACE";
  case ffmpegkit::LevelAVLogDebug:
    return "DEBUG";
  case ffmpegkit::LevelAVLogVerbose:
    return "VERBOSE";
  case ffmpegkit::LevelAVLogInfo:
    return "INFO";
  case ffmpegkit::LevelAVLogWarning:
    return "WARNING";
  case ffmpegkit::LevelAVLogError:
    return "ERROR";
  case ffmpegkit::LevelAVLogFatal:
    return "FATAL";
  case ffmpegkit::LevelAVLogPanic:
    return "PANIC";
  case ffmpegkit::LevelAVLogQuiet:
    return "QUIET";
  default:
    return "";
  }
}

int ffmpegkit::FFmpegKitConfig::getSessionHistorySize() {
  return sessionHistorySize;
}

void ffmpegkit::FFmpegKitConfig::setSessionHistorySize(
    const int newSessionHistorySize) {
  if (newSessionHistorySize >= SESSION_MAP_SIZE) {

    /*
     * THERE IS A HARD LIMIT ON THE NATIVE SIDE. HISTORY SIZE MUST BE SMALLER
     * THAN SESSION_MAP_SIZE
     */
    throw std::runtime_error(
        "Session history size must not exceed the hard limit!");
  } else if (newSessionHistorySize > 0) {
    sessionHistorySize = newSessionHistorySize;
    deleteExpiredSessions();
  }
}

std::shared_ptr<ffmpegkit::Session>
ffmpegkit::FFmpegKitConfig::getSession(const long sessionId) {
  std::unique_lock<std::recursive_mutex> lock(getSessionMutex(), std::defer_lock);
  lock.lock();

  auto session = getSessionHistoryMap().find(sessionId);
  if (session != getSessionHistoryMap().end()) {
    return session->second;
  } else {
    return nullptr;
  }
}

std::shared_ptr<ffmpegkit::Session>
ffmpegkit::FFmpegKitConfig::getLastSession() {
  std::unique_lock<std::recursive_mutex> lock(getSessionMutex(), std::defer_lock);

  lock.lock();

  if (getSessionHistoryList().empty()) {
    return nullptr;
  }

  return getSessionHistoryList().front();
}

std::shared_ptr<ffmpegkit::FFmpegSession>
ffmpegkit::FFmpegKitConfig::getLastFFmpegSession() {
  std::unique_lock<std::recursive_mutex> lock(getSessionMutex(), std::defer_lock);

  lock.lock();

  if (getSessionHistoryList().empty()) {
    return nullptr;
  }

  for (auto rit = getSessionHistoryList().rbegin(); rit != getSessionHistoryList().rend();
       ++rit) {
    auto session = *rit;
    if (session->isFFmpeg()) {
      return std::dynamic_pointer_cast<ffmpegkit::FFmpegSession>(session);
    }
  }

  return nullptr;
}

std::shared_ptr<ffmpegkit::FFprobeSession>
ffmpegkit::FFmpegKitConfig::getLastFFprobeSession() {
  std::unique_lock<std::recursive_mutex> lock(getSessionMutex(), std::defer_lock);

  lock.lock();

  if (getSessionHistoryList().empty()) {
    return nullptr;
  }

  for (auto rit = getSessionHistoryList().rbegin(); rit != getSessionHistoryList().rend();
       ++rit) {
    auto session = *rit;
    if (session->isFFprobe()) {
      return std::dynamic_pointer_cast<ffmpegkit::FFprobeSession>(session);
    }
  }

  return nullptr;
}

std::shared_ptr<ffmpegkit::FFplaySession>
ffmpegkit::FFmpegKitConfig::getLastFFplaySession() {
  std::unique_lock<std::recursive_mutex> lock(getSessionMutex(), std::defer_lock);

  lock.lock();

  if (getSessionHistoryList().empty()) {
    return nullptr;
  }

  for (auto rit = getSessionHistoryList().rbegin(); rit != getSessionHistoryList().rend();
       ++rit) {
    auto session = *rit;
    if (session->isFFplay()) {
      return std::dynamic_pointer_cast<ffmpegkit::FFplaySession>(session);
    }
  }

  return nullptr;
}

std::shared_ptr<ffmpegkit::MediaInformationSession>
ffmpegkit::FFmpegKitConfig::getLastMediaInformationSession() {
  std::unique_lock<std::recursive_mutex> lock(getSessionMutex(), std::defer_lock);

  lock.lock();

  if (getSessionHistoryList().empty()) {
    return nullptr;
  }

  for (auto rit = getSessionHistoryList().rbegin(); rit != getSessionHistoryList().rend();
       ++rit) {
    auto session = *rit;
    if (session->isMediaInformation()) {
      return std::dynamic_pointer_cast<ffmpegkit::MediaInformationSession>(session);
    }
  }

  return nullptr;
}

std::shared_ptr<ffmpegkit::Session>
ffmpegkit::FFmpegKitConfig::getLastCompletedSession() {
  std::unique_lock<std::recursive_mutex> lock(getSessionMutex(), std::defer_lock);

  lock.lock();

  for (auto rit = getSessionHistoryList().rbegin(); rit != getSessionHistoryList().rend();
       ++rit) {
    auto session = *rit;
    if (session->getState() == SessionStateCompleted) {
      return session;
    }
  }

  return nullptr;
}

std::shared_ptr<std::list<std::shared_ptr<ffmpegkit::Session>>>
ffmpegkit::FFmpegKitConfig::getSessions() {
  std::unique_lock<std::recursive_mutex> lock(getSessionMutex(), std::defer_lock);
  lock.lock();

  auto sessionHistoryListCopy =
      std::make_shared<std::list<std::shared_ptr<ffmpegkit::Session>>>(
          getSessionHistoryList());

  lock.unlock();

  return sessionHistoryListCopy;
}

void ffmpegkit::FFmpegKitConfig::clearSessions() {
  std::unique_lock<std::recursive_mutex> lock(getSessionMutex(), std::defer_lock);
  lock.lock();

  getSessionHistoryList().clear();
  getSessionHistoryMap().clear();

  lock.unlock();
}

std::shared_ptr<std::list<std::shared_ptr<ffmpegkit::FFmpegSession>>>
ffmpegkit::FFmpegKitConfig::getFFmpegSessions() {
  std::unique_lock<std::recursive_mutex> lock(getSessionMutex(), std::defer_lock);
  const auto ffmpegSessions =
      std::make_shared<std::list<std::shared_ptr<ffmpegkit::FFmpegSession>>>();

  lock.lock();

  for (auto it = getSessionHistoryList().begin(); it != getSessionHistoryList().end();
       ++it) {
    auto session = *it;
    if (session->isFFmpeg()) {
      ffmpegSessions->push_back(
          std::static_pointer_cast<ffmpegkit::FFmpegSession>(session));
    }
  }

  lock.unlock();

  return ffmpegSessions;
}

std::shared_ptr<std::list<std::shared_ptr<ffmpegkit::FFprobeSession>>>
ffmpegkit::FFmpegKitConfig::getFFprobeSessions() {
  std::unique_lock<std::recursive_mutex> lock(getSessionMutex(), std::defer_lock);
  std::shared_ptr<std::list<std::shared_ptr<ffmpegkit::FFprobeSession>>>
      result = std::make_shared<
          std::list<std::shared_ptr<ffmpegkit::FFprobeSession>>>();

  lock.lock();

  for (auto it = getSessionHistoryList().begin(); it != getSessionHistoryList().end();
       ++it) {
    if ((*it)->isFFprobe()) {
      result->push_back(
          std::static_pointer_cast<ffmpegkit::FFprobeSession>(*it));
    }
  }

  lock.unlock();

  return result;
}

std::shared_ptr<std::list<std::shared_ptr<ffmpegkit::FFplaySession>>>
ffmpegkit::FFmpegKitConfig::getFFplaySessions() {
  std::unique_lock<std::recursive_mutex> lock(getSessionMutex(), std::defer_lock);
  std::shared_ptr<std::list<std::shared_ptr<ffmpegkit::FFplaySession>>>
      result = std::make_shared<
          std::list<std::shared_ptr<ffmpegkit::FFplaySession>>>();

  lock.lock();

  for (auto it = getSessionHistoryList().begin(); it != getSessionHistoryList().end();
       ++it) {
    if ((*it)->isFFplay()) {
      result->push_back(
          std::static_pointer_cast<ffmpegkit::FFplaySession>(*it));
    }
  }

  lock.unlock();

  return result;
}

std::shared_ptr<ffmpegkit::FFplaySession>
ffmpegkit::FFmpegKitConfig::getActiveFFplaySession() {
  long sessionId = activeFFplaySessionId.load();
  if (sessionId != 0) {
    return std::static_pointer_cast<FFplaySession>(getSession(sessionId));
  }
  return nullptr;
}

std::shared_ptr<std::list<std::shared_ptr<ffmpegkit::MediaInformationSession>>>
ffmpegkit::FFmpegKitConfig::getMediaInformationSessions() {
  std::unique_lock<std::recursive_mutex> lock(getSessionMutex(), std::defer_lock);
  const auto mediaInformationSessions = std::make_shared<
      std::list<std::shared_ptr<ffmpegkit::MediaInformationSession>>>();

  lock.lock();

  for (auto it = getSessionHistoryList().begin(); it != getSessionHistoryList().end();
       ++it) {
    auto session = *it;
    if (session->isMediaInformation()) {
      mediaInformationSessions->push_back(
          std::static_pointer_cast<ffmpegkit::MediaInformationSession>(
              session));
    }
  }

  lock.unlock();

  return mediaInformationSessions;
}

std::shared_ptr<std::list<std::shared_ptr<ffmpegkit::Session>>>
ffmpegkit::FFmpegKitConfig::getSessionsByState(const SessionState state) {
  std::unique_lock<std::recursive_mutex> lock(getSessionMutex(), std::defer_lock);
  auto sessions =
      std::make_shared<std::list<std::shared_ptr<ffmpegkit::Session>>>();

  lock.lock();

  for (auto it = getSessionHistoryList().begin(); it != getSessionHistoryList().end();
       ++it) {
    auto session = *it;
    if (session->getState() == state) {
      sessions->push_back(session);
    }
  }

  lock.unlock();

  return sessions;
}

ffmpegkit::LogRedirectionStrategy
ffmpegkit::FFmpegKitConfig::getLogRedirectionStrategy() {
  return globalLogRedirectionStrategy;
}

void ffmpegkit::FFmpegKitConfig::setLogRedirectionStrategy(
    const LogRedirectionStrategy logRedirectionStrategy) {
  globalLogRedirectionStrategy = logRedirectionStrategy;
}

int ffmpegkit::FFmpegKitConfig::messagesInTransmit(const long sessionId) {
  return std::atomic_load(
      &sessionInTransitMessageCountMap[sessionId % SESSION_MAP_SIZE]);
}

std::string
ffmpegkit::FFmpegKitConfig::sessionStateToString(SessionState state) {
  switch (state) {
  case SessionStateCreated:
    return "CREATED";
  case SessionStateRunning:
    return "RUNNING";
  case SessionStateFailed:
    return "FAILED";
  case SessionStateCompleted:
    return "COMPLETED";
  default:
    return "";
  }
}

std::list<std::string>
ffmpegkit::FFmpegKitConfig::parseArguments(const std::string &command) {
  std::list<std::string> argumentList;
  std::string currentArgument;

  bool singleQuoteStarted = false;
  bool doubleQuoteStarted = false;

  for (int i = 0; i < command.size(); i++) {
    char previousChar;
    if (i > 0) {
      previousChar = command[i - 1];
    } else {
      previousChar = 0;
    }
    char currentChar = command[i];

    if (currentChar == ' ') {
      if (singleQuoteStarted || doubleQuoteStarted) {
        currentArgument += currentChar;
      } else if (currentArgument.size() > 0) {
        argumentList.push_back(currentArgument);
        currentArgument = "";
      }
    } else if (currentChar == '\'' &&
               (previousChar == 0 || previousChar != '\\')) {
      if (singleQuoteStarted) {
        singleQuoteStarted = false;
      } else if (doubleQuoteStarted) {
        currentArgument += currentChar;
      } else {
        singleQuoteStarted = true;
      }
    } else if (currentChar == '\"' &&
               (previousChar == 0 || previousChar != '\\')) {
      if (doubleQuoteStarted) {
        doubleQuoteStarted = false;
      } else if (singleQuoteStarted) {
        currentArgument += currentChar;
      } else {
        doubleQuoteStarted = true;
      }
    } else {
      currentArgument += currentChar;
    }
  }

  if (currentArgument.size() > 0) {
    argumentList.push_back(currentArgument);
  }

  return argumentList;
}

std::string ffmpegkit::FFmpegKitConfig::argumentsToString(
    std::shared_ptr<std::list<std::string>> arguments) {
  if (arguments == nullptr) {
    return "null";
  }

  std::string string;
  for (auto it = arguments->begin(); it != arguments->end(); ++it) {
    auto argument = *it;
    if (it != arguments->begin()) {
      string += " ";
    }
    string += argument;
  }

  return string;
}

void ffmpegkit::FFmpegKitConfig::setAudioOutputDevice(const std::string &deviceName) {
    ffplay_set_audio_output_device(deviceName.empty() ? nullptr : deviceName.c_str());
}

std::string ffmpegkit::FFmpegKitConfig::listAudioOutputDevices() {
    char* devices = ffplay_list_audio_devices();
    std::string result = "";
    if (devices) {
        result = std::string(devices);
        av_free(devices);
    }
    return result;
}

ffmpegkit::FFmpegKitConfig::~FFmpegKitConfig() {
  // 1. Stop background redirection thread first to prevent races on sessions
  disableRedirection();

  // 2. Clear session history
  clearSessions();
  // 2. Reset global callbacks with lock
  {
    std::lock_guard<std::recursive_mutex> lock(getGlobalCallbacksMutex());
    logCallback = nullptr;
    statisticsCallback = nullptr;
    ffmpegSessionCompleteCallback = nullptr;
    ffprobeSessionCompleteCallback = nullptr;
    ffplaySessionCompleteCallback = nullptr;
    mediaInformationSessionCompleteCallback = nullptr;
  }
  // 3. Clear remaining callback data raw pointers
  std::lock_guard<std::recursive_mutex> lock(getCallbackDataMutex());
  while (!getCallbackDataList().empty()) {
    delete getCallbackDataList().front();
    getCallbackDataList().pop_front();
  }
}

// At the very end of FFmpegKitConfig.cpp
namespace ffmpegkit {
    static FFmpegKitConfig globalCleanupGuard;
}