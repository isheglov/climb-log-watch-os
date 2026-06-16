//
//  ContentView.swift
//  test44444444 Watch App
//
//  Created by Ilia Shcheglov on 27.05.26.
//

import SwiftUI
import WatchKit

struct ContentView: View {
    @StateObject private var store = ClimbStore()

    @State private var selectedGrade: String = "4"
    @State private var selectedColorName: String = "blue"
    @State private var showSavedTick: Bool = false
    @State private var lastSavedClimb: Climb? = nil

    private let grades: [String] = ["4-", "4", "4+", "5-", "5", "5+", "6-", "6", "6+", "7-", "7", "7+", "8-", "8", "8+", "9-", "9", "9+", "10-", "10", "10+", "11-", "11", "11+"]
    private let colorOptions: [(name: String, color: Color)] = [
        ("blue", .blue), ("red", .red), ("green", .green), ("yellow", .yellow), ("purple", .purple), ("orange", .orange), ("black", .black), ("gray", .gray), ("mint", .mint), ("white", .white)
    ]

    private var selectedColor: Color {
        Color.fromName(selectedColorName)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                NavigationLink {
                    GradeSelectionView(grades: grades, selectedGrade: $selectedGrade)
                } label: {
                    VStack(spacing: 0) {
                        Text("Grade")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(selectedGrade)
                            .font(.system(size: 48, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity, minHeight: 70)
                    .padding(.trailing, 24)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.trailing, 24)

                NavigationLink {
                    ColorSelectionView(colorOptions: colorOptions, selectedColorName: $selectedColorName)
                } label: {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(selectedColor)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Circle().stroke(Color.primary.opacity(selectedColorName == "white" ? 0.35 : 0), lineWidth: 1)
                            )
                        Text(selectedColorName.capitalized)
                            .font(.title3.weight(.medium))
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)

                if showSavedTick, lastSavedClimb != nil {
                    Button("Undo", action: undoLastSave)
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.bordered)
                }

                Button(action: saveClimb) {
                    HStack {
                        Image(systemName: showSavedTick ? "checkmark.circle.fill" : "plus.circle")
                        Text(showSavedTick ? "Saved" : "Save")
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        ClimbLogListView(store: store)
                    } label: {
                        Image(systemName: "list.bullet")
                    }
                    .labelStyle(.iconOnly)
                }
            }
        }
    }

    private func saveClimb() {
        let newClimb = Climb(date: Date(), grade: selectedGrade, colorName: selectedColorName)
        store.add(newClimb)
        lastSavedClimb = newClimb

        WKInterfaceDevice.current().play(.success)

        withAnimation { showSavedTick = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation { showSavedTick = false }
        }
    }

    private func undoLastSave() {
        guard let lastSavedClimb, store.climbs.first?.id == lastSavedClimb.id else { return }
        store.delete(at: IndexSet(integer: 0))
        self.lastSavedClimb = nil
        withAnimation { showSavedTick = false }
    }
}

struct ClimbLogListView: View {
    @ObservedObject var store: ClimbStore

    var body: some View {
        List {
            if store.climbs.isEmpty {
                Text("No climbs saved")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.climbs) { climb in
                    ClimbLogRow(climb: climb)
                }
                .onDelete(perform: store.delete)
            }
        }
        .navigationTitle("Log")
    }
}

struct ClimbLogRow: View {
    let climb: Climb

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.fromName(climb.colorName))
                .frame(width: 14, height: 14)
                .overlay(
                    Circle().stroke(Color.primary.opacity(climb.colorName == "white" ? 0.35 : 0), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(climb.colorName.capitalized)
                        .lineLimit(1)
                    Text(climb.grade)
                        .fontWeight(.semibold)
                    Spacer(minLength: 0)
                }
                .font(.headline)

                Text(climb.date, format: .dateTime.hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
    }
}

struct GradeSelectionView: View {
    let grades: [String]
    @Binding var selectedGrade: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List(grades, id: \.self) { grade in
            Button {
                selectedGrade = grade
                WKInterfaceDevice.current().play(.click)
                dismiss()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark")
                        .font(.headline.weight(.semibold))
                        .opacity(selectedGrade == grade ? 1 : 0)
                        .frame(width: 20)
                    Text(grade)
                        .font(.title3.weight(.medium))
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .navigationTitle("Grade")
    }
}

struct ColorSelectionView: View {
    let colorOptions: [(name: String, color: Color)]
    @Binding var selectedColorName: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List(colorOptions, id: \.name) { option in
            Button {
                selectedColorName = option.name
                WKInterfaceDevice.current().play(.click)
                dismiss()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark")
                        .font(.headline.weight(.semibold))
                        .opacity(selectedColorName == option.name ? 1 : 0)
                        .frame(width: 20)
                    Circle()
                        .fill(option.color)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Circle().stroke(Color.primary.opacity(option.name == "white" ? 0.35 : 0), lineWidth: 1)
                        )
                    Text(option.name.capitalized)
                        .font(.title3.weight(.medium))
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .navigationTitle("Color")
    }
}

#Preview {
    ContentView()
}
