AC_INIT([ffmpeg-kit], [8.0], [https://github.com/akashskypatel/ffmpeg-kit-builders/issues/new])
AC_CONFIG_MACRO_DIR([m4])
AC_CONFIG_SRCDIR([src/FFmpegKit.cpp])
AC_CONFIG_HEADERS([config.h])

# ==============================================================================
# Detect System First (Moved to Top)
# ==============================================================================

# Use modern canonical macros
AC_CANONICAL_TARGET

# Set target OS
AC_MSG_CHECKING([for target system])
case "$target" in
    *mingw32*|*mingw64*|*windows*|*win32*|*win64*)
        AC_MSG_RESULT([Windows])
        AC_DEFINE([TARGET_OS_WINDOWS], [1], [Windows target])
        AC_DEFINE([_WIN32], [1], [Windows platform])
        VERSION_OS="Windows"
        target_os_clean="windows"
        ;;
    *)
        AC_MSG_RESULT([Linux])
        AC_DEFINE([TARGET_OS_LINUX], [1], [Linux target])
        VERSION_OS="Linux"
        target_os_clean="linux"
        ;;
esac
AC_DEFINE_UNQUOTED(VERSION_OS, "$VERSION_OS", [os version])

# ==============================================================================
# Custom Argument: Copy fftools from FFmpeg Source & Apply Patches
# ==============================================================================
AC_ARG_WITH([ffmpeg-src],
    [AS_HELP_STRING([--with-ffmpeg-src=DIR], 
        [Path to FFmpeg source directory. Files from DIR/fftools will be copied to src/])],
    [ffmpeg_src_dir="$withval"],
    [ffmpeg_src_dir=""])
  
AC_ARG_WITH([ffmpeg-build],
    [AS_HELP_STRING([--with-ffmpeg-build=DIR], 
        [Path to FFmpeg build directory. "config.h" will be copied to src/])],
    [ffmpeg_build_dir="$withval"],
    [ffmpeg_build_dir=""])

# Check if the argument was provided. If not, error out.
if test "x$ffmpeg_build_dir" = "x"; then
    AC_MSG_ERROR([--with-ffmpeg-build=DIR is required. Please provide the path to the FFmpeg build directory.])
fi

# Validate build directory exists
if test ! -d "$ffmpeg_build_dir"; then
    AC_MSG_ERROR([The provided FFmpeg build directory does not exist: $ffmpeg_build_dir])
fi

# Validate include subdirectory exists
if test ! -d "$ffmpeg_build_dir/include"; then
    AC_MSG_ERROR([The directory '$ffmpeg_build_dir/include' does not exist.])
fi

# Validate config.h file exists
if test ! -f "$ffmpeg_build_dir/include/config.h"; then
    AC_MSG_ERROR([The file '$ffmpeg_build_dir/include/config.h' does not exist.])
fi

# 4. Perform the copy operation
AC_MSG_NOTICE([Copying config.h from $ffmpeg_build_dir/include to src/...])
if cp -f "$ffmpeg_build_dir/include/config.h" "src/config.h"; then
    AC_MSG_RESULT([Successfully copied config.h to src directory.])
    if test "x$target_os_clean" = "xwindows"; then
        AC_MSG_NOTICE([Patching config.h for MinGW compatibility...])
        # Disable other potentially conflicting POSIX headers
        sed -i 's/#define HAVE_UNISTD_H 1/#define HAVE_UNISTD_H 0/g' src/config.h
    fi
    cat > src/config.c <<EOF
const char program_name[[]] = "ffmpeg-kit";
const int program_birth_year = 2025;
EOF
else
    AC_MSG_ERROR([Failed to copy config.h to src directory.])
fi

# Check if the argument was provided. If not, error out.
if test "x$ffmpeg_src_dir" = "x"; then
    AC_MSG_ERROR([--with-ffmpeg-src=DIR is required. Please provide the path to the FFmpeg source directory.])
fi

AC_MSG_NOTICE([Processing FFmpeg source argument: $ffmpeg_src_dir])

# Validate source directory exists
if test ! -d "$ffmpeg_src_dir"; then
    AC_MSG_ERROR([The provided FFmpeg source directory does not exist: $ffmpeg_src_dir])
