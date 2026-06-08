# FFmpeg Kit Builders 构建机制与鸿蒙 OS 适配结论

## 结论

这个仓库可以作为适配鸿蒙 OS / OpenHarmony 的基础，但当前不能直接产出鸿蒙可用的 FFmpegKit 包。

原因是仓库虽然已经出现了 `ohcodec` 和 `harmony` 的零散配置痕迹，但缺少完整的平台后端，包括平台选择、工具链初始化、依赖构建脚本、FFmpeg configure 分支、CMake toolchain 和最终打包流程。

## 当前如何编译各种形式的 FFmpeg

仓库的构建流程分为三层：

1. 外部依赖库

   `runner.sh` 解析 `--host`、`--arch`、`--enable-*` 等参数后，加载对应平台的脚本：

   - `scripts/function-<platform>.sh`
   - `scripts/run-<platform>.sh`
   - `scripts/deps-<platform>.sh`

   这些脚本负责下载、配置和编译 x264、openssl、sdl2、jsoncpp 等外部库。产物会放到：

   ```text
   prebuilt/{platform}-{arch}/libraries
   ```

2. FFmpeg 本体

   `scripts/function.sh` 中的 `configure_ffmpeg` 会根据平台拼接 FFmpeg `configure` 参数。

   典型差异包括：

   - Android 使用 NDK clang、`--target-os=android`、`--disable-programs`。
   - Windows 使用 MinGW-w64、`--target-os=mingw32`。
   - iOS / macOS 使用 Apple SDK、darwin target 和平台 SDK 参数。
   - Linux 使用本机工具链和 pthread/dl/rt 等系统库。

   FFmpeg 本体可生成：

   - 静态库：`libavcodec.a`、`libavformat.a` 等。
   - 动态库：`.so`、`.dll`、`.dylib`。
   - 命令行程序：`ffmpeg`、`ffprobe`，取决于平台和构建参数。

3. FFmpegKit 包装层

   `FFmpegKit/CMakeLists.txt` 以已经构建好的 FFmpeg 为输入，编译 `libffmpegkit`。

   这个包装层把 FFmpeg / FFprobe / FFplay 的命令执行逻辑封装成 C/C++ API，并提供日志、统计、异步 session、回调等能力。

   不同平台最终产物不同：

   - Android：AAR / `jniLibs`。
   - iOS / macOS：XCFramework。
   - Linux / Windows：普通 bundle 或 zip。

## 当前平台支持边界

README 中明确支持的平台包括：

- Android
- iOS
- macOS
- Linux
- Windows

脚本中也有 tvOS 相关结构，但还不是完整稳定支持。

当前平台选择函数 `pick_host_platform` 只接受 Linux、Windows、Android、macOS、iOS、iOS Simulator、Apple TV、Apple TV Simulator。`setup_build_environment` 也只对这些平台分发环境初始化逻辑。

因此，即使传入 `--host=harmony`，当前构建系统也无法完成平台选择和环境初始化。

## 鸿蒙 OS / OpenHarmony 相关现状

仓库里已经存在少量鸿蒙相关痕迹：

- README 的库表中列出了 `ohcodec`，描述为访问 OpenHarmony multimedia codec 能力。
- `scripts/function.sh` 中有 `host_platform == "harmony"` 时启用 `--enable-ohcodec` 的分支。
- 多个平台的 `run-*.sh` 中都有 `build_ohcodec` 占位函数，但基本只是输出“Only available on Harmony build”。

这些说明作者已经意识到 OpenHarmony 硬编硬解方向，但还没有实现真正的 Harmony/OpenHarmony 平台构建后端。

## 适配鸿蒙需要补齐的内容

建议按最小可用版本推进，而不是一开始打开完整 feature bundle。

### 1. 增加平台入口

需要让以下逻辑识别 `harmony` / `ohos` / `openharmony`：

- `pick_host_platform`
- `runner.sh` 中的 `source_platform` 选择
- `setup_build_environment`
- `is*` 平台判断函数，新增 `isharmony` 或 `isohos`

