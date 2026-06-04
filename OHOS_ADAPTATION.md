# 鸿蒙 OS / OpenHarmony 适配方案

本文分析当前 `ffmpeg-kit-builders` 仓库的构建脚本结构，并给出把它扩展成鸿蒙 OS / OpenHarmony native 版本的推荐改法。目标是先产出可被 HarmonyOS/OpenHarmony 应用加载的 native 产物，例如 `libffmpegkit.so`、FFmpeg 静态库或共享库；ArkTS/N-API 封装和 HAR/HAP 打包建议作为下一阶段处理。

## 结论

当前仓库已经有一部分 OpenHarmony 相关痕迹，但还不能直接构建 OHOS：

- `runner.sh` 里有 `oh|openharmony|harmony` 的 preset 分支，但 `pick_host_platform` 不接受这些平台值，所以这些分支目前不可达。
- `scripts/variable.sh` 的 `CONFIG_HARDWARE` 已包含 `--enable-ohcodec`，多个 `run-*.sh` 里也有 `build_ohcodec` 占位函数。
- `scripts/function.sh` 的 `configure_ffmpeg` 只在 `host_platform == "harmony"` 时追加 `--enable-ohcodec`，但没有 `setup_harmony_environment` 或 `setup_ohos_environment`。
- 缺少 `scripts/function-ohos.sh`、`scripts/run-ohos.sh`、`scripts/deps-ohos.sh` 三个真正的平台脚本。
- `FFmpegKit/CMakeLists.txt` 只处理 Windows、Linux、Android、Apple，没有 OHOS 分支。

推荐做法是新增一个规范平台名 `ohos`，把 `harmony`、`openharmony`、`open-harmony`、`open_harmony`、`harmonyos` 作为别名归一到 `ohos`。实现上以 Android 脚本为模板，因为 OHOS 同样是 LLVM/Clang + sysroot 的交叉编译形态；但不要直接改 Android 脚本，避免破坏现有 Android 构建。

## 适配范围

第一阶段建议只做 native 基础版：

- 支持 ABI：`arm64-v8a` / `aarch64`，可选 `armeabi-v7a` / `armv7a` 和 `x86_64`。
- 支持基础库：`jsoncpp`、`zlib`、`bzip2`、`xz/lzma`、`iconv`、`openssl` 或 `mbedtls`。
- 支持 FFmpeg 内置组件和 `--enable-ohcodec`。
- 先不启用全量视频/AI/GPU/桌面 Linux 依赖，例如 X11、ALSA、PulseAudio、VAAPI、CUDA、OpenVINO、Torch、V4L2 等。
- `ffplay`/SDL2 可以二选一：要么先关闭 `ffplay`，要么确认 SDL2 能用 OHOS NDK 编译并适配图形/音频后再启用。

第二阶段再做：

- ArkTS/N-API 包装层。
- HAR 包结构。
- `libs/arm64-v8a/libffmpegkit.so` 等产物拷贝。
- HiLog 日志桥接。
- OpenHarmony 设备上的硬件编解码验证。

## 工具链约定

OpenHarmony NDK 的 CMake 入口通常是：

```bash
$OHOS_SDK_NATIVE/build/cmake/ohos.toolchain.cmake
```

建议让脚本接受如下环境变量：

```bash
export OHOS_SDK_NATIVE=/path/to/ohos-sdk/linux/native
```

如果没有显式设置，可以从这些变量推导：

```bash
${OHOS_SDK_HOME}/native
${HARMONY_SDK_HOME}/native
${DEVECO_SDK_HOME}/native
```

ABI 与目标三元组建议这样映射：

| 输入 arch | OHOS_ARCH | host_target | Rust target |
| --- | --- | --- | --- |
| `aarch64` / `arm64` / `arm64-v8a` | `arm64-v8a` | `aarch64-linux-ohos` | `aarch64-unknown-linux-ohos` |
| `armv7a` / `arm` / `armeabi-v7a` | `armeabi-v7a` | `arm-linux-ohos` | `armv7-unknown-linux-ohos` |
| `x86_64` | `x86_64` | `x86_64-linux-ohos` | `x86_64-unknown-linux-ohos` |

CMake 依赖应优先走官方 OHOS toolchain：

```bash
-DCMAKE_TOOLCHAIN_FILE="$OHOS_SDK_NATIVE/build/cmake/ohos.toolchain.cmake"
-DOHOS_PLATFORM=OHOS
-DOHOS_ARCH="$ohos_arch"
-DOHOS_STL=c++_static
```

