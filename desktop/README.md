# FFmpegKit for Desktop (Linux & Windows)

### 1. Features
- Provides a `C++` API with `c++11`
- Provides a `C` API wrapper for easy integration
- Supports `x86_64` and `i686` architectures
- Builds shared and static native libraries (.so, .dll, .a)
- Supports native Linux builds and cross-compilation for Windows
- Prebuilt binaries are not published

---

### 1.5 Documentation Wiki

For detailed technical guides, please refer to the following documentation:
- [C API Reference](docs/C_API.md) - Detailed guide for the C API wrapper.
- [Build System & Patching](docs/BUILD_SYSTEM.md) - Technical overview of how the desktop build works.
- [Architecture & Workflow](ARCHITECTURE.md) - Development workflow and file structure roles.

---

### 2. Building

Building FFmpegKit for Desktop is performed using the unified `runner.sh` script located in the project root directory.

#### 2.1 Pragmatic Guide

1.  **Environment Setup**: Follow the prerequisites and toolchain installation steps outlined in the [Main Repository README](../README.md#quick-start).
2.  **Basic Build**: Execute the runner script to build a base bones ffmpeg build with built-in functionality only. This build will not have any external libraries.

    ```bash
    # Build for Linux x86_64
    sudo ./runner.sh --host=linux --arch=x86_64 --enable-base -y --release

    # Build for Windows x86_64 (Cross-compile)
    sudo ./runner.sh --host=windows --arch=x86_64 --enable-base -y --release
    ```

3.  **Advanced Options**: Use `--enable-gpl` or `--enable-full` to include additional external libraries. Run `./runner.sh --help` to see all available options or refer to [Main Repository README](../README.md).

#### 2.2 Build Output

All libraries and headers created by the build process can be found under the `prebuilt` directory in the project root.
- Headers and libraries for the consolidated bundle are typically located under `prebuilt/{platform}-{arch}/bundle-.../`.

### 3. Using

#### 3.1 C++ API

FFmpegKit doesn't publish prebuilt desktop libraries. You need to build them manually and import them into your project.

You can use the following API methods to execute `FFmpeg` and `FFprobe` commands inside your application.

> [!NOTE]
> For the **C API**, see the detailed [C API Guide](docs/C_API.md).

1. Execute synchronous `FFmpeg` commands.

    ```C++
    #include <FFmpegKit.h>
    #include <FFmpegKitConfig.h>

    using namespace ffmpegkit;

    auto session = FFmpegKit::execute("-i file1.mp4 -c:v mpeg4 file2.mp4");
    if (ReturnCode::isSuccess(session->getReturnCode())) {
        // SUCCESS
    } else if (ReturnCode::isCancel(session->getReturnCode())) {
        // CANCEL
    } else {
        // FAILURE
        std::cout << "Command failed with state " << FFmpegKitConfig::sessionStateToString(session->getState()) << " and rc " << session->getReturnCode() << "." << session->getFailStackTrace() << std::endl;
    }
    ```

2. Each `execute` call (sync or async) creates a new session. Access every detail about your execution from the 
   session created.

    ```C++
    #include <FFmpegKit.h>
    #include <FFmpegKitConfig.h>

    using namespace ffmpegkit;
   
    auto session = FFmpegKit::execute("-i file1.mp4 -c:v mpeg4 file2.mp4");

    // Unique session id created for this execution
    long sessionId = session->getSessionId();

    // Command arguments as a single string
    auto command = session->getCommand();

    // Command arguments
    auto arguments = session->getArguments();

    // State of the execution. Shows whether it is still running or completed
    SessionState state = session->getState();

    // Return code for completed sessions.
    auto returnCode = session->getReturnCode();

    auto startTime = session->getStartTime();
    auto endTime = session->getEndTime();
    long duration = session->getDuration();

    // Console output generated for this execution
    auto output = session->getOutput();

    // The stack trace if FFmpegKit fails to run a command
    auto failStackTrace = session->getFailStackTrace();

    // The list of logs generated for this execution
    auto logs = session->getLogs();

    // The list of statistics generated for this execution
    auto statistics = session->getStatistics();
    ```

3. Execute asynchronous `FFmpeg` commands by providing session specific callbacks.

    ```C++
    #include <FFmpegKit.h>
    #include <FFmpegKitConfig.h>

    using namespace ffmpegkit;
   
    FFmpegKit::executeAsync("-i file1.mp4 -c:v mpeg4 file2.mp4", [](auto session) {
        const auto state = session->getState();
        auto returnCode = session->getReturnCode();
   
        std::cout << "FFmpeg process exited with state " << FFmpegKitConfig::sessionStateToString(state) << " and rc " << returnCode << "." << session->getFailStackTrace() << std::endl;
    }, [](auto log) {
        // CALLED WHEN SESSION PRINTS LOGS
    }, [](auto statistics) {
        // CALLED WHEN SESSION GENERATES STATISTICS
    });
    ```

4. Execute `FFprobe` commands.

    - Synchronous
    ```C++
    #include <FFprobeKit.h>
    #include <FFmpegKitConfig.h>

    using namespace ffmpegkit;

    auto session = FFprobeKit::execute(ffprobeCommand);
    if (!ReturnCode::isSuccess(session->getReturnCode())) {
        std::cout << "Command failed. Please check output for the details." << std::endl;
    }
    ```

5. Get media information for a file.

    ```C++
    #include <FFprobeKit.h>

    using namespace ffmpegkit;

    auto mediaInformation = FFprobeKit::getMediaInformation("<file path or uri>");
    mediaInformation->getMediaInformation();
    ```

### 4. Test Application

You can see how `FFmpegKit` is used inside an application by running the test applications developed under the `desktop/tests` directory or referring to the [FFmpegKit Test](https://github.com/akashskypatel/ffmpeg-kit-test) project.
