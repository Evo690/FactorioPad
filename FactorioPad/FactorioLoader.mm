#import "FactorioLoader.h"

#import "FactorioControllerBridge.h"
#import "FactorioKeyboardBridge.h"

#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <errno.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static NSString *const FactorioDataDirectoryName = @"FactorioPad";

static void FactorioReportError(NSString *message)
{
    NSLog(@"[FactorioPad] %@", message);
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:@"FactorioStopped"
            object:nil userInfo:@{@"message": message}];
    });
}

static void FactorioConfigureEnvironment(void)
{
    setenv("SDL_JOYSTICK_MFI", "1", 1);
    setenv("SDL_JOYSTICK_IOKIT", "0", 1);
    setenv("SDL_JOYSTICK_HIDAPI", "0", 1);
}

static NSString *FactorioWritableRoot(void)
{
    NSURL *applicationSupport = [NSFileManager.defaultManager
        URLsForDirectory:NSApplicationSupportDirectory
        inDomains:NSUserDomainMask].firstObject;

    return [applicationSupport.path
        stringByAppendingPathComponent:FactorioDataDirectoryName];
}

static NSArray<NSString *> *FactorioControllerBindings(void)
{
    return @[
        @"pick-items=SHIFT + E", @"drop-cursor=SHIFT + Q", @"show-info=CONTROL + SPACE",
        @"toggle-driving=CONTROL + E", @"copy=CONTROL + Q", @"cut=CONTROL + SHIFT + Q",
        @"paste=CONTROL + R", @"undo=CONTROL + SHIFT + R", @"redo=CONTROL + SHIFT + SPACE",
        @"open-technology-gui=SHIFT + M", @"production-statistics=CONTROL + M",
        @"toggle-blueprint-library=CONTROL + SHIFT + M"
    ];
}

static NSString *FactorioDefaultConfig(
    NSString *readDataPath,
    NSString *writeDataPath
)
{
    return [NSString stringWithFormat:
        // Factorio 2.0.77 uses format 13; older headers trigger settings conversion.
        @"; version=13\n"
         "[path]\n"
         "read-data=%@\n"
         "write-data=%@\n"
         "\n"
         "[graphics]\n"
         "render-in-native-resolution=true\n"
         "high-quality-animations=true\n"
         "texture-compression-level=high-quality\n"
         "\n"
         "[interface]\n"
         "ui-scale-mode=manual-pixels\n"
         "custom-ui-scale=1.5\n"
         "pick-ghost-cursor=true\n"
         "tooltip-delay=0.1\n"
         "active-quick-bars=1\n"
         "\n"
         "[input]\n"
         "input-method=keyboard-and-mouse\n"
         "heading-vehicle-driving=true\n"
         "\n"
         "[controller]\n"
         "icons=xbox\n"
         "button-layout=western\n",
        readDataPath,
        writeDataPath];
}

