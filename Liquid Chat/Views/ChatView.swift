//
//  ChatView.swift
//  Liquid Chat
//
//  Main chat interface with Liquid Glass message buffer
//

import SwiftUI

struct ChatView: View {
    let channel: IRCChannel
    @Bindable var chatState: ChatState
    
    @State private var messageText = ""
    @State private var showUserList = true
    @State private var messageHistory: [String] = []
    @State private var historyIndex = -1
    @State private var showPastebinAlert = false
    @Namespace private var glassNamespace
    
    // AI Summarization
    @State private var summarizer = CatchUpSummarizer()
    @State private var showingSummary = false
    @State private var currentSummary: ChatSummary?
    @State private var isSummarizing = false
    @State private var summaryError: String?
    @State private var showSummaryError = false
    
    // Search
    @State private var showSearch = false
    @State private var scrollToMessageIndex: Int?
    @State private var highlightedMessageIndex: Int?
    
    // Channel Recommendations
    @State private var recommender = ChannelRecommender()
    @State private var showingRecommendations = false
    @State private var currentRecommendations: [ChannelRecommendation] = []
    @State private var isGeneratingRecommendations = false
    @State private var recommendationError: String?
    @State private var showRecommendationError = false
    
    private var settings: AppSettings { AppSettings.shared }
    
    private var commandHandler: IRCCommandHandler {
        IRCCommandHandler(connection: channel.server.connection, chatState: chatState)
    }
    
