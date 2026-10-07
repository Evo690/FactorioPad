#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <objc/runtime.h>
#import <objc/message.h>


#define EXPORT \
    __attribute__((visibility("default"))) \
    __attribute__((used))

static void FPSwizzleMetalDevice(void);

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

    FPSwizzleMetalDevice();

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
- (BOOL)supportsBCTextureCompression;

@end


@implementation NSObject (FactorioMetalDeviceCompat)

- (BOOL)isDepth24Stencil8PixelFormatSupported
{
    return NO;
}

- (BOOL)supportsBCTextureCompression
{
    return NO;
}

@end

#pragma mark - BC Texture Compatibility for iOS (A-series GPUs)

enum {
    FP_MTLPixelFormatBC1_RGBA           = 130,
    FP_MTLPixelFormatBC1_RGBA_sRGB      = 131,
    FP_MTLPixelFormatBC2_RGBA           = 132,
    FP_MTLPixelFormatBC2_RGBA_sRGB      = 133,
    FP_MTLPixelFormatBC3_RGBA           = 134,
    FP_MTLPixelFormatBC3_RGBA_sRGB      = 135,
    FP_MTLPixelFormatBC4_RUnorm         = 140,
    FP_MTLPixelFormatBC4_RSnorm         = 141,
    FP_MTLPixelFormatBC5_RGUnorm        = 150,
    FP_MTLPixelFormatBC5_RGSnorm        = 151,
    FP_MTLPixelFormatBC6H_RGBFloat      = 160,
    FP_MTLPixelFormatBC6H_RGBUfloat     = 161,
    FP_MTLPixelFormatBC7_RGBAUnorm      = 170,
    FP_MTLPixelFormatBC7_RGBAUnorm_sRGB = 171,
};

static inline BOOL FPIsBCPixelFormat(MTLPixelFormat format)
{
    return (format >= 130 && format <= 135) ||
           (format >= 140 && format <= 141) ||
           (format >= 150 && format <= 151) ||
           (format >= 160 && format <= 161) ||
           (format >= 170 && format <= 171);
}

static inline MTLPixelFormat FPFallbackPixelFormat(MTLPixelFormat format)
{
    switch ((NSUInteger)format) {
        case FP_MTLPixelFormatBC1_RGBA:
        case FP_MTLPixelFormatBC2_RGBA:
        case FP_MTLPixelFormatBC3_RGBA:
        case FP_MTLPixelFormatBC7_RGBAUnorm:
            return MTLPixelFormatRGBA8Unorm;

        case FP_MTLPixelFormatBC1_RGBA_sRGB:
        case FP_MTLPixelFormatBC2_RGBA_sRGB:
        case FP_MTLPixelFormatBC3_RGBA_sRGB:
        case FP_MTLPixelFormatBC7_RGBAUnorm_sRGB:
            return MTLPixelFormatRGBA8Unorm_sRGB;

        case FP_MTLPixelFormatBC4_RUnorm:
            return MTLPixelFormatR8Unorm;

        case FP_MTLPixelFormatBC4_RSnorm:
            return MTLPixelFormatR8Snorm;

        case FP_MTLPixelFormatBC5_RGUnorm:
            return MTLPixelFormatRG8Unorm;

        case FP_MTLPixelFormatBC5_RGSnorm:
            return MTLPixelFormatRG8Snorm;

        case FP_MTLPixelFormatBC6H_RGBFloat:
        case FP_MTLPixelFormatBC6H_RGBUfloat:
            return MTLPixelFormatRGBA16Float;

        default:
            return format;
    }
}

static inline BOOL FPDeviceSupportsBC(id<MTLDevice> device)
{
    if ([device respondsToSelector:@selector(supportsBCTextureCompression)]) {
        return [device supportsBCTextureCompression];
    }
    return NO;
}

#pragma mark - BC Decompression Helpers

