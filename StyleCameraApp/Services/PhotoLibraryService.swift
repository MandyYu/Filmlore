import Foundation
import Photos

final class PhotoLibraryService {
    enum SaveError: Error {
        case notAuthorized
        case writeFailed
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
}
