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

#ifndef FFMPEG_KIT_FFPLAY_SESSION_H
#define FFMPEG_KIT_FFPLAY_SESSION_H

#include "AbstractSession.hpp"
#include "FFplaySessionCompleteCallback.hpp"
#include "ffplay_lib.h"

#include <atomic>

namespace ffmpegkit {

/**
 * <p>An FFplay session.
 */
class FFplaySession : public AbstractSession {
public:
  /**
   * Builds a new FFplay session.
   *
   * @param arguments command arguments
   * @return created session
   */
  static std::shared_ptr<ffmpegkit::FFplaySession>
  create(const std::list<std::string> &arguments);

  /**
   * Builds a new FFplay session.
   *
   * @param arguments        command arguments
   * @param completeCallback session specific complete callback
   * @return created session
   */
  static std::shared_ptr<ffmpegkit::FFplaySession>
  create(const std::list<std::string> &arguments,
         const FFplaySessionCompleteCallback completeCallback);

  /**
   * Builds a new FFplay session.
   *
   * @param arguments        command arguments
   * @param completeCallback session specific complete callback
   * @param logCallback      session specific log callback
   * @return created session
   */
  static std::shared_ptr<ffmpegkit::FFplaySession>
  create(const std::list<std::string> &arguments,
         const FFplaySessionCompleteCallback completeCallback,
         const ffmpegkit::LogCallback logCallback);

  /**
   * Builds a new FFplay session.
   *
   * @param arguments               command arguments
   * @param completeCallback        session specific complete callback
   * @param logCallback             session specific log callback
   * @param logRedirectionStrategy  session specific log redirection strategy
   * @return created session
   */
  static std::shared_ptr<ffmpegkit::FFplaySession>
  create(const std::list<std::string> &arguments,
         const FFplaySessionCompleteCallback completeCallback,
         const ffmpegkit::LogCallback logCallback,
         const LogRedirectionStrategy logRedirectionStrategy);

  /**
   * Returns the session specific complete callback.
   *
   * @return session specific complete callback
   */
  ffmpegkit::FFplaySessionCompleteCallback getCompleteCallback();

  /**
   * Returns whether it is an <code>FFplay</code> session or not.
   *
   * @return true if it is an <code>FFplay</code> session, false otherwise
   */
  bool isFFplay() const override;

  /**
   * Returns whether it is an <code>FFmpeg</code> session or not.
   *
   * @return true if it is an <code>FFmpeg</code> session, false otherwise
   */
  bool isFFmpeg() const override;

  /**
   * Returns whether it is an <code>FFprobe</code> session or not.
   *
   * @return true if it is an <code>FFprobe</code> session, false otherwise
   */
  bool isFFprobe() const override;

  /**
   * Returns whether it is a <code>MediaInformation</code> session or not.
   *
   * @return true if it is a <code>MediaInformation</code> session, false
   * otherwise
   */
  bool isMediaInformation() const override;

  /**
   * Starts the media.
   */
  void start();

  /**
   * Seeks to a specific position in the media.
   *
   * @param seconds the seconds to seek to
   * @param rel the relative position to seek to
   */
  void seek(double seconds, double rel = 0.0);

  /**
   * Pauses the media.
   */
  void pause();

  /**
   * Resumes the media.
   */
  void resume();

  /**
   * Stops the media.
   */
  void stop();

  /**
   * Returns the current position of the media.
   *
   * @return the current position of the media
   */
  double getPosition();

  /**
   * Sets the current position of the media.
   *
   * @param position the position to set
   */
  void setPosition(double position);

  /**
   * Returns the duration of the media.
   *
   * @return the duration of the media
   */
  double getDuration();

  /**
   * Returns whether the media is playing.
   *
   * @return true if the media is playing, false otherwise
   */
  bool isPlaying();

  /**
   * Returns whether the media is paused.
   *
   * @return true if the media is paused, false otherwise
   */
  bool isPaused();

  /**
   * Sets the volume of the media.
   *
   * @param volume the volume to set
   */
  void setVolume(float volume);

  /**
   * Returns the volume of the media.
   *
   * @return the volume of the media
   */
  float getVolume();

  /**
   * Returns the current video width in pixels, or 0 if not yet known.
   */
  int getVideoWidth();

  /**
   * Returns the current video height in pixels, or 0 if not yet known.
   */
  int getVideoHeight();

  /**
   * Returns the ffplay context.
   *
   * @return the ffplay context
   */
  FFplayContext *getContext();

  /**
   * Sets the ffplay context.
   *
   * @param context the ffplay context
   */
  void setContext(FFplayContext *context);

  /**
   * Closes the ffplay session.
   */
  void close();

  /**
   * Cancels the ffplay session.
   */
  /**
   * Cancels the ffplay session.
   */
  void cancel() override;

  /**
   * Sets the session specific complete callback.
   *
   * @param completeCallback session specific complete callback
   */
  void
  setCompleteCallback(const FFplaySessionCompleteCallback completeCallback);

  virtual ~FFplaySession();

private:
  struct PublicFFplaySession;

  /**
   * Builds a new FFplay session.
   *
   * @param arguments               command arguments
   * @param completeCallback        session specific complete callback
   * @param logCallback             session specific log callback
   * @param logRedirectionStrategy  session specific log redirection strategy
   */
  FFplaySession(const std::list<std::string> &arguments,
                const FFplaySessionCompleteCallback completeCallback,
                const ffmpegkit::LogCallback logCallback,
                const LogRedirectionStrategy logRedirectionStrategy);

  FFplaySessionCompleteCallback _completeCallback;
  std::atomic<FFplayContext *> _context;
  double _position;
  double _duration;
  bool _isPlaying;
  bool _isPaused;
};

} // namespace ffmpegkit

#endif // FFMPEG_KIT_FFPLAY_SESSION_H
