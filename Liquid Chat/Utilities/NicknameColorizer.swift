//
//  NicknameColorizer.swift
//  Liquid Chat
//
//  Generates consistent colors for nicknames
//

import SwiftUI

struct NicknameColorizer {
    /// Generate a consistent color for a nickname
    static func color(for nickname: String) -> Color {
        let hash = nickname.lowercased().hash
        let hue = Double(abs(hash) % 360) / 360.0
        
        // Use vibrant colors with good saturation and lightness
        return Color(hue: hue, saturation: 0.7, brightness: 0.8)
    }
    
    /// Get a contrasting text color (for use on colored backgrounds)
    static func textColor(for backgroundColor: Color) -> Color {
        // Simple heuristic - could be improved with actual luminance calculation
        return .white
    }
}
