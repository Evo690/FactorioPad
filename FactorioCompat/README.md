# FactorioCompat

This folder builds the framework that lets Factorio use iOS functions in place of Mac functions. It handles graphics, audio, touch, keyboard, mouse, and gamepad input.

`FactorioGraphicsQuality.h` holds the sprite resolution names each Factorio version accepts, the settings every Graphics Quality preset writes, and the device rule for high quality. The app and this framework both use it, and the sanitizer only rewrites values that would otherwise be ignored.

See the [main README](../README.md) for build and installation steps.
