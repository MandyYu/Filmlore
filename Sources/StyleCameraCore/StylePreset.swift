import Foundation
import UIKit

public struct StylePreset: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var params: StyleParams
    public var isBuiltIn: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        params: StyleParams,
        isBuiltIn: Bool = false
    ) {
        self.id = id
        self.name = name
        self.params = params
        self.isBuiltIn = isBuiltIn
    }
}

/// 普通文字水印中附加的信息，可组合使用；不控制模板中显式声明的字段。
public struct WatermarkContentFields: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let date = Self(rawValue: 1 << 0)
    public static let device = Self(rawValue: 1 << 1)
    public static let styleName = Self(rawValue: 1 << 2)
    public static let location = Self(rawValue: 1 << 3)

    public static let all: Self = [.date, .device, .styleName, .location]
    public static let standard: Self = [.date, .styleName]
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
    public var watermarkScale: Float
    public var template: WatermarkTemplate
    /// 普通文字水印显示的信息，默认日期和风格；[] 表示全部关闭。
    /// 模板底栏中的日期、设备、风格、地点由 insetContent 的字段独立决定。
    public var includedFields: WatermarkContentFields
    public var locationOverrideText: String
    public var textColor: WatermarkTextColor
    public var customTextColorHex: String
    public var font: WatermarkFont
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
        watermarkScale: Float = 1,
        template: WatermarkTemplate = .signature,
        includedFields: WatermarkContentFields = .standard,
        locationOverrideText: String = "",
        textColor: WatermarkTextColor = .automatic,
        customTextColorHex: String = "#FFFFFF",
        font: WatermarkFont = .sourceHanSans,
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
        self.watermarkScale = min(2, max(0.5, watermarkScale))
        self.template = template
        self.includedFields = includedFields
        self.locationOverrideText = locationOverrideText
        self.textColor = textColor
        self.customTextColorHex = customTextColorHex
        self.font = font
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
        let decodedWatermarkScale = try container.decodeIfPresent(Float.self, forKey: .watermarkScale) ?? 1
        watermarkScale = min(2, max(0.5, decodedWatermarkScale))
        template = try container.decodeIfPresent(WatermarkTemplate.self, forKey: .template) ?? .signature
        // Keep the existing JSON format and missing-key defaults for saved templates.
        includedFields = []
        for (key, field) in Self.persistedFields {
            if try container.decodeIfPresent(Bool.self, forKey: key)
                ?? WatermarkContentFields.standard.contains(field) {
                includedFields.insert(field)
            }
        }
        locationOverrideText = try container.decodeIfPresent(String.self, forKey: .locationOverrideText) ?? ""
        textColor = try container.decodeIfPresent(WatermarkTextColor.self, forKey: .textColor) ?? .automatic
        customTextColorHex = try container.decodeIfPresent(String.self, forKey: .customTextColorHex) ?? "#FFFFFF"
        font = try container.decodeIfPresent(WatermarkFont.self, forKey: .font) ?? .sourceHanSans
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
        try container.encode(watermarkScale, forKey: .watermarkScale)
        try container.encode(template, forKey: .template)
        for (key, field) in Self.persistedFields {
            try container.encode(includedFields.contains(field), forKey: key)
        }
        try container.encode(locationOverrideText, forKey: .locationOverrideText)
        try container.encode(textColor, forKey: .textColor)
        try container.encode(customTextColorHex, forKey: .customTextColorHex)
        try container.encode(font, forKey: .font)
        try container.encode(visualStyle, forKey: .visualStyle)
        try container.encode(effect, forKey: .effect)
    }

    private static let persistedFields: [(CodingKeys, WatermarkContentFields)] = [
        (.includeDate, .date), (.includeDevice, .device),
        (.includeStyleName, .styleName), (.includeLocation, .location)
    ]

    private enum CodingKeys: String, CodingKey {
        case enabled
        case mode
        case text
        case position
        case customPosition
        case opacity
        case imageData
        case imageScale
        case watermarkScale
        case template
        case includeDate
        case includeDevice
        case includeStyleName
        case includeLocation
        case locationOverrideText
        case textColor
        case customTextColorHex
        case font
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
        let style = includedFields.contains(.styleName) ? styleName.trimmingCharacters(in: .whitespacesAndNewlines) : ""
        let device = includedFields.contains(.device) ? deviceName.trimmingCharacters(in: .whitespacesAndNewlines) : ""
        let date = includedFields.contains(.date) ? dateText.trimmingCharacters(in: .whitespacesAndNewlines) : ""
        let location: String

        if includedFields.contains(.location) {
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

public enum WatermarkTemplate: String, Codable, CaseIterable, Hashable, Sendable {
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
    case bottom
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
    case custom
}

public enum WatermarkFont: String, Codable, CaseIterable, Sendable {
    case sourceHanSans
    case sourceHanSerif
    case lxgwWenKai
    case smileySans
    case maShanZheng
    case longCang
    case zcoolXiaoWei
    case zcoolKuaiLe
    case dianZiJueJiangHei
    case caveat
    case bebasNeue

    public var displayName: String {
        switch self {
        case .sourceHanSans: return "思源黑体 Source Han Sans SC"
        case .sourceHanSerif: return "思源宋体 Source Han Serif SC"
        case .lxgwWenKai: return "霞鹜文楷 LXGW WenKai"
        case .smileySans: return "得意黑 Smiley Sans"
        case .maShanZheng: return "马善政毛笔楷书 Ma Shan Zheng"
        case .longCang: return "龙藏体 Long Cang"
        case .zcoolXiaoWei: return "站酷小薇体 ZCOOL XiaoWei"
        case .zcoolKuaiLe: return "站酷快乐体 ZCOOL KuaiLe"
        case .dianZiJueJiangHei: return "点字倔强黑"
        case .caveat: return "Caveat"
        case .bebasNeue: return "Bebas Neue"
        }
    }

    public var title: String {
        switch self {
        case .sourceHanSans: return "思源黑体"
        case .sourceHanSerif: return "思源宋体"
        case .lxgwWenKai: return "霞鹜文楷"
        case .smileySans: return "得意黑"
        case .maShanZheng: return "马善政毛笔楷书"
        case .longCang: return "龙藏体"
        case .zcoolXiaoWei: return "站酷小薇体"
        case .zcoolKuaiLe: return "站酷快乐体"
        case .dianZiJueJiangHei: return "点字倔强黑"
        case .caveat: return "Caveat"
        case .bebasNeue: return "Bebas Neue"
        }
    }

    public var englishName: String {
        switch self {
        case .sourceHanSans: return "Source Han Sans SC"
        case .sourceHanSerif: return "Source Han Serif SC"
        case .lxgwWenKai: return "LXGW WenKai"
        case .smileySans: return "Smiley Sans"
        case .maShanZheng: return "Ma Shan Zheng"
        case .longCang: return "Long Cang"
        case .zcoolXiaoWei: return "ZCOOL XiaoWei"
        case .zcoolKuaiLe: return "ZCOOL KuaiLe"
        case .dianZiJueJiangHei: return "ID Jue Jiang Hei"
        case .caveat: return "Caveat"
        case .bebasNeue: return "Bebas Neue"
        }
    }

    public var styleTag: String {
        switch self {
        case .sourceHanSans: return "现代正式"
        case .sourceHanSerif: return "优雅正式"
        case .lxgwWenKai: return "随性手写"
        case .smileySans: return "粗体潮流"
        case .maShanZheng: return "书法张力"
        case .longCang: return "狂放手写"
        case .zcoolXiaoWei: return "纤细文艺"
        case .zcoolKuaiLe: return "活泼可爱"
        case .dianZiJueJiangHei: return "个性硬朗"
        case .caveat: return "英文随写"
        case .bebasNeue: return "窄体硬朗"
        }
    }
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
    public var baseInsets : UIEdgeInsets

    public init(
        enabled: Bool = false,
        style: PhotoFrameStyle = .cleanWhite,
        opacity: Float = 1,
        borderWidth: Float = 24,
        cornerRadius: Float = 12,
        shadowEnabled: Bool = true,
        backgroundColor: PhotoFrameBackgroundColor = .white,
        baseInsets: UIEdgeInsets = .zero
    ) {
        self.enabled = enabled
        self.style = style
        self.opacity = min(1, max(0, opacity))
        self.borderWidth = min(40, max(4, borderWidth))
        self.cornerRadius = min(30, max(0, cornerRadius))
        self.shadowEnabled = shadowEnabled
        self.backgroundColor = backgroundColor
        self.baseInsets = baseInsets
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
        baseInsets = try container.decodeIfPresent(UIEdgeInsets.self, forKey: .baseInsets) ?? .zero
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
