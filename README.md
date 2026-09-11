# StyleCamera

An iPhone-style real-time filter camera prototype built from `iphone_style_camera_app_plan.md`.

## What Is Implemented

- SwiftUI camera shell with a large live preview.
- Bottom controls that keep the iPhone Camera layout: recent photo, shutter, video/photo mode selector, flip camera, and lens倍率 row.
- Right-side vertical style selector inside the live preview. It scrolls vertically and uses the same dark circular visual style as the lens controls.
- Core style model, built-in presets, style selection model, and Core Image style renderer.
- Four main built-in style formulas are set from the supplied reference images: `冷白皮风`, `城市质感风`, `食物 ins 风`, and `富士清新风`.
- AVFoundation camera engine with preview frames and high-quality photo capture.
- PhotoKit saving with processed style output, capture-aspect-ratio cropping, and template-specific inset/content composition.
- A SwiftPM check executable for core presets, parameter clamping, selection wrapping, and renderer extent preservation.

## Open In Xcode

Open:

```bash
open StyleCamera.xcodeproj
```

Select the `StyleCamera` scheme and run on a physical iPhone. Camera preview and saving require a real device.

## StyleCamera Pro

The app uses StoreKit 2 with one non-consumable product:

```text
com.mandy.stylecamera.pro.lifetime
```

Before distributing the app, create a non-consumable In-App Purchase with that product ID in App Store Connect, complete its localization and price, and submit it with the app version. Debug builds also expose a local Pro entitlement switch on the upgrade page so the locked UI can be tested before the App Store product is ready.

## Verification Notes

This machine currently has only Command Line Tools selected and no `/Applications/Xcode.app`:

```text
xcode-select -p
/Library/Developer/CommandLineTools
```

`xcodebuild` cannot build iOS apps in that state. The installed Command Line Tools also do not expose `XCTest` or `Testing`, so this repo includes `StyleCameraCoreChecks` as a local verification executable.

After installing full Xcode, select it:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

Then run:

```bash
swift test
swift run StyleCameraCoreChecks
xcodebuild -project StyleCamera.xcodeproj -scheme StyleCamera -destination 'generic/platform=iOS' build
```
