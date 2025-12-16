/*
 * This file is part of FFmpeg.
 *
 * FFmpeg is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * FFmpeg is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with FFmpeg; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
 */

#ifndef FFTOOLS_AVTEXTFORMAT_H
#define FFTOOLS_AVTEXTFORMAT_H

#include <stddef.h>
#include <stdint.h>
#include "libavutil/rational.h"
#include "libavformat/avio.h"

#define AV_TEXTFORMAT_SECTION_FLAG_IS_WRAPPER           (1 << 0)
#define AV_TEXTFORMAT_SECTION_FLAG_IS_ARRAY             (1 << 1)
#define AV_TEXTFORMAT_SECTION_FLAG_HAS_VARIABLE_FIELDS  (1 << 2)
#define AV_TEXTFORMAT_SECTION_FLAG_HAS_TYPE             (1 << 3)
#define AV_TEXTFORMAT_SECTION_FLAG_NUMBERING_BY_TYPE    (1 << 4)

#define AV_TEXTFORMAT_PRINT_STRING_OPTIONAL      (1 << 0)
#define AV_TEXTFORMAT_PRINT_STRING_VALIDATE      (1 << 1)

// Added missing flag
#define AV_TEXTFORMAT_FLAG_SUPPORTS_MIXED_ARRAY_CONTENT (1 << 0)

typedef struct AVTextFormatSection {
    int id;
    const char *name;
    int flags;
    const int children_ids[25];
    const char *element_name;
    const char *unique_name;
    const char *(*get_type)(const void *data);
    
    // Internal use
    int show_all_entries;
    struct AVDictionary *entries_to_show;
} AVTextFormatSection;

typedef struct AVTextWriterContext AVTextWriterContext;

typedef struct AVTextFormatOptions {
    int show_optional_fields;
    int show_value_unit;
    int use_value_prefix;
    int use_byte_value_binary_prefix;
    int use_value_sexagesimal_format;
} AVTextFormatOptions;

// Moved struct definition here so ffprobe can access 'flags'
typedef struct AVTextFormatter {
    const char *name;
    int flags;
} AVTextFormatter;

// Moved struct definition here so ffprobe can access members
typedef struct AVTextFormatContext {
    const AVTextFormatter *formatter;
    AVTextWriterContext *writer;
    AVTextFormatOptions options;
    const AVTextFormatSection *sections;
    int nb_sections;
    
    // Internal state for default formatting
    int indent_level;
    int is_first;
    
    int string_validation_utf8_flags;
} AVTextFormatContext;

extern const AVTextFormatter avtextformatter_default;
extern const AVTextFormatter avtextformatter_json;
extern const AVTextFormatter avtextformatter_xml;
extern const AVTextFormatter avtextformatter_flat;
extern const AVTextFormatter avtextformatter_ini;
extern const AVTextFormatter avtextformatter_csv;

const AVTextFormatter *avtext_get_formatter_by_name(const char *name);

int avtext_context_open(AVTextFormatContext **ptctx, const AVTextFormatter *formatter,
                        AVTextWriterContext *writer, const char *args,
                        const AVTextFormatSection *sections, int nb_sections,
                        AVTextFormatOptions options, const char *hash_str);
int avtext_context_close(AVTextFormatContext **ptctx);

int avtextwriter_create_file(AVTextWriterContext **pwctx, const char *filename);
int avtextwriter_create_avio(AVTextWriterContext **pwctx, AVIOContext *avio, int close_on_uninit);
int avtextwriter_context_close(AVTextWriterContext **pwctx);

void avtext_print_section_header(AVTextFormatContext *tctx, const void *data, int section_id);
void avtext_print_section_footer(AVTextFormatContext *tctx);

// Changed return types to int to match usage in ffprobe.c (checking < 0)
int avtext_print_integer(AVTextFormatContext *tctx, const char *key, int64_t val, int flags);
int avtext_print_string(AVTextFormatContext *tctx, const char *key, const char *val, int flags);
int avtext_print_rational(AVTextFormatContext *tctx, const char *key, AVRational val, char sep);
int avtext_print_time(AVTextFormatContext *tctx, const char *key, int64_t ts, const AVRational *tb, int duration);
int avtext_print_ts(AVTextFormatContext *tctx, const char *key, int64_t ts, int is_duration);
int avtext_print_unit_integer(AVTextFormatContext *tctx, const char *key, int64_t val, const char *unit);
int avtext_print_integers(AVTextFormatContext *tctx, const char *key, const void *data, int count,
                           const char *fmt, int size, int columns, int pad);
int avtext_print_data(AVTextFormatContext *tctx, const char *key, const uint8_t *data, int size);
int avtext_print_data_hash(AVTextFormatContext *tctx, const char *key, const uint8_t *data, int size);

#endif /* FFTOOLS_AVTEXTFORMAT_H */