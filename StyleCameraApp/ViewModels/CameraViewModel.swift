import AVFoundation
import CoreImage
import CoreLocation
import ImageIO
import StyleCameraCore
import SwiftUI
import UIKit

enum CaptureMode: String, CaseIterable {
    case video
    case photo
}

enum CaptureAspectRatio: String, CaseIterable, Identifiable, Codable {
    case threeByFour
    case square
    case nineBySixteen

    var id: String { rawValue }

    var title: String {
        switch self {
        case .threeByFour: return "3:4"
        case .square: return "1:1"
        case .nineBySixteen: return "9:16"
        }
    }

    var portraitRatio: CGFloat {
        switch self {
        case .threeByFour: return 3 / 4
        case .square: return 1
        case .nineBySixteen: return 9 / 16
        }
    }

    func ratio(for imageSize: CGSize) -> CGFloat {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return portraitRatio
        }

        return imageSize.width > imageSize.height ? 1 / portraitRatio : portraitRatio
    }
}

@MainActor
final class CameraPreviewStore: ObservableObject {
    @Published private(set) var image: UIImage?

    fileprivate func publish(_ image: UIImage) {
        self.image = image
    }
}

@MainActor
final class StylePreviewStore: ObservableObject {
    @Published fileprivate(set) var images: [StylePreset.ID: UIImage] = [:]

    fileprivate func publish(_ images: [StylePreset.ID: UIImage]) {
        self.images = images
    }

    fileprivate func reset() {
        images = [:]
    }
}

private struct LivePreviewRenderResult {
    let image: UIImage
    let rawImage: UIImage?
    let guidanceHint: PhotoGuidanceHint?
}

private final class LivePreviewRenderWorker: @unchecked Sendable {
    private let renderer = StyleRenderer()
    private let guidanceAnalyzer = CompositionGuideAnalyzer()
    private let guidanceEngine = PhotoGuidanceEngine()
    private let maximumEditorPreviewDimension: CGFloat = 1_000

    func render(
        image: CIImage,
        params: StyleParams,
        styleName: String,
        guidanceSettings: PhotoGuidanceSettings,
        rollDegrees: Double,
        shouldAnalyzeGuidance: Bool,
        includeRawImage: Bool,
        screenScale: CGFloat
    ) -> LivePreviewRenderResult? {
        let output = renderer.applyStyle(to: image, params: params)
        let hint: PhotoGuidanceHint?

        if shouldAnalyzeGuidance {
            let scene = guidanceAnalyzer.analyze(image, rollDegrees: rollDegrees)
            hint = guidanceEngine.hint(
                for: scene,
                styleName: styleName,
                settings: guidanceSettings
            )
        } else {
            hint = nil
        }

        guard let cgImage = renderer.context.createCGImage(output, from: output.extent) else {
            return nil
        }

        let rawImage: UIImage?
        if includeRawImage {
            var normalizedInput = renderer.normalized(image)
            let longestSide = max(normalizedInput.extent.width, normalizedInput.extent.height)
            if longestSide > maximumEditorPreviewDimension {
                let scale = maximumEditorPreviewDimension / longestSide
                normalizedInput = normalizedInput.transformed(
                    by: CGAffineTransform(scaleX: scale, y: scale)
                )
            }

            if let rawCGImage = renderer.context.createCGImage(
                normalizedInput,
                from: normalizedInput.extent
            ) {
                rawImage = UIImage(cgImage: rawCGImage, scale: screenScale, orientation: .up)
            } else {
                rawImage = nil
            }
        } else {
            rawImage = nil
        }

        return LivePreviewRenderResult(
            image: UIImage(cgImage: cgImage, scale: screenScale, orientation: .up),
            rawImage: rawImage,
            guidanceHint: hint
        )
    }
}

private final class StylePreviewRenderWorker: @unchecked Sendable {
    private let renderer = StyleRenderer()
    private let tileSize = CGSize(width: 164, height: 124)

