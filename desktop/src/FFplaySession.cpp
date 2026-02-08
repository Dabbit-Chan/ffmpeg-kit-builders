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

#include "FFplaySession.hpp"
#include "FFmpegKitConfig.hpp"
#include "LogCallback.hpp"

extern void
addSessionToSessionHistory(const std::shared_ptr<ffmpegkit::Session> session);

std::shared_ptr<ffmpegkit::FFplaySession>
ffmpegkit::FFplaySession::create(const std::list<std::string> &arguments) {
  auto session = std::static_pointer_cast<ffmpegkit::FFplaySession>(
      std::make_shared<ffmpegkit::FFplaySession::PublicFFplaySession>(
          arguments, nullptr, nullptr,
          ffmpegkit::FFmpegKitConfig::getLogRedirectionStrategy()));
  addSessionToSessionHistory(session);
  return session;
}

std::shared_ptr<ffmpegkit::FFplaySession> ffmpegkit::FFplaySession::create(
    const std::list<std::string> &arguments,
    const FFplaySessionCompleteCallback completeCallback) {
  auto session = std::static_pointer_cast<ffmpegkit::FFplaySession>(
      std::make_shared<ffmpegkit::FFplaySession::PublicFFplaySession>(
          arguments, completeCallback, nullptr,
          ffmpegkit::FFmpegKitConfig::getLogRedirectionStrategy()));
  addSessionToSessionHistory(session);
  return session;
}

std::shared_ptr<ffmpegkit::FFplaySession> ffmpegkit::FFplaySession::create(
    const std::list<std::string> &arguments,
    const FFplaySessionCompleteCallback completeCallback,
    const ffmpegkit::LogCallback logCallback) {
  auto session = std::static_pointer_cast<ffmpegkit::FFplaySession>(
      std::make_shared<ffmpegkit::FFplaySession::PublicFFplaySession>(
          arguments, completeCallback, logCallback,
          ffmpegkit::FFmpegKitConfig::getLogRedirectionStrategy()));
  addSessionToSessionHistory(session);
  return session;
}

std::shared_ptr<ffmpegkit::FFplaySession> ffmpegkit::FFplaySession::create(
    const std::list<std::string> &arguments,
    const FFplaySessionCompleteCallback completeCallback,
    const ffmpegkit::LogCallback logCallback,
    const LogRedirectionStrategy logRedirectionStrategy) {
  auto session = std::static_pointer_cast<ffmpegkit::FFplaySession>(
      std::make_shared<ffmpegkit::FFplaySession::PublicFFplaySession>(
          arguments, completeCallback, logCallback, logRedirectionStrategy));
  addSessionToSessionHistory(session);
  return session;
}

struct ffmpegkit::FFplaySession::PublicFFplaySession
    : public ffmpegkit::FFplaySession {
  PublicFFplaySession(const std::list<std::string> &arguments,
                       const FFplaySessionCompleteCallback completeCallback,
                       const ffmpegkit::LogCallback logCallback,
                       const LogRedirectionStrategy logRedirectionStrategy)
      : FFplaySession(arguments, completeCallback, logCallback,
                       logRedirectionStrategy) {}
};

ffmpegkit::FFplaySession::FFplaySession(
    const std::list<std::string> &arguments,
    const FFplaySessionCompleteCallback completeCallback,
    const ffmpegkit::LogCallback logCallback,
    const LogRedirectionStrategy logRedirectionStrategy)
    : ffmpegkit::AbstractSession(arguments, logCallback,
                                 logRedirectionStrategy),
      _completeCallback{completeCallback} {}

ffmpegkit::FFplaySessionCompleteCallback
ffmpegkit::FFplaySession::getCompleteCallback() {
  return _completeCallback;
}

bool ffmpegkit::FFplaySession::isFFplay() const { return true; }

bool ffmpegkit::FFplaySession::isFFmpeg() const { return false; }

bool ffmpegkit::FFplaySession::isFFprobe() const { return false; }

bool ffmpegkit::FFplaySession::isMediaInformation() const { return false; }
