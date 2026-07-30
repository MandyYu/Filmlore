import AVFoundation
import CoreLocation
import CoreImage
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

@MainActor
final class CameraViewModel: ObservableObject {
    @Published var selectedStyleName = BuiltInPresets.foodINS.name
    @Published private(set) var disabledStyleIDs = Set<StylePreset.ID>()
    @Published var flashMode: AVCaptureDevice.FlashMode = .off
    @Published var showGrid = true
    @Published var watermark: WatermarkPreset {
        didSet {
            Self.saveWatermarkPreset(watermark)
            updateMotionTracking()
        }
    }
    @Published var photoFrame: PhotoFramePreset {
        didSet {
            Self.savePhotoFramePreset(photoFrame)
        }
    }
    @Published var selectedLens: CGFloat = 1
    @Published var isStyleEditorPresented = false
    @Published var isPhotoLibraryPresented = false
    @Published var isSettingsPresented = false
    @Published var lastSavedThumbnail: UIImage?
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
    private let renderer = StyleRenderer()
    private let photoLibrary = PhotoLibraryService()
    private let watermarkRenderer = WatermarkRenderer()
    private lazy var photoFrameRenderer = PhotoFrameRenderer(context: renderer.context)
    private let locationService = CameraLocationService()
    private let motionLevelService = MotionLevelService()
    private let renderQueue = DispatchQueue(label: "stylecamera.preview.render.queue")
    private let stylePreviewQueue = DispatchQueue(label: "stylecamera.style.preview.render.queue", qos: .userInitiated)
    private let livePreviewRenderWorker = LivePreviewRenderWorker()
    private let stylePreviewRenderWorker = StylePreviewRenderWorker()
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

    init() {
        watermark = Self.loadWatermarkPreset()
        photoFrame = Self.loadPhotoFramePreset()
        guidanceSettings = Self.loadGuidanceSettings()
        captureAspectRatio = Self.loadCaptureAspectRatio()
        selection = StyleSelectionModel(
            presets: BuiltInPresets.all + Self.loadCustomStylePresets(),
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

        cameraEngine.onPhotoCaptured = { [weak self] data in
            self?.processCapturedPhoto(data)
        }
    }

    func start() {
        cameraEngine.configure()
        updateMotionTracking()
        if watermark.includeLocation {
            requestWatermarkLocation()
        }
    }

    func stop() {
        cameraEngine.stop()
        motionLevelService.stop()
        currentRollDegrees = 0
    }

    func capturePhoto() {
        cameraEngine.capturePhoto(flashMode: flashMode)
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

    func toggleWatermark() {
        watermark.enabled.toggle()
    }

    func requestWatermarkLocation() {
        locationService.requestLocation()
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

    func updateWatermarkAnchor(_ unitPoint: CGPoint) {
        let clampedX = Float(max(0.05, min(0.95, unitPoint.x)))
        let clampedY = Float(max(0.05, min(0.95, unitPoint.y)))
        watermark.position = .custom
        watermark.customPosition = WatermarkAnchor(x: clampedX, y: clampedY)
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
        guard let existingPreset = selection.presets.first(where: { $0.id == id }),
              !existingPreset.isBuiltIn else {
            return nil
        }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let updatedPreset = StylePreset(
            id: existingPreset.id,
            name: trimmedName.isEmpty ? existingPreset.name : trimmedName,
            params: params,
            watermark: existingPreset.watermark,
            isBuiltIn: false
        )
        selection.replacePreset(id: id, with: updatedPreset)
        if selection.selectedPreset.id == id {
            selectedStyleName = updatedPreset.name
        }
        Self.saveCustomStylePresets(selection.presets.filter { !$0.isBuiltIn })
        refreshStylePreviewImages()
        return updatedPreset
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
        if guidanceSettings.isEnabled || watermark.enabled {
            motionLevelService.start()
        } else {
            motionLevelService.stop()
            currentRollDegrees = 0
        }
    }

    private func processCapturedPhoto(_ data: Data) {
        guard let input = CIImage(
            data: data,
            options: [.applyOrientationProperty: true]
        ) else { return }
        let style = selection.selectedPreset
        let watermark = watermark
        let photoFrame = photoFrame
        let locationText = locationText
        let captureAspectRatio = captureAspectRatio

        if watermark.includeLocation {
            requestWatermarkLocation()
        }

        renderQueue.async { [weak self] in
            guard let self else { return }
            let croppedInput = Self.centerCrop(input, to: captureAspectRatio)
            var output = self.renderer.applyStyle(to: croppedInput, params: style.params)
            output = self.renderer.normalized(output)

            if watermark.enabled {
                output = self.watermarkRenderer.renderWatermark(
                    on: output,
                    preset: watermark,
                    styleName: style.name,
                    locationText: locationText
                )
            }

            output = self.photoFrameRenderer.renderFrame(around: output, preset: photoFrame)

            guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
                  let jpeg = self.renderer.context.jpegRepresentation(
                    of: output,
                    colorSpace: colorSpace,
                    options: [
                        kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 0.92
                    ]
                  ) else {
                return
            }

            self.photoLibrary.savePhotoData(jpeg) { result in
                if case .success = result,
                   let image = UIImage(data: jpeg) {
                    Task { @MainActor in
                        self.lastSavedThumbnail = image
                    }
                }
            }
        }
    }

    private static let watermarkSettingsKey = "stylecamera.watermark.settings"
    private static let photoFrameSettingsKey = "stylecamera.photo.frame.settings"
    private static let customStyleSettingsKey = "stylecamera.custom.styles"
    private static let disabledStyleSettingsKey = "stylecamera.disabled.styles"
    private static let guidanceSettingsKey = "stylecamera.photo.guidance.settings"
    private static let captureAspectRatioSettingsKey = "stylecamera.capture.aspectRatio"

    nonisolated private static func centerCrop(_ image: CIImage, to aspectRatio: CaptureAspectRatio) -> CIImage {
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

    private static func loadWatermarkPreset() -> WatermarkPreset {
        guard let data = UserDefaults.standard.data(forKey: watermarkSettingsKey),
              let preset = try? JSONDecoder().decode(WatermarkPreset.self, from: data) else {
            return WatermarkPreset(enabled: true)
        }
        return preset
    }

    private static func saveWatermarkPreset(_ preset: WatermarkPreset) {
        guard let data = try? JSONEncoder().encode(preset) else {
            return
        }
        UserDefaults.standard.set(data, forKey: watermarkSettingsKey)
    }

    private static func loadPhotoFramePreset() -> PhotoFramePreset {
        guard let data = UserDefaults.standard.data(forKey: photoFrameSettingsKey),
              let preset = try? JSONDecoder().decode(PhotoFramePreset.self, from: data) else {
            return PhotoFramePreset()
        }
        return preset
    }

    private static func savePhotoFramePreset(_ preset: PhotoFramePreset) {
        guard let data = try? JSONEncoder().encode(preset) else {
            return
        }
        UserDefaults.standard.set(data, forKey: photoFrameSettingsKey)
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
            let placemark = placemarks?.first
            let text = Self.locationText(from: placemark)
            self?.onLocationTextChange?(text)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        onLocationTextChange?(nil)
    }

    private static func locationText(from placemark: CLPlacemark?) -> String? {
        guard let placemark else { return nil }

        let candidates = [
            placemark.locality,
            placemark.subAdministrativeArea,
            placemark.administrativeArea,
            placemark.country
        ]
        let parts = candidates.compactMap { value -> String? in
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
