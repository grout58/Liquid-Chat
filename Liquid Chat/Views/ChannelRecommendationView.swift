//
//  ChannelRecommendationView.swift
//  Liquid Chat
//
//  AI-powered channel recommendations with Liquid Glass design
//

import SwiftUI

/// Displays AI-generated channel recommendations with beautiful Liquid Glass UI
struct ChannelRecommendationView: View {
    let recommendations: [ChannelRecommendation]
    let onJoin: (String) -> Void
    let onDismiss: () -> Void
    
    @State private var selectedRecommendation: ChannelRecommendation?
    @Namespace private var glassNamespace
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Header with AI sparkles
                    headerSection
                    
                    // Recommendation cards
                    ForEach(recommendations) { recommendation in
                        recommendationCard(for: recommendation)
                    }
                    
                    if recommendations.isEmpty {
                        emptyState
                    }
                }
                .padding()
            }
            .navigationTitle("Recommended Channels")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        onDismiss()
                    }
                    .buttonStyle(.glass)
                }
            }
        }
        .frame(width: 600, height: 500)
    }
    
    /// Header section with AI indicator
    private var headerSection: some View {
        VStack(spacing: 8) {
            // Sparkles icon with gradient
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple, .pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("AI-Powered Recommendations")
                .font(.headline)
                .foregroundStyle(.primary)
            
            Text("Based on your recent conversation")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    /// Individual recommendation card with Liquid Glass
    private func recommendationCard(for recommendation: ChannelRecommendation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Channel name and relevance score
            HStack {
                Text(recommendation.channelName)
                    .font(.title3.bold())
                    .foregroundStyle(.primary)
                
                Spacer()
                
                // Relevance badge
                relevanceBadge(score: recommendation.relevanceScore)
            }
            
            // Reason
            Text(recommendation.reason)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            // Similar topics tags
            if !recommendation.similarTopics.isEmpty {
                topicTags(recommendation.similarTopics)
            }
            
            // Join button
            HStack {
                Spacer()
                
                Button {
                    onJoin(recommendation.channelName)
                    onDismiss()
                } label: {
                    Label("Join Channel", systemImage: "arrow.right.circle.fill")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        .transition(.asymmetric(
            insertion: .scale.combined(with: .opacity),
            removal: .opacity
        ))
    }
    
    /// Relevance score badge
    private func relevanceBadge(score: Double) -> some View {
        let percentage = Int(score * 100)
        let color: Color = {
            if score > 0.7 { return .green }
            if score > 0.4 { return .orange }
            return .gray
        }()
        
        return HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .font(.caption2)
            Text("\(percentage)%")
                .font(.caption.bold())
                .monospacedDigit()
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
    }
    
    /// Topic tags display
    private func topicTags(_ topics: [String]) -> some View {
        HStack(spacing: 8) {
            ForEach(topics.prefix(4), id: \.self) { topic in
                Text(topic)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.thinMaterial)
                    .clipShape(Capsule())
            }
        }
    }
    
    /// Empty state when no recommendations
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 60))
                .foregroundStyle(.tertiary)
            
            Text("No Recommendations Yet")
                .font(.title2.bold())
                .foregroundStyle(.primary)
            
            Text("Continue chatting to get personalized channel suggestions based on your conversation topics.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

/// Compact recommendation widget for sidebar
struct ChannelRecommendationWidget: View {
    let recommendations: [ChannelRecommendation]
    let onJoin: (String) -> Void
    let onShowAll: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Label("Recommended", systemImage: "sparkles")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if recommendations.count > 3 {
                    Button("See All") {
                        onShowAll()
                    }
                    .font(.caption)
                    .buttonStyle(.plain)
                }
            }
            
            // Top 3 recommendations
            VStack(spacing: 8) {
                ForEach(recommendations.prefix(3)) { recommendation in
                    compactRecommendationRow(recommendation)
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func compactRecommendationRow(_ recommendation: ChannelRecommendation) -> some View {
        Button {
            onJoin(recommendation.channelName)
        } label: {
            HStack(spacing: 8) {
                // Relevance indicator
                Circle()
                    .fill(relevanceColor(for: recommendation.relevanceScore))
                    .frame(width: 8, height: 8)
                
                // Channel name
                Text(recommendation.channelName)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                Spacer()
                
                // Join arrow
                Image(systemName: "arrow.right.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private func relevanceColor(for score: Double) -> Color {
        if score > 0.7 { return .green }
        if score > 0.4 { return .orange }
        return .gray
    }
}

#Preview("Full View") {
    ChannelRecommendationView(
        recommendations: [
            ChannelRecommendation(
                channelName: "#swift",
                reason: "Active discussion about Swift programming and iOS development",
                relevanceScore: 0.92,
                similarTopics: ["swift", "ios", "swiftui"]
            ),
            ChannelRecommendation(
                channelName: "#python",
                reason: "Python developers sharing code snippets and best practices",
                relevanceScore: 0.78,
                similarTopics: ["python", "django", "async"]
            ),
            ChannelRecommendation(
                channelName: "#linux",
                reason: "Linux system administration and DevOps discussions",
                relevanceScore: 0.65,
                similarTopics: ["linux", "docker", "kubernetes"]
            )
        ],
        onJoin: { channel in
            print("Joining \(channel)")
        },
        onDismiss: {
            print("Dismissed")
        }
    )
}

#Preview("Widget") {
    ChannelRecommendationWidget(
        recommendations: [
            ChannelRecommendation(
                channelName: "#swift",
                reason: "Swift programming",
                relevanceScore: 0.92,
                similarTopics: ["swift", "ios"]
            ),
            ChannelRecommendation(
                channelName: "#python",
                reason: "Python development",
                relevanceScore: 0.78,
                similarTopics: ["python", "django"]
            )
        ],
        onJoin: { _ in },
        onShowAll: { }
    )
    .padding()
    .frame(width: 250)
}
