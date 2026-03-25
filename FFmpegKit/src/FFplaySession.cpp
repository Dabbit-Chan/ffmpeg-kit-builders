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
#include "libavutil/log.h"

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
  std::lock_guard<std::mutex> lock(_stateMutex);
  return _completeCallback;
}

bool ffmpegkit::FFplaySession::isFFplay() const { return true; }

bool ffmpegkit::FFplaySession::isFFmpeg() const { return false; }

bool ffmpegkit::FFplaySession::isFFprobe() const { return false; }

bool ffmpegkit::FFplaySession::isMediaInformation() const { return false; }

void ffmpegkit::FFplaySession::seek(double seconds, double rel) {
    FFplayContext *ctx = _context.load(std::memory_order_acquire);
    if (ctx == nullptr) return;

    if (rel != 0.0) {
        ffplay_seek(ctx, seconds, rel);
        _position = seconds;
        return;
    }

    // Use ctx directly instead of calling getDuration()/getPosition(),
    // which would each do their own load — ctx could be nulled between calls.
    double duration = ffplay_get_duration(ctx);
    double currentPos = ffplay_get_position(ctx);
    double targetPos;
    double rel_hint = 0;

    if (seconds < 0) {
        targetPos = currentPos + seconds;
        rel_hint = seconds;
    } else {
        targetPos = seconds;
        rel_hint = targetPos - currentPos;
    }

    if (targetPos < 0) targetPos = 0;
    if (duration > 0 && targetPos > duration) targetPos = duration;

    ffplay_seek(ctx, targetPos, rel_hint);
    _position = targetPos;
}

void ffmpegkit::FFplaySession::start() {
    FFplayContext *ctx = _context.load(std::memory_order_acquire);
    if (ctx != nullptr) {
        ffplay_start(ctx);
    }
}

void ffmpegkit::FFplaySession::pause() {
    FFplayContext *ctx = _context.load(std::memory_order_acquire);
    if (ctx != nullptr) {
        ffplay_pause(ctx);
    }
}

void ffmpegkit::FFplaySession::resume() {
    FFplayContext *ctx = _context.load(std::memory_order_acquire);
    if (ctx != nullptr) {
        ffplay_resume(ctx);
    }
}

void ffmpegkit::FFplaySession::stop() {
    FFplayContext *ctx = _context.load(std::memory_order_acquire);
    if (ctx != nullptr) {
        ffplay_stop(ctx);
    }
}

double ffmpegkit::FFplaySession::getPosition() {
    FFplayContext *ctx = _context.load(std::memory_order_acquire);
    if (ctx != nullptr) {
        _position = ffplay_get_position(ctx);
        return _position;
    }
    return 0.0;
}

void ffmpegkit::FFplaySession::setPosition(double position) {
    seek(position, 0.0);
}

double ffmpegkit::FFplaySession::getDuration() {
    FFplayContext *ctx = _context.load(std::memory_order_acquire);
    if (ctx != nullptr) {
        _duration = ffplay_get_duration(ctx);
        av_log(NULL, AV_LOG_DEBUG, "[FFplaySession] getDuration: ctx=%p => %f\n", ctx, _duration);
        return _duration;
    }
    av_log(NULL, AV_LOG_WARNING, "[FFplaySession] getDuration: ctx=NULL (session not running)\n");
    return 0.0;
}

bool ffmpegkit::FFplaySession::isPlaying() {
    FFplayContext *ctx = _context.load(std::memory_order_acquire);
    if (ctx != nullptr) {
        _isPlaying = ffplay_is_playing(ctx) != 0;
        av_log(NULL, AV_LOG_DEBUG, "[FFplaySession] isPlaying: ctx=%p => %d\n", ctx, (int)_isPlaying);
        return _isPlaying;
    }
    av_log(NULL, AV_LOG_WARNING, "[FFplaySession] isPlaying: ctx=NULL (session not running)\n");
    return false;
}

bool ffmpegkit::FFplaySession::isPaused() {
    FFplayContext *ctx = _context.load(std::memory_order_acquire);
    if (ctx != nullptr) {
        _isPaused = ffplay_is_paused(ctx) != 0;
        av_log(NULL, AV_LOG_DEBUG, "[FFplaySession] isPaused: ctx=%p => %d\n", ctx, (int)_isPaused);
        return _isPaused;
    }
    av_log(NULL, AV_LOG_WARNING, "[FFplaySession] isPaused: ctx=NULL (session not running)\n");
    return false;
}

int ffmpegkit::FFplaySession::getVideoWidth() {
    FFplayContext *ctx = _context.load(std::memory_order_acquire);
    if (ctx == nullptr) return 0;
    int w = 0, h = 0;
    ffplay_get_video_size(ctx, &w, &h);
    return w;
}

int ffmpegkit::FFplaySession::getVideoHeight() {
    FFplayContext *ctx = _context.load(std::memory_order_acquire);
    if (ctx == nullptr) return 0;
    int w = 0, h = 0;
    ffplay_get_video_size(ctx, &w, &h);
    return h;
}

void ffmpegkit::FFplaySession::setVolume(float volume) {
    FFplayContext *ctx = _context.load(std::memory_order_acquire);
    if (ctx != nullptr) {
        ffplay_set_volume(ctx, volume);
    }
}

float ffmpegkit::FFplaySession::getVolume() {
    FFplayContext *ctx = _context.load(std::memory_order_acquire);
    if (ctx != nullptr) {
        return ffplay_get_volume(ctx);
    }
    // Return -1.0 as a sentinel to signal "context not ready" so callers can
    // distinguish a legitimate mute (0.0) from an uninitialised context.
    return -1.0f;
}

FFplayContext *ffmpegkit::FFplaySession::getContext() {
    return _context.load(std::memory_order_acquire);
}

void ffmpegkit::FFplaySession::setContext(FFplayContext *context) {
    av_log(NULL, AV_LOG_INFO, "[FFplaySession] setContext: %p -> %p\n",
        _context.load(std::memory_order_relaxed), context);
    _context.store(context, std::memory_order_release);
}

void ffmpegkit::FFplaySession::close() {
    FFplayContext *ctx = _context.exchange(nullptr, std::memory_order_acq_rel);
    if (ctx != nullptr) {
        ffplay_stop(ctx);
    }
}

void ffmpegkit::FFplaySession::cancel() { close(); }

ffmpegkit::FFplaySession::~FFplaySession() { close(); }

void ffmpegkit::FFplaySession::setCompleteCallback(
    const FFplaySessionCompleteCallback completeCallback) {
  std::lock_guard<std::mutex> lock(_stateMutex);
  _completeCallback = completeCallback;
}