### 2. 增加鸿蒙工具链环境

新增类似 `setup_android_environment` 的函数，例如：

```bash
setup_harmony_environment
```

它需要配置 OpenHarmony Native SDK：

- `OHOS_SDK_HOME` 或类似 SDK 根目录变量。
- clang / clang++。
- llvm-ar、llvm-ranlib、llvm-strip、llvm-nm。
- sysroot。
- target triple，例如 `aarch64-linux-ohos`、`arm-linux-ohos`、`x86_64-linux-ohos`。
- `CFLAGS`、`CXXFLAGS`、`CPPFLAGS`、`LDFLAGS`。
- `PKG_CONFIG_PATH` / `PKG_CONFIG_LIBDIR`。

### 3. 增加平台脚本

至少新增：

```text
scripts/function-harmony.sh
scripts/run-harmony.sh
scripts/deps-harmony.sh
```

初版可以从 Android 脚本裁剪，而不是从 Linux 脚本直接复制。原因是鸿蒙同样是交叉编译目标，工具链和 sysroot 模型更接近 Android NDK。

### 4. 调整 FFmpeg configure

需要增加 Harmony/OpenHarmony 分支，处理：

- `--enable-cross-compile`
- `--arch`
- `--cc`
- `--cxx`
- `--ar`
- `--ranlib`
- `--strip`
- `--nm`
- `--sysroot`
- `--extra-cflags`
- `--extra-ldflags`
- 是否启用 `--enable-ohcodec`

初版建议禁用命令行程序，只构建库和 FFmpegKit：

```text
--disable-programs
--enable-pic
--enable-static
--disable-shared
```

最终是否构建 `.so`，由 FFmpegKit 包装层控制。

### 5. 先做最小依赖集合

第一阶段建议只打开 base 能力：

- FFmpeg 内建编解码能力。
- zlib / bzlib / lzma / iconv 等基础库。
- jsoncpp。
- 必要时禁用 SDL2 和 FFplay。

暂时不要打开：

- Linux 桌面采集相关库。
- Android JNI / MediaCodec。
- Apple VideoToolbox / Metal / CoreImage。
- Windows D3D / MediaFoundation。
- 复杂 AI / GPU / OpenCV / Torch / TensorFlow 依赖。

### 6. 第二阶段再接入 ohcodec

`ohcodec` 是鸿蒙硬件编解码能力，不应作为最小移植的第一步。

原因：

- 它依赖 OpenHarmony native media codec 相关系统头文件和系统库。
- 需要确认 FFmpeg 当前版本的 `--enable-ohcodec` 对目标 OpenHarmony SDK 版本的兼容性。
- 还需要处理运行时权限、系统库加载、编码/解码器枚举和设备差异。

## 推荐实施路线

1. 先实现 `--host=harmony --arch=aarch64 --enable-base`。
2. 编出 FFmpeg 静态库。
3. 编出 `libffmpegkit.so`。
4. 在鸿蒙 native demo 中验证最基础命令，例如读取媒体信息或转封装。
5. 增加基础外部库，如 zlib、openssl。
6. 再启用 `--enable-ohcodec`，验证硬解和硬编。
7. 最后再考虑包管理格式、完整 bundle、许可证收集和发布流程。

## 风险点

- 外部依赖库数量很多，完整 bundle 对新平台的移植成本很高。
- FFmpegKit 包装层中部分平台 glue 目前只有 Android / Apple / Windows / Linux 特殊处理，鸿蒙可能需要单独宏和链接规则。
- OpenHarmony Native SDK 的 sysroot、系统库命名和 target triple 需要和实际 SDK 版本对齐。
- `ohcodec` 可能涉及非自由或平台限制能力，发布前需要单独确认许可证和分发条件。

## 总体判断

适配鸿蒙 OS 是可行的，但应视为新增一个完整目标平台，而不是启用已有隐藏功能。

