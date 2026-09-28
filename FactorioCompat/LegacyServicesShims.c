#include <CoreFoundation/CoreFoundation.h>


#include <stdint.h>
#include <stddef.h>


#define EXPORT \
    __attribute__((visibility("default"))) \
    __attribute__((used))


/*
 * ApplicationServices
 */

EXPORT
uint32_t UAZoomEnabled(void)
{
    return 0;
}


/*
 * CoreServices
 */

EXPORT
int32_t LSOpenCFURLRef(
    const void *url,
    void **launchedURL
)
{
    (void)url;

    if (launchedURL) {
        *launchedURL = NULL;
    }

    return -1;
}


EXPORT
int32_t UCKeyTranslate(void)
{
    /*
     * SDL later uses our custom keyboard handling.
     */
    return -1;
}


EXPORT
CFStringRef const kUTTypeFileURL =
    CFSTR("public.file-url");

EXPORT
double nan(const char *tagp)
{
    (void)tagp;

    /*
     * IEEE-754 quiet NaN.
     *
     * Do not call the system nan(), because this shim provides
     * that symbol to Factorio.
     */
    union {
        uint64_t bits;
        double value;
    } result;

    result.bits = UINT64_C(0x7ff8000000000000);

    return result.value;
}
