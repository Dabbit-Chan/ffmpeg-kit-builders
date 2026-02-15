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
#include <cstring>

using namespace ffmpegkit;

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

template <typename T> static void *to_handle(std::shared_ptr<T> ptr) {
  if (!ptr)
    return nullptr;
  return new std::shared_ptr<T>(ptr);
}

template <typename T> static std::shared_ptr<T> from_handle(void *handle) {
  if (!handle)
    return nullptr;
  return *static_cast<std::shared_ptr<T> *>(handle);
}

template <typename T> static void *create_handle(std::shared_ptr<T> ptr) {
  // Cast to void shared_ptr to allow generic deletion
  return new std::shared_ptr<void>(ptr);
}

template <typename T> static std::shared_ptr<T> get_ptr(void *handle) {
  if (!handle)
    return nullptr;
  auto void_ptr = *static_cast<std::shared_ptr<void> *>(handle);
  return std::static_pointer_cast<T>(void_ptr);
}

template <typename T>
static void **
list_to_handle_array(std::shared_ptr<std::list<std::shared_ptr<T>>> list) {
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
}

extern "C" {

void ffmpeg_kit_handle_release(void *handle) {
  if (handle) {
    delete static_cast<std::shared_ptr<void> *>(handle);
  }
}

/* FFmpegKit */

FFmpegSessionHandle ffmpeg_kit_execute(const char *command) {
  if (!command)
    return nullptr;
  auto session = FFmpegKit::execute(std::string(command));
  return create_handle(session);
}

FFmpegSessionHandle
ffmpeg_kit_execute_async(const char *command,
                         FFmpegKitCompleteCallback complete_cb,
                         void *user_data) {
  if (!command)
    return nullptr;
  auto lambda = [complete_cb, user_data](std::shared_ptr<Session> s) {
    if (complete_cb) {
      auto handle = create_handle(std::dynamic_pointer_cast<FFmpegSession>(s));
      complete_cb(handle, user_data);
      ffmpeg_kit_handle_release(handle);
    }
  };
  auto session = FFmpegKit::executeAsync(std::string(command), lambda);
  return create_handle(session);
}

FFmpegSessionHandle ffmpeg_kit_execute_async_full(
    const char *command, FFmpegKitCompleteCallback complete_cb,
    FFmpegKitLogCallback log_cb, FFmpegKitStatisticsCallback stats_cb,
    void *user_data, int waitTimeout) {
  if (!command)
    return nullptr;
  auto complete = [complete_cb, user_data](std::shared_ptr<Session> s) {
    if (complete_cb) {
      auto handle = create_handle(std::dynamic_pointer_cast<FFmpegSession>(s));
      complete_cb(handle, user_data);
      ffmpeg_kit_handle_release(handle);
    }
  };
  auto log = [log_cb, user_data](std::shared_ptr<Log> l) {
    if (log_cb) {
      log_cb(nullptr, l->getMessage().c_str(), user_data);
    }
  };
  auto stats = [stats_cb, user_data](std::shared_ptr<Statistics> s) {
    if (stats_cb) {
      stats_cb(nullptr, s->getTime(), s->getSize(), s->getBitrate(),
               s->getSpeed(), s->getVideoFrameNumber(), s->getVideoFps(),
               s->getVideoQuality(), user_data);
    }
  };

  auto session =
      FFmpegKit::executeAsync(std::string(command), complete, log, stats);
  return create_handle(session);
}

FFmpegSessionHandle ffmpeg_kit_create_session(const char *command) {
  if (!command)
    return nullptr;
  auto arguments = FFmpegKitConfig::parseArguments(command);
  auto session = FFmpegSession::create(arguments);
  return create_handle(session);
}

void ffmpeg_kit_session_execute(FFmpegSessionHandle session) {
  auto ptr = get_ptr<FFmpegSession>(session);
  if (ptr) {
    FFmpegKitConfig::ffmpegExecute(ptr);
  }
}

void ffmpeg_kit_session_execute_async(FFmpegSessionHandle session) {
  auto ptr = get_ptr<FFmpegSession>(session);
  if (ptr) {
    FFmpegKitConfig::asyncFFmpegExecute(ptr);
  }
}

void ffmpeg_kit_cancel(void) { FFmpegKit::cancel(); }

void ffmpeg_kit_cancel_session(long session_id) {
  FFmpegKit::cancel(session_id);
}

/* FFprobeKit */

FFprobeSessionHandle ffprobe_kit_execute(const char *command) {
  if (!command)
    return nullptr;
  auto session = FFprobeKit::execute(std::string(command));
  return create_handle(session);
}

FFprobeSessionHandle
ffprobe_kit_execute_async(const char *command,
                          FFprobeKitCompleteCallback complete_cb,
                          void *user_data) {
  if (!command)
    return nullptr;
  auto lambda = [complete_cb, user_data](std::shared_ptr<Session> s) {
    if (complete_cb) {
      auto handle = create_handle(std::dynamic_pointer_cast<FFprobeSession>(s));
      complete_cb(handle, user_data);
      ffmpeg_kit_handle_release(handle);
    }
  };
  auto session = FFprobeKit::executeAsync(std::string(command), lambda);
  return create_handle(session);
}

FFprobeSessionHandle ffprobe_kit_create_session(const char *command) {
  if (!command)
    return nullptr;
  auto arguments = FFmpegKitConfig::parseArguments(command);
  auto session = FFprobeSession::create(arguments);
  return create_handle(session);
}

void ffprobe_kit_session_execute(FFprobeSessionHandle session) {
  auto ptr = get_ptr<FFprobeSession>(session);
  if (ptr) {
    FFmpegKitConfig::ffprobeExecute(ptr);
  }
}

void ffprobe_kit_session_execute_async(FFprobeSessionHandle session) {
  auto ptr = get_ptr<FFprobeSession>(session);
  if (ptr) {
    FFmpegKitConfig::asyncFFprobeExecute(ptr);
  }
}

MediaInformationSessionHandle
ffprobe_kit_get_media_information(const char *path) {
  if (!path)
    return nullptr;
  auto session = FFprobeKit::getMediaInformation(std::string(path));
  return create_handle(session);
}

MediaInformationSessionHandle ffprobe_kit_get_media_information_async(
    const char *path, ::MediaInformationSessionCompleteCallback complete_cb,
    void *user_data) {
  if (!path)
    return nullptr;
  auto lambda = [complete_cb,
                 user_data](std::shared_ptr<MediaInformationSession> s) {
    if (complete_cb) {
      auto handle = create_handle(s);
      complete_cb(handle, user_data);
      ffmpeg_kit_handle_release(handle);
    }
  };
  auto session =
      FFprobeKit::getMediaInformationAsync(std::string(path), lambda);
  return create_handle(session);
}

/* FFplayKit */

FFplaySessionHandle ffplay_kit_execute(const char *command, int timeout) {
  if (!command)
    return nullptr;
  auto session = FFplayKit::execute(std::string(command), timeout);
  return create_handle(session);
}

FFplaySessionHandle
ffplay_kit_execute_async(const char *command,
                         FFplayKitCompleteCallback complete_cb,
                         void *user_data, int waitTimeout) {
  if (!command)
    return nullptr;
  auto lambda = [complete_cb, user_data](std::shared_ptr<Session> s) {
    if (complete_cb) {
      auto handle = create_handle(std::dynamic_pointer_cast<FFplaySession>(s));
      complete_cb(handle, user_data);
      ffmpeg_kit_handle_release(handle);
    }
  };
  auto session = FFplayKit::executeAsync(std::string(command), lambda, waitTimeout);
  return create_handle(session);
}

FFplaySessionHandle ffplay_kit_create_session(const char *command) {
  if (!command)
    return nullptr;
  auto arguments = FFmpegKitConfig::parseArguments(command);
  auto session = FFplaySession::create(arguments);
  return create_handle(session);
}

void ffplay_kit_session_execute(FFplaySessionHandle session, int timeout) {
  auto ptr = get_ptr<FFplaySession>(session);
  if (ptr) {  
    FFmpegKitConfig::ffplayExecute(ptr, timeout);
  }
}

FFplaySessionHandle ffplay_kit_get_current_session(void) {
  auto session = FFmpegKitConfig::getActiveFFplaySession();
  return create_handle(std::dynamic_pointer_cast<FFplaySession>(session));
}

void ffplay_kit_session_execute_async(FFplaySessionHandle session, int timeout) {
  auto ptr = get_ptr<FFplaySession>(session);
  if (ptr) {
    FFmpegKitConfig::asyncFFplayExecute(ptr, timeout);
  }
}

void ffplay_kit_session_seek(FFplaySessionHandle session, double seconds) {
  auto ptr = get_ptr<FFplaySession>(session);
  if (ptr) {
    ptr->seek(seconds);
  }
}

void ffplay_kit_session_pause(FFplaySessionHandle session) {
  auto ptr = get_ptr<FFplaySession>(session);
  if (ptr) {
    ptr->pause();
  }
}

void ffplay_kit_session_start(FFplaySessionHandle session) {
  auto ptr = get_ptr<FFplaySession>(session);
  if (ptr) {
    ptr->start();
  }
}

void ffplay_kit_session_resume(FFplaySessionHandle session) {
  auto ptr = get_ptr<FFplaySession>(session);
  if (ptr) {
    ptr->resume();
  }
}

void ffplay_kit_session_stop(FFplaySessionHandle session) {
  auto ptr = get_ptr<FFplaySession>(session);
  if (ptr) {
    ptr->stop();
  }
}

void ffplay_kit_session_close(FFplaySessionHandle session) {
  auto ptr = get_ptr<FFplaySession>(session);
  if (ptr) {
    ptr->close();
  }
}

double ffplay_kit_session_get_position(FFplaySessionHandle session) {
  auto ptr = get_ptr<FFplaySession>(session);
  if (ptr) {
    return ptr->getPosition();
  }
  return 0.0;
}

void ffplay_kit_session_set_position(FFplaySessionHandle session, double seconds) {
  auto ptr = get_ptr<FFplaySession>(session);
  if (ptr) {
    ptr->setPosition(seconds);
  }
}

double ffplay_kit_session_get_duration(FFplaySessionHandle session) {
  auto ptr = get_ptr<FFplaySession>(session);
  if (ptr) {
    return ptr->getDuration();
  }
  return 0.0;
}

int ffplay_kit_session_is_playing(FFplaySessionHandle session) {
  auto ptr = get_ptr<FFplaySession>(session);
  if (ptr) {
    return ptr->isPlaying() ? 1 : 0;
  }
  return 0;
}

int ffplay_kit_session_is_paused(FFplaySessionHandle session) {
  auto ptr = get_ptr<FFplaySession>(session);
  if (ptr) {
    return ptr->isPaused() ? 1 : 0;
  }
  return 0;
}

void ffplay_kit_session_set_volume(FFplaySessionHandle session, float volume) {
  auto ptr = get_ptr<FFplaySession>(session);
  if (ptr) {
    ptr->setVolume(volume);
  }
}

float ffplay_kit_session_get_volume(FFplaySessionHandle session) {
  auto ptr = get_ptr<FFplaySession>(session);
  if (ptr) {
    return ptr->getVolume();
  }
  return 0.0;
}

void ffplay_kit_seek(double seconds) { FFplayKit::seek(seconds); }

void ffplay_kit_start(void) { FFplayKit::start(); }

void ffplay_kit_pause(void) { FFplayKit::pause(); }

void ffplay_kit_resume(void) { FFplayKit::resume(); }

void ffplay_kit_stop(void) { FFplayKit::stop(); }

void ffplay_kit_close(void) { FFplayKit::close(); }

double ffplay_kit_get_position(void) { return FFplayKit::getPosition(); }

void ffplay_kit_set_position(double seconds) { FFplayKit::setPosition(seconds); }

double ffplay_kit_get_duration(void) { return FFplayKit::getDuration(); }

int ffplay_kit_is_playing(void) { return FFplayKit::isPlaying() ? 1 : 0; }

int ffplay_kit_is_paused(void) { return FFplayKit::isPaused() ? 1 : 0; }

void ffplay_kit_set_volume(float volume) { FFplayKit::setVolume(volume); }

float ffplay_kit_get_volume(void) { return FFplayKit::getVolume(); }

/* Config */

void ffmpeg_kit_config_enable_redirection(void) {
  FFmpegKitConfig::enableRedirection();
}

void ffmpeg_kit_config_disable_redirection(void) {
  FFmpegKitConfig::disableRedirection();
}

void ffmpeg_kit_config_set_log_level(FFmpegKitLogLevel level) {
  FFmpegKitConfig::setLogLevel((Level)level);
}

FFmpegKitLogLevel ffmpeg_kit_config_get_log_level(void) {
  return (FFmpegKitLogLevel)FFmpegKitConfig::getLogLevel();
}

char *ffmpeg_kit_config_log_level_to_string(FFmpegKitLogLevel level) {
  return strdup_cpp(FFmpegKitConfig::logLevelToString((Level)level));
}

void ffmpeg_kit_config_set_font_directory(const char *path,
                                          const char *name_mappings_json) {
  // Mapping JSON parsing omitted for brevity/simplicity as it requires a JSON
  // parser. Passing empty map for now if null.
  std::map<std::string, std::string> map;
  FFmpegKitConfig::setFontDirectory(path ? std::string(path) : "", map);
}

int ffmpeg_kit_config_set_environment_variable(const char *name,
                                               const char *value) {
  if (!name || !value)
    return -1;
  return FFmpegKitConfig::setEnvironmentVariable(std::string(name),
                                                 std::string(value));
}

void ffmpeg_kit_config_ignore_signal(FFmpegKitSignal signal) {
  FFmpegKitConfig::ignoreSignal((Signal)signal);
}

char *ffmpeg_kit_config_get_ffmpeg_version(void) {
  return strdup_cpp(FFmpegKitConfig::getFFmpegVersion());
}

char *ffmpeg_kit_config_get_ffmpeg_architecture(void) {
  return strdup_cpp(FFmpegKitConfig::getFFmpegArchitecture());
}

char *ffmpeg_kit_config_get_version(void) {
  return strdup_cpp(FFmpegKitConfig::getVersion());
}

void ffmpeg_kit_config_set_audio_output_device(const char* device_name) {
  FFmpegKitConfig::setAudioOutputDevice(device_name ? std::string(device_name) : "");
}

char* ffmpeg_kit_config_list_audio_output_devices(void) {
  return strdup_cpp(FFmpegKitConfig::listAudioOutputDevices());
}

/* Packages */

char *ffmpeg_kit_packages_get_package_name(void) {
  return strdup_cpp(Packages::getPackageName());
}

char *ffmpeg_kit_packages_get_bundled_libraries(void) {
  auto libs = Packages::getExternalLibraries();
  std::string result = "";
  for (const auto &lib : *libs) {
    if (!result.empty())
      result += ", ";
    result += lib;
  }
  return strdup_cpp(result);
}

char *ffmpeg_kit_packages_get_external_libraries(void) {
  auto libs = Packages::getExternalLibraries();
  std::string result = "";
  for (const auto &lib : *libs) {
    if (!result.empty())
      result += ", ";
    result += lib;
  }
  return strdup_cpp(result);
}

/* Session Management */

long ffmpeg_kit_session_get_session_id(void *session_handle) {
  if (!session_handle)
    return -1;
  return get_ptr<Session>(session_handle)->getSessionId();
}

FFmpegKitSessionState ffmpeg_kit_session_get_state(void *session_handle) {
  if (!session_handle)
    return FFMPEG_KIT_SESSION_STATE_CREATED;
  return (FFmpegKitSessionState)get_ptr<Session>(session_handle)->getState();
}

int ffmpeg_kit_session_get_return_code(void *session_handle) {
  if (!session_handle)
    return -1;
  auto obj = get_ptr<Session>(session_handle)->getReturnCode();
  return obj ? obj->getValue() : -1;
}

char *ffmpeg_kit_session_get_output(void *session_handle) {
  if (!session_handle)
    return nullptr;
  return strdup_cpp(get_ptr<Session>(session_handle)->getOutput());
}

char *ffmpeg_kit_session_get_logs_as_string(void *session_handle) {
  if (!session_handle)
    return nullptr;
  return strdup_cpp(get_ptr<Session>(session_handle)->getLogsAsString());
}

char *ffmpeg_kit_session_get_fail_stack_trace(void *session_handle) {
  if (!session_handle)
    return nullptr;
  return strdup_cpp(get_ptr<Session>(session_handle)->getFailStackTrace());
}

/* Media Information Session Specific */

MediaInformationSessionHandle media_information_create_session(
    const char *command) {
  if (!command)
    return nullptr;
  auto arguments = FFmpegKitConfig::parseArguments(command);
  auto session = MediaInformationSession::create(arguments);
  return create_handle(session);
}

void media_information_session_execute(MediaInformationSessionHandle session, int timeout) {
  auto ptr = get_ptr<MediaInformationSession>(session);
  if (ptr) {
    FFmpegKitConfig::getMediaInformationExecute(ptr, timeout);
  }
}

void media_information_session_execute_async(
    MediaInformationSessionHandle session, int timeout) {
  auto ptr = get_ptr<MediaInformationSession>(session);
  if (ptr) {
    FFmpegKitConfig::asyncGetMediaInformationExecute(ptr, timeout);
  }
}

MediaInformationHandle media_information_session_get_media_information(
    MediaInformationSessionHandle session) {
  if (!session)
    return nullptr;
  auto info = get_ptr<MediaInformationSession>(session)->getMediaInformation();
  return create_handle(info);
}

/* Media Information */

char *media_information_get_filename(MediaInformationHandle handle) {
  auto ptr = get_ptr<MediaInformation>(handle);
  return ptr ? strdup_safe_ptr(ptr->getFilename()) : nullptr;
}
char *media_information_get_format(MediaInformationHandle handle) {
  auto ptr = get_ptr<MediaInformation>(handle);
  return ptr ? strdup_safe_ptr(ptr->getFormat()) : nullptr;
}
char *media_information_get_long_format(MediaInformationHandle handle) {
  auto ptr = get_ptr<MediaInformation>(handle);
  return ptr ? strdup_safe_ptr(ptr->getLongFormat()) : nullptr;
}
char *media_information_get_duration(MediaInformationHandle handle) {
  auto ptr = get_ptr<MediaInformation>(handle);
  return ptr ? strdup_safe_ptr(ptr->getDuration()) : nullptr;
}
char *media_information_get_bitrate(MediaInformationHandle handle) {
  auto ptr = get_ptr<MediaInformation>(handle);
  return ptr ? strdup_safe_ptr(ptr->getBitrate()) : nullptr;
}
char *media_information_get_size(MediaInformationHandle handle) {
  auto ptr = get_ptr<MediaInformation>(handle);
  return ptr ? strdup_safe_ptr(ptr->getSize()) : nullptr;
}
char *media_information_get_tags_json(MediaInformationHandle handle) {
  auto ptr = get_ptr<MediaInformation>(handle);
  if (!ptr)
    return nullptr;
  auto tags = ptr->getTags();
  return tags ? strdup_cpp(tags->toStyledString()) : nullptr;
}

int media_information_get_streams_count(MediaInformationHandle handle) {
  if (!handle)
    return 0;
  auto streams = get_ptr<MediaInformation>(handle)->getStreams();
  return streams ? streams->size() : 0;
}

StreamInformationHandle
media_information_get_stream_at(MediaInformationHandle handle, int index) {
  if (!handle)
    return nullptr;
  auto streams = get_ptr<MediaInformation>(handle)->getStreams();
  if (streams && index >= 0 && index < streams->size()) {
    return create_handle(streams->at(index));
  }
  return nullptr;
}

int media_information_get_chapters_count(MediaInformationHandle handle) {
  if (!handle)
    return 0;
  auto chapters = get_ptr<MediaInformation>(handle)->getChapters();
  return chapters ? chapters->size() : 0;
}

ChapterHandle media_information_get_chapter_at(MediaInformationHandle handle,
                                               int index) {
  if (!handle)
    return nullptr;
  auto chapters = get_ptr<MediaInformation>(handle)->getChapters();
  if (chapters && index >= 0 && index < chapters->size()) {
    return create_handle(chapters->at(index));
  }
  return nullptr;
}

/* Stream Information */

#define STREAM_GETTER(Func, Type)                                              \
  Type *stream_information_get_##Func(StreamInformationHandle handle) {        \
    return strdup_safe_ptr(get_ptr<StreamInformation>(handle)->get##Func());   \
  }

char *stream_information_get_type(StreamInformationHandle handle) {
  return strdup_safe_ptr(get_ptr<StreamInformation>(handle)->getType());
}
char *stream_information_get_codec(StreamInformationHandle handle) {
  return strdup_safe_ptr(get_ptr<StreamInformation>(handle)->getCodec());
}
char *stream_information_get_codec_long(StreamInformationHandle handle) {
  return strdup_safe_ptr(get_ptr<StreamInformation>(handle)->getCodecLong());
}
char *stream_information_get_format(StreamInformationHandle handle) {
  return strdup_safe_ptr(get_ptr<StreamInformation>(handle)->getFormat());
}
char *stream_information_get_bitrate(StreamInformationHandle handle) {
  return strdup_safe_ptr(get_ptr<StreamInformation>(handle)->getBitrate());
}
char *stream_information_get_sample_rate(StreamInformationHandle handle) {
  return strdup_safe_ptr(get_ptr<StreamInformation>(handle)->getSampleRate());
}
char *stream_information_get_sample_format(StreamInformationHandle handle) {
  return strdup_safe_ptr(get_ptr<StreamInformation>(handle)->getSampleFormat());
}
char *
stream_information_get_display_aspect_ratio(StreamInformationHandle handle) {
  return strdup_safe_ptr(
      get_ptr<StreamInformation>(handle)->getDisplayAspectRatio());
}
char *
stream_information_get_average_frame_rate(StreamInformationHandle handle) {
  return strdup_safe_ptr(
      get_ptr<StreamInformation>(handle)->getAverageFrameRate());
}
char *stream_information_get_real_frame_rate(StreamInformationHandle handle) {
  return strdup_safe_ptr(
      get_ptr<StreamInformation>(handle)->getRealFrameRate());
}
char *stream_information_get_time_base(StreamInformationHandle handle) {
  return strdup_safe_ptr(get_ptr<StreamInformation>(handle)->getTimeBase());
}

int stream_information_get_width(StreamInformationHandle handle) {
  if (!handle)
    return 0;
  auto val = get_ptr<StreamInformation>(handle)->getWidth();
  return val ? *val : 0;
}
int stream_information_get_height(StreamInformationHandle handle) {
  if (!handle)
    return 0;
  auto val = get_ptr<StreamInformation>(handle)->getHeight();
  return val ? *val : 0;
}
int stream_information_get_index(StreamInformationHandle handle) {
  if (!handle)
    return -1;
  auto val = get_ptr<StreamInformation>(handle)->getIndex();
  return val ? *val : -1;
}
char *stream_information_get_tags_json(StreamInformationHandle handle) {
  auto tags = get_ptr<StreamInformation>(handle)->getTags();
  return tags ? strdup_cpp(tags->toStyledString()) : nullptr;
}

/* Chapter */
long chapter_get_id(ChapterHandle handle) {
  if (!handle)
    return -1;
  auto val = get_ptr<Chapter>(handle)->getId();
  return val ? *val : -1;
}
char *chapter_get_time_base(ChapterHandle handle) {
  return strdup_safe_ptr(get_ptr<Chapter>(handle)->getTimeBase());
}
long chapter_get_start(ChapterHandle handle) {
  if (!handle)
    return -1;
  auto val = get_ptr<Chapter>(handle)->getStart();
  return val ? *val : -1;
}
char *chapter_get_start_time(ChapterHandle handle) {
  return strdup_safe_ptr(get_ptr<Chapter>(handle)->getStartTime());
}
long chapter_get_end(ChapterHandle handle) {
  if (!handle)
    return -1;
  auto val = get_ptr<Chapter>(handle)->getEnd();
  return val ? *val : -1;
}
char *chapter_get_end_time(ChapterHandle handle) {
  return strdup_safe_ptr(get_ptr<Chapter>(handle)->getEndTime());
}
char *chapter_get_tags_json(ChapterHandle handle) {
  auto tags = get_ptr<Chapter>(handle)->getTags();
  return tags ? strdup_cpp(tags->toStyledString()) : nullptr;
}

/* Session History */
FFmpegSessionHandle *ffmpeg_kit_get_sessions(void) {
  return (FFmpegSessionHandle *)list_to_handle_array(
      FFmpegKitConfig::getSessions());
}

FFmpegSessionHandle *ffmpeg_kit_get_ffmpeg_sessions(void) {
  return (FFmpegSessionHandle *)list_to_handle_array(
      FFmpegKitConfig::getFFmpegSessions());
}

FFprobeSessionHandle *ffmpeg_kit_get_ffprobe_sessions(void) {
  return (FFprobeSessionHandle *)list_to_handle_array(
      FFmpegKitConfig::getFFprobeSessions());
}

FFplaySessionHandle *ffmpeg_kit_get_ffplay_sessions(void) {
  return (FFplaySessionHandle *)list_to_handle_array(
      FFmpegKitConfig::getFFplaySessions());
}

MediaInformationSessionHandle *ffmpeg_kit_get_media_information_sessions(void) {
  return (MediaInformationSessionHandle *)list_to_handle_array(
      FFmpegKitConfig::getMediaInformationSessions());
}

FFmpegSessionHandle ffmpeg_kit_get_session(long session_id) {
  return create_handle(FFmpegKitConfig::getSession(session_id));
}

FFmpegSessionHandle ffmpeg_kit_get_last_session(void) {
  return create_handle(FFmpegKitConfig::getLastSession());
}

FFmpegSessionHandle ffmpeg_kit_get_last_ffmpeg_session(void) {
  return create_handle(FFmpegKitConfig::getLastFFmpegSession());
}

FFprobeSessionHandle ffmpeg_kit_get_last_ffprobe_session(void) {
  return create_handle(FFmpegKitConfig::getLastFFprobeSession());
}

FFplaySessionHandle ffmpeg_kit_get_last_ffplay_session(void) {
  return create_handle(FFmpegKitConfig::getLastFFplaySession());
}

MediaInformationSessionHandle ffmpeg_kit_get_last_media_information_session(void) {
  return create_handle(FFmpegKitConfig::getLastMediaInformationSession());
}

FFmpegSessionHandle ffmpeg_kit_get_last_completed_session(void) {
  return create_handle(FFmpegKitConfig::getLastCompletedSession());
}

int ffmpeg_kit_get_session_history_size(void) {
  return FFmpegKitConfig::getSessionHistorySize();
}

void ffmpeg_kit_set_session_history_size(int size) {
  FFmpegKitConfig::setSessionHistorySize(size);
}

void ffmpeg_kit_clear_sessions(void) { FFmpegKitConfig::clearSessions(); }

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
  g_log_callback = log_cb;
  g_log_user_data = user_data;
  if (log_cb) {
    FFmpegKitConfig::enableLogCallback([](std::shared_ptr<Log> log) {
      if (g_log_callback) {
        g_log_callback(nullptr, log->getMessage().c_str(), g_log_user_data);
      }
    });
  } else {
    FFmpegKitConfig::enableLogCallback(nullptr);
  }
}

