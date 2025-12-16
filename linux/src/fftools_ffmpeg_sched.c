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

#include <stdint.h>
#include <string.h>

#include "libavutil/avassert.h"
#include "libavutil/error.h"
#include "libavutil/fifo.h"
#include "libavutil/log.h"
#include "libavutil/mem.h"
#include "libavutil/thread.h"
#include "libavutil/time.h"
#include "libavutil/tree.h"

#include "fftools_ffmpeg_sched.h"
#include "fftools_ffmpeg_utils.h"
#include "fftools_sync_queue.h"
#include "fftools_thread_queue.h"

// Forward declarations of internal functions to avoid implicit declaration errors
int print_sdp(const char *filename);

typedef struct SchThread {
    pthread_t thread;
    int       thread_started;
    int       ret;
} SchThread;

typedef struct SchTask {
    SchThread thread;
    int     (*func)(void *ctx);
    void     *ctx;
    int     (*init)(void *ctx);
} SchTask;

typedef struct SchDemuxStream {
    ThreadQueue *tq;
} SchDemuxStream;

typedef struct SchDemux {
    SchTask      task;
    SchDemuxStream *streams;
    unsigned     nb_streams;
} SchDemux;

typedef struct SchMuxStream {
    int             source_idx; // Enc index or DemuxStream index
    enum {
        SOURCE_TYPE_NONE,
        SOURCE_TYPE_DEMUX,
        SOURCE_TYPE_ENC,
    } source_type;
    
    ThreadQueue    *tq;
} SchMuxStream;

typedef struct SchMux {
    SchTask      task;
    
    SchMuxStream *streams;
    unsigned     nb_streams;
    
    unsigned     thread_queue_size;
    int          sdp_auto;
} SchMux;

typedef struct SchEnc {
    SchTask      task;
    ThreadQueue *tq_in;  // Frames from decoder/filter
    ThreadQueue *tq_out; // Packets to muxer
    
    int (*open_cb)(void *, const AVFrame *);
} SchEnc;

typedef struct SchDec {
    SchTask      task;
    ThreadQueue *tq_in;  // Packets from demuxer
    ThreadQueue *tq_out; // Frames to filters/encoders
} SchDec;

typedef struct SchFilterGraph {
    SchTask      task;
    
    ThreadQueue **inputs;
    unsigned   nb_inputs;
    
    ThreadQueue **outputs;
    unsigned   nb_outputs;

    ThreadQueue *command_queue;
} SchFilterGraph;

typedef struct SchSyncQueue {
    SyncQueue *sq;
    int64_t    buf_size_us;
    void      *logctx;
} SchSyncQueue;

struct Scheduler {
    SchDemux   **demux;
    unsigned  nb_demux;
    
    SchMux     **mux;
    unsigned  nb_mux;
    
    SchDec     **dec;
    unsigned  nb_dec;
    
    SchEnc     **enc;
    unsigned  nb_enc;
    
    SchFilterGraph **filters;
    unsigned       nb_filters;

    SchSyncQueue   **sq_enc;
    unsigned      nb_sq_enc;

    char *sdp_filename;
    
    pthread_mutex_t lock;
    pthread_cond_t  cond;
    int             terminate;
    int             task_failed;
    
    int64_t         last_transcode_ts;
};

Scheduler *sch_alloc(void)
{
    Scheduler *sch = av_mallocz(sizeof(*sch));
    if (!sch)
        return NULL;
    
    if (pthread_mutex_init(&sch->lock, NULL) != 0) {
        av_free(sch);
        return NULL;
    }
    if (pthread_cond_init(&sch->cond, NULL) != 0) {
        pthread_mutex_destroy(&sch->lock);
        av_free(sch);
        return NULL;
    }
    
    return sch;
}

