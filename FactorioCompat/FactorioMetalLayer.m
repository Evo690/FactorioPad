#import "FactorioMetalLayer.h"
#import <objc/runtime.h>

static NSCondition *gLifecycleCondition;
static BOOL gApplicationActive = YES;

static void FPSetDisplaySyncEnabled(id self, SEL selector, BOOL value)
{
    // The SDL macOS setting stalls presentation on iPadOS. Keep the native behavior.
    (void)self;
    (void)selector;
    (void)value;
}

static void FPMainSync(dispatch_block_t block)
{
    if (NSThread.isMainThread) {
        block();
    } else {
        dispatch_sync(dispatch_get_main_queue(), block);
    }
}

@implementation FactorioMetalLayer

+ (void)setApplicationActive:(BOOL)active
{
    [gLifecycleCondition lock];
    gApplicationActive = active;
    if (active) { [gLifecycleCondition broadcast]; }
    [gLifecycleCondition unlock];
}

- (id<CAMetalDrawable>)nextDrawable
{
    [gLifecycleCondition lock];
    while (!gApplicationActive) {
        if (NSThread.isMainThread) {
            [gLifecycleCondition unlock];
            return nil;
        }
        [gLifecycleCondition wait];
    }
    [gLifecycleCondition unlock];
    return [super nextDrawable];
}

- (void)setDrawableSize:(CGSize)value
{
    FPMainSync(^{ [super setDrawableSize:value]; });
}

- (void)setContentsScale:(CGFloat)value
{
    FPMainSync(^{ [super setContentsScale:value]; });
}

- (void)setFrame:(CGRect)value
{
    FPMainSync(^{ [super setFrame:value]; });
}

- (void)setBounds:(CGRect)value
{
    FPMainSync(^{ [super setBounds:value]; });
}

- (void)setDevice:(id<MTLDevice>)value
{
    FPMainSync(^{ [super setDevice:value]; });
}

- (void)setPixelFormat:(MTLPixelFormat)value
{
    FPMainSync(^{ [super setPixelFormat:value]; });
}

- (void)setFramebufferOnly:(BOOL)value
{
    FPMainSync(^{ [super setFramebufferOnly:value]; });
}

- (void)setPresentsWithTransaction:(BOOL)value
{
    FPMainSync(^{ [super setPresentsWithTransaction:value]; });
}

- (void)setMaximumDrawableCount:(NSUInteger)value
{
    FPMainSync(^{ [super setMaximumDrawableCount:value]; });
}

- (void)setAllowsNextDrawableTimeout:(BOOL)value
{
    FPMainSync(^{ [super setAllowsNextDrawableTimeout:value]; });
}

- (void)setOpaque:(BOOL)value
{
    FPMainSync(^{ [super setOpaque:value]; });
}

- (void)setColorspace:(CGColorSpaceRef)value
{
    FPMainSync(^{ [super setColorspace:value]; });
}

- (void)setWantsExtendedDynamicRangeContent:(BOOL)value
{
    FPMainSync(^{ [super setWantsExtendedDynamicRangeContent:value]; });
}

- (void)setMagnificationFilter:(CALayerContentsFilter)value
{
    FPMainSync(^{ [super setMagnificationFilter:value]; });
}

+ (void)load
{
    gLifecycleCondition = [[NSCondition alloc] init];
    SEL selector = NSSelectorFromString(@"setDisplaySyncEnabled:");
    Method method = class_getInstanceMethod(CAMetalLayer.class, selector);
    if (method) {
        class_addMethod(self, selector, (IMP)FPSetDisplaySyncEnabled, method_getTypeEncoding(method));
    }
}

@end