void ffmpeg_kit_config_enable_statistics_callback(
    FFmpegKitStatisticsCallback stats_cb, void *user_data) {
  g_stats_callback = stats_cb;
  g_stats_user_data = user_data;
  if (stats_cb) {
    FFmpegKitConfig::enableStatisticsCallback(
        [](std::shared_ptr<Statistics> s) {
          if (g_stats_callback) {
            g_stats_callback(nullptr, s->getTime(), s->getSize(),
                             s->getBitrate(), s->getSpeed(),
                             s->getVideoFrameNumber(), s->getVideoFps(),
                             s->getVideoQuality(), g_stats_user_data);
          }
        });
  } else {
    FFmpegKitConfig::enableStatisticsCallback(nullptr);
  }
}

void ffmpeg_kit_config_enable_ffmpeg_session_complete_callback(
    FFmpegKitCompleteCallback complete_cb, void *user_data) {
  g_ffmpeg_complete_callback = complete_cb;
  g_ffmpeg_complete_user_data = user_data;
  if (complete_cb) {
    FFmpegKitConfig::enableFFmpegSessionCompleteCallback(
        [](std::shared_ptr<FFmpegSession> title) {
          if (g_ffmpeg_complete_callback) {
            auto handle = create_handle(title);
            g_ffmpeg_complete_callback(handle, g_ffmpeg_complete_user_data);
            ffmpeg_kit_handle_release(handle);
          }
        });
  } else {
    FFmpegKitConfig::enableFFmpegSessionCompleteCallback(nullptr);
  }
}

