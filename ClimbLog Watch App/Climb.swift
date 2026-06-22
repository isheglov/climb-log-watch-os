import Foundation
import SwiftUI
import WatchConnectivity
import Combine

enum DetectionSource: String, Codable, Equatable {
    case manualSave
    case manualTimer
    case autoDetected
    case edited
}

struct MotionWindow: Identifiable, Codable, Equatable {
    let id: UUID
    let startDate: Date
    let duration: TimeInterval
    let accelMagnitudeMean: Double
    let accelMagnitudeStd: Double
    let gyroMagnitudeMean: Double
    let gyroMagnitudeStd: Double
    let heartRate: Double?

    init(id: UUID = UUID(), startDate: Date, duration: TimeInterval, accelMean: Double, accelStd: Double, gyroMean: Double, gyroStd: Double, heartRate: Double? = nil) {
        self.id = id
        self.startDate = startDate
        self.duration = duration
        self.accelMagnitudeMean = accelMean
        self.accelMagnitudeStd = accelStd
        self.gyroMagnitudeMean = gyroMean
        self.gyroMagnitudeStd = gyroStd
        self.heartRate = heartRate
    }
}

struct Climb: Identifiable, Codable, Equatable {
    let id: UUID
    var date: Date
    var grade: String
    var colorName: String
    var colorHex: String
    var result: String?
    var note: String?
    var gym: String?
    var sector: String?
    
    // New fields for Start/Stop mode
    var startDate: Date?
    var endDate: Date?
    var durationSeconds: TimeInterval?
    var detectionSource: DetectionSource = .manualSave
    var detectionConfidence: Double?
    var motionWindows: [MotionWindow]?

    init(
        id: UUID = UUID(),
        date: Date,
        grade: String,
        colorName: String,
        colorHex: String = ClimbColor(name: "gray").hex,
        result: String? = nil,
        note: String? = nil,
        gym: String? = nil,
        sector: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        durationSeconds: TimeInterval? = nil,
        detectionSource: DetectionSource = .manualSave,
        detectionConfidence: Double? = nil,
        motionWindows: [MotionWindow]? = nil
    ) {
        self.id = id
        self.date = date
        self.grade = grade
        self.colorName = colorName
        self.colorHex = colorHex == ClimbColor(name: "gray").hex ? ClimbColor(name: colorName).hex : colorHex
        self.result = result
        self.note = note
        self.gym = gym
        self.sector = sector
        self.startDate = startDate
        self.endDate = endDate
        self.durationSeconds = durationSeconds
        self.detectionSource = detectionSource
        self.detectionConfidence = detectionConfidence
        self.motionWindows = motionWindows
    }

    private enum CodingKeys: String, CodingKey {
        case id, date, grade, colorName, colorHex, result, note, gym, sector, startDate, endDate, durationSeconds, detectionSource, detectionConfidence, motionWindows
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        grade = try container.decode(String.self, forKey: .grade)
        colorName = try container.decode(String.self, forKey: .colorName)
        colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex) ?? ClimbColor(name: colorName).hex
        result = try container.decodeIfPresent(String.self, forKey: .result)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        gym = try container.decodeIfPresent(String.self, forKey: .gym)
        sector = try container.decodeIfPresent(String.self, forKey: .sector)
        startDate = try container.decodeIfPresent(Date.self, forKey: .startDate)
        endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
        durationSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .durationSeconds)
        detectionSource = try container.decodeIfPresent(DetectionSource.self, forKey: .detectionSource) ?? .manualSave
        detectionConfidence = try container.decodeIfPresent(Double.self, forKey: .detectionConfidence)
        motionWindows = try container.decodeIfPresent([MotionWindow].self, forKey: .motionWindows)
    }
}

@MainActor final class ClimbStore: ObservableObject {
    @Published private(set) var climbs: [Climb] = []

    private let storageKey = "climb_log_entries"
    private let syncManager = WatchClimbSyncManager()

    init() {
        load()
        syncManager.sendAll(climbs)
    }

    func add(_ climb: Climb) {
        climbs.insert(climb, at: 0)
        persist()
        syncManager.send(climb)
        syncManager.sendAll(climbs)
    }

    func delete(at offsets: IndexSet) {
        climbs.remove(atOffsets: offsets)
        persist()
        syncManager.sendAll(climbs)
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(climbs)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            // In a simple watch app, silently fail; could add logging if needed
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do {
            let decoded = try JSONDecoder().decode([Climb].self, from: data)
            self.climbs = decoded.sorted { $0.date > $1.date }
        } catch {
            self.climbs = []
        }
    }
}

final class WatchClimbSyncManager: NSObject, WCSessionDelegate {
    private let encoder = JSONEncoder()

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func send(_ climb: Climb) {
        guard WCSession.isSupported(), let data = try? encoder.encode(climb) else { return }
        WCSession.default.transferUserInfo(["entry": data])
    }

    func sendAll(_ climbs: [Climb]) {
        guard WCSession.isSupported(), let data = try? encoder.encode(climbs) else { return }
        try? WCSession.default.updateApplicationContext(["entries": data])
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) { }
}

extension Color {
    static func fromName(_ name: String) -> Color {
        return ClimbColor(name: name).swiftUIColor
    }
}
