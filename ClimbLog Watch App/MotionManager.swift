import CoreMotion
import Foundation
import Combine

@MainActor
final class MotionManager: ObservableObject {
    private let motionManager = CMMotionManager()
    private var accelerometerSamples: [CMAccelerometerData] = []
    private var gyroscopeSamples: [CMGyroData] = []
    private var timer: Timer?
    
    @Published var isRecording: Bool = false
    @Published var windows: [MotionWindow] = []

    func startRecording() {
        windows = []
        accelerometerSamples = []
        gyroscopeSamples = []
        
        guard motionManager.isAccelerometerAvailable, 
              motionManager.isGyroAvailable else { 
            print("Sensors not available")
            return 
        }
        
        motionManager.accelerometerUpdateInterval = 0.1
        motionManager.gyroUpdateInterval = 0.1
        
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            Task { @MainActor in
                if let data = data { self?.accelerometerSamples.append(data) }
            }
        }
        
        motionManager.startGyroUpdates(to: .main) { [weak self] data, _ in
            Task { @MainActor in
                if let data = data { self?.gyroscopeSamples.append(data) }
            }
        }
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.aggregateWindow()
            }
        }
        isRecording = true
    }

    func stopRecording() -> [MotionWindow] {
        timer?.invalidate()
        motionManager.stopAccelerometerUpdates()
        motionManager.stopGyroUpdates()
        isRecording = false
        return windows
    }

    private func aggregateWindow() {
        let now = Date()
        
        let accelMags = accelerometerSamples.map { 
            sqrt(pow($0.acceleration.x, 2) + pow($0.acceleration.y, 2) + pow($0.acceleration.z, 2)) 
        }
        
        let gyroMags = gyroscopeSamples.map { 
            sqrt(pow($0.rotationRate.x, 2) + pow($0.rotationRate.y, 2) + pow($0.rotationRate.z, 2)) 
        }
        
        let window = MotionWindow(
            startDate: now.addingTimeInterval(-1),
            duration: 1.0,
            accelMean: accelMags.average,
            accelStd: accelMags.stdDev,
            gyroMean: gyroMags.average,
            gyroStd: gyroMags.stdDev
        )
        
        windows.append(window)
        
        accelerometerSamples.removeAll()
        gyroscopeSamples.removeAll()
    }
}

extension Array where Element == Double {
    var average: Double {
        isEmpty ? 0 : reduce(0, +) / Double(count)
    }
    
    var stdDev: Double {
        guard count > 1 else { return 0 }
        let avg = average
        let sumOfSquaredDiffs = reduce(0) { $0 + pow($1 - avg, 2) }
        return sqrt(sumOfSquaredDiffs / Double(count - 1))
    }
}
