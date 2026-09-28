#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT void FactorioTouchRegisterSDLResponder(
    id view,
    id listener
);

FOUNDATION_EXPORT void FactorioTouchBegin(
    CGFloat x,
    CGFloat y
);

FOUNDATION_EXPORT void FactorioTouchMove(
    CGFloat x,
    CGFloat y
);

FOUNDATION_EXPORT void FactorioTouchEnd(
    CGFloat x,
    CGFloat y
);

FOUNDATION_EXPORT void FactorioTouchCancel(void);

FOUNDATION_EXPORT void FactorioTouchUpdateWindowSize(void);

NS_ASSUME_NONNULL_END
