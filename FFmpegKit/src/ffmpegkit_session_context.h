#ifndef FFMPEG_KIT_SESSION_CONTEXT_H
#define FFMPEG_KIT_SESSION_CONTEXT_H

#ifdef __cplusplus
extern "C" {
#endif

void ffmpegkit_bind_session_id(long session_id);
void ffmpegkit_unbind_session_id(void);
void ffmpegkit_register_root_context(const void *root, long session_id);
void ffmpegkit_unregister_root_context(const void *root);

#ifdef __cplusplus
}
#endif

#endif // FFMPEG_KIT_SESSION_CONTEXT_H
