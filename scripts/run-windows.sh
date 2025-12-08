#!/bin/bash

# shellcheck disable=SC2317,SC2129,SC1091,SC2120,SC2035,SC2016

#region WINDOWS FFMPEG BUILD PRIMARY DEPENDENCIES

#===============================================================================================
#
#                        WINDOWS FFMPEG BUILD PRIMARY DEPENDENCIES
#
#===============================================================================================

build_dlfcn() {
	change_dir "$src_dir"
	do_git_checkout https://github.com/dlfcn-win32/dlfcn-win32
	change_dir "$src_dir/dlfcn-win32"
	if [[ ! -f Makefile.bak ]]; then # Change CFLAGS.
		sed -i.bak "s/-O3/-O2/" Makefile
	fi
	do_configure "--prefix=$dependency_install_prefix --cross-prefix=$cross_prefix" # rejects some normal cross compile options so custom here
	do_make_and_make_install
	gen_ld_script libdl.a dl_s -lpsapi # dlfcn-win32's 'README.md': "If you are linking to the static 'dl.lib' or 'libdl.a', then you would need to explicitly add 'psapi.lib' or '-lpsapi' to your linking command, depending on if MinGW is used."
	change_dir "$src_dir"
}
#--enable-libxavs (from build_libxavs) - AVS video encoding.
build_libxavs() {
  if [[ $disable_libxavs != 1 && $enable_libxavs == 1 ]]; then
	change_dir "$src_dir"
	do_git_checkout https://github.com/Distrotech/xavs xavs
	change_dir "$src_dir/xavs"
	if [[ ! -f Makefile.bak ]]; then
		sed -i.bak "s/O4/O2/" configure # Change CFLAGS.
	fi
	apply_patch "https://patch-diff.githubusercontent.com/raw/Distrotech/xavs/pull/1.patch" -p1
	do_configure "--host=$host_target --prefix=$dependency_install_prefix --cross-prefix=$cross_prefix" # see https://github.com/rdp/ffmpeg-windows-build-helpers/issues/3
	do_make_and_make_install "$compiler_flags"
	if [[ -d NUL ]]; then
		remove_path -f NUL # cygwin causes windows explorer to not be able to delete this folder if it has this oddly named file in it...
	fi
	change_dir "$src_dir"
	fi
}
#--enable-libdavs2 (from build_libdavs2) - AVS2 video decoding.
build_libdavs2() {
  if [[ $disable_libdavs2 != 1 && $enable_libdavs2 == 1 ]]; then
	change_dir "$src_dir"
	do_git_checkout https://github.com/pkuvcl/davs2
	change_dir "$src_dir/davs2/build/linux"
	if [[ $host_target == "i686-w64-mingw32" ]]; then
		do_configure "--cross-prefix=$cross_prefix --host=$host_target --prefix=$dependency_install_prefix --enable-pic --disable-asm"
	else
		do_configure "--cross-prefix=$cross_prefix --host=$host_target --prefix=$dependency_install_prefix --enable-pic"
	fi
	do_make_and_make_install
	change_dir "$src_dir"
	fi
}
#--enable-libxavs2 (from build_libxavs2) - AVS2 video encoding.
build_libxavs2() {
  if [[ $disable_libxavs2 != 1 && $enable_libxavs2 == 1 ]]; then
	if [[ $host_target != 'i686-w64-mingw32' ]]; then
		change_dir "$src_dir"
		do_git_checkout https://github.com/pkuvcl/xavs2 xavs2
		change_dir "$src_dir/xavs2"
		for file in "${PWD}/build/linux/already_configured"*; do
			if [[ -e "$file" ]]; then
				curl "https://github.com/pkuvcl/xavs2/compare/master...1480c1:xavs2:gcc14/pointerconversion.patch" | git apply -v
			fi
		done
		change_dir "$src_dir/xavs2/build/linux"
		do_configure "--cross-prefix=$cross_prefix --host=$host_target --prefix=$dependency_install_prefix --enable-strip" # --enable-pic
		do_make_and_make_install
		change_dir "$src_dir"
	fi
	fi
}