void ffmpeg_kit_config_enable_ffprobe_session_complete_callback(
    FFprobeKitCompleteCallback complete_cb, void *user_data) {
  g_ffprobe_complete_callback = complete_cb;
  g_ffprobe_complete_user_data = user_data;
  if (complete_cb) {
    FFmpegKitConfig::enableFFprobeSessionCompleteCallback(
        [](std::shared_ptr<FFprobeSession> title) {
          if (g_ffprobe_complete_callback) {
            auto handle = create_handle(title);
            g_ffprobe_complete_callback(handle, g_ffprobe_complete_user_data);
            ffmpeg_kit_handle_release(handle);
          }
        });
  } else {
    FFmpegKitConfig::enableFFprobeSessionCompleteCallback(nullptr);
  }
}

void ffmpeg_kit_config_enable_ffplay_session_complete_callback(
    FFplayKitCompleteCallback complete_cb, void *user_data) {
  g_ffplay_complete_callback = complete_cb;
  g_ffplay_complete_user_data = user_data;
  if (complete_cb) {
    FFmpegKitConfig::enableFFplaySessionCompleteCallback(
        [](std::shared_ptr<FFplaySession> title) {
          if (g_ffplay_complete_callback) {
            auto handle = create_handle(title);
            g_ffplay_complete_callback(handle, g_ffplay_complete_user_data);
            ffmpeg_kit_handle_release(handle);
          }
        });
  } else {
    FFmpegKitConfig::enableFFplaySessionCompleteCallback(nullptr);
  }
}

