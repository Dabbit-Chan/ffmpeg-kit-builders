add_executable(ffmpegkit_tests
    main_test.cpp
    wrapper_test.cpp
    callback_test.cpp
    stress_test.cpp
    config_test.cpp
)

target_link_libraries(ffmpegkit_tests
    PRIVATE
    ffmpegkit
    GTest::gtest_main
)

# Ensure the test executable finds the shared libraries if needed
target_include_directories(ffmpegkit_tests PRIVATE 
    ${CMAKE_SOURCE_DIR}/src
    ${FFMPEG_BUILD_DIR}/include
)

target_compile_definitions(ffmpegkit_tests PRIVATE 
    FFMPEG_KIT_TEST_DIR="${CMAKE_CURRENT_SOURCE_DIR}"
)
