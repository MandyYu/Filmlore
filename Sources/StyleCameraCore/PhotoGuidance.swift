import CoreGraphics
import Foundation

public enum PhotoGuidanceCategory: String, Codable, CaseIterable, Sendable {
    case composition
    case angle
    case light
    case sharpness
    case style
}

public enum PhotoGuidanceSeverity: String, Codable, CaseIterable, Comparable, Sendable {
    case low
    case medium
    case high

    public static func < (lhs: PhotoGuidanceSeverity, rhs: PhotoGuidanceSeverity) -> Bool {
        lhs.rank < rhs.rank
    }

    private var rank: Int {
        switch self {
        case .low: return 0
        case .medium: return 1
        case .high: return 2
        }
    }
}

public enum PhotoGuidanceIntensity: String, Codable, CaseIterable, Sendable {
    case quiet
    case standard
    case active
}

public struct PhotoGuidanceHint: Codable, Equatable, Sendable {
    public var category: PhotoGuidanceCategory
    public var severity: PhotoGuidanceSeverity
    public var message: String

    public init(
        category: PhotoGuidanceCategory,
        severity: PhotoGuidanceSeverity,
        message: String
    ) {
        self.category = category
        self.severity = severity
        self.message = message
    }
}

public struct PhotoGuidanceSettings: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var intensity: PhotoGuidanceIntensity
    public var compositionEnabled: Bool
    public var angleEnabled: Bool
    public var lightEnabled: Bool
    public var sharpnessEnabled: Bool
    public var styleEnabled: Bool

    public init(
        isEnabled: Bool = true,
        intensity: PhotoGuidanceIntensity = .standard,
        compositionEnabled: Bool = true,
        angleEnabled: Bool = true,
        lightEnabled: Bool = true,
        sharpnessEnabled: Bool = true,
        styleEnabled: Bool = true
    ) {
        self.isEnabled = isEnabled
        self.intensity = intensity
        self.compositionEnabled = compositionEnabled
        self.angleEnabled = angleEnabled
        self.lightEnabled = lightEnabled
        self.sharpnessEnabled = sharpnessEnabled
        self.styleEnabled = styleEnabled
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        intensity = try container.decodeIfPresent(PhotoGuidanceIntensity.self, forKey: .intensity) ?? .standard
        compositionEnabled = try container.decodeIfPresent(Bool.self, forKey: .compositionEnabled) ?? true
        angleEnabled = try container.decodeIfPresent(Bool.self, forKey: .angleEnabled) ?? true
        lightEnabled = try container.decodeIfPresent(Bool.self, forKey: .lightEnabled) ?? true
        sharpnessEnabled = try container.decodeIfPresent(Bool.self, forKey: .sharpnessEnabled) ?? true
        styleEnabled = try container.decodeIfPresent(Bool.self, forKey: .styleEnabled) ?? true
    }
}

public struct PhotoGuidanceSceneAnalysis: Equatable, Sendable {
    public var averageBrightness: Double
    public var overexposedPixelRatio: Double
    public var sharpnessScore: Double
    public var subjectRect: CGRect?
    public var rollDegrees: Double

    public init(
        averageBrightness: Double,
        overexposedPixelRatio: Double,
        sharpnessScore: Double,
        subjectRect: CGRect?,
        rollDegrees: Double
    ) {
        self.averageBrightness = averageBrightness
        self.overexposedPixelRatio = overexposedPixelRatio
        self.sharpnessScore = sharpnessScore
        self.subjectRect = subjectRect
        self.rollDegrees = rollDegrees
    }
}

public struct PhotoGuidanceEngine: Sendable {
    public init() {}

    public func hint(
        for scene: PhotoGuidanceSceneAnalysis,
        styleName: String,
        settings: PhotoGuidanceSettings
    ) -> PhotoGuidanceHint? {
        guard settings.isEnabled else { return nil }

        if settings.lightEnabled,
           let lightHint = lightHint(for: scene, intensity: settings.intensity) {
            return lightHint
        }

        if settings.sharpnessEnabled,
           let sharpnessHint = sharpnessHint(for: scene, intensity: settings.intensity) {
            return sharpnessHint
        }

        if settings.angleEnabled,
           let angleHint = angleHint(for: scene, intensity: settings.intensity) {
            return angleHint
        }

        if settings.compositionEnabled,
           let compositionHint = compositionHint(for: scene, intensity: settings.intensity) {
            return compositionHint
        }

        if settings.styleEnabled {
            return styleHint(for: scene, styleName: styleName)
        }

        return nil
    }

    private func lightHint(
        for scene: PhotoGuidanceSceneAnalysis,
        intensity: PhotoGuidanceIntensity
    ) -> PhotoGuidanceHint? {
        let thresholds = thresholds(for: intensity)
        if scene.overexposedPixelRatio >= thresholds.overexposedRatio || scene.averageBrightness >= thresholds.highBrightness {
            return PhotoGuidanceHint(category: .light, severity: .high, message: "高光过亮")
        }

        if scene.averageBrightness <= thresholds.lowBrightness {
            return PhotoGuidanceHint(category: .light, severity: .medium, message: "光线偏暗")
        }

        return nil
    }