当前仓库的价值在于已经有成熟的多平台构建框架、依赖配方、FFmpegKit 包装层和产物打包模型。鸿蒙适配的主要工作是补齐 OpenHarmony 工具链、平台配置和最小依赖集，然后逐步打开 `ohcodec` 和更多外部功能。

## 关于 FFmpeg 命令参数支持的结论

鸿蒙适配后，不能只满足“能编出一个 FFmpeg”。这个库的核心价值之一是 FFmpegKit 可以执行大量 FFmpeg / FFprobe / FFplay 风格的命令参数，因此鸿蒙版本也应该尽量保持同样的命令行为。

需要明确的是，FFmpegKit 自身并不重新实现 FFmpeg 的命令参数解析。它主要负责把命令字符串拆分、创建 session、转发日志/统计/回调，并调用内嵌的 FFmpeg / FFprobe / FFplay 逻辑。真正决定某个参数是否可用的是 FFmpeg 本体的编译配置。

也就是说，运行时参数支持由以下内容共同决定：

- FFmpeg 编译时启用了哪些 encoders、decoders、muxers、demuxers。
- FFmpeg 编译时启用了哪些 filters、bsfs、protocols。
- 外部库是否成功移植，例如 x264、x265、libvpx、openssl、freetype、fontconfig、ass、opus、vorbis 等。
- 平台硬件能力是否存在，例如 Android MediaCodec、Apple VideoToolbox、Windows MediaFoundation、OpenHarmony ohcodec。
- 平台系统 API 是否存在，例如 ALSA、X11、D3D、CoreImage 等。

因此，不能承诺鸿蒙版本天然支持“所有 FFmpeg 参数”。更准确的结论是：

1. 通用 FFmpeg CLI 参数应该支持。

   例如 `-i`、`-map`、`-c:v`、`-c:a`、`-f`、`-filter_complex`、`-vf`、`-af`、`-ss`、`-t`、`-y`、`-loglevel`、`-hide_banner` 等。这些属于 FFmpeg 通用命令框架，只要 FFmpeg 本体和 FFmpegKit 包装层正常工作，就应该保持一致。

2. 编解码、封装、滤镜、协议相关参数必须由对应组件支撑。

   例如 `-c:v libx264` 依赖 x264，`-c:a libopus` 依赖 libopus，`subtitles`/`ass` 滤镜依赖 libass、freetype、fontconfig，`https` 输入依赖 openssl/gnutls/mbedtls 等 TLS 库。鸿蒙平台如果没有移植这些依赖，对应参数就不能算支持。

3. 平台专属参数不能跨平台强行支持。

   Android 的 `mediacodec`、Apple 的 `videotoolbox`、Windows 的 `d3d11va` / `mediafoundation`、Linux 桌面的 ALSA / X11 / VAAPI 等，不能在鸿蒙上原样支持。鸿蒙上应该用 OpenHarmony 对应能力，例如 `ohcodec`，但这不是对其他平台参数的一比一替代。

4. FFplay 相关参数需要单独评估。

   当前仓库包含 FFplay 支持，并依赖 SDL2。鸿蒙如果没有稳定移植 SDL2 或没有实现等价渲染/音频输出层，FFplay 相关参数不能默认认为可用。第一阶段建议优先保障 FFmpeg 和 FFprobe，FFplay 后置。

## 鸿蒙版本的参数支持目标

如果要求“每个参数都要支持”，需要把目标定义为可验证的能力矩阵，而不是口头承诺。

推荐目标分三档：

1. 最小可用档

   支持 FFmpeg 通用命令框架、基础 demux/mux、基础软件编解码、基础 filter、FFprobe 媒体信息读取。

2. 对齐现有移动端档

   在最小可用档基础上，移植 Android/iOS 常用 bundle 中的通用外部库，例如 openssl、x264、x265、libvpx、opus、vorbis、ass、freetype、fontconfig、webp、dav1d 等。目标是让大多数跨平台 FFmpeg 命令在鸿蒙上表现一致。

