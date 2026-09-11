import Foundation
import StyleCameraCore
import SwiftUI
import UIKit

struct CameraTemplateGalleryView: View {
    @EnvironmentObject private var proAccess: ProAccessManager

    let selectedTemplateID: String?
    let openTemplate: (CameraTemplatePreset) -> Void
    let selectTemplate: (CameraTemplatePreset) -> Void
    let requestUpgrade: () -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 26) {
                ForEach(CameraTemplateCategory.allCases) { category in
                    templateSection(category)
                }
            }
            .padding(.vertical, 18)
        }
        .scrollIndicators(.hidden)
        .background(StyleCameraTheme.screenBackground)
        .navigationTitle("模板")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
    }

    private func templateSection(_ category: CameraTemplateCategory) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(category.title)
                    .font(.title3.weight(.semibold))

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(templates(in: category)) { template in
                        CameraTemplateCard(
                            template: template,
                            isSelected: selectedTemplateID == template.id,
                            isLocked: template.isPro && !proAccess.isProUnlocked,
                            open: {
                                if template.isPro && !proAccess.isProUnlocked {
                                    requestUpgrade()
                                } else {
                                    openTemplate(template)
                                }
                            },
                            select: {
                                guard selectedTemplateID != template.id else { return }
                                if template.isPro && !proAccess.isProUnlocked {
                                    requestUpgrade()
                                } else {
                                    selectTemplate(template)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func templates(in category: CameraTemplateCategory) -> [CameraTemplatePreset] {
        BuiltInCameraTemplates.all.filter { $0.category == category }
    }
}

struct CameraTemplateEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var previewStore: CameraPreviewStore
    let styleName: String
    let locationText: String?
    let save: (CameraTemplatePreset) -> Void

    @State private var draft: CameraTemplatePreset

    init(
        template: CameraTemplatePreset,
        previewStore: CameraPreviewStore,
        styleName: String,
        locationText: String?,
        save: @escaping (CameraTemplatePreset) -> Void
    ) {
        self.previewStore = previewStore
        self.styleName = styleName
        self.locationText = locationText
        self.save = save
        _draft = State(initialValue: template)
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                CameraTemplateArtworkView(
                    template: draft,
                    previewImage: previewStore.image,
                    styleName: styleName,
                    locationText: locationText,
                    usesStaticImage: false
                )
                .frame(maxWidth: .infinity)
                .frame(height: 290)

                HStack(spacing: 6) {
                    Circle()
                        .fill(StyleCameraTheme.cyan)
                        .frame(width: 7, height: 7)
                    Text("实时效果")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(.black.opacity(0.54), in: Capsule())
                .padding(12)
            }
            .clipped()

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    watermarkSection
                }
                .padding(16)
            }
            .scrollIndicators(.hidden)
        }
        .background(StyleCameraTheme.screenGradient)
        .navigationTitle(draft.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: saveDraft) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 32, height: 32)
                }
                .accessibilityLabel("应用模板")
            }
        }
        .tint(StyleCameraTheme.primary)
        .preferredColorScheme(.dark)
    }

    private var watermarkSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("内容样式")
                .font(.headline)

            TemplateEditorPanel {
                TemplateSliderRow(
                    title: "默认字号",
                    value: watermarkScaleBinding,
                    range: 0.5...2,
                    valueText: String(format: "%.1fx", draft.watermark.watermarkScale)
                )

                TemplateTextColorEditor(
                    title: "默认颜色",
                    selection: $draft.watermark.textColor,
                    customHex: $draft.watermark.customTextColorHex
                )

                TemplateFontEditor(
                    title: "默认字体",
                    selection: $draft.watermark.font
                )

                if draft.watermark.position == .bottom {
                    Divider()
                    Text("预设内容")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    CameraTemplateColumnEditor(
                        title: "左侧",
                        column: $draft.insetContent.left
                    )
                    CameraTemplateColumnEditor(
                        title: "中间",
                        column: $draft.insetContent.center
                    )
                    CameraTemplateColumnEditor(
                        title: "右侧",
                        column: $draft.insetContent.right
                    )
                }
            }
        }
    }

    private var watermarkScaleBinding: Binding<Double> {
        Binding(
            get: { Double(draft.watermark.watermarkScale) },
            set: { draft.watermark.watermarkScale = Float($0) }
        )
    }

    private func saveDraft() {
        save(draft)
        dismiss()
    }
}

