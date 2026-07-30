import AVFoundation
import CoreImage
import Foundation
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

    var onPreviewFrame: ((CIImage) -> Void)?
    var onPhotoCaptured: ((Data) -> Void)?

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

    func capturePhoto(flashMode: AVCaptureDevice.FlashMode) {
        sessionQueue.async {
            let settings = AVCapturePhotoSettings()
            if self.photoOutput.supportedFlashModes.contains(flashMode) {
                settings.flashMode = flashMode
            }
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
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard error == nil,
              let data = photo.fileDataRepresentation() else {
            return
        }
        onPhotoCaptured?(data)
    }
}
