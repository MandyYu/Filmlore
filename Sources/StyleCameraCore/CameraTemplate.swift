import Foundation
import UIKit

public enum CameraTemplateCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case classicWatermark
    case colorWalk
    case frames
    case personal
    case minimalFrame
    case personalFrame
    case seasonalFrame

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .classicWatermark: return "经典水印"
        case .colorWalk: return "Color walk"
        case .frames: return "相框"
        case .personal: return "个人水印"
        case .minimalFrame: return "极简边框"
        case .personalFrame: return "个人边框"
        case .seasonalFrame: return "时节边框"
        }
    }
}

public enum CameraTemplateSlotType: String, Codable, CaseIterable, Sendable {
    case none
    case icon
    case text
}

public enum CameraTemplateTextSource: String, Codable, CaseIterable, Sendable {
    case custom
    case signature
    case location
    case date
    case weekday
    case device
    case styleName
}

public enum CityIconName: String, CaseIterable, Codable, Sendable {
    case beijing = "city_beijing"
    case shanghai = "city_shanghai"
    case guangzhou = "city_guangzhou"
    case shenzhen = "city_shenzhen"
    case tianjin = "city_tianjin"
    case chongqing = "city_chongqing"
    case suzhou = "city_suzhou"
    case hangzhou = "city_hangzhou"
    case wuhan = "city_wuhan"
    case chengdu = "city_chengdu"
    case xian = "city_xian"
    case lhasa = "city_lhasa"
    case taipei = "city_taipei"
    case shenyang = "city_shenyang"
    case nanjing = "city_nanjing"
    case qingdao = "city_qingdao"
    case zhengzhou = "city_zhengzhou"
    case changsha = "city_changsha"
    case harbin = "city_harbin"
    case hongkong = "city_hongkong"
    case macau = "city_macau"
    case urumqi = "city_urumqi"
    case kunming = "city_kunming"
    case lanzhou = "city_lanzhou"
    case nanchang = "city_nanchang"

    public var assetName: String { rawValue }

    public var displayName: String {
        switch self {
        case .beijing: return "北京"
        case .shanghai: return "上海"
        case .guangzhou: return "广州"
        case .shenzhen: return "深圳"
        case .tianjin: return "天津"
        case .chongqing: return "重庆"
        case .suzhou: return "苏州"
        case .hangzhou: return "杭州"
        case .wuhan: return "武汉"
        case .chengdu: return "成都"
        case .xian: return "西安"
        case .lhasa: return "拉萨"
        case .taipei: return "台北"
        case .shenyang: return "沈阳"
        case .nanjing: return "南京"
        case .qingdao: return "青岛"
        case .zhengzhou: return "郑州"
        case .changsha: return "长沙"
        case .harbin: return "哈尔滨"
        case .hongkong: return "香港"
        case .macau: return "澳门"
        case .urumqi: return "乌鲁木齐"
        case .kunming: return "昆明"
        case .lanzhou: return "兰州"
        case .nanchang: return "南昌"
        }
    }
}

public struct CameraTemplateSlot: Codable, Equatable, Sendable {
    public var type: CameraTemplateSlotType
    public var iconName: String
    public var textSource: CameraTemplateTextSource
    public var customText: String
    public var fontScale: Float
    public var textColor: WatermarkTextColor
    public var customTextColorHex: String
    public var font: WatermarkFont?

    public init(
        type: CameraTemplateSlotType = .none,
        iconName: String = "camera.fill",
        textSource: CameraTemplateTextSource = .custom,
        customText: String = "",
        fontScale: Float = 1,
        textColor: WatermarkTextColor = .automatic,
        customTextColorHex: String = "#FFFFFF",
        font: WatermarkFont? = nil
    ) {
        self.type = type
        self.iconName = iconName
        self.textSource = textSource
        self.customText = customText
        self.fontScale = min(2.5, max(0.5, fontScale))
        self.textColor = textColor
        self.customTextColorHex = customTextColorHex
        self.font = font
    }

