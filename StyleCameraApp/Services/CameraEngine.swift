import AVFoundation
import CoreImage
import Foundation
import ImageIO
import StyleCameraCore
import UIKit

final class CameraEngine: NSObject {
    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "stylecamera.session.queue")
    private let videoQueue = DispatchQueue(label: "stylecamera.video.queue")
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private var currentInput: AVCaptureDeviceInput?
    private var currentPosition: AVCaptureDevice.Position = .back
    private var requestedZoomFactor: CGFloat = 1
    private var lastPhotoRotationAngle: CGFloat = 90
    private var captureRequestIDs: [Int64: UUID] = [:]
    private let captureRequestLock = NSLock()

    var onPreviewFrame: ((CIImage) -> Void)?
    var onPhotoCaptured: ((UUID, CIImage) -> Void)?
    var onDeferredPhotoCaptured: ((UUID, CIImage, Data) -> Void)?
    var onPhotoCaptureFailed: ((UUID) -> Void)?

    func configure() {
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard granted else { return }
            self?.sessionQueue.async {
                self?.configureSession(position: .back)
            }
        }
    }

    func stop() {
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    func capturePhoto(requestID: UUID, flashMode: AVCaptureDevice.FlashMode) {
        sessionQueue.async {
            let settings = AVCapturePhotoSettings()
            settings.photoQualityPrioritization = .quality
            if self.photoOutput.maxPhotoDimensions.width > 0,
               self.photoOutput.maxPhotoDimensions.height > 0 {
                settings.maxPhotoDimensions = self.photoOutput.maxPhotoDimensions
            }
            if self.photoOutput.supportedFlashModes.contains(flashMode) {
                settings.flashMode = flashMode
            }
            self.captureRequestLock.lock()
            self.captureRequestIDs[settings.uniqueID] = requestID
            self.captureRequestLock.unlock()
            self.updatePhotoOrientationForCapture()
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    func flipCamera() {
        sessionQueue.async {
            let next: AVCaptureDevice.Position = self.currentPosition == .back ? .front : .back
            self.configureSession(position: next)
        }
    }

    func setZoomFactor(_ zoomFactor: CGFloat) {
        setZoomFactor(zoomFactor, animated: true)
    }

    func setZoomFactor(_ zoomFactor: CGFloat, animated: Bool) {
        sessionQueue.async {
            self.requestedZoomFactor = zoomFactor
            guard let device = self.currentInput?.device else { return }
            self.applyDisplayedZoomFactor(zoomFactor, to: device, animated: animated)
        }
    }

    func setFocusAndExposure(at point: CGPoint) {
        sessionQueue.async {
            guard let device = self.currentInput?.device else { return }
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }

                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = point
                    if device.isFocusModeSupported(.autoFocus) {
                        device.focusMode = .autoFocus
                    } else if device.isFocusModeSupported(.continuousAutoFocus) {
                        device.focusMode = .continuousAutoFocus
                    }
                }
                if device.isExposurePointOfInterestSupported {
                    device.exposurePointOfInterest = point
                    if device.isExposureModeSupported(.autoExpose) {
                        device.exposureMode = .autoExpose
                    } else if device.isExposureModeSupported(.continuousAutoExposure) {
                        device.exposureMode = .continuousAutoExposure
                    }
                }
            } catch {
                return
            }
        }
    }

    private func configureSession(position: AVCaptureDevice.Position) {
        session.beginConfiguration()
        session.sessionPreset = .photo

        if let currentInput {
            session.removeInput(currentInput)
        }

        guard let device = preferredDevice(position: position),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }

        session.addInput(input)
        currentInput = input
        currentPosition = position
        applyDisplayedZoomFactor(requestedZoomFactor, to: device, animated: false)

        if videoOutput.sampleBufferDelegate == nil {
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            videoOutput.setSampleBufferDelegate(self, queue: videoQueue)

            if session.canAddOutput(videoOutput) {
                session.addOutput(videoOutput)
            }
        }

        if !session.outputs.contains(photoOutput), session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }

        configurePhotoOutput(for: device)

        updateVideoOrientation()
        session.commitConfiguration()

        if !session.isRunning {
            session.startRunning()
        }
    }

    private func preferredDevice(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        if position == .back,
           let triple = AVCaptureDevice.default(.builtInTripleCamera, for: .video, position: position) {
            return triple
        }

        if position == .back,
           let dualWide = AVCaptureDevice.default(.builtInDualWideCamera, for: .video, position: position) {
            return dualWide
        }

        return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
    }

    private func configurePhotoOutput(for device: AVCaptureDevice) {
        photoOutput.maxPhotoQualityPrioritization = .quality

        guard let preferredDimensions = preferredPhotoDimensions(
            from: device.activeFormat.supportedMaxPhotoDimensions
        ) else {
            return
        }

        photoOutput.maxPhotoDimensions = preferredDimensions

        if photoOutput.isResponsiveCaptureSupported {
            photoOutput.isResponsiveCaptureEnabled = true
        }
        if photoOutput.isZeroShutterLagSupported {
            photoOutput.isZeroShutterLagEnabled = true
        }
        if photoOutput.isAutoDeferredPhotoDeliverySupported {
            photoOutput.isAutoDeferredPhotoDeliveryEnabled = true
        }
    }

    private func preferredPhotoDimensions(from dimensions: [CMVideoDimensions]) -> CMVideoDimensions? {
        guard !dimensions.isEmpty else { return nil }

        let twentyFourMegapixels: Int64 = 24_000_000
        let twentyFourMegapixelCandidates = dimensions.filter {
            let pixels = Int64($0.width) * Int64($0.height)
            return pixels >= 20_000_000 && pixels <= 30_000_000
        }

        if let closest24MP = twentyFourMegapixelCandidates.min(by: {
            abs(Int64($0.width) * Int64($0.height) - twentyFourMegapixels)
                < abs(Int64($1.width) * Int64($1.height) - twentyFourMegapixels)
        }) {
            return closest24MP
        }

        let nonFortyEightMegapixelDimensions = dimensions.filter {
            Int64($0.width) * Int64($0.height) < 30_000_000
        }
        return (nonFortyEightMegapixelDimensions.isEmpty
            ? dimensions
            : nonFortyEightMegapixelDimensions).max(by: {
            Int64($0.width) * Int64($0.height) < Int64($1.width) * Int64($1.height)
        })
    }

    private func applyDisplayedZoomFactor(
        _ displayedZoomFactor: CGFloat,
        to device: AVCaptureDevice,
        animated: Bool
    ) {
        do {
            try device.lockForConfiguration()
            let normalLensHardwareZoom = normalLensHardwareZoomFactor(for: device)
            let maxHardwareZoom = min(device.activeFormat.videoMaxZoomFactor, max(10, normalLensHardwareZoom * 10))
            let hardwareZoomFactor = ZoomFactorMapper.hardwareZoom(
                displayedZoom: displayedZoomFactor,
                normalLensHardwareZoom: normalLensHardwareZoom,
                minHardwareZoom: device.minAvailableVideoZoomFactor,
                maxHardwareZoom: maxHardwareZoom
            )

            if animated, abs(device.videoZoomFactor - hardwareZoomFactor) > 0.03 {
                device.cancelVideoZoomRamp()
                device.ramp(toVideoZoomFactor: hardwareZoomFactor, withRate: 18)
            } else {
                if device.isRampingVideoZoom {
                    device.cancelVideoZoomRamp()
                }
                device.videoZoomFactor = hardwareZoomFactor
            }
            device.unlockForConfiguration()
        } catch {
            return
        }
    }

    private func normalLensHardwareZoomFactor(for device: AVCaptureDevice) -> CGFloat {
        let usesUltraWideBaseline = device.deviceType == .builtInDualWideCamera
            || device.deviceType == .builtInTripleCamera

        guard usesUltraWideBaseline else {
            return 1
        }

        let switchOverFactors = device.virtualDeviceSwitchOverVideoZoomFactors
            .map { CGFloat(truncating: $0) }
            .filter { $0 > 1 }
            .sorted()

        return switchOverFactors.first ?? 2
    }

    private func updateVideoOrientation() {
        if let connection = videoOutput.connection(with: .video) {
            connection.videoRotationAngle = 90

            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = currentPosition == .front
            }
        }

        updatePhotoOrientationForCapture()
    }

    private func updatePhotoOrientationForCapture() {
        guard let connection = photoOutput.connection(with: .video) else {
            return
        }

        let angle = Self.photoRotationAngle(for: UIDevice.current.orientation) ?? lastPhotoRotationAngle
        lastPhotoRotationAngle = angle
        connection.videoRotationAngle = angle

        if connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = currentPosition == .front
        }
    }

    private static func photoRotationAngle(for orientation: UIDeviceOrientation) -> CGFloat? {
        switch orientation {
        case .portrait:
            return 90
        case .portraitUpsideDown:
            return 270
        case .landscapeLeft:
            return 0
        case .landscapeRight:
            return 180
        case .faceUp, .faceDown, .unknown:
            return nil
        @unknown default:
            return nil
        }
    }
}

