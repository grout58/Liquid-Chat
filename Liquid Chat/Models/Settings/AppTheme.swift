//
//  AppTheme.swift
//  Liquid Chat
//
//  Theme management with popular color schemes
//

import SwiftUI

/// Theme color palette
struct ThemeColors {
    let background: Color
    let secondaryBackground: Color
    let text: Color
    let secondaryText: Color
    let accent: Color
    let success: Color
    let warning: Color
    let error: Color
    
    static let systemLight = ThemeColors(
        background: Color(nsColor: .windowBackgroundColor),
        secondaryBackground: Color(nsColor: .controlBackgroundColor),
        text: Color.primary,
        secondaryText: Color.secondary,
        accent: Color.accentColor,
        success: Color.green,
        warning: Color.orange,
        error: Color.red
    )
    
    static let systemDark = ThemeColors(
        background: Color(nsColor: .windowBackgroundColor),
        secondaryBackground: Color(nsColor: .controlBackgroundColor),
        text: Color.primary,
        secondaryText: Color.secondary,
        accent: Color.accentColor,
        success: Color.green,
        warning: Color.orange,
        error: Color.red
    )
}

/// Available appearance themes
enum AppTheme: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    case solarizedLight = "Solarized Light"
    case solarizedDark = "Solarized Dark"
    case gruvboxLight = "Gruvbox Light"
    case gruvboxDark = "Gruvbox Dark"
    case nord = "Nord"
    case tokyoNight = "Tokyo Night"
    case draculaLight = "Dracula Light"
    case draculaDark = "Dracula Dark"
    case psychedelic = "Psychedelic"
    case gameBoy = "Game Boy"
    case zelda = "Hyrule"
    
    var id: String { rawValue }
    
    /// Display name for the theme
    var displayName: String { rawValue }
    
    /// Convert to ColorScheme for SwiftUI
    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil  // Use system preference
        case .light, .solarizedLight, .gruvboxLight, .draculaLight, .gameBoy:
            return .light
        case .dark, .solarizedDark, .gruvboxDark, .nord, .tokyoNight, .draculaDark, .psychedelic, .zelda:
            return .dark
        }
    }
    
    /// Theme color palette
    var colors: ThemeColors {
        switch self {
        case .system:
            return ThemeColors.systemLight
        case .light:
            return ThemeColors.systemLight
        case .dark:
            return ThemeColors.systemDark
            
        case .solarizedLight:
            return ThemeColors(
                background: Color(red: 0.99, green: 0.96, blue: 0.89),
                secondaryBackground: Color(red: 0.93, green: 0.91, blue: 0.84),
                text: Color(red: 0.40, green: 0.48, blue: 0.51),
                secondaryText: Color(red: 0.58, green: 0.63, blue: 0.63),
                accent: Color(red: 0.11, green: 0.48, blue: 0.71),
                success: Color(red: 0.52, green: 0.60, blue: 0.00),
                warning: Color(red: 0.80, green: 0.29, blue: 0.09),
                error: Color(red: 0.86, green: 0.20, blue: 0.18)
            )
            
        case .solarizedDark:
            return ThemeColors(
                background: Color(red: 0.00, green: 0.17, blue: 0.21),
                secondaryBackground: Color(red: 0.03, green: 0.21, blue: 0.26),
                text: Color(red: 0.51, green: 0.58, blue: 0.59),
                secondaryText: Color(red: 0.36, green: 0.43, blue: 0.44),
                accent: Color(red: 0.15, green: 0.55, blue: 0.82),
                success: Color(red: 0.52, green: 0.60, blue: 0.00),
                warning: Color(red: 0.80, green: 0.29, blue: 0.09),
                error: Color(red: 0.86, green: 0.20, blue: 0.18)
            )
            
        case .gruvboxLight:
            return ThemeColors(
                background: Color(red: 0.98, green: 0.94, blue: 0.84),
                secondaryBackground: Color(red: 0.92, green: 0.86, blue: 0.70),
                text: Color(red: 0.16, green: 0.16, blue: 0.14),
                secondaryText: Color(red: 0.51, green: 0.46, blue: 0.31),
                accent: Color(red: 0.16, green: 0.51, blue: 0.42),
                success: Color(red: 0.60, green: 0.59, blue: 0.10),
                warning: Color(red: 0.84, green: 0.60, blue: 0.13),
                error: Color(red: 0.80, green: 0.14, blue: 0.11)
            )
            
        case .gruvboxDark:
            return ThemeColors(
                background: Color(red: 0.16, green: 0.16, blue: 0.14),
                secondaryBackground: Color(red: 0.20, green: 0.19, blue: 0.17),
                text: Color(red: 0.92, green: 0.86, blue: 0.70),
                secondaryText: Color(red: 0.66, green: 0.61, blue: 0.53),
                accent: Color(red: 0.55, green: 0.75, blue: 0.49),
                success: Color(red: 0.72, green: 0.73, blue: 0.15),
                warning: Color(red: 0.98, green: 0.74, blue: 0.20),
                error: Color(red: 0.98, green: 0.29, blue: 0.29)
            )
            
        case .nord:
            return ThemeColors(
                background: Color(red: 0.18, green: 0.20, blue: 0.25),
                secondaryBackground: Color(red: 0.23, green: 0.26, blue: 0.32),
                text: Color(red: 0.92, green: 0.93, blue: 0.94),
                secondaryText: Color(red: 0.76, green: 0.78, blue: 0.82),
                accent: Color(red: 0.53, green: 0.75, blue: 0.82),
                success: Color(red: 0.64, green: 0.75, blue: 0.54),
                warning: Color(red: 0.92, green: 0.80, blue: 0.55),
                error: Color(red: 0.75, green: 0.38, blue: 0.42)
            )
            
        case .tokyoNight:
            return ThemeColors(
                background: Color(red: 0.09, green: 0.10, blue: 0.15),
                secondaryBackground: Color(red: 0.12, green: 0.13, blue: 0.19),
                text: Color(red: 0.79, green: 0.82, blue: 0.91),
                secondaryText: Color(red: 0.55, green: 0.58, blue: 0.69),
                accent: Color(red: 0.45, green: 0.69, blue: 1.00),
                success: Color(red: 0.61, green: 0.89, blue: 0.66),
                warning: Color(red: 0.90, green: 0.70, blue: 0.40),
                error: Color(red: 0.97, green: 0.51, blue: 0.48)
            )
            
        case .draculaLight:
            return ThemeColors(
                background: Color(red: 0.97, green: 0.97, blue: 0.99),
                secondaryBackground: Color(red: 0.91, green: 0.91, blue: 0.95),
                text: Color(red: 0.18, green: 0.20, blue: 0.25),
                secondaryText: Color(red: 0.38, green: 0.40, blue: 0.45),
                accent: Color(red: 0.74, green: 0.58, blue: 0.98),
                success: Color(red: 0.31, green: 0.98, blue: 0.48),
                warning: Color(red: 1.00, green: 0.71, blue: 0.42),
                error: Color(red: 1.00, green: 0.33, blue: 0.33)
            )
            
        case .draculaDark:
            return ThemeColors(
                background: Color(red: 0.16, green: 0.17, blue: 0.21),
                secondaryBackground: Color(red: 0.23, green: 0.25, blue: 0.29),
                text: Color(red: 0.95, green: 0.95, blue: 0.98),
                secondaryText: Color(red: 0.78, green: 0.78, blue: 0.82),
                accent: Color(red: 0.74, green: 0.58, blue: 0.98),
                success: Color(red: 0.31, green: 0.98, blue: 0.48),
                warning: Color(red: 1.00, green: 0.71, blue: 0.42),
                error: Color(red: 1.00, green: 0.33, blue: 0.33)
            )
            
        case .psychedelic:
            return ThemeColors(
                background: Color(red: 0.10, green: 0.05, blue: 0.15),
                secondaryBackground: Color(red: 0.15, green: 0.10, blue: 0.25),
                text: Color(red: 1.00, green: 0.20, blue: 0.80),
                secondaryText: Color(red: 0.60, green: 1.00, blue: 0.80),
                accent: Color(red: 1.00, green: 0.00, blue: 1.00),
                success: Color(red: 0.00, green: 1.00, blue: 0.50),
                warning: Color(red: 1.00, green: 0.90, blue: 0.00),
                error: Color(red: 1.00, green: 0.20, blue: 0.60)
            )
            
        case .gameBoy:
            return ThemeColors(
                background: Color(red: 0.61, green: 0.73, blue: 0.06),
                secondaryBackground: Color(red: 0.54, green: 0.67, blue: 0.06),
                text: Color(red: 0.06, green: 0.22, blue: 0.06),
                secondaryText: Color(red: 0.20, green: 0.40, blue: 0.10),
                accent: Color(red: 0.10, green: 0.38, blue: 0.08),
                success: Color(red: 0.15, green: 0.50, blue: 0.10),
                warning: Color(red: 0.40, green: 0.50, blue: 0.08),
                error: Color(red: 0.25, green: 0.25, blue: 0.08)
            )
            
        case .zelda:
            return ThemeColors(
                background: Color(red: 0.12, green: 0.22, blue: 0.10),
                secondaryBackground: Color(red: 0.18, green: 0.30, blue: 0.15),
                text: Color(red: 0.90, green: 0.85, blue: 0.60),
                secondaryText: Color(red: 0.70, green: 0.75, blue: 0.50),
                accent: Color(red: 1.00, green: 0.84, blue: 0.00),
                success: Color(red: 0.40, green: 0.85, blue: 0.30),
                warning: Color(red: 0.90, green: 0.60, blue: 0.20),
                error: Color(red: 0.85, green: 0.20, blue: 0.20)
            )
        }
    }
    
    /// Preview icon for theme selector
    var previewIcon: String {
        switch self {
        case .system:
            return "laptopcomputer"
        case .light:
            return "sun.max.fill"
        case .dark:
            return "moon.fill"
        case .solarizedLight:
            return "sun.and.horizon.fill"
        case .solarizedDark:
            return "sun.and.horizon"
        case .gruvboxLight:
            return "tree.fill"
        case .gruvboxDark:
            return "tree"
        case .nord:
            return "snowflake"
        case .tokyoNight:
            return "moon.stars.fill"
        case .draculaLight:
            return "wand.and.stars"
        case .draculaDark:
            return "wand.and.stars.inverse"
        case .psychedelic:
            return "waveform.circle.fill"
        case .gameBoy:
            return "gamecontroller.fill"
        case .zelda:
            return "shield.lefthalf.filled"
        }
    }
    
    /// Description text
    var description: String {
        switch self {
        case .system:
            return "Follows system appearance"
        case .light:
            return "Clean light appearance"
        case .dark:
            return "Classic dark appearance"
        case .solarizedLight:
            return "Warm light theme, easy on the eyes"
        case .solarizedDark:
            return "Warm dark theme with precise contrast"
        case .gruvboxLight:
            return "Retro groove light theme"
        case .gruvboxDark:
            return "Warm dark theme with earthy tones"
        case .nord:
            return "Arctic, north-bluish color palette"
        case .tokyoNight:
            return "Dark theme inspired by Tokyo at night"
        case .draculaLight:
            return "Light variant of the Dracula theme"
        case .draculaDark:
            return "Dark theme with vibrant colors"
        case .psychedelic:
            return "Groovy neon vibes from the 60s"
        case .gameBoy:
            return "Classic green monochrome nostalgia"
        case .zelda:
            return "Adventure in Hyrule's forest"
        }
    }
    
    /// Theme category for grouping
    var category: String {
        switch self {
        case .system, .light, .dark:
            return "Standard"
        case .solarizedLight, .solarizedDark:
            return "Solarized"
        case .gruvboxLight, .gruvboxDark:
            return "Gruvbox"
        case .nord:
            return "Nord"
        case .tokyoNight:
            return "Tokyo Night"
        case .draculaLight, .draculaDark:
            return "Dracula"
        case .psychedelic, .gameBoy, .zelda:
            return "Fun Themes"
        }
    }
}
