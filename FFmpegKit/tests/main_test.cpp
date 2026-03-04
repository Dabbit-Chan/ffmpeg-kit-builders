#include <gtest/gtest.h>

extern "C" {
const char *__tsan_default_suppressions() {
    return "race:SDL_RunThread\n";
}

const char *__lsan_default_suppressions() {
    return "leak:SDL_DBus_Init\n"
           "leak:SDL_Init\n"
           "leak:SDL_InitSubSystem\n"
           "leak:libX11\n"
           "leak:libLLVM\n"
           "leak:libGL\n"
           "leak:libglapi\n"
           "leak:libGLX_mesa\n"
           "leak:<unknown module>\n";
}
}

int main(int argc, char **argv) {
    ::testing::InitGoogleTest(&argc, argv);
    return RUN_ALL_TESTS();
}