FFmpeg 的 `configure` 目前有 `--enable-ohcodec`，但没有稳定的 `--target-os=ohos` 分支。建议对 FFmpeg 继续使用：

```bash
--target-os=linux
--enable-cross-compile
--enable-pthreads
--enable-ohcodec
```

同时通过 `--cc`、`--cxx`、`--ar`、`--nm`、`--ranlib`、`--strip`、`--extra-cflags`、`--extra-ldflags` 传入 OHOS Clang、sysroot 和目标三元组。不要复用 Android 的 `--target-os=android`、`--enable-jni`、`-landroid`、`-llog`。

## 需要修改的文件

### 1. `scripts/variable.sh`

新增 OHOS 平台 preset。不要把 Android 的 `jni`、`mediacodec` 放进去。

建议新增：

```bash
CONFIG_OH="\
--enable-openssl \
--enable-ohcodec"

CONFIG_OH_NON_FREE=""
```

同时建议把 `CONFIG_HARDWARE` 中的 `--enable-ohcodec` 保留，但只在 OHOS 平台真正追加 `--enable-ohcodec` 到 FFmpeg configure。否则 Android/Linux 选择 `--enable-hardware` 时可能会误启 OHOS-only 特性。

当前 `CONFIG_BASE` 包含 `--enable-sdl2` 和 `--enable-pthread-win32`。OHOS 第一阶段建议：

- `pthread-win32` 只应在 Windows 生效，OHOS 不需要。
- `sdl2` 如果不能稳定编译 OHOS，先把 FFplay 做成可选，避免基础包被 SDL2 卡住。

### 2. `runner.sh`

当前 `runner.sh` 已有 OH/Harmony preset case，但平台选择前置校验不接受 OHOS，所以需要在 `pick_host_platform` 中补齐，而不是只改 `runner.sh` 后面的 case。

建议统一平台名：

```bash
set_ohos() {
  export host_platform="ohos"
  export toolchain_sys="ohos"
  apply_preset "$CONFIG_OH"
}
```

把合法值扩展为：

```bash
ohos|oh|openharmony|open-harmony|open_harmony|harmony|harmonyos
```

交互菜单增加 OHOS，例如：

```text
9. OpenHarmony / HarmonyOS
10. Exit
```

`runner.sh` 中已有的 preset 分支建议改为归一后的平台名：

```bash
ohos)
  apply_preset "$CONFIG_OH"
  ;;
```

这样 `source_platform="$host_platform"` 会加载：

```bash
scripts/function-ohos.sh
scripts/run-ohos.sh
scripts/deps-ohos.sh
```

### 3. `scripts/function.sh`

需要新增 `isohos`、`setup_ohos_environment`，并在总入口中接入。

`setup_build_environment` 的 case 增加：

```bash
"ohos") setup_ohos_environment ;;
```

新增判断函数：

```bash
isohos() {
  [[ "$host_platform" == "ohos" ]]
}
```

`setup_ohos_environment` 建议骨架：

