import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

public final class StyleRenderer {
    public let context: CIContext

    public init(context: CIContext? = nil) {
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)
        self.context = context ?? CIContext(options: [
            .workingColorSpace: colorSpace as Any,
            .outputColorSpace: colorSpace as Any
        ])
    }

    public func applyStyle(to input: CIImage, params: StyleParams) -> CIImage {
        let normalizedInput = normalized(input)
        var image = normalizedInput

        image = applyExposure(image, value: params.exposure)
        image = applyHighlightShadow(image, highlights: params.highlights, shadows: params.shadows)
        image = applyColorControls(
            image,
            brightness: params.brightness,
            contrast: params.contrast,
            saturation: params.saturation
        )
        image = applyBlackPoint(image, value: params.blackPoint)
        image = applyVibrance(image, value: params.vibrance)
        image = applyTemperatureAndTint(image, warmth: params.warmth, tint: params.tint)
        image = applyBrilliance(image, value: params.brilliance)
        image = applySharpness(image, value: params.sharpness)
        image = applyFade(image, value: params.fade)
        image = applyVignette(image, value: params.vignette)

        return normalized(image.cropped(to: normalizedInput.extent))
    }

    public func normalized(_ image: CIImage) -> CIImage {
        let extent = image.extent
        guard extent.origin != .zero else {
            return image
        }

        return image.transformed(
            by: CGAffineTransform(translationX: -extent.origin.x, y: -extent.origin.y)
        )
    }

    private func applyExposure(_ image: CIImage, value: Float) -> CIImage {
        guard abs(value) > 0.1 else { return image }
        let filter = CIFilter.exposureAdjust()
        filter.inputImage = image
        filter.ev = value / 100 * 1.2
        return filter.outputImage ?? image
    }

    private func applyHighlightShadow(_ image: CIImage, highlights: Float, shadows: Float) -> CIImage {
        guard abs(highlights) > 0.1 || abs(shadows) > 0.1 else { return image }
        let filter = CIFilter.highlightShadowAdjust()
        filter.inputImage = image
        filter.highlightAmount = 1 + highlights / 100 * 0.7
        filter.shadowAmount = shadows / 100
        return filter.outputImage ?? image
    }

    private func applyColorControls(
        _ image: CIImage,
        brightness: Float,
        contrast: Float,
        saturation: Float
    ) -> CIImage {
        guard abs(brightness) > 0.1 || abs(contrast) > 0.1 || abs(saturation) > 0.1 else {
            return image
        }
        let filter = CIFilter.colorControls()
        filter.inputImage = image
        filter.brightness = brightness / 100 * 0.25
        filter.contrast = 1 + contrast / 100 * 0.6
        filter.saturation = 1 + saturation / 100 * 0.8
        return filter.outputImage ?? image
    }

    private func applyBlackPoint(_ image: CIImage, value: Float) -> CIImage {
        guard abs(value) > 0.1 else { return image }

        let amount = CGFloat(value / 100)
        let filter = CIFilter.colorMatrix()
        filter.inputImage = image
        filter.rVector = CIVector(x: 1 + amount * 0.16, y: 0, z: 0, w: 0)
        filter.gVector = CIVector(x: 0, y: 1 + amount * 0.16, z: 0, w: 0)
        filter.bVector = CIVector(x: 0, y: 0, z: 1 + amount * 0.16, w: 0)
        filter.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        filter.biasVector = CIVector(
            x: -amount * 0.035,
            y: -amount * 0.035,
            z: -amount * 0.035,
            w: 0
        )
        return filter.outputImage ?? image
    }

    private func applyVibrance(_ image: CIImage, value: Float) -> CIImage {
        guard abs(value) > 0.1 else { return image }
        let filter = CIFilter.vibrance()
        filter.inputImage = image
        filter.amount = value / 100 * 0.8
        return filter.outputImage ?? image
    }

    private func applyTemperatureAndTint(_ image: CIImage, warmth: Float, tint: Float) -> CIImage {
        guard abs(warmth) > 0.1 || abs(tint) > 0.1 else { return image }
        let filter = CIFilter.temperatureAndTint()
        filter.inputImage = image
        filter.neutral = CIVector(x: 6500, y: 0)
        filter.targetNeutral = CIVector(
            x: CGFloat(6500 + warmth * 35),
            y: CGFloat(tint * 1.5)
        )
        return filter.outputImage ?? image
    }

    private func applyBrilliance(_ image: CIImage, value: Float) -> CIImage {
        guard abs(value) > 0.1 else { return image }

        let highlightShadow = CIFilter.highlightShadowAdjust()
        highlightShadow.inputImage = image
        highlightShadow.highlightAmount = 1 - value / 100 * 0.25
        highlightShadow.shadowAmount = value / 100 * 0.25
        let adjusted = highlightShadow.outputImage ?? image

        let controls = CIFilter.colorControls()
        controls.inputImage = adjusted
        controls.contrast = 1 + value / 100 * 0.12
        controls.brightness = value / 100 * 0.04
        return controls.outputImage ?? adjusted
    }

    private func applySharpness(_ image: CIImage, value: Float) -> CIImage {
        guard value > 0.1 else { return image }
        let filter = CIFilter.sharpenLuminance()
        filter.inputImage = image
        filter.sharpness = value / 100 * 0.8
        return filter.outputImage ?? image
    }

    private func applyFade(_ image: CIImage, value: Float) -> CIImage {
        guard value > 0.1 else { return image }
        let filter = CIFilter.colorControls()
        filter.inputImage = image
        filter.contrast = 1 - value / 100 * 0.24
        filter.brightness = value / 100 * 0.035
        filter.saturation = 1 - value / 100 * 0.08
        return filter.outputImage ?? image
    }

    private func applyVignette(_ image: CIImage, value: Float) -> CIImage {
        guard value > 0.1 else { return image }
        let filter = CIFilter.vignette()
        filter.inputImage = image
        filter.intensity = value / 100 * 1.2
        filter.radius = 1.5
        return filter.outputImage ?? image
    }
}