extension CameraEngine: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        onPreviewFrame?(CIImage(cvPixelBuffer: pixelBuffer))
    }
}

extension CameraEngine: AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings,
        error: Error?
    ) {
        guard error != nil,
              let requestID = requestID(for: resolvedSettings.uniqueID) else {
            return
        }
        finishCapture(requestID: requestID, uniqueID: resolvedSettings.uniqueID, failed: true)
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard let requestID = requestID(for: photo.resolvedSettings.uniqueID) else {
            return
        }
        guard error == nil else {
            finishCapture(requestID: requestID, uniqueID: photo.resolvedSettings.uniqueID, failed: true)
            return
        }

        guard let image = orientedImage(from: photo) else {
            finishCapture(requestID: requestID, uniqueID: photo.resolvedSettings.uniqueID, failed: true)
            return
        }
        onPhotoCaptured?(requestID, image)
        finishCapture(requestID: requestID, uniqueID: photo.resolvedSettings.uniqueID, failed: false)
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishCapturingDeferredPhotoProxy deferredPhotoProxy: AVCaptureDeferredPhotoProxy?,
        error: Error?
    ) {
        guard let proxy = deferredPhotoProxy,
              let requestID = requestID(for: proxy.resolvedSettings.uniqueID) else {
            return
        }
        guard error == nil,
              let image = orientedImage(from: proxy),
              let data = proxy.fileDataRepresentation() else {
            finishCapture(requestID: requestID, uniqueID: proxy.resolvedSettings.uniqueID, failed: true)
            return
        }

        onDeferredPhotoCaptured?(requestID, image, data)
        finishCapture(requestID: requestID, uniqueID: proxy.resolvedSettings.uniqueID, failed: false)
    }

    private func orientedImage(from photo: AVCapturePhoto) -> CIImage? {
        if let cgImage = photo.cgImageRepresentation() {
            let exifOrientation = (
                photo.metadata[String(kCGImagePropertyOrientation)] as? NSNumber
            )?.int32Value ?? 1
            return CIImage(cgImage: cgImage).oriented(forExifOrientation: exifOrientation)
        }

        guard let data = photo.fileDataRepresentation() else { return nil }
        return CIImage(data: data, options: [.applyOrientationProperty: true])
    }

    private func requestID(for uniqueID: Int64) -> UUID? {
        captureRequestLock.lock()
        defer { captureRequestLock.unlock() }
        return captureRequestIDs[uniqueID]
    }

    private func finishCapture(requestID: UUID, uniqueID: Int64, failed: Bool) {
        captureRequestLock.lock()
        captureRequestIDs.removeValue(forKey: uniqueID)
        captureRequestLock.unlock()

        if failed {
            onPhotoCaptureFailed?(requestID)
        }
    }
}