fi

# Validate fftools subdirectory exists
if test ! -d "$ffmpeg_src_dir/fftools"; then
    AC_MSG_ERROR([The directory '$ffmpeg_src_dir/fftools' does not exist.])
fi

# Ensure local destination exists
if test ! -d "src"; then
    AC_MSG_NOTICE([Creating local src directory...])
    mkdir -p "src"
fi

# Perform the copy operation
AC_MSG_NOTICE([Copying files from $ffmpeg_src_dir/fftools to src/...])
if cp -rf "$ffmpeg_src_dir/fftools/." "src/"; then
    AC_MSG_RESULT([Successfully copied fftools content to src directory.])
    rm -f "src/ffplay"*.c # remove ffplay for now
    rm -f "src/ffplay"*.h # remove ffplay for now
    AC_MSG_NOTICE([Copying stdbit compat files...])
    cp -rf "$ffmpeg_src_dir/compat/stdbit/stdbit.h" "src/stdbit.h"
else
    AC_MSG_ERROR([Failed to copy files from fftools to src.])
fi

# Apply Patches
# Checks 'patches' folder.
if test -d "patches"; then
    AC_MSG_NOTICE([Checking for patches in 'patches' directory...])
    
    # Verify git utility exists (required for robust patch checking)
    if ! command -v git >/dev/null 2>&1; then
        AC_MSG_ERROR([The 'git' utility is required for patch verification.])
    fi

    # Iterate over patch files
    for p in patches/*.patch; do
        if test -f "$p"; then
            p_name=$(basename "$p")
            AC_MSG_CHECKING([patch status for $p_name])
            
            # Check if patch is already applied using git apply
            # Returns 0 if the patch can be reversed (meaning it is already applied)

            if patch -p1 -R --dry-run --silent < "$p" >/dev/null 2>&1; then
                AC_MSG_RESULT([already applied])
            else
                # Not applied, try to apply it using standard patch
                if patch -p1 -N < "$p"; then
                    AC_MSG_RESULT([applied successfully])
                else
                    AC_MSG_RESULT([failed])
                    AC_MSG_ERROR([Failed to apply patch '$p_name'. Check for conflicts.])
                fi
            fi
        fi
    done
fi

# ==============================================================================
# Optimization Flags (Size & Stripping)
# ==============================================================================
AC_MSG_NOTICE([Applying size optimizations...])

SIZE_FLAGS="-Os -ffunction-sections -fdata-sections"
CFLAGS="$CFLAGS $SIZE_FLAGS"
CXXFLAGS="$CXXFLAGS $SIZE_FLAGS"

if test "x$target_os_clean" != "xwindows"; then
    CFLAGS="$CFLAGS -fvisibility=hidden"
    CXXFLAGS="$CXXFLAGS -fvisibility=hidden"
fi

# ==============================================================================
# Set compiler flags
# ==============================================================================

AM_INIT_AUTOMAKE([-Wall foreign subdir-objects])
AM_MAINTAINER_MODE

# Add shared/static library options
AC_ARG_ENABLE([shared],
    [AS_HELP_STRING([--enable-shared], [build shared libraries @<:@default=no@:>@])],
    [enable_shared=$enableval], [enable_shared=no])

AC_ARG_ENABLE([static],
    [AS_HELP_STRING([--enable-static], [build static libraries @<:@default=yes@:>@])],
    [enable_static=$enableval], [enable_static=yes])

if test "x$enable_shared" = "xyes"; then 
  BUILD_SHARED=yes; BUILD_STATIC=no;
else 
  BUILD_SHARED=no; BUILD_STATIC=yes;
fi
if test "x$enable_static" = "xyes"; then 
  BUILD_STATIC=yes; BUILD_SHARED=no;
else 
  BUILD_STATIC=no; BUILD_SHARED=yes;
fi

AC_SUBST([BUILD_SHARED])
AC_SUBST([BUILD_STATIC])
AM_CONDITIONAL([BUILD_STATIC_LIB], [test "x$BUILD_STATIC" = "xyes"])
AM_CONDITIONAL([BUILD_SHARED_LIB], [test "x$BUILD_SHARED" = "xyes"])

# Check for cross-compilation
AC_MSG_CHECKING([whether we are cross compiling])
if test "$cross_compiling" = yes; then
    AC_MSG_RESULT([yes])
    IS_CROSS_COMPILE=yes
else
    AC_MSG_RESULT([no])
    IS_CROSS_COMPILE=no
fi

# Allow custom toolchain programs
AC_ARG_VAR([CC], [C compiler command])
AC_ARG_VAR([CXX], [C++ compiler command])
AC_ARG_VAR([AR], [Archive maintainer command])
AC_ARG_VAR([AS], [Assembler command])
AC_ARG_VAR([NM], [Symbol listing command])
AC_ARG_VAR([RANLIB], [Archive indexer command])
AC_ARG_VAR([LD], [Linker command])
AC_ARG_VAR([STRIP], [Symbol stripper command])

# Force Windows toolchain logic
if test "x$target_os_clean" = "xwindows"; then
    AC_MSG_NOTICE([Configuring for Windows cross-compilation])
    if test -z "$CC"; then CC=x86_64-w64-mingw32-gcc; fi
    if test -z "$CXX"; then CXX=x86_64-w64-mingw32-g++; fi
    if test -z "$AR"; then AR=x86_64-w64-mingw32-ar; fi
    if test -z "$RANLIB"; then RANLIB=x86_64-w64-mingw32-ranlib; fi
    
    if test "x$enable_shared" = "xyes"; then
        LIBRARY_EXT="dll"; ARCHIVE_EXT="dll.a"
    else
        LIBRARY_EXT="a"; ARCHIVE_EXT="a"
    fi

    # WINDOWS_LDFLAGS="-Wl,--export-all-symbols -Wl,--enable-auto-import -Wl,--allow-multiple-definition"
    WINDOWS_LDFLAGS="-Wl,--enable-auto-import -Wl,--allow-multiple-definition"
else
    if test "x$enable_shared" = "xyes"; then LIBRARY_EXT="so"; ARCHIVE_EXT="so";
    else LIBRARY_EXT="a"; ARCHIVE_EXT="a"; fi
    WINDOWS_LDFLAGS=""
fi

# Build Date
if test -z "$FFMPEG_KIT_BUILD_DATE"; then
    FFMPEG_KIT_BUILD_DATE=$(date +%Y%m%d)
fi
AC_DEFINE_UNQUOTED([FFMPEG_KIT_BUILD_DATE], ["$FFMPEG_KIT_BUILD_DATE"], [FFmpegKit build date])

AC_SUBST([FFMPEG_KIT_BUILD_DATE])
AC_SUBST([LIBRARY_EXT])
AC_SUBST([ARCHIVE_EXT])
AC_SUBST([WINDOWS_LDFLAGS])

AM_CONDITIONAL([WINDOWS], [test "x$target_os_clean" = "xwindows"])
AM_CONDITIONAL([LINUX], [test "x$target_os_clean" = "xlinux"])

# Checks for programs
AC_LANG([C++])
AC_PROG_CXX
AC_PROG_CC
AM_PROG_AR
AC_CHECK_TOOL([AS], [as])
AC_CHECK_TOOL([NM], [nm])
AC_CHECK_TOOL([RANLIB], [ranlib])
AC_CHECK_TOOL([LD], [ld])
AC_CHECK_TOOL([STRIP], [strip])
AC_CHECK_FUNCS([cbrt cbrtf copysign erf hypot rint lrint lrintf round roundf trunc truncf isnan isfinite])

AX_CXX_COMPILE_STDCXX(11, noext)
LT_INIT
PKG_PROG_PKG_CONFIG

# ==============================================================================
# FFmpeg Dependency Detection (Dynamic via pkg-config)
# ==============================================================================

if test -n "$ffmpeg_build_dir"; then
    export PKG_CONFIG_PATH="$ffmpeg_build_dir/lib/pkgconfig:$PKG_CONFIG_PATH"
    AC_MSG_NOTICE([Using PKG_CONFIG_PATH: $PKG_CONFIG_PATH])
fi

PKG_CHECK_MODULES([FFMPEG], 
    [libavdevice libavfilter libavformat libavcodec libswresample libswscale libavutil jsoncpp], 
    [
        AC_MSG_NOTICE([FFmpeg and JsonCpp found.])
        AC_MSG_NOTICE([FFMPEG_CFLAGS: $FFMPEG_CFLAGS])
        CPPFLAGS="$CPPFLAGS $FFMPEG_CFLAGS"
        AC_MSG_NOTICE([FFmpeg libraries found.])
    ], 
    [
        AC_MSG_ERROR([FFmpeg libraries not found in $ffmpeg_build_dir. Check config.log.])
    ]
)

if test "x$target_os_clean" = "xwindows"; then
    WINDOWS_CFLAGS="-D_WIN32_WINNT=0x0600"
    WINDOWS_CXXFLAGS="-D_WIN32_WINNT=0x0600"
    CFLAGS="$CFLAGS $WINDOWS_CFLAGS"
    CXXFLAGS="$CXXFLAGS $WINDOWS_CXXFLAGS"
fi

AC_SUBST(FFMPEG_LIBS)
AC_SUBST(WINDOWS_CFLAGS)
AC_SUBST(WINDOWS_CXXFLAGS)

VERSION_INFO="11:0:6"
AC_SUBST(VERSION_INFO)

# Checks for typedefs, structures
AC_C_BIGENDIAN
AC_C_INLINE
AC_TYPE_INT32_T
AC_TYPE_INT64_T
AC_TYPE_SIZE_T
AC_TYPE_UINT8_T

# ==============================================================================
# Dynamic Source Detection
# ==============================================================================
AC_MSG_CHECKING([for all source and header files in src/])

# dummy file to force C compiler setup
if test ! -f "src/dummy.c"; then
    echo "/* dummy file to force C compiler setup */" > src/dummy.c