    public static var empty: CameraTemplateSlot {
        CameraTemplateSlot()
    }

    public static func icon(
        _ name: String,
        fontScale: Float = 1,
        textColor: WatermarkTextColor = .automatic,
        customTextColorHex: String = "#FFFFFF",
        font: WatermarkFont? = nil
    ) -> CameraTemplateSlot {
        CameraTemplateSlot(
            type: .icon,
            iconName: name,
            fontScale: fontScale,
            textColor: textColor,
            customTextColorHex: customTextColorHex,
            font: font
        )
    }

    public static func cityIcon(
        _ city: CityIconName,
        fontScale: Float = 1,
        textColor: WatermarkTextColor = .automatic,
        customTextColorHex: String = "#FFFFFF",
        font: WatermarkFont? = nil
    ) -> CameraTemplateSlot {
        icon(
            city.assetName,
            fontScale: fontScale,
            textColor: textColor,
            customTextColorHex: customTextColorHex,
            font: font
        )
    }

    public static func icon(
        _ city: CityIconName,
        fontScale: Float = 1,
        textColor: WatermarkTextColor = .automatic,
        customTextColorHex: String = "#FFFFFF",
        font: WatermarkFont? = nil
    ) -> CameraTemplateSlot {
        cityIcon(
            city,
            fontScale: fontScale,
            textColor: textColor,
            customTextColorHex: customTextColorHex,
            font: font
        )
    }

    public static func text(
        _ source: CameraTemplateTextSource,
        customText: String = "",
        fontScale: Float = 1,
        textColor: WatermarkTextColor = .automatic,
        customTextColorHex: String = "#FFFFFF",
        font: WatermarkFont? = nil
    ) -> CameraTemplateSlot {
        CameraTemplateSlot(
            type: .text,
            textSource: source,
            customText: customText,
            fontScale: fontScale,
            textColor: textColor,
            customTextColorHex: customTextColorHex,
            font: font
        )
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case iconName
        case textSource
        case customText
        case fontScale
        case textColor
        case customTextColorHex
        case font
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decodeIfPresent(CameraTemplateSlotType.self, forKey: .type) ?? .none
        iconName = try container.decodeIfPresent(String.self, forKey: .iconName) ?? "camera.fill"
        textSource = try container.decodeIfPresent(CameraTemplateTextSource.self, forKey: .textSource) ?? .custom
        customText = try container.decodeIfPresent(String.self, forKey: .customText) ?? ""
        let decodedScale = try container.decodeIfPresent(Float.self, forKey: .fontScale) ?? 1
        fontScale = min(2.5, max(0.5, decodedScale))
        textColor = try container.decodeIfPresent(WatermarkTextColor.self, forKey: .textColor) ?? .automatic
        customTextColorHex = try container.decodeIfPresent(String.self, forKey: .customTextColorHex) ?? "#FFFFFF"
        font = try container.decodeIfPresent(WatermarkFont.self, forKey: .font)
    }
}

public struct CameraTemplateContentLine: Codable, Equatable, Sendable {
    public var fields: [CameraTemplateSlot]

    public init(fields: [CameraTemplateSlot] = []) {
        self.fields = fields
    }

    public static var empty: CameraTemplateContentLine {
        CameraTemplateContentLine()
    }

    public static func single(_ field: CameraTemplateSlot) -> CameraTemplateContentLine {
        CameraTemplateContentLine(fields: [field])
    }

    public var hasContent: Bool {
        fields.contains { $0.type != .none }
    }

    public var usesLocation: Bool {
        fields.contains { $0.type == .text && $0.textSource == .location }
    }
}

public struct CameraTemplateContentColumn: Codable, Equatable, Sendable {
    public var lines: [CameraTemplateContentLine]

    public init(lines: [CameraTemplateContentLine] = []) {
        self.lines = lines
    }

