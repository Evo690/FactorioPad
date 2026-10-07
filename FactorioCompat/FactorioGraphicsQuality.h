//
//  FactorioGraphicsQuality.h
//
//  One source of truth for the [graphics] values FactorioPad writes into
//  Factorio's config.ini, for the values FactorioCompat keeps valid while it
//  sanitizes that file, and for the sprite resolution Factorio reports in its
//  own log.
//
//  Factorio 2.0 renamed the sprite resolution options: what used to be
//  `graphics-quality=normal` is now `medium`, and 2.x builds only accept
//  `high` or `medium`. A value the running game does not know is ignored
//  silently and the preset Factorio detected for the GPU (usually high) stays
//  active, which turned a low-memory choice into the heaviest atlas load on an
//  iPhone. Every writer therefore has to spell the value the running version
//  expects, and every writer has to agree with this header.
//

#import <Foundation/Foundation.h>

#import <string.h>

NS_ASSUME_NONNULL_BEGIN

// Physical memory a device needs before Factorio's high resolution sprites
// (roughly 5 GB of uncompressed atlases for base and Space Age) can be held in
// memory. iOS keeps an app well below the physical total, so smaller devices
// run out of memory while the atlases are built.
static inline unsigned long long FactorioGraphicsHighQualityMemory(void)
{
    return 12ULL * 1024 * 1024 * 1024;
}

// Factorio renamed `graphics-quality=normal` to `medium` before 2.0, so 1.x and
// 2.x can only share one config when the value is written for the right
// version. Unparseable versions behave like the 2.x releases this app targets.
static inline BOOL FactorioGraphicsVersionUsesMediumQuality(NSString * _Nullable guestVersion)
{
    NSInteger major = guestVersion.integerValue;
    if (major >= 1) {
        return major >= 2;
    }
    return YES;
}

// The config value for the app's low/normal/high preference. Low and normal
// share one sprite resolution because Factorio 2.0 only has two; they differ in
// the remaining memory settings that FactorioPad adds for each preset.
static inline NSString *FactorioGraphicsQualityValue(NSString *preference, NSString * _Nullable guestVersion)
{
    if ([preference isEqualToString:@"high"]) {
        return @"high";
    }
    return FactorioGraphicsVersionUsesMediumQuality(guestVersion) ? @"medium" : @"normal";
}

static inline BOOL FactorioGraphicsQualityValueIsAccepted(NSString *value, NSString * _Nullable guestVersion)
{
    return [value isEqualToString:@"high"] ||
        [value isEqualToString:FactorioGraphicsQualityValue(@"normal", guestVersion)];
}

// High resolution sprites need a GPU that can upload compressed textures and
// enough memory to hold the uncompressed atlases. Without both, the device has
// to fall back to the standard sprites instead of crashing during loading.
static inline BOOL FactorioGraphicsAllowsHighQuality(
    unsigned long long physicalMemory,
    BOOL supportsBCTextureCompression
)
{
    return supportsBCTextureCompression || physicalMemory >= FactorioGraphicsHighQualityMemory();
}

