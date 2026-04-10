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

/*
 * iOS/macOS platform glue for FFmpegKit.
 *
 * Provides:
 *   - AVAudioSession activation on iOS so that CoreAudio (SDL's coreaudio
 *     driver, set in ffplay_lib.c) can open an audio output stream without the
 *     host app having to configure the session first.
 *   - A __attribute__((constructor)) initializer that runs once at library
 *     load time, mirroring the role of JNI_OnLoad on Android.
 *
 * On macOS, AVAudioSession does not exist; only the os_log initializer runs.
 *
 * Audio is handled by SDL's CoreAudio backend (SDL_AUDIODRIVER=coreaudio set
 * in ffplay_lib.c), which is fully native and requires no Objective-C
 * interaction beyond the one-time AVAudioSession activation below.
 *
 * Swift/ObjC integration:
 *   If the host application already configures AVAudioSession (e.g. for
 *   recording or Bluetooth routing), call ffmpeg_kit_apple_configure_audio()
 *   before starting an FFplay session to apply FFmpegKit's preferred category.
 *   Passing activate=NO lets you manage activation yourself.
 */

#ifdef __APPLE__

#import <Foundation/Foundation.h>
#import <os/log.h>
#include <TargetConditionals.h>

#if TARGET_OS_IOS
#import <AVFoundation/AVFoundation.h>
#endif

#define LOG_TAG "FFmpegKitApple"

static os_log_t _apple_log = NULL;

static void ensure_log(void) {
    if (!_apple_log)
        _apple_log = os_log_create("com.akashskypatel.ffmpegkit", LOG_TAG);
}

#define ALOGI(fmt, ...) do { ensure_log(); os_log_info(_apple_log,  fmt, ##__VA_ARGS__); } while(0)
#define ALOGE(fmt, ...) do { ensure_log(); os_log_error(_apple_log, fmt, ##__VA_ARGS__); } while(0)

#if TARGET_OS_IOS
/**
 * Activates AVAudioSession for playback on iOS.
 *
 * Sets the session category to AVAudioSessionCategoryPlayback (allows audio
 * when the silent switch is engaged) and activates the session.  Safe to call
 * multiple times.
 *
 * @param activate  Pass YES to activate the session immediately (recommended
 *                  before starting an FFplay session).  Pass NO to configure
 *                  the category without activating (useful when the host app
 *                  manages activation timing, e.g. after requesting microphone
 *                  permission).
 */
void ffmpeg_kit_apple_configure_audio(BOOL activate) {
    NSError *error = nil;
    AVAudioSession *session = [AVAudioSession sharedInstance];

    BOOL ok = [session setCategory:AVAudioSessionCategoryPlayback
                              mode:AVAudioSessionModeMoviePlayback
                           options:AVAudioSessionCategoryOptionMixWithOthers
                             error:&error];
    if (!ok) {
        ALOGE("[ffmpeg_kit_apple] setCategory failed: %{public}s",
              error.localizedDescription.UTF8String);
        return;
    }

    if (activate) {
        ok = [session setActive:YES error:&error];
        if (!ok) {
            ALOGE("[ffmpeg_kit_apple] setActive failed: %{public}s",
                  error.localizedDescription.UTF8String);
        } else {
            ALOGI("[ffmpeg_kit_apple] AVAudioSession activated (category=Playback mode=MoviePlayback)");
        }
    }
}
#endif /* TARGET_OS_IOS */

/**
 * Library-load initializer — runs once when the dylib/framework is loaded.
 *
 * On iOS: activates AVAudioSession so SDL's coreaudio driver can open the
 *         audio device immediately when ffplay_init() is called.
 * On macOS: initialises the os_log subsystem only (CoreAudio HAL does not
 *           require session management on macOS).
 */
__attribute__((constructor))
static void ffmpeg_kit_apple_init(void) {
    ensure_log();
    ALOGI("[ffmpeg_kit_apple] library loaded (platform=%{public}s)",
#if TARGET_OS_IOS
          "ios"
#elif TARGET_OS_TV
          "tvos"
#elif TARGET_OS_WATCH
          "watchos"
#else
          "macos"
#endif
    );

#if TARGET_OS_IOS
    ffmpeg_kit_apple_configure_audio(YES);
#endif
}

#endif /* __APPLE__ */
