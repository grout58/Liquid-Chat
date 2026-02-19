//
//  AppTheme.swift
//  Liquid Chat
//
//  Simple theme management using macOS native appearance
//

import SwiftUI

/// Available appearance modes - uses standard macOS system
enum AppTheme: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    
    var id: String { rawValue }
    
    /// Display name for the theme
    var displayName: String { rawValue }
    
    /// Convert to ColorScheme for SwiftUI
    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil  // Use system preference
        case .light:
            return .light
        case .dark:
            return .dark
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
        }
    }
    
    /// Description text
    var description: String {
        switch self {
        case .system:
            return "Follows system appearance"
        case .light:
            return "Always use light mode"
        case .dark:
            return "Always use dark mode"
        }
    }
}
