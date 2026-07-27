import Foundation

public struct StyleParams: Codable, Equatable, Sendable {
    public var exposure: Float
    public var brilliance: Float
    public var highlights: Float
    public var shadows: Float
    public var contrast: Float
    public var blackPoint: Float
    public var brightness: Float
    public var saturation: Float
    public var vibrance: Float
    public var warmth: Float
    public var tint: Float
    public var sharpness: Float
    public var fade: Float
    public var grain: Float
    public var vignette: Float

    public init(
        exposure: Float = 0,
        brilliance: Float = 0,
        highlights: Float = 0,
        shadows: Float = 0,
        contrast: Float = 0,
        blackPoint: Float = 0,
        brightness: Float = 0,
        saturation: Float = 0,
        vibrance: Float = 0,
        warmth: Float = 0,
        tint: Float = 0,
        sharpness: Float = 0,
        fade: Float = 0,
        grain: Float = 0,
        vignette: Float = 0
    ) {
        self.exposure = Self.clampSigned(exposure)
        self.brilliance = Self.clampSigned(brilliance)
        self.highlights = Self.clampSigned(highlights)
        self.shadows = Self.clampSigned(shadows)
        self.contrast = Self.clampSigned(contrast)
        self.blackPoint = Self.clampSigned(blackPoint)
        self.brightness = Self.clampSigned(brightness)
        self.saturation = Self.clampSigned(saturation)
        self.vibrance = Self.clampSigned(vibrance)
        self.warmth = Self.clampSigned(warmth)
        self.tint = Self.clampSigned(tint)
        self.sharpness = Self.clampSigned(sharpness)
        self.fade = Self.clampPositive(fade)
        self.grain = Self.clampPositive(grain)
        self.vignette = Self.clampPositive(vignette)
    }

    private static func clampSigned(_ value: Float) -> Float {
        min(100, max(-100, value))
    }

    private static func clampPositive(_ value: Float) -> Float {
        min(100, max(0, value))
    }
}
