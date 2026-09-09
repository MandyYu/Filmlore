import CoreImage
import StyleCameraCore
import SwiftUI
import UIKit

enum CameraTemplateTypography {
    static let baseFontRatio: CGFloat = 0.026

    static func baseFontSize(in size: CGSize) -> CGFloat {
        max(1, min(size.width, size.height) * baseFontRatio)
    }
}

final class WatermarkRenderer {
    private struct ResolvedTemplateItem {
        let configuration: CameraTemplateSlot
        let value: ResolvedCameraTemplateSlot
    }

    func renderWatermark(
        on image: CIImage,
        preset: WatermarkPreset,
        styleName: String,
        locationText: String?,
        photoFrame: PhotoFramePreset = PhotoFramePreset()
    ) -> CIImage {
        guard preset.enabled else {
            return image
        }

        switch preset.mode {
        case .manual:
            return renderTextWatermark(
                on: image,
                preset: preset,
                styleName: styleName,
                locationText: locationText,
                photoFrame: photoFrame,
                cameraTemplate: nil
            )
        case .image:
            return renderImageWatermark(
                on: image,
                preset: preset,
                photoFrame: photoFrame
            )
        }
    }

    func renderTemplateWatermark(
        on image: CIImage,
        template: CameraTemplatePreset,
        styleName: String,
        locationText: String?
    ) -> CIImage {
        let preset = template.watermark
        guard preset.enabled else { return image }

        switch preset.mode {
        case .manual:
            return renderTextWatermark(
                on: image,
                preset: preset,
                styleName: styleName,
                locationText: locationText,
                photoFrame: template.photoFrame,
                cameraTemplate: template
            )
        case .image:
            return renderImageWatermark(
                on: image,
                preset: preset,
                photoFrame: template.photoFrame
            )
        }
    }

    private func renderTextWatermark(
        on image: CIImage,
        preset: WatermarkPreset,
        styleName: String,
        locationText: String?,
        photoFrame: PhotoFramePreset,
        cameraTemplate: CameraTemplatePreset?
    ) -> CIImage {
        let fullText = Self.displayText(
            for: preset,
            styleName: styleName,
            locationText: locationText
        )
        let resolvedColumns = cameraTemplate.map {
            Self.resolvedColumns(
                for: $0,
                styleName: styleName,
                locationText: locationText
            )
        } ?? []
        let usesBottomSlots = preset.position == .bottom
            && cameraTemplate?.hasSlotContent == true
        let hasResolvedContent = resolvedColumns
            .flatMap { $0 }
            .flatMap { $0 }
            .contains { !$0.value.isEmpty }
        guard usesBottomSlots ? hasResolvedContent : !fullText.isEmpty else {
            return image
        }

        let extent = image.extent
        let size = CGSize(width: extent.width, height: extent.height)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        let overlay = renderer.image { context in
            UIColor.clear.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let fontSize = CameraTemplateTypography.baseFontSize(in: size)
                * CGFloat(preset.watermarkScale)

            if usesBottomSlots,
               let bandRect = PhotoFrameLayoutMetrics.bottomBandRect(
                   in: size,
                   preset: photoFrame
               ) {
                Self.drawBottomSlots(
                    resolvedColumns,
                    in: bandRect,
                    preset: preset,
                    fontSize: fontSize,
                    context: context.cgContext
                )
                return
            }

            let attributed = Self.attributedText(
                fullText,
                preset: preset,
                fontSize: fontSize
            )
            let textSize = attributed.boundingRect(
                with: CGSize(width: size.width * 0.72, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            ).integral.size
            let horizontalPadding = Self.horizontalPadding(for: preset, fontSize: fontSize)
            let verticalPadding = Self.verticalPadding(for: preset, fontSize: fontSize)
            let margin = max(24, min(size.width, size.height) * 0.035)
            let backgroundSize = CGSize(
                width: textSize.width + horizontalPadding * 2,
                height: textSize.height + verticalPadding * 2
            )
            let backgroundRect = Self.positionedRect(
                size: backgroundSize,
                canvasSize: size,
                margin: margin,
                preset: preset,
                photoFrame: photoFrame
            )
            let textRect = backgroundRect.insetBy(dx: horizontalPadding, dy: verticalPadding)

            Self.applyEffect(preset.effect, opacity: preset.opacity, in: context.cgContext)
            if let backgroundColor = Self.backgroundColor(for: preset) {
                backgroundColor.setFill()
                UIBezierPath(
                    roundedRect: backgroundRect,
                    cornerRadius: preset.template == .signature
                        ? min(backgroundRect.height / 2, 18)
                        : min(fontSize * 0.72, 16)
                ).fill()
            }
            attributed.draw(in: textRect)
        }

        guard let watermark = CIImage(image: overlay) else {
            return image
        }

        return watermark
            .transformed(by: CGAffineTransform(translationX: extent.minX, y: extent.minY))
            .composited(over: image)
            .cropped(to: extent)
    }

    private func renderImageWatermark(
        on image: CIImage,
        preset: WatermarkPreset,
        photoFrame: PhotoFramePreset
    ) -> CIImage {
        guard let imageData = preset.imageData,
              let watermarkImage = UIImage(data: imageData),
              watermarkImage.size.width > 0,
              watermarkImage.size.height > 0 else {
            return image
        }

        let extent = image.extent
        let size = CGSize(width: extent.width, height: extent.height)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        let overlay = renderer.image { context in
            UIColor.clear.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let targetSize = Self.imageWatermarkSize(
                originalSize: watermarkImage.size,
                canvasSize: size,
                preset: preset
            )
            let margin = max(24, min(size.width, size.height) * 0.035)
            let targetRect = Self.positionedRect(
                size: targetSize,
                canvasSize: size,
                margin: margin,
                preset: preset,
                photoFrame: photoFrame
            )

            context.cgContext.saveGState()
            context.cgContext.setAlpha(CGFloat(preset.opacity))
            watermarkImage.draw(in: targetRect)
            context.cgContext.restoreGState()
        }

        guard let watermark = CIImage(image: overlay) else {
            return image
        }

        return watermark
            .transformed(by: CGAffineTransform(translationX: extent.minX, y: extent.minY))
            .composited(over: image)
            .cropped(to: extent)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter
    }()

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "EEEE"
        return formatter
    }()