3. 鸿蒙完整档

   在对齐现有移动端档基础上，启用 `ohcodec`，验证硬解、硬编、像素格式、码率控制、关键帧、分辨率限制、异常回退等行为。

## 参数支持验证方式

鸿蒙适配完成后，应把参数支持作为测试项，而不是只看编译是否成功。

建议至少输出并对比以下命令：

```bash
ffmpeg -hide_banner -buildconf
ffmpeg -hide_banner -version
ffmpeg -hide_banner -formats
ffmpeg -hide_banner -codecs
ffmpeg -hide_banner -encoders
ffmpeg -hide_banner -decoders
ffmpeg -hide_banner -filters
ffmpeg -hide_banner -protocols
ffprobe -hide_banner -version
```

同时维护一组跨平台命令回归用例：

```bash
ffmpeg -y -i input.mp4 -c copy output.mkv
ffmpeg -y -i input.mp4 -vf scale=640:-2 -c:v libx264 -c:a aac output.mp4
ffmpeg -y -i input.wav -af volume=0.5 output.wav
ffprobe -v error -show_format -show_streams -of json input.mp4
```

如果启用 `ohcodec`，还需要增加鸿蒙硬编硬解专项用例：

```bash
ffmpeg -hide_banner -encoders | grep -i oh
ffmpeg -hide_banner -decoders | grep -i oh
```

最终交付标准应该是：鸿蒙构建产物的 `buildconf`、`formats`、`codecs`、`filters`、`protocols` 与目标 bundle 的能力矩阵一致。只有矩阵中标记为支持的参数，才算真正支持。

## OHOS_SDK_HOME 到底需要什么 SDK

鸿蒙生态里"SDK"是一个被多次复用的词，必须先把范围限定清楚，再决定 `OHOS_SDK_HOME` 指向什么。

可选项及取舍：

1. OpenHarmony Native SDK（推荐，本仓库默认目标）

   - 名称：OpenHarmony SDK，使用其中的 `native/` 子目录。
   - 公开发布、license 清晰，既可通过 DevEco Studio `command-line-tools` 安装，也可从 OpenHarmony 官方/华为云镜像直接下载。
   - 包含交叉编译 FFmpeg 所需的全套工具链：
     - `native/llvm/bin/` 下的 clang、clang++、llvm-ar、llvm-ranlib、llvm-strip、llvm-nm、lld。
       同时提供 target 预绑定的 wrapper：`aarch64-unknown-linux-ohos-clang(++)`、`armv7-unknown-linux-ohos-clang(++)`。可以直接用 wrapper（target 已内置），也可以用裸 `clang --target=aarch64-linux-ohos --sysroot=...`。
     - `native/sysroot/usr/include/` 通用头；`native/sysroot/usr/include/multimedia/player_framework/` 下有 `native_avcodec_*.h`。
     - `native/sysroot/usr/lib/<triple>/` 提供 `libc.so`、`libdl.a`、`libm.a`、`libpthread.a`、`librt.a`、`libz.so` 等核心库，以及 `libnative_media_*.so` 这一组媒体 NDK 库。OpenHarmony libc 基于 musl 改造，但保留了 `libpthread.a` / `libdl.a` / `librt.a` / `libm.a` 等占位归档，常规链接选项与 glibc/Android 大体兼容。
     - `native/build/cmake/ohos.toolchain.cmake` 官方 CMake toolchain 文件。
     - `native/build-tools/cmake/` 配套的 cmake 二进制（可用，也可以用宿主 cmake）。
   - sysroot 目录名（用于 `--sysroot/<triple>/lib`、`-L`）：
     - `aarch64-linux-ohos`（主目标）
     - `arm-linux-ohos`
     - `x86_64-linux-ohos`
     注意 clang wrapper 文件名里多了一段 `unknown`（如 `aarch64-unknown-linux-ohos-clang`），sysroot 目录名里没有 `unknown`。脚本里要分清这两套写法。
   - `OHOS_ARCH` 取值（CMake toolchain 约定，不是 triple）：
     - `arm64-v8a`（对应 aarch64-linux-ohos）
     - `armeabi-v7a`（对应 arm-linux-ohos）
     - `x86_64`（对应 x86_64-linux-ohos）
     不要把 `aarch64` 直接传给 `-DOHOS_ARCH=`，`ohos.toolchain.cmake` 会以 `unrecognized` 报错退出。
   - 版本验证：本仓库已确认可用的 SDK 是 `apiVersion: 24` / `version: 6.1.1.125`（OpenHarmony 6.x 线），由 `native/oh-uni-package.json` 标识。任何 API 12 / OpenHarmony 5.0 LTS 及以上的 native SDK 都满足启用 `--enable-ohcodec` 的头/库需求；更低版本只能作为最小可用档（不启 ohcodec）使用。