private struct CameraTemplateCard: View {
    let template: CameraTemplatePreset
    let isSelected: Bool
    let isLocked: Bool
    let open: () -> Void
    let select: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: open) {
                VStack(alignment: .leading, spacing: 0) {
                    CameraTemplateArtworkView(
                        template: template,
                        previewImage: nil,
                        styleName: "富士清新",
                        locationText: "北京",
                        usesStaticImage: true
                    )
                    .frame(width: 240, height: 320)
                    .background(.red)
                    
                    .clipped()

//                    VStack(alignment: .leading, spacing: 3) {
//                        Text(template.name)
//                            .font(.subheadline.weight(.semibold))
//                            .foregroundStyle(.primary)
//                            .lineLimit(1)
//
//                        Text(template.summary)
//                            .font(.caption2)
//                            .foregroundStyle(.secondary)
//                            .lineLimit(1)
//                    }
//                    .padding(10)
//                    .padding(.trailing, 34)
                }
                .frame(width: 240, alignment: .leading)
                .background(StyleCameraTheme.panelBackground)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    if isLocked {
                        Text("PRO")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .frame(height: 23)
                            .background(StyleCameraTheme.warmGradient, in: Capsule())
                            .padding(8)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isLocked ? "解锁模板\(template.name)" : "编辑模板\(template.name)")

            Button(action: select) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isSelected ? StyleCameraTheme.primary : Color.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 2)
            .padding(.top, 4)
            .accessibilityLabel(isSelected ? "已选择\(template.name)" : "选择模板\(template.name)")
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
    }
}

private struct CameraTemplateArtworkView: View {
    let template: CameraTemplatePreset
    let previewImage: UIImage?
    let styleName: String
    let locationText: String?
    let usesStaticImage: Bool

