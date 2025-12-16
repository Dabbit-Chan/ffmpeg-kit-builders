/*
 * This file is part of FFmpeg.
 * Copyright (c) 2025 Akash Patel
 * Copyright (c) 2023 ARTHENICA LTD
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

#ifndef FFTOOLS_FFMPEG_SCHED_H
#define FFTOOLS_FFMPEG_SCHED_H

#include <stddef.h>
#include <stdint.h>

#include "libavcodec/packet.h"
#include "libavutil/frame.h"

typedef struct Scheduler Scheduler;

typedef struct SchedulerNode {
    unsigned idx;
    enum {
        SCH_NODE_TYPE_NONE = 0,
        SCH_NODE_TYPE_DEMUX,
        SCH_NODE_TYPE_MUX,
        SCH_NODE_TYPE_DEC,
        SCH_NODE_TYPE_ENC,
        SCH_NODE_TYPE_FILTER_IN,
        SCH_NODE_TYPE_FILTER_OUT,
    } type;
} SchedulerNode;

#define SCH_DSTREAM(file, stream)   ((SchedulerNode){ .type = SCH_NODE_TYPE_DEMUX,      .idx = (file)   << 16 | (stream) })
#define SCH_MSTREAM(file, stream)   ((SchedulerNode){ .type = SCH_NODE_TYPE_MUX,        .idx = (file)   << 16 | (stream) })
#define SCH_DEC_IN(dec)             ((SchedulerNode){ .type = SCH_NODE_TYPE_DEC,        .idx = (dec)    << 16 | 0 })
#define SCH_DEC_OUT(dec, stream)    ((SchedulerNode){ .type = SCH_NODE_TYPE_DEC,        .idx = (dec)    << 16 | 1 | (stream) << 1 })
#define SCH_ENC(enc)                ((SchedulerNode){ .type = SCH_NODE_TYPE_ENC,        .idx = (enc) })
#define SCH_FILTER_IN(filter, pad)  ((SchedulerNode){ .type = SCH_NODE_TYPE_FILTER_IN,  .idx = (filter) << 16 | (pad) })
#define SCH_FILTER_OUT(filter, pad) ((SchedulerNode){ .type = SCH_NODE_TYPE_FILTER_OUT, .idx = (filter) << 16 | (pad) })

Scheduler *sch_alloc(void);
void       sch_free(Scheduler **sch);

int sch_start(Scheduler *sch);
int sch_stop(Scheduler *sch, int64_t *finish_ts);

/**
 * Wait for the transcoding to progress.
 *
 * @param timeout_us wait at most this many microseconds; -1 to wait indefinitely
 * @param transcode_ts current transcoding timestamp in AV_TIME_BASE_Q
 *                     is written here
 *
 * @return 0 on success, a negative error code on failure (including timeout)
 */
int sch_wait(Scheduler *sch, int64_t timeout_us, int64_t *transcode_ts);

int sch_add_demux(Scheduler *sch, int (*func)(void *), void *ctx);
int sch_add_demux_stream(Scheduler *sch, unsigned demux_idx);

int sch_add_dec(Scheduler *sch, int (*func)(void *), void *ctx);

int sch_add_filtergraph(Scheduler *sch, unsigned nb_inputs, unsigned nb_outputs,
                        int (*func)(void *), void *ctx);

int sch_add_enc(Scheduler *sch, int (*func)(void *), void *ctx, 
               int (*open_cb)(void *, const AVFrame *));

int sch_add_mux(Scheduler *sch, int (*func)(void *), int (*init)(void *),
                void *ctx, int sdp_auto, unsigned thread_queue_size);
int sch_add_mux_stream(Scheduler *sch, unsigned mux_idx);
int sch_mux_stream_buffering(Scheduler *sch, unsigned mux_idx, unsigned stream_idx,
                             int max_packets, int max_size_bytes);
int sch_mux_sub_heartbeat_add(Scheduler *sch, unsigned mux_idx, unsigned stream_idx,
                              unsigned enc_idx);
int sch_mux_sub_heartbeat(Scheduler *sch, unsigned mux_idx, unsigned stream_idx,
                          AVPacket *pkt);

int sch_sdp_filename(Scheduler *sch, const char *filename);

int sch_connect(Scheduler *sch, SchedulerNode src, SchedulerNode dst);

/**
 * Send a frame to a filtergraph input.
 *
 * @param sch the scheduler
 * @param fg_idx index of the filtergraph
 * @param input_idx index of the input
 * @param frame the frame to send, or NULL to signal EOF
 *
 * @return 0 on success, AVERROR(EAGAIN) if the filtergraph is not ready to
 *         receive the frame, AVERROR_EOF if the filtergraph is finished,
 *         a negative error code on failure.
 */
int sch_filter_send(Scheduler *sch, unsigned fg_idx, unsigned input_idx,
                    AVFrame *frame);

/**
 * Receive a frame from a filtergraph output.
 *
 * @param sch the scheduler
 * @param fg_idx index of the filtergraph
 * @param output_idx index of the output (in/out parameter). If *output_idx is
 *                   -1, the function will return the index of the output that
 *                   produced the frame.
 * @param frame the frame to receive
 *
 * @return 0 on success, AVERROR(EAGAIN) if no frame is available,
 *         AVERROR_EOF if the filtergraph is finished, a negative error code
 *         on failure.
 */
int sch_filter_receive(Scheduler *sch, unsigned fg_idx, unsigned *output_idx,
                       AVFrame *frame);

int sch_filter_command(Scheduler *sch, unsigned fg_idx, AVFrame *frame);

void sch_filter_receive_finish(Scheduler *sch, unsigned fg_idx, unsigned output_idx);

int sch_demux_send(Scheduler *sch, unsigned demux_idx, AVPacket *pkt, unsigned flags);

int sch_dec_send(Scheduler *sch, unsigned dec_idx, AVPacket *pkt);
int sch_dec_receive(Scheduler *sch, unsigned dec_idx, AVFrame *frame);

int sch_enc_send(Scheduler *sch, unsigned enc_idx, AVFrame *frame);
int sch_enc_receive(Scheduler *sch, unsigned enc_idx, AVPacket *pkt);

int sch_mux_receive(Scheduler *sch, unsigned mux_idx, AVPacket *pkt);
void sch_mux_receive_finish(Scheduler *sch, unsigned mux_idx, unsigned stream_idx);

int sch_mux_stream_ready(Scheduler *sch, unsigned mux_idx, unsigned stream_idx);

int sch_add_sq_enc(Scheduler *sch, int64_t buf_size_us, void *logctx);
int sch_sq_add_enc(Scheduler *sch, unsigned sq_idx, unsigned enc_idx,
                   int limiting, uint64_t max_frames);

#define DEMUX_SEND_STREAMCOPY_EOF (1 << 0)

#endif /* FFTOOLS_FFMPEG_SCHED_H */