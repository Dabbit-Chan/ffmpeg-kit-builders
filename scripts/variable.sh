#!/bin/bash

#shellcheck disable=SC2317,SC1091,SC2120,SC2034

# DIRECTORY DEFINITIONS
export FFMPEG_KIT_TMPDIR="${BASEDIR}/.tmp"

export MINGW_W64_BRANCH="master"
export BINUTILS_BRANCH="binutils-2_44-branch"
export GCC_BRANCH="releases/gcc-14"
export LOG_FILE="${BASEDIR}"/build.log

export sandbox="prebuilt"
export WORKDIR="$BASEDIR/$sandbox"
export SCRIPTDIR="$BASEDIR/scripts"

# variables with their defaults
export build_force="0"
export build_ffmpeg_static=n
export build_ffmpeg_shared=y
export build_ffmpeg_kit_only=n
export build_dvbtee=n
export build_libmxf=n
export build_mp4box=n
export build_mplayer=n
export build_vlc=n
export build_lsw=n # To build x264 with L-Smash-Works.
export build_dependencies=y
export git_get_latest=y
export prefer_stable=y # Only for x264 and x265.
export build_amd_amf=y
export ffmpeg_git_checkout_version="release/8.0"
export build_ismindex=n
export enable_gpl=y
export original_cflags="$CFLAGS"
export build_x264_with_libav=n # To build x264 with Libavformat.
export ffmpeg_git_checkout="https://github.com/FFmpeg/FFmpeg.git"
export cpu_count=$(nproc)
export original_cpu_count=$(nproc) # save it away for some that revert it temporarily
export PKG_CONFIG_LIBDIR= # disable pkg-config from finding [and using] normal linux system installed libs [yikes]
export original_path=$PATH

export BUILD_STEPS=(
"platform_deps" \
"build_libxavs" \
"build_libdavs2" \
"build_libxavs2" \
"build_zlib" \
"build_libcaca" \
"build_bzlib" \
"build_lzma" \
"build_iconv" \
"build_sdl2" \
"build_amf" \
"build_libvpl" \
"build_nvenc" \
"build_cuvid" \
"build_libzimg" \
"build_libopenjpeg" \
"build_opengl" \
"build_libpng" \
"build_libwebp" \
"build_libxml2" \
"build_brotli" \
"build_libfreetype" \
"build_libharfbuzz" \
"build_libvmaf" \
"build_libfontconfig" \
"build_gmp" \
"build_libnettle" \
"build_zstd" \
"build_openssl" \
"build_gnutls" \
"build_curl" \
"build_libogg" \
"build_libvorbis" \
"build_libopus" \
"build_libspeexdsp" \
"build_libspeex" \
"build_libtheora" \
"build_libgsm" \
"build_mpg123" \
"build_libmp3lame" \
"build_libtwolame" \
"build_libopenmpt" \
"build_libopencore_amrnb" \
"build_libvo_amrwbenc" \
"build_libilbc" \
"build_libmodplug" \
"build_libgme" \
"build_libbluray" \
"build_libbs2b" \
"build_libsoxr" \
"build_libflite" \
"build_libsnappy" \
"build_fftw" \
"build_chromaprint" \
"build_librubberband" \
"build_frei0r" \
"build_svt_hevc" \
"build_svt_vp9" \
"build_libsvtav1" \
"build_libvidstab" \
"build_libmysofa" \
"build_decklink" \
"build_libzvbi" \
"build_libfribidi" \
"build_libass" \
"build_libxvid" \
"build_libsrt" \
"build_libaribcaption" \
"build_libaribb24" \
"build_libtesseract" \
"build_liblensfun" \
"build_libtensorflow" \
"build_libvpx" \
"build_libx265" \
"build_libopenh264" \
"build_libaom" \
"build_libdav1d" \
"build_vulkan" \
"build_libplacebo" \
"build_libshaderc" \
"build_avisynth" \
"build_libvvenc" \
"build_libvvdec" \
"build_libx264" \
"build_libjsoncpp" \
"build_libcodec2" \
"build_libjxl" \
"build_libkvazaar" \
"build_libxeve" \
"build_libxevd" \
"build_ladspa" \
"build_libfdk_aac" \
"build_libshine" \
"build_openal" \
"build_pocketsphinx" \
"build_whisper" \
"build_lcms2" \
"build_liblc3" \
"build_liblcevc_dec" \
"build_liboapv" \
"build_libqrencode" \
"build_libuavs3d" \
"build_vapoursynth" \
"build_libquirc" \
"build_librsvg" \
"build_libopencv" \
"build_librav1e" \
"build_gcrypt" \
"build_librist" \
"build_lv2" \
"build_libcdio" \
"build_libpulse" \
"build_librtmp" \
"build_librabbitmq" \
"build_libssh" \
"build_libtls" \
"build_libzmq" \
"build_mbedtls" \
"build_opencl" \
"build_libglslang" \
"build_libklvanc" \
"build_vulkan_static" \
"build_libnpp" \
"build_cuda_nvcc" \
"build_libjack" \
"build_alsa" \
"build_libdc1394" \
"build_libdrm" \
"build_libiec61883" \
"build_libv4l2" \
"build_libxcb" \
"build_libxcb_shape" \
"build_libxcb_shm" \
"build_libxcb_xfixes" \
"build_rkmpp" \
"build_vaapi" \
"build_xlib" \
"build_libmfx" \
"build_omx" \
"build_sndio" \
"build_libdvdnav" \
"build_libdvdread" \
"build_libopenvino" \
"build_libsmbclient" \
"build_jni" \
"build_mediacodec" \
"build_ohcodec" \
"build_v4l2_m2m" \
"build_libopencore_amrwb" \
"build_libcelt" \
"build_libtorch" \
"build_cuda_llvm" \
"build_ffnvcodec" \
"build_nvdec" \
"build_vdpau" \
"build_mmal" \
"build_omx_rpi" \
"build_d3d11va" \
"build_d3d12va" \
"build_dxva2" \
"build_schannel" \
"build_mediafoundation" \
"build_avfoundation" \
"build_appkit" \
"build_audiotoolbox" \
"build_coreimage" \
"build_metal" \
"build_securetransport" \
"build_videotoolbox")