    private static func displayText(
        for preset: WatermarkPreset,
        styleName: String,
        locationText: String?
    ) -> String {
        preset.displayText(
            styleName: styleName,
            deviceName: UIDevice.current.model,
            locationText: locationText,
            dateText: dateFormatter.string(from: Date()),
            weekdayText: weekdayFormatter.string(from: Date())
        )
    }

    private static func resolvedColumns(
        for template: CameraTemplatePreset,
        styleName: String,
        locationText: String?
    ) -> [[[ResolvedTemplateItem]]] {
        let dateText = dateFormatter.string(from: Date())
        let weekdayText = weekdayFormatter.string(from: Date())
        return template.insetContent.columns.map { column in
            column.lines.map { line in
                line.fields.map { field in
                    ResolvedTemplateItem(
                        configuration: field,
                        value: template.resolvedSlot(
                            field,
                            styleName: styleName,
                            deviceName: UIDevice.current.model,
                            locationText: locationText,
                            dateText: dateText,
                            weekdayText: weekdayText
                        )
                    )
                }
            }
        }
    }

    private static func drawBottomSlots(
        _ columns: [[[ResolvedTemplateItem]]],
        in bandRect: CGRect,
        preset: WatermarkPreset,
        fontSize: CGFloat,
        context: CGContext
    ) {
        guard bandRect.width > 0, bandRect.height > 0 else { return }

        let slotWidth = bandRect.width / 3
        let horizontalInset = max(10, fontSize * 0.72)
        context.saveGState()
        context.clip(to: bandRect)
        applyEffect(preset.effect, opacity: preset.opacity, in: context)

        for (columnIndex, column) in columns.prefix(3).enumerated() {
            let slotRect = CGRect(
                x: bandRect.minX + CGFloat(columnIndex) * slotWidth + horizontalInset,
                y: bandRect.minY,
                width: max(1, slotWidth - horizontalInset * 2),
                height: bandRect.height
            )
            let visibleLines = column
                .map { $0.filter { !$0.value.isEmpty } }
                .filter { !$0.isEmpty }
            guard !visibleLines.isEmpty else { continue }

            let lineSpacing = visibleLines.count > 1 ? max(1, fontSize * 0.18) : 0
            let unscaledLineHeights = visibleLines.map { line in
                line.map {
                    fontSize * CGFloat($0.configuration.fontScale) * 1.24
                }.max() ?? 0
            }
            let availableLineHeight = max(
                1,
                slotRect.height - lineSpacing * CGFloat(visibleLines.count - 1)
            )
            let totalUnscaledLineHeight = unscaledLineHeights.reduce(0, +)
            let verticalScale = min(1, availableLineHeight / max(1, totalUnscaledLineHeight))
            let lineHeights = unscaledLineHeights.map { $0 * verticalScale }
            let totalHeight = lineHeights.reduce(0, +)
                + lineSpacing * CGFloat(visibleLines.count - 1)
            var currentY = slotRect.midY - totalHeight / 2

            for (lineIndex, line) in visibleLines.enumerated() {
                let lineRect = CGRect(
                    x: slotRect.minX,
                    y: currentY,
                    width: slotRect.width,
                    height: lineHeights[lineIndex]
                )
                drawTemplateLine(
                    line,
                    in: lineRect,
                    columnIndex: columnIndex,
                    preset: preset,
                    baseFontSize: fontSize,
                    verticalScale: verticalScale
                )
                currentY += lineHeights[lineIndex] + lineSpacing
            }
        }

        context.restoreGState()
    }

