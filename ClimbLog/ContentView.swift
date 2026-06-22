//
//  ContentView.swift
//  ClimbLog
//
//  Created by Ilia Shcheglov on 13.06.26.
//

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

struct ClimbLogEntry: Identifiable, Codable, Equatable {
    let id: UUID
    var grade: String
    var colorName: String
    var colorHex: String
    var date: Date
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
        grade: String,
        colorName: String,
        colorHex: String = ClimbColor(name: "gray").hex,
        date: Date,
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
        self.grade = grade
        self.colorName = colorName
        self.colorHex = colorHex
        self.date = date
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
}

@MainActor
final class ClimbLogStore: NSObject, ObservableObject {
    @Published private(set) var entries: [ClimbLogEntry] = []

    private let storageKey = "climb_log_entries"
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    override init() {
        super.init()
        load()
        configureWatchConnectivity()
    }

    func delete(_ entry: ClimbLogEntry) {
        entries.removeAll { $0.id == entry.id }
        persist()
    }

    func delete(at offsets: IndexSet, from visibleEntries: [ClimbLogEntry]) {
        let idsToDelete = offsets.map { visibleEntries[$0].id }
        entries.removeAll { idsToDelete.contains($0.id) }
        persist()
    }

    func update(_ entry: ClimbLogEntry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[index] = entry
        sortAndPersist()
    }

    func merge(_ incomingEntries: [ClimbLogEntry]) {
        var mergedByID = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
        for entry in incomingEntries {
            mergedByID[entry.id] = entry
        }
        entries = Array(mergedByID.values).sorted { $0.date > $1.date }
        persist()
    }

    private func sortAndPersist() {
        entries.sort { $0.date > $1.date }
        persist()
    }

    private func persist() {
        do {
            let data = try encoder.encode(entries)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            assertionFailure("Failed to save climbs: \(error)")
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do {
            entries = try decoder.decode([ClimbLogEntry].self, from: data).sorted { $0.date > $1.date }
        } catch {
            entries = []
        }
    }

    private func configureWatchConnectivity() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    private func handleWatchPayload(_ payload: [String: Any]) {
        if let data = payload["entries"] as? Data,
           let decodedEntries = try? decoder.decode([ClimbLogEntry].self, from: data) {
            merge(decodedEntries)
            return
        }

        if let data = payload["entry"] as? Data,
           let decodedEntry = try? decoder.decode(ClimbLogEntry.self, from: data) {
            merge([decodedEntry])
        }
    }
}

extension ClimbLogStore: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) { }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        Task { @MainActor in
            self.handleWatchPayload(userInfo)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in
            self.handleWatchPayload(applicationContext)
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) { }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}

struct ContentView: View {
    @StateObject private var store = ClimbLogStore()

    var body: some View {
        TabView {
            TodayView(store: store)
                .tabItem {
                    Label("Today", systemImage: "calendar.day.timeline.left")
                }

            HistoryView(store: store)
                .tabItem {
                    Label("History", systemImage: "list.bullet.rectangle")
                }

            StatsView(entries: store.entries)
                .tabItem {
                    Label("Stats", systemImage: "chart.bar")
                }
        }
    }
}

struct TodayView: View {
    @ObservedObject var store: ClimbLogStore

    private var todayEntries: [ClimbLogEntry] {
        store.entries.filter { Calendar.current.isDateInToday($0.date) }
    }