    var body: some View {
        GeometryReader { proxy in
            let artworkRect = artworkRect(in: proxy.size)

            ZStack {
                showsFrameBackground
                    ? template.photoFrame.backgroundColor.templateColor
                    : Color.black

                sampleImage
                    .resizable()
                    .scaledToFill()
                    .frame(width: artworkRect.width, height: artworkRect.height)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: CGFloat(template.photoFrame.cornerRadius) * 0.35,
                            style: .continuous
                        )
                    )
                    .shadow(
                        color: template.photoFrame.shadowEnabled ? .black.opacity(0.34) : .clear,
                        radius: 5,
                        y: 3
                    )
                    .position(x: artworkRect.midX, y: artworkRect.midY)

                if template.photoFrame.enabled && template.photoFrame.style == .minimal {
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Color.white.opacity(0.72), lineWidth: 1)
                        .frame(
                            width: max(1, artworkRect.width - 8),
                            height: max(1, artworkRect.height - 8)
                        )
                        .position(x: artworkRect.midX, y: artworkRect.midY)
                }
//
//                if template.watermark.enabled {
//                    watermarkLabel
//                        .frame(maxWidth: layout.width * 0.88, alignment: watermarkAlignment)
//                        .position(watermarkPosition(in: proxy.size, layout: layout))
//                }
                if template.watermark.enabled {
                    if template.watermark.position == .bottom,
                       template.hasSlotContent,
                       let bandRect = PhotoFrameLayoutMetrics.bottomBandRect(
                           in: proxy.size,
                           preset: template.photoFrame
                       ) {
                        CameraTemplateSlotBarView(
                            template: template,
                            styleName: styleName,
                            locationText: locationText,
                            baseFontSize: CameraTemplateTypography.baseFontSize(in: proxy.size),
                            compact: true
                        )
                        .frame(width: bandRect.width, height: bandRect.height)
                        .position(x: bandRect.midX, y: bandRect.midY)
                    } else {
                        watermarkLabel
                            .frame(maxWidth: artworkRect.width * 0.88, alignment: watermarkAlignment)
                            .position(watermarkPosition(in: proxy.size, layout: artworkRect.size))
                    }
                }
            }
        }
        .background(Color.black)
    }

    private var sampleImage: Image {
        if !usesStaticImage, let previewImage {
            return Image(uiImage: previewImage)
        }
        if let image = UIImage(named: "photo-frame-sample") {
            return Image(uiImage: image)
        }
        return Image(systemName: "photo")
    }

    private var showsFrameBackground: Bool {
        template.photoFrame.shouldRenderFrame
    }
    
    private var watermarkLabel: some View {
        Text(watermarkText)
            .font(.system(size: 10 * CGFloat(template.watermark.watermarkScale), weight: .semibold))
            .multilineTextAlignment(textAlignment)
            .foregroundStyle(
                template.watermark.textColor.templateColor(
                    customHex: template.watermark.customTextColorHex
                )
            )
            .lineLimit(5)
            .minimumScaleFactor(0.52)
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(watermarkBackground)
            .shadow(
                color: template.watermark.effect == .shadow ? .black.opacity(0.68) : .clear,
                radius: 2,
                y: 1
            )
            .opacity(Double(template.watermark.opacity))
    }

    private var watermarkText: String {
        template.watermark.displayText(
            styleName: styleName,
            deviceName: "iPhone 15 Pro",
            locationText: locationText,
            dateText: "2026.08.14",
            weekdayText: "星期五"
        )
    }

    @ViewBuilder
    private var watermarkBackground: some View {
        switch template.watermark.visualStyle {
        case .minimal:
            Color.clear
        case .darkBadge, .film:
            RoundedRectangle(cornerRadius: 5).fill(.black.opacity(0.52))
        case .lightBadge:
            RoundedRectangle(cornerRadius: 5).fill(.white.opacity(0.82))
        }
    }

    private var watermarkAlignment: Alignment {
        switch template.watermark.position {
        case .topLeft, .bottomLeft: return .leading
        case .topRight, .bottomRight: return .trailing
        case .bottomCenter, .custom: return .center
        case .bottom: return .leading
        }
    }

    private var textAlignment: TextAlignment {
        switch template.watermark.position {
        case .topLeft, .bottomLeft: return .leading
        case .topRight, .bottomRight: return .trailing
        case .bottomCenter, .custom: return .center
        case .bottom: return .leading
        }
    }

    private func artworkRect(in size: CGSize) -> CGRect {
        guard template.photoFrame.shouldRenderFrame else {
            return CGRect(origin: .zero, size: size)
        }
        return PhotoFrameLayoutMetrics.make(
            in: size,
            preset: template.photoFrame
        ).contentRect
    }

    private func watermarkPosition(in size: CGSize, layout: CGSize) -> CGPoint {
        let horizontalInset = max(14, (size.width - layout.width) / 2 + 9)
        let verticalInset = max(14, (size.height - layout.height) / 2 + 10)
        switch template.watermark.position {
        case .topLeft:
            return CGPoint(x: horizontalInset + layout.width * 0.35, y: verticalInset + 16)
        case .topRight:
            return CGPoint(x: size.width - horizontalInset - layout.width * 0.35, y: verticalInset + 16)
        case .bottomLeft:
            return CGPoint(x: horizontalInset + layout.width * 0.35, y: size.height - verticalInset - 16)
        case .bottomRight:
            return CGPoint(x: size.width - horizontalInset - layout.width * 0.35, y: size.height - verticalInset - 16)
        case .bottomCenter:
            return CGPoint(x: size.width / 2, y: size.height - verticalInset - 16)
        case .custom:
            let anchor = template.watermark.customPosition ?? WatermarkAnchor(x: 0.5, y: 0.78)
            return CGPoint(x: size.width * CGFloat(anchor.x), y: size.height * CGFloat(anchor.y))
        case .bottom:
            return PhotoFrameLayoutMetrics.bottomBandCenter(
                in: size,
                preset: template.photoFrame
            ) ?? CGPoint(x: size.width / 2, y: size.height - verticalInset - 16)
        }
    }
}