    // Source compatibility for presets created before inline fields were supported.
    public init(items: [CameraTemplateSlot]) {
        lines = items.map(CameraTemplateContentLine.single)
    }

    public static var empty: CameraTemplateContentColumn {
        CameraTemplateContentColumn()
    }

    public static func single(_ field: CameraTemplateSlot) -> CameraTemplateContentColumn {
        CameraTemplateContentColumn(lines: [.single(field)])
    }

    public var hasContent: Bool {
        lines.contains { $0.hasContent }
    }

    public var usesLocation: Bool {
        lines.contains { $0.usesLocation }
    }

    private enum CodingKeys: String, CodingKey {
        case lines
        case items
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if container.contains(.lines) {
            lines = try container.decodeIfPresent(
                [CameraTemplateContentLine].self,
                forKey: .lines
            ) ?? []
            return
        }
        if container.contains(.items) {
            let legacyItems = try container.decodeIfPresent(
                [CameraTemplateSlot].self,
                forKey: .items
            ) ?? []
            lines = legacyItems.map(CameraTemplateContentLine.single)
            return
        }
        throw DecodingError.keyNotFound(
            CodingKeys.lines,
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Expected template content lines or legacy items."
            )
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(lines, forKey: .lines)
    }
}

public struct CameraTemplateInsetContent: Codable, Equatable, Sendable {
    public var left: CameraTemplateContentColumn
    public var center: CameraTemplateContentColumn
    public var right: CameraTemplateContentColumn

    public init(
        left: CameraTemplateContentColumn = .empty,
        center: CameraTemplateContentColumn = .empty,
        right: CameraTemplateContentColumn = .empty
    ) {
        self.left = left
        self.center = center
        self.right = right
    }

    public static var empty: CameraTemplateInsetContent {
        CameraTemplateInsetContent()
    }

    public var columns: [CameraTemplateContentColumn] {
        [left, center, right]
    }

    public var hasContent: Bool {
        columns.contains { $0.hasContent }
    }

    public var usesLocation: Bool {
        columns.contains { $0.usesLocation }
    }

    private enum CodingKeys: String, CodingKey {
        case left
        case center
        case right
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        left = Self.decodeColumn(from: container, forKey: .left)
        center = Self.decodeColumn(from: container, forKey: .center)
        right = Self.decodeColumn(from: container, forKey: .right)
    }

    private static func decodeColumn(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) -> CameraTemplateContentColumn {
        if let column = try? container.decode(CameraTemplateContentColumn.self, forKey: key) {
            return column
        }
        if let legacySlot = try? container.decode(CameraTemplateSlot.self, forKey: key) {
            return .single(legacySlot)
        }
        return .empty
    }
}

public enum ResolvedCameraTemplateSlot: Equatable, Sendable {
    case empty
    case icon(String)
    case text(String)

    public var isEmpty: Bool {
        if case .empty = self { return true }
        return false
    }
}

