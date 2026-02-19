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

#include "ffplay_lib.h"
#include <SDL.h>
#include "ffmpeg_tls.h"

const char program_name[] = "ffplay";
const int program_birth_year = 2003;

// Global state for audio device management
static char *requested_audio_device = NULL;
static SDL_AudioSpec captured_wanted_spec;
static int has_captured_spec = 0;
struct VideoState; // Forward declaration
static struct VideoState *active_audio_is = NULL;
static SDL_AudioDeviceID active_audio_dev_id = 0;

// Interception logic
static SDL_AudioDeviceID ffplay_kit_SDL_OpenAudioDevice(
    const char *device,
    int iscapture,
    const SDL_AudioSpec *desired,
    SDL_AudioSpec *obtained,
    int allowed_changes)
{
    const char *target = device;
    if (requested_audio_device && !iscapture) {
        target = requested_audio_device;
    }

    SDL_AudioDeviceID dev = SDL_OpenAudioDevice(target, iscapture, desired, obtained, allowed_changes);

    // Capture the spec if this is our main playback session opening
    if (desired && !iscapture && dev > 0) {
        captured_wanted_spec = *desired;
        has_captured_spec = 1;
        // active_audio_is will be extracted from userdata after compilation of ffplay.c struct
        active_audio_is = (struct VideoState *)desired->userdata;
        active_audio_dev_id = dev;
    }

    return dev;
}

static void ffplay_kit_SDL_CloseAudioDevice(SDL_AudioDeviceID dev) {
    if (dev > 0 && dev == active_audio_dev_id) {
        active_audio_is = NULL;
        active_audio_dev_id = 0;
        has_captured_spec = 0;
    }
    SDL_CloseAudioDevice(dev);
}

// Redirection macro must be defined before including ffplay.c
#define SDL_OpenAudioDevice ffplay_kit_SDL_OpenAudioDevice
#define SDL_CloseAudioDevice ffplay_kit_SDL_CloseAudioDevice

// Include the patched ffplay.c to access internal structures and static functions
// This is a common pattern in FFmpeg tools wrapping (e.g., ffmpeg_lib.c)
#include "ffplay.c"

// Forward declare the auto-generated TLS initializer
extern void ffplay_tls_init_options(void);
// Forward declarations of internal functions we need that might be static
// (If they are static in ffplay.c, including the file makes them available here)
extern FFMPEG_THREAD_LOCAL void (*ffplay_on_show_help)(void);
extern VideoState *ffplay_init_internal(int argc, char **argv);
extern void ffplay_reset_internal_state(void);

struct FFplayContext {
    VideoState *is;
    int argc;
    char **argv;
    FFplayCallbacks callbacks;
    int quit;
};

// Helper for argument splitting (reuse from other libs if possible, specific implementation here)
static int split_args(const char *args, char ***argv_out) {
    if (!args || !argv_out) return -1;
    char *args_copy = av_strdup(args);
    if (!args_copy) return -1;

    int argc = 0;
    char *p = args_copy;
    int in_quotes = 0;

    // Count
    while (*p) {
        while (*p && !in_quotes && (*p == ' ' || *p == '\t' || *p == '\n')) p++;
        if (!*p) break;
        argc++;
        if (*p == '"') {
            in_quotes = 1;
            p++;
            while (*p && *p != '"') p++;
            if (*p) p++;
            in_quotes = 0;
        } else {
            while (*p && *p != ' ' && *p != '\t' && *p != '\n') p++;
        }
    }

    char **argv = av_mallocz(sizeof(char *) * (argc + 1));
    if (!argv) {
        av_free(args_copy);
        return -1;
    }

    strcpy(args_copy, args);
    p = args_copy;
    int idx = 0;
    while (*p && idx < argc) {
        while (*p && (*p == ' ' || *p == '\t' || *p == '\n')) p++;
        if (!*p) break;
        char *start = p;
        if (*p == '"') {
            p++;
            start = p;
            while (*p && *p != '"') p++;
            if (*p) *p++ = '\0';
        } else {
            while (*p && *p != ' ' && *p != '\t' && *p != '\n') p++;
            if (*p) *p++ = '\0';
        }
        argv[idx++] = av_strdup(start);
    }
    
    av_free(args_copy);
    *argv_out = argv;
    return argc;
}

