//
//  Theme.swift
//  ChickenPetHealth
//

import SwiftUI

enum AppThemeMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "Match Device"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum Theme {
    static func background(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "#1B3B35") : Color(hex: "#F4FAF2")
    }

    static func card(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "#FFF8E1").opacity(0.12) : Color.white.opacity(0.9)
    }

    static func mutedText(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.7) : Color.black.opacity(0.6)
    }

    static func overlay(for scheme: ColorScheme) -> Color {
        scheme == .dark ? background(for: scheme).opacity(0.6) : Color.white.opacity(0.8)
    }

    static let accent = Color(hex: "#FFD93D")
    static let warning = Color(hex: "#FF6B6B")
    static let calmYellow = Color(hex: "#FFEAA7")
    static let treatmentBlue = Color(hex: "#6CCFF6")

    static var accentGradient: LinearGradient {
        LinearGradient(colors: [accent, calmYellow], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
