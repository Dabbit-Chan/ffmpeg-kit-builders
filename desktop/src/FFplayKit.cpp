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
    const std::list<std::string> &arguments) {
  auto session = ffmpegkit::FFplaySession::create(arguments);
  ffmpegkit::FFmpegKitConfig::ffplayExecute(session);
  return session;
}

std::shared_ptr<ffmpegkit::FFplaySession>
ffmpegkit::FFplayKit::executeWithArgumentsAsync(
    const std::list<std::string> &arguments,
    FFplaySessionCompleteCallback completeCallback) {
  auto session = ffmpegkit::FFplaySession::create(arguments, completeCallback);
  ffmpegkit::FFmpegKitConfig::asyncFFplayExecute(session);
  return session;
}

std::shared_ptr<ffmpegkit::FFplaySession>
ffmpegkit::FFplayKit::executeWithArgumentsAsync(
    const std::list<std::string> &arguments,
    FFplaySessionCompleteCallback completeCallback,
    ffmpegkit::LogCallback logCallback) {
  auto session = ffmpegkit::FFplaySession::create(
      arguments, completeCallback, logCallback);
  ffmpegkit::FFmpegKitConfig::asyncFFplayExecute(session);
  return session;
}

std::shared_ptr<ffmpegkit::FFplaySession>
ffmpegkit::FFplayKit::execute(const std::string command) {
  auto session = ffmpegkit::FFplaySession::create(
      FFmpegKitConfig::parseArguments(command.c_str()));
  ffmpegkit::FFmpegKitConfig::ffplayExecute(session);
  return session;
}

std::shared_ptr<ffmpegkit::FFplaySession> ffmpegkit::FFplayKit::executeAsync(
    const std::string command, FFplaySessionCompleteCallback completeCallback) {
  auto session = ffmpegkit::FFplaySession::create(
      FFmpegKitConfig::parseArguments(command.c_str()), completeCallback);
  ffmpegkit::FFmpegKitConfig::asyncFFplayExecute(session);
  return session;
}

std::shared_ptr<ffmpegkit::FFplaySession> ffmpegkit::FFplayKit::executeAsync(
    const std::string command, FFplaySessionCompleteCallback completeCallback,
    ffmpegkit::LogCallback logCallback) {
  auto session = ffmpegkit::FFplaySession::create(
      FFmpegKitConfig::parseArguments(command.c_str()), completeCallback,
      logCallback);
  ffmpegkit::FFmpegKitConfig::asyncFFplayExecute(session);
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

void ffmpegkit::FFplayKit::setPlaybackSpeed(double speed) {
  auto session = ffmpegkit::FFmpegKitConfig::getActiveFFplaySession();
  if (session) {
    session->setPlaybackSpeed(speed);
  }
}

double ffmpegkit::FFplayKit::getPlaybackSpeed() {
  auto session = ffmpegkit::FFmpegKitConfig::getActiveFFplaySession();
  if (session) {
    return session->getPlaybackSpeed();
  }
  return 1.0;
}
