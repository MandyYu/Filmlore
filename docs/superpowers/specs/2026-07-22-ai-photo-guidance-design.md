# AI Photo Guidance Design

## Goal

Add a local, real-time photo guidance assistant to the camera app. The first implementation covers practical shooting hints and a small layer of style-specific advice without sending preview images to a server.

## Scope

- Add an optional "AI 拍照指导" setting.
- Analyze live preview frames at a throttled interval.
- Show one short hint at a time over the camera preview.
- Cover first-phase guidance: brightness, overexposure, blur, subject placement, subject size, and phone level.
- Cover second-phase guidance: simple suggestions for the current style, especially food, cool-white skin, Fuji, and city styles.
- Keep capture, zoom, style selector, watermark, and library behavior unchanged.

## Non-Goals

- No cloud visual model in this phase.
- No photo-upload workflow.
- No automatic camera movement or auto-cropping.
- No persistent AI history.

## Architecture

The feature is split into two layers:

- `StyleCameraCore` owns pure guidance models and rule selection. This is easy to test through `StyleCameraCoreChecks`.
- `StyleCameraApp` owns live preview analysis, motion level detection, UI overlay, and settings persistence.

Preview frames already flow from `CameraEngine` into `CameraViewModel`. `CameraViewModel` will throttle analysis, combine frame metrics with device roll, ask the core guidance engine for the best hint, and publish that hint for `CameraView`.

## User Experience

The camera preview shows a small dark capsule near the top of the live image when guidance has something useful to say. The hint fades with normal SwiftUI transitions and avoids showing disabled categories.

Settings gains a section named `AI 拍照指导`:

- Enable/disable guidance.
- Hint intensity: quiet, standard, active.
- Toggles for composition, angle, light, sharpness, and style suggestions.

## Guidance Priority

The guidance engine returns only one hint:

1. Critical light issue.
2. Obvious blur.
3. Phone not level.
4. Subject placement or size issue.
5. Style-specific suggestion.

The intensity setting controls thresholds. Quiet mode waits for stronger issues. Active mode speaks earlier.

## Testing

`StyleCameraCoreChecks` verifies:

- Default settings are enabled and include all guidance categories.
- Disabled guidance returns no hints.
- Too-dark and overexposed frames produce light hints.
- Blurry frames produce a sharpness hint.
- Large roll produces an angle hint.
- Off-center or too-small subjects produce composition hints.
- Food, city, Fuji, and cool-white styles can produce style-specific hints.