FFplayContext* ffplay_init(const char* args_string, const FFplayCallbacks *cb) {
    FFplayContext *ctx = av_mallocz(sizeof(FFplayContext));
    if (!ctx) return NULL;

    if (cb) {
        ctx->callbacks = *cb;
    }
    
    // Reset global state in ffplay.c
    ffplay_reset_internal_state();

    ffplay_tls_init_options();

    ctx->argc = split_args(args_string, &ctx->argv);
    if (ctx->argc < 0) {
        av_free(ctx);
        return NULL;
    }

    // Call internal init
    // Note: ffplay_init_internal calls everything up to event_loop
    ctx->is = ffplay_init_internal(ctx->argc, ctx->argv);
    if (!ctx->is) {
        // Init failed
        for (int i=0; i<ctx->argc; i++) av_free(ctx->argv[i]);
        av_free(ctx->argv);
        av_free(ctx);
        return NULL;
    }

    return ctx;
}

// Custom events for thread-safe control
#define FF_PLAY_SEEK_EVENT      (SDL_USEREVENT + 3)
#define FF_PLAY_PAUSE_EVENT     (SDL_USEREVENT + 4)
#define FF_PLAY_RESUME_EVENT    (SDL_USEREVENT + 5)
#define FF_PLAY_VOLUME_EVENT    (SDL_USEREVENT + 6)
#define FF_PLAY_SPEED_EVENT     (SDL_USEREVENT + 7)

// Data structures for events
typedef struct SeekEventData {
    double seconds;
    double rel;
} SeekEventData;

typedef struct SpeedEventData {
    double speed;
} SpeedEventData;

typedef struct VolumeEventData {
    float volume;
} VolumeEventData;

static char *base_afilters = NULL;
static char *allocated_afilters = NULL;

int ffplay_start(FFplayContext* ctx) {
    if (!ctx || !ctx->is) return -1;
    // ffplay_init_internal already started threads (read_thread, etc.)
    return 0; 
}