// The value of an active `key=value` binding, or nil when the key is missing or
// only mentioned in a comment. Factorio's own config template is full of
// commented examples, so settings have to be read and written line by line.
static inline NSString * _Nullable FactorioGraphicsActiveValue(NSString *content, NSString *key)
{
    for (NSString *line in [content componentsSeparatedByString:@"\n"]) {
        NSString *trimmed = [line stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        if ([trimmed hasPrefix:@";"]) {
            continue;
        }
        NSRange equals = [trimmed rangeOfString:@"="];
        if (equals.location == NSNotFound) {
            continue;
        }
        NSString *existingKey = [[trimmed substringToIndex:equals.location]
            stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        if ([existingKey caseInsensitiveCompare:key] != NSOrderedSame) {
            continue;
        }
        return [[trimmed substringFromIndex:equals.location + 1]
            stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    }
    return nil;
}

// Replaces the value of every active `key` binding and records the changes in
// `changes` as "key=old -> new". Comments and every unrelated line survive.
static inline NSString *FactorioGraphicsSetActiveValue(
    NSString *content,
    NSString *key,
    NSString *value,
    NSMutableArray<NSString *> * _Nullable changes
)
{
    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    for (NSString *line in [content componentsSeparatedByString:@"\n"]) {
        NSString *trimmed = [line stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        NSRange equals = [trimmed rangeOfString:@"="];
        // Message sends to nil return 0, which is also NSOrderedSame, so a
        // missing separator has to be rejected before comparing keys.
        if ([trimmed hasPrefix:@";"] || equals.location == NSNotFound) {
            [lines addObject:line];
            continue;
        }
        NSString *existingKey = [[trimmed substringToIndex:equals.location]
            stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        if ([existingKey caseInsensitiveCompare:key] != NSOrderedSame) {
            [lines addObject:line];
            continue;
        }
        NSString *existingValue = [[trimmed substringFromIndex:equals.location + 1]
            stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        if ([existingValue isEqualToString:value]) {
            [lines addObject:line];
            continue;
        }
        [changes addObject:[NSString stringWithFormat:@"%@=%@ -> %@", key, existingValue, value]];
        [lines addObject:[key stringByAppendingFormat:@"=%@", value]];
    }
    return [lines componentsJoinedByString:@"\n"];
}

// Replaces a sprite resolution the running version cannot use, or one the
// device cannot afford. Factorio ignores an unknown value and keeps the preset
// it detected for the GPU, so a stale value silently becomes the heaviest one.
static inline NSString *FactorioGraphicsNormalizeQuality(
    NSString *content,
    NSString * _Nullable guestVersion,
    BOOL allowsHighQuality,
    NSMutableArray<NSString *> *changes
)
{
    NSString *value = FactorioGraphicsActiveValue(content, @"graphics-quality");
    if (!value.length) {
        return content;
    }
    BOOL tooHeavy = [value isEqualToString:@"high"] && !allowsHighQuality;
    if (!tooHeavy && FactorioGraphicsQualityValueIsAccepted(value, guestVersion)) {
        return content;
    }
    return FactorioGraphicsSetActiveValue(content, @"graphics-quality",
        FactorioGraphicsQualityValue(@"normal", guestVersion), changes);
}

// The version of the Factorio executable the companion injected into the app.
static inline NSString * _Nullable FactorioGraphicsGuestVersion(void)
{
    NSString *path = NSBundle.mainBundle.privateFrameworksPath;
    if (!path.length) {
        return nil;
    }
    path = [path stringByAppendingPathComponent:@"FactorioGuest.framework/Info.plist"];
    id version = [NSDictionary dictionaryWithContentsOfFile:path][@"CFBundleShortVersionString"];
    return [version isKindOfClass:NSString.class] ? version : nil;
}

// Factorio reports the sprite resolution it really uses while it prepares the
// atlases ("... Graphics options: [Graphics quality: high] [Video memory usage:
// low] ..."), which is the only way the app can confirm that the requested
// preset reached the game. Copies the last value in the buffer into `value` and
// returns whether one was found.
static inline BOOL FactorioGraphicsQualityFromLogBytes(
    const char *bytes,
    size_t length,
    char *value,
    size_t capacity
)
{
    static const char marker[] = "[Graphics quality: ";
    const size_t markerLength = sizeof(marker) - 1;
    if (!bytes || !value || capacity < 2) {
        return NO;
    }
    value[0] = '\0';
    const char *reported = NULL;
    size_t reportedLength = 0;
    for (size_t index = 0; index + markerLength <= length; index++) {
        if (memcmp(bytes + index, marker, markerLength) != 0) {
            continue;
        }
        size_t start = index + markerLength;
        size_t end = start;
        while (end < length && bytes[end] != ']' && bytes[end] != ' ' && bytes[end] != '\n' && end - start < capacity - 1) {
            end++;
        }
        // A value without its closing delimiter is still being written, so the
        // next read has to supply the rest of the line instead of reporting a
        // truncated resolution.
        if (end == start || end == length) {
            continue;
        }
        reported = bytes + start;
        reportedLength = end - start;
        index = end;
    }
    if (!reported) {
        return NO;
    }
    memcpy(value, reported, reportedLength);
    value[reportedLength] = '\0';
    return YES;
}

NS_ASSUME_NONNULL_END