    private static func drawTemplateLine(
        _ line: [ResolvedTemplateItem],
        in lineRect: CGRect,
        columnIndex: Int,
        preset: WatermarkPreset,
        baseFontSize: CGFloat,
        verticalScale: CGFloat
    ) {
        let fieldSpacing = line.count > 1 ? max(2, baseFontSize * 0.28) : 0
        var fieldFontSizes = line.map {
            baseFontSize * CGFloat($0.configuration.fontScale) * verticalScale
        }
        var fieldSizes = zip(line, fieldFontSizes).map {
            templateItemSize($0.0, preset: preset, fontSize: $0.1, maxHeight: lineRect.height)
        }
        let spacingWidth = fieldSpacing * CGFloat(line.count - 1)
        var fieldsWidth = fieldSizes.reduce(0) { $0 + $1.width }
        var totalWidth = fieldsWidth + spacingWidth

        if totalWidth > lineRect.width {
            let availableFieldsWidth = max(1, lineRect.width - spacingWidth)
            let horizontalScale = min(1, availableFieldsWidth / max(1, fieldsWidth))
            fieldFontSizes = fieldFontSizes.map { $0 * horizontalScale }
            fieldSizes = zip(line, fieldFontSizes).map {
                templateItemSize($0.0, preset: preset, fontSize: $0.1, maxHeight: lineRect.height)
            }
            fieldsWidth = fieldSizes.reduce(0) { $0 + $1.width }
            totalWidth = fieldsWidth + spacingWidth
        }

        var currentX: CGFloat
        switch columnIndex {
        case 0:
            currentX = lineRect.minX
        case 2:
            currentX = lineRect.maxX - totalWidth
        default:
            currentX = lineRect.midX - totalWidth / 2
        }

        for index in line.indices {
            let size = fieldSizes[index]
            let rect = CGRect(
                x: currentX,
                y: lineRect.midY - size.height / 2,
                width: size.width,
                height: size.height
            )
            drawTemplateItem(
                line[index],
                in: rect,
                preset: preset,
                fontSize: fieldFontSizes[index]
            )
            currentX += size.width + fieldSpacing
        }
    }

    private static func templateItemSize(
        _ item: ResolvedTemplateItem,
        preset: WatermarkPreset,
        fontSize: CGFloat,
        maxHeight: CGFloat
    ) -> CGSize {
        switch item.value {
        case .empty:
            return .zero
        case let .icon(name):
            guard let image = templateIcon(named: name, fontSize: fontSize) else {
                return .zero
            }
            let scale = min(1, maxHeight / max(1, image.size.height))
            return CGSize(width: image.size.width * scale, height: image.size.height * scale)
        case let .text(text):
            let attributed = NSAttributedString(
                string: text,
                attributes: templateTextAttributes(
                    for: item.configuration,
                    preset: preset,
                    fontSize: fontSize
                )
            )
            return attributed.boundingRect(
                with: CGSize(width: 100_000, height: maxHeight),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            ).integral.size
        }
    }

    private static func drawTemplateItem(
        _ item: ResolvedTemplateItem,
        in rect: CGRect,
        preset: WatermarkPreset,
        fontSize: CGFloat
    ) {
        let attributes = templateTextAttributes(
            for: item.configuration,
            preset: preset,
            fontSize: fontSize
        )
        switch item.value {
        case .empty:
            break
        case let .icon(name):
            let color = (attributes[.foregroundColor] as? UIColor) ?? .white
            templateIcon(named: name, fontSize: fontSize)?
                .withTintColor(color, renderingMode: .alwaysOriginal)
                .draw(in: rect)
        case let .text(text):
            NSAttributedString(string: text, attributes: attributes).draw(in: rect)
        }
    }

    private static func templateIcon(named name: String, fontSize: CGFloat) -> UIImage? {
        if let asset = UIImage(named: name) {
            let targetHeight = fontSize * 1.2
            let aspectRatio = asset.size.width / max(1, asset.size.height)
            let size = CGSize(width: targetHeight * aspectRatio, height: targetHeight)
            let renderer = UIGraphicsImageRenderer(size: size)
            return renderer.image { _ in
                asset.withRenderingMode(.alwaysTemplate).draw(in: CGRect(origin: .zero, size: size))
            }.withRenderingMode(.alwaysTemplate)
        }

        let configuration = UIImage.SymbolConfiguration(
            pointSize: fontSize * 1.2,
            weight: .semibold
        )
        return UIImage(systemName: name, withConfiguration: configuration)
    }