int ffplay_step(FFplayContext* ctx) {
    if (ctx->quit) return 1;
    if (!ctx || !ctx->is) return 1;

    SDL_Event event;
    double remaining_time = 0.0; // Instant return if possible

    SDL_PumpEvents();

    // Peep events
    while (SDL_PeepEvents(&event, 1, SDL_GETEVENT, SDL_FIRSTEVENT, SDL_LASTEVENT) > 0) {
         switch (event.type) {
        case SDL_KEYDOWN:
            if (exit_on_keydown || event.key.keysym.sym == SDLK_ESCAPE || event.key.keysym.sym == SDLK_q) {
                do_exit(ctx->is);
                ctx->is = NULL;
                ctx->quit = 1;
                return 1;
            }
            if (!ctx->is->width) continue;
            switch (event.key.keysym.sym) {
            case SDLK_f:
                toggle_full_screen(ctx->is);
                ctx->is->force_refresh = 1;
                break;
            case SDLK_p:
            case SDLK_SPACE:
                toggle_pause(ctx->is);
                break;
            case SDLK_m:
                toggle_mute(ctx->is);
                break;
            case SDLK_KP_MULTIPLY:
            case SDLK_0:
                update_volume(ctx->is, 1, SDL_VOLUME_STEP);
                break;
            case SDLK_KP_DIVIDE:
            case SDLK_9:
                update_volume(ctx->is, -1, SDL_VOLUME_STEP);
                break;
            case SDLK_s: // S: Step to next frame
                step_to_next_frame(ctx->is);
                break;
            case SDLK_a:
                stream_cycle_channel(ctx->is, AVMEDIA_TYPE_AUDIO);
                break;
            case SDLK_v:
                stream_cycle_channel(ctx->is, AVMEDIA_TYPE_VIDEO);
                break;
            case SDLK_c:
                stream_cycle_channel(ctx->is, AVMEDIA_TYPE_VIDEO);
                stream_cycle_channel(ctx->is, AVMEDIA_TYPE_AUDIO);
                stream_cycle_channel(ctx->is, AVMEDIA_TYPE_SUBTITLE);
                break;
            case SDLK_t:
                stream_cycle_channel(ctx->is, AVMEDIA_TYPE_SUBTITLE);
                break;
            case SDLK_w:
                if (ctx->is->show_mode == SHOW_MODE_VIDEO && ctx->is->vfilter_idx < nb_vfilters - 1) {
                    if (++ctx->is->vfilter_idx >= nb_vfilters)
                        ctx->is->vfilter_idx = 0;
                } else {
                    ctx->is->vfilter_idx = 0;
                    toggle_audio_display(ctx->is);
                }
                break;
             // Seeking logic copied from event_loop
            default:
                break;
            }
            break;
        case SDL_QUIT:
        case FF_QUIT_EVENT:
            do_exit(ctx->is);
            ctx->quit = 1;
            return 1;
        
        // Custom Events Handling
        case FF_PLAY_SEEK_EVENT: {
            SeekEventData *data = (SeekEventData*)event.user.data1;
            if (data) {
                int64_t pos = (int64_t)(data->seconds * AV_TIME_BASE);
                int64_t rel_pts = (int64_t)(data->rel * AV_TIME_BASE);
                stream_seek(ctx->is, pos, rel_pts, 0);
                av_free(data);
            }
            break;
        }
        case FF_PLAY_PAUSE_EVENT:
            if (!ctx->is->paused)
                stream_toggle_pause(ctx->is);
            break;
        case FF_PLAY_RESUME_EVENT:
            if (ctx->is->paused)
                stream_toggle_pause(ctx->is);
            break;
        case FF_PLAY_VOLUME_EVENT: {
            VolumeEventData *data = (VolumeEventData*)event.user.data1;
            if (data) {
                int vol = av_clip(data->volume * 100, 0, 100);
                vol = av_clip(SDL_MIX_MAXVOLUME * vol / 100, 0, SDL_MIX_MAXVOLUME);
                ctx->is->audio_volume = vol;
                av_free(data);
            }
            break;
        }
        case FF_PLAY_SPEED_EVENT: {
            SpeedEventData *data = (SpeedEventData*)event.user.data1;
            if (data) {
                double speed = data->speed;

                // Capture base filters consistently
                if (!base_afilters) {
                    if (afilters) {
                        base_afilters = av_strdup(afilters);
                    } else {
                        base_afilters = av_strdup("");
                    }
                }

                char filters_buf[1024] = "";
                if (base_afilters && strlen(base_afilters) > 0)
                    av_strlcat(filters_buf, base_afilters, sizeof(filters_buf));

                if (speed != 1.0) {
                   double s = speed;
                   // Chain atempo
                   while (s > 2.0) {
                       if (strlen(filters_buf) > 0) av_strlcat(filters_buf, ",", sizeof(filters_buf));
                       av_strlcat(filters_buf, "atempo=2.0", sizeof(filters_buf));
                       s /= 2.0;
                   }
                   while (s < 0.5) {
                       if (strlen(filters_buf) > 0) av_strlcat(filters_buf, ",", sizeof(filters_buf));
                       av_strlcat(filters_buf, "atempo=0.5", sizeof(filters_buf));
                       s /= 0.5;
                   }
                   if (s != 1.0) {
                       if (strlen(filters_buf) > 0) av_strlcat(filters_buf, ",", sizeof(filters_buf));
                       char atempo_args[32];
                       snprintf(atempo_args, sizeof(atempo_args), "atempo=%g", s);
                       av_strlcat(filters_buf, atempo_args, sizeof(filters_buf));
                   }
                }

                if (allocated_afilters) {
                    av_free(allocated_afilters);
                    allocated_afilters = NULL;
                }
                
                allocated_afilters = av_strdup(filters_buf);
                afilters = allocated_afilters;

                // Force reconfiguration of audio filters
                // We need to access the graph to reconfigure, but ffplay.c handles this 
                // by checking afilters change mostly in configure_audio_filters
                // But we need to trigger it.
                // In ffplay.c, `audio_open` or `configure_filtergraph` uses `afilters`.
                // Changing logic: `audio_thread` reconfigures if `is->audio_filter_src.freq` changes or similar.
                // Setting `is->audio_filter_src.freq = 0` forces reconfiguration in `audio_thread`.
                ctx->is->audio_filter_src.freq = 0;
                
                av_free(data);
            }
            break;
        }

        default:
            break;
        }
    }
    
    // Refresh video if needed (from refresh_loop_wait_event logic)
    if (!cursor_hidden) {
        if (av_gettime_relative() - cursor_last_shown > CURSOR_HIDE_DELAY) {
            SDL_ShowCursor(0);
            cursor_hidden = 1;
        }
    }
    
    if (ctx->is->show_mode != SHOW_MODE_NONE && (!ctx->is->paused || ctx->is->force_refresh)) {
         video_refresh(ctx->is, &remaining_time);
    }

    return ctx->quit;
}

