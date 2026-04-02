# =============================================================================
# PREAMBLE: Project Setup & Platform Validation
# =============================================================================
# - Enforce MinGW for Windows builds to prevent MSVC compatibility issues
# - Prevent in-source builds to maintain clean build directory separation
# - Initialize project with C/C++ support and enable IDE integration
# =============================================================================

cmake_minimum_required(VERSION 3.16)

# Enforce MinGW when building for Windows
if(WIN32 AND NOT MINGW)
    message(FATAL_ERROR "Windows builds require MinGW. Use MinGW-w64 toolchain for cross-compilation. MSVC is currently not supported.")
endif()

if("${CMAKE_SOURCE_DIR}" STREQUAL "${CMAKE_BINARY_DIR}")
  message(FATAL_ERROR "In-source builds are not allowed.")
endif()

# Initialize Project
project(ffmpeg-kit VERSION 8.0 LANGUAGES C CXX)

# Export compile_commands.json for Clangd
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS_DEBUG ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS_RELEASE ON)
option(BUILD_TESTS "Build tests" OFF)
option(ENABLE_LIBPLACEBO "Enable libplacebo" OFF)
option(ENABLE_LIBTENSORFLOW "Enable libtensorflow" OFF)
option(ENABLE_OPENVINO "Enable openvino" OFF)
option(ENABLE_LIBTORCH "Enable libtorch" OFF)
# CMAKE_BUILD_TYPE is a CMake built-in string variable, not a boolean option.
# Using option() on it silently converts it to OFF. Use set() instead.
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE "Release" CACHE STRING "Build type (Debug, Release, RelWithDebInfo, MinSizeRel)" FORCE)
endif()
# =============================================================================
# 1. OPTIONS & CONFIGURATION: Build Parameters & Path Validation
# =============================================================================
# - Configure build type (shared/static library, optional dependencies)
# - Validate FFmpeg source and build directory paths
# - Set build metadata (date, bundle type, version)
# ==============================================================================
option(BUILD_SHARED_LIBS "Build shared library" ON)
set(FFMPEG_KIT_BUILD_DATE "" CACHE STRING "Build date override")
set(FFMPEG_KIT_BUNDLE_TYPE "" CACHE STRING "Bundle type override")
set(FFMPEG_KIT_VERSION "" CACHE STRING "FFmpegKit version override")

# Define Paths
set(FFMPEG_SRC_DIR "" CACHE PATH "Path to FFmpeg source directory (fftools)")
set(FFMPEG_BUILD_DIR "" CACHE PATH "Path to FFmpeg build directory (libs)")

if(NOT FFMPEG_SRC_DIR OR NOT EXISTS "${FFMPEG_SRC_DIR}/fftools")
    message(FATAL_ERROR "FFMPEG_SRC_DIR is invalid. Point it to the FFmpeg source root.")
endif()

if(NOT FFMPEG_BUILD_DIR OR NOT EXISTS "${FFMPEG_BUILD_DIR}/include/config.h")
    message(FATAL_ERROR "FFMPEG_BUILD_DIR is invalid. It must contain include/config.h")
endif()

if(NOT FFMPEG_BUILD_DIR OR NOT EXISTS "${FFMPEG_BUILD_DIR}/include/config_components.h")
    message(FATAL_ERROR "FFMPEG_BUILD_DIR is invalid. It must contain include/config_components.h")
endif()

