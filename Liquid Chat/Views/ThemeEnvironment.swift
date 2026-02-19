//
//  ThemeEnvironment.swift
//  Liquid Chat
//
//  View modifiers for applying themes using native macOS APIs
//

import SwiftUI

/// View modifier that applies theme (appearance) using native SwiftUI
struct ThemedViewModifier: ViewModifier {
    @Bindable var settings: AppSettings
    
    func body(content: Content) -> some View {
        content
            .preferredColorScheme(settings.theme.colorScheme)
    }
}

extension View {
    /// Apply theme styling to this view using native macOS appearance
    func themedStyle(_ settings: AppSettings = .shared) -> some View {
        modifier(ThemedViewModifier(settings: settings))
    }
}

/// Themed background using native system colors
extension View {
    func themedBackground(_ settings: AppSettings = .shared) -> some View {
        self.background(Color(nsColor: .windowBackgroundColor))
    }
}

/// Themed card/panel using native materials
extension View {
    func themedCard(cornerRadius: CGFloat = 12, settings: AppSettings = .shared) -> some View {
        self
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
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

