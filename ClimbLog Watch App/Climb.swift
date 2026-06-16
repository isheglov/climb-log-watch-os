import Foundation
import SwiftUI
import WatchConnectivity
import Combine

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

    init(
        id: UUID = UUID(),
        date: Date,
        grade: String,
        colorName: String,
        colorHex: String = ClimbColor(name: "gray").hex,
        result: String? = nil,
        note: String? = nil,
        gym: String? = nil,
        sector: String? = nil
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
    }

    private enum CodingKeys: String, CodingKey {
        case id, date, grade, colorName, colorHex, result, note, gym, sector
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
    // Map color names to system colors for persistence simplicity
    static func fromName(_ name: String) -> Color {
        return ClimbColor(name: name).swiftUIColor
    }
}
