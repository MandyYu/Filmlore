# AI Photo Guidance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first local AI photo guidance assistant plus simple style-specific guidance.

**Architecture:** Put pure rule logic and settings in `StyleCameraCore`, then connect live preview metrics and device roll in the iOS app. Keep the UI as a lightweight overlay and settings section.

**Tech Stack:** Swift 6, SwiftUI, AVFoundation, Core Image, Vision, Core Motion, StyleCameraCoreChecks.

---

### Task 1: Core Guidance Models And Rules

**Files:**
- Create: `Sources/StyleCameraCore/PhotoGuidance.swift`
- Modify: `Sources/StyleCameraCoreChecks/main.swift`

- [ ] Add failing checks for guidance settings and rule output.
- [ ] Add pure `PhotoGuidanceSettings`, `PhotoGuidanceSceneAnalysis`, `PhotoGuidanceHint`, and `PhotoGuidanceEngine`.
- [ ] Run `swift run StyleCameraCoreChecks`.

### Task 2: Live Frame And Motion Analysis

**Files:**
- Create: `StyleCameraApp/Services/CompositionGuideAnalyzer.swift`
- Create: `StyleCameraApp/Services/MotionLevelService.swift`
- Modify: `StyleCamera.xcodeproj/project.pbxproj`

- [ ] Add a throttled Core Image/Vision analyzer for brightness, overexposure, blur, and subject rectangle.
- [ ] Add a Core Motion service that publishes roll degrees.
- [ ] Add both app files to the Xcode app target.

### Task 3: View Model Integration

**Files:**
- Modify: `StyleCameraApp/ViewModels/CameraViewModel.swift`

- [ ] Persist guidance settings in `UserDefaults`.
- [ ] Start/stop motion updates with the camera.
- [ ] Analyze preview frames at most once per second.
- [ ] Publish the current guidance hint.

### Task 4: Overlay And Settings UI

**Files:**
- Create: `StyleCameraApp/Views/PhotoGuidanceOverlayView.swift`
- Modify: `StyleCameraApp/Views/CameraView.swift`
- Modify: `StyleCamera.xcodeproj/project.pbxproj`

- [ ] Render a small camera-style hint capsule over the preview.
- [ ] Add the `AI 拍照指导` settings section.
- [ ] Add the overlay view to the Xcode app target.

### Task 5: Verification

**Files:**
- No new files.

- [ ] Run `swift run StyleCameraCoreChecks`.
- [ ] Run `xcodebuild -project StyleCamera.xcodeproj -scheme StyleCamera -configuration Debug -destination generic/platform=iOS -derivedDataPath .derivedData build`.

