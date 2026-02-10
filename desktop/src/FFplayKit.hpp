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

#ifndef FFPLAY_KIT_H
#define FFPLAY_KIT_H

#include "FFplaySession.hpp"
#include <stdlib.h>

namespace ffmpegkit {

/**
 * <p>Main class to run <code>FFplay</code> commands. Supports executing
 * commands both synchronously and asynchronously.
 */
class FFplayKit {
public:
  /**
   * <p>Synchronously executes FFplay with arguments provided.
   *
   * @param arguments FFplay command options/arguments as string list
   * @return FFplay session created for this execution
   */
  static std::shared_ptr<ffmpegkit::FFplaySession>
  executeWithArguments(const std::list<std::string> &arguments);

  /**
   * <p>Starts an asynchronous FFplay execution with arguments provided.
   *
   * <p>Note that this method returns immediately and does not wait the
   * execution to complete. You must use an FFplaySessionCompleteCallback if you
   * want to be notified about the result.
   *
   * @param arguments        FFplay command options/arguments as string list
   * @param completeCallback callback that will be called when the execution has
   * completed
   * @return FFplay session created for this execution
   */
  static std::shared_ptr<ffmpegkit::FFplaySession>
  executeWithArgumentsAsync(const std::list<std::string> &arguments,
                            FFplaySessionCompleteCallback completeCallback);

  /**
   * <p>Starts an asynchronous FFplay execution with arguments provided.
   *
   * <p>Note that this method returns immediately and does not wait the
   * execution to complete. You must use an FFplaySessionCompleteCallback if you
   * want to be notified about the result.
   *
   * @param arguments           FFplay command options/arguments as string list
   * @param completeCallback    callback that will be called when the execution
   * has completed
   * @param logCallback         callback that will receive logs
   * @return FFplay session created for this execution
   */
  static std::shared_ptr<ffmpegkit::FFplaySession>
  executeWithArgumentsAsync(const std::list<std::string> &arguments,
                            FFplaySessionCompleteCallback completeCallback,
                            ffmpegkit::LogCallback logCallback);

  /**
   * <p>Synchronously executes FFplay command provided. Space character is used
   * to split command into arguments. You can use single or double quote
   * characters to specify arguments inside your command.
   *
   * @param command FFplay command
   * @return FFplay session created for this execution
   */
  static std::shared_ptr<ffmpegkit::FFplaySession>
  execute(const std::string command);

  /**
   * <p>Starts an asynchronous FFplay execution for the given command. Space
   * character is used to split the command into arguments. You can use single
   * or double quote characters to specify arguments inside your command.
   *
   * <p>Note that this method returns immediately and does not wait the
   * execution to complete. You must use an FFplaySessionCompleteCallback if you
   * want to be notified about the result.
   *
   * @param command          FFplay command
   * @param completeCallback callback that will be called when the execution has
   * completed
   * @return FFplay session created for this execution
   */
  static std::shared_ptr<ffmpegkit::FFplaySession>
  executeAsync(const std::string command,
               FFplaySessionCompleteCallback completeCallback);

  /**
   * <p>Starts an asynchronous FFplay execution for the given command. Space
   * character is used to split the command into arguments. You can use single
   * or double quote characters to specify arguments inside your command.
   *
   * <p>Note that this method returns immediately and does not wait the
   * execution to complete. You must use an FFplaySessionCompleteCallback if you
   * want to be notified about the result.
   *
   * @param command             FFplay command
   * @param completeCallback    callback that will be called when the execution
   * has completed
   * @param logCallback         callback that will receive logs
   * @return FFplay session created for this execution
   */
  static std::shared_ptr<ffmpegkit::FFplaySession>
  executeAsync(const std::string command,
               FFplaySessionCompleteCallback completeCallback,
               ffmpegkit::LogCallback logCallback);

  /**
   * <p>Lists all FFplay sessions in the session history.
   *
   * @return all FFplay sessions in the session history
   */
  static std::shared_ptr<std::list<std::shared_ptr<ffmpegkit::FFplaySession>>>
  listFFplaySessions();

  /**
   * <p>Seek to the given position in the media.
   *
   * @param seconds Position to seek to in seconds
   */
  static void seek(double seconds);

  /**
   * <p>Pause the media.
   */
  static void pause();

  /**
   * <p>Resume the media.
   */
  static void resume();

  /**
   * <p>Stop the media.
   */
  static void stop();

  /**
   * <p>Get the current position in the media.
   *
   * @return Current position in seconds
   */
  static double getPosition();

  /**
   * <p>Get the duration of the media.
   *
   * @return Duration in seconds
   */
  static double getDuration();

  /**
   * <p>Check if the media is playing.
   *
   * @return True if the media is playing, false otherwise
   */
  static bool isPlaying();

  /**
   * <p>Check if the media is paused.
   *
   * @return True if the media is paused, false otherwise
   */
  static bool isPaused();

  /**
   * <p>Set the volume of the media.
   *
   * @param volume Volume to set (0.0 to 1.0)
   */
  static void setVolume(float volume);

  /**
   * <p>Set the playback speed of the media.
   *
   * @param speed Playback speed to set (0.5 to 100.0)
   */
  static void setPlaybackSpeed(double speed);

  /**
   * <p>Get the playback speed of the media.
   *
   * @return Playback speed
   */
  static double getPlaybackSpeed();
};

} // namespace ffmpegkit

#endif // FFPLAY_KIT_H