    var body: some View {
        // Liquid Glass Container for morphing effects
        GlassEffectContainer(spacing: 16.0) {
            VStack(spacing: 0) {
                // Search bar at top (morphs in/out)
                if showSearch {
                    ChatSearchView(channel: channel, isPresented: $showSearch)
                        .padding(.horizontal, 12)
                        .padding(.top, 12)
                        .glassEffectID("search", in: glassNamespace)
                        .glassEffectTransition(.matchedGeometry)
                }
                
                HStack(spacing: 0) {
                    // Main message area
                    VStack(spacing: 0) {
                        // Channel header with Liquid Glass
                        ChannelHeaderView(channel: channel)
                            .padding(12)
                            .glassEffect(.regular.tint(.blue.opacity(0.15)), 
                                        in: .rect(cornerRadius: 12))
                            .glassEffectID("header", in: glassNamespace)
                            .padding(.horizontal, 12)
                            .padding(.top, showSearch ? 0 : 12)
                        
                        // Message list with Liquid Glass
                        MessageListView(
                            channel: channel,
                            scrollToMessageIndex: $scrollToMessageIndex,
                            highlightedMessageIndex: $highlightedMessageIndex
                        )
                        .glassEffect(.regular, in: .rect(cornerRadius: 12))
                        .glassEffectID("messages", in: glassNamespace)
                        .padding(12)
                        
                        // Message input with interactive Liquid Glass
                        MessageInputView(
                            messageText: $messageText,
                            messageHistory: messageHistory,
                            historyIndex: $historyIndex,
                            onSend: {
                                sendMessage()
                            },
                            users: channel.users
                        )
                        .padding(12)
                        .glassEffect(.regular.interactive(), 
                                    in: .rect(cornerRadius: 20))
                        .glassEffectID("input", in: glassNamespace)
                        .padding(12)
                    }
                    
                    // User list sidebar with morphing transition
                    if showUserList {
                        UserListView(channel: channel, chatState: chatState)
                            .frame(width: UI.userListWidth)
                            .glassEffect(.regular, in: .rect(cornerRadius: 12))
                            .glassEffectID("userlist", in: glassNamespace)
                            .padding(.trailing, 12)
                            .padding(.vertical, 12)
                    }
                }
            }
        }
        .navigationTitle(channel.name)
        .sheet(item: $chatState.showingChannelListForServer) { server in
            ChannelListView(server: server, chatState: chatState)
        }
        .alert("Large Message", isPresented: $showPastebinAlert) {
            Button("Send Anyway") {
                performSend()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This message contains \(messageText.components(separatedBy: .newlines).count) lines. Consider using a pastebin service for large blocks of text.")
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        showSearch.toggle()
                    }
                } label: {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .buttonStyle(.glass)
                .help("Search in conversation (Cmd+F)")
                .keyboardShortcut("f", modifiers: .command)
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button {
                    withAnimation(.spring) {
                        showUserList.toggle()
                    }
                } label: {
                    Label(
                        showUserList ? "Hide Users" : "Show Users",
                        systemImage: "person.2"
                    )
                }
                .buttonStyle(.glass)
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button {
                    generateSummary()
                } label: {
                    if isSummarizing {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Summarizing...")
                                .font(.caption)
                        }
                    } else {
                        Label("Summarize", systemImage: "sparkles")
                    }
                }
                .buttonStyle(.glass)
                .disabled(isSummarizing || !summarizer.isAvailable || channel.messages.isEmpty)
                .help(summarizer.isAvailable 
                      ? "Generate AI summary of conversation" 
                      : "AI features require macOS 26+ with Apple Intelligence")
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button {
                    generateRecommendations()
                } label: {
                    if isGeneratingRecommendations {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Finding...")
                                .font(.caption)
                        }
                    } else {
                        Label("Recommend", systemImage: "sparkles.rectangle.stack")
                    }
                }
                .buttonStyle(.glass)
                .disabled(isGeneratingRecommendations || !AppSettings.shared.enableAIFeatures || 
                         channel.messages.isEmpty || channel.server.availableChannels.isEmpty)
                .help(AppSettings.shared.enableAIFeatures
                      ? "Get AI-powered channel recommendations"
                      : "AI features require macOS 26+ with Apple Intelligence")
            }
        }
        .sheet(isPresented: $showingSummary) {
            if let summary = currentSummary {
                SummaryView(summary: summary)
            }
        }
        .alert("Summarization Error", isPresented: $showSummaryError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(summaryError ?? "An unknown error occurred")
        }
        .sheet(isPresented: $showingRecommendations) {
            ChannelRecommendationView(
                recommendations: currentRecommendations,
                onJoin: { channelName in
                    chatState.joinChannel(name: channelName, on: channel.server)
                },
                onDismiss: {
                    showingRecommendations = false
                }
            )
        }
        .alert("Recommendation Error", isPresented: $showRecommendationError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(recommendationError ?? "An unknown error occurred")
        }
        .onReceive(NotificationCenter.default.publisher(for: .scrollToSearchResult)) { notification in
            if let messageIndex = notification.userInfo?["messageIndex"] as? Int {
                scrollToMessageIndex = messageIndex
                highlightedMessageIndex = messageIndex
                
                // Clear highlight after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        highlightedMessageIndex = nil
                    }
                }
            }
        }
    }
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        // Check if message exceeds pastebin threshold
        let lineCount = messageText.components(separatedBy: .newlines).count
        if lineCount >= IRC.pastebinThreshold {
            showPastebinAlert = true
            return
        }
        
        performSend()
    }
    
    private func performSend() {
        // Add to history
        messageHistory.append(messageText)
        if messageHistory.count > IRC.maxCommandHistory {
            messageHistory.removeFirst()
        }
        historyIndex = -1
        
        // Check if it's a command
        let isCommand = commandHandler.handleInput(messageText, in: channel)
        
        // If not a command, send as regular message
        if !isCommand {
            chatState.sendMessage(messageText, to: channel)
        }
        
        messageText = ""
    }
    
    private func generateSummary() {
        guard !isSummarizing else { return }
        
        isSummarizing = true
        summaryError = nil
        
        Task { @MainActor in
            do {
                currentSummary = try await summarizer.summarize(messages: channel.messages)
                showingSummary = true
            } catch let error as CatchUpSummarizer.SummarizerError {
                switch error {
                case .featuresDisabled:
                    summaryError = "AI features are disabled. Enable them in Settings > Advanced > AI Features."
                case .modelUnavailable:
                    summaryError = "AI model is unavailable. This feature requires macOS 26+ with Apple Intelligence enabled."
                case .noMessages:
                    summaryError = "No messages to summarize."
                }
                showSummaryError = true
            } catch {
                summaryError = "Failed to generate summary: \(error.localizedDescription)"
                showSummaryError = true
            }
            isSummarizing = false
        }
    }
    
    /// Generate AI-powered channel recommendations based on current conversation
    private func generateRecommendations() {
        guard !isGeneratingRecommendations else { return }
        
        isGeneratingRecommendations = true
        recommendationError = nil
        
        Task { @MainActor in
            do {
                currentRecommendations = try await recommender.recommend(
                    basedOn: channel.messages,
                    from: channel.server.availableChannels,
                    excluding: channel.name
                )
                
                if currentRecommendations.isEmpty {
                    recommendationError = "No relevant channels found. Try /list to see all available channels."
                    showRecommendationError = true
                } else {
                    showingRecommendations = true
                    ConsoleLogger.shared.log(
                        "Generated \(currentRecommendations.count) channel recommendations",
                        level: .info,
                        category: "AI"
                    )
                }
            } catch let error as RecommenderError {
                recommendationError = error.localizedDescription
                showRecommendationError = true
            } catch {
                recommendationError = "Failed to generate recommendations: \(error.localizedDescription)"
                showRecommendationError = true
            }
            isGeneratingRecommendations = false
        }
    }
}