    func render(
        image: CIImage,
        presets: [StylePreset],
        screenScale: CGFloat
    ) -> [StylePreset.ID: UIImage] {
        guard !presets.isEmpty else { return [:] }

        let source = preparedSource(from: image)
        let tileExtent = CGRect(origin: .zero, size: tileSize)
        var atlas: CIImage?

        for (index, preset) in presets.enumerated() {
            let styled = renderer.applyStyle(to: source, params: preset.params)
                .cropped(to: tileExtent)
                .transformed(
                    by: CGAffineTransform(
                        translationX: CGFloat(index) * tileSize.width,
                        y: 0
                    )
                )
            atlas = atlas.map { styled.composited(over: $0) } ?? styled
        }

        let atlasExtent = CGRect(
            x: 0,
            y: 0,
            width: tileSize.width * CGFloat(presets.count),
            height: tileSize.height
        )
        guard let atlas,
              let atlasImage = renderer.context.createCGImage(atlas, from: atlasExtent) else {
            return [:]
        }

        var images = [StylePreset.ID: UIImage](minimumCapacity: presets.count)
        for (index, preset) in presets.enumerated() {
            let cropRect = CGRect(
                x: CGFloat(index) * tileSize.width,
                y: 0,
                width: tileSize.width,
                height: tileSize.height
            )
            guard let crop = atlasImage.cropping(to: cropRect) else { continue }
            images[preset.id] = UIImage(cgImage: crop, scale: screenScale, orientation: .up)
        }
        return images
    }

    private func preparedSource(from image: CIImage) -> CIImage {
        let normalized = renderer.normalized(image)
        let extent = normalized.extent
        guard extent.width > 0, extent.height > 0 else { return normalized }

        let scale = max(tileSize.width / extent.width, tileSize.height / extent.height)
        let scaled = normalized.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let cropRect = CGRect(
            x: scaled.extent.midX - tileSize.width / 2,
            y: scaled.extent.midY - tileSize.height / 2,
            width: tileSize.width,
            height: tileSize.height
        )
        return scaled
            .cropped(to: cropRect)
            .transformed(
                by: CGAffineTransform(
                    translationX: -cropRect.minX,
                    y: -cropRect.minY
                )
            )
    }
}

private struct CaptureRenderConfiguration: Sendable {
    let style: StylePreset
    let cameraTemplate: CameraTemplatePreset?
    let locationText: String?
    let captureAspectRatio: CaptureAspectRatio
}

private final class CapturedPhotoRenderWorker: @unchecked Sendable {
    private let renderer = StyleRenderer()
    private let watermarkRenderer = WatermarkRenderer()
    private lazy var photoFrameRenderer = PhotoFrameRenderer(context: renderer.context)

    func render(
        _ input: CIImage,
        configuration: CaptureRenderConfiguration
    ) -> CIImage {
        let croppedInput = CameraViewModel.centerCrop(
            input,
            to: configuration.captureAspectRatio
        )
        var output = renderer.applyStyle(to: croppedInput, params: configuration.style.params)
        output = renderer.normalized(output)

        guard let template = configuration.cameraTemplate else {
            return output
        }

        output = photoFrameRenderer.renderFrame(
            around: output,
            preset: template.photoFrame
        )
        return watermarkRenderer.renderTemplateWatermark(
            on: output,
            template: template,
            styleName: configuration.style.name,
            locationText: configuration.locationText
        )
    }

    func jpegData(from image: CIImage) -> Data? {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        return renderer.context.jpegRepresentation(
            of: image,
            colorSpace: colorSpace,
            options: [
                kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 0.98
            ]
        )
    }

