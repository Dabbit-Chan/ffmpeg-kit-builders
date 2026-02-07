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
