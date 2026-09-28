#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

#import <dispatch/dispatch.h>
#import <dlfcn.h>
#import <stdint.h>
#import <string.h>
#import <sys/types.h>


// ============================================================
// Minimal macOS CoreAudio HAL ABI required by SDL.
// The iPhoneOS SDK does not provide CoreAudio/CoreAudio.h.
// ============================================================

#define FP_FOURCC(a, b, c, d) \
    ((UInt32)( \
        ((UInt32)(uint8_t)(a) << 24) | \
        ((UInt32)(uint8_t)(b) << 16) | \
        ((UInt32)(uint8_t)(c) <<  8) | \
        ((UInt32)(uint8_t)(d)      ) \
    ))


typedef UInt32 FPAudioObjectID;
typedef UInt32 FPAudioDeviceID;

typedef UInt32 FPAudioObjectPropertySelector;
typedef UInt32 FPAudioObjectPropertyScope;
typedef UInt32 FPAudioObjectPropertyElement;


typedef struct {
    FPAudioObjectPropertySelector mSelector;
    FPAudioObjectPropertyScope    mScope;
    FPAudioObjectPropertyElement  mElement;
} FPAudioObjectPropertyAddress;


typedef OSStatus (*FPAudioObjectPropertyListenerProc)(
    FPAudioObjectID inObjectID,
    UInt32 inNumberAddresses,
    const FPAudioObjectPropertyAddress *inAddresses,
    void *inClientData
);


// ============================================================
// CoreAudio HAL constants from macOS.
// ============================================================

enum {
    FP_kAudioObjectSystemObject = 1,

    FP_kAudioHardwarePropertyDevices =
        FP_FOURCC('d', 'e', 'v', '#'),

    FP_kAudioHardwarePropertyDefaultInputDevice =
        FP_FOURCC('d', 'I', 'n', ' '),

    FP_kAudioHardwarePropertyDefaultOutputDevice =
        FP_FOURCC('d', 'O', 'u', 't'),

    FP_kAudioDevicePropertyStreamConfiguration =
        FP_FOURCC('s', 'l', 'a', 'y'),

    FP_kAudioDevicePropertyNominalSampleRate =
        FP_FOURCC('n', 's', 'r', 't'),

    FP_kAudioDevicePropertyDeviceUID =
        FP_FOURCC('u', 'i', 'd', ' '),

    FP_kAudioDevicePropertyDeviceIsAlive =
        FP_FOURCC('l', 'i', 'v', 'n'),

    FP_kAudioDevicePropertyHogMode =
        FP_FOURCC('o', 'i', 'n', 'k'),

    FP_kAudioObjectPropertyName =
        FP_FOURCC('l', 'n', 'a', 'm'),

    FP_kAudioObjectPropertyScopeGlobal =
        FP_FOURCC('g', 'l', 'o', 'b'),

    FP_kAudioDevicePropertyScopeInput =
        FP_FOURCC('i', 'n', 'p', 't'),

    FP_kAudioDevicePropertyScopeOutput =
        FP_FOURCC('o', 'u', 't', 'p'),

    // AudioQueue property used by macOS SDL.
    FP_kAudioQueueProperty_CurrentDevice =
        FP_FOURCC('a', 'q', 'c', 'd')
};


static const OSStatus FP_NO_ERR = 0;
static const OSStatus FP_PARAM_ERR = -50;


// Our single virtual HAL device.
static const FPAudioDeviceID FP_AUDIO_DEVICE = 0xFA17;


// ============================================================
// Helpers
// ============================================================

static BOOL FPWrite(
    void *destination,
    UInt32 *ioSize,
    const void *source,
    UInt32 sourceSize
) {
    if (!destination ||
        !ioSize ||
        !source ||
        *ioSize < sourceSize) {

        return NO;
    }

    memcpy(
        destination,
        source,
        sourceSize
    );

    *ioSize = sourceSize;

    return YES;
}


// ============================================================
// Fake macOS AudioObject HAL
// ============================================================
//
// The macOS SDL build tries to enumerate CoreAudio HAL devices.
// We do not start HALS/IOKit on iOS.
//
// Instead, we emulate one device:
//
//   ID:       0xFA17
//   name:     iPad Audio
//   output:   stereo
//   rate:     48000 Hz
//
// Audio capture is not needed.
// ============================================================


OSStatus AudioObjectAddPropertyListener(
    FPAudioObjectID objectID,
    const FPAudioObjectPropertyAddress *address,
    FPAudioObjectPropertyListenerProc listener,
    void *clientData
) {
    (void)objectID;
    (void)address;
    (void)listener;
    (void)clientData;

    // Do not start the real desktop HAL.
    return FP_NO_ERR;
}