    var body: some View {
        NavigationStack {
            List {
                TodaySummaryCard(entries: todayEntries)
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)

                if todayEntries.isEmpty {
                    ContentUnavailableView("No climbs today", systemImage: "figure.climbing", description: Text("Saved climbs from the watch will appear here."))
                } else {
                    ForEach(todayEntries) { entry in
                        ClimbEntryRow(entry: entry)
                    }
                    .onDelete { offsets in
                        store.delete(at: offsets, from: todayEntries)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Today")
        }
    }
}

struct TodaySummaryCard: View {
    let entries: [ClimbLogEntry]

    private var gradeRange: String? {
        let sortedGrades = entries.map(\.grade).sorted(by: GradeCatalog.compare)
        guard let first = sortedGrades.first, let last = sortedGrades.last else { return nil }
        return first == last ? first : "\(first)-\(last)"
    }

    private var mostFrequentColor: String? {
        entries.map { ClimbColor(name: $0.colorName).displayName }.mostFrequent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Today")
                    .font(.headline)
                Spacer()
                Text("\(entries.count)")
                    .font(.title.bold())
                    .monospacedDigit()
                Text(entries.count == 1 ? "climb" : "climbs")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                SummaryMetric(title: "Grade range", value: gradeRange ?? "-", systemImage: "arrow.up.arrow.down")
                SummaryMetric(title: "Top color", value: mostFrequentColor ?? "-", systemImage: "circle.fill")
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct SummaryMetric: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct HistoryView: View {
    @ObservedObject var store: ClimbLogStore

    private var groupedEntries: [(date: Date, entries: [ClimbLogEntry])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: store.entries) { entry in
            calendar.startOfDay(for: entry.date)
        }
        return groups
            .map { (date: $0.key, entries: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            List {
                if store.entries.isEmpty {
                    ContentUnavailableView("No saved climbs", systemImage: "list.bullet.rectangle", description: Text("Log climbs on Apple Watch to review them here."))
                } else {
                    ForEach(groupedEntries, id: \.date) { group in
                        Section(group.date.formatted(date: .abbreviated, time: .omitted)) {
                            ForEach(group.entries) { entry in
                                NavigationLink {
                                    ClimbDetailView(store: store, entryID: entry.id)
                                } label: {
                                    ClimbEntryRow(entry: entry)
                                }
                            }
                            .onDelete { offsets in
                                store.delete(at: offsets, from: group.entries)
                            }
                        }
                    }
                }
            }
            .navigationTitle("History")
        }
    }
}

struct ClimbDetailView: View {
    @ObservedObject var store: ClimbLogStore
    let entryID: UUID
    @Environment(\.dismiss) private var dismiss

    private var entry: ClimbLogEntry? {
        store.entries.first { $0.id == entryID }
    }

    var body: some View {
        Group {
            if let entry {
                Form {
                    Section("Climb") {
                        Picker("Grade", selection: binding(for: entry, keyPath: \.grade)) {
                            ForEach(GradeCatalog.grades, id: \.self) { grade in
                                Text(grade).tag(grade)
                            }
                        }

                        Picker("Color", selection: colorBinding(for: entry)) {
                            ForEach(ClimbColor.allCases) { option in
                                Label(option.displayName, systemImage: "circle.fill")
                                    .foregroundStyle(option.swiftUIColor)
                                    .tag(option.displayName)
                            }
                        }
                    }

                    Section("Details") {
                        LabeledContent("Grade", value: entry.grade)
                        LabeledContent("Color", value: ClimbColor(name: entry.colorName).displayName)
                        LabeledContent("Date", value: entry.date.formatted(date: .abbreviated, time: .shortened))
                        
                        if let duration = entry.durationSeconds {
                            LabeledContent("Duration", value: duration.formattedDuration())
                        }
                        
                        LabeledContent("Source", value: entry.detectionSource.rawValue.capitalized)
                    }

                    Section {
                        Button(role: .destructive) {
                            store.delete(entry)
                            dismiss()
                        } label: {
                            Label("Delete Entry", systemImage: "trash")
                        }
                    }
                }
                .navigationTitle("Climb")
            } else {
                ContentUnavailableView("Climb deleted", systemImage: "trash")
            }
        }
    }

    private func binding(for entry: ClimbLogEntry, keyPath: WritableKeyPath<ClimbLogEntry, String>) -> Binding<String> {
        Binding(
            get: { self.entry?[keyPath: keyPath] ?? entry[keyPath: keyPath] },
            set: { newValue in
                var updatedEntry = entry
                updatedEntry[keyPath: keyPath] = newValue
                store.update(updatedEntry)
            }
        )
    }

    private func colorBinding(for entry: ClimbLogEntry) -> Binding<String> {
        Binding(
            get: { ClimbColor(name: self.entry?.colorName ?? entry.colorName).displayName },
            set: { newValue in
                var updatedEntry = entry
                let selected = ClimbColor(displayName: newValue)
                updatedEntry.colorName = selected.rawValue
                updatedEntry.colorHex = selected.hex
                store.update(updatedEntry)
            }
        )
    }
}

struct StatsView: View {
    let entries: [ClimbLogEntry]

    private var weekEntries: [ClimbLogEntry] {
        entries.filter { Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .weekOfYear) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("This week", value: "\(weekEntries.count) climbs")
                        .font(.headline)
                }

                CountSection(title: "Grades", counts: countsByGrade)
                CountSection(title: "Colors", counts: countsByColor)
            }
            .navigationTitle("Stats")
        }
    }

    private var countsByGrade: [(String, Int)] {
        Dictionary(grouping: entries, by: \.grade)
            .map { ($0.key, $0.value.count) }
            .sorted { GradeCatalog.compare($0.0, $1.0) }
    }

    private var countsByColor: [(String, Int)] {
        Dictionary(grouping: entries, by: { ClimbColor(name: $0.colorName).displayName })
            .map { ($0.key, $0.value.count) }
            .sorted { $0.1 == $1.1 ? $0.0 < $1.0 : $0.1 > $1.1 }
    }
}

struct CountSection: View {
    let title: String
    let counts: [(String, Int)]

