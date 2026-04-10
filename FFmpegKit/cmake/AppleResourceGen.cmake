
# =============================================================================
# RESOURCE FILE COMPILATION: Apple Platform Resource Embedding
# =============================================================================
# - Build bin2c host tool from FFmpeg source
# - Generate C source files from graph.css and graph.html
# - Add generated resources to KIT_SOURCES for compilation
# ==============================================================================
function(generate_apple_resource_files)
  if(APPLE)
      message(STATUS "Configuring resource compilation for Apple platform...")

      # Build bin2c host tool
      set(BIN2C_SOURCE "${FFMPEG_SRC_DIR}/ffbuild/bin2c.c")
      set(BIN2C_OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/bin2c")

      if(NOT EXISTS "${BIN2C_OUTPUT}")
          message(STATUS "Building bin2c host tool...")
          execute_process(
              COMMAND ${CMAKE_C_COMPILER} -o "${BIN2C_OUTPUT}" "${BIN2C_SOURCE}"
              RESULT_VARIABLE BIN2C_BUILD_RESULT
              OUTPUT_VARIABLE BIN2C_BUILD_OUTPUT
              ERROR_VARIABLE BIN2C_BUILD_ERROR
          )
          if(NOT BIN2C_BUILD_RESULT EQUAL 0)
              message(FATAL_ERROR "Failed to build bin2c tool:\n${BIN2C_BUILD_OUTPUT}\n${BIN2C_BUILD_ERROR}")
          endif()
          message(STATUS "bin2c tool built successfully.")
      else()
          message(STATUS "bin2c tool already exists, skipping build.")
      endif()

      # Define resource files to process
      set(RESOURCE_FILES
          "${CMAKE_CURRENT_SOURCE_DIR}/src/resources/graph.css"
          "${CMAKE_CURRENT_SOURCE_DIR}/src/resources/graph.html"
      )

      set(GENERATED_RESOURCE_SOURCES "")

      foreach(RESOURCE_FILE ${RESOURCE_FILES})
          if(EXISTS "${RESOURCE_FILE}")
              get_filename_component(RESOURCE_NAME "${RESOURCE_FILE}" NAME_WE)
              get_filename_component(RESOURCE_EXT "${RESOURCE_FILE}" EXT)
              set(GENERATED_C_FILE "${CMAKE_CURRENT_BINARY_DIR}/resources/${RESOURCE_NAME}${RESOURCE_EXT}.c")

              message(STATUS "Generating resource: ${RESOURCE_NAME}${RESOURCE_EXT}.c from ${RESOURCE_EXT} file...")

              # Ensure output directory exists
              file(MAKE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/resources")

              # Run bin2c to generate C source
              execute_process(
                  COMMAND "${BIN2C_OUTPUT}" "${RESOURCE_FILE}" "${GENERATED_C_FILE}"
                  RESULT_VARIABLE BIN2C_RESULT
                  OUTPUT_VARIABLE BIN2C_OUTPUT_MSG
                  ERROR_VARIABLE BIN2C_ERROR_MSG
              )

              if(NOT BIN2C_RESULT EQUAL 0)
                  message(FATAL_ERROR "Failed to generate ${GENERATED_C_FILE}:\n${BIN2C_OUTPUT_MSG}\n${BIN2C_ERROR_MSG}")
              endif()

              message(STATUS "Generated: ${GENERATED_C_FILE}")
              list(APPEND GENERATED_RESOURCE_SOURCES "${GENERATED_C_FILE}")
          else()
              message(WARNING "Resource file not found: ${RESOURCE_FILE}")
          endif()
      endforeach()

      # Add generated resource sources to KIT_SOURCES
      if(GENERATED_RESOURCE_SOURCES)
          list(APPEND KIT_SOURCES ${GENERATED_RESOURCE_SOURCES})
          message(STATUS "Added ${GENERATED_RESOURCE_SOURCES} resource files to build.")
      endif()
  endif()
endfunction()
