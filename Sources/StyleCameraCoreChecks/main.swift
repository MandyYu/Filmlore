import CoreImage
import CoreGraphics
import Foundation
import StyleCameraCore

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("Check failed: \(message)\n", stderr)
        exit(1)
    }
}

let names = BuiltInPresets.all.map(\.name)
expect(names == [
    "原图",
    "食物 ins 风",
    "冷白皮风",
    "富士清新风",
    "城市质感风",
    "日系奶油风",
    "夜景氛围风"
], "built-in preset order")
expect(BuiltInPresets.all.allSatisfy(\.isBuiltIn), "built-in flags")

let params = StyleParams(
    exposure: 140,
    brilliance: -140,
    highlights: 120,
    shadows: -120,
    contrast: 101,
    blackPoint: 130,
    brightness: -101,
    saturation: 150,
    vibrance: -150,
    warmth: 125,
    tint: -125,
    sharpness: 140,
    fade: -20,
    grain: 180,
    vignette: 300
)
expect(params.exposure == 100, "exposure clamp")
expect(params.brilliance == -100, "brilliance clamp")
expect(params.highlights == 100, "highlights clamp")
expect(params.shadows == -100, "shadows clamp")
expect(params.contrast == 100, "contrast clamp")
expect(params.blackPoint == 100, "blackPoint clamp")
expect(params.brightness == -100, "brightness clamp")
expect(params.saturation == 100, "saturation clamp")
expect(params.vibrance == -100, "vibrance clamp")
expect(params.warmth == 100, "warmth clamp")
expect(params.tint == -100, "tint clamp")
expect(params.sharpness == 100, "sharpness clamp")
expect(params.fade == 0, "fade clamp")
expect(params.grain == 100, "grain clamp")
expect(params.vignette == 100, "vignette clamp")

let model = StyleSelectionModel(presets: BuiltInPresets.all, selectedIndex: 0)
model.selectPrevious()
expect(model.selectedPreset.name == "夜景氛围风", "selection wraps backward")
model.selectNext()
expect(model.selectedPreset.name == "原图", "selection wraps forward")
model.selectPreset(id: BuiltInPresets.all[3].id)
expect(model.selectedPreset.name == "富士清新风", "selection by id")
let customPreset = StylePreset(name: "我的风格", params: StyleParams(exposure: 12), isBuiltIn: false)
model.appendAndSelect(customPreset)
expect(model.selectedPreset.name == "我的风格", "append custom style selects it")
model.replaceSelectedPreset(with: StylePreset(name: "我的风格 2", params: StyleParams(exposure: 20), isBuiltIn: false))
expect(model.selectedPreset.name == "我的风格 2", "replace selected style")
expect(model.selectedPreset.params.exposure == 20, "replace selected style params")
let updatedCustomPreset = StylePreset(
    id: model.selectedPreset.id,
    name: "我的风格 3",
    params: StyleParams(exposure: 28),
    isBuiltIn: false
)
model.replacePreset(id: updatedCustomPreset.id, with: updatedCustomPreset)
expect(model.selectedPreset.name == "我的风格 3", "replace style by id")
expect(model.selectedPreset.params.exposure == 28, "replace style by id params")

let input = CIImage(color: CIColor(red: 0.4, green: 0.5, blue: 0.6))
    .cropped(to: CGRect(x: 0, y: 0, width: 12, height: 18))
let output = StyleRenderer().applyStyle(to: input, params: BuiltInPresets.foodINS.params)
expect(output.extent == input.extent, "renderer preserves extent")

let offsetInput = input.transformed(by: CGAffineTransform(translationX: 42, y: -16))
let normalizedOutput = StyleRenderer().applyStyle(to: offsetInput, params: BuiltInPresets.foodINS.params)
expect(normalizedOutput.extent.origin == .zero, "renderer normalizes extent origin")
expect(normalizedOutput.extent.size == input.extent.size, "renderer preserves normalized size")

