//
//  SmartReplyView.swift
//  Liquid Chat
//
//  Smart reply suggestions with Liquid Glass morphing effects
//

import SwiftUI

/// Displays AI-generated smart reply suggestions with beautiful Liquid Glass animations
struct SmartReplyView: View {
    let suggestions: [SmartReply]
    let onSelect: (SmartReply) -> Void
    let onDismiss: () -> Void
    
    @Namespace private var glassNamespace
    @State private var hoveredReply: UUID?
    
    var body: some View {
        HStack(spacing: 8) {
            // Sparkles icon to indicate AI-powered
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.tint)
                .glassEffectID("icon", in: glassNamespace)
            
            // Smart reply chips with interactive Liquid Glass
            ForEach(suggestions) { suggestion in
                SmartReplyChip(
                    suggestion: suggestion,
                    isHovered: hoveredReply == suggestion.id,
                    onSelect: {
                        onSelect(suggestion)
                    }
                )
                .glassEffectID(suggestion.id.uuidString, in: glassNamespace)
                .onHover { hovering in
                    withAnimation(.spring(duration: 0.2)) {
                        hoveredReply = hovering ? suggestion.id : nil
                    }
                }
            }
            
            Spacer()
            
            // Dismiss button
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .glassEffectID("dismiss", in: glassNamespace)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
        .glassEffectTransition(.matchedGeometry)
    }
}

/// Individual smart reply chip with Liquid Glass interactive effects
struct SmartReplyChip: View {
    let suggestion: SmartReply
    let isHovered: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack(spacing: 4) {
                Text(suggestion.emoji)
                    .font(.system(size: 14))
                
                Text(suggestion.text)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.tint.opacity(isHovered ? 0.2 : 0.1))
            }
            .scaleEffect(isHovered ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(.spring(duration: 0.2), value: isHovered)
    }
}

/// Loading state for smart reply generation
struct SmartReplyLoadingView: View {
    @Namespace private var glassNamespace
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.tint)
            
            ProgressView()
                .controlSize(.small)
            
            Text("Generating smart replies...")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
        .glassEffectTransition(.matchedGeometry)
    }
}

#Preview("Smart Reply Suggestions") {
    VStack(spacing: 16) {
        SmartReplyView(
            suggestions: [
                SmartReply(text: "Sounds good!", emoji: "👍", category: .agreement, confidence: 0.9),
                SmartReply(text: "Can you share the logs?", emoji: "⚙️", category: .technical, confidence: 0.85),
                SmartReply(text: "Thanks!", emoji: "🙏", category: .thanks, confidence: 0.8)
            ],
            onSelect: { reply in
                print("Selected: \(reply.text)")
            },
            onDismiss: {
                print("Dismissed")
            }
        )
        .padding()
        
        SmartReplyLoadingView()
            .padding()
    }
    .frame(width: 600)
}