OSStatus AudioObjectRemovePropertyListener(
    FPAudioObjectID objectID,
    const FPAudioObjectPropertyAddress *address,
    FPAudioObjectPropertyListenerProc listener,
    void *clientData
) {
    (void)objectID;
    (void)address;
    (void)listener;
    (void)clientData;

    return FP_NO_ERR;
}


OSStatus AudioObjectGetPropertyDataSize(
    FPAudioObjectID objectID,
    const FPAudioObjectPropertyAddress *address,
    UInt32 qualifierDataSize,
    const void *qualifierData,
    UInt32 *outDataSize
) {
    (void)qualifierDataSize;
    (void)qualifierData;

    if (!address || !outDataSize) {
        return FP_PARAM_ERR;
    }


    // --------------------------------------------------------
    // System device list.
    // --------------------------------------------------------

    if (objectID == FP_kAudioObjectSystemObject &&
        address->mSelector ==
            FP_kAudioHardwarePropertyDevices) {

        *outDataSize =
            (UInt32)sizeof(FPAudioDeviceID);

        return FP_NO_ERR;
    }


    // --------------------------------------------------------
    // SDL first requests the size of AudioBufferList.
    // One device, one buffer.
    // --------------------------------------------------------

    if (objectID == FP_AUDIO_DEVICE &&
        address->mSelector ==
            FP_kAudioDevicePropertyStreamConfiguration) {

        *outDataSize =
            (UInt32)sizeof(AudioBufferList);

        return FP_NO_ERR;
    }


    return FP_PARAM_ERR;
}


OSStatus AudioObjectGetPropertyData(
    FPAudioObjectID objectID,
    const FPAudioObjectPropertyAddress *address,
    UInt32 qualifierDataSize,
    const void *qualifierData,
    UInt32 *ioDataSize,
    void *outData
) {
    (void)qualifierDataSize;
    (void)qualifierData;

    if (!address ||
        !ioDataSize ||
        !outData) {

        return FP_PARAM_ERR;
    }


    // ========================================================
    // System object
    // ========================================================

    if (objectID == FP_kAudioObjectSystemObject) {

        // ----------------------------------------------------
        // Device list.
        // ----------------------------------------------------

        if (address->mSelector ==
            FP_kAudioHardwarePropertyDevices) {

            FPAudioDeviceID device =
                FP_AUDIO_DEVICE;

            return FPWrite(
                outData,
                ioDataSize,
                &device,
                (UInt32)sizeof(device)
            )
            ? FP_NO_ERR
            : FP_PARAM_ERR;
        }


        // ----------------------------------------------------
        // Default output.
        // ----------------------------------------------------

        if (address->mSelector ==
            FP_kAudioHardwarePropertyDefaultOutputDevice) {

            FPAudioDeviceID device =
                FP_AUDIO_DEVICE;

            return FPWrite(
                outData,
                ioDataSize,
                &device,
                (UInt32)sizeof(device)
            )
            ? FP_NO_ERR
            : FP_PARAM_ERR;
        }


        // ----------------------------------------------------
        // Default input.
        //
        // Return the same virtual device. Its input has zero channels,
        // so SDL does not add it as a capture device.
        // ----------------------------------------------------

        if (address->mSelector ==
            FP_kAudioHardwarePropertyDefaultInputDevice) {

            FPAudioDeviceID device =
                FP_AUDIO_DEVICE;

            return FPWrite(
                outData,
                ioDataSize,
                &device,
                (UInt32)sizeof(device)
            )
            ? FP_NO_ERR
            : FP_PARAM_ERR;
        }


        return FP_PARAM_ERR;
    }


    // ========================================================
    // Fake device
    // ========================================================

    if (objectID != FP_AUDIO_DEVICE) {
        return FP_PARAM_ERR;
    }


    switch (address->mSelector) {

        // ----------------------------------------------------
        // Audio channels.
        //
        // SDL calls this separately for the input and output scopes.
        // ----------------------------------------------------

        case FP_kAudioDevicePropertyStreamConfiguration: {

            AudioBufferList list;
            memset(
                &list,
                0,
                sizeof(list)
            );

            list.mNumberBuffers = 1;

            if (address->mScope ==
                FP_kAudioDevicePropertyScopeInput) {

                // Do not expose a microphone.
                list.mBuffers[0].mNumberChannels = 0;

            } else {

                // Stereo playback.
                list.mBuffers[0].mNumberChannels = 2;
            }

            list.mBuffers[0].mDataByteSize = 0;
            list.mBuffers[0].mData = NULL;

            return FPWrite(
                outData,
                ioDataSize,
                &list,
                (UInt32)sizeof(list)
            )
            ? FP_NO_ERR
            : FP_PARAM_ERR;
        }


        // ----------------------------------------------------
        // Sample rate.
        // ----------------------------------------------------

        case FP_kAudioDevicePropertyNominalSampleRate: {

            Float64 sampleRate = 48000.0;

            return FPWrite(
                outData,
                ioDataSize,
                &sampleRate,
                (UInt32)sizeof(sampleRate)
            )
            ? FP_NO_ERR
            : FP_PARAM_ERR;
        }


        // ----------------------------------------------------
        // Device name.
        // ----------------------------------------------------

        case FP_kAudioObjectPropertyName: {

            CFStringRef name =
                CFSTR("iPad Audio");

            return FPWrite(
                outData,
                ioDataSize,
                &name,
                (UInt32)sizeof(name)
            )
            ? FP_NO_ERR
            : FP_PARAM_ERR;
        }


        // ----------------------------------------------------
        // Device alive.
        // ----------------------------------------------------

        case FP_kAudioDevicePropertyDeviceIsAlive: {

            UInt32 alive = 1;

            return FPWrite(
                outData,
                ioDataSize,
                &alive,
                (UInt32)sizeof(alive)
            )
            ? FP_NO_ERR
            : FP_PARAM_ERR;
        }


        // ----------------------------------------------------
        // Hog mode.
        //
        // -1 means that no process has exclusive ownership.
        // ----------------------------------------------------

        case FP_kAudioDevicePropertyHogMode: {

            pid_t pid = -1;

            return FPWrite(
                outData,
                ioDataSize,
                &pid,
                (UInt32)sizeof(pid)
            )
            ? FP_NO_ERR
            : FP_PARAM_ERR;
        }


        // ----------------------------------------------------
        // UID used shortly afterward by
        // AudioQueueSetProperty(CurrentDevice).
        // ----------------------------------------------------

        case FP_kAudioDevicePropertyDeviceUID: {

            CFStringRef uid =
                CFSTR("FactorioPad-iOS-Audio");

            return FPWrite(
                outData,
                ioDataSize,
                &uid,
                (UInt32)sizeof(uid)
            )
            ? FP_NO_ERR
            : FP_PARAM_ERR;
        }


        default:
            return FP_PARAM_ERR;
    }
}


