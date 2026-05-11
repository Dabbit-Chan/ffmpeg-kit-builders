#ifndef FFMPEG_KIT_SESSION_CONTEXT_H
#define FFMPEG_KIT_SESSION_CONTEXT_H

#ifdef __cplusplus
extern "C" {
#endif

void ffmpegkit_bind_session_id(long session_id);
void ffmpegkit_unbind_session_id(void);

#ifdef __cplusplus
}
#endif

#endif // FFMPEG_KIT_SESSION_CONTEXT_H