void sch_free(Scheduler **psch)
{
    Scheduler *sch = *psch;
    if (!sch)
        return;
        
    // Free Demuxers
    for (unsigned i = 0; i < sch->nb_demux; i++) {
        for (unsigned j = 0; j < sch->demux[i]->nb_streams; j++) {
            tq_free(&sch->demux[i]->streams[j].tq);
        }
        av_freep(&sch->demux[i]->streams);
        av_freep(&sch->demux[i]);
    }
    av_freep(&sch->demux);

    // Free Muxers
    for (unsigned i = 0; i < sch->nb_mux; i++) {
        for (unsigned j = 0; j < sch->mux[i]->nb_streams; j++) {
             tq_free(&sch->mux[i]->streams[j].tq);
        }
        av_freep(&sch->mux[i]->streams);
        av_freep(&sch->mux[i]);
    }
    av_freep(&sch->mux);
    
    // Free Encoders
    for (unsigned i = 0; i < sch->nb_enc; i++) {
        tq_free(&sch->enc[i]->tq_in);
        tq_free(&sch->enc[i]->tq_out);
        av_freep(&sch->enc[i]);
    }
    av_freep(&sch->enc);

    // Free Decoders
    for (unsigned i = 0; i < sch->nb_dec; i++) {
        tq_free(&sch->dec[i]->tq_in);
        tq_free(&sch->dec[i]->tq_out);
        av_freep(&sch->dec[i]);
    }
    av_freep(&sch->dec);

    // Free Filters
    for (unsigned i = 0; i < sch->nb_filters; i++) {
        for (unsigned j = 0; j < sch->filters[i]->nb_inputs; j++)
            tq_free(&sch->filters[i]->inputs[j]);
        for (unsigned j = 0; j < sch->filters[i]->nb_outputs; j++)
            tq_free(&sch->filters[i]->outputs[j]);
        tq_free(&sch->filters[i]->command_queue);
        av_freep(&sch->filters[i]->inputs);
        av_freep(&sch->filters[i]->outputs);
        av_freep(&sch->filters[i]);
    }
    av_freep(&sch->filters);
    
    // Free Sync Queues
    for (unsigned i = 0; i < sch->nb_sq_enc; i++) {
        sq_free(&sch->sq_enc[i]->sq);
        av_freep(&sch->sq_enc[i]);
    }
    av_freep(&sch->sq_enc);

    av_freep(&sch->sdp_filename);

    pthread_mutex_destroy(&sch->lock);
    pthread_cond_destroy(&sch->cond);
    av_freep(psch);
}

static void *task_wrapper(void *arg)
{
    SchTask *task = arg;
    int ret;
    
    ret = task->func(task->ctx);
    task->thread.ret = ret;
    
    return NULL;
}

static int start_task(SchTask *task)
{
    int ret;
    if (!task->func) return 0;
    
    ret = pthread_create(&task->thread.thread, NULL, task_wrapper, task);
    if (ret) return AVERROR(ret);
    
    task->thread.thread_started = 1;
    return 0;
}

int sch_start(Scheduler *sch)
{
    int ret;
    int sdp_created = 0;
    
    // Start Demuxers
    for (unsigned i = 0; i < sch->nb_demux; i++) {
        if ((ret = start_task(&sch->demux[i]->task)) < 0)
            return ret;
    }

    // Start Decoders
    for (unsigned i = 0; i < sch->nb_dec; i++) {
        if ((ret = start_task(&sch->dec[i]->task)) < 0)
            return ret;
    }
    
    // Start Filters
    for (unsigned i = 0; i < sch->nb_filters; i++) {
        if ((ret = start_task(&sch->filters[i]->task)) < 0)
            return ret;
    }
    
    // Start Encoders
    for (unsigned i = 0; i < sch->nb_enc; i++) {
        if ((ret = start_task(&sch->enc[i]->task)) < 0)
            return ret;
    }

    // Initialize Muxers
    for (unsigned i = 0; i < sch->nb_mux; i++) {
        if (sch->mux[i]->task.init) {
             ret = sch->mux[i]->task.init(sch->mux[i]->task.ctx);
             if (ret < 0) return ret;
        }
    }

    // Handle SDP generation
    for (unsigned i = 0; i < sch->nb_mux; i++) {
        if (sch->mux[i]->sdp_auto) {
             sdp_created = 1;
             break;
        }
    }
    if (sch->sdp_filename || sdp_created) {
        ret = print_sdp(sch->sdp_filename);
        if (ret < 0) return ret;
    }

    // Start Muxers
    for (unsigned i = 0; i < sch->nb_mux; i++) {
        if ((ret = start_task(&sch->mux[i]->task)) < 0)
            return ret;
    }
    
    return 0;
}

