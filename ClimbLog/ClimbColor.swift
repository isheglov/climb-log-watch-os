import SwiftUI

public enum ClimbColor: String, CaseIterable, Codable, Identifiable {
    case blue
    case red
    case green
    case yellow
    case purple
    case orange
    case black
    case gray
    case mint
    case white

    public var id: String { rawValue }

    public var displayName: String {
        rawValue.capitalized
    }

    public var swiftUIColor: Color {
        switch self {
        case .blue: return .blue
        case .red: return .red
        case .green: return .green
        case .yellow: return .yellow
        case .purple: return .purple
        case .orange: return .orange
        case .black: return .black
        case .gray: return .gray
        case .mint: return .mint
        case .white: return .white
        }
    }

    public var hex: String {
        switch self {
        case .blue: return "#007AFF"
        case .red: return "#FF3B30"
        case .green: return "#34C759"
        case .yellow: return "#FFCC00"
        case .purple: return "#AF52DE"
        case .orange: return "#FF9500"
        case .black: return "#000000"
        case .gray: return "#8E8E93"
        case .mint: return "#00C7BE"
        case .white: return "#FFFFFF"
        }
    }

    // Case-insensitive initialization from any stored name or display name
    public init(name: String) {
        self = ClimbColor(rawValue: name.lowercased()) ?? .gray
    }

    public init(displayName: String) {
        self = ClimbColor(rawValue: displayName.lowercased()) ?? .gray
    }
}
