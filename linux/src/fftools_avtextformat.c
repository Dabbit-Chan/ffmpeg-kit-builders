/*
 * This file is part of FFmpeg.
 * Copyright (c) 2025 Akash Patel
 * Copyright (c) 2023 ARTHENICA LTD
 *
 * FFmpeg is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 */

#include "fftools_avtextformat.h"
#include "libavutil/avstring.h"
#include "libavutil/bprint.h"
#include "libavutil/error.h"
#include "libavutil/log.h"
#include "libavutil/mem.h"
#include "libavutil/opt.h"
#include "libavutil/dict.h"
#include <stdarg.h>

/* Minimal AVTextWriter implementation wrapping AVIOContext */
struct AVTextWriterContext {
    const AVClass *class;
    AVIOContext *avio;
    int close_on_uninit;
};

static void writer_print(AVTextWriterContext *wctx, const char *fmt, ...) {
    va_list vl;
    va_start(vl, fmt);
    if (wctx->avio) {
        // Use a temporary buffer to format the string for AVIO
        char buf[1024];
        vsnprintf(buf, sizeof(buf), fmt, vl);
        avio_write(wctx->avio, (const uint8_t *)buf, strlen(buf));
    } else {
        av_vlog(NULL, AV_LOG_INFO, fmt, vl);
    }
    va_end(vl);
}

int avtextwriter_create_avio(AVTextWriterContext **pwctx, AVIOContext *avio, int close_on_uninit) {
    AVTextWriterContext *wctx = av_mallocz(sizeof(*wctx));
    if (!wctx) return AVERROR(ENOMEM);
    wctx->avio = avio;
    wctx->close_on_uninit = close_on_uninit;
    *pwctx = wctx;
    return 0;
}

int avtextwriter_create_file(AVTextWriterContext **pwctx, const char *filename) {
    AVIOContext *avio = NULL;
    int ret = avio_open(&avio, filename, AVIO_FLAG_WRITE);
    if (ret < 0) return ret;
    return avtextwriter_create_avio(pwctx, avio, 1);
}

int avtextwriter_context_close(AVTextWriterContext **pwctx) {
    AVTextWriterContext *wctx = *pwctx;
    if (!wctx) return 0;
    if (wctx->close_on_uninit && wctx->avio)
        avio_closep(&wctx->avio);
    av_freep(pwctx);
    return 0;
}

const AVTextFormatter avtextformatter_default = { .name = "default" };
const AVTextFormatter avtextformatter_json    = { .name = "json" };
const AVTextFormatter avtextformatter_xml     = { .name = "xml" };
const AVTextFormatter avtextformatter_flat    = { .name = "flat" };
const AVTextFormatter avtextformatter_ini     = { .name = "ini" };
const AVTextFormatter avtextformatter_csv     = { .name = "csv" };

const AVTextFormatter *avtext_get_formatter_by_name(const char *name) {
    if (!strcmp(name, "default")) return &avtextformatter_default;
    if (!strcmp(name, "json"))    return &avtextformatter_json;
    if (!strcmp(name, "xml"))     return &avtextformatter_xml;
    if (!strcmp(name, "flat"))    return &avtextformatter_flat;
    if (!strcmp(name, "ini"))     return &avtextformatter_ini;
    if (!strcmp(name, "csv"))     return &avtextformatter_csv;
    return NULL;
}

int avtext_context_open(AVTextFormatContext **ptctx, const AVTextFormatter *formatter,
                        AVTextWriterContext *writer, const char *args,
                        const AVTextFormatSection *sections, int nb_sections,
                        AVTextFormatOptions options, const char *hash_str) {
    AVTextFormatContext *tctx = av_mallocz(sizeof(*tctx));
    if (!tctx) return AVERROR(ENOMEM);
    
    tctx->formatter = formatter;
    tctx->writer = writer;
    tctx->options = options;
    tctx->sections = sections;
    tctx->nb_sections = nb_sections;
    
    *ptctx = tctx;
    return 0;
}

int avtext_context_close(AVTextFormatContext **ptctx) {
    av_freep(ptctx);
    return 0;
}

// Basic printing implementations (simplified for logging)
void avtext_print_section_header(AVTextFormatContext *tctx, const void *data, int section_id) {
    const AVTextFormatSection *s = &tctx->sections[section_id];
    writer_print(tctx->writer, "[%s]\n", s->name);
}

void avtext_print_section_footer(AVTextFormatContext *tctx) {
    writer_print(tctx->writer, "\n");
}

int avtext_print_string(AVTextFormatContext *tctx, const char *key, const char *val, int flags) {
    writer_print(tctx->writer, "%s=%s\n", key, val);
    return 0;
}

int avtext_print_integer(AVTextFormatContext *tctx, const char *key, int64_t val, int flags) {
    writer_print(tctx->writer, "%s=%"PRId64"\n", key, val);
    return 0;
}

int avtext_print_rational(AVTextFormatContext *tctx, const char *key, AVRational val, char sep) {
    writer_print(tctx->writer, "%s=%d%c%d\n", key, val.num, sep, val.den);
    return 0;
}

int avtext_print_time(AVTextFormatContext *tctx, const char *key, int64_t ts, const AVRational *tb, int duration) {
    if (ts == AV_NOPTS_VALUE) {
        writer_print(tctx->writer, "%s=N/A\n", key);
    } else {
        double d = av_q2d(*tb) * ts;
        writer_print(tctx->writer, "%s=%f\n", key, d);
    }
    return 0;
}

int avtext_print_ts(AVTextFormatContext *tctx, const char *key, int64_t ts, int is_duration) {
    if (ts == AV_NOPTS_VALUE) {
        writer_print(tctx->writer, "%s=N/A\n", key);
    } else {
        writer_print(tctx->writer, "%s=%"PRId64"\n", key, ts);
    }
    return 0;
}

int avtext_print_unit_integer(AVTextFormatContext *tctx, const char *key, int64_t val, const char *unit) {
    writer_print(tctx->writer, "%s=%"PRId64"%s\n", key, val, tctx->options.show_value_unit ? unit : "");
    return 0;
}

int avtext_print_integers(AVTextFormatContext *tctx, const char *key, const void *data, int count,
                           const char *fmt, int size, int columns, int pad) {
     writer_print(tctx->writer, "%s=...\n", key); // Simplified
     return 0;
}

int avtext_print_data(AVTextFormatContext *tctx, const char *key, const uint8_t *data, int size) {
     writer_print(tctx->writer, "%s=(%d bytes)\n", key, size);
     return 0;
}

int avtext_print_data_hash(AVTextFormatContext *tctx, const char *key, const uint8_t *data, int size) {
     // Hash printing logic would go here
     return 0;
}