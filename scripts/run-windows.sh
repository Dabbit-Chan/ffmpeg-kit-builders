#!/bin/bash

# shellcheck disable=SC2317,SC2129,SC1091,SC2120,SC2035,SC2016

#region WINDOWS FFMPEG BUILD PRIMARY DEPENDENCIES

#===============================================================================================
#
#                        WINDOWS FFMPEG BUILD PRIMARY DEPENDENCIES
#
#===============================================================================================

build_dlfcn() {
  local repo="https://github.com/dlfcn-win32/dlfcn-win32"
  local lib="dlfcn-win32"
  local repo_ver="v1.4.2"
	change_dir "$src_dir"
	do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
	change_dir "$src_dir/$lib"
	if [[ ! -f Makefile.bak ]]; then # Change CFLAGS.
		sed -i.bak "s/-O3/-O2/" Makefile
	fi
	do_configure "--prefix=$dependency_install_prefix --cross-prefix=$cross_prefix" # rejects some normal cross compile options so custom here
	do_make_and_make_install
	gen_ld_script libdl.a dl_s -lpsapi # dlfcn-win32's 'README.md': "If you are linking to the static 'dl.lib' or 'libdl.a', then you would need to explicitly add 'psapi.lib' or '-lpsapi' to your linking command, depending on if MinGW is used."
	change_dir "$src_dir"
}
# build_libxavs           # config_options+= --enable-libxavs             # enable AVS encoding via xavs [no]
build_libxavs() {
  if ! truthy "$disable_libxavs" && truthy "$enable_libxavs"; then
  local repo="https://github.com/Distrotech/xavs"
  local lib="libxavs"
  local repo_ver="distrotech-xavs-git"
	change_dir "$src_dir"
	do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
	change_dir "$src_dir/$lib"
  sed -i 's/, tmp\[0\]);/, \&tmp[0]);/g' "$src_dir/$lib/common/i386/dct-c.c"
  sed -i 's/, tmp\[1\]);/, \&tmp[1]);/g' "$src_dir/$lib/common/i386/dct-c.c"
  sed -i 's/, tmp\[2\]);/, \&tmp[2]);/g' "$src_dir/$lib/common/i386/dct-c.c"
  sed -i 's/, tmp\[3\]);/, \&tmp[3]);/g' "$src_dir/$lib/common/i386/dct-c.c"
	if [[ ! -f Makefile.bak ]]; then
		sed -i.bak "s/O4/O2/" configure # Change CFLAGS.
	fi
  clear_cross_vars AS
  # wget "https://patch-diff.githubusercontent.com/raw/Distrotech/xavs/pull/1.patch" > >(redirect_output) 2>&1
	# apply_patch "1.patch"
	generic_configure "--enable-static \
--disable-shared \
--enable-pic \
--with-pic \
--disable-asm \
--extra-cflags=\"-fPIC\" \
--host=$host_target \
--prefix=$dependency_install_prefix \
--cross-prefix=$cross_prefix"
	do_make_and_make_install "AS= " "AS= "
	if [[ -d NUL ]]; then
		remove_path -f NUL # cygwin causes windows explorer to not be able to delete this folder if it has this oddly named file in it...
	fi
  reset_cross_vars
	change_dir "$src_dir"
	fi
}
# build_libdavs2          # config_options+= --enable-libdavs2            # enable AVS2 decoding via libdavs2 [no]
build_libdavs2() {
  if ! truthy "$disable_libdavs2" && truthy "$enable_libdavs2"; then
  local repo="https://github.com/pkuvcl/davs2"
  local lib="davs2"
  local repo_ver="1.7"
	change_dir "$src_dir"
	do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
	change_dir "$src_dir/$lib/build/linux"
  clear_cross_vars AS
	generic_configure "--enable-pic --disable-asm --disable-cli"
  disable_nonessential "$src_dir/$lib/build/linux"
	do_make_and_make_install "AS= AR=\"$AR rc \" " "AS= AR=\"$AR rc \" "
  sed -i "s/Version:.*/Version: ${repo_ver}.0/g" "$dependency_install_prefix"/lib/pkgconfig/davs2.pc
	change_dir "$src_dir"
  reset_cross_vars
	fi
}
# build_libxavs2          # config_options+= --enable-libxavs2            # enable AVS2 encoding via xavs2 [no]
build_libxavs2() {
  if ! truthy "$disable_libxavs2" && truthy "$enable_libxavs2"; then
	if [[ $host_target != 'i686-w64-mingw32' ]]; then
    local repo="https://github.com/pkuvcl/xavs2"
    local lib="libxavs2"
    local repo_ver="1.4"
	change_dir "$src_dir"
    do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
		change_dir "$src_dir/$lib/build/linux"
    clear_cross_vars AS
		generic_configure "--disable-cli \
--enable-static \
--disable-shared \
--enable-pic \
--with-pic \
--disable-asm \
--extra-cflags=\"$CFLAGS -Wno-error=incompatible-pointer-types\""
    wget "https://github.com/pkuvcl/xavs2/compare/master...1480c1:xavs2:gcc14/pointerconversion.patch" > >(redirect_output) 2>&1
    apply_patch "pointerconversion.patch"
    disable_nonessential "$src_dir/$lib/build/linux"
		do_make_and_make_install "AS= AR=\"$AR rc \" " "AS= AR=\"$AR rc \" "
    reset_cross_vars
	change_dir "$src_dir"
  sed -i "s/^Version:.*/Version: $repo_ver.0/g" "$install_pkgconfig_dir/xavs2.pc"
	fi
	fi
}

build_mingw_std_threads() {
  local repo="https://github.com/meganz/mingw-std-threads"
  local lib="mingw-std-threads"
  local repo_ver="1.0.0"
	change_dir "$src_dir"
	do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
	change_dir "$src_dir/$lib"
	cp *.h "$dependency_install_prefix/include"
	change_dir "$src_dir"
}
# build_zlib              # config_options+= --disable-zlib               # disable zlib [autodetect]
build_zlib() {
  if ! truthy "$disable_zlib" && truthy "$enable_zlib" || [[ -n "$1" ]]; then
  local repo="https://github.com/madler/zlib"
  local lib="zlib"
  local repo_ver="v1.3.1"
	change_dir "$src_dir"
	do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
	change_dir "$src_dir/$lib"
	local make_options
	export ARFLAGS=rcs # Native can't take ARFLAGS; https://stackoverflow.com/questions/21396988/zlib-build-not-configuring-properly-with-cross-compiler-ignores-ar
	do_configure "--static \
--prefix=\"$dependency_install_prefix\" \
--libdir=\"$dependency_install_prefix/lib\"
CFLAGS=\"-O3\" \
CPPFLAGS=\"\"" #doesnt like host variable
  disable_nonessential "$src_dir/$lib"
	do_make_and_make_install "$(get_compiler_flags) ARFLAGS=rcs"
	unset ARFLAGS
	change_dir "$src_dir"
  fi
}
# build_libcaca           # config_options+= --enable-libcaca             # enable textual display using libcaca [no]
build_libcaca() {
  if ! truthy "$disable_libcaca" && truthy "$enable_libcaca"; then
	run_valid_function "build_brotli"
  local lib="libcaca"
  local repo_ver="v0.99.beta20"
  local repo="https://github.com/cacalabs/libcaca"
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  export LDFLAGS="$LDFLAGS -lbrotlidec -lbrotlicommon -liconv -lxml2 -lglib-2.0 -lpcre2-8 -pthread -lffi -lz -lgraphite2"
  [[ ! -f "caca/figfont.c.bak" ]] && copy_path "caca/figfont.c" "caca/figfont.c.bak" "-fv" >>"$LOG_FILE" 2>&1
  [[ ! -f "caca/string.c.bak" ]] && copy_path "caca/string.c" "caca/string.c.bak" "-fv" >>"$LOG_FILE" 2>&1
  apply_patch "$PATCHDIR/libcaca_git_stdio-cruft.diff"
  sed -i 's/AC_PREREQ([2.71])/# AC_PREREQ([2.71])/g' configure.ac
  generic_configure "--disable-csharp \
--disable-java  \
--disable-cxx \
--disable-python \
--disable-ruby \
--disable-doc \
--disable-cocoa \
--disable-ncurses \
--disable-x11 \
--disable-gl"
  change_dir "$src_dir/$lib/caca"
  sed -i.bak "s/__declspec(dllexport)//g" *.h # get rid of the declspec lines otherwise the build will fail for undefined symbols
  sed -i.bak "s/__declspec(dllimport)//g" *.h
  change_dir "$src_dir/$lib"
  disable_nonessential "$src_dir/$lib" "src"
	do_make_and_make_install
	change_dir "$src_dir"
  reset_ldflags
	fi
}
# build_bzlib             # config_options+= --disable-bzlib              # disable bzlib [autodetect]
build_bzlib() {
  # https://gitlab.com/bzip2/bzip2
  local lib="bzip2"
  local repo="https://sourceware.org/pub/bzip2/bzip2-1.0.8.tar.gz"
  local repo_ver="bzip2-1.0.8"
	change_dir "$src_dir"
	download_and_unpack_file "$repo" "$lib"
	change_dir "$src_dir/$lib"
  apply_patch "$PATCHDIR/bzip2-1.0.8_brokenstuff.diff"
	generic_make "libbz2.a CFLAGS=\"${CFLAGS}\""
  disable_nonessential "$src_dir/$lib"
  
  if [[ -f "$src_dir/$lib/bzlib.h" ]]; then
    copy_path "$src_dir/$lib/bzlib.h" "$dependency_install_prefix/include/bzlib.h" "-fv" >>"$LOG_FILE" 2>&1
  fi
  if [[ -f "$src_dir/$lib/libbz2.a" ]]; then
    copy_path "$src_dir/$lib/libbz2.a" "$dependency_install_prefix/lib/libbz2.a" "-fv" >>"$LOG_FILE" 2>&1
  fi
  if [[ ! -f "$install_pkgconfig_dir/bzip2.pc" ]] || truthy "$build_force"; then
  cat > "$install_pkgconfig_dir/bzip2.pc" <<EOF
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
  fi
	change_dir "$src_dir"
}
# build_lzma              # config_options+= --disable-lzma               # disable lzma [autodetect]
build_lzma() {
  if ! truthy "$disable_lzma" && truthy "$enable_lzma"; then
	echo "NOTE FROM LZMA DEV: Users of LZMA Utils should 
  move to XZ Utils. XZ Utils support the legacy 
  .lzma format used by LZMA Utils, and can also 
  emulate the command line tools of LZMA Utils." >>"$LOG_FILE"
  local lib="xz"
  local repo="https://sourceforge.net/projects/lzmautils/files/xz-5.8.1.tar.xz"
	change_dir "$src_dir"
	download_and_unpack_file "$repo" "$lib"
  change_dir "$src_dir/$lib"
	generic_configure "--enable-static --disable-shared --disable-xz --disable-xzdec --disable-lzmadec --disable-lzmainfo --disable-scripts --disable-doc --disable-nls"
	disable_nonessential "$src_dir/$lib"
  do_make_and_make_install
	change_dir "$src_dir"
  fi
}
# build_iconv             # config_options+= --disable-iconv              # disable iconv [autodetect]
build_iconv() {
  if ! truthy "$disable_iconv" && truthy "$enable_iconv" || [[ -n "$1" ]]; then
	local lib="libiconv"
  local repo="https://ftp.gnu.org/gnu/libiconv/libiconv-1.18.tar.gz"
  local repo_ver="v1.18"
	change_dir "$src_dir"
	download_and_unpack_file "$repo" "$lib"
  change_dir "$src_dir/$lib"
  touch "no.autoreconf"
	generic_configure "--enable-static \
--with-sysroot=${dependency_install_prefix} \
--enable-pic \
--with-pic \
--disable-shared \
--disable-nls \
--disable-rpath \
--disable-tools \
--disable-tests \
--disable-examples \
--disable-docs \
--without-libintl-prefix \
CFLAGS=\"$CFLAGS\"" "" "minimal"
  sed -i 's/OBJECTS_RES_yes = libiconv.res.lo/OBJECTS_RES_yes = /g' "lib/Makefile"
  sed -i 's/OBJECTS_RES_yes = iconv.res/OBJECTS_RES_yes = /g' "src/Makefile"
  disable_nonessential "$src_dir/$lib"
  do_make "" "minimal"
  do_make_install "" "-C lib install" "minimal"
  if [[ -f "$src_dir/$lib/include/iconv.h.inst" ]]; then
    copy_path "$src_dir/$lib/include/iconv.h.inst" "$dependency_install_prefix/include/iconv.h" "-fv" >>"$LOG_FILE" 2>&1
  fi
	change_dir "$src_dir"
  reset_allflags
	run_valid_function "build_gettext"
  reset_allflags
	local lib="libiconv"
  change_dir "$src_dir/$lib"
  generic_configure "--prefix=${dependency_install_prefix} \
--enable-static \
--disable-shared \
--enable-pic \
--with-pic \
--disable-nls \
--with-libintl-prefix=${dependency_install_prefix} \
CFLAGS=\"$CFLAGS\"" "" "full"
  disable_nonessential "$src_dir/$lib"
  sed -i 's/OBJECTS_RES_yes = libiconv.res.lo/OBJECTS_RES_yes = /g' "lib/Makefile"
  sed -i 's/OBJECTS_RES_yes = iconv.res/OBJECTS_RES_yes = /g' "src/Makefile"
  do_make_and_make_install "" "" "full"
  cat > "$install_pkgconfig_dir/iconv.pc" << EOF
prefix=$dependency_install_prefix
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: libiconv
Description: GNU libiconv character set conversion library
Version: 1.18
Libs: -L\${libdir} -liconv
Cflags: -I\${includedir}
EOF
	change_dir "$src_dir"
  fi
}
# build_sdl2              # config_options+= --disable-sdl2               # disable sdl2 [autodetect]
build_sdl2() {
  if ! truthy "$disable_sdl2" && truthy "$enable_sdl2" || [[ -n "$1" ]]; then
	local lib="sdl2-$host_name"
  # local repo="https://github.com/libsdl-org/SDL"
  local repo="https://github.com/libsdl-org/SDL/releases/download/release-2.32.10/SDL2-2.32.10.tar.gz"
  local repo_ver="release-2.32.10"
	change_dir "$src_dir"
  download_and_unpack_file "$repo" "$lib"
  change_dir "$src_dir/$lib"
  generic_configure "--bindir=$toolchain_bin_path --enable-static --disable-shared"
  sed -i -E 's|=\s*\$\(objects\)/version\.lo|=|g' "Makefile"
  disable_nonessential "$src_dir/$lib"
  do_make_and_make_install
	change_dir "$src_dir"
  fi
}
# build_amf               # config_options+= --disable-amf                # disable AMF video encoding code [autodetect]
build_amf() {
  if ! truthy "$disable_amf" && truthy "$enable_amf"; then
	local lib="amf_headers"
  local repo="https://github.com/GPUOpen-LibrariesAndSDKs/AMF"
  local repo_ver="v1.5.0"
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
	change_dir "$src_dir/$lib"
	local touch_name=$(get_small_touchfile_name "${host_name}_already_installed")
	if [ ! -f "$touch_name" ]; then
		if [ ! -d "$dependency_install_prefix/include/AMF" ]; then
			create_dir "$dependency_install_prefix/include/AMF"
		fi
		cp -av "amf/public/include/." "$dependency_install_prefix/include/AMF" >>"$LOG_FILE"
		create_touch_file 0 "$touch_name"
  else
    echo -e "INFO: amf headers already installed" >>"$LOG_FILE"
	fi
	change_dir "$src_dir"
	fi
}
# build_libvpl            # config_options+= --enable-libvpl              # enable Intel oneVPL code via libvpl if libmfx is not used [no]
build_libvpl() {
  if ! truthy "$disable_libvpl" && truthy "$enable_libvpl"; then
	local lib="libvpl"
  local repo="https://github.com/intel/libvpl"
  local repo_ver="v2.15.0"
	change_dir "$src_dir"
	do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
	if [ "$bits_target" = "32" ]; then
		wget "https://raw.githubusercontent.com/msys2/MINGW-packages/master/mingw-w64-libvpl/0003-cmake-fix-32bit-install.patch" > >(redirect_output) 2>&1
    apply_patch "0003-cmake-fix-32bit-install.patch"
  fi
  change_dir "$src_dir/$lib"
  sed -i 's|configure_file(src/windows.*||g' "$src_dir/$lib/libvpl/CMakeLists.txt"
  sed -i 's|list(APPEND SOURCES ${CMAKE_CURRENT_BINARY_DIR}/src/windows/version.rc)||g' "$src_dir/$lib/libvpl/CMakeLists.txt"
  change_dir "$src_dir/$lib/build" 1
  do_cmake_from_build_dir "$src_dir/$lib" "-DCMAKE_BUILD_TYPE=Release \
-DBUILD_SHARED_LIBS=OFF \
-DBUILD_TESTS=OFF \
-DINSTALL_EXAMPLES=OFF \
-DINSTALL_LIB=ON \
-DINSTALL_DEV=ON \
-DINSTALL_EXAMPLES=OFF \
-DINSTALL_DEV=ON \
-DBUILD_EXPERIMENTAL=OFF \
-DENABLE_LIBDIR_IN_RUNTIME_SEARCH=ON \
-DBUILD_EXPERIMENTAL=OFF"
  disable_nonessential "$src_dir/$lib/build"
	do_make_and_make_install
  add_libs_to_pkg -t="$install_pkgconfig_dir/vpl.pc" -l="-lstdc++"
	change_dir "$src_dir"
	fi
}
# build_nvenc             # config_options+= --disable-nvenc              # disable Nvidia video encoding code [autodetect]
build_nvenc() {
  if ! truthy "$disable_nvenc" && truthy "$enable_nvenc" || [[ -n "$1" ]]; then
  echo "WARNING: This is a non-gpl library. Binaries including this library are non-redistributable!" >>"$LOG_FILE"
  local lib="nvenc"
  local repo="https://github.com/FFmpeg/nv-codec-headers"
  local repo_ver="n13.0.19.0"
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
	generic_make_install
	change_dir "$src_dir"
	fi
}
# build_ffnvcodec         # config_options+= --disable-ffnvcodec          # disable dynamically linked Nvidia code [autodetect]
build_ffnvcodec() {
  if ! truthy "$disable_ffnvcodec" && truthy "$enable_ffnvcodec" || [[ -n "$1" ]]; then
	echo "WARNING: This is a non-gpl library." >>"$LOG_FILE"
	run_valid_function "build_nvenc" 1
  fi
}
# build_nvdec             # config_options+= --disable-nvdec              # disable Nvidia video decoding acceleration (via hwaccel) [autodetect]
build_nvdec() {
  if ! truthy "$disable_nvdec" && truthy "$enable_nvdec" || [[ -n "$1" ]]; then
  echo "WARNING: This is a non-gpl library." >>"$LOG_FILE"
	run_valid_function "build_nvenc" 1
  fi
}
# build_cuvid             # config_options+= --disable-cuvid              # disable Nvidia CUVID support [autodetect]
build_cuvid() {
  if ! truthy "$disable_cuvid" && truthy "$enable_cuvid" || [[ -n "$1" ]]; then
  echo "WARNING: This is a non-gpl library." >>"$LOG_FILE"
	run_valid_function "build_nvenc" 1
  fi
}
# build_libzimg           # config_options+= --enable-libzimg             # enable z.lib, needed for zscale filter [no]
build_libzimg() {
  if ! truthy "$disable_libzimg" && truthy "$enable_libzimg" || [[ -n "$1" ]]; then
	local lib="libzimg"
  local repo="https://github.com/sekrit-twc/zimg"
  local repo_ver="release-3.0.6"
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  generic_configure "--enable-static \
--disable-shared \
--with-pic"
  disable_nonessential "$src_dir/$lib"
  do_make_and_make_install
  reset_cflags
  reset_cxxflags
	change_dir "$src_dir"
	fi
}
# build_libopenjpeg       # config_options+= --enable-libopenjpeg         # enable JPEG 2000 encoding via OpenJPEG [no]
build_libopenjpeg() {
  if ! truthy "$disable_libopenjpeg" && truthy "$enable_libopenjpeg"; then
	local lib="libopenjpeg"
  local repo="https://github.com/uclouvain/openjpeg"
  local repo_ver="v2.5.4"
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  generic_cmake "-DCMAKE_CROSSCOMPILING=1 -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DOPJ_BIG_ENDIAN=0 -DBUILD_CODEC=0" "$src_dir/$lib"
	disable_nonessential "$src_dir/$lib"
  do_make_and_make_install
	change_dir "$src_dir"
	fi
}
# build_opengl            # config_options+= --enable-opengl              # enable OpenGL rendering [no]
build_opengl() {
  if ! truthy "$disable_opengl" && truthy "$enable_opengl" || [[ -n "$1" ]]; then
	run_valid_function "build_glew"
	run_valid_function "build_glfw"
  local lib="opengl"
  fi
}

build_glew() {
  if ! truthy "$disable_opengl" && truthy "$enable_opengl" || [[ -n "$1" ]]; then
	local lib="glew"
  local repo="https://sourceforge.net/projects/glew/files/glew/2.1.0/glew-2.1.0.tgz/download"
  local repo_ver="glew-2.2.0"
	change_dir "$src_dir"
  download_and_unpack_file "$repo" "$lib"
  change_dir "$src_dir/$lib/build" 1
  sed -i -e '/glew.rc)/d' \
    -e '/glewinfo.rc)/d' \
    -e '/visualinfo.rc)/d' \
    "$src_dir/$lib/build/cmake/CMakeLists.txt"
	local cmake_params="-DCMAKE_BUILD_TYPE=Release \
-DBUILD_UTILS=OFF \
-DGLEW_USE_STATIC_LIBS=ON \
-DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=BOTH \
-DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=BOTH \
-DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=BOTH \
-DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
-DWIN32=1"
	do_cmake_from_build_dir "$src_dir/$lib/build/cmake" "$cmake_params"
  disable_nonessential "$src_dir/$lib/build/cmake"
	do_make_and_make_install
	change_dir "$src_dir"
  add_libs_to_pkg -t="$install_pkgconfig_dir/glew.pc" -l="-lopengl32 -lglu32"
  sed -i '/^Requires:/s/\bglu\b//g' "$install_pkgconfig_dir/glew.pc"
	fi
}

build_glfw() {
  if ! truthy "$disable_opengl" && truthy "$enable_opengl"; then
	local lib="glfw"
  local repo="https://github.com/glfw/glfw"
  local repo_ver="3.4"
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
	change_dir "$src_dir/$lib"
	generic_cmake "-DBUILD_SHARED_LIBS=OFF \
-DGLFW_LIBRARY_TYPE=STATIC \
-DGLFW_BUILD_EXAMPLES=OFF \
-DGLFW_BUILD_TESTS=OFF \
-DGLFW_BUILD_DOCS=OFF \
-DGLFW_BUILD_X11=ON \
-DGLFW_BUILD_WIN32=OFF \
-DGLFW_BUILD_COCOA=OFF \
-DGLFW_BUILD_WAYLAND=OFF \
-DGLFW_BUILD_X11=OFF \
-DGLFW_BUILD_WIN32=ON"
  disable_nonessential "$src_dir/$lib"
  do_make_and_make_install
	change_dir "$src_dir"
	fi
}

build_libpng() {
	run_valid_function "build_zlib" 1
	local lib="libpng"
  local repo_ver="v1.6.53"
  local repo="https://github.com/glennrp/libpng"
  export CPATH="$CPATH -I${dependency_install_prefix}/include ${dependency_install_prefix}/include"
  export LIBS="-lz"
  change_dir "$src_dir"
	do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  generic_configure
  disable_nonessential "$src_dir/$lib"
  do_make_and_make_install
  unset CPATH LIBS
	change_dir "$src_dir"
}
# build_libwebp           # config_options+= --enable-libwebp             # enable WebP encoding via libwebp [no]
build_libwebp() {
  if ! truthy "$disable_libwebp" && truthy "$enable_libwebp" || [[ -n "$1" ]]; then
	run_valid_function "build_libpng"
  local lib="libwebp"
  local repo="https://chromium.googlesource.com/webm/libwebp"
  local repo_ver="v1.6.0"
	change_dir "$src_dir"
	do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
	change_dir "$src_dir/$lib"
	export LIBPNG_CONFIG="$dependency_install_prefix/bin/libpng-config --static" # LibPNG somehow doesn't get autodetected.
	generic_configure "--disable-wic --enable-static --disable-shared"
  disable_nonessential "$src_dir/$lib"
	do_make_and_make_install
	unset LIBPNG_CONFIG
	change_dir "$src_dir"
	fi
}
# build_libxml2           # config_options+= --enable-libxml2             # enable XML parsing using the C library libxml2, needed for dash and imf demuxing support [no]
build_libxml2() {
  if ! truthy "$disable_libxml2" && truthy "$enable_libxml2" || [[ -n "$1" ]]; then
	run_valid_function "build_iconv" 1
  local lib="libxml2"
  local repo="https://gitlab.gnome.org/GNOME/libxml2"
  local repo_ver="v2.10.1"
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
	generic_configure "--with-ftp=no --with-http=no --with-python=no --with-iconv=$dependency_install_prefix"
	do_make_and_make_install
	change_dir "$src_dir"
	fi
}

