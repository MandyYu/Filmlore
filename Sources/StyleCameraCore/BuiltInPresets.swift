import Foundation

public enum BuiltInPresets {
    public static let original = StylePreset(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        name: "原图",
        params: StyleParams(),
        isBuiltIn: true
    )

    public static let foodINS = StylePreset(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        name: "食物 ins 风",
        params: StyleParams(
            exposure: 10,
            brilliance: 30,
            highlights: -20,
            shadows: 20,
            contrast: -10,
            brightness: 10,
            saturation: 5,
            vibrance: 15,
            warmth: -5,
            tint: 5,
            sharpness: 30
        ),
        isBuiltIn: true
    )

    public static let coolWhiteSkin = StylePreset(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
        name: "冷白皮风",
        params: StyleParams(
            brilliance: 79,
            highlights: -17,
            shadows: 59,
            contrast: -15,
            blackPoint: 23,
            brightness: 29,
            saturation: -11,
            vibrance: -19,
            warmth: -37,
            tint: 20,
            sharpness: 33
        ),
        isBuiltIn: true
    )

    public static let fujiFresh = StylePreset(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
        name: "富士清新风",
        params: StyleParams(
            exposure: 10,
            brilliance: 30,
            highlights: -20,
            shadows: 20,
            contrast: -10,
            brightness: 10,
            saturation: 5,
            vibrance: 15,
            warmth: -5,
            tint: 5,
            sharpness: 30,
            fade: 8
        ),
        isBuiltIn: true
    )

    public static let cityTexture = StylePreset(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
        name: "城市质感风",
        params: StyleParams(
            exposure: -18,
            brilliance: 67,
            highlights: -24,
            shadows: 20,
            contrast: -17,
            saturation: -32,
            warmth: 17,
            sharpness: 30,
            vignette: 4
        ),
        isBuiltIn: true
    )

    public static let japaneseCream = StylePreset(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000006")!,
        name: "日系奶油风",
        params: StyleParams(
            exposure: 10,
            brilliance: 12,
            highlights: -18,
            shadows: 18,
            contrast: -22,
            brightness: 10,
            saturation: -8,
            vibrance: 8,
            warmth: 12,
            tint: 3,
            sharpness: -5,
            fade: 16,
            grain: 4
        ),
        isBuiltIn: true
    )

    public static let nightMood = StylePreset(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000007")!,
        name: "夜景氛围风",
        params: StyleParams(
            exposure: -5,
            brilliance: 18,
            highlights: -35,
            shadows: 15,
            contrast: 10,
            brightness: -2,
            vibrance: 8,
            warmth: -3,
            tint: 4,
            sharpness: 12,
            grain: 10,
            vignette: 12
        ),
        isBuiltIn: true
    )

    public static let all: [StylePreset] = [
        original,
        foodINS,
        coolWhiteSkin,
        fujiFresh,
        cityTexture,
        japaneseCream,
        nightMood
    ]
}
