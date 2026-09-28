#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>


/*
 * Carbon / HIToolbox compatibility stubs.
 *
 * Factorio's bundled SDL Cocoa backend imports these.
 * For now we only need dyld to resolve them.
 */


/*
 * Original macOS declaration is effectively:
 *
 * extern const CFStringRef kTISPropertyUnicodeKeyLayoutData;
 */

__attribute__((visibility("default")))
const CFStringRef kTISPropertyUnicodeKeyLayoutData =
    CFSTR("TISPropertyUnicodeKeyLayoutData");


/*
 * TISCopyCurrentKeyboardLayoutInputSource()
 *
 * We'll eventually replace keyboard-layout handling with the
 * iPadOS input path. For --version this shouldn't be needed.
 */

__attribute__((visibility("default")))
CFTypeRef TISCopyCurrentKeyboardLayoutInputSource(void)
{
    return NULL;
}


/*
 * TISGetInputSourceProperty()
 */

__attribute__((visibility("default")))
const void *TISGetInputSourceProperty(
    CFTypeRef inputSource,
    CFStringRef propertyKey
)
{
    (void)inputSource;
    (void)propertyKey;

    return NULL;
}


/*
 * Old Carbon keyboard helpers.
 */

__attribute__((visibility("default")))
int16_t KBGetLayoutType(int16_t keyboardType)
{
    (void)keyboardType;

    return 0;
}


__attribute__((visibility("default")))
uint8_t LMGetKbdType(void)
{
    return 0;
}