build_brotli() {
	local lib="brotli"
  local repo="https://github.com/google/brotli"
  local repo_ver="v1.2.0"
	change_dir "$src_dir"
	do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
	change_dir "$src_dir/$lib"
	generic_cmake "-DCMAKE_INSTALL_PREFIX=$dependency_install_prefix \
-DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF \
-DCMAKE_POSITION_INDEPENDENT_CODE=ON" "$src_dir/$lib"
  disable_nonessential "$src_dir/$lib"
	do_make_and_make_install
  
  add_libs_to_pkg -t="$install_pkgconfig_dir/libbrotlicommon.pc" -l="-lbrotlicommon"
  add_libs_to_pkg -t="$install_pkgconfig_dir/libbrotlidec.pc" -l="-lbrotlidec -lbrotlicommon"
  add_libs_to_pkg -t="$install_pkgconfig_dir/libbrotlienc.pc" -l="-lbrotlienc -lbrotlicommon"
  
	change_dir "$src_dir"
  reset_cflags
  reset_cxxflags
}
# build_libfreetype       # config_options+= --enable-libfreetype         # enable libfreetype, needed for drawtext filter [no]
build_libfreetype() {
  if ! truthy "$disable_libfreetype" && truthy "$enable_libfreetype" || [[ -n "$1" ]]; then
	run_valid_function "build_brotli" 1
  run_valid_function "build_libpng"
  activate_meson
	local lib="freetype"
  local repo="https://github.com/freetype/freetype"
  local repo_ver="VER-2-14-1"
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  sed -i "s|winmod.compile_resources('src/base/ftver.rc').*||g" meson.build
	local meson_options="-Dtests=disabled \
-Dbzip2=disabled \
--wrap-mode=nodownload \
-Dzlib=enabled"
	generic_meson "$meson_options"
  sed -i "s|winmod.compile_resources('src/base/ftver.rc').*||g" meson.build
  disable_nonessential "$src_dir/$lib"
	do_ninja_and_ninja_install
	change_dir "$src_dir"
	fi
}
build_graphite() {
  local lib="graphite"
  local repo="https://github.com/silnrsi/graphite"
  local repo_ver="1.3.14"
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  sed -i "s/add_subdirectory(tests)/#add_subdirectory(tests)/g" CMakeLists.txt
  sed -i "s/add_subdirectory(doc)/#add_subdirectory(doc)/g" CMakeLists.txt
  sed -i "s/add_subdirectory(gr2fonttest)/#add_subdirectory(gr2fonttest)/g" CMakeLists.txt
	generic_cmake "-DCMAKE_BUILD_TYPE=Release \
-DBUILD_SHARED_LIBS=OFF \
-DCMAKE_POLICY_VERSION_MINIMUM=3.5" "$src_dir/$lib"
  disable_nonessential "$src_dir/$lib"
  do_make_and_make_install
	change_dir "$src_dir"
}
# build_libharfbuzz       # config_options+= --enable-libharfbuzz         # enable libharfbuzz, needed for drawtext filter [no]
build_libharfbuzz() {
  if ! truthy "$disable_libharfbuzz" && truthy "$enable_libharfbuzz" || [[ -n "$1" ]]; then
	run_valid_function "build_graphite"
	run_valid_function "build_glib"
	run_valid_function "build_cairo"
  activate_meson
	local lib="harfbuzz"
  local repo_ver="10.4.0"
  local repo="https://github.com/harfbuzz/harfbuzz"
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver" # 11.0.0 no longer found by ffmpeg via this method, multiple issues, breaks harfbuzz freetype circular depends hack
  change_dir "$src_dir/$lib"
  export CFLAGS="$CFLAGS -DGRAPHITE2_STATIC -DGLIB_2.0_STATIC -DCAIRO_WIN32_STATIC_BUILD "
  export CXXFLAGS="$CXXFLAGS -DGRAPHITE2_STATIC -DGLIB_2.0_STATIC -DCAIRO_WIN32_STATIC_BUILD "
  local meson_options="-Dglib=disabled \
-Dgobject=enabled \
-Dcairo=enabled \
-Dicu=disabled \
-Dtests=disabled \
-Dintrospection=disabled \
-Ddocs=disabled \
-Dgraphite=enabled \
-Dgraphite2=enabled"
  export LDFLAGS="$LDFLAGS -lbrotlidec"
  generic_meson "$meson_options"
  disable_nonessential "$src_dir/$lib"
  do_ninja_and_ninja_install
	change_dir "$src_dir"
  add_libs_to_pkg -t="$install_pkgconfig_dir/harfbuzz-cairo.pc" -l="-lstdc++" -p="-lole32 -lwindowscodecs -luuid"
  reset_ldflags
  reset_cflags
  reset_cxxflags
	fi
}
# build_libvmaf           # config_options+= --enable-libvmaf             # enable vmaf filter via libvmaf [no]
build_libvmaf() {
  if ! truthy "$disable_libvmaf" && truthy "$enable_libvmaf"; then
  activate_meson
	local lib="libvmaf"
  local repo="https://github.com/Netflix/vmaf"
  local repo_ver="v3.0.0"
	change_dir "$src_dir"
	do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  change_dir "$src_dir/$lib/libvmaf"
	local meson_options="-Denable_float=true -Dbuilt_in_models=true -Denable_tests=false -Denable_docs=false"
	generic_meson "$meson_options"
  disable_nonessential "$src_dir/$lib"
	do_ninja_and_ninja_install
  add_libs_to_pkg -t="$install_pkgconfig_dir/libvmaf.pc" -l="-lstdc++"
	change_dir "$src_dir"
	fi
}
# build_libfontconfig     # config_options+= --enable-libfontconfig       # enable libfontconfig, useful for drawtext filter [no]
build_libfontconfig() {
  if ! truthy "$disable_libfontconfig" && truthy "$enable_libfontconfig" || [[ -n "$1" ]]; then
	run_valid_function "build_libfreetype"
	run_valid_function "build_libxml2" 1
	activate_meson
	local lib="fontconfig"
  local repo_ver="2.17.1"
  local repo="https://gitlab.freedesktop.org/fontconfig/fontconfig"
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  export LIBS="-lz -llzma -lbrotlidec -lbrotlicommon -lfreetype -lz -lpng"
  export LDFLAGS="$LDFLAGS -lbrotlidec"
  local meson_options="-Dtools=disabled \
-Ddoc=disabled \
-Diconv=enabled \
-Dtests=disabled \
-Dxml-backend=libxml2 \
--wrap-mode=nodownload \
-Dc_link_args=\"-L$dependency_install_prefix/lib $LIBS\""
	generic_meson "$meson_options"
  disable_nonessential "$src_dir/$lib"
	do_ninja_and_ninja_install
	change_dir "$src_dir"
  unset LIBS
  reset_ldflags
	fi
}
# build_gmp               # config_options+= --enable-gmp                 # enable gmp, needed for rtmp(t)e support if openssl or librtmp is not used [no]
build_gmp() {
  if ! truthy "$disable_gmp" && truthy "$enable_gmp"; then
	local lib="gmp"
  local repo="https://ftp.gnu.org/pub/gnu/gmp/gmp-6.3.0.tar.xz"
	change_dir "$src_dir"
  download_and_unpack_file "$repo" "$lib"
  change_dir "$src_dir/$lib"
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
	local lib="nettle"
  local repo="https://ftp.gnu.org/gnu/nettle/nettle-3.10.2.tar.gz"
	change_dir "$src_dir"
	download_and_unpack_file "$repo" "$lib"
	change_dir "$src_dir/$lib"
	local config_options="--disable-openssl --disable-documentation"
	generic_configure "$config_options"
	disable_nonessential "$src_dir/$lib"
  do_make_and_make_install
	change_dir "$src_dir"
}

build_libunistring() {
  local lib="libunistring"
  local repo="https://ftp.gnu.org/gnu/libunistring/libunistring-1.4.1.tar.gz"
	change_dir "$src_dir"
	download_and_unpack_file "$repo" "$lib"
  change_dir "$src_dir/$lib"
  generic_configure
  sed -i -E 's/=[[:space:]]*libunistring\.res\.lo/=/g' "lib/Makefile"
  disable_nonessential "$src_dir/$lib"
  do_make_and_make_install
	change_dir "$src_dir"
}

build_libidn2() {
	run_valid_function "build_libunistring"
  local repo="https://ftp.gnu.org/gnu/libidn/libidn2-2.3.8.tar.gz"
  local lib="libidn2"
  local repo_ver="2.3.8"
	change_dir "$src_dir"
	download_and_unpack_file "$repo" "$lib"
	change_dir "$src_dir/$lib"
  touch "no.autoreconf"
  export LDFLAGS="$LDFLAGS -liconv"
  export CPPFLAGS="$CPPFLAGS -DLIBICONV_STATIC "
	generic_configure "--enable-static \
--disable-shared \
--disable-doc \
--disable-rpath \
--disable-nls \
--disable-gtk-doc-html \
--disable-fast-install \
--with-libiconv-prefix=\"$dependency_install_prefix\" \
--with-libunistring-prefix=\"$dependency_install_prefix\" \
LIBS=\"-lcharset -lunistring -liconv\""
  disable_nonessential "$src_dir/$lib"
	do_make_and_make_install
	change_dir "$src_dir"
  add_libs_to_pkg -t="$install_pkgconfig_dir/libidn2.pc" -l="-liconv"
  reset_cflags
  reset_cppflags
}

build_zstd() {
  activate_meson
	local lib="zstd"
  local repo="https://github.com/facebook/zstd"
  local repo_ver="v1.5.7"
	change_dir "$src_dir"
	do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
	change_dir "$src_dir/$lib/build/meson"
  local meson_options="-Dbin_programs=false \
-Dbin_tests=false \
-Dbin_contrib=false \
-Ddebug_level=0 \
-Dlegacy_level=7"
  generic_meson "$meson_options"
  disable_nonessential "$src_dir/$lib" "programs"
  do_ninja_and_ninja_install
	change_dir "$src_dir"
}
# build_gnutls            # config_options+= --enable-gnutls              # enable gnutls, needed for https support if openssl, libtls or mbedtls is not used [no]
build_gnutls() {
  if ! truthy "$disable_gnutls" && truthy "$enable_gnutls" || [[ -n "$1" ]]; then
	run_valid_function "build_brotli" 1
	run_valid_function "build_libnettle"
	local lib="gnutls"
  local repo="https://www.gnupg.org/ftp/gcrypt/gnutls/v3.8/gnutls-3.8.9.tar.xz"
	change_dir "$src_dir"
  download_and_unpack_file "$repo" "$lib" # v3.8.10 not found by ffmpeg with identical .pc?
  change_dir "$src_dir/$lib"
	export CFLAGS="-Wno-int-conversion"
	generic_configure "--disable-cxx \
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
--disable-gtk-doc-html \
--with-brotli \
--disable-non-suiteb-curves"
  disable_nonessential "$src_dir/$lib"
	do_make_and_make_install
	reset_cflags
  add_libs_to_pkg -t="$install_pkgconfig_dir/gnutls.pc" -l="-lcrypt32 -lnettle -lhogweed -lgmp -liconv -lunistring"
	change_dir "$src_dir"
	fi
}

build_curl() {
	run_valid_function "build_libidn2"
	run_valid_function "build_zstd"
	run_valid_function "build_brotli"
	run_valid_function "build_libpsl"
	run_valid_function "build_nghttp2"
	run_valid_function "build_openssl" 1
	local lib="curl"
  local repo="https://github.com/curl/curl"
  local repo_ver="curl-8_17_0"
	change_dir "$src_dir"
	do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  local cmake_options="-DBUILD_CURL_EXE=OFF \
-DCURL_USE_PKGCONFIG=ON \
-DBUILD_LIBCURL_DOCS=OFF \
-DBUILD_MISC_DOCS=OFF \
-DENABLE_CURL_MANUAL=OFF \
-DBUILD_TESTING=OFF \
-DBUILD_EXAMPLES=OFF"
  if ! truthy "$disable_libssh" && truthy "$enable_libssh"; then
	run_valid_function "build_libssh" 1
    cmake_options+=" -DCURL_USE_LIBSSH=ON "
    export LIBS="$LIBS -lssh -lssl -lcrypto"
    export CPPFLAGS="$CPPFLAGS -DLIBSSH_STATIC"
  fi
  if ! truthy "$disable_librtmp" && truthy "$enable_librtmp"; then
	run_valid_function "build_librtmp" 1
    cmake_options+=" -DUSE_LIBRTMP=ON "
    export LIBS="$LIBS -lrtmp -lssl -lcrypto"
  fi
  export CPPFLAGS="$CPPFLAGS -DNGHTTP2_STATICLIB -DPSL_STATIC "
  export CXXFLAGS="$CXXFLAGS -DNGHTTP2_STATICLIB -DPSL_STATIC "
  export LIBS=" $LIBS -lpsl -lidn2 -lunistring -liconv -lbrotlidec -lbrotlicommon -lws2_32 -lwinmm -lz -lcrypt32 -lbcrypt"
  change_dir "$src_dir/$lib/build" 1
  do_cmake_from_build_dir "$src_dir/$lib" "$cmake_options"
  do_make_and_make_install
  reset_allflags
  unset LIBS
	change_dir "$src_dir"
}

build_libogg() {
	local lib="libogg"
  local repo="https://github.com/xiph/ogg"
  local repo_ver="v1.3.6"
	change_dir "$src_dir"
	do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  change_dir "$src_dir/$lib/build" 1
	do_cmake_from_build_dir "$src_dir/$lib" 
  disable_nonessential "$src_dir/$lib/build"
  do_make_and_make_install
	change_dir "$src_dir"
}
# build_libvorbis         # config_options+= --enable-libvorbis           # enable Vorbis en/decoding via libvorbis, native implementation exists [no]
build_libvorbis() {
  if ! truthy "$disable_libvorbis" && truthy "$enable_libvorbis" || [[ -n "$1" ]]; then
	run_valid_function "build_libogg"
	local lib="libvorbis"
  local repo="https://github.com/xiph/vorbis"
  local repo_ver="v1.3.7"
	change_dir "$src_dir"
	do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
	change_dir "$src_dir/$lib"
	generic_configure "--disable-docs --disable-examples --disable-oggtest --enable-static --disable-shared"
	disable_nonessential "$src_dir/$lib"
  do_make_and_make_install
	change_dir "$src_dir"
	fi
}
# build_libopus           # config_options+= --enable-libopus             # enable Opus de/encoding via libopus [no]
build_libopus() {
  if ! truthy "$disable_libopus" && truthy "$enable_libopus"; then
	local lib="libopus"
  local repo="https://github.com/xiph/opus"
  local repo_ver="v1.5.2"
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
	generic_configure "--disable-doc --disable-extra-programs --disable-stack-protector --enable-static --disable-shared"
	disable_nonessential "$src_dir/$lib"
  do_make_and_make_install
	change_dir "$src_dir"
	fi
}
# build_libspeex          # config_options+= --enable-libspeex            # enable Speex de/encoding via libspeex [no]
build_libspeex() {
  if ! truthy "$disable_libspeex" && truthy "$enable_libspeex"; then
  local lib="libspeex"
  local repo="https://github.com/xiph/speex"
  local repo_ver="Speex-1.2.1" 
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
	change_dir "$src_dir/$lib"
  generic_configure "--disable-binaries --disable-examples"
	do_make_and_make_install
	change_dir "$src_dir"
  fi
}

build_libspeexdsp() {
  if ! truthy "$disable_libspeex" && truthy "$enable_libspeex"; then
	run_valid_function "build_libspeex"
	local lib="libspeexdsp"
  local repo="https://github.com/xiph/speexdsp"
  local repo_ver="SpeexDSP-1.2.1" 
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
	change_dir "$src_dir/$lib"
	export SPEEXDSP_CFLAGS="-I$dependency_install_prefix/include"
	export SPEEXDSP_LIBS="-L$dependency_install_prefix/lib -lspeexdsp"
	generic_configure "--disable-binaries --disable-examples"
  disable_nonessential "$src_dir/$lib"
	do_make_and_make_install
	unset SPEEXDSP_CFLAGS
	unset SPEEXDSP_LIBS
	change_dir "$src_dir"
	fi
}
# build_libtheora         # config_options+= --enable-libtheora           # enable Theora encoding via libtheora [no]
build_libtheora() {
  if ! truthy "$disable_libtheora" && truthy "$enable_libtheora"; then
	local lib="libtheora"
  local repo="https://github.com/xiph/theora"
  local repo_ver="v1.2.0"
	change_dir "$src_dir"
	do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
	change_dir "$src_dir/$lib"
  sed -i 's|AC_PREREQ(\[2.71\])|# AC_PREREQ([2.71])|g' "$src_dir/$lib/configure.ac"
	generic_configure "--enable-static \
--disable-shared \
--disable-doc \
--disable-spec \
--disable-oggtest \
--disable-vorbistest \
--disable-examples \
--disable-asm" # disable asm: avoid [theora @ 0x1043144a0]error in unpack_block_qpis in 64 bit... [OK OS X 64 bit tho...]
  do_make_and_make_install
	change_dir "$src_dir"
	fi
}
# build_libgsm            # config_options+= --enable-libgsm              # enable GSM de/encoding via libgsm [no]
build_libgsm() {
  if ! truthy "$disable_libgsm" && truthy "$enable_libgsm"; then
	run_valid_function "build_libsndfile"
  local lib="libsndfile"
  local repo="https://github.com/libsndfile/libsndfile"
  local repo_ver="1.2.2"
  change_dir "$src_dir/$lib"
  if [[ -f "src/GSM610/gsm.h" ]]; then
    copy_path "$src_dir/$lib/src/GSM610/gsm.h" "$dependency_install_prefix/include/gsm.h" "-fv" >>"$LOG_FILE" 2>&1
  fi
  if [[ -f "src/GSM610/.libs/libgsm.a" ]]; then 
    copy_path "$src_dir/$lib/src/GSM610/.libs/libgsm.a" "$dependency_install_prefix/lib/libgsm.a" "-fv" >>"$LOG_FILE" 2>&1
  fi
	change_dir "$src_dir"
  fi
}
build_libsndfile() {
	local lib="libsndfile"
  local repo="https://github.com/libsndfile/libsndfile"
  local repo_ver="1.2.2"
	change_dir "$src_dir"
	do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
	change_dir "$src_dir/$lib"
	generic_configure "--disable-sqlite --disable-external-libs --disable-full-suite"
  sed -i -E 's|=[[:space:]]*src/version-metadata\.lo|=|g' "Makefile"
	disable_nonessential "$src_dir/$lib"
  do_make_and_make_install
	change_dir "$src_dir"
}

build_mpg123() {
	local lib="mpg123"
  local repo="https://sourceforge.net/projects/mpg123/files/mpg123/1.33.3/mpg123-1.33.3.tar.bz2/download"
  local repo_ver="r5008"
	change_dir "$src_dir"
	download_and_unpack_file "$repo" "$lib"
  change_dir "$src_dir/$lib"
  generic_configure
  disable_nonessential "$src_dir/$lib"
  do_make_and_make_install
	change_dir "$src_dir"
}
# build_libmp3lame        # config_options+= --enable-libmp3lame          # enable MP3 encoding via libmp3lame [no]
build_libmp3lame() {
  if ! truthy "$disable_libmp3lame" && truthy "$enable_libmp3lame"; then
	run_valid_function "build_mpg123"
	local lib="libmp3lame"
  local repo="https://sourceforge.net/projects/lame/files/lame/3.100/lame-3.100.tar.gz/download"
  local repo_ver="r6525"
	change_dir "$src_dir"
  download_and_unpack_file "$repo" "$lib" 
  change_dir "$src_dir/$lib"
  generic_configure "--enable-nasm --disable-frontend"
  disable_nonessential "$src_dir/$lib"
  do_make_and_make_install
  cat > "$install_pkgconfig_dir/libmp3lame.pc" <<EOF
prefix=${dependency_install_prefix}
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: libmp3lame
Description: High quality MPEG Audio Layer III (MP3) encoder
Version: 3.100
Libs: -L\${libdir} -lmp3lame
Libs.private: -lm
Cflags: -I\${includedir}
EOF
	change_dir "$src_dir"
	fi
}
# build_libtwolame        # config_options+= --enable-libtwolame          # enable MP2 encoding via libtwolame [no]
build_libtwolame() {
  if ! truthy "$disable_libtwolame" && truthy "$enable_libtwolame"; then
	local lib="libtwolame"
  local repo="https://github.com/njh/twolame"
  local repo_ver="0.4.0"
	change_dir "$src_dir"
	do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
	change_dir "$src_dir/$lib"
	if [[ ! -f Makefile.am.bak ]]; then # Library only, front end refuses to build for some reason with git master
		sed -i.bak "/^SUBDIRS/s/ frontend.*//" Makefile.am || exit_message 1 "build_libtwolame: could not update makefile for twolame"
	fi
	generic_configure "--enable-static --disable-shared"
	disable_nonessential "$src_dir/$lib"
  do_make_and_make_install
	change_dir "$src_dir"
	fi
}
build_sdl12_compat() {
	run_valid_function "build_sdl2" 1
  local repo="https://github.com/libsdl-org/sdl12-compat"
  local lib="sdl12-compat"
  local repo_ver="release-1.2.72"
	change_dir "$src_dir"
	do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  sed -i 's/set(WIN32_SRCS "src\/version.rc")/set(WIN32_SRCS "")/' CMakeLists.txt
  generic_cmake "-DCMAKE_BUILD_TYPE=Release \
-DSDL12TESTS=OFF \
-DCMAKE_RC_COMPILER=/bin/false \
-DSDL12COMPAT_INSTALL_RES=OFF" "$src_dir/$lib"
  disable_nonessential "$src_dir/$lib"
  do_make_and_make_install
	change_dir "$src_dir"
}
# build_libopenmpt        # config_options+= --enable-libopenmpt          # enable decoding tracked files via libopenmpt [no]
build_libopenmpt() {
  if ! truthy "$disable_libopenmpt" && truthy "$enable_libopenmpt"; then
	run_valid_function "build_flac"
	run_valid_function "build_zlib" 1
	run_valid_function "build_mpg123"
	run_valid_function "build_libogg"
	run_valid_function "build_libvorbis" 1
	run_valid_function "build_sdl2" 1
	run_valid_function "build_sdl12_compat"
	run_valid_function "build_libsndfile"
	local lib="libopenmpt"
  #local repo="https://github.com/OpenMPT/openmpt" # doesnt work from git for some reason
  local repo="https://lib.openmpt.org/files/libopenmpt/src/libopenmpt-0.8.3+release.autotools.tar.gz"
  local repo_ver="libopenmpt-0.8.3"
	change_dir "$src_dir"
  download_and_unpack_file "$repo" "$lib"
  #do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  touch "no.autoreconf"
  generic_configure "--enable-shared=no \
--enable-static=yes \
--without-pulseaudio \
--without-portaudiocpp \
--with-sdl2 \
--disable-openmpt123 \
--disable-examples \
--disable-tests \
--disable-doxygen-doc"
  disable_nonessential "$src_dir/$lib"
	do_make_and_make_install "PREFIX=$dependency_install_prefix \
CONFIG=mingw64-win64 \
EXESUFFIX=.exe \
SOSUFFIX=.dll \
SOSUFFIXWINDOWS=1 \
DYNLINK=0 \
SHARED_LIB=0 \
STATIC_LIB=1 \
SHARED_SONAME=0 \
IS_CROSS=1 \
NO_ZLIB=0 \
NO_LTDL=0 \
NO_DL=0 \
NO_MPG123=0 \
NO_OGG=0 \
NO_VORBIS=0 \
NO_VORBISFILE=0 \
NO_PORTAUDIO=1 \
NO_PORTAUDIOCPP=1 \
NO_PULSEAUDIO=1 \
NO_SDL=0 \
NO_SDL2=0 \
NO_SNDFILE=0 \
NO_FLAC=0 \
EXAMPLES=0 \
OPENMPT123=0 \
TEST=0" # OPENMPT123=1 >>> fail
  add_libs_to_pkg -t="$install_pkgconfig_dir/libopenmpt.pc" -p="-lrpcrt4"
	change_dir "$src_dir"
	fi
}
# build_libopencore_amrnb # config_options+= --enable-libopencore-amrnb   # enable AMR-NB de/encoding via libopencore-amrnb [no]
build_libopencore_amrnb() {
  if ! truthy "$disable_libopencore_amrnb" && truthy "$enable_libopencore_amrnb" || [[ -n "$1" ]]; then
	local lib="libopencore_amrnb"
  local repo="https://sourceforge.net/projects/opencore-amr/files/opencore-amr/opencore-amr-0.1.6.tar.gz"
	change_dir "$src_dir"
  download_and_unpack_file "$repo" "$lib"
  change_dir "$src_dir/$lib"
  generic_configure "--enable-static --disable-shared"
  disable_nonessential "$src_dir/$lib"
  do_make_and_make_install
	change_dir "$src_dir"
	fi
}
# build_libopencore_amrwb # config_options+= --enable-libopencore-amrwb   # enable AMR-WB decoding via libopencore-amrwb [no]
build_libopencore_amrwb() {
  if ! truthy "$disable_libopencore_amrwb" && truthy "$enable_libopencore_amrwb" || [[ -n "$1" ]]; then
	run_valid_function "build_libopencore_amrnb" 1
  fi
}

# build_libilbc           # config_options+= --enable-libilbc             # enable iLBC de/encoding via libilbc [no]
build_libilbc() {
  if ! truthy "$disable_libilbc" && truthy "$enable_libilbc"; then
	local lib="libilbc"
  local repo="https://github.com/TimothyGu/libilbc"
  local repo_ver="v3.0.4"
  change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
	generic_cmake "-DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DENABLE_UBSAN=0" "$src_dir/$lib"
	disable_nonessential "$src_dir/$lib"
  do_make_and_make_install
	change_dir "$src_dir"
	fi
}
# build_libmodplug        # config_options+= --enable-libmodplug          # enable ModPlug via libmodplug [no]
build_libmodplug() {
  if ! truthy "$disable_libmodplug" && truthy "$enable_libmodplug"; then
	local lib="libmodplug"
  local repo="https://github.com/Konstanty/libmodplug"
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib"
  change_dir "$src_dir/$lib"
  sed -i.bak 's/__declspec(dllexport)//' "$src_dir/$lib/src/modplug.h" #strip DLL import/export directives
	sed -i.bak 's/__declspec(dllimport)//' "$src_dir/$lib/src/modplug.h"
  autoreconf_library
  automake --add-missing > >(redirect_output) 2>&1
	generic_configure
  disable_nonessential "$src_dir/$lib"
  do_make_and_make_install
	change_dir "$src_dir"
	fi
}
# build_libgme            # config_options+= --enable-libgme              # enable Game Music Emu via libgme [no]
build_libgme() {
  if ! truthy "$disable_libgme" && truthy "$enable_libgme"; then
	# do_git_checkout https://bitbucket.org/mpyne/game-music-emu
	local lib="libgme"
  local repo="https://bitbucket.org/mpyne/game-music-emu/downloads/game-music-emu-0.6.3.tar.xz"
  change_dir "$src_dir"
  download_and_unpack_file "$repo" "$lib"
  change_dir "$src_dir/$lib"
	generic_cmake "-DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DENABLE_UBSAN=0 -DCMAKE_POLICY_VERSION_MINIMUM=3.5" "$src_dir/$lib"
  disable_nonessential "$src_dir/$lib"
  do_make_and_make_install
	change_dir "$src_dir"
	fi
}
# build_libbluray         # config_options+= --enable-libbluray           # enable BluRay reading using libbluray [no]
build_libbluray() {
  if ! truthy "$disable_libbluray" && truthy "$enable_libbluray"; then
	local lib="libbluray"
  local repo="https://code.videolan.org/videolan/libbluray"
  local repo_ver="1.4.0"
  activate_meson
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
	wget "https://raw.githubusercontent.com/m-ab-s/mabs-patches/master/libbluray/0001-dec-prefix-with-libbluray-for-now.patch" > >(redirect_output) 2>&1
	apply_patch "0001-dec-prefix-with-libbluray-for-now.patch"
  export LIBS="-lfontconfig -lfreetype -lz -llzma"
  local meson_options="-Denable_examples=false \
-Dbdj_jar=disabled \
-Denable_tools=false \
-Denable_docs=false \
--wrap-mode=default \
-Dlibxml2=enabled \
-Dc_link_args=\"-L${dependency_install_prefix}/lib $LIBS\""
	generic_meson "$meson_options"
	disable_nonessential "$src_dir/$lib"
  do_ninja_and_ninja_install
  add_libs_to_pkg -t="$install_pkgconfig_dir/libbluray.pc" -p="-lstdc++ -lssp -lgdi32"
	change_dir "$src_dir"
  unset LIBS
  reset_ldflags
	fi
}
# build_libbs2b           # config_options+= --enable-libbs2b             # enable bs2b DSP library [no]
build_libbs2b() {
  if ! truthy "$disable_libbs2b" && truthy "$enable_libbs2b"; then
	run_valid_function "build_libsndfile"
	local lib="libbs2b"
  local repo="https://downloads.sourceforge.net/project/bs2b/libbs2b/3.1.0/libbs2b-3.1.0.tar.gz"
  local repo_ver="3.1.0"
	change_dir "$src_dir"
  download_and_unpack_file "$repo" "$lib"
  change_dir "$src_dir/$lib"
  touch "no.autoreconf"
  # apply_patch "$PATCHDIR/libbs2b.patch" # not needed anymore?
	sed -i.bak "s/AC_FUNC_MALLOC//" configure.ac # #270
	generic_configure "--enable-static --disable-shared"
	disable_nonessential "$src_dir/$lib"
  do_make_and_make_install
	change_dir "$src_dir"
	fi
}
# build_libsoxr           # config_options+= --enable-libsoxr             # enable Include libsoxr resampling [no]
build_libsoxr() {
  if ! truthy "$disable_libsoxr" && truthy "$enable_libsoxr"; then
	local lib="libsoxr"
  local repo="https://github.com/chirlu/soxr"
  local repo_ver="0.1.3" 
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
	sed -i 's/elseif (NOT WIN32)/elseif (WIN32)/g' "$src_dir/$lib/src/CMakeLists.txt"
  change_dir "$src_dir/$lib/build" 1
	do_cmake_from_build_dir "$src_dir/$lib" "-DCMAKE_BUILD_TYPE=Release \
-DBUILD_SHARED_LIBS=OFF \
-DWITH_OPENMP=0 \
-DBUILD_TESTS=0 \
-DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
-DBUILD_EXAMPLES=0"
  disable_nonessential "$src_dir/$lib"
  do_make_and_make_install
	change_dir "$src_dir"
  add_libs_to_pkg -t="$install_pkgconfig_dir/soxr-lsr.pc" -l="-lsoxr -lsoxr-lsr"
	fi
}

