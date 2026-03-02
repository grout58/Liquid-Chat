//
//  NicknameColorizer.swift
//  Liquid Chat
//
//  Generates consistent colors for nicknames
//

import SwiftUI

struct NicknameColorizer {
    /// Generate a consistent color for a nickname, adapted for the current color scheme.
    /// Dark mode uses higher brightness (0.85) so colors don't muddy against dark backgrounds.
    /// Light mode uses lower brightness (0.6) and higher saturation so colors don't wash out.
    static func color(for nickname: String, colorScheme: ColorScheme = .dark) -> Color {
        let hash = nickname.lowercased().hash
        // Use .magnitude to avoid abs(Int.min) integer overflow (undefined behaviour)
        let hue = Double(hash.magnitude % 360) / 360.0

        switch colorScheme {
        case .dark:
            return Color(hue: hue, saturation: 0.7, brightness: 0.85)
        default:
            return Color(hue: hue, saturation: 0.85, brightness: 0.55)
        }
    }

    /// Get a contrasting text color (for use on colored backgrounds)
    static func textColor(for backgroundColor: Color) -> Color {
        return .white
    }
}