static NSString *FactorioUpdateConfigPaths(
    NSString *config,
    NSString *readDataPath,
    NSString *writeDataPath
)
{
    NSArray<NSString *> *lines = [config componentsSeparatedByString:@"\n"];
    NSMutableArray<NSString *> *result = [NSMutableArray arrayWithCapacity:lines.count + 3];
    __block BOOL inPathSection = NO;
    __block BOOL foundPathSection = NO;
    __block BOOL foundReadPath = NO;
    __block BOOL foundWritePath = NO;

    void (^appendMissingPaths)(void) = ^{
        if (!foundReadPath) {
            [result addObject:[@"read-data=" stringByAppendingString:readDataPath]];
            foundReadPath = YES;
        }
        if (!foundWritePath) {
            [result addObject:[@"write-data=" stringByAppendingString:writeDataPath]];
            foundWritePath = YES;
        }
    };

    for (NSString *line in lines) {
        NSString *trimmed = [line stringByTrimmingCharactersInSet:
            NSCharacterSet.whitespaceCharacterSet];

        if ([trimmed hasPrefix:@"["] && [trimmed hasSuffix:@"]"]) {
            if (inPathSection) {
                appendMissingPaths();
            }
            inPathSection = [trimmed caseInsensitiveCompare:@"[path]"] == NSOrderedSame;
            foundPathSection = foundPathSection || inPathSection;
        }

        NSRange equals = [trimmed rangeOfString:@"="];
        NSString *key = equals.location == NSNotFound ? @"" : [[trimmed substringToIndex:equals.location]
            stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        if (inPathSection && [key isEqualToString:@"read-data"]) {
            [result addObject:[@"read-data=" stringByAppendingString:readDataPath]];
            foundReadPath = YES;
        } else if (inPathSection && [key isEqualToString:@"write-data"]) {
            [result addObject:[@"write-data=" stringByAppendingString:writeDataPath]];
            foundWritePath = YES;
        } else {
            [result addObject:line];
        }
    }

    if (inPathSection) {
        appendMissingPaths();
    } else if (!foundPathSection) {
        [result addObjectsFromArray:@[
            @"[path]",
            [@"read-data=" stringByAppendingString:readDataPath],
            [@"write-data=" stringByAppendingString:writeDataPath]
        ]];
    }

    return [result componentsJoinedByString:@"\n"];
}

static NSString *FactorioApplyControlSection(
    NSString *config,
    NSString *section,
    NSArray<NSString *> *bindings,
    BOOL enabled
)
{
    NSArray<NSString *> *lines = [config componentsSeparatedByString:@"\n"];
    NSMutableArray<NSString *> *result = [NSMutableArray arrayWithCapacity:lines.count + bindings.count];
    NSMutableSet<NSString *> *present = [NSMutableSet set];
    __block BOOL inSection = NO;
    BOOL foundSection = NO;
    void (^appendMissing)(void) = ^{
        if (!enabled || !inSection) return;
        for (NSString *binding in bindings) {
            NSString *key = [[binding componentsSeparatedByString:@"="] firstObject];
            if (![present containsObject:key]) [result addObject:binding];
        }
    };

    for (NSString *line in lines) {
        NSString *trimmed = [line stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        if ([trimmed hasPrefix:@"["] && [trimmed hasSuffix:@"]"]) {
            appendMissing();
            inSection = [trimmed caseInsensitiveCompare:section] == NSOrderedSame;
            foundSection = foundSection || inSection;
            [present removeAllObjects];
        }
        BOOL removeLine = NO;
        if (inSection) {
            NSRange equals = [trimmed rangeOfString:@"="];
            NSString *key = equals.location == NSNotFound ? @"" : [[trimmed substringToIndex:equals.location]
                stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
            for (NSString *binding in bindings) {
                if ([binding hasPrefix:[key stringByAppendingString:@"="]]) {
                    [present addObject:key];
                    removeLine = !enabled && [trimmed isEqualToString:binding];
                    break;
                }
            }
        }
        if (!removeLine) [result addObject:line];
    }
    appendMissing();
    if (enabled && !foundSection) {
        [result addObject:section];
        [result addObjectsFromArray:bindings];
    }
    return [result componentsJoinedByString:@"\n"];
}

#if DEBUG
static void FactorioCheckConfigUpdater(void)
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *updated = FactorioUpdateConfigPaths(
            @"[path]\nread-data=/old\n[graphics]\nfoo=bar\n",
            @"/new/read",
            @"/new/write"
        );

        NSCAssert([updated containsString:@"read-data=/new/read"], @"read-data was not updated");
        NSCAssert([updated containsString:@"write-data=/new/write"], @"write-data was not added");
        NSCAssert([updated containsString:@"foo=bar"], @"existing settings were not preserved");
    });
}
#endif

#ifndef FACTORIO_CONFIG_TEST
static NSString *FactorioPrepareWritableData(NSString *readDataPath)
{
#if DEBUG
    FactorioCheckConfigUpdater();
#endif

    NSFileManager *fileManager = NSFileManager.defaultManager;
    NSString *root = FactorioWritableRoot();
    NSArray<NSString *> *directories = @[
        root,
        [root stringByAppendingPathComponent:@"config"],
        [root stringByAppendingPathComponent:@"mods"],
        [root stringByAppendingPathComponent:@"saves"],
        [root stringByAppendingPathComponent:@"scenarios"],
        [root stringByAppendingPathComponent:@"temp"],
        [root stringByAppendingPathComponent:@"script-output"]
    ];

    for (NSString *directory in directories) {
        NSError *error = nil;
        if (![fileManager createDirectoryAtPath:directory
                    withIntermediateDirectories:YES
                                     attributes:@{NSFileProtectionKey: NSFileProtectionCompleteUntilFirstUserAuthentication}
                                          error:&error]) {
            FactorioReportError(@"Factorio cannot create its data folder.");
            return nil;
        }
    }

    NSString *configPath = [root stringByAppendingPathComponent:@"config/config.ini"];
    NSError *error = nil;
    NSString *config = [NSString stringWithContentsOfFile:configPath
                                                  encoding:NSUTF8StringEncoding
                                                     error:&error];

    if (!config && [fileManager fileExistsAtPath:configPath]) {
        FactorioReportError(@"Factorio cannot read its configuration. The app did not replace it.");
        return nil;
    }
    if (!config) {
        config = FactorioDefaultConfig(readDataPath, root);
    } else {
        config = FactorioUpdateConfigPaths(config, readDataPath, root);
        config = FactorioApplyControlSection(config, @"[input]",
            @[@"heading-vehicle-driving=true"], YES);
        config = FactorioApplyControlSection(config, @"[controls]",
            FactorioControllerBindings(), NO);
    }

    if (![config writeToFile:configPath
                  atomically:YES
                    encoding:NSUTF8StringEncoding
                       error:&error]) {
        FactorioReportError(@"Factorio cannot save its configuration.");
        return nil;
    }

    return configPath;
}

