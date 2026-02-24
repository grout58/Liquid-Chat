//
//  SummaryView.swift
//  Liquid Chat
//
//  AI-powered chat summary display
//

import SwiftUI

struct SummaryView: View {
    let summary: ChatSummary
    @Environment(\.dismiss) private var dismiss
    @Environment(\.themeColors) private var themeColors
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header with participant info
                    HStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.title)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("AI Summary")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            HStack(spacing: 12) {
                                Label("\(summary.participantCount) participants", systemImage: "person.2.fill")
                                    .font(.caption)
                                    .foregroundStyle(themeColors.secondaryText)
                                
                                Label("\(summary.messageCount) messages", systemImage: "bubble.left.and.bubble.right.fill")
                                    .font(.caption)
                                    .foregroundStyle(themeColors.secondaryText)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(themeColors.secondaryBackground.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    // Key Points
                    if !summary.keyPoints.isEmpty {
                        SummarySectionView(
                            title: "Key Points",
                            icon: "star.fill",
                            iconColor: .yellow,
                            items: summary.keyPoints
                        )
                    }
                    
                    // Topics Discussed
                    if !summary.topics.isEmpty {
                        SummarySectionView(
                            title: "Topics Discussed",
                            icon: "bubble.left.and.bubble.right.fill",
                            iconColor: .blue,
                            items: summary.topics
                        )
                    }
                    
                    // Sentiment
                    SentimentView(sentiment: summary.sentiment)
                    
                    // Action items (if any mentions of TODO, etc.)
                    if summary.keyPoints.contains(where: { $0.lowercased().contains("todo") || $0.lowercased().contains("action") }) {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Action Items", systemImage: "checkmark.circle.fill")
                                .font(.headline)
                                .foregroundStyle(.green)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(summary.keyPoints.filter { $0.lowercased().contains("todo") || $0.lowercased().contains("action") }, id: \.self) { item in
                                    HStack(alignment: .top, spacing: 8) {
                                        Image(systemName: "circle")
                                            .font(.caption2)
                                            .foregroundStyle(themeColors.secondaryText)
                                        
                                        Text(item)
                                            .font(.body)
                                            .foregroundStyle(themeColors.text)
                                    }
                                }
                            }
                            .padding()
                            .background(Color.green.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Chat Summary")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        copyToClipboard()
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }
    
    private func copyToClipboard() {
        var text = "# Chat Summary\n\n"
        text += "**Participants:** \(summary.participantCount)\n"
        text += "**Messages:** \(summary.messageCount)\n"
        text += "**Sentiment:** \(summary.sentiment)\n\n"
        
        if !summary.keyPoints.isEmpty {
            text += "## Key Points\n"
            for point in summary.keyPoints {
                text += "- \(point)\n"
            }
            text += "\n"
        }
        
        if !summary.topics.isEmpty {
            text += "## Topics Discussed\n"
            for topic in summary.topics {
                text += "- \(topic)\n"
            }
        }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

struct SummarySectionView: View {
    let title: String
    let icon: String
    let iconColor: Color
    let items: [String]
    
    @Environment(\.themeColors) private var themeColors
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(iconColor)
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(index + 1).")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundStyle(iconColor.opacity(0.8))
                            .frame(width: 24, alignment: .trailing)
                        
                        Text(item)
                            .font(.body)
                            .foregroundStyle(themeColors.text)
                    }
                }
            }
            .padding()
            .background(iconColor.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct SentimentView: View {
    let sentiment: String
    @Environment(\.themeColors) private var themeColors
    
    private var sentimentInfo: (color: Color, icon: String, description: String) {
        let lowercased = sentiment.lowercased()
        
        if lowercased.contains("positive") || lowercased.contains("friendly") {
            return (.green, "face.smiling.fill", "Positive and friendly")
        } else if lowercased.contains("negative") || lowercased.contains("tense") {
            return (.red, "face.dashed.fill", "Tense or negative")
        } else if lowercased.contains("neutral") {
            return (.blue, "face.dashed", "Neutral tone")
        } else if lowercased.contains("mixed") {
            return (.orange, "face.smiling", "Mixed sentiment")
        } else {
            return (.blue, "face.dashed", sentiment)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Sentiment", systemImage: sentimentInfo.icon)
                .font(.headline)
                .foregroundStyle(sentimentInfo.color)
            
            HStack(spacing: 12) {
                Image(systemName: sentimentInfo.icon)
                    .font(.title)
                    .foregroundStyle(sentimentInfo.color)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(sentimentInfo.description)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(themeColors.text)
                    
                    Text(sentiment)
                        .font(.caption)
                        .foregroundStyle(themeColors.secondaryText)
                }
                
                Spacer()
            }
            .padding()
            .background(sentimentInfo.color.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

#Preview {
    SummaryView(summary: ChatSummary(
        keyPoints: [
            "Discussion about SwiftUI 6 new features and performance improvements",
            "Several users sharing code snippets and best practices",
            "Help provided for a macOS app deployment issue",
            "Planning for an upcoming Swift meetup next week"
        ],
        participantCount: 8,
        topics: [
            "SwiftUI 6 features",
            "Xcode 16 improvements",
            "macOS app deployment",
            "Community meetup planning"
        ],
        sentiment: "Positive and collaborative",
        messageCount: 127
    ))
}
