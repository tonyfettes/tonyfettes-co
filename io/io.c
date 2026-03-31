#include "io.h"

#if defined(__linux__)
#include "io_uring.c"
#elif defined(_WIN32)
// TODO: IOCP backend
#error "Windows IOCP backend not yet implemented"
#elif defined(__APPLE__)
// TODO: GCD backend
#error "macOS GCD backend not yet implemented"
#else
#error "Unsupported platform"
#endif
