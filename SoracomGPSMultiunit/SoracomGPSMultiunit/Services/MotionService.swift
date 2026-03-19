import Foundation
import CoreMotion
import Combine

/// Core Motion を使って加速度センサーデータを取得するサービス
@MainActor
class MotionService: ObservableObject {
    @Published var acceleration: CMAcceleration = CMAcceleration(x: 0, y: 0, z: 0)
    @Published var isAvailable: Bool = false
    @Published var motionError: Error?

    private let motionManager = CMMotionManager()
    private let updateInterval: TimeInterval = 0.1

    init() {
        isAvailable = motionManager.isAccelerometerAvailable
    }

    func startUpdating() {
        guard motionManager.isAccelerometerAvailable else {
            return
        }
        motionManager.accelerometerUpdateInterval = updateInterval
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
            Task { @MainActor [weak self] in
                if let error {
                    self?.motionError = error
                    return
                }
                if let acceleration = data?.acceleration {
                    self?.acceleration = acceleration
                }
            }
        }
    }

    func stopUpdating() {
        if motionManager.isAccelerometerActive {
            motionManager.stopAccelerometerUpdates()
        }
    }
}
