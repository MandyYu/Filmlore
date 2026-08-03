import Foundation

public struct StylePreset: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var params: StyleParams
    public var watermark: WatermarkPreset?
    public var isBuiltIn: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        params: StyleParams,
        watermark: WatermarkPreset? = nil,
        isBuiltIn: Bool = false
    ) {
        self.id = id
        self.name = name
        self.params = params
        self.watermark = watermark
        self.isBuiltIn = isBuiltIn
    }
}

public struct WatermarkPreset: Codable, Equatable, Sendable {
    public var enabled: Bool
    public var mode: WatermarkMode
    public var text: String
    public var position: WatermarkPosition
    public var customPosition: WatermarkAnchor?
    public var opacity: Float
    public var imageData: Data?
    public var imageScale: Float
    public var template: WatermarkTemplate
    public var includeDate: Bool
    public var includeDevice: Bool
    public var includeStyleName: Bool
    public var includeLocation: Bool
    public var locationOverrideText: String
    public var textColor: WatermarkTextColor
    public var visualStyle: WatermarkVisualStyle
    public var effect: WatermarkEffect

    public init(
        enabled: Bool = false,
        mode: WatermarkMode = .manual,
        text: String = "Shot by Me",
        position: WatermarkPosition = .bottomRight,
        customPosition: WatermarkAnchor? = nil,
        opacity: Float = 0.65,
        imageData: Data? = nil,
        imageScale: Float = 0.22,
        template: WatermarkTemplate = .signature,
        includeDate: Bool = true,
        includeDevice: Bool = false,
        includeStyleName: Bool = true,
        includeLocation: Bool = false,
        locationOverrideText: String = "",
        textColor: WatermarkTextColor = .automatic,
        visualStyle: WatermarkVisualStyle = .minimal,
        effect: WatermarkEffect = .shadow
    ) {
        self.enabled = enabled
        self.mode = mode
        self.text = text
        self.position = position
        self.customPosition = customPosition
        self.opacity = min(1, max(0, opacity))
        self.imageData = imageData
        self.imageScale = min(0.6, max(0.08, imageScale))
        self.template = template
        self.includeDate = includeDate
        self.includeDevice = includeDevice
        self.includeStyleName = includeStyleName
        self.includeLocation = includeLocation
        self.locationOverrideText = locationOverrideText
        self.textColor = textColor
        self.visualStyle = visualStyle
        self.effect = effect
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        mode = try container.decodeIfPresent(WatermarkMode.self, forKey: .mode) ?? .manual
        text = try container.decodeIfPresent(String.self, forKey: .text) ?? "Shot by Me"
        position = try container.decodeIfPresent(WatermarkPosition.self, forKey: .position) ?? .bottomRight
        customPosition = try container.decodeIfPresent(WatermarkAnchor.self, forKey: .customPosition)
        let decodedOpacity = try container.decodeIfPresent(Float.self, forKey: .opacity) ?? 0.65
        opacity = min(1, max(0, decodedOpacity))
        imageData = try container.decodeIfPresent(Data.self, forKey: .imageData)
        let decodedImageScale = try container.decodeIfPresent(Float.self, forKey: .imageScale) ?? 0.22
        imageScale = min(0.6, max(0.08, decodedImageScale))
        template = try container.decodeIfPresent(WatermarkTemplate.self, forKey: .template) ?? .signature
        includeDate = try container.decodeIfPresent(Bool.self, forKey: .includeDate) ?? true
        includeDevice = try container.decodeIfPresent(Bool.self, forKey: .includeDevice) ?? false
        includeStyleName = try container.decodeIfPresent(Bool.self, forKey: .includeStyleName) ?? true
        includeLocation = try container.decodeIfPresent(Bool.self, forKey: .includeLocation) ?? false
        locationOverrideText = try container.decodeIfPresent(String.self, forKey: .locationOverrideText) ?? ""
        textColor = try container.decodeIfPresent(WatermarkTextColor.self, forKey: .textColor) ?? .automatic
        visualStyle = try container.decodeIfPresent(WatermarkVisualStyle.self, forKey: .visualStyle) ?? .minimal
        effect = try container.decodeIfPresent(WatermarkEffect.self, forKey: .effect) ?? .shadow
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(enabled, forKey: .enabled)
        try container.encode(mode, forKey: .mode)
        try container.encode(text, forKey: .text)
        try container.encode(position, forKey: .position)
        try container.encodeIfPresent(customPosition, forKey: .customPosition)
        try container.encode(opacity, forKey: .opacity)
        try container.encodeIfPresent(imageData, forKey: .imageData)
        try container.encode(imageScale, forKey: .imageScale)
        try container.encode(template, forKey: .template)
        try container.encode(includeDate, forKey: .includeDate)
        try container.encode(includeDevice, forKey: .includeDevice)
        try container.encode(includeStyleName, forKey: .includeStyleName)
        try container.encode(includeLocation, forKey: .includeLocation)
        try container.encode(locationOverrideText, forKey: .locationOverrideText)
        try container.encode(textColor, forKey: .textColor)
        try container.encode(visualStyle, forKey: .visualStyle)
        try container.encode(effect, forKey: .effect)
    }

    private enum CodingKeys: String, CodingKey {
        case enabled
        case mode
        case text
        case position
        case customPosition
        case opacity
        case imageData
        case imageScale
        case template
        case includeDate
        case includeDevice
        case includeStyleName
        case includeLocation
        case locationOverrideText
        case textColor
        case visualStyle
        case effect
    }