    var body: some View {
        Section(title) {
            if counts.isEmpty {
                Text("No data yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(counts, id: \.0) { label, count in
                    LabeledContent(label, value: "\(count)")
                }
            }
        }
    }
}

struct ClimbEntryRow: View {
    let entry: ClimbLogEntry

    var body: some View {
        let colorEnum = ClimbColor(name: entry.colorName)

        HStack(spacing: 12) {
            Text(entry.date, format: .dateTime.hour().minute())
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .leading)

            Circle()
                .fill(colorEnum.swiftUIColor)
                .frame(width: 14, height: 14)
                .overlay(
                    Circle().stroke(Color.primary.opacity(colorEnum == .white ? 0.35 : 0), lineWidth: 1)
                )

            Text(colorEnum.displayName)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let duration = entry.durationSeconds {
                Text(duration.formattedDuration())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .frame(width: 40, alignment: .trailing)
            }

            Text(entry.grade)
                .fontWeight(.semibold)
        }
        .contentShape(Rectangle())
    }
}

enum GradeCatalog {
    nonisolated(unsafe) static let grades: [String] = ["4-", "4", "4+", "5-", "5", "5+", "6-", "6", "6+", "7-", "7", "7+", "8-", "8", "8+", "9-", "9", "9+", "10-", "10", "10+", "11-", "11", "11+"]

    nonisolated static func compare(_ lhs: String, _ rhs: String) -> Bool {
        rank(lhs) < rank(rhs)
    }

    nonisolated private static func rank(_ grade: String) -> Int {
        grades.firstIndex(of: grade) ?? Int.max
    }
}

extension Array where Element == String {
    var mostFrequent: String? {
        var counts: [String: Int] = [:]
        for item in self {
            counts[item, default: 0] += 1
        }

        return counts
            .sorted { lhs, rhs in
                lhs.value == rhs.value ? lhs.key < rhs.key : lhs.value > rhs.value
            }
            .first?.key
    }
}

extension TimeInterval {
    func formattedDuration() -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: self) ?? "0:00"
    }
}

#Preview {
    ContentView()
}