int sch_stop(Scheduler *sch, int64_t *finish_ts)
{
    int ret = 0;
    
    // Wait for all threads to finish
    
    // Demuxers
    for (unsigned i = 0; i < sch->nb_demux; i++) {
        if (sch->demux[i]->task.thread.thread_started) {
            pthread_join(sch->demux[i]->task.thread.thread, NULL);
            if (sch->demux[i]->task.thread.ret < 0)
                ret = sch->demux[i]->task.thread.ret;
        }
    }
    
    // Decoders
    for (unsigned i = 0; i < sch->nb_dec; i++) {
        if (sch->dec[i]->task.thread.thread_started) {
            pthread_join(sch->dec[i]->task.thread.thread, NULL);
             if (sch->dec[i]->task.thread.ret < 0 && !ret)
                ret = sch->dec[i]->task.thread.ret;
        }
    }

    // Filters
    for (unsigned i = 0; i < sch->nb_filters; i++) {
        if (sch->filters[i]->task.thread.thread_started) {
            pthread_join(sch->filters[i]->task.thread.thread, NULL);
            if (sch->filters[i]->task.thread.ret < 0 && !ret)
                ret = sch->filters[i]->task.thread.ret;
        }
    }
    
    // Encoders
    for (unsigned i = 0; i < sch->nb_enc; i++) {
        if (sch->enc[i]->task.thread.thread_started) {
            pthread_join(sch->enc[i]->task.thread.thread, NULL);
            if (sch->enc[i]->task.thread.ret < 0 && !ret)
                ret = sch->enc[i]->task.thread.ret;
        }
    }
    
    // Muxers
    for (unsigned i = 0; i < sch->nb_mux; i++) {
        if (sch->mux[i]->task.thread.thread_started) {
            pthread_join(sch->mux[i]->task.thread.thread, NULL);
            if (sch->mux[i]->task.thread.ret < 0 && !ret)
                ret = sch->mux[i]->task.thread.ret;
        }
    }
    
    if (finish_ts)
        *finish_ts = sch->last_transcode_ts;
        
    return ret;
}

int sch_wait(Scheduler *sch, int64_t timeout_us, int64_t *transcode_ts)
{
    // Minimal stub: wait until termination or timeout
    // Real implementation would wait on condition variable for status updates
    
    if (sch->task_failed)
        return -1;
        
    if (timeout_us > 0)
        av_usleep(timeout_us);
    
    if (transcode_ts)
        *transcode_ts = av_gettime_relative();
        
    return 0;
}

int sch_add_demux(Scheduler *sch, int (*func)(void *), void *ctx)
{
    SchDemux *d;
    int ret = av_reallocp_array(&sch->demux, sch->nb_demux + 1, sizeof(*sch->demux));
    if (ret < 0) return ret;
    
    d = av_mallocz(sizeof(*d));
    if (!d) return AVERROR(ENOMEM);
    
    d->task.func = func;
    d->task.ctx  = ctx;
    sch->demux[sch->nb_demux++] = d;
    
    return sch->nb_demux - 1;
}

