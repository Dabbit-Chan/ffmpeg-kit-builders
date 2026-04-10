cmake_minimum_required(VERSION 3.20)

option(FALLBACK_TO_SHARED "Fallback to shared libraries if static not found" ON)
option(SHARED_TO_STATIC_DEBUG "Debug shared-to-static replacement" ON)

function(replace_shared_with_static INPUT_LIB OUTPUT_VAR)
    set(options "")
    set(oneValueArgs "")
    set(multiValueArgs "")
    cmake_parse_arguments(RSTS "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
    
    if(NOT DEFINED INPUT_LIB OR NOT INPUT_LIB)
        if(SHARED_TO_STATIC_DEBUG)
            message(STATUS "replace_shared_with_static: INPUT_LIB is empty")
        endif()
        set(${OUTPUT_VAR} "" PARENT_SCOPE)
        return()
    endif()
    
    set(SHARED_TO_STATIC_CACHE "${CMAKE_BINARY_DIR}/.shared_to_static_cache")
    
    # Check cache (only if file exists to avoid spurious creation)
    if(EXISTS "${SHARED_TO_STATIC_CACHE}")
        file(STRINGS "${SHARED_TO_STATIC_CACHE}" CACHE_CONTENTS)
        foreach(CACHE_LINE ${CACHE_CONTENTS})
            string(FIND "${CACHE_LINE}" "${INPUT_LIB}:" FIND_POS)
            if(FIND_POS EQUAL 0)
                string(LENGTH "${INPUT_LIB}" LIB_LEN)
                math(EXPR VALUE_START "${LIB_LEN} + 1")
                string(SUBSTRING "${CACHE_LINE}" ${VALUE_START} -1 CACHE_VALUE)
                if(CACHE_VALUE)
                    if(SHARED_TO_STATIC_DEBUG)
                        message(STATUS "[CACHE HIT] ${INPUT_LIB} -> ${CACHE_VALUE}")
                    endif()
                    set(${OUTPUT_VAR} "${CACHE_VALUE}" PARENT_SCOPE)
                    return()
                endif()
            endif()
        endforeach()
    endif()
    
    # Resolve to absolute path if it's a target
    set(RESOLVED_LIB "${INPUT_LIB}")
    if(TARGET ${INPUT_LIB})
        get_target_property(TARGET_LIB ${INPUT_LIB} IMPORTED_LOCATION)
        if(TARGET_LIB)
            set(RESOLVED_LIB "${TARGET_LIB}")
        elseif(SHARED_TO_STATIC_DEBUG)
            message(STATUS "Target ${INPUT_LIB} has no IMPORTED_LOCATION property")
        endif()
    endif()
    
    # If it's a bare library name (not a path), try to resolve it
    if(NOT RESOLVED_LIB MATCHES "/" AND NOT RESOLVED_LIB MATCHES "^[A-Za-z]:")
        find_library(RSTS_RESOLVED_LIB NAMES "${INPUT_LIB}")
        if(RSTS_RESOLVED_LIB)
            set(RESOLVED_LIB "${RSTS_RESOLVED_LIB}")
            if(SHARED_TO_STATIC_DEBUG)
                message(STATUS "Resolved bare name '${INPUT_LIB}' to '${RESOLVED_LIB}'")
            endif()
        else()
            # Couldn't resolve; treat as framework or system reference
            if(SHARED_TO_STATIC_DEBUG)
                message(STATUS "Could not resolve bare name '${INPUT_LIB}', treating as system library")
            endif()
            set(${OUTPUT_VAR} "${INPUT_LIB}" PARENT_SCOPE)
            return()
        endif()
        unset(RSTS_RESOLVED_LIB CACHE)
    endif()
    
    cmake_path(GET RESOLVED_LIB FILENAME LIB_NAME)
    cmake_path(GET RESOLVED_LIB PARENT_PATH LIB_DIR)
    
    set(RESULT "")
    
    # Windows import library (.dll.a)
    if(LIB_NAME MATCHES "\\.dll\\.a$")
        cmake_path(REPLACE_EXTENSION LIB_NAME ".a" OUTPUT_VARIABLE STATIC_NAME)
        cmake_path(APPEND LIB_DIR "${STATIC_NAME}" OUTPUT_VARIABLE STATIC_PATH)
        if(EXISTS "${STATIC_PATH}")
            set(RESULT "${STATIC_PATH}")
            if(SHARED_TO_STATIC_DEBUG)
                message(STATUS "Found .dll.a -> .a: ${STATIC_PATH}")
            endif()
        endif()
    
    # Windows DLL
    elseif(LIB_NAME MATCHES "\\.dll$")
        cmake_path(REPLACE_EXTENSION LIB_NAME ".a" OUTPUT_VARIABLE STATIC_NAME)
        find_library(RSTS_STATIC_LIB NAMES "${STATIC_NAME}" PATHS "${LIB_DIR}" NO_DEFAULT_PATH)
        if(RSTS_STATIC_LIB)
            set(RESULT "${RSTS_STATIC_LIB}")
            if(SHARED_TO_STATIC_DEBUG)
                message(STATUS "Found .dll -> .a: ${RSTS_STATIC_LIB}")
            endif()
        endif()
        unset(RSTS_STATIC_LIB CACHE)
    
    # Unix shared object (.so)
    elseif(LIB_NAME MATCHES "\\.so" AND NOT LIB_NAME MATCHES "\\.a$")
        if(NOT _is_system_library("${LIB_DIR}"))
            cmake_path(REPLACE_EXTENSION LIB_NAME ".a" OUTPUT_VARIABLE STATIC_NAME)
            find_library(RSTS_STATIC_LIB NAMES "${STATIC_NAME}" PATHS "${LIB_DIR}" NO_DEFAULT_PATH)
            if(RSTS_STATIC_LIB)
                set(RESULT "${RSTS_STATIC_LIB}")
                if(SHARED_TO_STATIC_DEBUG)
                    message(STATUS "Found .so -> .a: ${RSTS_STATIC_LIB}")
                endif()
            endif()
            unset(RSTS_STATIC_LIB CACHE)
        endif()
    
    # macOS dynamic library (.dylib)
    elseif(LIB_NAME MATCHES "\\.dylib$")
        if(NOT _is_system_library("${LIB_DIR}"))
            cmake_path(REPLACE_EXTENSION LIB_NAME ".a" OUTPUT_VARIABLE STATIC_NAME)
            find_library(RSTS_STATIC_LIB NAMES "${STATIC_NAME}" PATHS "${LIB_DIR}" NO_DEFAULT_PATH)
            if(RSTS_STATIC_LIB)
                set(RESULT "${RSTS_STATIC_LIB}")
                if(SHARED_TO_STATIC_DEBUG)
                    message(STATUS "Found .dylib -> .a: ${RSTS_STATIC_LIB}")
                endif()
            endif()
            unset(RSTS_STATIC_LIB CACHE)
        endif()
    
    # Unknown extension: treat as-is (likely already static or target reference)
    else()
        if(EXISTS "${RESOLVED_LIB}")
            set(RESULT "${RESOLVED_LIB}")
        else()
            set(RESULT "${INPUT_LIB}")
        endif()
    endif()
    
    # Apply fallback if needed
    if(NOT RESULT)
        if(FALLBACK_TO_SHARED)
            set(RESULT "${INPUT_LIB}")
            if(SHARED_TO_STATIC_DEBUG)
                message(STATUS "[FALLBACK] ${INPUT_LIB} -> no static found, using shared")
            endif()
        else()
            message(WARNING "Static library not found for ${INPUT_LIB} and FALLBACK_TO_SHARED is OFF")
        endif()
    endif()
    
    # Cache the result
    if(RESULT)
        if(NOT EXISTS "${SHARED_TO_STATIC_CACHE}")
            file(WRITE "${SHARED_TO_STATIC_CACHE}" "")
        endif()
        file(APPEND "${SHARED_TO_STATIC_CACHE}" "${INPUT_LIB}:${RESULT}\n")
    endif()
    
    set(${OUTPUT_VAR} "${RESULT}" PARENT_SCOPE)
endfunction()


# Helper function: check if a directory is a system library path
function(_is_system_library LIB_DIR RESULT_VAR)
    # List of system library paths (Unix, macOS, Windows)
    # Use simple prefix matching to avoid regex issues with special characters
    set(IS_SYSTEM FALSE)
    
    # Unix/Linux system paths
    if(LIB_DIR STREQUAL "/lib" OR LIB_DIR STREQUAL "/lib64" OR
       LIB_DIR STREQUAL "/usr/lib" OR LIB_DIR STREQUAL "/usr/lib64")
        set(IS_SYSTEM TRUE)
    endif()
    
    # macOS system paths
    if(LIB_DIR STREQUAL "/usr/local/lib" OR
       LIB_DIR STREQUAL "/opt/homebrew/lib" OR
       LIB_DIR STREQUAL "/opt/homebrew/opt")
        set(IS_SYSTEM TRUE)
    endif()
    
    # Windows system paths
    if(LIB_DIR MATCHES "^[A-Za-z]:/Windows" OR
       LIB_DIR MATCHES "^[A-Za-z]:/Program Files")
        set(IS_SYSTEM TRUE)
    endif()
    
    # Check for prefix matches (subdirectories of system paths)
    foreach(PREFIX "/lib/" "/lib64/" "/usr/lib/" "/usr/lib64/"
                   "/usr/local/lib/" "/opt/homebrew/lib/" "/opt/homebrew/opt/")
        string(FIND "${LIB_DIR}" "${PREFIX}" FIND_POS)
        if(NOT FIND_POS EQUAL -1)
            set(IS_SYSTEM TRUE)
            break()
        endif()
    endforeach()
    
    set(${RESULT_VAR} ${IS_SYSTEM} PARENT_SCOPE)
endfunction()