    public func displayText(
        styleName: String,
        deviceName: String,
        locationText: String?,
        dateText: String,
        weekdayText: String = ""
    ) -> String {
        let signature = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let style = includeStyleName ? styleName.trimmingCharacters(in: .whitespacesAndNewlines) : ""
        let device = includeDevice ? deviceName.trimmingCharacters(in: .whitespacesAndNewlines) : ""
        let date = includeDate ? dateText.trimmingCharacters(in: .whitespacesAndNewlines) : ""
        let location: String

        if includeLocation {
            let override = locationOverrideText.trimmingCharacters(in: .whitespacesAndNewlines)
            location = override.isEmpty
                ? (locationText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
                : override
        } else {
            location = ""
        }

        let compact = { (values: [String], separator: String) in
            values.filter { !$0.isEmpty }.joined(separator: separator)
        }
        let lines: [String]

        switch template {
        case .signature:
            lines = [compact([signature, style, device, location, date], " · ")]
        case .travelCard:
            let title = compact([signature, style], "  ")
            let firstLine = title.isEmpty ? "" : "▣ \(title)"
            lines = [firstLine, compact([date, device, location], " | ")]
        case .dateStamp:
            lines = [date, compact([signature, style, location, device], " · ")]
        case .locationCard:
            lines = [location, compact([signature, style, date, device], " · ")]
        case .stacked:
            lines = [
                signature,
                compact([style, location], " · "),
                compact([date, device], " | ")
            ]
        case .centeredTravel:
            let title = compact([signature, style], "  ")
            let decoratedTitle = title.isEmpty ? "" : "— \(title) —"
            lines = [
                decoratedTitle,
                compact([location, device], " · "),
                date.replacingOccurrences(of: ".", with: "-")
            ]
        case .weekdayQuote:
            lines = [
                weekdayText,
                compact([date.replacingOccurrences(of: ".", with: "/"), device], "  "),
                "────────",
                compact([signature, style, location], " · "),
                "────────"
            ]
        }

        return lines.filter { !$0.isEmpty }.joined(separator: "\n")
    }
}

public enum WatermarkMode: String, Codable, CaseIterable, Sendable {
    case manual
    case image
}

public enum WatermarkTemplate: String, Codable, CaseIterable, Sendable {
    case signature
    case travelCard
    case dateStamp
    case locationCard
    case stacked
    case centeredTravel
    case weekdayQuote
}

public struct WatermarkAnchor: Codable, Equatable, Sendable {
    public var x: Float
    public var y: Float

    public init(x: Float, y: Float) {
        self.x = min(1, max(0, x))
        self.y = min(1, max(0, y))
    }
}

public enum WatermarkPosition: String, Codable, CaseIterable, Sendable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
    case bottomCenter
    case custom
}

public enum WatermarkVisualStyle: String, Codable, CaseIterable, Sendable {
    case minimal
    case darkBadge
    case lightBadge
    case film
}

public enum WatermarkTextColor: String, Codable, CaseIterable, Sendable {
    case automatic
    case white
    case black
    case yellow
    case orange
    case blue
    case pink
}

public enum WatermarkEffect: String, Codable, CaseIterable, Sendable {
    case none
    case shadow
    case glow
}

public struct PhotoFramePreset: Codable, Equatable, Sendable {
    public var enabled: Bool
    public var style: PhotoFrameStyle
    public var opacity: Float
    public var borderWidth: Float
    public var cornerRadius: Float
    public var shadowEnabled: Bool
    public var backgroundColor: PhotoFrameBackgroundColor

    public init(
        enabled: Bool = false,
        style: PhotoFrameStyle = .cleanWhite,
        opacity: Float = 1,
        borderWidth: Float = 24,
        cornerRadius: Float = 12,
        shadowEnabled: Bool = true,
        backgroundColor: PhotoFrameBackgroundColor = .white
    ) {
        self.enabled = enabled
        self.style = style
        self.opacity = min(1, max(0, opacity))
        self.borderWidth = min(40, max(4, borderWidth))
        self.cornerRadius = min(30, max(0, cornerRadius))
        self.shadowEnabled = shadowEnabled
        self.backgroundColor = backgroundColor
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        style = try container.decodeIfPresent(PhotoFrameStyle.self, forKey: .style) ?? .cleanWhite
        let decodedOpacity = try container.decodeIfPresent(Float.self, forKey: .opacity) ?? 1
        opacity = min(1, max(0, decodedOpacity))
        let decodedBorderWidth = try container.decodeIfPresent(Float.self, forKey: .borderWidth) ?? 24
        borderWidth = min(40, max(4, decodedBorderWidth))
        let decodedCornerRadius = try container.decodeIfPresent(Float.self, forKey: .cornerRadius) ?? 12
        cornerRadius = min(30, max(0, decodedCornerRadius))
        shadowEnabled = try container.decodeIfPresent(Bool.self, forKey: .shadowEnabled) ?? true
        backgroundColor = try container.decodeIfPresent(PhotoFrameBackgroundColor.self, forKey: .backgroundColor)
            ?? ((style == .cleanBlack || style == .film) ? .black : .white)
    }
}

public enum PhotoFrameStyle: String, Codable, CaseIterable, Sendable {
    case cleanWhite
    case cleanBlack
    case instant
    case film
    case minimal
}

public enum PhotoFrameBackgroundColor: String, Codable, CaseIterable, Sendable {
    case white
    case lightGray
    case black
    case cream
    case pink
    case mint
}
