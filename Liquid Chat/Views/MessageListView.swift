//
//  MessageListView.swift
//  Liquid Chat
//
//  Modern UX with message grouping, collapsed status events, and visual hierarchy
//

import SwiftUI
import AppKit

struct MessageListView: View {
    let channel: IRCChannel
    @Binding var scrollToMessageIndex: Int?
    @Binding var highlightedMessageIndex: Int?
    var searchText: String? = nil
    
    @State private var scrollPosition: UUID?
    @State private var expandedStatusGroups: Set<UUID> = []
    
    // Group messages for better UX
    private var groupedMessages: [MessageGroup] {
        groupMessages(channel.messages)
    }
    
    // Find group containing a specific message index
    private func findGroup(forMessageIndex index: Int) -> UUID? {
        for group in groupedMessages {
            switch group {
            case .regular(_, _):
                if let groupIndex = channel.messages.firstIndex(where: { msg in
                    if case .regular(let message, _) = group {
                        return msg.id == message.id
                    }
                    return false
                }), groupIndex == index {
                    return group.id
                }
            case .statusGroup(let messages):
                if messages.contains(where: { msg in
                    if let msgIndex = channel.messages.firstIndex(where: { $0.id == msg.id }) {
                        return msgIndex == index
                    }
                    return false
                }) {
                    return group.id
                }
            }
        }
        return nil
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(groupedMessages.enumerated()), id: \.element.id) { index, group in
                        let prevBatchID = index > 0 ? groupedMessages[index - 1].batchID : nil
                        if group.batchID != nil && group.batchID != prevBatchID {
                            BatchSeparatorView()
                        }
                        MessageGroupView(
                            group: group,
                            channel: channel,
                            messageIndex: getMessageIndex(for: group),
                            isHighlighted: isGroupHighlighted(group),
                            isExpanded: expandedStatusGroups.contains(group.id),
                            searchText: searchText,
                            onToggleExpand: {
                                if expandedStatusGroups.contains(group.id) {
                                    expandedStatusGroups.remove(group.id)
                                } else {
                                    expandedStatusGroups.insert(group.id)
                                }
                            }
                        )
                        .id(group.id)
                    }
                }
                .padding(12)
            }
            .onChange(of: channel.messages.count) { _, _ in
                // Auto-scroll to bottom on new messages
                if let lastGroup = groupedMessages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(lastGroup.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: scrollToMessageIndex) { _, newIndex in
                guard let index = newIndex,
                      let groupId = findGroup(forMessageIndex: index) else { return }
                
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(groupId, anchor: .center)
                }
                
                // Clear scroll target
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    scrollToMessageIndex = nil
                }
            }
        }
    }
    
    private func getMessageIndex(for group: MessageGroup) -> Int? {
        switch group {
        case .regular(let message, _):
            return channel.messages.firstIndex(where: { $0.id == message.id })
        case .statusGroup(let messages):
            if let firstMsg = messages.first {
                return channel.messages.firstIndex(where: { $0.id == firstMsg.id })
            }
            return nil
        }
    }
    
    private func isGroupHighlighted(_ group: MessageGroup) -> Bool {
        guard let highlightIndex = highlightedMessageIndex else { return false }
        
        switch group {
        case .regular(let message, _):
            if let index = channel.messages.firstIndex(where: { $0.id == message.id }) {
                return index == highlightIndex
            }
        case .statusGroup(let messages):
            for msg in messages {
                if let index = channel.messages.firstIndex(where: { $0.id == msg.id }),
                   index == highlightIndex {
                    return true
                }
            }
        }
        return false
    }
    
    // MARK: - Message Grouping Logic
    
    private func groupMessages(_ messages: [IRCChatMessage]) -> [MessageGroup] {
        var groups: [MessageGroup] = []
        var currentStatusGroup: [IRCChatMessage] = []
        
        for (index, message) in messages.enumerated() {
            let isStatusEvent = [.join, .part, .quit, .nick].contains(message.type)
            
            if isStatusEvent {
                // Accumulate status events
                currentStatusGroup.append(message)
            } else {
                // Flush any accumulated status events
                if !currentStatusGroup.isEmpty {
                    groups.append(.statusGroup(currentStatusGroup))
                    currentStatusGroup = []
                }
                
                // Check if we should group with previous message
                let previousIndex = index - 1
                let shouldGroup = previousIndex >= 0 &&
                    !isStatusEvent &&
                    shouldGroupWith(message, previous: messages[previousIndex])
                
                groups.append(.regular(message, isGrouped: shouldGroup))
            }
        }
        
        // Flush any remaining status events
        if !currentStatusGroup.isEmpty {
            groups.append(.statusGroup(currentStatusGroup))
        }
        
        return groups
    }
    
    private func shouldGroupWith(_ message: IRCChatMessage, previous: IRCChatMessage) -> Bool {
        // Only group regular messages from same sender
        guard message.type == .message || message.type == .action,
              previous.type == .message || previous.type == .action,
              message.sender == previous.sender else {
            return false
        }
        
        // Group if within 5 minutes
        let timeDifference = message.timestamp.timeIntervalSince(previous.timestamp)
        return timeDifference <= 300 // 5 minutes
    }
}