    func thumbnail(from image: CIImage) -> UIImage? {
        let normalized = renderer.normalized(image)
        let longestSide = max(normalized.extent.width, normalized.extent.height)
        guard longestSide > 0 else { return nil }
        let scale = min(1, 512 / longestSide)
        let thumbnail = normalized.transformed(
            by: CGAffineTransform(scaleX: scale, y: scale)
        )
        guard let cgImage = renderer.context.createCGImage(thumbnail, from: thumbnail.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}

@MainActor
final class CameraViewModel: ObservableObject {
    @Published var selectedStyleName = BuiltInPresets.foodINS.name
    @Published private(set) var disabledStyleIDs = Set<StylePreset.ID>()
    @Published var flashMode: AVCaptureDevice.FlashMode = .off
    @Published var showGrid = true
    @Published var selectedTemplate: CameraTemplatePreset? {
        didSet {
            Self.saveSelectedTemplate(selectedTemplate)
            updateMotionTracking()
        }
    }
    @Published var selectedLens: CGFloat = 1
    @Published var isStyleEditorPresented = false
    @Published var isPhotoLibraryPresented = false
    @Published var isSettingsPresented = false
    @Published var lastSavedThumbnail: UIImage?
    @Published private(set) var isProcessingHighResolutionPhoto = false
    @Published var captureMode: CaptureMode = .photo
    @Published var captureAspectRatio: CaptureAspectRatio {
        didSet {
            Self.saveCaptureAspectRatio(captureAspectRatio)
        }
    }
    @Published var locationText: String?
    @Published var currentRollDegrees: Double = 0
    @Published var guidanceSettings: PhotoGuidanceSettings {
        didSet {
            Self.saveGuidanceSettings(guidanceSettings)
            if !guidanceSettings.isEnabled {
                guidanceHint = nil
            }
            updateMotionTracking()
        }
    }
    @Published var guidanceHint: PhotoGuidanceHint?

    let selection: StyleSelectionModel
    let previewStore = CameraPreviewStore()
    let rawPreviewStore = CameraPreviewStore()
    let stylePreviewStore = StylePreviewStore()

    private let cameraEngine = CameraEngine()
    private let photoLibrary = PhotoLibraryService()
    private let locationService = CameraLocationService()
    private let motionLevelService = MotionLevelService()
    private let renderQueue = DispatchQueue(label: "stylecamera.preview.render.queue")
    private let stylePreviewQueue = DispatchQueue(label: "stylecamera.style.preview.render.queue", qos: .userInitiated)
    private let livePreviewRenderWorker = LivePreviewRenderWorker()
    private let stylePreviewRenderWorker = StylePreviewRenderWorker()
    private let capturedPhotoRenderWorker = CapturedPhotoRenderWorker()
    private var lastGuidanceAnalysisAt: TimeInterval = 0
    private var lastGuidanceDisplayAt: TimeInterval = 0
    private var isStylePreviewComparisonActive = false
    private var isStyleEditorPreviewActive = false
    private var isPreviewRenderInFlight = false
    private var isStylePreviewRenderInFlight = false
    private var latestPreviewSource: CIImage?
    private var latestPreviewFrameID = 0
    private var stylePreviewRenderGeneration = 0
    private var lastGuidanceMessage: String?
    private var pendingCaptures: [UUID: CaptureRenderConfiguration] = [:]

    var selectedTemplateID: String? {
        selectedTemplate?.id
    }

    init() {
        selectedTemplate = Self.loadSelectedTemplate()
        guidanceSettings = Self.loadGuidanceSettings()
        captureAspectRatio = Self.loadCaptureAspectRatio()
        selection = StyleSelectionModel(
            presets: Self.loadConfiguredBuiltInPresets() + Self.loadCustomStylePresets(),
            selectedIndex: 1
        )
        disabledStyleIDs = Self.loadDisabledStyleIDs().intersection(selection.presets.map(\.id))
        if disabledStyleIDs.count == selection.presets.count {
            disabledStyleIDs.remove(BuiltInPresets.original.id)
        }
        if disabledStyleIDs.contains(selection.selectedPreset.id),
           let firstVisiblePreset = visibleStylePresets.first {
            selection.selectPreset(id: firstVisiblePreset.id)
        }
        selectedStyleName = selection.selectedPreset.name

        locationService.onLocationTextChange = { [weak self] text in
            Task { @MainActor in
                self?.locationText = text
            }
        }

        motionLevelService.onRollDegreesChange = { [weak self] rollDegrees in
            Task { @MainActor in
                self?.currentRollDegrees = rollDegrees
            }
        }

        cameraEngine.onPreviewFrame = { [weak self] image in
            self?.renderPreview(image)
        }

        cameraEngine.onPhotoCaptured = { [weak self] requestID, image in
            Task { @MainActor in
                self?.processCapturedPhoto(requestID: requestID, image: image)
            }
        }

        cameraEngine.onDeferredPhotoCaptured = { [weak self] requestID, proxyImage, proxyData in
            Task { @MainActor in
                self?.processDeferredPhoto(
                    requestID: requestID,
                    proxyImage: proxyImage,
                    proxyData: proxyData
                )
            }
        }

        cameraEngine.onPhotoCaptureFailed = { [weak self] requestID in
            Task { @MainActor in
                self?.finishCapture(requestID: requestID)
            }
        }
    }

    func start() {
        cameraEngine.configure()
        updateMotionTracking()
        if selectedTemplate?.usesLocation == true {
            requestTemplateLocation()
        }
    }

    func stop() {
        cameraEngine.stop()
        motionLevelService.stop()
        currentRollDegrees = 0
    }

    func capturePhoto() {
        let requestID = UUID()
        pendingCaptures[requestID] = CaptureRenderConfiguration(
            style: selection.selectedPreset,
            cameraTemplate: selectedTemplate,
            locationText: locationText,
            captureAspectRatio: captureAspectRatio
        )
        isProcessingHighResolutionPhoto = true

        // Match the native Camera interaction: acknowledge the shutter from the
        // already-rendered live frame while the full-resolution photo is processed.
        if let preview = previewStore.image {
            lastSavedThumbnail = preview
        }

        cameraEngine.capturePhoto(requestID: requestID, flashMode: flashMode)
    }

    func capturePrimaryAction() {
        switch captureMode {
        case .photo:
            capturePhoto()
        case .video:
            showTransientHint(
                PhotoGuidanceHint(
                    category: .style,
                    severity: .low,
                    message: "视频模式下一阶段接入"
                )
            )
        }
    }

    func openPhotoLibrary() {
        guard let photosURL = URL(string: "photos-redirect://") else {
            isPhotoLibraryPresented = true
            return
        }

        UIApplication.shared.open(photosURL, options: [:]) { [weak self] opened in
            guard !opened else { return }

            Task { @MainActor in
                self?.isPhotoLibraryPresented = true
            }
        }
    }

    func useLibraryImage(_ image: UIImage) {
        lastSavedThumbnail = image
    }

    func flipCamera() {
        cameraEngine.flipCamera()
    }

    func toggleFlash() {
        switch flashMode {
        case .off:
            flashMode = .auto
        case .auto:
            flashMode = .on
        case .on:
            flashMode = .off
        @unknown default:
            flashMode = .off
        }
    }

    func toggleGrid() {
        showGrid.toggle()
    }

    func applyTemplate(_ template: CameraTemplatePreset) {
        selectedTemplate = template
        if template.usesLocation {
            requestTemplateLocation()
        }
    }

    func requestTemplateLocation() {
        locationService.requestLocation()
    }

    func updateTemplateWatermarkAnchor(_ unitPoint: CGPoint) {
        guard var template = selectedTemplate else { return }
        template.watermark.position = .custom
        template.watermark.customPosition = WatermarkAnchor(
            x: Float(max(0.05, min(0.95, unitPoint.x))),
            y: Float(max(0.05, min(0.95, unitPoint.y)))
        )
        selectedTemplate = template
    }

    func focus(at unitPoint: CGPoint) {
        cameraEngine.setFocusAndExposure(at: unitPoint)
    }

    func setZoom(_ zoom: CGFloat) {
        applyZoom(zoom, animated: true)
    }

    func setZoomInteractively(_ zoom: CGFloat) {
        applyZoom(zoom, animated: false)
    }

    private func applyZoom(_ zoom: CGFloat, animated: Bool) {
        let clampedZoom = min(10, max(0.5, zoom))
        selectedLens = clampedZoom
        cameraEngine.setZoomFactor(clampedZoom, animated: animated)
    }

    func setCaptureMode(_ mode: CaptureMode) {
        captureMode = mode
    }

    func setCaptureAspectRatio(_ ratio: CaptureAspectRatio) {
        captureAspectRatio = ratio
    }

    func setStylePreviewComparisonActive(_ isActive: Bool) {
        isStylePreviewComparisonActive = isActive
        if isActive {
            startStylePreviewRenderIfNeeded()
        } else {
            stylePreviewRenderGeneration += 1
        }
    }

    func setStyleEditorPreviewActive(_ isActive: Bool) {
        isStyleEditorPreviewActive = isActive
        if isActive {
            startLivePreviewRenderIfNeeded()
        }
    }

    var visibleStylePresets: [StylePreset] {
        selection.presets.filter { !disabledStyleIDs.contains($0.id) }
    }

    func selectNextStyle() {
        selectRelativeStyle(offset: 1)
    }

    func selectPreviousStyle() {
        selectRelativeStyle(offset: -1)
    }

    func selectStyle(id: StylePreset.ID) {
        guard !disabledStyleIDs.contains(id) else { return }
        selection.selectPreset(id: id)
        selectedStyleName = selection.selectedPreset.name
    }

    func saveCustomStyle(name: String, params: StyleParams) {
        _ = createCustomStyle(name: name, params: params)
    }

    @discardableResult
    func createCustomStyle(name: String, params: StyleParams) -> StylePreset {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let preset = StylePreset(
            name: trimmedName.isEmpty ? "\(selection.selectedPreset.name) 副本" : trimmedName,
            params: params,
            isBuiltIn: false
        )
        selection.appendAndSelect(preset)
        disabledStyleIDs.remove(preset.id)
        selectedStyleName = selection.selectedPreset.name
        Self.saveCustomStylePresets(selection.presets.filter { !$0.isBuiltIn })
        Self.saveDisabledStyleIDs(disabledStyleIDs)
        refreshStylePreviewImages()
        return preset
    }

    @discardableResult
    func updateCustomStyle(
        id: StylePreset.ID,
        name: String,
        params: StyleParams
    ) -> StylePreset? {
        guard let existingPreset = selection.presets.first(where: { $0.id == id }) else {
            return nil
        }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let updatedPreset = StylePreset(
            id: existingPreset.id,
            name: trimmedName.isEmpty ? existingPreset.name : trimmedName,
            params: params,
            isBuiltIn: existingPreset.isBuiltIn
        )
        selection.replacePreset(id: id, with: updatedPreset)
        if selection.selectedPreset.id == id {
            selectedStyleName = updatedPreset.name
        }
        if updatedPreset.isBuiltIn {
            Self.saveBuiltInStyleOverrides(selection.presets.filter { $0.isBuiltIn })
        } else {
            Self.saveCustomStylePresets(selection.presets.filter { !$0.isBuiltIn })
        }
        refreshStylePreviewImages()
        return updatedPreset
    }

    @discardableResult
    func deleteCustomStyle(id: StylePreset.ID) -> Bool {
        guard let preset = selection.presets.first(where: { $0.id == id }),
              !preset.isBuiltIn,
              selection.removePreset(id: id) != nil else {
            return false
        }

        disabledStyleIDs.remove(id)
        if visibleStylePresets.isEmpty {
            disabledStyleIDs.remove(BuiltInPresets.original.id)
        }
        if disabledStyleIDs.contains(selection.selectedPreset.id),
           let replacement = visibleStylePresets.first {
            selection.selectPreset(id: replacement.id)
        }

        selectedStyleName = selection.selectedPreset.name
        Self.saveCustomStylePresets(selection.presets.filter { !$0.isBuiltIn })
        Self.saveDisabledStyleIDs(disabledStyleIDs)
        refreshStylePreviewImages()
        return true
    }

    @discardableResult
    func setStyleEnabled(id: StylePreset.ID, isEnabled: Bool) -> Bool {
        let isCurrentlyEnabled = !disabledStyleIDs.contains(id)
        guard isCurrentlyEnabled != isEnabled else { return true }
        guard selection.presets.contains(where: { $0.id == id }) else { return false }

        if !isEnabled, visibleStylePresets.count <= 1 {
            return false
        }

        if isEnabled {
            disabledStyleIDs.remove(id)
        } else {
            disabledStyleIDs.insert(id)
            if selection.selectedPreset.id == id,
               let replacement = visibleStylePresets.first {
                selection.selectPreset(id: replacement.id)
                selectedStyleName = replacement.name
            }
        }

        Self.saveDisabledStyleIDs(disabledStyleIDs)
        return true
    }

    private func selectRelativeStyle(offset: Int) {
        let presets = visibleStylePresets
        guard !presets.isEmpty else { return }
        let currentIndex = presets.firstIndex(where: { $0.id == selection.selectedPreset.id }) ?? 0
        let nextIndex = (currentIndex + offset + presets.count) % presets.count
        selectStyle(id: presets[nextIndex].id)
    }

    private func refreshStylePreviewImages() {
        stylePreviewRenderGeneration += 1
        stylePreviewStore.reset()
    }

    private func renderPreview(_ image: CIImage) {
        latestPreviewFrameID += 1
        latestPreviewSource = image

        startLivePreviewRenderIfNeeded()

        if isStylePreviewComparisonActive || stylePreviewStore.images.isEmpty {
            startStylePreviewRenderIfNeeded(
                publishWhenInactive: !isStylePreviewComparisonActive && stylePreviewStore.images.isEmpty
            )
        }
    }

    private func startLivePreviewRenderIfNeeded() {
        guard !isPreviewRenderInFlight, let image = latestPreviewSource else { return }

        isPreviewRenderInFlight = true
        let frameID = latestPreviewFrameID
        let params = selection.selectedPreset.params
        let styleName = selection.selectedPreset.name
        let guidanceSettings = guidanceSettings
        let rollDegrees = currentRollDegrees
        let shouldAnalyzeGuidance = guidanceSettings.isEnabled && shouldRunGuidanceAnalysis()
        let includeRawImage = isStyleEditorPreviewActive
        let screenScale = UIScreen.main.scale
        let worker = livePreviewRenderWorker

        renderQueue.async { [weak self] in
            let result = worker.render(
                image: image,
                params: params,
                styleName: styleName,
                guidanceSettings: guidanceSettings,
                rollDegrees: rollDegrees,
                shouldAnalyzeGuidance: shouldAnalyzeGuidance,
                includeRawImage: includeRawImage,
                screenScale: screenScale
            )

            Task { @MainActor in
                guard let self else { return }
                self.isPreviewRenderInFlight = false

                if let result {
                    self.previewStore.publish(result.image)
                    if let rawImage = result.rawImage {
                        self.rawPreviewStore.publish(rawImage)
                    }
                    if shouldAnalyzeGuidance {
                        self.publishGuidanceHint(result.guidanceHint)
                    }
                }

                if self.latestPreviewFrameID > frameID {
                    self.startLivePreviewRenderIfNeeded()
                }
            }
        }
    }

    private func shouldRunGuidanceAnalysis() -> Bool {
        let now = Date().timeIntervalSinceReferenceDate
        guard now - lastGuidanceAnalysisAt >= 0.9 else {
            return false
        }

        lastGuidanceAnalysisAt = now
        return true
    }

    private func startStylePreviewRenderIfNeeded(
        publishWhenInactive: Bool = false
    ) {
        guard !isStylePreviewRenderInFlight, let image = latestPreviewSource else { return }

        isStylePreviewRenderInFlight = true
        let frameID = latestPreviewFrameID
        let generation = stylePreviewRenderGeneration
        let presets = selection.presets
        let screenScale = UIScreen.main.scale
        let worker = stylePreviewRenderWorker

        stylePreviewQueue.async { [weak self] in
            let previewImages = worker.render(
                image: image,
                presets: presets,
                screenScale: screenScale
            )

            Task { @MainActor in
                guard let self else { return }

                self.isStylePreviewRenderInFlight = false
                if self.stylePreviewRenderGeneration == generation,
                   (publishWhenInactive || self.isStylePreviewComparisonActive) {
                    self.stylePreviewStore.publish(previewImages)
                }

                if self.isStylePreviewComparisonActive,
                   (self.stylePreviewRenderGeneration != generation
                    || self.latestPreviewFrameID > frameID) {
                    self.startStylePreviewRenderIfNeeded()
                }
            }
        }
    }

    private func publishGuidanceHint(_ hint: PhotoGuidanceHint?) {
        guard guidanceSettings.isEnabled else {
            guidanceHint = nil
            return
        }

        guard let hint else {
            guidanceHint = nil
            return
        }

        let now = Date().timeIntervalSinceReferenceDate
        if hint.message == lastGuidanceMessage,
           now - lastGuidanceDisplayAt < 5 {
            return
        }

        lastGuidanceMessage = hint.message
        lastGuidanceDisplayAt = now
        guidanceHint = hint

        Task { [weak self, message = hint.message] in
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            await MainActor.run {
                guard self?.guidanceHint?.message == message else {
                    return
                }
                self?.guidanceHint = nil
            }
        }
    }

    private func showTransientHint(_ hint: PhotoGuidanceHint) {
        guidanceHint = hint

        Task { [weak self, message = hint.message] in
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            await MainActor.run {
                guard self?.guidanceHint?.message == message else {
                    return
                }
                self?.guidanceHint = nil
            }
        }
    }

    private func updateMotionTracking() {
        if guidanceSettings.isEnabled || selectedTemplate?.watermark.enabled == true {
            motionLevelService.start()
        } else {
            motionLevelService.stop()
            currentRollDegrees = 0
        }
    }

    private func processCapturedPhoto(requestID: UUID, image: CIImage) {
        guard let configuration = pendingCaptures[requestID] else { return }

        if configuration.cameraTemplate?.usesLocation == true {
            requestTemplateLocation()
        }

        renderQueue.async { [weak self] in
            guard let self else { return }
            let worker = self.capturedPhotoRenderWorker
            let photoLibrary = self.photoLibrary
            let output = worker.render(image, configuration: configuration)

            guard let jpeg = worker.jpegData(from: output) else {
                Task { @MainActor in
                    self.finishCapture(requestID: requestID)
                }
                return
            }

            photoLibrary.savePhotoData(jpeg) { result in
                if case .success = result,
                   let image = UIImage(data: jpeg) {
                    Task { @MainActor in
                        self.lastSavedThumbnail = image
                    }
                }
                Task { @MainActor in
                    self.finishCapture(requestID: requestID)
                }
            }
        }
    }

    private func processDeferredPhoto(
        requestID: UUID,
        proxyImage: CIImage,
        proxyData: Data
    ) {
        guard let configuration = pendingCaptures[requestID] else { return }
        let worker = capturedPhotoRenderWorker
        let photoLibrary = photoLibrary

        // Render the lightweight proxy first so the recent-photo button quickly
        // reflects the selected style.
        renderQueue.async { [weak self] in
            guard let self else { return }
            let renderedProxy = worker.render(proxyImage, configuration: configuration)
            if let thumbnail = worker.thumbnail(from: renderedProxy) {
                Task { @MainActor in
                    self.lastSavedThumbnail = thumbnail
                }
            }
        }

        photoLibrary.saveDeferredPhotoProxy(proxyData) { [weak self] result in
            guard let self else { return }
            switch result {
            case let .success(localIdentifier):
                photoLibrary.requestEditingSource(localIdentifier: localIdentifier) { sourceResult in
                    switch sourceResult {
                    case let .success(source):
                        self.renderQueue.async { [weak self] in
                            guard let self else { return }
                            let output = worker.render(
                                source.image,
                                configuration: configuration
                            )
                            photoLibrary.commitAdjustedPhoto(output, source: source) { _ in
                                if let thumbnail = worker.thumbnail(from: output) {
                                    Task { @MainActor in
                                        self.lastSavedThumbnail = thumbnail
                                    }
                                }
                                Task { @MainActor in
                                    self.finishCapture(requestID: requestID)
                                }
                            }
                        }
                    case .failure:
                        Task { @MainActor in
                            self.finishCapture(requestID: requestID)
                        }
                    }
                }
            case .failure:
                // If full Photo Library access isn't available, preserve the shot
                // through the standard processed-photo path instead of losing it.
                self.renderQueue.async { [weak self] in
                    guard let self else { return }
                    let output = worker.render(proxyImage, configuration: configuration)
                    guard let jpeg = worker.jpegData(from: output) else {
                        Task { @MainActor in
                            self.finishCapture(requestID: requestID)
                        }
                        return
                    }
                    photoLibrary.savePhotoData(jpeg) { _ in
                        Task { @MainActor in
                            self.finishCapture(requestID: requestID)
                        }
                    }
                }
            }
        }
    }

    private func finishCapture(requestID: UUID) {
        pendingCaptures.removeValue(forKey: requestID)
        isProcessingHighResolutionPhoto = !pendingCaptures.isEmpty
    }

    private static let selectedTemplateSettingsKey = "stylecamera.selected.template"
    private static let customStyleSettingsKey = "stylecamera.custom.styles"
    private static let builtInStyleOverridesKey = "stylecamera.builtin.style.overrides"
    private static let disabledStyleSettingsKey = "stylecamera.disabled.styles"
    private static let guidanceSettingsKey = "stylecamera.photo.guidance.settings"
    private static let captureAspectRatioSettingsKey = "stylecamera.capture.aspectRatio"

    nonisolated fileprivate static func centerCrop(_ image: CIImage, to aspectRatio: CaptureAspectRatio) -> CIImage {
        let normalizedImage = image.transformed(
            by: CGAffineTransform(translationX: -image.extent.origin.x, y: -image.extent.origin.y)
        )
        let extent = normalizedImage.extent
        guard extent.width > 0, extent.height > 0 else {
            return normalizedImage
        }

        let targetRatio = aspectRatio.ratio(for: extent.size)
        let currentRatio = extent.width / extent.height
        let cropRect: CGRect

        if currentRatio > targetRatio {
            let targetWidth = extent.height * targetRatio
            cropRect = CGRect(
                x: (extent.width - targetWidth) / 2,
                y: 0,
                width: targetWidth,
                height: extent.height
            )
        } else {
            let targetHeight = extent.width / targetRatio
            cropRect = CGRect(
                x: 0,
                y: (extent.height - targetHeight) / 2,
                width: extent.width,
                height: targetHeight
            )
        }

        return normalizedImage
            .cropped(to: cropRect.integral)
            .transformed(by: CGAffineTransform(translationX: -cropRect.integral.origin.x, y: -cropRect.integral.origin.y))
    }

    private static func loadCustomStylePresets() -> [StylePreset] {
        guard let data = UserDefaults.standard.data(forKey: customStyleSettingsKey),
              let presets = try? JSONDecoder().decode([StylePreset].self, from: data) else {
            return []
        }
        return presets.map { preset in
            var copy = preset
            copy.isBuiltIn = false
            return copy
        }
    }

    private static func loadConfiguredBuiltInPresets() -> [StylePreset] {
        guard let data = UserDefaults.standard.data(forKey: builtInStyleOverridesKey),
              let overrides = try? JSONDecoder().decode([StylePreset].self, from: data) else {
            return BuiltInPresets.all
        }

        let overridesByID = Dictionary(uniqueKeysWithValues: overrides.map { ($0.id, $0) })
        return BuiltInPresets.all.map { preset in
            guard var override = overridesByID[preset.id] else { return preset }
            override.isBuiltIn = true
            return override
        }
    }

    private static func saveBuiltInStyleOverrides(_ presets: [StylePreset]) {
        guard let data = try? JSONEncoder().encode(presets) else { return }
        UserDefaults.standard.set(data, forKey: builtInStyleOverridesKey)
    }

    private static func saveCustomStylePresets(_ presets: [StylePreset]) {
        guard let data = try? JSONEncoder().encode(presets) else {
            return
        }
        UserDefaults.standard.set(data, forKey: customStyleSettingsKey)
    }

    private static func loadDisabledStyleIDs() -> Set<StylePreset.ID> {
        let rawIDs = UserDefaults.standard.stringArray(forKey: disabledStyleSettingsKey) ?? []
        return Set(rawIDs.compactMap(UUID.init(uuidString:)))
    }

    private static func saveDisabledStyleIDs(_ ids: Set<StylePreset.ID>) {
        UserDefaults.standard.set(ids.map(\.uuidString).sorted(), forKey: disabledStyleSettingsKey)
    }

    private static func loadGuidanceSettings() -> PhotoGuidanceSettings {
        guard let data = UserDefaults.standard.data(forKey: guidanceSettingsKey),
              let settings = try? JSONDecoder().decode(PhotoGuidanceSettings.self, from: data) else {
            return PhotoGuidanceSettings()
        }
        return settings
    }

    private static func saveGuidanceSettings(_ settings: PhotoGuidanceSettings) {
        guard let data = try? JSONEncoder().encode(settings) else {
            return
        }
        UserDefaults.standard.set(data, forKey: guidanceSettingsKey)
    }

    private static func loadCaptureAspectRatio() -> CaptureAspectRatio {
        guard let rawValue = UserDefaults.standard.string(forKey: captureAspectRatioSettingsKey),
              let aspectRatio = CaptureAspectRatio(rawValue: rawValue) else {
            return .nineBySixteen
        }
        return aspectRatio
    }

    private static func saveCaptureAspectRatio(_ aspectRatio: CaptureAspectRatio) {
        UserDefaults.standard.set(aspectRatio.rawValue, forKey: captureAspectRatioSettingsKey)
    }

    private static func loadSelectedTemplate() -> CameraTemplatePreset? {
        if let data = UserDefaults.standard.data(forKey: selectedTemplateSettingsKey),
           let template = try? JSONDecoder().decode(CameraTemplatePreset.self, from: data) {
            return template
        }

        guard let legacyID = UserDefaults.standard.string(forKey: selectedTemplateSettingsKey) else {
            return nil
        }
        return BuiltInCameraTemplates.preset(id: legacyID)
    }

    private static func saveSelectedTemplate(_ template: CameraTemplatePreset?) {
        guard let template,
              let data = try? JSONEncoder().encode(template) else {
            UserDefaults.standard.removeObject(forKey: selectedTemplateSettingsKey)
            return
        }
        UserDefaults.standard.set(data, forKey: selectedTemplateSettingsKey)
    }
}

private final class CameraLocationService: NSObject, CLLocationManagerDelegate {
    var onLocationTextChange: ((String?) -> Void)?

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestLocation() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .denied, .restricted:
            onLocationTextChange?(nil)
        @unknown default:
            onLocationTextChange?(nil)
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .denied, .restricted:
            onLocationTextChange?(nil)
        case .notDetermined:
            break
        @unknown default:
            onLocationTextChange?(nil)
        }
    }

    func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let location = locations.last else {
            onLocationTextChange?(nil)
            return
        }

        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            self?.onLocationTextChange?(Self.locationText(from: placemarks?.first))
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        onLocationTextChange?(nil)
    }

    private static func locationText(from placemark: CLPlacemark?) -> String? {
        guard let placemark else { return nil }
        let parts = [
            placemark.locality,
            placemark.subAdministrativeArea,
            placemark.administrativeArea,
            placemark.country
        ].compactMap { value -> String? in
            guard let value,
                  !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            return value
        }
        guard !parts.isEmpty else { return nil }
        return Array(parts.prefix(2)).joined(separator: " · ")
    }
}