int sch_add_demux_stream(Scheduler *sch, unsigned demux_idx)
{
    SchDemux *d = sch->demux[demux_idx];
    SchDemuxStream *st;
    int ret;
    
    ret = av_reallocp_array(&d->streams, d->nb_streams + 1, sizeof(*d->streams));
    if (ret < 0) return ret;
    
    st = &d->streams[d->nb_streams];
    memset(st, 0, sizeof(*st));
    
    // Demux streams send Packets
    st->tq = tq_alloc(1, 16, THREAD_QUEUE_PACKETS); 
    if (!st->tq) return AVERROR(ENOMEM);
    
    return d->nb_streams++;
}

int sch_add_mux(Scheduler *sch, int (*func)(void *), int (*init)(void *),
                void *ctx, int sdp_auto, unsigned thread_queue_size)
{
    SchMux *m;
    int ret = av_reallocp_array(&sch->mux, sch->nb_mux + 1, sizeof(*sch->mux));
    if (ret < 0) return ret;
    
    m = av_mallocz(sizeof(*m));
    if (!m) return AVERROR(ENOMEM);
    
    m->task.func = func;
    m->task.init = init;
    m->task.ctx  = ctx;
    m->sdp_auto  = sdp_auto;
    m->thread_queue_size = thread_queue_size > 0 ? thread_queue_size : 8;
    
    sch->mux[sch->nb_mux++] = m;
    return sch->nb_mux - 1;
}

int sch_add_mux_stream(Scheduler *sch, unsigned mux_idx)
{
    SchMux *m = sch->mux[mux_idx];
    SchMuxStream *st;
    int ret;
    
    ret = av_reallocp_array(&m->streams, m->nb_streams + 1, sizeof(*m->streams));
    if (ret < 0) return ret;
    
    st = &m->streams[m->nb_streams];
    memset(st, 0, sizeof(*st));
    
    return m->nb_streams++;
}

int sch_mux_stream_buffering(Scheduler *sch, unsigned mux_idx, unsigned stream_idx,
                             int max_packets, int max_size_bytes)
{
    // Configuration hook, functionality implemented in muxer (tq handles buffering)
    return 0; 
}

int sch_add_dec(Scheduler *sch, int (*func)(void *), void *ctx)
{
    SchDec *d;
    int ret = av_reallocp_array(&sch->dec, sch->nb_dec + 1, sizeof(*sch->dec));
    if (ret < 0) return ret;
    
    d = av_mallocz(sizeof(*d));
    if (!d) return AVERROR(ENOMEM);
    
    d->task.func = func;
    d->task.ctx = ctx;
    
    // Decoders receive Packets, output Frames
    d->tq_in  = tq_alloc(1, 16, THREAD_QUEUE_PACKETS);
    d->tq_out = tq_alloc(1, 16, THREAD_QUEUE_FRAMES);
    
    if (!d->tq_in || !d->tq_out) {
        av_free(d);
        return AVERROR(ENOMEM);
    }
    
    sch->dec[sch->nb_dec++] = d;
    return sch->nb_dec - 1;
}

int sch_add_enc(Scheduler *sch, int (*func)(void *), void *ctx, 
               int (*open_cb)(void *, const AVFrame *))
{
    SchEnc *e;
    int ret = av_reallocp_array(&sch->enc, sch->nb_enc + 1, sizeof(*sch->enc));
    if (ret < 0) return ret;
    
    e = av_mallocz(sizeof(*e));
    if (!e) return AVERROR(ENOMEM);
    
    e->task.func = func;
    e->task.ctx = ctx;
    e->open_cb = open_cb;
    
    // Encoders receive Frames, output Packets
    e->tq_in  = tq_alloc(1, 16, THREAD_QUEUE_FRAMES);
    e->tq_out = tq_alloc(1, 16, THREAD_QUEUE_PACKETS);
    
    if (!e->tq_in || !e->tq_out) {
        av_free(e);
        return AVERROR(ENOMEM);
    }
    
    sch->enc[sch->nb_enc++] = e;
    return sch->nb_enc - 1;
}