// ============================================================
// AudioQueue bridge
// ============================================================
//
// macOS SDL calls this after AudioQueueNewOutput():
//
//   AudioQueueSetProperty(
//       queue,
//       kAudioQueueProperty_CurrentDevice,
//       ...
//   )
//
// This selects a specific macOS HAL device.
//
// AVAudioSession selects the route on iOS, so we ignore this property.
//
// Forward all other properties, such as ChannelLayout,
// to the real AudioToolbox.
// ============================================================


typedef OSStatus (*FPAudioQueueSetPropertyFn)(
    AudioQueueRef inAQ,
    AudioQueuePropertyID inID,
    const void *inData,
    UInt32 inDataSize
);


static FPAudioQueueSetPropertyFn
FPRealAudioQueueSetProperty(void)
{
    static FPAudioQueueSetPropertyFn function = NULL;
    static dispatch_once_t onceToken;

    dispatch_once(
        &onceToken,
        ^{
            function =
                (FPAudioQueueSetPropertyFn)
                dlsym(
                    RTLD_NEXT,
                    "AudioQueueSetProperty"
                );

            if (!function) {
                NSLog(
                    @"[FactorioCompat] real AudioQueueSetProperty not found: %s",
                    dlerror() ?: "<unknown>"
                );
            }
        }
    );

    return function;
}


OSStatus AudioQueueSetProperty(
    AudioQueueRef inAQ,
    AudioQueuePropertyID inID,
    const void *inData,
    UInt32 inDataSize
) {
    // --------------------------------------------------------
    // The desktop CurrentDevice property does not apply on iOS.
    // --------------------------------------------------------

    if ((UInt32)inID ==
        FP_kAudioQueueProperty_CurrentDevice) {

        return FP_NO_ERR;
    }


    // --------------------------------------------------------
    // Forward everything else to the real AudioToolbox.
    // --------------------------------------------------------

    FPAudioQueueSetPropertyFn realFunction =
        FPRealAudioQueueSetProperty();

    if (!realFunction) {
        return FP_PARAM_ERR;
    }

    return realFunction(
        inAQ,
        inID,
        inData,
        inDataSize
    );
}