```bash
setup_ohos_environment() {
  export PATCHDIR="$SCRIPTDIR/ohos/patches"

  if [[ -z "$OHOS_SDK_NATIVE" ]]; then
    if [[ -n "$OHOS_SDK_HOME" && -d "$OHOS_SDK_HOME/native" ]]; then
      export OHOS_SDK_NATIVE="$OHOS_SDK_HOME/native"
    elif [[ -n "$HARMONY_SDK_HOME" && -d "$HARMONY_SDK_HOME/native" ]]; then
      export OHOS_SDK_NATIVE="$HARMONY_SDK_HOME/native"
    fi
  fi

  [[ -f "$OHOS_SDK_NATIVE/build/cmake/ohos.toolchain.cmake" ]] \
    || exit_message 1 "OpenHarmony native SDK not found. Set OHOS_SDK_NATIVE."

  case "$host_arch" in
    "aarch64"|"arm64"|"arm64-v8a")
      export host_arch="aarch64"
      export cmake_host_arch="aarch64"
      export ohos_arch="arm64-v8a"
      export host_target="aarch64-linux-ohos"
      export rust_target="aarch64-unknown-linux-ohos"
      ;;
    "armv7a"|"arm"|"armeabi-v7a")
      export host_arch="armv7a"
      export cmake_host_arch="armv7-a"
      export ohos_arch="armeabi-v7a"
      export host_target="arm-linux-ohos"
      export rust_target="armv7-unknown-linux-ohos"
      ;;
    "x86_64")
      export host_arch="x86_64"
      export cmake_host_arch="x86_64"
      export ohos_arch="x86_64"
      export host_target="x86_64-linux-ohos"
      export rust_target="x86_64-unknown-linux-ohos"
      ;;
    *)
      exit_message 1 "setup_ohos_environment: Unsupported host arch '$host_arch'"
      ;;
  esac

  export dependency_install_prefix="$work_dir/libraries"
  export install_pkgconfig_dir="${dependency_install_prefix}/lib/pkgconfig"
  export toolchain_bin_path="$OHOS_SDK_NATIVE/llvm/bin"
  export toolchain_sysroot="$OHOS_SDK_NATIVE/sysroot"
  export toolchain_include_path="$toolchain_sysroot/usr/include"
  export toolchain_lib_path="$toolchain_sysroot/usr/lib/$host_target"

  export CC="$toolchain_bin_path/clang"
  export CXX="$toolchain_bin_path/clang++"
  export AR="$toolchain_bin_path/llvm-ar"
  export AS="$toolchain_bin_path/llvm-as"
  export NM="$toolchain_bin_path/llvm-nm"
  export RANLIB="$toolchain_bin_path/llvm-ranlib"
  export STRIP="$toolchain_bin_path/llvm-strip"
  export LD="$toolchain_bin_path/ld.lld"

  export PKG_CONFIG_PATH="$install_pkgconfig_dir:$ffmpeg_install_prefix/lib/pkgconfig"
  export PKG_CONFIG_LIBDIR="$install_pkgconfig_dir:$toolchain_lib_path/pkgconfig"
  export PKG_CONFIG_SYSROOT_DIR="$toolchain_sysroot"
  export PATH="$toolchain_bin_path:$dependency_install_prefix/bin:$original_path:$ffmpeg_install_prefix/bin"

  create_dir "$install_pkgconfig_dir"
  create_dir "$work_dir/pkgconfig"
  create_dir "$dependency_install_prefix/{bin,lib/pkgconfig,include,usr/include}"

  reset_cross_vars
  export PREFIX="$dependency_install_prefix"
  export build_cross_compile=y

  export ohos_target_flags="--target=$host_target --sysroot=$toolchain_sysroot"
  export CFLAGS="$original_cflags $ohos_target_flags -D__OHOS__ -fPIC -I${toolchain_include_path} -I${dependency_install_prefix}/include"
  export CXXFLAGS="$original_cxxflags $ohos_target_flags -D__OHOS__ -fPIC -I${toolchain_include_path} -I${dependency_install_prefix}/include"
  export CPPFLAGS="$original_cppflags -D__OHOS__ -I${toolchain_include_path} -I${dependency_install_prefix}/include"
  export LDFLAGS="$original_ldflags $ohos_target_flags -L${dependency_install_prefix}/lib -L${toolchain_lib_path}"
}
```

`configure_ffmpeg` 中新增 OHOS 分支。建议放在 Android 分支附近：

```bash
elif isohos; then
  export PKG_CONFIG_SYSROOT_DIR="$toolchain_sysroot"
  export PKG_CONFIG_LIBDIR="$install_pkgconfig_dir:$ffmpeg_install_prefix/lib/pkgconfig:$toolchain_lib_path/pkgconfig"
  export AS="$CC"
  export LD="$CXX"

  init_options+=" --host-cc=$(command -v cc)"
  init_options+=" --cc=$CC"
  init_options+=" --cxx=$CXX"
  init_options+=" --ld=$CXX"
  init_options+=" --ar=$AR"
  init_options+=" --ranlib=$RANLIB"
  init_options+=" --nm=$NM"
  init_options+=" --strip=$STRIP"
  init_options+=" --target-os=linux"
  init_options+=" --enable-pthreads"
  init_options+=" --disable-programs"
  init_options+=" --extra-cflags='$CFLAGS'"
  init_options+=" --extra-cxxflags='$CXXFLAGS'"
  init_options+=" --extra-ldflags='$LDFLAGS'"
  init_options+=" --extra-ldexeflags='$LDFLAGS'"
fi
```

把当前的：

```bash
if [[ $host_platform == "harmony" ]]; then
```

改成：

```bash
if isohos; then
```

并保留：

```bash
truthy "$enable_ohcodec" && config_options+=" --enable-ohcodec"
```

`install_ffmpeg` 中 Android 专用的：

```bash
isandroid && export AS="$CC" && export LD="$CC"
```

建议扩展为：

