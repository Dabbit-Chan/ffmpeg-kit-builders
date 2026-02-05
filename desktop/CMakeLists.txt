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

# ==============================================================================
# 1. Options & Configuration
# ==============================================================================
option(BUILD_SHARED_LIBS "Build shared library" ON)
set(FFMPEG_KIT_BUILD_DATE "" CACHE STRING "Build date override")

# Define Paths
set(FFMPEG_SRC_DIR "" CACHE PATH "Path to FFmpeg source directory (fftools)")
set(FFMPEG_BUILD_DIR "" CACHE PATH "Path to FFmpeg build directory (libs)")

if(NOT FFMPEG_SRC_DIR OR NOT EXISTS "${FFMPEG_SRC_DIR}/fftools")
    message(FATAL_ERROR "FFMPEG_SRC_DIR is invalid. Point it to the FFmpeg source root.")
endif()

if(NOT FFMPEG_BUILD_DIR OR NOT EXISTS "${FFMPEG_BUILD_DIR}/include/config.h")
    message(FATAL_ERROR "FFMPEG_BUILD_DIR is invalid. It must contain include/config.h")
endif()

# ==============================================================================
# 2. File Copying & Preparation
# ==============================================================================
message(STATUS "Preparing source tree...")
file(MAKE_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/src")

# Copy config.h
file(COPY "${FFMPEG_BUILD_DIR}/include/config.h" DESTINATION "${CMAKE_CURRENT_SOURCE_DIR}/src/")

if(MINGW)
    message(STATUS "Patching config.h for MinGW compatibility...")
    file(READ "${CMAKE_CURRENT_SOURCE_DIR}/src/config.h" CONFIG_H_CONTENT)
    string(REPLACE "#define HAVE_UNISTD_H 1" "#define HAVE_UNISTD_H 0" CONFIG_H_CONTENT "${CONFIG_H_CONTENT}")
    file(WRITE "${CMAKE_CURRENT_SOURCE_DIR}/src/config.h" "${CONFIG_H_CONTENT}")
endif()

# Copy fftools (Source code)
message(STATUS "Copying fftools from ${FFMPEG_SRC_DIR}...")
file(COPY "${FFMPEG_SRC_DIR}/fftools/" 
     DESTINATION "${CMAKE_CURRENT_SOURCE_DIR}/src/"
     FILES_MATCHING
     PATTERN "*.c"
     PATTERN "*.h"
     PATTERN "*.css"
     PATTERN "*.html"
)
file(COPY "${FFMPEG_SRC_DIR}/compat/stdbit/stdbit.h" DESTINATION "${CMAKE_CURRENT_SOURCE_DIR}/src/")

# Remove unwanted ffplay files
file(GLOB REMOVE_FILES "${CMAKE_CURRENT_SOURCE_DIR}/src/ffplay*")
if(REMOVE_FILES)
    file(REMOVE ${REMOVE_FILES})
endif()

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
endif()

# ==============================================================================
# 4. Source & Header Detection
# ==============================================================================
if(NOT FFMPEG_KIT_BUILD_DATE)
    string(TIMESTAMP FFMPEG_KIT_BUILD_DATE "%Y%m%d")
endif()
file(WRITE "${CMAKE_CURRENT_SOURCE_DIR}/src/config.c" 
    "const char program_name[] = \"ffmpeg-kit\";\nconst int program_birth_year = 2025;\n")

# Find all sources
file(GLOB_RECURSE KIT_SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/src/*.c" "${CMAKE_CURRENT_SOURCE_DIR}/src/*.cpp")
file(GLOB_RECURSE KIT_HEADERS "${CMAKE_CURRENT_SOURCE_DIR}/src/*.h")

# ==============================================================================
# 5. Dependency Detection
# ==============================================================================
find_package(PkgConfig REQUIRED)

# Force PkgConfig to check the build dir first
set(ENV{PKG_CONFIG_PATH} "${FFMPEG_BUILD_DIR}/lib/pkgconfig:$ENV{PKG_CONFIG_PATH}")

pkg_check_modules(FFMPEG REQUIRED IMPORTED_TARGET 
    libavdevice libavfilter libavformat libavcodec libswresample libswscale libavutil jsoncpp
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

target_include_directories(ffmpegkit PRIVATE 
    "${CMAKE_CURRENT_SOURCE_DIR}/src"
    "${FFMPEG_BUILD_DIR}/include"
)
target_include_directories(ffmpegkit PUBLIC ${FFMPEG_INCLUDE_DIRS})

target_compile_options(ffmpegkit PRIVATE -Os -ffunction-sections -fdata-sections)
target_compile_features(ffmpegkit PRIVATE cxx_std_11)

target_compile_definitions(ffmpegkit PRIVATE
    HAVE_CONFIG_H
    __STDC_CONSTANT_MACROS
    __STDC_LIMIT_MACROS
    __STDC_FORMAT_MACROS
    FFMPEG_KIT_BUILD_DATE=${FFMPEG_KIT_BUILD_DATE}
)

if(MINGW)
    target_compile_definitions(ffmpegkit PRIVATE
        _WIN32 WIN32 TARGET_OS_WINDOWS FFMPEG_KIT_WINDOWS
        _WIN32_WINNT=0x0600
        __NO_WINDRES__
    )

    target_compile_definitions(ffmpegkit PRIVATE FFMPEG_KIT_BUILDING_DLL)

    target_link_options(ffmpegkit PRIVATE 
        -static-libgcc 
        -static-libstdc++ 
        -Wl,--enable-auto-import 
        -Wl,--allow-multiple-definition
    )
else()
    target_compile_definitions(ffmpegkit PRIVATE TARGET_OS_LINUX)
    target_compile_options(ffmpegkit PRIVATE -fvisibility=default)
endif()

# ==============================================================================
# 7. Linking & Scripts
# ==============================================================================
target_link_libraries(ffmpegkit PRIVATE PkgConfig::FFMPEG)

if(BUILD_SHARED_LIBS)
    target_compile_definitions(ffmpegkit PRIVATE DLL_EXPORT PIC)
    
    target_link_options(ffmpegkit PRIVATE -Wl,--no-undefined)

    if(MINGW OR CMAKE_SYSTEM_NAME MATCHES "Linux")
    target_link_libraries(ffmpegkit PRIVATE 
            "-Wl,--whole-archive"
            PkgConfig::FFMPEG
            "-Wl,--no-whole-archive"
        )
    else()
        # macOS / Standard fallback
        target_link_libraries(ffmpegkit PRIVATE PkgConfig::FFMPEG)
    endif()

    # Linker Script
    set(LINKER_SCRIPT "${CMAKE_CURRENT_BINARY_DIR}/ffmpeg-linker-script.map")
    file(WRITE ${LINKER_SCRIPT} "{\n    global:\n        av*;\n        swr*;\n        sws*;\n    local:\n        *;\n};\n")
    target_link_options(ffmpegkit PRIVATE "-Wl,--version-script=${LINKER_SCRIPT}")

    # Bundling Manifest (Requires shared-library.sh)
    add_custom_command(TARGET ffmpegkit POST_BUILD
        COMMAND bash "${CMAKE_CURRENT_SOURCE_DIR}/scripts/shared-library.sh" "${FFMPEG_BUILD_DIR}"
        COMMENT "Generating bundle manifest for shared dependencies..."
    )

    # Install Hook for Bundled Libs
    install(CODE "
        if(EXISTS \"${CMAKE_CURRENT_BINARY_DIR}/bundle_manifest.txt\")
            file(STRINGS \"${CMAKE_CURRENT_BINARY_DIR}/bundle_manifest.txt\" BUNDLE_LIBS)
            foreach(LIB \${BUNDLE_LIBS})
                message(STATUS \"Bundling: \${LIB}\")
                if(LIB MATCHES \"\\\\.dll$\")
                    file(INSTALL DESTINATION \"\${CMAKE_INSTALL_PREFIX}/bin\" FILES \"\${LIB}\")
                else()
                    file(INSTALL DESTINATION \"\${CMAKE_INSTALL_PREFIX}/lib\" FILES \"\${LIB}\")
                endif()
            endforeach()
        endif()
    ")

else()
    # Static Build Logic
    if(MINGW)
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