2. HarmonyOS NEXT（鸿蒙 5）Native SDK（不推荐用于容器化构建）

   - 由 DevEco Studio 商业版安装，目录结构与 OpenHarmony Native SDK 接近，但分发不公开、license 受限。
   - 适合在本地 IDE 环境里小范围验证，不适合放到 CI Docker 镜像里。

3. HarmonyOS / OpenHarmony 应用层 SDK（不适用）

   - 包含 ArkTS、JS、previewer、toolchains 等子目录，是给应用开发用的，不包含 C/C++ 交叉工具链，不能用于编译 FFmpeg。

结论：**`OHOS_SDK_HOME` 应该指向 OpenHarmony Native SDK 的 `native/` 目录**。

宿主机本地实测路径形如：

```bash
# DevEco Studio command-line-tools 安装出来的形态（本仓库验证过的真实路径）
OHOS_SDK_HOME=/path/to/command-line-tools/sdk/default/openharmony/native

# Docker 中烘焙的形态（示例）
OHOS_SDK_HOME=/opt/ohos-sdk/native
```

即使最终是要在 HarmonyOS 真机上跑，用 OpenHarmony Native SDK 编出来的 `.so` 通常也能加载执行，因为 HarmonyOS native 层与 OpenHarmony native ABI 兼容。商业 HarmonyOS NEXT SDK 只在需要鸿蒙商业 API 时才必须使用。

## 推荐的 SDK 获取方式

两条路线，最终产物都是同一份 `native/` 目录，脚本和 Dockerfile 只看 `OHOS_SDK_HOME` 这个变量，不关心来源。

1. **DevEco Studio command-line-tools（本地开发推荐）**

   下载 OpenHarmony 官方提供的 `command-line-tools` 压缩包并解压，解压后路径形如：

   ```text
   command-line-tools/sdk/default/openharmony/native/
   ├── build/cmake/ohos.toolchain.cmake
   ├── build-tools/cmake/
   ├── llvm/bin/{clang, aarch64-unknown-linux-ohos-clang, ...}
   ├── oh-uni-package.json
   └── sysroot/usr/{include, lib/{aarch64-linux-ohos, arm-linux-ohos, x86_64-linux-ohos}}
   ```

   把 `native/` 这一层作为 `OHOS_SDK_HOME` 即可，这就是本仓库目前使用的实际形态。

2. **华为云 / OpenHarmony 镜像直接下载（CI / Docker 推荐）**

   公开镜像（Linux Docker 中直接 `curl`/`wget` 可用）：

   ```text
   https://repo.huaweicloud.com/openharmony/os/<version>/ohos-sdk-windows_linux-public.tar.gz
   ```

   下载后解压取其中的 `linux/native/`（不同发布版本目录结构可能略有差异），Windows 部分可以丢掉以减小镜像体积。具体 URL、压缩格式和版本号以 OpenHarmony 官方发布页为准。

## 在现有 Docker 里编译鸿蒙版本