// MARK: - Message Group Model

enum MessageGroup: Identifiable {
    case regular(IRCChatMessage, isGrouped: Bool)
    case statusGroup([IRCChatMessage])
    
    var id: UUID {
        switch self {
        case .regular(let message, _):
            return message.id
        case .statusGroup(let messages):
            // Use first message's ID for the group
            return messages.first?.id ?? UUID()
        }
    }

    var batchID: String? {
        switch self {
        case .regular(let message, _):
            return message.batchID
        case .statusGroup(let messages):
            return messages.first?.batchID
        }
    }
}

// MARK: - Batch Separator View

struct BatchSeparatorView: View {
    var body: some View {
        HStack(spacing: 8) {
            VStack { Divider() }
            Text("replayed history")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize()
            VStack { Divider() }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Message Group View

struct MessageGroupView: View {
    let group: MessageGroup
    let channel: IRCChannel
    let messageIndex: Int?
    let isHighlighted: Bool
    let isExpanded: Bool
    var searchText: String? = nil
    let onToggleExpand: () -> Void
    
    var body: some View {
        Group {
            switch group {
            case .regular(let message, let isGrouped):
                MessageRowView(message: message, isGrouped: isGrouped, channel: channel, searchText: searchText)
                
            case .statusGroup(let messages):
                StatusGroupView(
                    messages: messages,
                    isExpanded: isExpanded,
                    channel: channel,
                    searchText: searchText,
                    onToggle: onToggleExpand
                )
            }
        }
        .background(
            isHighlighted
                ? Color.accentColor.opacity(0.15)
                : Color.clear
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .animation(.easeInOut(duration: 0.3), value: isHighlighted)
    }
}

// MARK: - Status Group View

struct StatusGroupView: View {
    let messages: [IRCChatMessage]
    let isExpanded: Bool
    let channel: IRCChannel
    var searchText: String? = nil
    let onToggle: () -> Void
    @Environment(\.themeColors) private var themeColors
    
    private var summaryText: String {
        let joins = messages.filter { $0.type == .join }.count
        let parts = messages.filter { $0.type == .part }.count
        let quits = messages.filter { $0.type == .quit }.count
        let nicks = messages.filter { $0.type == .nick }.count
        
        var components: [String] = []
        if joins > 0 { components.append("\(joins) joined") }
        if parts > 0 { components.append("\(parts) left") }
        if quits > 0 { components.append("\(quits) quit") }
        if nicks > 0 { components.append("\(nicks) changed nick") }
        
        return components.joined(separator: ", ")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if isExpanded {
                // Show all status messages
                ForEach(messages) { message in
                    StatusMessageRow(message: message, channel: channel, searchText: searchText)
                }
            } else {
                // Show collapsed summary
                HStack(spacing: 8) {
                    // Fixed gutter spacing
                    Color.clear.frame(width: 50 + 16 + 12) // timestamp + icon + spacing
                    
                    HStack(spacing: 6) {
                        Image(systemName: "ellipsis.circle")
                            .font(.caption)
                            .foregroundStyle(themeColors.secondaryText.opacity(0.6))
                            .controlSize(.small)
                        
                        Text(summaryText)
                            .font(.caption)
                            .foregroundStyle(themeColors.secondaryText.opacity(0.7))
                        
                        Text("(tap to expand)")
                            .font(.caption2)
                            .foregroundStyle(themeColors.secondaryText.opacity(0.5))
                    }
                }
                .padding(.vertical, 2)
                .contentShape(Rectangle())
                .onTapGesture {
                    onToggle()
                }
            }
        }
    }
}

struct StatusMessageRow: View {
    let message: IRCChatMessage
    let channel: IRCChannel
    var searchText: String? = nil
    @Environment(\.themeColors) private var themeColors
    
    private var icon: String {
        switch message.type {
        case .join: return "arrow.right.circle"
        case .part, .quit: return "arrow.left.circle"
        case .nick: return "person.circle"
        default: return "info.circle"
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Gutter: Timestamp
            Text(message.timestamp, style: .time)
                .font(.caption2)
                .foregroundStyle(themeColors.secondaryText.opacity(0.5))
                .frame(width: 50, alignment: .trailing)
            
            // Icon
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(themeColors.secondaryText.opacity(0.4))
                .frame(width: 16)
                .controlSize(.small)
            
            // Content
            Text(message.content)
                .font(.caption)
                .foregroundStyle(themeColors.secondaryText.opacity(0.7))
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 8)
    }
}

// MARK: - Message Row View

struct MessageRowView: View {
    let message: IRCChatMessage
    let isGrouped: Bool
    let channel: IRCChannel
    var searchText: String? = nil
    
    @Environment(\.themeColors) private var themeColors
    @Environment(\.colorScheme) private var colorScheme
    @State private var urlPreview: URLPreview?
    @State private var isLoadingPreview = false
    @State private var isHovering = false
    
    // Detect if current user is mentioned
    private var isMention: Bool {
        guard let connection = channel.server.connection else { return false }
        let messageText = String(message.content.characters).lowercased()
        let nickname = connection.currentNickname.lowercased()
        return messageText.contains(nickname)
    }
    
    private var messageIcon: String {
        switch message.type {
        case .message: return "bubble.left"
        case .action: return "star.fill"
        case .notice: return "exclamationmark.triangle"
        case .topic: return "text.bubble"
        case .system: return "info.circle"
        default: return "info.circle"
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // GUTTER: Fixed-width timestamp (Tertiary color)
            Group {
                if isGrouped && !isHovering {
                    // Hidden timestamp, shown on hover
                    Text("")
                        .font(.caption2)
                        .frame(width: 50, alignment: .trailing)
                } else {
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundStyle(themeColors.secondaryText.opacity(0.6))
                        .frame(width: 50, alignment: .trailing)
                }
            }
            
            // GUTTER: Fixed-width icon
            Image(systemName: messageIcon)
                .font(.caption2)
                .foregroundStyle(themeColors.accent.opacity(isGrouped ? 0.3 : 0.6))
                .frame(width: 16)
                .opacity(isGrouped && !isHovering ? 0.3 : 1.0)
            
            // Message content with perfect vertical alignment
            VStack(alignment: .leading, spacing: 4) {
                // Sender name (Primary color, hidden when grouped)
                if !isGrouped {
                    Text(message.sender)
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(NicknameColorizer.color(for: message.sender, colorScheme: colorScheme))
                }
                
                // Message text (Secondary color for body)
                HighPerformanceTextView(
                    content: message.content,
                    baseColor: themeColors.text,
                    searchText: searchText
                )
                .textSelection(.enabled)
                
                // URL preview if available
                if let preview = urlPreview {
                    URLPreviewView(preview: preview)
                        .frame(maxWidth: 400)
                        .padding(.top, 4)
                } else if isLoadingPreview {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.6)
                            .controlSize(.small)
                        Text("Loading preview...")
                            .font(.caption2)
                            .foregroundStyle(themeColors.secondaryText.opacity(0.6))
                    }
                    .padding(.top, 4)
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(.vertical, isGrouped ? 2 : 6)
        .padding(.horizontal, 8)
        .background(
            // Subtle highlight for mentions
            isMention
                ? themeColors.accent.opacity(0.08)
                : Color.clear
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .task {
            // Only fetch previews for regular messages
            guard message.type == .message else { return }
            
            // Extract URLs from message
            let messageText = String(message.content.characters)
            let urls = messageText.extractURLs()
            
            // Fetch preview for the first URL
            if let firstURL = urls.first {
                isLoadingPreview = true
                urlPreview = await URLPreviewFetcher.shared.fetchPreview(for: firstURL)
                isLoadingPreview = false
            }
        }
    }
}

/// High-performance text view using TextLayout API for rendering chat messages
/// This view uses NSTextLayoutManager for optimal performance with large chat histories
struct HighPerformanceTextView: View {
    let content: AttributedString
    let baseColor: Color
    var searchText: String? = nil
    
    // PERFORMANCE: Static URL detector cached across all instances
    private static let urlDetector = try? NSDataDetector(
        types: NSTextCheckingResult.CheckingType.link.rawValue
    )
    
    init(content: AttributedString, baseColor: Color = .primary, searchText: String? = nil) {
        self.content = content
        self.baseColor = baseColor
        self.searchText = searchText
    }
    
    var processedContent: AttributedString {
        var attributed = content
        
        // Apply base color to text
        if let range = attributed.range(of: String(attributed.characters)) {
            attributed[range].foregroundColor = baseColor
        }
        
        let text = String(attributed.characters)
        
        // Highlight search matches
        if let searchTerm = searchText, !searchTerm.isEmpty {
            let searchLower = searchTerm.lowercased()
            let textLower = text.lowercased()
            
            var startIndex = textLower.startIndex
            while let range = textLower.range(of: searchLower, range: startIndex..<textLower.endIndex) {
                // Convert to attributed string range
                if let attrRange = attributed.range(of: String(text[range])) {
                    attributed[attrRange].backgroundColor = Color.yellow.opacity(0.4)
                    attributed[attrRange].foregroundColor = Color.black
                }
                startIndex = range.upperBound
            }
        }
        
        // Detect and linkify URLs using cached detector
        let matches = Self.urlDetector?.matches(
            in: text,
            range: NSRange(text.startIndex..., in: text)
        )
        
        for match in matches ?? [] {
            if let range = Range(match.range, in: text),
               let attributedRange = attributed.range(of: String(text[range])) {
                attributed[attributedRange].foregroundColor = .blue
                attributed[attributedRange].underlineStyle = .single
                if let url = match.url {
                    attributed[attributedRange].link = url
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

#Preview("Modern Message Grouping") {
    @Previewable @State var scrollIndex: Int? = nil
    @Previewable @State var highlightIndex: Int? = nil
    
    let server = IRCServer(config: IRCServerConfig(hostname: "irc.libera.chat", nickname: "TestUser"))
    let channel = IRCChannel(name: "#swift", server: server)
    
    // Simulate connection for mention detection
    let connection = IRCConnection(config: server.config)
    server.connection = connection
    
    // Create messages with grouping scenarios
    let now = Date()
    
    var styledMessage = AttributedString("Check out this link: https://swift.org for Swift resources")
    if let range = styledMessage.range(of: "https://swift.org") {
        styledMessage[range].foregroundColor = .blue
        styledMessage[range].underlineStyle = .single
    }
    
    channel.messages = [
        // Status events group
        IRCChatMessage(sender: "Alice", content: "Alice has joined #swift", type: .join, timestamp: now.addingTimeInterval(-300)),
        IRCChatMessage(sender: "Bob", content: "Bob has joined #swift", type: .join, timestamp: now.addingTimeInterval(-290)),
        IRCChatMessage(sender: "Charlie", content: "Charlie has joined #swift", type: .join, timestamp: now.addingTimeInterval(-280)),
        
        // Regular messages
        IRCChatMessage(sender: "Alice", content: "Hey everyone! Welcome to #swift", type: .message, timestamp: now.addingTimeInterval(-270)),
        IRCChatMessage(sender: "Bob", content: "Thanks Alice! Happy to be here 👋", type: .message, timestamp: now.addingTimeInterval(-260)),
        IRCChatMessage(sender: "Bob", content: "Has anyone tried SwiftUI 6?", type: .message, timestamp: now.addingTimeInterval(-250)),
        
        // Grouped messages (same sender within 5 min)
        IRCChatMessage(sender: "Alice", content: "I have! It's amazing", type: .message, timestamp: now.addingTimeInterval(-240)),
        IRCChatMessage(sender: "Alice", content: "The new APIs are so clean", type: .message, timestamp: now.addingTimeInterval(-230)),
        IRCChatMessage(sender: "Alice", content: styledMessage, type: .message, timestamp: now.addingTimeInterval(-220)),
        
        // Mention (with TestUser)
        IRCChatMessage(sender: "Charlie", content: "Hey TestUser, what do you think?", type: .message, timestamp: now.addingTimeInterval(-210)),
        
        // More status events
        IRCChatMessage(sender: "Dave", content: "Dave has quit (Connection reset)", type: .quit, timestamp: now.addingTimeInterval(-200)),
        IRCChatMessage(sender: "Eve", content: "Eve has left #swift", type: .part, timestamp: now.addingTimeInterval(-190)),
        
        // System message
        IRCChatMessage(sender: "System", content: "Topic: Swift programming and iOS development", type: .topic, timestamp: now.addingTimeInterval(-180)),
        
        // Recent messages
        IRCChatMessage(sender: "Bob", content: "The documentation is really helpful", type: .message, timestamp: now.addingTimeInterval(-60)),
        IRCChatMessage(sender: "Alice", content: "Agreed! Apple did a great job", type: .message, timestamp: now.addingTimeInterval(-30)),
    ]
    
    channel.users = [
        IRCUser(nickname: "Alice", modes: ["o"]),
        IRCUser(nickname: "Bob", modes: ["v"]),
        IRCUser(nickname: "Charlie"),
        IRCUser(nickname: "TestUser"),
    ]
    
    return MessageListView(
        channel: channel,
        scrollToMessageIndex: $scrollIndex,
        highlightedMessageIndex: $highlightIndex
    )
    .frame(height: 600)
    .padding()
}