#------------------------------------------------------------------------------     
# ----------------------------- android features ------------------------------     
#------------------------------------------------------------------------------      
# build_jni               # config_options+= --disable-jni                # enable JNI support [no]
# build_ladspa            # config_options+= --disable-ladspa             # enable LADSPA audio filtering [no]
# build_mediacodec        # config_options+= --disable-mediacodec         # enable Android MediaCodec support [no]
#------------------------------------------------------------------------------    
# ----------------------------- harmony features ------------------------------     
#------------------------------------------------------------------------------    
# build_ohcodec           # config_options+= --disable-ohcodec            # enable OpenHarmony Codec support [no]
#------------------------------------------------------------------------------    
# --------------------------- linux/unix features -----------------------------     
#------------------------------------------------------------------------------    
# build_alsa              # config_options+= --disable-alsa               # disable ALSA support [autodetect]
# build_libdc1394         # config_options+= --enable-libdc1394           # enable IIDC-1394 grabbing using libdc1394 and libraw1394 [no]
# build_libdrm            # config_options+= --disable-libdrm             # disable DRM code (Linux) [autodetect]
# build_libiec61883       # config_options+= --enable-libiec61883         # enable iec61883 via libiec61883 [no]
# build_libv4l2           # config_options+= --enable-libv4l2             # enable libv4l2/v4l-utils [no]
# build_libxcb_shape      # config_options+= --enable-libxcb-shape        # enable X11 grabbing shape rendering [autodetect]
# build_libxcb_shm        # config_options+= --enable-libxcb-shm          # enable X11 grabbing shm communication [autodetect]
# build_libxcb_xfixes     # config_options+= --enable-libxcb-xfixes       # enable X11 grabbing mouse rendering [autodetect]
# build_libxcb            # config_options+= --enable-libxcb              # enable X11 grabbing using XCB [autodetect]
# build_rkmpp             # config_options+= --enable-rkmpp               # enable Rockchip Media Process Platform code [no]
# build_v4l2_m2m          # config_options+= --disable-v4l2-m2m           # disable V4L2 mem2mem code [autodetect]
# build_vaapi             # config_options+= --disable-vaapi              # disable Video Acceleration API (mainly Unix/Intel) code [autodetect]
# build_xlib              # config_options+= --disable-xlib               # disable xlib [autodetect]
#------------------------------------------------------------------------------
# ----------------------------- hardware features ----------------------------- 
#------------------------------------------------------------------------------
# build_amf               # config_options+= --disable-amf                # disable AMF video encoding code [autodetect]
# build_vulkan            # config_options+= --disable-vulkan             # disable Vulkan code [autodetect]
# build_libmfx            # config_options+= --enable-libmfx              # enable Intel MediaSDK (AKA Quick Sync Video) code via libmfx [no]
# build_libvpl            # config_options+= --enable-libvpl              # enable Intel oneVPL code via libvpl if libmfx is not used [no]
# build_omx               # config_options+= --enable-omx                 # enable OpenMAX IL code [no]
# build_vulkan_static     # config_options+= --enable-vulkan-static       # enable statically link to libvulkan [no]
#------------------------------------------------------------------------------
# ----------------------------- windows features ------------------------------ 
#------------------------------------------------------------------------------
# build_avisynth          # config_options+= --enable-avisynth            # enable reading of AviSynth script files [no]
#------------------------------------------------------------------------------
# -------------------------- cross-platform features --------------------------
#------------------------------------------------------------------------------ 
# build_bzlib             # config_options+= --disable-bzlib              # disable bzlib [autodetect]
# build_iconv             # config_options+= --disable-iconv              # disable iconv [autodetect]
# build_lzma              # config_options+= --disable-lzma               # disable lzma [autodetect]
# build_sdl2              # config_options+= --disable-sdl2               # disable sdl2 [autodetect]
# build_sndio             # config_options+= --disable-sndio              # disable sndio support [autodetect]
# build_zlib              # config_options+= --disable-zlib               # disable zlib [autodetect]
# build_libvo_amrwbenc    # config_options+= --enable-libvo-amrwbenc      # enable AMR-WB encoding via libvo-amrwbenc [no]
# build_libopencore_amrnb # config_options+= --enable-libopencore-amrnb   # enable AMR-NB de/encoding via libopencore-amrnb [no]
# build_libopencore_amrwb # config_options+= --enable-libopencore-amrwb   # enable AMR-WB decoding via libopencore-amrwb [no]
# build_liblcevc_dec      # config_options+= --enable-liblcevc-dec        # enable LCEVC decoding via liblcevc-dec [no]
# build_chromaprint       # config_options+= --enable-chromaprint         # enable audio fingerprinting with chromaprint [no]
# build_frei0r            # config_options+= --enable-frei0r              # enable frei0r video filtering [no]
# build_gcrypt            # config_options+= --enable-gcrypt              # enable gcrypt, needed for rtmp(t)e support if openssl, librtmp or gmp is not used [no]
# build_gmp               # config_options+= --enable-gmp                 # enable gmp, needed for rtmp(t)e support if openssl or librtmp is not used [no]
# build_gnutls            # config_options+= --enable-gnutls              # enable gnutls, needed for https support if openssl, libtls or mbedtls is not used [no]
# build_lcms2             # config_options+= --enable-lcms2               # enable ICC profile support via LittleCMS 2 [no]
# build_libaom            # config_options+= --enable-libaom              # enable AV1 video encoding/decoding via libaom [no]
# build_libaribb24        # config_options+= --enable-libaribb24          # enable ARIB text and caption decoding via libaribb24 [no]
# build_libaribcaption    # config_options+= --enable-libaribcaption      # enable ARIB text and caption decoding via libaribcaption [no]
# build_libass            # config_options+= --enable-libass              # enable libass subtitles rendering, needed for subtitles and ass filter [no]
# build_libbluray         # config_options+= --enable-libbluray           # enable BluRay reading using libbluray [no]
# build_libbs2b           # config_options+= --enable-libbs2b             # enable bs2b DSP library [no]
# build_libcaca           # config_options+= --enable-libcaca             # enable textual display using libcaca [no]
# build_libcdio           # config_options+= --enable-libcdio             # enable audio CD grabbing with libcdio [no]
# build_libcelt           # config_options+= --enable-libcelt             # enable CELT decoding via libcelt [no]
# build_libcodec2         # config_options+= --enable-libcodec2           # enable codec2 en/decoding using libcodec2 [no]
# build_libdav1d          # config_options+= --enable-libdav1d            # enable AV1 decoding via libdav1d [no]
# build_libdavs2          # config_options+= --enable-libdavs2            # enable AVS2 decoding via libdavs2 [no]
# build_libdvdnav         # config_options+= --enable-libdvdnav           # enable libdvdnav, needed for DVD demuxing [no]
# build_libdvdread        # config_options+= --enable-libdvdread          # enable libdvdread, needed for DVD demuxing [no]
# build_libflite          # config_options+= --enable-libflite            # enable flite (voice synthesis) support via libflite [no]
# build_libfontconfig     # config_options+= --enable-libfontconfig       # enable libfontconfig, useful for drawtext filter [no]
# build_libfreetype       # config_options+= --enable-libfreetype         # enable libfreetype, needed for drawtext filter [no]
# build_libfribidi        # config_options+= --enable-libfribidi          # enable libfribidi, improves drawtext filter [no]
# build_libglslang        # config_options+= --enable-libglslang          # enable GLSL->SPIRV compilation via libglslang [no]
# build_libgme            # config_options+= --enable-libgme              # enable Game Music Emu via libgme [no]
# build_libgsm            # config_options+= --enable-libgsm              # enable GSM de/encoding via libgsm [no]
# build_libharfbuzz       # config_options+= --enable-libharfbuzz         # enable libharfbuzz, needed for drawtext filter [no]
# build_libilbc           # config_options+= --enable-libilbc             # enable iLBC de/encoding via libilbc [no]
# build_libjack           # config_options+= --enable-libjack             # enable JACK audio sound server [no]
# build_libjxl            # config_options+= --enable-libjxl              # enable JPEG XL de/encoding via libjxl [no]
# build_libklvanc         # config_options+= --enable-libklvanc           # enable Kernel Labs VANC processing [no]
# build_libkvazaar        # config_options+= --enable-libkvazaar          # enable HEVC encoding via libkvazaar [no]
# build_liblc3            # config_options+= --enable-liblc3              # enable LC3 de/encoding via liblc3 [no]
# build_liblensfun        # config_options+= --enable-liblensfun          # enable lensfun lens correction [no]
# build_libmodplug        # config_options+= --enable-libmodplug          # enable ModPlug via libmodplug [no]
# build_libmp3lame        # config_options+= --enable-libmp3lame          # enable MP3 encoding via libmp3lame [no]
# build_libmysofa         # config_options+= --enable-libmysofa           # enable libmysofa, needed for sofalizer filter [no]
# build_liboapv           # config_options+= --enable-liboapv             # enable APV encoding via liboapv [no]
# build_libopencv         # config_options+= --enable-libopencv           # enable video filtering via libopencv [no]
# build_libopenh264       # config_options+= --enable-libopenh264         # enable H.264 encoding via OpenH264 [no]
# build_libopenjpeg       # config_options+= --enable-libopenjpeg         # enable JPEG 2000 encoding via OpenJPEG [no]
# build_libopenmpt        # config_options+= --enable-libopenmpt          # enable decoding tracked files via libopenmpt [no]
# build_libopenvino       # config_options+= --enable-libopenvino         # enable OpenVINO as a DNN module backend for DNN based filters like dnn_processing [no]
# build_libopus           # config_options+= --enable-libopus             # enable Opus de/encoding via libopus [no]
# build_libplacebo        # config_options+= --enable-libplacebo          # enable libplacebo library [no]
# build_libpulse          # config_options+= --enable-libpulse            # enable Pulseaudio input via libpulse [no]
# build_libqrencode       # config_options+= --enable-libqrencode         # enable QR encode generation via libqrencode [no]
# build_libquirc          # config_options+= --enable-libquirc            # enable QR decoding via libquirc [no]
# build_librabbitmq       # config_options+= --enable-librabbitmq         # enable RabbitMQ library [no]
# build_librav1e          # config_options+= --enable-librav1e            # enable AV1 encoding via rav1e [no]
# build_librist           # config_options+= --enable-librist             # enable RIST via librist [no]
# build_librsvg           # config_options+= --enable-librsvg             # enable SVG rasterization via librsvg [no]
# build_librtmp           # config_options+= --enable-librtmp             # enable RTMP[E] support via librtmp [no]
# build_librubberband     # config_options+= --enable-librubberband       # enable rubberband needed for rubberband filter [no]
# build_libshaderc        # config_options+= --enable-libshaderc          # enable GLSL->SPIRV compilation via libshaderc [no]
# build_libshine          # config_options+= --enable-libshine            # enable fixed-point MP3 encoding via libshine [no]
# build_libsmbclient      # config_options+= --enable-libsmbclient        # enable Samba protocol via libsmbclient [no]
# build_libsnappy         # config_options+= --enable-libsnappy           # enable Snappy compression, needed for hap encoding [no]
# build_libsoxr           # config_options+= --enable-libsoxr             # enable Include libsoxr resampling [no]
# build_libspeex          # config_options+= --enable-libspeex            # enable Speex de/encoding via libspeex [no]
# build_libsrt            # config_options+= --enable-libsrt              # enable Haivision SRT protocol via libsrt [no]
# build_libssh            # config_options+= --enable-libssh              # enable SFTP protocol via libssh [no]
# build_libsvtav1         # config_options+= --enable-libsvtav1           # enable AV1 encoding via SVT [no]
# build_libtensorflow     # config_options+= --enable-libtensorflow       # enable TensorFlow as a DNN module backend for DNN based filters like sr [no]
# build_libtesseract      # config_options+= --enable-libtesseract        # enable Tesseract, needed for ocr filter [no]
# build_libtheora         # config_options+= --enable-libtheora           # enable Theora encoding via libtheora [no]
# build_libtls            # config_options+= --enable-libtls              # enable LibreSSL (via libtls), needed for https support if openssl, gnutls or mbedtls is not used [no]
# build_libtorch          # config_options+= --enable-libtorch            # enable Torch as one DNN backend [no]
# build_libtwolame        # config_options+= --enable-libtwolame          # enable MP2 encoding via libtwolame [no]
# build_libuavs3d         # config_options+= --enable-libuavs3d           # enable AVS3 decoding via libuavs3d [no]
# build_libvidstab        # config_options+= --enable-libvidstab          # enable video stabilization using vid.stab [no]
# build_libvmaf           # config_options+= --enable-libvmaf             # enable vmaf filter via libvmaf [no]
# build_libvorbis         # config_options+= --enable-libvorbis           # enable Vorbis en/decoding via libvorbis, native implementation exists [no]
# build_libvpx            # config_options+= --enable-libvpx              # enable VP8 and VP9 de/encoding via libvpx [no]
# build_libvvenc          # config_options+= --enable-libvvenc            # enable H.266/VVC encoding via vvenc [no]
# build_libwebp           # config_options+= --enable-libwebp             # enable WebP encoding via libwebp [no]
# build_libx264           # config_options+= --enable-libx264             # enable H.264 encoding via x264 [no]
# build_libx265           # config_options+= --enable-libx265             # enable HEVC encoding via x265 [no]
# build_libxavs           # config_options+= --enable-libxavs             # enable AVS encoding via xavs [no]
# build_libxavs2          # config_options+= --enable-libxavs2            # enable AVS2 encoding via xavs2 [no]
# build_libxevd           # config_options+= --enable-libxevd             # enable EVC decoding via libxevd [no]
# build_libxeve           # config_options+= --enable-libxeve             # enable EVC encoding via libxeve [no]
# build_libxml2           # config_options+= --enable-libxml2             # enable XML parsing using the C library libxml2, needed for dash and imf demuxing support [no]
# build_libxvid           # config_options+= --enable-libxvid             # enable Xvid encoding via xvidcore, native MPEG-4/Xvid encoder exists [no]
# build_libzimg           # config_options+= --enable-libzimg             # enable z.lib, needed for zscale filter [no]
# build_libzmq            # config_options+= --enable-libzmq              # enable message passing via libzmq [no]
# build_libzvbi           # config_options+= --enable-libzvbi             # enable teletext support via libzvbi [no]
# build_lv2               # config_options+= --enable-lv2                 # enable LV2 audio filtering [no]
# build_mbedtls           # config_options+= --enable-mbedtls             # enable mbedTLS, needed for https support if openssl, gnutls or libtls is not used [no]
# build_openal            # config_options+= --enable-openal              # enable OpenAL 1.1 capture support [no]
# build_opencl            # config_options+= --enable-opencl              # enable OpenCL processing [no]
# build_opengl            # config_options+= --enable-opengl              # enable OpenGL rendering [no]
# build_openssl           # config_options+= --enable-openssl             # enable openssl, needed for https support if gnutls, libtls or mbedtls is not used [no]
# build_pocketsphinx      # config_options+= --enable-pocketsphinx        # enable PocketSphinx, needed for asr filter [no]
# build_vapoursynth       # config_options+= --enable-vapoursynth         # enable VapourSynth demuxer [no]
# build_whisper           # config_options+= --enable-whisper             # enable whisper filter [no]
#------------------------------------------------------------------------------
# ------------------------------ non-gpl features -----------------------------
#------------------------------------------------------------------------------ 
# build_decklink          # config_options+= --enable-decklink            # enable Blackmagic DeckLink I/O support [no]
# build_libfdk_aac        # config_options+= --enable-libfdk-aac          # enable AAC de/encoding via libfdk-aac [no]
# ----------------------------- hardware features ----------------------------- 
# build_cuda_llvm         # config_options+= --disable-cuda-llvm          # disable CUDA compilation using clang [autodetect]
# build_cuvid             # config_options+= --disable-cuvid              # disable Nvidia CUVID support [autodetect]
# build_ffnvcodec         # config_options+= --disable-ffnvcodec          # disable dynamically linked Nvidia code [autodetect]
# build_nvdec             # config_options+= --disable-nvdec              # disable Nvidia video decoding acceleration (via hwaccel) [autodetect]
# build_nvenc             # config_options+= --disable-nvenc              # disable Nvidia video encoding code [autodetect]
# build_vdpau             # config_options+= --disable-vdpau              # disable Nvidia Video Decode and Presentation API for Unix code [autodetect]
# build_cuda_nvcc         # config_options+= --enable-cuda-nvcc           # enable Nvidia CUDA compiler [no]
# build_libnpp            # config_options+= --enable-libnpp              # enable Nvidia Performance Primitives-based code [no]
# --------------------------- linux/unix features -----------------------------    
# build_mmal              # config_options+= --disable-mmal               # enable Broadcom Multi-Media Abstraction Layer (Raspberry Pi) via MMAL [no]
# build_omx_rpi           # config_options+= --disable-omx-rpi            # enable OpenMAX IL code for Raspberry Pi [no]
# ----------------------------- windows features ------------------------------ 
# build_d3d11va           # config_options+= --disable-d3d11va            # disable Microsoft Direct3D 11 video acceleration code [autodetect]
# build_d3d12va           # config_options+= --disable-d3d12va            # disable Microsoft Direct3D 12 video acceleration code [autodetect]
# build_dxva2             # config_options+= --disable-dxva2              # disable Microsoft DirectX 9 video acceleration code [autodetect]
# build_schannel          # config_options+= --disable-schannel           # disable SChannel SSP, needed for TLS support on Windows if openssl and gnutls are not used [autodetect]
# build_mediafoundation   # config_options+= --enable-mediafoundation     # enable encoding via MediaFoundation [auto]
# ------------------------------ apple features -------------------------------     
# build_avfoundation      # config_options+= --disable-avfoundation       # disable Apple AVFoundation framework [autodetect]
# build_appkit            # config_options+= --disable-appkit             # disable Apple AppKit framework [autodetect]
# build_audiotoolbox      # config_options+= --disable-audiotoolbox       # disable Apple AudioToolbox code [autodetect]
# build_coreimage         # config_options+= --disable-coreimage          # disable Apple CoreImage framework [autodetect]
# build_metal             # config_options+= --disable-metal              # disable Apple Metal framework [autodetect]
# build_securetransport   # config_options+= --disable-securetransport    # disable Secure Transport, needed for TLS support on OSX if openssl and gnutls are not used [autodetect]
# build_videotoolbox      # config_options+= --disable-videotoolbox       # disable VideoToolbox code [autodetect]