当前 `docker/Dockerfile` 是 manylinux 2.28 (AlmaLinux 8) 基础镜像，已经预装了 Android NDK、xPack MinGW、ARM 工具链、Rust、Flutter、Wine、Java、Gradle 等。鸿蒙构建在此镜像里属于"再叠加一份交叉工具链"，不需要重做基础镜像。

总体流程分为四步：镜像里准备 OpenHarmony Native SDK → 进入容器 → 跑改造后的 `runner.sh` → 取出产物。

### 1. 在镜像里准备 OpenHarmony Native SDK

最简单的方式是把宿主机已经安装好的 SDK 直接 bind-mount 进容器，避免在 Dockerfile 里走下载步骤：

```bash
HOST_OHOS_NATIVE=/Users/<you>/Downloads/command-line-tools/sdk/default/openharmony/native
docker run --rm -it \
  -v "${HOST_OHOS_NATIVE}:/opt/ohos-sdk/native:ro" \
  -e OHOS_SDK_HOME=/opt/ohos-sdk/native \
  -v "$(pwd)/..:/workspace" \
  -w /workspace \
  ffmpeg-kit-builders:latest \
  bash
```

如果要把 SDK 烧进镜像（更利于 CI 复现），在 `docker/Dockerfile` 现有 Android SDK 步骤之后追加一节，例如：

```dockerfile
# 9. Install OpenHarmony Native SDK
ENV OHOS_SDK_HOME=/opt/ohos-sdk/native
ENV PATH="${OHOS_SDK_HOME}/llvm/bin:${PATH}"

ARG OHOS_SDK_URL=https://repo.huaweicloud.com/openharmony/os/<version>/ohos-sdk-windows_linux-public.tar.gz
RUN curl -L -o /tmp/ohos-sdk.tar.gz "${OHOS_SDK_URL}" && \
    mkdir -p /opt/ohos-sdk && \
    tar -xzf /tmp/ohos-sdk.tar.gz -C /tmp && \
    mv /tmp/ohos-sdk/linux/native /opt/ohos-sdk/native && \
    rm -rf /tmp/ohos-sdk /tmp/ohos-sdk.tar.gz && \
    chown -R vscode:vscode /opt/ohos-sdk
```

要点：

- 把 `OHOS_SDK_HOME` 指向 `native/` 这一层，而不是 `ohos-sdk/` 或 `openharmony/`。
- 只保留 `linux/native`，删掉 `windows/` 可显著减小镜像体积。
- 设置 `PATH=${OHOS_SDK_HOME}/llvm/bin:${PATH}`，让脚本和交互式 shell 都能直接看到 `clang`、`llvm-ar`、`aarch64-unknown-linux-ohos-clang` 等。
- 把所有权交给 `vscode`，与镜像中其它 SDK 的做法一致。
- 如果要复用本仓库 6.1.1.125 验证过的 SDK，把 `ARG OHOS_SDK_URL=` 钉到官方对应版本的归档 URL；具体 URL 以发布页为准。

两种方案不能并存：用 bind-mount 时，不要再在 Dockerfile 里写 `ENV OHOS_SDK_HOME`，否则容器内会被镜像里的空目录覆盖。

### 2. 启动容器

镜像构建完成后：

```bash
cd docker
docker build -t ffmpeg-kit-builders:latest .

docker run --rm -it \
  -v "$(pwd)/..:/workspace" \
  -w /workspace \
  ffmpeg-kit-builders:latest \
  bash
```

如果选择 bind-mount SDK 的方式，再加上：

```bash
  -v "${HOST_OHOS_NATIVE}:/opt/ohos-sdk/native:ro" \
  -e OHOS_SDK_HOME=/opt/ohos-sdk/native \
```

容器里应该可以直接执行：

```bash
echo "$OHOS_SDK_HOME"
cat "$OHOS_SDK_HOME/oh-uni-package.json"            # 看到 apiVersion / version
"$OHOS_SDK_HOME/llvm/bin/clang" --version
"$OHOS_SDK_HOME/llvm/bin/aarch64-unknown-linux-ohos-clang" --version
ls "$OHOS_SDK_HOME/sysroot/usr/lib/aarch64-linux-ohos" | head
```

