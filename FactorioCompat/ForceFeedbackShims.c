#include <stdint.h>

#define EXPORT \
    __attribute__((visibility("default"))) \
    __attribute__((used))

#define FF_STUB(name) \
    EXPORT int32_t name(void) { return -1; }


FF_STUB(FFCreateDevice)
FF_STUB(FFDeviceCreateEffect)
FF_STUB(FFDeviceGetForceFeedbackCapabilities)
FF_STUB(FFDeviceGetForceFeedbackProperty)
FF_STUB(FFDeviceReleaseEffect)
FF_STUB(FFDeviceSendForceFeedbackCommand)
FF_STUB(FFDeviceSetForceFeedbackProperty)
FF_STUB(FFEffectGetEffectStatus)
FF_STUB(FFEffectSetParameters)
FF_STUB(FFEffectStart)
FF_STUB(FFEffectStop)
FF_STUB(FFIsForceFeedback)
FF_STUB(FFReleaseDevice)
