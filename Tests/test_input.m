#include "../FactorioCompat/FactorioKeyboardBridge.m"
#include "../FactorioCompat/FactorioControllerBridge.m"

// Capture only the SDL boundary. The controller and input bridge are production code.
static NSMutableArray<NSData *> *events;
static uint16_t sdlModifiers;
static int window;

int SDL_PushEvent(FPSDLEvent *event)
{
    [events addObject:[NSData dataWithBytes:event length:sizeof(*event)]];
    return 1;
}
void *SDL_GetKeyboardFocus(void) { return &window; }
uint32_t SDL_GetWindowID(void *value) { NSCAssert(value == &window, @"window must match"); return 77; }
uint32_t SDL_GetTicks(void) { return 42; }
void SDL_SetModState(uint16_t modifiers) { sdlModifiers = modifiers; }
int SDL_SendKeyboardKey(uint8_t state, int32_t scancode)
{
    uint16_t modifier = scancode == 224 ? FP_MOD_LCTRL : scancode == 225 ? FP_MOD_LSHIFT : scancode == 227 ? FP_MOD_LGUI : 0;
    if (state) sdlModifiers |= modifier; else sdlModifiers &= ~modifier;
    FPSDLEvent event = {0};
    event.key.type = state ? FP_SDL_KEYDOWN : FP_SDL_KEYUP;
    event.key.windowID = 77;
    event.key.timestamp = 42;
    event.key.state = state;
    event.key.keysym.scancode = scancode;
    event.key.keysym.mod = sdlModifiers;
    return SDL_PushEvent(&event);
}

int main(void)
{
    @autoreleasepool {
        events = [NSMutableArray array];
        void *fixture = dlopen(NULL, RTLD_NOW);
        NSCAssert(FactorioKeyboardBridgeSetGuestHandle(fixture), @"all SDL functions must resolve through dlsym");
        gControllerQueue = dispatch_queue_create("FactorioPad.InputTest", DISPATCH_QUEUE_SERIAL);
        GCController *controller = [GCController controllerWithExtendedGamepad];
        FPInstallController(controller);
        GCExtendedGamepad *pad = controller.extendedGamepad;
        dispatch_sync(gControllerQueue, ^{
            pad.rightShoulder.pressedChangedHandler(pad.rightShoulder, 1, YES);
            [events removeAllObjects];
            pad.dpad.up.pressedChangedHandler(pad.dpad.up, 1, YES);
            pad.dpad.up.pressedChangedHandler(pad.dpad.up, 0, NO);
            NSCAssert(events.count == 7, @"filter must send six shortcut events and release the number");
            FPSDLEvent click;
            [events[2] getBytes:&click length:sizeof(click)];
            NSCAssert(click.type == FP_SDL_MOUSEBUTTONDOWN && click.button.button == FP_MOUSE_RIGHT &&
                click.button.windowID == 77 && click.button.timestamp == 42 &&
                click.button.x == llround(gCursorX) && click.button.y == llround(gCursorY),
                @"controller clicks must reach the real bridge with correct SDL fields");
            [events removeAllObjects];
            pad.dpad.right.pressedChangedHandler(pad.dpad.right, 1, YES);
            FPSDLEvent weapon;
            [events[0] getBytes:&weapon length:sizeof(weapon)];
            NSCAssert(weapon.key.keysym.scancode == FP_SC_C && weapon.key.keysym.mod == 0 &&
                sdlModifiers == FP_MOD_LCTRL, @"next weapon must restore the held shoulder");
        });

        [events removeAllObjects];
        dispatch_group_t group = dispatch_group_create();
        dispatch_group_async(group, gControllerQueue, ^{
            @autoreleasepool {
                for (int index = 0; index < 1000; index++) {
                    pad.dpad.up.pressedChangedHandler(pad.dpad.up, 1, YES);
                    pad.dpad.up.pressedChangedHandler(pad.dpad.up, 0, NO);
                }
            }
        });
        dispatch_group_async(group, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            @autoreleasepool {
                for (int index = 0; index < 1000; index++) {
                    FactorioKeyboardInsertText(@"Factory é");
                    FactorioKeyboardBackspace();
                    FactorioKeyboardReturn();
                }
            }
        });
        NSCAssert(dispatch_group_wait(group, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC)) == 0,
            @"concurrent input must finish without a deadlock");
        BOOL commandHeld = NO;
        NSUInteger textCount = 0, clickCount = 0;
        for (NSUInteger index = 0; index < events.count; index++) {
            FPSDLEvent event;
            [events[index] getBytes:&event length:sizeof(event)];
            if (event.type == FP_SDL_KEYDOWN && event.key.keysym.scancode == FP_SC_LGUI) commandHeld = YES;
            if (event.type == FP_SDL_KEYUP && event.key.keysym.scancode == FP_SC_LGUI) commandHeld = NO;
            if (event.type == FP_SDL_MOUSEBUTTONDOWN) {
                NSCAssert(commandHeld, @"filter clicks must stay inside their Command transaction");
                clickCount++;
            }
            if (event.type == FP_SDL_TEXTINPUT) {
                NSCAssert(!commandHeld && strcmp(event.text.text, "Factory é") == 0,
                    @"text must not interrupt a controller shortcut or become corrupted");
                textCount++;
            }
            if (event.type == FP_SDL_KEYDOWN &&
                (event.key.keysym.scancode == 40 || event.key.keysym.scancode == 42)) {
                NSCAssert(!commandHeld && index + 1 < events.count, @"typing keys must stay outside shortcuts");
                FPSDLEvent release;
                [events[index + 1] getBytes:&release length:sizeof(release)];
                NSCAssert(release.type == FP_SDL_KEYUP && release.key.keysym.scancode == event.key.keysym.scancode,
                    @"a typing key press and release must not be interleaved");
            }
        }
        NSCAssert(!commandHeld && textCount == 1000 && clickCount == 1000, @"no concurrent input may be lost");
        dispatch_sync(gControllerQueue, ^{ FPReleaseEverything(); });
        FactorioInputPerform(^{ NSCAssert(gSyntheticModifiers == 0 && gSyntheticMouseButtons == 0,
            @"suspension must leave no held modifiers or mouse buttons"); });
        NSUInteger previousCount = events.count;
        FactorioMouseButton(0, YES, 0, 0);
        FactorioMouseButton(33, YES, 0, 0);
        NSCAssert(events.count == previousCount && gSyntheticMouseButtons == 0, @"invalid button numbers must be rejected");
        void *incompatible = dlopen("/usr/lib/libSystem.B.dylib", RTLD_NOW | RTLD_LOCAL);
        NSCAssert(incompatible && !FactorioKeyboardBridgeSetGuestHandle(incompatible),
            @"an incompatible guest must fail initialization");
        previousCount = events.count;
        FactorioKeyboardReturn();
        FactorioMouseButton(0, YES, 0, 0);
        NSCAssert(events.count == previousCount && !gPushEvent && !gSendKeyboardKey,
            @"failed initialization must disable the bridge");
        dlclose(incompatible);
        dlclose(fixture);
        puts("Factorio input integration tests passed.");
    }
    return 0;
}
