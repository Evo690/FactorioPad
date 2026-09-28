
#include <stdint.h>


#define EXPORT \
    __attribute__((visibility("default"))) \
    __attribute__((used))


typedef int32_t FCVReturn;

typedef struct {
    int64_t timeValue;
    int32_t timeScale;
    uint32_t flags;
} FCVTime;


EXPORT
FCVReturn CVDisplayLinkCreateWithActiveCGDisplays(
    void **displayLinkOut
)
{
    if (displayLinkOut) {
        *displayLinkOut = 0;
    }

    return -1;
}


EXPORT
FCVReturn CVDisplayLinkCreateWithCGDisplay(
    uint32_t display,
    void **displayLinkOut
)
{
    (void)display;

    if (displayLinkOut) {
        *displayLinkOut = 0;
    }

    return -1;
}


EXPORT
FCVTime CVDisplayLinkGetNominalOutputVideoRefreshPeriod(
    void *displayLink
)
{
    (void)displayLink;

    FCVTime value = {
        .timeValue = 1,
        .timeScale = 60,
        .flags = 0
    };

    return value;
}


EXPORT
void CVDisplayLinkRelease(
    void *displayLink
)
{
    (void)displayLink;
}


EXPORT
FCVReturn CVDisplayLinkSetCurrentCGDisplayFromOpenGLContext(void)
{
    return -1;
}


EXPORT
FCVReturn CVDisplayLinkSetOutputCallback(void)
{
    return -1;
}


EXPORT
FCVReturn CVDisplayLinkStart(
    void *displayLink
)
{
    (void)displayLink;

    return -1;
}