fi

FFMPEGKIT_HEADERS_VAR=""
FFMPEGKIT_OBJECTS_VAR=""

# Define the "anchor" file we will statically list in Makefile.am
STATIC_SOURCE="FFmpegKit.cpp"

if test -d "src"; then
    # 1. Scan Sources
    for f in $(find src -type f \( -name "*.c" -o -name "*.cpp" \) | sort); do
        # Strip 'src/' prefix
        rel_path=${f#src/}
        # Skip the static anchor file
        if test "$rel_path" != "$STATIC_SOURCE"; then
             # Change extension to .lo for Libtool objects
             # Use sed to replace only the last occurrence
            if test "x$enable_shared" = "xyes"; then
              objname=$(echo "$rel_path" | sed 's/\.cpp$/.lo/;s/\.c$/.lo/')
            else
              objname=$(echo "$rel_path" | sed 's/\.cpp$/.o/;s/\.c$/.o/')
            fi
             FFMPEGKIT_OBJECTS_VAR="$FFMPEGKIT_OBJECTS_VAR $objname"
        fi
    done

    # 2. Scan Headers
    for f in $(find src -type f -name "*.h" | sort); do
        rel_path=${f#src/}
        FFMPEGKIT_HEADERS_VAR="$FFMPEGKIT_HEADERS_VAR $rel_path"
    done

    # 3. Create .deps directories for subdirectories (CRITICAL FIX)
    # Automake expects 'graph/.deps/' to exist if it compiles 'graph/file.c'
    AC_MSG_NOTICE([Creating .deps directories for submodules...])
    find src -type d -name ".*" -prune -o -type d -print | while read -r dir; do
        if test "$dir" != "src"; then
            mkdir -p "$dir/.deps"
        fi
    done
fi

AC_MSG_RESULT([detected])

AC_SUBST([ffmpeg_build_dir])
AC_SUBST([FFMPEGKIT_HEADERS], [$FFMPEGKIT_HEADERS_VAR])
AC_SUBST([FFMPEGKIT_OBJECTS], [$FFMPEGKIT_OBJECTS_VAR])
# ==============================================================================

AC_CONFIG_FILES([Makefile src/Makefile])
AC_CONFIG_FILES([src/ffmpeg-kit.pc:src/ffmpeg-kit.pc.in])
AC_OUTPUT