build_mingw_std_threads() {
	change_dir "$src_dir"
	do_git_checkout https://github.com/meganz/mingw-std-threads # it needs std::mutex too :|
	change_dir "$src_dir/mingw-std-threads"
	cp *.h "$dependency_install_prefix/include"
	change_dir "$src_dir"
}
#   --disable-zlib           disable zlib [autodetect]
build_zlib() {
  if [[ $disable_zlib != 1 ]]; then
	change_dir "$src_dir"
	do_git_checkout https://github.com/madler/zlib zlib
	change_dir "$src_dir/zlib"
	local make_options
	export ARFLAGS=rcs # Native can't take ARFLAGS; https://stackoverflow.com/questions/21396988/zlib-build-not-configuring-properly-with-cross-compiler-ignores-ar
	# TODO: Allow shared library build
	do_configure "--prefix=$dependency_install_prefix --static"
	do_make_and_make_install "$compiler_flags ARFLAGS=rcs"
	unset ARFLAGS
	change_dir "$src_dir"
  fi
}
#--enable-libcaca (from build_libcaca) - Textual display of video.
build_libcaca() {
  if [[ $disable_libcaca != 1 && $enable_libcaca == 1 ]]; then
	change_dir "$src_dir"
	do_git_checkout https://github.com/cacalabs/libcaca libcaca 813baea7a7bc28986e474541dd1080898fac14d7
	change_dir "$src_dir/libcaca"
	apply_patch "file://$WINPATCHDIR/libcaca_git_stdio-cruft.diff" -p1 # Fix WinXP incompatibility.
	change_dir "$src_dir/libcaca/caca"
	sed -i.bak "s/__declspec(dllexport)//g" *.h # get rid of the declspec lines otherwise the build will fail for undefined symbols
	sed -i.bak "s/__declspec(dllimport)//g" *.h
	change_dir "$src_dir/libcaca"
	generic_configure "--libdir=$dependency_install_prefix/lib --disable-csharp --disable-java --disable-cxx --disable-python --disable-ruby --disable-doc --disable-cocoa --disable-ncurses"
	do_make_and_make_install
	change_dir "$src_dir"
	fi
}
#   --disable-bzlib          disable bzlib [autodetect]
build_bzlib() {
	change_dir "$src_dir"
	download_and_unpack_file https://sourceware.org/pub/bzip2/bzip2-1.0.8.tar.gz
	change_dir "$src_dir/bzip2"
	apply_patch "file://$WINPATCHDIR/bzip2-1.0.8_brokenstuff.diff"
	if [[ ! -f ./libbz2.a ]] || [[ -f $dependency_install_prefix/lib/libbz2.a && ! $(/usr/bin/env md5sum ./libbz2.a) = $(/usr/bin/env md5sum "$dependency_install_prefix"/lib/libbz2.a) ]]; then # Not built or different build installed
		do_make "libbz2.a $compiler_flags"
		install -m644 bzlib.h "$dependency_install_prefix"/include/bzlib.h
		install -m644 libbz2.a "$dependency_install_prefix"/lib/libbz2.a
      cat > "$dependency_install_prefix/lib/pkgconfig/bzip2.pc" <<EOF
prefix=$dependency_install_prefix
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: bzip2
Description: bzip2 compression library
Version: 1.0.8
Libs: -L\${libdir} -lbz2
Cflags: -I\${includedir}
EOF
	else
		echo -e "Already made bzip2-1.0.8"
	fi
	change_dir "$src_dir"
}
#   --disable-lzma           disable lzma [autodetect]
build_lzma() {
  if [[ $disable_lzma != 1 ]]; then
	change_dir "$src_dir"
	download_and_unpack_file https://sourceforge.net/projects/lzmautils/files/xz-5.8.1.tar.xz
	change_dir "$src_dir/xz-5.8.1"
	generic_configure "--disable-xz --disable-xzdec --disable-lzmadec --disable-lzmainfo --disable-scripts --disable-doc --disable-nls"
	do_make_and_make_install
	change_dir "$src_dir"
  fi
}
#   --disable-iconv          disable iconv [autodetect]
build_iconv() {
  if [[ $disable_iconv != 1 ]]; then
	change_dir "$src_dir"
	download_and_unpack_file https://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.18.tar.gz
	change_dir "$src_dir/libiconv-1.18"
	generic_configure "--disable-nls"
	do_make "install-lib" # No need for 'do_make_install', because 'install-lib' already has install-instructions.
	change_dir "$src_dir"
  fi
}
#   --disable-sdl2           disable sdl2 [autodetect]
build_sdl2() {
  if [[ $disable_sdl2 != 1 ]]; then
	change_dir "$src_dir"
	download_and_unpack_file https://www.libsdl.org/release/SDL2-2.32.10.tar.gz
	change_dir "$src_dir/SDL2-2.32.10"
	apply_patch "file://$WINPATCHDIR/SDL2-2.32.10_lib-only.diff"
	if [[ ! -f configure.bak ]]; then
		sed -i.bak "s/ -mwindows//" configure # Allow ffmpeg to output anything to console.
	fi
	export CFLAGS="$CFLAGS -DDECLSPEC=" # avoid SDL trac tickets 939 and 282 [broken shared builds]
	generic_configure "--bindir=$toolchain_bin_path"
	do_make_and_make_install
	if [[ ! -f $toolchain_bin_path/$host_target-sdl2-config ]]; then
		mv "$toolchain_bin_path/sdl2-config" "$toolchain_bin_path/$host_target-sdl2-config" # At the moment FFmpeg's 'configure' doesn't use 'sdl2-config', because it gives priority to 'sdl2.pc', but when it does, it expects 'i686-w64-mingw32-sdl2-config' in 'cross_compilers/mingw-w64-i686/bin'.
	fi
	reset_cflags
	change_dir "$src_dir"
  fi
}
#--enable-amf (headers from build_amd_amf_headers) - AMD AMF hardware encoding.
#   --disable-amf            disable AMF video encoding code [autodetect]
build_amf() {
  if [[ $disable_amf != 1 ]]; then
	change_dir "$src_dir"
	# was https://github.com/GPUOpen-LibrariesAndSDKs/AMF too big
	# or https://github.com/DeadSix27/AMF smaller
	# but even smaller!
	do_git_checkout https://github.com/GPUOpen-LibrariesAndSDKs/AMF amf_headers
	change_dir "$src_dir/amf_headers"
	if [ ! -f "already_installed" ]; then
		#rm -rf "./Thirdparty" # ?? plus too chatty...
		if [ ! -d "$dependency_install_prefix/include/AMF" ]; then
			create_dir "$dependency_install_prefix/include/AMF"
		fi
		cp -av "amf/public/include/." "$dependency_install_prefix/include/AMF"
		create_touch_file 0 "already_installed"
	fi
	change_dir "$src_dir"
	fi
}
#--enable-libvpl (from build_libvpl) - Intel oneVPL (Quick Sync Video) support.
build_libvpl() {
  if [[ $disable_libvpl != 1 && $enable_libvpl == 1 ]]; then
	change_dir "$src_dir"
	# build_intel_qsv_mfx
	do_git_checkout https://github.com/intel/libvpl libvpl # f8d9891
	change_dir "$src_dir/libvpl"
	if [ "$bits_target" = "32" ]; then
		apply_patch "https://raw.githubusercontent.com/msys2/MINGW-packages/master/mingw-w64-libvpl/0003-cmake-fix-32bit-install.patch" -p1
	fi
	do_cmake "-B build -GNinja -DCMAKE_BUILD_TYPE=Release -DINSTALL_EXAMPLES=OFF -DINSTALL_DEV=ON -DBUILD_EXPERIMENTAL=OFF"
	do_ninja_and_ninja_install
	sed -i.bak "s/Libs: .*/& -lstdc++/" "$PKG_CONFIG_PATH/vpl.pc"
	change_dir "$src_dir"
	fi
}
# (headers from build_nv_headers) - NVIDIA hardware encoding/decoding.
# --enable-cuvid 
# --disable-cuvid
# --enable-nvdec 
# --disable-nvdec          disable Nvidia video decoding acceleration (via hwaccel) [autodetect]
# --enable-nvenc 
# --disable-nvenc          disable Nvidia video encoding code [autodetect]
# --enable-ffnvcodec
# --disable-ffnvcodec      disable dynamically linked Nvidia code [autodetect]
build_nvenc() {
  if [[ $enable_nvenc == 1 || $enable_cuvid == 1 || $enable_nvdec == 1 || $enable_ffnvcodec == 1 ]]; then
  echo "WARNING: Including this library will make the binaries non-redistributable"
	change_dir "$src_dir"
	do_git_checkout https://github.com/FFmpeg/nv-codec-headers
	change_dir "$src_dir/nv-codec-headers"
	do_make_install "PREFIX=$dependency_install_prefix" # just copies in headers
	change_dir "$src_dir"
  else
  echo
  echo -e "WARNING: disabling one NVIDIA HW flags disables all!"
  echo
	fi
}
build_ffnvcodec() {
	build_nvenc
}
build_nvdec() {
  build_nvenc
}
build_cuvid() {
  build_nvenc
}
#--enable-libzimg (from build_libzimg) - High-quality zscale scaling filter.
build_libzimg() {
  if [[ $disable_libzimg != 1 && $enable_libzimg == 1 ]]; then
	change_dir "$src_dir"
	do_git_checkout_and_make_install https://github.com/sekrit-twc/zimg zimg
	change_dir "$src_dir"
	fi
}
#--enable-libopenjpeg (from build_libopenjpeg) - JPEG 2000 support.
build_libopenjpeg() {
  if [[ $disable_libopenjpeg != 1 && $enable_libopenjpeg == 1 ]]; then
	change_dir "$src_dir"
	do_git_checkout https://github.com/uclouvain/openjpeg openjpeg
	change_dir "$src_dir/openjpeg"
	do_cmake_and_install "-DCMAKE_CROSSCOMPILING=1 -DOPJ_BIG_ENDIAN=0 -DBUILD_CODEC=0"
	change_dir "$src_dir"
	fi
}
#--enable-opengl (from build_glew and build_glfw) - OpenGL rendering support.
build_opengl() {
  build_glew
  build_glfw
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

build_libpng() {
	change_dir "$src_dir"
	do_git_checkout_and_make_install https://github.com/glennrp/libpng
	change_dir "$src_dir"
}
#--enable-libwebp (from build_libwebp) - WebP image encoding.
build_libwebp() {
  if [[ $disable_libwebp != 1 && $enable_libwebp == 1 ]]; then
	change_dir "$src_dir"
	do_git_checkout https://chromium.googlesource.com/webm/libwebp libwebp
	change_dir "$src_dir/libwebp"
	# TODO: Allow shared library build
	export LIBPNG_CONFIG="$dependency_install_prefix/bin/libpng-config --static" # LibPNG somehow doesn't get autodetected.
	generic_configure "--disable-wic"
	do_make_and_make_install
	unset LIBPNG_CONFIG
	change_dir "$src_dir"
	fi
}
#--enable-libxml2 (from build_libxml2) - XML parsing for DASH manifests.
build_libxml2() {
  if [[ $disable_libxml2 != 1 && $enable_libxml2 == 1 ]]; then
	change_dir "$src_dir"
	do_git_checkout https://gitlab.gnome.org/GNOME/libxml2 libxml2
	change_dir "$src_dir/libxml2"
	generic_configure "--with-ftp=no --with-http=no --with-python=no"
	do_make_and_make_install
	change_dir "$src_dir"
	fi
}

build_brotli() {
	change_dir "$src_dir"
	do_git_checkout https://github.com/google/brotli brotli v1.0.9 # v1.1.0 static headache stay away
	change_dir "$src_dir/brotli"
	if [ ! -f "brotli.exe" ]; then
		remove_path -f configure
	fi
	generic_configure
	sed -i.bak -e "s/\(allow_undefined=\)yes/\1no/" libtool
	do_make_and_make_install
  sed -i.bak 's/Libs.*$/Libs: -L${libdir} -lbrotlicommon/' "$PKG_CONFIG_PATH"/libbrotlicommon.pc # remove rpaths not possible in conf
  sed -i.bak 's/Libs.*$/Libs: -L${libdir} -lbrotlidec/' "$PKG_CONFIG_PATH"/libbrotlidec.pc
  sed -i.bak 's/Libs.*$/Libs: -L${libdir} -lbrotlienc/' "$PKG_CONFIG_PATH"/libbrotlienc.pc
	change_dir "$src_dir"
}
#--enable-libfreetype (from build_harfbuzz, which calls build_freetype) - Font rendering for the drawtext filter.
build_libfreetype() {
  if [[ $disable_libfreetype != 1 && $enable_libfreetype == 1 ]]; then
	activate_meson
	change_dir "$src_dir"
	do_git_checkout https://github.com/freetype/freetype freetype
	change_dir "$src_dir/freetype"
	local config_options=""
	if [[ -e $PKG_CONFIG_PATH/harfbuzz.pc ]]; then
		local config_options+=" -Dharfbuzz=enabled"
	fi
  local cross_file=$(get_meson_cross_file)
	local meson_options="$config_options"
	# get_local_meson_cross_with_propeties
	meson_options+=" --cross-file=$cross_file"
	do_meson "$meson_options" "setup build"
	do_ninja_and_ninja_install
	change_dir "$src_dir"
	fi
}
#--enable-libharfbuzz (from build_harfbuzz) - Complex text shaping for drawtext.
build_libharfbuzz() {
  if [[ $disable_libharfbuzz != 1 && $enable_libharfbuzz == 1 ]]; then
	change_dir "$src_dir"
	activate_meson
	build_freetype
	do_git_checkout https://github.com/harfbuzz/harfbuzz harfbuzz "10.4.0" # 11.0.0 no longer found by ffmpeg via this method, multiple issues, breaks harfbuzz freetype circular depends hack
	change_dir "$src_dir/harfbuzz"
	if [[ ! -f DUN ]]; then
		local meson_options="-Dglib=disabled -Dgobject=disabled -Dcairo=disabled -Dicu=disabled -Dtests=disabled -Dintrospection=disabled -Ddocs=disabled"
		local cross_file=$(get_meson_cross_file)
		meson_options+=" --cross-file=$cross_file"
		do_meson "$meson_options" "setup build"
		do_ninja_and_ninja_install
		create_touch_file 0 DUN
	fi
	change_dir "$src_dir"
	build_freetype # with harfbuzz now
	sed -i.bak 's/-lfreetype.*/-lfreetype -lharfbuzz -lpng -lbz2/' "$PKG_CONFIG_PATH/freetype2.pc"
	sed -i.bak 's/-lharfbuzz.*/-lfreetype -lharfbuzz -lpng -lbz2/' "$PKG_CONFIG_PATH/harfbuzz.pc"
	fi
}
#--enable-libvmaf (from build_libvmaf) - Netflix's VMAF video quality metric filter.
build_libvmaf() {
  if [[ $disable_libvmaf != 1 && $enable_libvmaf == 1 ]]; then
	change_dir "$src_dir"
	do_git_checkout https://github.com/Netflix/vmaf vmaf
	activate_meson
	change_dir "$src_dir/vmaf/libvmaf"
	local meson_options="-Denable_float=true -Dbuilt_in_models=true -Denable_tests=false -Denable_docs=false"
	local cross_file=$(get_meson_cross_file)
	meson_options+=" --cross-file=$cross_file"
	do_meson "$meson_options" "setup build"
	do_ninja_and_ninja_install
	sed -i.bak "s/Libs: .*/& -lstdc++/" "$PKG_CONFIG_PATH/libvmaf.pc"
	change_dir "$src_dir"
	fi
}
#--enable-libfontconfig - System font discovery for the drawtext filter.
build_libfontconfig() {
  if [[ $disable_libfontconfig != 1 && $enable_libfontconfig == 1 ]]; then
	activate_meson
	change_dir "$src_dir"
	do_git_checkout https://gitlab.freedesktop.org/fontconfig/fontconfig fontconfig
	change_dir "$src_dir/fontconfig"
	local meson_options="-Ddoc=disabled -Diconv=enabled -Dxml-backend=libxml2 -Dtests=disabled"
	local cross_file=$(get_meson_cross_file)
	meson_options+=" --cross-file=$cross_file"
	do_meson "$meson_options" "setup build"
	do_ninja_and_ninja_install
	# generic_configure "--enable-iconv --enable-libxml2 --disable-docs --with-libiconv" # Use Libxml2 instead of Expat; will find libintl from gettext on 2nd pass build and ffmpeg rejects it
	# do_make_and_make_install
	change_dir "$src_dir"
	fi
}
#--enable-gmp (from build_gmp) - For RTMPE support.
build_gmp() {
  if [[ $disable_gmp != 1 && $enable_gmp == 1 ]]; then
	change_dir "$src_dir"
	download_and_unpack_file https://ftp.gnu.org/pub/gnu/gmp/gmp-6.3.0.tar.xz
	change_dir "$src_dir/gmp-6.3.0"
	export CC_FOR_BUILD=/usr/bin/gcc # WSL seems to need this..
	export CPP_FOR_BUILD=usr/bin/cpp
	generic_configure "ABI=$bits_target"
	unset CC_FOR_BUILD
	unset CPP_FOR_BUILD
	do_make_and_make_install
	change_dir "$src_dir"
	fi
}

build_libnettle() {
	change_dir "$src_dir"
	download_and_unpack_file https://ftp.gnu.org/gnu/nettle/nettle-3.10.2.tar.gz
	change_dir "$src_dir/nettle-3.10.2"
	local config_options="--disable-openssl --disable-documentation" # in case we have both gnutls and openssl, just use gnutls [except that gnutls uses this so...huh?
	generic_configure "$config_options" # in case we have both gnutls and openssl, just use gnutls [except that gnutls uses this so...huh? https://github.com/rdp/ffmpeg-windows-build-helpers/issues/25#issuecomment-28158515
	do_make_and_make_install            # What's up with "Configured with: ... --with-gmp=/cygdrive/d/ffmpeg-windows-build-helpers-master/native_build/windows/ffmpeg_local_builds/prebuilt/cross_compilers/pkgs/gmp/gmp-6.1.2-i686" in 'config.log'? Isn't the 'gmp-6.1.2' above being used?
	change_dir "$src_dir"
}

build_unistring() {
	change_dir "$src_dir"
	generic_download_and_make_and_install https://ftp.gnu.org/gnu/libunistring/libunistring-1.4.1.tar.gz
	change_dir "$src_dir"
}

build_libidn2() {
	change_dir "$src_dir"
	download_and_unpack_file https://ftp.gnu.org/gnu/libidn/libidn2-2.3.8.tar.gz
	change_dir "$src_dir/libidn2-2.3.8"
	generic_configure "--disable-doc --disable-rpath --disable-nls --disable-gtk-doc-html --disable-fast-install"
	do_make_and_make_install
	change_dir "$src_dir"
}

build_zstd() {
	change_dir "$src_dir"
	do_git_checkout https://github.com/facebook/zstd zstd v1.5.7
	change_dir "$src_dir/zstd"
	do_cmake "-S build/cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DZSTD_BUILD_SHARED=OFF -DZSTD_USE_STATIC_RUNTIME=ON -DCMAKE_BUILD_WITH_INSTALL_RPATH=OFF"
	do_ninja_and_ninja_install
	change_dir "$src_dir"
}
#--enable-gnutls (from build_gnutls) - For HTTPS and other secure protocols.
build_gnutls() {
  if [[ $disable_gnutls != 1 && $enable_gnutls == 1 ]]; then
	change_dir "$src_dir"
	download_and_unpack_file https://www.gnupg.org/ftp/gcrypt/gnutls/v3.8/gnutls-3.8.9.tar.xz # v3.8.10 not found by ffmpeg with identical .pc?
	change_dir "$src_dir/gnutls-3.8.9"
	export CFLAGS="-Wno-int-conversion"
	local config_options+=" --disable-non-suiteb-curves"
	generic_configure "--disable-cxx --disable-doc --disable-tools --disable-tests --disable-nls --disable-rpath --disable-libdane --disable-gcc-warnings --disable-code-coverage
      --without-p11-kit --with-idn --without-tpm --with-included-unistring --with-included-libtasn1 -disable-gtk-doc-html --with-brotli $config_options"
	do_make_and_make_install
	reset_cflags
	sed -i.bak 's/-lgnutls.*/-lgnutls -lcrypt32 -lnettle -lhogweed -lgmp -liconv -lunistring/' "$PKG_CONFIG_PATH/gnutls.pc"
	change_dir "$src_dir"
	fi
}

build_curl() {
	change_dir "$src_dir"
	build_libssh2
	build_zstd
	build_brotli
	build_libpsl
	build_nghttp2
	local config_options=""
	export CPPFLAGS+="$CPPFLAGS -DNGHTTP2_STATICLIB -DPSL_STATIC $config_options"
	change_dir "$src_dir"
	do_git_checkout https://github.com/curl/curl curl curl-8_16_0
	change_dir "$src_dir/curl"
	generic_configure "--with-libssh2 --with-libpsl --with-libidn2 --disable-debug --enable-hsts --with-brotli --enable-versioned-symbols --enable-sspi --with-schannel"
	do_make_and_make_install
	reset_cppflags
	change_dir "$src_dir"
}

build_libogg() {
	change_dir "$src_dir"
	do_git_checkout_and_make_install https://github.com/xiph/ogg
	change_dir "$src_dir"
}
#--enable-libvorbis (from build_libvorbis) - Vorbis audio encoding/decoding.
build_libvorbis() {
  if [[ $disable_libvorbis != 1 && $enable_libvorbis == 1 ]]; then
	change_dir "$src_dir"
	do_git_checkout https://github.com/xiph/vorbis
	change_dir "$src_dir/vorbis"
	generic_configure "--disable-docs --disable-examples --disable-oggtest"
	do_make_and_make_install
	change_dir "$src_dir"
	fi
}
#--enable-libopus (from build_libopus) - Opus audio encoding/decoding.
build_libopus() {
  if [[ $disable_libopus != 1 && $enable_libopus == 1 ]]; then
	change_dir "$src_dir"
	do_git_checkout https://github.com/xiph/opus opus origin/main
	change_dir "$src_dir/opus"
	generic_configure "--disable-doc --disable-extra-programs --disable-stack-protector"
	do_make_and_make_install
	change_dir "$src_dir"
	fi
}

build_libspeexdsp() {
	change_dir "$src_dir"
	do_git_checkout https://github.com/xiph/speexdsp
	change_dir "$src_dir/speexdsp"
	generic_configure "--disable-examples"
	do_make_and_make_install
	change_dir "$src_dir"
}
#--enable-libspeex (from build_libspeex) - Speex speech audio codec.
build_libspeex() {
  if [[ $disable_libspeex != 1 && $enable_libspeex == 1 ]]; then
	change_dir "$src_dir"
	do_git_checkout https://github.com/xiph/speex
	change_dir "$src_dir/speex"
	export SPEEXDSP_CFLAGS="-I$dependency_install_prefix/include"
	export SPEEXDSP_LIBS="-L$dependency_install_prefix/lib -lspeexdsp" # 'configure' somehow can't find SpeexDSP with 'pkg-config'.
	generic_configure "--disable-binaries"                           # If you do want the libraries, then 'speexdec.exe' needs 'LDFLAGS=-lwinmm'.
	do_make_and_make_install
	unset SPEEXDSP_CFLAGS
	unset SPEEXDSP_LIBS
	change_dir "$src_dir"
	fi
}
#--enable-libtheora (from build_libtheora) - Theora video encoding.
build_libtheora() {
  if [[ $disable_libtheora != 1 && $enable_libtheora == 1 ]]; then
	change_dir "$src_dir"
	do_git_checkout https://github.com/xiph/theora
	change_dir "$src_dir/theora"
	generic_configure "--disable-doc --disable-spec --disable-oggtest --disable-vorbistest --disable-examples --disable-asm" # disable asm: avoid [theora @ 0x1043144a0]error in unpack_block_qpis in 64 bit... [OK OS X 64 bit tho...]
	do_make_and_make_install
	change_dir "$src_dir"
	fi
}
#--enable-libgsm
build_libgsm() {
  build_libsndfile  
}
build_libsndfile() {
  if [[ $disable_libgsm != 1 && $enable_libgsm == 1 ]]; then
	change_dir "$src_dir"
	do_git_checkout https://github.com/libsndfile/libsndfile
	change_dir "$src_dir/libsndfile"
	generic_configure "--disable-sqlite --disable-external-libs --disable-full-suite"
	do_make_and_make_install
	if [[ ! -f $dependency_install_prefix/lib/libgsm.a ]]; then
		install -m644 src/GSM610/gsm.h "$dependency_install_prefix/include/gsm.h" || exit_message 1 "could not install src/GSM610/gsm.h"
		install -m644 src/GSM610/.libs/libgsm.a "$dependency_install_prefix/lib/libgsm.a" || exit_message 1 "could not install src/GSM610/.libs/libgsm.a"
	else
		echo -e "already installed GSM 6.10 ..."
	fi
	change_dir "$src_dir"
	fi
}

build_mpg123() {
	change_dir "$src_dir"
	do_svn_checkout svn://scm.orgis.org/mpg123/trunk mpg123_svn r5008 # avoid Think again failure
	change_dir "$src_dir/mpg123_svn"
	generic_configure_make_install
	change_dir "$src_dir"
}
#--enable-libmp3lame (from build_lame) - High-quality MP3 audio encoding.
build_libmp3lame() {
  if [[ $disable_libmp3lame != 1 && $enable_libmp3lame == 1 ]]; then
	change_dir "$src_dir"
	do_svn_checkout https://svn.code.sf.net/p/lame/svn/trunk/lame libmp3lame r6525 # anything other than r6525 fails
	change_dir "$src_dir/libmp3lame"
	# sed -i.bak '1s/^\xEF\xBB\xBF//' libmp3lame/i386/nasm.h # Remove a UTF-8 BOM that breaks nasm if it's still there; should be fixed in trunk eventually https://sourceforge.net/p/lame/patches/81/
	generic_configure "--enable-nasm --enable-libmpg123"
	do_make_and_make_install
	change_dir "$src_dir"
	fi
}
#--enable-libtwolame (from build_twolame) - MP2 audio encoding.
build_libtwolame() {
  if [[ $disable_libtwolame != 1 && $enable_libtwolame == 1 ]]; then
	change_dir "$src_dir"
	do_git_checkout https://github.com/njh/twolame twolame "origin/main"
	change_dir "$src_dir/twolame"
	if [[ ! -f Makefile.am.bak ]]; then # Library only, front end refuses to build for some reason with git master
		sed -i.bak "/^SUBDIRS/s/ frontend.*//" Makefile.am || exit_message 1 "could not update makefile for twolame"
	fi
	cpu_count=1 # maybe can't handle it http://betterlogic.com/roger/2017/07/mp3lame-woe/ comments
	generic_configure_make_install
	cpu_count=$original_cpu_count
	change_dir "$src_dir"
	fi
}
#--enable-libopenmpt (from build_openmpt) - OpenMPT tracker music library.
build_libopenmpt() {
  if [[ $disable_libopenmpt != 1 && $enable_libopenmpt == 1 ]]; then
	build_flac
	change_dir "$src_dir"
	do_git_checkout https://github.com/OpenMPT/openmpt openmpt # OpenMPT-1.30
	change_dir "$src_dir/openmpt"
	# TODO: Allow shared library build
	do_make_and_make_install "PREFIX=$dependency_install_prefix CONFIG=mingw64-win64 EXESUFFIX=.exe SOSUFFIX=.dll SOSUFFIXWINDOWS=1 DYNLINK=0 SHARED_LIB=0 STATIC_LIB=1 
      SHARED_SONAME=0 IS_CROSS=1 NO_ZLIB=0 NO_LTDL=0 NO_DL=0 NO_MPG123=0 NO_OGG=0 NO_VORBIS=0 NO_VORBISFILE=0 NO_PORTAUDIO=1 NO_PORTAUDIOCPP=1 NO_PULSEAUDIO=1 NO_SDL=0 
      NO_SDL2=0 NO_SNDFILE=0 NO_FLAC=0 EXAMPLES=0 OPENMPT123=0 TEST=0" # OPENMPT123=1 >>> fail
	sed -i.bak 's/Libs.private.*/& -lrpcrt4/' "$PKG_CONFIG_PATH/libopenmpt.pc"
	change_dir "$src_dir"
	fi
}
# --enable-libopencore-amrnb (from build_libopencore) - AMR-NB audio codec.
# --enable-libopencore-amrwb enable AMR-WB decoding via libopencore-amrwb [no]
build_libopencore_amrnb() {
  if [[ $disable_libopencore_amrnb != 1 && $enable_libopencore_amrnb == 1 || $enable_libopencore_amrwb == 1 ]]; then
	change_dir "$src_dir"
	generic_download_and_make_and_install https://sourceforge.net/projects/opencore-amr/files/opencore-amr/opencore-amr-0.1.6.tar.gz
	change_dir "$src_dir"
	fi
}

build_libopencore_amrwb() {
  build_libopencore_amrnb
}

#--enable-libilbc (from build_libilbc) - iLBC speech audio codec.
build_libilbc() {
  if [[ $disable_libilbc != 1 && $enable_libilbc == 1 ]]; then
	change_dir "$src_dir"
	do_git_checkout https://github.com/TimothyGu/libilbc libilbc
	change_dir "$src_dir/libilbc"
	do_cmake "-B build -GNinja"
	do_ninja_and_ninja_install
	change_dir "$src_dir"
	fi
}
#--enable-libmodplug (from build_libmodplug) - ModPlug tracker music library.
build_libmodplug() {
  if [[ $disable_libmodplug != 1 && $enable_libmodplug == 1 ]]; then
	change_dir "$src_dir"
	do_git_checkout https://github.com/Konstanty/libmodplug
	change_dir "libmodplug"
	sed -i.bak 's/__declspec(dllexport)//' "$dependency_install_prefix/include/libmodplug/modplug.h" #strip DLL import/export directives
	sed -i.bak 's/__declspec(dllimport)//' "$dependency_install_prefix/include/libmodplug/modplug.h"
	generic_configure_make_install # or could use cmake I guess
	change_dir "$src_dir"
	fi
}
#--enable-libgme (from build_libgme) - Game Music Emu library.
build_libgme() {
  if [[ $disable_libgme != 1 && $enable_libgme == 1 ]]; then
	# do_git_checkout https://bitbucket.org/mpyne/game-music-emu
	change_dir "$src_dir"
	download_and_unpack_file "https://bitbucket.org/mpyne/game-music-emu/downloads/game-music-emu-0.6.3.tar.xz" "libgme"
	change_dir "$src_dir/libgme"
	do_cmake_and_install "-DENABLE_UBSAN=0"
	change_dir "$src_dir"
	fi
}
#--enable-libbluray (from build_libbluray) - Reading Blu-ray discs.
build_libbluray() {
  if [[ $disable_libbluray != 1 && $enable_libbluray == 1 ]]; then
	change_dir "$src_dir"
	do_git_checkout https://code.videolan.org/videolan/libbluray
	activate_meson
	change_dir "$src_dir/libbluray"
	apply_patch "https://raw.githubusercontent.com/m-ab-s/mabs-patches/master/libbluray/0001-dec-prefix-with-libbluray-for-now.patch" -p1
	local meson_options="-Denable_examples=false -Dbdj_jar=disabled --wrap-mode=default"
	local cross_file=$(get_meson_cross_file)
	meson_options+=" --cross-file=$cross_file"
	do_meson "$meson_options" "setup build"
	do_ninja_and_ninja_install # "CPPFLAGS=\"-Ddec_init=libbr_dec_init\""
	sed -i.bak 's/-lbluray.*/-lbluray -lstdc++ -lssp -lgdi32/' "$PKG_CONFIG_PATH/libbluray.pc"
	change_dir "$src_dir"
	fi
}
#--enable-libbs2b (from build_libbs2b) - Bauer stereophonic-to-binaural DSP.
build_libbs2b() {
  if [[ $disable_libbs2b != 1 && $enable_libbs2b == 1 ]]; then
	change_dir "$src_dir"
	download_and_unpack_file https://downloads.sourceforge.net/project/bs2b/libbs2b/3.1.0/libbs2b-3.1.0.tar.gz
	change_dir "$src_dir/libbs2b-3.1.0"
	apply_patch "file://$WINPATCHDIR/libbs2b.patch"
	sed -i.bak "s/AC_FUNC_MALLOC//" configure.ac # #270
	export LIBS=-lm                              # avoid pow failure linux native
	generic_configure_make_install
	unset LIBS
	change_dir "$src_dir"
	fi
}
#--enable-libsoxr (from build_libsoxr) - High-quality audio resampling.
build_libsoxr() {
  if [[ $disable_libsoxr != 1 && $enable_libsoxr == 1 ]]; then
	change_dir "$src_dir"
	do_git_checkout https://github.com/chirlu/soxr soxr
	change_dir "$src_dir/soxr"
	do_cmake_and_install "-DWITH_OPENMP=0 -DBUILD_TESTS=0 -DBUILD_EXAMPLES=0"
	change_dir "$src_dir"
	fi
}

#--enable-libflite (from build_libflite) - Flite text-to-speech synthesis.
build_libflite() {
  if [[ $disable_libflite != 1 && $enable_libflite == 1 ]]; then
	change_dir "$src_dir"
	do_git_checkout https://github.com/festvox/flite flite
	change_dir "$src_dir/flite"
	apply_patch "file://$WINPATCHDIR/flite-2.1.0_mingw-w64-fixes.patch"
	if [[ ! -f main/Makefile.bak ]]; then
		sed -i.bak "s/cp -pd/cp -p/" main/Makefile # friendlier cp for OS X
	fi
	generic_configure "--bindir=$dependency_install_prefix/bin --with-audio=none"
	do_make
	if [[ ! -f $dependency_install_prefix/lib/libflite.a ]]; then
		cp -rf ./build/x86_64-mingw32/lib/libflite* "$dependency_install_prefix/lib/"
		cp -rf include "$dependency_install_prefix/include/flite"
		# cp -rf ./bin/*.exe $dependency_install_prefix/bin # if want .exe's uncomment
	fi
	change_dir "$src_dir"
	fi
}
#--enable-libsnappy (from build_libsnappy) - Snappy compression, for hap encoding.
build_libsnappy() {
  if [[ $disable_libsnappy != 1 && $enable_libsnappy == 1 ]]; then
	change_dir "$src_dir"
	do_git_checkout https://github.com/google/snappy snappy # got weird failure once 1.1.8
	change_dir "$src_dir/snappy"
	do_cmake_and_install "-DBUILD_BINARY=OFF -DCMAKE_BUILD_TYPE=Release -DSNAPPY_BUILD_TESTS=OFF -DSNAPPY_BUILD_BENCHMARKS=OFF" # extra params from deadsix27 and from new cMakeLists.txt content
	remove_path -f "$dependency_install_prefix/lib/libsnappy.dll.a"                                                               # unintall shared :|
	change_dir "$src_dir"
	fi
}

build_vamp_plugin() {
	#download_and_unpack_file https://code.soundsoftware.ac.uk/attachments/download/2691/vamp-plugin-sdk-2.10.0.tar.gz
	change_dir "$src_dir"
	download_and_unpack_file https://github.com/vamp-plugins/vamp-plugin-sdk/archive/refs/tags/vamp-plugin-sdk-v2.10.zip vamp-plugin-sdk-vamp-plugin-sdk-v2.10
	#cd vamp-plugin-sdk-2.10.0
	change_dir "$src_dir/vamp-plugin-sdk-vamp-plugin-sdk-v2.10"
	apply_patch "file://$WINPATCHDIR/vamp-plugin-sdk-2.10_static-lib.diff"
	if [[ ! -f src/vamp-sdk/PluginAdapter.cpp.bak ]]; then
		sed -i.bak "s/#include <mutex>/#include <mingw.mutex.h>/" src/vamp-sdk/PluginAdapter.cpp
	fi
	if [[ ! -f configure.bak ]]; then # Fix for "'M_PI' was not declared in this scope" (see https://stackoverflow.com/a/29264536).
		sed -i.bak "s/c++11/gnu++11/" configure
		sed -i.bak "s/c++11/gnu++11/" Makefile.in
	fi
	do_configure "--host=$host_target --prefix=$dependency_install_prefix --disable-programs"
	# TODO: Allow shared library build
	do_make "install-static" # No need for 'do_make_install', because 'install-static' already has install-instructions.
	change_dir "$src_dir"
}

build_fftw() {
	change_dir "$src_dir"
	download_and_unpack_file http://fftw.org/fftw-3.3.10.tar.gz
	change_dir "$src_dir/fftw-3.3.10"
	# TODO: Allow shared library build
	generic_configure "--disable-doc --prefix=$dependency_install_prefix --host=$host_target --enable-static --disable-shared"
	do_make_and_make_install
	change_dir "$src_dir"
}
#--enable-chromaprint (from build_chromaprint) - Audio fingerprinting.
build_chromaprint() {
  if [[ $disable_chromaprint != 1 && $enable_chromaprint == 1 ]]; then
	echo -e "$dependency_install_prefix"
	build_fftw
	change_dir "$src_dir"
	do_git_checkout https://github.com/acoustid/chromaprint chromaprint
	change_dir "$src_dir/chromaprint"
	do_cmake_and_install "-DCMAKE_BUILD_TYPE=Release -DBUILD_TOOLS=OFF -DBUILD_TESTS=OFF -DFFT_LIB=fftw3 -DCMAKE_TOOLCHAIN_FILE=$(get_generic_cmake_toolchain)"
	change_dir "$src_dir"
	fi
}

build_libsamplerate() {
	# I think this didn't work with ubuntu 14.04 [too old automake or some odd] :|
	change_dir "$src_dir"
	do_git_checkout_and_make_install https://github.com/erikd/libsamplerate
	# but OS X can't use 0.1.9 :|
	# rubberband can use this, but uses speex bundled by default [any difference? who knows!]
	change_dir "$src_dir"
}
#--enable-librubberband (from build_librubberband) - High-quality audio time-stretching.
build_librubberband() {
  if [[ $disable_librubberband != 1 && $enable_librubberband == 1 ]]; then
	change_dir "$src_dir"
	do_git_checkout https://github.com/breakfastquay/rubberband rubberband 18c06ab8c431854056407c467f4755f761e36a8e
	change_dir "$src_dir/rubberband"
	apply_patch "file://$WINPATCHDIR/rubberband_git_static-lib.diff" # create install-static target
	do_configure "--host=$host_target --prefix=$dependency_install_prefix --disable-ladspa"
	# TODO: Allow shared library build
	do_make "install-static AR=${cross_prefix}ar" # No need for 'do_make_install', because 'install-static' already has install-instructions.
	sed -i.bak 's/-lrubberband.*$/-lrubberband -lfftw3 -lsamplerate -lstdc++/' "$PKG_CONFIG_PATH/rubberband.pc"
	change_dir "$src_dir"
	fi
}
#--enable-frei0r (from build_frei0r) - External frei0r video filter plugins.
build_frei0r() {
  if [[ $disable_frei0r != 1 && $enable_frei0r == 1 ]]; then
	#do_git_checkout https://github.com/dyne/frei0r
	#cd frei0r
	change_dir "$src_dir"
	download_and_unpack_file https://github.com/dyne/frei0r/archive/refs/tags/v2.3.3.tar.gz frei0r-2.3.3
	change_dir "$src_dir/frei0r-2.3.3"
	sed -i.bak 's/-arch i386//' CMakeLists.txt # OS X https://github.com/dyne/frei0r/issues/64
	do_cmake_and_install "-DWITHOUT_OPENCV=1"  # XXX could look at this more...

	create_dir "$src_dir/redist" # Strip and pack shared libraries.
	if [ "$bits_target" = 32 ]; then
		local arch=x86
	else
		local arch=x86_64
	fi
	archive="$src_dir/redist/frei0r-plugins-${arch}-$(git describe --tags).7z"
	if [[ ! -f "$archive.done" ]]; then
		for sharedlib in "$dependency_install_prefix"/lib/frei0r-1/*.dll; do
			# shellcheck disable=SC2086
			"${cross_prefix}strip" $sharedlib
		done
		for doc in AUTHORS ChangeLog COPYING README.md; do
			sed "s/$/\r/" "$doc" > "$dependency_install_prefix/lib/frei0r-1/$doc.txt"
		done
		7z a -mx=9 "$archive $dependency_install_prefix/lib/frei0r-1" && remove_path -f "$dependency_install_prefix/lib/frei0r-1/*.txt"
		create_touch_file 0 "$archive.done" # for those with no 7z so it won't restrip every time
	fi
	change_dir "$src_dir"
	fi
}
#--enable-libsvtav1 (from build_svt_av1) - High-performance AV1 video encoding.
build_libsvtav1() {
  if [[ $disable_libsvtav1 != 1 && $enable_libsvtav1 == 1 ]]; then
	if [[ "$bits_target" != "32" ]]; then
		build_cpuinfo
		change_dir "$src_dir"
		do_git_checkout https://gitlab.com/AOMediaCodec/SVT-AV1 SVT-AV1
		change_dir "$src_dir/SVT-AV1"
		do_cmake "-B build -GNinja -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF -DUSE_CPUINFO=SYSTEM" # -DSVT_AV1_LTO=OFF if fails try adding this
		do_ninja_and_ninja_install
		change_dir "$src_dir"
	fi
	fi
}
#--enable-libvidstab (from build_vidstab) - Video stabilization filters.
build_libvidstab() {
  if [[ $disable_libvidstab != 1 && $enable_libvidstab == 1 ]]; then
	change_dir "$src_dir"
	do_git_checkout https://github.com/georgmartius/vid.stab vid.stab
	change_dir "$src_dir/vid.stab"
	do_cmake_and_install "-DUSE_OMP=0" # '-DUSE_OMP' is on by default, but somehow libgomp ('cygwin_local_install/lib/gcc/i686-pc-cygwin/5.4.0/include/omp.h') can't be found, so '-DUSE_OMP=0' to prevent a compilation error.
	change_dir "$src_dir"
	fi
}
#--enable-libmysofa (from build_libmysofa) - Sofalizer filter for HRTF audio.
build_libmysofa() {
  if [[ $disable_libmysofa != 1 && $enable_libmysofa == 1 ]]; then
	change_dir "$src_dir"
	do_git_checkout https://github.com/hoene/libmysofa libmysofa "origin/main"
	change_dir "$src_dir/libmysofa"
	local cmake_params="-DBUILD_TESTS=0"
	do_cmake "$cmake_params"
	do_make_and_make_install
	change_dir "$src_dir"
	fi
}
#--enable-decklink (from build_libdecklink) - Blackmagic DeckLink I/O support.
build_decklink() {
  if [[ $disable_decklink != 1 && $enable_decklink == 1 ]]; then
  echo "WARNING: Including this library will make the binaries non-redistributable"
	change_dir "$src_dir"
	do_git_checkout https://gitlab.com/m-ab-s/decklink-headers decklink-headers 47d84f8d272ca6872b5440eae57609e36014f3b6
	change_dir "$src_dir/decklink-headers"
	do_make_install "PREFIX=$dependency_install_prefix"
	change_dir "$src_dir"
	fi
}
#--enable-libzvbi (from build_zvbi) - Teletext support.
build_libzvbi() {
  if [[ $disable_libzvbi != 1 && $enable_libzvbi == 1 ]]; then
	change_dir "$src_dir"
	do_git_checkout https://github.com/zapping-vbi/zvbi zvbi
	change_dir "$src_dir/zvbi"
	generic_configure "--disable-dvb --disable-bktr --disable-proxy --disable-nls --without-doxygen --disable-examples --disable-tests --without-libiconv-prefix"
	do_make_and_make_install
	change_dir "$src_dir"
	fi
}
#--enable-libfribidi (from build_fribidi) - Bidirectional text support for drawtext.
build_libfribidi() {
  if [[ $disable_libfribidi != 1 && $enable_libfribidi == 1 ]]; then
	change_dir "$src_dir"
	download_and_unpack_file https://github.com/fribidi/fribidi/releases/download/v1.0.16/fribidi-1.0.16.tar.xz # Get c2man errors building from repo
	change_dir "$src_dir/fribidi-1.0.16"
	generic_configure "--disable-debug --disable-deprecated --disable-docs"
	do_make_and_make_install
	change_dir "$src_dir"
	fi
}
#--enable-libass (from build_libass) - Advanced subtitle rendering (.ass, .ssa).
build_libass() {
  if [[ $disable_libass != 1 && $enable_libass == 1 ]]; then
	change_dir "$src_dir"
	do_git_checkout_and_make_install https://github.com/libass/libass
	change_dir "$src_dir"
	fi
}
#--enable-libxvid (from build_libxvid) - Xvid (MPEG-4) video encoding.
build_libxvid() {
  if [[ $disable_libxvid != 1 && $enable_libxvid == 1 ]]; then
	change_dir "$src_dir"
	download_and_unpack_file https://downloads.xvid.com/downloads/xvidcore-1.3.7.tar.gz xvidcore
	change_dir "$src_dir/xvidcore/build/generic"
	apply_patch "file://$WINPATCHDIR/xvidcore-1.3.7_static-lib.patch"
	do_configure "--host=$host_target --prefix=$dependency_install_prefix" # no static option...
	do_make_and_make_install
	change_dir "$src_dir"
	fi
}
#--enable-libsrt (from build_libsrt) - SRT secure reliable transport protocol.
build_libsrt() {
  if [[ $disable_libsrt != 1 && $enable_libsrt == 1 ]]; then
	# do_git_checkout https://github.com/Haivision/srt # might be able to use these days...?
	change_dir "$src_dir"
	download_and_unpack_file https://github.com/Haivision/srt/archive/v1.5.4.tar.gz srt-1.5.4
	change_dir "$src_dir/srt-1.5.4"
	apply_patch "file://$WINPATCHDIR/srt.app.patch" -p1
	# CMake Warning at CMakeLists.txt:893 (message):
	#   On MinGW, some C++11 apps are blocked due to lacking proper C++11 headers
	#   for <thread>.  FIX IF POSSIBLE.
	do_cmake "-DUSE_ENCLIB=gnutls -DENABLE_SHARED=OFF -DENABLE_CXX11=OFF"
	do_make_and_make_install
	change_dir "$src_dir"
	fi
}
#--enable-libaribcaption (from build_libaribcaption) - ARIB caption decoding.
build_libaribcaption() {
  if [[ $disable_libaribcaption != 1 && $enable_libaribcaption == 1 ]]; then
	if [[ $ffmpeg_git_checkout_version != *"n6.0"* ]] && [[ $ffmpeg_git_checkout_version != *"n5"* ]] && [[ $ffmpeg_git_checkout_version != *"n4"* ]] && [[ $ffmpeg_git_checkout_version != *"n3"* ]] && [[ $ffmpeg_git_checkout_version != *"n2"* ]]; then
		change_dir "$src_dir"
		do_git_checkout https://github.com/xqq/libaribcaption
		mkdir libaribcaption/build
		change_dir "$src_dir/libaribcaption/build"
		do_cmake_from_build_dir "$src_dir/libaribcaption" "-DCMAKE_BUILD_TYPE=Release"
		do_make_and_make_install
		change_dir "$src_dir"
	fi
	fi
}
#--enable-libaribb24 (from build_libaribb24) - ARIB caption decoding.
build_libaribb24() {
  if [[ $disable_libaribb24 != 1 && $enable_libaribb24 == 1 ]]; then
	change_dir "$src_dir"
	do_git_checkout_and_make_install https://github.com/nkoriyama/aribb24
	change_dir "$src_dir"
	fi
}
#--enable-libtesseract (from build_libtesseract) - OCR filter for reading text from video.
build_libtesseract() {
  if [[ $disable_libtesseract != 1 && $enable_libtesseract == 1 ]]; then
	build_libtiff
	build_libleptonica
	build_libarchive
	change_dir "$src_dir"
	do_git_checkout https://github.com/tesseract-ocr/tesseract tesseract
	change_dir "$src_dir/tesseract"
	export CPPFLAGS="$CPPFLAGS -DCURL_STATICLIB"
	generic_configure "--disable-openmp --with-archive --disable-graphics --disable-tessdata-prefix --with-curl LIBLEPT_HEADERSDIR=$dependency_install_prefix/include --datadir=$dependency_install_prefix/bin"
	do_make_and_make_install
	sed -i.bak 's/Requires.private.*/& lept libarchive liblzma libtiff-4 libcurl/' "$PKG_CONFIG_PATH/tesseract.pc"
	sed -i 's/-ltesseract.*$/-ltesseract -lstdc++ -lws2_32 -lbz2 -lz -liconv -lpthread  -lgdi32 -lcrypt32/' "$PKG_CONFIG_PATH/tesseract.pc"
	if [[ ! -f $dependency_install_prefix/bin/tessdata/tessdata/eng.traineddata ]]; then
		create_dir "$dependency_install_prefix/bin/tessdata"
		cp -f /usr/share/tesseract-ocr/**/tessdata/eng.traineddata "$dependency_install_prefix/bin/tessdata/"
	fi
	reset_cppflags
	change_dir "$src_dir"
	fi
}
#--enable-liblensfun (from build_lensfun) - Lens correction filter.
build_liblensfun() {
  if [[ $disable_liblensfun != 1 && $enable_liblensfun == 1 ]]; then
	build_glib
	change_dir "$src_dir"
	do_git_checkout "https://github.com/lensfun/lensfun.git" "lensfun"
	change_dir "$src_dir/lensfun"
	export CPPFLAGS="$CPPFLAGS -DGLIB_STATIC_COMPILATION"
	export CXXFLAGS="$CFLAGS -DGLIB_STATIC_COMPILATION"
	# TODO: Allow shared library build
	do_cmake "-DBUILD_STATIC=on -DCMAKE_INSTALL_DATAROOTDIR=$dependency_install_prefix -DBUILD_TESTS=off -DBUILD_DOC=off -DINSTALL_HELPER_SCRIPTS=off -DINSTALL_PYTHON_MODULE=OFF"
	do_make_and_make_install
	sed -i.bak 's/-llensfun/-llensfun -lstdc++/' "$PKG_CONFIG_PATH/lensfun.pc"
	reset_cppflags
	unset CXXFLAGS
	change_dir "$src_dir"
	fi
}
#--enable-libtensorflow (from build_libtensorflow) - TensorFlow support for AI filters.
build_libtensorflow() {
  if [[ $disable_libtensorflow != 1 && $enable_libtensorflow == 1 ]]; then
	change_dir "$src_dir"
	if [[ ! -e Tensorflow ]]; then
		create_dir "$src_dir/Tensorflow"
		change_dir "$src_dir/Tensorflow"
		wget "https://storage.googleapis.com/tensorflow/versions/2.18.1/libtensorflow-cpu-windows-x86_64.zip" # tensorflow.dll required by ffmpeg to run
		unzip -o "libtensorflow-cpu-windows-x86_64.zip" -d "$dependency_install_prefix"
		remove_path -f "libtensorflow-cpu-windows-x86_64.zip"
		change_dir ..
	else
		echo -e "Tensorflow already installed"
	fi
	change_dir "$src_dir"
	fi
}
#--enable-libvpx (from build_libvpx) - VP8/VP9 video encoding/decoding.
build_libvpx() {
  if [[ $disable_libvpx != 1 && $enable_libvpx == 1 ]]; then
	change_dir "$src_dir"
	do_git_checkout https://chromium.googlesource.com/webm/libvpx libvpx "origin/main"
	change_dir "$src_dir/libvpx"
	# apply_patch file://$WINPATCHDIR/vpx_160_semaphore.patch -p1 # perhaps someday can remove this after 1.6.0 or mingw fixes it LOL
	if [[ "$bits_target" = "32" ]]; then
		local config_options="--target=x86-win32-gcc"
	else
		local config_options="--target=x86_64-win64-gcc"
	fi
	export CROSS="$cross_prefix"
	# VP8 encoder *requires* sse3 support
	# TODO: Allow shared library build
	do_configure "$config_options --prefix=$dependency_install_prefix --enable-ssse3 --enable-static --disable-shared --disable-examples --disable-tools --disable-docs --disable-unit-tests --enable-vp9-highbitdepth --extra-cflags=-fno-asynchronous-unwind-tables --extra-cflags=-mstackrealign" # fno for Error: invalid register for .seh_savexmm
	do_make_and_make_install
	unset CROSS
	change_dir "$src_dir"
	fi
}
#--enable-libx265 (from build_libx265) - HEVC (H.265) video encoding.
build_libx265() {
  if [[ $disable_libx265 != 1 && $enable_libx265 == 1 ]]; then
	change_dir "$src_dir"
	local checkout_dir=x265
	local remote="https://bitbucket.org/multicoreware/x265"
	if [[ -n $x265_git_checkout_version ]]; then
		checkout_dir+="_$x265_git_checkout_version"
		do_git_checkout "$remote" "$checkout_dir" "$x265_git_checkout_version"
	else
		if [[ $prefer_stable = "n" ]]; then
			checkout_dir+="_unstable"
			do_git_checkout "$remote" "$checkout_dir" "origin/master"
		fi
		if [[ $prefer_stable = "y" ]]; then
			do_git_checkout "$remote" "$checkout_dir" "origin/stable"
		fi
	fi
	change_dir "$checkout_dir"

	local cmake_params="-DENABLE_SHARED=0" # build x265.exe

	# Apply x86 noasm detection fix on newer versions
	if [[ $x265_git_checkout_version != *"3.5"* ]] && [[ $x265_git_checkout_version != *"3.4"* ]] && [[ $x265_git_checkout_version != *"3.3"* ]] && [[ $x265_git_checkout_version != *"3.2"* ]] && [[ $x265_git_checkout_version != *"3.1"* ]]; then
		git apply "$WINPATCHDIR/x265_x86_noasm_fix.patch"
	fi

	if [ "$bits_target" = "32" ]; then
		cmake_params+=" -DWINXP_SUPPORT=1" # enable windows xp/vista compatibility in x86 build, since it still can I think...
	fi
	create_dir 8bit 10bit 12bit

	# Build 12bit (main12)
	change_dir 12bit
	local cmake_12bit_params="$cmake_params -DENABLE_CLI=0 -DHIGH_BIT_DEPTH=1 -DMAIN12=1 -DEXPORT_C_API=0"
	if [ "$bits_target" = "32" ]; then
		cmake_12bit_params="$cmake_12bit_params -DENABLE_ASSEMBLY=OFF" # apparently required or build fails
	fi
	do_cmake_from_build_dir ../source "$cmake_12bit_params"
	do_make
	cp libx265.a ../8bit/libx265_main12.a

	# Build 10bit (main10)
	change_dir ../10bit
	local cmake_10bit_params="$cmake_params -DENABLE_CLI=0 -DHIGH_BIT_DEPTH=1 -DENABLE_HDR10_PLUS=1 -DEXPORT_C_API=0"
	if [ "$bits_target" = "32" ]; then
		cmake_10bit_params="$cmake_10bit_params -DENABLE_ASSEMBLY=OFF" # apparently required or build fails
	fi
	do_cmake_from_build_dir ../source "$cmake_10bit_params"
	do_make
	cp libx265.a ../8bit/libx265_main10.a

	# Build 8 bit (main) with linked 10 and 12 bit then install
	change_dir ../8bit
	cmake_params="$cmake_params -DENABLE_CLI=1 -DEXTRA_LINK_FLAGS=-L. -DLINKED_10BIT=1 -DLINKED_12BIT=1"
	cmake_params+=" -DEXTRA_LIB='$(pwd)/libx265_main10.a;$(pwd)/libx265_main12.a'"
	do_cmake_from_build_dir ../source "$cmake_params"
	do_make
	mv libx265.a libx265_main.a
		"${cross_prefix}ar" -M <<EOF
CREATE libx265.a
ADDLIB libx265_main.a
ADDLIB libx265_main10.a
ADDLIB libx265_main12.a
SAVE
END
EOF
	make install # force reinstall in case you just switched from stable to not :|
	change_dir "$src_dir"
	fi
}
#--enable-libopenh264 (from build_libopenh264) - H.264 video encoding from Cisco.
build_libopenh264() {
  if [[ $disable_libopenh264 != 1 && $enable_libopenh264 == 1 ]]; then
	change_dir "$src_dir"
	do_git_checkout "https://github.com/cisco/openh264.git" openh264 v2.6.0 #75b9fcd2669c75a99791 # wels/codec_api.h weirdness
	change_dir "$src_dir/openh264"
	sed -i.bak "s/_M_X64/_M_DISABLED_X64/" codec/encoder/core/inc/param_svc.h # for 64 bit, avoid missing _set_FMA3_enable, it needed to link against msvcrt120 to get this or something weird?
	if [[ $bits_target == 32 ]]; then
		local arch=i686 # or x86?
	else
		local arch=x86_64
	fi
	# TODO: Allow shared library build
	do_make "$compiler_flags OS=mingw_nt ARCH=$arch ASM=yasm install-static"
	change_dir "$src_dir"
  fi
}
# --enable-libaom (from build_libaom) - AV1 video encoding/decoding.
build_libaom() {
  if [[ $disable_libaom != 1 && $enable_libaom == 1 ]]; then
	change_dir "$src_dir"
	do_git_checkout https://aomedia.googlesource.com/aom aom
	if [ "$bits_target" = "32" ]; then
		local config_options="-DCMAKE_TOOLCHAIN_FILE=../build/cmake/toolchains/x86-mingw-gcc.cmake -DAOM_TARGET_CPU=x86"
	else
		local config_options="-DCMAKE_TOOLCHAIN_FILE=../build/cmake/toolchains/x86_64-mingw-gcc.cmake -DAOM_TARGET_CPU=x86_64"
	fi
	create_dir "$src_dir/aom/aom_build"
	change_dir "$src_dir/aom/aom_build"
	do_cmake_from_build_dir "$src_dir/aom" "$config_options"
	do_make_and_make_install
	change_dir "$src_dir"
	fi
}
#--enable-libdav1d (from build_dav1d) - High-performance AV1 video decoding.
build_libdav1d() {
  if [[ $disable_libdav1d != 1 && $enable_libdav1d == 1 ]]; then
	change_dir "$src_dir"
	do_git_checkout https://code.videolan.org/videolan/dav1d libdav1d
	activate_meson
	change_dir "$src_dir/libdav1d"
	if [[ $bits_target == 32 || $bits_target == 64 ]]; then   # XXX why 64???
		apply_patch "file://$WINPATCHDIR/david_no_asm.patch" -p1 # XXX report
	fi
	cpu_count=1 # XXX report :|
	local meson_options="-Denable_tests=false -Denable_examples=false"
	local cross_file=$(get_meson_cross_file)
	meson_options+=" --cross-file=$cross_file"
	do_meson "$meson_options" "setup build"
	do_ninja_and_ninja_install
	copy_path "$src_dir/build/src/libdav1d.a" "$dependency_install_prefix/lib" || exit_message 1 "could not copy $src_dir/build/src/libdav1d.a" # avoid 'run ranlib' weird failure, possibly older meson's https://github.com/mesonbuild/meson/issues/4138 :|
	cpu_count=$original_cpu_count
	change_dir "$src_dir"
	fi
}
# --enable-vulkan (from build_vulkan) - Vulkan support.
# --disable-vulkan         disable Vulkan code [autodetect]
build_vulkan() {
  if [[ $disable_vulkan != 1 && $enable_vulkan == 1 ]]; then
	change_dir "$src_dir"
	do_git_checkout https://github.com/KhronosGroup/Vulkan-Headers Vulkan-Headers v1.4.326
	change_dir "$src_dir/Vulkan-Headers"
	do_cmake_and_install "-DCMAKE_BUILD_TYPE=Release -DVULKAN_HEADERS_ENABLE_MODULE=NO -DVULKAN_HEADERS_ENABLE_TESTS=NO -DVULKAN_HEADERS_ENABLE_INSTALL=YES"
	change_dir "$src_dir"
	fi
}
# --enable-vulkan-static         # enable statically link to libvulkan [no]
build_vulkan_static() {
  if [[ $disable_vulkan_static != 1 && $enable_vulkan_static == 1 ]]; then
	build_vulkan_loader
	fi
}
#--enable-libplacebo (from build_libplacebo) - Advanced video rendering library (Vulkan/OpenGL).
build_libplacebo() {
  if [[ $disable_libplacebo != 1 && $enable_libplacebo == 1 ]]; then
	build_vulkan_loader
	build_lcms
	build_libunwind
	build_libxxhash
	build_spirv_cross
	build_libdovi
	build_libshaderc
	change_dir "$src_dir"
	do_git_checkout https://code.videolan.org/videolan/libplacebo libplacebo #515da9548ad734d923c7d0988398053f87b454d5
	activate_meson
	change_dir "$src_dir/libplacebo"
	apply_patch "file://$WINPATCHDIR/fix_libplacebo_absolute_path.patch" -p1 # latest meson version wont work without patch
	git submodule update --init --recursive --depth=1 --filter=blob:none
	local config_options=""
	local config_options+=" -Dvulkan-registry=$dependency_install_prefix/share/vulkan/registry/vk.xml"
	# TODO: Allow shared library build
	local meson_options="-Ddemos=false -Dbench=false -Dfuzz=false -Dvulkan=enabled -Dvk-proc-addr=disabled -Dglslang=disabled -Dc_link_args=-static -Dcpp_link_args=-static $config_options" # https://mesonbuild.com/Dependencies.html#shaderc trigger use of shaderc_combined
	if [[ $disable_libshaderc != 1 && $enable_libshaderc == 1 ]]; then
    meson_options+=" -Dshaderc=enabled"
  else
    meson_options+=" -Dshaderc=disabled"
  fi
  local cross_file=$(get_meson_cross_file)
	meson_options+=" --cross-file=$cross_file"
	do_meson "$meson_options" "setup build"
	do_ninja_and_ninja_install
	sed -i.bak 's/-lplacebo.*$/-lplacebo -lm -lshlwapi -lunwind -lxxhash -lversion -lstdc++/' "$PKG_CONFIG_PATH/libplacebo.pc"
	change_dir "$src_dir"
	fi
}
#--enable-avisynth (from build_avisynth) - AviSynth script support.
build_avisynth() {
  if [[ $disable_avisynth != 1 && $enable_avisynth == 1 ]]; then
	change_dir "$src_dir"
	do_git_checkout https://github.com/AviSynth/AviSynthPlus avisynth
	create_dir "$src_dir/avisynth/avisynth-build"
	change_dir "$src_dir/avisynth/avisynth-build"
	do_cmake_from_build_dir "$src_dir/avisynth" -DHEADERS_ONLY:bool=on
	do_make "$compiler_flags VersionGen install"
	change_dir "$src_dir"
	fi
}
#--enable-libvvenc (from build_libvvenc) - VVC (H.266) video encoding.
build_libvvenc() {
  if [[ $disable_libvvenc != 1 && $enable_libvvenc == 1 ]]; then
	change_dir "$src_dir"
	do_git_checkout https://github.com/fraunhoferhhi/vvenc libvvenc
	change_dir "$src_dir/libvvenc"
	do_cmake "-B build -DCMAKE_BUILD_TYPE=Release -DVVENC_ENABLE_LINK_TIME_OPT=OFF -DVVENC_INSTALL_FULLFEATURE_APP=ON -GNinja"
	do_ninja_and_ninja_install
	change_dir "$src_dir"
	fi
}

#--enable-libx264 (from build_libx264) - High-quality H.264 video encoding.
build_libx264() {
  if [[ $disable_libx264 != 1 && $enable_libx264 == 1 ]]; then
	change_dir "$src_dir"
	local checkout_dir="x264"
	if [[ $build_x264_with_libav == "y" ]]; then
		# TODO: Allow shared library build
		build_ffmpeg static --disable-libx264 ffmpeg_git_pre_x264 # installs libav locally so we can use it within x264.exe FWIW...
		checkout_dir="${checkout_dir}_with_libav"
		# they don't know how to use a normal pkg-config when cross compiling, so specify some manually: (see their mailing list for a request...)
		export LAVF_LIBS="$LAVF_LIBS $(pkg-config --libs libavformat libavcodec libavutil libswscale)"
		export LAVF_CFLAGS="$LAVF_CFLAGS $(pkg-config --cflags libavformat libavcodec libavutil libswscale)"
		export SWSCALE_LIBS="$SWSCALE_LIBS $(pkg-config --libs libswscale)"
	fi

	local x264_profile_guided=n # or y -- haven't gotten this proven yet...TODO

	if [[ $prefer_stable = "n" ]]; then
		checkout_dir="${checkout_dir}_unstable"
		do_git_checkout "https://code.videolan.org/videolan/x264.git" "$checkout_dir" "origin/master"
	else
		do_git_checkout "https://code.videolan.org/videolan/x264.git" "$checkout_dir" "origin/stable"
	fi
	change_dir "$checkout_dir"
	if [[ ! -f configure.bak ]]; then # Change CFLAGS.
		sed -i.bak "s/O3 -/O2 -/" configure
	fi
	# TODO: Allow shared library build
	local configure_flags="--host=$host_target --enable-static --cross-prefix=$cross_prefix --prefix=$dependency_install_prefix --enable-strip" # --enable-win32thread --enable-debug is another useful option here?
	if [[ $build_x264_with_libav == "n" ]]; then
		configure_flags+=" --disable-lavf" # lavf stands for libavformat, there is no --enable-lavf option, either auto or disable...
	fi
	configure_flags+=" --bit-depth=all"
	for i in $CFLAGS; do
		configure_flags+=" --extra-cflags=$i" # needs it this way seemingly :|
	done

	if [[ $x264_profile_guided = y ]]; then
		# I wasn't able to figure out how/if this gave any speedup...
		# TODO more march=native here?
		# TODO profile guided here option, with wine?
		do_configure "$configure_flags"
		curl -4 http://samples.mplayerhq.hu/yuv4mpeg2/example.y4m.bz2 -O --fail || exit_message 1 "could not download from http://samples.mplayerhq.hu/yuv4mpeg2/example.y4m.bz2"
		remove_path -f example.y4m # in case it exists already...
		bunzip2 example.y4m.bz2 || exit_message 1 "could not unzip example.y4m.bz2"
		# XXX does this kill git updates? maybe a more general fix, since vid.stab does also?
		sed -i.bak "s_\\, ./x264_, wine ./x264_" Makefile     # in case they have wine auto-run disabled http://askubuntu.com/questions/344088/how-to-ensure-wine-does-not-auto-run-exe-files
		do_make_and_make_install "fprofiled VIDS=example.y4m" # guess it has its own make fprofiled, so we don't need to manually add -fprofile-generate here...
	else
		# normal path non profile guided
		do_configure "$configure_flags"
		do_make
		make install # force reinstall in case changed stable -> unstable
	fi

	unset LAVF_LIBS
	unset LAVF_CFLAGS
	unset SWSCALE_LIBS
	change_dir "$src_dir"
	fi
}

#     --enable-libcodec2 (Low-bitrate speech/video codec)
# shellcheck disable=SC2082
build_libcodec2() {
  if [[ $disable_libcodec2 != 1 && $enable_libcodec2 == 1 ]]; then
	change_dir "$src_dir"
	local lib="codec2"
	do_git_checkout https://github.com/drowe67/codec2
	change_dir "$src_dir/$lib/build" 1
	local cmake_params="-DUNITTEST=FALSE"
	cmake_params+=" -DCMAKE_TOOLCHAIN_FILE=$(get_generic_cmake_toolchain) "
	local target_proc=AMD64
	if [ "$bits_target" = "32" ]; then
		target_proc=X86
	fi
	copy_path "$WINPATCHDIR/codec2_GetDependencies.cmake.in" "$src_dir/$lib/cmake/GetDependencies.cmake.in" "-f"
	do_cmake_from_build_dir "$src_dir/$lib" "$cmake_params"
	do_make_and_make_install
	change_dir "$src_dir"
  fi
}

#     --enable-libjxl (JPEG XL image format)
build_libjxl() {
  if [[ $disable_libjxl != 1 && $enable_libjxl == 1 ]]; then
	change_dir "$src_dir"
	local lib="libjxl"
	do_git_checkout https://github.com/libjxl/libjxl
	change_dir "$src_dir/$lib/build" 1
	local cmake_params=" -DCMAKE_TOOLCHAIN_FILE=$(get_generic_cmake_toolchain) -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF"
	local target_proc=AMD64
	if [ "$bits_target" = "32" ]; then
		target_proc=X86
	fi
	do_cmake_from_build_dir "$src_dir/$lib" "$cmake_params"
	do_make_and_make_install
	change_dir "$src_dir"
	fi
}

#     --enable-libkvazaar (Alternative HEVC/H.265 encoder)
build_libkvazaar() {
  if [[ $disable_libkvazaar != 1 && $enable_libkvazaar == 1 ]]; then
	local lib="kvazaar"
	change_dir "$src_dir"
	do_git_checkout https://github.com/ultravideo/kvazaar
	change_dir "$src_dir/$lib/build" 1
	local cmake_params=" -DCMAKE_TOOLCHAIN_FILE=$(get_generic_cmake_toolchain) -DCMAKE_BUILD_TESTS=OFF"
	local target_proc=AMD64
	if [ "$bits_target" = "32" ]; then
		target_proc=X86
	fi
	do_cmake_from_build_dir "$src_dir/$lib" "$cmake_params"
	do_make_and_make_install
	change_dir "$src_dir"
	fi
}
# --enable-openssl  enable openssl, needed for https support if gnutls, libtls or mbedtls is not used [no]
build_openssl() {
  if [[ $disable_openssl != 1 && $enable_openssl == 1 ]]; then
  local lib="openssl"
	# https://github.com/openssl/openssl 
	change_dir "$src_dir"
	do_git_checkout https://github.com/openssl/openssl "openssl" "openssl-3.6.0"
	change_dir "$src_dir/$lib"
  do_configure "mingw64 --release --cross-compile-prefix=$cross_prefix --prefix=$dependency_install_prefix --openssldir=$dependency_install_prefix/ssl --libdir=lib no-shared no-tests no-docs no-demos no-legacy" "./Configure"
	do_make_and_make_install
	change_dir "$src_dir"
	fi
}

#     --enable-librav1e (Alternative AV1 encoder written in Rust)
build_librav1e() {
  if [[ $disable_librav1e != 1 && $enable_librav1e == 1 ]]; then
	local lib="librav1e"
	# https://github.com/xiph/rav1e
	change_dir "$src_dir"
  do_git_checkout https://github.com/xiph/rav1e "$lib"
	change_dir "$src_dir/$lib"
  unset CC CXX AR WINDRES STRIP PKG_CONFIG_ALLOW_CROSS
  export CROSS_ROOT=$toolchain_bin_path
  export PATH=$CROSS_ROOT:$PATH
  export CC="${cross_prefix}gcc"
  export CXX="${cross_prefix}g++"
  export AR="${cross_prefix}ar"
  export WINDRES="${cross_prefix}windres"
  export STRIP="${cross_prefix}strip"
  export PKG_CONFIG_ALLOW_CROSS=1
  export CFLAGS="-static -O3 -I$dependency_install_prefix/include -L$dependency_install_prefix/lib"
  export CXXFLAGS="-static -O3 -I$dependency_install_prefix/include -L$dependency_install_prefix/lib"
  export RUSTFLAGS="-C target-feature=+crt-static -C target-cpu=x86-64"
  export CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER="${cross_prefix}gcc"
  export CARGO_TARGET_X86_64_PC_WINDOWS_GNU_AR="${cross_prefix}ar"
  export CC_x86_64_pc_windows_gnu="${cross_prefix}gcc"
  export CXX_x86_64_pc_windows_gnu="${cross_prefix}g++"
  export AR_x86_64_pc_windows_gnu="${cross_prefix}ar"
  confirm_libgcc_eh "$toolchain_root_dir/lib/gcc"
	cargo_build_and_install "--no-default-features --features=asm,binaries --profile release-no-lto" "--no-default-features --library-type=staticlib --features=asm,binaries"
	change_dir "$src_dir"
	fi
}

#     --enable-libxeve (EVC encoder)
build_libxeve() {
  if [[ $disable_libxeve != 1 && $enable_libxeve == 1 ]]; then
	local lib="xeve"
	# encoder
	# https://github.com/mpeg5/xeve
	change_dir "$src_dir"
	do_git_checkout https://github.com/mpeg5/xeve "$lib" "$lib-0.5.0"
	change_dir "$src_dir/$lib/build" 1
	local cmake_params=" -DCMAKE_TOOLCHAIN_FILE=$(get_generic_cmake_toolchain)"
	local target_proc=AMD64
	if [ "$bits_target" = "32" ]; then
		target_proc=X86
	fi
# needs a version.txt file but git repo doesnt have one for some reason
	if [ -d .git ]; then
			# Get version from git tags
			VERSION=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.5.0")
	else
			# Use default version
			VERSION="v0.5.0"
	fi
cat >"$src_dir/$lib/version.txt" <<EOF
$VERSION
EOF
	do_cmake_from_build_dir "$src_dir/$lib" "$cmake_params"
	do_make_and_make_install
	change_dir "$src_dir"
	fi
}

#     --enable-libxevd (EVC decoder)
build_libxevd() {
  if [[ $disable_libxevd != 1 && $enable_libxevd == 1 ]]; then
	local lib="xevd"
	# decoder
	# https://github.com/mpeg5/xevd
	change_dir "$src_dir"
	do_git_checkout https://github.com/mpeg5/xevd "$lib" "$lib-0.5.0"
	change_dir "$src_dir/$lib/build" 1
	local cmake_params=" -DCMAKE_TOOLCHAIN_FILE=$(get_generic_cmake_toolchain)"
	local target_proc=AMD64
	if [ "$bits_target" = "32" ]; then
		target_proc=X86
	fi
# needs a version.txt file but git repo doesnt have one for some reason
	if [ -d .git ]; then
			# Get version from git tags
			VERSION=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.5.0")
	else
			# Use default version
			VERSION="v0.5.0"
	fi
cat >"$src_dir/$lib/version.txt" <<EOF
$VERSION
EOF
	do_cmake_from_build_dir "$src_dir/$lib" "$cmake_params"
	do_make_and_make_install
	change_dir "$src_dir"
	fi
}

#     --enable-ladspa (LADSPA audio plugins) An API standard for audio plugins.
build_ladspa() {
  if [[ $disable_ladspa != 1 && $enable_ladspa == 1 ]]; then
  # TODO: LINUX --enable-ladspa
  echo "Only available in Linux build"
# 		# linux only
# 		#  http://www.ladspa.org/download/ladspa_sdk_1.17.tgz
	local lib="ladspa"
# 		change_dir "$src_dir"
# 		do_git_checkout "https://salsa.debian.org/multimedia-team/ladspa-sdk" "$lib"
# 		change_dir "$src_dir/$lib"
# 		change_dir "$src_dir"
	fi
}

#     --enable-lv2 (LV2 audio plugins) An API standard for audio plugins for audio production.
build_lv2() {
  if [[ $disable_lv2 != 1 && $enable_lv2 == 1 ]]; then
		# https://github.com/lv2/lv2
		local lib="lv2"
    activate_meson
    change_dir "$src_dir"
    do_git_checkout https://github.com/lv2/lv2 "$lib" # meson build for fontconfig no good
    change_dir "$src_dir/$lib"
    local cross_file=$(get_meson_cross_file)
    local meson_options="-Dtests=disabled -Ddocs=disabled -Donline_docs=false"
    meson_options+=" --cross-file=$cross_file"
    do_meson "$meson_options" "setup build"
    do_ninja_and_ninja_install
    change_dir "$src_dir"
	fi
}

#     --enable-libcelt (CELT audio decoder) A legacy audio codec that has been superseded by Opus.
build_libcelt() {
  if [[ $disable_libcelt != 1 && $enable_libcelt == 1 ]]; then
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

#     --enable-libcdio (Audio CD grabbing) Library for CD-ROM and CD-image access.
build_libcdio() {
  if [[ $disable_libcdio != 1 && $enable_libcdio == 1 ]]; then
		# https://github.com/libcdio/libcdio
	local lib="libcdio"
	change_dir "$src_dir"
		do_git_checkout https://github.com/libcdio/libcdio "$lib"
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

#     --enable-libfdk-aac The Fraunhofer FDK AAC library.
build_libfdk_aac() {
  if [[ $disable_libfdk_aac != 1 && $enable_libfdk_aac == 1 ]]; then
  echo "WARNING: Including this library will make the binaries non-redistributable"
	change_dir "$src_dir"
		local checkout_dir=fdk-aac
    if [[ -n $fdk_aac_git_checkout_version ]]; then
      checkout_dir+="_$fdk_aac_git_checkout_version"
      do_git_checkout "https://github.com/mstorsjo/fdk-aac.git" "$checkout_dir" "refs/tags/$fdk_aac_git_checkout_version"
    else
      do_git_checkout "https://github.com/mstorsjo/fdk-aac.git" "$checkout_dir"
    fi
  	change_dir "$src_dir/$checkout_dir"
    if [[ ! -f "configure" ]]; then
      autoreconf -fiv || exit_message 1
    fi
    generic_configure_make_install
  change_dir "$src_dir"
	fi
}

build_tre() {
  if [[ $disable_libjack != 1 && $enable_libjack == 1 ]]; then
  # https://github.com/laurikari/tre
    local lib="tre"
    change_dir "$src_dir"
    do_git_checkout https://github.com/laurikari/tre "$lib" "TRE 0.9.0" # meson build for fontconfig no good
    change_dir "$src_dir/$lib"
    if git apply --reverse --check --ignore-space-change --ignore-whitespace --verbose "$WINPATCHDIR/tre_tre-internal.diff" >/dev/null 2>&1; then
      echo "INFO: Patch already applied. Skipping." >>"$LOG_FILE"
    else
      echo "INFO: Applying patch tre_tre-internal.diff..." >>"$LOG_FILE"
      copy_path "lib/tre-internal.h" "lib/tre-internal.h.bak"
      git apply --ignore-space-change --ignore-whitespace --verbose "$WINPATCHDIR/tre_tre-internal.diff" > >(redirect_output) 2>&1 || exit_message 1 "unable to patch makefile"
    fi
    generic_configure_make_install "--disable-nls"
    change_dir "$src_dir"
  fi
}

build_portaudio() {
  if [[ $disable_libjack != 1 && $enable_libjack == 1 ]]; then
  # https://github.com/PortAudio/portaudio
    local lib="portaudio"
    local repo="https://github.com/PortAudio/portaudio"
    local repo_ver="v19.7.0"
    change_dir "$src_dir"
    do_git_checkout "$repo" "$lib" "$repo_ver" # meson build for fontconfig no good
    change_dir "$src_dir/$lib"
    if [[ ! -d "$src_dir/$lib/opt/asiosdk/common" ]]; then
      download_and_unpack_file "https://download.steinberg.net/sdk_downloads/ASIO-SDK_2.3.4_2025-10-15.zip"
      create_dir "opt"
      mv -f "ASIOSDK" "opt/asiosdk"
    fi 
    generic_configure_make_install "--with-winapi=wmme,directx,wasapi,asio --with-asiodir=$src_dir/$lib/opt/asiosdk"
    change_dir "$src_dir"
  fi
}

#     --enable-libjack (JACK audio server support).
build_libjack() {
  if [[ $disable_libjack != 1 && $enable_libjack == 1 ]]; then
    build_tre
    build_portaudio
		# https://github.com/jackaudio/jack2
    local lib="libjack"
    change_dir "$src_dir"
    do_git_checkout https://github.com/jackaudio/jack2 "$lib" "v1.9.22"
    change_dir "$src_dir/$lib"
    export CC="${cross_prefix}gcc"
    export CXX="${cross_prefix}g++"
    export AR="${cross_prefix}ar"
    export WINDRES="${cross_prefix}windres"
    export STRIP="${cross_prefix}strip"
    export CFLAGS="-static -O3 -I$dependency_install_prefix/include -L$dependency_install_prefix/lib"
    export CXXFLAGS="-static -O3 -I$dependency_install_prefix/include -L$dependency_install_prefix/lib"
    sed -i "/opt.load('xcode6')/d" wscript
    sed -i "/conf.load('xcode6')/d" wscript
    sed -i "s/type='str'/type=str/g" wscript
    sed -i "s/type='int'/type=int/g" wscript
    sed -i "s/Utils.unversioned_sys_platform()/'win32'/g" wscript
    do_python '--prefix="$dependency_install_prefix" --platform="win32" --db="no" --check-c-compiler=gcc --check-cxx-compiler=g++'
    do_python "" "./waf build -v"
    do_python "" "./waf install -v"
	fi
}
#     --enable-libpulse (PulseAudio support).
build_libpulse() {
  if [[ $disable_libpulse != 1 && $enable_libpulse == 1 ]]; then
		# https://github.com/pulseaudio/pulseaudio
    local lib="libpulse"
    activate_meson
    change_dir "$src_dir"
    do_git_checkout https://github.com/pulseaudio/pulseaudio "$lib" "v17.0"
    change_dir "$src_dir/$lib"
    remove_path -rf "$src_dir/$lib/build"
    echo "17.0" > "$src_dir/$lib/.tarball-version"
    local meson_options="-Dtests=false \
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
-Ddaemon=false"
    meson_options+=" --cross-file=$(get_meson_cross_libpulse)"
    export CC="${cross_prefix}gcc"
    export CXX="${cross_prefix}g++"
    export AR="${cross_prefix}ar"
    export WINDRES="${cross_prefix}windres"
    export STRIP="${cross_prefix}strip"
    export CFLAGS="-static -O3 -I$dependency_install_prefix/include -L$dependency_install_prefix/lib"
    export CXXFLAGS="-static -O3 -I$dependency_install_prefix/include -L$dependency_install_prefix/lib"
    do_meson "$meson_options" "setup build"
    if git apply --reverse --check --ignore-space-change --ignore-whitespace --verbose "$WINPATCHDIR/pulseaudio.diff" >/dev/null 2>&1; then
      echo "INFO: Patch already applied. Skipping." >>"$LOG_FILE"
    else
      echo "INFO: Applying patch to remove demo app..." >>"$LOG_FILE"
      copy_path "src/pulse/fork-detect.c" "src/pulse/fork-detect.c.bak"
      copy_path "src/pulsecore/arpa-inet.c" "src/pulsecore/arpa-inet.c.bak"
      git apply --ignore-space-change --ignore-whitespace --verbose "$WINPATCHDIR/pulseaudio.diff" > >(redirect_output) 2>&1 || exit_message 1 "unable to patch makefile"
    fi
    do_ninja_and_ninja_install
    change_dir "$src_dir"
	fi
}

#     --enable-libshine (Fixed-point MP3 encoder)
build_libshine() {
  if [[ $disable_libshine != 1 && $enable_libshine == 1 ]]; then
	# https://github.com/toots/shine 
	change_dir "$src_dir"
	do_git_checkout https://github.com/toots/shine
	change_dir "$src_dir/shine"
	generic_configure_make_install
	change_dir "$src_dir"
	fi
}

#     --enable-openal (OpenAL audio capture)
build_openal() {
  if [[ $disable_openal != 1 && $enable_openal == 1 ]]; then
	# https://github.com/kcat/openal-soft
	local lib="openal-soft"
	change_dir "$src_dir"
	do_git_checkout https://github.com/kcat/openal-soft
	change_dir "$src_dir/$lib/build" 1
	local cmake_params=" -DCMAKE_TOOLCHAIN_FILE=$(get_generic_cmake_toolchain) \
-DCMAKE_BUILD_TYPE=Release \
-DALSOFT_UTILS=OFF \
-DALSOFT_EXAMPLES=OFF \
-DALSOFT_REQUIRE_DSOUND=ON \
-DALSOFT_REQUIRE_WASAPI=ON \
-DLIBTYPE=STATIC"
	local target_proc=AMD64
	if [ "$bits_target" = "32" ]; then
		target_proc=X86
	fi
	do_cmake_from_build_dir "$src_dir/$lib" "$cmake_params"
	do_make_and_make_install
	change_dir "$src_dir"
	fi
}

#     --enable-pocketsphinx (PocketSphinx speech recognition for the asr filter)
build_pocketsphinx() {
  if [[ $disable_pocketsphinx != 1 && $enable_pocketsphinx == 1 ]]; then
	# https://github.com/cmusphinx/pocketsphinx
	local lib="pocketsphinx"
	change_dir "$src_dir"
	do_git_checkout https://github.com/cmusphinx/pocketsphinx
	change_dir "$src_dir/$lib/build" 1
	local cmake_params=" -DCMAKE_TOOLCHAIN_FILE=$(get_generic_cmake_toolchain) -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF"
	local target_proc=AMD64
	if [ "$bits_target" = "32" ]; then
		target_proc=X86
	fi
	do_cmake_from_build_dir "$src_dir/$lib" "$cmake_params"
	do_make_and_make_install
	change_dir "$src_dir"
	fi
}
#     --enable-whisper (OpenAI Whisper speech recognition for the whisper filter)
build_whisper() {
  if [[ $disable_whisper != 1 && $enable_whisper == 1 ]]; then
	# https://github.com/ggerganov/whisper.cpp
	local lib="whisper.cpp"
	change_dir "$src_dir"
	do_git_checkout https://github.com/ggerganov/whisper.cpp "whisper.cpp"
	change_dir "$src_dir/$lib/build" 1
	local cmake_params=" -DCMAKE_TOOLCHAIN_FILE=$(get_generic_cmake_toolchain) \
-DCMAKE_BUILD_TYPE=Release \
-DWHISPER_BUILD_EXAMPLES=OFF \
-DWHISPER_BUILD_TESTS=OFF \
-DBUILD_SHARED_LIBS=OFF \
-DGGML_STATIC=ON \
-DGGML_AVX2=ON \
-DGGML_FMA=ON \
-DGGML_F16C=ON \
-DGGML_NATIVE=OFF"
	local target_proc=AMD64
	if [ "$bits_target" = "32" ]; then
		target_proc=X86
	fi
	do_cmake_from_build_dir "$src_dir/$lib" "$cmake_params"
	do_make_and_make_install
	change_dir "$src_dir"
	fi
}

#     --enable-gcrypt (Required for RTMPE as an alternative to OpenSSL)
build_gcrypt() {
  if [[ $disable_gcrypt != 1 && $enable_gcrypt == 1 ]]; then
  build_libgpg_error
	# https://github.com/gpg/libgcrypt
	local lib="libgcrypt"
  change_dir "$src_dir"
  do_git_checkout https://github.com/gpg/libgcrypt "$lib"
  change_dir "$src_dir/$lib"
  export CC="${cross_prefix}gcc"
  export CXX="${cross_prefix}g++"
  export AR="${cross_prefix}ar"
  export WINDRES="${cross_prefix}windres"
  export STRIP="${cross_prefix}strip"
  export CFLAGS="-static -O3 -I$dependency_install_prefix/include -L$dependency_install_prefix/lib -Wno-incompatible-pointer-types"
  export CXXFLAGS="-static -O3 -I$dependency_install_prefix/include -L$dependency_install_prefix/lib"
  export LDFLAGS="-I$dependency_install_prefix/include -L$dependency_install_prefix/lib"
  generic_configure_make_install "--disable-doc --disable-tests --disable-amd64-as-feature-detection"
  change_dir "$src_dir"
	fi
}
#     --enable-librist (RIST protocol for reliable streaming)
build_librist() {
  if [[ $disable_librist != 1 && $enable_librist == 1 ]]; then
	# https://code.videolan.org/rist/librist
	local lib="librist"
  activate_meson
  change_dir "$src_dir"
  do_git_checkout https://code.videolan.org/rist/librist "$lib"
  change_dir "$src_dir/$lib"
  if git apply --reverse --check --ignore-space-change --ignore-whitespace --verbose "$WINPATCHDIR/librist_time-shim.diff" >/dev/null 2>&1; then
    echo "INFO: Patch already applied. Skipping." >>"$LOG_FILE"
	else
		echo "INFO: Applying patch to remove demo app..." >>"$LOG_FILE"
		copy_path "contrib/time-shim.c" "contrib/time-shim.c.bak"
		git apply --ignore-space-change --ignore-whitespace --verbose "$WINPATCHDIR/librist_time-shim.diff" > >(redirect_output) 2>&1 || exit_message 1 "unable to patch makefile"
	fi
  local cross_file=$(get_meson_cross_file)
  local meson_options="-Ddefault_library=static -Duse_mbedtls=true -Dbuilt_tools=false -Dtest=false"
	meson_options+=" --cross-file=$cross_file"
  do_meson "$meson_options" "setup build"
	do_ninja_and_ninja_install
  change_dir "$src_dir"
	fi
}
#     --enable-librtmp (RTMP/RTMPE support via the librtmp library)
# shellcheck disable=2086
build_librtmp() {
  if [[ $disable_librtmp != 1 && $enable_librtmp == 1 ]]; then
	# https://github.com/mirror/rtmpdump
	local lib="librtmp"
  change_dir "$src_dir"
  do_git_checkout https://github.com/mirror/rtmpdump "$lib"
  change_dir "$src_dir/$lib"
  #fix clean command
  sed -i 's/rm -f \*.o \*.a \*.$(SOX) \*$(SO_EXT)/rm -f *.o *.a *.so* *.dll *.dylib/g' librtmp/Makefile
  if grep -q "-lcrypt32" "librtmp/Makefile"; then
    echo "crypt32 library already referenced, skipping"
  else
    sed -i 's/-lgdi32/-lgdi32 -lcrypt32/g' "librtmp/Makefile"
  fi
  if grep -q "-lcrypt32" "Makefile"; then
    echo "crypt32 library already referenced, skipping"
  else
    sed -i 's/-lgdi32/-lgdi32 -lcrypt32/g' "Makefile"
  fi
  do_make 'SYS=mingw CROSS_COMPILE="'$cross_prefix'" INC="-I'$dependency_install_prefix'/include" LDFLAGS="-L'$dependency_install_prefix'/lib --static"'
  do_make_install 'SYS=mingw prefix="'${dependency_install_prefix}'" CROSS_COMPILE="'$cross_prefix'"'
  change_dir "$src_dir"
	fi
}
#     --enable-librabbitmq (RabbitMQ messaging)
build_librabbitmq() {
  if [[ $disable_librabbitmq != 1 && $enable_librabbitmq == 1 ]]; then
	# https://github.com/alanxz/rabbitmq-c
	local lib="librabbitmq"
  change_dir "$src_dir"
  do_git_checkout https://github.com/alanxz/rabbitmq-c "$lib"
  change_dir "$src_dir/$lib"
  if git apply --reverse --check --ignore-space-change --ignore-whitespace --verbose "$WINPATCHDIR/librabbitmq_amqp_socket.diff" >/dev/null 2>&1; then
    echo "INFO: Patch already applied. Skipping." >>"$LOG_FILE"
	else
		echo "INFO: Applying patch to remove demo app..." >>"$LOG_FILE"
		copy_path "librabbitmq/amqp_socket.c" "librabbitmq/amqp_socket.c.bak"
		git apply --ignore-space-change --ignore-whitespace --verbose "$WINPATCHDIR/librabbitmq_amqp_socket.diff" > >(redirect_output) 2>&1 || exit_message 1 "unable to patch makefile"
	fi
  local cmake_params="-DCMAKE_TOOLCHAIN_FILE=$(get_generic_cmake_toolchain) \
-DCMAKE_BUILD_TYPE=Release \
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
#     --enable-libsmbclient (Samba protocol for Windows file sharing)
build_libsmbclient() {
  if [[ $disable_libsmbclient != 1 && $enable_libsmbclient == 1 ]]; then
    if [[ $host_platform == "windows" ]]; then
      echo "INFO: SMB support already built into $host_platform. Seperate library not needed." && return 0
    fi
		# TODO NON-WINDOWS --enable-libsmbclient - Not needed for windows"
	echo "TODO --enable-libsmbclient"
  echo "Not needed for Windows. Windows has SMB built into the Operating System."
	# https://git.samba.org/samba
	local lib="libsmbclient"
	fi
}
#     --enable-libssh (SFTP protocol support; your script builds libssh2, which is a different library)
build_libssh() {
  if [[ $disable_libssh != 1 && $enable_libssh == 1 ]]; then
	# https://github.com/canonical/libssh
	local lib="libssh"
  change_dir "$src_dir"
  do_git_checkout https://github.com/canonical/libssh "$lib" "libssh-0.11.1"
  change_dir "$src_dir/$lib/build" 1
  local cmake_params="-DCMAKE_TOOLCHAIN_FILE=$(get_generic_cmake_toolchain) \
-DBUILD_SHARED_LIBS=OFF \
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
#     --enable-libtls (LibreSSL support)
build_libtls() {
  if [[ $disable_libtls != 1 && $enable_libtls == 1 ]]; then
	# https://github.com/PowerShell/LibreSSL
	local lib="LibreSSL"
  change_dir "$src_dir"
  do_git_checkout https://github.com/PowerShell/LibreSSL "$lib" "V4.0.0.0"
  change_dir "$src_dir/$lib/build" 1
  local cmake_params="-DCMAKE_TOOLCHAIN_FILE=$(get_generic_cmake_toolchain) \
-DCMAKE_INSTALL_PREFIX=${dependency_install_prefix} \
-DBUILD_SHARED_LIBS=OFF \
-DLIBRESSL_APPS=OFF \
-DLIBRESSL_TESTS=OFF \
-DCMAKE_BUILD_TYPE=Release"
  do_cmake_from_build_dir "$src_dir/$lib" "$cmake_params"
  do_make_and_make_install
  change_dir "$src_dir"
	fi
}
#     --enable-libzmq (ZeroMQ messaging)
build_libzmq() {
  if [[ $disable_libzmq != 1 && $enable_libzmq == 1 ]]; then
	# https://github.com/zeromq/libzmq libzmq 4.3.5
	local lib="libzmq"
  change_dir "$src_dir"
  do_git_checkout https://github.com/zeromq/libzmq "$lib" "libzmq 4.3.5"
  change_dir "$src_dir/$lib"
  export CC="${cross_prefix}gcc"
  export CXX="${cross_prefix}g++"
  export AR="${cross_prefix}ar"
  export WINDRES="${cross_prefix}windres"
  export STRIP="${cross_prefix}strip"
  export CFLAGS="-static -O3 -I$dependency_install_prefix/include -L$dependency_install_prefix/lib -Wno-incompatible-pointer-types"
  export CXXFLAGS="-DZE_MQ_STATIC -O2 -Wno-error -Wno-unknown-pragmas -I$dependency_install_prefix/include -L$dependency_install_prefix/lib"
  export LDFLAGS="-static -static-libgcc -static-libstdc++ -I$dependency_install_prefix/include -L$dependency_install_prefix/lib"
  generic_configure_make_install "--enable-static \
--disable-shared \
--without-docs \
--without-libsodium \
--disable-libunwind \
--disable-perf \
--disable-werror \
--disable-curve-keygen \
--disable-curve"' LIBS="-lpthread -lws2_32"'
  change_dir "$src_dir"
	fi
}
#     --enable-mbedtls (mbedTLS for HTTPS, alternative to GnuTLS/OpenSSL)
build_mbedtls() {
  if [[ $disable_mbedtls != 1 && $enable_mbedtls == 1 ]]; then
	# https://github.com/Mbed-TLS/mbedtls "v3.6.5"
	local lib="mbedtls"
  change_dir "$src_dir"
  do_git_checkout https://github.com/Mbed-TLS/mbedtls "$lib" "v3.6.5"
  change_dir "$src_dir/$lib"
  local cmake_params="-DCMAKE_TOOLCHAIN_FILE=$(get_generic_cmake_toolchain) \
-DCMAKE_INSTALL_PREFIX=${dependency_install_prefix} \
-DCMAKE_BUILD_TYPE=Release \
-DENABLE_TESTING=OFF \
-DENABLE_PROGRAMS=OFF \
-DUSE_STATIC_MBEDTLS_LIBRARY=ON \
-DUSE_SHARED_MBEDTLS_LIBRARY=OFF \
-DMBEDTLS_FATAL_WARNINGS=OFF"' -DCMAKE_C_FLAGS="-D__USE_MINGW_ANSI_STDIO=1"'
  do_cmake_and_install "$cmake_params" "$src_dir/$lib"
  change_dir "$src_dir"
	fi
}

#     --enable-jni (Java Native Interface, for Android integration)
build_jni() {
  if [[ $disable_jni != 1 && $enable_jni == 1 ]]; then
	echo "INFO: No jni library to compile. Library built into OS."
	echo "INFO: Only available on Android build"
	local lib="jni"
	fi
}
#     --enable-ohcodec (OpenHarmony Codec support)
build_ohcodec() {
  if [[ $disable_ohcodec != 1 && $enable_ohcodec == 1 ]]; then
	echo "INFO: No ohcodec library to compile. Library built into OS."
	echo "INFO: Only available on Harmony build"
	local lib="ohcodec"
	fi
}
#     --enable-mediacodec (Android MediaCodec support)
build_mediacodec() {
  if [[ $disable_mediacodec != 1 && $enable_mediacodec == 1 ]]; then
	echo "INFO: No mediacodec library to compile. Library built into OS."
	echo "INFO: Only available on Android build"
	local lib="mediacodec"
	fi
}
#     --enable-mediafoundation (Windows MediaFoundation support)
build_mediafoundation() {
  if [[ $disable_mediafoundation != 1 && $enable_mediafoundation == 1 ]]; then
  echo "INFO: No mediafoundation library to compile. Library built into OS."
  echo "WARNING: Including this library will make the binaries non-redistributable"
	echo "INFO: Only available on Windows build"
	local lib="mediafoundation"
	fi
}

#     --enable-libdc1394 (FireWire camera support)
build_libdc1394() {
  if [[ $disable_libdc1394 != 1 && $enable_libdc1394 == 1 ]]; then
		# TODO LINUX --enable-libdc1394"
  echo "TODO --enable-libdc1394"
	echo "Only available on Linux build"
	# https://github.com/damienfirmonte/libdc1394
	local lib="libdc1394"
	fi
}

# --enable-rkmpp                         # enable Rockchip Media Process Platform code [no]
build_rkmpp() {
  if [[ $disable_rkmpp != 1 && $enable_rkmpp == 1 ]]; then
		# TODO LINUX --enable-rkmpp"
  echo "TODO --enable-rkmpp"
	echo "Only available on Linux build"
	# 
	local lib="rkmpp"
	fi
}

#     --enable-libiec61883 (Another FireWire library)
build_libiec61883() {
  if [[ $disable_libiec61883 != 1 && $enable_libiec61883 == 1 ]]; then
		# TODO LINUX --enable-libiec61883"
  echo "TODO --enable-libiec61883"
	echo "Only available on Linux build"
	# https://github.com/Mint-Fan/libiec61883
	local lib="libiec61883"
	fi
}
#     --enable-libv4l2 (Video4Linux2 for device capture on Linux)
build_libv4l2() {
  if [[ $disable_libv4l2 != 1 && $enable_libv4l2 == 1 ]]; then
		# TODO LINUX --enable-libv4l2"
  echo "TODO --enable-libv4l2"
	echo "Only available for Linux build"
	# https://git.linuxtv.org/v4l-utils
	local lib="libv4l2"
	fi
}
#     --enable-opencl (OpenCL for GPU-based processing)
build_opencl() {
  if [[ $disable_opencl != 1 && $enable_opencl == 1 ]]; then
	# https://github.com/KhronosGroup/OpenCL-Headers
  local lib="opencl-headers"
  change_dir "$src_dir/opencl" 1
  do_git_checkout https://github.com/KhronosGroup/OpenCL-Headers "$lib" "v2025.07.22"
  change_dir "$src_dir/opencl/$lib"
  local cmake_params="-DCMAKE_TOOLCHAIN_FILE=$(get_generic_cmake_toolchain) \
-DCMAKE_INSTALL_PREFIX=${dependency_install_prefix} \
-DCMAKE_BUILD_TYPE=Release \
-DBUILD_TESTING=OFF \
-DOPENCL_HEADERS_BUILD_TESTING=OFF"
  do_cmake_from_build_dir "$src_dir/opencl/$lib" "$cmake_params"
  do_make_and_make_install
  # https://github.com/KhronosGroup/OpenCL-ICD-Loader
  lib="opencl-icd-loader"
  change_dir "$src_dir/opencl"
  do_git_checkout https://github.com/KhronosGroup/OpenCL-ICD-Loader "$lib" "v2025.07.22"
  change_dir "$src_dir/opencl/$lib"
  local cmake_params="-DCMAKE_TOOLCHAIN_FILE=$(get_generic_cmake_toolchain) \
-DCMAKE_INSTALL_PREFIX=${dependency_install_prefix} \
-DCMAKE_BUILD_TYPE=Release \
-DBUILD_SHARED_LIBS=ON \
-DBUILD_TESTING=OFF \
-DOPENCL_ICD_LOADER_BUILD_TESTING=OFF"
  do_cmake_from_build_dir "$src_dir/opencl/$lib" "$cmake_params"
  do_make_and_make_install
  change_dir "$src_dir"
	fi
}

#     --enable-libopenvino (Intel's OpenVINO toolkit)
build_libopenvino() {
  if [[ $disable_libopenvino != 1 && $enable_libopenvino == 1 ]]; then
    # https://github.com/openvinotoolkit/openvino # compiling from source fails and is complicated. using pre-built binaries
    # pre-compiled https://storage.openvinotoolkit.org/repositories/openvino/packages/2025.4/windows/openvino_toolkit_windows_2025.4.0.20398.8fdad55727d_x86_64.zip
    local lib="libopenvino"
    change_dir "$src_dir/$lib" 1
    download_and_unpack_file "https://storage.openvinotoolkit.org/repositories/openvino/packages/2025.4/windows/openvino_toolkit_windows_2025.4.0.20398.8fdad55727d_x86_64.zip" "$lib"
    if ! check_pkg_config_batch "$dependency_install_prefix/lib/pkgconfig/*openvino*.pc" > >(redirect_output) 2>&1; then
      convert_msvc_to_mingw -t="$src_dir/$lib/$lib/openvino_toolkit_windows_2025.4.0.20398.8fdad55727d_x86_64/runtime" -c="$cross_prefix" -o="$lib" -i="mingw-bundle" > >(redirect_output) 2>&1
      change_dir "$src_dir/$lib/mingw-bundle/"
      sed -i "s|^prefix=.*|prefix=${dependency_install_prefix}|g" "$src_dir/$lib/mingw-bundle/lib/pkgconfig/$lib.pc"
      [[ -d "bin" ]] && (cp -rv bin/* "$dependency_install_prefix/bin/" > >(redirect_output) 2>&1 || exit_message 1 "could not install mingw-pcre bin")
      [[ -d "include" ]] && (cp -rv include/* "$dependency_install_prefix/include/" > >(redirect_output) 2>&1 || exit_message 1 "could not install mingw-pcre include")
      [[ -d "lib" ]] && (cp -rv lib/* "$dependency_install_prefix/lib/" > >(redirect_output) 2>&1 || exit_message 1 "could not install mingw-pcre lib")
      [[ -d "share" ]] && (cp -rv share/* "$dependency_install_prefix/share/" > >(redirect_output) 2>&1 || exit_message 1 "could not install mingw-pcre share")
    fi
    change_dir "$src_dir"
    remove_path -rf "$src_dir/$lib/mingw-bundle/"
	fi
}
#     --enable-libtorch (PyTorch)
build_libtorch() {
  if [[ $disable_libtorch != 1 && $enable_libtorch == 1 ]]; then
    # TODO ABI Mismatch --enable-libtorch"
	  echo "TODO --enable-libtorch"
    # https://github.com/pytorch/pytorch # compiling from source fails and is complicated. using pre-built binaries  
    local lib="libtorch"
    echo -e "WARNING: [disabled] Using $lib may cause segmentation faults due to ABI mismatch (mingw vs mscv)" >>"$LOG_FILE"
    # change_dir "$src_dir/$lib" 1
    # download_and_unpack_file "https://download.pytorch.org/libtorch/cpu/libtorch-win-shared-with-deps-latest.zip" "$lib"
    # if ! check_pkg_config_batch "$dependency_install_prefix/lib/pkgconfig/libtorch*.pc" > >(redirect_output) 2>&1; then
    #   convert_msvc_to_mingw -t="$src_dir/$lib/$lib/libtorch" -c="$cross_prefix" -o="$lib" -i="mingw-bundle" > >(redirect_output) 2>&1
    #   change_dir "$src_dir/$lib/mingw-bundle/"
    #   sed -i "s|^prefix=.*|prefix=${dependency_install_prefix}|g" "$src_dir/$lib/mingw-bundle/lib/pkgconfig/$lib.pc"
    #   [[ -d "bin" ]] && (cp -rv bin/* "$dependency_install_prefix/bin/" > >(redirect_output) 2>&1 || exit_message 1 "could not install mingw-pcre bin")
    #   [[ -d "include" ]] && (cp -rv include/* "$dependency_install_prefix/include/" > >(redirect_output) 2>&1 || exit_message 1 "could not install mingw-pcre include")
    #   [[ -d "lib" ]] && (cp -rv lib/* "$dependency_install_prefix/lib/" > >(redirect_output) 2>&1 || exit_message 1 "could not install mingw-pcre lib")
    #   [[ -d "share" ]] && (cp -rv share/* "$dependency_install_prefix/share/" > >(redirect_output) 2>&1 || exit_message 1 "could not install mingw-pcre share")
    # fi
    # change_dir "$src_dir"
    # remove_path -rf "$src_dir/$lib/mingw-bundle/"
	fi
}

#     --enable-lcms2 (LittleCMS v2 for color management; your script has a build_lcms but not one specifically for v2)
build_lcms2() {
  if [[ $disable_lcms2 != 1 && $enable_lcms2 == 1 ]]; then
	# https://github.com/mm2/Little-CMS
	local lib="Little-CMS"
	activate_meson
	change_dir "$src_dir"
	do_git_checkout https://github.com/mm2/Little-CMS "$lib" # meson build for fontconfig no good
	change_dir "$src_dir/$lib"
  local cross_file=$(get_meson_cross_file)
	local meson_options="-Dtests=disabled -Dutils=false"
	meson_options+=" --cross-file=$cross_file"
	do_meson "$meson_options" "setup build"
	do_ninja_and_ninja_install
	change_dir "$src_dir"
	fi
}

#     --enable-libglslang (For compiling GLSL to SPIR-V, used in GPU filters).
build_libglslang() {
  if [[ $disable_libglslang != 1 && $enable_libglslang == 1 ]]; then
  # https://github.com/KhronosGroup/SPIRV-Headers
  local parent_lib="libglslang"
  local lib="SPIRV-Headers"
  change_dir "$src_dir/$parent_lib" 1
  do_git_checkout https://github.com/KhronosGroup/SPIRV-Headers "$lib" "vulkan-sdk-1.4.328.1"
  change_dir "$src_dir/$parent_lib/$lib" 1
  local cmake_params="-DCMAKE_TOOLCHAIN_FILE=$(get_generic_cmake_toolchain) \
-DCMAKE_INSTALL_PREFIX=${dependency_install_prefix} \
-DCMAKE_BUILD_TYPE=Release \
-DBUILD_SHARED_LIBS=OFF \
-DSPIRV_HEADERS_SKIP_EXAMPLES=ON"
  do_cmake_from_build_dir "$src_dir/$parent_lib/$lib" "$cmake_params"
  do_make_and_make_install
  # https://github.com/KhronosGroup/SPIRV-Tools
  local lib="SPIRV-Tools"
  change_dir "$src_dir/$parent_lib"
  do_git_checkout https://github.com/KhronosGroup/SPIRV-Tools "$lib" "v2025.4"
  change_dir "$src_dir/$parent_lib/$lib" 1
  local cmake_params="-DCMAKE_TOOLCHAIN_FILE=$(get_generic_cmake_toolchain) \
-DCMAKE_INSTALL_PREFIX=${dependency_install_prefix} \
-DCMAKE_BUILD_TYPE=Release \
-DBUILD_SHARED_LIBS=OFF \
-DSPIRV_SKIP_TESTS=ON \
-DSPIRV_WERROR=OFF \
-DSPIRV_SKIP_EXECUTABLES=ON \
-DSPIRV-Headers_SOURCE_DIR=${dependency_install_prefix}"
  do_cmake_from_build_dir "$src_dir/$parent_lib/$lib" "$cmake_params"
  do_make_and_make_install
	# https://github.com/KhronosGroup/glslang
	local lib="glslang"
  change_dir "$src_dir/$parent_lib"
  do_git_checkout https://github.com/KhronosGroup/glslang "$lib" "Release 16.1.0"
  change_dir "$src_dir/$parent_lib/$lib" 1
  local cmake_params="-DCMAKE_TOOLCHAIN_FILE=$(get_generic_cmake_toolchain) \
-DCMAKE_INSTALL_PREFIX=${dependency_install_prefix} \
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

#     --enable-libklvanc (Kernel Labs VANC processing).
build_libklvanc() {
  if [[ $disable_libklvanc != 1 && $enable_libklvanc == 1 ]]; then
	# https://github.com/stoth68000/libklvanc
	local lib="libklvanc"
  change_dir "$src_dir"
  do_git_checkout https://github.com/stoth68000/libklvanc "$lib" "vid.obe.1.6.0"
  change_dir "$src_dir/$lib"
  export CC="${cross_prefix}gcc"
  export CXX="${cross_prefix}g++"
  export AR="${cross_prefix}ar"
  export WINDRES="${cross_prefix}windres"
  export STRIP="${cross_prefix}strip"
  export CFLAGS="-static -O3 -I$dependency_install_prefix/include -L$dependency_install_prefix/lib"
  export CXXFLAGS="-I$dependency_install_prefix/include -L$dependency_install_prefix/lib"
  export LDFLAGS="-static -static-libgcc -static-libstdc++ -I$dependency_install_prefix/include -L$dependency_install_prefix/lib"
  sed -i.bak 's#<sys/errno.h>#<errno.h>#g' src/libklvanc/vanc.h src/libklvanc/vanc-packets.h src/core-private.h src/libklvanc/vanc-lines.h
  sed -i.bak 's/SUBDIRS = src tools/SUBDIRS = src/g' Makefile
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
#     --enable-liblc3 (LC3 audio codec)
build_liblc3() {
  if [[ $disable_liblc3 != 1 && $enable_liblc3 == 1 ]]; then
	# https://github.com/google/liblc3
	local lib="liblc3"
	activate_meson
	change_dir "$src_dir"
	do_git_checkout https://github.com/google/liblc3 "$lib"
	change_dir "$src_dir/$lib"
  local cross_file=$(get_meson_cross_file)
	local meson_options="-Dtools=false -Dpython=false"
	meson_options+=" --cross-file=$cross_file"
	generic_meson "$meson_options"
	change_dir "$src_dir/$lib/build"
	do_meson "" "install"
	change_dir "$src_dir"
	fi
}
#     --enable-liblcevc-dec (LCEVC decoder)
build_liblcevc_dec() {
  if [[ $disable_liblcevc_dec != 1 && $enable_liblcevc_dec == 1 ]]; then
	# https://github.com/v-novaltd/LCEVCdec
	local lib="liblcevc"
	change_dir "$src_dir"
	do_git_checkout https://github.com/v-novaltd/LCEVCdec "$lib"
	change_dir "$src_dir/$lib/build" 1
	local cmake_params=" -DCMAKE_TOOLCHAIN_FILE=$(get_generic_cmake_toolchain) \
-DCMAKE_BUILD_TYPE=Release \
-DBUILD_SHARED_LIBS=OFF \
-DVN_SDK_EXECUTABLES=OFF \
-DVN_SDK_UNIT_TESTS=OFF \
-DVN_SDK_DOCS=OFF \
-DVN_SDK_SAMPLE_SOURCE=OFF \
-DVN_SDK_PIPELINE_VULKAN=OFF \
-DVN_SDK_PIPELINE_LEGACY=OFF"
	local target_proc=AMD64
	if [ "$bits_target" = "32" ]; then
		target_proc=X86
	fi
	do_cmake_from_build_dir "$src_dir/$lib" "$cmake_params"
	do_make_and_make_install
	change_dir "$src_dir"
	fi
}
#     --enable-liboapv (APV encoder)
build_liboapv() {
  if [[ $disable_liboapv != 1 && $enable_liboapv == 1 ]]; then
	# https://github.com/AcademySoftwareFoundation/openapv
	local lib="liboapv"
	change_dir "$src_dir"
	do_git_checkout https://github.com/AcademySoftwareFoundation/openapv "$lib"
	change_dir "$src_dir/$lib/build" 1
	local cmake_params=" -DCMAKE_TOOLCHAIN_FILE=$(get_generic_cmake_toolchain) \
-DCMAKE_BUILD_TYPE=Release \
-DOAPV_BUILD_APPS=ON \
-DOAPV_BUILD_STATIC_LIB=ON \
-DOAPV_BUILD_SHARED_LIB=ON \
-DOAPV_APP_STATIC_BUILD=ON"
	local target_proc=AMD64
	if [ "$bits_target" = "32" ]; then
		target_proc=X86
	fi
	do_cmake_from_build_dir "$src_dir/$lib" "$cmake_params"
	do_make_and_make_install
	change_dir "$src_dir"
	fi
}
#     --enable-libqrencode (QR code generation)
build_libqrencode() {
  if [[ $disable_libqrencode != 1 && $enable_libqrencode == 1 ]]; then
	# https://github.com/fukuchi/libqrencode
	local lib="libqrencode"
	change_dir "$src_dir"
	do_git_checkout https://github.com/fukuchi/libqrencode "$lib"
	change_dir "$src_dir/$lib/build" 1
	local cmake_params=" -DCMAKE_TOOLCHAIN_FILE=$(get_generic_cmake_toolchain) \
-DCMAKE_BUILD_TYPE=Release \
-DWITH_TOOLS=NO \
-DWITH_TESTS=NO \
-DWITHOUT_PNG=YES \
-DBUILD_SHARED_LIBS=NO"
	local target_proc=AMD64
	if [ "$bits_target" = "32" ]; then
		target_proc=X86
	fi
	do_cmake_from_build_dir "$src_dir/$lib" "$cmake_params"
	do_make_and_make_install
	change_dir "$src_dir"
	fi
}
#     --enable-libquirc (QR code decoding)
build_libquirc() {
  if [[ $disable_libquirc != 1 && $enable_libquirc == 1 ]]; then
	# https://github.com/dlbeer/quirc
	local lib="libquirc"
	change_dir "$src_dir"
	do_git_checkout https://github.com/dlbeer/quirc "$lib"
	create_dir "$src_dir/$lib/build"
	export CC="${cross_prefix}gcc"
	export CXX="${cross_prefix}g++"
	export AR="${cross_prefix}ar"
	export AS="${cross_prefix}as"
	export STRIP="${cross_prefix}strip"
	export RANLIB="${cross_prefix}ranlib"
	export TOOLCHAIN_PATH=$toolchain_bin_path
  # path to remove demo app build because it requires some unnecessary dependencies
	if git apply --reverse --check --ignore-space-change --ignore-whitespace --verbose "$WINPATCHDIR/libquirc_Makefile.patch" >/dev/null 2>&1; then
    echo "INFO: Patch already applied. Skipping."
	else
		echo "INFO: Applying patch to remove demo app..."
		copy_path "Makefile" "Makefile.bak"
		git apply --ignore-space-change --ignore-whitespace --verbose "$WINPATCHDIR/libquirc_Makefile.patch" > >(redirect_output) 2>&1 || exit_message 1 "unable to patch makefile"
	fi
	do_make_and_make_install "CC=${CC} AR=${AR} AS=${AS} CXX=${CXX} STRIP=${STRIP} RANLIB=${RANLIB}"' libquirc.a LDFLAGS="-static"'" PREFIX=${dependency_install_prefix}" "PREFIX=${dependency_install_prefix}"
	change_dir "$src_dir"
	fi
}

# --enable-librsvg (SVG image rendering).
build_librsvg() {
  build_pixman
  build_cairo
  build_pango
  if [[ $disable_librsvg != 1 && $enable_librsvg == 1 ]]; then
# 	# https://github.com/GNOME/librsvg
	local lib="librsvg"
	activate_meson
	change_dir "$src_dir"
	do_git_checkout https://github.com/GNOME/librsvg "$lib"
	change_dir "$src_dir/$lib" 1
	local meson_options="-Ddocs=disabled \
-Dintrospection=disabled \
-Dvala=disabled \
-Davif=disabled \
-Dpixbuf-loader=disabled \
-Dtests=false \
-Drsvg-convert=disabled \
-Dtriplet=x86_64-pc-windows-gnu \
-Dc_args=\"-DCAIRO_WIN32_STATIC_BUILD -DGLIB_STATIC_COMPILATION\" \
-Dcpp_args=\"-DCAIRO_WIN32_STATIC_BUILD -DGLIB_STATIC_COMPILATION\" \
-Dc_link_args=\"-lssp -lmsvcrt -lstdc++\" \
-Dcpp_link_args=\"-lssp -lmsvcrt -lstdc++\""
  local cross_file=$(get_meson_cross_file)
	meson_options+=" --cross-file=$cross_file"
	generic_meson "$meson_options"
	change_dir "$src_dir/$lib/build" 1
	do_meson "" "install"
	change_dir "$src_dir"
	fi
}

#     --enable-libuavs3d (AVS3 decoder)
build_libuavs3d() {
  if [[ $disable_libuavs3d != 1 && $enable_libuavs3d == 1 ]]; then
	# https://github.com/uavs3/uavs3d
	local lib="libuavs3d"
	change_dir "$src_dir"
	do_git_checkout https://github.com/uavs3/uavs3d "$lib"
	change_dir "$src_dir/$lib/build" 1
	local cmake_params=" -DCMAKE_TOOLCHAIN_FILE=$(get_generic_cmake_toolchain) \
-DCOMPILE_10BIT=0 \
-DBUILD_SHARED_LIBS=0 \
-DCMAKE_BUILD_TYPE=Release"
	local target_proc=AMD64
	if [ "$bits_target" = "32" ]; then
		target_proc=X86
	fi
	do_cmake_from_build_dir "$src_dir/$lib" "$cmake_params"
	do_make_and_make_install
	change_dir "$src_dir"
	fi
}
#     --enable-vapoursynth (VapourSynth script support)
build_vapoursynth() {
  if [[ $disable_vapoursynth != 1 && $enable_vapoursynth == 1 ]]; then
	# https://github.com/vapoursynth/vapoursynth
	local lib="vapoursynth"
	activate_meson
	change_dir "$src_dir"
	do_git_checkout https://github.com/vapoursynth/vapoursynth "$lib" # meson build for fontconfig no good
	change_dir "$src_dir/$lib"
	copy_path "src/vsscript/vsscript.cpp" "src/vsscript/vsscript.cpp.bak"
	sed -i 's/#include <Windows.h>/#include <windows.h>/' src/vsscript/vsscript.cpp
  # patch to load windows python dependencies
	if git apply --reverse --check --ignore-space-change --ignore-whitespace --verbose "$WINPATCHDIR/vapoursynth_meson_build.patch" >/dev/null 2>&1; then
    echo "INFO: Patch already applied. Skipping."
	else
		echo "INFO: Applying patch..."
		copy_path "meson.build" "meson.build.bak"
		git apply --ignore-space-change --ignore-whitespace --verbose "$WINPATCHDIR/vapoursynth_meson_build.patch" > >(redirect_output) 2>&1 || exit_message 1 "unable to patch python"
	fi
	apt install cython3 # needed for enable_python_module 
	change_dir "$src_dir/$lib/python_dep" 1
	download_and_unpack_file "https://www.nuget.org/api/v2/package/python/3.12.0" > >(redirect_output) 2>&1 || exit_message 1 "unable to download python"
	change_dir "$src_dir/$lib"
  local cross_file=$(get_meson_cross_file)
	local meson_options="--cross-file=$cross_file -D b_lto=false"
	do_meson "$meson_options" "setup build"
	do_ninja_and_ninja_install
	change_dir "$src_dir"
	fi
}

#   --disable-metal          disable Apple Metal framework [autodetect]
build_metal() {
  if [[ $disable_metal != 1 && $enable_metal == 1 ]]; then
    echo "WARNING: Including this library will make the binaries non-redistributable"
    echo "Only available on Apple build"
  fi
}
#   --disable-sndio          disable sndio support [autodetect]
build_sndio () {
  if [[ $disable_sndio != 1 && $enable_sndio == 1 ]]; then
		# TODO No MinGW/Windows support --enable-sndio"
    echo "WARNING: Library does not have MinGW/windows support. Unable to enable on Windows currently."
    # https://github.com/ratchov/sndio
    local lib="sndio"
  fi
}
#   --disable-schannel       disable SChannel SSP, needed for TLS support on Windows if openssl and gnutls are not used [autodetect]
build_schannel () {
  if [[ $disable_schannel != 1 && $enable_schannel == 1 ]]; then
    echo "WARNING: Including this library will make the binaries non-redistributable"
    echo "Only available on Windows build"
  fi
}
#   --disable-securetransport disable Secure Transport, needed for TLS support on OSX if openssl and gnutls are not used [autodetect]
build_securetransport () {
  if [[ $disable_securetransport != 1 && $enable_securetransport == 1 ]]; then
    echo "WARNING: Including this library will make the binaries non-redistributable"
    echo "Only available on Apple build"
  fi
}
#   --disable-xlib           disable xlib [autodetect]
build_xlib () {
  if [[ $disable_xlib != 1 && $enable_xlib == 1 ]]; then
    echo "Only available on Linux build"
    # https://github.com/mirror/libX11
  fi
}
#   --disable-v4l2-m2m       disable V4L2 mem2mem code [autodetect]
build_v4l2_m2m () {
  if [[ $disable_v4l2_m2m != 1 && $enable_v4l2_m2m == 1 ]]; then
    echo "Only available on Linux build"
  fi
}
#   --disable-vaapi          disable Video Acceleration API (mainly Unix/Intel) code [autodetect]
build_vaapi () {
  if [[ $disable_vaapi != 1 && $enable_vaapi == 1 ]]; then
    echo "Only available on Linux build"
    # https://github.com/intel/libva
  fi
}
#   --disable-vdpau          disable Nvidia Video Decode and Presentation API for Unix code [autodetect]
build_vdpau () {
  if [[ $disable_vdpau != 1 && $enable_vdpau == 1 ]]; then
    echo "WARNING: Including this library will make the binaries non-redistributable"
    echo "Only available on Linux build"
    # https://gitlab.freedesktop.org/vdpau/libvdpau
  fi
}
#   --disable-videotoolbox   disable VideoToolbox code [autodetect]
build_videotoolbox () {
  if [[ $disable_videotoolbox != 1 && $enable_videotoolbox == 1 ]]; then
    echo "WARNING: Including this library will make the binaries non-redistributable"
    echo "Only available on Apple build"
  fi
}
#   --disable-alsa           disable ALSA support [autodetect]
build_alsa() {
  if [[ $disable_alsa != 1 && $enable_alsa == 1 ]]; then
    echo "Only available on Linux build"
    # https://github.com/alsa-project/alsa-lib
  fi
}
#   --disable-appkit         disable Apple AppKit framework [autodetect]
build_appkit() {
  if [[ $disable_appkit != 1 && $enable_appkit == 1 ]]; then
    echo "WARNING: Including this library will make the binaries non-redistributable"
    echo "Only available on Apple build"
  fi
}
#   --disable-audiotoolbox   disable Apple AudioToolbox code [autodetect]
build_audiotoolbox() {
  if [[ $disable_audiotoolbox != 1 && $enable_audiotoolbox == 1 ]]; then
    echo "WARNING: Including this library will make the binaries non-redistributable"
    echo "Only available on Apple build"
  fi
}
#   --disable-avfoundation   disable Apple AVFoundation framework [autodetect]
build_avfoundation() {
  if [[ $disable_avfoundation != 1 && $enable_avfoundation == 1 ]]; then
    echo "WARNING: Including this library will make the binaries non-redistributable"
    echo "Only available on Apple build"
  fi
}

#   --disable-coreimage      disable Apple CoreImage framework [autodetect]
build_coreimage() {
  if [[ $disable_coreimage != 1 && $enable_coreimage == 1 ]]; then
    echo "WARNING: Including this library will make the binaries non-redistributable"
    echo "Only available on Apple build"
  fi
}
#   --disable-cuda-llvm      disable CUDA compilation using clang [autodetect]
build_cuda_llvm() {
  if [[ $disable_cuda_llvm != 1 && $enable_cuda_llvm == 1 ]]; then
    echo "WARNING: Including this library will make the binaries non-redistributable"
		# TODO --enable-cuda-llvm"
    echo "TODO --enable-cuda-llvm"
    
  fi
}
#   --enable-cuda-nvcc       enable Nvidia CUDA compiler [no]
build_cuda_nvcc() {
  if [[ $disable_cuda_nvcc != 1 && $enable_cuda_nvcc == 1 ]]; then
    echo "WARNING: Including this library will make the binaries non-redistributable"
    # https://developer.download.nvidia.com/compute/cuda/redist/cuda_nvcc/windows-x86_64/cuda_nvcc-windows-x86_64-13.0.88-archive.zip
    local lib="cuda-nvcc"
    download_and_unpack_file https://developer.download.nvidia.com/compute/cuda/redist/cuda_nvcc/windows-x86_64/cuda_nvcc-windows-x86_64-13.0.88-archive.zip "$lib"
    change_dir "$src_dir/$lib"
    if ! check_pkg_config_batch "$dependency_install_prefix/lib/pkgconfig/$lib*.pc" > >(redirect_output) 2>&1; then
      convert_msvc_to_mingw -t="$src_dir/$lib/cuda_nvcc-windows-x86_64-13.0.88-archive" -c="$cross_prefix" -o="$lib" -i="mingw-bundle" > >(redirect_output) 2>&1
      change_dir "$src_dir/$lib/mingw-bundle/"
      sed -i "s|^prefix=.*|prefix=${dependency_install_prefix}|g" "$src_dir/$lib/mingw-bundle/lib/pkgconfig/$lib.pc"
      [[ -d "bin" ]] && (cp -rv bin/* "$dependency_install_prefix/bin/" > >(redirect_output) 2>&1 || exit_message 1 "could not install $lib bin")
      [[ -d "include" ]] && (cp -rv include/* "$dependency_install_prefix/include/" > >(redirect_output) 2>&1 || exit_message 1 "could not install $lib include")
      [[ -d "lib" ]] && (cp -rv lib/* "$dependency_install_prefix/lib/" > >(redirect_output) 2>&1 || exit_message 1 "could not install $lib lib")
      [[ -d "share" ]] && (cp -rv share/* "$dependency_install_prefix/share/" > >(redirect_output) 2>&1 || exit_message 1 "could not install $lib share")
    fi
    change_dir "$src_dir"
    remove_path -rf "$src_dir/$lib/mingw-bundle/"
  fi
}
#   --disable-d3d11va        disable Microsoft Direct3D 11 video acceleration code [autodetect]
build_d3d11va() {
  if [[ $disable_d3d11va != 1 && $enable_d3d11va == 1 ]]; then
    echo "WARNING: Including this library will make the binaries non-redistributable"
    echo "Only available on Windows build"
  fi
}
#   --disable-d3d12va        disable Microsoft Direct3D 12 video acceleration code [autodetect]
build_d3d12va() {
  if [[ $disable_d3d12va != 1 && $enable_d3d12va == 1 ]]; then
    echo "WARNING: Including this library will make the binaries non-redistributable"
    echo "Only available on Windows build"
  fi
}
#   --disable-dxva2          disable Microsoft DirectX 9 video acceleration code [autodetect]
build_dxva2() {
  if [[ $disable_dxva2 != 1 && $enable_dxva2 == 1 ]]; then
    echo "WARNING: Including this library will make the binaries non-redistributable"
    echo "Only available on Windows build"
  fi
}
#   --disable-libdrm         disable DRM code (Linux) [autodetect]
build_libdrm() {
  if [[ $disable_libdrm != 1 && $enable_libdrm == 1 ]]; then
    echo "Only available on Linux build"
    # https://gitlab.freedesktop.org/mesa/libdrm
  fi
}
#   --enable-omx-rpi         # enable OpenMAX IL code for Raspberry Pi [no]
build_omx_rpi() {
  if [[ $disable_omx_rpi != 1 && $enable_omx_rpi == 1 ]]; then
    # https://github.com/tizonia/tizonia-openmax-il maybe?
    echo "WARNING: Including this library will make the binaries non-redistributable"
    echo "Only available on Linux build"
    #
  fi
}
#   --enable-omx         # enable OpenMAX IL code [no]
build_omx() {
  if [[ $disable_omx != 1 && $enable_omx == 1 ]]; then
    echo "Only available on Linux build"
    # https://github.com/tizonia/tizonia-openmax-il maybe?
    #
  fi
}
#   --enable-mmal         # enable Broadcom Multi-Media Abstraction Layer (Raspberry Pi) via MMAL [no]
build_mmal() {
  if [[ $disable_mmal != 1 && $enable_mmal == 1 ]]; then
    # https://github.com/raspberrypi/userland/tree/master/interface/mmal maybe?
    echo "WARNING: Including this library will make the binaries non-redistributable"
    echo "Only available on Linux build"
    #
  fi
}
#   --enable-libmfx          enable Intel MediaSDK (AKA Quick Sync Video) code via libmfx [no]
build_libmfx() {
  if [[ $disable_libmfx != 1 && $enable_libmfx == 1 ]]; then
    echo "WARNING: [disabled] Library has been archived and has security issues."
    # https://github.com/Intel-Media-SDK/MediaSDK
  fi
}
#   --enable-libnpp          enable Nvidia Performance Primitives-based code [no]
build_libnpp() {
  if [[ $disable_libnpp != 1 && $enable_libnpp == 1 ]]; then
    echo "WARNING: Including this library will make the binaries non-redistributable"
    local lib="libnpp"
    # https://developer.download.nvidia.com/compute/cuda/redist/libnpp/windows-x86_64/libnpp-windows-x86_64-13.0.1.2-archive.zip
    download_and_unpack_file https://developer.download.nvidia.com/compute/cuda/redist/libnpp/windows-x86_64/libnpp-windows-x86_64-13.0.1.2-archive.zip "$lib"
    change_dir "$src_dir/$lib"
    if ! check_pkg_config_batch "$dependency_install_prefix/lib/pkgconfig/$lib*.pc" > >(redirect_output) 2>&1; then
      convert_msvc_to_mingw -t="$src_dir/$lib/libnpp-windows-x86_64-13.0.1.2-archive" -c="$cross_prefix" -o="$lib" -i="mingw-bundle" > >(redirect_output) 2>&1
      change_dir "$src_dir/$lib/mingw-bundle/"
      sed -i "s|^prefix=.*|prefix=${dependency_install_prefix}|g" "$src_dir/$lib/mingw-bundle/lib/pkgconfig/$lib.pc"
      [[ -d "bin" ]] && (cp -rv bin/* "$dependency_install_prefix/bin/" > >(redirect_output) 2>&1 || exit_message 1 "could not install $lib bin")
      [[ -d "include" ]] && (cp -rv include/* "$dependency_install_prefix/include/" > >(redirect_output) 2>&1 || exit_message 1 "could not install $lib include")
      [[ -d "lib" ]] && (cp -rv lib/* "$dependency_install_prefix/lib/" > >(redirect_output) 2>&1 || exit_message 1 "could not install $lib lib")
      [[ -d "share" ]] && (cp -rv share/* "$dependency_install_prefix/share/" > >(redirect_output) 2>&1 || exit_message 1 "could not install $lib share")
    fi
    change_dir "$src_dir"
  fi
}
#   --enable-libopencv       enable video filtering via libopencv [no]
build_libopencv() {
  if [[ $disable_libopencv != 1 && $enable_libopencv == 1 ]]; then
    #https://github.com/opencv/opencv
    build_mingw_std_threads
    #do_git_checkout https://github.com/opencv/opencv # too big :|
    change_dir "$src_dir"
    download_and_unpack_file https://github.com/opencv/opencv/archive/3.4.5.zip opencv-3.4.5
    create_dir "$src_dir/opencv-3.4.5/build"
    #change_dir "$src_dir/opencv-3.4.5"
    apply_patch "file://$WINPATCHDIR/opencv.detection_based.patch"
    change_dir "$src_dir"
    change_dir "$src_dir/opencv-3.4.5/build"
    # could do more here, it seems to think it needs its own internal libwebp etc...
    cpu_count=1
    do_cmake_from_build_dir "$src_dir/opencv-3.4.5" "-DWITH_FFMPEG=0 -DOPENCV_GENERATE_PKGCONFIG=1 -DHAVE_DSHOW=0" # https://stackoverflow.com/q/40262928/32453, no pkg config by default on "windows", who cares ffmpeg
    do_make_and_make_install
    cp unix-install/opencv.pc "$PKG_CONFIG_PATH"
    cpu_count=$original_cpu_count
    change_dir "$src_dir"
  fi
}

#   --enable-libshaderc      enable GLSL->SPIRV compilation via libshaderc [no]
build_libshaderc() {
  if [[ $disable_libshaderc != 1 && $enable_libshaderc == 1 ]]; then
	change_dir "$src_dir"
	do_git_checkout https://github.com/google/shaderc shaderc 3a44d5d7850da3601aa43d523a3d228f045fb43d
	change_dir "$src_dir/shaderc"
	./utils/git-sync-deps
	# TODO: Allow shared library build
	do_cmake "-B build -DCMAKE_BUILD_TYPE=release -GNinja -DSHADERC_SKIP_EXAMPLES=ON -DSHADERC_SKIP_TESTS=ON -DSPIRV_SKIP_TESTS=ON -DSHADERC_SKIP_COPYRIGHT_CHECK=ON -DENABLE_EXCEPTIONS=ON -DENABLE_GLSLANG_BINARIES=OFF -DSPIRV_SKIP_EXECUTABLES=ON -DSPIRV_TOOLS_BUILD_STATIC=ON -DBUILD_SHARED_LIBS=OFF"
	do_ninja_and_ninja_install
	cp build/libshaderc_util/libshaderc_util.a "$dependency_install_prefix/lib"
	sed -i.bak "s/Libs: .*/& -lstdc++/" "$PKG_CONFIG_PATH/shaderc_combined.pc"
	sed -i.bak "s/Libs: .*/& -lstdc++/" "$PKG_CONFIG_PATH/shaderc_static.pc"
	change_dir "$src_dir"
  fi
}
#   --enable-libvo-amrwbenc  enable AMR-WB encoding via libvo-amrwbenc [no]
build_libvo_amrwbenc() {
  if [[ $disable_libvo_amrwbenc != 1 && $enable_libvo_amrwbenc == 1 ]]; then
    change_dir "$src_dir"
    generic_download_and_make_and_install https://sourceforge.net/projects/opencore-amr/files/vo-amrwbenc/vo-amrwbenc-0.1.3.tar.gz
	  change_dir "$src_dir"
  fi
}
#   --enable-libxcb          enable X11 grabbing using XCB [autodetect]
build_libxcb() {
  if [[ $disable_libxcb != 1 && $enable_libxcb == 1 ]]; then
    echo "Only available on Linux build"
    # https://gitlab.freedesktop.org/xorg/lib/libxcb
  fi
}
#   --enable-libxcb-shape    enable X11 grabbing shape rendering [autodetect]
build_libxcb_shape() {
  if [[ $disable_libxcb_shape != 1 && $enable_libxcb_shape == 1 ]]; then
    echo "Only available on Linux build"
    build_libxcb
    # https://gitlab.freedesktop.org/xorg/lib/libxcb
  fi
}
#   --enable-libxcb-shm      enable X11 grabbing shm communication [autodetect]
build_libxcb_shm() {
  if [[ $disable_libxcb_shm != 1 && $enable_libxcb_shm == 1 ]]; then
    echo "Only available on Linux build"
    build_libxcb
    # https://gitlab.freedesktop.org/xorg/lib/libxcb
  fi
}
#   --enable-libxcb-xfixes   enable X11 grabbing mouse rendering [autodetect]
build_libxcb_xfixes() {
  if [[ $disable_libxcb_xfixes != 1 && $enable_libxcb_xfixes == 1 ]]; then
    echo "Only available on Linux build"
    build_libxcb
    # https://gitlab.freedesktop.org/xorg/lib/libxcb
  fi
}

# --enable-libdvdread               # enable libdvdread, needed for DVD demuxing [no]
build_libdvdread() {
  if [[ $disable_libdvdread != 1 && $enable_libdvdread == 1 ]]; then
	build_libdvdcss
	change_dir "$src_dir"
	download_and_unpack_file http://dvdnav.mplayerhq.hu/releases/libdvdread-4.9.9.tar.xz # last revision before 5.X series so still works with MPlayer
	change_dir "$src_dir/libdvdread-4.9.9"
	# XXXX better CFLAGS here...
	generic_configure "CFLAGS=-DHAVE_DVDCSS_DVDCSS_H LDFLAGS=-ldvdcss --enable-dlfcn" # vlc patch: "--enable-libdvdcss" # XXX ask how I'm *supposed* to do this to the dvdread peeps [svn?]
	do_make_and_make_install
	sed -i.bak 's/-ldvdread.*/-ldvdread -ldvdcss/' "$PKG_CONFIG_PATH/dvdread.pc"
	change_dir "$src_dir"
  fi
}

# --enable-libdvdnav                 # enable libdvdnav, needed for DVD demuxing [no]
build_libdvdnav() {
  if [[ $disable_libdvdnav != 1 && $enable_libdvdnav == 1 ]]; then
	change_dir "$src_dir"
	download_and_unpack_file http://dvdnav.mplayerhq.hu/releases/libdvdnav-4.2.1.tar.xz # 4.2.1. latest revision before 5.x series [?]
	change_dir "$src_dir/libdvdnav-4.2.1"
	if [[ ! -f ./configure ]]; then
		./autogen.sh
	fi
	generic_configure_make_install
	sed -i.bak 's/-ldvdnav.*/-ldvdnav -ldvdread -ldvdcss -lpsapi/' "$PKG_CONFIG_PATH/dvdnav.pc" # psapi for dlfcn ... [hrm?]
	change_dir "$src_dir"
  fi
}

#endregion

#region WINDOWS FFMPEG BUILD SECONDARY DEPENDENCIES

#===============================================================================================
#
#                        WINDOWS FFMPEG BUILD SECONDARY DEPENDENCIES
#
#===============================================================================================

build_pango() {
  if [[ $disable_librsvg != 1 && $enable_librsvg == 1 ]]; then
  build_harfbuzz
  build_freetype
  build_libfontconfig
 	# https://gitlab.gnome.org/GNOME/pango
	local lib="pango"
  activate_meson
	change_dir "$src_dir"
	do_git_checkout https://gitlab.gnome.org/GNOME/pango "$lib"
	change_dir "$src_dir/$lib"
  export PKG_CONFIG_PATH="$dependency_install_prefix/lib/pkgconfig"
	local meson_options="-Ddocumentation=false \
-Dgtk_doc=false \
-Dman-pages=false \
-Dbuild-testsuite=false \
-Dbuild-examples=false \
-Dintrospection=disabled \
-Dxft=disabled \
-Dc_args=\"-DCAIRO_WIN32_STATIC_BUILD -DGLIB_STATIC_COMPILATION\" \
-Dcpp_args=\"-DCAIRO_WIN32_STATIC_BUILD -DGLIB_STATIC_COMPILATION\" \
-Dc_link_args=\"-lssp -lmsvcrt\" \
-Dcpp_link_args=\"-lssp -lmsvcrt\""
  # disable tools - not needed for ffmpeg
  sed -i "s/subdir('utils')/# subdir('utils')/g" meson.build
  local cross_file=$(get_meson_cross_file)
	meson_options+=" --cross-file=$cross_file --libdir=$dependency_install_prefix/lib"
	generic_meson "$meson_options"
	change_dir "$src_dir/$lib/build" 1
	do_meson "" "install"
	change_dir "$src_dir"
	fi
}

build_pixman() {
  if [[ $disable_librsvg != 1 && $enable_librsvg == 1 ]]; then
 	# https://gitlab.freedesktop.org/pixman/pixman
	local lib="pixman"
  activate_meson
	change_dir "$src_dir"
	do_git_checkout https://gitlab.freedesktop.org/pixman/pixman "$lib"
	change_dir "$src_dir/$lib"
  local cross_file=$(get_meson_cross_file)
	local meson_options="-Dtests=disabled -Ddemos=disabled"
	meson_options+=" --cross-file=$cross_file"
	generic_meson "$meson_options"
	change_dir "$src_dir/$lib/build" 1
	do_meson "" "install"
	change_dir "$src_dir"
	fi
}

build_cairo() {
  if [[ $disable_librsvg != 1 && $enable_librsvg == 1 ]]; then
 	# https://gitlab.freedesktop.org/cairo/cairo
	local lib="cairo"
  activate_meson
	change_dir "$src_dir"
	do_git_checkout https://gitlab.freedesktop.org/cairo/cairo "$lib"
	change_dir "$src_dir/$lib"
  local cross_file=$(get_meson_cross_file)
	local meson_options="-Dtests=disabled -Dgtk_doc=false"
	meson_options+=" --cross-file=$cross_file"
	generic_meson "$meson_options"
	change_dir "$src_dir/$lib/build" 1
	do_meson "" "install"
	change_dir "$src_dir"
	fi
}

build_libgpg_error() {
  # https://github.com/gpg/libgpg-error
  local lib="libgpg-error"
  change_dir "$src_dir"
  do_git_checkout https://github.com/gpg/libgpg-error "$lib"
  change_dir "$src_dir/$lib"
  export CC="${cross_prefix}gcc"
  export CXX="${cross_prefix}g++"
  export AR="${cross_prefix}ar"
  export WINDRES="${cross_prefix}windres"
  export STRIP="${cross_prefix}strip"
  generic_configure_make_install "--disable-doc --disable-nls --disable-languages"
  change_dir "$src_dir"
}

build_lcms() {
	change_dir "$src_dir"
	do_git_checkout_and_make_install https://github.com/ImageMagick/lcms
	change_dir "$src_dir"
}

build_libjsoncpp() {
  activate_meson
	change_dir "$src_dir"
	do_git_checkout https://github.com/open-source-parsers/jsoncpp jsoncpp
	change_dir "$src_dir/jsoncpp"
	if [[ "$build_force" -eq 1 ]]; then
		remove_path -rf already_*
	fi
	local config_options=""
	local meson_options="$config_options"
	get_meson_cross_jsoncpp
	meson_options+=" --cross-file=${src_dir}/jsoncpp/meson-cross-jsoncpp.mingw.txt"
	do_meson "$meson_options" "setup build"
	do_ninja_and_ninja_install
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

build_libtiff() {
	build_libjpeg_turbo # auto uses it?
	change_dir "$src_dir"
	generic_download_and_make_and_install http://download.osgeo.org/libtiff/tiff-4.7.1.tar.gz
	sed -i.bak "s/-ltiff.*$/-ltiff -llzma -ljpeg -lz/" "$PKG_CONFIG_PATH/libtiff-4.pc" # static deps
	change_dir "$src_dir"
}

build_gettext() {
	change_dir "$src_dir"
	generic_download_and_make_and_install "https://ftp.gnu.org/pub/gnu/gettext/gettext-0.26.tar.gz"
	change_dir "$src_dir"
}

build_libffi() {
	change_dir "$src_dir"
	download_and_unpack_file "https://github.com/libffi/libffi/releases/download/v3.5.2/libffi-3.5.2.tar.gz" # also dep
	change_dir "$src_dir/libffi-3.5.2"
	apply_patch "file://$WINPATCHDIR/libffi.patch" -p1
	generic_configure_make_install
	change_dir "$src_dir"
}

build_glib() {
	build_gettext
	build_libffi
	change_dir "$src_dir"
	do_git_checkout https://github.com/GNOME/glib glib
	activate_meson
	change_dir "$src_dir/glib"
  local cross_file=$(get_meson_cross_file)
	local meson_options="--force-fallback-for=libpcre -Dforce_posix_threads=true -Dman-pages=disabled -Dsysprof=disabled -Dglib_debug=disabled -Dtests=false --wrap-mode=default"
	# get_local_meson_cross_with_propeties
	meson_options+=" --cross-file=$cross_file"
	do_meson "$meson_options" "setup build"
	do_ninja_and_ninja_install
	sed -i.bak 's/-lglib-2.0.*$/-lglib-2.0 -lintl -lws2_32 -lwinmm -lm -liconv -lole32/' "$PKG_CONFIG_PATH/glib-2.0.pc"
	change_dir "$src_dir"
}

build_lz4() {
	change_dir "$src_dir"
	download_and_unpack_file https://github.com/lz4/lz4/releases/download/v1.10.0/lz4-1.10.0.tar.gz
	change_dir "$src_dir/lz4-1.10.0"
	# TODO: Allow shared library build
	do_cmake "-S build/cmake -B build -GNinja -DCMAKE_BUILD_TYPE=Release -DBUILD_STATIC_LIBS=ON"
	do_ninja_and_ninja_install
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

build_flac() {
	change_dir "$src_dir"
	do_git_checkout https://github.com/xiph/flac flac
	change_dir "$src_dir/flac"
	do_cmake "-B build -DCMAKE_BUILD_TYPE=Release -DINSTALL_MANPAGES=OFF -GNinja"
	do_ninja_and_ninja_install
	change_dir "$src_dir"
}

build_libpsl() {
	change_dir "$src_dir"
	export CFLAGS="-DPSL_STATIC"
	download_and_unpack_file https://github.com/rockdaboot/libpsl/releases/download/0.21.5/libpsl-0.21.5.tar.gz
	change_dir "$src_dir/libpsl-0.21.5"
	generic_configure "--disable-nls --disable-rpath --disable-gtk-doc-html --disable-man --disable-runtime"
	do_make_and_make_install
	sed -i.bak "s/Libs: .*/& -lidn2 -lunistring -lws2_32 -liconv/" "$PKG_CONFIG_PATH/libpsl.pc"
	reset_cflags
	change_dir "$src_dir"
}

build_nghttp2() {
	change_dir "$src_dir"
	export CFLAGS="-DNGHTTP2_STATICLIB"
	download_and_unpack_file https://github.com/nghttp2/nghttp2/releases/download/v1.67.1/nghttp2-1.67.1.tar.gz
	change_dir "$src_dir/nghttp2-1.67.1"
	# TODO: Allow shared library build
	do_cmake "-B build -DENABLE_LIB_ONLY=1 -DBUILD_SHARED_LIBS=0 -DBUILD_STATIC_LIBS=1 -GNinja"
	do_ninja_and_ninja_install
	reset_cflags
	change_dir "$src_dir"
}

build_libssh2() {
	change_dir "$src_dir"
	generic_download_and_make_and_install https://github.com/libssh2/libssh2/releases/download/libssh2-1.11.1/libssh2-1.11.1.tar.gz
	change_dir "$src_dir"
}

build_cpuinfo() {
	change_dir "$src_dir"
	do_git_checkout https://github.com/pytorch/cpuinfo
	change_dir "$src_dir/cpuinfo"
	do_cmake_and_install # builds included cpuinfo bugged
	change_dir "$src_dir"
}

build_vulkan_loader() {
	change_dir "$src_dir"
	do_git_checkout https://github.com/BtbN/Vulkan-Shim-Loader Vulkan-Shim-Loader 9657ca8e395ef16c79b57c8bd3f4c1aebb319137
	change_dir "$src_dir/Vulkan-Shim-Loader"
	do_git_checkout https://github.com/KhronosGroup/Vulkan-Headers Vulkan-Headers v1.4.326
	do_cmake_and_install "-DCMAKE_BUILD_TYPE=Release -DVULKAN_SHIM_IMPERSONATE=ON"
	change_dir "$src_dir"
}

build_libunwind() {
	change_dir "$src_dir"
	do_git_checkout https://github.com/libunwind/libunwind libunwind
	change_dir "$src_dir/libunwind"
	autoreconf -i
	# TODO: Allow shared library build
	do_configure "--host=x86_64-linux-gnu --prefix=$dependency_install_prefix --disable-shared --enable-static"
	do_make_and_make_install
	change_dir "$src_dir"
}

build_libxxhash() {
	change_dir "$src_dir"
	do_git_checkout https://github.com/Cyan4973/xxHash xxHash dev
	change_dir "$src_dir/xxHash"
	do_cmake "-S build/cmake -B build -DCMAKE_BUILD_TYPE=release -GNinja"
	do_ninja_and_ninja_install
	change_dir "$src_dir"
}

build_spirv_cross() {
	change_dir "$src_dir"
	do_git_checkout https://github.com/KhronosGroup/SPIRV-Cross SPIRV-Cross b26ac3fa8bcfe76c361b56e3284b5276b23453ce
	change_dir "$src_dir/SPIRV-Cross"
	# TODO: Allow shared library build
	do_cmake "-B build -GNinja -DSPIRV_CROSS_STATIC=ON -DSPIRV_CROSS_SHARED=OFF -DCMAKE_BUILD_TYPE=Release -DSPIRV_CROSS_CLI=OFF -DSPIRV_CROSS_ENABLE_TESTS=OFF -DSPIRV_CROSS_FORCE_PIC=ON -DSPIRV_CROSS_ENABLE_CPP=OFF"
	do_ninja_and_ninja_install
	mv "$PKG_CONFIG_PATH/spirv-cross-c.pc" "$PKG_CONFIG_PATH/spirv-cross-c-shared.pc"
	change_dir "$src_dir"
}

build_libdovi() {
	change_dir "$src_dir"
	do_git_checkout https://github.com/quietvoid/dovi_tool dovi_tool
	change_dir "$src_dir/dovi_tool"
	if [[ ! -e $dependency_install_prefix/lib/libdovi.a ]]; then
		curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && . "$HOME/.cargo/env" && rustup update && rustup target add x86_64-pc-windows-gnu # rustup self uninstall
		wget https://github.com/quietvoid/dovi_tool/releases/download/2.3.1/dovi_tool-2.3.1-x86_64-pc-windows-msvc.zip
		unzip -o dovi_tool-2.3.1-x86_64-pc-windows-msvc.zip -d "$dependency_install_prefix/bin"
		remove_path -f dovi_tool-2.3.1-x86_64-pc-windows-msvc.zip
		unset PKG_CONFIG_PATH
		change_dir "$src_dir/dovi_tool/dolby_vision"
		cargo install cargo-c --features=vendored-openssl
		export PKG_CONFIG_PATH="$dependency_install_prefix/lib/pkgconfig"
		# TODO: Allow shared library build
		cargo cinstall --release --prefix="$dependency_install_prefix" --libdir="$dependency_install_prefix/lib" --library-type=staticlib --target x86_64-pc-windows-gnu
		change_dir "$src_dir"
	else
		echo -e "libdovi already installed"
	fi
	change_dir "$src_dir"
}

build_libjpeg_turbo() {
	change_dir "$src_dir"
	do_git_checkout https://github.com/libjpeg-turbo/libjpeg-turbo libjpeg-turbo "origin/main"
	change_dir "$src_dir/libjpeg-turbo"
	local cmake_params="-DENABLE_SHARED=0 -DCMAKE_ASM_NASM_COMPILER=yasm"
		cmake_params+=" -DCMAKE_TOOLCHAIN_FILE=$(get_generic_cmake_toolchain)"
		local target_proc=AMD64
		if [ "$bits_target" = "32" ]; then
			target_proc=X86
		fi
	do_cmake_and_install "$cmake_params"
	change_dir "$src_dir"
}

build_libdvdcss() {
	change_dir "$src_dir"
	generic_download_and_make_and_install https://download.videolan.org/pub/videolan/libdvdcss/1.2.13/libdvdcss-1.2.13.tar.bz2
  change_dir "$src_dir"
}

build_libvvdec() {
	change_dir "$src_dir"
	do_git_checkout https://github.com/fraunhoferhhi/vvdec libvvdec
	change_dir "$src_dir/libvvdec"
	do_cmake "-B build -DCMAKE_BUILD_TYPE=Release -DVVDEC_ENABLE_LINK_TIME_OPT=OFF -DVVDEC_INSTALL_VVDECAPP=ON -GNinja"
	do_ninja_and_ninja_install
	change_dir "$src_dir"
}

build_svt_hevc() {
	if [[ "$bits_target" != "32" ]] && [[ $build_svt_hevc = y ]]; then
		change_dir "$src_dir"
		do_git_checkout https://github.com/OpenVisualCloud/SVT-HEVC
		create_dir "$src_dir/SVT-HEVC/release"
		do_cmake_from_build_dir "$src_dir/SVT-HEVC" "-DCMAKE_BUILD_TYPE=Release"
		do_make_and_make_install
		change_dir "$src_dir"
	fi
}

build_svt_vp9() {
	if [[ "$bits_target" != "32" ]] && [[ $build_svt_vp9 = y ]]; then
		change_dir "$src_dir"
		do_git_checkout https://github.com/OpenVisualCloud/SVT-VP9
		change_dir "$src_dir/SVT-VP9/Build"
		do_cmake_from_build_dir "$src_dir/SVT-VP9" "-DCMAKE_BUILD_TYPE=Release"
		do_make_and_make_install
		change_dir "$src_dir"
	fi
}

#endregion

#region WINDOWS TOOLCHAIN FILES

#===============================================================================================
#
#                        WINDOWS TOOLCHAIN FILES
#
#===============================================================================================

# 1. variant
# @. custom values
# Usage: get_generic_cmake_toolchain [variant_suffix] [VAR="VALUE" ...]
# Example: get_generic_cmake_toolchain "rabbitmq" CMAKE_C_FLAGS_INIT="-static -Wno-error"
get_generic_cmake_toolchain() {
    local variant="$1"
    local base_filename="$host_name-toolchain.cmake"
    local base_filepath="$src_dir/$base_filename"
    shift
    # Determine filename based on variant presence
    local toolchain_filename="$host_name-toolchain.cmake"
    if [[ -n "$variant" ]]; then
      toolchain_filename="$host_name-toolchain-$variant.cmake"
      local toolchain_path="$(pwd)/$toolchain_filename"
    else
      toolchain_filename="$host_name-toolchain.cmake"
      local toolchain_path="$src_dir/$toolchain_filename"
    fi
    # Only generate if it doesn't exist
    if [[ ! -e "$toolchain_path" ]]; then
        local cpu_family="x86_64"
        if [ "$bits_target" = 32 ]; then
            cpu_family="x86"
        fi
        declare -A cmake_config
        # System info
        cmake_config["CMAKE_SYSTEM_NAME"]="Windows"
        cmake_config["CMAKE_SYSTEM_PROCESSOR"]="${target_proc:-$cpu_family}"
        # Toolchain locations
        cmake_config["TOOLCHAIN_PREFIX"]="${host_target}"
        cmake_config["TOOLCHAIN_ROOT"]="${toolchain_root_dir}"
        # Compilers
        cmake_config["CMAKE_C_COMPILER"]="${cross_prefix}gcc"
        cmake_config["CMAKE_CXX_COMPILER"]="${cross_prefix}g++"
        cmake_config["CMAKE_RC_COMPILER"]="${cross_prefix}windres"
        cmake_config["CMAKE_AR"]="${cross_prefix}ar"
        cmake_config["CMAKE_RANLIB"]="${cross_prefix}ranlib"
        cmake_config["CMAKE_STRIP"]="${cross_prefix}strip"
        # Search Paths
        cmake_config["CMAKE_FIND_ROOT_PATH"]="${dependency_install_prefix}"
        cmake_config["CMAKE_FIND_ROOT_PATH_MODE_PROGRAM"]="NEVER"
        cmake_config["CMAKE_FIND_ROOT_PATH_MODE_LIBRARY"]="ONLY"
        cmake_config["CMAKE_FIND_ROOT_PATH_MODE_INCLUDE"]="ONLY"
        # Flags (Using INIT to allow appending later)
        cmake_config["CMAKE_C_FLAGS_INIT"]="-static -static-libgcc -static-libstdc++"
        cmake_config["CMAKE_CXX_FLAGS_INIT"]="-static -static-libgcc -static-libstdc++"
        cmake_config["CMAKE_EXE_LINKER_FLAGS_INIT"]="-static -static-libgcc -static-libstdc++"
        # Loop through remaining args in format KEY="VALUE"
        for arg in "$@"; do
            local key="${arg%%=*}"
            local value="${arg#*=}"
            echo "DEBUG: adding KEY:$key and VALUE:$value to cmake toolchain file for $variant" >>"$LOG_FILE"
            cmake_config["$key"]="$value"
        done
        echo "# Generated via get_generic_cmake_toolchain" > "$toolchain_path"
        # Write CMAKE_SYSTEM_NAME first (convention)
        echo "set(CMAKE_SYSTEM_NAME \"${cmake_config[CMAKE_SYSTEM_NAME]}\")" >> "$toolchain_path"
        unset 'cmake_config[CMAKE_SYSTEM_NAME]'
        # Write the rest
        for key in "${!cmake_config[@]}"; do
            echo "set($key \"${cmake_config[$key]}\")" >> "$toolchain_path"
        done
    fi
    echo "$toolchain_path"
}

get_meson_cross_libpulse() {
	local cpu_family="x86_64"
	if [ "$bits_target" = 32 ]; then
		cpu_family="x86"
	fi
	remove_path -fv "${src_dir}/libpulse/meson-cross-libpulse.mingw.txt"
	cat >>"${src_dir}/libpulse/meson-cross-libpulse.mingw.txt" <<EOF
[built-in options]
buildtype = 'release'
wrap_mode = 'nofallback'  
default_library = 'static'  
prefer_static = 'true'
backend = 'ninja'
prefix = '$dependency_install_prefix'
libdir = '$dependency_install_prefix/lib'
c_args = ['-DPCRE_STATIC']
c_link_args = ['-lpcre', '-Wl,--export-all-symbols', '-Wl,--allow-multiple-definition']

[binaries]
c = '${cross_prefix}gcc'
cpp = '${cross_prefix}g++'
ld = '${cross_prefix}ld'
ar = '${cross_prefix}ar'
strip = '${cross_prefix}strip'
nm = '${cross_prefix}nm'
windres = '${cross_prefix}windres'
dlltool = '${cross_prefix}dlltool'
pkg-config = 'pkg-config'
nasm = 'nasm'
cmake = 'cmake'

[host_machine]
system = 'windows'
cpu_family = '$cpu_family'
cpu = '$cpu_family'
endian = 'little'

[properties]
pkg_config_sysroot_dir = '$dependency_install_prefix'
pkg_config_libdir = '$pkg_config_sysroot_dir/lib/pkgconfig'
EOF
echo "${src_dir}/libpulse/meson-cross-libpulse.mingw.txt"
}

get_meson_cross_jsoncpp() {
	local cpu_family="x86_64"
	if [ "$bits_target" = 32 ]; then
		cpu_family="x86"
	fi
	remove_path -fv "${src_dir}/jsoncpp/meson-cross-jsoncpp.mingw.txt"
	cat >>"${src_dir}/jsoncpp/meson-cross-jsoncpp.mingw.txt" <<EOF
[built-in options]
buildtype = 'release'
wrap_mode = 'nofallback'  
default_library = 'both'
backend = 'ninja'
prefix = '$dependency_install_prefix'
libdir = 'lib'
includedir = 'include'

[binaries]
c = '${cross_prefix}gcc'
cpp = '${cross_prefix}g++'
ld = '${cross_prefix}ld'
ar = '${cross_prefix}ar'
strip = '${cross_prefix}strip'
nm = '${cross_prefix}nm'
windres = '${cross_prefix}windres'
dlltool = '${cross_prefix}dlltool'
pkg-config = 'pkg-config'
nasm = 'nasm'
cmake = 'cmake'

[host_machine]
system = 'windows'
cpu_family = '$cpu_family'
cpu = '$cpu_family'
endian = 'little'

[properties]
pkg_config_libdir = '$dependency_install_prefix/lib/pkgconfig'
EOF
echo "${src_dir}/jsoncpp/meson-cross-jsoncpp.mingw.txt"
}

get_meson_cross_file() {
    local variant_name="$1"      # e.g., "librist"
    local extra_content="$2"     # e.g., "[built-in options]..."
    local base_filename="$host_name-meson-cross.mingw.txt"
    local base_filepath="$src_dir/$base_filename"
    # 1. Generate the BASE file if it doesn't exist (Standard Logic)
    if [[ ! -e "$base_filepath" ]]; then
        local cpu_family="x86_64"
        if [ "$bits_target" = 32 ]; then
            cpu_family="x86"
        fi
        cat >"$base_filepath" <<EOF
[built-in options]
buildtype = 'release'
wrap_mode = 'nofallback'  
default_library = 'static'  
prefer_static = 'true'
backend = 'ninja'
prefix = '$dependency_install_prefix'
libdir = '$dependency_install_prefix/lib'
 
[binaries]
c = '${cross_prefix}gcc'
cpp = '${cross_prefix}g++'
ld = '${cross_prefix}ld'
ar = '${cross_prefix}ar'
strip = '${cross_prefix}strip'
nm = '${cross_prefix}nm'
windres = '${cross_prefix}windres'
dlltool = '${cross_prefix}dlltool'
pkg-config = 'pkg-config'
nasm = 'nasm'
cmake = 'cmake'

[host_machine]
system = 'windows'
cpu_family = '$cpu_family'
cpu = '$cpu_family'
endian = 'little'

[properties]
pkg_config_sysroot_dir = '$dependency_install_prefix'
pkg_config_libdir = '$pkg_config_sysroot_dir/lib/pkgconfig'
EOF
    fi
    # 2. Handle Custom Variant logic
    if [[ -n "$variant_name" ]]; then
        local custom_filepath="$(pwd)/$host_name-meson-cross.mingw.${variant_name}.txt"
        # Always overwrite the variant with a fresh copy of the base
        cp "$base_filepath" "$custom_filepath" 2>"$LOG_FILE"
        # Append custom options if provided
        if [[ -n "$extra_content" ]]; then
            # Add a newline for safety
            echo "" >> "$custom_filepath"
            echo -e "$extra_content" >> "$custom_filepath"
        fi
        # Return the path to the NEW custom file
        echo "$custom_filepath"
    else
        # No customization requested, return the standard base file
        echo "$base_filepath"
    fi
}

get_local_meson_cross_with_propeties() {
	local local_dir="$1"
	if [[ -z $local_dir ]]; then
		local_dir="."
	fi
	copy_path "$src_dir/$host_name-meson-cross.mingw.txt" "$local_dir"
	cat >>meson-cross.mingw.txt <<EOF
EOF
}

#endregion

#region WINDOWS FFMPEG UNUSED LIBRARIES

#===============================================================================================
#
#                        WINDOWS FFMPEG UNUSED LIBRARIES
#
#===============================================================================================

# build_facebooktransform360() {
# 	build_opencv
# 	change_dir "$src_dir"
# 	do_git_checkout https://github.com/facebook/transform360
# 	change_dir "$src_dir/transform360"
# 	apply_patch "file://$WINPATCHDIR/transform360.pi.diff" -p1
# 	#change_dir "$src_dir"
# 	change_dir "$src_dir/transform360/Transform360"
# 	do_cmake ""
# 	sed -i.bak "s/isystem/I/g" CMakeFiles/Transform360.dir/includes_CXX.rsp # weird stdlib.h error
# 	do_make_and_make_install
# 	change_dir "$src_dir"
# }

# build_lsmash() { # an MP4 library
# 	change_dir "$src_dir"
# 	do_git_checkout https://github.com/l-smash/l-smash l-smash
# 	change_dir l-smash
# 	do_configure "--prefix=$dependency_install_prefix --cross-prefix=$cross_prefix"
# 	do_make_and_make_install
# 	change_dir "$src_dir"
# }

# build_libproxy() {
# 	# NB this lacks a .pc file still
# 	change_dir "$src_dir"
# 	download_and_unpack_file https://libproxy.googlecode.com/files/libproxy-0.4.11.tar.gz
# 	change_dir "$src_dir/libproxy-0.4.11"
# 	sed -i.bak "s/= recv/= (void *) recv/" libmodman/test/main.cpp # some compile failure
# 	do_cmake_and_install
# 	change_dir "$src_dir"
# }

# build_lua() {
# 	change_dir "$src_dir"
# 	download_and_unpack_file https://www.lua.org/ftp/lua-5.3.3.tar.gz
# 	change_dir "$src_dir/lua-5.3.3"
# 	export AR="${cross_prefix}ar rcu"                                    # needs rcu parameter so have to call it out different :|
# 	# TODO: Allow shared library build
# 	do_make "CC=${cross_prefix}gcc RANLIB=${cross_prefix}ranlib generic" # generic == "generic target" and seems to result in a static build, no .exe's blah blah the mingw option doesn't even build liblua.a
# 	unset AR
# 	do_make_install "INSTALL_TOP=$dependency_install_prefix" "generic install"
# 	cp etc/lua.pc "$PKG_CONFIG_PATH"
# 	change_dir "$src_dir"
# }

# build_libhdhomerun() {
# 	exit_message 1 "unable to build libhdhomerun at the moment" # still broken unfortunately, for cross compile :|
# 	change_dir "$src_dir"
# 	download_and_unpack_file https://download.silicondust.com/hdhomerun/libhdhomerun_20150826.tgz libhdhomerun
# 	change_dir "$src_dir/libhdhomerun"
# 	do_make "CROSS_COMPILE=$cross_prefix OS=Windows_NT"
# 	change_dir "$src_dir"
# }

# build_dvbtee_app() {
# 	build_iconv # said it needed it
# 	build_curl  # it "can use this" so why not
# 	#  build_libhdhomerun # broken but possible dependency apparently :|
# 	change_dir "$src_dir"
# 	do_git_checkout https://github.com/mkrufky/libdvbtee libdvbtee
# 	change_dir "$src_dir/libdvbtee"
# 	# checkout its submodule, apparently required
# 	if [ ! -e libdvbpsi/bootstrap ]; then
# 		remove_path -rf libdvbpsi # remove placeholder
# 		do_git_checkout https://github.com/mkrufky/libdvbpsi
# 		change_dir libdvbpsi
# 		generic_configure_make_install # library dependency submodule... TODO don't install it, just leave it local :)
# 		change_dir ..
# 	fi
# 	generic_configure
# 	do_make # not install since don't have a dependency on the library
# 	change_dir "$src_dir"
# }

# build_qt() {
# 	build_libjpeg_turbo # libjpeg a dependency [?]
# 	unset CFLAGS        # it makes something of its own first, which runs locally, so can't use a foreign arch, or maybe it can, but not important enough: http://stackoverflow.com/a/18775859/32453 XXXX could look at this
# 	#download_and_unpack_file http://pkgs.fedoraproject.org/repo/pkgs/qt/qt-everywhere-opensource-src-4.8.7.tar.gz/d990ee66bf7ab0c785589776f35ba6ad/qt-everywhere-opensource-src-4.8.7.tar.gz # untested
# 	#cd qt-everywhere-opensource-src-4.8.7
# 	# download_and_unpack_file http://download.qt-project.org/official_releases/qt/5.1/5.1.1/submodules/qtbase-opensource-src-5.1.1.tar.xz qtbase-opensource-src-5.1.1 # not officially supported seems...so didn't try it
# 	change_dir "$src_dir"
# 	download_and_unpack_file http://pkgs.fedoraproject.org/repo/pkgs/qt/qt-everywhere-opensource-src-4.8.5.tar.gz/1864987bdbb2f58f8ae8b350dfdbe133/qt-everywhere-opensource-src-4.8.5.tar.gz
# 	change_dir qt-everywhere-opensource-src-4.8.5
# 	apply_patch "file://$WINPATCHDIR/imageformats.patch"
# 	apply_patch "file://$WINPATCHDIR/qt-win64.patch"
# 	# vlc's configure options...mostly
# 	# TODO: Allow shared library build
# 	do_configure "-static -release -fast -no-exceptions -no-stl -no-sql-sqlite -no-qt3support -no-gif -no-libmng -qt-libjpeg -no-libtiff -no-qdbus -no-openssl -no-webkit -sse -no-script -no-multimedia -no-phonon -opensource -no-scripttools -no-opengl -no-script -no-scripttools -no-declarative -no-declarative-debug -opensource -no-s60 -host-little-endian -confirm-license -xplatform win32-g++ -device-option CROSS_COMPILE=$cross_prefix -prefix $dependency_install_prefix -prefix-install -nomake examples"
# 	if [ ! -f 'already_qt_maked_k' ]; then
# 		make sub-src -j "$(get_cpu_count)"
# 		make install sub-src                                                                      # let it fail, baby, it still installs a lot of good stuff before dying on mng...? huh wuh?
# 		cp ./plugins/imageformats/libqjpeg.a "$dependency_install_prefix/lib" || exit_message 1 "could not copy ./plugins/imageformats/libqjpeg.a"             # I think vlc's install is just broken to need this [?]
# 		cp ./plugins/accessible/libqtaccessiblewidgets.a "$dependency_install_prefix/lib" || exit_message 1 "could not copy ./plugins/accessible/libqtaccessiblewidgets.a" # this feels wrong...
# 		# do_make_and_make_install "sub-src" # sub-src might make the build faster? # complains on mng? huh?
# 		create_touch_file 0 'already_qt_maked_k'
# 	fi
# 	# vlc needs an adjust .pc file? huh wuh?
# 	sed -i.bak 's/Libs: -L${libdir} -lQtGui/Libs: -L${libdir} -lcomctl32 -lqjpeg -lqtaccessiblewidgets -lQtGui/' "$PKG_CONFIG_PATH/QtGui.pc" # sniff
# 	change_dir "$src_dir"
# 	reset_cflags
# }

# build_vlc() {
# 	# currently broken, since it got too old for libavcodec and I didn't want to build its own custom one yet to match, and now it's broken with gcc 5.2.0 seemingly
# 	# call out dependencies here since it's a lot, plus hierarchical FTW!
# 	# should be ffmpeg 1.1.1 or some odd?
# 	echo -e "not building vlc, broken dependencies or something weird"
# 	return
# 	# vlc's own dependencies:
# 	build_lua
# 	build_libdvdread
# 	build_libdvdnav
# 	build_libx265
# 	build_libjpeg_turbo
# 	build_ffmpeg
# 	build_qt
# 	change_dir "$src_dir"
# 	# currently vlc itself currently broken :|
# 	do_git_checkout https://github.com/videolan/vlc
# 	change_dir vlc
# 	#apply_patch file://$WINPATCHDIR/vlc_localtime_s.patch # git revision needs it...
# 	# outdated and patch doesn't apply cleanly anymore apparently...
# 	#if [[ "$non_free" = "y" ]]; then
# 	#  apply_patch https://raw.githubusercontent.com/gcsx/ffmpeg-windows-build-helpers/patch-5/patches/priorize_avcodec.patch
# 	#fi
# 	if [[ ! -f "configure" ]]; then
# 		./bootstrap
# 	fi
# 	export DVDREAD_LIBS='-ldvdread -ldvdcss -lpsapi'
# 	do_configure "--disable-libgcrypt --disable-a52 --host=$host_target --disable-lua --disable-mad --enable-qt --disable-sdl --disable-mod" # don't have lua mingw yet, etc. [vlc has --disable-sdl [?]] x265 disabled until we care enough... Looks like the bluray problem was related to the BLURAY_LIBS definition. [not sure what's wrong with libmod]
# 	remove_path -f "$(find . -name "*.exe")"                                                                                                 # try to force a rebuild...though there are tons of .a files we aren't rebuilding as well FWIW...:|
# 	remove_path -f already_ran_make*                                                                                                         # try to force re-link just in case...
# 	do_make
# 	# do some gymnastics to avoid building the mozilla plugin for now [couldn't quite get it to work]
# 	#sed -i.bak 's_git://git.videolan.org/npapi-vlc.git_https://github.com/rdp/npapi-vlc.git_' Makefile # this wasn't enough...following lines instead...
# 	sed -i.bak "s/package-win-common: package-win-install build-npapi/package-win-common: package-win-install/" Makefile
# 	sed -i.bak "s/.*cp .*builddir.*npapi-vlc.*//g" Makefile
# 	make package-win-common # not do_make, fails still at end, plus this way we get new vlc.exe's
# 	echo -e "


#      vlc success, created a file like ${PWD}/vlc-xxx-git/vlc.exe



# "
# 	change_dir "$src_dir"
# 	unset DVDREAD_LIBS
# }

# build_mplayer() {
# 	# pre requisites
# 	build_libjpeg_turbo
# 	build_libdvdread
# 	build_libdvdnav

# 	download_and_unpack_file https://sourceforge.net/projects/mplayer-edl/files/mplayer-export-snapshot.2014-05-19.tar.bz2 mplayer-export-2014-05-19
# 	change_dir mplayer-export-2014-05-19
# 	do_git_checkout https://github.com/FFmpeg/FFmpeg ffmpeg d43c303038e9bd # known compatible commit
# 	export LDFLAGS='-lpthread -ldvdnav -ldvdread -ldvdcss'                 # not compat with newer dvdread possibly? huh wuh?
# 	export CFLAGS=-DHAVE_DVDCSS_DVDCSS_H
# 	do_configure "--enable-cross-compile --host-cc=cc --cc=${cross_prefix}gcc --windres=${cross_prefix}windres --ranlib=${cross_prefix}ranlib --ar=${cross_prefix}ar --as=${cross_prefix}as --nm=${cross_prefix}nm --enable-runtime-cpudetection --extra-cflags=$CFLAGS --with-dvdnav-config=$dependency_install_prefix/bin/dvdnav-config --disable-dvdread-internal --disable-libdvdcss-internal --disable-w32threads --enable-pthreads --extra-libs=-lpthread --enable-debug --enable-ass-internal --enable-dvdread --enable-dvdnav --disable-libvpx-lavc" # haven't reported the ldvdcss thing, think it's to do with possibly it not using dvdread.pc [?] XXX check with trunk
# 	# disable libvpx didn't work with its v1.5.0 some reason :|
# 	unset LDFLAGS
# 	reset_cflags
# 	sed -i.bak "s/HAVE_PTHREAD_CANCEL 0/HAVE_PTHREAD_CANCEL 1/g" config.h # mplayer doesn't set this up right?
# 	touch -t 201203101513 config.h                                        # the above line change the modify time for config.h--forcing a full rebuild *every time* yikes!
# 	# try to force re-link just in case...
# 	remove_path -f *.exe
# 	remove_path -f already_ran_make* # try to force re-link just in case...
# 	do_make
# 	cp mplayer.exe mplayer_debug.exe
# 	"${cross_prefix}strip" mplayer.exe
# 	echo -e "built ${PWD}/{mplayer,mencoder,mplayer_debug}.exe"
# 	change_dir "$src_dir"
# }

# build_mp4box() { # like build_gpac
# 	# This script only builds the gpac_static lib plus MP4Box. Other tools inside
# 	# specify revision until this works: https://sourceforge.net/p/gpac/discussion/287546/thread/72cf332a/
# 	do_git_checkout https://github.com/gpac/gpac mp4box_gpac
# 	change_dir mp4box_gpac
# 	# are these tweaks needed? If so then complain to the mp4box people about it?
# 	sed -i.bak "s/has_dvb4linux=\"yes\"/has_dvb4linux=\"no\"/g" configure
# 	# XXX do I want to disable more things here?
# 	# ./prebuilt/cross_compilers/mingw-w64-i686/bin/i686-w64-mingw32-sdl-config
# 	# TODO: Allow shared library build
# 	generic_configure "  --cross-prefix=${cross_prefix} --target-os=MINGW32 --extra-cflags=-Wno-format --static-build --static-bin --disable-oss-audio --extra-ldflags=-municode --disable-x11 --sdl-cfg=${cross_prefix}sdl-config"
# 	./check_revision.sh
# 	# I seem unable to pass 3 libs into the same config line so do it with sed...
# 	sed -i.bak "s/EXTRALIBS=.*/EXTRALIBS=-lws2_32 -lwinmm -lz/g" config.mak
# 	change_dir src
# 	do_make "$compiler_flags"
# 	change_dir ..
# 	remove_path -f ./bin/gcc/MP4Box* # try and force a relink/rebuild of the .exe
# 	change_dir applications/mp4box
# 	remove_path -f already_ran_make* # ??
# 	do_make "$compiler_flags"
# 	change_dir ../..
# 	# copy it every time just in case it was rebuilt...
# 	cp ./bin/gcc/MP4Box ./bin/gcc/MP4Box.exe # it doesn't name it .exe? That feels broken somehow...
# 	echo -e "built $(readlink -f ./bin/gcc/MP4Box.exe)"
# 	change_dir "$src_dir"
# }

# build_libMXF() {
# 	download_and_unpack_file https://sourceforge.net/projects/ingex/files/1.0.0/libMXF/libMXF-src-1.0.0.tgz "libMXF-src-1.0.0"
# 	change_dir libMXF-src-1.0.0
# 	apply_patch "file://$WINPATCHDIR/libMXF.diff"
# 	do_make "MINGW_CC_PREFIX=$cross_prefix"
# 	#
# 	# Manual equivalent of make install. Enable it if desired. We shouldn't need it in theory since we never use libMXF.a file and can just hand pluck out the *.exe files already...
# 	#
# 	#cp libMXF/lib/libMXF.a $dependency_install_prefix/lib/libMXF.a
# 	#cp libMXF++/libMXF++/libMXF++.a $dependency_install_prefix/lib/libMXF++.a
# 	#mv libMXF/examples/writeaviddv50/writeaviddv50 libMXF/examples/writeaviddv50/writeaviddv50.exe
# 	#mv libMXF/examples/writeavidmxf/writeavidmxf libMXF/examples/writeavidmxf/writeavidmxf.exe
# 	#cp libMXF/examples/writeaviddv50/writeaviddv50.exe $dependency_install_prefix/bin/writeaviddv50.exe
# 	#cp libMXF/examples/writeavidmxf/writeavidmxf.exe $dependency_install_prefix/bin/writeavidmxf.exe
# 	change_dir "$src_dir"
# }

# build_lsw() {
# 	# Build L-Smash-Works, which are AviSynth plugins based on lsmash/ffmpeg
# 	#build_ffmpeg static # dependency, assume already built since it builds before this does...
# 	build_lsmash # dependency
# 	do_git_checkout https://github.com/VFR-maniac/L-SMASH-Works lsw
# 	change_dir lsw/VapourSynth
# 	do_configure "--prefix=$dependency_install_prefix --cross-prefix=$cross_prefix --target-os=mingw"
# 	do_make_and_make_install
# 	# AviUtl is 32bit-only
# 	if [ "$bits_target" = "32" ]; then
# 		change_dir ../AviUtl
# 		do_configure "--prefix=$dependency_install_prefix --cross-prefix=$cross_prefix"
# 		do_make
# 	fi
# 	change_dir "$src_dir"
# }


# build_librtmfp() {
# 	# needs some version of openssl...
# 	# build_openssl_1_0_2 # fails OS X
# 	build_openssl_1_1_1 # fails WSL
# 	change_dir "$src_dir"
# 	do_git_checkout https://github.com/MonaSolutions/librtmfp
# 	change_dir "$src_dir/librtmfp/include/Base"
# 	do_git_checkout https://github.com/meganz/mingw-std-threads mingw-std-threads # our g++ apparently doesn't have std::mutex baked in...weird...this replaces it...
# 	change_dir "$src_dir"
# 	change_dir "$src_dir/librtmfp"
# 	apply_patch "file://$WINPATCHDIR/rtmfp.static.cross.patch" -p1  # works e48efb4f
# 	apply_patch "file://$WINPATCHDIR/rtmfp_capitalization.diff" -p1 # cross for windows needs it if on linux...
# 	apply_patch "file://$WINPATCHDIR/librtmfp_xp.diff.diff" -p1     # cross for windows needs it if on linux...
# 	do_make "$compiler_flags GPP=${cross_prefix}g++"
# 	do_make_install "prefix=$dependency_install_prefix PKGCONFIGPATH=$PKG_CONFIG_PATH"
# 	sed -i.bak 's/-lrtmfp.*/-lrtmfp -lstdc++ -lws2_32 -liphlpapi/' "$PKG_CONFIG_PATH/librtmfp.pc"
# 	change_dir "$src_dir"
# }

# build_openssl_1_0_2() {
# 	change_dir "$src_dir"
# 	download_and_unpack_file https://www.openssl.org/source/openssl-1.0.2p.tar.gz
# 	change_dir "$src_dir/openssl-1.0.2p"
# 	apply_patch "file://$WINPATCHDIR/openssl-1.0.2l_lib-only.diff"
# 	export CC="${cross_prefix}gcc"
# 	export AR="${cross_prefix}ar"
# 	export RANLIB="${cross_prefix}ranlib"
# 	local config_options="--prefix=$dependency_install_prefix zlib "
# 	if [ "$1" = "dllonly" ]; then
# 		config_options+="shared "
# 	else
# 		config_options+="no-shared no-dso "
# 	fi
# 	if [ "$bits_target" = "32" ]; then
# 		config_options+="mingw" # Build shared libraries ('libeay32.dll' and 'ssleay32.dll') if "dllonly" is specified.
# 		local arch=x86
# 	else
# 		config_options+="mingw64" # Build shared libraries ('libeay64.dll' and 'ssleay64.dll') if "dllonly" is specified.
# 		local arch=x86_64
# 	fi
# 	do_configure "$config_options" ./Configure
# 	if [[ ! -f Makefile_1 ]]; then
# 		sed -i_1 "s/-O3/-O2/" Makefile # Change CFLAGS (OpenSSL's 'Configure' already creates a 'Makefile.bak').
# 	fi
# 	if [ "$1" = "dllonly" ]; then
# 		do_make "build_libs"

# 		create_dir "$src_dir/redist" # Strip and pack shared libraries.
# 		archive="$src_dir/redist/openssl-${arch}-v1.0.2l.7z"
# 		if [[ ! -f $archive ]]; then
# 			for sharedlib in *.dll; do
# 				# shellcheck disable=SC2086
# 				"${cross_prefix}strip" $sharedlib
# 			done
# 			sed "s/$/\r/" LICENSE >LICENSE.txt
# 			7z a -mx=9 "$archive" *.dll LICENSE.txt && remove_path -f LICENSE.txt
# 		fi
# 	else
# 		do_make_and_make_install
# 	fi
# 	unset CC
# 	unset AR
# 	unset RANLIB
# 	change_dir "$src_dir"
# }

# build_openssl_1_1_1() {
# 	change_dir "$src_dir"
# 	download_and_unpack_file https://www.openssl.org/source/openssl-1.1.1.tar.gz
# 	change_dir "$src_dir/openssl-1.1.1"
# 	export CC="${cross_prefix}gcc"
# 	export AR="${cross_prefix}ar"
# 	export RANLIB="${cross_prefix}ranlib"
# 	local config_options="--prefix=$dependency_install_prefix zlib "
# 	if [ "$1" = "dllonly" ]; then
# 		config_options+="shared no-engine "
# 	else
# 		config_options+="no-shared no-dso no-engine "
# 	fi
# 	if [[ $(uname) =~ 5.1 ]] || [[ $(uname) =~ 6.0 ]]; then
# 		config_options+="no-async " # "Note: on older OSes, like CentOS 5, BSD 5, and Windows XP or Vista, you will need to configure with no-async when building OpenSSL 1.1.0 and above. The configuration system does not detect lack of the Posix feature on the platforms." (https://wiki.openssl.org/index.php/Compilation_and_Installation)
# 	fi
# 	if [ "$bits_target" = "32" ]; then
# 		config_options+="mingw" # Build shared libraries ('libcrypto-1_1.dll' and 'libssl-1_1.dll') if "dllonly" is specified.
# 		local arch=x86
# 	else
# 		config_options+="mingw64" # Build shared libraries ('libcrypto-1_1-x64.dll' and 'libssl-1_1-x64.dll') if "dllonly" is specified.
# 		local arch=x86_64
# 	fi
# 	do_configure "$config_options" ./Configure
# 	if [[ ! -f Makefile.bak ]]; then # Change CFLAGS.
# 		sed -i.bak "s/-O3/-O2/" Makefile
# 	fi
# 	do_make "build_libs"
# 	if [ "$1" = "dllonly" ]; then
# 		create_dir "$src_dir/redist" # Strip and pack shared libraries.
# 		archive="$src_dir/redist/openssl-${arch}-v1.1.0f.7z"
# 		if [[ ! -f $archive ]]; then
# 			for sharedlib in *.dll; do
# 				# shellcheck disable=SC2086
# 				"${cross_prefix}strip" $sharedlib
# 			done
# 			sed "s/$/\r/" LICENSE >LICENSE.txt
# 			7z a -mx=9 "$archive" *.dll LICENSE.txt && remove_path -f LICENSE.txt
# 		fi
# 	else
# 		do_make_install "" "install_dev"
# 	fi
# 	unset CC
# 	unset AR
# 	unset RANLIB
# 	change_dir "$src_dir"
# }


# build_intel_qsv_mfx() {
# 	change_dir "$src_dir"                                                                # disableable via command line switch...
# 	do_git_checkout https://github.com/lu-zero/mfx_dispatch mfx_dispatch 2cd279f # lu-zero?? oh well seems somewhat supported...
# 	change_dir "$src_dir/mfx_dispatch"
# 	if [[ ! -f "configure" ]]; then
# 		autoreconf -fiv || exit_message 1 "could not autoreconf intel_qsv_mfx"
# 		automake --add-missing || exit_message 1 "could not autoremake intel_qsv_mfx"
# 	fi
# 	generic_configure_make_install
# 	change_dir "$src_dir"
# }
#
#
# build_AudioToolboxWrapper() {
#   do_git_checkout https://github.com/cynagenautes/AudioToolboxWrapper AudioToolboxWrapper
#   change_dir AudioToolboxWrapper
#     do_cmake "-B build -GNinja"
#     do_ninja_and_ninja_install
#     # This wrapper library enables FFmpeg to use AudioToolbox codecs on Windows, with DLLs shipped with iTunes.
#     # i.e. You need to install iTunes, or be able to LoadLibrary("CoreAudioToolbox.dll"), for this to work.
#     # test ffmpeg build can use it [ffmpeg -f lavfi -i sine=1000 -c aac_at -f mp4 -y NUL]
#   change_dir ..
# }

#endregion

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