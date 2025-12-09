#!/bin/bash

# shellcheck disable=SC2317,SC1091,SC1090,SC2120

# required for ffmpeg-kit
build_libjsoncpp() {
  activate_meson
  local repo="https://github.com/open-source-parsers/jsoncpp"
  local lib="jsoncpp"
  local repo_ver="1.9.6"
	change_dir "$src_dir"
	do_git_checkout "$repo" "$lib" "$repo_ver"
	change_dir "$src_dir/jsoncpp"
  local meson_options="--prefix=$dependency_install_prefix -Ddefault_library=static"
	do_meson "$meson_options" "setup build"
	do_ninja_and_ninja_install
	change_dir "$src_dir"
}


#------------------------------------------------------------------------------     
#region------------------------ android features ------------------------------     
#------------------------------------------------------------------------------      
# build_jni               # config_options+= --disable-jni                # enable JNI support [no]
build_jni() {
  if [[ $disable_jni != 1 && $enable_jni == 1 ]]; then
	echo "INFO: Only available on Android build"
  echo "INFO: No jni library to compile. Library built into OS."
	fi
}
# build_ladspa            # config_options+= --disable-ladspa             # enable LADSPA audio filtering [no]
build_ladspa() {
  if [[ $disable_ladspa != 1 && $enable_ladspa == 1 ]]; then
	echo "INFO: Only available on Android build"
  echo "INFO: No ladspa library to compile. Library built into OS."
	fi
}
# build_mediacodec        # config_options+= --disable-mediacodec         # enable Android MediaCodec support [no]
build_mediacodec() {
  if [[ $disable_mediacodec != 1 && $enable_mediacodec == 1 ]]; then
	echo "INFO: Only available on Android build"
  echo "INFO: No mediacodec library to compile. Library built into OS."
	fi 
}
#endregion---------------------------------------------------------------------    
#region----------------------- harmony features ------------------------------     
#------------------------------------------------------------------------------    
# build_ohcodec           # config_options+= --disable-ohcodec            # enable OpenHarmony Codec support [no]
build_ohcodec() {
  if [[ $disable_ohcodec != 1 && $enable_ohcodec == 1 ]]; then
	echo "INFO: Only available on Harmony build"
  echo "INFO: No ohcodec library to compile. Library built into OS."
	fi 
}
#endregion---------------------------------------------------------------------    
#region---------------------- linux/unix features -----------------------------     
#------------------------------------------------------------------------------    
# build_alsa              # config_options+= --disable-alsa               # disable ALSA support [autodetect]
build_alsa() {
  if [[ $disable_alsa != 1 && $enable_alsa == 1 ]]; then
	local lib="alsa"
  local repo="https://github.com/alsa-project/alsa-lib"
  change_dir "$src_dir"
	do_git_checkout "$repo" "$lib"
  change_dir "$src_dir/$lib"
  generic_configure_make_install "--enable-static --disable-shared"
  change_dir "$src_dir"
	fi 
}
build_libusb() {
  local repo="https://github.com/libusb/libusb"
  local lib="libusb"
  local repo_ver="v1.0.29"
  change_dir "$src_dir"
	do_git_checkout "$repo" "$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  generic_configure_make_install "--disable-udev"
  change_dir "$src_dir"
}
build_sdl12_compat() {
  build_sdl2
  local repo="https://github.com/libsdl-org/sdl12-compat"
  local lib="sdl12-compat"
  local repo_ver="release-1.2.72"
  change_dir "$src_dir"
	do_git_checkout "$repo" "$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  do_cmake_and_install "-DCMAKE_EXE_LINKER_FLAGS=\"-lm\" -DSDL12TESTS=OFF"
  change_dir "$src_dir"
}
# build_libdc1394         # config_options+= --enable-libdc1394           # enable IIDC-1394 grabbing using libdc1394 and libraw1394 [no]
build_libdc1394() {
  if [[ $disable_libdc1394 != 1 && $enable_libdc1394 == 1 ]]; then
  build_sdl12_compat
  build_libusb
  local repo="https://git.code.sf.net/p/libdc1394/code"
  local lib="libdc1394"
  local repo_ver="V_2_2_7"
  change_dir "$src_dir"
	do_git_checkout "$repo" "$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  sed -i 's/^AM_PATH_SDL/# AM_PATH_SDL/g' configure.ac
  generic_configure_make_install
  change_dir "$src_dir"
  fi
}
# build_libdrm            # config_options+= --disable-libdrm             # disable DRM code (Linux) [autodetect]
build_libdrm() {
  if [[ $disable_libdrm != 1 && $enable_libdrm == 1 ]]; then
  activate_meson
  local repo="https://gitlab.freedesktop.org/mesa/libdrm"
  local lib="libdrm"
  local repo_ver="libdrm-2.4.129"
  change_dir "$src_dir"
	do_git_checkout "$repo" "$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  local meson_options="--prefix=$dependency_install_prefix -Ddefault_library=static"
	do_meson "$meson_options" "setup build"
	do_ninja_and_ninja_install
  fi
}
build_libraw1394() {
  local repo="https://github.com/Distrotech/libraw1394"
  local lib="libraw1394"
  change_dir "$src_dir"
	do_git_checkout "$repo" "$lib"
  change_dir "$src_dir/$lib"
  generic_configure_make_install
  change_dir "$src_dir"
}
# build_libiec61883       # config_options+= --enable-libiec61883         # enable iec61883 via libiec61883 [no]
build_libiec61883() {
  if [[ $disable_libiec61883 != 1 && $enable_libiec61883 == 1 ]]; then
  build_libraw1394
  local repo="https://github.com/Distrotech/libiec61883"
  local lib="libiec61883"
  change_dir "$src_dir"
	do_git_checkout "$repo" "$lib"
  change_dir "$src_dir/$lib"
  generic_configure_make_install
  change_dir "$src_dir"
  fi
}
# build_libv4l2           # config_options+= --enable-libv4l2             # enable libv4l2/v4l-utils [no]
build_libv4l2() {
  if [[ ($disable_libv4l2 != 1 && $enable_libv4l2 == 1) || ($enable_v4l2_m2m == 1 && $disable_v4l2_m2m != 1) ]]; then
  activate_meson
  local lib="libv4l2"
  local repo="https://github.com/gjasny/v4l-utils"
  local repo_ver="v4l-utils-1.30.1"
  change_dir "$src_dir"
	do_git_checkout "$repo" "$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  local meson_options="--prefix=$dependency_install_prefix -Ddefault_library=static -Ddoxygen-doc=disabled -Ddoxygen-html=false -Ddoxygen-man=false"
	do_meson "$meson_options" "setup build"
	do_ninja_and_ninja_install
  fi
}
# build_libxcb_shape      # config_options+= --enable-libxcb-shape        # enable X11 grabbing shape rendering [autodetect]
build_libxcb_shape() {
  if [[ $disable_libxcb_shape != 1 && $enable_libxcb_shape == 1 ]]; then
    build_libxcb
    echo "INFO: libxcb-shape is part of libxcb."
  fi
}
# build_libxcb_shm        # config_options+= --enable-libxcb-shm          # enable X11 grabbing shm communication [autodetect]
build_libxcb_shm() {
  if [[ $disable_libxcb_shm != 1 && $enable_libxcb_shm == 1 ]]; then
    build_libxcb
    echo "INFO: libxcb-shm is part of libxcb."
  fi
}
# build_libxcb_xfixes     # config_options+= --enable-libxcb-xfixes       # enable X11 grabbing mouse rendering [autodetect]
build_libxcb_xfixes() {
  if [[ $disable_libxcb_xfixes != 1 && $enable_libxcb_xfixes == 1 ]]; then
    build_libxcb
    echo "INFO: libxcb-xfixes is part of libxcb."
  fi
}
build_xcbproto() {
  # https://gitlab.freedesktop.org/xorg/proto/xcbproto
  local lib="xcbproto"
  local repo="https://gitlab.freedesktop.org/xorg/proto/xcbproto"
  local repo_ver="xcb-proto-1.17.0"
  change_dir "$src_dir"
	do_git_checkout "$repo" "$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  generic_configure_make_install
  change_dir "$src_dir"
}
build_libxau() {
  build_xorgproto
  # https://gitlab.freedesktop.org/xorg/lib/libxau
  local lib="libxau"
  local repo="https://gitlab.freedesktop.org/xorg/lib/libxau"
  local repo_ver="libXau-1.0.12"
  change_dir "$src_dir"
	do_git_checkout "$repo" "$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  generic_configure_make_install
  change_dir "$src_dir"
}
# build_libxcb            # config_options+= --enable-libxcb              # enable X11 grabbing using XCB [autodetect]
build_libxcb() {
  if [[ $disable_libxcb != 1 && $enable_libxcb == 1 ]]; then
  build_xcbproto
  build_libxau
  # https://gitlab.freedesktop.org/xorg/lib/libxcb
  local lib="libxcb"
  local repo="https://gitlab.freedesktop.org/xorg/lib/libxcb"
  local repo_ver="libxcb-1.17.0"
  change_dir "$src_dir"
	do_git_checkout "$repo" "$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  generic_configure_make_install
  change_dir "$src_dir"
  fi
}
# build_rkmpp             # config_options+= --enable-rkmpp               # enable Rockchip Media Process Platform code [no]
build_rkmpp() {
  if [[ $disable_rkmpp != 1 && $enable_rkmpp == 1 ]]; then
  # https://github.com/rockchip-linux/mpp
  local lib="rkmpp"
  local repo="https://github.com/rockchip-linux/mpp"
  local repo_ver="1.0.11"
  change_dir "$src_dir"
	do_git_checkout "$repo" "$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  do_cmake_and_install
  change_dir "$src_dir"
  fi
}
# build_v4l2_m2m          # config_options+= --disable-v4l2-m2m           # disable V4L2 mem2mem code [autodetect]
build_v4l2_m2m() {
  if [[ $disable_v4l2_m2m != 1 || $enable_v4l2_m2m == 1 ]]; then
  # https://github.com/gjasny/v4l-utils
  local lib="v4l2_m2m"
  build_libv4l2
  fi
}
# build_vaapi             # config_options+= --disable-vaapi              # disable Video Acceleration API (mainly Unix/Intel) code [autodetect]
build_vaapi() {
  if [[ $disable_vaapi != 1 && $enable_vaapi == 1 ]]; then
  activate_meson
  # https://github.com/intel/libva
  local lib="vaapi"
  local repo="https://github.com/intel/libva"
  local repo_ver="2.22.0"
  change_dir "$src_dir"
	do_git_checkout "$repo" "$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  local meson_options="--prefix=$dependency_install_prefix -Ddefault_library=static"
	do_meson "$meson_options" "setup build"
	do_ninja_and_ninja_install
  fi
}
build_xtrans() {
  # https://gitlab.freedesktop.org/xorg/lib/libxtrans
  local lib="xtrans"
  local repo="https://gitlab.freedesktop.org/xorg/lib/libxtrans"
  local repo_ver="xtrans-1.5.0"
  change_dir "$src_dir"
	do_git_checkout "$repo" "$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  generic_configure_make_install
  change_dir "$src_dir"
}
build_xorgproto() {
  # https://gitlab.freedesktop.org/xorg/proto/xorgproto
  # This package replaces deprecated individual proto packages like
  # xproto, kbproto, inputproto, and xextproto.
  activate_meson
  local lib="xorgproto"
  local repo="https://gitlab.freedesktop.org/xorg/proto/xorgproto"
  local repo_ver="xorgproto-2024.1"
  change_dir "$src_dir"
  do_git_checkout "$repo" "$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  generic_meson
  do_ninja_and_ninja_install
  change_dir "$src_dir"
}
# build_xlib              # config_options+= --disable-xlib               # disable xlib [autodetect]
build_xlib() {
  if [[ $disable_xlib != 1 && $enable_xlib == 1 ]]; then
  build_xorgproto
  build_xtrans
  build_libxcb
  # https://github.com/mirror/libX11
  local lib="xlib"
  local repo="https://github.com/mirror/libX11"
  local repo_ver="libX11-1.8.4"
  change_dir "$src_dir"
	do_git_checkout "$repo" "$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  generic_configure_make_install
  change_dir "$src_dir"
  fi
}
#endregion---------------------------------------------------------------------
#region------------------------ hardware features ----------------------------- 
#------------------------------------------------------------------------------
# build_amf               # config_options+= --disable-amf                # disable AMF video encoding code [autodetect]
build_amf() {
  if [[ $disable_amf != 1 && $enable_amf == 1 ]]; then
  # was https://github.com/GPUOpen-LibrariesAndSDKs/AMF
  local lib="amf_headers"
  do_git_checkout https://github.com/GPUOpen-LibrariesAndSDKs/AMF amf_headers
	change_dir "$src_dir/amf_headers"
  local touch_name=$(get_small_touchfile_name "already_installed_${host_name}")
	if [ ! -f "$touch_name" ]; then
		if [ ! -d "$dependency_install_prefix/include/AMF" ]; then
			create_dir "$dependency_install_prefix/include/AMF"
		fi
		cp -av "amf/public/include/." "$dependency_install_prefix/include/AMF" > >(redirect_output) 2>&1
		create_touch_file 0 "$touch_name"
  else
    echo -e "INFO: amf headers already installed" >>"$LOG_FILE"
	fi
	change_dir "$src_dir"
  fi
}
# build_vulkan            # config_options+= --disable-vulkan             # disable Vulkan code [autodetect]
build_vulkan() {
  local extra_args="$1"
  if [[ ($disable_vulkan != 1 && $enable_vulkan == 1) || -n $extra_args ]]; then
  # https://github.com/KhronosGroup/Vulkan-Headers  Vulkan-Headers v1.4.326
  local lib="Vulkan-Headers"
  local repo="https://github.com/KhronosGroup/Vulkan-Headers"
  local repo_ver="v1.4.335"
  change_dir "$src_dir"
	do_git_checkout "$repo" "$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  do_cmake_and_install "-DCMAKE_BUILD_TYPE=Release -DVULKAN_HEADERS_ENABLE_MODULE=NO -DVULKAN_HEADERS_ENABLE_TESTS=NO -DVULKAN_HEADERS_ENABLE_INSTALL=YES $extra_args"
  change_dir "$src_dir"
  fi
}
# build_libmfx            # config_options+= --enable-libmfx              # enable Intel MediaSDK (AKA Quick Sync Video) code via libmfx [no]
build_libmfx() {
  if [[ $disable_libmfx != 1 && $enable_libmfx == 1 ]]; then
  # https://github.com/Intel-Media-SDK/MediaSDK
  echo "WARNING: [disabled] Library has been archived and has security issues."
  fi
}
# build_libvpl            # config_options+= --enable-libvpl              # enable Intel oneVPL code via libvpl if libmfx is not used [no]
build_libvpl() {
  if [[ $disable_libvpl != 1 && $enable_libvpl == 1 ]]; then
  local lib="libvpl"
  local repo="https://github.com/intel/libvpl"
  local repo_ver="v2.15.0"
  change_dir "$src_dir"
	do_git_checkout "$repo" "$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  do_cmake "-B build -GNinja -DCMAKE_BUILD_TYPE=Release -DINSTALL_EXAMPLES=OFF -DINSTALL_DEV=ON -DBUILD_EXPERIMENTAL=OFF"
	do_ninja_and_ninja_install
  change_dir "$src_dir"
  fi
}
# build_omx               # config_options+= --enable-omx                 # enable OpenMAX IL code [no]
build_omx() {
  if [[ $disable_omx != 1 && $enable_omx == 1 ]]; then
  local repo="https://git.code.sf.net/p/omxil/omxil"
  local lib="libomxil-bellagio"
  local repo_ver="0.9.1"
  change_dir "$src_dir"
  do_git_checkout "$repo" "$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  export CFLAGS="$CFLAGS -Wno-error"
  # disable omxregister utility. not needed for ffmpeg
  sed -i 's/bin_PROGRAMS = omxregister-bellagio/#bin_PROGRAMS = omxregister-bellagio/' src/Makefile.am
  find . -name "configure.ac" -exec sed -i 's/-Werror//g' {} +
  generic_configure_make_install "--disable-doc"
  reset_cflags
  change_dir "$src_dir"
  fi
}
# build_vulkan_static     # config_options+= --enable-vulkan-static       # enable statically link to libvulkan [no]
build_vulkan_static() {
  if [[ $disable_vulkan_static != 1 && $enable_vulkan_static == 1 ]]; then
  local lib="Vulkan-Shim-Loader"
	change_dir "$src_dir"
	do_git_checkout https://github.com/BtbN/Vulkan-Shim-Loader "$lib"
	change_dir "$src_dir/$lib"
	build_vulkan "-DCMAKE_BUILD_TYPE=Release -DVULKAN_SHIM_IMPERSONATE=ON"
	change_dir "$src_dir"
	fi
}
#endregion---------------------------------------------------------------------
#region------------------------ windows features ------------------------------ 
#------------------------------------------------------------------------------
# build_avisynth          # config_options+= --enable-avisynth            # enable reading of AviSynth script files [no]
build_avisynth() {
  if [[ $disable_avisynth != 1 && $enable_avisynth == 1 ]]; then
	echo "INFO: Only available on Windows build"
  echo "INFO: No ohcodec library to compile. Library built into OS."
  fi
}
#endregion---------------------------------------------------------------------
#region--------------------- cross-platform features --------------------------
#------------------------------------------------------------------------------ 
# build_bzlib             # config_options+= --disable-bzlib              # disable bzlib [autodetect]
build_bzlib() {
  if [[ $disable_bzlib != 1 && $enable_bzlib == 1 ]]; then
  activate_meson
  # https://gitlab.com/bzip2/bzip2
  local lib="bzip2"
  local repo="https://gitlab.com/bzip2/bzip2"
  local repo_ver="bzip2-1.0.8"
  change_dir "$src_dir"
	do_git_checkout "$repo" "$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  do_make_and_make_install
  change_dir "$src_dir"
  fi
}
# build_iconv             # config_options+= --disable-iconv              # disable iconv [autodetect]
build_iconv() {
  if [[ $disable_iconv != 1 && $enable_iconv == 1 ]]; then
  # https://git.savannah.gnu.org/git/libiconv
  local lib="libiconv"
  local repo="https://ftp.gnu.org/gnu/libiconv/libiconv-1.18.tar.gz"
  local repo_ver="v1.18"
  change_dir "$src_dir"
	download_and_unpack_file "$repo" "$lib"
  change_dir "$src_dir/$lib"
  generic_configure_make_install "--enable-static --disable-shared --enable-pic --disable-rpath"
  change_dir "$src_dir"
  fi
}
# build_lzma              # config_options+= --disable-lzma               # disable lzma [autodetect]
build_lzma() {
  if [[ $disable_lzma != 1 && $enable_lzma == 1 ]]; then
  echo "NOTE FROM LZMA DEV: Users of LZMA Utils should 
  move to XZ Utils. XZ Utils support the legacy 
  .lzma format used by LZMA Utils, and can also 
  emulate the command line tools of LZMA Utils."
  local lib="xz"
  local repo="https://sourceforge.net/projects/lzmautils/files/xz-5.8.1.tar.xz"
  change_dir "$src_dir"
	download_and_unpack_file "$repo" "$lib"
  change_dir "$src_dir/$lib"
  generic_configure_make_install
  change_dir "$src_dir"
  fi
}
# build_sdl2              # config_options+= --disable-sdl2               # disable sdl2 [autodetect]
build_sdl2() {
  if [[ $disable_sdl2 != 1 ]]; then
  local lib="sdl2"
  local repo="https://github.com/libsdl-org/SDL"
  local repo_ver="release-2.32.8"
  change_dir "$src_dir"
	do_git_checkout "$repo" "$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  generic_configure_make_install
  change_dir "$src_dir"
  fi
}
# build_sndio             # config_options+= --disable-sndio              # disable sndio support [autodetect]
build_sndio() {
  if [[ $disable_sndio != 1 && $enable_sndio == 1 ]]; then
  # https://github.com/ratchov/sndio
  local lib="sndio"
  local repo="https://github.com/ratchov/sndio"
  local repo_ver="v1.10.0"
  change_dir "$src_dir"
	do_git_checkout "$repo" "$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  do_configure "--prefix=$dependency_install_prefix --enable-static"
  do_make_and_make_install
  change_dir "$src_dir"
  fi
}
# build_zlib              # config_options+= --disable-zlib               # disable zlib [autodetect]
build_zlib() {
  if [[ $disable_zlib != 1 && $enable_zlib == 1 ]]; then
  # https://github.com/madler/zlib
  local lib="zlib"
  local repo="https://github.com/madler/zlib"
  local repo_ver="v1.3.1"
  change_dir "$src_dir"
	do_git_checkout "$repo" "$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  export CFLAGS="$CFLAGS -fPIC"
  do_configure "--prefix=$dependency_install_prefix --static"
  do_make_and_make_install
  change_dir "$src_dir"
  fi
}
# build_libvo_amrwbenc    # config_options+= --enable-libvo-amrwbenc      # enable AMR-WB encoding via libvo-amrwbenc [no]
build_libvo_amrwbenc() {
  if [[ $disable_libvo_amrwbenc != 1 && $enable_libvo_amrwbenc == 1 ]]; then
  local lib="libvo_amrwbenc"
  local repo="https://sourceforge.net/projects/opencore-amr/files/vo-amrwbenc/vo-amrwbenc-0.1.3.tar.gz"
  change_dir "$src_dir"
  generic_download_and_make_and_install "$repo" "$lib"
  change_dir "$src_dir"
  fi
}
# build_libopencore_amrnb # config_options+= --enable-libopencore-amrnb   # enable AMR-NB de/encoding via libopencore-amrnb [no]
build_libopencore_amrnb() {
  if [[ $disable_libopencore_amrnb != 1 && $enable_libopencore_amrnb == 1 ]]; then
  local lib="libopencore_amrnb"
  local repo="https://sourceforge.net/projects/opencore-amr/files/opencore-amr/opencore-amr-0.1.6.tar.gz"
  change_dir "$src_dir"
  generic_download_and_make_and_install "$repo" "$lib"
  change_dir "$src_dir"
  fi
}
# build_libopencore_amrwb # config_options+= --enable-libopencore-amrwb   # enable AMR-WB decoding via libopencore-amrwb [no]
build_libopencore_amrwb() {
  if [[ $disable_libopencore_amrwb != 1 && $enable_libopencore_amrwb == 1 ]]; then
  local lib="libopencore_amrwb"
  build_libopencore_amrnb
  fi
}
# build_liblcevc_dec      # config_options+= --enable-liblcevc-dec        # enable LCEVC decoding via liblcevc-dec [no]
build_liblcevc_dec() {
  if [[ $disable_liblcevc_dec != 1 && $enable_liblcevc_dec == 1 ]]; then
  # https://github.com/v-novaltd/LCEVCdec
  local lib="liblcevc"
  local repo="https://github.com/v-novaltd/LCEVCdec"
  local repo_ver="4.0.4"
  change_dir "$src_dir"
  do_git_checkout "$repo" "$lib" "$repo_ver"
  change_dir "$src_dir/$lib/build" 1
  local cmake_params="-DCMAKE_BUILD_TYPE=Release \
-DBUILD_SHARED_LIBS=OFF \
-DVN_SDK_EXECUTABLES=OFF \
-DVN_SDK_UNIT_TESTS=OFF \
-DVN_SDK_DOCS=OFF \
-DVN_SDK_SAMPLE_SOURCE=OFF \
-DVN_SDK_PIPELINE_VULKAN=OFF \
-DVN_SDK_PIPELINE_LEGACY=OFF"
  do_cmake_and_install "$cmake_params" "$src_dir/$lib"
  change_dir "$src_dir"
  fi
}
build_fftw() {
  local lib="fftw"
  local repo="http://fftw.org/fftw-3.3.10.tar.gz"
	change_dir "$src_dir"
	download_and_unpack_file "$repo" "$lib"
	change_dir "$src_dir/$lib"
	generic_configure "--disable-doc --prefix=$dependency_install_prefix --enable-static --disable-shared"
	do_make_and_make_install
	change_dir "$src_dir"
}
# build_chromaprint       # config_options+= --enable-chromaprint         # enable audio fingerprinting with chromaprint [no]
build_chromaprint() {
  if [[ $disable_chromaprint != 1 && $enable_chromaprint == 1 ]]; then
  build_fftw
  # https://github.com/acoustid/chromaprint
  local lib="chromaprint"
  local repo="https://github.com/acoustid/chromaprint"
  local repo_ver="v1.6.0"
  change_dir "$src_dir"
  do_git_checkout "$repo" "$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  do_cmake_and_install "-DCMAKE_BUILD_TYPE=Release -DBUILD_TOOLS=OFF -DBUILD_TESTS=OFF -DFFT_LIB=fftw3"
  change_dir "$src_dir"
  fi
}
# build_frei0r            # config_options+= --enable-frei0r              # enable frei0r video filtering [no]
build_frei0r() {
  if [[ $disable_frei0r != 1 && $enable_frei0r == 1 ]]; then
  # https://github.com/dyne/frei0r
  local lib="frei0r"
  local repo="https://github.com/dyne/frei0r"
  local repo_ver="v2.5.1"
  change_dir "$src_dir"
  do_git_checkout "$repo" "$lib" "$repo_dir"
  change_dir "$src_dir/$lib/build"
  do_cmake_and_install "-DWITHOUT_OPENCV=1"
  change_dir "$src_dir"
  fi
}
build_libgpg_error() {
  # https://github.com/gpg/libgpg-error
  local lib="libgpg-error"
  local repo="https://github.com/gpg/libgpg-error"
  local repo_ver="libgpg-error-1.45"
  change_dir "$src_dir"
  do_git_checkout "$repo" "$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  generic_configure_make_install "--disable-doc --disable-nls --disable-languages --enable-install-gpg-error-config"
  change_dir "$src_dir"
}
# build_gcrypt            # config_options+= --enable-gcrypt              # enable gcrypt, needed for rtmp(t)e support if openssl, librtmp or gmp is not used [no]
build_gcrypt() {
  if [[ $disable_gcrypt != 1 && $enable_gcrypt == 1 ]]; then
  build_libgpg_error
  # https://github.com/gpg/libgcrypt #repo doesnt seem to work
  # https://www.gnupg.org/ftp/gcrypt/libgcrypt/libgcrypt-1.11.2.tar.bz2
  local lib="libgcrypt"
  local repo="https://www.gnupg.org/ftp/gcrypt/libgcrypt/libgcrypt-1.11.2.tar.bz2"
  change_dir "$src_dir"
  download_and_unpack_file "$repo" "$lib"
  change_dir "$src_dir/$lib"
  generic_configure_make_install "--with-libgpg-error-prefix=$dependency_install_prefix LIBS=\"-lpthread -ldl\" --disable-doc --disable-amd64-as-feature-detection"
  change_dir "$src_dir"
  fi
}
# build_gmp               # config_options+= --enable-gmp                 # enable gmp, needed for rtmp(t)e support if openssl or librtmp is not used [no]
build_gmp() {
  if [[ $disable_gmp != 1 && $enable_gmp == 1 ]]; then
  local lib="gmp"
  local repo="https://ftp.gnu.org/pub/gnu/gmp/gmp-6.3.0.tar.xz"
  change_dir "$src_dir"
  download_and_unpack_file https://ftp.gnu.org/pub/gnu/gmp/gmp-6.3.0.tar.xz
  change_dir "$src_dir/$lib"
  generic_configure_make_install "ABI=$bits_target"
  change_dir "$src_dir"
  fi
}
build_libnettle() {
  local lib="nettle"
  local repo="https://ftp.gnu.org/gnu/nettle/nettle-3.10.2.tar.gz"
	change_dir "$src_dir"
	download_and_unpack_file "$repo" "$lib"
	change_dir "$src_dir/$lib"
	generic_configure_make_install "--disable-openssl --disable-documentation --libdir=$dependency_install_prefix/lib" # in case we have both gnutls and openssl, just use gnutls [except that gnutls uses this so...huh?
	cp -rfv source/. destination/ 
  change_dir "$src_dir"
}
build_brotli() {
  local lib="brotli"
  local repo="https://github.com/google/brotli"
  local repo_ver="v1.2.0"
	change_dir "$src_dir"
	do_git_checkout "$repo" "$lib" "$repo_ver"
	change_dir "$src_dir/$lib"
  export CFLAGS="$CFLAGS -fPIC"
  export CXXFLAGS="$CXXFLAGS -fPIC"
	do_cmake_and_install "-DCMAKE_INSTALL_PREFIX=$dependency_install_prefix \
-DCMAKE_BUILD_TYPE=Release \
-DCMAKE_POSITION_INDEPENDENT_CODE=ON"
  # Replace all instances of "-R" with "-Wl,-rpath," in all .pc files
  sed -i.bak 's/Libs.*$/Libs: -L${libdir} -lbrotlicommon/' "$dependency_install_prefix"/lib/pkgconfig/libbrotlicommon.pc # remove rpaths not possible in conf
  sed -i.bak 's/Libs.*$/Libs: -L${libdir} -lbrotlidec/' "$dependency_install_prefix"/lib/pkgconfig/libbrotlidec.pc
  sed -i.bak 's/Libs.*$/Libs: -L${libdir} -lbrotlienc/' "$dependency_install_prefix"/lib/pkgconfig/libbrotlienc.pc
  sed -i 's/-lbrotlidec/-lbrotlidec -lbrotlicommon/g' "$dependency_install_prefix"/lib/pkgconfig/libbrotlidec.pc
	change_dir "$src_dir"
}
# build_gnutls            # config_options+= --enable-gnutls              # enable gnutls, needed for https support if openssl, libtls or mbedtls is not used [no]
build_gnutls() {
  if [[ $disable_gnutls != 1 && $enable_gnutls == 1 ]]; then
  build_brotli
  build_libnettle
  local lib="gnutls"
  local repo="https://www.gnupg.org/ftp/gcrypt/gnutls/v3.8/gnutls-3.8.9.tar.xz"
  change_dir "$src_dir"
  download_and_unpack_file "$repo" "$lib" # v3.8.10 not found by ffmpeg with identical .pc?
  change_dir "$src_dir/$lib"
  generic_configure_make_install "--disable-cxx \
--disable-doc \
--disable-tools \
--disable-tests \
--disable-nls \
--disable-rpath \
--disable-libdane \
--disable-gcc-warnings \
--disable-code-coverage \
--without-p11-kit \
--with-idn \
--without-tpm \
--with-included-unistring \
--with-included-libtasn1 \
-disable-gtk-doc-html \
--with-brotli \
--disable-non-suiteb-curves"
  change_dir "$src_dir"
  fi
}
# build_lcms2             # config_options+= --enable-lcms2               # enable ICC profile support via LittleCMS 2 [no]
build_lcms2() {
  if [[ $disable_lcms2 != 1 && $enable_lcms2 == 1 ]]; then
  local lib="lcms2"
  local repo_ver="lcms2.17"
  local repo="https://github.com/mm2/Little-CMS"
  activate_meson
  change_dir "$src_dir"
  do_git_checkout "$repo" "$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  local meson_options="--prefix=$dependency_install_prefix -Ddefault_library=static -Dtests=disabled -Dutils=false"
  do_meson "$meson_options" "setup build"
  do_ninja_and_ninja_install
  change_dir "$src_dir"
  fi
}
# build_libaom            # config_options+= --enable-libaom              # enable AV1 video encoding/decoding via libaom [no]
build_libaom() {
  if [[ $disable_libaom != 1 && $enable_libaom == 1 ]]; then
    local lib="aom"
    local repo_ver="v3.13.1"
    local repo="https://aomedia.googlesource.com/aom"
    change_dir "$src_dir"
    do_git_checkout "$repo" "$lib" "$repo_ver"
    change_dir "$src_dir/$lib"
    local cmake_params="-B build -G Ninja \
-DCMAKE_BUILD_TYPE=Release \
-DBUILD_SHARED_LIBS=0 \
-DENABLE_TESTS=0 \
-DENABLE_EXAMPLES=0 \
-DENABLE_DOCS=0"
    do_cmake "$cmake_params"
    do_ninja_and_ninja_install
    change_dir "$src_dir"
  fi
}
build_libpng() {
  local lib="libpng"
  local repo_ver="v1.6.53"
  local repo="https://github.com/glennrp/libpng"
	change_dir "$src_dir"
	do_git_checkout_and_make_install "$repo" "$lib" "$repo_ver"
	change_dir "$src_dir"
}
# build_libaribb24        # config_options+= --enable-libaribb24          # enable ARIB text and caption decoding via libaribb24 [no]
build_libaribb24() {
  if [[ $disable_libaribb24 != 1 && $enable_libaribb24 == 1 ]]; then
  build_libpng
  local lib="libaribb24"
  local repo_ver="v1.0.3"
  local repo="https://github.com/nkoriyama/aribb24"
  change_dir "$src_dir"
  do_git_checkout_and_make_install "$repo" "$lib" "$repo_ver"
  change_dir "$src_dir"
  fi
}
# build_libaribcaption    # config_options+= --enable-libaribcaption      # enable ARIB text and caption decoding via libaribcaption [no]
build_libaribcaption() {
  if [[ $disable_libaribcaption != 1 && $enable_libaribcaption == 1 ]]; then
  build_libfontconfig
  local lib="libaribcaption"
  local repo_ver="v1.1.1"
  local repo="https://github.com/xqq/libaribcaption"
  change_dir "$src_dir"
  do_git_checkout "$repo" "$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  do_cmake_and_install "-DBUILD_TESTS=OFF -DBUILD_EXAMPLES=OFF"
  change_dir "$src_dir"
  fi
}
# build_libass            # config_options+= --enable-libass              # enable libass subtitles rendering, needed for subtitles and ass filter [no]
build_libass() {
  if [[ $disable_libass != 1 && $enable_libass == 1 ]]; then
  build_libfribidi
  build_libharfbuzz
  local lib="libass"
  local repo="https://github.com/libass/libass"
  local repo_ver="0.17.4"
  do_git_checkout_and_make_install "$repo" "$lib" "$repo_ver"
  fi
}
# build_libbluray         # config_options+= --enable-libbluray           # enable BluRay reading using libbluray [no]
build_libbluray() {
  if [[ $disable_libbluray != 1 && $enable_libbluray == 1 ]]; then
  local lib="libbluray"
  local repo="https://code.videolan.org/videolan/libbluray"
  local repo_ver="1.4.0"
  activate_meson
  change_dir "$src_dir"
  do_git_checkout "$repo" "$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  local meson_options="--prefix=$dependency_install_prefix -Ddefault_library=static -Denable_examples=false -Dbdj_jar=disabled --wrap-mode=default"
  do_meson "$meson_options" "setup build"
  do_ninja_and_ninja_install
  change_dir "$src_dir"
  fi
}
# build_libbs2b           # config_options+= --enable-libbs2b             # enable bs2b DSP library [no]
build_libbs2b() {
  if [[ $disable_libbs2b != 1 && $enable_libbs2b == 1 ]]; then
  build_libsndfile
  local lib="libbs2b"
  local repo="https://downloads.sourceforge.net/project/bs2b/libbs2b/3.1.0/libbs2b-3.1.0.tar.gz"
  local repo_ver="3.1.0"
  change_dir "$src_dir"
  download_and_unpack_file "$repo" "$lib"
  change_dir "$src_dir/$lib"
  sed -i.bak "s/AC_FUNC_MALLOC//" configure.ac # #270
	export LIBS=-lm                              # avoid pow failure linux native
  export CFLAGS="$CFLAGS -I${dependency_install_prefix}/include"
  export CXXFLAGS=" $CXXFLAGS -I${dependency_install_prefix}/include"
  export LDFLAGS="$LDFLAGS -L${dependency_install_prefix}/lib"
	generic_configure_make_install
	unset LIBS CFLAGS CXXFLAGS LDFLAGS
	change_dir "$src_dir"
  fi
}
# build_libcaca           # config_options+= --enable-libcaca             # enable textual display using libcaca [no]
build_libcaca() {
  if [[ $disable_libcaca != 1 && $enable_libcaca == 1 ]]; then
  local lib="libcaca"
  local repo_ver="v0.99.beta20"
  local repo="https://github.com/cacalabs/libcaca"
  change_dir "$src_dir"
  do_git_checkout "$repo" "$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  generic_configure "--libdir=$dependency_install_prefix/lib --disable-csharp --disable-java --disable-cxx --disable-python --disable-ruby --disable-doc --disable-cocoa --disable-ncurses"
	do_make_and_make_install
	change_dir "$src_dir"
  fi
}
# build_libcdio           # config_options+= --enable-libcdio             # enable audio CD grabbing with libcdio [no]
build_libcdio() {
  if [[ $disable_libcdio != 1 && $enable_libcdio == 1 ]]; then
  local lib="libcdio"
  local repo_ver="2.2.0"
  local repo="https://github.com/libcdio/libcdio"
  change_dir "$src_dir"
  do_git_checkout "$repo" "$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  if [[ ! -f "configure" ]]; then
    autoreconf -fiv || exit_message 1
  fi
  generic_configure "--disable-vcd-info --disable-cddb --disable-example-progs MAKEINFO=true"
  for prog in cd-drive cd-info cd-read iso-info iso-read mmc-tool; do
    touch src/"$prog".1
  done
  do_make_and_make_install
  change_dir "$src_dir"
  fi
}
# build_libcelt           # config_options+= --enable-libcelt             # enable CELT decoding via libcelt [no]
build_libcelt() {
  if [[ $disable_libcelt != 1 && $enable_libcelt == 1 ]]; then
  local lib="libcelt"
  echo -e "The celt codec design and implementation have been merged into
the IETF Codec Working Group's \"Opus\" codec. As such, this
repository is no longer under active development.

Please see https://git.xiph.org/?p=opus
and https://git.xiph.org/?p=users/jm/opus-tools.git for more
current work. Visit http://opus-codec.org/ for more
information.

We apologize for any inconvenience this has caused.
"
		# https://github.com/xiph/opus
  fi
}
# build_libcodec2         # config_options+= --enable-libcodec2           # enable codec2 en/decoding using libcodec2 [no]
build_libcodec2() {
  if [[ $disable_libcodec2 != 1 && $enable_libcodec2 == 1 ]]; then
  local lib="libcodec2"
  local repo_ver="1.2.0"
  local repo="https://github.com/drowe67/codec2"
  change_dir "$src_dir"
  do_git_checkout "$repo" "$lib" "$repo_ver"
  change_dir "$src_dir/$lib/build" 1
  do_cmake_from_build_dir "$src_dir/$lib" "-DUNITTEST=FALSE"
	do_make_and_make_install
	change_dir "$src_dir"
  fi
}
# build_libdav1d          # config_options+= --enable-libdav1d            # enable AV1 decoding via libdav1d [no]
build_libdav1d() {
  if [[ $disable_libdav1d != 1 && $enable_libdav1d == 1 ]]; then
  local lib="libdav1d"
  local repo_ver="1.5.2"
  local repo="https://code.videolan.org/videolan/dav1d"
  activate_meson
  change_dir "$src_dir"
  do_git_checkout "$repo" "$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  local meson_options="--prefix=$dependency_install_prefix -Ddefault_library=static -Denable_tools=false -Denable_examples=false -Denable_tests=false"
  do_meson "$meson_options" "setup build"
  do_ninja_and_ninja_install
  change_dir "$src_dir"
  fi
}
# build_libdavs2          # config_options+= --enable-libdavs2            # enable AVS2 decoding via libdavs2 [no]
build_libdavs2() {
  if [[ $disable_libdavs2 != 1 && $enable_libdavs2 == 1 ]]; then
  local lib="davs2"
  local repo_ver="1.7"
  local repo="https://github.com/pkuvcl/davs2"
  change_dir "$src_dir"
  do_git_checkout "$repo" "$lib" "$repo_ver"
  change_dir "$src_dir/$lib/build/linux"
  do_configure "--prefix=$dependency_install_prefix --enable-pic"
	do_make_and_make_install
	change_dir "$src_dir"
  fi
}
# build_libdvdnav         # config_options+= --enable-libdvdnav           # enable libdvdnav, needed for DVD demuxing [no]
build_libdvdnav() {
  if [[ $disable_libdvdnav != 1 && $enable_libdvdnav == 1 ]]; then
  build_libdvdread
  local lib="libdvdnav"
  local repo="http://dvdnav.mplayerhq.hu/releases/libdvdnav-4.2.1.tar.xz"
  change_dir "$src_dir"
  download_and_unpack_file "$repo" "$lib"  # 4.2.1. latest revision before 5.x series [?]
  change_dir "$src_dir/$lib"
  generic_configure_make_install
	sed -i.bak 's/-ldvdnav.*/-ldvdnav -ldvdread -ldvdcss -lpsapi/' "$dependency_install_prefix/lib/pkgconfig/dvdnav.pc" # psapi for dlfcn ... [hrm?]
	change_dir "$src_dir"
  fi
}
build_libdvdcss() {
	change_dir "$src_dir"
	generic_download_and_make_and_install https://download.videolan.org/pub/videolan/libdvdcss/1.2.13/libdvdcss-1.2.13.tar.bz2
  change_dir "$src_dir"
}
# build_libdvdread        # config_options+= --enable-libdvdread          # enable libdvdread, needed for DVD demuxing [no]
build_libdvdread() {
  if [[ $disable_libdvdread != 1 && $enable_libdvdread == 1 ]]; then
  build_libdvdcss
  local lib="libdvdread"
  local repo="http://dvdnav.mplayerhq.hu/releases/libdvdread-4.9.9.tar.xz" # last revision before 5.X series so still works with MPlayer
  change_dir "$src_dir"
  download_and_unpack_file "$repo" "$lib"  # 4.2.1. latest revision before 5.x series [?]
  change_dir "$src_dir/$lib"
  export CFLAGS="$CFLAGS -I${dependency_install_prefix}/include"
  export CXXFLAGS=" $CXXFLAGS -I${dependency_install_prefix}/include"
  export LDFLAGS="$LDFLAGS -L${dependency_install_prefix}/lib"
  generic_configure
	do_make_and_make_install
	sed -i.bak 's/-ldvdread.*/-ldvdread -ldvdcss/' "$dependency_install_prefix/lib/pkgconfig/dvdread.pc"
  change_dir "$src_dir"
  fi
}
# build_libflite          # config_options+= --enable-libflite            # enable flite (voice synthesis) support via libflite [no]
build_libflite() {
  if [[ $disable_libflite != 1 && $enable_libflite == 1 ]]; then
  local lib="flite"
  local repo="https://github.com/festvox/flite"
  local repo_ver="v2.2"
  change_dir "$src_dir"
  do_git_checkout "$repo" "$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  generic_configure_make_install
	change_dir "$src_dir"
  fi
}
# build_libfontconfig     # config_options+= --enable-libfontconfig       # enable libfontconfig, useful for drawtext filter [no]
build_libfontconfig() {
  if [[ $disable_libfontconfig != 1 && $enable_libfontconfig == 1 ]]; then
  build_libfreetype
  build_libxml2
  local lib="fontconfig"
  local repo="https://gitlab.freedesktop.org/fontconfig/fontconfig"
  local repo_ver="2.17.1"
  activate_meson
  change_dir "$src_dir"
  do_git_checkout "$repo" "$lib"
  change_dir "$src_dir/$lib"
  local meson_options="--prefix=$dependency_install_prefix -Ddefault_library=static -Ddoc=disabled -Diconv=enabled -Dtests=disabled -Dxml-backend=libxml2"
  do_meson "$meson_options" "setup build"
  do_ninja_and_ninja_install
  change_dir "$src_dir"
  fi
}
# build_libfreetype       # config_options+= --enable-libfreetype         # enable libfreetype, needed for drawtext filter [no]
build_libfreetype() {
  if [[ $disable_libfreetype != 1 && $enable_libfreetype == 1 ]]; then
  local lib="freetype"
  local repo="https://github.com/freetype/freetype"
  local repo_ver="VER-2-14-1"
  activate_meson
  change_dir "$src_dir"
  do_git_checkout "$repo" "$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  local meson_options="--prefix=$dependency_install_prefix -Ddefault_library=static -Dtests=disabled -Dharfbuzz=disabled -Dpng=disabled -Dbzip2=disabled -Dzlib=disabled"
  do_meson "$meson_options" "setup build"
  do_ninja_and_ninja_install
  change_dir "$src_dir"
  fi
}
# build_libfribidi        # config_options+= --enable-libfribidi          # enable libfribidi, improves drawtext filter [no]
build_libfribidi() {
  if [[ $disable_libfribidi != 1 && $enable_libfribidi == 1 ]]; then
  local lib="fribidi"
  local repo="https://github.com/fribidi/fribidi"
  local repo_ver="v1.0.16"
  activate_meson
  change_dir "$src_dir"
  do_git_checkout "$repo" "$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  local meson_options="--prefix=$dependency_install_prefix -Ddefault_library=static -Ddeprecated=false -Ddocs=false -Dtests=false"
  do_meson "$meson_options" "setup build"
  do_ninja_and_ninja_install
	change_dir "$src_dir"
  fi
}
# build_libglslang        # config_options+= --enable-libglslang          # enable GLSL->SPIRV compilation via libglslang [no]
build_libglslang() {
  if [[ $disable_libglslang != 1 && $enable_libglslang == 1 ]]; then
  local parent_lib="libglslang"
  change_dir "$src_dir"
  local lib="SPIRV-Headers"
  local repo="https://github.com/KhronosGroup/SPIRV-Headers"
  local repo_ver="vulkan-sdk-1.4.328.1"
  change_dir "$src_dir/$parent_lib" 1
  do_git_checkout "$repo" "$lib" "$repo_ver"
  change_dir "$src_dir/$parent_lib/$lib"
  local cmake_params="-DCMAKE_INSTALL_PREFIX=${dependency_install_prefix} \
-DCMAKE_BUILD_TYPE=Release \
-DBUILD_SHARED_LIBS=OFF \
-DSPIRV_HEADERS_SKIP_EXAMPLES=ON"
  do_cmake_from_build_dir "$src_dir/$parent_lib/$lib" "$cmake_params"
  do_make_and_make_install
  local lib="SPIRV-Tools"
  local repo="https://github.com/KhronosGroup/SPIRV-Tools"
  local repo_ver="v2025.4"
  change_dir "$src_dir/$parent_lib"
  do_git_checkout "$repo" "$lib" "$repo_ver"
  change_dir "$src_dir/$parent_lib/$lib"
  local cmake_params="-DCMAKE_INSTALL_PREFIX=${dependency_install_prefix} \
-DCMAKE_BUILD_TYPE=Release \
-DBUILD_SHARED_LIBS=OFF \
-DSPIRV_SKIP_TESTS=ON \
-DSPIRV_WERROR=OFF \
-DSPIRV_SKIP_EXECUTABLES=ON \
-DSPIRV-Headers_SOURCE_DIR=${dependency_install_prefix}"
  do_cmake_from_build_dir "$src_dir/$parent_lib/$lib" "$cmake_params"
  do_make_and_make_install
  local lib="glslang"
  local repo="https://github.com/KhronosGroup/glslang"
  local repo_ver="Release 16.1.0"
  change_dir "$src_dir/$parent_lib"
  do_git_checkout "$repo" "$lib" "$repo_ver"
  change_dir "$src_dir/$parent_lib/$lib"
  local cmake_params="-DCMAKE_INSTALL_PREFIX=${dependency_install_prefix} \
-DCMAKE_BUILD_TYPE=Release \
-DBUILD_SHARED_LIBS=OFF \
-DENABLE_OPT=ON \
-DENABLE_HLSL=ON \
-DBUILD_TESTING=OFF \
-DENABLE_GLSLANG_BINARIES=OFF \
-DGLSLANG_TESTS=OFF \
-DALLOW_EXTERNAL_SPIRV_TOOLS=ON \
-DCMAKE_PREFIX_PATH=${dependency_install_prefix}"
  do_cmake_from_build_dir "$src_dir/$parent_lib/$lib" "$cmake_params"
  do_make_and_make_install
  cat > "${dependency_install_prefix}/lib/pkgconfig/glslang.pc" <<EOF
prefix=${dependency_install_prefix}
exec_prefix=\${prefix}
libdir=\${prefix}/lib
includedir=\${prefix}/include

Name: glslang
Description: Khronos glslang validator and generator
Version: 16.1.0
Requires:
Libs: -L\${libdir} -lglslang -lMachineIndependent -lGenericCodeGen -lOSDependent -lSPIRV -lSPVRemapper -lSPIRV-Tools-opt -lSPIRV-Tools -lstdc++
Cflags: -I\${includedir}
EOF
  change_dir "$src_dir"
  fi
}
# build_libgme            # config_options+= --enable-libgme              # enable Game Music Emu via libgme [no]
build_libgme() {
  if [[ $disable_libgme != 1 && $enable_libgme == 1 ]]; then
  local lib="libgme"
  local repo="https://bitbucket.org/mpyne/game-music-emu/downloads/game-music-emu-0.6.3.tar.xz"
  download_and_unpack_file "$repo" "$lib"
  change_dir "$src_dir/$lib"
	do_cmake_and_install "-DENABLE_UBSAN=0"
	change_dir "$src_dir"
  fi
}
build_libsndfile() {
  local lib="libsndfile"
  local repo="https://github.com/libsndfile/libsndfile"
  local repo_ver="1.2.2"
	change_dir "$src_dir"
	do_git_checkout "$repo" "$lib" "$repo_ver"
	change_dir "$src_dir/$lib"
	generic_configure "--disable-sqlite --disable-external-libs --disable-full-suite"
	do_make_and_make_install
	change_dir "$src_dir"
}
# build_libgsm            # config_options+= --enable-libgsm              # enable GSM de/encoding via libgsm [no]
build_libgsm() {
  if [[ $disable_libgsm != 1 && $enable_libgsm == 1 ]]; then
  build_libsndfile
  local lib="libsndfile"
  local repo="https://github.com/libsndfile/libsndfile"
  local repo_ver="1.2.2"
  change_dir "$src_dir/$lib"
  if [[ ! -f $dependency_install_prefix/lib/libgsm.a ]]; then
		install -m644 src/GSM610/gsm.h "$dependency_install_prefix/include/gsm.h" || exit_message 1 "could not install src/GSM610/gsm.h"
		install -m644 src/GSM610/.libs/libgsm.a "$dependency_install_prefix/lib/libgsm.a" || exit_message 1 "could not install src/GSM610/.libs/libgsm.a"
	else
		echo -e "already installed GSM 6.10 ..."
	fi
  change_dir "$src_dir"
  fi
}
# build_libharfbuzz       # config_options+= --enable-libharfbuzz         # enable libharfbuzz, needed for drawtext filter [no]
build_libharfbuzz() {
  if [[ $disable_libharfbuzz != 1 && $enable_libharfbuzz == 1 ]]; then
  local lib="harfbuzz"
  local repo_ver="10.4.0"
  local repo="https://github.com/harfbuzz/harfbuzz"
  activate_meson
  change_dir "$src_dir"
  do_git_checkout "$repo" "$lib" "$repo_ver" # 11.0.0 no longer found by ffmpeg via this method, multiple issues, breaks harfbuzz freetype circular depends hack
  change_dir "$src_dir/$lib"
  local meson_options="--prefix=$dependency_install_prefix -Dglib=disabled -Dgobject=disabled -Dcairo=disabled -Dicu=disabled -Dtests=disabled -Dintrospection=disabled -Ddocs=disabled"
  do_meson "$meson_options" "setup build"
  do_ninja_and_ninja_install
	change_dir "$src_dir"
  fi
}
# build_libilbc           # config_options+= --enable-libilbc             # enable iLBC de/encoding via libilbc [no]
build_libilbc() {
  if [[ $disable_libilbc != 1 && $enable_libilbc == 1 ]]; then
  local lib="libilbc"
  local repo="https://github.com/TimothyGu/libilbc"
  local repo_ver="v3.0.4"
  do_git_checkout "$repo" "$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
	do_cmake_and_install "-DENABLE_UBSAN=0"
	change_dir "$src_dir"
  fi
}