# =============================================================================
# 2. FILE COPYING & PREPARATION: Source Tree Setup
# =============================================================================
# - Copy FFmpeg configuration headers and source files
# - Apply platform-specific compatibility fixes (MinGW unistd.h)
# - Integrate FFmpeg fftools with corrected include paths
# - Copy compatibility headers for cross-platform support
# ==============================================================================
message(STATUS "Preparing source tree...")
file(MAKE_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/src")

# Copy config.h
file(COPY "${FFMPEG_BUILD_DIR}/include/config.h" DESTINATION "${CMAKE_CURRENT_SOURCE_DIR}/src/")
file(COPY "${FFMPEG_BUILD_DIR}/include/config_components.h" DESTINATION "${CMAKE_CURRENT_SOURCE_DIR}/src/")

message(STATUS "Patching config.h for SDL compatibility...")
file(READ "${CMAKE_CURRENT_SOURCE_DIR}/src/config.h" CONFIG_H_CONTENT)
string(REPLACE "#define HAVE_PTHREAD_SETNAME_NP 0" "" CONFIG_H_CONTENT "${CONFIG_H_CONTENT}")
file(WRITE "${CMAKE_CURRENT_SOURCE_DIR}/src/config.h" "${CONFIG_H_CONTENT}")

# Copy fftools (Source code)
message(STATUS "Copying fftools from ${FFMPEG_SRC_DIR}...")
#copy fftools to src/fftools.tmp
file(COPY "${FFMPEG_SRC_DIR}/fftools/" 
     DESTINATION "${CMAKE_CURRENT_SOURCE_DIR}/src/fftools.tmp"
     FILES_MATCHING
     PATTERN "*.c"
     PATTERN "*.h"
     PATTERN "*.css"
     PATTERN "*.html"
)
# replace "fftools/" in "# include" with  "" in "${CMAKE_CURRENT_SOURCE_DIR}/src/fftools.tmp"
file(GLOB_RECURSE FFTMP_FILES "${CMAKE_CURRENT_SOURCE_DIR}/src/fftools.tmp/*.c" "${CMAKE_CURRENT_SOURCE_DIR}/src/fftools.tmp/*.h")
foreach(FFTMP_FILE ${FFTMP_FILES})
    file(READ "${FFTMP_FILE}" FFTMP_CONTENT)
    string(REPLACE "#include \"fftools/" "#include \"" FFTMP_CONTENT "${FFTMP_CONTENT}")
    file(WRITE "${FFTMP_FILE}" "${FFTMP_CONTENT}")
endforeach()
# move files in fftools.tmp to src
file(COPY "${CMAKE_CURRENT_SOURCE_DIR}/src/fftools.tmp/" 
     DESTINATION "${CMAKE_CURRENT_SOURCE_DIR}/src/"
     FILES_MATCHING
     PATTERN "*"
)
# remove fftools.tmp
file(REMOVE_RECURSE "${CMAKE_CURRENT_SOURCE_DIR}/src/fftools.tmp")
# copy stdbit to src
file(COPY "${FFMPEG_SRC_DIR}/compat/stdbit/stdbit.h" DESTINATION "${CMAKE_CURRENT_SOURCE_DIR}/src/")
# copy va_copy.h to src
file(COPY "${FFMPEG_SRC_DIR}/compat/va_copy.h" DESTINATION "${CMAKE_CURRENT_SOURCE_DIR}/src/compat/")
# copy w32dlfcn.h to src
if(WIN32)
    file(COPY "${FFMPEG_SRC_DIR}/compat/w32dlfcn.h" DESTINATION "${CMAKE_CURRENT_SOURCE_DIR}/src/compat/")
endif()
# copy android compat files to src
if(ANDROID)
    file(COPY "${FFMPEG_SRC_DIR}/compat/android" DESTINATION "${CMAKE_CURRENT_SOURCE_DIR}/src/compat")
endif()
# =============================================================================
# 3. PATCH APPLICATION: Automated Source Transformation
# =============================================================================
# - Apply manual patches from patches/ directory to fix FFmpeg tools
# - Execute TLS patch script to convert globals to thread-local storage
# - Execute options patch script to handle static const arrays with TLS
# - These automated transformations enable concurrent FFmpeg execution
# ==============================================================================
if(IS_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/patches")
    message(STATUS "Checking for patches in 'patches' directory...")
    find_program(PATCH_EXECUTABLE patch REQUIRED)
    file(GLOB PATCH_FILES "${CMAKE_CURRENT_SOURCE_DIR}/patches/*.patch")
    
    foreach(PATCH_FILE ${PATCH_FILES})
        get_filename_component(PATCH_NAME ${PATCH_FILE} NAME)
        message(STATUS "Processing patch: ${PATCH_NAME}")
        
        # Check if applied (Reverse dry-run)
        execute_process(
            COMMAND ${PATCH_EXECUTABLE} -p1 -R --dry-run -s
            INPUT_FILE ${PATCH_FILE}
            WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
            RESULT_VARIABLE PATCH_APPLIED_EXIT_CODE
            OUTPUT_QUIET ERROR_QUIET
        )
        
        if(PATCH_APPLIED_EXIT_CODE EQUAL 0)
            message(STATUS "  - Already applied.")
        else()
            # Apply Patch
            execute_process(
                COMMAND ${PATCH_EXECUTABLE} -p1 -N
                INPUT_FILE ${PATCH_FILE}
                WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
                RESULT_VARIABLE PATCH_EXIT_CODE
            )
            if(NOT PATCH_EXIT_CODE EQUAL 0)
                message(FATAL_ERROR "Failed to apply patch '${PATCH_NAME}'. Check for conflicts.")
            else()
                message(STATUS "  - Applied successfully.")
            endif()
        endif()
    endforeach()

    if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/scripts/tls_patch.py")
        message(STATUS "Applying TLS (Thread Local Storage) patches...")
        execute_process(
            COMMAND python3 "${CMAKE_CURRENT_SOURCE_DIR}/scripts/tls_patch.py" 
            WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
            RESULT_VARIABLE TLS_PATCH_EXIT_CODE
        )
        if(NOT TLS_PATCH_EXIT_CODE EQUAL 0)
            message(FATAL_ERROR "Failed to apply TLS patches. Check for conflicts.")
        endif()
    else()
        message(FATAL_ERROR "TLS patch script not found. Cannot proceed.")
    endif()
endif()

# =============================================================================
# 4. SOURCE DETECTION & METADATA: Build Asset Discovery
# =============================================================================
# - Generate build metadata (date, bundle type, version)
# - Discover all source files for compilation
# - Filter out duplicate and backup files
# - Log discovered sources for debugging
# ==============================================================================
if(NOT FFMPEG_KIT_BUILD_DATE)
    string(TIMESTAMP FFMPEG_KIT_BUILD_DATE "%Y%m%d")
endif()

if(NOT FFMPEG_KIT_BUNDLE_TYPE)
    set(FFMPEG_KIT_BUNDLE_TYPE "custom")
endif()

# Find all sources
file(GLOB_RECURSE KIT_SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/src/*.c" "${CMAKE_CURRENT_SOURCE_DIR}/src/*.cpp")
file(GLOB_RECURSE KIT_HEADERS "${CMAKE_CURRENT_SOURCE_DIR}/src/*.h")

# Exclude ffplay.c and ffprobe.c as they are included in ffplay_lib.c and ffprobe_lib.c respectively
list(REMOVE_ITEM KIT_SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/src/ffplay.c")
list(REMOVE_ITEM KIT_SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/src/ffprobe.c")

# exclude _bak and _orig files
list(FILTER KIT_SOURCES EXCLUDE REGEX ".*_(bak|orig)\\.(c|cpp)$")
list(FILTER KIT_HEADERS EXCLUDE REGEX ".*_(bak|orig)\\.h$")

# print KIT_SOURCES and KIT_HEADERS
# message(STATUS "KIT_SOURCES: ${KIT_SOURCES}")
# message(STATUS "KIT_HEADERS: ${KIT_HEADERS}")

# =============================================================================
# 5. DEPENDENCY MANAGEMENT: Library Resolution & Linking
# =============================================================================
# - Create ffmpegkit target with forced includes for TLS/assert overrides
# - Configure pkg-config for FFmpeg library detection
# - Define library resolution functions for cross-platform compatibility
# - Handle optional dependencies (libplacebo, TensorFlow, OpenVINO)
# - Fix broken include paths in generated pkg-config files
# ==============================================================================
add_library(ffmpegkit ${KIT_SOURCES} ${KIT_HEADERS})

target_compile_options(ffmpegkit PRIVATE
    "-include${CMAKE_CURRENT_SOURCE_DIR}/src/ffmpeg_tls.h"
    "-include${CMAKE_CURRENT_SOURCE_DIR}/src/ffmpeg_kit_assert_override.h"
)
set_source_files_properties(
    ${KIT_SOURCES}
    # add any other .cpp files here
    PROPERTIES COMPILE_OPTIONS "-Wno-attributes"
)
set(BUNDLE_LIBRARIES "")
find_package(PkgConfig REQUIRED)

# Force PkgConfig to check the build dir first
message(STATUS "Setting PKG_CONFIG_PATH to: \"${FFMPEG_BUILD_DIR}/lib/pkgconfig:$ENV{PKG_CONFIG_PATH}\"")
set(ENV{PKG_CONFIG_PATH} "${FFMPEG_BUILD_DIR}/lib/pkgconfig:$ENV{PKG_CONFIG_PATH}")

set(PKG_CONFIG_USE_STATIC_LIBS ON)

pkg_check_modules(FFMPEG REQUIRED IMPORTED_TARGET 
    libavdevice libavfilter libavformat libavcodec libswresample libswscale libavutil jsoncpp sdl2
)

function(replace_shared_with_static INPUT_LIB OUTPUT_VAR)
    if(INPUT_LIB MATCHES "\\.dll\\.a$")
        string(REPLACE ".dll.a" ".a" STATIC_PATH "${INPUT_LIB}")
        if(EXISTS "${STATIC_PATH}")
            set(${OUTPUT_VAR} "${STATIC_PATH}" PARENT_SCOPE)
            message(STATUS "Replaced ${INPUT_LIB} with ${STATIC_PATH}")
        else()
            set(${OUTPUT_VAR} "${INPUT_LIB}" PARENT_SCOPE)
        endif()
    elseif(INPUT_LIB MATCHES "\\.dll$")
        # First try to find the actual .dll file in /bin/ directory
        string(REPLACE "/lib/" "/bin/" DLL_BIN_PATH "${INPUT_LIB}")
        if(EXISTS "${DLL_BIN_PATH}")
            set(${OUTPUT_VAR} "${DLL_BIN_PATH}" PARENT_SCOPE)
            message(STATUS "Replaced ${INPUT_LIB} with ${DLL_BIN_PATH}")
        else()
            # Fall back to static .a file in /lib/ directory
            string(REPLACE ".dll" ".a" STATIC_PATH "${INPUT_LIB}")
            if(EXISTS "${STATIC_PATH}")
                set(${OUTPUT_VAR} "${STATIC_PATH}" PARENT_SCOPE)
                message(STATUS "Replaced ${INPUT_LIB} with ${STATIC_PATH}")
            else()
                set(${OUTPUT_VAR} "${INPUT_LIB}" PARENT_SCOPE)
            endif()
        endif()
    elseif(INPUT_LIB MATCHES "\\.so$")
        # Skip system libraries for Linux builds
        if(INPUT_LIB MATCHES "^/(lib|lib64|usr/lib|usr/lib64)/")
            set(${OUTPUT_VAR} "${INPUT_LIB}" PARENT_SCOPE)
        else()
            string(REPLACE ".so" ".a" STATIC_PATH "${INPUT_LIB}")
            if(EXISTS "${STATIC_PATH}")
                set(${OUTPUT_VAR} "${STATIC_PATH}" PARENT_SCOPE)
                message(STATUS "Replaced ${INPUT_LIB} with ${STATIC_PATH}")
            else()
                set(${OUTPUT_VAR} "${INPUT_LIB}" PARENT_SCOPE)
            endif()
        endif()
    else()
        set(${OUTPUT_VAR} "${INPUT_LIB}" PARENT_SCOPE)
    endif()
endfunction()

function(replace_dll_a_with_dll INPUT_LIB OUTPUT_VAR)
    if(INPUT_LIB MATCHES "\\.dll\\.a$")
        string(REPLACE ".dll.a" ".dll" DLL_PATH "${INPUT_LIB}")
        if(EXISTS "${DLL_PATH}")
            set(${OUTPUT_VAR} "${DLL_PATH}" PARENT_SCOPE)
            message(STATUS "Replaced ${INPUT_LIB} with ${DLL_PATH}")
        else()
            # If DLL not found in lib path, try bin path
            string(REPLACE "/lib/" "/bin/" BIN_DLL_PATH "${DLL_PATH}")
            if(EXISTS "${BIN_DLL_PATH}")
                set(${OUTPUT_VAR} "${BIN_DLL_PATH}" PARENT_SCOPE)
                message(STATUS "Replaced ${INPUT_LIB} with ${BIN_DLL_PATH}")
            else()
                # Try removing lib prefix for bin path (only from filename, not full path)
                get_filename_component(LIB_DIR "${DLL_PATH}" DIRECTORY)
                get_filename_component(LIB_NAME "${DLL_PATH}" NAME_WE)
                # Only remove "lib" prefix if it exists at the start
                if(LIB_NAME MATCHES "^lib")
                    string(REPLACE "lib" "" LIB_NAME_NO_LIB "${LIB_NAME}")
                else()
                    set(LIB_NAME_NO_LIB "${LIB_NAME}")
                endif()
                # Get parent directory to remove the 'lib' subdirectory
                get_filename_component(PARENT_DIR "${LIB_DIR}" DIRECTORY)
                set(BIN_DLL_PATH_NO_LIB "${PARENT_DIR}/bin/${LIB_NAME_NO_LIB}.dll")
                if(EXISTS "${BIN_DLL_PATH_NO_LIB}")
                    set(${OUTPUT_VAR} "${BIN_DLL_PATH_NO_LIB}" PARENT_SCOPE)
                    message(STATUS "Replaced ${INPUT_LIB} with ${BIN_DLL_PATH_NO_LIB}")
                else()
                    set(${OUTPUT_VAR} "${INPUT_LIB}" PARENT_SCOPE)
                endif()
            endif()
        endif()
    else()
        set(${OUTPUT_VAR} "${INPUT_LIB}" PARENT_SCOPE)
    endif()
endfunction()

# Fix library linking for static/dynamic libraries
# If static linking is enabled, replace shared libraries with static ones: .so -> .a or .dll -> .a or .dll.a -> .a
# If dynamic linking is enabled, if MINGW, replace .dll.a files with .dll files, 
# else keep the original as dynamic linking can link to both shared and static libraries
function(configure_library_linking LIBRARY_NAME STATIC_LINKING)
    # Get the interface link libraries
    get_target_property(${LIBRARY_NAME}_LIBS PkgConfig::${LIBRARY_NAME} INTERFACE_LINK_LIBRARIES)

    set(FIXED_LIBS "")
    foreach(LIB_PATH IN LISTS ${LIBRARY_NAME}_LIBS)
        if(STATIC_LINKING)
            replace_shared_with_static("${LIB_PATH}" RESOLVED_LIB)
        else()
            if(MINGW)
                replace_dll_a_with_dll("${LIB_PATH}" RESOLVED_LIB)
            else()
                set(RESOLVED_LIB ${LIB_PATH})
            endif()
        endif()
        list(APPEND FIXED_LIBS "${RESOLVED_LIB}")
    endforeach()
    set_target_properties(PkgConfig::${LIBRARY_NAME} PROPERTIES INTERFACE_LINK_LIBRARIES "${FIXED_LIBS}")
    list(APPEND BUNDLE_LIBRARIES ${FIXED_LIBS})
    set(BUNDLE_LIBRARIES "${BUNDLE_LIBRARIES}" PARENT_SCOPE)
endfunction()

configure_library_linking(FFMPEG ON)

if(ENABLE_LIBPLACEBO)
    set(_OLD_PKG_CONFIG_USE_STATIC_LIBS ${PKG_CONFIG_USE_STATIC_LIBS})
    set(PKG_CONFIG_USE_STATIC_LIBS OFF)
    pkg_check_modules(LIBPLACEBO REQUIRED IMPORTED_TARGET libplacebo)
    configure_library_linking(LIBPLACEBO ON)
    target_link_libraries(ffmpegkit PRIVATE PkgConfig::LIBPLACEBO)
    target_compile_definitions(ffmpegkit PRIVATE PL_STATIC PLACEBO_STATIC)
    set(PKG_CONFIG_USE_STATIC_LIBS ${_OLD_PKG_CONFIG_USE_STATIC_LIBS})
endif()

# Tensorflow cannot be linked statically on Windows
if(ENABLE_LIBTENSORFLOW)
    set(_OLD_PKG_CONFIG_USE_STATIC_LIBS ${PKG_CONFIG_USE_STATIC_LIBS})
    set(PKG_CONFIG_USE_STATIC_LIBS OFF)
    pkg_check_modules(LIBTENSORFLOW REQUIRED IMPORTED_TARGET libtensorflow)
    configure_library_linking(LIBTENSORFLOW OFF)
    target_link_libraries(ffmpegkit PRIVATE PkgConfig::LIBTENSORFLOW)
    set(PKG_CONFIG_USE_STATIC_LIBS ${_OLD_PKG_CONFIG_USE_STATIC_LIBS})
endif()

if(ENABLE_OPENVINO)
    set(_OLD_PKG_CONFIG_USE_STATIC_LIBS ${PKG_CONFIG_USE_STATIC_LIBS})
    set(PKG_CONFIG_USE_STATIC_LIBS OFF)
    pkg_check_modules(OPENVINO REQUIRED IMPORTED_TARGET openvino)
    configure_library_linking(OPENVINO OFF)
    target_link_libraries(ffmpegkit PRIVATE PkgConfig::OPENVINO)
    # Try tbb12 first, fallback to tbb
    pkg_check_modules(TBB12 QUIET IMPORTED_TARGET tbb12)
    if(NOT TBB12_FOUND)
        pkg_check_modules(TBB12 REQUIRED IMPORTED_TARGET tbb)
    endif()
    configure_library_linking(TBB12 OFF)
    target_link_libraries(ffmpegkit PRIVATE PkgConfig::TBB12)
    set(PKG_CONFIG_USE_STATIC_LIBS ${_OLD_PKG_CONFIG_USE_STATIC_LIBS})
endif()

if(ENABLE_LIBTORCH)
    if(NOT WIN32)
        set(_OLD_PKG_CONFIG_USE_STATIC_LIBS ${PKG_CONFIG_USE_STATIC_LIBS})
        set(PKG_CONFIG_USE_STATIC_LIBS OFF)
        pkg_check_modules(LIBTORCH REQUIRED IMPORTED_TARGET libtorch)
        configure_library_linking(LIBTORCH OFF)
        find_library(PYTHON311_LIB
            NAMES
                python3.11
            PATHS
                /usr/lib64
                /usr/lib
                /usr/local/lib64
                /usr/local/lib
            NO_DEFAULT_PATH
        )
        if(NOT PYTHON311_LIB)
            if(EXISTS "/usr/lib64/libpython3.11.so.1.0")
                set(PYTHON311_LIB "/usr/lib64/libpython3.11.so.1.0")
            elseif(EXISTS "/usr/lib/libpython3.11.so.1.0")
                set(PYTHON311_LIB "/usr/lib/libpython3.11.so.1.0")
            endif()
        endif()
        if(NOT PYTHON311_LIB)
            message(FATAL_ERROR "Could not find libpython3.11 in /usr/lib64 or /usr/lib")
        else()
            message(STATUS "Found Python 3.11 library: ${PYTHON311_LIB}")
        endif()
        # Link system LLVM before libtorch so the dynamic linker loads it first.
        # libtensorflow_framework (a libtorch dep) bundles its own LLVM and exports
        # those symbols globally. If system libLLVM-17 loads after it, LLVM vtables
        # get crossed and cause a segfault when Mesa later loads swrast_dri.so.
        find_library(LLVM17_LIB
            NAMES LLVM-17 LLVM libLLVM-17
            PATHS /usr/lib64/llvm17/lib /usr/lib64 /usr/lib
            NO_DEFAULT_PATH
        )
        if(LLVM17_LIB)
            message(STATUS "Found system LLVM-17: ${LLVM17_LIB} (linked before libtorch to prevent symbol conflicts)")
            target_link_libraries(ffmpegkit PRIVATE ${LLVM17_LIB})
            get_filename_component(LLVM17_LIB_DIR "${LLVM17_LIB}" DIRECTORY)
        else()
            message(WARNING "System LLVM-17 not found. LLVM symbol conflicts with libtensorflow may cause crashes.")
        endif()

        target_link_libraries(ffmpegkit PRIVATE
            PkgConfig::LIBTORCH
            ${PYTHON311_LIB}
        )
        target_link_options(ffmpegkit PRIVATE
            "-Wl,-rpath,/usr/lib64"
            $<$<BOOL:${LLVM17_LIB_DIR}>:-Wl,-rpath,${LLVM17_LIB_DIR}>
        )
        set(PKG_CONFIG_USE_STATIC_LIBS ${_OLD_PKG_CONFIG_USE_STATIC_LIBS})
    endif()
endif()

# Fix for broken include paths in generated .pc files
if(TARGET PkgConfig::FFMPEG)
    get_target_property(RAW_INCLUDES PkgConfig::FFMPEG INTERFACE_INCLUDE_DIRECTORIES)
    set(VALID_INCLUDES "")
    if(RAW_INCLUDES)
        foreach(DIR ${RAW_INCLUDES})
            if(EXISTS "${DIR}")
                list(APPEND VALID_INCLUDES "${DIR}")
            endif()
        endforeach()
        set_target_properties(PkgConfig::FFMPEG PROPERTIES INTERFACE_INCLUDE_DIRECTORIES "${VALID_INCLUDES}")
    endif()
endif()

# =============================================================================
# 6. TARGET CONFIGURATION: Compiler Flags & Platform Hardening
# =============================================================================
# - Set compiler standards, include directories, and optimization flags
# - Define preprocessor macros for FFmpeg compatibility
# - Apply platform-specific security hardening (DEP, ASLR, stack protection)
# - Configure Windows/MinGW, Linux, and Android-specific settings
# ==============================================================================
target_include_directories(ffmpegkit PRIVATE 
    "${CMAKE_CURRENT_SOURCE_DIR}/src"
    "${FFMPEG_BUILD_DIR}/include"
)
link_directories("${FFMPEG_BUILD_DIR}/lib")
target_include_directories(ffmpegkit PUBLIC ${FFMPEG_INCLUDE_DIRS})

# Set C++ Standard to 17 (Required by prebuilt GoogleTest headers)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

target_compile_options(ffmpegkit PRIVATE -Os -ffunction-sections -fdata-sections)
target_compile_features(ffmpegkit PRIVATE cxx_std_17)

target_compile_definitions(ffmpegkit PRIVATE
    HAVE_CONFIG_H
    __STDC_CONSTANT_MACROS
    __STDC_LIMIT_MACROS
    __STDC_FORMAT_MACROS
)

target_compile_definitions(ffmpegkit PUBLIC
    FFMPEG_KIT_BUILD_DATE=${FFMPEG_KIT_BUILD_DATE}
    FFMPEG_KIT_BUNDLE_TYPE=\"${FFMPEG_KIT_BUNDLE_TYPE}\"
    FFMPEG_KIT_VERSION=\"${FFMPEG_KIT_VERSION}\" 
)

if(WIN32)
    set(CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS ON)

    target_compile_definitions(ffmpegkit PRIVATE
        _WIN32 WIN32 TARGET_OS_WINDOWS FFMPEG_KIT_WINDOWS
        FFMPEG_KIT_BUILDING_DLL
    )

    if(MINGW)
        target_compile_definitions(ffmpegkit PRIVATE 
            _WIN32_WINNT=0x0600
            _FORTIFY_SOURCE=2
        )
        
        target_compile_options(ffmpegkit PRIVATE 
            -fstack-protector-strong
        )

        target_link_options(ffmpegkit PRIVATE 
            "-static-libgcc" 
            "-static-libstdc++" 
            # "-nodefaultlibs"
            # "-Wl,--entry,_DllMainCRTStartup"
            "-Wl,--enable-runtime-pseudo-reloc"
            "-Wl,-u,__mingw_raise_matherr"
            "-Wl,--exclude-libs,libstdc++.a"
            "-Wl,--exclude-libs,libgcc.a"
            "-Wl,--exclude-libs,libgomp.a"
            "-Wl,--exclude-libs,libssp.a"
            "-Wl,--nxcompat"        # Data Execution Prevention (DEP)
            "-Wl,--dynamicbase"     # ASLR
            "-Wl,--high-entropy-va"   # 64-bit ASLR
            "-Wl,--enable-auto-import"
            "-Wl,--allow-multiple-definition"
            "-Wl,--stack,16777216"
        )
        target_compile_options(ffmpegkit PRIVATE 
            "-mstackrealign"
            "-mpreferred-stack-boundary=4"
        )
    endif()
elseif(CMAKE_SYSTEM_NAME MATCHES "Linux")
    target_compile_definitions(ffmpegkit PRIVATE TARGET_OS_LINUX _FORTIFY_SOURCE=2)

    # Compilation flags for hardening
    target_compile_options(ffmpegkit PRIVATE
        -fstack-protector-strong
        -fvisibility=default
        -fPIC # Required for shared libraries on Linux
    )

    # Linker hardening (RELRO and Bind Now)
    target_link_options(ffmpegkit PRIVATE
        "-Wl,-z,relro"   # Read-only relocations
        "-Wl,-z,now"     # Immediate symbol resolution (Complete RELRO)
        "-Wl,-z,noexecstack" # DEP equivalent for Linux
        "-Wl,--warn-common"
        "-Wl,--no-warn-mismatch"
    )
    pkg_check_modules(ALSA REQUIRED alsa)
    target_include_directories(ffmpegkit PRIVATE ${ALSA_INCLUDE_DIRS})

    # Allow libffmpegkit.so to find sibling libs (e.g. libpulsecommon) in the
    # same directory it is installed into (Flutter bundle's lib/ folder)
    set_target_properties(ffmpegkit PROPERTIES
        INSTALL_RPATH "$ORIGIN"
        BUILD_WITH_INSTALL_RPATH TRUE
    )
elseif(ANDROID)
    # Define Android-specific macros for source code compatibility
    target_compile_definitions(ffmpegkit PRIVATE 
        TARGET_OS_ANDROID 
        __ANDROID_API__=${ANDROID_NATIVE_API_LEVEL}
        _FORTIFY_SOURCE=2
    )

    # Link essential Android system libraries
    # 'log' is required for av_log redirection to logcat
    # 'android' and 'jnigraphics' provide native window and bitmap support
    target_link_libraries(ffmpegkit PRIVATE 
        log 
        android 
        jnigraphics 
        m 
        z 
        atomic 
        dl
    )

    # Android-specific hardening and visibility
    target_compile_options(ffmpegkit PRIVATE 
        -fstack-protector-strong 
        -fvisibility=default
        -fPIC
    )

    # Linker flags for Android (using LLD)
    target_link_options(ffmpegkit PRIVATE
        "-Wl,-z,relro"
        "-Wl,-z,now"
        "-Wl,-z,noexecstack"
        "-Wl,--warn-shared-textrel" # Warn if text relocations are found
        "-Wl,--fatal-warnings"
        "-Wl,--allow-multiple-definition"
        "-Wl,--as-needed"
        "-Wl,--verbose"
    )
endif()

# =============================================================================
# 7. LINKING & SCRIPTS: Library Integration & Build Automation
# =============================================================================
# - Configure static vs dynamic linking with proper dependency ordering
# - Generate linker scripts to control symbol visibility
# - Execute post-build scripts for library bundling and merging
# - Handle platform-specific linking requirements (whole-archive, etc.)
# ==============================================================================
option(FFMPEG_STATIC "Link against static FFmpeg libraries" ON)

target_link_directories(ffmpegkit PRIVATE "${FFMPEG_BUILD_DIR}/lib")

if(BUILD_SHARED_LIBS)
    target_compile_definitions(ffmpegkit PRIVATE DLL_EXPORT PIC)
    target_link_options(ffmpegkit PRIVATE -Wl,--no-undefined)

    if(FFMPEG_STATIC)
        # Static Link Path: Use absolute paths and whole-archive to prevent symbol stripping
        set(FFMPEG_STATIC_LIBS
            "${FFMPEG_BUILD_DIR}/lib/libavdevice.a"
            "${FFMPEG_BUILD_DIR}/lib/libavfilter.a"
            "${FFMPEG_BUILD_DIR}/lib/libavformat.a"
            "${FFMPEG_BUILD_DIR}/lib/libavcodec.a"
            "${FFMPEG_BUILD_DIR}/lib/libswresample.a"
            "${FFMPEG_BUILD_DIR}/lib/libswscale.a"
            "${FFMPEG_BUILD_DIR}/lib/libavutil.a"
        )

        if(MINGW)
            target_link_libraries(ffmpegkit PRIVATE
                # 1. CRT and threading - must resolve before anything else
                "-Wl,-Bstatic"
                "-lstdc++"
                "-lgcc"
                "-lwinpthread"
                "-Wl,-Bdynamic"

                # 2. FFmpeg core - whole-archive to prevent dead-stripping of
                #    codecs and muxers that are referenced only by string tables
                "-Wl,--whole-archive"
                ${FFMPEG_STATIC_LIBS}
                "-Wl,--no-whole-archive"

                # 3. External dependency libs from pkg-config (SDL2, openmpt, rist,
                #    etc.) - grouped to resolve circular references between them.
                #    This is the block that was previously misplaced after -Bdynamic.
                "-Wl,--start-group"
                PkgConfig::FFMPEG
                "-Wl,--end-group"

                # 4. Windows system DLLs - always dynamic, always last
                "-lkernel32"
                "-ladvapi32"
                "-luser32"
                "-lole32"
                "-lshlwapi"
                "-lbcrypt"
                "-lws2_32"
            )
        elseif(CMAKE_SYSTEM_NAME MATCHES "Linux")
            target_link_libraries(ffmpegkit PRIVATE 
                "-Wl,--whole-archive"
                ${FFMPEG_STATIC_LIBS}
                ${ALSA_LIBRARIES}
                "-Wl,--no-whole-archive"
                PkgConfig::FFMPEG
            )
        elseif(ANDROID)
            target_link_libraries(ffmpegkit PRIVATE 
                "-Wl,--whole-archive"
                ${FFMPEG_STATIC_LIBS}
                "-Wl,--no-whole-archive"
                PkgConfig::FFMPEG
            )
        else()
            target_link_libraries(ffmpegkit PRIVATE ${FFMPEG_STATIC_LIBS} PkgConfig::FFMPEG)
        endif()
    else()
        if(MINGW)
            target_link_libraries(ffmpegkit PRIVATE 
                "-Wl,--start-group"
                "${PTW32_STATIC_LIB}"
                PkgConfig::FFMPEG
                "pthread"
                "ws2_32" 
                "bcrypt"
                "-Wl,--end-group"
            )
        else()
            target_link_libraries(ffmpegkit PRIVATE PkgConfig::FFMPEG)  
        endif()
    endif()

    # Append platform-specific trailing dependencies
    if(ANDROID)
        target_link_libraries(ffmpegkit PRIVATE OpenSLES)
    endif()

    # Linker Script
    # Ensure JNI symbols are kept global in the version script
    # The existing LINKER_SCRIPT logic will work if Java_* symbols are added
    set(LINKER_SCRIPT "${CMAKE_CURRENT_BINARY_DIR}/ffmpeg-linker-script.map")
    file(WRITE ${LINKER_SCRIPT} "
{
    global:
        av*;
        swr*;
        sws*;
        ffmpeg*;
        ffprobe*;
        ffplay*;
        media_information*;
        stream_information*;
        chapter*;
        Java_*;
        JNI_OnLoad;
        ffplay_kit_session_get_video_width;
        ffplay_kit_session_get_video_height;
        extern \"C++\" {
            ffmpegkit::*;
            typeinfo*for*ffmpegkit::*;
            typeinfo*name*for*ffmpegkit::*;
            vtable*for*ffmpegkit::*;
            Json::*;
            typeinfo*for*Json::*;
            typeinfo*name*for*Json::*;
            vtable*for*Json::*;
        };
    local:
        *;
};
")
    target_link_options(ffmpegkit PRIVATE "-Wl,--version-script=${LINKER_SCRIPT}")

    # set(CMAKE_MESSAGE_LOG_LEVEL VERBOSE)
    # message(STATUS "BUNDLE_LIBRARIES: ${BUNDLE_LIBRARIES}")
    # set(CMAKE_MESSAGE_LOG_LEVEL DEBUG)
    
    # Bundling Manifest (Requires shared-library.sh)
    add_custom_command(TARGET ffmpegkit POST_BUILD
        COMMAND bash "${CMAKE_CURRENT_SOURCE_DIR}/scripts/shared-library.sh" "${FFMPEG_BUILD_DIR}" "\"${BUNDLE_LIBRARIES}\""
        COMMENT "Generating bundle manifest for shared dependencies..."
    )
else()
    set(OUTPUT_LIB "$<TARGET_FILE:ffmpegkit>")
    add_custom_command(TARGET ffmpegkit POST_BUILD
        COMMAND bash "${CMAKE_CURRENT_SOURCE_DIR}/scripts/static-library.sh" 
                "${OUTPUT_LIB}" 
                "${CMAKE_AR}" 
                "${CMAKE_RANLIB}" 
                "${FFMPEG_BUILD_DIR}"
                "\"${BUNDLE_LIBRARIES}\""
        COMMENT "Merging static libraries into monolithic archive..."
    )
endif()

# Install Hook for Bundled Libs
install(CODE "
    if(EXISTS \"${CMAKE_CURRENT_BINARY_DIR}/bundle_manifest.txt\")
        file(STRINGS \"${CMAKE_CURRENT_BINARY_DIR}/bundle_manifest.txt\" BUNDLE_LIBS)
        foreach(LIB \${BUNDLE_LIBS})
            # Standardize paths for CMake (Backslash to Forward Slash)
            string(REPLACE \"\\\\\" \"/\" LIB_CLEAN \"\${LIB}\")
            
            if(EXISTS \"\${LIB_CLEAN}\")
                message(STATUS \"Bundling: \${LIB_CLEAN}\")
                if(LIB_CLEAN MATCHES \"\\\\.dll$\")
                    # Windows DLLs go to bin
                    file(INSTALL DESTINATION \"\${CMAKE_INSTALL_PREFIX}/bin\" 
                        TYPE SHARED_LIBRARY FILES \"\${LIB_CLEAN}\")
                else()
                    # Linux/Android .so go to lib
                    file(INSTALL DESTINATION \"\${CMAKE_INSTALL_PREFIX}/lib\" 
                        TYPE SHARED_LIBRARY FILES \"\${LIB_CLEAN}\")
                endif()
            else()
                message(WARNING \"Bundle source not found: \${LIB_CLEAN}\")
            endif()
        endforeach()
    endif()
")

if(MINGW)
    target_link_libraries(ffmpegkit PRIVATE dbghelp)
endif()

# =============================================================================
# 8. INSTALLATION: Package Distribution Setup
# =============================================================================
# - Install library files (shared/static) to standard locations
# - Install public headers for client application development
# - Generate and install pkg-config file for dependency resolution
# ==============================================================================
install(TARGETS ffmpegkit
    LIBRARY DESTINATION lib
    ARCHIVE DESTINATION lib
    RUNTIME DESTINATION bin
)

install(DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/src/" 
    DESTINATION include
    FILES_MATCHING PATTERN "*.h*"
)

configure_file("src/ffmpegkit.pc.in" "ffmpegkit.pc" @ONLY)
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/ffmpegkit.pc" DESTINATION lib/pkgconfig)

# =============================================================================
# 9. TESTING: Unit Test Framework Integration
# =============================================================================
# - Enable testing infrastructure with GoogleTest framework
# - Configure cross-platform test build settings
# - Handle Windows-specific CRT conflicts for test builds
# - Add test directory to build system
# ==============================================================================
if(BUILD_TESTS)
    set_target_properties(ffmpegkit PROPERTIES
        INSTALL_RPATH "$ORIGIN:$ORIGIN/pulseaudio:/usr/lib/pulseaudio:/usr/lib64/pulseaudio:${CMAKE_SOURCE_DIR}/../prebuilt/linux-x86_64/libraries/lib:${CMAKE_SOURCE_DIR}/../prebuilt/linux-x86_64/libraries/lib/pulseaudio"
        BUILD_WITH_INSTALL_RPATH TRUE
    )
    
    enable_testing()

    include(FetchContent)
    FetchContent_Declare(
    googletest
    URL https://github.com/google/googletest/archive/refs/tags/v1.17.0.zip
    )
    # For Windows: Prevent overriding the parent project's compiler/linker settings
    set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
    # Build GoogleTest as static to avoid exporting runtime symbols and conflicting with libgcc_eh
    if(MINGW)
        set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
        set(INSTALL_GTEST OFF CACHE BOOL "" FORCE)
    endif()
    FetchContent_MakeAvailable(googletest)

    add_subdirectory(tests)
endif()