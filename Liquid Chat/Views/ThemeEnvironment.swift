//
//  ThemeEnvironment.swift
//  Liquid Chat
//
//  View modifiers for applying themes using custom colors
//

import SwiftUI

/// Environment key for theme colors
struct ThemeColorsKey: EnvironmentKey {
    static let defaultValue = AppTheme.system.colors
}

extension EnvironmentValues {
    var themeColors: ThemeColors {
        get { self[ThemeColorsKey.self] }
        set { self[ThemeColorsKey.self] = newValue }
    }
}

/// View modifier that applies theme (appearance) using custom colors
struct ThemedViewModifier: ViewModifier {
    @Bindable var settings: AppSettings
    
    func body(content: Content) -> some View {
        content
            .preferredColorScheme(settings.theme.colorScheme)
            .tint(settings.theme.colors.accent)
            .environment(\.themeColors, settings.theme.colors)
            .foregroundStyle(settings.theme.colors.text)
    }
}

extension View {
    /// Apply theme styling to this view
    func themedStyle(_ settings: AppSettings = .shared) -> some View {
        modifier(ThemedViewModifier(settings: settings))
    }
}

/// Themed background using theme colors
extension View {
    func themedBackground(_ settings: AppSettings = .shared) -> some View {
        self.background(settings.theme.colors.background)
    }
}

/// Themed card/panel using theme colors
extension View {
    func themedCard(cornerRadius: CGFloat = 12, settings: AppSettings = .shared) -> some View {
        self
            .padding()
            .background(settings.theme.colors.secondaryBackground, in: RoundedRectangle(cornerRadius: cornerRadius))
    }
}

/// Themed secondary text color
extension View {
    func themedSecondaryText(_ settings: AppSettings = .shared) -> some View {
        self.foregroundStyle(settings.theme.colors.secondaryText)
    }
}

/// Dynamic font size based on settings
extension View {
    func dynamicFontSize(_ baseSize: CGFloat = 14, settings: AppSettings = .shared) -> some View {
        self.font(.system(size: baseSize * settings.fontSizeMultiplier))
    }
}

// Note: macOS 26 includes native .glass and .glassProminent button styles in SwiftUI
// No custom implementation needed - the native styles are used throughout the app