static void FPDecodeBC1Block(const uint8_t *src, uint8_t *dst, size_t dstPitch)
{
    uint16_t c0 = (uint16_t)(src[0] | (src[1] << 8));
    uint16_t c1 = (uint16_t)(src[2] | (src[3] << 8));
    uint8_t r[4], g[4], b[4], a[4];
    r[0] = ((c0 >> 11) & 0x1F) * 255 / 31;
    g[0] = ((c0 >> 5) & 0x3F) * 255 / 63;
    b[0] = (c0 & 0x1F) * 255 / 31;
    a[0] = 255;
    r[1] = ((c1 >> 11) & 0x1F) * 255 / 31;
    g[1] = ((c1 >> 5) & 0x3F) * 255 / 63;
    b[1] = (c1 & 0x1F) * 255 / 31;
    a[1] = 255;
    if (c0 > c1) {
        r[2] = (uint8_t)((2 * r[0] + r[1]) / 3);
        g[2] = (uint8_t)((2 * g[0] + g[1]) / 3);
        b[2] = (uint8_t)((2 * b[0] + b[1]) / 3);
        a[2] = 255;
        r[3] = (uint8_t)((r[0] + 2 * r[1]) / 3);
        g[3] = (uint8_t)((g[0] + 2 * r[1]) / 3);
        b[3] = (uint8_t)((b[0] + 2 * b[1]) / 3);
        a[3] = 255;
    } else {
        r[2] = (uint8_t)((r[0] + r[1]) / 2);
        g[2] = (uint8_t)((g[0] + g[1]) / 2);
        b[2] = (uint8_t)((b[0] + b[1]) / 2);
        a[2] = 255;
        r[3] = g[3] = b[3] = a[3] = 0;
    }
    uint32_t indices = (uint32_t)(src[4] | (src[5] << 8) | (src[6] << 16) | (src[7] << 24));
    for (int y = 0; y < 4; y++) {
        for (int x = 0; x < 4; x++) {
            int idx = (indices >> (2 * (y * 4 + x))) & 3;
            dst[y * dstPitch + x * 4 + 0] = r[idx];
            dst[y * dstPitch + x * 4 + 1] = g[idx];
            dst[y * dstPitch + x * 4 + 2] = b[idx];
            dst[y * dstPitch + x * 4 + 3] = a[idx];
        }
    }
}

static void FPDecodeBC3Block(const uint8_t *src, uint8_t *dst, size_t dstPitch)
{
    const uint64_t *p64 = (const uint64_t *)src;
    if (p64[0] == 0 && p64[1] == 0) {
        for (int y = 0; y < 4; y++) {
            memset(dst + y * dstPitch, 0, 16);
        }
        return;
    }
    uint8_t a0 = src[0], a1 = src[1];
    uint8_t a[8];
    a[0] = a0; a[1] = a1;
    if (a0 > a1) {
        for (int i = 1; i <= 6; i++) a[i + 1] = (uint8_t)(((7 - i) * a0 + i * a1) / 7);
    } else {
        for (int i = 1; i <= 4; i++) a[i + 1] = (uint8_t)(((5 - i) * a0 + i * a1) / 5);
        a[6] = 0; a[7] = 255;
    }
    uint64_t aIndices = (uint64_t)src[2] | ((uint64_t)src[3] << 8) | ((uint64_t)src[4] << 16) |
                        ((uint64_t)src[5] << 24) | ((uint64_t)src[6] << 32) | ((uint64_t)src[7] << 40);

    uint16_t c0 = (uint16_t)(src[8] | (src[9] << 8));
    uint16_t c1 = (uint16_t)(src[10] | (src[11] << 8));
    uint8_t r[4], g[4], b[4];
    r[0] = ((c0 >> 11) & 0x1F) * 255 / 31;
    g[0] = ((c0 >> 5) & 0x3F) * 255 / 63;
    b[0] = (c0 & 0x1F) * 255 / 31;
    r[1] = ((c1 >> 11) & 0x1F) * 255 / 31;
    g[1] = ((c1 >> 5) & 0x3F) * 255 / 63;
    b[1] = (c1 & 0x1F) * 255 / 31;
    r[2] = (uint8_t)((2 * r[0] + r[1]) / 3);
    g[2] = (uint8_t)((2 * g[0] + g[1]) / 3);
    b[2] = (uint8_t)((2 * b[0] + b[1]) / 3);
    r[3] = (uint8_t)((r[0] + 2 * r[1]) / 3);
    g[3] = (uint8_t)((g[0] + 2 * g[1]) / 3);
    b[3] = (uint8_t)((b[0] + 2 * b[1]) / 3);
    uint32_t cIndices = (uint32_t)(src[12] | (src[13] << 8) | (src[14] << 16) | (src[15] << 24));
    for (int y = 0; y < 4; y++) {
        for (int x = 0; x < 4; x++) {
            int p = y * 4 + x;
            int cIdx = (cIndices >> (2 * p)) & 3;
            int aIdx = (int)((aIndices >> (3 * p)) & 7);
            dst[y * dstPitch + x * 4 + 0] = r[cIdx];
            dst[y * dstPitch + x * 4 + 1] = g[cIdx];
            dst[y * dstPitch + x * 4 + 2] = b[cIdx];
            dst[y * dstPitch + x * 4 + 3] = a[aIdx];
        }
    }
}