# build_libflite          # config_options+= --enable-libflite            # enable flite (voice synthesis) support via libflite [no]
build_libflite() {
  if ! truthy "$disable_libflite" && truthy "$enable_libflite"; then
	local lib="flite"
  local repo="https://github.com/festvox/flite"
  local repo_ver="v2.2"
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  # apply_patch "$PATCHDIR/flite-2.1.0_mingw-w64-fixes.patch"
  if grep -Fq -e "cp -pd" Makefile; then
		sed -i.bak "s/cp -pd/cp -p/" main/Makefile # friendlier cp for OS X
	fi
  export CFLAGS="$CFLAGS -Dc99_snprintf=snprintf"
  export LDFLAGS="$LDFLAGS -lpthread"
	generic_configure "--bindir=$dependency_install_prefix/bin \
--with-audio=none \
--disable-shared \
--with-lang=usenglish \
--with-vox=cmu_us_kal \
--with-pic"
	disable_nonessential "$src_dir/$lib" "main"
  if [ -f "config/default.lv" ]; then
      sed -i 's/cmu_indic_lang//g' config/default.lv
      sed -i 's/cmu_indic_lex//g' config/default.lv
      sed -i 's/cmu_grapheme_lang//g' config/default.lv
      sed -i 's/cmu_grapheme_lex//g' config/default.lv
  fi
  do_make_and_make_install
	change_dir "$src_dir"
	if find "$src_dir/$lib/build/x86_64-mingw32/lib" -type f -name "libflite*.a" >/dev/null; then
		cp -rfv "$src_dir/$lib/build/x86_64-mingw32/lib/libflite"* "$dependency_install_prefix/lib/" >>"$LOG_FILE"
		cp -rfv "$src_dir/$lib/include" "$dependency_install_prefix/include/flite" >>"$LOG_FILE"
		# cp -rf ./bin/*.exe $dependency_install_prefix/bin # if want .exe's uncomment
	fi
	change_dir "$src_dir"
  reset_ldflags
	fi
}
# build_libsnappy         # config_options+= --enable-libsnappy           # enable Snappy compression, needed for hap encoding [no]
build_libsnappy() {
  if ! truthy "$disable_libsnappy" && truthy "$enable_libsnappy"; then
	local lib="libsnappy"
  local repo="https://github.com/google/snappy"
  local repo_ver="1.2.2" 
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
	change_dir "$src_dir/$lib"
	do_cmake_and_install "-DBUILD_BINARY=OFF \
-DBUILD_SHARED_LIBS=OFF \
-DCMAKE_BUILD_TYPE=Release \
-DSNAPPY_BUILD_TESTS=OFF \
-DSNAPPY_BUILD_BENCHMARKS=OFF" # extra params from deadsix27 and from new cMakeLists.txt content
	disable_nonessential "$src_dir/$lib"
  do_make_and_make_install
  remove_path -f "$dependency_install_prefix/lib/libsnappy.dll.a" # unintall shared :|
	change_dir "$src_dir"
  while IFS= read -r -d '' file; do
    add_libs_to_pkg -t="$file" -l="-lshlwapi"
  done < <(find "$install_pkgconfig_dir" -name "benchmark*.pc" -print0)
  if [[ -f "$install_pkgconfig_dir/libhwy-test.pc" ]]; then
    remove_path -f "$install_pkgconfig_dir/libhwy-test.pc"
  fi
	fi
}

build_vamp_plugin() {
	#download_and_unpack_file https://code.soundsoftware.ac.uk/attachments/download/2691/vamp-plugin-sdk-2.10.0.tar.gz
	change_dir "$src_dir"
	download_and_unpack_file https://github.com/vamp-plugins/vamp-plugin-sdk/archive/refs/tags/vamp-plugin-sdk-v2.10.zip vamp-plugin-sdk-vamp-plugin-sdk-v2.10
	#cd vamp-plugin-sdk-2.10.0
	change_dir "$src_dir/vamp-plugin-sdk-vamp-plugin-sdk-v2.10"
	apply_patch "$PATCHDIR/vamp-plugin-sdk-2.10_static-lib.diff"
	if [[ ! -f src/vamp-sdk/PluginAdapter.cpp.bak ]]; then
		sed -i.bak "s/#include <mutex>/#include <mingw.mutex.h>/" src/vamp-sdk/PluginAdapter.cpp
	fi
	if [[ ! -f configure.bak ]]; then # Fix for "'M_PI' was not declared in this scope" (see https://stackoverflow.com/a/29264536).
		sed -i.bak "s/c++11/gnu++11/" configure
		sed -i.bak "s/c++11/gnu++11/" Makefile.in
	fi
	generic_configure "--host=$host_target --prefix=$dependency_install_prefix --disable-programs"
	do_make "install-static" # No need for 'do_make_install', because 'install-static' already has install-instructions.
	change_dir "$src_dir"
}

build_fftw() {
	local lib="fftw"
  local repo="http://fftw.org/fftw-3.3.10.tar.gz"
	change_dir "$src_dir"
	download_and_unpack_file "$repo" "$lib"
	change_dir "$src_dir/$lib"
	generic_configure "--disable-doc --enable-static --disable-shared"
	disable_nonessential "$src_dir/$lib"
  do_make_and_make_install
	change_dir "$src_dir"
}
# build_chromaprint       # config_options+= --enable-chromaprint         # enable audio fingerprinting with chromaprint [no]
build_chromaprint() {
  if ! truthy "$disable_chromaprint" && truthy "$enable_chromaprint"; then
	run_valid_function "build_fftw"
	local lib="chromaprint"
  local repo="https://github.com/acoustid/chromaprint"
  local repo_ver="v1.6.0"
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
	generic_cmake "-DCMAKE_BUILD_TYPE=Release \
-DBUILD_SHARED_LIBS=OFF \
-DBUILD_TOOLS=OFF \
-DBUILD_TESTS=OFF \
-DFFT_LIB=fftw3" "$src_dir/$lib"
  disable_nonessential "$src_dir/$lib"
  do_make_and_make_install
	change_dir "$src_dir"
  add_libs_to_pkg -t="$install_pkgconfig_dir/libchromaprint.pc" -l="-lfftw3"
	fi
}

