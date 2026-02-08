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

const char program_name[] = "ffplay";
const int program_birth_year = 2003;

// Include the patched ffplay.c to access internal structures and static functions
// This is a common pattern in FFmpeg tools wrapping (e.g., ffmpeg_lib.c)
#include "ffplay.c"

// Forward declarations of internal functions we need that might be static
// (If they are static in ffplay.c, including the file makes them available here)

extern void (*ffplay_on_show_help)(void);
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

int ffplay_start(FFplayContext* ctx) {
    if (!ctx || !ctx->is) return -1;
    // ffplay_init_internal already started threads (read_thread, etc.)
    return 0; 
}

// Single step of the event loop logic
int ffplay_step(FFplayContext* ctx) {
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
        default:
            break;
        }
    }
    
    // Refresh video if needed (from refresh_loop_wait_event logic)
    if (!cursor_hidden && av_gettime_relative() - cursor_last_shown > CURSOR_HIDE_DELAY) {
        SDL_ShowCursor(0);
        cursor_hidden = 1;
    }
    
    if (ctx->is->show_mode != SHOW_MODE_NONE && (!ctx->is->paused || ctx->is->force_refresh)) {
         video_refresh(ctx->is, &remaining_time);
    }

    return ctx->quit;
}

int ffplay_seek(FFplayContext* ctx, double seconds) {
    if (!ctx || !ctx->is) return -1;
    // Logic similar to stream_seek
    int64_t pos = (int64_t)(seconds * AV_TIME_BASE);
    int64_t rel = 0;
    stream_seek(ctx->is, pos, rel, 0); // 0 = not by bytes
    return 0;
}

int ffplay_pause(FFplayContext* ctx) {
    if (!ctx || !ctx->is) return -1;
    if (!ctx->is->paused)
        stream_toggle_pause(ctx->is);
    return 0;
}

int ffplay_resume(FFplayContext* ctx) {
    if (!ctx || !ctx->is) return -1;
    if (ctx->is->paused)
        stream_toggle_pause(ctx->is);
    return 0;
}

int ffplay_stop(FFplayContext* ctx) {
    if (!ctx || !ctx->is) return -1;
    do_exit(ctx->is);
    ctx->quit = 1;
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
    int vol = av_clip(volume * 100, 0, 100);
    vol = av_clip(SDL_MIX_MAXVOLUME * vol / 100, 0, SDL_MIX_MAXVOLUME);
    ctx->is->audio_volume = vol;
}

void ffplay_free(FFplayContext* ctx) {
    if (!ctx) return;
    if (!ctx->quit) {
        do_exit(ctx->is);
    }
    // argv freed
    if (ctx->argv) {
        for (int i=0; i<ctx->argc; i++) av_free(ctx->argv[i]);
        av_free(ctx->argv);
    }
    av_free(ctx);
}