void ffmpeg_kit_config_enable_media_information_session_complete_callback(
    ::MediaInformationSessionCompleteCallback complete_cb, void *user_data) {
  g_media_complete_callback = complete_cb;
  g_media_complete_user_data = user_data;
  if (complete_cb) {
    FFmpegKitConfig::enableMediaInformationSessionCompleteCallback(
        [](std::shared_ptr<MediaInformationSession> title) {
          if (g_media_complete_callback) {
            auto handle = create_handle(title);
            g_media_complete_callback(handle, g_media_complete_user_data);
            ffmpeg_kit_handle_release(handle);
          }
        });
  } else {
    FFmpegKitConfig::enableMediaInformationSessionCompleteCallback(nullptr);
  }
}

/* Utils */
char *ffmpeg_kit_config_register_new_ffmpeg_pipe(void) {
  return strdup_safe_ptr(FFmpegKitConfig::registerNewFFmpegPipe());
}

void ffmpeg_kit_config_close_ffmpeg_pipe(const char *pipe_path) {
  if (pipe_path) {
    FFmpegKitConfig::closeFFmpegPipe(std::string(pipe_path));
  }
}

void ffmpeg_kit_config_set_font_directory_list(const char **font_directory_list,
                                               int list_size,
                                               const char *name_mappings_json) {
  std::list<std::string> fonts;
  if (font_directory_list) {
    for (int i = 0; i < list_size; i++) {
      if (font_directory_list[i]) {
        fonts.push_back(std::string(font_directory_list[i]));
      }
    }
  }
  std::map<std::string, std::string> map;
  FFmpegKitConfig::setFontDirectoryList(fonts, map);
}