static void FPDecodeBC4Block(const uint8_t *src, uint8_t *dst, size_t dstPitch)
{
    uint8_t e0 = src[0], e1 = src[1];
    uint8_t val[8];
    val[0] = e0; val[1] = e1;
    if (e0 > e1) {
        for (int i = 1; i <= 6; i++) val[i + 1] = (uint8_t)(((7 - i) * e0 + i * e1) / 7);
    } else {
        for (int i = 1; i <= 4; i++) val[i + 1] = (uint8_t)(((5 - i) * e0 + i * e1) / 5);
        val[6] = 0; val[7] = 255;
    }
    uint64_t indices = (uint64_t)src[2] | ((uint64_t)src[3] << 8) | ((uint64_t)src[4] << 16) |
                       ((uint64_t)src[5] << 24) | ((uint64_t)src[6] << 32) | ((uint64_t)src[7] << 40);
    for (int y = 0; y < 4; y++) {
        for (int x = 0; x < 4; x++) {
            int p = y * 4 + x;
            int idx = (int)((indices >> (3 * p)) & 7);
            dst[y * dstPitch + x] = val[idx];
        }
    }
}

static void FPDecodeBC5Block(const uint8_t *src, uint8_t *dst, size_t dstPitch)
{
    uint8_t red[16], green[16];
    FPDecodeBC4Block(src, red, 4);
    FPDecodeBC4Block(src + 8, green, 4);
    for (int y = 0; y < 4; y++) {
        for (int x = 0; x < 4; x++) {
            dst[y * dstPitch + x * 2 + 0] = red[y * 4 + x];
            dst[y * dstPitch + x * 2 + 1] = green[y * 4 + x];
        }
    }
}