static void *FactorioOpenFramework(NSString *name, int flags)
{
    NSString *path = [NSBundle.mainBundle.privateFrameworksPath
        stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.framework/%@", name, name]];

    dlerror();
    void *handle = dlopen(path.fileSystemRepresentation, flags);
    if (!handle) {
        NSLog(@"[FactorioPad] Cannot load %@: %s", name, dlerror());
        FactorioReportError([NSString stringWithFormat:@"Factorio cannot load %@. Close and reopen the app.", name]);
    }
    return handle;
}

@implementation FactorioLoader

+ (void)startWithWindowSize:(CGSize)windowSize
{
    FactorioConfigureEnvironment();

    NSString *readDataPath = [NSBundle.mainBundle.bundlePath
        stringByAppendingPathComponent:@"FactorioData"];
    BOOL isDirectory = NO;

    if (![NSFileManager.defaultManager fileExistsAtPath:readDataPath isDirectory:&isDirectory] || !isDirectory) {
        FactorioReportError(@"The app does not contain the Factorio game data.");
        return;
    }

    NSString *configPath = FactorioPrepareWritableData(readDataPath);
    if (!configPath) {
        return;
    }

    NSString *writeRoot = configPath.stringByDeletingLastPathComponent.stringByDeletingLastPathComponent;
    NSString *modsPath = [writeRoot stringByAppendingPathComponent:@"mods"];

    void *compat = FactorioOpenFramework(@"FactorioCompat", RTLD_NOW | RTLD_GLOBAL);
    if (!compat) {
        return;
    }

    void *guest = FactorioOpenFramework(@"FactorioGuest", RTLD_NOW | RTLD_LOCAL);
    if (!guest) {
        return;
    }

    if (!FactorioKeyboardBridgeSetGuestHandle(guest)) {
        FactorioReportError(@"This Factorio game file does not provide compatible input functions.");
        return;
    }
    FactorioControllerBridgeStart();
    FactorioControllerBridgeSetViewportSize(windowSize.width, windowSize.height);

    typedef int (*FactorioMainFunction)(int, char **);
    dlerror();
    FactorioMainFunction factorioMain = (FactorioMainFunction)dlsym(guest, "main");
    if (!factorioMain) {
        NSLog(@"[FactorioPad] Factorio main is missing: %s", dlerror());
        FactorioReportError(@"The Factorio game file is not compatible with this app.");
        return;
    }

    CGFloat width = MAX(windowSize.width, 1.0);
    CGFloat height = MAX(windowSize.height, 1.0);
    NSString *windowSizeArgument = [NSString stringWithFormat:@"%ldx%ld",
        lround(width), lround(height)];

    NSArray<NSString *> *arguments = @[
        @"factorio",
        @"--config", configPath,
        @"--mod-directory", modsPath,
        @"--no-log-rotation",
        @"--force-metal",
        @"--fullscreen=false",
        @"--window-size", windowSizeArgument,
        @"--nogamepad",
        @"--single-thread-loading"
    ];

    NSThread *thread = [[NSThread alloc] initWithBlock:^{
        @autoreleasepool {
            if (chdir(NSBundle.mainBundle.bundlePath.fileSystemRepresentation) != 0) {
                int savedErrno = errno;
                NSLog(@"[FactorioPad] Cannot set the working directory: %s", strerror(savedErrno));
                FactorioReportError(@"Factorio cannot open its game folder.");
                return;
            }

            int argumentCount = (int)arguments.count;
            char **argumentValues = (char **)calloc((size_t)argumentCount + 1, sizeof(char *));
            if (!argumentValues) {
                FactorioReportError(@"Factorio does not have enough memory to start.");
                return;
            }

            for (int index = 0; index < argumentCount; index++) {
                argumentValues[index] = strdup(arguments[(NSUInteger)index].fileSystemRepresentation);
                if (!argumentValues[index]) {
                    for (int previous = 0; previous < index; previous++) {
                        free(argumentValues[previous]);
                    }
                    free(argumentValues);
                    FactorioReportError(@"Factorio does not have enough memory to start.");
                    return;
                }
            }

            int result = factorioMain(argumentCount, argumentValues);

            for (int index = 0; index < argumentCount; index++) {
                free(argumentValues[index]);
            }
            free(argumentValues);

            NSLog(@"[FactorioPad] Factorio stopped with status %d", result);
            FactorioControllerBridgeSetActive(NO);
            FactorioReportError(result == 0 ? @"Factorio stopped. Close and reopen the app to play again."
                : @"Factorio stopped because of an error. Close and reopen the app to try again.");
        }
    }];

    thread.name = @"FactorioMainThread";
    thread.stackSize = 8 * 1024 * 1024;
    [thread start];
}

@end
#endif