char *ffmpeg_kit_config_get_build_date(void) {
  return strdup_cpp(FFmpegKitConfig::getBuildDate());
}

char *ffmpeg_kit_config_session_state_to_string(FFmpegKitSessionState state) {
  return strdup_cpp(FFmpegKitConfig::sessionStateToString((SessionState)state));
}

char **ffmpeg_kit_config_parse_arguments(const char *command, int *arg_count) {
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
}

char *ffmpeg_kit_config_arguments_to_string(char **arguments, int arg_count) {
  if (!arguments)
    return nullptr;
  auto list = std::make_shared<std::list<std::string>>();
  for (int i = 0; i < arg_count; i++) {
    if (arguments[i]) {
      list->push_back(std::string(arguments[i]));
    }
  }
  return strdup_cpp(FFmpegKitConfig::argumentsToString(list));
}

int ffmpeg_kit_config_messages_in_transmit(long session_id) {
  return FFmpegKitConfig::messagesInTransmit(session_id);
}

/* Session Management Extended */
long ffmpeg_kit_session_get_create_time(void *session_handle) {
  if (!session_handle)
    return 0;
  auto tp = get_ptr<Session>(session_handle)->getCreateTime();
  return std::chrono::duration_cast<std::chrono::milliseconds>(
             tp.time_since_epoch())
      .count();
}