struct ChannelHeaderView: View {
    let channel: IRCChannel
    @Environment(\.themeColors) private var themeColors
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "number")
                    .font(.title3)
                    .foregroundStyle(themeColors.accent.opacity(0.8))
                
                Text(channel.name)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(themeColors.text)
                
                Spacer()
                
                // User count badge
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.caption2)
                    Text("\(channel.users.count)")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundStyle(themeColors.secondaryText)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(themeColors.secondaryBackground.opacity(0.5))
                .clipShape(Capsule())
            }
            
            // Topic bar with subtle separator
            if !channel.topic.isEmpty {
                Divider()
                    .padding(.vertical, 2)
                
                HStack(spacing: 6) {
                    Image(systemName: "text.bubble")
                        .font(.caption)
                        .foregroundStyle(themeColors.secondaryText.opacity(0.6))
                    
                    Text(channel.topic)
                        .font(.subheadline)
                        .foregroundStyle(themeColors.secondaryText)
                        .lineLimit(2)
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial) // Material background for blur effect
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct MessageInputView: View {
    @Binding var messageText: String
    let messageHistory: [String]
    @Binding var historyIndex: Int
    let onSend: () -> Void
    var users: [IRCUser] = []
    
    @FocusState private var isFocused: Bool
    @State private var tabCompletionIndex = 0
    @State private var lastTabCompletionWord = ""
    
    var body: some View {
        HStack(spacing: 12) {
            TextField("Message or /command", text: $messageText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .focused($isFocused)
                .onSubmit {
                    onSend()
                }
                .onKeyPress(.upArrow) {
                    navigateHistory(direction: .up)
                    return .handled
                }
                .onKeyPress(.downArrow) {
                    navigateHistory(direction: .down)
                    return .handled
                }
                .onKeyPress(.tab) {
                    handleTabCompletion()
                    return .handled
                }
            
            Button {
                onSend()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
            .disabled(messageText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(12)
        .onAppear {
            isFocused = true
        }
    }
    
    private func navigateHistory(direction: HistoryDirection) {
        guard !messageHistory.isEmpty else { return }
        
        switch direction {
        case .up:
            if historyIndex < messageHistory.count - 1 {
                historyIndex += 1
                messageText = messageHistory[messageHistory.count - 1 - historyIndex]
            }
        case .down:
            if historyIndex > 0 {
                historyIndex -= 1
                messageText = messageHistory[messageHistory.count - 1 - historyIndex]
            } else if historyIndex == 0 {
                historyIndex = -1
                messageText = ""
            }
        }
    }
    
    enum HistoryDirection {
        case up, down
    }
    
    private func handleTabCompletion() {
        guard !users.isEmpty else { return }
        
        // Find the current word being typed
        let cursorPosition = messageText.endIndex
        var wordStart = messageText.startIndex
        
        // Find the start of the current word
        for i in messageText.indices.reversed() {
            if messageText[i].isWhitespace {
                wordStart = messageText.index(after: i)
                break
            }
        }
        
        let currentWord = String(messageText[wordStart..<cursorPosition])
        
        // If this is a new tab completion (word changed), reset the index
        if currentWord != lastTabCompletionWord {
            tabCompletionIndex = 0
            lastTabCompletionWord = currentWord
        }
        
        // Find matching nicknames
        let matches = users
            .map { $0.nickname }
            .filter { $0.lowercased().hasPrefix(currentWord.lowercased()) }
            .sorted()
        
        guard !matches.isEmpty else { return }
        
        // Get the next match (cycle through)
        let match = matches[tabCompletionIndex % matches.count]
        tabCompletionIndex += 1
        
        // Replace the current word with the match
        messageText.removeSubrange(wordStart..<cursorPosition)
        
        // Add colon if at the start of the message
        if wordStart == messageText.startIndex {
            messageText.insert(contentsOf: "\(match): ", at: wordStart)
        } else {
            messageText.insert(contentsOf: match, at: wordStart)
        }
        
        lastTabCompletionWord = match
    }
}

struct UserListView: View {
    let channel: IRCChannel
    let chatState: ChatState
    
    var sortedUsers: [IRCUser] {
        channel.users.sorted { user1, user2 in
            // Sort by mode (ops first, then voiced, then regular)
            if user1.modes.contains("o") && !user2.modes.contains("o") { return true }
            if !user1.modes.contains("o") && user2.modes.contains("o") { return false }
            if user1.modes.contains("v") && !user2.modes.contains("v") { return true }
            if !user1.modes.contains("v") && user2.modes.contains("v") { return false }
            return user1.nickname.localizedCaseInsensitiveCompare(user2.nickname) == .orderedAscending
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Users")
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.top, 8)
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(sortedUsers) { user in
                        UserRowView(user: user, channel: channel, chatState: chatState)
                    }
                }
                .padding(.horizontal, 8)
            }
        }
    }
}

struct UserRowView: View {
    let user: IRCUser
    let channel: IRCChannel
    let chatState: ChatState
    
    var body: some View {
        HStack(spacing: 8) {
            Text(user.displayPrefix)
                .font(.caption)
                .foregroundStyle(user.modes.contains("o") ? .orange : .green)
                .frame(width: 12)
            
            Image(systemName: "person.circle.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text(user.nickname)
                .font(.body)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .contextMenu {
            // Information
            Button {
                if let connection = channel.server.connection {
                    connection.send(command: "WHOIS", parameters: [user.nickname])
                }
            } label: {
                Label("WHOIS", systemImage: "info.circle")
            }
            
            Divider()
            
            // Communication
            Button {
                chatState.openPrivateMessage(with: user.nickname, on: channel.server)
            } label: {
                Label("Send Direct Message", systemImage: "bubble.left.and.bubble.right")
            }
            
            Divider()
            
            // Moderation (if you're an op)
            if let connection = channel.server.connection,
               channel.users.first(where: { $0.nickname == connection.currentNickname })?.modes.contains("o") == true {
                
                Button {
                    if let connection = channel.server.connection {
                        connection.send(command: "MODE", parameters: [channel.name, "+o", user.nickname])
                    }
                } label: {
                    Label("Give Op", systemImage: "star.fill")
                }
                
                Button {
                    if let connection = channel.server.connection {
                        connection.send(command: "MODE", parameters: [channel.name, "-o", user.nickname])
                    }
                } label: {
                    Label("Remove Op", systemImage: "star")
                }
                
                Button {
                    if let connection = channel.server.connection {
                        connection.send(command: "MODE", parameters: [channel.name, "+v", user.nickname])
                    }
                } label: {
                    Label("Give Voice", systemImage: "mic.fill")
                }
                
                Button {
                    if let connection = channel.server.connection {
                        connection.send(command: "MODE", parameters: [channel.name, "-v", user.nickname])
                    }
                } label: {
                    Label("Remove Voice", systemImage: "mic.slash")
                }
                
                Divider()
                
                Button(role: .destructive) {
                    if let connection = channel.server.connection {
                        connection.send(command: "KICK", parameters: [channel.name, user.nickname])
                    }
                } label: {
                    Label("Kick", systemImage: "person.crop.circle.badge.xmark")
                }
                
                Button(role: .destructive) {
                    if let connection = channel.server.connection {
                        connection.send(command: "MODE", parameters: [channel.name, "+b", "\(user.nickname)!*@*"])
                        connection.send(command: "KICK", parameters: [channel.name, user.nickname])
                    }
                } label: {
                    Label("Kick & Ban", systemImage: "hand.raised.fill")
                }
            }
        }
    }
}

#Preview {
    let chatState = ChatState()
    let server = IRCServer(config: IRCServerConfig(
        hostname: "irc.libera.chat",
        useSSL: true,
        nickname: "TestUser"
    ))
    
    let channel = IRCChannel(name: "#swift", server: server)
    channel.topic = "Swift programming and iOS development"
    channel.messages = [
        IRCChatMessage(sender: "Alice", content: "Welcome to #swift!", type: .join),
        IRCChatMessage(sender: "Bob", content: "Hello everyone! How's everyone doing today?", type: .message),
        IRCChatMessage(sender: "Charlie", content: "Working on a new SwiftUI project", type: .message),
    ]
    channel.users = [
        IRCUser(nickname: "Alice", modes: ["o"]),
        IRCUser(nickname: "Bob", modes: ["v"]),
        IRCUser(nickname: "Charlie"),
        IRCUser(nickname: "TestUser"),
    ]
    
    return ChatView(channel: channel, chatState: chatState)
}