int ffplay_seek(FFplayContext* ctx, double seconds, double rel) {
    if (!ctx || !ctx->is) return -1;
    
    SeekEventData *data = av_malloc(sizeof(SeekEventData));
    if (!data) return -1;
    data->seconds = seconds;
    data->rel = rel;

    SDL_Event event;
    event.type = FF_PLAY_SEEK_EVENT;
    event.user.data1 = data;
    SDL_PushEvent(&event);
    
    return 0;
}

int ffplay_pause(FFplayContext* ctx) {
    if (!ctx || !ctx->is) return -1;
    
    SDL_Event event;
    event.type = FF_PLAY_PAUSE_EVENT;
    SDL_PushEvent(&event);
    
    return 0;
}

int ffplay_resume(FFplayContext* ctx) {
    if (!ctx || !ctx->is) return -1;

    SDL_Event event;
    event.type = FF_PLAY_RESUME_EVENT;
    SDL_PushEvent(&event);
    
    return 0;
}

int ffplay_stop(FFplayContext* ctx) {
    if (!ctx || !ctx->is) return -1;
    
    SDL_Event event;
    event.type = FF_QUIT_EVENT;
    // Don't pass is pointer as data, it might be freed before event is processed if we are racing.
    // However, the event loop uses event.user.data1 = is. 
    // But since we are inside ffplay_lib.c and have access to ctx->is, we rely on the loop to handle it correctly.
    // The issue is likely that the read_thread or other threads are accessing 'is' while it's being freed.
    // But here we are just pushing an event.
    event.user.data1 = ctx->is; 
    SDL_PushEvent(&event);
    
    return 0;
}

double ffplay_get_position(FFplayContext* ctx) {
    if (!ctx || !ctx->is) return 0.0;
    return get_master_clock(ctx->is);
}

double ffplay_get_duration(FFplayContext* ctx) {
    if (!ctx || !ctx->is || !ctx->is->ic) return 0.0;
    if (ctx->is->ic->duration == AV_NOPTS_VALUE) return 0.0;
    return (double)ctx->is->ic->duration / AV_TIME_BASE;
}

int ffplay_is_playing(FFplayContext* ctx) {
    if (!ctx || !ctx->is) return 0;
    return !ctx->is->paused && !ctx->quit;
}

int ffplay_is_paused(FFplayContext* ctx) {
    if (!ctx || !ctx->is) return 0;
    return ctx->is->paused;
}

void ffplay_set_volume(FFplayContext* ctx, float volume) {
    if (!ctx || !ctx->is) return;
    
    VolumeEventData *data = av_malloc(sizeof(VolumeEventData));
    if (!data) return;
    data->volume = volume;

    SDL_Event event;
    event.type = FF_PLAY_VOLUME_EVENT;
    event.user.data1 = data;
    SDL_PushEvent(&event);
}

float ffplay_get_volume(FFplayContext* ctx) {
    if (!ctx || !ctx->is) return 0.0;
    return ctx->is->audio_volume;
}