long ffmpeg_kit_session_get_start_time(void *session_handle) {
  if (!session_handle)
    return 0;
  auto tp = get_ptr<Session>(session_handle)->getStartTime();
  return std::chrono::duration_cast<std::chrono::milliseconds>(
             tp.time_since_epoch())
      .count();
}

long ffmpeg_kit_session_get_end_time(void *session_handle) {
  if (!session_handle)
    return 0;
  auto tp = get_ptr<Session>(session_handle)->getEndTime();
  return std::chrono::duration_cast<std::chrono::milliseconds>(
             tp.time_since_epoch())
      .count();
}

long ffmpeg_kit_session_get_duration(void *session_handle) {
  if (!session_handle)
    return 0;
  return get_ptr<Session>(session_handle)->getDuration();
}

char *ffmpeg_kit_session_get_command(void *session_handle) {
  if (!session_handle)
    return nullptr;
  return strdup_cpp(get_ptr<Session>(session_handle)->getCommand());
}

int ffmpeg_kit_session_get_logs_count(void *session_handle) {
  if (!session_handle)
    return 0;
  auto logs = get_ptr<Session>(session_handle)->getLogs();
  return logs ? logs->size() : 0;
}

char *ffmpeg_kit_session_get_log_at(void *session_handle, int index) {
  if (!session_handle)
    return nullptr;
  auto logs = get_ptr<Session>(session_handle)->getLogs();
  if (logs && index >= 0 && index < logs->size()) {
    auto it = logs->begin();
    std::advance(it, index);
    return strdup_cpp((*it)->getMessage());
  }
  return nullptr;
}