public struct CameraTemplatePreset: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public var name: String
    public var summary: String
    public var category: CameraTemplateCategory
    public var watermark: WatermarkPreset
    public var photoFrame: PhotoFramePreset
    public var insetContent: CameraTemplateInsetContent
    public var isPro: Bool

    public init(
        id: String,
        name: String,
        summary: String,
        category: CameraTemplateCategory,
        watermark: WatermarkPreset,
        photoFrame: PhotoFramePreset,
        insetContent: CameraTemplateInsetContent = .empty,
        isPro: Bool = false
    ) {
        self.id = id
        self.name = name
        self.summary = summary
        self.category = category
        self.watermark = watermark
        self.photoFrame = photoFrame
        self.insetContent = insetContent
        self.isPro = isPro
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case summary
        case category
        case watermark
        case photoFrame
        case insetContent
        // Legacy keys are decoded for migration only.
        case left
        case center
        case right
        case isPro
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        summary = try container.decode(String.self, forKey: .summary)
        category = try container.decode(CameraTemplateCategory.self, forKey: .category)
        watermark = try container.decode(WatermarkPreset.self, forKey: .watermark)
        photoFrame = try container.decode(PhotoFramePreset.self, forKey: .photoFrame)
        if let decodedContent = try container.decodeIfPresent(
            CameraTemplateInsetContent.self,
            forKey: .insetContent
        ) {
            insetContent = decodedContent
        } else {
            insetContent = CameraTemplateInsetContent(
                left: .single(try container.decodeIfPresent(CameraTemplateSlot.self, forKey: .left) ?? .empty),
                center: .single(try container.decodeIfPresent(CameraTemplateSlot.self, forKey: .center) ?? .empty),
                right: .single(try container.decodeIfPresent(CameraTemplateSlot.self, forKey: .right) ?? .empty)
            )
        }
        isPro = try container.decodeIfPresent(Bool.self, forKey: .isPro) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(summary, forKey: .summary)
        try container.encode(category, forKey: .category)
        try container.encode(watermark, forKey: .watermark)
        try container.encode(photoFrame, forKey: .photoFrame)
        try container.encode(insetContent, forKey: .insetContent)
        try container.encode(isPro, forKey: .isPro)
    }

    public var hasSlotContent: Bool {
        insetContent.hasContent
    }

    public var usesLocation: Bool {
        watermark.includeLocation
            || insetContent.usesLocation
    }

    public func resolvedSlot(
        _ slot: CameraTemplateSlot,
        styleName: String,
        deviceName: String,
        locationText: String?,
        dateText: String,
        weekdayText: String = ""
    ) -> ResolvedCameraTemplateSlot {
        switch slot.type {
        case .none:
            return .empty
        case .icon:
            let iconName = slot.iconName.trimmingCharacters(in: .whitespacesAndNewlines)
            return iconName.isEmpty ? .empty : .icon(iconName)
        case .text:
            let value: String
            switch slot.textSource {
            case .custom:
                value = slot.customText
            case .signature:
                value = watermark.text
            case .location:
                let override = watermark.locationOverrideText.trimmingCharacters(in: .whitespacesAndNewlines)
                value = override.isEmpty ? (locationText ?? "") : override
            case .date:
                value = dateText
            case .weekday:
                value = weekdayText
            case .device:
                value = deviceName
            case .styleName:
                value = styleName
            }

            let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? .empty : .text(text)
        }
    }
}

