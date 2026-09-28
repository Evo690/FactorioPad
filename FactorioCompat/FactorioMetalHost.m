#import "FactorioMetalHost.h"

#import <QuartzCore/QuartzCore.h>
#import <QuartzCore/CAMetalLayer.h>


static __weak UIView *gFactorioHostView = nil;
static CAMetalLayer *gFactorioMetalLayer = nil;

static BOOL gFactorioLayerAttached = NO;
static BOOL gFactorioAttachScheduled = NO;

static CAMetalLayer *gFactorioHostMetalLayer = nil;

static CGFloat gFactorioHostScale = 1.0;
static CGRect gFactorioHostBounds = {{0, 0}, {0, 0}};

@implementation FactorioMetalHost


+ (void)setHostView:(UIView *)view
{
    void (^block)(void) = ^{

        gFactorioHostView = view;
        
        CGFloat scale = view.traitCollection.displayScale;

        if (scale <= 0.0) {
            UIScreen *screen = view.window.windowScene.screen;

            if (screen) {
                scale = screen.scale;
            }
        }

        if (scale <= 0.0) {
            scale = 1.0;
        }

        @synchronized(self) {
            gFactorioHostScale = scale;
            gFactorioHostBounds = view.bounds;
        }

        if ([view.layer isKindOfClass:[CAMetalLayer class]]) {

            CAMetalLayer *hostLayer = (CAMetalLayer *)view.layer;
            @synchronized(self) { gFactorioHostMetalLayer = hostLayer; }
            [CATransaction begin];
            [CATransaction setDisableActions:YES];
            hostLayer.contentsScale = scale;
            hostLayer.drawableSize = CGSizeMake(view.bounds.size.width * scale, view.bounds.size.height * scale);
            CAMetalLayer *guestLayer;
            @synchronized(self) { guestLayer = gFactorioMetalLayer; }
            if (guestLayer && guestLayer != hostLayer) {
                guestLayer.frame = view.bounds;
                guestLayer.contentsScale = scale;
                guestLayer.drawableSize = hostLayer.drawableSize;
            }
            [CATransaction commit];
        } else {

            NSLog(
                @"[FactorioCompat] ERROR host backing layer is %@, "
                @"expected CAMetalLayer",
                NSStringFromClass([view.layer class])
            );
        }
    };

    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_async(
            dispatch_get_main_queue(),
            block
        );
    }
}


+ (void)attachMetalLayer:(CAMetalLayer *)layer
{
    if (!layer) {
        return;
    }


    @synchronized(self) {

        if (gFactorioMetalLayer != layer) {

            gFactorioMetalLayer = layer;
            gFactorioLayerAttached = NO;
        }


        /*
         * Do not enqueue another block on the main queue
         * for every NSView.layer read.
         */
        if (
            gFactorioLayerAttached ||
            gFactorioAttachScheduled
        ) {
            return;
        }


        gFactorioAttachScheduled = YES;
    }


    dispatch_async(dispatch_get_main_queue(), ^{

        UIView *host =
            gFactorioHostView;


        if (!host) {

            @synchronized(self) {
                gFactorioAttachScheduled = NO;
            }

            return;
        }
        
        if (layer == host.layer) {

            @synchronized(self) {
                gFactorioLayerAttached = YES;
                gFactorioAttachScheduled = NO;
            }

            return;
        }


        [CATransaction begin];
        [CATransaction setDisableActions:YES];


        if (layer.superlayer != host.layer) {

            [layer removeFromSuperlayer];

            [host.layer
                addSublayer:layer
            ];
        }


        layer.frame =
            host.bounds;


        [CATransaction commit];


        @synchronized(self) {
            gFactorioLayerAttached = YES;
            gFactorioAttachScheduled = NO;
        }
    });
}

+ (CAMetalLayer *)hostMetalLayer
{
    @synchronized(self) {
        return gFactorioHostMetalLayer;
    }
}

+ (CGFloat)hostScale
{
    @synchronized(self) {
        return gFactorioHostScale;
    }
}

+ (CGRect)hostBounds
{
    @synchronized(self) {
        return gFactorioHostBounds;
    }
}

@end