    private static func templateTextAttributes(
        for item: CameraTemplateSlot,
        preset: WatermarkPreset,
        fontSize: CGFloat
    ) -> [NSAttributedString.Key: Any] {
        var attributes = textAttributes(for: preset, fontSize: fontSize)
        guard item.textColor != .automatic else { return attributes }

        let alpha = CGFloat(preset.opacity)
        let color: UIColor
        switch item.textColor {
        case .automatic:
            return attributes
        case .white:
            color = UIColor.white.withAlphaComponent(alpha)
        case .black:
            color = UIColor.black.withAlphaComponent(alpha)
        case .yellow:
            color = UIColor(red: 1, green: 0.86, blue: 0.12, alpha: alpha)
        case .orange:
            color = UIColor(red: 1, green: 0.48, blue: 0.16, alpha: alpha)
        case .blue:
            color = UIColor(red: 0.36, green: 0.64, blue: 1, alpha: alpha)
        case .pink:
            color = UIColor(red: 1, green: 0.48, blue: 0.72, alpha: alpha)
        }
        attributes[.foregroundColor] = color
        return attributes
    }

    private static func textAttributes(
        for preset: WatermarkPreset,
        fontSize: CGFloat
    ) -> [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.lineSpacing = preset.template == .signature ? 0 : fontSize * 0.22

        let font: UIFont
        let color: UIColor

        switch preset.visualStyle {
        case .minimal:
            font = preset.font.uiFont(size: fontSize, weight: .medium)
            color = Self.textColor(for: preset, fallback: .white, alphaMultiplier: 0.78)
        case .darkBadge:
            font = preset.font.uiFont(size: fontSize, weight: .semibold)
            color = Self.textColor(for: preset, fallback: .white, alphaMultiplier: 0.92)
        case .lightBadge:
            font = preset.font.uiFont(size: fontSize, weight: .semibold)
            color = Self.textColor(for: preset, fallback: .black, alphaMultiplier: 0.72)
        case .film:
            font = preset.font.uiFont(size: fontSize * 0.92, weight: .medium)
            color = Self.textColor(
                for: preset,
                fallback: UIColor(red: 1.0, green: 0.88, blue: 0.36, alpha: 1),
                alphaMultiplier: 0.9
            )
        }

        return [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]
    }

    private static func attributedText(
        _ text: String,
        preset: WatermarkPreset,
        fontSize: CGFloat
    ) -> NSAttributedString {
        let baseAttributes = textAttributes(for: preset, fontSize: fontSize)
        guard preset.template == .centeredTravel || preset.template == .weekdayQuote else {
            return NSAttributedString(string: text, attributes: baseAttributes)
        }

        let lines = text.components(separatedBy: "\n")
        let attributed = NSMutableAttributedString(string: "")

        for (index, line) in lines.enumerated() {
            var attributes = baseAttributes
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineBreakMode = .byWordWrapping
            paragraph.alignment = preset.template == .centeredTravel ? .center : .left
            paragraph.paragraphSpacing = fontSize * 0.16
            attributes[.paragraphStyle] = paragraph
            attributes[.font] = templateFont(
                for: preset.template,
                lineIndex: index,
                fontSize: fontSize,
                watermarkFont: preset.font
            )

            let suffix = index == lines.indices.last ? "" : "\n"
            attributed.append(NSAttributedString(string: line + suffix, attributes: attributes))
        }

        return attributed
    }

    private static func templateFont(
        for template: WatermarkTemplate,
        lineIndex: Int,
        fontSize: CGFloat,
        watermarkFont: WatermarkFont
    ) -> UIFont {
        switch template {
        case .centeredTravel:
            return lineIndex == 0
                ? watermarkFont.uiFont(size: fontSize * 1.16, weight: .semibold)
                : watermarkFont.uiFont(size: fontSize * 0.86, weight: .regular)
        case .weekdayQuote:
            switch lineIndex {
            case 0:
                return watermarkFont.uiFont(size: fontSize * 1.42, weight: .medium)
            case 1:
                return watermarkFont.uiFont(size: fontSize * 0.9, weight: .bold)
            case 2, 4:
                return watermarkFont.uiFont(size: fontSize * 0.68, weight: .regular)
            default:
                return watermarkFont.uiFont(size: fontSize, weight: .regular)
            }
        default:
            return watermarkFont.uiFont(size: fontSize)
        }
    }

    private static func backgroundColor(for preset: WatermarkPreset) -> UIColor? {
        switch preset.visualStyle {
        case .minimal:
            return nil
        case .darkBadge:
            return .black.withAlphaComponent(CGFloat(preset.opacity) * 0.42)
        case .lightBadge:
            return .white.withAlphaComponent(CGFloat(preset.opacity) * 0.68)
        case .film:
            return UIColor(red: 0.04, green: 0.035, blue: 0.02, alpha: CGFloat(preset.opacity) * 0.58)
        }
    }

