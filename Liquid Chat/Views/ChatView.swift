//
//  ChatView.swift
//  Liquid Chat
//
//  Main chat interface with Liquid Glass message buffer
//

import SwiftUI

struct ChatView: View {
    let channel: IRCChannel
    let chatState: ChatState
    
    @State private var messageText = ""
    @State private var showUserList = true
    @State private var messageHistory: [String] = []
    @State private var historyIndex = -1
    
    private var settings: AppSettings { AppSettings.shared }
    
    private var commandHandler: IRCCommandHandler {
        IRCCommandHandler(connection: channel.server.connection, chatState: chatState)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Main message area
                VStack(spacing: 0) {
                    // Channel header
                    ChannelHeaderView(channel: channel)
                        .themedCard(cornerRadius: 12, settings: settings)
                        .padding(.horizontal, 12)
                        .padding(.top, 12)
                    
                    // Message list
                    MessageListView(channel: channel)
                        .themedCard(cornerRadius: 12, settings: settings)
                        .padding(12)
                    
                    // Message input
                    MessageInputView(
                        messageText: $messageText,
                        messageHistory: messageHistory,
                        historyIndex: $historyIndex,
                        onSend: {
                            sendMessage()
                        }
                    )
                    .themedCard(cornerRadius: 20, settings: settings)
                    .padding(12)
                }
                
                // User list sidebar (if visible)
                if showUserList {
                    UserListView(channel: channel)
                        .frame(width: 200)
                        .themedCard(cornerRadius: 12, settings: settings)
                        .padding(.trailing, 12)
                        .padding(.vertical, 12)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
        }
        .themedBackground(settings)
        .navigationTitle(channel.name)
        .toolbar {
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
        }
    }
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        // Add to history
        messageHistory.append(messageText)
        if messageHistory.count > 50 {
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
}

struct ChannelHeaderView: View {
    let channel: IRCChannel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "number")
                    .foregroundStyle(.secondary)
                
                Text(channel.name)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(channel.users.count) users")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if !channel.topic.isEmpty {
                Text(channel.topic)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(12)
    }
}

struct MessageInputView: View {
    @Binding var messageText: String
    let messageHistory: [String]
    @Binding var historyIndex: Int
    let onSend: () -> Void
    
    @FocusState private var isFocused: Bool
    
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
}

struct UserListView: View {
    let channel: IRCChannel
    
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
                        UserRowView(user: user)
                    }
                }
                .padding(.horizontal, 8)
            }
        }
    }
}

struct UserRowView: View {
    let user: IRCUser
    
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
