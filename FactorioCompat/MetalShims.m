#import <Foundation/Foundation.h>
#import <Metal/Metal.h>


#define EXPORT \
    __attribute__((visibility("default"))) \
    __attribute__((used))


EXPORT
NSArray *MTLCopyAllDevicesWithObserver(
    id *observer,
    id handler
)
{
    (void)handler;

    if (observer) {
        *observer = nil;
    }

    id<MTLDevice> device =
        MTLCreateSystemDefaultDevice();

    if (!device) {
        return @[];
    }

    return @[device];
}


EXPORT
void MTLRemoveDeviceObserver(
    id observer
)
{
    (void)observer;
}

#pragma mark - macOS-only MTLDevice compatibility

@interface NSObject (FactorioMetalDeviceCompat)

- (BOOL)isDepth24Stencil8PixelFormatSupported;

@end


@implementation NSObject (FactorioMetalDeviceCompat)

- (BOOL)isDepth24Stencil8PixelFormatSupported
{
    return NO;
}

@end