    private func sharpnessHint(
        for scene: PhotoGuidanceSceneAnalysis,
        intensity: PhotoGuidanceIntensity
    ) -> PhotoGuidanceHint? {
        let thresholds = thresholds(for: intensity)
        guard scene.sharpnessScore <= thresholds.lowSharpness else {
            return nil
        }

        return PhotoGuidanceHint(category: .sharpness, severity: .medium, message: "稳住手机")
    }

    private func angleHint(
        for scene: PhotoGuidanceSceneAnalysis,
        intensity: PhotoGuidanceIntensity
    ) -> PhotoGuidanceHint? {
        let thresholds = thresholds(for: intensity)
        guard abs(scene.rollDegrees) >= thresholds.rollDegrees else {
            return nil
        }

        return PhotoGuidanceHint(category: .angle, severity: .medium, message: "保持水平")
    }

    private func compositionHint(
        for scene: PhotoGuidanceSceneAnalysis,
        intensity: PhotoGuidanceIntensity
    ) -> PhotoGuidanceHint? {
        guard let rect = scene.subjectRect else {
            return nil
        }

        let thresholds = thresholds(for: intensity)
        let centerX = rect.midX
        let centerY = rect.midY
        let area = rect.width * rect.height

        if area <= thresholds.tinySubjectArea {
            return PhotoGuidanceHint(category: .composition, severity: .medium, message: "靠近一点")
        }

        if area >= thresholds.largeSubjectArea {
            return PhotoGuidanceHint(category: .composition, severity: .low, message: "后退一点")
        }

        if centerX <= thresholds.leftSubjectCenter {
            return PhotoGuidanceHint(category: .composition, severity: .low, message: "向左一点")
        }

        if centerX >= thresholds.rightSubjectCenter {
            return PhotoGuidanceHint(category: .composition, severity: .low, message: "向右一点")
        }

        if centerY <= thresholds.topSubjectCenter {
            return PhotoGuidanceHint(category: .composition, severity: .low, message: "镜头抬高一点")
        }

        if centerY >= thresholds.bottomSubjectCenter {
            return PhotoGuidanceHint(category: .composition, severity: .low, message: "镜头压低一点")
        }

        return nil
    }

    private func styleHint(
        for scene: PhotoGuidanceSceneAnalysis,
        styleName: String
    ) -> PhotoGuidanceHint? {
        if styleName.contains("食物") {
            if let area = scene.subjectRect.map({ $0.width * $0.height }),
               area < 0.12 {
                return PhotoGuidanceHint(category: .style, severity: .low, message: "食物可以再靠近一点")
            }

            return PhotoGuidanceHint(category: .style, severity: .low, message: "低一点拍更有食欲")
        }

        if styleName.contains("城市") {
            return PhotoGuidanceHint(category: .style, severity: .low, message: "建筑线条尽量放正")
        }

        if styleName.contains("富士") {
            return PhotoGuidanceHint(category: .style, severity: .low, message: "留一点明亮背景")
        }

        if styleName.contains("冷白") {
            return PhotoGuidanceHint(category: .style, severity: .low, message: "脸转向柔和光源")
        }

        return nil
    }

    private func thresholds(for intensity: PhotoGuidanceIntensity) -> Thresholds {
        switch intensity {
        case .quiet:
            return Thresholds(
                lowBrightness: 0.16,
                highBrightness: 0.9,
                overexposedRatio: 0.2,
                lowSharpness: 0.09,
                rollDegrees: 8,
                tinySubjectArea: 0.018,
                largeSubjectArea: 0.58,
                leftSubjectCenter: 0.28,
                rightSubjectCenter: 0.72,
                topSubjectCenter: 0.18,
                bottomSubjectCenter: 0.82
            )
        case .standard:
            return Thresholds(
                lowBrightness: 0.2,
                highBrightness: 0.86,
                overexposedRatio: 0.14,
                lowSharpness: 0.13,
                rollDegrees: 6,
                tinySubjectArea: 0.024,
                largeSubjectArea: 0.52,
                leftSubjectCenter: 0.32,
                rightSubjectCenter: 0.68,
                topSubjectCenter: 0.2,
                bottomSubjectCenter: 0.8
            )
        case .active:
            return Thresholds(
                lowBrightness: 0.26,
                highBrightness: 0.8,
                overexposedRatio: 0.09,
                lowSharpness: 0.18,
                rollDegrees: 4,
                tinySubjectArea: 0.036,
                largeSubjectArea: 0.46,
                leftSubjectCenter: 0.38,
                rightSubjectCenter: 0.62,
                topSubjectCenter: 0.24,
                bottomSubjectCenter: 0.76
            )
        }
    }
}

private struct Thresholds {
    var lowBrightness: Double
    var highBrightness: Double
    var overexposedRatio: Double
    var lowSharpness: Double
    var rollDegrees: Double
    var tinySubjectArea: Double
    var largeSubjectArea: Double
    var leftSubjectCenter: Double
    var rightSubjectCenter: Double
    var topSubjectCenter: Double
    var bottomSubjectCenter: Double
}
