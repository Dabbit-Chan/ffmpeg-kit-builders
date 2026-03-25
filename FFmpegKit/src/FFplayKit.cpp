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
 *  You should have received a copy of the GNU Lesser General Public License
 *  along with FFmpegKit.  If not, see <http://www.gnu.org/licenses/>.
 */

#include "FFplayKit.hpp"
#include "FFmpegKitConfig.hpp"

extern void *ffmpegKitInitialize();

const void *_ffplayKitInitializer{ffmpegKitInitialize()};

std::shared_ptr<ffmpegkit::FFplaySession>
ffmpegkit::FFplayKit::executeWithArguments(
    const std::list<std::string> &arguments, int timeout) {
  auto session = ffmpegkit::FFplaySession::create(arguments);
  ffmpegkit::FFmpegKitConfig::ffplayExecute(session, timeout);
  return session;
}

std::shared_ptr<ffmpegkit::FFplaySession>
ffmpegkit::FFplayKit::executeWithArgumentsAsync(
    const std::list<std::string> &arguments,
    FFplaySessionCompleteCallback completeCallback, int timeout) {
  auto session = ffmpegkit::FFplaySession::create(arguments, completeCallback);
  ffmpegkit::FFmpegKitConfig::asyncFFplayExecute(session, timeout);
  return session;
}

std::shared_ptr<ffmpegkit::FFplaySession>
ffmpegkit::FFplayKit::executeWithArgumentsAsync(
    const std::list<std::string> &arguments,
    FFplaySessionCompleteCallback completeCallback,
    ffmpegkit::LogCallback logCallback, int timeout) {
  auto session = ffmpegkit::FFplaySession::create(
      arguments, completeCallback, logCallback);
  ffmpegkit::FFmpegKitConfig::asyncFFplayExecute(session, timeout);
  return session;
}

std::shared_ptr<ffmpegkit::FFplaySession>
ffmpegkit::FFplayKit::execute(const std::string command, int timeout) {
  auto session = ffmpegkit::FFplaySession::create(
      FFmpegKitConfig::parseArguments(command.c_str()));
  ffmpegkit::FFmpegKitConfig::ffplayExecute(session, timeout);
  return session;
}

std::shared_ptr<ffmpegkit::FFplaySession> ffmpegkit::FFplayKit::executeAsync(
    const std::string command, FFplaySessionCompleteCallback completeCallback, int timeout) {
  auto session = ffmpegkit::FFplaySession::create(
      FFmpegKitConfig::parseArguments(command.c_str()), completeCallback);
  ffmpegkit::FFmpegKitConfig::asyncFFplayExecute(session, timeout);
  return session;
}

std::shared_ptr<ffmpegkit::FFplaySession> ffmpegkit::FFplayKit::executeAsync(
    const std::string command, FFplaySessionCompleteCallback completeCallback,
    ffmpegkit::LogCallback logCallback, int timeout) {
  auto session = ffmpegkit::FFplaySession::create(
      FFmpegKitConfig::parseArguments(command.c_str()), completeCallback,
      logCallback);
  ffmpegkit::FFmpegKitConfig::asyncFFplayExecute(session, timeout);
  return session;
}

std::shared_ptr<std::list<std::shared_ptr<ffmpegkit::FFplaySession>>>
ffmpegkit::FFplayKit::listFFplaySessions() {
  return ffmpegkit::FFmpegKitConfig::getFFplaySessions();
}

void ffmpegkit::FFplayKit::seek(double seconds) {
  auto session = ffmpegkit::FFmpegKitConfig::getActiveFFplaySession();
  if (session) {
    session->seek(seconds);
  }
}

void ffmpegkit::FFplayKit::start() {
  auto session = ffmpegkit::FFmpegKitConfig::getActiveFFplaySession();
  if (session) {
    session->start();
  }
}

void ffmpegkit::FFplayKit::pause() {
  auto session = ffmpegkit::FFmpegKitConfig::getActiveFFplaySession();
  if (session) {
    session->pause();
  }
}

void ffmpegkit::FFplayKit::resume() {
  auto session = ffmpegkit::FFmpegKitConfig::getActiveFFplaySession();
  if (session) {
    session->resume();
  }
}

void ffmpegkit::FFplayKit::stop() {
  auto session = ffmpegkit::FFmpegKitConfig::getActiveFFplaySession();
  if (session) {
    session->stop();
  }
}

double ffmpegkit::FFplayKit::getPosition() {
  auto session = ffmpegkit::FFmpegKitConfig::getActiveFFplaySession();
  if (session) {
    return session->getPosition();
  }
  return 0.0;
}

void ffmpegkit::FFplayKit::setPosition(double position) {
  auto session = ffmpegkit::FFmpegKitConfig::getActiveFFplaySession();
  if (session) {
    session->setPosition(position);
  }
}

double ffmpegkit::FFplayKit::getDuration() {
  auto session = ffmpegkit::FFmpegKitConfig::getActiveFFplaySession();
  if (session) {
    return session->getDuration();
  }
  return 0.0;
}

bool ffmpegkit::FFplayKit::isPlaying() {
  auto session = ffmpegkit::FFmpegKitConfig::getActiveFFplaySession();
  if (session) {
    return session->isPlaying();
  }
  return false;
}

bool ffmpegkit::FFplayKit::isPaused() {
  auto session = ffmpegkit::FFmpegKitConfig::getActiveFFplaySession();
  if (session) {
    return session->isPaused();
  }
  return false;
}

void ffmpegkit::FFplayKit::setVolume(float volume) {
  auto session = ffmpegkit::FFmpegKitConfig::getActiveFFplaySession();
  if (session) {
    session->setVolume(volume);
  }
}

float ffmpegkit::FFplayKit::getVolume() {
  auto session = ffmpegkit::FFmpegKitConfig::getActiveFFplaySession();
  if (session) {
    return session->getVolume();
  }
  return -1.0;
}

void ffmpegkit::FFplayKit::close() {
  auto session = ffmpegkit::FFmpegKitConfig::getActiveFFplaySession();
  if (session) {
    session->close();
  }
}

#ifdef __ANDROID__
#include <android/native_window_jni.h>
#include "ffplay_lib.h"

void ffmpegkit::FFplayKit::setAndroidSurface(JNIEnv *env, jobject surface) {
  // Retain the new window and release the previous one, mirroring the
  // g_retained_window lifecycle in ffmpeg_kit_android.c.
  static ANativeWindow *s_retained = nullptr;
  if (s_retained) {
    // Null the global BEFORE releasing: ffplay_set_android_window holds the
    // ffplay_api_mutex, so once it returns no new blit will start on the old
    // window (ffplay_step acquires a ref under that same mutex).
    ffplay_set_android_window(nullptr);
    ANativeWindow_release(s_retained);
    s_retained = nullptr;
  }
  ANativeWindow *nw = surface ? ANativeWindow_fromSurface(env, surface) : nullptr;
  s_retained = nw;
  ffplay_set_android_window(nw);
}
#endif /* __ANDROID__ */