build_libsamplerate() {
  local lib="libsamplerate"
  local repo="https://github.com/erikd/libsamplerate"
  local repo_ver="0.2.2"
	# I think this didn't work with ubuntu 14.04 [too old automake or some odd] :|
	change_dir "$src_dir"
	do_git_checkout_and_make_install "$repo" "$src_dir/$lib" "$repo_ver"
	# but OS X can't use 0.1.9 :|
	# rubberband can use this, but uses speex bundled by default [any difference? who knows!]
	change_dir "$src_dir"
}
# build_librubberband     # config_options+= --enable-librubberband       # enable rubberband needed for rubberband filter [no]
build_librubberband() {
  if ! truthy "$disable_librubberband" && truthy "$enable_librubberband"; then
	run_valid_function "build_libsamplerate"
	local lib="librubberband"
  local repo="https://github.com/breakfastquay/rubberband"
  local repo_ver="v4.0.0"
  activate_meson
	change_dir "$src_dir"
	do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
	change_dir "$src_dir/$lib"
  local meson_options="-Dladspa=disabled -Dtests=disabled -Dcmdline=disabled -Djni=disabled -Dladspa=disabled"
	generic_meson "$meson_options"
  disable_nonessential "$src_dir/$lib"
	do_ninja_and_ninja_install
	change_dir "$src_dir"
	# apply_patch "$PATCHDIR/rubberband_git_static-lib.diff" # create install-static target
	# generic_configure "--disable-ladspa"
	# do_make "install-static AR=${cross_prefix}ar" # No need for 'do_make_install', because 'install-static' already has install-instructions.
	# sed -i.bak 's/-lrubberband.*$/-lrubberband -lfftw3 -lsamplerate -lstdc++/' "$install_pkgconfig_dir/rubberband.pc"
  # 	#	change_dir "$src_dir"
	fi
}
# build_frei0r            # config_options+= --enable-frei0r              # enable frei0r video filtering [no]
build_frei0r() {
  if ! truthy "$disable_frei0r" && truthy "$enable_frei0r"; then
	#do_git_checkout https://github.com/dyne/frei0r
	local lib="frei0r"
  local repo="https://github.com/dyne/frei0r"
  local repo_ver="v2.5.1"
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_dir"
  change_dir "$src_dir/$lib"
  sed -i.bak 's/-arch i386//' CMakeLists.txt # OS X https://github.com/dyne/frei0r/issues/64
  sed -i.bak 's/find_package (Cairo)/# find_package (Cairo)/' CMakeLists.txt # OS X https://github.com/dyne/frei0r/issues/64
  change_dir "$src_dir/$lib/build" 1	
  do_cmake_from_build_dir "$src_dir/$lib" "-DCMAKE_BUILD_TYPE=Release \
-DBUILD_SHARED_LIBS=OFF \
-DWITHOUT_OPENCV=ON \
-DWITHOUT_GAVL=ON"
  disable_nonessential "$src_dir/$lib/build"
  do_make_and_make_install
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
# build_libsvtav1         # config_options+= --enable-libsvtav1           # enable AV1 encoding via SVT [no]
build_libsvtav1() {
  if ! truthy "$disable_libsvtav1" && truthy "$enable_libsvtav1"; then
	if [[ "$bits_target" != "32" ]]; then
	run_valid_function "build_cpuinfo"
		local lib="libsvtav1"
    local repo="https://gitlab.com/AOMediaCodec/SVT-AV1"
    local repo_ver="v3.1.2"
	change_dir "$src_dir"
    do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
    change_dir "$src_dir/$lib"
		generic_cmake "-DCMAKE_BUILD_TYPE=Release \
-DBUILD_TESTING=OFF \
-DUSE_CPUINFO=SYSTEM" # -DSVT_AV1_LTO=OFF if fails try adding this
		disable_nonessential "$src_dir/$lib"
    do_make_and_make_install
	change_dir "$src_dir"
	fi
	fi
}
# build_libvidstab        # config_options+= --enable-libvidstab          # enable video stabilization using vid.stab [no]
build_libvidstab() {
  if ! truthy "$disable_libvidstab" && truthy "$enable_libvidstab"; then
	local lib="libvidstab"
  local repo="https://github.com/georgmartius/vid.stab"
  local repo_ver="v1.1.1"
	change_dir "$src_dir"
	do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
	generic_cmake "-DCMAKE_BUILD_TYPE=Release \
-DBUILD_SHARED_LIBS=OFF \
-DUSE_OMP=0 \
-DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
-DBUILD_SHARED_LIBS=0" "$src_dir/$lib" # '-DUSE_OMP' is on by default, but somehow libgomp ('cygwin_local_install/lib/gcc/i686-pc-cygwin/5.4.0/include/omp.h') can't be found, so '-DUSE_OMP=0' to prevent a compilation error.
  disable_nonessential "$src_dir/$lib"
  do_make_and_make_install
	change_dir "$src_dir"
	fi
}
# build_libmysofa         # config_options+= --enable-libmysofa           # enable libmysofa, needed for sofalizer filter [no]
build_libmysofa() {
  if ! truthy "$disable_libmysofa" && truthy "$enable_libmysofa"; then
	local lib="libmysofa"
  local repo="https://github.com/hoene/libmysofa"
  local repo_ver="latest"
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  change_dir "$src_dir/$lib/build" 1
	local cmake_params="-DBUILD_TESTS=0 -DCMAKE_POLICY_VERSION_MINIMUM=3.10 -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=BOTH"
	do_cmake_from_build_dir "$src_dir/$lib" "$cmake_params" 
	disable_nonessential "$src_dir/$lib"
  do_make_and_make_install
	change_dir "$src_dir"
	fi
}
# build_decklink          # config_options+= --enable-decklink            # enable Blackmagic DeckLink I/O support [no]
build_decklink() {
  if ! truthy "$disable_decklink" && truthy "$enable_decklink"; then
  echo "WARNING: This is a non-gpl library. Binaries including this library are non-redistributable!" >>"$LOG_FILE"
	local lib="decklink"
  local repo="https://gitlab.com/m-ab-s/decklink-headers"
  local repo_ver="40eb094072004d8a8416e3c57721967df8b1d10c"
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
	generic_make_install
	change_dir "$src_dir"
	fi
}
# build_libzvbi           # config_options+= --enable-libzvbi             # enable teletext support via libzvbi [no]
build_libzvbi() {
  if ! truthy "$disable_libzvbi" && truthy "$enable_libzvbi"; then
	local lib="libzvbi"
  local repo="https://github.com/zapping-vbi/zvbi"
  local repo_ver="v0.2.44"
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  export LIBS="-lpng -lz -liconv"
  export LDFLAGS="$LDFLAGS $LIBS"
  which autopoint
  autopoint --version
  # do_autogen
# 	generic_configure "--enable-static \
# --disable-shared \
# --disable-dvb \
# --disable-bktr \
# --disable-proxy \
# --disable-nls \
# --without-doxygen \
# --disable-examples \
# --disable-tests \
# --enable-pic \
# --with-pic \
# --with-libiconv-prefix=\"$dependency_install_prefix\""
# 	disable_nonessential "$src_dir/$lib"
#   do_make_and_make_install
# 	change_dir "$src_dir"
#   reset_ldflags
  export PATH=$ORIG_PATH
  export ACLOCAL_PATH=$ORIG_ACLOCAL_PATH
  unset LIBS
	fi
}
# build_libfribidi        # config_options+= --enable-libfribidi          # enable libfribidi, improves drawtext filter [no]
build_libfribidi() {
  if ! truthy "$disable_libfribidi" && truthy "$enable_libfribidi"; then
	local lib="fribidi"
  local repo="https://github.com/fribidi/fribidi"
  local repo_ver="v1.0.16"
  activate_meson
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
	local meson_options="-Ddeprecated=false \
-Ddocs=false \
-Dtests=false"
  generic_meson "$meson_options"
  disable_nonessential "$src_dir/$lib"
  do_ninja_and_ninja_install
	change_dir "$src_dir"
	fi
}
# build_libass            # config_options+= --enable-libass              # enable libass subtitles rendering, needed for subtitles and ass filter [no]
build_libass() {
  if ! truthy "$disable_libass" && truthy "$enable_libass"; then
	run_valid_function "build_libfribidi"
	run_valid_function "build_libharfbuzz"
	local lib="libass"
  local repo="https://github.com/libass/libass"
  local repo_ver="0.17.4"
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  export NASM=nasm
  local meson_options="-Dtest=disabled \
-Dcompare=disabled \
-Dprofile=disabled \
-Dfuzz=disabled \
-Dcheckasm=disabled \
-Ddirectwrite=enabled \
-Dasm=enabled \
-Dfontconfig=enabled"
  generic_meson "$meson_options"
  do_ninja_and_ninja_install
	change_dir "$src_dir"
  unset nasm
	fi
}
# build_libxvid           # config_options+= --enable-libxvid             # enable Xvid encoding via xvidcore, native MPEG-4/Xvid encoder exists [no]
build_libxvid() {
  if ! truthy "$disable_libxvid" && truthy "$enable_libxvid"; then
  echo "Only available on Linux build" >>"$LOG_FILE"
  disable_library "libxvid"
	fi
}
# build_libsrt            # config_options+= --enable-libsrt              # enable Haivision SRT protocol via libsrt [no]
build_libsrt() {
  if ! truthy "$disable_libsrt" && truthy "$enable_libsrt"; then
	run_valid_function "build_openssl" 1
	run_valid_function "build_zlib" 1
	# do_git_checkout https://github.com/Haivision/srt # might be able to use these days...?
	local lib="libsrt"
  # do_git_checkout https://github.com/Haivision/srt # might be able to use these days...?
  local repo="https://github.com/Haivision/srt"
  local repo_ver="v1.5.4" 
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
	change_dir "$src_dir/$lib"
	apply_patch "$PATCHDIR/srt.app.patch"
	# CMake Warning at CMakeLists.txt:893 (message):
	#   On MinGW, some C++11 apps are blocked due to lacking proper C++11 headers
	#   for <thread>.  FIX IF POSSIBLE.
  local enclib
  truthy "$enable_openssl" && enclib=openssl
  truthy "$enable_gnutls" && enclib=gnutls
  truthy "$enable_mbedtls" && enclib=mbedtls
	generic_cmake "-DUSE_ENCLIB=$enclib \
-DENABLE_SHARED=OFF \
-DENABLE_STATIC=ON \
-DENABLE_APPS=OFF \
-DUSE_STATIC_LIBSTDCXX=ON \
-DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
-DENABLE_CXX11=OFF"
	disable_nonessential "$src_dir/$lib"
  do_make_and_make_install
	change_dir "$src_dir"
	fi
}
# build_libaribcaption    # config_options+= --enable-libaribcaption      # enable ARIB text and caption decoding via libaribcaption [no]
build_libaribcaption() {
  if ! truthy "$disable_libaribcaption" && truthy "$enable_libaribcaption"; then
	run_valid_function "build_libfontconfig" 1
		local lib="libaribcaption"
    local repo_ver="v1.1.1"
    local repo="https://github.com/xqq/libaribcaption"
	change_dir "$src_dir"
    do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
    change_dir "$src_dir/$lib/build" 1
    generic_cmake "-DCMAKE_BUILD_TYPE=Release \
-DARIBCC_BUILD_TESTS=OFF \
-DARIBCC_SHARED_LIBRARY=OFF \
-DBUILD_SHARED_LIBS=OFF \
-DBUILD_TESTS=OFF \
-DBUILD_EXAMPLES=OFF" "$src_dir/$lib"
		disable_nonessential "$src_dir/$lib"
    do_make_and_make_install
	change_dir "$src_dir"
	fi
}
# build_libaribb24        # config_options+= --enable-libaribb24          # enable ARIB text and caption decoding via libaribb24 [no]
build_libaribb24() {
  if ! truthy "$disable_libaribb24" && truthy "$enable_libaribb24"; then
	run_valid_function "build_libpng"
	local lib="libaribb24"
  local repo_ver="v1.0.3"
  local repo="https://github.com/nkoriyama/aribb24"
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  generic_configure
  disable_nonessential "$src_dir/$lib"
  do_make_and_make_install
	change_dir "$src_dir"
	fi
}
# build_libtesseract      # config_options+= --enable-libtesseract        # enable Tesseract, needed for ocr filter [no]
build_libtesseract() {
  if ! truthy "$disable_libtesseract" && truthy "$enable_libtesseract"; then
	run_valid_function "build_libleptonica"
	run_valid_function "build_libarchive"
	run_valid_function "build_curl"
  run_valid_function "build_pango"
	local lib="libtesseract"
  local repo="https://github.com/tesseract-ocr/tesseract"
  local repo_ver="5.5.1"
	change_dir "$src_dir"
	do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
	change_dir "$src_dir/$lib"
	export CPPFLAGS="$CPPFLAGS -DJBG_STATIC "
  export CXXFLAGS="$CXXFLAGS -DJBG_STATIC "
  export LIBS="-lleptonica -ltiff -larchive -lgif -lwebp -lwebpmux -lLerc -lsharpyuv -lopenjp2 -lpng -ljpeg -ljbig -llzma -lzstd -ldeflate -lz -lbz2 -lexpat -lxml2 -liconv -lcharset -lwinmm -lcrypt32 -lws2_32"
  export LDFLAGS=" -static -Wl,--allow-multiple-definition $LDFLAGS -static-libgcc -static-libstdc++ "
	generic_configure "--disable-openmp \
--with-archive \
--disable-graphics \
--disable-tessdata-prefix \
--without-curl \
--disable-doc \
--with-extra-libraries=\"$dependency_install_prefix/lib\" \
--with-extra-includes=\"$dependency_install_prefix/include\" \
LIBLEPT_HEADERSDIR=$dependency_install_prefix/include \
LDFLAGS=\"$LDFLAGS\" \
CPPFLAGS=\"$CPPFLAGS\" \
CXXFLAGS=\"$CXXFLAGS\" \
LIBS=\"$LIBS\" \
--datadir=\"$dependency_install_prefix/bin\""
	disable_nonessential "$src_dir/$lib"
  do_make_and_make_install "LDFLAGS=\"$LDFLAGS\" LIBS=\"$LIBS\" CXXFLAGS=\"$CXXFLAGS\"" "LDFLAGS=\"$LDFLAGS\" LIBS=\"$LIBS\" CXXFLAGS=\"$CXXFLAGS\""
  add_libs_to_pkg -t="$install_pkgconfig_dir/tesseract.pc" -l="-lstdc++ -lws2_32 -lbz2 -lz -liconv -lgdi32 -lcrypt32" -rp="lept libarchive liblzma libtiff-4"
	# TODO: add ability to download tessdata
  # https://github.com/tesseract-ocr/tessdata
  # https://github.com/tesseract-ocr/tessdata_best
  # https://github.com/tesseract-ocr/tessdata_fast
	reset_cppflags
  reset_ldflags
  unset LIBS
	change_dir "$src_dir"
	fi
}
# build_liblensfun        # config_options+= --enable-liblensfun          # enable lensfun lens correction [no]
build_liblensfun() {
  if ! truthy "$disable_liblensfun" && truthy "$enable_liblensfun"; then
	run_valid_function "build_glib"
	local lib="liblensfun"
  local repo="https://github.com/lensfun/lensfun"
  local repo_ver="master"
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
	export CPPFLAGS="$CPPFLAGS -DGLIB_STATIC_COMPILATION -I$dependency_install_prefix/lib/glib-2.0/include"
	export CXXFLAGS="$CFLAGS -DGLIB_STATIC_COMPILATION -I$dependency_install_prefix/lib/glib-2.0/include"
	generic_cmake "-DCMAKE_BUILD_TYPE=Release \
-DBUILD_STATIC=on \
-DCMAKE_INSTALL_DATAROOTDIR=$dependency_install_prefix \
-DBUILD_TESTS=off \
-DBUILD_DOC=off \
-DINSTALL_HELPER_SCRIPTS=off \
-DINSTALL_PYTHON_MODULE=OFF"
	disable_nonessential "$src_dir/$lib"
  do_make_and_make_install
  add_libs_to_pkg -t="$install_pkgconfig_dir/lensfun.pc" -l="-lstdc++"
	reset_cppflags
	reset_cxxflags
	change_dir "$src_dir"
	fi
}
# build_libvpx            # config_options+= --enable-libvpx              # enable VP8 and VP9 de/encoding via libvpx [no]
build_libvpx() {
  if ! truthy "$disable_libvpx" && truthy "$enable_libvpx"; then
	local lib="libvpx"
  local repo="https://chromium.googlesource.com/webm/libvpx"
  local repo_ver="v1.15.2"
	change_dir "$src_dir"
	do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
	# apply_patch $PATCHDIR/vpx_160_semaphore.patch -p1 # perhaps someday can remove this after 1.6.0 or mingw fixes it LOL
	if [[ "$bits_target" = "32" ]]; then
		local config_options="--target=x86-win32-gcc"
	else
		local config_options="--target=x86_64-win64-gcc"
	fi
	export CROSS="$cross_prefix"
  clear_cross_vars AS
	do_configure "--prefix=$dependency_install_prefix \
--libdir=$dependency_install_prefix/lib \
--enable-static \
--disable-shared \
--disable-examples \
--disable-tools \
--disable-docs \
--disable-unit-tests \
--enable-pic \
--disable-mmx \
--disable-sse \
--disable-sse2 \
--disable-sse3 \
--disable-ssse3 \
--disable-sse4_1 \
--disable-avx \
--disable-avx2 \
--disable-avx512 \
--enable-vp9-highbitdepth \
--extra-cflags=-fno-asynchronous-unwind-tables \
--extra-cflags=-mstackrealign" # fno for Error: invalid register for .seh_savexmm
	do_make_and_make_install "AS= " "AS= "
	change_dir "$src_dir"
  unset CROSS
  reset_cross_vars
	fi
}
# build_libx265           # config_options+= --enable-libx265             # enable HEVC encoding via x265 [no]
build_libx265() {
  if ! truthy "$disable_libx265" && truthy "$enable_libx265"; then
	local lib="libx265"
  local repo="https://bitbucket.org/multicoreware/x265_git"
  local repo_ver="4.1"
	change_dir "$src_dir"
	do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"

  sed -i 's/cmake_policy(SET CMP0025 OLD)//g' "$src_dir/$lib/source/CMakeLists.txt"
  sed -i 's/cmake_policy(SET CMP0054 OLD)//g' "$src_dir/$lib/source/CMakeLists.txt"
  sed -i 's/ARGS ${NASM_FLAGS} ${ASM_SRC}/ARGS ${NASM_FLAGS} -DPIC ${ASM_SRC}/g' "$src_dir/$lib/source/CMakeLists.txt"
  sed -i 's/set(ARGS -f elf64)/set(ARGS -f elf64 -DPIC)/g' "$src_dir/$lib/source/cmake/CMakeASM_NASMInformation.cmake"
  sed -i 's/set(ARGS -f elf32)/set(ARGS -f elf32 -DPIC)/g' "$src_dir/$lib/source/cmake/CMakeASM_NASMInformation.cmake"
  if [ -f "source/dynamicHDR10/json11/json11.cpp" ] && ! grep -Fq -e "#include <cstdint>" "source/dynamicHDR10/json11/json11.cpp" 2>/dev/null; then
      sed -i '/#include <limits>/a #include <cstdint>' source/dynamicHDR10/json11/json11.cpp
  fi
  change_dir "$src_dir/$lib/12bit" 1
  do_cmake_from_build_dir "$src_dir/$lib/source" "-DHIGH_BIT_DEPTH=ON \
-DEXPORT_C_API=OFF \
-DENABLE_CLI=OFF \
-DMAIN12=ON \
-DENABLE_CLI=OFF \
-DENABLE_PIC=ON \
-DENABLE_SHARED=OFF \
-DHIGH_BIT_DEPTH=1 \
-DCMAKE_ASM_NASM_FLAGS=\"-DPIC\" \
-DCMAKE_C_FLAGS:STRING=\"-fPIC -fvisibility=hidden\" \
-DCMAKE_CXX_FLAGS:STRING=\"-fPIC -fvisibility=hidden\" \
-DCMAKE_POLICY_VERSION_MINIMUM=3.5"
  disable_nonessential "$src_dir/$lib/12bit"
  do_make
  change_dir "$src_dir/$lib/10bit" 1
  do_cmake_from_build_dir "$src_dir/$lib/source" "-DHIGH_BIT_DEPTH=ON \
-DEXPORT_C_API=OFF \
-DENABLE_CLI=OFF \
-DENABLE_CLI=OFF \
-DENABLE_PIC=ON \
-DENABLE_SHARED=OFF \
-DHIGH_BIT_DEPTH=1 \
-DENABLE_HDR10_PLUS=1 \
-DCMAKE_ASM_NASM_FLAGS=\"-DPIC\" \
-DCMAKE_C_FLAGS:STRING=\"-fPIC -fvisibility=hidden\" \
-DCMAKE_CXX_FLAGS:STRING=\"-fPIC -fvisibility=hidden\" \
-DCMAKE_POLICY_VERSION_MINIMUM=3.5"
  disable_nonessential "$src_dir/$lib/10bit"
  do_make
  change_dir "$src_dir/$lib/8bit" 1
  ln -sf "$src_dir/$lib/10bit/libx265.a" libx265_main10.a
  ln -sf "$src_dir/$lib/12bit/libx265.a" libx265_main12.a
  do_cmake_from_build_dir "$src_dir/$lib/source" "-DEXTRA_LIB=\"x265_main10.a;x265_main12.a\" \
-DEXTRA_LINK_FLAGS=-L. \
-DLINKED_10BIT=ON \
-DLINKED_12BIT=ON \
-DENABLE_CLI=OFF \
-DENABLE_PIC=ON \
-DENABLE_SHARED=OFF \
-DHIGH_BIT_DEPTH=1 \
-DCMAKE_ASM_NASM_FLAGS=\"-DPIC\" \
-DCMAKE_C_FLAGS:STRING=\"-fPIC -fvisibility=hidden\" \
-DCMAKE_CXX_FLAGS:STRING=\"-fPIC -fvisibility=hidden\" \
-DCMAKE_POLICY_VERSION_MINIMUM=3.5"
  change_dir "$src_dir/$lib/8bit"
  disable_nonessential "$src_dir/$lib/8bit"
  do_make
  mv -f "libx265.a" "libx265_main.a"
  "$AR" -M <<EOF
CREATE libx265.a
ADDLIB libx265_main.a
ADDLIB libx265_main10.a
ADDLIB libx265_main12.a
SAVE
END
EOF
  do_make_install
	change_dir "$src_dir"
	fi
}
# build_libopenh264       # config_options+= --enable-libopenh264         # enable H.264 encoding via OpenH264 [no]
build_libopenh264() {
  if ! truthy "$disable_libopenh264" && truthy "$enable_libopenh264"; then
  activate_meson
	local lib="libopenh264"
  local repo="https://github.com/cisco/openh264.git"
  local repo_ver="v2.6.0" #75b9fcd2669c75a99791 # wels/codec_api.h weirdness
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  local meson_options="-Dtests=disabled"
  generic_meson "$meson_options"
  do_ninja_and_ninja_install
	change_dir "$src_dir"
  fi
}
# build_libaom            # config_options+= --enable-libaom              # enable AV1 video encoding/decoding via libaom [no]
build_libaom() {
  if ! truthy "$disable_libaom" && truthy "$enable_libaom"; then
	local lib="aom"
  local repo_ver="v3.13.1"
  local repo="https://aomedia.googlesource.com/aom"
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
	if [ "$bits_target" = "32" ]; then
		local config_options="-DCMAKE_TOOLCHAIN_FILE=../build/cmake/toolchains/x86-mingw-gcc.cmake -DAOM_TARGET_CPU=x86"
	else
		local config_options="-DCMAKE_TOOLCHAIN_FILE=../build/cmake/toolchains/x86_64-mingw-gcc.cmake -DAOM_TARGET_CPU=x86_64"
	fi
	change_dir "$src_dir/$lib/build" 1
  local cmake_params="-DCMAKE_BUILD_TYPE=Release \
-DBUILD_SHARED_LIBS=0 \
-DENABLE_TESTS=0 \
-DENABLE_EXAMPLES=0 \
-DENABLE_TOOLS=0 \
-DENABLE_DOCS=0"
	do_cmake_from_build_dir "$src_dir/$lib" "$cmake_params"
  disable_nonessential "$src_dir/$lib"
  do_make_and_make_install
	change_dir "$src_dir"
	fi
}
# build_libdav1d          # config_options+= --enable-libdav1d            # enable AV1 decoding via libdav1d [no]
build_libdav1d() {
  if ! truthy "$disable_libdav1d" && truthy "$enable_libdav1d"; then
	local lib="libdav1d"
  local repo_ver="1.5.2"
  local repo="https://code.videolan.org/videolan/dav1d"
  activate_meson
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  apply_patch "$PATCHDIR/david_no_asm.patch"
	local meson_options="-Denable_tools=false -Denable_tests=false -Denable_examples=false"
	generic_meson "$meson_options"
	do_ninja_and_ninja_install
  if [[ -f "$src_dir/build/src/libdav1d.a" ]]; then
	  copy_path "$src_dir/build/src/libdav1d.a" "$dependency_instal_prefix/lib/libdav1d.a" "-fv" >>"$LOG_FILE" 2>&1
  fi
	disable_nonessential "$src_dir/$lib"
  do_ninja_and_ninja_install
	change_dir "$src_dir"
	fi
}
# build_vulkan            # config_options+= --disable-vulkan             # disable Vulkan code [autodetect]
build_vulkan() {
  extra_args="$1"
  if ! truthy "$disable_vulkan" && truthy "$enable_vulkan" || [[ -n "$extra_args" ]]; then
	local lib="Vulkan-Headers"
  local repo="https://github.com/KhronosGroup/Vulkan-Headers"
  local repo_ver="v1.4.335"
	change_dir "$src_dir"
	do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
	do_cmake_and_install "-DCMAKE_BUILD_TYPE=Release \
-DVULKAN_HEADERS_ENABLE_MODULE=NO \
-DVULKAN_HEADERS_ENABLE_TESTS=NO \
-DVULKAN_HEADERS_ENABLE_INSTALL=YES \
$extra_args" "$src_dir/$lib"
  disable_nonessential "$src_dir/$lib"
  do_make_and_make_install
	change_dir "$src_dir"
	fi
}
# build_vulkan_static     # config_options+= --enable-vulkan-static       # enable statically link to libvulkan [no]
build_vulkan_static() {
  if ! truthy "$disable_vulkan_static" && truthy "$enable_vulkan_static"; then
	local lib="Vulkan-Shim-Loader"
  local repo="https://github.com/BtbN/Vulkan-Shim-Loader"
	change_dir "$src_dir"
	do_git_checkout "$repo" "$src_dir/$lib"
	change_dir "$src_dir/$lib"
	run_valid_function "build_vulkan" "-DCMAKE_BUILD_TYPE=Release -DVULKAN_SHIM_IMPERSONATE=ON"
	change_dir "$src_dir"
	fi
}
# build_libplacebo        # config_options+= --enable-libplacebo          # enable libplacebo library [no]
build_libplacebo() {
  if ! truthy "$disable_libplacebo" && truthy "$enable_libplacebo"; then
	run_valid_function "build_vulkan_loader"
	run_valid_function "build_lcms2" 1
	run_valid_function "build_libxxhash"
	run_valid_function "build_spirv_cross"
	run_valid_function "build_libdovi"
	run_valid_function "build_libshaderc" 1
  activate_meson
	local lib="libplacebo"
  local repo="https://code.videolan.org/videolan/libplacebo"
  local repo_ver="v7.351.0"
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
	git submodule update --init --recursive --depth=1 --filter=blob:none
	local config_options=""
	local config_options+=" -Dvulkan-registry=$dependency_install_prefix/share/vulkan/registry/vk.xml"
	local meson_options="-Ddemos=false \
-Dbench=false \
-Dfuzz=false \
-Dvulkan=enabled \
-Dvk-proc-addr=disabled \
-Dglslang=disabled \
-Dc_link_args=\"-L$dependency_install_prefix/lib -lshaderc_combined -lspirv-cross-c -static\" \
-Dcpp_link_args=-static $config_options" # https://mesonbuild.com/Dependencies.html#shaderc trigger use of shaderc_combined
	if ! truthy "$disable_libshaderc" && truthy "$enable_libshaderc"; then
    meson_options+=" -Dshaderc=enabled"
  else
    meson_options+=" -Dshaderc=disabled"
  fi
  sed -i '/windows\.compile_resources(/,/)/ s/^/# /' "$src_dir/$lib/src/meson.build"
  sed -i '/windows\.compile_resources(/,/)/ s/^/# /' "$src_dir/$lib/demos/meson.build"
	generic_meson "$meson_options"
	do_ninja_and_ninja_install
  add_libs_to_pkg -t="$install_pkgconfig_dir/libplacebo.pc" -l="-lspirv-cross-core -lspirv-cross-glsl -lspirv-cross-hlsl -lspirv-cross-msl -lshlwapi -lxxhash -lversion -lstdc++ -luserenv"
	change_dir "$src_dir"
	fi
}
# build_avisynth          # config_options+= --enable-avisynth            # enable reading of AviSynth script files [no]
build_avisynth() {
  if ! truthy "$disable_avisynth" && truthy "$enable_avisynth"; then
  local lib="avisynth"
  local repo="https://github.com/AviSynth/AviSynthPlus"
  local repo_ver="v3.7.5"
	change_dir "$src_dir"
	do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
	change_dir "$src_dir/$lib/build" 1
	do_cmake_from_build_dir "$src_dir/$lib" "-DHEADERS_ONLY:bool=on"
  disable_nonessential "$src_dir/$lib/build"
  do_make_and_make_install "$(get_compiler_flags) VersionGen install"
	change_dir "$src_dir"
	fi
}
# build_libvvenc          # config_options+= --enable-libvvenc            # enable H.266/VVC encoding via vvenc [no]
build_libvvenc() {
  if ! truthy "$disable_libvvenc" && truthy "$enable_libvvenc"; then
	local lib="libvvenc"
  local repo="https://github.com/fraunhoferhhi/vvenc"
  local repo_ver="v1.13.1"
	change_dir "$src_dir"
	do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  change_dir "$src_dir/$lib/build" 1
	do_cmake_from_build_dir "$src_dir/$lib" "-DCMAKE_BUILD_TYPE=Release \
-DBUILD_SHARED_LIBS=0 \
-DVVENC_ENABLE_LINK_TIME_OPT=OFF \
-DVVENC_INSTALL_FULLFEATURE_APP=ON"
	disable_nonessential "$src_dir/$lib"
	do_make_and_make_install
  sed -i 's/interface_libs-NOTFOUND//g' "$install_pkgconfig_dir/libvvenc.pc"
	change_dir "$src_dir"
	fi
}

# build_libx264           # config_options+= --enable-libx264             # enable H.264 encoding via x264 [no]
build_libx264() {
  if ! truthy "$disable_libx264" && truthy "$enable_libx264"; then
	local lib="libx264"
  local repo="https://code.videolan.org/videolan/x264.git"
  local repo_ver="stable"
	change_dir "$src_dir"
	do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
	change_dir "$src_dir/$lib"
  clear_cross_vars AS
  generic_configure "--enable-static --disable-cli --disable-asm --enable-pic"
	disable_nonessential "$src_dir/$lib"
  do_make_and_make_install "AS= AR=\"${AR} rc \" " "AS= AR=\"${AR} rc \" " # weird ness with AR variable
  reset_cross_vars
	change_dir "$src_dir"
	fi
}

# build_libcodec2         # config_options+= --enable-libcodec2           # enable codec2 en/decoding using libcodec2 [no]
# shellcheck disable=SC2082
build_libcodec2() {
  if ! truthy "$disable_libcodec2" && truthy "$enable_libcodec2"; then
	local lib="libcodec2"
  local repo_ver="1.2.0"
  local repo="https://github.com/drowe67/codec2"
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  change_dir "$src_dir/$lib/build" 1
	local cmake_params="-DUNITTEST=FALSE -DBUILD_SHARED_LIBS=OFF"
	if [[ -f "$PATCHDIR/codec2_GetDependencies.cmake.in" ]]; then
    copy_path "$PATCHDIR/codec2_GetDependencies.cmake.in" "$src_dir/$lib/cmake/GetDependencies.cmake.in" "-fv" >>"$LOG_FILE" 2>&1
  fi
	do_cmake_from_build_dir "$src_dir/$lib" "$cmake_params"
	disable_nonessential "$src_dir/$lib/build"
  do_make_and_make_install " CC= CXX= "
	change_dir "$src_dir"
  fi
}

# build_libjxl            # config_options+= --enable-libjxl              # enable JPEG XL de/encoding via libjxl [no]
build_libjxl() {
  if ! truthy "$disable_libjxl" && truthy "$enable_libjxl"; then
	run_valid_function "build_brotli"
	run_valid_function "build_lcms2" 1
	local lib="libjxl"
  local repo="https://github.com/libjxl/libjxl"
  local repo_ver="v0.7.2"
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  change_dir "$src_dir/$lib/build" 1
	export LDFLAGS="$LDFLAGS -lbrotlidec -lbrotlicommon"
  local cmake_params="-DCMAKE_BUILD_TYPE=Release \
-DBUILD_TESTING=OFF \
-DJPEGXL_STATIC=ON \
-DJPEGXL_ENABLE_TOOLS=OFF \
-DJPEGXL_ENABLE_BENCHMARK=OFF \
-DJPEGXL_ENABLE_EXAMPLES=OFF \
-DCMAKE_PREFIX_PATH=\"$dependency_install_prefix\" \
-DJPEGXL_FORCE_SYSTEM_BROTLI=ON \
-DJPEGXL_ENABLE_DOXYGEN=OFF \
-DJPEGXL_ENABLE_MANPAGES=OFF \
-DJPEGXL_ENABLE_FUZZERS=OFF \
-DJPEGXL_ENABLE_VIEWERS=OFF \
-DJPEGXL_ENABLE_SJPEG=OFF \
-DJPEGXL_ENABLE_PLUGINS=OFF \
-DJPEGXL_BUNDLE_LIBPNG=OFF \
-DBUILD_TESTING=OFF \
-DCMAKE_POSITION_INDEPENDENT_CODE=ON \
-DJPEGXL_FORCE_SYSTEM_LCMS2=ON"
  sed -i '1s/^/set(CMAKE_POSITION_INDEPENDENT_CODE ON CACHE BOOL "Force PIC" FORCE)\n/' "$src_dir/$lib/third_party/CMakeLists.txt"
	do_cmake_from_build_dir "$src_dir/$lib" "$cmake_params"
	disable_nonessential "$src_dir/$lib/build"
  do_make_and_make_install
  reset_ldflags
	change_dir "$src_dir"
	fi
}

# build_libkvazaar        # config_options+= --enable-libkvazaar          # enable HEVC encoding via libkvazaar [no]
build_libkvazaar() {
  if ! truthy "$disable_libkvazaar" && truthy "$enable_libkvazaar"; then
	local lib="libkvazaar"
  local repo="https://github.com/ultravideo/kvazaar"
  local repo_ver="v2.3.2"
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  export ASFLAGS="$ASFLAGS -DPIC"
	local cmake_params="-DCMAKE_BUILD_TESTS=OFF \
-DCMAKE_ASM_NASM_FLAGS=\"-DPIC\" \
-DBUILD_KVAZAAR_BINARY=OFF \
-DBUILD_TESTS=OFF \
-DBUILD_SHARED_LIBS=OFF"
  change_dir "$src_dir/$lib/build" 1
  do_cmake_from_build_dir "$src_dir/$lib" "$cmake_params"
	disable_nonessential "$src_dir/$lib/build"
  do_make_and_make_install
	change_dir "$src_dir"
  unset ASFLAGS
  add_libs_to_pkg -t="$install_pkgconfig_dir/kvazaar.pc" -c="-DKVZ_STATIC_LIB"
	fi
}
# build_openssl           # config_options+= --enable-openssl             # enable openssl, needed for https support if gnutls, libtls or mbedtls is not used [no]
build_openssl() {
  if ! truthy "$disable_openssl" && truthy "$enable_openssl" || [[ -n "$1" ]]; then
  local lib="openssl"
  # https://github.com/openssl/openssl 
  local repo="https://github.com/openssl/openssl"
  local repo_ver="openssl-3.6.0"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
	change_dir "$src_dir/$lib"
  install_missing_packages perl-IPC-Cmd perl-Time-Piece
  clear_cross_vars
  do_configure "mingw64 \
--release \
--prefix=$dependency_install_prefix \
--cross-compile-prefix=$host_target- \
--openssldir=$dependency_install_prefix/ssl \
--libdir=lib \
no-apps \
no-shared \
no-tests \
no-docs \
no-demos \
no-legacy"
	# disable_nonessential "$src_dir/$lib"
  # uses different build process and doesnt respect cross variables correctly
  local touch_make=$(get_small_touchfile_name "${host_name}_already_make_make" "make")
  local touch_install=$(get_small_touchfile_name "${host_name}_already_make_install" "make install")
  if truthy "$build_force"; then
    remove_path -f "$touch_make"
    { nice make clean -j"$(get_concurrent_proc)" > >(redirect_output) 2>&1 || true; }
    remove_path -f "$touch_install"
    { nice make uninstall > >(redirect_output) 2>&1 || true; }
  fi
  [[ ! -f "$touch_make" ]] && make -j"$(get_concurrent_proc)" > >(redirect_output) 2>&1
  create_touch_file 0 "$touch_make"
  [[ ! -f "$touch_install" ]] && make install > >(redirect_output) 2>&1
  create_touch_file 0 "$touch_install"
  reset_cross_vars
	change_dir "$src_dir"
	fi
}

# build_librav1e          # config_options+= --enable-librav1e            # enable AV1 encoding via rav1e [no]
build_librav1e() {
  if ! truthy "$disable_librav1e" && truthy "$enable_librav1e"; then
	local lib="librav1e"
  local repo="https://github.com/xiph/rav1e"
  local repo_ver="v0.8.1"
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver" 
  change_dir "$src_dir/$lib"
  unset CC CXX AR STRIP PKG_CONFIG_ALLOW_CROSS
  export CROSS_ROOT=$toolchain_bin_path
  export PATH=$CROSS_ROOT:$PATH
  export PKG_CONFIG_ALLOW_CROSS=1
  export CFLAGS="-static -O3 -fPIC -I$dependency_install_prefix/include -L$dependency_install_prefix/lib"
  export CXXFLAGS="-static -O3 -fPIC -I$dependency_install_prefix/include -L$dependency_install_prefix/lib"
  export RUSTFLAGS="-C target-feature=+crt-static -C target-cpu=x86-64"
  export CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER="${cross_prefix}gcc"
  export CARGO_TARGET_X86_64_PC_WINDOWS_GNU_AR="${cross_prefix}ar"
  export CC_x86_64_pc_windows_gnu="${cross_prefix}gcc"
  export CXX_x86_64_pc_windows_gnu="${cross_prefix}g++"
  export AR_x86_64_pc_windows_gnu="${cross_prefix}ar"
  confirm_libgcc_eh "$toolchain_root_dir/lib/gcc"
	cargo_build_and_install "--no-default-features --features=asm,binaries --profile release-no-lto" "--no-default-features --library-type=staticlib --features=asm,binaries"
  reset_cflags
  reset_cxxflags
  reset_cross_vars
	change_dir "$src_dir"
	fi
}

# build_libxeve           # config_options+= --enable-libxeve             # enable EVC encoding via libxeve [no]
build_libxeve() {
  if ! truthy "$disable_libxeve" && truthy "$enable_libxeve"; then
	local lib="libxeve"
  # https://github.com/mpeg5/xeve
  local repo="https://github.com/mpeg5/xeve"
  local repo_ver="v0.5.1"
	change_dir "$src_dir"
	do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
	change_dir "$src_dir/$lib/build" 1
	local cmake_params=" -DCMAKE_TOOLCHAIN_FILE=$(get_generic_windows_cmake_toolchain)"
# needs a version.txt file but git repo doesnt have one for some reason
	if [ -d .git ]; then
			# Get version from git tags
			VERSION=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.5.1")
	else
			# Use default version
			VERSION="0.5.1"
	fi
cat >"$src_dir/$lib/version.txt" <<EOF
$VERSION
EOF
	do_cmake_from_build_dir "$src_dir/$lib" "-DBUILD_SHARED_LIBS=OFF \
-DCMAKE_POSITION_INDEPENDENT_CODE=ON \
-DCMAKE_BUILD_TYPE=Release"
	disable_nonessential "$src_dir/$lib/build"
	do_make "xeve"
  sed -i "s/Version:.*/Version: 0.5.1/g" "$src_dir/$lib/build/xeve.pc"
  { cp -fv "$src_dir/$lib/build/src_main/libxeve.a" "$dependency_install_prefix/lib/" >>"$LOG_FILE"; } || exit_message 1 "build_libxeve: could not install $lib static lib"
  { cp -fv "$src_dir/$lib/inc/xeve.h" "$dependency_install_prefix/include/" >>"$LOG_FILE"; } || exit_message 1 "build_libxeve: could not install $lib headers"
  { cp -fv "$src_dir/$lib/build/xeve_exports.h" "$dependency_install_prefix/include/" >>"$LOG_FILE"; } || exit_message 1 "build_libxeve: could not install $lib headers"
  { cp -fv "$src_dir/$lib/build/xeve.pc" "$install_pkgconfig_dir/" >>"$LOG_FILE"; } || exit_message 1 "build_libxeve: could not install $lib pkg-config"
	change_dir "$src_dir"
	fi
}

# build_libxevd           # config_options+= --enable-libxevd             # enable EVC decoding via libxevd [no]
build_libxevd() {
  if ! truthy "$disable_libxevd" && truthy "$enable_libxevd"; then
	local lib="libxevd"
  local repo="https://github.com/mpeg5/xevd"
  local repo_ver="v0.5.0"
	change_dir "$src_dir"
	do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
	change_dir "$src_dir/$lib/build" 1
# needs a version.txt file but git repo doesnt have one for some reason
	if [ -d .git ]; then
			# Get version from git tags
			VERSION=$(git describe --tags --abbrev=0 2>/dev/null || echo "0.5.0")
	else
			# Use default version
			VERSION="0.5.0"
	fi
cat >"$src_dir/$lib/version.txt" <<EOF
$VERSION
EOF
	do_cmake_from_build_dir "$src_dir/$lib" "-DBUILD_SHARED_LIBS=OFF \
-DCMAKE_POSITION_INDEPENDENT_CODE=ON \
-DCMAKE_BUILD_TYPE=Release"
  disable_nonessential "$src_dir/$lib/build"
	do_make "xevd"
  # XXX replace version if repo_ver is changed
  sed -i "s/Version:.*/Version: 1.5.0/g" "$src_dir/$lib/build/xevd.pc"
  # manually install static library only
  { cp -fv "$src_dir/$lib/build/src_main/libxevd.a" "$dependency_install_prefix/lib/" >>"$LOG_FILE"; } || exit_message 1 "build_libxevd: could not install $lib static lib"
  { cp -fv "$src_dir/$lib/inc/xevd.h" "$dependency_install_prefix/include/" >>"$LOG_FILE"; } || exit_message 1 "build_libxevd: could not install $lib headers"
  { cp -fv "$src_dir/$lib/build/xevd_exports.h" "$dependency_install_prefix/include/" >>"$LOG_FILE"; } || exit_message 1 "build_libxevd: could not install $lib headers"
  { cp -fv "$src_dir/$lib/build/xevd.pc" "$install_pkgconfig_dir/" >>"$LOG_FILE"; } || exit_message 1 "build_libxevd: could not install $lib pkg-config"
	change_dir "$src_dir"
	fi
}

# build_ladspa            # config_options+= --disable-ladspa             # enable LADSPA audio filtering [no]
build_ladspa() {
  if ! truthy "$disable_ladspa" && truthy "$enable_ladspa"; then
  echo "INFO: Only available on Linux build" >>"$LOG_FILE"
	fi
}
build_sratom() {
	run_valid_function "build_sord"
  activate_meson
  local lib="sratom"
  local repo="https://gitlab.com/lv2/sratom"
  local repo_ver="v0.6.20"
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  local meson_options="-Dtests=disabled -Ddocs=disabled"
  generic_meson "$meson_options"
  disable_nonessential "$src_dir/$lib"
  do_ninja_and_ninja_install
  change_dir "$dependency_install_prefix/lib"
  # ln -sf "libsratom-0.a" "libsratom.a"
  cp -f "libsratom-0.a" "libsratom.a"
  change_dir "$install_pkgconfig_dir"
  ln -sf "sratom-0.pc" "sratom.pc"
	change_dir "$src_dir"
}
build_sord() {
	run_valid_function "build_zix"
  activate_meson
  local lib="sord"
  local repo="https://gitlab.com/drobilla/sord"
  local repo_ver="v0.16.20"
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  local meson_options="-Dtests=disabled -Dtools=disabled -Ddocs=disabled"
  generic_meson "$meson_options"
  disable_nonessential "$src_dir/$lib"
  do_ninja_and_ninja_install
  change_dir "$dependency_install_prefix/lib"
  # ln -sf "libsord-0.a" "libsord.a"
  cp -f "libsord-0.a" "libsord.a"
  change_dir "$install_pkgconfig_dir"
  ln -sf "sord-0.pc" "sord.pc"
	change_dir "$src_dir"
}
build_serd() {
  activate_meson
  local lib="serd"
  local repo="https://gitlab.com/drobilla/serd"
  local repo_ver="v0.32.6"
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  local meson_options="-Dtests=disabled -Dtools=disabled -Ddocs=disabled -Dstatic=true"
  generic_meson "$meson_options"
  disable_nonessential "$src_dir/$lib"
  do_ninja_and_ninja_install
  change_dir "$dependency_install_prefix/lib"
  # ln -sf "libserd-0.a" "libserd.a"
  cp -f "libserd-0.a" "libserd.a"
  change_dir "$install_pkgconfig_dir"
  ln -sf "serd-0.pc" "serd.pc"
	change_dir "$src_dir"
}
build_zix() {
	run_valid_function "build_serd"
  activate_meson
  local lib="zix"
  local repo="https://gitlab.com/drobilla/zix"
  local repo_ver="v0.8.0"
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  local meson_options="-Dtests=disabled -Dtests_cpp=disabled -Ddocs=disabled"
  generic_meson "$meson_options"
  disable_nonessential "$src_dir/$lib"
  do_ninja_and_ninja_install
  change_dir "$dependency_install_prefix/lib"
  # ln -sf "libzix-0.a" "libzix.a"
  cp -f "libzix-0.a" "libzix.a"
  change_dir "$install_pkgconfig_dir"
  ln -sf "zix-0.pc" "zix.pc"
	change_dir "$src_dir"
}
build_lilv() {
  activate_meson
  local lib="lilv"
  local repo="https://github.com/lv2/lilv"
  local repo_ver="v0.26.2"
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  local meson_options="-Dtests=disabled -Ddocs=disabled -Dtools=disabled"
  generic_meson "$meson_options"
  disable_nonessential "$src_dir/$lib"
  do_ninja_and_ninja_install
  change_dir "$dependency_install_prefix/lib"
  # ln -sf "liblilv-0.a" "liblilv.a"
  cp -f "liblilv-0.a" "liblilv.a"
  change_dir "$install_pkgconfig_dir"
  ln -sf "lilv-0.pc" "lilv.pc"
	change_dir "$src_dir"
}
# build_lv2               # config_options+= --enable-lv2                 # enable LV2 audio filtering [no]
build_lv2() {
  if ! truthy "$disable_lv2" && truthy "$enable_lv2"; then
		activate_meson
    local lib="lv2"
    local repo="https://github.com/lv2/lv2"
    local repo_ver="v1.18.10"
	change_dir "$src_dir"
    do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
    change_dir "$src_dir/$lib"
    local meson_options="-Dtests=disabled -Ddocs=disabled -Donline_docs=false -Dplugins=disabled"
    generic_meson "$meson_options"
    disable_nonessential "$src_dir/$lib"
    do_ninja_and_ninja_install
	change_dir "$src_dir"
	run_valid_function "build_sratom"
	run_valid_function "build_lilv"
    change_dir "$install_pkgconfig_dir"
    sed -i 's/-lsratom-0\b/-lsratom/g' *.pc
    sed -i 's/-lsord-0\b/-lsord/g' *.pc
    sed -i 's/-lserd-0\b/-lserd/g' *.pc
    sed -i 's/-llilv-0\b/-llilv/g' *.pc
    sed -i 's/-lzix-0\b/-lzix/g' *.pc
    sed -i 's/-lilv-0\b/-llilv/g' *.pc
	fi
}

# build_libcelt           # config_options+= --enable-libcelt             # enable CELT decoding via libcelt [no]
build_libcelt() {
  if ! truthy "$disable_libcelt" && truthy "$enable_libcelt"; then
  enable_library "libopus"
  disable_library "libcelt"
	run_valid_function "build_libopus" 1
  echo -e "The celt codec design and implementation have been merged into
the IETF Codec Working Group's \"Opus\" codec. As such, this
repository is no longer under active development.

Please see https://git.xiph.org/?p=opus
and https://git.xiph.org/?p=users/jm/opus-tools.git for more
current work. Visit http://opus-codec.org/ for more
information.

We apologize for any inconvenience this has caused.
" >>"$LOG_FILE"
		# https://github.com/xiph/opus
	fi
}
build_libcdio_paranoia() {
  if ! truthy "$disable_libcdio" && truthy "$enable_libcdio"; then
  local lib="libcdio-paranoia"
  local repo_ver="release-10.2+2.0.2"
  local repo="https://github.com/libcdio/libcdio-paranoia"
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  generic_configure "--disable-example-progs MAKEINFO=true"
  disable_nonessential "$src_dir/$lib"
  do_make_and_make_install
	change_dir "$src_dir"
  fi
}
# build_libcdio           # config_options+= --enable-libcdio             # enable audio CD grabbing with libcdio [no]
build_libcdio() {
  if ! truthy "$disable_libcdio" && truthy "$enable_libcdio"; then
	local lib="libcdio"
  local repo_ver="2.2.0"
  local repo="https://github.com/libcdio/libcdio"
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
		if [[ ! -f "configure" ]]; then
      autoreconf -fiv || exit_message 1 "build_libcdio: could not auto-reconfigure"
    fi
    generic_configure "--disable-vcd-info --disable-cddb --disable-example-progs MAKEINFO=true"
    for prog in cd-drive cd-info cd-read iso-info iso-read mmc-tool; do
      touch src/"$prog".1
    done
    disable_nonessential "$src_dir/$lib"
    do_make_and_make_install
	  change_dir "$src_dir"
	  run_valid_function "build_libcdio_paranoia"
    add_libs_to_pkg -t="$install_pkgconfig_dir/libcdio++.pc" -l="-liconv"
	fi
}

# build_libfdk_aac        # config_options+= --enable-libfdk-aac          # enable AAC de/encoding via libfdk-aac [no]
build_libfdk_aac() {
  if ! truthy "$disable_libfdk_aac" && truthy "$enable_libfdk_aac"; then
  echo "WARNING: This is a non-gpl library. Binaries including this library are non-redistributable!" >>"$LOG_FILE"
  local lib="libfdk_aac"
  local repo="https://github.com/mstorsjo/fdk-aac"
  local repo_ver="v2.0.3"
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  generic_configure "--enable-static --disable-shared"
  disable_nonessential "$src_dir/$lib"
  do_make_and_make_install
	change_dir "$src_dir"
  fi
}

# build_libjack           # config_options+= --enable-libjack             # enable JACK audio sound server [no]
build_libjack() {
  if ! truthy "$disable_libjack" && truthy "$enable_libjack"; then
    echo "Only available on Linux build" >>"$LOG_FILE"
    disable_library "libjack"
	fi
}
# build_libpulse          # config_options+= --enable-libpulse            # enable Pulseaudio input via libpulse [no]
build_libpulse() {
  if ! truthy "$disable_libpulse" && truthy "$enable_libpulse"; then
    echo "Only available on Linux build" >>"$LOG_FILE"
    disable_library "libpulse"
	fi
}

# build_libshine          # config_options+= --enable-libshine            # enable fixed-point MP3 encoding via libshine [no]
build_libshine() {
  if ! truthy "$disable_libshine" && truthy "$enable_libshine"; then
  local lib="libshine"
  local repo="https://github.com/toots/shine"
  local repo_ver="3.1.1" 
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
	change_dir "$src_dir/$lib"
	generic_configure "--enable-static --disable-shared"
  change_dir "$src_dir/$lib/src"
  disable_nonessential "$src_dir/$lib/src" "bin"
  change_dir "$src_dir/$lib"
  do_make_and_make_install
	change_dir "$src_dir"
  fi
}

# build_openal            # config_options+= --enable-openal              # enable OpenAL 1.1 capture support [no]
build_openal() {
  if ! truthy "$disable_openal" && truthy "$enable_openal"; then
	# https://github.com/kcat/openal-soft
	local lib="openal"
  local repo="https://github.com/kcat/openal-soft"
  local repo_ver="1.24.3"
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  change_dir "$src_dir/$lib/build" 1
	local cmake_params="-DCMAKE_BUILD_TYPE=Release \
-DLIBTYPE=STATIC \
-DALSOFT_UTILS=OFF \
-DALSOFT_EXAMPLES=OFF \
-DALSOFT_TESTS=OFF \
-DALSOFT_STATIC_LIBGCC=ON \
-DALSOFT_STATIC_STDCXX=ON \
-DALSOFT_REQUIRE_WASAPI=ON \
-DALSOFT_BACKEND_DSOUND=ON \
-DALSOFT_BACKEND_ALSA=ON \
-DALSOFT_BACKEND_PULSEAUDIO=ON \
-DALSOFT_BACKEND_PIPEWIRE=ON"
	do_cmake_from_build_dir "$src_dir/$lib" "$cmake_params"
	disable_nonessential "$src_dir/$lib/build"
  do_make_and_make_install
	change_dir "$src_dir"
  add_libs_to_pkg -t="$install_pkgconfig_dir/openal.pc" -l="-lole32 -lshell32 -luuid"
	fi
}
build_pcre2() {
	run_valid_function "build_zlib" 1
	run_valid_function "build_bzlib" 1
  local lib="pcre2"
  local repo="https://github.com/PCRE2Project/pcre2"
  local repo_ver="pcre2-10.47"
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  change_dir "$src_dir/$lib/build" 1
	local cmake_params="-DCMAKE_BUILD_TYPE=Release \
-DOAPV_BUILD_STATIC_LIB=ON \
-DOAPV_BUILD_SHARED_LIB=ON \
-DPCRE2_BUILD_PCRE2_8=ON"
	do_cmake_from_build_dir "$src_dir/$lib" "$cmake_params"
	disable_nonessential "$src_dir/$lib/build"
  do_make_and_make_install
	change_dir "$src_dir"
}
build_bison() {
  local lib="bison"
  local repo="https://github.com/akimd/bison"
  local repo_ver="v3.8.2"
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  clear_cross_vars
  do_configure "--build=\"$build_triple\" \
--host=\"$build_triple\" \
--prefix=$dependency_install_prefix \
--libdir=$dependency_install_prefix/lib \
--enable-static --disable-shared --enable-pic --with-pic"
  do_make "CC=gcc \
AR=ar \
AS=as \
RANLIB=ranlib \
LD=ld \
STRIP=strip \
CXX=g++ \
CROSS_COMPILE="
  do_make_install "CC=gcc \
AR=ar \
AS=as \
RANLIB=ranlib \
LD=ld \
STRIP=strip \
CXX=g++ \
CROSS_COMPILE="
  reset_cross_vars
	change_dir "$src_dir"
  while IFS= read -r -d '' file; do
    add_libs_to_pkg -t="$file" -l="-lshlwapi"
  done < <(find "$install_pkgconfig_dir" -name "benchmark*.pc" -print0)
  if [[ -f "$install_pkgconfig_dir/libhwy-test.pc" ]]; then
    remove_path -f "$install_pkgconfig_dir/libhwy-test.pc"
  fi
}
# build_pocketsphinx      # config_options+= --enable-pocketsphinx        # enable PocketSphinx, needed for asr filter [no]
build_pocketsphinx() {
  if ! truthy "$disable_pocketsphinx" && truthy "$enable_pocketsphinx"; then
  run_valid_function "build_dlfcn"
  clear_cross_vars
  local parent="pocketsphinx"
  local lib="swig"
  # local repo="https://github.com/swig/swig"
  local repo="https://sourceforge.net/projects/swig/files/swig/swig-2.0.12/swig-2.0.12.tar.gz/download"
  local repo_ver="v2.0.12"
  export CXXFLAGS="$CXXFLAGS -DSWIG_LIB='\"${dependency_install_prefix}/share/swig\"' "
	change_dir "$src_dir"
  change_dir "$src_dir/$parent" 1
  download_and_unpack_file "$repo" "$lib"
  change_dir "$src_dir/$parent/$lib"
  touch "no.autoreconf"
  do_configure "--build=\"$build_triple\" \
--host=\"$build_triple\" \
--prefix=$dependency_install_prefix \
--libdir=$dependency_install_prefix/lib \
--without-pcre \
--enable-static --disable-shared --enable-pic --with-pic"
  do_make "CC=gcc AR=ar AS=as RANLIB=ranlib LD=ld STRIP=strip CXX=g++ WINDRES= CROSS_COMPILE="
  do_make_install "CC=gcc AR=ar AS=as RANLIB=ranlib LD=ld STRIP=strip CXX=g++ WINDRES= CROSS_COMPILE="
  reset_cxxflags
  reset_cross_vars
  local lib="sphinxbase"
  local repo="https://github.com/cmusphinx/sphinxbase"
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$parent/$lib"
	change_dir "$src_dir/$parent/$lib"
	generic_configure "--enable-static \
--disable-shared \
--without-python \
--without-lapack"
  disable_nonessential "$src_dir/$parent/$lib"
  do_make_and_make_install
	change_dir "$src_dir"
  activate_meson
  local lib="gstreamer"
  local repo="https://gitlab.freedesktop.org/gstreamer/gstreamer"
  local repo_ver="1.26.10"
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$parent/$lib"
  export LDFLAGS=" -static $LDFLAGS -L${dependency_install_prefix}/lib -llzma -ldl"
  local meson_options="-Ddoc=disabled \
-Dexamples=disabled \
-Dtests=disabled \
-Dtools=disabled \
-Dpkg_config_path=\"$install_pkgconfig_dir\" \
-Dc_link_args=\"$LDFLAGS\""
  generic_meson "$meson_options"
  disable_nonessential "$src_dir/$parent/$lib"
  do_ninja_and_ninja_install
  while IFS= read -r -d '' file; do
    add_libs_to_pkg -t="$file" -l="-ldl"
  done < <(find "$install_pkgconfig_dir" -name "gstreamer*.pc" -print0)
  reset_ldflags
	change_dir "$src_dir"
  local lib="pocketsphinx"
  local repo="https://svn.code.sf.net/p/cmusphinx/code/trunk/pocketsphinx"
  local repo_ver="r13291"
	change_dir "$src_dir"
  do_svn_checkout "$repo" "$src_dir/$parent/$lib"
	change_dir "$src_dir/$parent/$lib"
	generic_configure "--enable-static \
--disable-shared \
--without-python \
--without-lapack"
  disable_nonessential "$src_dir/$parent/$lib"
  do_make_and_make_install
	change_dir "$src_dir"
  add_libs_to_pkg -t="$install_pkgconfig_dir/pocketsphinx.pc" -l="-lwinmm"
  add_libs_to_pkg -t="$install_pkgconfig_dir/sphinxbase.pc" -l="-lwinmm"
  fi
}
# build_pocketsphinx() {
#   if ! truthy "$disable_pocketsphinx" && truthy "$enable_pocketsphinx"; then
# 	# https://github.com/cmusphinx/pocketsphinx
# 	local lib="pocketsphinx"
#   local repo="https://github.com/cmusphinx/pocketsphinx"
#   local repo_ver="v5.0.4"
#	change_dir "$src_dir"
#   do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
# 	change_dir "$src_dir/$lib/build" 1
# 	local cmake_params=" -DCMAKE_TOOLCHAIN_FILE=$(get_generic_windows_cmake_toolchain) -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF"
# 	do_cmake_from_build_dir "$src_dir/$lib" "$cmake_params"
# 	do_make_and_make_install
#   #	change_dir "$src_dir"
# 	fi
# }
# build_whisper           # config_options+= --enable-whisper             # enable whisper filter [no]
build_whisper() {
  if ! truthy "$disable_whisper" && truthy "$enable_whisper"; then
	# https://github.com/ggerganov/whisper.cpp
	local lib="whisper"
  local repo="https://github.com/ggerganov/whisper.cpp"
  local repo_ver="v1.8.2"
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  change_dir "$src_dir/$lib/build" 1
	local cmake_params="-DCMAKE_BUILD_TYPE=Release \
-DWHISPER_BUILD_EXAMPLES=OFF \
-DWHISPER_BUILD_TESTS=OFF \
-DCMAKE_STATIC_LIBRARY_PREFIX=lib \
-DWHISPER_FFMPEG=ON \
-DBUILD_SHARED_LIBS=OFF \
-DGGML_STATIC=ON \
-DGGML_AVX2=ON \
-DGGML_FMA=ON \
-DGGML_F16C=ON \
-DGGML_NATIVE=OFF"
	do_cmake_from_build_dir "$src_dir/$lib" "$cmake_params"
	disable_nonessential "$src_dir/$lib/build"
  do_make_and_make_install
  local lib_dir="$dependency_install_prefix/lib"
  for lib_name in ggml ggml-base ggml-cpu; do
      if [[ -f "$lib_dir/${lib_name}.a" && ! -f "$lib_dir/lib${lib_name}.a" ]]; then
          copy_path "$lib_dir/${lib_name}.a" "$lib_dir/lib${lib_name}.a" "-fv" >>"$LOG_FILE" 2>&1
      fi
  done
  while IFS= read -r -d '' file; do
    add_libs_to_pkg -t="$file" -l="-lwhisper -lggml -lggml-base -lggml-cpu -lgomp -lstdc++ -lpthread -lws2_32 -lwinmm"
  done < <(find "$install_pkgconfig_dir" -name "whisper*.pc" -print0)
	change_dir "$src_dir"
	fi
}

# build_gcrypt            # config_options+= --enable-gcrypt              # enable gcrypt, needed for rtmp(t)e support if openssl, librtmp or gmp is not used [no]
build_gcrypt() {
  if ! truthy "$disable_gcrypt" && truthy "$enable_gcrypt"; then
	run_valid_function "build_libgpg_error"
	# https://github.com/gpg/libgcrypt
	local lib="libgcrypt"
  local repo="https://github.com/gpg/libgcrypt"
  local repo_ver="libgcrypt-1.11.2"
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  generic_configure "--disable-doc --disable-tests --disable-amd64-as-feature-detection"
  disable_nonessential "$src_dir/$lib"
  do_make_and_make_install
	change_dir "$src_dir"
	fi
}
# build_librist           # config_options+= --enable-librist             # enable RIST via librist [no]
build_librist() {
  if ! truthy "$disable_librist" && truthy "$enable_librist"; then
	# https://code.videolan.org/rist/librist
	local lib="librist"
  local repo="https://code.videolan.org/rist/librist"
  local repo_ver="v0.2.11"
  activate_meson
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver" 
  change_dir "$src_dir/$lib"
  [[ ! -f "contrib/time-shim.c.bak" ]] && copy_path "contrib/time-shim.c" "contrib/time-shim.c.bak" "-fv" >>"$LOG_FILE" 2>&1
  apply_patch "$PATCHDIR/librist_time-shim.diff"
  local cross_file=$(get_generic_windows_meson_cross_file)
  local meson_options="-Ddefault_library=static -Duse_mbedtls=true -Dbuilt_tools=false -Dtest=false"
	meson_options+=" --cross-file=$cross_file"
  do_meson "$meson_options"
	do_ninja_and_ninja_install
  sed -i 's|^Libs:.*|Libs: -lrist -lws2_32 -liphlpapi|g' "$install_pkgconfig_dir/librist.pc"
	change_dir "$src_dir"
	fi
}
# build_librtmp           # config_options+= --enable-librtmp             # enable RTMP[E] support via librtmp [no]
# shellcheck disable=2086
build_librtmp() {
  if ! truthy "$disable_librtmp" && truthy "$enable_librtmp" || [[ -n "$1" ]]; then
	# https://github.com/mirror/rtmpdump
	local lib="librtmp"
  local repo="git://git.ffmpeg.org/rtmpdump"
  local repo_ver="v2.6"
	change_dir "$src_dir"
	do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
	change_dir "$src_dir/$lib"
  #fix clean command
  sed -i 's/rm -f \*.o \*.a \*.$(SOX) \*$(SO_EXT)/rm -f *.o *.a *.so* *.dll *.dylib/g' librtmp/Makefile
  if grep -Fq -e "-lcrypt32" "librtmp/Makefile" 2>/dev/null; then
    echo "crypt32 library already referenced, skipping" >>"$LOG_FILE"
  else
    sed -i 's/-lgdi32/-lgdi32 -lcrypt32/g' "librtmp/Makefile"
  fi
  if grep -Fq -e "-lcrypt32" "Makefile" 2>/dev/null; then
    echo "crypt32 library already referenced, skipping" >>"$LOG_FILE"
  else
    sed -i 's/-lgdi32/-lgdi32 -lcrypt32/g' "Makefile"
  fi
  do_make "-C librtmp \
SHARED= \
SYS=mingw \
XCFLAGS=\"$CFLAGS\" \
CROSS_COMPILE=\"$cross_prefix\" \
INC=\"-I$dependency_install_prefix/include\" \
XLDFLAGS=\"-L$dependency_install_prefix/lib -static -lssl -lcrypto -lz\" \
prefix=${dependency_install_prefix}"
  disable_nonessential "$src_dir/$lib"
  do_make_install "SHARED= \
SYS=mingw \
XCFLAGS=\"$CFLAGS\" \
CROSS_COMPILE=\"$cross_prefix\" \
INC=\"-I$dependency_install_prefix/include\" \
XLDFLAGS=\"-L$dependency_install_prefix/lib -static -lssl -lcrypto -lz\" \
prefix=${dependency_install_prefix}"

	change_dir "$src_dir"
  unset LIBS
	fi
}
# build_librabbitmq       # config_options+= --enable-librabbitmq         # enable RabbitMQ library [no]
build_librabbitmq() {
  if ! truthy "$disable_librabbitmq" && truthy "$enable_librabbitmq"; then
	# https://github.com/alanxz/rabbitmq-c
	local lib="librabbitmq"
  local repo="https://github.com/alanxz/rabbitmq-c"
  local repo_ver="v0.15.0"
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver" 
  change_dir "$src_dir/$lib"
  [[ ! -f "librabbitmq/amqp_socket.c.bak" ]] && copy_path "librabbitmq/amqp_socket.c" "librabbitmq/amqp_socket.c.bak" "-fv" >>"$LOG_FILE" 2>&1
  apply_patch "$PATCHDIR/librabbitmq_amqp_socket.diff"
  sed -i 's/set(libs_private "${libs_private} -l${LIBRT}")/if(LIBRT)\n    set(libs_private "${libs_private} -l${LIBRT}")\nendif()/' \
    "$src_dir/$lib/CMakeLists.txt"
  sed -i 's/OUTPUT_NAME librabbitmq\.\${RMQ_SOVERSION}/OUTPUT_NAME rabbitmq/' \
    "$src_dir/$lib/librabbitmq/CMakeLists.txt"
  local cmake_params="-DCMAKE_TOOLCHAIN_FILE=$(get_generic_windows_cmake_toolchain) \
-DCMAKE_BUILD_TYPE=Release \
-DBUILD_SHARED_LIBS=OFF \
-DBUILD_STATIC_LIBS=ON \
-DBUILD_EXAMPLES=OFF \
-DBUILD_TESTING=OFF \
-DBUILD_TOOLS=OFF \
-DBUILD_API_DOCS=OFF \
-DENABLE_SSL_SUPPORT=OFF \
-DCMAKE_INSTALL_PREFIX=${dependency_install_prefix}"
  change_dir "$src_dir/$lib/build" 1
  do_cmake_from_build_dir "$src_dir/$lib" "$cmake_params"
  disable_nonessential "$src_dir/$lib/build"
  do_make_and_make_install
  if [[ -f "librabbitmq.pc" ]]; then
    copy_path "librabbitmq.pc" "$install_pkgconfig_dir/librabbitmq.pc" "-fv"
  fi
	change_dir "$src_dir"
	fi
}
# build_libsmbclient      # config_options+= --enable-libsmbclient        # enable Samba protocol via libsmbclient [no]
build_libsmbclient() {
  if ! truthy "$disable_libsmbclient" && truthy "$enable_libsmbclient"; then
    if iswindows; then
      echo "INFO: SMB support already built into $host_platform. Seperate library not needed." >>"$LOG_FILE" && return 0
    fi
	# https://git.samba.org/samba
	local lib="libsmbclient"
	fi
}
# build_libssh            # config_options+= --enable-libssh              # enable SFTP protocol via libssh [no]
build_libssh() {
  if ! truthy "$disable_libssh" && truthy "$enable_libssh" || [[ -n "$1" ]]; then
	run_valid_function "build_openssl" 1
	# https://github.com/canonical/libssh
	local lib="libssh"
  # https://github.com/canonical/libssh
  local repo="https://github.com/canonical/libssh"
  local repo_ver="libssh-0.11.1" 
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
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
  disable_nonessential "$src_dir/$lib/build"
  do_make_and_make_install
	change_dir "$src_dir"
  add_libs_to_pkg -t="$install_pkgconfig_dir/libssh.pc" -l="-lssl -lcrypto -lcrypt32 -lws2_32 -lz -liphlpapi" -c="-DLIBSSH_STATIC"
	fi
}
# build_libtls            # config_options+= --enable-libtls              # enable LibreSSL (via libtls), needed for https support if openssl, gnutls or mbedtls is not used [no]
build_libtls() {
  if ! truthy "$disable_libtls" && truthy "$enable_libtls"; then
	# https://github.com/PowerShell/LibreSSL
	local lib="libtls"
  # https://github.com/PowerShell/LibreSSL
  local repo="https://github.com/PowerShell/LibreSSL"
  local repo_ver="V4.0.0.0"
	change_dir "$src_dir"
	do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  change_dir "$src_dir/$lib/build" 1
  local cmake_params="-DCMAKE_INSTALL_PREFIX=${dependency_install_prefix} \
-DBUILD_SHARED_LIBS=OFF \
-DLIBRESSL_APPS=OFF \
-DLIBRESSL_TESTS=OFF \
-DCMAKE_BUILD_TYPE=Release"
  do_cmake_from_build_dir "$src_dir/$lib" "$cmake_params"
  disable_nonessential "$src_dir/$lib/build"
  do_make_and_make_install
	change_dir "$src_dir"
	fi
}
# build_libzmq            # config_options+= --enable-libzmq              # enable message passing via libzmq [no]
build_libzmq() {
  if ! truthy "$disable_libzmq" && truthy "$enable_libzmq"; then
	# https://github.com/zeromq/libzmq libzmq 4.3.5
	local lib="libzmq"
  local repo="https://github.com/zeromq/libzmq"
  local repo_ver="v4.3.5"
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  export CFLAGS="-static -O3 -I$dependency_install_prefix/include -L$dependency_install_prefix/lib -Wno-incompatible-pointer-types"
  export CXXFLAGS="-DZE_MQ_STATIC -O2 -Wno-error -Wno-unknown-pragmas -I$dependency_install_prefix/include -L$dependency_install_prefix/lib"
  export LDFLAGS="-static -static-libgcc -static-libstdc++ -I$dependency_install_prefix/include -L$dependency_install_prefix/lib"
  generic_configure "--enable-static \
--disable-shared \
--without-docs \
--without-libsodium \
--disable-libunwind \
--disable-perf \
--disable-werror \
--disable-curve-keygen \
--disable-curve"' LIBS="-lpthread -lws2_32"'
  disable_nonessential "$src_dir/$lib"
  do_make_and_make_install
	change_dir "$src_dir"
  reset_cflags
  reset_cxxflags
  reset_ldflags
  add_libs_to_pkg -t="$install_pkgconfig_dir/libzmq.pc" -l="-lws2_32"
	fi
}
# build_mbedtls           # config_options+= --enable-mbedtls             # enable mbedTLS, needed for https support if openssl, gnutls or libtls is not used [no]
build_mbedtls() {
  if ! truthy "$disable_mbedtls" && truthy "$enable_mbedtls"; then
	# https://github.com/Mbed-TLS/mbedtls "v3.6.5"
	local lib="mbedtls"
  local repo="https://github.com/Mbed-TLS/mbedtls"
  local repo_ver="v3.6.5"
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  local cmake_params="-DCMAKE_INSTALL_PREFIX=${dependency_install_prefix} \
-DCMAKE_BUILD_TYPE=Release \
-DENABLE_TESTING=OFF \
-DENABLE_PROGRAMS=OFF \
-DUSE_STATIC_MBEDTLS_LIBRARY=ON \
-DUSE_SHARED_MBEDTLS_LIBRARY=OFF \
-DMBEDTLS_FATAL_WARNINGS=OFF \
-DCMAKE_C_FLAGS=\"-D__USE_MINGW_ANSI_STDIO=1\""
  generic_cmake "$cmake_params" "$src_dir/$lib"
  disable_nonessential "$src_dir/$lib"
  do_make_and_make_install
	change_dir "$src_dir"
	fi
}

# build_jni               # config_options+= --disable-jni                # enable JNI support [no]
build_jni() {
  if ! truthy "$disable_jni" && truthy "$enable_jni"; then
	echo "INFO: No jni library to compile. Library built into OS." >>"$LOG_FILE"
	echo "INFO: Only available on Android build" >>"$LOG_FILE"
	local lib="jni"
	fi
}
# build_ohcodec           # config_options+= --disable-ohcodec            # enable OpenHarmony Codec support [no]
build_ohcodec() {
  if ! truthy "$disable_ohcodec" && truthy "$enable_ohcodec"; then
	echo "INFO: No ohcodec library to compile. Library built into OS." >>"$LOG_FILE"
	echo "INFO: Only available on Harmony build" >>"$LOG_FILE"
	local lib="ohcodec"
	fi
}
# build_mediacodec        # config_options+= --disable-mediacodec         # enable Android MediaCodec support [no]
build_mediacodec() {
  if ! truthy "$disable_mediacodec" && truthy "$enable_mediacodec"; then
	echo "INFO: No mediacodec library to compile. Library built into OS." >>"$LOG_FILE"
	echo "INFO: Only available on Android build" >>"$LOG_FILE"
	local lib="mediacodec"
	fi
}
# build_mediafoundation   # config_options+= --enable-mediafoundation     # enable encoding via MediaFoundation [auto]
build_mediafoundation() {
  if ! truthy "$disable_mediafoundation" && truthy "$enable_mediafoundation"; then
  echo "INFO: No mediafoundation library to compile. Library built into OS." >>"$LOG_FILE"
  echo "WARNING: Including this library will make the binaries non-redistributable" >>"$LOG_FILE"
	echo "INFO: Only available on Windows build" >>"$LOG_FILE"
	local lib="mediafoundation"
	fi
}

# build_libdc1394         # config_options+= --enable-libdc1394           # enable IIDC-1394 grabbing using libdc1394 and libraw1394 [no]
build_libdc1394() {
  if ! truthy "$disable_libdc1394" && truthy "$enable_libdc1394"; then
	echo "Only available on Linux build" >>"$LOG_FILE"
	# https://github.com/damienfirmonte/libdc1394
	local lib="libdc1394"
    disable_library "libdc1394"
	fi
}

# build_rkmpp             # config_options+= --enable-rkmpp               # enable Rockchip Media Process Platform code [no]
build_rkmpp() {
  if ! truthy "$disable_rkmpp" && truthy "$enable_rkmpp"; then
	echo "Only available on Linux build" >>"$LOG_FILE"
	# 
	local lib="rkmpp"
    disable_library "rkmpp"
	fi
}

# build_libiec61883       # config_options+= --enable-libiec61883         # enable iec61883 via libiec61883 [no]
build_libiec61883() {
  if ! truthy "$disable_libiec61883" && truthy "$enable_libiec61883"; then
	echo "Only available on Linux build" >>"$LOG_FILE"
	# https://github.com/Mint-Fan/libiec61883
	local lib="libiec61883"
    disable_library "libiec61883"
	fi
}
# build_libv4l2           # config_options+= --enable-libv4l2             # enable libv4l2/v4l-utils [no]
build_libv4l2() {
  if ! truthy "$disable_libv4l2" && truthy "$enable_libv4l2"; then
	echo "Only available for Linux build" >>"$LOG_FILE"
	# https://git.linuxtv.org/v4l-utils
	local lib="libv4l2"
    disable_library "libv4l2"
	fi
}
# build_opencl            # config_options+= --enable-opencl              # enable OpenCL processing [no]
build_opencl() {
  if ! truthy "$disable_opencl" && truthy "$enable_opencl"; then
	# https://github.com/KhronosGroup/OpenCL-Headers
  local parentlib="opencl"
  local lib="OpenCL-Headers"
  local repo="https://github.com/KhronosGroup/OpenCL-Headers"
  local repo_ver="v2025.07.22"
	change_dir "$src_dir"
  change_dir "$src_dir/$parentlib" 1
  do_git_checkout "$repo" "$lib" "$repo_ver"
  change_dir "$src_dir/$parentlib/$lib/build" 1
  local cmake_params="-DCMAKE_INSTALL_PREFIX=${dependency_install_prefix} \
-DCMAKE_BUILD_TYPE=Release \
-DBUILD_SHARED_LIBS=OFF \
-DBUILD_TESTING=OFF \
-DOPENCL_HEADERS_BUILD_TESTING=OFF"
  do_cmake_from_build_dir "$src_dir/$parentlib/$lib" "$cmake_params"
  disable_nonessential "$src_dir/$parentlib/$lib/build"
  do_make_and_make_install
  if [[ -f "$src_dir/$parentlib/$lib/OpenCL-Headers.pc.in" ]]; then
    copy_path "$src_dir/$parentlib/$lib/OpenCL-Headers.pc.in" "$install_pkgconfig_dir/OpenCL-Headers.pc" "-fv" >>"$LOG_FILE" 2>&1
  fi
  sed -i "s|@PKGCONFIG_PREFIX@|${dependency_install_prefix}|g" "$install_pkgconfig_dir/OpenCL-Headers.pc"
  sed -i "s|@OPENCL_INCLUDEDIR_PC@|\${prefix}/include|g" "$install_pkgconfig_dir/OpenCL-Headers.pc"
  # https://github.com/KhronosGroup/OpenCL-ICD-Loader
  local lib="OpenCL-ICD-Loader"
  local repo="https://github.com/KhronosGroup/OpenCL-ICD-Loader"
  local repo_ver="v2025.07.22"
  change_dir "$src_dir/$parentlib"
  do_git_checkout "$repo" "$lib" "$repo_ver"
  change_dir "$src_dir/$parentlib/$lib/build" 1
  sed -i 's|loader/windows/OpenCL.rc)|)|g' "$src_dir/$parentlib/$lib/CMakeLists.txt"
  local cmake_params="-DCMAKE_INSTALL_PREFIX=${dependency_install_prefix} \
-DCMAKE_BUILD_TYPE=Release \
-DBUILD_SHARED_LIBS=OFF \
-DBUILD_TESTING=OFF \
-DOPENCL_ICD_LOADER_BUILD_SHARED_LIBS=OFF \
-DOPENCL_ICD_LOADER_BUILD_TESTING=OFF"
  do_cmake_from_build_dir "$src_dir/$parentlib/$lib" "$cmake_params"
  disable_nonessential "$src_dir/$parentlib/$lib/build"
  do_make_and_make_install
	change_dir "$src_dir"
  add_libs_to_pkg -t="$install_pkgconfig_dir/OpenCL.pc" -l="-lcfgmgr32 -lole32"
  if [[ -f "$dependency_install_prefix/lib/OpenCL.a" ]]; then
    mv -f "$dependency_install_prefix/lib/OpenCL.a" "$dependency_install_prefix/lib/libOpenCL.a"
  fi
	fi
}
# build_libtensorflow     # config_options+= --enable-libtensorflow       # enable TensorFlow as a DNN module backend for DNN based filters like sr [no]
build_libtensorflow() {
  if ! truthy "$disable_libtensorflow" && truthy "$enable_libtensorflow" && [[ $bits_target == 64 ]]; then
    local base_lib="libtensorflow"
    local lib="$base_lib-$host_name"
    local repo_ver="2.18.0"
    local repo="https://storage.googleapis.com/tensorflow/versions/2.18.0/libtensorflow-cpu-windows-x86_64.zip"
    local subdir="cpu"
    pick_gpu_support
    if truthy "$gpu_support"; then
      pick_gpu_type
      subdir=$gpu_type
      if [[ $subdir == "rocm" ]]; then
        echo -e "WARNING: [disabled] $lib ROCm support is not availbale on Windows" >>"$LOG_FILE"
        disable_library "libtensorflow"
        return
      else
        local repo="https://storage.googleapis.com/tensorflow/libtensorflow/libtensorflow-gpu-windows-x86_64-2.10.0.zip"
        repo_ver="2.10.0"
        echo "WARNING: uninstalling cpu $base_lib if installed." >> "$LOG_FILE"
        uninstall_manifest "$install_pkgconfig_dir/${lib}_cpu_manifest" > >(redirect_output) 2>&1
      fi
    fi

    local manifest="$work_dir/pkgconfig/${lib}_${subdir}_manifest"
    [[ ! -f "$manifest" ]] && touch "$manifest"
    
    change_dir "$src_dir"
    local touch_name=$(get_small_touchfile_name "${host_name}_installed" "$repo")
    
    truthy "$build_force" && remove_path -rf "$src_dir/$lib/$subdir"
    if [[ -f "$manifest" && ! -f "$src_dir/$lib/$subdir/$touch_name" ]]; then
      [[ -d "$src_dir/$lib" ]] && reset_touch "$src_dir/$lib" "${host_name}_installed*.touch"
      uninstall_manifest "$manifest" >>"$LOG_FILE" 2>&1
    fi

    change_dir "$src_dir/$lib" 1

    if [ ! -f "$src_dir/$lib/$subdir/$touch_name" ]; then
        download_and_unpack_file "$repo" "$src_dir/$lib/$subdir"
        
        install_prebuilt_binary \
            -n="$base_lib" -v="$repo_ver" \
            -s="$src_dir/$lib/$subdir" \
            -I="include" \
            -L="lib" \
            -B="lib" \
            -m="$manifest" \
            -d="TensorFlow C Library ($subdir)" || exit_message 1 "could not install $base_lib"

        change_dir "$src_dir/$lib/$subdir"
        create_touch_file 0 "$touch_name"
        echo "$src_dir/$lib/$subdir/$touch_name" >>"$manifest"
    fi
  fi
}
# build_libopenvino       # config_options+= --enable-libopenvino         # enable OpenVINO as a DNN module backend for DNN based filters like dnn_processing [no]
build_libopenvino() {
  if ! truthy "$disable_libopenvino" && truthy "$enable_libopenvino" && [[ $bits_target == 64 ]]; then
    run_valid_function "build_cpuinfo"
    local lib_name="libopenvino"
    local repo_ver="2025.4.0"
    local repo="https://storage.openvinotoolkit.org/repositories/openvino/packages/2025.4/windows/openvino_toolkit_windows_2025.4.0.20398.8fdad55727d_x86_64.zip"
    local lib="$lib_name-$host_name"

    local manifest="$work_dir/pkgconfig/${lib}_manifest"
    [[ ! -f "$manifest" ]] && touch "$manifest"

    change_dir "$src_dir"
    
    local touch_name=$(get_small_touchfile_name "${host_name}_installed" "$repo")
    
    truthy "$build_force" && remove_path -rf "$src_dir/$lib"
    if [[ -f "$manifest" && ! -f "$src_dir/$lib/$touch_name" ]]; then
        [[ -d "$src_dir/$lib" ]] && reset_touch "$src_dir/$lib" "${host_name}_installed*.touch"
        uninstall_manifest "$manifest" >>"$LOG_FILE" 2>&1
    fi

    if [ ! -f "$src_dir/$lib/$touch_name" ]; then
        download_and_unpack_file "$repo" "$lib"
        change_dir "$src_dir/$lib"
        # 1. Install Main OpenVINO
        install_prebuilt_binary \
            -n="openvino" -v="$repo_ver" \
            -s="$src_dir/$lib" \
            -I="runtime/include" \
            -L="runtime/lib/intel64/Release" \
            -B="runtime/bin/intel64/Release" \
            -m="$manifest" \
            -d="OpenVINO Toolkit" || exit_message 1 "could not install $lib_name"
        # 2. Install TBB Dependency
        install_prebuilt_binary \
            -n="tbb" -v="$repo_ver" \
            -s="$src_dir/$lib" \
            -I="runtime/3rdparty/tbb/include" \
            -L="runtime/3rdparty/tbb/lib" \
            -B="runtime/3rdparty/tbb/bin" \
            -m="$manifest" \
            -d="Threading Building Blocks for OpenVINO" || exit_message 1 "could not install $lib_name"
        create_touch_file 0 "$touch_name"
        echo "$src_dir/$lib/$touch_name" >>"$manifest"
        # patch winodws BOOLEAN conflict
        if [[ -f "$dependency_install_prefix/include/openvino/c/openvino.h" ]]; then
        sed -i 's/^#define BOOLEAN OV_BOOLEAN/\/\/ #define BOOLEAN OV_BOOLEAN/g' "$dependency_install_prefix/include/openvino/c/openvino.h"
        fi
        if [[ -f "$dependency_install_prefix/include/openvino/c/ov_common.h" ]]; then
        sed -i -E 's/^([[:space:]]*)BOOLEAN,/\1OV_BOOLEAN,/g' "$dependency_install_prefix/include/openvino/c/ov_common.h"
        fi
    fi
    add_libs_to_pkg -t="$install_pkgconfig_dir/libout123.pc" -l="-lwinmm"
  fi
}
# build_libtorch          # config_options+= --enable-libtorch            # enable Torch as one DNN backend [no]
build_libtorch() {
  if ! truthy "$disable_libtorch" && truthy "$enable_libtorch" && [[ $bits_target == 64 ]]; then
    # https://github.com/pytorch/pytorch # compiling from source fails and is complicated. 
    # echo -e "WARNING: [disabled] Using $lib may cause segmentation faults due to ABI mismatch (mingw vs mscv)" >>"$LOG_FILE"
    local lib_name="libtorch"
    local lib="$lib_name-$host_name"
    local repo_ver="2.9.1"
    local repo="https://download.pytorch.org/libtorch/cpu/libtorch-win-shared-with-deps-2.9.1%2Bcpu.zip"
    local subdir=cpu
    pick_gpu_support
    if truthy "$gpu_support"; then
      pick_gpu_type
      subdir=$gpu_type
      if [[ $subdir == "rocm" ]]; then
        echo -e "WARNING: [disabled] $lib ROCm support is not availbale on Windows" >>"$LOG_FILE"
        disable_library "libtorch"
        return
      else
        local repo="https://download.pytorch.org/libtorch/cu130/libtorch-win-shared-with-deps-2.9.1%2Bcu130.zip"
        echo "WARNING: uninstalling cpu libtorch if installed." >> "$LOG_FILE"
        uninstall_manifest "$install_pkgconfig_dir/${lib}_cpu_manifest" > >(redirect_output) 2>&1
      fi
    fi

    local manifest="$work_dir/pkgconfig/${lib}_${subdir}_manifest"
    [[ ! -f "$manifest" ]] && touch "$manifest"
    
    change_dir "$src_dir"
    local touch_name=$(get_small_touchfile_name "${host_name}_installed" "$repo")
    
    truthy "$build_force" && remove_path -rf "$src_dir/$lib/$subdir"
    if [[ -f "$manifest" && ! -f "$src_dir/$lib/$subdir/$touch_name" ]]; then
      [[ -d "$src_dir/$lib" ]] && reset_touch "$src_dir/$lib" "${host_name}_installed*.touch"
      uninstall_manifest "$manifest" >>"$LOG_FILE" 2>&1
    fi

    change_dir "$src_dir/$lib" 1

    if [ ! -f "$src_dir/$lib/$subdir/$touch_name" ]; then
        download_and_unpack_file "$repo" "$src_dir/$lib/$subdir"
        
        install_prebuilt_binary \
            -n="$lib_name" -v="$repo_ver" \
            -s="$src_dir/$lib/$subdir" \
            -I="include" \
            -L="lib" \
            -B="lib" \
            -m="$manifest" \
            -d="PyTorch Library ($subdir)" || exit_message 1 "could not install libtensorflow"

        change_dir "$src_dir/$lib/$subdir"
        create_touch_file 0 "$touch_name"
        echo "$src_dir/$lib/$subdir/$touch_name" >>"$manifest"
    fi
	fi
}

# build_lcms2             # config_options+= --enable-lcms2               # enable ICC profile support via LittleCMS 2 [no]
build_lcms2() {
  if ! truthy "$disable_lcms2" && truthy "$enable_lcms2"; then
	# https://github.com/mm2/Little-CMS
  activate_meson
	local lib="lcms2"
  local repo_ver="lcms2.17"
  local repo="https://github.com/mm2/Little-CMS"
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
	local meson_options="-Dtests=disabled -Dutils=false"
	generic_meson "$meson_options"
	do_ninja_and_ninja_install
	change_dir "$src_dir"
	fi
}

build_spirv_headers() {
  local lib="SPIRV-Headers"
  local repo="https://github.com/KhronosGroup/SPIRV-Headers"
  local repo_ver="vulkan-sdk-1.4.328.1"
  change_dir "$src_dir/$lib" 1
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  local cmake_params="-DCMAKE_INSTALL_PREFIX=${dependency_install_prefix} \
-DCMAKE_BUILD_TYPE=Release \
-DBUILD_SHARED_LIBS=OFF \
-DSPIRV_HEADERS_SKIP_EXAMPLES=ON"
  change_dir "$src_dir/$lib/build" 1
  do_cmake_from_build_dir "$src_dir/$lib" "$cmake_params"
  disable_nonessential "$src_dir/$lib/build"
  do_make_and_make_install
  change_dir "$src_dir"
}
build_spirv_tools() {
  run_valid_function "build_spirv_tools"
  local lib="SPIRV-Tools"
  local repo="https://github.com/KhronosGroup/SPIRV-Tools"
  local repo_ver="v2025.4"
  change_dir "$src_dir/$lib"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  local cmake_params="-DCMAKE_INSTALL_PREFIX=${dependency_install_prefix} \
-DCMAKE_BUILD_TYPE=Release \
-DBUILD_SHARED_LIBS=OFF \
-DSPIRV_SKIP_TESTS=ON \
-DSPIRV_WERROR=OFF \
-DSPIRV_SKIP_EXECUTABLES=ON \
-DSPIRV-Headers_SOURCE_DIR=${dependency_install_prefix}"
  change_dir "$src_dir/$lib/build" 1
  do_cmake_from_build_dir "$src_dir/$lib" "$cmake_params"
  disable_nonessential "$src_dir/$lib/build"
  do_make_and_make_install
  change_dir "$src_dir"
}
# build_libglslang        # config_options+= --enable-libglslang          # enable GLSL->SPIRV compilation via libglslang [no]
build_libglslang() {
  if ! truthy "$disable_libglslang" && truthy "$enable_libglslang"; then
  # https://github.com/KhronosGroup/SPIRV-Headers
  run_valid_function "build_spirv_tools"
	change_dir "$src_dir"
  	# https://github.com/KhronosGroup/glslang
	local lib="libglslang"
  local repo="https://github.com/KhronosGroup/glslang"
  local repo_ver="Release 16.1.0"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
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
  change_dir "$src_dir/$lib/build" 1
  do_cmake_from_build_dir "$src_dir/$lib" "$cmake_params"
  do_make_and_make_install
  cat > "$install_pkgconfig_dir/glslang.pc" <<EOF
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

# build_libklvanc         # config_options+= --enable-libklvanc           # enable Kernel Labs VANC processing [no]
build_libklvanc() {
  if ! truthy "$disable_libklvanc" && truthy "$enable_libklvanc"; then
	# https://github.com/stoth68000/libklvanc
	local lib="libklvanc"
  local repo="https://github.com/stoth68000/libklvanc"
  local repo_ver="vid.obe.1.6.0"
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  sed -i.bak 's#<sys/errno.h>#<errno.h>#g' src/libklvanc/vanc.h src/libklvanc/vanc-packets.h src/core-private.h src/libklvanc/vanc-lines.h
  generic_configure "--enable-static \
--disable-shared"
  disable_nonessential "$src_dir/$lib"
  change_dir "$src_dir/$lib/src"
  do_make_and_make_install
  cat > "$install_pkgconfig_dir/libklvanc.pc" <<EOF
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
    change_dir "$src_dir/$lib"
	change_dir "$src_dir"
	fi
}
# build_liblc3            # config_options+= --enable-liblc3              # enable LC3 de/encoding via liblc3 [no]
build_liblc3() {
  if ! truthy "$disable_liblc3" && truthy "$enable_liblc3"; then
  activate_meson
	# https://github.com/google/liblc3
	local lib="liblc3"
  local repo="https://github.com/google/liblc3"
  local repo_ver="v1.1.3"
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
	local meson_options="-Dtools=false -Dpython=false"
	generic_meson "$meson_options"
	do_ninja_and_ninja_install
  if [[ -f "$install_pkgconfig_dir/lc3.pc" ]]; then
    sed -i "s|^Libs: -L\${libdir}.*|Libs: -Wl,--whole-archive $dependency_install_prefix/lib/liblc3.a -Wl,--no-whole-archive|g" "$install_pkgconfig_dir/lc3.pc"
  fi
	change_dir "$src_dir"
	fi
}
# build_liblcevc_dec      # config_options+= --enable-liblcevc-dec        # enable LCEVC decoding via liblcevc-dec [no]
build_liblcevc_dec() {
  if ! truthy "$disable_liblcevc_dec" && truthy "$enable_liblcevc_dec"; then
	# https://github.com/v-novaltd/LCEVCdec
	local lib="liblcevc"
  local repo="https://github.com/v-novaltd/LCEVCdec"
  local repo_ver="4.0.4"
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  change_dir "$src_dir/$lib/build" 1
	local cmake_params="-DCMAKE_BUILD_TYPE=Release \
-DBUILD_SHARED_LIBS=OFF \
-DVN_SDK_EXECUTABLES=OFF \
-DVN_SDK_UNIT_TESTS=OFF \
-DVN_SDK_DOCS=OFF \
-DVN_SDK_SAMPLE_SOURCE=OFF \
-DVN_SDK_PIPELINE_VULKAN=OFF \
-DVN_SDK_PIPELINE_LEGACY=OFF"
	do_cmake_from_build_dir "$src_dir/$lib" "$cmake_params"
  # disable_nonessential "$src_dir/$lib"
	do_make_and_make_install
	change_dir "$src_dir"
  if [[ -f "$install_pkgconfig_dir/lcevc_dec_utility.pc" ]]; then
    remove_path -f "$install_pkgconfig_dir/lcevc_dec_utility.pc"
  fi
	fi
}
# build_liboapv           # config_options+= --enable-liboapv             # enable APV encoding via liboapv [no]
build_liboapv() {
  if ! truthy "$disable_liboapv" && truthy "$enable_liboapv"; then
	# https://github.com/AcademySoftwareFoundation/openapv
	local lib="liboapv"
  local repo="https://github.com/AcademySoftwareFoundation/openapv"
  local repo_ver="v0.2.0.4"
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  change_dir "$src_dir/$lib/build" 1
	local cmake_params=" -DCMAKE_TOOLCHAIN_FILE=$(get_generic_windows_cmake_toolchain) \
-DCMAKE_BUILD_TYPE=Release \
-DOAPV_BUILD_APPS=OFF \
-DOAPV_BUILD_STATIC_LIB=ON \
-DOAPV_BUILD_SHARED_LIB=OFF \
-DCMAKE_INSTALL_LIBDIR=\"${dependency_install_prefix}/lib\" \
-DCMAKE_INSTALL_INCLUDEDIR=\"${dependency_install_prefix}/include\" \
-DENABLE_TESTS=OFF"
	do_cmake_from_build_dir "$src_dir/$lib" "$cmake_params"
  disable_nonessential "$src_dir/$lib/build"
	do_make_and_make_install
  sed -i 's|libdir=.*|libdir=\${prefix}/lib/oapv|g' "$install_pkgconfig_dir/oapv.pc"
  sed -i 's|includedir=.*|includedir=\${prefix}/include|g' "$install_pkgconfig_dir/oapv.pc"
	change_dir "$src_dir"
	fi
}
# build_libqrencode       # config_options+= --enable-libqrencode         # enable QR encode generation via libqrencode [no]
build_libqrencode() {
  if ! truthy "$disable_libqrencode" && truthy "$enable_libqrencode"; then
	# https://github.com/fukuchi/libqrencode
	local lib="libqrencode"
  local repo="https://github.com/fukuchi/libqrencode"
  local repo_ver="v4.1.1"
	change_dir "$src_dir"
	do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
	change_dir "$src_dir/$lib/build" 1
	local cmake_params="-DCMAKE_BUILD_TYPE=Release \
-DWITH_TOOLS=NO \
-DWITH_TESTS=NO \
-DWITHOUT_PNG=YES \
-DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
-DBUILD_SHARED_LIBS=NO"
	do_cmake_from_build_dir "$src_dir/$lib" "$cmake_params"
  disable_nonessential "$src_dir/$lib/build"
	do_make_and_make_install
	change_dir "$src_dir"
	fi
}
# build_libquirc          # config_options+= --enable-libquirc            # enable QR decoding via libquirc [no]
build_libquirc() {
  if ! truthy "$disable_libquirc" && truthy "$enable_libquirc"; then
	# https://github.com/dlbeer/quirc
	local lib="libquirc"
  local repo="https://github.com/dlbeer/quirc"
  local repo_ver="master"
	change_dir "$src_dir"
	do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
	change_dir "$src_dir/$lib" 1
	export TOOLCHAIN_PATH=$toolchain_bin_path
  # path to remove demo app build because it requires some unnecessary dependencies
	[[ ! -f "Makefile.bak" ]] && copy_path "Makefile" "Makefile.bak" "-fv" >>"$LOG_FILE" 2>&1
  apply_patch "$PATCHDIR/libquirc_Makefile.patch"
	do_make "libquirc.a CC=${CC} AR=${AR} AS=${AS} CXX=${CXX} STRIP=${STRIP} RANLIB=${RANLIB} LDFLAGS=\"$LDFLAGS -static\" PREFIX=${dependency_install_prefix}"
  disable_nonessential "$src_dir/$lib"
	do_make_install
	change_dir "$src_dir"
	fi
}

# build_librsvg           # config_options+= --enable-librsvg             # enable SVG rasterization via librsvg [no]
build_librsvg() {
  if ! truthy "$disable_librsvg" && truthy "$enable_librsvg"; then
	run_valid_function "build_cairo"
	run_valid_function "build_pango"
  activate_meson
# 	# https://github.com/GNOME/librsvg
	local lib="librsvg"
  local repo="https://gitlab.gnome.org/GNOME/librsvg"
  local repo_ver="2.61.3"
	change_dir "$src_dir"
	do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
	change_dir "$src_dir/$lib"
	local meson_options="-Ddocs=disabled \
-Dintrospection=disabled \
-Dvala=disabled \
-Davif=disabled \
-Dpixbuf-loader=disabled \
-Dtests=false \
-Drsvg-convert=disabled \
-Dc_args=\"-DCAIRO_WIN32_STATIC_BUILD -DGLIB_STATIC_COMPILATION\" \
-Dcpp_args=\"-DCAIRO_WIN32_STATIC_BUILD -DGLIB_STATIC_COMPILATION\" \
-Dc_link_args=\"-lssp -lmsvcrt -lstdc++\" \
-Dcpp_link_args=\"-lssp -lmsvcrt -lstdc++\""
  if [[ $bits_target == 64 ]]; then
    meson_options+=" -Dtriplet=x86_64-pc-windows-gnu"
  else
    meson_options+=" -Dtriplet=i386-pc-windows-gnu"
  fi
	generic_meson "$meson_options"
  disable_nonessential "$src_dir/$lib/build"
	do_ninja_and_ninja_install
	change_dir "$src_dir"
	fi
}

# build_libuavs3d         # config_options+= --enable-libuavs3d           # enable AVS3 decoding via libuavs3d [no]
build_libuavs3d() {
  if ! truthy "$disable_libuavs3d" && truthy "$enable_libuavs3d"; then
	local lib="libuavs3d"
  local repo="https://github.com/uavs3/uavs3d"
  local repo_ver="master"
	change_dir "$src_dir"
	do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  if [[ -f "$src_dir/$lib/version.sh" ]]; then
    chmod -R a+rwx "$src_dir/$lib/version.sh"
    eval "$src_dir/$lib/version.sh" > >(redirect_output) 2>&1
  fi
	change_dir "$src_dir/$lib/build" 1
	local cmake_params="-DCOMPILE_10BIT=0 \
-DBUILD_SHARED_LIBS=0 \
-DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
-DCMAKE_BUILD_TYPE=Release"
	do_cmake_from_build_dir "$src_dir/$lib" "$cmake_params"
  disable_nonessential "$src_dir/$lib/build"
	do_make_and_make_install
	change_dir "$src_dir"
	fi
}
# build_vapoursynth       # config_options+= --enable-vapoursynth         # enable VapourSynth demuxer [no]
build_vapoursynth() {
  if ! truthy "$disable_vapoursynth" && truthy "$enable_vapoursynth"; then
	# https://github.com/vapoursynth/vapoursynth
	run_valid_function "build_libzimg" 1
  activate_meson
  local lib="vapoursynth"
  local repo="https://github.com/vapoursynth/vapoursynth"
  local repo_ver="R73"
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  local py_root="$src_dir/$lib/python_dep"
  local py_inc="$py_root/tools/include"
  local py_lib_dir="$py_root/tools"
  download_and_unpack_file "https://globalcdn.nuget.org/packages/python.3.12.0.nupkg" "python_dep"
	[[ ! -f "src/vsscript/vsscript.cpp.bak" ]] && copy_path "src/vsscript/vsscript.cpp" "src/vsscript/vsscript.cpp.bak" "-fv" >>"$LOG_FILE" 2>&1
	sed -i 's/#include <Windows.h>/#include <windows.h>/' src/vsscript/vsscript.cpp
  # patch to load windows python dependencies
	[[ ! -f "meson.build.bak" ]] && copy_path "meson.build" "meson.build.bak" "-fv" >>"$LOG_FILE" 2>&1
  apply_patch "$PATCHDIR/vapoursynth_meson_build.patch"
	change_dir "$src_dir/$lib"
	local meson_options="-Db_lto=false \
-Denable_vspipe=false \
-Denable_python_module=false \
-Dc_args=\"$CFLAGS -I$py_inc\" \
-Dcpp_args=\"$CXXFLAGS -I$py_inc\" \
-Dcpp_link_args=\"$LDFLAGS -L$py_lib_dir -lpython312 -lpython3\""
	generic_meson "$meson_options"
	disable_nonessential "$src_dir/$lib"
  do_ninja_and_ninja_install
	change_dir "$src_dir"
  reset_ldflags
  local pkg_file="$install_pkgconfig_dir/vapoursynth-script.pc"
  if [ -f "$pkg_file" ]; then
    sed -i -e 's/^Libs:.*/Libs: -L\${libdir} -lvapoursynth-script/' \
      -e '/^Libs.private:.*/d' \
      "$pkg_file"
    echo "Libs.private: -L$py_lib_dir -lpython312 -lpython3" >> "$pkg_file"
  fi
	fi
}

# build_metal             # config_options+= --disable-metal              # disable Apple Metal framework [autodetect]
build_metal() {
  if ! truthy "$disable_metal" && truthy "$enable_metal"; then
    echo "WARNING: Including this library will make the binaries non-redistributable" >>"$LOG_FILE"
    disable_library "metal"
    echo "Only available on Apple build" >>"$LOG_FILE"
  fi
}
# build_sndio             # config_options+= --disable-sndio              # disable sndio support [autodetect]
build_sndio() {
  if ! truthy "$disable_sndio" && truthy "$enable_sndio"; then
    echo "WARNING: Library does not have MinGW/windows support. Unable to enable on Windows currently." >>"$LOG_FILE"
    disable_library "sndio"
    # https://github.com/ratchov/sndio
    local lib="sndio"
  fi
}
# build_schannel          # config_options+= --disable-schannel           # disable SChannel SSP, needed for TLS support on Windows if openssl and gnutls are not used [autodetect]
build_schannel() {
  if ! truthy "$disable_schannel" && truthy "$enable_schannel"; then
    echo "WARNING: Including this library will make the binaries non-redistributable" >>"$LOG_FILE"
    echo "Only available on Windows build" >>"$LOG_FILE"
  fi
}
# build_securetransport   # config_options+= --disable-securetransport    # disable Secure Transport, needed for TLS support on OSX if openssl and gnutls are not used [autodetect]
build_securetransport() {
  if ! truthy "$disable_securetransport" && truthy "$enable_securetransport"; then
    echo "WARNING: Including this library will make the binaries non-redistributable" >>"$LOG_FILE"
    disable_library "securetransport"
    echo "Only available on Apple build" >>"$LOG_FILE"
  fi
}
# build_xlib              # config_options+= --disable-xlib               # disable xlib [autodetect]
build_xlib() {
  if ! truthy "$disable_xlib" && truthy "$enable_xlib"; then
    echo "Only available on Linux build" >>"$LOG_FILE"
    disable_library "xlib"
    # https://github.com/mirror/libX11
  fi
}
# build_v4l2_m2m          # config_options+= --disable-v4l2-m2m           # disable V4L2 mem2mem code [autodetect]
build_v4l2_m2m() {
  if ! truthy "$disable_v4l2_m2m" && truthy "$enable_v4l2_m2m"; then
    echo "Only available on Linux build" >>"$LOG_FILE"
    disable_library "v4l2-m2m"
  fi
}
# build_vaapi             # config_options+= --disable-vaapi              # disable Video Acceleration API (mainly Unix/Intel) code [autodetect]
build_vaapi() {
  if ! truthy "$disable_vaapi" && truthy "$enable_vaapi"; then
    echo "Only available on Linux build" >>"$LOG_FILE"
    # https://github.com/intel/libva
    disable_library "vaapi"
  fi
}
# build_vdpau             # config_options+= --disable-vdpau              # disable Nvidia Video Decode and Presentation API for Unix code [autodetect]
build_vdpau() {
  if ! truthy "$disable_vdpau" && truthy "$enable_vdpau"; then
    echo "WARNING: Including this library will make the binaries non-redistributable" >>"$LOG_FILE"
    echo "Only available on Linux build" >>"$LOG_FILE"
    # https://gitlab.freedesktop.org/vdpau/libvdpau
    disable_library "vdpau"
  fi
}
# build_videotoolbox      # config_options+= --disable-videotoolbox       # disable VideoToolbox code [autodetect]
build_videotoolbox() {
  if ! truthy "$disable_videotoolbox" && truthy "$enable_videotoolbox"; then
    echo "WARNING: Including this library will make the binaries non-redistributable" >>"$LOG_FILE"
    echo "Only available on Apple build" >>"$LOG_FILE"
    disable_library "videotoolbox"
  fi
}
# build_alsa              # config_options+= --disable-alsa               # disable ALSA support [autodetect]
build_alsa() {
  if ! truthy "$disable_alsa" && truthy "$enable_alsa"; then
    echo "Only available on Linux build" >>"$LOG_FILE"
    # https://github.com/alsa-project/alsa-lib
    disable_library "alsa"
  fi
}
# build_appkit            # config_options+= --disable-appkit             # disable Apple AppKit framework [autodetect]
build_appkit() {
  if ! truthy "$disable_appkit" && truthy "$enable_appkit"; then
    echo "WARNING: Including this library will make the binaries non-redistributable" >>"$LOG_FILE"
    echo "Only available on Apple build" >>"$LOG_FILE"
    disable_library "appkit"
  fi
}
# build_audiotoolbox      # config_options+= --disable-audiotoolbox       # disable Apple AudioToolbox code [autodetect]
build_audiotoolbox() {
  if ! truthy "$disable_audiotoolbox" && truthy "$enable_audiotoolbox"; then
    echo "WARNING: Including this library will make the binaries non-redistributable" >>"$LOG_FILE"
    echo "Only available on Apple build" >>"$LOG_FILE"
    disable_library "audiotoolbox"
  fi
}
# build_avfoundation      # config_options+= --disable-avfoundation       # disable Apple AVFoundation framework [autodetect]
build_avfoundation() {
  if ! truthy "$disable_avfoundation" && truthy "$enable_avfoundation"; then
    echo "WARNING: Including this library will make the binaries non-redistributable" >>"$LOG_FILE"
    echo "Only available on Apple build" >>"$LOG_FILE"
    disable_library "avfoundation"
  fi
}

# build_coreimage         # config_options+= --disable-coreimage          # disable Apple CoreImage framework [autodetect]
build_coreimage() {
  if ! truthy "$disable_coreimage" && truthy "$enable_coreimage"; then
    echo "WARNING: Including this library will make the binaries non-redistributable" >>"$LOG_FILE"
    disable_library "coreimage"
    echo "Only available on Apple build" >>"$LOG_FILE"
  fi
}
# build_cuda_llvm         # config_options+= --disable-cuda-llvm          # disable CUDA compilation using clang [autodetect]
build_cuda_llvm() {
  if ! truthy "$disable_cuda_llvm" && truthy "$enable_cuda_llvm"; then
    echo "WARNING: Including this library will make the binaries non-redistributable" >>"$LOG_FILE"
  fi
}
build_libnvvm() {
    [[ "$bits_target" == "32" ]] && return
    local repo="https://developer.download.nvidia.com/compute/cuda/redist/libnvvm/windows-x86_64/libnvvm-windows-x86_64-13.1.80-archive.zip"
    local base_lib="libnvvm"
    local lib="$base_lib-$host_name"
    local repo_ver="13.1.80"

    local manifest="$work_dir/pkgconfig/${lib}_manifest"
    [[ ! -f "$manifest" ]] && touch "$manifest"
    
    change_dir "$src_dir"
    local touch_name=$(get_small_touchfile_name "${host_name}_installed" "$repo")
    
    truthy "$build_force" && remove_path -rf "$src_dir/$lib"
    if [[ -f "$manifest" && ! -f "$src_dir/$lib/$touch_name" ]]; then
      [[ -d "$src_dir/$lib" ]] && reset_touch "$src_dir/$lib" "${host_name}_installed*.touch"
      uninstall_manifest "$manifest" >>"$LOG_FILE" 2>&1
    fi

    if [ ! -f "$src_dir/$lib/$touch_name" ]; then
        download_and_unpack_file "$repo" "$src_dir/$lib"
        change_dir "$src_dir/$lib"
        install_prebuilt_binary -n="$base_lib" -v="$repo_ver" \
            -s="$src_dir/$lib/nvvm" \
            -m="$manifest" \
            -I="include" -L="lib" -B="bin" || exit_message 1 "could not install $base_lib"
        install_prebuilt_binary -n="libdevice" -v="$repo_ver" \
            -s="$src_dir/$lib/nvvm" \
            -m="$manifest" \
            -L="libdevice" || exit_message 1 "could not install $base_lib"
        create_touch_file 0 "$touch_name"
        echo "$src_dir/$lib/$touch_name" >>"$manifest"
    fi
}

build_cuda_cudart() {
    [[ "$bits_target" == "32" ]] && return
    local repo="https://developer.download.nvidia.com/compute/cuda/redist/cuda_cudart/windows-x86_64/cuda_cudart-windows-x86_64-13.1.80-archive.zip"
    local base_lib="cuda-cudart"
    local lib="$base_lib-$host_name"

    local manifest="$work_dir/pkgconfig/${lib}_manifest"
    [[ ! -f "$manifest" ]] && touch "$manifest"

    change_dir "$src_dir"
    local touch_name=$(get_small_touchfile_name "${host_name}_installed" "$repo")
    
    truthy "$build_force" && remove_path -rf "$src_dir/$lib"
    if [[ -f "$manifest" && ! -f "$src_dir/$lib/$touch_name" ]]; then
      [[ -d "$src_dir/$lib" ]] && reset_touch "$src_dir/$lib" "${host_name}_installed*.touch"
      uninstall_manifest "$manifest" >>"$LOG_FILE" 2>&1
    fi

    if [ ! -f "$src_dir/$lib/$touch_name" ]; then
        download_and_unpack_file "$repo" "$src_dir/$lib"
        change_dir "$src_dir/$lib"
        
        install_prebuilt_binary -n="$base_lib" -v="13.1.80" \
            -s="$src_dir/$lib" \
            -m="$manifest" \
            -I="include" -L="lib" -B="bin" || exit_message 1 "could not install $base_lib"

        create_touch_file 0 "$touch_name"
        echo "$src_dir/$lib/$touch_name" >>"$manifest"
    fi
}

# cuda_crt has NO binaries, only headers.
build_cuda_crt() {
    [[ "$bits_target" == "32" ]] && return
    local repo="https://developer.download.nvidia.com/compute/cuda/redist/cuda_crt/windows-x86_64/cuda_crt-windows-x86_64-13.1.80-archive.zip"
    local base_lib="cuda-crt"
    local lib="$base_lib-$host_name"

    local manifest="$work_dir/pkgconfig/${lib}_manifest"
    [[ ! -f "$manifest" ]] && touch "$manifest"

    change_dir "$src_dir"
    local touch_name=$(get_small_touchfile_name "${host_name}_installed" "$repo")
    
    truthy "$build_force" && remove_path -rf "$src_dir/$lib"
    if [[ -f "$manifest" && ! -f "$src_dir/$lib/$touch_name" ]]; then
      [[ -d "$src_dir/$lib" ]] && reset_touch "$src_dir/$lib" "${host_name}_installed*.touch"
      uninstall_manifest "$manifest" >>"$LOG_FILE" 2>&1
    fi

    if [ ! -f "$src_dir/$lib/$touch_name" ]; then
        download_and_unpack_file "$repo" "$src_dir/$lib"
        change_dir "$src_dir/$lib"
        # Only headers
        install_prebuilt_binary -n="$base_lib" -v="13.1.80" \
            -m="$manifest" \
            -s="$src_dir/$lib" \
            -I="include" || exit_message 1 "could not install $base_lib"
        create_touch_file 0 "$touch_name"
        echo "$src_dir/$lib/$touch_name" >>"$manifest"
    fi
}
build_cuda_nvcc_native() {
  if ! truthy "$disable_cuda_nvcc" && truthy "$enable_cuda_nvcc"; then
    if [[ "$bits_target" != "32" ]]; then
      local base_lib="cuda-nvcc"
      local lib_native="$base_lib-linux-$host_arch"
      local lib="$base_lib-$host_name"
      local repo_ver="13.1.88" 
      local repo="https://developer.download.nvidia.com/compute/cuda/redist/cuda_nvcc/linux-x86_64/cuda_nvcc-linux-x86_64-13.1.80-archive.tar.xz"
      
      local manifest="$work_dir/pkgconfig/${base_lib}-${base_lib}-${host_name}_${base_lib}-linux-${host_arch}_manifest"
      [[ ! -f "$manifest" ]] && touch "$manifest"
      
      change_dir "$src_dir"
      local touch_name=$(get_small_touchfile_name "linux-${host_arch}_installed" "$repo")\

      truthy "$build_force" && remove_path -rf "$src_dir/$lib_native"
      # Force Rebuild Logic
      if [[ -f "$manifest" && ! -f "$src_dir/$lib_native/$touch_name" ]]; then
        [[ -d "$src_dir/$lib_native" ]] && reset_touch "$src_dir/$lib_native" "linux-${host_arch}_installed*.touch"
        uninstall_manifest "$manifest" >>"$LOG_FILE" 2>&1
      fi
      if [ ! -f "$src_dir/$lib_native/$touch_name" ]; then
        download_and_unpack_file "$repo" "$src_dir/$lib_native"
        change_dir "$src_dir/$lib_native"
        copy_and_link "$dependency_install_prefix/bin" "$dependency_install_prefix/bin" "$src_dir/$lib_native/bin/"* 1>> "$manifest" 2>>"$LOG_FILE" || exit_message 1 "build_cuda_nvcc: could not install $lib bins"
        create_touch_file 0 "$touch_name"
        echo "$src_dir/$lib/$touch_name" >>"$manifest"
      fi
    else
      echo -e "WARNING: 32bit not supported for cuda_nvcc" >>"$LOG_FILE"
    fi
    change_dir "$src_dir"
  fi
}
# build_cuda_nvcc         # config_options+= --enable-cuda-nvcc           # enable Nvidia CUDA compiler [no]
build_cuda_nvcc() {
  if ! truthy "$disable_cuda_nvcc" && truthy "$enable_cuda_nvcc"; then
    echo "WARNING: This is a non-gpl library." >>"$LOG_FILE"
    if [[ "$bits_target" != "32" ]]; then
      disable_library "cuda-nvcc"
      enable_library "cuda-llvm"
      install_missing_packages clang compiler-rt
      run_valid_function "build_cuda_cudart"
      run_valid_function "build_cuda_crt"
      run_valid_function "build_libnvvm"
      run_valid_function "build_cuda_nvcc_native"
    fi
  fi
}
# build_d3d11va           # config_options+= --disable-d3d11va            # disable Microsoft Direct3D 11 video acceleration code [autodetect]
build_d3d11va() {
  if ! truthy "$disable_d3d11va" && truthy "$enable_d3d11va"; then
    echo "Only available on Windows build" >>"$LOG_FILE"
  fi
}
# build_d3d12va           # config_options+= --disable-d3d12va            # disable Microsoft Direct3D 12 video acceleration code [autodetect]
build_d3d12va() {
  if ! truthy "$disable_d3d12va" && truthy "$enable_d3d12va"; then
    echo "Only available on Windows build" >>"$LOG_FILE"
  fi
}
# build_dxva2             # config_options+= --disable-dxva2              # disable Microsoft DirectX 9 video acceleration code [autodetect]
build_dxva2() {
  if ! truthy "$disable_dxva2" && truthy "$enable_dxva2"; then
    echo "Only available on Windows build" >>"$LOG_FILE"
  fi
}
# build_libdrm            # config_options+= --disable-libdrm             # disable DRM code (Linux) [autodetect]
build_libdrm() {
  if ! truthy "$disable_libdrm" && truthy "$enable_libdrm"; then
    echo "Only available on Linux build" >>"$LOG_FILE"
    # https://gitlab.freedesktop.org/mesa/libdrm
    disable_library "libdrm"
  fi
}
# build_omx_rpi           # config_options+= --disable-omx-rpi            # enable OpenMAX IL code for Raspberry Pi [no]
build_omx_rpi() {
  if ! truthy "$disable_omx_rpi" && truthy "$enable_omx_rpi"; then
    # https://github.com/tizonia/tizonia-openmax-il maybe?
    echo "Only available on Linux build" >>"$LOG_FILE"
    disable_library "omx-rpi"
    #
  fi
}
# build_omx               # config_options+= --enable-omx                 # enable OpenMAX IL code [no]
build_omx() {
  if ! truthy "$disable_omx" && truthy "$enable_omx"; then
    echo "Only available on Linux build" >>"$LOG_FILE"
    # https://github.com/tizonia/tizonia-openmax-il maybe?
    disable_library "omx"
  fi
}
# build_mmal              # config_options+= --disable-mmal               # enable Broadcom Multi-Media Abstraction Layer (Raspberry Pi) via MMAL [no]
build_mmal() {
  if ! truthy "$disable_mmal" && truthy "$enable_mmal"; then
    # https://github.com/raspberrypi/userland/tree/master/interface/mmal maybe?
    echo "Only available on Linux build" >>"$LOG_FILE"
    disable_library "mmal"
  fi
}
# build_libmfx            # config_options+= --enable-libmfx              # enable Intel MediaSDK (AKA Quick Sync Video) code via libmfx [no]
build_libmfx() {
  if ! truthy "$disable_libmfx" && truthy "$enable_libmfx"; then
    echo "WARNING: [disabled] Library has been archived and has security issues." >>"$LOG_FILE"
    # https://github.com/Intel-Media-SDK/MediaSDK
    disable_library "libmfx"
  fi
}
# build_libnpp            # config_options+= --enable-libnpp              # enable Nvidia Performance Primitives-based code [no]
build_libnpp() {
  if ! truthy "$disable_libnpp" && truthy "$enable_libnpp"; then
    echo "WARNING: This is FFmpeg does not support modern npp based filters. Older api has been deprecated by Nvidia. Use scale_cuda instead. Disabling libnpp." >>"$LOG_FILE"
    disable_library "libnpp"
  fi
}
# build_libopencv         # config_options+= --enable-libopencv           # enable video filtering via libopencv [no]
build_libopencv() {
  if ! truthy "$disable_libopencv" && truthy "$enable_libopencv"; then
	run_valid_function "build_libtiff"
	run_valid_function "build_libwebp" 1
  run_valid_function "build_mingw_std_threads"
  # https://github.com/opencv/opencv
    local lib="libopencv"
    local repo="https://github.com/opencv/opencv/"
    local repo_ver="4.12.0"
    export LDFLAGS="$LDFLAGS -static-libgcc -static-libstdc++"
	  change_dir "$src_dir"
    do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
    # apply_patch "$PATCHDIR/opencv.detection_based.patch"
    change_dir "$src_dir/$lib"
    # sed -i '/^[[:space:]]*cmake_parse_arguments(VS_VER/,/^[[:space:]]*configure_file("${OpenCV_SOURCE_DIR}/ s/^/# /' "cmake/OpenCVUtils.cmake"
    sed -i '/^[[:space:]]*ocv_generate_vs_version_file("${_VS_VERSION_FILE}"/,/)/ s/^/# /' "cmake/OpenCVModule.cmake"
    sed -i '/^[[:space:]]*source_group("Src" FILES "${_VS_VERSION_FILE}")/ s/^/# /' "cmake/OpenCVModule.cmake"
    sed -i 's/^[[:space:]]*${_VS_VERSION_FILE}[[:space:]]*$/# ${_VS_VERSION_FILE}/' "cmake/OpenCVModule.cmake"
    change_dir "$src_dir/$lib/build" 1
    local original_pkg_path=$PKG_CONFIG_PATH
    export PKG_CONFIG_PATH="$install_pkgconfig_dir"
    export LIBS="-ltiff -lwebp -lwebpmux -lsharpyuv -lzstd \
-lLerc -ldeflate -ljpeg -lz -llzma -ljbig \
-lstdc++ -lwinmm -lversion -lbcrypt -lws2_32 \
-ladvapi32 -luser32 -lgdi32 -lole32 -lcomdlg32 -luuid"
    export LDFLAGS="-static $LDFLAGS -Wl,--start-group $LIBS -Wl,--end-group"
    local cmake_params="-DCMAKE_BUILD_TYPE=Release \
-DCMAKE_SYSROOT=\"${dependency_install_prefix}\" \
-DWITH_FFMPEG=ON \
-DBUILD_DOCS=OFF \
-DBUILD_EXAMPLES=OFF \
-DBUILD_TESTS=OFF \
-DBUILD_PERF_TESTS=OFF \
-DBUILD_opencv_apps=OFF \
-DOPENCV_FFMPEG_SKIP_BUILD_CHECK=ON \
-DOPENCV_FORCE_3RDPARTY_BUILD=OFF \
-DWITH_IPP=OFF \
-DBUILD_ZLIB=OFF \
-DBUILD_TIFF=OFF \
-DBUILD_OPENJPEG=OFF \
-DBUILD_JPEG=OFF \
-DBUILD_PNG=OFF \
-DBUILD_WEBP=OFF \
-DWITH_PROTOBUF=OFF \
-DBUILD_SHARED_LIBS=OFF \
-DBUILD_STATIC_LIBS=ON \
-DOPENCV_GENERATE_PKGCONFIG=ON \
-DOPENCV_EXE_LINKER_FLAGS=\"-L${dependency_install_prefix}/lib -Wl,--start-group $LIBS -Wl,--end-group\" \
-DOPENCV_EXTRA_EXE_LINKER_FLAGS=\"-L${dependency_install_prefix}/lib -Wl,--start-group $LIBS -Wl,--end-group\" \
-DCMAKE_SHARED_LINKER_FLAGS=\"-L${dependency_install_prefix}/lib -Wl,--start-group $LIBS -Wl,--end-group\" \
-DOPENCV_LINKER_LIBS=\"$LIBS\" \
-DCMAKE_CXX_STANDARD_LIBRARIES=\"-lstdc++ -lwinmm -luser32 -lgdi32\" \
-DOPENCV_INCLUDE_INSTALL_PATH=${dependency_install_prefix}/include \
-DHAVE_DSHOW=1"
    do_cmake_from_build_dir "$src_dir/$lib" "$cmake_params"
    disable_nonessential "$src_dir/$lib/build"
    do_make_and_make_install
    if [[ -f "$install_pkgconfig_dir/opencv4.pc" ]]; then
      copy_path "$install_pkgconfig_dir/opencv4.pc" "$install_pkgconfig_dir/opencv.pc" "-fv" >>"$LOG_FILE" 2>&1
    else
      copy_path "$src_dir/$lib/build/unix-install/opencv4.pc" "$install_pkgconfig_dir/opencv.pc" "-fv" >>"$LOG_FILE" 2>&1
    fi
    export PKG_CONFIG_PATH=$original_pkg_path
    find "$install_pkgconfig_dir" -name "opencv*.pc" -exec sed -i \
    -e 's|^libdir=.*|libdir=${prefix}/lib|' \
    -e 's|^includedir=.*|includedir=${prefix}/include|' \
    -e 's|-L[^ ]*opencv4/3rdparty|-L${libdir}/opencv4/3rdparty|g' \
    -e 's|-L${exec_prefix}//[^ ]*||g' \
    -e 's|-L/workspaces/[^ ]*||g' \
    {} + # TODO: fix "workspaces" path
	  change_dir "$src_dir"
    unset LIBS
    reset_ldflags
    while IFS= read -r -d '' file; do
      add_libs_to_pkg -t="$file" -l="-loleaut32"
    done < <(find "$install_pkgconfig_dir" -name "opencv*.pc" -print0)
  fi
}

# build_libshaderc        # config_options+= --enable-libshaderc          # enable GLSL->SPIRV compilation via libshaderc [no]
build_libshaderc() {
  if ! truthy "$disable_libshaderc" && truthy "$enable_libshaderc" || [[ -n "$1" ]]; then
  run_valid_function "build_spirv_tools"
	local lib="libshaderc"
  local repo="https://github.com/google/shaderc"
  local repo_ver="v2025.5"
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
	./utils/git-sync-deps > >(redirect_output) 2>&1
  sed -i 's/define_pkg_config_file(shaderc -lshaderc_shared)/define_pkg_config_file(shaderc -lshaderc -lshaderc_util)/' "$src_dir/$lib/CMakeLists.txt"
  change_dir "$src_dir/$lib/build" 1
	local cmake_params="-DCMAKE_BUILD_TYPE=release \
-DSHADERC_SKIP_EXAMPLES=ON \
-DSHADERC_SKIP_TESTS=ON \
-DSPIRV_SKIP_TESTS=ON \
-DSHADERC_SKIP_COPYRIGHT_CHECK=ON \
-DENABLE_EXCEPTIONS=ON \
-DENABLE_GLSLANG_BINARIES=OFF \
-DSPIRV_SKIP_EXECUTABLES=ON \
-DSPIRV_TOOLS_BUILD_STATIC=ON \
-DCMAKE_EXE_LINKER_FLAGS=\"-lstdc++fs\" \
-DCMAKE_CXX_STANDARD_LIBRARIES=\"-lstdc++fs\" \
-DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
-DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
-DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
-DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY \
-DBUILD_SHARED_LIBS=OFF"
  do_cmake_from_build_dir "$src_dir/$lib" "$cmake_params"
  disable_nonessential "$src_dir/$lib/build"
	do_make_and_make_install
	if [[ -f "$src_dir/$lib/build/libshaderc_util/libshaderc_util.a" ]] ; then
    copy_path "$src_dir/$lib/build/libshaderc_util/libshaderc_util.a" "$dependency_install_prefix/lib/libshaderc_util.a" "-fv" >>"$LOG_FILE" 2>&1
  fi
  while IFS= read -r -d '' file; do
    add_libs_to_pkg -t="$file" -l="-lshlwapi" || true;
  done < <(find "$install_pkgconfig_dir" -name "benchmark*.pc" -print0)
  if [[ -f "$install_pkgconfig_dir/libhwy-test.pc" ]]; then
    remove_path -f "$install_pkgconfig_dir/libhwy-test.pc"
  fi
  while IFS= read -r -d '' file; do
    add_libs_to_pkg -t="$file" -l="-lshaderc_util -lglslang -lMachineIndependent -lGenericCodeGen -lOSDependent -lSPIRV -lSPIRV-Tools-opt -lSPIRV-Tools -lstdc++" || true;
  done < <(find "$install_pkgconfig_dir" -name "shaderc*.pc" -print0)
  if [[ -f "$install_pkgconfig_dir/SPIRV-Tools-shared.pc" ]]; then
    remove_path -f "$install_pkgconfig_dir/SPIRV-Tools-shared.pc"
  fi
  change_dir "$src_dir"
  fi
}
# build_libvo_amrwbenc    # config_options+= --enable-libvo-amrwbenc      # enable AMR-WB encoding via libvo-amrwbenc [no]
build_libvo_amrwbenc() {
  if ! truthy "$disable_libvo_amrwbenc" && truthy "$enable_libvo_amrwbenc"; then
    local lib="libvo_amrwbenc"
    local repo="https://sourceforge.net/projects/opencore-amr/files/vo-amrwbenc/vo-amrwbenc-0.1.3.tar.gz"
	change_dir "$src_dir"
    download_and_unpack_file "$repo" "$lib"
    change_dir "$src_dir/$lib"
    generic_configure "--enable-static --disable-shared"
    disable_nonessential "$src_dir/$lib"
    do_make_and_make_install
	change_dir "$src_dir"
  fi
}
# build_libxcb            # config_options+= --enable-libxcb              # enable X11 grabbing using XCB [autodetect]
build_libxcb() {
  if ! truthy "$disable_libxcb" && truthy "$enable_libxcb"; then
    echo "Only available on Linux build" >>"$LOG_FILE"
    # https://gitlab.freedesktop.org/xorg/lib/libxcb
  disable_library "libxcb"
  fi
}
# build_libxcb_shape      # config_options+= --enable-libxcb-shape        # enable X11 grabbing shape rendering [autodetect]
build_libxcb_shape() {
  if ! truthy "$disable_libxcb_shape" && truthy "$enable_libxcb_shape"; then
    echo "Only available on Linux build" >>"$LOG_FILE"
    # https://gitlab.freedesktop.org/xorg/lib/libxcb
  disable_library "libxcb-shape"
  fi
}
# build_libxcb_shm        # config_options+= --enable-libxcb-shm          # enable X11 grabbing shm communication [autodetect]
build_libxcb_shm() {
  if ! truthy "$disable_libxcb_shm" && truthy "$enable_libxcb_shm"; then
    echo "Only available on Linux build" >>"$LOG_FILE"
    # https://gitlab.freedesktop.org/xorg/lib/libxcb
  disable_library "libxcb-shm"
  fi
}
# build_libxcb_xfixes     # config_options+= --enable-libxcb-xfixes       # enable X11 grabbing mouse rendering [autodetect]
build_libxcb_xfixes() {
  if ! truthy "$disable_libxcb_xfixes" && truthy "$enable_libxcb_xfixes"; then
    echo "Only available on Linux build" >>"$LOG_FILE"
    # https://gitlab.freedesktop.org/xorg/lib/libxcb
  disable_library "libxcb-xfixes"
  fi
}

# build_libdvdread        # config_options+= --enable-libdvdread          # enable libdvdread, needed for DVD demuxing [no]
build_libdvdread() {
  if ! truthy "$disable_libdvdread" && truthy "$enable_libdvdread" || [[ -n "$1" ]]; then
	activate_meson
	run_valid_function "build_libdvdcss"
  local lib="libdvdread"
  local repo="https://code.videolan.org/videolan/libdvdread"
  local repo_ver="7.0.1"
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  local meson_options="-Denable_docs=false -Dlibdvdcss=enabled"
  generic_meson "$meson_options"
  disable_nonessential "$src_dir/$lib"
	do_ninja_and_ninja_install
	change_dir "$src_dir"
  fi
}

# build_libdvdnav         # config_options+= --enable-libdvdnav           # enable libdvdnav, needed for DVD demuxing [no]
build_libdvdnav() {
  if ! truthy "$disable_libdvdnav" && truthy "$enable_libdvdnav"; then
	activate_meson
	run_valid_function "build_libdvdread" 1
  local lib="libdvdnav"
  local repo="https://code.videolan.org/videolan/libdvdnav"
  local repo_ver="7.0.0"
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  local meson_options="-Denable_docs=false -Denable_examples=false"
  generic_meson "$meson_options"
  disable_nonessential "$src_dir/$lib"
  do_ninja_and_ninja_install
  add_libs_to_pkg -t="$install_pkgconfig_dir/dvdnav.pc" -l="-ldvdread -ldvdcss -lpsapi"
	#sed -i.bak 's/-ldvdnav.*/-ldvdnav -ldvdread -ldvdcss -lpsapi/' "$install_pkgconfig_dir/dvdnav.pc" # psapi for dlfcn ... [hrm?]
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
build_libexpat() {
  local lib="libexpat"
  local repo="https://github.com/libexpat/libexpat"
  local repo_ver="R_2_7_3" 
  change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
	change_dir "$src_dir/$lib/expat"
	generic_configure "--enable-static --disable-shared"
  disable_nonessential "$src_dir/$lib"
  do_make_and_make_install
  change_dir "$src_dir"
}
build_pango() {
  run_valid_function "build_dlfcn"
	run_valid_function "build_libharfbuzz" 1
	run_valid_function "build_libfontconfig" 1
  run_valid_function "build_libexpat"
 	# https://gitlab.gnome.org/GNOME/pango
	local lib="pango"
  local repo="https://gitlab.gnome.org/GNOME/pango"
  local repo_ver="1.57.0"
  activate_meson
	change_dir "$src_dir"
	do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
	change_dir "$src_dir/$lib"
  export LIBS="-lfontconfig -lexpat -lfreetype -lbrotlidec -lbrotlicommon -lpng -lz -lbz2 -lintl -liconv -ldl -lstdc++"
  export LDFLAGS="$LDFLAGS $LIBS"
	local meson_options="-Ddocumentation=false \
-Dgtk_doc=false \
-Dman-pages=false \
-Dfontconfig=enabled \
-Dcairo=enabled \
-Dfreetype=enabled \
-Dbuild-testsuite=false \
-Dbuild-examples=false \
-Dintrospection=disabled \
-Dxft=disabled \
-Dc_args=\"-DCAIRO_WIN32_STATIC_BUILD -DGLIB_STATIC_COMPILATION\" \
-Dcpp_args=\"-DCAIRO_WIN32_STATIC_BUILD -DGLIB_STATIC_COMPILATION\" \
-Dc_link_args=\"-L${dependency_install_prefix}/lib $LIBS\" \
-Dcpp_link_args=\"-L${dependency_install_prefix}/lib $LIBS\""
  # disable tools - not needed for ffmpeg
  sed -i "s/subdir('utils')/# subdir('utils')/g" meson.build
  find . -name "meson.build" -exec sed -i -E \
        -e "/\.compile_resources\(/ s/^/# /" \
        -e "/_rc = configure_file\(/,/\)/ s/^/# /" \
        -e "/_sources \+= [^ ]+_res/ s/^/# /" \
        -e "/_res = import\('windows'\)/ s/^/# /" \
        {} +
	generic_meson "$meson_options"
	do_ninja_and_ninja_install
	change_dir "$src_dir"
  reset_ldflags
  unset LIBS
}

build_pixman() {
 	# https://gitlab.freedesktop.org/pixman/pixman
	local lib="pixman"
  local repo="https://gitlab.freedesktop.org/pixman/pixman"
  local repo_ver="pixman-0.46.4"
  activate_meson
	change_dir "$src_dir"
	do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
	change_dir "$src_dir/$lib"
	local meson_options="-Dtests=disabled -Ddemos=disabled"
	generic_meson "$meson_options"
	do_ninja_and_ninja_install
	change_dir "$src_dir"
}

build_cairo() {
  run_valid_function "build_dlfcn"
	run_valid_function "build_pixman"
	run_valid_function "build_libfontconfig" 1
 	# https://gitlab.freedesktop.org/cairo/cairo
	local lib="cairo"
  local repo="https://gitlab.freedesktop.org/cairo/cairo"
  local repo_ver="1.18.4"
  activate_meson
	change_dir "$src_dir"
	do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
	change_dir "$src_dir/$lib"
  export CFLAGS="$CFLAGS -lpthread"
  export CXXFLAGS="$CXXFLAGS -lpthread"
  export LDFLAGS="$LDFLAGS -lpthread"
  export LIBS="-lpng -lpthread -llzma -lbrotlidec -lbrotlicommon -ldl -lstdc++"
	local meson_options="-Dtests=disabled \
-Dgtk_doc=false \
-Dglib=enabled \
-Dxlib=disabled \
-Dxcb=disabled \
-Dxlib-xcb=disabled \
-Dspectre=disabled \
-Dsymbol-lookup=disabled \
-Dlzo=disabled \
-Dfontconfig=enabled \
-Dfreetype=enabled \
-Dtee=enabled \
-Dc_link_args=\"-L${dependency_install_prefix}/lib $LIBS\" \
-Dcpp_link_args=\"-L${dependency_install_prefix}/lib $LIBS\""
	generic_meson "$meson_options"
	do_ninja_and_ninja_install
	change_dir "$src_dir"
  while IFS= read -r -d '' file; do
    add_libs_to_pkg -t="$file" -l="-lstdc++" -p="-lole32 -lwindowscodecs -luuid"
  done < <(find "$install_pkgconfig_dir" -type f -name "cairo*.pc" -print0)
  unset LIBS
  reset_allflags
}

build_libgpg_error() {
  # https://github.com/gpg/libgpg-error
  local lib="libgpg-error"
  local repo="https://github.com/gpg/libgpg-error"
  local repo_ver="libgpg-error-1.45"
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  generic_configure "--disable-doc --disable-nls --disable-languages --enable-install-gpg-error-config"
  sed -i -E 's/=[[:space:]]*versioninfo\.lo/=/g' "src/Makefile"
  disable_nonessential "$src_dir/$lib"
  do_make_and_make_install
	change_dir "$src_dir"
}

build_lcms() {
  local lib="lcms"
  local repo="https://github.com/ImageMagick/lcms"
	change_dir "$src_dir"
	do_git_checkout_and_make_install "$repo" "$lib"
	change_dir "$src_dir"
}

build_libjsoncpp() {
  activate_meson
	local repo="https://github.com/open-source-parsers/jsoncpp"
  local lib="jsoncpp"
  local repo_ver="1.9.6"
	change_dir "$src_dir"
	do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
	change_dir "$src_dir/$lib"
	local meson_options=""
	generic_meson "$meson_options"
	do_ninja_and_ninja_install
	change_dir "$src_dir"
}

build_giflib() {
	local lib="giflib"
  local repo="https://sourceforge.net/projects/giflib/files/giflib-5.1.4.tar.gz"
  local repo_ver="5.1.4"
	change_dir "$src_dir"
	download_and_unpack_file "$repo" "$lib"
  change_dir "$src_dir/$lib"
  generic_configure
  disable_nonessential "$src_dir/$lib"
  do_make_and_make_install
	change_dir "$src_dir"
}

build_libleptonica() {
	run_valid_function "build_libpng"
	run_valid_function "build_libwebp" 1
	run_valid_function "build_libjpeg_turbo"
	run_valid_function "build_giflib"
  local lib="libleptonica"
  local repo="https://github.com/DanBloomberg/leptonica"
  local repo_ver="1.86.0"
	change_dir "$src_dir"
	do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
	change_dir "$src_dir/$lib/build" 1
	export CFLAGS="$CFLAGS -DOPJ_STATIC -DJBG_STATIC "
  export CPPFLAGS="$CPPFLAGS -DOPJ_STATIC -DJBG_STATIC "
  sed -i -e 's/@leptonica_OUTPUT_NAME@/leptonica/g' \
    -e '/set(pkg_conf_name lept_$<CONFIG>.pc)/d' \
    "$src_dir/$lib/CMakeLists.txt"
  sed -i \
    -e 's/add_library(leptonica /add_library(leptonica STATIC /' \
    -e '/if(MINGW)/,/endif(MINGW)/d' \
    -e 's/"leptonica.*)/"leptonica")/' \
    "$src_dir/$lib/src/CMakeLists.txt"
    
  local cmake_params="-DCMAKE_BUILD_TYPE=Release \
-DBUILD_SHARED_LIBS=OFF \
-DBUILD_PROG=OFF \
-DSW_BUILD=OFF \
-DSTRICT_CONF=ON"
  do_cmake_from_build_dir "$src_dir/$lib" "$cmake_params"
  disable_nonessential "$src_dir/$lib" "prog"
  do_make_and_make_install
	reset_cflags
  reset_cppflags
	change_dir "$src_dir"
  sed -i '/Requires.private:.*/d' "$install_pkgconfig_dir/lept.pc"
  add_libs_to_pkg -t="$install_pkgconfig_dir/lept.pc" -p="-lz -lpng -ljpeg -ltiff -lsharpyuv -ljbig -lgif -lwebp -lwebpmux -lopenjp2 -llzma -lzstd -ldeflate -lLerc -larchive -lexpat -lgdi32 -luser32"
}
build_jbig() {
  local lib="jbig"
  local repo="https://github.com/ImageMagick/jbig"
  local repo_ver="master"
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
  export CFLAGS="$CFLAGS -DJBG_STATIC "
  sed -i "s|CCFLAGS = -O2 -W|CCFLAGS = -O2 -W ${CFLAGS}|g" Makefile
  change_dir "$src_dir/$lib/libjbig"
  sed -i "s|CCFLAGS = -O2 -W|CCFLAGS = -O2 -W ${CFLAGS}|g" Makefile
  do_make "libjbig.a"
  cp -fv "$src_dir/$lib/libjbig/libjbig.a" "$dependency_install_prefix/lib/" >>"$LOG_FILE"
  cp -fv "$src_dir/$lib/libjbig/jbig.h" "$dependency_install_prefix/include/" >>"$LOG_FILE"
  cat > "$install_pkgconfig_dir/jbig.pc" <<EOF
prefix=${dependency_install_prefix}
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: jbig
Description: JBIG-KIT provides a portable library of compression and decompression functions
Version: 1.6.0
Libs: -L\${libdir} -ljbig
Libs.private:
Cflags: -I\${includedir}
EOF
  	change_dir "$src_dir"
    reset_cflags
}
build_libdeflate() {
  local lib="libdeflate"
  local repo="https://github.com/ebiggers/libdeflate"
  local repo_ver="v1.25"
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  change_dir "$src_dir/$lib/build" 1
  local cmake_params="-DCMAKE_BUILD_TYPE=Release \
-DLIBDEFLATE_BUILD_STATIC_LIB=ON \
-DLIBDEFLATE_BUILD_SHARED_LIB=OFF \
-DLIBDEFLATE_BUILD_GZIP=OFF \
-DBUILD_SHARED_LIBS=OFF \
-DCMAKE_INSTALL_PREFIX=$dependency_install_prefix \
-DENABLE_SHARED=0"
	do_cmake_from_build_dir "$src_dir/$lib" "$cmake_params"
  disable_nonessential "$src_dir/$lib"
  do_make_and_make_install
    change_dir "$src_dir"
}
build_lerc() {
  local lib="lerc"
  local repo="https://github.com/Esri/lerc"
  local repo_ver="v4.0.0"
	change_dir "$src_dir"
	do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
	change_dir "$src_dir/$lib"
	local cmake_params="-DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DCMAKE_INSTALL_PREFIX=$dependency_install_prefix -DENABLE_SHARED=0"
	generic_cmake "$cmake_params" "$src_dir/$lib"
  disable_nonessential "$src_dir/$lib"
  do_make_and_make_install
  	change_dir "$src_dir"
}
build_libtiff() {
	run_valid_function "build_libjpeg_turbo" # auto uses it?
	run_valid_function "build_lzma" 1
	run_valid_function "build_zstd"
	run_valid_function "build_jbig"
	run_valid_function "build_libdeflate"
	run_valid_function "build_lerc"
  run_valid_function "build_libwebp" 1
	local lib="libtiff"
  local repo="https://download.osgeo.org/libtiff/tiff-4.7.1rc1.tar.gz" # "https://gitlab.com/libtiff/libtiff"
  local repo_ver="v4.7.1"
	change_dir "$src_dir"
  download_and_unpack_file "$repo" "$lib"
  change_dir "$src_dir/$lib"
  export CFLAGS="$CFLAGS -D_LIB "
  export CPPFLAGS="$CPPFLAGS -D_LIB "
  export LIBS="-ljbig -ljpeg -llzma -lwebp -lsharpyuv -lwebp -lwebpmux -lwebpdemux -lLerc -lzstd -ldeflate -lz -lstdc++"
  generic_configure "--enable-static \
--disable-shared \
--disable-docs \
--disable-tools \
--disable-tests \
--disable-utilities \
--disable-contrib \
--with-jbig-lib-dir=$dependency_install_prefix/lib \
--with-jbig-include-dir=$dependency_install_prefix/include \
--with-sysroot=\"$dependency_install_prefix\" \
LIBS=\"$LIBS\""
  disable_nonessential "$src_dir/$lib"
  do_make_and_make_install
  add_libs_to_pkg -t="$install_pkgconfig_dir/libtiff-4.pc" -l="-llzma -ljpeg -lz -ljbig -lwebp -lLerc"
	change_dir "$src_dir"
  reset_cflags
  reset_cppflags
  unset LIBS
}

build_gettext() {
	local lib="gettext"
  local repo="https://ftp.gnu.org/pub/gnu/gettext/gettext-0.26.tar.gz"
  change_dir "$src_dir"
  download_and_unpack_file "$repo" "$lib"
	# download_and_unpack_file "$repo" "$lib" 
  change_dir "$src_dir/$lib/gettext-runtime" 1
  export LIBS="-liconv"
	local config="--prefix=${dependency_install_prefix} \
--with-sysroot=\"${dependency_install_prefix}\" \
--with-libiconv-prefix=\"${dependency_install_prefix}\" \
--with-included-gettext \
--enable-static \
--disable-shared \
--disable-java \
--disable-csharp \
--disable-native-java \
--disable-libasprintf \
--disable-openmp \
--disable-doc \
CFLAGS=\"$CFLAGS -Dlibintl_STATIC -Wno-incompatible-pointer-types\" \
LIBS=\"$LIBS\""
  generic_configure "$config"
  find . -name "Makefile*" -exec sed -i -E '/=/s/[^ ]+\.res(\.lo)?//g' {} + # otherwise causes issues with static linking
  #disable_nonessential "$src_dir/$lib"
  do_make_and_make_install "CFLAGS=\"$CFLAGS -Dlibintl_STATIC -Wno-incompatible-pointer-types\"" "CFLAGS=\"$CFLAGS -Dlibintl_STATIC -Wno-incompatible-pointer-types\""
  cat > "$install_pkgconfig_dir/intl.pc" <<EOF
prefix=${dependency_install_prefix}
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: intl
Description: GNU gettext library
Version: ${version}
Libs: -L\${libdir} -lintl -liconv
Cflags: -I\${includedir} -Dlibintl_STATIC
EOF
  change_dir "$src_dir/$lib"
  add_src_dir "$src_dir/$lib"
	change_dir "$src_dir"
  unset LIBS
  reset_cflags
}

build_libffi() {
	local lib="libffi"
  local repo="https://github.com/libffi/libffi/releases/download/v3.5.2/libffi-3.5.2.tar.gz"
	change_dir "$src_dir"
	download_and_unpack_file "$repo" "$lib" # also dep
	change_dir "$src_dir/$lib"
	apply_patch "$PATCHDIR/libffi.patch"
	generic_configure "--disable-multi-os-directory"
  disable_nonessential "$src_dir/$lib"
  do_make_and_make_install
	change_dir "$src_dir"
}
build_glib() {
	run_valid_function "build_iconv" 1
	run_valid_function "build_libffi"
	run_valid_function "build_pcre2"
  activate_meson
	local lib="glib"
  local repo="https://github.com/GNOME/glib"
  local repo_ver="2.82.0"
	change_dir "$src_dir"
	do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
	change_dir "$src_dir/$lib"
	local meson_options="-Dforce_posix_threads=true \
-Dman-pages=disabled \
-Dsysprof=disabled \
-Dglib_debug=disabled \
-Dtests=false \
--includedir=\"${dependency_install_prefix}/include\" \
-Dc_link_args=\"-L${dependency_install_prefix}/lib -lintl -liconv\" \
-Dcpp_link_args=\"-L${dependency_install_prefix}/lib -lintl -liconv\" \
--wrap-mode=nofallback"
	generic_meson "$meson_options"
	do_ninja_and_ninja_install
  add_libs_to_pkg -t="$install_pkgconfig_dir/glib-2.0.pc" -l="-lintl -lws2_32 -lwinmm -liconv -lole32"
	change_dir "$src_dir"
}

build_lz4() {
  activate_meson
	local lib="lz4"
  local repo="https://github.com/lz4/lz4/releases/download/v1.10.0/lz4-1.10.0.tar.gz"
  local repo_ver="v1.10.0"
	change_dir "$src_dir"
	download_and_unpack_file "$repo" "$lib"
	change_dir "$src_dir/$lib/build/meson"
  local meson_options="-Dossfuzz=false"
  generic_meson
	# generic_cmake "-DCMAKE_BUILD_TYPE=Release -DBUILD_STATIC_LIBS=ON -DBUILD_SHARED_LIBS=OFF" "$src_dir/$lib"
  disable_nonessential "$src_dir/$lib"
	do_ninja_and_ninja_install
	change_dir "$src_dir"
}

build_libarchive() {
	run_valid_function "build_lz4"
  local lib="libarchive"
  local repo="https://github.com/libarchive/libarchive"
  local repo_ver="v3.8.4"
	change_dir "$src_dir"
	do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
	change_dir "$src_dir/$lib"
  touch "no_autoreconf"
	generic_configure "--enable-static \
--disable-shared \
--with-nettle \
--bindir=$dependency_install_prefix/bin \
--without-bz2lib \
--without-lz4 \
--without-zstd \
--without-lzo2 \
--without-cng \
--without-xml2 \
--without-nettle \
--without-iconv \
--disable-posix-regex-lib"
	disable_nonessential "$src_dir/$lib"
  do_make_and_make_install
  reset_cflags
  reset_ldflags
	change_dir "$src_dir"
}

build_flac() {
	run_valid_function "build_libogg"
	local lib="flac"
  local repo="https://github.com/xiph/flac"
  local repo_ver="1.5.0"
	change_dir "$src_dir"
	do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
	change_dir "$src_dir/$lib"
  find . -name "CMakeLists.txt" -exec sed -i 's/version.rc//g' {} +
  change_dir "$src_dir/$lib/build" 1
	do_cmake_from_build_dir "$src_dir/$lib" "-DBUILD_DOCS=OFF \
-DBUILD_TESTING=OFF \
-DBUILD_EXAMPLES=OFF \
-DBUILD_PROGRAMS=OFF \
-DBUILD_STATIC_LIBS=ON \
-DBUILD_SHARED_LIBS=OFF \
-DCMAKE_BUILD_TYPE=Release \
-DINSTALL_MANPAGES=OFF"
  disable_nonessential "$src_dir/$lib"
	do_make_and_make_install
	change_dir "$src_dir"
}

build_libpsl() {
	local lib="libpsl"
  local repo="https://github.com/rockdaboot/libpsl"
  local repo_ver="0.21.5"
	change_dir "$src_dir"
	do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
	change_dir "$src_dir/$lib"
	export CFLAGS="-DPSL_STATIC"
  touch "no.autoreconf"
	generic_configure "--disable-nls \
--disable-rpath \
--disable-gtk-doc-html \
--disable-man \
--disable-runtime \
--enable-static \
--disable-shared"
	disable_nonessential "$src_dir/$lib"
  do_make_and_make_install
  add_libs_to_pkg -t="$install_pkgconfig_dir/libpsl.pc" -l="-lidn2 -lunistring -liconv"
	reset_cflags
	change_dir "$src_dir"
  add_libs_to_pkg -t="$install_pkgconfig_dir/libpsl.pc" -l="-lws2_32"
}

build_nghttp2() {
	local lib="nghttp2"
  local repo="https://github.com/nghttp2/nghttp2"
  local repo_ver="v1.68.0"
	change_dir "$src_dir"
	do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
	change_dir "$src_dir/$lib"
  export CFLAGS="$CFLAGS -DNGHTTP2_STATICLIB"
	generic_configure "--enable-static --disable-shared"
  disable_nonessential "$src_dir/$lib"
  do_make_and_make_install
	reset_cflags
	change_dir "$src_dir"
}

build_libssh2() {
	local lib="libssh2"
  local repo="https://github.com/libssh2/libssh2"
  local repo_ver="1.11.1"
	change_dir "$src_dir"
	do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
	change_dir "$src_dir/$lib"
	generic_configure "--enable-static --disable-shared"
  disable_nonessential "$src_dir/$lib"
  do_make_and_make_install
	change_dir "$src_dir"
}

build_cpuinfo() {
	local lib="cpuinfo"
  local repo="https://github.com/pytorch/cpuinfo"
	change_dir "$src_dir"
	do_git_checkout "$repo" "$src_dir/$lib"
  change_dir "$src_dir/$lib/deps/clog/build" 1
  do_cmake_from_build_dir "$src_dir/$lib" "-DCMAKE_BUILD_TYPE=Release \
-DCLOG_BUILD_TESTS=OFF \
-DCMAKE_POSITION_INDEPENDENT_CODE=ON \
-DBUILD_SHARED_LIBS=OFF"
  do_make_and_make_install
  change_dir "$src_dir/$lib/build" 1
	do_cmake_from_build_dir "$src_dir/$lib" "-DCMAKE_BUILD_TYPE=Release \
-DCPUINFO_BUILD_UNIT_TESTS=OFF \
-DCPUINFO_BUILD_TOOLS=OFF \
-DCPUINFO_BUILD_MOCK_TESTS=OFF \
-DCPUINFO_BUILD_BENCHMARKS=OFF \
-DCPUINFO_LIBRARY_TYPE=static \
-DCMAKE_POSITION_INDEPENDENT_CODE=ON \
-DBUILD_SHARED_LIBS=OFF"
  disable_nonessential "$src_dir/$lib/build"
  do_make_and_make_install
	change_dir "$src_dir"
  while IFS= read -r -d '' file; do
    add_libs_to_pkg -t="$file" -l="-lshlwapi"
  done < <(find "$install_pkgconfig_dir" -name "benchmark*.pc" -print0)
  if [[ -f "$install_pkgconfig_dir/libhwy-test.pc" ]]; then
    remove_path -f "$install_pkgconfig_dir/libhwy-test.pc"
  fi
}

build_vulkan_loader() {
	local parentlib="vulkan-loader"
  local lib="Vulkan-Shim-Loader"
  local repo="https://github.com/BtbN/Vulkan-Shim-Loader"
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$parentlib"
  change_dir "$src_dir/$parentlib"
  local lib="Vulkan-Headers"
  local repo="https://github.com/KhronosGroup/Vulkan-Headers"
  local repo_ver="v1.4.326"
	do_git_checkout "$repo" "$src_dir/$parentlib/$lib" "$repo_ver"
  change_dir "$src_dir/$parentlib/$lib"
	generic_cmake "-DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DCMAKE_BUILD_TYPE=Release -DVULKAN_SHIM_IMPERSONATE=ON" "$src_dir/$parentlib/$lib"
  disable_nonessential "$src_dir/$parentlib/$lib"
  do_make_and_make_install
	change_dir "$src_dir"
}

build_libunwind() {
	local lib="libunwind"
  local repo="https://github.com/libunwind/libunwind"
  local repo_ver="v1.8.3"
	change_dir "$src_dir"
	do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
	change_dir "$src_dir/$lib"
	generic_configure "--disable-shared --enable-static"
  disable_nonessential "$src_dir/$lib"
  do_make_and_make_install
	change_dir "$src_dir"
}

build_libxxhash() {
	local lib="libxxhash"
  local repo="https://github.com/Cyan4973/xxHash"
  local repo_ver="v0.8.3"
	change_dir "$src_dir"
	do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
	change_dir "$src_dir/$lib"
  sed -i 's/install: .*/install: install_libxxhash.a install_libxxhash.includes install_libxxhash.pc/g' Makefile
	generic_make "CFLAGS=\"${CFLAGS}\""
  disable_nonessential "$src_dir/$lib"
  generic_make_install
	change_dir "$src_dir"
}

build_spirv_cross() {
	local lib="SPIRV-Cross"
  local repo="https://github.com/KhronosGroup/SPIRV-Cross"
  local repo_ver="vulkan-sdk-1.4.328.1"
	change_dir "$src_dir"
	do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
	change_dir "$src_dir/$lib/build" 1
	do_cmake_from_build_dir "$src_dir/$lib" "-DSPIRV_CROSS_STATIC=ON \
-DSPIRV_CROSS_SHARED=OFF \
-DCMAKE_BUILD_TYPE=Release \
-DSPIRV_CROSS_CLI=OFF \
-DSPIRV_CROSS_ENABLE_TESTS=OFF \
-DSPIRV_CROSS_FORCE_PIC=ON \
-DSPIRV_CROSS_ENABLE_CPP=OFF"
  disable_nonessential "$src_dir/$lib"
	do_make_and_make_install
	[[ -f "$install_pkgconfig_dir/spirv-cross-c.pc" ]] && mv "$install_pkgconfig_dir/spirv-cross-c.pc" "$install_pkgconfig_dir/spirv-cross-c-shared.pc"
  add_libs_to_pkg -t="$install_pkgconfig_dir/spirv-cross-c-shared.pc" -l="-lspirv-cross-c -lspirv-cross-glsl -lspirv-cross-hlsl -lspirv-cross-msl -lspirv-cross-reflect -lspirv-cross-core -lstdc++"
	change_dir "$src_dir"
}

build_libdovi() {
	local lib="libdovi"
  local repo="https://github.com/quietvoid/dovi_tool"
  local repo_ver="2.3.1"
	change_dir "$src_dir"
	do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
	change_dir "$src_dir/$lib/dolby_vision"
	cargo_build_and_install "--release" "--package dolby_vision \
--release \
--library-type=staticlib"
	change_dir "$src_dir"
	# if [[ ! -e $dependency_install_prefix/lib/libdovi.a ]]; then
	# 	curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && . "$HOME/.cargo/env" && rustup update && rustup target add x86_64-pc-windows-gnu # rustup self uninstall
	# 	wget https://github.com/quietvoid/dovi_tool/releases/download/2.3.1/dovi_tool-2.3.1-x86_64-pc-windows-msvc.zip > >(redirect_output) 2>&1
	# 	unzip -o dovi_tool-2.3.1-x86_64-pc-windows-msvc.zip -d "$dependency_install_prefix/bin"
	# 	remove_path -f dovi_tool-2.3.1-x86_64-pc-windows-msvc.zip
	# 	unset install_pkgconfig_dir
	# 	change_dir "$src_dir/$lib/dolby_vision"
	# 	cargo install cargo-c --features=vendored-openssl
	# 	export install_pkgconfig_dir="$install_pkgconfig_dir"
	# 	cargo cinstall --release --prefix="$dependency_install_prefix" --libdir="$dependency_install_prefix/lib" --library-type=staticlib --target x86_64-pc-windows-gnu
	#	change_dir "$src_dir"
	# else
	# 	echo -e "libdovi already installed" >>"$LOG_FILE"
	# fi
}

build_libjpeg_turbo() {
	local lib="libjpeg-turbo"
  local repo="https://github.com/libjpeg-turbo/libjpeg-turbo"
  local repo_ver="3.1.2"
	change_dir "$src_dir"
	do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
	change_dir "$src_dir/$lib"
	local cmake_params="-DCMAKE_BUILD_TYPE=Release \
-DBUILD_SHARED_LIBS=OFF \
-DCMAKE_INSTALL_PREFIX=$dependency_install_prefix \
-DENABLE_SHARED=0 \
-DCMAKE_ASM_NASM_COMPILER=yasm"
	generic_cmake "$cmake_params" "$src_dir/$lib"
  disable_nonessential "$src_dir/$lib"
  do_make_and_make_install
	change_dir "$src_dir"
}

build_libdvdcss() {
	activate_meson
  local lib="libdvdcss"
  local repo="https://code.videolan.org/videolan/libdvdcss"
  local repo_ver="1.5.0"
	change_dir "$src_dir"
  do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
  change_dir "$src_dir/$lib"
	local meson_options="-Denable_docs=false -Denable_examples=false"
  generic_meson "$meson_options"
  disable_nonessential "$src_dir/$lib"
  do_ninja_and_ninja_install
	change_dir "$src_dir"
}

build_libvvdec() {
  local lib="libvvdec"
  local repo="https://github.com/fraunhoferhhi/vvdec"
  local repo_ver="v3.1.0"
	change_dir "$src_dir"
	do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
	change_dir "$src_dir/$lib"
	generic_cmake "-DCMAKE_BUILD_TYPE=Release -DVVDEC_ENABLE_LINK_TIME_OPT=OFF -DVVDEC_INSTALL_VVDECAPP=ON"
	do_ninja_and_ninja_install
	change_dir "$src_dir"
}

build_svt_hevc() {
	if [[ "$bits_target" != "32" ]] && [[ $build_svt_hevc = y ]]; then
  local lib="svt-hevc"
  local repo="https://github.com/OpenVisualCloud/SVT-HEVC"
  local repo_ver="v1.5.1"
	change_dir "$src_dir"
	do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
	change_dir "$src_dir/$lib/build" 1
  do_cmake_from_build_dir "$src_dir/$lib" "-DCMAKE_BUILD_TYPE=Release"
  do_make_and_make_install
	change_dir "$src_dir"
	fi
}

build_svt_vp9() {
	if [[ "$bits_target" != "32" ]] && [[ $build_svt_vp9 = y ]]; then
  local lib="svt-vp9"
  local repo="https://github.com/OpenVisualCloud/SVT-VP9"
  local repo_ver="v0.3.1"
	change_dir "$src_dir"
	do_git_checkout "$repo" "$src_dir/$lib" "$repo_ver"
	change_dir "$src_dir/$lib/build" 1
  do_cmake_from_build_dir "$src_dir/$lib" "-DCMAKE_BUILD_TYPE=Release"
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
windres = '/usr/bin/true'
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
sys_root = '$dependency_install_prefix'
pkg_config_sysroot_dir = '$dependency_install_prefix'
pkg_config_libdir = '$pkg_config_sysroot_dir/lib/pkgconfig'
needs_exe_wrapper = true
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
windres = '/usr/bin/true'
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
sys_root = '$dependency_install_prefix'
pkg_config_libdir = '$install_pkgconfig_dir'
needs_exe_wrapper = true
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
windres = '/usr/bin/true'
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
sys_root = '$dependency_install_prefix'
pkg_config_sysroot_dir = '$dependency_install_prefix'
pkg_config_libdir = '$pkg_config_sysroot_dir/lib/pkgconfig'
needs_exe_wrapper = true
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