```bash
(isandroid || isohos) && export AS="$CC" && export LD="$CXX"
```

### 4. 新增 `scripts/function-ohos.sh`

建议从 `scripts/function-android.sh` 复制一份，再删除 Android 专用内容。

需要保留或重写：

- `set_toolchain_paths`
- `configure_ffmpeg_kit`
- `get_generic_cmake_toolchain`
- `get_generic_meson_cross_file`
- `fix_pkgconfig_flags`
- `ffmpeg_patches`

`configure_ffmpeg_kit` 的 CMake 参数建议如下：

```bash
local cmake_params="-DCMAKE_SYSTEM_NAME=OHOS \
-DCMAKE_TOOLCHAIN_FILE=$OHOS_SDK_NATIVE/build/cmake/ohos.toolchain.cmake \
-DOHOS_PLATFORM=OHOS \
-DOHOS_ARCH=$ohos_arch \
-DOHOS_STL=c++_static \
-DCMAKE_FIND_ROOT_PATH=\"$dependency_install_prefix;$OHOS_SDK_NATIVE\" \
-DCMAKE_C_COMPILER=$CC \
-DCMAKE_CXX_COMPILER=$CXX \
-DFFMPEG_SRC_DIR=\"$ffmpeg_source_dir\" \
-DFFMPEG_BUILD_DIR=\"$ffmpeg_install_prefix\" \
-DCMAKE_INSTALL_PREFIX=\"$ffmpeg_kit_install\" \
-DFFMPEG_KIT_BUNDLE_TYPE=\"$(get_bundle_type)\" \
-DFFMPEG_KIT_VERSION=\"$(get_latest_version_from_changelog)\""
```

OHOS 不应使用这些 Android 参数：

- `-DCMAKE_SYSTEM_NAME=Android`
- `ANDROID_NDK_ROOT`
- `ANDROID_API_LEVEL`
- `ANDROID_ABI`
- `-landroid`
- `-llog`
- `JNI_OnLoad` 相关链接保留逻辑
- `create_android_aar`

`fix_pkgconfig_flags` 建议先做轻量处理：

```bash
fix_pkgconfig_flags() {
  echo "INFO: Fixing pkgconfig files for OHOS in $install_pkgconfig_dir"
  find "$install_pkgconfig_dir" -name "*.pc" -exec sed -i -E \
    -e 's/(^|[[:space:]])-lrt([[:space:]]|$)/ /g' \
    -e 's/(^|[[:space:]])-lpthread([[:space:]]|$)/ -pthread /g' \
    "{}" + 2>>"$LOG_FILE"
  find "$dependency_install_prefix/lib" -name "*.la*" -delete
}
```

如果某些依赖生成 `.pc` 时写入了 Linux 桌面库，例如 `-lX11`、`-lasound`、`-lva`，说明该依赖不适合第一阶段 OHOS build，应禁用而不是在这里强行清洗。

### 5. 新增 `scripts/deps-ohos.sh`

建议从 `scripts/deps-android.sh` 复制，再删掉明显不适合 OHOS 的依赖链。

基础版可保留：

```bash
SUB_DEPENDENCIES[build_libjsoncpp]=""
SUB_DEPENDENCIES[build_bzlib]=""
SUB_DEPENDENCIES[build_lzma]=""
SUB_DEPENDENCIES[build_zlib]=""
SUB_DEPENDENCIES[build_iconv]="build_iconv_minimal build_gettext"
SUB_DEPENDENCIES[build_openssl]=""
SUB_DEPENDENCIES[build_ohcodec]=""
```

建议禁用或暂缓：

- Android-only：`build_jni`、`build_mediacodec`
- Linux desktop：`build_alsa`、`build_libpulse`、`build_libjack`、`build_xlib`、`build_libxcb*`、`build_vaapi`、`build_v4l2`
- GPU/AI：`build_openvino`、`build_libtorch`、`build_libtensorflow`、`build_cuda_*`
- Rust heavy deps：`rav1e`、`dovi_tool` 相关依赖，除非已经验证 `*-unknown-linux-ohos` target。

### 6. 新增 `scripts/run-ohos.sh`

建议从 `scripts/run-android.sh` 开始复制，但只保留第一阶段依赖的 build 函数。不要一开始复用完整 Android 依赖表，里面有大量 `-landroid`、OpenCV Android SDK、JNI、MediaCodec 和 NDK API 逻辑。

必须提供 OHOS 系统能力占位：

```bash
build_ohcodec() {
  echo "INFO: No ohcodec library to compile. Library is provided by OpenHarmony native SDK/system." >>"$LOG_FILE"
}
```