static BOOL FPDecompressBCData(MTLPixelFormat format,
                               const void *srcBytes,
                               size_t srcBytesPerRow,
                               size_t width,
                               size_t height,
                               void **outData,
                               size_t *outBytesPerRow)
{
    size_t blocksX = (width + 3) / 4;
    size_t blocksY = (height + 3) / 4;
    if (blocksX == 0 || blocksY == 0) return NO;

    size_t blockSize = 0;
    size_t dstBytesPerPixel = 0;

    switch ((NSUInteger)format) {
        case FP_MTLPixelFormatBC1_RGBA:
        case FP_MTLPixelFormatBC1_RGBA_sRGB:
            blockSize = 8;
            dstBytesPerPixel = 4;
            break;
        case FP_MTLPixelFormatBC2_RGBA:
        case FP_MTLPixelFormatBC2_RGBA_sRGB:
        case FP_MTLPixelFormatBC3_RGBA:
        case FP_MTLPixelFormatBC3_RGBA_sRGB:
        case FP_MTLPixelFormatBC7_RGBAUnorm:
        case FP_MTLPixelFormatBC7_RGBAUnorm_sRGB:
            blockSize = 16;
            dstBytesPerPixel = 4;
            break;
        case FP_MTLPixelFormatBC4_RUnorm:
        case FP_MTLPixelFormatBC4_RSnorm:
            blockSize = 8;
            dstBytesPerPixel = 1;
            break;
        case FP_MTLPixelFormatBC5_RGUnorm:
        case FP_MTLPixelFormatBC5_RGSnorm:
            blockSize = 16;
            dstBytesPerPixel = 2;
            break;
        default:
            return NO;
    }

    size_t dstPitch = width * dstBytesPerPixel;
    size_t totalDstBytes = dstPitch * height;
    uint8_t *dst = (uint8_t *)calloc(1, totalDstBytes);
    if (!dst) return NO;

    if (srcBytesPerRow == 0) {
        srcBytesPerRow = blocksX * blockSize;
    }

    const uint8_t *src = (const uint8_t *)srcBytes;

    BOOL allZero = YES;
    for (size_t by = 0; by < blocksY && allZero; by++) {
        const uint8_t *row = src + by * srcBytesPerRow;
        for (size_t bx = 0; bx < blocksX; bx++) {
            const uint64_t *p64 = (const uint64_t *)(row + bx * blockSize);
            if (p64[0] != 0 || (blockSize == 16 && p64[1] != 0)) {
                allZero = NO;
                break;
            }
        }
    }

    if (allZero) {
        *outData = dst;
        *outBytesPerRow = dstPitch;
        return YES;
    }

    for (size_t by = 0; by < blocksY; by++) {
        const uint8_t *srcRow = src + by * srcBytesPerRow;
        for (size_t bx = 0; bx < blocksX; bx++) {
            const uint8_t *srcBlock = srcRow + bx * blockSize;
            uint8_t blockDst[16 * 4];
            size_t blockPitch = 4 * dstBytesPerPixel;

            switch ((NSUInteger)format) {
                case FP_MTLPixelFormatBC1_RGBA:
                case FP_MTLPixelFormatBC1_RGBA_sRGB:
                    FPDecodeBC1Block(srcBlock, blockDst, blockPitch);
                    break;
                case FP_MTLPixelFormatBC3_RGBA:
                case FP_MTLPixelFormatBC3_RGBA_sRGB:
                    FPDecodeBC3Block(srcBlock, blockDst, blockPitch);
                    break;
                case FP_MTLPixelFormatBC4_RUnorm:
                case FP_MTLPixelFormatBC4_RSnorm:
                    FPDecodeBC4Block(srcBlock, blockDst, blockPitch);
                    break;
                case FP_MTLPixelFormatBC5_RGUnorm:
                case FP_MTLPixelFormatBC5_RGSnorm:
                    FPDecodeBC5Block(srcBlock, blockDst, blockPitch);
                    break;
                default:
                    FPDecodeBC3Block(srcBlock, blockDst, blockPitch);
                    break;
            }

            size_t blockW = (bx * 4 + 4 <= width) ? 4 : (width - bx * 4);
            size_t blockH = (by * 4 + 4 <= height) ? 4 : (height - by * 4);
            for (size_t y = 0; y < blockH; y++) {
                memcpy(dst + (by * 4 + y) * dstPitch + (bx * 4) * dstBytesPerPixel,
                       blockDst + y * blockPitch,
                       blockW * dstBytesPerPixel);
            }
        }
    }

    *outData = dst;
    *outBytesPerRow = dstPitch;
    return YES;
}

#pragma mark - Method Swizzling

static const char kOriginalPixelFormatKey = 0;

typedef id<MTLTexture> (*FPNewTextureWithDescriptorIMP)(id, SEL, MTLTextureDescriptor *);
typedef id<MTLTexture> (*FPNewTextureWithDescriptorIOSurfaceIMP)(id, SEL, MTLTextureDescriptor *, IOSurfaceRef, NSUInteger);
typedef MTLPixelFormat (*FPPixelFormatIMP)(id, SEL);
typedef void (*FPReplaceRegionIMP)(id, SEL, MTLRegion, NSUInteger, const void *, NSUInteger);
typedef void (*FPReplaceRegionSliceIMP)(id, SEL, MTLRegion, NSUInteger, NSUInteger, const void *, NSUInteger, NSUInteger);

static FPNewTextureWithDescriptorIMP orig_newTextureWithDescriptor = NULL;
static FPNewTextureWithDescriptorIOSurfaceIMP orig_newTextureWithDescriptorIOSurface = NULL;
static FPPixelFormatIMP orig_pixelFormat = NULL;
static FPReplaceRegionIMP orig_replaceRegion = NULL;
static FPReplaceRegionSliceIMP orig_replaceRegionSlice = NULL;

static MTLPixelFormat FPTarget_pixelFormat(id self, SEL _cmd)
{
    NSNumber *origFormat = objc_getAssociatedObject(self, &kOriginalPixelFormatKey);
    if (origFormat != nil) {
        return (MTLPixelFormat)[origFormat unsignedIntegerValue];
    }
    if (orig_pixelFormat) {
        return orig_pixelFormat(self, _cmd);
    }
    return MTLPixelFormatInvalid;
}

