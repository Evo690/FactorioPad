#include <stdint.h>

#define EXPORT \
    __attribute__((visibility("default"))) \
    __attribute__((used))


EXPORT
int32_t clGetPlatformIDs(void)
{
    return -1;
}


EXPORT
int32_t clGetDeviceIDs(void)
{
    return -1;
}


EXPORT
int32_t clGetDeviceInfo(void)
{
    return -1;
}
