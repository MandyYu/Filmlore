import CoreGraphics
import CoreImage
import Foundation
import StyleCameraCore
import Vision

struct CompositionGuideAnalyzer {
    private let context: CIContext
    private let colorSpace: CGColorSpace

    init() {
        colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        context = CIContext(options: [.workingColorSpace: colorSpace])
    }

    func analyze(_ image: CIImage, rollDegrees: Double) -> PhotoGuidanceSceneAnalysis {
        let metrics = sampledMetrics(for: image)
        return PhotoGuidanceSceneAnalysis(
            averageBrightness: metrics.averageBrightness,
            overexposedPixelRatio: metrics.overexposedPixelRatio,
            sharpnessScore: sharpnessScore(for: image),
            subjectRect: subjectRect(in: image),
            rollDegrees: rollDegrees
        )
    }

    private func sampledMetrics(for image: CIImage) -> (averageBrightness: Double, overexposedPixelRatio: Double) {
        let sampleSize = 32
        let normalized = normalizedImage(image, sampleSize: sampleSize)
        var bitmap = [UInt8](repeating: 0, count: sampleSize * sampleSize * 4)

        context.render(
            normalized,
            toBitmap: &bitmap,
            rowBytes: sampleSize * 4,
            bounds: CGRect(x: 0, y: 0, width: sampleSize, height: sampleSize),
            format: .RGBA8,
            colorSpace: colorSpace
        )

        var luminanceTotal = 0.0
        var overexposedCount = 0
        let pixelCount = sampleSize * sampleSize

        stride(from: 0, to: bitmap.count, by: 4).forEach { index in
            let red = Double(bitmap[index]) / 255
            let green = Double(bitmap[index + 1]) / 255
            let blue = Double(bitmap[index + 2]) / 255
            let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
            luminanceTotal += luminance
            if luminance >= 0.92 {
                overexposedCount += 1
            }
        }

        return (
            averageBrightness: luminanceTotal / Double(pixelCount),
            overexposedPixelRatio: Double(overexposedCount) / Double(pixelCount)
        )
    }

    private func sharpnessScore(for image: CIImage) -> Double {
        let sampleSize = 32
        let normalized = normalizedImage(image, sampleSize: sampleSize)
        let edgeImage = normalized.applyingFilter(
            "CIEdges",
            parameters: [kCIInputIntensityKey: 1.0]
        )

        guard let averageFilter = CIFilter(
            name: "CIAreaAverage",
            parameters: [
                kCIInputImageKey: edgeImage,
                kCIInputExtentKey: CIVector(cgRect: CGRect(x: 0, y: 0, width: sampleSize, height: sampleSize))
            ]
        ),
        let outputImage = averageFilter.outputImage else {
            return 0.5
        }

        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(
            outputImage,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: colorSpace
        )

        let red = Double(bitmap[0]) / 255
        let green = Double(bitmap[1]) / 255
        let blue = Double(bitmap[2]) / 255
        let edgeLuminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
        return min(1, max(0, edgeLuminance * 3.2))
    }

    private func subjectRect(in image: CIImage) -> CGRect? {
        if let faceRect = faceRect(in: image) {
            return faceRect
        }

        return salientObjectRect(in: image)
    }

    private func faceRect(in image: CIImage) -> CGRect? {
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(ciImage: image, options: [:])
        try? handler.perform([request])

        return request.results?
            .map(\.boundingBox)
            .max { lhs, rhs in
                lhs.width * lhs.height < rhs.width * rhs.height
            }
            .map(normalizedVisionRect)
    }

    private func salientObjectRect(in image: CIImage) -> CGRect? {
        let request = VNGenerateAttentionBasedSaliencyImageRequest()
        let handler = VNImageRequestHandler(ciImage: image, options: [:])
        try? handler.perform([request])

        guard let observation = request.results?.first,
              let object = observation.salientObjects?.max(by: { lhs, rhs in
                  lhs.boundingBox.width * lhs.boundingBox.height < rhs.boundingBox.width * rhs.boundingBox.height
              }) else {
            return nil
        }

        return normalizedVisionRect(object.boundingBox)
    }

    private func normalizedVisionRect(_ rect: CGRect) -> CGRect {
        CGRect(
            x: rect.minX,
            y: 1 - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    private func normalizedImage(_ image: CIImage, sampleSize: Int) -> CIImage {
        let extent = image.extent
        guard extent.width > 0, extent.height > 0 else {
            return image
        }

        let transform = CGAffineTransform(translationX: -extent.minX, y: -extent.minY)
            .scaledBy(
                x: CGFloat(sampleSize) / extent.width,
                y: CGFloat(sampleSize) / extent.height
            )

        return image.transformed(by: transform)
            .cropped(to: CGRect(x: 0, y: 0, width: sampleSize, height: sampleSize))
    }
}