public enum BuiltInCameraTemplates {
    public static let all: [CameraTemplatePreset] = [
        CameraTemplatePreset(
            id: "minimal-travel",
            name: "旅拍记录",
            summary: "日期、设备与地点",
            category: .minimalFrame,
            watermark: WatermarkPreset(
                enabled: true,
                text: "我的旅拍",
                position: .bottom,
                opacity: 0.84,
                watermarkScale: 0.9,
                template: .travelCard,
                includeDate: true,
                includeDevice: true,
                includeStyleName: true,
                includeLocation: true,
                textColor: .black,
                font: .sourceHanSans,
                visualStyle: .darkBadge,
                effect: .none
            ),
            photoFrame: PhotoFramePreset(
                enabled: true,
                cornerRadius: 0,
                shadowEnabled: false,
                baseInsets : UIEdgeInsets(
                     top: 20,
                     left: 20,
                     bottom: 20,
                     right: 20
                 )
            ),
            insetContent: CameraTemplateInsetContent(
                
                center: .single(.text(.signature)),
                
            )
        ),
        CameraTemplatePreset(
            id: "classic-travel",
            name: "旅拍记录",
            summary: "日期、设备与地点",
            category: .classicWatermark,
            watermark: WatermarkPreset(
                enabled: true,
                text: "我的旅拍",
                position: .bottom,
                opacity: 0.84,
                watermarkScale: 0.9,
                template: .travelCard,
                includeDate: true,
                includeDevice: true,
                includeStyleName: true,
                includeLocation: true,
                textColor: .black,
                font: .sourceHanSans,
                visualStyle: .darkBadge,
                effect: .none
            ),
            photoFrame: PhotoFramePreset(
                enabled: true,
                cornerRadius: 0,
                shadowEnabled: false,
                baseInsets : UIEdgeInsets(
                     top: 0,
                     left: 0,
                     bottom: 100,
                     right: 0
                 )
            ),
            insetContent: CameraTemplateInsetContent(
                left: .single(.icon(
                    .beijing,
                    fontScale: 1.2,
                    textColor: .black
                )),
//                center: .single(.text(.signature)),
                right: CameraTemplateContentColumn(lines: [
                    CameraTemplateContentLine(fields: [
                        .text(.location, fontScale: 1.05, textColor: .blue),
                        .text(.custom, customText: "|", fontScale: 0.82, textColor: .blue),
                        .text(.date, fontScale: 1.05, textColor: .blue)
                    ]),
//                    CameraTemplateContentLine(fields: [
//                        .text(.location, fontScale: 1.05),
//                        .text(.custom, customText: "|", fontScale: 0.82),
//                        .text(.date, fontScale: 1.05)
//                    ])
                ])
            )
        ),
        CameraTemplatePreset(
            id: "classic-leica",
            name: "经典铭牌",
            summary: "底部留白与相机参数",
            category: .classicWatermark,
            watermark: WatermarkPreset(
                enabled: true,
                text: "STYLECAMERA",
                position: .bottom,
                opacity: 0.76,
                watermarkScale: 0.82,
                template: .dateStamp,
                includeDate: true,
                includeDevice: true,
                includeStyleName: false,
                includeLocation: false,
                textColor: .black,
                font: .bebasNeue,
                visualStyle: .minimal,
                effect: .none
            ),
            photoFrame: PhotoFramePreset(
                enabled: true,
                style: .film,
                borderWidth: 22,
                cornerRadius: 0,
                shadowEnabled: false,
                backgroundColor: .white,
                baseInsets : UIEdgeInsets(
                     top: 0,
                     left: 0,
                     bottom: 80,
                     right: 0
                 )
            ),
            insetContent: CameraTemplateInsetContent(
                left: .single(.icon(
                    .beijing,
                    fontScale: 1.4,
                    textColor: .orange
                )),
                center: .single(.text(.signature)),
                right: CameraTemplateContentColumn(lines: [
                    CameraTemplateContentLine(fields: [
                        .text(.location, fontScale: 1.05,textColor: .blue),
                        .text(.custom, customText: "|", fontScale: 0.82, textColor: .blue),
                        .text(.date, fontScale: 1.05, textColor: .blue)
                    ])
                ])
            )
        ),
        
        CameraTemplatePreset(
            id: "classic-leicax",
            name: "经典铭牌",
            summary: "底部留白与相机参数",
            category: .classicWatermark,
            watermark: WatermarkPreset(
                enabled: true,
                text: "STYLECAMERA",
                position: .bottom,
                opacity: 0.76,
                watermarkScale: 0.82,
                template: .dateStamp,
                includeDate: true,
                includeDevice: true,
                includeStyleName: false,
                includeLocation: false,
                textColor: .black,
                font: .bebasNeue,
                visualStyle: .minimal,
                effect: .none
            ),
            photoFrame: PhotoFramePreset(
                enabled: true,
                style: .film,
                borderWidth: 22,
                cornerRadius: 0,
                shadowEnabled: false,
                backgroundColor: .white,
                baseInsets : UIEdgeInsets(
                     top: 30,
                     left: 30,
                     bottom: 30,
                     right: 30
                 )
            ),
            insetContent: CameraTemplateInsetContent(
                left: .single(.icon(
                    .beijing,
                    fontScale: 1.4,
                    textColor: .orange
                )),
                center: .single(.text(.signature)),
                right: CameraTemplateContentColumn(lines: [
                    CameraTemplateContentLine(fields: [
                        .text(.location, fontScale: 1.05,textColor: .blue),
                        .text(.custom, customText: "|", fontScale: 0.82, textColor: .blue),
                        .text(.date, fontScale: 1.05, textColor: .blue)
                    ])
                ])
            )
        ),
        CameraTemplatePreset(
            id: "classic-date",
            name: "日期札记",
            summary: "简洁日期与签名",
            category: .classicWatermark,
            watermark: WatermarkPreset(
                enabled: true,
                text: "DAILY MOMENT",
                position: .bottomCenter,
                opacity: 0.78,
                watermarkScale: 0.86,
                template: .dateStamp,
                includeDate: true,
                includeDevice: false,
                includeStyleName: false,
                includeLocation: true,
                textColor: .white,
                font: .caveat,
                visualStyle: .minimal,
                effect: .shadow
            ),
            photoFrame: PhotoFramePreset(enabled: false),
            isPro: true
        ),
        CameraTemplatePreset(
            id: "color-olive",
            name: "橄榄漫步",
            summary: "留白与自然记录",
            category: .colorWalk,
            watermark: WatermarkPreset(
                enabled: true,
                text: "Stay alive · keep trying",
                position: .topLeft,
                opacity: 0.82,
                watermarkScale: 0.82,
                template: .signature,
                includeDate: true,
                includeDevice: false,
                includeStyleName: false,
                includeLocation: false,
                textColor: .white,
                font: .caveat,
                visualStyle: .minimal,
                effect: .shadow
            ),
            photoFrame: PhotoFramePreset(
                enabled: true,
                style: .instant,
                borderWidth: 28,
                cornerRadius: 0,
                shadowEnabled: false,
                backgroundColor: .mint
            )
        ),
        CameraTemplatePreset(
            id: "color-ocean",
            name: "海岸蓝",
            summary: "清爽蓝调留白",
            category: .colorWalk,
            watermark: WatermarkPreset(
                enabled: true,
                text: "SUMMER WALK",
                position: .topRight,
                opacity: 0.78,
                watermarkScale: 0.78,
                template: .locationCard,
                includeDate: true,
                includeDevice: false,
                includeStyleName: false,
                includeLocation: true,
                textColor: .white,
                font: .sourceHanSans,
                visualStyle: .minimal,
                effect: .shadow
            ),
            photoFrame: PhotoFramePreset(
                enabled: true,
                style: .instant,
                borderWidth: 26,
                cornerRadius: 0,
                shadowEnabled: false,
                backgroundColor: .lightGray
            ),
            isPro: true
        ),
        CameraTemplatePreset(
            id: "color-coral",
            name: "落日珊瑚",
            summary: "暖色留白与短句",
            category: .colorWalk,
            watermark: WatermarkPreset(
                enabled: true,
                text: "GOOD DAY",
                position: .topRight,
                opacity: 0.82,
                watermarkScale: 0.82,
                template: .signature,
                includeDate: true,
                includeDevice: false,
                includeStyleName: false,
                includeLocation: false,
                textColor: .white,
                font: .smileySans,
                visualStyle: .minimal,
                effect: .shadow
            ),
            photoFrame: PhotoFramePreset(
                enabled: true,
                style: .instant,
                borderWidth: 30,
                cornerRadius: 0,
                shadowEnabled: false,
                backgroundColor: .pink
            ),
            isPro: true
        ),
        CameraTemplatePreset(
            id: "frame-polaroid",
            name: "拍立得",
            summary: "经典下方留白",
            category: .frames,
            watermark: WatermarkPreset(
                enabled: true,
                text: "StyleCamera",
                position: .bottomCenter,
                opacity: 0.72,
                watermarkScale: 0.82,
                template: .signature,
                includeDate: true,
                includeDevice: false,
                includeStyleName: false,
                includeLocation: false,
                textColor: .black,
                font: .caveat,
                visualStyle: .minimal,
                effect: .none
            ),
            photoFrame: PhotoFramePreset(
                enabled: true,
                style: .cleanWhite,
                borderWidth: 26,
                cornerRadius: 2,
                shadowEnabled: true,
                backgroundColor: .white
            )
        ),
        CameraTemplatePreset(
            id: "frame-film",
            name: "胶片边框",
            summary: "深色胶片质感",
            category: .frames,
            watermark: WatermarkPreset(
                enabled: true,
                text: "STYLECAMERA · 12",
                position: .bottomCenter,
                opacity: 0.72,
                watermarkScale: 0.74,
                template: .signature,
                includeDate: false,
                includeDevice: false,
                includeStyleName: false,
                includeLocation: false,
                textColor: .orange,
                font: .bebasNeue,
                visualStyle: .minimal,
                effect: .none
            ),
            photoFrame: PhotoFramePreset(
                enabled: true,
                style: .cleanBlack,
                borderWidth: 24,
                cornerRadius: 2,
                shadowEnabled: true,
                backgroundColor: .black
            ),
            isPro: true
        ),
        CameraTemplatePreset(
            id: "frame-viewfinder",
            name: "取景框",
            summary: "轻量角标取景线",
            category: .frames,
            watermark: WatermarkPreset(enabled: false),
            photoFrame: PhotoFramePreset(
                enabled: true,
                style: .minimal,
                borderWidth: 12,
                cornerRadius: 0,
                shadowEnabled: false,
                backgroundColor: .white
            ),
            isPro: true
        ),
        CameraTemplatePreset(
            id: "personal-name",
            name: "摄影师签名",
            summary: "姓名、地点与日期",
            category: .personal,
            watermark: WatermarkPreset(
                enabled: true,
                text: "PHOTOGRAPHER",
                position: .bottomLeft,
                opacity: 0.84,
                watermarkScale: 0.9,
                template: .stacked,
                includeDate: true,
                includeDevice: false,
                includeStyleName: true,
                includeLocation: true,
                textColor: .white,
                font: .sourceHanSerif,
                visualStyle: .darkBadge,
                effect: .shadow
            ),
            photoFrame: PhotoFramePreset(enabled: false)
        ),
        CameraTemplatePreset(
            id: "personal-postcard",
            name: "旅行明信片",
            summary: "居中标题与地点",
            category: .personal,
            watermark: WatermarkPreset(
                enabled: true,
                text: "我的旅拍",
                position: .bottomCenter,
                opacity: 0.86,
                watermarkScale: 0.92,
                template: .centeredTravel,
                includeDate: true,
                includeDevice: false,
                includeStyleName: false,
                includeLocation: true,
                textColor: .black,
                font: .sourceHanSerif,
                visualStyle: .lightBadge,
                effect: .none
            ),
            photoFrame: PhotoFramePreset(
                enabled: true,
                style: .cleanWhite,
                borderWidth: 22,
                cornerRadius: 0,
                shadowEnabled: false,
                backgroundColor: .white
            ),
            isPro: true
        ),
        CameraTemplatePreset(
            id: "personal-weekday",
            name: "星期札记",
            summary: "日期、短句与签名",
            category: .personal,
            watermark: WatermarkPreset(
                enabled: true,
                text: "勇往直前 不畏艰险",
                position: .bottomLeft,
                opacity: 0.82,
                watermarkScale: 0.88,
                template: .weekdayQuote,
                includeDate: true,
                includeDevice: false,
                includeStyleName: false,
                includeLocation: false,
                textColor: .white,
                font: .maShanZheng,
                visualStyle: .darkBadge,
                effect: .shadow
            ),
            photoFrame: PhotoFramePreset(enabled: false),
            isPro: true
        )
    ]

    public static func preset(id: String) -> CameraTemplatePreset? {
        all.first { $0.id == id }
    }
}