static void FP_replaceRegion(id self, SEL _cmd, MTLRegion region, NSUInteger level, const void *pixelBytes, NSUInteger bytesPerRow)
{
    NSNumber *origFormatNum = objc_getAssociatedObject(self, &kOriginalPixelFormatKey);
    if (!origFormatNum || !pixelBytes) {
        if (orig_replaceRegion) {
            orig_replaceRegion(self, _cmd, region, level, pixelBytes, bytesPerRow);
        }
        return;
    }

    MTLPixelFormat origFormat = (MTLPixelFormat)[origFormatNum unsignedIntegerValue];
    size_t width = region.size.width;
    size_t height = region.size.height;

    void *decompressedData = NULL;
    size_t decompressedBytesPerRow = 0;

    if (FPDecompressBCData(origFormat, pixelBytes, bytesPerRow, width, height, &decompressedData, &decompressedBytesPerRow)) {
        if (orig_replaceRegion) {
            orig_replaceRegion(self, _cmd, region, level, decompressedData, decompressedBytesPerRow);
        }
        free(decompressedData);
    } else {
        if (orig_replaceRegion) {
            orig_replaceRegion(self, _cmd, region, level, pixelBytes, bytesPerRow);
        }
    }
}

static void FP_replaceRegionSlice(id self, SEL _cmd, MTLRegion region, NSUInteger level, NSUInteger slice, const void *pixelBytes, NSUInteger bytesPerRow, NSUInteger bytesPerImage)
{
    NSNumber *origFormatNum = objc_getAssociatedObject(self, &kOriginalPixelFormatKey);
    if (!origFormatNum || !pixelBytes) {
        if (orig_replaceRegionSlice) {
            orig_replaceRegionSlice(self, _cmd, region, level, slice, pixelBytes, bytesPerRow, bytesPerImage);
        }
        return;
    }

    MTLPixelFormat origFormat = (MTLPixelFormat)[origFormatNum unsignedIntegerValue];
    size_t width = region.size.width;
    size_t height = region.size.height;
    size_t depth = region.size.depth > 0 ? region.size.depth : 1;

    void *decompressedData = NULL;
    size_t decompressedBytesPerRow = 0;

    if (depth == 1 && FPDecompressBCData(origFormat, pixelBytes, bytesPerRow, width, height, &decompressedData, &decompressedBytesPerRow)) {
        size_t decompressedBytesPerImage = decompressedBytesPerRow * height;
        if (orig_replaceRegionSlice) {
            orig_replaceRegionSlice(self, _cmd, region, level, slice, decompressedData, decompressedBytesPerRow, decompressedBytesPerImage);
        }
        free(decompressedData);
    } else {
        if (orig_replaceRegionSlice) {
            orig_replaceRegionSlice(self, _cmd, region, level, slice, pixelBytes, bytesPerRow, bytesPerImage);
        }
    }
}

static void FPSwizzleTextureClassIfNeeded(Class textureClass)
{
    static NSMutableSet *swizzledClasses = nil;
    static dispatch_once_t initToken;
    dispatch_once(&initToken, ^{
        swizzledClasses = [[NSMutableSet alloc] init];
    });

    @synchronized(swizzledClasses) {
        if ([swizzledClasses containsObject:textureClass]) {
            return;
        }
        [swizzledClasses addObject:textureClass];

        SEL selPixelFormat = @selector(pixelFormat);
        Method mPixelFormat = class_getInstanceMethod(textureClass, selPixelFormat);
        if (mPixelFormat) {
            orig_pixelFormat = (FPPixelFormatIMP)method_getImplementation(mPixelFormat);
            if (!class_addMethod(textureClass, selPixelFormat, (IMP)FPTarget_pixelFormat, method_getTypeEncoding(mPixelFormat))) {
                method_setImplementation(mPixelFormat, (IMP)FPTarget_pixelFormat);
            }
        }

        SEL selReplace = @selector(replaceRegion:mipmapLevel:withBytes:bytesPerRow:);
        Method mReplace = class_getInstanceMethod(textureClass, selReplace);
        if (mReplace) {
            orig_replaceRegion = (FPReplaceRegionIMP)method_getImplementation(mReplace);
            if (!class_addMethod(textureClass, selReplace, (IMP)FP_replaceRegion, method_getTypeEncoding(mReplace))) {
                method_setImplementation(mReplace, (IMP)FP_replaceRegion);
            }
        }

        SEL selReplaceSlice = @selector(replaceRegion:mipmapLevel:slice:withBytes:bytesPerRow:bytesPerImage:);
        Method mReplaceSlice = class_getInstanceMethod(textureClass, selReplaceSlice);
        if (mReplaceSlice) {
            orig_replaceRegionSlice = (FPReplaceRegionSliceIMP)method_getImplementation(mReplaceSlice);
            if (!class_addMethod(textureClass, selReplaceSlice, (IMP)FP_replaceRegionSlice, method_getTypeEncoding(mReplaceSlice))) {
                method_setImplementation(mReplaceSlice, (IMP)FP_replaceRegionSlice);
            }
        }
    }
}