int ffmpeg_kit_session_get_log_level_at(void *session_handle, int index) {
  if (!session_handle)
    return 0;
  auto logs = get_ptr<Session>(session_handle)->getLogs();
  if (logs && index >= 0 && index < logs->size()) {
    auto it = logs->begin();
    std::advance(it, index);
    return (int)(*it)->getLevel();
  }
  return 0;
}

int ffmpeg_kit_session_get_statistics_count(void *session_handle) {
  if (!session_handle)
    return 0;
  auto stats = get_ptr<FFmpegSession>(session_handle)->getStatistics();
  return stats ? stats->size() : 0;
}

StatisticsHandle ffmpeg_kit_session_get_statistics_at(void *session_handle,
                                                      int index) {
  if (!session_handle)
    return nullptr;
  auto stats = get_ptr<FFmpegSession>(session_handle)->getStatistics();
  if (stats && index >= 0 && index < stats->size()) {
    auto it = stats->begin();
    std::advance(it, index);
    return create_handle(*it);
  }
  return nullptr;
}

/* Entity Properties Extended */

char *media_information_get_start_time(MediaInformationHandle handle) {
  auto ptr = get_ptr<MediaInformation>(handle);
  return ptr ? strdup_safe_ptr(ptr->getStartTime()) : nullptr;
}

