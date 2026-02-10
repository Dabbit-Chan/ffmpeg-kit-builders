/*
 * Copyright (c) 2025 Akash Patel
 *
 * This file is part of FFmpegKit.
 *
 * FFmpegKit is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * FFmpegKit is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General License for more details.
 *
 *  You should have received a copy of the GNU Lesser General License
 *  along with FFmpegKit.  If not, see <http://www.gnu.org/licenses/>.
 */

#include "Packages.hpp"
extern "C" {
#include <libavutil/avutil.h>
}
#include <algorithm>
#include <memory>

std::string ffmpegkit::Packages::getPackageName() {
  std::string bundleType = getBundleType();
  return bundleType;
}

bool ffmpegkit::Packages::getIsGpl() {
  std::string buildConfiguration = avutil_configuration();
  return buildConfiguration.find("--enable-gpl") != std::string::npos;
}

bool ffmpegkit::Packages::getIsNonFree() {
  std::string buildConfiguration = avutil_configuration();
  return buildConfiguration.find("--enable-nonfree") != std::string::npos;
}

std::string ffmpegkit::Packages::getBundleType() {
  std::string bundleType = FFMPEG_KIT_BUNDLE_TYPE;
  return bundleType;
}

std::shared_ptr<std::set<std::string>>
ffmpegkit::Packages::getExternalLibraries() {
  const std::set<const char *> supportedExternalLibraries{"alsa",
                                                          "amf",
                                                          "aom",
                                                          "appkit",
                                                          "aribb24",
                                                          "aribcaption",
                                                          "ass",
                                                          "audiotoolbox",
                                                          "avfoundation",
                                                          "avisynth",
                                                          "bluray",
                                                          "bs2b",
                                                          "caca",
                                                          "cdio",
                                                          "celt",
                                                          "chromaprint",
                                                          "codec2",
                                                          "coreimage",
                                                          "cuda-llvm",
                                                          "cuda-nvcc",
                                                          "cuvid",
                                                          "d3d11va",
                                                          "d3d12va",
                                                          "dav1d",
                                                          "davs2",
                                                          "dc1394",
                                                          "decklink",
                                                          "drm",
                                                          "dvdnav",
                                                          "dvdread",
                                                          "dxva2",
                                                          "fdk-aac",
                                                          "ffnvcodec",
                                                          "flite",
                                                          "fontconfig",
                                                          "frei0r",
                                                          "freetype",
                                                          "fribidi",
                                                          "gcrypt",
                                                          "glslang",
                                                          "gme",
                                                          "gmp",
                                                          "gnutls",
                                                          "gsm",
                                                          "harfbuzz",
                                                          "iconv",
                                                          "iec61883",
                                                          "ilbc",
                                                          "jack",
                                                          "jni",
                                                          "jxl",
                                                          "klvanc",
                                                          "kvazaar",
                                                          "ladspa",
                                                          "lc3",
                                                          "lcevc-dec",
                                                          "lcms2",
                                                          "lensfun",
                                                          "lv2",
                                                          "mbedtls",
                                                          "mediacodec",
                                                          "mediafoundation",
                                                          "metal",
                                                          "mfx",
                                                          "mmal",
                                                          "modplug",
                                                          "mp3lame",
                                                          "mysofa",
                                                          "npp",
                                                          "nvdec",
                                                          "nvenc",
                                                          "oapv",
                                                          "ohcodec",
                                                          "omx",
                                                          "omx-rpi",
                                                          "openal",
                                                          "opencl",
                                                          "opencv",
                                                          "opencore-amrnb",
                                                          "opencore-amrwb",
                                                          "opengl",
                                                          "openh264",
                                                          "openjpeg",
                                                          "openmpt",
                                                          "openssl",
                                                          "openvino",
                                                          "opus",
                                                          "placebo",
                                                          "pocketsphinx",
                                                          "pulse",
                                                          "qrencode",
                                                          "quirc",
                                                          "rabbitmq",
                                                          "rav1e",
                                                          "rist",
                                                          "rkmpp",
                                                          "rsvg",
                                                          "rtmp",
                                                          "rubberband",
                                                          "schannel",
                                                          "sdl2",
                                                          "securetransport",
                                                          "shaderc",
                                                          "shine",
                                                          "smbclient",
                                                          "snappy",
                                                          "sndio",
                                                          "soxr",
                                                          "speex",
                                                          "srt",
                                                          "ssh",
                                                          "svtav1",
                                                          "tensorflow",
                                                          "tesseract",
                                                          "theora",
                                                          "tls",
                                                          "torch",
                                                          "twolame",
                                                          "uavs3d",
                                                          "v4l2",
                                                          "v4l2-m2m",
                                                          "vaapi",
                                                          "vapoursynth",
                                                          "vdpau",
                                                          "videotoolbox",
                                                          "vidstab",
                                                          "vmaf",
                                                          "vo-amrwbenc",
                                                          "vorbis",
                                                          "vpl",
                                                          "vpx",
                                                          "vulkan",
                                                          "vvenc",
                                                          "webp",
                                                          "whisper",
                                                          "x264",
                                                          "x265",
                                                          "xavs",
                                                          "xavs2",
                                                          "xcb",
                                                          "xcb-shape",
                                                          "xcb-shm",
                                                          "xcb-xfixes",
                                                          "xevd",
                                                          "xeve",
                                                          "xlib",
                                                          "xml2",
                                                          "xvid",
                                                          "zimg",
                                                          "zmq",
                                                          "zvbi"};

  std::string buildConfiguration(avutil_configuration());
  char libraryName1[50];
  char libraryName2[50];
  std::shared_ptr<std::set<std::string>> enabledLibrarySet =
      std::make_shared<std::set<std::string>>();

  std::for_each(
      supportedExternalLibraries.cbegin(), supportedExternalLibraries.cend(),
      [&](const char *supportedExternalLibrary) {
        sprintf(libraryName1, "enable-%s", supportedExternalLibrary);
        sprintf(libraryName2, "enable-lib%s", supportedExternalLibrary);

        if (buildConfiguration.find(libraryName1) != std::string::npos ||
            buildConfiguration.find(libraryName2) != std::string::npos) {
          enabledLibrarySet->insert(supportedExternalLibrary);
        }
      });

  return enabledLibrarySet;
}