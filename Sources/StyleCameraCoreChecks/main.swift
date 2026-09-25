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

// The four legacy flags retain their defaults and all 16 combinations.
let watermarkFieldFixtures: [(String, WatermarkContentFields, String)] = [
    ("includeDate", .date, "2026.09.20"),
    ("includeDevice", .device, "iPhone"),
    ("includeStyleName", .styleName, "富士清新"),
    ("includeLocation", .location, "北京")
]
let missingFieldsWatermark = try JSONDecoder().decode(WatermarkPreset.self, from: Data("{}".utf8))
expect(missingFieldsWatermark == WatermarkPreset(), "missing watermark keys retain initializer defaults")
for mask in 0..<16 {
    var legacyObject: [String: Any] = ["text": "签名"]
    var fields: WatermarkContentFields = []
    for (index, fixture) in watermarkFieldFixtures.enumerated() {
        let isIncluded = mask & (1 << index) != 0
        legacyObject[fixture.0] = isIncluded
        if isIncluded { fields.insert(fixture.1) }
    }
    let decoded = try JSONDecoder().decode(
        WatermarkPreset.self,
        from: JSONSerialization.data(withJSONObject: legacyObject)
    )
    expect(decoded.includedFields == fields, "legacy watermark flags decode correctly: \(mask)")
    var expectedText = ["签名"]
    // Signature layout order remains style, device, location, date, independent of set order.
    for index in [2, 1, 3, 0] where mask & (1 << index) != 0 {
        expectedText.append(watermarkFieldFixtures[index].2)
    }
    expect(
        decoded.displayText(styleName: "富士清新", deviceName: "iPhone", locationText: "北京", dateText: "2026.09.20")
            == expectedText.joined(separator: " · "),
        "field selection preserves ordinary watermark content and order: \(mask)"
    )
    let configured = WatermarkPreset(text: "签名", includedFields: fields)
    expect(configured == decoded, "new field configuration matches legacy flags: \(mask)")
    let encoded = try JSONEncoder().encode(configured)
    let encodedObject = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
    for fixture in watermarkFieldFixtures {
        expect(
            encodedObject[fixture.0] as? Bool == legacyObject[fixture.0] as? Bool,
            "saved watermark retains legacy boolean schema: \(fixture.0)"
        )
    }
    let restored = try JSONDecoder().decode(WatermarkPreset.self, from: encoded)
    expect(restored == configured, "field selections survive persistence: \(mask)")
}
let partialFieldsWatermark = try JSONDecoder().decode(
    WatermarkPreset.self, from: Data(#"{"includeDate":false,"includeLocation":true}"#.utf8)
)
expect(partialFieldsWatermark.includedFields == [.styleName, .location], "partial legacy flags preserve absent-key defaults")
var locationWatermark = WatermarkPreset(includedFields: [.location], locationOverrideText: " 上海 ")
expect(
    locationWatermark.displayText(styleName: "风格", deviceName: "设备", locationText: "北京", dateText: "日期")
        == "Shot by Me · 上海",
    "selected location uses the user's override"
)
locationWatermark.includedFields.remove(.location)
expect(
    locationWatermark.displayText(styleName: "风格", deviceName: "设备", locationText: "北京", dateText: "日期")
        == "Shot by Me",
    "removing location also hides overridden location text"
)

expect(
    CameraTemplateCategory.allCases.map(\.title) == [
        "亲密关系", "节日纪念", "旅行出行", "日常生活",
        "自然瞬间", "运动爱好", "成长记录", "实用档案"
    ],
    "template categories follow the requested display order"
)

let legacyCategoriesByTemplateID: [String: String] = [
    "minimal-travel": "minimalFrame", "classic-travel": "classicWatermark",
    "classic-leica": "classicWatermark", "classic-leicax": "classicWatermark",
    "classic-date": "classicWatermark", "color-olive": "colorWalk",
    "color-ocean": "colorWalk", "color-coral": "colorWalk",
    "frame-polaroid": "frames", "frame-film": "frames", "frame-viewfinder": "frames",
    "personal-name": "personal", "personal-postcard": "personal", "personal-weekday": "personal"
]
for (id, legacyCategory) in legacyCategoriesByTemplateID {
    guard var template = BuiltInCameraTemplates.preset(id: id) else {
        expect(false, "legacy template still exists: \(id)")
        continue
    }
    template.watermark.customTextColorHex = "#123456"
    template.watermark.textColor = .custom
    template.watermark.watermarkScale = 1.35
    let data = try JSONEncoder().encode(template)
    var object = try JSONSerialization.jsonObject(with: data) as! [String: Any]
    object["category"] = legacyCategory
    let restored = try JSONDecoder().decode(
        CameraTemplatePreset.self,
        from: JSONSerialization.data(withJSONObject: object)
    )
    expect(restored == template, "legacy category migration preserves user settings: \(id)")
}

for category in CameraTemplateCategory.allCases {
    let data = try JSONEncoder().encode(category)
    let restored = try JSONDecoder().decode(CameraTemplateCategory.self, from: data)
    expect(restored == category, "new template category survives persistence")
}

let legacyCategoryFallbacks: [String: CameraTemplateCategory] = [
    "classicWatermark": .dailyLife, "colorWalk": .nature, "frames": .dailyLife,
    "personal": .dailyLife, "minimalFrame": .dailyLife,
    "personalFrame": .relationships, "seasonalFrame": .celebrations
]
for (legacyCategory, expected) in legacyCategoryFallbacks {
    let data = try JSONEncoder().encode(legacyCategory)
    let restored = try JSONDecoder().decode(CameraTemplateCategory.self, from: data)
    expect(restored == expected, "unmatched legacy categories have a migration fallback")
}

let classicTravelTemplate = BuiltInCameraTemplates.preset(id: "classic-travel")
expect(classicTravelTemplate != nil, "classic travel template exists")
if var explicitFieldsTemplate = classicTravelTemplate {
    explicitFieldsTemplate.watermark.includedFields = []
    expect(
        explicitFieldsTemplate.resolvedSlot(
            .text(.date), styleName: "风格", deviceName: "设备", locationText: "北京", dateText: "2026.09.20"
        ) == .text("2026.09.20"),
        "explicit template fields remain independent of ordinary watermark field selection"
    )
    explicitFieldsTemplate.insetContent = .empty
    expect(!explicitFieldsTemplate.usesLocation, "templates without either location source do not request location")
    explicitFieldsTemplate.watermark.includedFields.insert(.location)
    expect(explicitFieldsTemplate.usesLocation, "ordinary location field participates in template location requirements")
    explicitFieldsTemplate.watermark.includedFields = []
    explicitFieldsTemplate.insetContent = CameraTemplateInsetContent(left: .single(.text(.location)))
    expect(explicitFieldsTemplate.usesLocation, "explicit location slots retain their location requirements")
}
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
expect(
    decodedTemplate?.coverImageName == "template-cover-classic-travel",
    "template cover survives persistence"
)
if let encodedTemplate,
   var legacyObject = try? JSONSerialization.jsonObject(with: encodedTemplate) as? [String: Any] {
    legacyObject.removeValue(forKey: "coverImageName")
    legacyObject.removeValue(forKey: "coverOrientation")
    let legacyData = try? JSONSerialization.data(withJSONObject: legacyObject)
    let legacyTemplate = legacyData.flatMap {
        try? JSONDecoder().decode(CameraTemplatePreset.self, from: $0)
    }
    var expectedLegacyTemplate = classicTravelTemplate
    expectedLegacyTemplate?.coverImageName = nil
    expectedLegacyTemplate?.coverOrientation = .portrait
    expect(
        legacyTemplate != nil && legacyTemplate == expectedLegacyTemplate,
        "templates saved without a cover retain all existing settings"
    )
} else {
    expect(false, "legacy template compatibility fixture can be created")
}

if var landscapeTemplate = classicTravelTemplate {
    landscapeTemplate.coverOrientation = .landscape
    let data = try? JSONEncoder().encode(landscapeTemplate)
    let restoredTemplate = data.flatMap {
        try? JSONDecoder().decode(CameraTemplatePreset.self, from: $0)
    }
    expect(
        restoredTemplate == landscapeTemplate,
        "landscape cover orientation survives persistence without changing template settings"
    )
}

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
