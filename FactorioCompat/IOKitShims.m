#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <IOKit/IOKitLib.h>

#include <stdint.h>


#define EXPORT \
    __attribute__((visibility("default"))) \
    __attribute__((used))


/*
 * macOS-only display information helper.
 *
 * iPadOS IOKit exports almost all IOKit symbols used by Factorio,
 * but not IODisplayCreateInfoDictionary().
 *
 * Return a valid, retained CFDictionaryRef.
 */

EXPORT
CFDictionaryRef IODisplayCreateInfoDictionary(
    io_service_t framebuffer,
    IOOptionBits options
)
{
    (void)framebuffer;
    (void)options;

    NSDictionary *dictionary = @{

        @"DisplayProductName": @{
            @"en_US": @"iPad Display"
        },

        @"DisplayVendorID": @(1),
        @"DisplayProductID": @(1)
    };
    return CFBridgingRetain(dictionary);
}
