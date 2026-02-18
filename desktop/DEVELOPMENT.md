# FFmpegKit Builders - Architecture & Workflow

## Overview

This project is a wrapper library around FFmpeg and its core tools: [ffmpeg](src/ffmpeg_lib.h), [ffprobe](src/ffprobe_lib.h), and [ffplay](src/ffplay_lib.h). The [ffmpegkit](src/FFmpegKit.hpp) library provides a native library API to other applications, allowing consuming applications to pass string arguments directly to the library as if invoking the FFmpeg tool executables.

For a deep dive into the underlying build process, dependency bundling, and CMake configuration, see the [Build System Guide](docs/BUILD_SYSTEM.md).

The core philosophy is to leverage the existing code written by the FFmpeg team for `fftools`, making minimal changes to adapt them for library use. To achieve true concurrency (running multiple FFmpeg commands simultaneously in the same process), this project utilizes automated AST-parsing scripts to dynamically refactor FFmpeg's global memory state into Thread-Local Storage (TLS).

## File Structure & Roles

The project uses a specific file structure to manage patches and source modifications:

### Source Files (`desktop/src/`)

* **Original Source (`_orig.c`)**:
    * Example: `ffprobe_orig.c`
    * **Description**: These are untouched, pristine copies of the original source files from the upstream `ffmpeg/fftools` repository.
    * **Rule**: These files must NEVER be modified. They serve as the baseline for patch generation.

* **Patched Snapshot (`_bak.c`)**:
    * Example: `ffprobe_bak.c`
    * **Description**: These files represent the current state of the manually patched source code. They are snapshots of the files after applying the existing manual patches, but *before* the automated TLS scripts run.
    * **Rule**: These are the **primary files for manual development**. All logic modifications, fixes, and new features should be applied to these files. They are the blueprint for generating updated manual patches.

* **Compiled Source (`.c`)**:
    * Example: `ffprobe.c`
    * **Description**: These are the actual source files used during compilation. In this workflow, they are effectively generated or overwritten by the patch application and automated scripting process.
    * **Rule**: Changes should be made to `_bak` files and then formatted into a patch file. Direct edits here will be overwritten by the build system.

* **Original Source (`_orig.h`)**:
    * Example: `cmdutils_orig.h`
    * **Description**: Untouched, pristine copies of the original header files.
    * **Rule**: NEVER modify.

* **Patched Snapshot (`_bak.h`)**:
    * Example: `cmdutils_bak.h`
    * **Description**: Snapshots of the header files after applying manual patches, prior to TLS automation.
    * **Rule**: Primary files for manual header development.

* **Compiled Source (`.h`)**:
    * Example: `cmdutils.h`
    * **Description**: The actual header files used during compilation.
    * **Rule**: Do not edit directly.

* **Wrapper Source (`*_lib.c`, `*_lib.h`, `*_wrapper.cpp`, `*_wrapper.h`)**:
    * Example: `ffprobe_lib.c`
    * **Description**: These are the actual source files used to bridge FFmpeg to the FFI layer. 
    * **Rule**: These files are part of ffmpeg-kit source and can be modified directly.

### Patches (`desktop/patches/`)

* **Patch Files (`.patch`)**:
    * Example: `ffprobe.c.patch`
    * **Description**: Contains the differences between the original source (`_orig`) and the manually modified source (`_bak`).
    * **Rule**: These files are the source of truth for all custom manual modifications.

### Automated Refactoring Scripts (`scripts/`)

To support cross-platform concurrency without maintaining massive, brittle patch files, the build system employs Python scripts to dynamically rewrite FFmpeg's memory architecture at compile-time:

* **`tls_patch.py`**:
    * **Role**: Converts FFmpeg's static/global variables into Thread-Local Storage.
    * **Mechanism**: It orchestrates `clang-query` to parse the Abstract Syntax Tree (AST) of the C files, identifies every global variable declaration, and safely injects the `FFMPEG_THREAD_LOCAL` macro. This ensures each executing thread (Isolate) gets its own isolated memory state, preventing race conditions during concurrent transcodes.
* **`options_patch.py`**:
    * **Role**: Decouples FFmpeg's command-line parser from compile-time memory addresses.
    * **Mechanism**: Because the C compiler forbids placing dynamic Thread-Local addresses inside static `const OptionDef options[]` arrays, this script automatically strips the pointers (replacing them with `NULL`), removes the `const` qualifier, and generates a C function (e.g., `ffmpeg_tls_init_options()`). The native wrappers (`*_lib.c`) call these generated functions to dynamically re-bind the pointers to the current thread's memory exactly when the transcode begins.

## Development Workflow

To modify or fix issues in `ffprobe` (or other tools), follow this strict workflow:

1.  **Modify the Snapshot (`_bak.c`)**:
    * Open `desktop/src/ffprobe_bak.c`.
    * Apply your changes (fixes, debug prints, new features) directly to this file. 
    * *Note: You do not need to manually worry about thread-safety for new global variables. The automation scripts will handle TLS conversion downstream.*

2.  **Generate a Diff**:
    * Create a unified diff between the original file and your modified backup file.
    * Command: `git diff --no-index desktop/src/ffprobe_orig.c desktop/src/ffprobe_bak.c > desktop/patches/ffprobe.c.patch`

3.  **Clean the Patch**:
    * Edit the generated patch file (`desktop/patches/ffprobe.c.patch`).
    * Remove the `_orig` and `_bak` extensions from the file paths in the patch header to ensure it applies correctly to the target file (`ffprobe.c`) during the build process.
    * Example Header Change:
        * **From**: `--- desktop/src/ffprobe_orig.c`
        * **To**: `--- a/src/ffprobe.c`
        * **From**: `+++ desktop/src/ffprobe_bak.c`
        * **To**: `+++ b/src/ffprobe.c`

4.  **Rebuild**:
    * Run the runner script or follow the [Build System Guide](docs/BUILD_SYSTEM.md).
    * **The Build Sequence:**
        1. The build system copies `_orig` files into the compilation directory.
        2. It applies your updated `.patch` files to create the base modifications.
        3. It executes `tls_patch.py` to identify and mark all global variables as Thread-Local.
        4. It executes `options_patch.py` to decouple the static arrays and generate the runtime initializers.
        5. The C compiler builds the final, fully-concurrent shared library.