expect(
    ZoomFactorMapper.hardwareZoom(
        displayedZoom: 0.5,
        normalLensHardwareZoom: 2,
        minHardwareZoom: 1,
        maxHardwareZoom: 8
    ) == 1,
    "0.5x maps to the ultra-wide hardware baseline on dual/triple camera devices"
)
expect(
    ZoomFactorMapper.hardwareZoom(
        displayedZoom: 1,
        normalLensHardwareZoom: 2,
        minHardwareZoom: 1,
        maxHardwareZoom: 8
    ) == 2,
    "1x maps to the normal wide lens on dual/triple camera devices"
)
expect(
    ZoomFactorMapper.hardwareZoom(
        displayedZoom: 2,
        normalLensHardwareZoom: 2,
        minHardwareZoom: 1,
        maxHardwareZoom: 8
    ) == 4,
    "2x remains twice the normal wide lens on dual/triple camera devices"
)
expect(
    ZoomFactorMapper.hardwareZoom(
        displayedZoom: 1,
        normalLensHardwareZoom: 1,
        minHardwareZoom: 1,
        maxHardwareZoom: 8
    ) == 1,
    "1x remains hardware 1x on single wide camera devices"
)

let watermarkDefaults = WatermarkPreset()
expect(watermarkDefaults.mode == .manual, "default watermark mode")
expect(watermarkDefaults.includeLocation == false, "default watermark hides location")
expect(watermarkDefaults.locationOverrideText == "", "default watermark location override")
expect(watermarkDefaults.customPosition == nil, "default watermark custom position")
expect(watermarkDefaults.imageData == nil, "default watermark image data")
expect(watermarkDefaults.imageScale == 0.22, "default watermark image scale")
expect(watermarkDefaults.textColor == .automatic, "default watermark text color")
expect(watermarkDefaults.visualStyle == .minimal, "default watermark visual style")
expect(watermarkDefaults.effect == .shadow, "default watermark effect")
expect(WatermarkAnchor(x: -1, y: 2) == WatermarkAnchor(x: 0, y: 1), "watermark anchor clamp")
expect(WatermarkPreset(imageScale: 2).imageScale == 0.6, "watermark image scale upper clamp")
expect(WatermarkPreset(imageScale: -1).imageScale == 0.08, "watermark image scale lower clamp")
expect(
    WatermarkMode.allCases == [.manual, .image],
    "watermark mode options"
)
expect(
    WatermarkPosition.allCases == [.topLeft, .topRight, .bottomLeft, .bottomRight, .bottomCenter, .custom],
    "watermark position options"
)
expect(
    WatermarkTextColor.allCases == [.automatic, .white, .black, .yellow, .orange, .blue, .pink],
    "watermark text color options"
)
expect(
    WatermarkVisualStyle.allCases == [.minimal, .darkBadge, .lightBadge, .film],
    "watermark visual style options"
)
expect(
    WatermarkEffect.allCases == [.none, .shadow, .glow],
    "watermark effect options"
)