Android-only 占位应显式禁用：

```bash
build_jni() {
  echo "INFO: JNI is Android-only; disabling on OHOS." >>"$LOG_FILE"
  disable_library "jni"
}

build_mediacodec() {
  echo "INFO: MediaCodec is Android-only; disabling on OHOS." >>"$LOG_FILE"
  disable_library "mediacodec"
}
```

Linux desktop-only 依赖也建议写成禁用函数，避免 feature preset 误触发：

```bash
build_alsa() {
  echo "INFO: ALSA is not part of the OHOS native target; disabling." >>"$LOG_FILE"
  disable_library "alsa"
}
```

### 7. `FFmpegKit/CMakeLists.txt`

需要新增 OHOS 平台分支。

`replace_static_with_shared` 中把 OHOS 当作 `.so` 平台：

```cmake
elseif(CMAKE_SYSTEM_NAME STREQUAL "Linux"
    OR CMAKE_SYSTEM_NAME STREQUAL "Android"
    OR CMAKE_SYSTEM_NAME STREQUAL "OHOS")
    string(REPLACE ".a" ".so" SHARED_PATH "${INPUT_LIB}")
```

平台 hardening 区域新增：

```cmake
elseif(CMAKE_SYSTEM_NAME STREQUAL "OHOS")
    target_compile_definitions(ffmpegkit PRIVATE
        TARGET_OS_OHOS
        __OHOS__
        _FORTIFY_SOURCE=2
    )

    target_link_libraries(ffmpegkit PRIVATE
        m
        z
        atomic
        dl
    )

    target_compile_options(ffmpegkit PRIVATE
        -fstack-protector-strong
        -fvisibility=default
        -fPIC
    )

    target_link_options(ffmpegkit PRIVATE
        "-Wl,-z,relro"
        "-Wl,-z,now"
        "-Wl,-z,noexecstack"
        "-Wl,--warn-shared-textrel"
        "-Wl,--allow-multiple-definition"
        "-Wl,--as-needed"
    )
```

如果 `--enable-ohcodec` 链接阶段没有从 FFmpeg 的 `.pc` 自动带出 native media 库，可以在 OHOS 分支中补充：

```cmake
target_link_libraries(ffmpegkit PRIVATE
    native_media_codecbase
    native_media_core
    native_media_vdec
    native_media_venc
)
```

是否存在 `native_media_venc` 取决于 SDK 版本和 FFmpeg 检测逻辑，实际以 `$OHOS_SDK_NATIVE/sysroot/usr/lib/$host_target` 下的库为准。

Android 的 JNI version script 不应套到 OHOS。`ffmpeg_kit_android.c` 本身有 `#ifdef __ANDROID__`，不会在 OHOS 编译出 JNI 符号。

## 推荐构建命令

先验证 FFmpeg 源码是否包含 `ohcodec`：

```bash
sudo ./runner.sh --host=linux --arch=x86_64 -y --run-only=download_ffmpeg --skip
prebuilt/src/ffmpeg/configure --help | grep ohcodec
```

如果没有 `--enable-ohcodec`，需要切到包含 OHCodec 支持的 FFmpeg 版本，例如更新 `--ffmpeg-git-checkout-version` 到较新的 release 或 master。

基础 OHOS native 构建建议：

```bash
export OHOS_SDK_NATIVE=/path/to/ohos-sdk/linux/native

sudo -E ./runner.sh \
  --host=ohos \
  --arch=aarch64 \
  -y \
  --enable-base \
  --enable-ohcodec \
  --build-deps-only \
  --skip

sudo -E ./runner.sh \
  --host=ohos \
  --arch=aarch64 \
  -y \
  --enable-base \
  --enable-ohcodec \
  --build-ffmpeg-only=static \
  --ff-disable-programs \
  --skip

sudo -E ./runner.sh \
  --host=ohos \
  --arch=aarch64 \
  -y \
  --enable-base \
  --enable-ohcodec \
  --build-ffmpeg-kit-only=shared \
  --skip
```

仓库当前 `runner.sh` 会要求 `sudo`，所以必须用 `sudo -E` 保留 `OHOS_SDK_NATIVE` 等环境变量。

## 验证方式

本地检查：

```bash
file prebuilt/ohos-aarch64/*/lib/libffmpegkit.so
$OHOS_SDK_NATIVE/llvm/bin/llvm-readelf -d prebuilt/ohos-aarch64/*/lib/libffmpegkit.so
$OHOS_SDK_NATIVE/llvm/bin/llvm-nm -D prebuilt/ohos-aarch64/*/lib/libffmpegkit.so | head
```

