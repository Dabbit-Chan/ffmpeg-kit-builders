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

#ifdef __ANDROID__
#include <jni.h>
#endif

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
   * @param timeout   the timeout in milliseconds
   * @return FFplay session created for this execution
   */
  static std::shared_ptr<ffmpegkit::FFplaySession>
  executeWithArguments(const std::list<std::string> &arguments, int timeout);

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
   * @param timeout          the timeout in milliseconds
   * @return FFplay session created for this execution
   */
  static std::shared_ptr<ffmpegkit::FFplaySession>
  executeWithArgumentsAsync(const std::list<std::string> &arguments,
                            FFplaySessionCompleteCallback completeCallback,
                            int timeout);

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
   * @param timeout             the timeout in milliseconds
   * @return FFplay session created for this execution
   */
  static std::shared_ptr<ffmpegkit::FFplaySession>
  executeWithArgumentsAsync(const std::list<std::string> &arguments,
                            FFplaySessionCompleteCallback completeCallback,
                            ffmpegkit::LogCallback logCallback,
                            int timeout);

  /**
   * <p>Synchronously executes FFplay command provided. Space character is used
   * to split command into arguments. You can use single or double quote
   * characters to specify arguments inside your command.
   *
   * @param command FFplay command
   * @param timeout the timeout in milliseconds
   * @return FFplay session created for this execution
   */
  static std::shared_ptr<ffmpegkit::FFplaySession>
  execute(const std::string command, int timeout);

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
   * @param timeout          the timeout in milliseconds
   * @return FFplay session created for this execution
   */
  static std::shared_ptr<ffmpegkit::FFplaySession>
  executeAsync(const std::string command,
               FFplaySessionCompleteCallback completeCallback,
               int timeout);

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
   * @param timeout             the timeout in milliseconds
   * @return FFplay session created for this execution
   */
  static std::shared_ptr<ffmpegkit::FFplaySession>
  executeAsync(const std::string command,
               FFplaySessionCompleteCallback completeCallback,
               ffmpegkit::LogCallback logCallback,
               int timeout);

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
   * <p>Start the media.
   */
  static void start();

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
   * <p>Set the current position in the media.
   *
   * @param position Position to set in seconds
   */
  static void setPosition(double position);

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
   * <p>Get the volume of the media.
   *
   * @return Volume (0.0 to 1.0)
   */
  static float getVolume();

  /**
   * <p>Close the ffplay session.
   */
  static void close();

#ifdef __ANDROID__
  /**
   * <p>Sets the Android Surface for FFplay video output.
   *
   * <p>Must be called before executing an FFplay session. The Surface is
   * typically obtained from a SurfaceView or TextureView in your Activity or
   * Fragment. Call with <code>nullptr</code> when the Surface is destroyed
   * (e.g., in <code>surfaceDestroyed()</code>) to avoid use-after-free.
   *
   * <p>Audio output uses OpenSL ES and requires no Surface.
   *
   * @param env     JNIEnv pointer from the calling JNI context
   * @param surface jobject of type android.view.Surface, or nullptr to clear
   */
  static void setAndroidSurface(JNIEnv *env, jobject surface);
#endif /* __ANDROID__ */
};

} // namespace ffmpegkit

#endif // FFPLAY_KIT_H
