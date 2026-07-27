import CoreMotion
import Foundation

final class MotionLevelService {
    var onRollDegreesChange: ((Double) -> Void)?

    private let manager = CMMotionManager()
    private let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "stylecamera.motion.level.queue"
        queue.qualityOfService = .userInteractive
        return queue
    }()

    func start() {
        guard manager.isDeviceMotionAvailable,
              !manager.isDeviceMotionActive else {
            return
        }

        manager.deviceMotionUpdateInterval = 0.2
        manager.startDeviceMotionUpdates(to: queue) { [weak self] motion, _ in
            guard let gravity = motion?.gravity else {
                return
            }

            let radians = atan2(gravity.x, -gravity.y)
            let degrees = radians * 180 / .pi
            self?.onRollDegreesChange?(degrees)
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }
}