char *media_information_get_string_property(MediaInformationHandle handle,
                                            const char *key) {
  return strdup_safe_ptr(
      get_ptr<MediaInformation>(handle)->getStringProperty(key));
}

long media_information_get_number_property(MediaInformationHandle handle,
                                           const char *key) {
  auto val = get_ptr<MediaInformation>(handle)->getNumberProperty(key);
  return val ? *val : -1;
}

char *media_information_get_all_properties_json(MediaInformationHandle handle) {
  auto props = get_ptr<MediaInformation>(handle)->getAllProperties();
  return props ? strdup_cpp(props->toStyledString()) : nullptr;
}

// StreamInformation
char *stream_information_get_channel_layout(StreamInformationHandle handle) {
  return strdup_safe_ptr(
      get_ptr<StreamInformation>(handle)->getChannelLayout());
}

char *
stream_information_get_sample_aspect_ratio(StreamInformationHandle handle) {
  return strdup_safe_ptr(
      get_ptr<StreamInformation>(handle)->getSampleAspectRatio());
}

char *stream_information_get_codec_time_base(StreamInformationHandle handle) {
  return strdup_safe_ptr(
      get_ptr<StreamInformation>(handle)->getCodecTimeBase());
}

char *stream_information_get_string_property(StreamInformationHandle handle,
                                             const char *key) {
  return strdup_safe_ptr(
      get_ptr<StreamInformation>(handle)->getStringProperty(key));
}

long stream_information_get_number_property(StreamInformationHandle handle,
                                            const char *key) {
  auto val = get_ptr<StreamInformation>(handle)->getNumberProperty(key);
  return val ? *val : -1;
}

char *
stream_information_get_all_properties_json(StreamInformationHandle handle) {
  auto props = get_ptr<StreamInformation>(handle)->getAllProperties();
  return props ? strdup_cpp(props->toStyledString()) : nullptr;
}

// Chapter
char *chapter_get_string_property(ChapterHandle handle, const char *key) {
  return strdup_safe_ptr(get_ptr<Chapter>(handle)->getStringProperty(key));
}

long chapter_get_number_property(ChapterHandle handle, const char *key) {
  auto val = get_ptr<Chapter>(handle)->getNumberProperty(key);
  return val ? *val : -1;
}

char *chapter_get_all_properties_json(ChapterHandle handle) {
  auto props = get_ptr<Chapter>(handle)->getAllProperties();
  return props ? strdup_cpp(props->toStyledString()) : nullptr;
}

int session_is_ffmpeg_session(void *session) {
  if (!session)
    return 0;
  return get_ptr<AbstractSession>(session)->isFFmpeg();
}

int session_is_ffprobe_session(void *session) {
  if (!session)
    return 0;
  return get_ptr<AbstractSession>(session)->isFFprobe();
}

int session_is_ffplay_session(void *session) {
  if (!session)
    return 0;
  return get_ptr<AbstractSession>(session)->isFFplay();
}

int session_is_media_information_session(void *session) {
  if (!session)
    return 0;
  return get_ptr<AbstractSession>(session)->isMediaInformation();
}
}