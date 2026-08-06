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

            let fontSize = max(
                9,
                min(size.width, size.height)
                    * 0.026
                    * CGFloat(preset.watermarkScale)
            )
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

struct PhotoFrameLayoutMetrics {
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

        let insets = UIEdgeInsets(
            top: baseInsets.top * thicknessScale,
            left: baseInsets.left * thicknessScale,
            bottom: baseInsets.bottom * thicknessScale,
            right: baseInsets.right * thicknessScale
        )
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