    private static func textColor(
        for preset: WatermarkPreset,
        fallback: UIColor,
        alphaMultiplier: CGFloat
    ) -> UIColor {
        let baseColor: UIColor
        switch preset.textColor {
        case .automatic:
            baseColor = fallback
        case .white:
            baseColor = .white
        case .black:
            baseColor = .black
        case .yellow:
            baseColor = UIColor(red: 1.0, green: 0.86, blue: 0.12, alpha: 1)
        case .orange:
            baseColor = UIColor(red: 1.0, green: 0.48, blue: 0.16, alpha: 1)
        case .blue:
            baseColor = UIColor(red: 0.36, green: 0.64, blue: 1.0, alpha: 1)
        case .pink:
            baseColor = UIColor(red: 1.0, green: 0.48, blue: 0.72, alpha: 1)
        }

        return baseColor.withAlphaComponent(CGFloat(preset.opacity) * alphaMultiplier)
    }

    private static func horizontalPadding(for preset: WatermarkPreset, fontSize: CGFloat) -> CGFloat {
        preset.visualStyle == .minimal ? 0 : fontSize * 0.78
    }

    private static func verticalPadding(for preset: WatermarkPreset, fontSize: CGFloat) -> CGFloat {
        preset.visualStyle == .minimal ? 0 : fontSize * 0.42
    }

    private static func imageWatermarkSize(
        originalSize: CGSize,
        canvasSize: CGSize,
        preset: WatermarkPreset
    ) -> CGSize {
        let maxSide = max(
            24,
            min(canvasSize.width, canvasSize.height)
                * CGFloat(preset.imageScale)
                * CGFloat(preset.watermarkScale)
        )
        let originalMaxSide = max(originalSize.width, originalSize.height)
        guard originalMaxSide > 0 else {
            return CGSize(width: maxSide, height: maxSide)
        }

        let scale = maxSide / originalMaxSide
        return CGSize(
            width: originalSize.width * scale,
            height: originalSize.height * scale
        )
    }

    private static func positionedRect(
        size: CGSize,
        canvasSize: CGSize,
        margin: CGFloat,
        preset: WatermarkPreset,
        photoFrame: PhotoFramePreset
    ) -> CGRect {
        let x: CGFloat
        let y: CGFloat

        switch preset.position {
        case .topLeft:
            x = margin
            y = margin
        case .topRight:
            x = canvasSize.width - size.width - margin
            y = margin
        case .bottomLeft:
            x = margin
            y = canvasSize.height - size.height - margin
        case .bottomRight:
            x = canvasSize.width - size.width - margin
            y = canvasSize.height - size.height - margin
        case .bottomCenter:
            x = (canvasSize.width - size.width) / 2
            y = canvasSize.height - size.height - margin
        case .bottom:
            x = (canvasSize.width - size.width) / 2
            if let center = PhotoFrameLayoutMetrics.bottomBandCenter(
                in: canvasSize,
                preset: photoFrame
            ) {
                y = center.y - size.height / 2
            } else {
                y = canvasSize.height - size.height - margin
            }
        case .custom:
            let anchor = preset.customPosition ?? WatermarkAnchor(x: 0.5, y: 0.86)
            let rawX = CGFloat(anchor.x) * canvasSize.width - size.width / 2
            let rawY = CGFloat(anchor.y) * canvasSize.height - size.height / 2
            x = min(max(margin, rawX), canvasSize.width - size.width - margin)
            y = min(max(margin, rawY), canvasSize.height - size.height - margin)
        }

        return CGRect(origin: CGPoint(x: x, y: y), size: size)
    }

    private static func applyEffect(
        _ effect: WatermarkEffect,
        opacity: Float,
        in context: CGContext
    ) {
        switch effect {
        case .none:
            context.setShadow(offset: .zero, blur: 0, color: nil)
        case .shadow:
            context.setShadow(
                offset: CGSize(width: 0, height: 2),
                blur: 8,
                color: UIColor.black.withAlphaComponent(CGFloat(opacity) * 0.48).cgColor
            )
        case .glow:
            context.setShadow(
                offset: .zero,
                blur: 14,
                color: UIColor.white.withAlphaComponent(CGFloat(opacity) * 0.58).cgColor
            )
        }
    }
}

struct PhotoFrameLayoutMetrics {
    // Template inset values are authored against the 3:4 static preview asset.
    private static let customInsetsReferenceSize = CGSize(width: 1086, height: 1448)

    let contentRect: CGRect
    let cornerRadius: CGFloat
    let shadowWidth: CGFloat
    let markerLineWidth: CGFloat
    let markerLength: CGFloat
    let markerOffset: CGFloat