private struct CameraTemplateColumnEditor: View {
    let title: String
    @Binding var column: CameraTemplateContentColumn

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))

            if column.lines.isEmpty {
                Text("此区域无预设内容")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(column.lines.indices, id: \.self) { index in
                    CameraTemplateLineEditor(
                        index: index,
                        line: $column.lines[index]
                    )

                    if index != column.lines.indices.last {
                        Divider()
                    }
                }
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct CameraTemplateLineEditor: View {
    let index: Int
    @Binding var line: CameraTemplateContentLine

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("第 \(index + 1) 行")
                .font(.subheadline.weight(.medium))

            if line.fields.isEmpty {
                Text("本行无预设内容")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(line.fields.indices, id: \.self) { fieldIndex in
                    CameraTemplateSlotEditorRow(
                        index: fieldIndex,
                        slot: $line.fields[fieldIndex]
                    )

                    if fieldIndex != line.fields.indices.last {
                        Divider()
                            .padding(.leading, 12)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}

private struct CameraTemplateSlotEditorRow: View {
    let index: Int
    @Binding var slot: CameraTemplateSlot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("字段 \(index + 1)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 52, alignment: .leading)

                Text(contentTitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }

            if slot.type == .text {
                TemplateOptionalFontEditor(
                    title: "字体",
                    selection: $slot.font
                )
            }

            if slot.type != .none {
                HStack(spacing: 10) {
                    Text("字号")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 42, alignment: .leading)

                    Slider(value: fontScaleBinding, in: 0.5...2.5, step: 0.05)

                    Text(String(format: "%.0f%%", slot.fontScale * 100))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 42, alignment: .trailing)
                }

                TemplateTextColorEditor(
                    title: "颜色",
                    selection: $slot.textColor,
                    customHex: $slot.customTextColorHex
                )
            }
        }
    }

    private var fontScaleBinding: Binding<Double> {
        Binding(
            get: { Double(slot.fontScale) },
            set: { slot.fontScale = Float($0) }
        )
    }

    private var selectedIconTitle: String {
        CityIconName(rawValue: slot.iconName)?.displayName ?? "自定义图标"
    }

    private var contentTitle: String {
        switch slot.type {
        case .none:
            return "空"
        case .icon:
            return "图标 · \(selectedIconTitle)"
        case .text:
            if slot.textSource == .custom {
                let text = slot.customText.trimmingCharacters(in: .whitespacesAndNewlines)
                return text.isEmpty ? "自定义文本" : "文本 · \(text)"
            }
            return "文本 · \(slot.textSource.templateTitle)"
        }
    }
}

private struct TemplateFontEditor: View {
    let title: String
    @Binding var selection: WatermarkFont

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 62, alignment: .leading)

            Menu {
                ForEach(WatermarkFont.allCases, id: \.rawValue) { font in
                    Button(font.displayName) {
                        selection = font
                    }
                }
            } label: {
                TemplateMenuLabel(title: selection.displayName)
                    .font(selection.swiftUIFont(size: 13, weight: .medium))
            }

            Spacer(minLength: 0)
        }
    }
}

private struct TemplateOptionalFontEditor: View {
    let title: String
    @Binding var selection: WatermarkFont?

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 42, alignment: .leading)

            Menu {
                Button("跟随模板") {
                    selection = nil
                }

                Divider()

                ForEach(WatermarkFont.allCases, id: \.rawValue) { font in
                    Button(font.displayName) {
                        selection = font
                    }
                }
            } label: {
                TemplateMenuLabel(title: selection?.displayName ?? "跟随模板")
                    .font((selection ?? .sourceHanSans).swiftUIFont(size: 13, weight: .medium))
            }

            Spacer(minLength: 0)
        }
    }
}

private struct TemplateTextColorEditor: View {
    let title: String
    @Binding var selection: WatermarkTextColor
    @Binding var customHex: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 62, alignment: .leading)

                Menu {
                    ForEach(WatermarkTextColor.allCases, id: \.rawValue) { color in
                        Button(color.templateTitle) {
                            selection = color
                        }
                    }
                } label: {
                    HStack(spacing: 7) {
                        Circle()
                            .fill(selection.templateColor(customHex: customHex))
                            .frame(width: 14, height: 14)
                            .overlay {
                                Circle().stroke(Color.white.opacity(0.2), lineWidth: 1)
                            }
                        Text(selection.templateTitle)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                    }
                    .font(.caption)
                }

                Spacer(minLength: 0)
            }

            if selection == .custom {
                HStack(spacing: 10) {
                    ColorPicker("", selection: customColorBinding, supportsOpacity: false)
                        .labelsHidden()
                        .frame(width: 32)

                    TextField("#RRGGBB", text: $customHex)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.caption.monospaced())
                }
                .padding(.leading, 72)
            }
        }
    }

    private var customColorBinding: Binding<Color> {
        Binding(
            get: { Color(watermarkHex: customHex) ?? .white },
            set: { customHex = UIColor($0).watermarkHexString }
        )
    }
}

private struct TemplateEditorPanel<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(14)
        .background(StyleCameraTheme.panelBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(StyleCameraTheme.divider.opacity(0.78), lineWidth: 1)
        }
    }
}

private struct TemplateMenuLabel: View {
    let title: String

    var body: some View {
        HStack(spacing: 5) {
            Text(title)
                .lineLimit(1)
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption2)
        }
        .foregroundStyle(StyleCameraTheme.primary)
    }
}