五条命令都正常输出，说明 SDK 接入成功。

### 3. 触发鸿蒙构建

脚本侧改造完成（新增 `function-harmony.sh`、`run-harmony.sh`、`deps-harmony.sh`，并在 `pick_host_platform`、`setup_build_environment`、`configure_ffmpeg` 等处接入 `harmony` 分支）后，在容器里调用：

```bash
./runner.sh \
  --host=harmony \
  --arch=arm64-v8a \
  --enable-base
```

注：脚本侧 `--arch` 的取值建议直接采用 `ohos.toolchain.cmake` 约定的 `arm64-v8a` / `armeabi-v7a` / `x86_64`，而不是裸 triple 里的 `aarch64` / `arm`。这样 FFmpegKit 的 CMake 调用可以直接把 `--arch` 透传到 `-DOHOS_ARCH=`，不用再做一次映射；FFmpeg `configure --arch=` 还是会用 `aarch64` / `arm` / `x86_64`，由 `function-harmony.sh` 内部做一次翻译。

第一阶段建议显式禁用桌面/移动端专属库，避免 deps 阶段失败：

```bash
./runner.sh \
  --host=harmony \
  --arch=arm64-v8a \
  --enable-base \
  --disable-sdl2 \
  --disable-ffplay
```

如果想验证多架构：

```bash
./runner.sh --host=harmony --arch=armeabi-v7a --enable-base
./runner.sh --host=harmony --arch=x86_64      --enable-base
```

构建过程中应能在日志里看到：

- `pick_host_platform` 命中 `harmony` 分支。
- `setup_harmony_environment` 打印出 `OHOS_SDK_HOME`、`CC`（指向 `aarch64-unknown-linux-ohos-clang` 或带 `--target` 的裸 `clang`）、`AR`（`llvm-ar`）、`SYSROOT`（`${OHOS_SDK_HOME}/sysroot`）、target triple（`aarch64-linux-ohos`）。
- FFmpeg `configure` 行包含 `--enable-cross-compile`、`--target-os=`（实现层可以选择写成 `linux` 或新增的 `harmony`/`ohos`，FFmpeg 6.1+ 已支持 `ohos`）、`--arch=aarch64`、`--sysroot=${OHOS_SDK_HOME}/sysroot`、`--cc=...clang`、`--ar=...llvm-ar` 等。

### 4. 取出产物

产物路径与其它平台一致（按 `host-arch` 命名，`arch` 与 `OHOS_ARCH` 风格保持一致）：

```text
prebuilt/harmony-arm64-v8a/
  libraries/             # 外部依赖库的 .a / .so
  ffmpeg/                # FFmpeg 源码与构建中间产物
  ffmpeg-kit/            # libffmpegkit 输出
```

从宿主机取出：

```bash
docker cp <container>:/workspace/prebuilt/harmony-arm64-v8a ./out/
```

如果使用了 bind-mount `-v "$(pwd)/..:/workspace"`，产物会直接落到宿主机源码目录下，不需要 `docker cp`。

### 5. 第二阶段：启用 ohcodec

确认最小可用档能跑通后，再叠加：

```bash
./runner.sh \
  --host=harmony \
  --arch=arm64-v8a \
  --enable-base \
  --enable-ohcodec
```

启用前需要确认：

- 头文件存在：`$OHOS_SDK_HOME/sysroot/usr/include/multimedia/player_framework/native_avcodec_base.h`、`native_avcodec_videodecoder.h`、`native_avcodec_videoencoder.h`、`native_avcodec_audiocodec.h` 等。
- 库存在：`$OHOS_SDK_HOME/sysroot/usr/lib/aarch64-linux-ohos/` 下应能看到 `libnative_media_codecbase.so`、`libnative_media_core.so`、`libnative_media_vdec.so`、`libnative_media_venc.so`、`libnative_media_acodec.so`、`libnative_media_avdemuxer.so`、`libnative_media_avsource.so` 等。本仓库 6.1.1.125 SDK 已经齐全。
- FFmpeg 源码里 `libavcodec/ohcodec*.c` 与该 SDK 版本兼容。