static id<MTLTexture> FP_newTextureWithDescriptor(id self, SEL _cmd, MTLTextureDescriptor *descriptor)
{
    if (!descriptor) {
        return orig_newTextureWithDescriptor ? orig_newTextureWithDescriptor(self, _cmd, descriptor) : nil;
    }

    MTLPixelFormat requestedFormat = descriptor.pixelFormat;
    if (FPIsBCPixelFormat(requestedFormat) && !FPDeviceSupportsBC((id<MTLDevice>)self)) {
        MTLPixelFormat fallback = FPFallbackPixelFormat(requestedFormat);
        NSLog(@"[FactorioCompat] Intercepted unsupported BC texture format %lu -> remapping to %lu (%zux%zu)",
              (unsigned long)requestedFormat, (unsigned long)fallback,
              (size_t)descriptor.width, (size_t)descriptor.height);

        MTLTextureDescriptor *safeDesc = [descriptor copy];
        safeDesc.pixelFormat = fallback;

        id<MTLTexture> texture = orig_newTextureWithDescriptor ? orig_newTextureWithDescriptor(self, _cmd, safeDesc) : nil;
        if (texture) {
            objc_setAssociatedObject(texture, &kOriginalPixelFormatKey, @(requestedFormat), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            FPSwizzleTextureClassIfNeeded([texture class]);
        }
        return texture;
    }

    return orig_newTextureWithDescriptor ? orig_newTextureWithDescriptor(self, _cmd, descriptor) : nil;
}

static id<MTLTexture> FP_newTextureWithDescriptorIOSurface(id self, SEL _cmd, MTLTextureDescriptor *descriptor, IOSurfaceRef iosurface, NSUInteger plane)
{
    if (!descriptor) {
        return orig_newTextureWithDescriptorIOSurface ? orig_newTextureWithDescriptorIOSurface(self, _cmd, descriptor, iosurface, plane) : nil;
    }

    MTLPixelFormat requestedFormat = descriptor.pixelFormat;
    if (FPIsBCPixelFormat(requestedFormat) && !FPDeviceSupportsBC((id<MTLDevice>)self)) {
        MTLPixelFormat fallback = FPFallbackPixelFormat(requestedFormat);
        NSLog(@"[FactorioCompat] Intercepted unsupported BC IOSurface texture format %lu -> remapping to %lu",
              (unsigned long)requestedFormat, (unsigned long)fallback);

        MTLTextureDescriptor *safeDesc = [descriptor copy];
        safeDesc.pixelFormat = fallback;

        id<MTLTexture> texture = orig_newTextureWithDescriptorIOSurface ? orig_newTextureWithDescriptorIOSurface(self, _cmd, safeDesc, iosurface, plane) : nil;
        if (texture) {
            objc_setAssociatedObject(texture, &kOriginalPixelFormatKey, @(requestedFormat), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            FPSwizzleTextureClassIfNeeded([texture class]);
        }
        return texture;
    }

    return orig_newTextureWithDescriptorIOSurface ? orig_newTextureWithDescriptorIOSurface(self, _cmd, descriptor, iosurface, plane) : nil;
}

static void FPSwizzleMetalDevice(void)
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        if (!device) {
            return;
        }

        Class deviceClass = [device class];

        SEL selNewTex = @selector(newTextureWithDescriptor:);
        Method mNewTex = class_getInstanceMethod(deviceClass, selNewTex);
        if (mNewTex) {
            orig_newTextureWithDescriptor = (FPNewTextureWithDescriptorIMP)method_getImplementation(mNewTex);
            if (!class_addMethod(deviceClass, selNewTex, (IMP)FP_newTextureWithDescriptor, method_getTypeEncoding(mNewTex))) {
                method_setImplementation(mNewTex, (IMP)FP_newTextureWithDescriptor);
            }
        }

        SEL selNewTexIO = @selector(newTextureWithDescriptor:iosurface:plane:);
        Method mNewTexIO = class_getInstanceMethod(deviceClass, selNewTexIO);
        if (mNewTexIO) {
            orig_newTextureWithDescriptorIOSurface = (FPNewTextureWithDescriptorIOSurfaceIMP)method_getImplementation(mNewTexIO);
            if (!class_addMethod(deviceClass, selNewTexIO, (IMP)FP_newTextureWithDescriptorIOSurface, method_getTypeEncoding(mNewTexIO))) {
                method_setImplementation(mNewTexIO, (IMP)FP_newTextureWithDescriptorIOSurface);
            }
        }
    });
}

