#define FACTORIO_CONFIG_TEST 1
#include "../FactorioPad/FactorioLoader.mm"

int main(void)
{
    @autoreleasepool {
        NSString *defaults = FactorioDefaultConfig(@"/new/read", @"/new/write");
        NSCAssert([defaults hasPrefix:@"; version=13\n"],
            @"defaults must declare the configuration format");
        NSCAssert([defaults containsString:@"[graphics]\nrender-in-native-resolution=true\nhigh-quality-animations=true\ntexture-compression-level=high-quality\n"],
            @"new installations must use high-quality animations and texture compression");
        NSCAssert([defaults containsString:@"[interface]\nui-scale-mode=manual-pixels\ncustom-ui-scale=1.5\n"],
            @"new installations must use a manual 150 percent interface scale");
        NSCAssert([defaults containsString:@"pick-ghost-cursor=true\ntooltip-delay=0.1\n"],
            @"new installations must enable ghost selection and a 0.1-second tooltip delay");
        NSCAssert([defaults containsString:@"[input]\ninput-method=keyboard-and-mouse\nheading-vehicle-driving=true\n"],
            @"heading driving must apply to the emulated keyboard input, not native controller input");
        NSCAssert(![defaults containsString:@"flat-character-gui="], @"inventory layout must stay unchanged");
        NSCAssert([defaults containsString:@"active-quick-bars=1\n"], @"new installations must show only one quickbar row");
        NSCAssert(![defaults containsString:@"quick-bar-button-1-secondary="],
            @"RB + D-pad must no longer configure second-row quickbar shortcuts");
        NSCAssert(![defaults containsString:@"[controls]\n"],
            @"new installations must keep Factorio's default key bindings");
        NSString *oldControllerConfig = [defaults stringByAppendingFormat:@"\n[controls]\n%@\ncopy=ALT + C\n",
            [FactorioControllerBindings() componentsJoinedByString:@"\n"]];
        NSString *upgrade = FactorioApplyConfigSection(oldControllerConfig, @"[controls]",
            FactorioControllerBindings(), NO);
        for (NSString *binding in FactorioControllerBindings()) {
            NSCAssert(![upgrade containsString:binding],
                @"upgrading must remove every old FactorioPad shortcut");
        }
        NSCAssert([upgrade containsString:@"heading-vehicle-driving=true"] &&
            [upgrade containsString:@"copy=ALT + C"],
            @"upgrading must retain driving support and custom key bindings");
        NSCAssert([FactorioUpdateConfigPaths(defaults, @"/new/read", @"/new/write") isEqualToString:defaults],
            @"later launches must preserve the default interface scale");
        NSString *customScale = @"[interface]\nui-scale-mode=manual-display-points\ncustom-ui-scale=1.25\ncustom-proportional-ui-scale=1.25\n";
        NSCAssert([FactorioUpdateConfigPaths(customScale, @"/new/read", @"/new/write") hasPrefix:customScale],
            @"saved interface preferences must not be replaced by new defaults");
        NSString *customControls = @"[interface]\npick-ghost-cursor=false\ntooltip-delay=0.04\nactive-quick-bars=2\n[input]\nheading-vehicle-driving=false\n";
        NSCAssert([FactorioUpdateConfigPaths(customControls, @"/new/read", @"/new/write") hasPrefix:customControls],
            @"saved gameplay preferences must not be replaced by new defaults");
        NSString *customGraphics = @"[graphics]\nhigh-quality-animations=false\ntexture-compression-level=none\n";
        NSCAssert([FactorioUpdateConfigPaths(customGraphics, @"/new/read", @"/new/write") hasPrefix:customGraphics],
            @"saved graphics preferences must not be replaced by new defaults");
        // Factorio 2.0 renamed the sprite resolutions: `normal` became `medium`
        // and only `high` and `medium` are accepted. A value the running game
        // does not know is ignored, so a wrong spelling silently keeps the
        // heaviest preset the GPU detection picked.
        NSCAssert([FactorioGraphicsQualityValue(@"low", @"2.0.77") isEqualToString:@"medium"] &&
            [FactorioGraphicsQualityValue(@"normal", @"2.0.77") isEqualToString:@"medium"] &&
            [FactorioGraphicsQualityValue(@"high", @"2.0.77") isEqualToString:@"high"],
            @"2.x only accepts high and medium, so low and normal both use the standard sprites");
        NSCAssert([FactorioGraphicsQualityValue(@"low", @"1.1.110") isEqualToString:@"normal"] &&
            [FactorioGraphicsQualityValue(@"normal", @"1.1.110") isEqualToString:@"normal"] &&
            [FactorioGraphicsQualityValue(@"high", @"1.1.110") isEqualToString:@"high"],
            @"1.x only accepts high and normal");
        NSCAssert(FactorioGraphicsVersionUsesMediumQuality(@"2.0.77") &&
            !FactorioGraphicsVersionUsesMediumQuality(@"1.1.110") &&
            FactorioGraphicsVersionUsesMediumQuality(nil) &&
            FactorioGraphicsVersionUsesMediumQuality(@""),
            @"an unknown version must behave like the tested 2.x release");
        NSCAssert(FactorioGraphicsQualityValueIsAccepted(@"medium", @"2.0.77") &&
            !FactorioGraphicsQualityValueIsAccepted(@"normal", @"2.0.77") &&
            !FactorioGraphicsQualityValueIsAccepted(@"low", @"2.0.77") &&
            FactorioGraphicsQualityValueIsAccepted(@"normal", @"1.1.110") &&
            !FactorioGraphicsQualityValueIsAccepted(@"medium", @"1.1.110") &&
            FactorioGraphicsQualityValueIsAccepted(@"high", @"1.1.110"),
            @"a resolution the running version cannot use has to be reported as unsupported");
        NSCAssert(!FactorioGraphicsAllowsHighQuality(6ULL * 1024 * 1024 * 1024, NO) &&
            FactorioGraphicsAllowsHighQuality(6ULL * 1024 * 1024 * 1024, YES) &&
            !FactorioGraphicsAllowsHighQuality(FactorioGraphicsHighQualityMemory() - 1, NO) &&
            FactorioGraphicsAllowsHighQuality(FactorioGraphicsHighQualityMemory(), NO),
            @"high quality needs either compressed textures or enough memory for the atlases");

        NSArray<NSString *> *low20 = FactorioGraphicsSettings(@"low", @"2.0.77");
        NSCAssert([low20 containsObject:@"graphics-quality=medium"] &&
            ![low20 containsObject:@"graphics-quality=low"] &&
            [low20 containsObject:@"video-memory-usage=low"] &&
            [low20 containsObject:@"high-quality-terrain=false"] &&
            [low20 containsObject:@"high-quality-shadows=false"] &&
            [low20 containsObject:@"additional-terrain-effects=false"] &&
            [low20 containsObject:@"light-occlusion=false"] &&
            [low20 containsObject:@"optimize-for-low-vram=true"],
            @"the low preset must use the standard sprites and the memory-saving effects");
        NSArray<NSString *> *low11 = FactorioGraphicsSettings(@"low", @"1.1.110");
        NSCAssert([low11 containsObject:@"graphics-quality=normal"] &&
            ![low11 containsObject:@"optimize-for-low-vram=true"] &&
            ![low11 containsObject:@"high-quality-terrain=false"],
            @"1.x keeps the old spelling and cannot use the 2.x effect keys");
        NSArray<NSString *> *normal20 = FactorioGraphicsSettings(@"normal", @"2.0.77");
        NSCAssert([normal20 containsObject:@"graphics-quality=medium"] &&
            [normal20 containsObject:@"video-memory-usage=medium"] &&
            ![normal20 containsObject:@"high-quality-terrain=false"],
            @"the normal preset must keep the standard sprites without removing effects");
        NSArray<NSString *> *high20 = FactorioGraphicsSettings(@"high", @"2.0.77");
        NSCAssert([high20 containsObject:@"graphics-quality=high"] &&
            [high20 containsObject:@"high-quality-animations=true"] &&
            [high20 containsObject:@"video-memory-usage=all"],
            @"the high preset must ask for the 2x sprites");

        NSString *staleHigh = @"[graphics]\ngraphics-quality=high\nhigh-quality-animations=true\n"
            "max-texture-size=0\nvideo-memory-usage=all\n[interface]\ncustom-ui-scale=1.25\n";
        NSString *appliedLow = FactorioApplyConfigSection(staleHigh, @"[graphics]",
            FactorioGraphicsSettings(@"low", @"2.0.77"), YES, YES);
        NSCAssert(FactorioConfigSectionContainsBinding(appliedLow, @"[graphics]", @"graphics-quality=medium") &&
            ![appliedLow containsString:@"graphics-quality=high"] &&
            ![appliedLow containsString:@"high-quality-animations=true"] &&
            ![appliedLow containsString:@"max-texture-size=0"] &&
            ![appliedLow containsString:@"video-memory-usage=all"] &&
            [appliedLow containsString:@"custom-ui-scale=1.25"],
            @"selecting low must replace a stale high configuration and keep unrelated settings");

        // The FactorioCompat sanitizer corrects configs written by older builds
        // or by hand; it must never leave a value the running game ignores.
        NSMutableArray<NSString *> *changes = [NSMutableArray array];
        NSString *sanitized = FactorioGraphicsNormalizeQuality(staleHigh, @"2.0.77", NO, changes);
        NSCAssert(FactorioConfigSectionContainsBinding(sanitized, @"[graphics]", @"graphics-quality=medium") &&
            ![sanitized containsString:@"graphics-quality=high"] &&
            changes.count == 1,
            @"a 2.x sanitizer must replace high with medium on a device that cannot afford it");
        [changes removeAllObjects];
        NSString *kept = FactorioGraphicsNormalizeQuality(staleHigh, @"2.0.77", YES, changes);
        NSCAssert([kept isEqualToString:staleHigh] && changes.count == 0,
            @"a device that can afford high must keep its resolution");
        [changes removeAllObjects];
        NSString *legacy = FactorioGraphicsNormalizeQuality(@"[graphics]\ngraphics-quality=very-low\n",
            @"2.0.77", NO, changes);
        NSCAssert([legacy containsString:@"graphics-quality=medium"] && changes.count == 1,
            @"a deprecated 1.x value must be replaced with the value 2.x accepts");
        [changes removeAllObjects];
        NSString *oneX = FactorioGraphicsNormalizeQuality(@"[graphics]\ngraphics-quality=medium\n",
            @"1.1.110", NO, changes);
        NSCAssert([oneX containsString:@"graphics-quality=normal"] && changes.count == 1,
            @"a 2.x value must be replaced with the value 1.x accepts");
        [changes removeAllObjects];
        NSString *commented = FactorioGraphicsNormalizeQuality(
            @"; Options: high, medium\n; graphics-quality=high\n[graphics]\n", @"2.0.77", NO, changes);
        NSCAssert(changes.count == 0 && [commented containsString:@"; graphics-quality=high"],
            @"commented example values must survive sanitization");
        [changes removeAllObjects];
        NSString *missing = FactorioGraphicsNormalizeQuality(@"[graphics]\nvideo-memory-usage=low\n",
            @"2.0.77", NO, changes);
        NSCAssert(changes.count == 0 && [missing containsString:@"video-memory-usage=low"],
            @"a config without a sprite resolution must be left alone");
        [changes removeAllObjects];
        NSString *spaced = FactorioGraphicsSetActiveValue(@"[graphics]\n high-quality-animations = true \n",
            @"high-quality-animations", @"false", changes);
        NSCAssert([spaced containsString:@"high-quality-animations=false"] &&
            ![spaced containsString:@"animations = true"] && changes.count == 1,
            @"values must be replaced even when they are padded with spaces");
        [changes removeAllObjects];
        NSString *unchanged = FactorioGraphicsSetActiveValue(@"[graphics]\nvideo-memory-usage=low\n",
            @"video-memory-usage", @"low", changes);
        NSCAssert(changes.count == 0 && [unchanged containsString:@"video-memory-usage=low"],
            @"a value that is already correct must not be rewritten");

        NSString *lowPreset = FactorioApplyConfigSection(@"[graphics]\ngraphics-quality=high\nhigh-quality-animations=true\n",
            @"[graphics]", @[@"graphics-quality=medium", @"high-quality-animations=false",
                @"max-texture-size=4096", @"video-memory-usage=low"], YES, YES);
        NSCAssert(FactorioConfigSectionContainsBinding(lowPreset, @"[graphics]", @"graphics-quality=medium") &&
            ![lowPreset containsString:@"graphics-quality=high"] &&
            [lowPreset containsString:@"high-quality-animations=false"] &&
            [lowPreset containsString:@"max-texture-size=4096"] &&
            [lowPreset containsString:@"video-memory-usage=low"],
            @"selecting low must replace stale graphics settings with the full low preset");

        char reported[16];
        const char *optionsReport =
            "0.259 Graphics options: [Graphics quality: high] [Video memory usage: low] [DXT: none]";
        NSCAssert(FactorioGraphicsQualityFromLogBytes(optionsReport, strlen(optionsReport),
            reported, sizeof(reported)) && strcmp(reported, "high") == 0,
            @"the sprite resolution in Factorio's log must be readable");
        const char *splitReport = "0.259 Graphics options: [Graphics quality: medium]";
        NSCAssert(FactorioGraphicsQualityFromLogBytes(splitReport, 40, reported, sizeof(reported)) == NO &&
            FactorioGraphicsQualityFromLogBytes(splitReport, strlen(splitReport), reported, sizeof(reported)) &&
            strcmp(reported, "medium") == 0,
            @"a report that straddles two reads must still be found once the whole line arrives");
        const char *truncatedReport = "0.259 Graphics options: [Graphics quality: med";
        NSCAssert(!FactorioGraphicsQualityFromLogBytes(truncatedReport, strlen(truncatedReport),
            reported, sizeof(reported)),
            @"a report cut off before its closing bracket must wait for the rest of the line");
        NSCAssert(!FactorioGraphicsQualityFromLogBytes("Loading sounds...\n", 18, reported, sizeof(reported)),
            @"output without a resolution report must not invent one");
        NSString *duplicateGraphics = @"[graphics]\n graphics-quality = high \ncustom=keep\n[graphics]\n[interface]\ncustom-ui-scale=1.25\n";
        NSCAssert(!FactorioConfigSectionContainsBinding(duplicateGraphics, @"[graphics]", @"graphics-quality=medium"),
            @"verification must reject a stale value or a missing value in a duplicate graphics section");
        NSString *graphicsDump = FactorioConfigSectionDump(duplicateGraphics, @"[graphics]");
        NSCAssert([graphicsDump containsString:@"graphics-quality = high"] &&
            ![graphicsDump containsString:@"[interface]"],
            @"diagnostic dumps must include every graphics section and no unrelated section");
        NSString *repairedGraphics = FactorioSetConfigSectionBinding(duplicateGraphics,
            @"[graphics]", @"graphics-quality=medium");
        NSCAssert(FactorioConfigSectionContainsBinding(repairedGraphics, @"[graphics]", @"graphics-quality=medium") &&
            ![repairedGraphics containsString:@"graphics-quality = high"] &&
            [repairedGraphics containsString:@"custom=keep"],
            @"fallback must normalize all duplicate graphics sections and preserve unrelated settings");
        NSString *newGraphics = FactorioSetConfigSectionBinding(@"[audio]\nvolume=1\n",
            @"[graphics]", @"graphics-quality=medium");
        NSCAssert(FactorioConfigSectionContainsBinding(newGraphics, @"[graphics]", @"graphics-quality=medium"),
            @"fallback must create a missing graphics section");
        for (NSString *graphics in @[
            @"[graphics]\ntexture-compression-level=high-quality\n[interface]\ncustom-ui-scale=1.25\n",
            @"[graphics]\n texture-compression-level = high-quality \nhigh-quality-animations=false\n[interface]\ncustom-ui-scale=1.25\n",
            @"[graphics]\nhigh-quality-animations=false\n[interface]\ncustom-ui-scale=1.25\n",
            @"[interface]\ncustom-ui-scale=1.25\n"
        ]) {
            NSString *safe = FactorioApplyConfigSection(graphics, @"[graphics]",
                @[@"texture-compression-level=none"], YES, YES);
            NSCAssert([safe containsString:@"texture-compression-level=none"] &&
                ![safe containsString:@"texture-compression-level=high-quality"] &&
                ![safe containsString:@"texture-compression-level = high-quality"],
                @"unsupported GPUs must disable compression in existing and new configurations");
            NSCAssert([safe containsString:@"custom-ui-scale=1.25"], @"the GPU fallback must preserve unrelated preferences");
            NSCAssert([FactorioApplyConfigSection(safe, @"[graphics]",
                @[@"texture-compression-level=none"], YES, YES) isEqualToString:safe], @"the fallback must survive repeated launches");
        }
        NSArray<NSString *> *examples = @[
            @"[path]\nread-data=/old\nwrite-data=/old-write\n[graphics]\nquality=high\n",
            @"[path]\n read-data = /old \n[graphics]\nquality=high\n",
            @"[graphics]\nquality=high\n",
            @"[graphics]\nquality=high\n[path]\n"
        ];
        for (NSString *example in examples) {
            NSString *updated = FactorioUpdateConfigPaths(example, @"/new/read", @"/new/write");
            NSCAssert([updated containsString:@"read-data=/new/read"], @"read-data must move with the app");
            NSCAssert([updated containsString:@"write-data=/new/write"], @"write-data must move with the sandbox");
            NSCAssert([updated containsString:@"quality=high"], @"game configuration must survive");
            NSCAssert(![updated containsString:@"/old"], @"obsolete paths must be removed");
            NSCAssert([FactorioUpdateConfigPaths(updated, @"/new/read", @"/new/write") isEqualToString:updated],
                @"repeated launches must not change the configuration");
        }
        puts("Factorio configuration tests passed.");
    }
    return 0;
}