private struct TemplateSliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let valueText: String

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.subheadline)
                .frame(width: 64, alignment: .leading)

            Slider(value: $value, in: range)

            Text(valueText)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 42, alignment: .trailing)
        }
    }
}

private extension WatermarkTemplate {
    var templateTitle: String {
        switch self {
        case .signature: return "单行签名"
        case .travelCard: return "旅拍卡片"
        case .dateStamp: return "日期印章"
        case .locationCard: return "地点卡片"
        case .stacked: return "分层信息"
        case .centeredTravel: return "居中旅拍"
        case .weekdayQuote: return "星期札记"
        }
    }
}

private extension WatermarkPosition {
    var templateTitle: String {
        switch self {
        case .topLeft: return "左上"
        case .topRight: return "右上"
        case .bottomLeft: return "左下"
        case .bottomRight: return "右下"
        case .bottomCenter: return "底部居中"
        case .bottom: return "底部留白"
        case .custom: return "自定义"
        }
    }
}

private extension CameraTemplateSlotType {
    var templateTitle: String {
        switch self {
        case .none: return "无"
        case .icon: return "图标"
        case .text: return "文本"
        }
    }
}

private extension CameraTemplateTextSource {
    var templateTitle: String {
        switch self {
        case .custom: return "自定义"
        case .signature: return "签名"
        case .location: return "位置"
        case .date: return "日期"
        case .weekday: return "星期"
        case .device: return "设备"
        case .styleName: return "当前风格"
        }
    }
}

private extension WatermarkTextColor {
    var templateTitle: String {
        switch self {
        case .automatic: return "跟随模板"
        case .white: return "白色"
        case .black: return "黑色"
        case .yellow: return "黄色"
        case .orange: return "橙色"
        case .blue: return "蓝色"
        case .pink: return "粉色"
        case .custom: return "自定义"
        }
    }

    func templateColor(customHex: String) -> Color {
        switch self {
        case .automatic, .white: return .white
        case .black: return .black
        case .yellow: return .yellow
        case .orange: return StyleCameraTheme.orange
        case .blue: return StyleCameraTheme.accentBlue
        case .pink: return StyleCameraTheme.primary
        case .custom: return Color(watermarkHex: customHex) ?? .white
        }
    }
}

private extension Color {
    init?(watermarkHex: String) {
        let value = watermarkHex
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        guard value.count == 6, let rgb = UInt64(value, radix: 16) else {
            return nil
        }
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}

private extension UIColor {
    var watermarkHexString: String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return "#FFFFFF"
        }
        return String(
            format: "#%02X%02X%02X",
            Int(round(red * 255)),
            Int(round(green * 255)),
            Int(round(blue * 255))
        )
    }
}

private extension PhotoFrameStyle {
    var templateTitle: String {
        switch self {
        case .cleanWhite: return "拍立得"
        case .cleanBlack: return "经典"
        case .instant: return "上下"
        case .film: return "底部"
        case .minimal: return "取景框"
        }
    }

    var templateSampleImageName: String {
        switch self {
        case .cleanWhite: return "frame-style-1"
        case .cleanBlack: return "frame-style-2"
        case .instant: return "frame-style-3"
        case .film: return "frame-style-4"
        case .minimal: return "frame-style-5"
        }
    }
}

private extension PhotoFrameBackgroundColor {
    var templateColor: Color {
        switch self {
        case .white: return Color(red: 0.996, green: 0.996, blue: 0.996)
        case .lightGray: return Color(red: 0.94, green: 0.94, blue: 0.95)
        case .black: return Color(white: 0.03)
        case .cream: return Color(red: 0.996, green: 0.93, blue: 0.86)
        case .pink: return Color(red: 0.98, green: 0.82, blue: 0.87)
        case .mint: return Color(red: 0.79, green: 0.93, blue: 0.87)
        }
    }
}


#Preview("模板列表") {
    NavigationStack {
        CameraTemplateGalleryView(
            selectedTemplateID: "classic-travel",
            openTemplate: { _ in },
            selectTemplate: { _ in },
            requestUpgrade: {}
        )
    }
    .environmentObject(ProAccessManager())
}

#Preview("模板编辑") {
    NavigationStack {
        CameraTemplateEditorView(
            template: BuiltInCameraTemplates.all[0],
            previewStore: CameraPreviewStore(),
            styleName: "富士清新",
            locationText: "北京",
            save: { _ in }
        )
    }
}
