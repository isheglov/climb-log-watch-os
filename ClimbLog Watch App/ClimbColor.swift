import Foundation
import SwiftUI

struct ClimbColor: Equatable, Codable {
    let name: String
    let hex: String

    init(name: String) {
        self.name = name
        // Normalize name to lowercase for matching
        let key = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        // Basic mapping of common climbing hold colors to hex values
        switch key {
        case "red":
            self.hex = "#FF3B30"
        case "orange":
            self.hex = "#FF9500"
        case "yellow":
            self.hex = "#FFCC00"
        case "green":
            self.hex = "#34C759"
        case "mint":
            self.hex = "#00C7BE"
        case "teal":
            self.hex = "#30B0C7"
        case "cyan", "blue":
            self.hex = "#007AFF"
        case "indigo":
            self.hex = "#5856D6"
        case "purple":
            self.hex = "#AF52DE"
        case "pink":
            self.hex = "#FF2D55"
        case "brown":
            self.hex = "#A2845E"
        case "black":
            self.hex = "#000000"
        case "white":
            self.hex = "#FFFFFF"
        case "gray", "grey":
            self.hex = "#8E8E93"
        default:
            // Fallback to a neutral gray if unknown
            self.hex = "#8E8E93"
        }
    }

    var swiftUIColor: Color {
        Color(hex: hex)
    }
}

// Convenience Color initializer from hex strings like "#RRGGBB" or "RRGGBB"
private extension Color {
    init(hex: String) {
        let r, g, b, a: Double
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexString.hasPrefix("#") {
            hexString.removeFirst()
        }
        var int = UInt64()
        Scanner(string: hexString).scanHexInt64(&int)
        switch hexString.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255.0
            g = Double((int >> 8) & 0xFF) / 255.0
            b = Double(int & 0xFF) / 255.0
            a = 1.0
        case 8:
            r = Double((int >> 24) & 0xFF) / 255.0
            g = Double((int >> 16) & 0xFF) / 255.0
            b = Double((int >> 8) & 0xFF) / 255.0
            a = Double(int & 0xFF) / 255.0
        default:
            r = 142/255.0; g = 142/255.0; b = 147/255.0; a = 1.0
        }
        self = Color(red: r, green: g, blue: b, opacity: a)
    }
}
