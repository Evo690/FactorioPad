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
        NSCAssert([FactorioConfigGraphicsQuality(@"low") isEqualToString:@"medium"] &&
            [FactorioConfigGraphicsQuality(@"normal") isEqualToString:@"medium"] &&
            [FactorioConfigGraphicsQuality(@"high") isEqualToString:@"high"],
            @"Factorio 2.0 only accepts graphics-quality=medium or high");
        NSCAssert([FactorioGraphicsPresetName(@"low") isEqualToString:@"very-low"] &&
            [FactorioGraphicsPresetName(@"normal") isEqualToString:@"mac-with-low-ram"] &&
            [FactorioGraphicsPresetName(@"high") isEqualToString:@"high"],
            @"Apple GPUs must not keep the auto-detected high graphics preset");
        NSString *lowPreset = FactorioApplyConfigSection(@"[graphics]\ngraphics-quality=high\nhigh-quality-animations=true\n",
            @"[graphics]", FactorioGraphicsSettingsForQuality(@"low", YES), YES, YES);
        NSCAssert(FactorioConfigSectionContainsBinding(lowPreset, @"[graphics]", @"graphics-quality=medium") &&
            ![lowPreset containsString:@"graphics-quality=high"] &&
            ![lowPreset containsString:@"graphics-quality=low"] &&
            [lowPreset containsString:@"high-quality-animations=false"] &&
            [lowPreset containsString:@"max-texture-size=4096"] &&
            [lowPreset containsString:@"video-memory-usage=low"] &&
            [lowPreset containsString:@"skip-vram-detection=true"],
            @"selecting low must replace stale graphics settings with Factorio 2.0 medium sprites");
        NSString *normalPreset = FactorioApplyConfigSection(@"[graphics]\ngraphics-quality=low\n",
            @"[graphics]", FactorioGraphicsSettingsForQuality(@"normal", NO), YES, YES);
        NSCAssert(FactorioConfigSectionContainsBinding(normalPreset, @"[graphics]", @"graphics-quality=medium") &&
            ![normalPreset containsString:@"graphics-quality=low"] &&
            ![normalPreset containsString:@"graphics-quality=normal"] &&
            [normalPreset containsString:@"texture-compression-level=none"] &&
            [normalPreset containsString:@"video-memory-usage=medium"],
            @"selecting normal must not write Factorio 2.0-invalid graphics-quality=normal");
        NSArray<NSString *> *lowLaunch = FactorioMainArguments(@"/config.ini", @"/mods", @"844x390", @"low");
        NSUInteger lowQualityIndex = [lowLaunch indexOfObject:@"--graphics-quality"];
        NSUInteger lowPresetIndex = [lowLaunch indexOfObject:@"--force-graphics-preset"];
        NSUInteger lowVramIndex = [lowLaunch indexOfObject:@"--video-memory-usage"];
        NSCAssert(lowQualityIndex != NSNotFound && [lowLaunch[lowQualityIndex + 1] isEqualToString:@"medium"] &&
            lowPresetIndex != NSNotFound && [lowLaunch[lowPresetIndex + 1] isEqualToString:@"very-low"] &&
            lowVramIndex != NSNotFound && [lowLaunch[lowVramIndex + 1] isEqualToString:@"low"] &&
            [lowLaunch containsObject:@"--low-vram"] &&
            [[lowLaunch componentsJoinedByString:@" "] containsString:@"--window-size 844x390"],
            @"low must launch Factorio with medium sprites and the very-low preset");
        NSArray<NSString *> *highLaunch = FactorioMainArguments(@"/config.ini", @"/mods", @"1024x768", @"high");
        NSUInteger highQualityIndex = [highLaunch indexOfObject:@"--graphics-quality"];
        NSCAssert(highQualityIndex != NSNotFound && [highLaunch[highQualityIndex + 1] isEqualToString:@"high"] &&
            ![highLaunch containsObject:@"--low-vram"],
            @"high must keep Factorio graphics-quality=high");
        NSString *duplicateGraphics = @"[graphics]\n graphics-quality = high \ncustom=keep\n[graphics]\n[interface]\ncustom-ui-scale=1.25\n";
        NSCAssert(!FactorioConfigSectionContainsBinding(duplicateGraphics, @"[graphics]", @"graphics-quality=low"),
            @"verification must reject a stale value or a missing value in a duplicate graphics section");
        NSString *graphicsDump = FactorioConfigSectionDump(duplicateGraphics, @"[graphics]");
        NSCAssert([graphicsDump containsString:@"graphics-quality = high"] &&
            ![graphicsDump containsString:@"[interface]"],
            @"diagnostic dumps must include every graphics section and no unrelated section");
        NSString *repairedGraphics = FactorioSetConfigSectionBinding(duplicateGraphics,
            @"[graphics]", @"graphics-quality=low");
        NSCAssert(FactorioConfigSectionContainsBinding(repairedGraphics, @"[graphics]", @"graphics-quality=low") &&
            ![repairedGraphics containsString:@"graphics-quality = high"] &&
            [repairedGraphics containsString:@"custom=keep"],
            @"fallback must normalize all duplicate graphics sections and preserve unrelated settings");
        NSString *newGraphics = FactorioSetConfigSectionBinding(@"[audio]\nvolume=1\n",
            @"[graphics]", @"graphics-quality=low");
        NSCAssert(FactorioConfigSectionContainsBinding(newGraphics, @"[graphics]", @"graphics-quality=low"),
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
