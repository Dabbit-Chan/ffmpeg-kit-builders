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
  std::shared_ptr<std::set<std::string>> enabledLibrarySet =
      getExternalLibraries();
#define contains_ext_lib(element)                                              \
  enabledLibrarySet->find(element) != enabledLibrarySet->end()
  bool speex = contains_ext_lib("speex");
  bool fribidi = contains_ext_lib("fribidi");
  bool gnutls = contains_ext_lib("gnutls");
  bool xvid = contains_ext_lib("xvid");

  bool min = false;
  bool minGpl = false;
  bool https = false;
  bool httpsGpl = false;
  bool audio = false;
  bool video = false;
  bool full = false;
  bool fullGpl = false;

  if (speex && fribidi) {
    if (xvid) {
      fullGpl = true;
    } else {
      full = true;
    }
  } else if (speex) {
    audio = true;
  } else if (fribidi) {
    video = true;
  } else if (xvid) {
    if (gnutls) {
      httpsGpl = true;
    } else {
      minGpl = true;
    }
  } else {
    if (gnutls) {
      https = true;
    } else {
      min = true;
    }
  }

  if (fullGpl) {
    if (contains_ext_lib("dav1d") && contains_ext_lib("fontconfig") &&
        contains_ext_lib("freetype") && contains_ext_lib("fribidi") &&
        contains_ext_lib("gmp") && contains_ext_lib("gnutls") &&
        contains_ext_lib("kvazaar") && contains_ext_lib("mp3lame") &&
        contains_ext_lib("ass") && contains_ext_lib("iconv") &&
        contains_ext_lib("ilbc") && contains_ext_lib("theora") &&
        contains_ext_lib("vidstab") && contains_ext_lib("vorbis") &&
        contains_ext_lib("vpx") && contains_ext_lib("webp") &&
        contains_ext_lib("xml2") &&
        (contains_ext_lib("opencore-amrnb") ||
         contains_ext_lib("opencore-amrwb")) &&
        contains_ext_lib("opus") && contains_ext_lib("shine") &&
        contains_ext_lib("snappy") && contains_ext_lib("soxr") &&
        contains_ext_lib("speex") && contains_ext_lib("twolame") &&
        contains_ext_lib("x264") && contains_ext_lib("x265") &&
        contains_ext_lib("xvid")) {
      return "full-gpl";
    } else {
      return "custom";
    }
  }

  if (full) {
    if (contains_ext_lib("dav1d") && contains_ext_lib("fontconfig") &&
        contains_ext_lib("freetype") && contains_ext_lib("fribidi") &&
        contains_ext_lib("gmp") && contains_ext_lib("gnutls") &&
        contains_ext_lib("kvazaar") && contains_ext_lib("mp3lame") &&
        contains_ext_lib("ass") && contains_ext_lib("iconv") &&
        contains_ext_lib("ilbc") && contains_ext_lib("theora") &&
        contains_ext_lib("vorbis") && contains_ext_lib("vpx") &&
        contains_ext_lib("webp") && contains_ext_lib("xml2") &&
        (contains_ext_lib("opencore-amrnb") ||
         contains_ext_lib("opencore-amrwb")) &&
        contains_ext_lib("opus") && contains_ext_lib("shine") &&
        contains_ext_lib("snappy") && contains_ext_lib("soxr") &&
        contains_ext_lib("speex") && contains_ext_lib("twolame")) {
      return "full";
    } else {
      return "custom";
    }
  }

  if (video) {
    if (contains_ext_lib("dav1d") && contains_ext_lib("fontconfig") &&
        contains_ext_lib("freetype") && contains_ext_lib("fribidi") &&
        contains_ext_lib("kvazaar") && contains_ext_lib("ass") &&
        contains_ext_lib("iconv") && contains_ext_lib("theora") &&
        contains_ext_lib("vpx") && contains_ext_lib("webp") &&
        contains_ext_lib("snappy")) {
      return "video";
    } else {
      return "custom";
    }
  }

  if (audio) {
    if (contains_ext_lib("mp3lame") && contains_ext_lib("ilbc") &&
        contains_ext_lib("vorbis") &&
        (contains_ext_lib("opencore-amrnb") ||
         contains_ext_lib("opencore-amrwb")) &&
        contains_ext_lib("opus") && contains_ext_lib("shine") &&
        contains_ext_lib("soxr") && contains_ext_lib("speex") &&
        contains_ext_lib("twolame")) {
      return "audio";
    } else {
      return "custom";
    }
  }

  if (httpsGpl) {
    if (contains_ext_lib("gmp") && contains_ext_lib("gnutls") &&
        contains_ext_lib("vidstab") && contains_ext_lib("x264") &&
        contains_ext_lib("x265") && contains_ext_lib("xvid")) {
      return "https-gpl";
    } else {
      return "custom";
    }
  }

  if (https) {
    if (contains_ext_lib("gmp") && contains_ext_lib("gnutls")) {
      return "https";
    } else {
      return "custom";
    }
  }

  if (minGpl) {
    if (contains_ext_lib("vidstab") && contains_ext_lib("x264") &&
        contains_ext_lib("x265") && contains_ext_lib("xvid")) {
      return "min-gpl";
    } else {
      return "custom";
    }
  }

  return "min";
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