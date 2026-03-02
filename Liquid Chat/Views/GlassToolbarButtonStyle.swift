//
//  GlassToolbarButtonStyle.swift
//  Liquid Chat
//
//  Enhanced Liquid Glass button style for toolbar buttons
//

import SwiftUI

/// Beautiful Liquid Glass button style for toolbar with enhanced visual effects
struct GlassToolbarButtonStyle: ButtonStyle {
    let isActive: Bool
    let isDisabled: Bool
    
    init(isActive: Bool = false, isDisabled: Bool = false) {
        self.isActive = isActive
        self.isDisabled = isDisabled
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(foregroundStyle())
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(backgroundFill(configuration: configuration))
                    .shadow(color: shadowColor(configuration: configuration), radius: 4, x: 0, y: 2)
            }
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
            .glassEffect(
                isActive ? .regular.tint(.blue.opacity(0.3)) : .regular,
                in: .rect(cornerRadius: 8)
            )
    }
    
    private func foregroundStyle() -> some ShapeStyle {
        if isDisabled {
            return AnyShapeStyle(.tertiary)
        } else if isActive {
            return AnyShapeStyle(.white)
        } else {
            return AnyShapeStyle(.primary)
        }
    }
    
    private func backgroundFill(configuration: Configuration) -> some ShapeStyle {
        if isDisabled {
            return AnyShapeStyle(.quaternary.opacity(0.3))
        } else if isActive {
            return AnyShapeStyle(.blue.gradient)
        } else if configuration.isPressed {
            return AnyShapeStyle(.tertiary)
        } else {
            return AnyShapeStyle(.quaternary.opacity(0.6))
        }
    }
    
    private func shadowColor(configuration: Configuration) -> Color {
        if isActive {
            return .blue.opacity(0.3)
        } else if configuration.isPressed {
            return .black.opacity(0.1)
        } else {
            return .clear
        }
    }
}

/// Compact icon-only glass button for toolbar
struct GlassIconButtonStyle: ButtonStyle {
    let isActive: Bool
    let isDisabled: Bool
    
    init(isActive: Bool = false, isDisabled: Bool = false) {
        self.isActive = isActive
        self.isDisabled = isDisabled
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(iconForeground())
            .frame(width: 32, height: 32)
            .background {
                Circle()
                    .fill(backgroundFill(configuration: configuration))
                    .shadow(color: shadowColor(configuration: configuration), radius: 3, x: 0, y: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(duration: 0.15, bounce: 0.5), value: configuration.isPressed)
            .glassEffect(
                isActive ? .regular.tint(.blue.opacity(0.25)).interactive() : .regular.interactive(),
                in: .circle
            )
    }
    
    private func iconForeground() -> some ShapeStyle {
        if isDisabled {
            return AnyShapeStyle(.tertiary)
        } else if isActive {
            return AnyShapeStyle(.white)
        } else {
            return AnyShapeStyle(.primary)
        }
    }
    
    private func backgroundFill(configuration: Configuration) -> some ShapeStyle {
        if isDisabled {
            return AnyShapeStyle(.quaternary.opacity(0.3))
        } else if isActive {
            return AnyShapeStyle(.blue.gradient)
        } else if configuration.isPressed {
            return AnyShapeStyle(.tertiary.opacity(0.8))
        } else {
            return AnyShapeStyle(.quaternary.opacity(0.5))
        }
    }
    
    private func shadowColor(configuration: Configuration) -> Color {
        if isActive {
            return .blue.opacity(0.4)
        } else if configuration.isPressed {
            return .black.opacity(0.15)
        } else {
            return .clear
        }
    }
}

// MARK: - Button Style Extensions

extension ButtonStyle where Self == GlassToolbarButtonStyle {
    /// Enhanced glass style for toolbar buttons with optional active state
    static func glassToolbar(isActive: Bool = false, isDisabled: Bool = false) -> GlassToolbarButtonStyle {
        GlassToolbarButtonStyle(isActive: isActive, isDisabled: isDisabled)
    }
}

extension ButtonStyle where Self == GlassIconButtonStyle {
    /// Compact glass style for icon-only toolbar buttons
    static func glassIcon(isActive: Bool = false, isDisabled: Bool = false) -> GlassIconButtonStyle {
        GlassIconButtonStyle(isActive: isActive, isDisabled: isDisabled)
    }
}

#Preview("Glass Toolbar Buttons") {
    VStack(spacing: 20) {
        // Regular toolbar buttons
        HStack(spacing: 12) {
            Button {
            } label: {
                Label("Search", systemImage: "magnifyingglass")
            }
            .buttonStyle(.glassToolbar())
            
            Button {
            } label: {
                Label("Summarize", systemImage: "sparkles")
            }
            .buttonStyle(.glassToolbar(isActive: true))
            
            Button {
            } label: {
                Label("Disabled", systemImage: "xmark")
            }
            .buttonStyle(.glassToolbar(isDisabled: true))
        }
        
        Divider()
        
        // Icon-only buttons
        HStack(spacing: 12) {
            Button {
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .buttonStyle(.glassIcon())
            
            Button {
            } label: {
                Image(systemName: "sparkles")
            }
            .buttonStyle(.glassIcon(isActive: true))
            
            Button {
            } label: {
                Image(systemName: "person.2")
            }
            .buttonStyle(.glassIcon())
        }
        
        Divider()
        
        // Loading state
        HStack(spacing: 6) {
            ProgressView()
                .controlSize(.small)
            Text("Processing...")
                .font(.caption)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(.blue.gradient)
        }
        .foregroundStyle(.white)
        .glassEffect(.regular.tint(.blue.opacity(0.3)), in: .rect(cornerRadius: 8))
    }
    .padding(40)
    .frame(width: 500, height: 400)
    .background(.ultraThinMaterial)
}
