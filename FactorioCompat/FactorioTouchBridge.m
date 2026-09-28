#import "FactorioTouchBridge.h"
#import "FactorioMetalHost.h"
#import "FactorioKeyboardBridge.h"

#import <objc/message.h>
#import <objc/runtime.h>
#import <os/lock.h>


#pragma mark - Synthetic NSEvent-like object

@interface FactorioTouchMouseEvent : NSObject

@property (nonatomic, strong, nullable) id factorioWindow;
@property (nonatomic) CGPoint factorioLocation;

@end


@implementation FactorioTouchMouseEvent

- (id)window
{
    return self.factorioWindow;
}

- (CGPoint)locationInWindow
{
    return self.factorioLocation;
}

- (NSInteger)buttonNumber
{
    // AppKit: 0 = left
    return 0;
}

- (NSUInteger)modifierFlags
{
    return 0;
}

- (NSInteger)clickCount
{
    return 1;
}

@end


#pragma mark - State

static os_unfair_lock gFactorioTouchLock = OS_UNFAIR_LOCK_INIT;

static id gFactorioSDLView = nil;
static id gFactorioWindowListener = nil;




void FactorioTouchRegisterSDLResponder(
    id view,
    id listener
) {
    os_unfair_lock_lock(&gFactorioTouchLock);

    gFactorioSDLView = view;
    gFactorioWindowListener = listener;

    os_unfair_lock_unlock(&gFactorioTouchLock);
    dispatch_async(dispatch_get_main_queue(), ^{ FactorioTouchUpdateWindowSize(); });
}


static void FactorioTouchGetTargets(
    id __strong *view,
    id __strong *listener
) {
    os_unfair_lock_lock(&gFactorioTouchLock);

    *view = gFactorioSDLView;
    *listener = gFactorioWindowListener;

    os_unfair_lock_unlock(&gFactorioTouchLock);
}


static id FactorioTouchWindowForView(id view)
{
    if (!view) {
        return nil;
    }

    SEL selector = NSSelectorFromString(@"window");

    if (![view respondsToSelector:selector]) {
        return nil;
    }

    return ((id (*)(id, SEL))objc_msgSend)(
        view,
        selector
    );
}

void FactorioTouchUpdateWindowSize(void)
{
    NSCAssert(NSThread.isMainThread, @"Window resizing must run on the main thread");
    id view = nil;
    id listener = nil;
    FactorioTouchGetTargets(&view, &listener);
    id window = FactorioTouchWindowForView(view);
    CGRect bounds = [FactorioMetalHost hostBounds];
    SEL getFrame = NSSelectorFromString(@"frame");
    SEL setFrame = NSSelectorFromString(@"setFrame:display:");
    SEL resized = NSSelectorFromString(@"windowDidResize:");
    if (!window || ![window respondsToSelector:getFrame] || ![window respondsToSelector:setFrame]
        || ![listener respondsToSelector:resized] || CGRectIsEmpty(bounds)) {
        return;
    }
    CGRect frame = ((CGRect (*)(id, SEL))objc_msgSend)(window, getFrame);
    if (CGSizeEqualToSize(frame.size, bounds.size)) { return; }
    frame.size = bounds.size;
    ((void (*)(id, SEL, CGRect, BOOL))objc_msgSend)(window, setFrame, frame, NO);
    SEL setViewFrame = NSSelectorFromString(@"setFrame:");
    if ([view respondsToSelector:setViewFrame]) {
        ((void (*)(id, SEL, CGRect))objc_msgSend)(view, setViewFrame, bounds);
    }
    ((void (*)(id, SEL, id))objc_msgSend)(listener, resized, nil);
}


static FactorioTouchMouseEvent *FactorioTouchMakeEvent(
    CGFloat x,
    CGFloat y,
    id view
) {
    CGRect bounds = [FactorioMetalHost hostBounds];

    CGFloat width = bounds.size.width;
    CGFloat height = bounds.size.height;

    if (width <= 0.0 || height <= 0.0) {
        return nil;
    }

    // UIKit:
    // 0,0 = top-left corner
    //
    // AppKit:
    // 0,0 = bottom-left corner
    //
    // SDL Cocoa later converts this as follows:
    // SDL-y = windowHeight - AppKit-y

    x = MAX(0.0, MIN(x, width));
    y = MAX(0.0, MIN(y, height));

    CGPoint cocoaPoint = CGPointMake(
        x,
        height - y
    );

    FactorioTouchMouseEvent *event =
        [FactorioTouchMouseEvent new];

    event.factorioWindow =
        FactorioTouchWindowForView(view);

    event.factorioLocation =
        cocoaPoint;

    return event;
}


static void FactorioTouchSend(
    NSString *selectorName,
    CGFloat x,
    CGFloat y
) {
    id view = nil;
    id listener = nil;

    FactorioTouchGetTargets(
        &view,
        &listener
    );

    if (!listener || !view) {
        return;
    }

    FactorioTouchMouseEvent *event =
        FactorioTouchMakeEvent(
            x,
            y,
            view
        );

    if (!event) {
        return;
    }

    SEL selector =
        NSSelectorFromString(selectorName);

    if (![listener respondsToSelector:selector]) {
        return;
    }

    void (^sendEvent)(void) = ^{
        FactorioInputPerform(^{
            ((void (*)(id, SEL, id))objc_msgSend)(
                listener,
                selector,
                event
            );
        });
    };

    // The real Cocoa backend receives events on the main thread.
    // UIKit also delivers touch events on the main thread.
    if ([NSThread isMainThread]) {
        sendEvent();
    } else {
        dispatch_async(
            dispatch_get_main_queue(),
            sendEvent
        );
    }
}

#pragma mark - Public API

void FactorioTouchBegin(
    CGFloat x,
    CGFloat y
) {
    // Set the cursor position before pressing the left mouse button.
    FactorioTouchSend(
        @"mouseMoved:",
        x,
        y
    );

    FactorioTouchSend(
        @"mouseDown:",
        x,
        y
    );
}


void FactorioTouchMove(
    CGFloat x,
    CGFloat y
) {
    FactorioTouchSend(
        @"mouseDragged:",
        x,
        y
    );
}


void FactorioTouchEnd(
    CGFloat x,
    CGFloat y
) {
    // Final position update before releasing the button.
    FactorioTouchSend(
        @"mouseDragged:",
        x,
        y
    );

    FactorioTouchSend(
        @"mouseUp:",
        x,
        y
    );
}


void FactorioTouchCancel(void)
{
    id view = nil;
    id listener = nil;

    FactorioTouchGetTargets(
        &view,
        &listener
    );

    if (!view || !listener) {
        return;
    }

    CGRect bounds =
        [FactorioMetalHost hostBounds];

    FactorioTouchSend(
        @"mouseUp:",
        CGRectGetMidX(bounds),
        CGRectGetMidY(bounds)
    );
}