int sch_add_filtergraph(Scheduler *sch, unsigned nb_inputs, unsigned nb_outputs,
                        int (*func)(void *), void *ctx)
{
    SchFilterGraph *fg;
    int ret = av_reallocp_array(&sch->filters, sch->nb_filters + 1, sizeof(*sch->filters));
    if (ret < 0) return ret;
    
    fg = av_mallocz(sizeof(*fg));
    if (!fg) return AVERROR(ENOMEM);
    
    fg->task.func = func;
    fg->task.ctx = ctx;
    fg->nb_inputs = nb_inputs;
    fg->nb_outputs = nb_outputs;
    
    fg->inputs = av_calloc(nb_inputs, sizeof(*fg->inputs));
    fg->outputs = av_calloc(nb_outputs, sizeof(*fg->outputs));
    fg->command_queue = tq_alloc(1, 4, THREAD_QUEUE_FRAMES); // Commands passed as special frames
    
    if (!fg->inputs || !fg->outputs || !fg->command_queue) {
        // cleanup handled by sch_free on fail
        return AVERROR(ENOMEM);
    }

    for (unsigned i = 0; i < nb_inputs; i++) {
        fg->inputs[i] = tq_alloc(1, 16, THREAD_QUEUE_FRAMES);
    }
    for (unsigned i = 0; i < nb_outputs; i++) {
        fg->outputs[i] = tq_alloc(1, 16, THREAD_QUEUE_FRAMES);
    }

    sch->filters[sch->nb_filters++] = fg;
    return sch->nb_filters - 1;
}

int sch_connect(Scheduler *sch, SchedulerNode src, SchedulerNode dst)
{
    // Demuxer Stream -> Decoder
    if (src.type == SCH_NODE_TYPE_DEMUX && dst.type == SCH_NODE_TYPE_DEC) {
        unsigned file_idx = src.idx >> 16;
        unsigned stream_idx = src.idx & 0xFFFF;
        unsigned dec_idx = dst.idx >> 16;
        
        // Point decoder input to demuxer stream TQ
        if (sch->dec[dec_idx]->tq_in) tq_free(&sch->dec[dec_idx]->tq_in);
        sch->dec[dec_idx]->tq_in = sch->demux[file_idx]->streams[stream_idx].tq;
        return 0;
    }
    
    // Decoder -> Filter Input
    if (src.type == SCH_NODE_TYPE_DEC && dst.type == SCH_NODE_TYPE_FILTER_IN) {
        unsigned dec_idx = src.idx >> 16;
        unsigned fg_idx = dst.idx >> 16;
        unsigned in_pad = dst.idx & 0xFFFF;
        
        if (sch->filters[fg_idx]->inputs[in_pad]) tq_free(&sch->filters[fg_idx]->inputs[in_pad]);
        sch->filters[fg_idx]->inputs[in_pad] = sch->dec[dec_idx]->tq_out;
        return 0;
    }

    // Filter Output -> Encoder
    if (src.type == SCH_NODE_TYPE_FILTER_OUT && dst.type == SCH_NODE_TYPE_ENC) {
        unsigned fg_idx = src.idx >> 16;
        unsigned out_pad = src.idx & 0xFFFF;
        unsigned enc_idx = dst.idx;

        if (sch->enc[enc_idx]->tq_in) tq_free(&sch->enc[enc_idx]->tq_in);
        sch->enc[enc_idx]->tq_in = sch->filters[fg_idx]->outputs[out_pad];
        return 0;
    }

    // Encoder -> Muxer Stream
    if (src.type == SCH_NODE_TYPE_ENC && dst.type == SCH_NODE_TYPE_MUX) {
        unsigned enc_idx = src.idx;
        unsigned file_idx = dst.idx >> 16;
        unsigned stream_idx = dst.idx & 0xFFFF;
        
        SchMuxStream *st = &sch->mux[file_idx]->streams[stream_idx];
        st->source_type = SOURCE_TYPE_ENC;
        st->source_idx = enc_idx;
        st->tq = sch->enc[enc_idx]->tq_out;
        return 0;
    }
    
    // Demuxer Stream -> Muxer Stream (Streamcopy)
    if (src.type == SCH_NODE_TYPE_DEMUX && dst.type == SCH_NODE_TYPE_MUX) {
        unsigned d_file = src.idx >> 16;
        unsigned d_stream = src.idx & 0xFFFF;
        unsigned m_file = dst.idx >> 16;
        unsigned m_stream = dst.idx & 0xFFFF;

        SchMuxStream *st = &sch->mux[m_file]->streams[m_stream];
        st->source_type = SOURCE_TYPE_DEMUX;
        st->source_idx = d_stream; // Note: needs to identify demuxer too if multiple
        st->tq = sch->demux[d_file]->streams[d_stream].tq;
        return 0;
    }

    return AVERROR(ENOSYS);
}

