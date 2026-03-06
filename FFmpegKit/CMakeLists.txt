cmake_minimum_required(VERSION 3.16)

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
option(CMAKE_BUILD_TYPE "Build type" "Release")
# ==============================================================================
# 1. Options & Configuration
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

# ==============================================================================
# 2. File Copying & Preparation
# ==============================================================================
message(STATUS "Preparing source tree...")
file(MAKE_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/src")

# Copy config.h
file(COPY "${FFMPEG_BUILD_DIR}/include/config.h" DESTINATION "${CMAKE_CURRENT_SOURCE_DIR}/src/")
file(COPY "${FFMPEG_BUILD_DIR}/include/config_components.h" DESTINATION "${CMAKE_CURRENT_SOURCE_DIR}/src/")

if(MINGW)
    message(STATUS "Patching config.h for MinGW compatibility...")
    file(READ "${CMAKE_CURRENT_SOURCE_DIR}/src/config.h" CONFIG_H_CONTENT)
    string(REPLACE "#define HAVE_UNISTD_H 1" "#define HAVE_UNISTD_H 0" CONFIG_H_CONTENT "${CONFIG_H_CONTENT}")
    file(WRITE "${CMAKE_CURRENT_SOURCE_DIR}/src/config.h" "${CONFIG_H_CONTENT}")
endif()

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
# Remove unwanted ffplay files
# file(GLOB REMOVE_FILES "${CMAKE_CURRENT_SOURCE_DIR}/src/ffplay*")
# if(REMOVE_FILES)
#     file(REMOVE ${REMOVE_FILES})
# endif()

# ==============================================================================
# 3. Patch Application
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

    if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/scripts/options_patch.py")
        message(STATUS "Applying Options patches...")
        execute_process(
            COMMAND python3 "${CMAKE_CURRENT_SOURCE_DIR}/scripts/options_patch.py" 
            WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
            RESULT_VARIABLE OPTIONS_PATCH_EXIT_CODE
        )
        if(NOT OPTIONS_PATCH_EXIT_CODE EQUAL 0)
            message(FATAL_ERROR "Failed to apply Options patches. Check for conflicts.")
        endif()
    else()
        message(FATAL_ERROR "Options patch script not found. Cannot proceed.")
    endif()
endif()

# ==============================================================================
# 4. Source & Header Detection
# ==============================================================================
if(NOT FFMPEG_KIT_BUILD_DATE)
    string(TIMESTAMP FFMPEG_KIT_BUILD_DATE "%Y%m%d")
endif()

if(NOT FFMPEG_KIT_BUNDLE_TYPE)
    set(FFMPEG_KIT_BUNDLE_TYPE "custom")
endif()

# file(WRITE "${CMAKE_CURRENT_SOURCE_DIR}/src/config.c" 
#     "const char program_name[] = \"ffmpeg-kit\";\nconst int program_birth_year = 2025;\n")

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
message(STATUS "KIT_SOURCES: ${KIT_SOURCES}")
message(STATUS "KIT_HEADERS: ${KIT_HEADERS}")

# ==============================================================================
# 5. Dependency Detection
# ==============================================================================
find_package(PkgConfig REQUIRED)

# Force PkgConfig to check the build dir first
set(ENV{PKG_CONFIG_PATH} "${FFMPEG_BUILD_DIR}/lib/pkgconfig:$ENV{PKG_CONFIG_PATH}")

pkg_check_modules(FFMPEG REQUIRED IMPORTED_TARGET 
    libavdevice libavfilter libavformat libavcodec libswresample libswscale libavutil jsoncpp sdl2
)

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

# ==============================================================================
# 6. Target Definition & Flags
# ==============================================================================
add_library(ffmpegkit ${KIT_SOURCES} ${KIT_HEADERS})

if(ENABLE_LIBPLACEBO)
    # Force static linking for libplacebo
    set(_OLD_PKG_CONFIG_USE_STATIC_LIBS ${PKG_CONFIG_USE_STATIC_LIBS})
    set(PKG_CONFIG_USE_STATIC_LIBS ON)
    pkg_check_modules(LIBPLACEBO REQUIRED IMPORTED_TARGET libplacebo)
    set(PKG_CONFIG_USE_STATIC_LIBS ${_OLD_PKG_CONFIG_USE_STATIC_LIBS})

    target_link_libraries(ffmpegkit PRIVATE PkgConfig::LIBPLACEBO)
    target_compile_definitions(ffmpegkit PRIVATE PL_STATIC PLACEBO_STATIC)
endif()

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

        # Standard robust stack protection
        target_compile_options(ffmpegkit PRIVATE 
            -fstack-protector-strong
        )

        target_link_options(ffmpegkit PRIVATE 
            "-static-libgcc" 
            "-static-libstdc++" 
            "-Wl,-Bstatic" 
            "-lssp" 
            "-lssp_nonshared"
            "-Wl,-Bdynamic"
            "-Wl,--nxcompat"        # Data Execution Prevention (DEP)
            "-Wl,--dynamicbase"     # ASLR
            "-Wl,--high-entropy-va"   # 64-bit ASLR
            "-Wl,--enable-auto-import"
            "-Wl,--allow-multiple-definition"
        )
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
        )

        # Ensure JNI symbols are kept global in the version script
        # The existing LINKER_SCRIPT logic will work if Java_* symbols are added
    endif()
else()
    target_compile_definitions(ffmpegkit PRIVATE TARGET_OS_LINUX)
    target_compile_options(ffmpegkit PRIVATE -fvisibility=default)
endif()

# ==============================================================================
# 7. Linking & Scripts
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

        if(MINGW OR CMAKE_SYSTEM_NAME MATCHES "Linux" OR ANDROID)
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
        # Shared Link Path: Let PkgConfig handle -lavcodec etc. for .so files
        target_link_libraries(ffmpegkit PRIVATE PkgConfig::FFMPEG)
    endif()

    # Append platform-specific trailing dependencies
    if(ANDROID)
        target_link_libraries(ffmpegkit PRIVATE OpenSLES)
    endif()

    # Linker Script
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
    # Bundling Manifest (Requires shared-library.sh)
    add_custom_command(TARGET ffmpegkit POST_BUILD
        COMMAND bash "${CMAKE_CURRENT_SOURCE_DIR}/scripts/shared-library.sh" "${FFMPEG_BUILD_DIR}"
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

if(WIN32)
    target_link_libraries(ffmpegkit PRIVATE dbghelp)
endif()

# ==============================================================================
# 8. Installation
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

configure_file("src/ffmpeg-kit.pc.in" "ffmpeg-kit.pc" @ONLY)
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/ffmpeg-kit.pc" DESTINATION lib/pkgconfig)

# ==============================================================================
# 9. Testing
# ==============================================================================

if(BUILD_TESTS)
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