static void FPSanitizeConfigIfNeeded(NSString *configPath)
{
    // Use the exact config path prepared by FactorioLoader; do not independently
    // re-resolve Documents and risk sanitizing a different file.
    if (!configPath.length) {
        NSLog(@"[FactorioCompat] No canonical config path; skipping config sanitization.");
        return;
    }

    NSFileManager *fm = NSFileManager.defaultManager;
    if (![fm fileExistsAtPath:configPath]) {
        NSLog(@"[FactorioCompat] Canonical config does not exist: %@", configPath);
        return;
    }
    NSLog(@"[FactorioCompat] Checking canonical config: %@", configPath);

    NSError *err = nil;
    NSString *content = [NSString stringWithContentsOfFile:configPath encoding:NSUTF8StringEncoding error:&err];
    if (!content) {
        NSLog(@"[FactorioCompat] Cannot read canonical config %@: %@", configPath, err.localizedDescription);
        return;
    }

    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    BOOL bcSupported = device && device.supportsBCTextureCompression;
    if (bcSupported) {
        NSLog(@"[FactorioCompat] Config needs no mobile-GPU sanitization (BC compression supported).");
        return;
    }

    BOOL modified = NO;
    // Factorio 2.0 only accepts high or medium. Stale FactorioPad configs wrote
    // low/normal, which the game ignores and then keeps the GPU high preset.
    if ([content containsString:@"graphics-quality=low"]) {
        content = [content stringByReplacingOccurrencesOfString:@"graphics-quality=low"
                                                     withString:@"graphics-quality=medium"];
        modified = YES;
    }
    if ([content containsString:@"graphics-quality=normal"]) {
        content = [content stringByReplacingOccurrencesOfString:@"graphics-quality=normal"
                                                     withString:@"graphics-quality=medium"];
        modified = YES;
    }
    if ([content containsString:@"high-quality-animations=true"]) {
        content = [content stringByReplacingOccurrencesOfString:@"high-quality-animations=true"
                                                     withString:@"high-quality-animations=false"];
        modified = YES;
    }
    if ([content containsString:@"max-texture-size=0"]) {
        content = [content stringByReplacingOccurrencesOfString:@"max-texture-size=0"
                                                     withString:@"max-texture-size=4096"];
        modified = YES;
    }
    if ([content containsString:@"video-memory-usage=all"]) {
        content = [content stringByReplacingOccurrencesOfString:@"video-memory-usage=all"
                                                     withString:@"video-memory-usage=medium"];
        modified = YES;
    }
    if ([content containsString:@"texture-compression-level=high-quality"]) {
        content = [content stringByReplacingOccurrencesOfString:@"texture-compression-level=high-quality"
                                                     withString:@"texture-compression-level=none"];
        modified = YES;
    }
    if (modified) {
        NSError *writeError = nil;
        if (![content writeToFile:configPath atomically:YES encoding:NSUTF8StringEncoding error:&writeError]) {
            NSLog(@"[FactorioCompat] Cannot write sanitized config %@: %@", configPath, writeError.localizedDescription);
        } else {
            NSLog(@"[FactorioCompat] Sanitized canonical config for mobile GPU: %@", configPath);
        }
    } else {
        NSLog(@"[FactorioCompat] Canonical config already uses safe mobile-GPU settings.");
    }
}

EXPORT
void FactorioCompatSanitizeConfig(NSString *configPath)
{
    FPSanitizeConfigIfNeeded(configPath);
}

@interface FactorioMetalShims : NSObject
@end

@implementation FactorioMetalShims

+ (void)load
{
    FPSwizzleMetalDevice();
}

@end