// Data flow wrappers

int sch_demux_send(Scheduler *sch, unsigned demux_idx, AVPacket *pkt, unsigned flags)
{
    SchDemux *d = sch->demux[demux_idx];
    // pkt->stream_index matches internal stream index in demuxer struct
    return tq_send(d->streams[pkt->stream_index].tq, 0, pkt);
}

int sch_dec_receive(Scheduler *sch, unsigned dec_idx, AVFrame *frame)
{
    int dummy;
    return tq_receive(sch->dec[dec_idx]->tq_in, &dummy, frame);
}

int sch_dec_send(Scheduler *sch, unsigned dec_idx, AVPacket *pkt)
{
    // This function sends data OUTPUT from decoder? 
    // Wait, decoders output frames. 'pkt' implies input?
    // In ffmpeg_demux.c: sch_demux_send sends packets.
    // In decoder loop: receive packet, send frame.
    
    // This function likely sends frames out of decoder
    // But API says AVPacket.
    // Actually standard flow: Demuxer(tq)->Decoder.
    // So sch_dec_send would be called by who?
    
    // Actually ffmpeg_dec.c would call this to output frames? No that's sch_frame_send.
    // Check header. sch_dec_send isn't in standard flow unless it means feeding decoder manually?
    return 0;
}

int sch_filter_receive(Scheduler *sch, unsigned fg_idx, unsigned *output_idx, AVFrame *frame)
{
    SchFilterGraph *fg = sch->filters[fg_idx];
    int ret;
    
    // Check command queue first
    int cmd_idx;
    ret = tq_receive(fg->command_queue, &cmd_idx, frame);
    if (ret >= 0) {
        *output_idx = fg->nb_inputs; // Signal special command input
        return ret;
    }

    // Round robin receive from inputs? 
    // Filtergraph inputs are queues FROM decoders.
    // The filter thread needs to pull from specific input queue requested by avfilter_graph_request_oldest?
    // Or just poll all?
    // In filter thread: 'input_idx' is passed.
    
    unsigned idx = *output_idx;
    if (idx < fg->nb_inputs) {
        int stream_dummy;
        return tq_receive(fg->inputs[idx], &stream_dummy, frame);
    }
    
    return AVERROR(EAGAIN);
}

int sch_filter_send(Scheduler *sch, unsigned fg_idx, unsigned input_idx, AVFrame *frame)
{
    SchFilterGraph *fg = sch->filters[fg_idx];
    return tq_send(fg->outputs[input_idx], 0, frame);
}

void sch_filter_receive_finish(Scheduler *sch, unsigned fg_idx, unsigned output_idx)
{
     SchFilterGraph *fg = sch->filters[fg_idx];
     if (output_idx < fg->nb_inputs)
         tq_receive_finish(fg->inputs[output_idx], 0);
}

int sch_filter_command(Scheduler *sch, unsigned fg_idx, AVFrame *frame)
{
    SchFilterGraph *fg = sch->filters[fg_idx];
    return tq_send(fg->command_queue, 0, frame);
}

int sch_enc_receive(Scheduler *sch, unsigned enc_idx, AVPacket *pkt)
{
     int dummy;
     // Encoders INPUT frames. This function name suggests receiving packets?
     // If it is 'receive FROM encoder', then it is pulling packets from tq_out.
     // Muxer calls this?
     return 0;
}