build_tre() {
# https://github.com/laurikari/tre
  local lib="tre"
  local repo="https://github.com/laurikari/tre"
  local repo_ver="TRE 0.9.0"
  change_dir "$src_dir"
  do_git_checkout "$repo" "$lib" "$repo_ver" # meson build for fontconfig no good
  change_dir "$src_dir/$lib"
  generic_configure_make_install "--disable-nls"
  change_dir "$src_dir"
}

build_portaudio() {
# https://github.com/PortAudio/portaudio
  local lib="portaudio"
  local repo="https://github.com/PortAudio/portaudio"
  local repo_ver="v19.7.0"
  change_dir "$src_dir"
  do_git_checkout "$repo" "$lib" "$repo_ver"  # meson build for fontconfig no good
  change_dir "$src_dir/$lib"
  if [[ ! -d "$src_dir/$lib/opt/asiosdk/common" ]]; then
    download_and_unpack_file "https://download.steinberg.net/sdk_downloads/ASIO-SDK_2.3.4_2025-10-15.zip" "ASIOSDK"
    create_dir "opt"
    mv -f "ASIOSDK" "opt/asiosdk"
  fi
  change_dir "$src_dir/$lib"
  generic_configure_make_install "--with-asiodir=$src_dir/$lib/opt/asiosdk"
  change_dir "$src_dir"
}
# build_libjack           # config_options+= --enable-libjack             # enable JACK audio sound server [no]
build_libjack() {
  if [[ $disable_libjack != 1 && $enable_libjack == 1 ]]; then
  # https://github.com/jackaudio/jack2
  #build_tre
  #build_portaudio
  local lib="libjack"
  local repo="https://github.com/jackaudio/jack2"
  local repo_ver="v19.7.0"
  change_dir "$src_dir"
  do_git_checkout "$repo" "$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  export CFLAGS="-static -O3 -I$dependency_install_prefix/include -L$dependency_install_prefix/lib"
  export CXXFLAGS="-static -O3 -I$dependency_install_prefix/include -L$dependency_install_prefix/lib"
  sed -i "/opt.load('xcode6')/d" wscript
  sed -i "/conf.load('xcode6')/d" wscript
  do_python '--prefix="$dependency_install_prefix" --platform="$host_name" --db="no" --check-c-compiler=gcc --check-cxx-compiler=g++ --static'
  do_python "" "./waf build -v"
  do_python "" "./waf install -v"
  fi
}
# build_libjxl            # config_options+= --enable-libjxl              # enable JPEG XL de/encoding via libjxl [no]
build_libjxl() {
  if [[ $disable_libjxl != 1 && $enable_libjxl == 1 ]]; then
  local lib="libjxl"
  local repo="https://github.com/libjxl/libjxl"
  local repo_ver="v0.7.2"
  change_dir "$src_dir"
  do_git_checkout "$repo" "$lib" "$repo_ver"
  change_dir "$src_dir/$lib/build" 1
  local cmake_params="-DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF"
	do_cmake_from_build_dir "$src_dir/$lib" "$cmake_params"
	do_make_and_make_install
	change_dir "$src_dir"
  fi
}
# build_libklvanc         # config_options+= --enable-libklvanc           # enable Kernel Labs VANC processing [no]
build_libklvanc() {
  if [[ $disable_libklvanc != 1 && $enable_libklvanc == 1 ]]; then
  local lib="libklvanc"
  local repo="https://github.com/stoth68000/libklvanc"
  local repo_ver="vid.obe.1.6.0"
  change_dir "$src_dir"
  do_git_checkout "$repo" "$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  generic_configure_make_install "--enable-static \
--disable-shared \
--disable-examples"
cat > "${dependency_install_prefix}/lib/pkgconfig/libklvanc.pc" <<EOF
prefix=${dependency_install_prefix}
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: libklvanc
Description: VANC processing library
Version: 1.6.0
Libs: -L\${libdir} -lklvanc
Libs.private: -lz
Cflags: -I\${includedir}
EOF
  change_dir "$src_dir"
  fi
}
# build_libkvazaar        # config_options+= --enable-libkvazaar          # enable HEVC encoding via libkvazaar [no]
build_libkvazaar() {
  if [[ $disable_libkvazaar != 1 && $enable_libkvazaar == 1 ]]; then
  local lib="libkvazaar"
  local repo="https://github.com/ultravideo/kvazaar"
  local repo_ver="v2.3.2"
  change_dir "$src_dir"
  do_git_checkout "$repo" "$lib" "$repo_ver"
  change_dir "$src_dir/$lib/build" 1
	local cmake_params="-DCMAKE_BUILD_TESTS=OFF"
	do_cmake_from_build_dir "$src_dir/$lib" "$cmake_params"
	do_make_and_make_install
	change_dir "$src_dir"
  fi
}
# build_liblc3            # config_options+= --enable-liblc3              # enable LC3 de/encoding via liblc3 [no]
build_liblc3() {
  if [[ $disable_liblc3 != 1 && $enable_liblc3 == 1 ]]; then
  local lib="liblc3"
  local repo="https://github.com/google/liblc3"
  local repo_ver="v1.1.3"
  activate_meson
  change_dir "$src_dir"
  do_git_checkout "$repo" "$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
	generic_meson "-Dtools=false -Dpython=false"
	change_dir "$src_dir/$lib/build"
	do_meson "" "install"
	change_dir "$src_dir"
  fi
}
build_gettext() {
  local lib="liblc3"
  local repo="https://ftp.gnu.org/pub/gnu/gettext/gettext-0.26.tar.gz"
	change_dir "$src_dir"
	generic_download_and_make_and_install "$repo" "$lib"
	change_dir "$src_dir"
}
build_libffi() {
  local lib="libffi"
  local repo="https://github.com/libffi/libffi/releases/download/v3.5.2/libffi-3.5.2.tar.gz"
	change_dir "$src_dir"
	generic_download_and_make_and_install "$repo" "$lib"
	change_dir "$src_dir"
}
build_glib() {
	build_gettext
	build_libffi
  local lib="glib"
  local repo="https://github.com/GNOME/glib"
	change_dir "$src_dir"
	do_git_checkout "$repo" "$lib"
	activate_meson
	change_dir "$src_dir/$lib"
	local meson_options="--prefix=$dependency_install_prefix -Ddefault_library=static --force-fallback-for=libpcre -Dforce_posix_threads=true -Dman-pages=disabled -Dsysprof=disabled -Dglib_debug=disabled -Dtests=false --wrap-mode=default"
	do_meson "$meson_options" "setup build"
	do_ninja_and_ninja_install
	sed -i.bak 's/-lglib-2.0.*$/-lglib-2.0 -lintl -lm -liconv/' "${dependency_install_prefix}/lib/pkgconfig/glib-2.0.pc"
	deactivate
	change_dir "$src_dir"
}
# build_liblensfun        # config_options+= --enable-liblensfun          # enable lensfun lens correction [no]
build_liblensfun() {
  if [[ $disable_liblensfun != 1 && $enable_liblensfun == 1 ]]; then
  build_glib
  local lib="liblensfun"
  local repo="https://github.com/lensfun/lensfun"
  local repo_ver="v0.3.4"
  change_dir "$src_dir"
  do_git_checkout "$repo" "$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  export CPPFLAGS="$CPPFLAGS -DGLIB_STATIC_COMPILATION"
	export CXXFLAGS="$CFLAGS -DGLIB_STATIC_COMPILATION"
  do_cmake "-DBUILD_STATIC=on -DCMAKE_INSTALL_DATAROOTDIR=$dependency_install_prefix -DBUILD_TESTS=off -DBUILD_DOC=off -DINSTALL_HELPER_SCRIPTS=off -DINSTALL_PYTHON_MODULE=OFF"
	do_make_and_make_install
	sed -i.bak 's/-llensfun/-llensfun -lstdc++/' "$PKG_CONFIG_PATH/lensfun.pc"
	reset_cppflags
	reset_cxxflags
	change_dir "$src_dir"
  fi
}
# build_libmodplug        # config_options+= --enable-libmodplug          # enable ModPlug via libmodplug [no]
build_libmodplug() {
  if [[ $disable_libmodplug != 1 && $enable_libmodplug == 1 ]]; then
  local lib="libmodplug"
  local repo="https://github.com/Konstanty/libmodplug"
  change_dir "$src_dir"
  do_git_checkout "$repo" "$lib"
  change_dir "$src_dir/$lib"
	generic_configure_make_install # or could use cmake I guess
  change_dir "$src_dir"
  fi
}
build_mpg123() {
  local lib="mpg123"
  local repo="https://sourceforge.net/projects/mpg123/files/mpg123/1.33.3/mpg123-1.33.3.tar.bz2/download"
  local repo_ver="r5008"
	change_dir "$src_dir"
	generic_download_and_make_and_install "$repo" "$lib"
	change_dir "$src_dir"
}
# build_libmp3lame        # config_options+= --enable-libmp3lame          # enable MP3 encoding via libmp3lame [no]
build_libmp3lame() {
  if [[ $disable_libmp3lame != 1 && $enable_libmp3lame == 1 ]]; then
  build_mpg123
  local lib="libmp3lame"
  local repo="https://sourceforge.net/projects/lame/files/lame/3.100/lame-3.100.tar.gz/download"
  local repo_ver="r6525"
  change_dir "$src_dir"
  generic_download_and_make_and_install "$repo" "$lib"
  change_dir "$src_dir"
  fi
}
# build_libmysofa         # config_options+= --enable-libmysofa           # enable libmysofa, needed for sofalizer filter [no]
build_libmysofa() {
  if [[ $disable_libmysofa != 1 && $enable_libmysofa == 1 ]]; then
  local lib="libmysofa"
  local repo="https://github.com/hoene/libmysofa"
  local repo_ver="latest"
  change_dir "$src_dir"
  do_git_checkout "$repo" "$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
	local cmake_params="-DBUILD_TESTS=0 -DMATH=m"
	do_cmake "$cmake_params"
	do_make_and_make_install
	change_dir "$src_dir"
  fi
}
# build_liboapv           # config_options+= --enable-liboapv             # enable APV encoding via liboapv [no]
build_liboapv() {
  if [[ $disable_liboapv != 1 && $enable_liboapv == 1 ]]; then
  local lib="liboapv"
  local repo="https://github.com/AcademySoftwareFoundation/openapv"
  local repo_ver="v0.2.0.4"
  change_dir "$src_dir"
  do_git_checkout "$repo" "$lib" "$repo_ver"
  change_dir "$src_dir/$lib/build" 1
	local cmake_params="-DCMAKE_BUILD_TYPE=Release \
-DOAPV_BUILD_APPS=ON \
-DOAPV_BUILD_STATIC_LIB=ON \
-DOAPV_BUILD_SHARED_LIB=ON \
-DOAPV_APP_STATIC_BUILD=ON"
	do_cmake_from_build_dir "$src_dir/$lib" "$cmake_params"
	do_make_and_make_install
	change_dir "$src_dir"
  fi
}
# build_libopencv         # config_options+= --enable-libopencv           # enable video filtering via libopencv [no]
build_libopencv() {
  if [[ $disable_libopencv != 1 && $enable_libopencv == 1 ]]; then
  build_vaapi
  local lib="libopencv"
  local repo="https://github.com/opencv/opencv/"
  local repo_ver="4.12.0"
  change_dir "$src_dir"
  do_git_checkout "$repo" "$lib" "$repo_ver"
  change_dir "$src_dir/$lib/build" 1
  export LDFLAGS="$LDFLAGS -L${ffmpeg_install_prefix}/lib -L${dependency_install_prefix}/lib -L${dependency_install_prefix}/lib/$host_target"
  do_cmake_from_build_dir "$src_dir/$lib" "-DWITH_FFMPEG=0 -DOPENCV_GENERATE_PKGCONFIG=1 -DHAVE_DSHOW=0"
  do_make_and_make_install
  reset_ldflags
  change_dir "$src_dir"
  fi
}
# build_libopenh264       # config_options+= --enable-libopenh264         # enable H.264 encoding via OpenH264 [no]
build_libopenh264() {
  if [[ $disable_libopenh264 != 1 && $enable_libopenh264 == 1 ]]; then
  local lib="libopenh264"
  local repo="https://github.com/cisco/openh264.git"
  local repo_ver="openh264 v2.6.0" #75b9fcd2669c75a99791 # wels/codec_api.h weirdness
  change_dir "$src_dir"
  do_git_checkout "$repo" "$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  if [[ $bits_target == 32 ]]; then
		local arch=i686 # or x86?
	else
		local arch=x86_64
	fi
  do_make "PREFIX=$dependency_install_prefix OS=linux ARCH=$arch ASM=yasm install-static"
  change_dir "$src_dir"
  fi
}
# build_libopenjpeg       # config_options+= --enable-libopenjpeg         # enable JPEG 2000 encoding via OpenJPEG [no]
build_libopenjpeg() {
  if [[ $disable_libopenjpeg != 1 && $enable_libopenjpeg == 1 ]]; then
  local lib="libopenjpeg"
  local repo="https://github.com/uclouvain/openjpeg"
  local repo_ver="v2.5.4"
  change_dir "$src_dir"
  do_git_checkout "$repo" "$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  do_cmake_and_install "-DOPJ_BIG_ENDIAN=0 -DBUILD_CODEC=0"
  change_dir "$src_dir"
  fi
}
build_libogg() {
  local lib="libogg"
  local repo="https://github.com/xiph/ogg"
  local repo_ver="v1.3.6"
	change_dir "$src_dir"
	do_git_checkout "$repo" "$lib" "$repo_ver"
  change_dir "$src_dir/$lib/build" 1
  do_cmake_from_build_dir "$src_dir/$lib" 
  do_make_and_make_install
	change_dir "$src_dir"
}
build_flac() {
  local lib="flac"
  local repo="https://github.com/xiph/flac"
  local repo_ver="1.5.0"
	change_dir "$src_dir"
	do_git_checkout "$repo" "$lib" "$repo_ver"
	change_dir "$src_dir/$lib"
	do_cmake "-B build -DBUILD_DOCS=OFF -DBUILD_TESTING=OFF -DBUILD_EXAMPLES=OFF -DBUILD_PROGRAMS=OFF -DBUILD_STATIC_LIBS=ON -DBUILD_SHARED_LIBS=OFF -DCMAKE_BUILD_TYPE=Release -DINSTALL_MANPAGES=OFF -GNinja"
	do_ninja_and_ninja_install
	change_dir "$src_dir"
}
# build_libopenmpt        # config_options+= --enable-libopenmpt          # enable decoding tracked files via libopenmpt [no]
build_libopenmpt() {
  if [[ $disable_libopenmpt != 1 && $enable_libopenmpt == 1 ]]; then
  build_zlib
  build_mpg123
  build_libogg
  build_libvorbis
  build_sdl2
  build_sdl12_compat
  build_libsndfile
  local lib="libopenmpt"
  #local repo="https://github.com/OpenMPT/openmpt" # doesnt work from git for some reason
  local repo="https://lib.openmpt.org/files/libopenmpt/src/libopenmpt-0.8.3+release.autotools.tar.gz"
  local repo_ver="libopenmpt-0.8.3"
  change_dir "$src_dir"
  download_and_unpack_file "$repo" "$lib"
  #do_git_checkout "$repo" "$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  export CFLAGS="$CFLAGS -I${dependency_install_prefix}/include"
  export CXXFLAGS="$CXXFLAGS -I${dependency_install_prefix}/include"
  export LDFLAGS="$LDFLAGS -L${dependency_install_prefix}/lib -L${dependency_install_prefix}/lib/${host_target}"
  generic_configure_make_install "--enable-shared=no --enable-static=yes --with-pic --without-pulseaudio --without-portaudiocpp --with-sdl2 --disable-openmpt123 --disable-examples --disable-tests --disable-doxygen-doc"
  reset_cflags
  reset_cxxflags
  reset_ldflags
  change_dir "$src_dir"
  fi
}
# build_libopenvino       # config_options+= --enable-libopenvino         # enable OpenVINO as a DNN module backend for DNN based filters like dnn_processing [no]
build_libopenvino() {
  if [[ $disable_libopenvino != 1 && $enable_libopenvino == 1 ]]; then
  local lib="libopenvino"
  local repo="https://github.com/openvinotoolkit/openvino"
  local repo_ver="2025.4.0"
  change_dir "$src_dir"
	do_git_checkout "$repo" "$lib" "$repo_ver"
	change_dir "$src_dir/$lib/build" 1
  do_cmake_from_build_dir "$src_dir/$lib" "-DCMAKE_INSTALL_PREFIX=$dependency_install_prefix \
-DCMAKE_BUILD_TYPE=Release \
-DBUILD_SHARED_LIBS=OFF \
-DENABLE_LTO=OFF \
-DENABLE_INTEL_CPU=ON \
-DENABLE_INTEL_GPU=OFF \
-DENABLE_INTEL_GNA=OFF \
-DENABLE_CLDNN=OFF \
-DENABLE_PLANARTRACE=OFF \
-DENABLE_INTEL_NPU=OFF \
-DENABLE_INTEL_VPU=OFF \
-DENABLE_OV_FRONTEND=OFF \
-DENABLE_PYTHON=OFF \
-DENABLE_SAMPLES=OFF \
-DENABLE_TESTS=OFF \
-DENABLE_CPPLINT=OFF \
-DENABLE_NCC_STYLE=OFF \
-DTHREADING=SEQ \
-DENABLE_SYSTEM_PUGIXML=OFF \
-DENABLE_SYSTEM_TBB=OFF \
-DENABLE_SYSTEM_OPENCL=OFF \
-DENABLE_OPENCV=OFF \
-DCMAKE_DISABLE_FIND_PACKAGE_OpenCV=ON"
  do_make_and_make_install
  change_dir "$src_dir"
  fi
}
# build_libopus           # config_options+= --enable-libopus             # enable Opus de/encoding via libopus [no]
build_libopus() {
  if [[ $disable_libopus != 1 && $enable_libopus == 1 ]]; then
  local lib="libopus"
  local repo="https://github.com/xiph/opus"
  local repo_ver="v1.5.2"
  change_dir "$src_dir"
  do_git_checkout "$repo" "$lib"
  change_dir "$src_dir/$lib"
	generic_configure_make_install "--enable-static --disable-shared"
  change_dir "$src_dir"
  fi
}
build_libunwind() {
  local lib="libunwind"
  local repo="https://github.com/libunwind/libunwind"
  local repo_ver="v1.8.3"
	change_dir "$src_dir"
	do_git_checkout "$repo" "$lib" "$repo_ver"
	change_dir "$src_dir/$lib"
	generic_configure_make_install "--disable-shared --enable-static"
	change_dir "$src_dir"
}
build_libxxhash() {
  local lib="libxxhash"
  local repo="https://github.com/Cyan4973/xxHash"
  local repo_ver="v0.8.3"
	change_dir "$src_dir"
	do_git_checkout "$repo" "$lib" "$repo_ver"
	change_dir "$src_dir/$lib"
	do_make_and_make_install "PREFIX=$dependency_install_prefix"
	change_dir "$src_dir"
}
build_spirv_cross() {
  local lib="SPIRV-Cross"
  local repo="https://github.com/KhronosGroup/SPIRV-Cross"
  local repo_ver="vulkan-sdk-1.4.328.1"
	change_dir "$src_dir"
	do_git_checkout "$repo" "$lib" "$repo_ver"
	change_dir "$src_dir/$lib"
	# TODO: Allow shared library build
	do_cmake "-B build -GNinja -DSPIRV_CROSS_STATIC=ON -DSPIRV_CROSS_SHARED=OFF -DCMAKE_BUILD_TYPE=Release -DSPIRV_CROSS_CLI=OFF -DSPIRV_CROSS_ENABLE_TESTS=OFF -DSPIRV_CROSS_FORCE_PIC=ON -DSPIRV_CROSS_ENABLE_CPP=OFF"
	do_ninja_and_ninja_install
	mv "$dependency_install_prefix/lib/pkgconfig/spirv-cross-c.pc" "$dependency_install_prefix/lib/pkgconfig/spirv-cross-c-shared.pc"
	change_dir "$src_dir"
}
build_libdovi() {
  local lib="libdovi"
  local repo="https://github.com/quietvoid/dovi_tool"
  local repo_ver="2.3.1"
	change_dir "$src_dir"
	do_git_checkout "$repo" "$lib" "$repo_ver"
	change_dir "$src_dir/$lib/dolby_vision"
	cargo_build_and_install "--release" "--package dolby_vision --release --library-type=staticlib"
	change_dir "$src_dir"
}
build_vulkan_loader() {
  local parentlib="vulkan-loader"
  local lib="Vulkan-Shim-Loader"
  local repo="https://github.com/BtbN/Vulkan-Shim-Loader"
	change_dir "$src_dir/$parentlib" 1
	do_git_checkout "$repo" "$lib"
	change_dir "$src_dir/$parentlib/$lib"
  local lib="Vulkan-Headers"
  local repo="https://github.com/KhronosGroup/Vulkan-Headers"
  local repo_ver="v1.4.326"
	do_git_checkout "$repo" "$lib" "$repo_ver"
	do_cmake_and_install "-DCMAKE_BUILD_TYPE=Release -DVULKAN_SHIM_IMPERSONATE=ON"
	change_dir "$src_dir"
}
# build_libplacebo        # config_options+= --enable-libplacebo          # enable libplacebo library [no]
build_libplacebo() {
  if [[ $disable_libplacebo != 1 && $enable_libplacebo == 1 ]]; then
  build_vulkan_loader
	build_lcms
	build_libunwind
	build_libxxhash
	build_spirv_cross
	build_libdovi
	build_libshaderc
  activate_meson
  local lib="libplacebo"
  local repo="https://code.videolan.org/videolan/libplacebo"
  local repo_ver="v7.351.0"
  change_dir "$src_dir"
  do_git_checkout "$repo" "$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  local config_options+=" -Dvulkan-registry=$dependency_install_prefix/share/vulkan/registry/vk.xml"
  local meson_options="-Ddefault_library=static -Ddemos=false -Dbench=false -Dfuzz=false -Dvulkan=enabled -Dvk-proc-addr=disabled -Dglslang=disabled -Dc_link_args=-static -Dcpp_link_args=-static $config_options" # https://mesonbuild.com/Dependencies.html#shaderc trigger use of shaderc_combined
	if [[ $disable_libshaderc != 1 && $enable_libshaderc == 1 ]]; then
    meson_options+=" -Dshaderc=enabled"
  else
    meson_options+=" -Dshaderc=disabled"
  fi
  do_meson "$meson_options" "setup build"
	do_ninja_and_ninja_install
	sed -i.bak 's/-lplacebo.*$/-lplacebo -lm -lunwind -lxxhash -lstdc++/' "$dependency_install_prefix/lib/pkgconfig/libplacebo.pc"
  fi
}
# build_libpulse          # config_options+= --enable-libpulse            # enable Pulseaudio input via libpulse [no]
build_libpulse() {
  if [[ $disable_libpulse != 1 && $enable_libpulse == 1 ]]; then
  build_iconv
  local lib="libpulse"
  local repo="https://github.com/pulseaudio/pulseaudio"
  local repo_ver="v17.0"
  activate_meson
  change_dir "$src_dir"
  do_git_checkout "$repo" "$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  remove_path -rf "$src_dir/$lib/build"
  if [[ ! -f "$src_dir/$lib/.tarball-version" ]]; then
    echo "17.0" > "$src_dir/$lib/.tarball-version"
  fi
  export CFLAGS="$CFLAGS -I${dependency_install_prefix}/include"
  export LDFLAGS="$LDFLAGS -L${dependency_install_prefix}/lib -L${dependency_install_prefix}/lib/${host_target}"
  export LIBS="-liconv"
  local meson_options="-Dprefix=$dependency_install_prefix \
-Dlibdir=$dependency_install_prefix/lib \
-Dtests=false \
-Ddoxygen=false \
-Dman=false \
-Ddatabase=simple \
-Dglib=disabled \
-Dgtk=disabled \
-Dx11=disabled \
-Dopenssl=disabled \
-Dbluez5=disabled \
-Dudev=disabled \
-Dsystemd=disabled \
-Ddaemon=false \
-Ddefault_library=static \
--unity=off \
--warnlevel=0 \
-Dc_link_args=\"-liconv -L${dependency_install_prefix}/lib\" "
  do_meson "$meson_options" "setup build"
  do_ninja_and_ninja_install
  change_dir "$src_dir"
  fi
}
# build_libqrencode       # config_options+= --enable-libqrencode         # enable QR encode generation via libqrencode [no]
build_libqrencode() {
  if [[ $disable_libqrencode != 1 && $enable_libqrencode == 1 ]]; then
  local lib="libqrencode"
  local repo="https://github.com/fukuchi/libqrencode"
  local repo_ver="v4.1.1"
  change_dir "$src_dir"
	do_git_checkout "$repo" "$lib" "$repo_ver"
	change_dir "$src_dir/$lib/build" 1
	local cmake_params="-DCMAKE_BUILD_TYPE=Release \
-DWITH_TOOLS=NO \
-DWITH_TESTS=NO \
-DWITHOUT_PNG=YES \
-DBUILD_SHARED_LIBS=NO"
	do_cmake_from_build_dir "$src_dir/$lib" "$cmake_params"
	do_make_and_make_install
	change_dir "$src_dir"
  fi
}
# build_libquirc          # config_options+= --enable-libquirc            # enable QR decoding via libquirc [no]
build_libquirc() {
  if [[ $disable_libquirc != 1 && $enable_libquirc == 1 ]]; then
  local lib="libquirc"
  local repo="https://github.com/dlbeer/quirc"
  local repo_ver="master"
	change_dir "$src_dir"
	do_git_checkout "$repo" "$lib" "$repo_ver"
	create_dir "$src_dir/$lib/build"
  # path to remove demo app build because it requires some unnecessary dependencies
	if git apply --reverse --check --ignore-space-change --ignore-whitespace --verbose "$PATCHDIR/libquirc_Makefile.patch" >/dev/null 2>&1; then
    echo "INFO: Patch already applied. Skipping."
	else
		echo "INFO: Applying patch to remove demo app..."
		copy_path "Makefile" "Makefile.bak"
		git apply --ignore-space-change --ignore-whitespace --verbose "$PATCHDIR/libquirc_Makefile.patch" > >(redirect_output) 2>&1 || exit_message 1 "unable to patch makefile"
	fi
	do_make_and_make_install "libquirc.a LDFLAGS=\"-static\" PREFIX=${dependency_install_prefix}" "PREFIX=${dependency_install_prefix}"
	change_dir "$src_dir"
  fi
}
# build_librabbitmq       # config_options+= --enable-librabbitmq         # enable RabbitMQ library [no]
build_librabbitmq() {
  if [[ $disable_librabbitmq != 1 && $enable_librabbitmq == 1 ]]; then
  local lib="librabbitmq"
  local repo="https://github.com/alanxz/rabbitmq-c"
  local repo_ver="v0.15.0"
  change_dir "$src_dir"
  do_git_checkout "$repo" "$lib" "$repo_ver" 
  change_dir "$src_dir/$lib"
  local cmake_params="-DCMAKE_BUILD_TYPE=Release \
-DBUILD_SHARED_LIBS=OFF \
-DBUILD_STATIC_LIBS=ON \
-DBUILD_EXAMPLES=OFF \
-DBUILD_TESTING=OFF \
-DBUILD_TOOLS=OFF \
-DBUILD_API_DOCS=OFF \
-DENABLE_SSL_SUPPORT=OFF \
-DCMAKE_INSTALL_PREFIX=${dependency_install_prefix}"
  do_cmake_from_build_dir "$src_dir/$lib" "$cmake_params"
  do_make_and_make_install
  change_dir "$src_dir"
  fi
}
# build_librav1e          # config_options+= --enable-librav1e            # enable AV1 encoding via rav1e [no]
build_librav1e() {
  if [[ $disable_librav1e != 1 && $enable_librav1e == 1 ]]; then
  # https://github.com/xiph/rav1e
  local lib="librav1e"
  local repo="https://github.com/xiph/rav1e"
  local repo_ver="v0.8.1"
  change_dir "$src_dir"
  do_git_checkout "$repo" "$lib" "$repo_ver" 
  change_dir "$src_dir/$lib"
  cargo_build_and_install "--no-default-features --features=asm,binaries --profile release-no-lto" "--no-default-features --library-type=staticlib --features=asm,binaries"
  change_dir "$src_dir"
  fi
}
# build_librist           # config_options+= --enable-librist             # enable RIST via librist [no]
build_librist() {
  if [[ $disable_librist != 1 && $enable_librist == 1 ]]; then
  # https://code.videolan.org/rist/librist
  local lib="librist"
  local repo="https://code.videolan.org/rist/librist"
  local repo_ver="v0.2.11"
  activate_meson
  change_dir "$src_dir"
  do_git_checkout "$repo" "$lib" "$repo_ver" 
  change_dir "$src_dir/$lib"
  local meson_options="-Duse_mbedtls=true -Dbuilt_tools=false -Dtest=false"
  generic_meson "$meson_options"
	do_ninja_and_ninja_install
  change_dir "$src_dir"
  fi
}
build_pixman() {
 	# https://gitlab.freedesktop.org/pixman/pixman
	local lib="pixman"
  local repo="https://gitlab.freedesktop.org/pixman/pixman"
  local repo_ver="pixman-0.46.4"
  activate_meson
	change_dir "$src_dir"
	do_git_checkout "$repo" "$lib" "$repo_ver"
	change_dir "$src_dir/$lib"
	local meson_options="-Dtests=disabled -Ddemos=disabled"
	generic_meson "$meson_options"
	change_dir "$src_dir/$lib/build" 1
	do_meson "" "install"
	change_dir "$src_dir"
}
build_cairo() {
 	# https://gitlab.freedesktop.org/cairo/cairo
	local lib="cairo"
  local repo="https://gitlab.freedesktop.org/cairo/cairo"
  local repo_ver="1.18.4"
  activate_meson
	change_dir "$src_dir"
	do_git_checkout "$repo" "$lib" "$repo_ver"
	change_dir "$src_dir/$lib"
	local meson_options="-Dtests=disabled -Dgtk_doc=false"
	generic_meson "$meson_options"
	change_dir "$src_dir/$lib/build" 1
	do_meson "" "install"
	change_dir "$src_dir"
}
build_pango() {
  build_harfbuzz
  build_freetype
  build_libfontconfig
 	# https://gitlab.gnome.org/GNOME/pango
	local lib="pango"
  local repo="https://gitlab.gnome.org/GNOME/pango"
  local repo_ver="1.57.0"
  activate_meson
	change_dir "$src_dir"
	do_git_checkout "$repo" "$lib" "$repo_ver"
	change_dir "$src_dir/$lib"
	local meson_options="-Ddocumentation=false \
-Dgtk_doc=false \
-Dman-pages=false \
-Dbuild-testsuite=false \
-Dbuild-examples=false \
-Dintrospection=disabled \
-Dxft=disabled \
-Dc_args=\"-DGLIB_STATIC_COMPILATION\" \
-Dcpp_args=\"-DGLIB_STATIC_COMPILATION\""
  # disable tools - not needed for ffmpeg
  sed -i "s/subdir('utils')/# subdir('utils')/g" meson.build
	meson_options+=" --libdir=$dependency_install_prefix/lib"
	generic_meson "$meson_options"
	change_dir "$src_dir/$lib/build" 1
	do_meson "" "install"
	change_dir "$src_dir"
}
# build_librsvg           # config_options+= --enable-librsvg             # enable SVG rasterization via librsvg [no]
build_librsvg() {
  if [[ $disable_librsvg != 1 && $enable_librsvg == 1 ]]; then
  build_pixman
  build_cairo
  build_pango
  # 	# https://github.com/GNOME/librsvg
  local lib="librsvg"
  local repo="https://gitlab.gnome.org/GNOME/librsvg"
  local repo_ver="2.61.3"
  activate_meson
	change_dir "$src_dir"
	do_git_checkout "$repo" "$lib" "$repo_ver"
	change_dir "$src_dir/$lib"
	local meson_options="-Ddocs=disabled \
-Dintrospection=disabled \
-Dvala=disabled \
-Davif=disabled \
-Dpixbuf-loader=disabled \
-Dtests=false \
-Drsvg-convert=disabled \
-Dtriplet=$rust_target \
-Dc_args=\"-DGLIB_STATIC_COMPILATION\" \
-Dcpp_args=\"-DGLIB_STATIC_COMPILATION\""
	generic_meson "$meson_options"
	change_dir "$src_dir/$lib/build" 1
	do_meson "" "install"
	change_dir "$src_dir"
  fi
}
# build_librtmp           # config_options+= --enable-librtmp             # enable RTMP[E] support via librtmp [no]
build_librtmp() {
  if [[ $disable_librtmp != 1 && $enable_librtmp == 1 ]]; then
  # https://github.com/mirror/rtmpdump
  local lib="librtmp"
  local repo="git://git.ffmpeg.org/rtmpdump"
  local repo_ver="2.6"
  activate_meson
	change_dir "$src_dir"
	do_git_checkout "$repo" "$lib" "$repo_ver"
	change_dir "$src_dir/$lib"
  do_make "SHARED= INC=\"-I$dependency_install_prefix/include\" LDFLAGS=\"-L$dependency_install_prefix/lib -L${dependency_install_prefix}/lib/${host_target} --static\" prefix=${dependency_install_prefix}"
  do_make_install "SHARED= prefix=${dependency_install_prefix}"
  change_dir "$src_dir"
  fi
}
# build_librubberband     # config_options+= --enable-librubberband       # enable rubberband needed for rubberband filter [no]
build_librubberband() {
  if [[ $disable_librubberband != 1 && $enable_librubberband == 1 ]]; then
  local lib="librubberband"
  local repo="https://github.com/breakfastquay/rubberband"
  local repo_ver="v4.0.0"
  activate_meson
  change_dir "$src_dir"
	do_git_checkout "$repo" "$lib" "$repo_ver"
	change_dir "$src_dir/$lib"
  local meson_options="-Dtests=disabled"
	generic_meson "$meson_options"
	do_ninja_and_ninja_install
	change_dir "$src_dir"
  fi
}
# build_libshaderc        # config_options+= --enable-libshaderc          # enable GLSL->SPIRV compilation via libshaderc [no]
build_libshaderc() {
  if [[ $disable_libshaderc != 1 && $enable_libshaderc == 1 ]]; then
  local lib="libshaderc"
  local repo="https://github.com/google/shaderc"
  local repo_ver="v2025.5"
  change_dir "$src_dir"
  do_git_checkout "$repo" "$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  ./utils/git-sync-deps > >(redirect_output) 2>&1
	# TODO: Allow shared library build
	do_cmake "-B build -DCMAKE_BUILD_TYPE=release -GNinja -DSHADERC_SKIP_EXAMPLES=ON -DSHADERC_SKIP_TESTS=ON -DSPIRV_SKIP_TESTS=ON -DSHADERC_SKIP_COPYRIGHT_CHECK=ON -DENABLE_EXCEPTIONS=ON -DENABLE_GLSLANG_BINARIES=OFF -DSPIRV_SKIP_EXECUTABLES=ON -DSPIRV_TOOLS_BUILD_STATIC=ON -DBUILD_SHARED_LIBS=OFF"
	do_ninja_and_ninja_install
	cp -fv build/libshaderc_util/libshaderc_util.a "$dependency_install_prefix/lib" > >(redirect_output) 2>&1
	sed -i.bak "s/Libs: .*/& -lstdc++/" "$dependency_install_prefix/lib/pkgconfig/shaderc_combined.pc"
	sed -i.bak "s/Libs: .*/& -lstdc++/" "$dependency_install_prefix/lib/pkgconfig/shaderc_static.pc"
	change_dir "$src_dir"
  fi
}
# build_libshine          # config_options+= --enable-libshine            # enable fixed-point MP3 encoding via libshine [no]
build_libshine() {
  if [[ $disable_libshine != 1 && $enable_libshine == 1 ]]; then
  local lib="libshine"
  local repo="https://github.com/toots/shine"
  local repo_ver="3.1.1" 
  change_dir "$src_dir"
  do_git_checkout "$repo" "$lib" "$repo_ver"
	change_dir "$src_dir/$lib"
	generic_configure_make_install
	change_dir "$src_dir"
  fi
}
# build_libsmbclient      # config_options+= --enable-libsmbclient        # enable Samba protocol via libsmbclient [no]
build_libsmbclient() {
  if [[ $disable_libsmbclient != 1 && $enable_libsmbclient == 1 ]]; then
  local lib="libsmbclient"
  # https://git.samba.org/samba https://gitlab.com/samba-team/samba https://github.com/samba-team/samba https://www.samba.org/
  # best to just install locally as its a large library with a lot of dependencies https://wiki.samba.org/index.php/Distribution-specific_Package_Installation
  apt-get install acl attr samba winbind libpam-winbind libnss-winbind krb5-config krb5-user dnsutils python3-setproctitle ntp -y
  fi
}
# build_libsnappy         # config_options+= --enable-libsnappy           # enable Snappy compression, needed for hap encoding [no]
build_libsnappy() {
  if [[ $disable_libsnappy != 1 && $enable_libsnappy == 1 ]]; then
  local lib="libsnappy"
  local repo="https://github.com/google/snappy"
  local repo_ver="1.2.2" 
  change_dir "$src_dir"
  do_git_checkout "$repo" "$lib" "$repo_ver"
	change_dir "$src_dir/$lib"
	do_cmake_and_install "-DBUILD_BINARY=OFF -DCMAKE_BUILD_TYPE=Release -DSNAPPY_BUILD_TESTS=OFF -DSNAPPY_BUILD_BENCHMARKS=OFF" # extra params from deadsix27 and from new cMakeLists.txt content
	change_dir "$src_dir"
  fi
}
# build_libsoxr           # config_options+= --enable-libsoxr             # enable Include libsoxr resampling [no]
build_libsoxr() {
  if [[ $disable_libsoxr != 1 && $enable_libsoxr == 1 ]]; then
  local lib="libsoxr"
  local repo="https://github.com/chirlu/soxr"
  local repo_ver="0.1.3" 
  change_dir "$src_dir"
  do_git_checkout "$repo" "$lib" "$repo_ver"
	change_dir "$src_dir/$lib"
	do_cmake_and_install "-DWITH_OPENMP=0 -DBUILD_TESTS=0 -DBUILD_EXAMPLES=0"
	change_dir "$src_dir"
  fi
}
# build_libspeex          # config_options+= --enable-libspeex            # enable Speex de/encoding via libspeex [no]
build_libspeex() {
  if [[ $disable_libspeex != 1 && $enable_libspeex == 1 ]]; then
  local lib="libspeex"
  local repo="https://github.com/xiph/speexdsp"
  local repo_ver="SpeexDSP-1.2.1" 
  change_dir "$src_dir"
  do_git_checkout "$repo" "$lib" "$repo_ver"
	change_dir "$src_dir/$lib"
	generic_configure "--disable-examples"
	do_make_and_make_install
	change_dir "$src_dir"
  fi
}
# build_libsrt            # config_options+= --enable-libsrt              # enable Haivision SRT protocol via libsrt [no]
build_libsrt() {
  if [[ $disable_libsrt != 1 && $enable_libsrt == 1 ]]; then
  build_openssl
  local lib="libsrt"
  # do_git_checkout https://github.com/Haivision/srt # might be able to use these days...?
  local repo="https://github.com/Haivision/srt"
  local repo_ver="v1.5.4" 
  change_dir "$src_dir"
  do_git_checkout "$repo" "$lib" "$repo_ver"
	change_dir "$src_dir/$lib"
	do_cmake_and_install "-DCMAKE_BUILD_TYPE=Release -DENABLE_STATIC=ON -DENABLE_SHARED=OFF -DENABLE_APPS=OFF -DUSE_STATIC_LIBSTDCXX=ON"
	change_dir "$src_dir"
  fi
}
# build_libssh            # config_options+= --enable-libssh              # enable SFTP protocol via libssh [no]
build_libssh() {
  if [[ $disable_libssh != 1 && $enable_libssh == 1 ]]; then
  local lib="libssh"
  # https://github.com/canonical/libssh
  local repo="https://github.com/canonical/libssh"
  local repo_ver="libssh-0.11.1" 
  change_dir "$src_dir"
  do_git_checkout "$repo" "$lib" "$repo_ver"
	change_dir "$src_dir/$lib/build" 1
  local cmake_params="-DBUILD_SHARED_LIBS=OFF \
-DWITH_STATIC_LIB=ON \
-DWITH_EXAMPLES=OFF \
-DWITH_TESTING=OFF \
-DWITH_SERVER=OFF \
-DWITH_ZLIB=ON \
-DWITH_SFTP=ON \
-DWITH_GSSAPI=OFF \
-DWITH_NACL=OFF \
-DWITH_PCAP=OFF \
-DCMAKE_INSTALL_PREFIX=${dependency_install_prefix}"
  do_cmake_from_build_dir "$src_dir/$lib" "$cmake_params"
  do_make_and_make_install
	change_dir "$src_dir"
  fi
}
build_cpuinfo() {
  local lib="cpuinfo"
  local repo="https://github.com/pytorch/cpuinfo"
	change_dir "$src_dir"
	do_git_checkout "$repo" "$lib"
	change_dir "$src_dir/$lib"
	do_cmake_and_install # builds included cpuinfo bugged
	change_dir "$src_dir"
}
# build_libsvtav1         # config_options+= --enable-libsvtav1           # enable AV1 encoding via SVT [no]
build_libsvtav1() {
  if [[ $disable_libsvtav1 != 1 && $enable_libsvtav1 == 1 ]]; then
    if [[ "$bits_target" != "32" ]]; then
      build_cpuinfo
      local lib="libsvtav1"
      local repo="https://gitlab.com/AOMediaCodec/SVT-AV1"
      local repo_ver="v3.1.2"
      change_dir "$src_dir"
      do_git_checkout "$repo" "$lib" "$repo_ver"
      change_dir "$src_dir/$lib"
      do_cmake "-B build -GNinja -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF -DUSE_CPUINFO=SYSTEM" # -DSVT_AV1_LTO=OFF if fails try adding this
      do_ninja_and_ninja_install
      change_dir "$src_dir"
    else
      echo -e "WARNING: 32bit not supported" | tee -a "$LOG_FILE"
    fi
  fi
}
pick_gpu_support() {
    if [[ -n $1 ]]; then
        export gpu_support=$1
    fi
    while [[ ! "${gpu_support,,}" =~ ^([1-2]|yes|y|no|n)$ ]]; do
        # shellcheck disable=SC2199
        if [[ -n "${unknown_opts[@]}" ]]; then
            echo -e -n 'Unknown option(s)'
            for unknown_opt in "${unknown_opts[@]}"; do
                echo -e -n " '$unknown_opt'"
            done
            echo -e ', ignored.'
            echo
        fi
        cat <<'EOF'
Do you want to enable GPU support for TensorFlow?
  1. yes
  2. no [default]
EOF
        local timeout=10
        local gpu_support=""
        echo -ne 'Input your choice [1-2] (defaulting to "no" in 10 seconds): '
        for ((i=timeout; i>0; i--)); do
            if read -r -t 1 gpu_support; then
                break
            fi
            if (( i > 1 )); then
                echo -ne "\rInput your choice [1-2] (defaulting to \"no\" in $((i-1)) seconds): "
            else
                echo -ne "\rInput your choice [1-2] (defaulting to \"no\" in 0 seconds): "
            fi
        done
        
        # Check if timeout occurred
        if [[ -z "$gpu_support" ]] && (( i == 0 )); then
            echo "No input received within 10 seconds. Defaulting to 'no'."
            gpu_support="2"
        fi
    done
    case "${gpu_support,,}" in
        1|yes|y) 
            export gpu_support="yes"
            return 0
            ;;
        2|no|n|"") 
            export gpu_support="no"
            return 1
            ;;
        *)
            echo -e 'Your choice was not valid, please try again.'
            echo
            ;;
    esac
}
uninstall_manifest() {
  local manifest="$1"
  if [[ -f "$manifest" ]]; then
    echo "WARNING: found $manifest. Uninstalling files from $manifest if installed" >> "$LOG_FILE"
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" ]] && continue
        [[ -f "$line" ]] && remove_path -f "$line" || echo "WARNING: could not uninstall file: $line" >> "$LOG_FILE"
    done < "$manifest"
    remove_path -f "$manifest"
  else
    echo "WARNING: $manifest not found." >> "$LOG_FILE"
  fi
}
# build_libtensorflow     # config_options+= --enable-libtensorflow       # enable TensorFlow as a DNN module backend for DNN based filters like sr [no]
build_libtensorflow() {
  if [[ $disable_libtensorflow != 1 && $enable_libtensorflow == 1 ]]; then
  local lib="libtensorflow"
  if pick_gpu_support; then
      echo "GPU support enabled (user chose 'yes')" >> "$LOG_FILE"
      local repo="https://storage.googleapis.com/tensorflow/versions/2.18.0/libtensorflow-gpu-linux-x86_64.tar.gz"
      local subdir="gpu"
      echo "WARNING: uninstalling cpu libtensorflow if installed." >> "$LOG_FILE"
      uninstall_manifest "$src_dir/$lib/cpu/install_manifest"
  else
      echo "GPU support disabled (user chose 'no' or timed out)" >> "$LOG_FILE"
      local repo="https://storage.googleapis.com/tensorflow/versions/2.18.0/libtensorflow-cpu-linux-x86_64.tar.gz"
      local subdir="cpu"
      echo "WARNING: uninstalling gpu libtensorflow if installed." >> "$LOG_FILE"
      uninstall_manifest "$src_dir/$lib/gpu/install_manifest"
  fi
  # "https://github.com/tensorflow/tensorflow"
  change_dir "$src_dir"
  change_dir "$src_dir/$lib"
	download_and_unpack_file "$repo" "$src_dir/$lib/$subdir"
	change_dir "$src_dir/$lib/$subdir"
  echo > "$src_dir/$lib/$subdir/install_manifest" && chmod -R u+rwx "$src_dir/$lib/$subdir/install_manifest"
  cp -rfv "$src_dir/$lib/$subdir/lib"* "$dependency_install_prefix/lib" 2>&1 | sed -n "s/.*' -> '\(.*\)'/\1/p" >> "$src_dir/$lib/$subdir/install_manifest"
  cp -rfv "$src_dir/$lib/$subdir/include"* "$dependency_install_prefix/include" 2>&1 | sed -n "s/.*' -> '\(.*\)'/\1/p" >> "$src_dir/$lib/$subdir/install_manifest"
  cat >> "$dependency_install_prefix/lib/pkgconfig/tensorflow.pc" << EOF
prefix=${dependency_install_prefix}
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: tensorflow
Description: TensorFlow C Library (${subdir})
Version: 2.18.0
Libs: -L\${libdir} -ltensorflow -ltensorflow_framework
Cflags: -I\${includedir}
EOF
  echo "$dependency_install_prefix/lib/pkgconfig/tensorflow.pc" >> "$src_dir/$lib/$subdir/install_manifest"
	change_dir "$src_dir"
  fi
}
build_libtiff() {
  local lib="libtiff"
  local repo="https://download.osgeo.org/libtiff/tiff-4.7.1rc1.tar.gz" # "https://gitlab.com/libtiff/libtiff"
  local repo_ver="v4.7.1"
	#build_libjpeg_turbo # auto uses it?
	change_dir "$src_dir"
  download_and_unpack_file "$repo" "$lib"
  change_dir "$src_dir/$lib"
  generic_configure_make_install "--enable-static --disable-shared"
	sed -i.bak "s/-ltiff.*$/-ltiff -llzma -ljpeg -lz/" "$dependency_install_prefix/lib/pkgconfig/libtiff-4.pc" # static deps
	change_dir "$src_dir"
}
build_libjpeg_turbo() {
  local lib="libjpeg-turbo"
  local repo="https://github.com/libjpeg-turbo/libjpeg-turbo"
  local repo_ver="3.1.2"
	change_dir "$src_dir"
	do_git_checkout "$repo" "$lib" "$repo_ver"
	change_dir "$src_dir/$lib"
	local cmake_params="-DCMAKE_INSTALL_PREFIX=$dependency_install_prefix -DENABLE_SHARED=0 -DCMAKE_ASM_NASM_COMPILER=yasm"
	do_cmake_and_install "$cmake_params"
	change_dir "$src_dir"
}
build_giflib() {
	change_dir "$src_dir"
	generic_download_and_make_and_install https://sourceforge.net/projects/giflib/files/giflib-5.1.4.tar.gz
	change_dir "$src_dir"
}
build_libleptonica() {
	build_libjpeg_turbo
	build_giflib
	change_dir "$src_dir"
	do_git_checkout "https://github.com/DanBloomberg/leptonica.git" "leptonica"
	change_dir "$src_dir/leptonica"
	export CPPFLAGS="-DOPJ_STATIC"
	generic_configure_make_install
	reset_cppflags
	change_dir "$src_dir"
}
build_libarchive() {
	build_lz4
	change_dir "$src_dir"
	download_and_unpack_file https://github.com/libarchive/libarchive/releases/download/v3.8.1/libarchive-3.8.1.tar.gz
	change_dir "$src_dir/libarchive-3.8.1"
	generic_configure "--with-nettle --bindir=$dependency_install_prefix/bin --without-openssl --without-iconv --disable-posix-regex-lib"
	do_make_install
	change_dir "$src_dir"
}
# build_libtesseract      # config_options+= --enable-libtesseract        # enable Tesseract, needed for ocr filter [no]
build_libtesseract() {
  if [[ $disable_libtesseract != 1 && $enable_libtesseract == 1 ]]; then
  build_libtiff
	build_libleptonica
	build_libarchive
  local lib="libtesseract"
  do_git_checkout https://github.com/tesseract-ocr/tesseract tesseract
  fi
}
# build_libtheora         # config_options+= --enable-libtheora           # enable Theora encoding via libtheora [no]
build_libtheora() {
  if [[ $disable_libtheora != 1 && $enable_libtheora == 1 ]]; then
  local lib="libtheora"
  do_git_checkout https://github.com/xiph/theora
  fi
}
# build_libtls            # config_options+= --enable-libtls              # enable LibreSSL (via libtls), needed for https support if openssl, gnutls or mbedtls is not used [no]
build_libtls() {
  if [[ $disable_libtls != 1 && $enable_libtls == 1 ]]; then
  local lib="libtls"
  # https://github.com/PowerShell/LibreSSL
  fi
}
# build_libtorch          # config_options+= --enable-libtorch            # enable Torch as one DNN backend [no]
build_libtorch() {
  if [[ $disable_libtorch != 1 && $enable_libtorch == 1 ]]; then
  local lib="libtorch"
  # https://github.com/pytorch/pytorch
  fi
}
# build_libtwolame        # config_options+= --enable-libtwolame          # enable MP2 encoding via libtwolame [no]
build_libtwolame() {
  if [[ $disable_libtwolame != 1 && $enable_libtwolame == 1 ]]; then
  local lib="libtwolame"
  do_git_checkout https://github.com/njh/twolame twolame "origin/main"
  fi
}
# build_libuavs3d         # config_options+= --enable-libuavs3d           # enable AVS3 decoding via libuavs3d [no]
build_libuavs3d() {
  if [[ $disable_libuavs3d != 1 && $enable_libuavs3d == 1 ]]; then
  local lib="libuavs3d"
  # https://github.com/uavs3/uavs3d
  fi
}
# build_libvidstab        # config_options+= --enable-libvidstab          # enable video stabilization using vid.stab [no]
build_libvidstab() {
  if [[ $disable_libvidstab != 1 && $enable_libvidstab == 1 ]]; then
  local lib="libvidstab"
  do_git_checkout https://github.com/georgmartius/vid.stab vid.stab
  fi
}
# build_libvmaf           # config_options+= --enable-libvmaf             # enable vmaf filter via libvmaf [no]
build_libvmaf() {
  if [[ $disable_libvmaf != 1 && $enable_libvmaf == 1 ]]; then
  local lib="libvmaf"
  do_git_checkout https://github.com/Netflix/vmaf vmaf
  fi
}
# build_libvorbis         # config_options+= --enable-libvorbis           # enable Vorbis en/decoding via libvorbis, native implementation exists [no]
build_libvorbis() {
  if [[ $disable_libvorbis != 1 && $enable_libvorbis == 1 ]]; then
  build_libogg
  local lib="libvorbis"
  local repo="https://github.com/xiph/vorbis"
  local repo_ver="v1.3.7"
  change_dir "$src_dir"
	do_git_checkout "$repo" "$lib" "$repo_ver"
	change_dir "$src_dir/$lib/build" 1
  #generic_configure "--disable-docs --disable-examples --disable-oggtest --static"
  do_cmake_from_build_dir "$src_dir/$lib"
	do_make_and_make_install
  change_dir "$src_dir"
  fi
}
# build_libvpx            # config_options+= --enable-libvpx              # enable VP8 and VP9 de/encoding via libvpx [no]
build_libvpx() {
  if [[ $disable_libvpx != 1 && $enable_libvpx == 1 ]]; then
  local lib="libvpx"
  do_git_checkout https://chromium.googlesource.com/webm/libvpx libvpx "origin/main"
  fi
}
# build_libvvenc          # config_options+= --enable-libvvenc            # enable H.266/VVC encoding via vvenc [no]
build_libvvenc() {
  if [[ $disable_libvvenc != 1 && $enable_libvvenc == 1 ]]; then
  local lib="libvvenc"
  do_git_checkout https://github.com/fraunhoferhhi/vvenc libvvenc
  fi
}
# build_libwebp           # config_options+= --enable-libwebp             # enable WebP encoding via libwebp [no]
build_libwebp() {
  if [[ $disable_libwebp != 1 && $enable_libwebp == 1 ]]; then
  build_libpng
  local lib="libwebp"
  local repo="https://chromium.googlesource.com/webm/libwebp"
  local repo_ver="v1.6.0"
  change_dir "$src_dir"
	do_git_checkout "$repo" "$lib" "$repo_ver"
	change_dir "$src_dir/$lib"
	generic_configure "--disable-wic"
	do_make_and_make_install
	change_dir "$src_dir"
  fi
}
# build_libx264           # config_options+= --enable-libx264             # enable H.264 encoding via x264 [no]
build_libx264() {
  if [[ $disable_libx264 != 1 && $enable_libx264 == 1 ]]; then
  local lib="libx264"
  do_git_checkout "https://code.videolan.org/videolan/x264.git" "$checkout_dir" "origin/master"
  fi
}
# build_libx265           # config_options+= --enable-libx265             # enable HEVC encoding via x265 [no]
build_libx265() {
  if [[ $disable_libx265 != 1 && $enable_libx265 == 1 ]]; then
  local lib="libx265"
  local remote="https://bitbucket.org/multicoreware/x265"
  fi
}
# build_libxavs           # config_options+= --enable-libxavs             # enable AVS encoding via xavs [no]
build_libxavs() {
  if [[ $disable_libxavs != 1 && $enable_libxavs == 1 ]]; then
  local lib="libxavs"
  do_git_checkout https://github.com/Distrotech/xavs xavs
  fi
}
# build_libxavs2          # config_options+= --enable-libxavs2            # enable AVS2 encoding via xavs2 [no]
build_libxavs2() {
  if [[ $disable_libxavs2 != 1 && $enable_libxavs2 == 1 ]]; then
  local lib="libxavs2"
  do_git_checkout https://github.com/pkuvcl/xavs2 xavs2
  fi
}
# build_libxevd           # config_options+= --enable-libxevd             # enable EVC decoding via libxevd [no]
build_libxevd() {
  if [[ $disable_libxevd != 1 && $enable_libxevd == 1 ]]; then
  local lib="libxevd"
  # https://github.com/mpeg5/xevd
  fi
}
# build_libxeve           # config_options+= --enable-libxeve             # enable EVC encoding via libxeve [no]
build_libxeve() {
  if [[ $disable_libxeve != 1 && $enable_libxeve == 1 ]]; then
  local lib="libxeve"
  # https://github.com/mpeg5/xeve
  fi
}
# build_libxml2           # config_options+= --enable-libxml2             # enable XML parsing using the C library libxml2, needed for dash and imf demuxing support [no]
build_libxml2() {
  if [[ $disable_libxml2 != 1 && $enable_libxml2 == 1 ]]; then
  build_iconv
  local lib="libxml2"
  local repo="https://gitlab.gnome.org/GNOME/libxml2"
  local repo_ver="v2.15.1"
  change_dir "$src_dir"
  do_git_checkout "$repo" "$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  generic_configure "--with-ftp=no --with-http=no --with-python=no --with-iconv=$dependency_install_prefix" # using configure. meson doesnt work
	do_make_and_make_install
  change_dir "$src_dir"
  fi
}
# build_libxvid           # config_options+= --enable-libxvid             # enable Xvid encoding via xvidcore, native MPEG-4/Xvid encoder exists [no]
build_libxvid() {
  if [[ $disable_libxvid != 1 && $enable_libxvid == 1 ]]; then
  local lib="libxvid"
  download_and_unpack_file https://downloads.xvid.com/downloads/xvidcore-1.3.7.tar.gz xvidcore
  fi
}
# build_libzimg           # config_options+= --enable-libzimg             # enable z.lib, needed for zscale filter [no]
build_libzimg() {
  if [[ $disable_libzimg != 1 && $enable_libzimg == 1 ]]; then
  local lib="libzimg"
  do_git_checkout_and_make_install https://github.com/sekrit-twc/zimg zimg
  fi
}
# build_libzmq            # config_options+= --enable-libzmq              # enable message passing via libzmq [no]
build_libzmq() {
  if [[ $disable_libzmq != 1 && $enable_libzmq == 1 ]]; then
  local lib="libzmq"
  # https://github.com/zeromq/libzmq libzmq 4.3.5
  fi
}
# build_libzvbi           # config_options+= --enable-libzvbi             # enable teletext support via libzvbi [no]
build_libzvbi() {
  if [[ $disable_libzvbi != 1 && $enable_libzvbi == 1 ]]; then
  local lib="libzvbi"
  do_git_checkout https://github.com/zapping-vbi/zvbi zvbi
  fi
}
# build_lv2               # config_options+= --enable-lv2                 # enable LV2 audio filtering [no]
build_lv2() {
  if [[ $disable_lv2 != 1 && $enable_lv2 == 1 ]]; then
  local lib="lv2"
  # https://github.com/lv2/lv2
  fi
}
# build_mbedtls           # config_options+= --enable-mbedtls             # enable mbedTLS, needed for https support if openssl, gnutls or libtls is not used [no]
build_mbedtls() {
  if [[ $disable_mbedtls != 1 && $enable_mbedtls == 1 ]]; then
  local lib="mbedtls"
  # https://github.com/Mbed-TLS/mbedtls "v3.6.5"
  fi
}
# build_openal            # config_options+= --enable-openal              # enable OpenAL 1.1 capture support [no]
build_openal() {
  if [[ $disable_openal != 1 && $enable_openal == 1 ]]; then
  local lib="openal"
  # https://github.com/kcat/openal-soft
  fi
}
# build_opencl            # config_options+= --enable-opencl              # enable OpenCL processing [no]
build_opencl() {
  if [[ $disable_opencl != 1 && $enable_opencl == 1 ]]; then
  local lib="opencl"
  # https://github.com/KhronosGroup/OpenCL-Headers
  # https://github.com/KhronosGroup/OpenCL-ICD-Loader
  fi
}
build_glew() {
  if [[ $disable_opengl != 1 && $enable_opengl == 1 ]]; then
	change_dir "$src_dir"
	download_and_unpack_file https://sourceforge.net/projects/glew/files/glew/2.2.0/glew-2.2.0.tgz glew-2.2.0
	change_dir "$src_dir/glew-2.2.0/build"
	local cmake_params=""
	cmake_params+=" -DWIN32=1"
	do_cmake_from_build_dir ./cmake "$cmake_params" # "-DWITH_FFMPEG=0 -DOPENCV_GENERATE_PKGCONFIG=1 -DHAVE_DSHOW=0"
	do_make_and_make_install
	change_dir "$src_dir"
	fi
}
build_glfw() {
  if [[ $disable_opengl != 1 && $enable_opengl == 1 ]]; then
	change_dir "$src_dir"
	download_and_unpack_file https://github.com/glfw/glfw/releases/download/3.4/glfw-3.4.zip glfw-3.4
	change_dir "$src_dir/glfw-3.4"
	do_cmake_and_install "-DGLFW_BUILD_WAYLAND=OFF -DGLFW_BUILD_X11=OFF -DGLFW_BUILD_WIN32=ON"
	change_dir "$src_dir"
	fi
}
# build_opengl            # config_options+= --enable-opengl              # enable OpenGL rendering [no]
build_opengl() {
  if [[ $disable_opengl != 1 && $enable_opengl == 1 ]]; then
  build_glew
  build_glfw
  local lib="opengl"
  fi
}
# build_openssl           # config_options+= --enable-openssl             # enable openssl, needed for https support if gnutls, libtls or mbedtls is not used [no]
build_openssl() {
  if [[ $disable_openssl != 1 && $enable_openssl == 1 ]]; then
  local lib="openssl"
  # https://github.com/openssl/openssl 
  local repo="https://github.com/openssl/openssl"
  local repo_ver="openssl-3.6.0"
  do_git_checkout "$repo" "$lib" "$repo_ver"
	change_dir "$src_dir/$lib"
	do_configure "--release --prefix=$dependency_install_prefix --openssldir=$dependency_install_prefix/ssl --libdir=lib no-shared no-tests no-docs no-demos no-legacy" "./Configure"
	do_make_and_make_install
	change_dir "$src_dir"
  fi
}
# build_pocketsphinx      # config_options+= --enable-pocketsphinx        # enable PocketSphinx, needed for asr filter [no]
build_pocketsphinx() {
  if [[ $disable_pocketsphinx != 1 && $enable_pocketsphinx == 1 ]]; then
  local lib="pocketsphinx"
  # https://github.com/cmusphinx/pocketsphinx
  fi
}
# build_vapoursynth       # config_options+= --enable-vapoursynth         # enable VapourSynth demuxer [no]
build_vapoursynth() {
  if [[ $disable_vapoursynth != 1 && $enable_vapoursynth == 1 ]]; then
  local lib="vapoursynth"
  # https://github.com/vapoursynth/vapoursynth
  fi
}
# build_whisper           # config_options+= --enable-whisper             # enable whisper filter [no]
build_whisper() {
  if [[ $disable_whisper != 1 && $enable_whisper == 1 ]]; then
  local lib="whisper"
  # https://github.com/ggerganov/whisper.cpp
  fi
}
#endregion---------------------------------------------------------------------
#region------------------------- non-gpl features -----------------------------
#------------------------------------------------------------------------------ 
# build_decklink          # config_options+= --enable-decklink            # enable Blackmagic DeckLink I/O support [no]
build_decklink() {
  if [[ $disable_decklink != 1 && $enable_decklink == 1 ]]; then
  local lib="decklink"
  do_git_checkout https://gitlab.com/m-ab-s/decklink-headers decklink-headers 47d84f8d272ca6872b5440eae57609e36014f3b6
  fi
}
# build_libfdk_aac        # config_options+= --enable-libfdk-aac          # enable AAC de/encoding via libfdk-aac [no]
build_libfdk_aac() {
  if [[ $disable_libfdk_aac != 1 && $enable_libfdk_aac == 1 ]]; then
  local lib="libfdk_aac"
  do_git_checkout "https://github.com/mstorsjo/fdk-aac.git" "$checkout_dir"
  fi
}
#region-------------------- non-gpl hardware features ------------------------- 
# build_cuda_llvm         # config_options+= --disable-cuda-llvm          # disable CUDA compilation using clang [autodetect]
build_cuda_llvm() {
  if [[ $disable_cuda_llvm != 1 && $enable_cuda_llvm == 1 ]]; then
  local lib="cuda_llvm"
  fi
}
# build_cuvid             # config_options+= --disable-cuvid              # disable Nvidia CUVID support [autodetect]
build_cuvid() {
  if [[ $disable_cuvid != 1 && $enable_cuvid == 1 ]]; then
  do_git_checkout https://github.com/FFmpeg/nv-codec-headers
  local lib="cuvid"
  fi
}
# build_ffnvcodec         # config_options+= --disable-ffnvcodec          # disable dynamically linked Nvidia code [autodetect]
build_ffnvcodec() {
  if [[ $disable_ffnvcodec != 1 && $enable_ffnvcodec == 1 ]]; then
  do_git_checkout https://github.com/FFmpeg/nv-codec-headers
  local lib="ffnvcodec"
  fi
}
# build_nvdec             # config_options+= --disable-nvdec              # disable Nvidia video decoding acceleration (via hwaccel) [autodetect]
build_nvdec() {
  if [[ $disable_nvdec != 1 && $enable_nvdec == 1 ]]; then
  do_git_checkout https://github.com/FFmpeg/nv-codec-headers
  local lib="nvdec"
  fi
}
# build_nvenc             # config_options+= --disable-nvenc              # disable Nvidia video encoding code [autodetect]
build_nvenc() {
  if [[ $disable_nvenc != 1 && $enable_nvenc == 1 ]]; then
  do_git_checkout https://github.com/FFmpeg/nv-codec-headers
  local lib="nvenc"
  fi
}
# build_vdpau             # config_options+= --disable-vdpau              # disable Nvidia Video Decode and Presentation API for Unix code [autodetect]
build_vdpau() {
  if [[ $disable_vdpau != 1 && $enable_vdpau == 1 ]]; then
  local lib="vdpau"
  # https://gitlab.freedesktop.org/vdpau/libvdpau
  fi
}
# build_cuda_nvcc         # config_options+= --enable-cuda-nvcc           # enable Nvidia CUDA compiler [no]
build_cuda_nvcc() {
  if [[ $disable_cuda_nvcc != 1 && $enable_cuda_nvcc == 1 ]]; then
  local lib="cuda_nvcc"
  # https://developer.download.nvidia.com/compute/cuda/redist/
  fi
}
# build_libnpp            # config_options+= --enable-libnpp              # enable Nvidia Performance Primitives-based code [no]
build_libnpp() {
  if [[ $disable_libnpp != 1 && $enable_libnpp == 1 ]]; then
  local lib="libnpp"
  # https://developer.download.nvidia.com/compute/cuda/redist/
  fi
}
#endregion
#region------------------ non-gpl linux/unix features -------------------------    
# build_mmal              # config_options+= --disable-mmal               # enable Broadcom Multi-Media Abstraction Layer (Raspberry Pi) via MMAL [no]
build_mmal() {
  if [[ $disable_mmal != 1 && $enable_mmal == 1 ]]; then
  local lib="mmal"
    # https://github.com/raspberrypi/userland/tree/master/interface/mmal maybe?

  fi
}
# build_omx_rpi           # config_options+= --disable-omx-rpi            # enable OpenMAX IL code for Raspberry Pi [no]
build_omx_rpi() {
  if [[ $disable_omx_rpi != 1 && $enable_omx_rpi == 1 ]]; then
  local lib="omx_rpi"
    # https://github.com/tizonia/tizonia-openmax-il maybe?
  fi
}
#endregion
#region-------------------- non-gpl windows features -------------------------- 
# build_d3d11va           # config_options+= --disable-d3d11va            # disable Microsoft Direct3D 11 video acceleration code [autodetect]
build_d3d11va() {
  if [[ $disable_d3d11va != 1 && $enable_d3d11va == 1 ]]; then
  echo "INFO: Only available on Windows build"
  echo "INFO: No d3d11va library to compile. Library built into OS."
  fi
}
# build_d3d12va           # config_options+= --disable-d3d12va            # disable Microsoft Direct3D 12 video acceleration code [autodetect]
build_d3d12va() {
  if [[ $disable_d3d12va != 1 && $enable_d3d12va == 1 ]]; then
  echo "INFO: Only available on Windows build"
  echo "INFO: No d3d12va library to compile. Library built into OS."
  fi
}
# build_dxva2             # config_options+= --disable-dxva2              # disable Microsoft DirectX 9 video acceleration code [autodetect]
build_dxva2() {
  if [[ $disable_dxva2 != 1 && $enable_dxva2 == 1 ]]; then
  echo "INFO: Only available on Windows build"
  echo "INFO: No dxva2 library to compile. Library built into OS."
  fi
}
# build_schannel          # config_options+= --disable-schannel           # disable SChannel SSP, needed for TLS support on Windows if openssl and gnutls are not used [autodetect]
build_schannel() {
  if [[ $disable_schannel != 1 && $enable_schannel == 1 ]]; then
  echo "INFO: Only available on Windows build"
  echo "INFO: No schannel library to compile. Library built into OS."
  fi
}
# build_mediafoundation   # config_options+= --enable-mediafoundation     # enable encoding via MediaFoundation [auto]
build_mediafoundation() {
  if [[ $disable_mediafoundation != 1 && $enable_mediafoundation == 1 ]]; then
  echo "INFO: Only available on Windows build"
  echo "INFO: No mediafoundation library to compile. Library built into OS."
  fi
}
#endregion
#region--------------------- non-gpl apple features ---------------------------     
# build_avfoundation      # config_options+= --disable-avfoundation       # disable Apple AVFoundation framework [autodetect]
build_avfoundation() {
  if [[ $disable_avfoundation != 1 && $enable_avfoundation == 1 ]]; then
  echo "INFO: Only available on Apple build"
  echo "INFO: No avfoundation library to compile. Library built into OS."
  fi
}
# build_appkit            # config_options+= --disable-appkit             # disable Apple AppKit framework [autodetect]
build_appkit() {
  if [[ $disable_appkit != 1 && $enable_appkit == 1 ]]; then
  echo "INFO: Only available on Apple build"
  echo "INFO: No appkit library to compile. Library built into OS."
  fi
}
# build_audiotoolbox      # config_options+= --disable-audiotoolbox       # disable Apple AudioToolbox code [autodetect]
build_audiotoolbox() {
  if [[ $disable_audiotoolbox != 1 && $enable_audiotoolbox == 1 ]]; then
  echo "INFO: Only available on Apple build"
  echo "INFO: No audiotoolbox library to compile. Library built into OS."
  fi
}
# build_coreimage         # config_options+= --disable-coreimage          # disable Apple CoreImage framework [autodetect]
build_coreimage() {
  if [[ $disable_coreimage != 1 && $enable_coreimage == 1 ]]; then
  echo "INFO: Only available on Apple build"
  echo "INFO: No coreimage library to compile. Library built into OS."
  fi
}
# build_metal             # config_options+= --disable-metal              # disable Apple Metal framework [autodetect]
build_metal() {
  if [[ $disable_metal != 1 && $enable_metal == 1 ]]; then
  echo "INFO: Only available on Apple build"
  echo "INFO: No metal library to compile. Library built into OS."
  fi
}
# build_securetransport   # config_options+= --disable-securetransport    # disable Secure Transport, needed for TLS support on OSX if openssl and gnutls are not used [autodetect]
build_securetransport() {
  if [[ $disable_securetransport != 1 && $enable_securetransport == 1 ]]; then
  echo "INFO: Only available on Apple build"
  echo "INFO: No securetransport library to compile. Library built into OS."
  fi
}
# build_videotoolbox      # config_options+= --disable-videotoolbox       # disable VideoToolbox code [autodetect]
build_videotoolbox() {
  if [[ $disable_videotoolbox != 1 && $enable_videotoolbox == 1 ]]; then
  echo "INFO: Only available on Apple build"
  echo "INFO: No videotoolbox library to compile. Library built into OS."
  fi
}
#endregion
#endregion---------------------------------------------------------------------
#------------------------------------------------------------------------------ 