    static func make(in size: CGSize, preset: PhotoFramePreset) -> PhotoFrameLayoutMetrics {
        let width = max(1, size.width)
        let height = max(1, size.height)
        let shortSide = min(width, height)
        let insets: UIEdgeInsets

        if preset.hasCustomBaseInsets {
            let sourceInsets = preset.baseInsets
            let horizontalScale = width / customInsetsReferenceSize.width
            let verticalScale = height / customInsetsReferenceSize.height
            let horizontalInsets = clampedInsets(
                leading: max(0, sourceInsets.left) * horizontalScale,
                trailing: max(0, sourceInsets.right) * horizontalScale,
                available: width
            )
            let verticalInsets = clampedInsets(
                leading: max(0, sourceInsets.top) * verticalScale,
                trailing: max(0, sourceInsets.bottom) * verticalScale,
                available: height
            )
            insets = UIEdgeInsets(
                top: verticalInsets.leading,
                left: horizontalInsets.leading,
                bottom: verticalInsets.trailing,
                right: horizontalInsets.trailing
            )
        } else {
            let thicknessScale = min(1.7, max(0.25, CGFloat(preset.borderWidth) / 24))
            let baseInsets: UIEdgeInsets

            switch preset.style {
            case .cleanWhite:
                // Group 1: 10/120 side margins, 10/160 top, 30/160 bottom.
                baseInsets = UIEdgeInsets(
                    top: height * 0.0625,
                    left: width / 12,
                    bottom: height * 0.1875,
                    right: width / 12
                )
            case .cleanBlack:
                // Group 2: an even 10 px border in the 120 x 160 reference.
                baseInsets = UIEdgeInsets(
                    top: height * 0.0625,
                    left: width / 12,
                    bottom: height * 0.0625,
                    right: width / 12
                )
            case .instant:
                // Group 3: full-width image with 20 px top and bottom breathing room.
                baseInsets = UIEdgeInsets(
                    top: height * 0.125,
                    left: 0,
                    bottom: height * 0.125,
                    right: 0
                )
            case .film:
                // Group 4: edge-to-edge image with a 20 px caption area below it.
                baseInsets = UIEdgeInsets(
                    top: 0,
                    left: 0,
                    bottom: height * 0.125,
                    right: 0
                )
            case .minimal:
                // Group 5: centered image with viewfinder marks outside the opening.
                baseInsets = UIEdgeInsets(
                    top: height * 0.125,
                    left: width / 12,
                    bottom: height * 0.125,
                    right: width / 12
                )
            }

            insets = UIEdgeInsets(
                top: baseInsets.top * thicknessScale,
                left: baseInsets.left * thicknessScale,
                bottom: baseInsets.bottom * thicknessScale,
                right: baseInsets.right * thicknessScale
            )
        }
        let contentRect = CGRect(
            x: insets.left,
            y: insets.top,
            width: max(1, width - insets.left - insets.right),
            height: max(1, height - insets.top - insets.bottom)
        )
        let cornerRadius = min(
            min(contentRect.width, contentRect.height) / 2,
            shortSide * CGFloat(preset.cornerRadius) / 375
        )

        return PhotoFrameLayoutMetrics(
            contentRect: contentRect,
            cornerRadius: cornerRadius,
            shadowWidth: max(1, shortSide * 3 / 375),
            markerLineWidth: max(1, shortSide * 1.6 / 120),
            markerLength: min(contentRect.width, contentRect.height) * 0.28,
            markerOffset: shortSide * 4 / 120
        )
    }

    static func bottomBandCenter(in size: CGSize, preset: PhotoFramePreset) -> CGPoint? {
        guard let rect = bottomBandRect(in: size, preset: preset) else { return nil }
        return CGPoint(x: rect.midX, y: rect.midY)
    }

    static func bottomBandRect(in size: CGSize, preset: PhotoFramePreset) -> CGRect? {
        guard preset.shouldRenderFrame else { return nil }

        let layout = make(in: size, preset: preset)
        let bandHeight = max(0, size.height - layout.contentRect.maxY)
        guard bandHeight > 0 else { return nil }

        return CGRect(
            x: 0,
            y: layout.contentRect.maxY,
            width: size.width,
            height: bandHeight
        )
    }

    private static func clampedInsets(
        leading: CGFloat,
        trailing: CGFloat,
        available: CGFloat
    ) -> (leading: CGFloat, trailing: CGFloat) {
        let total = leading + trailing
        let maximum = max(0, available - 1)
        guard total > maximum, total > 0 else {
            return (leading, trailing)
        }

        let scale = maximum / total
        return (leading * scale, trailing * scale)
    }
}

extension PhotoFramePreset {
    var hasCustomBaseInsets: Bool {
        baseInsets.top != 0
            || baseInsets.left != 0
            || baseInsets.bottom != 0
            || baseInsets.right != 0
    }

    var shouldRenderFrame: Bool {
        enabled || hasCustomBaseInsets
    }
}

final class PhotoFrameRenderer {
    private let context: CIContext

    init(context: CIContext) {
        self.context = context
    }

    func renderFrame(around image: CIImage, preset: PhotoFramePreset) -> CIImage {
        let normalizedImage = normalized(image)
        guard preset.shouldRenderFrame else {
            return normalizedImage
        }

        let imageExtent = normalizedImage.extent
        guard let cgImage = context.createCGImage(normalizedImage, from: imageExtent) else {
            return normalizedImage
        }

        let canvasSize = imageExtent.size
        let canvasRect = CGRect(origin: .zero, size: canvasSize)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)