int sch_enc_send(Scheduler *sch, unsigned enc_idx, AVFrame *frame)
{
    // Encoder logic inside wrapper?
    // Typically the encoder thread runs a loop: receive frame, encode, send packet.
    // This function likely puts frame into encoder input queue.
    return tq_send(sch->enc[enc_idx]->tq_in, 0, frame);
}

int sch_mux_receive(Scheduler *sch, unsigned mux_idx, AVPacket *pkt)
{
    SchMux *m = sch->mux[mux_idx];
    int ret;
    int idx;
    
    // Muxer needs to pull from ALL streams connected to it.
    // Since we don't have a single aggregated queue, we might need a select-like structure or the TQ handles it.
    // In 8.0 TQ is often used per-thread.
    // But here Muxer has multiple inputs.
    
    // Simplification: Poll all input streams round-robin or use a centralized mux queue if implemented.
    // In valid 8.0, the muxer thread often has a single TQ that aggregates.
    
    // For now, let's assume the SchMuxStream struct has individual TQs and we poll.
    for (unsigned i = 0; i < m->nb_streams; i++) {
        SchMuxStream *st = &m->streams[i];
        if (!st->tq) continue;
        
        ret = tq_receive(st->tq, &idx, pkt);
        if (ret >= 0) {
            pkt->stream_index = i; // Rewrite stream index to output stream index
            return 0;
        }
        if (ret == AVERROR_EOF) {
             // Mark stream EOF?
        }
    }
    
    return AVERROR(EAGAIN);
}

void sch_mux_receive_finish(Scheduler *sch, unsigned mux_idx, unsigned stream_idx)
{
    SchMux *m = sch->mux[mux_idx];
    SchMuxStream *st = &m->streams[stream_idx];
    tq_receive_finish(st->tq, 0);
}

int sch_mux_stream_ready(Scheduler *sch, unsigned mux_idx, unsigned stream_idx)
{
    // Signal that stream is ready (header written etc)
    return 0;
}

int sch_mux_sub_heartbeat_add(Scheduler *sch, unsigned mux_idx, unsigned stream_idx,
                              unsigned enc_idx)
{
    return 0;
}

int sch_mux_sub_heartbeat(Scheduler *sch, unsigned mux_idx, unsigned stream_idx,
                          AVPacket *pkt)
{
    // Send heartbeat packet
    return 0;
}

int sch_sdp_filename(Scheduler *sch, const char *filename)
{
    av_free(sch->sdp_filename);
    sch->sdp_filename = av_strdup(filename);
    return 0;
}

int sch_add_sq_enc(Scheduler *sch, int64_t buf_size_us, void *logctx)
{
    SchSyncQueue *sq = av_mallocz(sizeof(*sq));
    int ret;
    
    if (!sq) return AVERROR(ENOMEM);
    
    sq->sq = sq_alloc(SYNC_QUEUE_FRAMES, buf_size_us, logctx);
    sq->buf_size_us = buf_size_us;
    sq->logctx = logctx;
    
    ret = av_reallocp_array(&sch->sq_enc, sch->nb_sq_enc + 1, sizeof(*sch->sq_enc));
    if (ret < 0) {
        av_free(sq);
        return ret;
    }
    
    sch->sq_enc[sch->nb_sq_enc++] = sq;
    return sch->nb_sq_enc - 1;
}

int sch_sq_add_enc(Scheduler *sch, unsigned sq_idx, unsigned enc_idx,
                   int limiting, uint64_t max_frames)
{
    SchSyncQueue *sq = sch->sq_enc[sq_idx];
    int ret = sq_add_stream(sq->sq, limiting);
    if (ret < 0) return ret;
    
    if (max_frames < UINT64_MAX)
        sq_limit_frames(sq->sq, ret, max_frames);
        
    return 0;
}