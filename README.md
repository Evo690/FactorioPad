# FactorioPad

Play Factorio on iPhone and iPad with a gamepad.

> [!IMPORTANT]
> FactorioPad does not include the game. Download the Mac version from [factorio.com](https://factorio.com/download), not Steam.

## What you need

- A Mac with Xcode 27.
- An iPhone or iPad with iOS 27 or iPadOS 27.
- A gamepad.
- `factorio.app` in `/Applications` on the Mac.

FactorioPad was tested with Factorio 2.0.77 on an iPad mini (7th generation) and an iPhone 15 Pro. Other game versions are untested.

## What changes on iPhone and iPad

- A gamepad acts as a mouse and keyboard. The right stick moves the mouse pointer.
- Touch supports menu taps and drags, but not touch-only gameplay.
- New installations change Factorio key bindings for gamepad controls.
- New installations use a 150% interface scale and one visible quickbar.
- The on-screen keyboard lets you type names and passwords. Hold the keyboard button to see the gamepad controls.

## Build an IPA

An IPA is an app file for your iPhone or iPad. Open Terminal in the FactorioPad project folder.
Run this command:

```sh
bash Tools/build_ipa.sh
```

The IPA appears at `dist/FactorioPad.ipa`. Move it to your device through Files or iCloud Drive.
Install it with [AltStore Classic](https://faq.altstore.io/altstore-classic/altserver) or [SideStore](https://docs.sidestore.io/docs/installation/prerequisites).
With a free Apple Account, refresh the installed app within seven days. You do not need to rebuild the IPA each week.

> [!NOTE]
> Keep the IPA private because it contains your copy of Factorio. The [MIT license](LICENSE) covers only the FactorioPad source code.

## Run from Xcode

1. Open Terminal in the FactorioPad project folder.
2. Run `bash Tools/build_ipa.sh --prepare-only` to prepare your game files.
3. Open `FactorioPad.xcodeproj` in Xcode.
4. Connect your iPhone or iPad to your Mac.
5. Select your device in Xcode.
6. In Signing & Capabilities, select your Apple team.
7. Set a unique Bundle Identifier, such as `com.yourname.FactorioPad`.
8. Press Run.

## Limitations

- Physical keyboards and mice are not supported for now.
- Not every keyboard key is available on the gamepad. Tab is not mapped.