        let layout = PhotoFrameLayoutMetrics.make(in: canvasSize, preset: preset)
        let framedImage = renderer.image { renderContext in
            UIImage(cgImage: cgImage).draw(in: canvasRect)

            if preset.shadowEnabled {
                Self.drawOpeningShadow(
                    layout: layout,
                    context: renderContext.cgContext
                )
            }
            Self.drawFrameMask(
                in: canvasRect,
                layout: layout,
                preset: preset
            )
            if preset.style == .minimal {
                Self.drawViewfinderMarks(
                    layout: layout,
                    preset: preset,
                    context: renderContext.cgContext
                )
            }
        }

        guard let output = CIImage(image: framedImage) else {
            return normalizedImage
        }
        return normalized(output)
    }

    private func normalized(_ image: CIImage) -> CIImage {
        let extent = image.extent
        guard extent.origin != .zero else {
            return image
        }

        return image.transformed(
            by: CGAffineTransform(translationX: -extent.origin.x, y: -extent.origin.y)
        )
    }

    private static func backgroundColor(for preset: PhotoFramePreset) -> UIColor {
        let alpha = CGFloat(preset.opacity)
        switch preset.backgroundColor {
        case .white:
            return UIColor(white: 0.98, alpha: alpha)
        case .lightGray:
            return UIColor(red: 0.88, green: 0.89, blue: 0.91, alpha: alpha)
        case .black:
            return UIColor(white: 0.03, alpha: alpha)
        case .cream:
            return UIColor(red: 0.96, green: 0.84, blue: 0.67, alpha: alpha)
        case .pink:
            return UIColor(red: 0.96, green: 0.84, blue: 0.90, alpha: alpha)
        case .mint:
            return UIColor(red: 0.78, green: 0.94, blue: 0.86, alpha: alpha)
        }
    }

    private static func drawOpeningShadow(
        layout: PhotoFrameLayoutMetrics,
        context: CGContext
    ) {
        context.saveGState()
        context.setShadow(
            offset: CGSize(width: 0, height: layout.shadowWidth),
            blur: layout.shadowWidth * 2.5,
            color: UIColor.black.withAlphaComponent(0.34).cgColor
        )
        UIColor.black.withAlphaComponent(0.28).setStroke()
        let path = UIBezierPath(
            roundedRect: layout.contentRect,
            cornerRadius: layout.cornerRadius
        )
        path.lineWidth = layout.shadowWidth
        path.stroke()
        context.restoreGState()
    }

    private static func drawFrameMask(
        in rect: CGRect,
        layout: PhotoFrameLayoutMetrics,
        preset: PhotoFramePreset
    ) {
        let path = UIBezierPath(rect: rect)
        path.append(
            UIBezierPath(
                roundedRect: layout.contentRect,
                cornerRadius: layout.cornerRadius
            )
        )
        path.usesEvenOddFillRule = true
        backgroundColor(for: preset).setFill()
        path.fill()
    }

    private static func drawViewfinderMarks(
        layout: PhotoFrameLayoutMetrics,
        preset: PhotoFramePreset,
        context: CGContext
    ) {
        context.saveGState()
        context.setLineWidth(layout.markerLineWidth)
        context.setLineCap(.square)
        markerColor(for: preset).setStroke()

        let rect = layout.contentRect
        let offset = layout.markerOffset
        let length = layout.markerLength
        let path = UIBezierPath()
        path.move(to: CGPoint(x: rect.minX - offset, y: rect.minY + length - offset))
        path.addLine(to: CGPoint(x: rect.minX - offset, y: rect.minY - offset))
        path.addLine(to: CGPoint(x: rect.minX + length - offset, y: rect.minY - offset))
        path.move(to: CGPoint(x: rect.maxX - length + offset, y: rect.maxY + offset))
        path.addLine(to: CGPoint(x: rect.maxX + offset, y: rect.maxY + offset))
        path.addLine(to: CGPoint(x: rect.maxX + offset, y: rect.maxY - length + offset))
        path.stroke()
        context.restoreGState()
    }

    private static func markerColor(for preset: PhotoFramePreset) -> UIColor {
        switch preset.backgroundColor {
        case .black:
            return UIColor.white.withAlphaComponent(CGFloat(preset.opacity) * 0.72)
        case .white, .lightGray, .cream, .pink, .mint:
            return UIColor.black.withAlphaComponent(CGFloat(preset.opacity) * 0.52)
        }
    }
}

