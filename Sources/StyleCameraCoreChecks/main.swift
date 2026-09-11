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
let removedCustomPreset = model.removePreset(id: updatedCustomPreset.id)
expect(removedCustomPreset?.name == "我的风格 3", "remove style by id")
expect(model.presets.count == BuiltInPresets.all.count, "remove style updates preset list")
expect(model.presets.contains(where: { $0.id == updatedCustomPreset.id }) == false, "removed style is absent")
let singlePresetModel = StyleSelectionModel(presets: [BuiltInPresets.original])
expect(singlePresetModel.removePreset(id: BuiltInPresets.original.id) == nil, "selection keeps at least one style")

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

let classicTravelTemplate = BuiltInCameraTemplates.preset(id: "classic-travel")
expect(classicTravelTemplate != nil, "classic travel template exists")
expect(
    classicTravelTemplate?.photoFrame.baseInsets.bottom == 100,
    "template base inset is preserved"
)
expect(
    classicTravelTemplate?.watermark.enabled == true,
    "template content overlay is enabled"
)
let encodedTemplate = classicTravelTemplate.flatMap { try? JSONEncoder().encode($0) }
let decodedTemplate = encodedTemplate.flatMap {
    try? JSONDecoder().decode(CameraTemplatePreset.self, from: $0)
}
expect(
    decodedTemplate?.photoFrame.baseInsets == classicTravelTemplate?.photoFrame.baseInsets,
    "template base insets survive persistence"
)

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
