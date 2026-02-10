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
      _completeCallback{completeCallback}, _context{nullptr} {}

ffmpegkit::FFplaySessionCompleteCallback
ffmpegkit::FFplaySession::getCompleteCallback() {
  return _completeCallback;
}

bool ffmpegkit::FFplaySession::isFFplay() const { return true; }

bool ffmpegkit::FFplaySession::isFFmpeg() const { return false; }

bool ffmpegkit::FFplaySession::isFFprobe() const { return false; }

bool ffmpegkit::FFplaySession::isMediaInformation() const { return false; }

void ffmpegkit::FFplaySession::seek(double seconds, double rel) {
  if (_context != nullptr) {
    if (rel != 0.0) {
      // Direct relative seek call
      ffplay_seek(_context, seconds, rel);
      _position = seconds;
      return;
    }

    double duration = getDuration();
    double currentPos = getPosition();
    double targetPos;
    double rel_hint = 0;

    if (seconds < 0) {
      // Implicit relative seek backward (seconds is the offset)
      targetPos = currentPos + seconds;
      rel_hint = seconds;
    } else {
      // Absolute seek (seconds is the target pos)
      targetPos = seconds;
      rel_hint = targetPos - currentPos;
    }

    if (targetPos < 0)
      targetPos = 0;
    if (duration > 0 && targetPos > duration)
      targetPos = duration;

    ffplay_seek(_context, targetPos, rel_hint);
    _position = targetPos;
  }
}

void ffmpegkit::FFplaySession::start() {
  if (_context != nullptr) {
    ffplay_start(_context);
  }
}

void ffmpegkit::FFplaySession::pause() {
  if (_context != nullptr) {
    ffplay_pause(_context);
  }
}

void ffmpegkit::FFplaySession::resume() {
  if (_context != nullptr) {
    ffplay_resume(_context);
  }
}

void ffmpegkit::FFplaySession::stop() {
  if (_context != nullptr) {
    ffplay_stop(_context);
  }
}

double ffmpegkit::FFplaySession::getPosition() {
  if (_context != nullptr) {
    _position = ffplay_get_position(_context);
    return _position;
  }
  return 0.0;
}

void ffmpegkit::FFplaySession::setPosition(double position) {
  seek(position, 0.0);
}

double ffmpegkit::FFplaySession::getDuration() {
  if (_context != nullptr) {
    _duration = ffplay_get_duration(_context);
    return _duration;
  }
  return 0.0;
}

bool ffmpegkit::FFplaySession::isPlaying() {
  if (_context != nullptr) {
    _isPlaying = ffplay_is_playing(_context) != 0;
    return _isPlaying;
  }
  return false;
}

bool ffmpegkit::FFplaySession::isPaused() {
  if (_context != nullptr) {
    _isPaused = ffplay_is_paused(_context) != 0;
    return _isPaused;
  }
  return false;
}

void ffmpegkit::FFplaySession::setVolume(float volume) {
  if (_context != nullptr) {
    ffplay_set_volume(_context, volume);
  }
}

float ffmpegkit::FFplaySession::getVolume() {
  if (_context != nullptr) {
    return ffplay_get_volume(_context);
  }
  return 0.0;
}

FFplayContext *ffmpegkit::FFplaySession::getContext() { return _context; }

void ffmpegkit::FFplaySession::setContext(FFplayContext *context) {
  _context = context;
}

void ffmpegkit::FFplaySession::close() {
  if (_context != nullptr) {
    ffplay_close(_context);
    _context = nullptr;
  }
}