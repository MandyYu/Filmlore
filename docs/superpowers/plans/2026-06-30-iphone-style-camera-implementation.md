# iPhone Style Camera Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a first-pass iOS camera app matching the approved iPhone-style layout with right-side vertical style switching and testable style rendering logic.

**Architecture:** Use a Swift package for core style logic and a SwiftUI iOS app source tree for UI/camera integration. Core logic is verified with `swift test`; Xcode project build is deferred until full Xcode is selected.

**Tech Stack:** Swift 6, SwiftUI, AVFoundation, Core Image, Photos, XCTest.

---

### Task 1: Core Package And Tests

**Files:**
- Create: `Package.swift`
- Create: `Sources/StyleCameraCore/StyleParams.swift`
- Create: `Sources/StyleCameraCore/StylePreset.swift`
- Create: `Sources/StyleCameraCore/BuiltInPresets.swift`
- Create: `Sources/StyleCameraCore/StyleSelectionModel.swift`
- Create: `Sources/StyleCameraCore/StyleRenderer.swift`
- Create: `Tests/StyleCameraCoreTests/StyleCameraCoreTests.swift`

- [ ] Write tests for built-in presets, style selection, and renderer smoke behavior.
- [ ] Run `swift test` and confirm the tests fail because files are missing.
- [ ] Add minimal core implementation.
- [ ] Run `swift test` and confirm tests pass.

### Task 2: SwiftUI App Shell

**Files:**
- Create: `StyleCameraApp/StyleCameraApp.swift`
- Create: `StyleCameraApp/Views/CameraView.swift`
- Create: `StyleCameraApp/Views/CameraPreviewView.swift`
- Create: `StyleCameraApp/Views/CameraControlsView.swift`
- Create: `StyleCameraApp/Views/VerticalStyleSelectorView.swift`
- Create: `StyleCameraApp/Views/StyleEditorView.swift`
- Create: `StyleCameraApp/ViewModels/CameraViewModel.swift`

- [ ] Add app entry point.
- [ ] Add camera screen with large live preview, right vertical style selector, bottom lens row, shutter, recent photo, mode selector, and flip button.
- [ ] Bind selected style through `StyleSelectionModel`.
- [ ] Add style editor sheet opened by long-press.

### Task 3: Camera, Photo Saving, And Watermark Services

**Files:**
- Create: `StyleCameraApp/Services/CameraEngine.swift`
- Create: `StyleCameraApp/Services/PhotoLibraryService.swift`
- Create: `StyleCameraApp/Services/WatermarkRenderer.swift`
- Create: `StyleCameraApp/Info.plist`

- [ ] Implement camera authorization and `AVCaptureSession` setup.
- [ ] Emit preview frames as `CIImage`.
- [ ] Capture high-quality photos through `AVCapturePhotoOutput`.
- [ ] Render style and optional watermark before saving through PhotoKit.
- [ ] Add camera/photo usage descriptions.

### Task 4: Local Xcode Project Metadata

**Files:**
- Create: `StyleCamera.xcodeproj/project.pbxproj`
- Create: `README.md`

- [ ] Create a minimal iOS Xcode project that references `StyleCameraApp` and `StyleCameraCore`.
- [ ] Document how to open, build, and run the app.
- [ ] Document the current verification limitation when only Command Line Tools are selected.

### Verification

- [ ] Run `swift test`.
- [ ] Attempt `xcodebuild -version`; if it reports Command Line Tools only, document that full app build needs `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`.