void ffplay_set_audio_output_device(const char* device_name) {
    // Update global requested name
    if (requested_audio_device) {
        av_free(requested_audio_device);
        requested_audio_device = NULL;
    }
    if (device_name) {
        requested_audio_device = av_strdup(device_name);
    }

    // Hot-swap if active
    if (active_audio_is && active_audio_is->audio_dev > 0 && has_captured_spec) {
        // Lock not strictly needed if we assume single-thread UI control but let's be safe(r) if SDL supports it
        // Check SDL_LockAudio not needed for Close/Open per docs
        
        struct VideoState *local_is = active_audio_is;
        SDL_CloseAudioDevice(local_is->audio_dev); 
        // Note: active_audio_is is cleared by interception here!
        
        // Open new device
        // We MUST use 0 for allowed changes to force SDL to match our existing spec
        // If we allowed changes, we'd have to reconfigure the whole filter graph which is hard from here
        SDL_AudioSpec obtained_spec;
        local_is->audio_dev = SDL_OpenAudioDevice(requested_audio_device, 0, &captured_wanted_spec, &obtained_spec, 0);
        
        if (local_is->audio_dev) {
            SDL_PauseAudioDevice(local_is->audio_dev, 0);
        } else {
            av_log(NULL, AV_LOG_ERROR, "Failed to switch audio device: %s\n", SDL_GetError());
            // Try fallback to default?
            if (device_name) {
                 // Open default
                 local_is->audio_dev = SDL_OpenAudioDevice(NULL, 0, &captured_wanted_spec, &obtained_spec, 0);
                 if (local_is->audio_dev) SDL_PauseAudioDevice(local_is->audio_dev, 0);
            }
        }
    }

}


char* ffplay_list_audio_devices(void) {
    if (SDL_InitSubSystem(SDL_INIT_AUDIO) < 0) {
        return NULL;
    }

    int count = SDL_GetNumAudioDevices(0);
    if (count <= 0) {
        SDL_QuitSubSystem(SDL_INIT_AUDIO);
        return NULL;
    }

    // Build a semicolon separated string
    // Calculate size first
    size_t total_len = 0;
    for (int i=0; i<count; i++) {
        const char *name = SDL_GetAudioDeviceName(i, 0);
        if (name) {
            total_len += strlen(name) + 1; // +1 for ';' or '\0'
        }
    }
    
    if (total_len == 0) {
        SDL_QuitSubSystem(SDL_INIT_AUDIO);
        return NULL;
    }

    char *result = av_malloc(total_len + 1);
    if (!result) {
        SDL_QuitSubSystem(SDL_INIT_AUDIO);
        return NULL;
    }
    result[0] = '\0';
    
    for (int i=0; i<count; i++) {
        const char *name = SDL_GetAudioDeviceName(i, 0);
        if (name) {
            strcat(result, name);
            if (i < count - 1) {
                strcat(result, ";");
            }
        }
    }

    SDL_QuitSubSystem(SDL_INIT_AUDIO);
    return result;
}

void ffplay_free(FFplayContext* ctx) {
    if (!ctx) return;
    if (!ctx->quit) {
        do_exit(ctx->is);
        // do_exit called SDL_Quit once.
    }
    
    // Force full SDL shutdown in case multiple inits increased refcount
    while (SDL_WasInit(0)) {
        SDL_Quit();
    }

    // Cleanup globals
    if (allocated_afilters) {
        av_free(allocated_afilters);
        allocated_afilters = NULL;
    }
    if (base_afilters) {
        av_free(base_afilters);
        base_afilters = NULL;
    }

    if (requested_audio_device) {
        av_free(requested_audio_device);
        requested_audio_device = NULL;
    }
    
    // Free VideoState structure (allocated in ffplay.c/ffplay_init_internal)
    // NOTE: stream_close(is) called by do_exit(is) already frees 'is' (av_free(is) in stream_close).
    // So we must NOT free it again here.
    if (ctx->is) {
        ctx->is = NULL;
    }

    // argv freed
    if (ctx->argv) {
        for (int i=0; i<ctx->argc; i++) av_free(ctx->argv[i]);
        av_free(ctx->argv);
    }
    av_free(ctx);
}

void ffplay_close(FFplayContext* ctx) {
    ffplay_free(ctx);
}