let photoFrameDefaults = PhotoFramePreset()
expect(photoFrameDefaults.enabled == false, "default photo frame disabled")
expect(photoFrameDefaults.style == .cleanWhite, "default photo frame style")
expect(photoFrameDefaults.opacity == 1, "default photo frame opacity")
expect(photoFrameDefaults.borderWidth == 24, "default photo frame border width")
expect(photoFrameDefaults.cornerRadius == 12, "default photo frame corner radius")
expect(photoFrameDefaults.shadowEnabled, "default photo frame shadow")
expect(photoFrameDefaults.backgroundColor == .white, "default photo frame background")
expect(PhotoFramePreset(enabled: true, style: .film, opacity: 3).opacity == 1, "photo frame opacity upper clamp")
expect(PhotoFramePreset(enabled: true, style: .film, opacity: -1).opacity == 0, "photo frame opacity lower clamp")
expect(PhotoFramePreset(borderWidth: 80).borderWidth == 40, "photo frame border width upper clamp")
expect(PhotoFramePreset(borderWidth: 0).borderWidth == 4, "photo frame border width lower clamp")
expect(PhotoFramePreset(cornerRadius: 80).cornerRadius == 30, "photo frame corner radius upper clamp")
expect(
    PhotoFrameStyle.allCases == [.cleanWhite, .cleanBlack, .instant, .film, .minimal],
    "photo frame style options"
)
expect(
    PhotoFrameBackgroundColor.allCases == [.white, .lightGray, .black, .cream, .pink, .mint],
    "photo frame background options"
)
let legacyPhotoFrameJSON = #"{"enabled":true,"style":"cleanBlack","opacity":0.8}"#.data(using: .utf8)!
let legacyPhotoFrame = try? JSONDecoder().decode(PhotoFramePreset.self, from: legacyPhotoFrameJSON)
expect(legacyPhotoFrame?.backgroundColor == .black, "legacy black frame background migration")
expect(legacyPhotoFrame?.borderWidth == 24, "legacy photo frame border width migration")
let encodedPhotoFrame = try? JSONEncoder().encode(
    PhotoFramePreset(
        enabled: true,
        style: .minimal,
        opacity: 0.9,
        borderWidth: 10,
        cornerRadius: 18,
        shadowEnabled: false,
        backgroundColor: .mint
    )
)
let decodedPhotoFrame = encodedPhotoFrame.flatMap { try? JSONDecoder().decode(PhotoFramePreset.self, from: $0) }
expect(decodedPhotoFrame?.style == .minimal, "photo frame style round trip")
expect(decodedPhotoFrame?.backgroundColor == .mint, "photo frame background round trip")
expect(decodedPhotoFrame?.cornerRadius == 18, "photo frame corner radius round trip")

let guidanceDefaults = PhotoGuidanceSettings()
expect(guidanceDefaults.isEnabled, "photo guidance is enabled by default")
expect(guidanceDefaults.intensity == .standard, "photo guidance default intensity")
expect(guidanceDefaults.compositionEnabled, "photo guidance default composition toggle")
expect(guidanceDefaults.angleEnabled, "photo guidance default angle toggle")
expect(guidanceDefaults.lightEnabled, "photo guidance default light toggle")
expect(guidanceDefaults.sharpnessEnabled, "photo guidance default sharpness toggle")
expect(guidanceDefaults.styleEnabled, "photo guidance default style toggle")

let guidanceEngine = PhotoGuidanceEngine()
let normalScene = PhotoGuidanceSceneAnalysis(
    averageBrightness: 0.5,
    overexposedPixelRatio: 0.01,
    sharpnessScore: 0.42,
    subjectRect: CGRect(x: 0.34, y: 0.32, width: 0.32, height: 0.34),
    rollDegrees: 0
)
expect(
    guidanceEngine.hint(
        for: normalScene,
        styleName: BuiltInPresets.foodINS.name,
        settings: PhotoGuidanceSettings(isEnabled: false)
    ) == nil,
    "disabled photo guidance returns no hint"
)

let darkScene = PhotoGuidanceSceneAnalysis(
    averageBrightness: 0.14,
    overexposedPixelRatio: 0.0,
    sharpnessScore: 0.46,
    subjectRect: normalScene.subjectRect,
    rollDegrees: 0
)
expect(
    guidanceEngine.hint(for: darkScene, styleName: BuiltInPresets.foodINS.name, settings: guidanceDefaults)?.category == .light,
    "dark scene returns light guidance"
)
expect(
    guidanceEngine.hint(for: darkScene, styleName: BuiltInPresets.foodINS.name, settings: guidanceDefaults)?.message == "光线偏暗",
    "dark scene message"
)

