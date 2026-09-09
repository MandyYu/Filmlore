import Foundation
import CoreImage
import ImageIO
import Photos
import UniformTypeIdentifiers

final class PhotoLibraryService: @unchecked Sendable {
    enum SaveError: Error {
        case notAuthorized
        case assetNotFound
        case sourceUnavailable
        case encodingFailed
        case writeFailed
    }

    struct EditingSource {
        let asset: PHAsset
        let input: PHContentEditingInput
        let image: CIImage
    }

    func savePhotoData(_ data: Data, completion: @escaping (Result<Void, Error>) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                completion(.failure(SaveError.notAuthorized))
                return
            }

            PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, data: data, options: nil)
            } completionHandler: { success, error in
                if let error {
                    completion(.failure(error))
                } else if success {
                    completion(.success(()))
                } else {
                    completion(.failure(SaveError.writeFailed))
                }
            }
        }
    }

    func saveDeferredPhotoProxy(
        _ data: Data,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            guard status == .authorized || status == .limited else {
                completion(.failure(SaveError.notAuthorized))
                return
            }

            var localIdentifier: String?
            PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photoProxy, data: data, options: nil)
                localIdentifier = request.placeholderForCreatedAsset?.localIdentifier
            } completionHandler: { success, error in
                if let error {
                    completion(.failure(error))
                } else if success, let localIdentifier {
                    completion(.success(localIdentifier))
                } else {
                    completion(.failure(SaveError.writeFailed))
                }
            }
        }
    }

    func requestEditingSource(
        localIdentifier: String,
        attemptsRemaining: Int = 12,
        completion: @escaping (Result<EditingSource, Error>) -> Void
    ) {
        guard let asset = PHAsset.fetchAssets(
            withLocalIdentifiers: [localIdentifier],
            options: nil
        ).firstObject else {
            completion(.failure(SaveError.assetNotFound))
            return
        }

        let options = PHContentEditingInputRequestOptions()
        options.isNetworkAccessAllowed = true
        options.canHandleAdjustmentData = { _ in false }
        asset.requestContentEditingInput(with: options) { [weak self] input, _ in
            guard let input,
                  let sourceURL = input.fullSizeImageURL,
                  let image = CIImage(
                    contentsOf: sourceURL,
                    options: [.applyOrientationProperty: true]
                  ) else {
                guard attemptsRemaining > 1 else {
                    completion(.failure(SaveError.sourceUnavailable))
                    return
                }

                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1.5) {
                    self?.requestEditingSource(
                        localIdentifier: localIdentifier,
                        attemptsRemaining: attemptsRemaining - 1,
                        completion: completion
                    )
                }
                return
            }

            completion(.success(EditingSource(asset: asset, input: input, image: image)))
        }
    }

    func commitAdjustedPhoto(
        _ image: CIImage,
        source: EditingSource,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let output = PHContentEditingOutput(contentEditingInput: source.input)
        let renderedURL = output.renderedContentURL
        let renderedType = output.defaultRenderedContentType ?? .jpeg

        guard writeImage(image, to: renderedURL, type: renderedType) else {
            completion(.failure(SaveError.encodingFailed))
            return
        }

        let adjustmentPayload = try? JSONSerialization.data(withJSONObject: [
            "renderer": "StyleCamera",
            "version": 1
        ])
        output.adjustmentData = PHAdjustmentData(
            formatIdentifier: "com.stylecamera.rendered-photo",
            formatVersion: "1.0",
            data: adjustmentPayload ?? Data()
        )

        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest(for: source.asset).contentEditingOutput = output
        } completionHandler: { success, error in
            if let error {
                completion(.failure(error))
            } else if success {
                completion(.success(()))
            } else {
                completion(.failure(SaveError.writeFailed))
            }
        }
    }

    private func writeImage(_ image: CIImage, to url: URL, type: UTType) -> Bool {
        let context = CIContext(options: [
            .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB) as Any,
            .outputColorSpace: CGColorSpace(name: CGColorSpace.sRGB) as Any
        ])
        guard let cgImage = context.createCGImage(image, from: image.extent),
              let destination = CGImageDestinationCreateWithURL(
                url as CFURL,
                type.identifier as CFString,
                1,
                nil
              ) else {
            return false
        }

        CGImageDestinationAddImage(
            destination,
            cgImage,
            [
                kCGImageDestinationLossyCompressionQuality: 0.98,
                kCGImagePropertyColorModel: kCGImagePropertyColorModelRGB,
                kCGImagePropertyProfileName: "sRGB IEC61966-2.1"
            ] as CFDictionary
        )
        return CGImageDestinationFinalize(destination)
    }
}
