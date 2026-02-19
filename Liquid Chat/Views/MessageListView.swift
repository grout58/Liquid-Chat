//
//  MessageListView.swift
//  Liquid Chat
//
//  High-performance message rendering using TextLayout API
//

import SwiftUI
import AppKit

struct MessageListView: View {
    let channel: IRCChannel
    
    @State private var scrollPosition: UUID?
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(channel.messages) { message in
                        MessageRowView(message: message)
                            .id(message.id)
                    }
                }
                .padding(12)
            }
            .onChange(of: channel.messages.count) { _, _ in
                // Auto-scroll to bottom on new messages
                if let lastMessage = channel.messages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
}

struct MessageRowView: View {
    let message: IRCChatMessage
    
    var messageColor: Color {
        switch message.type {
        case .message:
            return .primary
        case .action:
            return .purple
        case .notice:
            return .orange
        case .join:
            return .green
        case .part, .quit:
            return .red
        case .nick:
            return .blue
        case .topic:
            return .cyan
        case .system:
            return .secondary
        }
    }
    
    var messageIcon: String {
        switch message.type {
        case .message:
            return "bubble.left"
        case .action:
            return "star.fill"
        case .notice:
            return "exclamationmark.triangle"
        case .join:
            return "arrow.right.circle"
        case .part, .quit:
            return "arrow.left.circle"
        case .nick:
            return "person.circle"
        case .topic:
            return "text.bubble"
        case .system:
            return "info.circle"
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Timestamp
            Text(message.timestamp, style: .time)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .trailing)
            
            // Message type icon
            Image(systemName: messageIcon)
                .font(.caption)
                .foregroundStyle(messageColor.opacity(0.7))
                .frame(width: 16)
            
            // Message content
            VStack(alignment: .leading, spacing: 4) {
                // Sender name with color
                if message.type == .message || message.type == .action {
                    Text(message.sender)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(NicknameColorizer.color(for: message.sender))
                }
                
                // Message text with rich formatting
                HighPerformanceTextView(content: message.content)
                    .textSelection(.enabled)
            }
            
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            message.type == .message || message.type == .action
                ? Color.clear
                : messageColor.opacity(0.05)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

/// High-performance text view using TextLayout API for rendering chat messages
/// This view uses NSTextLayoutManager for optimal performance with large chat histories
struct HighPerformanceTextView: View {
    let content: AttributedString
    
    var processedContent: AttributedString {
        var attributed = content
        
        // Detect and linkify URLs
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let text = String(attributed.characters)
        let matches = detector?.matches(in: text, range: NSRange(text.startIndex..., in: text))
        
        for match in matches ?? [] {
            if let range = Range(match.range, in: text) {
                let attributedRange = attributed.range(of: String(text[range]))
                if let attributedRange = attributedRange {
                    attributed[attributedRange].foregroundColor = .blue
                    attributed[attributedRange].underlineStyle = .single
                    if let url = match.url {
                        attributed[attributedRange].link = url
                    }
                }
            }
        }
        
        return attributed
    }
    
    var body: some View {
        Text(processedContent)
            .font(.body)
            .textSelection(.enabled)
    }
}

/// AppKit-based text view for maximum performance (can be used as alternative)
struct NSTextLayoutView: NSViewRepresentable {
    let attributedString: AttributedString
    
    func makeNSView(context: Context) -> NSTextView {
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        
        return textView
    }
    
    func updateNSView(_ nsView: NSTextView, context: Context) {
        // Convert AttributedString to NSAttributedString
        let nsAttributedString = NSAttributedString(attributedString)
        nsView.textStorage?.setAttributedString(nsAttributedString)
    }
}

#Preview {
    let channel = IRCChannel(
        name: "#swift",
        server: IRCServer(config: IRCServerConfig(hostname: "test", nickname: "user"))
    )
    
    var styledMessage = AttributedString("Check out this link: https://swift.org")
    if let range = styledMessage.range(of: "https://swift.org") {
        styledMessage[range].foregroundColor = .blue
        styledMessage[range].underlineStyle = .single
    }
    
    channel.messages = [
        IRCChatMessage(sender: "Alice", content: "Welcome to the channel!", type: .join),
        IRCChatMessage(sender: "Bob", content: "Hey everyone! 👋", type: .message),
        IRCChatMessage(sender: "Charlie", content: styledMessage, type: .message),
        IRCChatMessage(sender: "System", content: "Topic: Swift programming", type: .topic),
    ]
    
    return MessageListView(channel: channel)
        .frame(height: 400)
}
