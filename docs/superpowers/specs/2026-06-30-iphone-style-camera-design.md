# iPhone Style Camera Design

## Goal

Build a SwiftUI iOS camera app that feels close to the iPhone Camera app while adding real-time style previews, photo capture, style presets, custom style editing, watermarking, and imported-photo styling.

## MVP Scope

- Live camera preview with real-time Core Image style application.
- Photo capture through `AVCapturePhotoOutput`, not preview screenshots.
- Save processed photos to the system photo library.
- Built-in styles: original, food INS, cool white skin, Fuji fresh, city texture, creamy Japanese, night mood.
- Right-side vertical style selector inside the live preview. It uses the same visual language as the iPhone lens selector: dark circular controls, selected item enlarged, yellow active text, vertical swipe to switch.
- Bottom camera controls remain iPhone-like: recent photo thumbnail, shutter, video/photo mode selector, camera flip, and lens倍率 row.
- Tap to focus/expose, pinch to zoom, grid overlay, flash toggle, watermark toggle.
- Style parameter model supports exposure, brilliance, highlights, shadows, contrast, brightness, saturation, vibrance, warmth, tint, sharpness, fade, grain, and vignette.

## Architecture

- `StyleCameraCore`: testable Swift package target containing style models, built-in presets, style selection state, and Core Image rendering.
- `StyleCameraApp`: SwiftUI app target containing camera UI, AVFoundation camera engine, preview bridge, photo library saving, and watermark rendering.
- The app keeps preview rendering and full-resolution photo rendering on separate paths but uses the same `StyleParams`.

## Key UI Decisions

- The live preview stays large.
- Style selection is vertical on the right side of the preview and does not displace bottom camera controls.
- The bottom area keeps the iPhone camera structure: lens controls above the shutter, shutter centered, recent photo left, flip right, mode selector near the bottom.
- Long-press on the active style opens style editing. Tapping the style icon opens a full style list.

## Verification

- Core style models, preset values, and selection behavior are covered by Swift unit tests.
- Core Image renderer is smoke-tested with generated CI images.
- Full iOS build requires complete Xcode, because this machine currently has Command Line Tools selected.
