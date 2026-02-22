# TODO

## Tests

### List of Untested APIs

#### **Global Configurations & Settings**

- [x] `ffmpeg_kit_config_enable_redirection`
- [x] `ffmpeg_kit_config_disable_redirection`
- [x] `ffmpeg_kit_config_set_environment_variable`
- [x] `ffmpeg_kit_config_ignore_signal`
- [x] `ffmpeg_kit_config_set_font_directory`
- [x] `ffmpeg_kit_config_set_font_directory_list`
- [x] `ffmpeg_kit_config_log_level_to_string`
- [x] `ffmpeg_kit_config_session_state_to_string`
- [x] `ffmpeg_kit_config_arguments_to_string`

#### **Global Callback Functions**

- [x] `ffmpeg_kit_config_enable_statistics_callback`
- [x] `ffmpeg_kit_config_enable_ffmpeg_session_complete_callback`
- [x] `ffmpeg_kit_config_enable_ffprobe_session_complete_callback`
- [x] `ffmpeg_kit_config_enable_ffplay_session_complete_callback`
- [x] `ffmpeg_kit_config_enable_media_information_session_complete_callback`

#### **FFplay Utilities**

- [x] `ffplay_kit_session_start`
- [x] `ffplay_kit_session_stop`
- [x] `ffplay_kit_session_close`
- [x] `ffplay_kit_session_set_position`
- [x] `ffplay_kit_session_get_duration`
- [x] `ffplay_kit_session_set_volume`
- [x] `ffplay_kit_session_get_volume`
- [x] `ffplay_kit_seek`
- [x] `ffplay_kit_start`
- [x] `ffplay_kit_close`

#### **FFprobe / Media Information Extensions**

- [x] `media_information_create_session`
- [x] `media_information_session_execute`
- [x] `media_information_session_execute_async`
- [x] `media_information_get_filename`
- [x] `media_information_get_duration`
- [x] `media_information_get_bitrate`
- [x] `media_information_get_size`
- [x] `media_information_get_streams_count`
- [x] `media_information_get_chapters_count`
- [x] `media_information_get_all_properties_json`
- [x] `media_information_get_stream_at`
- [x] `media_information_get_chapter_at`

#### **Stream & Chapter Getters**

- [x] `stream_information_get_index`
- [x] `stream_information_get_type`
- [x] `stream_information_get_codec`
- [x] `stream_information_get_codec_long`
- [x] `stream_information_get_format`
- [x] `stream_information_get_width`
- [x] `stream_information_get_height`
- [x] `stream_information_get_bitrate`
- [x] `stream_information_get_sample_rate`
- [x] `stream_information_get_sample_format`
- [x] `stream_information_get_display_aspect_ratio`
- [x] `stream_information_get_average_frame_rate`
- [x] `stream_information_get_real_frame_rate`
- [x] `stream_information_get_time_base`
- [x] `stream_information_get_tags_json`
- [x] `stream_information_get_channel_layout`
- [x] `stream_information_get_sample_aspect_ratio`
- [x] `stream_information_get_codec_time_base`
- [x] `stream_information_get_string_property`
- [x] `stream_information_get_number_property`
- [x] `stream_information_get_all_properties_json`
- [x] `chapter_get_start_time` (need to generate file with chapter info to test)
- [x] `chapter_get_end_time` (need to generate file with chapter info to test)

#### **Misc Session State Management**

- [x] `ffmpeg_kit_list_sessions`
- [x] `ffprobe_kit_list_sessions`
- [x] `media_information_kit_list_sessions`
- [x] `ffmpeg_kit_get_last_session`
- [x] `ffmpeg_kit_get_last_completed_session`
- [x] `ffprobe_kit_get_last_session`
- [x] `ffprobe_kit_get_last_completed_session`
- [x] `ffmpeg_kit_get_last_ffplay_session`
- [x] `ffmpeg_kit_session_get_start_time`
- [x] `ffmpeg_kit_session_get_end_time`
- [x] `ffmpeg_kit_session_get_statistics_count`
- [x] `ffmpeg_kit_session_get_statistics_at`

#### **Statistics Getters**

- [x] `ffmpeg_kit_statistics_get_video_frame_number`
- [x] `ffmpeg_kit_statistics_get_video_fps`
- [x] `ffmpeg_kit_statistics_get_video_quality`
- [x] `ffmpeg_kit_statistics_get_size`
- [x] `ffmpeg_kit_statistics_get_time`
- [x] `ffmpeg_kit_statistics_get_bitrate`
- [x] `ffmpeg_kit_statistics_get_speed`

## FFplay

- [ ] Make SDL output embeddable into any application, but most importantly Flutter.

## Platform support

- [ ] Add Android support
- [ ] Add iOS support
- [ ] Add macOS support
