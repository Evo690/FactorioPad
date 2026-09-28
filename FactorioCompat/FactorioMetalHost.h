#import <UIKit/UIKit.h>
#import <QuartzCore/CAMetalLayer.h>

NS_ASSUME_NONNULL_BEGIN

@interface FactorioMetalHost : NSObject

+ (void)setHostView:(UIView *)view;
+ (void)attachMetalLayer:(CAMetalLayer *)layer;
+ (nullable CAMetalLayer *)hostMetalLayer;
+ (CGFloat)hostScale;
+ (CGRect)hostBounds;

@end

NS_ASSUME_NONNULL_END
