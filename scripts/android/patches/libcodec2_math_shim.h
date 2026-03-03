#include <complex.h>
#include <math.h>
float crealf(float complex z);
float cimagf(float complex z);
static inline float cabsf(float complex z) { return hypotf(crealf(z), cimagf(z)); }
static inline float cargf(float complex z) { return atan2f(cimagf(z), crealf(z)); }