重点确认：

- ELF 架构是 `AArch64`。
- 不能依赖 Android 库，例如 `libandroid.so`、`liblog.so`、`libjnigraphics.so`。
- OHOS 系统库依赖应来自系统或 SDK，例如 native media 相关库。
- `libc++_shared.so` 是否出现取决于 `OHOS_STL`；如果选择 `c++_static`，要确认没有遗漏 C++ runtime。

设备侧验证：

```bash
hdc file send libffmpegkit.so /data/local/tmp/
hdc shell chmod 755 /data/local/tmp/libffmpegkit.so
```

更可靠的方式是写一个最小 native 测试程序，通过 C API 调用 `ffmpeg_kit_execute` 或 `ffprobe_kit_execute`，再用 OHOS NDK 编译后推到设备运行。

## 常见问题

### 1. `--enable-ohcodec` 检测失败

检查头文件和库是否存在：

```bash
find "$OHOS_SDK_NATIVE/sysroot/usr/include" -name 'native_avcodec_video*.h'
find "$OHOS_SDK_NATIVE/sysroot/usr/lib" -name 'libnative_media*'
```

FFmpeg 检测需要 native media codec 相关头文件和库。不同 SDK 版本库名可能有差异，应以 SDK 实际内容为准。

### 2. Autotools 项目不认识 `aarch64-linux-ohos`

很多第三方库的 `config.sub` 较旧，不识别 `*-ohos`。处理方式：

1. 优先更新该库源码中的 `config.sub` 和 `config.guess`。
2. 如果库本身不依赖 OS 名，可以临时传 `--host=aarch64-linux`，但仍通过 `CC/CFLAGS/LDFLAGS` 指向 OHOS 工具链和 sysroot。
3. 对复杂库单独写 OHOS patch，不要全局替换。

### 3. Meson 项目无法识别 `system = 'ohos'`

第一阶段可在 Meson cross file 中用：

```ini
[host_machine]
system = 'linux'
cpu_family = 'aarch64'
cpu = 'aarch64'
endian = 'little'
```

同时保留 OHOS 编译器、sysroot 和 pkg-config 路径。等具体依赖支持 `ohos` 后再逐个切换。

### 4. SDL2 卡住基础包

当前 `FFmpegKit/CMakeLists.txt` 的 `pkg_check_modules(FFMPEG REQUIRED ...)` 强制要求 `sdl2`。如果 OHOS 第一阶段不做 `ffplay`，建议把 SDL2 改成可选：

- `pkg_check_modules(SDL2 QUIET IMPORTED_TARGET sdl2)`
- 只有 `SDL2_FOUND` 时编译 `ffplay_lib.c` 和相关 `FFplayKit` API。
- 或保留 SDL2，但在 `run-ohos.sh` 中专门实现 SDL2 OHOS 编译。

### 5. Rust 依赖

Rust 已有 OpenHarmony target 命名，但不是所有 crate 都能无改动交叉编译。第一阶段建议禁用 `rav1e`、`libdovi`、`whisper` 等 Rust 或重依赖组件，等基础链路通了再逐项打开。

## 推荐落地顺序

1. 新增 `ohos` 平台选择、别名归一和 `setup_ohos_environment`。
2. 新增 `function-ohos.sh`，只保证 CMake、Meson、pkg-config 和 FFmpeg configure 能使用 OHOS NDK。
3. 新增最小 `run-ohos.sh` / `deps-ohos.sh`，只编基础依赖。
4. 修改 `configure_ffmpeg`，让 `isohos` 追加 `--enable-ohcodec`。
5. 修改 `FFmpegKit/CMakeLists.txt`，加入 OHOS 平台分支。
6. 先构建 `--enable-base --enable-ohcodec`。
7. 设备侧验证加载和最小转码/探测命令。
8. 再考虑 SDL2/ffplay、HAR/N-API 和全量 bundle。

## 参考资料

- OpenHarmony NDK CMake toolchain：<https://gitee.com/openharmony/build/blob/master/ohos/ndk/cmake/ohos.toolchain.cmake>
- FFmpeg OHCodec 变更记录：<https://ffmpeg.org/pipermail/ffmpeg-cvslog/2025-July/149370.html>
- Rust OpenHarmony targets：<https://doc.rust-lang.org/stable/rustc/platform-support/openharmony.html>
