import CoreImage
import StyleCameraCore
import UIKit

final class WatermarkRenderer {
    func renderWatermark(
        on image: CIImage,
        preset: WatermarkPreset,
        styleName: String,
        locationText: String?
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
                locationText: locationText
            )
        case .image:
            return renderImageWatermark(on: image, preset: preset)
        }
    }

    private func renderTextWatermark(
        on image: CIImage,
        preset: WatermarkPreset,
        styleName: String,
        locationText: String?
    ) -> CIImage {
        let fullText = Self.displayText(
            for: preset,
            styleName: styleName,
            locationText: locationText
        )
        guard !fullText.isEmpty else {
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

            let fontSize = max(18, min(size.width, size.height) * 0.026)
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
                preset: preset
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

    private func renderImageWatermark(on image: CIImage, preset: WatermarkPreset) -> CIImage {
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
                preset: preset
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
            font = .systemFont(ofSize: fontSize, weight: .medium)
            color = Self.textColor(for: preset, fallback: .white, alphaMultiplier: 0.78)
        case .darkBadge:
            font = .systemFont(ofSize: fontSize, weight: .semibold)
            color = Self.textColor(for: preset, fallback: .white, alphaMultiplier: 0.92)
        case .lightBadge:
            font = .systemFont(ofSize: fontSize, weight: .semibold)
            color = Self.textColor(for: preset, fallback: .black, alphaMultiplier: 0.72)
        case .film:
            font = .monospacedSystemFont(ofSize: fontSize * 0.92, weight: .medium)
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
                fontSize: fontSize
            )

            let suffix = index == lines.indices.last ? "" : "\n"
            attributed.append(NSAttributedString(string: line + suffix, attributes: attributes))
        }

        return attributed
    }

    private static func templateFont(
        for template: WatermarkTemplate,
        lineIndex: Int,
        fontSize: CGFloat
    ) -> UIFont {
        switch template {
        case .centeredTravel:
            return lineIndex == 0
                ? .systemFont(ofSize: fontSize * 1.16, weight: .semibold)
                : .systemFont(ofSize: fontSize * 0.86, weight: .regular)
        case .weekdayQuote:
            switch lineIndex {
            case 0:
                return .systemFont(ofSize: fontSize * 1.42, weight: .medium)
            case 1:
                return .systemFont(ofSize: fontSize * 0.9, weight: .bold)
            case 2, 4:
                return .monospacedSystemFont(ofSize: fontSize * 0.68, weight: .regular)
            default:
                return .systemFont(ofSize: fontSize, weight: .regular)
            }
        default:
            return .systemFont(ofSize: fontSize)
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
        let maxSide = max(48, min(canvasSize.width, canvasSize.height) * CGFloat(preset.imageScale))
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
        preset: WatermarkPreset
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

final class PhotoFrameRenderer {
    private let context: CIContext

    init(context: CIContext) {
        self.context = context
    }

    func renderFrame(around image: CIImage, preset: PhotoFramePreset) -> CIImage {
        let normalizedImage = normalized(image)
        guard preset.enabled else {
            return normalizedImage
        }

        let imageExtent = normalizedImage.extent
        guard let cgImage = context.createCGImage(normalizedImage, from: imageExtent) else {
            return normalizedImage
        }

        let imageSize = imageExtent.size
        let insets = Self.insets(for: preset, imageSize: imageSize)
        let canvasSize = imageSize
        let canvasRect = CGRect(origin: .zero, size: canvasSize)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)

        let cornerRadius = Self.scaledCornerRadius(for: preset, imageSize: imageSize)
        let framedImage = renderer.image { renderContext in
            UIImage(cgImage: cgImage).draw(in: canvasRect)

            switch preset.style {
            case .cleanWhite, .cleanBlack:
                Self.drawBorder(
                    in: canvasRect,
                    lineWidth: insets.left,
                    cornerRadius: cornerRadius,
                    preset: preset
                )
            case .instant:
                Self.drawInstantFrame(
                    in: canvasRect,
                    insets: insets,
                    cornerRadius: cornerRadius,
                    preset: preset,
                    context: renderContext.cgContext
                )
            case .film:
                Self.drawFilmFrame(
                    in: canvasRect,
                    insets: insets,
                    cornerRadius: cornerRadius,
                    preset: preset,
                    context: renderContext.cgContext
                )
            case .minimal:
                Self.drawBorder(
                    in: canvasRect,
                    lineWidth: insets.left,
                    cornerRadius: cornerRadius,
                    preset: preset
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

    private static func insets(for preset: PhotoFramePreset, imageSize: CGSize) -> UIEdgeInsets {
        let shortSide = min(imageSize.width, imageSize.height)
        let border = max(10, shortSide * CGFloat(preset.borderWidth) / 375)
        switch preset.style {
        case .cleanWhite, .cleanBlack:
            return UIEdgeInsets(top: border, left: border, bottom: border, right: border)
        case .instant:
            let side = max(border, shortSide * 0.04)
            let top = max(border, shortSide * 0.04)
            let bottom = max(border * 3.1, shortSide * 0.12)
            return UIEdgeInsets(top: top, left: side, bottom: bottom, right: side)
        case .film:
            let horizontal = max(border * 1.8, shortSide * 0.055)
            let vertical = max(border * 0.9, shortSide * 0.025)
            return UIEdgeInsets(top: vertical, left: horizontal, bottom: vertical, right: horizontal)
        case .minimal:
            let minimalBorder = max(8, border * 0.55)
            return UIEdgeInsets(
                top: minimalBorder,
                left: minimalBorder,
                bottom: minimalBorder,
                right: minimalBorder
            )
        }
    }

    private static func scaledCornerRadius(for preset: PhotoFramePreset, imageSize: CGSize) -> CGFloat {
        min(imageSize.width, imageSize.height) * CGFloat(preset.cornerRadius) / 375
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

    private static func drawBorder(
        in rect: CGRect,
        lineWidth: CGFloat,
        cornerRadius: CGFloat,
        preset: PhotoFramePreset
    ) {
        let safeLineWidth = max(1, lineWidth)
        let pathRect = rect.insetBy(dx: safeLineWidth / 2, dy: safeLineWidth / 2)
        let path = UIBezierPath(
            roundedRect: pathRect,
            cornerRadius: max(0, cornerRadius - safeLineWidth / 2)
        )

        if preset.shadowEnabled {
            UIColor.black.withAlphaComponent(0.28).setStroke()
            path.lineWidth = safeLineWidth + max(3, safeLineWidth * 0.18)
            path.stroke()
        }

        backgroundColor(for: preset).setStroke()
        path.lineWidth = safeLineWidth
        path.stroke()
    }

    private static func drawInstantFrame(
        in rect: CGRect,
        insets: UIEdgeInsets,
        cornerRadius: CGFloat,
        preset: PhotoFramePreset,
        context: CGContext
    ) {
        drawBorder(
            in: rect,
            lineWidth: insets.left,
            cornerRadius: cornerRadius,
            preset: preset
        )

        context.saveGState()
        UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius).addClip()
        let captionRect = CGRect(
            x: rect.minX,
            y: rect.maxY - insets.bottom,
            width: rect.width,
            height: insets.bottom
        )
        backgroundColor(for: preset).setFill()
        UIBezierPath(rect: captionRect).fill()

        let lineHeight = max(2, rect.width * 0.002)
        let lineRect = CGRect(
            x: rect.minX + max(insets.left, rect.width * 0.06),
            y: captionRect.minY + insets.bottom * 0.36,
            width: rect.width * 0.34,
            height: lineHeight
        )
        UIColor.black.withAlphaComponent(CGFloat(preset.opacity) * 0.14).setFill()
        UIBezierPath(roundedRect: lineRect, cornerRadius: lineHeight / 2).fill()
        context.restoreGState()
    }

    private static func drawFilmFrame(
        in rect: CGRect,
        insets: UIEdgeInsets,
        cornerRadius: CGFloat,
        preset: PhotoFramePreset,
        context: CGContext
    ) {
        context.saveGState()
        UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius).addClip()
        backgroundColor(for: preset).setFill()
        UIBezierPath(rect: CGRect(x: rect.minX, y: rect.minY, width: insets.left, height: rect.height)).fill()
        UIBezierPath(rect: CGRect(x: rect.maxX - insets.right, y: rect.minY, width: insets.right, height: rect.height)).fill()
        UIBezierPath(rect: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: insets.top)).fill()
        UIBezierPath(rect: CGRect(x: rect.minX, y: rect.maxY - insets.bottom, width: rect.width, height: insets.bottom)).fill()
        context.restoreGState()

        drawFilmPerforations(
            in: rect,
            railWidth: min(insets.left, insets.right),
            verticalInset: max(insets.top, insets.bottom),
            opacity: preset.opacity
        )
    }

    private static func drawFilmPerforations(
        in rect: CGRect,
        railWidth: CGFloat,
        verticalInset: CGFloat,
        opacity: Float
    ) {
        let holeWidth = max(8, railWidth * 0.34)
        let holeHeight = max(14, holeWidth * 1.65)
        let step = holeHeight * 1.72
        let leftX = rect.minX + (railWidth - holeWidth) / 2
        let rightX = rect.maxX - railWidth + (railWidth - holeWidth) / 2
        UIColor.white.withAlphaComponent(CGFloat(opacity) * 0.28).setFill()

        var y = rect.minY + verticalInset + holeHeight * 0.45
        while y + holeHeight < rect.maxY - verticalInset {
            let leftRect = CGRect(x: leftX, y: y, width: holeWidth, height: holeHeight)
            let rightRect = CGRect(x: rightX, y: y, width: holeWidth, height: holeHeight)
            UIBezierPath(roundedRect: leftRect, cornerRadius: holeWidth * 0.22).fill()
            UIBezierPath(roundedRect: rightRect, cornerRadius: holeWidth * 0.22).fill()
            y += step
        }
    }
}