public extension WatermarkFont {
    func uiFont(size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        let candidates: [String]
        switch self {
        case .sourceHanSans:
            candidates = ["SourceHanSansSC-Medium", "SourceHanSansCN-Medium", "PingFangSC-Medium"]
        case .sourceHanSerif:
            candidates = ["SourceHanSerifSC-Regular", "SourceHanSerifCN-Regular", "Songti SC", "Georgia"]
        case .lxgwWenKai:
            candidates = ["LXGWWenKai-Regular", "LXGWWenKaiMono-Regular", "Kaiti SC", "STKaiti"]
        case .smileySans:
            candidates = ["SmileySans-Oblique", "AvenirNext-Heavy", "Impact"]
        case .maShanZheng:
            candidates = ["MaShanZheng-Regular", "Xingkai SC", "STXingkai"]
        case .longCang:
            candidates = ["LongCang-Regular", "Chalkduster", "BradleyHandITCTT-Bold"]
        case .zcoolXiaoWei:
            candidates = ["ZCOOLXiaoWei-Regular", "STHeitiSC-Light", "PingFangSC-Thin"]
        case .zcoolKuaiLe:
            candidates = ["ZCOOLKuaiLe-Regular", "Yuanti SC", "ArialRoundedMTBold"]
        case .caveat:
            candidates = ["Caveat", "Caveat-Regular", "SnellRoundhand", "Bradley Hand"]
        case .bebasNeue:
            candidates = ["BebasNeue", "BebasNeue-Regular", "DIN Condensed Bold", "Impact"]
        }

        for name in candidates {
            if let font = UIFont(name: name, size: size) {
                return font
            }
        }

        switch self {
        case .sourceHanSans:
            return .systemFont(ofSize: size, weight: weight)
        case .sourceHanSerif:
            return .systemFont(ofSize: size, weight: weight)
        case .lxgwWenKai:
            return .systemFont(ofSize: size, weight: weight)
        case .smileySans:
            return .systemFont(ofSize: size, weight: .heavy)
        case .maShanZheng:
            return .systemFont(ofSize: size, weight: weight)
        case .longCang:
            return .systemFont(ofSize: size, weight: .semibold)
        case .zcoolXiaoWei:
            return .systemFont(ofSize: size, weight: .ultraLight)
        case .zcoolKuaiLe:
            return .systemFont(ofSize: size, weight: .bold)
        case .caveat:
            return .italicSystemFont(ofSize: size)
        case .bebasNeue:
            return .systemFont(ofSize: size, weight: .bold)
        }
    }

    func swiftUIFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let candidates: [String]
        switch self {
        case .sourceHanSans:
            candidates = ["SourceHanSansSC-Medium", "SourceHanSansCN-Medium", "PingFangSC-Medium"]
        case .sourceHanSerif:
            candidates = ["SourceHanSerifSC-Regular", "SourceHanSerifCN-Regular", "Songti SC", "Georgia"]
        case .lxgwWenKai:
            candidates = ["LXGWWenKai-Regular", "LXGWWenKaiMono-Regular", "Kaiti SC", "STKaiti"]
        case .smileySans:
            candidates = ["SmileySans-Oblique", "AvenirNext-Heavy", "Impact"]
        case .maShanZheng:
            candidates = ["MaShanZheng-Regular", "Xingkai SC", "STXingkai"]
        case .longCang:
            candidates = ["LongCang-Regular", "Chalkduster", "BradleyHandITCTT-Bold"]
        case .zcoolXiaoWei:
            candidates = ["ZCOOLXiaoWei-Regular", "STHeitiSC-Light", "PingFangSC-Thin"]
        case .zcoolKuaiLe:
            candidates = ["ZCOOLKuaiLe-Regular", "Yuanti SC", "ArialRoundedMTBold"]
        case .caveat:
            candidates = ["Caveat", "Caveat-Regular", "SnellRoundhand", "Bradley Hand"]
        case .bebasNeue:
            candidates = ["BebasNeue", "BebasNeue-Regular", "DIN Condensed Bold", "Impact"]
        }

        for name in candidates {
            if UIFont(name: name, size: size) != nil {
                return .custom(name, size: size)
            }
        }

        switch self {
        case .sourceHanSans:
            return .system(size: size, weight: weight, design: .default)
        case .sourceHanSerif:
            return .system(size: size, weight: weight, design: .serif)
        case .lxgwWenKai:
            return .system(size: size, weight: weight, design: .serif)
        case .smileySans:
            return .system(size: size, weight: .heavy, design: .default)
        case .maShanZheng:
            return .system(size: size, weight: weight, design: .serif)
        case .longCang:
            return .system(size: size, weight: .semibold, design: .serif)
        case .zcoolXiaoWei:
            return .system(size: size, weight: .ultraLight, design: .serif)
        case .zcoolKuaiLe:
            return .system(size: size, weight: .bold, design: .rounded)
        case .caveat:
            return .system(size: size, weight: weight, design: .serif).italic()
        case .bebasNeue:
            return .system(size: size, weight: .bold, design: .monospaced)
        }
    }
}