let brightScene = PhotoGuidanceSceneAnalysis(
    averageBrightness: 0.82,
    overexposedPixelRatio: 0.18,
    sharpnessScore: 0.46,
    subjectRect: normalScene.subjectRect,
    rollDegrees: 0
)
expect(
    guidanceEngine.hint(for: brightScene, styleName: BuiltInPresets.coolWhiteSkin.name, settings: guidanceDefaults)?.message == "高光过亮",
    "overexposed scene message"
)

let blurryScene = PhotoGuidanceSceneAnalysis(
    averageBrightness: 0.5,
    overexposedPixelRatio: 0.01,
    sharpnessScore: 0.08,
    subjectRect: normalScene.subjectRect,
    rollDegrees: 0
)
expect(
    guidanceEngine.hint(for: blurryScene, styleName: BuiltInPresets.foodINS.name, settings: guidanceDefaults)?.category == .sharpness,
    "blurry scene returns sharpness guidance"
)

let tiltedScene = PhotoGuidanceSceneAnalysis(
    averageBrightness: 0.5,
    overexposedPixelRatio: 0.01,
    sharpnessScore: 0.42,
    subjectRect: normalScene.subjectRect,
    rollDegrees: 7.4
)
expect(
    guidanceEngine.hint(for: tiltedScene, styleName: BuiltInPresets.cityTexture.name, settings: guidanceDefaults)?.message == "保持水平",
    "tilted scene message"
)

let leftSubjectScene = PhotoGuidanceSceneAnalysis(
    averageBrightness: 0.5,
    overexposedPixelRatio: 0.01,
    sharpnessScore: 0.42,
    subjectRect: CGRect(x: 0.05, y: 0.32, width: 0.24, height: 0.3),
    rollDegrees: 0
)
expect(
    guidanceEngine.hint(for: leftSubjectScene, styleName: BuiltInPresets.foodINS.name, settings: guidanceDefaults)?.message == "向左一点",
    "left subject message asks camera to move left"
)

let tinySubjectScene = PhotoGuidanceSceneAnalysis(
    averageBrightness: 0.5,
    overexposedPixelRatio: 0.01,
    sharpnessScore: 0.42,
    subjectRect: CGRect(x: 0.44, y: 0.42, width: 0.11, height: 0.11),
    rollDegrees: 0
)
expect(
    guidanceEngine.hint(for: tinySubjectScene, styleName: BuiltInPresets.cityTexture.name, settings: guidanceDefaults)?.message == "靠近一点",
    "tiny subject message"
)

let foodStyleScene = PhotoGuidanceSceneAnalysis(
    averageBrightness: 0.48,
    overexposedPixelRatio: 0.01,
    sharpnessScore: 0.42,
    subjectRect: CGRect(x: 0.34, y: 0.32, width: 0.28, height: 0.28),
    rollDegrees: 0
)
expect(
    guidanceEngine.hint(for: foodStyleScene, styleName: BuiltInPresets.foodINS.name, settings: guidanceDefaults)?.category == .style,
    "food style can return style guidance"
)
expect(
    guidanceEngine.hint(for: foodStyleScene, styleName: BuiltInPresets.foodINS.name, settings: guidanceDefaults)?.message == "食物可以再靠近一点",
    "food style message"
)

expect(
    guidanceEngine.hint(for: normalScene, styleName: BuiltInPresets.cityTexture.name, settings: guidanceDefaults)?.message == "建筑线条尽量放正",
    "city style message"
)
expect(
    guidanceEngine.hint(for: normalScene, styleName: BuiltInPresets.fujiFresh.name, settings: guidanceDefaults)?.message == "留一点明亮背景",
    "fuji style message"
)
expect(
    guidanceEngine.hint(for: normalScene, styleName: BuiltInPresets.coolWhiteSkin.name, settings: guidanceDefaults)?.message == "脸转向柔和光源",
    "cool white skin style message"
)

print("StyleCameraCoreChecks passed")