如果以上任一条件不满足，应保持 `--enable-ohcodec` 关闭，先交付软件编解码版本。

### 6. 常见坑

- **clang wrapper vs 裸 clang**：`llvm/bin/` 里既有 target 预绑定的 `aarch64-unknown-linux-ohos-clang`（注意带 `unknown`），也有裸 `clang`。两者都能用；用裸 `clang` 时必须显式带 `--target=aarch64-linux-ohos --sysroot=$OHOS_SDK_HOME/sysroot`。脚本里只挑一种，避免 wrapper 与 `--target` 同时设置导致混乱。
- **OHOS_ARCH 取值**：`-DOHOS_ARCH=` 只接受 `arm64-v8a` / `armeabi-v7a` / `x86_64`，不接受 `aarch64` / `arm`。FFmpeg `--arch=` 用的则是 `aarch64` / `arm` / `x86_64`，两套写法要在脚本里映射好。
- **musl 风味的 libc**：OpenHarmony libc 在 musl 基础上做了改造，部分 glibc 专属符号缺失（例如 `<execinfo.h>`、`backtrace`、`getauxval` 行为差异），依赖库的 configure 不要假设 glibc。但 sysroot 里保留了 `libpthread.a` / `libdl.a` / `librt.a` / `libm.a` 占位归档，常规 `-lpthread -ldl -lrt -lm` 仍然可写，不会报找不到。
- **pkg-config**：必须把 `PKG_CONFIG_LIBDIR` 指向自己 deps 安装出来的 `prebuilt/.../lib/pkgconfig`（SDK 自身没有提供系统级 `.pc`），并清空 `PKG_CONFIG_PATH`，防止链接到宿主 manylinux 的 `/usr/lib64`。
- **可执行程序**：第一阶段建议 `--disable-programs`，不要在容器里强行让 FFmpeg CLI 跑起来——ohos 目标的可执行文件不能在 manylinux 宿主直接运行，CLI 验证应放到真机/模拟器。
- **CMake**：FFmpegKit 包装层走 CMake 时，应使用 `$OHOS_SDK_HOME/build/cmake/ohos.toolchain.cmake`，并通过 `-DCMAKE_TOOLCHAIN_FILE=$OHOS_SDK_HOME/build/cmake/ohos.toolchain.cmake`、`-DOHOS_ARCH=arm64-v8a`（不是 `aarch64`）、`-DOHOS_PLATFORM=OHOS` 传参，而不是手写一份新的 toolchain 文件。
- **缓存隔离**：`prebuilt/harmony-arm64-v8a` 与 `prebuilt/android-arm64-v8a` 必须保持目录隔离，否则共享的 `libraries/` 会污染其它平台的产物。

### 7. 最小冒烟验证

在容器里完成首次构建后，至少跑以下三件事确认 toolchain 装得对：

```bash
file prebuilt/harmony-arm64-v8a/ffmpeg-kit/libffmpegkit.so
# 期望输出包含: ELF 64-bit LSB shared object, ARM aarch64

${OHOS_SDK_HOME}/llvm/bin/llvm-readelf -d \
  prebuilt/harmony-arm64-v8a/ffmpeg-kit/libffmpegkit.so | head
# 期望 NEEDED 列表中出现 libc.so / libdl.so / libm.so，且不出现 Android 专有库

${OHOS_SDK_HOME}/llvm/bin/llvm-nm -D \
  prebuilt/harmony-arm64-v8a/ffmpeg-kit/libffmpegkit.so | grep -c ffmpegkit
# 期望 > 0
```

然后再把产物拷到 OpenHarmony / HarmonyOS 真机或模拟器里做 FFmpeg/FFprobe 命令的回归测试，对照前文的能力矩阵逐项打钩。
