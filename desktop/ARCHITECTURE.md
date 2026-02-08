# FFmpegKit Builders - Architecture & Workflow

## Overview

This project is a wrapper library around FFmpeg and its core tools: [ffmpeg](src/ffmpeg_lib.h), [ffprobe](src/ffprobe_lib.h), and [ffplay](src/ffplay_lib.h). The [ffmpegkit](src/FFmpegKit.hpp) library provides a native library API to other applications, allowing consuming applications to pass string arguments directly to the library as if invoking the FFmpeg tool executables.

The core philosophy is to leverage the existing code written by the FFmpeg team for `fftools`, making minimal changes to adapt them for library use.

## File Structure & Roles

The project uses a specific file structure to manage patches and source modifications:

### Source Files (`desktop/src/`)

*   **Original Source (`.c.orig`)**:
    *   Example: `ffprobe.c.orig`
    *   **Description**: These are untouched, pristine copies of the original source files from the upstream `ffmpeg/fftools` repository.
    *   **Rule**: These files must NEVER be modified. They serve as the baseline for patch generation.

*   **Patched Snapshot (`.c.bak`)**:
    *   Example: `ffprobe.c.bak`
    *   **Description**: These files represent the current state of the patched source code. They are snapshots of the files after applying the existing patches.
    *   **Rule**: These are the **primary files for development**. All modifications, fixes, and new features should be applied to these files. They are the blueprint for generating updated patches.

*   **Compiled Source (`.c`)**:
    *   Example: `ffprobe.c`
    *   **Description**: These are the actual source files used during compilation. In this workflow, they are effectively generated or overwritten by the patch application process.
    *   **Rule**: Changes should be made to `.bak` files and then formatted into a patch file. Direct edits here may be lost or not propagate correctly if determining patches against `.orig`.

### Patches (`desktop/patches/`)

*   **Patch Files (`.patch`)**:
    *   Example: `ffprobe.c.patch`
    *   **Description**: Contains the differences between the original source (`.orig`) and the modified source (`.bak`).
    *   **Rule**: These files are the source of truth for all custom modifications. The build system applies these patches to generate the final source code.

## Development Workflow

To modifying or fixing issues in `ffprobe` (or other tools), follow this strict workflow:

1.  **Modify the Snapshot (`.bak`)**:
    *   Open `desktop/src/ffprobe.c.bak`.
    *   Apply your changes (fixes, debug prints, new features) directly to this file.

2.  **Generate a Diff**:
    *   Create a unified diff between the original file and your modified backup file.
    *   Command: `git diff --no-index desktop/src/ffprobe.c.orig desktop/src/ffprobe.c.bak > desktop/patches/ffprobe.c.patch`

3.  **Clean the Patch**:
    *   Edit the generated patch file (`desktop/patches/ffprobe.c.patch`).
    *   Remove the `.orig` and `.bak` extensions from the file paths in the patch header to ensure it applies correctly to the target file (`ffprobe.c`) during the build process.
    *   Example Header Change:
        *   **From**: `--- desktop/src/ffprobe.c.orig`
        *   **To**: `--- a/src/ffprobe.c` (or relative path expected by patch command)
        *   **From**: `+++ desktop/src/ffprobe.c.bak`
        *   **To**: `+++ b/src/ffprobe.c`

4.  **Rebuild**:
    *   Run the [build script](CMakeLists.txt) to apply the updated patch and compile the project.
    *   The build system will use the new patch file to generate the final `ffprobe.c` and compile it.
