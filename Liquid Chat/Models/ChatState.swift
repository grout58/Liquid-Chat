//
//  ChatState.swift
//  Liquid Chat
//
//  Main application state management
//

import Foundation
import SwiftUI
import UserNotifications

@MainActor
@Observable
class ChatState: IRCConnectionDelegate {
    /// List of connected IRC servers
    /// Note: Made public for preview/testing purposes - in production use addServer()
    var servers: [IRCServer] = []
    
    /// Currently selected channel for display. Marks the newly selected channel as read.
    var selectedChannel: IRCChannel? {
        didSet { selectedChannel?.markRead() }
    }
    
    /// Server for which to show the channel join dialog
    var showingChannelJoinForServer: IRCServer?
    
    /// Server for which to show the channel list view
    var showingChannelListForServer: IRCServer?

    /// Pending connection error alert (server + message)
    var connectionAlert: ConnectionAlert?
    
    init() {
        // Initialize with empty state
    }
    
    // MARK: - Server Management
    
    /// Adds a new IRC server to the connection list
    /// - Parameter config: The server configuration
    func addServer(config: IRCServerConfig) {
        let server = IRCServer(config: config)
        servers.append(server)
    }
    
    /// Connects to an IRC server and observes its connection state
    /// - Parameter server: The server to connect to
    func connectToServer(_ server: IRCServer) {
        server.manuallyDisconnected = false
        server.reconnectDelay = 5.0
        server.cancelReconnect()
        let connection = IRCConnection(config: server.config)
        connection.delegate = self
        server.connection = connection
        server.connectionState = .connecting
        connection.connect()
        
        // Cancel any existing observation task
        server.cancelObservation()
        
        // Observe connection state changes with proper cancellation support
        server.observationTask = Task { [weak server] in
            await observeConnectionState(for: server)
        }
    }
    
    /// Observes connection state changes with proper cancellation support
    /// - Parameter server: The server to observe (weak reference to prevent retain cycles)
    private func observeConnectionState(for server: IRCServer?) async {
        guard let server = server,
              let connection = server.connection else { return }
        
        // Update server connection state based on IRC connection state
        withObservationTracking {
            let ircState = connection.state
            
            Task { @MainActor in
                guard !Task.isCancelled else { return }
                
                switch ircState {
                case .disconnected:
                    server.connectionState = .disconnected
                case .connecting:
                    server.connectionState = .connecting
                case .connected:
                    server.connectionState = .connecting // Still not fully ready
                case .authenticating:
                    server.connectionState = .authenticating
                case .registered:
                    server.connectionState = .connected
                case .error(let message):
                    server.connectionState = .error(message)
                }
            }
        } onChange: {
            // Only continue observing if not cancelled and connection still exists
            Task { @MainActor [weak server] in
                guard !Task.isCancelled,
                      let server = server,
                      server.connection != nil else { return }
                await self.observeConnectionState(for: server)
            }
        }
    }
    
    /// Disconnects from an IRC server and cancels observation
    /// - Parameter server: The server to disconnect from
    func disconnectFromServer(_ server: IRCServer) {
        server.manuallyDisconnected = true
        server.cancelReconnect()
        server.connection?.disconnect()
        server.connection = nil
        server.isConnected = false
        server.connectionState = .disconnected
        server.cancelObservation()
    }
    
    // MARK: - Channel Management
    
    /// Joins an IRC channel on the specified server
    /// - Parameters:
    ///   - name: The channel name (e.g., "#swift")
    ///   - server: The server where the channel exists
    func joinChannel(name: String, on server: IRCServer) {
        guard let connection = server.connection else { return }
        
        // Create channel if it doesn't exist, or get existing one
        let channel: IRCChannel
        if let existing = server.channels.first(where: { $0.name == name }) {
            channel = existing
        } else {
            channel = IRCChannel(name: name, server: server)
            server.channels.append(channel)
        }
        
        // Switch to the channel immediately
        selectedChannel = channel
        
        connection.join(channel: name)
    }
    
    /// Leaves an IRC channel
    /// - Parameter channel: The channel to leave
    func partChannel(_ channel: IRCChannel) {
        guard let connection = channel.server.connection else { return }
        connection.part(channel: channel.name)
        channel.isJoined = false
    }
    
    /// Opens a private message conversation with a user
    /// - Parameters:
    ///   - nickname: The user's nickname
    ///   - server: The server where the user is connected
    func openPrivateMessage(with nickname: String, on server: IRCServer) {
        // Check if we already have a DM open with this user
        if let existingChannel = server.channels.first(where: { $0.name == nickname }) {
            selectedChannel = existingChannel
            return
        }
        
        // Create a new private message channel
        let channel = IRCChannel(name: nickname, server: server)
        server.channels.append(channel)
        selectedChannel = channel
    }
    
    /// Sends a message to an IRC channel
    /// - Parameters:
    ///   - text: The message text to send
    ///   - channel: The destination channel
    func sendMessage(_ text: String, to channel: IRCChannel) {
        guard let connection = channel.server.connection else { return }
        connection.sendMessage(text, to: channel.name)

        // Add message to local history (own messages never count as unread)
        let message = IRCChatMessage(
            sender: connection.currentNickname,
            content: text,
            type: .message
        )
        channel.appendMessage(message, isActive: true)
    }

    /// Mark a channel as read and clear its unread/mention state.
    func markRead(_ channel: IRCChannel) {
        channel.markRead()
    }

    /// Post a local notification if the user has granted permission.
    private func sendNotification(title: String, body: String, identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = AppSettings.shared.enableSoundNotifications ? .default : nil
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - IRCConnectionDelegate
    
    nonisolated func connectionDidConnect(_ connection: IRCConnection) {
        Task {
            await ConsoleLogger.shared.log("Connected to \(connection.config.hostname)", level: .info, category: "Connection")
        }
    }
    
    nonisolated func connectionDidRegister(_ connection: IRCConnection) {
        Task {
            await ConsoleLogger.shared.log("Registered on \(connection.config.hostname)", level: .info, category: "Connection")
        }
        // Request notification permission once after first successful registration
        Task {
            try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        }
        
        // Mark server as connected - dispatch to MainActor without blocking
        Task { @MainActor in
            if let server = servers.first(where: { $0.connection === connection }) {
                server.isConnected = true
                server.reconnectDelay = 5.0  // Reset backoff on successful registration

                // Rejoin any previously joined channels
                let previousChannels = server.channels.filter { $0.isJoined && !$0.isPrivateMessage }
                if previousChannels.isEmpty {
                    // No previously joined channels — show the join dialog
                    Task {
                        try? await Task.sleep(for: .milliseconds(500))
                        showingChannelJoinForServer = server
                    }
                } else {
                    // Rejoin all previously joined channels
                    for channel in previousChannels {
                        channel.isJoined = false  // Will be set true again on JOIN confirmation
                        connection.join(channel: channel.name)
                    }
                    Task {
                        await ConsoleLogger.shared.log("Rejoining \(previousChannels.count) channel(s) on \(server.config.hostname)", level: .info, category: "Connection")
                    }
                }
            }
        }
    }
    
    nonisolated func connectionDidDisconnect(_ connection: IRCConnection) {
        Task {
            await ConsoleLogger.shared.log("Disconnected from \(connection.config.hostname)", level: .warning, category: "Connection")
        }

        Task { @MainActor in
            if let server = servers.first(where: { $0.connection === connection }) {
                server.isConnected = false
                server.connectionState = .disconnected
                scheduleReconnect(for: server)
            }
        }
    }

    nonisolated func connectionDidFail(_ connection: IRCConnection, error: Error) {
        Task {
            await ConsoleLogger.shared.log("Connection failed: \(error.localizedDescription)", level: .error, category: "Connection")
        }

        Task { @MainActor in
            if let server = servers.first(where: { $0.connection === connection }) {
                server.connectionState = .error(error.localizedDescription)
                // Show alert once the backoff has maxed out (persistent failure)
                if server.reconnectDelay >= 300 {
                    connectionAlert = ConnectionAlert(
                        server: server,
                        message: error.localizedDescription
                    )
                }
                scheduleReconnect(for: server)
            }
        }
    }

    /// Schedule a reconnect attempt with exponential backoff (5s → 10s → 20s … capped at 300s)
    private func scheduleReconnect(for server: IRCServer) {
        guard !server.manuallyDisconnected else { return }

        let delay = server.reconnectDelay
        // Double the delay for next attempt, cap at 5 minutes
        server.reconnectDelay = min(server.reconnectDelay * 2, 300)

        Task {
            await ConsoleLogger.shared.log("Reconnecting to \(server.config.hostname) in \(Int(delay))s…", level: .info, category: "Connection")
        }

        server.reconnectTask = Task { [weak self, weak server] in
            guard let self, let server else { return }
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, !server.manuallyDisconnected else { return }
            await MainActor.run {
                self.connectToServer(server)
            }
        }
    }
    
    nonisolated func connection(_ connection: IRCConnection, didReceiveMessage message: IRCMessage) {
        // CRITICAL: This is called from IRC background thread
        // Use Task to dispatch to MainActor WITHOUT blocking the IRC thread
        Task { @MainActor in
            handleIRCMessage(message, from: connection)
        }
    }
    
    nonisolated func connection(_ connection: IRCConnection, didEncounterError error: Error) {
        Task {
            await ConsoleLogger.shared.log("Connection error: \(error.localizedDescription)", level: .error, category: "Connection")
        }
    }
    
    // MARK: - Message Handling
    
    private func handleIRCMessage(_ message: IRCMessage, from connection: IRCConnection) {
        guard let server = servers.first(where: { $0.connection === connection }) else { return }
        
        switch message.command {
        case "PRIVMSG":
            handlePrivMsg(message, server: server)
            
        case "JOIN":
            handleJoin(message, server: server)
            
        case "PART":
            handlePart(message, server: server)
            
        case "QUIT":
            handleQuit(message, server: server)
            
        case "332": // RPL_TOPIC
            handleTopic(message, server: server)
            
        case "353": // RPL_NAMREPLY
            handleNamesReply(message, server: server)
            
        case "321": // RPL_LISTSTART
            handleListStart(message, server: server)
            
        case "322": // RPL_LIST
            handleList(message, server: server)
            
        case "323": // RPL_LISTEND
            handleListEnd(message, server: server)
            
        case "NICK":
            handleNickChange(message, server: server)
            
        case "MODE":
            handleMode(message, server: server)
            
        case "KICK":
            handleKick(message, server: server)
            
        case "TOPIC":
            handleTopicChange(message, server: server)
            
        case "311": // RPL_WHOISUSER
            handleWhoisUser(message, server: server)
            
        case "312": // RPL_WHOISSERVER
            handleWhoisServer(message, server: server)
            
        case "317": // RPL_WHOISIDLE
            handleWhoisIdle(message, server: server)
            
        case "319": // RPL_WHOISCHANNELS
            handleWhoisChannels(message, server: server)
            
        default:
            break
        }
    }
    
    private func handlePrivMsg(_ message: IRCMessage, server: IRCServer) {
        guard message.parameters.count >= 2,
              let sender = message.nick else { return }

        // Drop messages from ignored users
        guard !AppSettings.shared.isIgnored(sender) else { return }

        let target = message.parameters[0]
        let text = message.parameters[1]

        // Route ZNC pseudo-server messages (*status, *playback, etc.) to a dedicated console channel
        if sender.hasPrefix("*") {
            handleZNCStatus(message: text, from: sender, server: server)
            return
        }
        
        // Determine if this is a channel message or private message
        let isChannelMessage = target.hasPrefix("#") || target.hasPrefix("&")
        
        // For private messages, the "channel" is the sender's nickname
        let channelName = isChannelMessage ? target : sender
        
        // Find or create channel/query
        let channel: IRCChannel
        if let existingChannel = server.channels.first(where: { $0.name == channelName }) {
            channel = existingChannel
        } else {
            // Create a query channel for private messages
            let newChannel = IRCChannel(name: channelName, server: server)
            server.channels.append(newChannel)
            channel = newChannel
        }
        
        // Use server timestamp if available (IRCv3 server-time capability)
        let timestamp = message.serverTime ?? Date()
        let chatMessage = IRCChatMessage(sender: sender, content: text, type: .message, timestamp: timestamp, batchID: message.batchID)

        let currentNick = server.connection?.currentNickname
        let isActive = channel === selectedChannel
        channel.appendMessage(chatMessage, currentNickname: currentNick, isActive: isActive)

        // Fire desktop notifications for mentions and DMs
        let textLower = text.lowercased()
        let isMention = currentNick.map { textLower.contains($0.lowercased()) } ?? false

        if !isActive {
            if !isChannelMessage && AppSettings.shared.enablePrivateMessageNotifications {
                sendNotification(
                    title: "Message from \(sender)",
                    body: text,
                    identifier: "dm-\(sender)-\(timestamp.timeIntervalSince1970)"
                )
            } else if isMention && AppSettings.shared.enableMentionNotifications {
                sendNotification(
                    title: "\(sender) mentioned you in \(channelName)",
                    body: text,
                    identifier: "mention-\(sender)-\(timestamp.timeIntervalSince1970)"
                )
            }
        }

        // Log message to disk
        Task {
            await ChannelLogger.shared.log(
                message: chatMessage,
                channel: channelName,
                server: server.config.hostname
            )
        }
    }
    
    private func handleJoin(_ message: IRCMessage, server: IRCServer) {
        guard message.parameters.count >= 1,
              let nick = message.nick else { return }
        guard !AppSettings.shared.isIgnored(nick) else { return }
        
        let channelName = message.parameters[0]
        
        if let channel = server.channels.first(where: { $0.name == channelName }) {
            // Add user to channel
            let user = IRCUser(nickname: nick)
            channel.users.append(user)
            
            // Add system message
            let joinMessage = IRCChatMessage(
                sender: "System",
                content: "\(nick) has joined \(channelName)",
                type: .join
            )
            channel.appendMessage(joinMessage)
            
            // If it's us, mark channel as joined
            if let connection = server.connection, nick == connection.currentNickname {
                channel.isJoined = true
            }
        }
    }
    
    private func handlePart(_ message: IRCMessage, server: IRCServer) {
        guard message.parameters.count >= 1,
              let nick = message.nick else { return }
        
        let channelName = message.parameters[0]
        
        if let channel = server.channels.first(where: { $0.name == channelName }) {
            // Remove user from channel
            channel.users.removeAll { $0.nickname == nick }
            
            // Add system message
            let partMessage = IRCChatMessage(
                sender: "System",
                content: "\(nick) has left \(channelName)",
                type: .part
            )
            channel.appendMessage(partMessage)
        }
    }
    
    /// Handles QUIT messages from IRC server
    /// Optimized to O(n) by using single-pass removal instead of contains+removeAll
    private func handleQuit(_ message: IRCMessage, server: IRCServer) {
        guard let nick = message.nick else { return }
        
        let quitMessage = message.parameters.first ?? "Quit"
        
        // Optimized: Single pass through channels, only create quit message if user was present
        for channel in server.channels {
            // Use firstIndex for O(n) single-pass check and removal
            if let userIndex = channel.users.firstIndex(where: { $0.nickname == nick }) {
                // Remove user (already found, no need to search again)
                channel.users.remove(at: userIndex)
                
                // Add quit message only to channels where user was present
                let systemMessage = IRCChatMessage(
                    sender: "System",
                    content: "\(nick) has quit (\(quitMessage))",
                    type: .quit
                )
                channel.appendMessage(systemMessage)
            }
        }
    }
    
    private func handleTopic(_ message: IRCMessage, server: IRCServer) {
        guard message.parameters.count >= 2 else { return }
        
        let channelName = message.parameters[1]
        let topic = message.parameters.count >= 3 ? message.parameters[2] : ""
        
        if let channel = server.channels.first(where: { $0.name == channelName }) {
            channel.topic = topic
        }
    }
    
    private func handleNamesReply(_ message: IRCMessage, server: IRCServer) {
        guard message.parameters.count >= 4 else { 
            Task { await ConsoleLogger.shared.log("NAMES: Invalid parameters count: \(message.parameters.count)", level: .error, category: "IRC") }
            return 
        }
        
        let channelName = message.parameters[2]
        let names = message.parameters[3].split(separator: " ").map(String.init)
        
        Task { await ConsoleLogger.shared.log("NAMES for \(channelName): \(names.count) users", level: .info, category: "IRC") }
        
        if let channel = server.channels.first(where: { $0.name == channelName }) {
            for name in names {
                var nickname = name
                var modes: Set<Character> = []
                
                // Parse mode prefixes (handle multi-prefix like @+nickname)
                while let first = nickname.first, ["@", "+", "%", "&", "~"].contains(first) {
                    modes.insert(first)
                    nickname.removeFirst()
                }
                
                let user = IRCUser(nickname: nickname, modes: modes)
                if !channel.users.contains(where: { $0.nickname == nickname }) {
                    channel.users.append(user)
                }
            }
            Task { await ConsoleLogger.shared.log("Total users in \(channelName): \(channel.users.count)", level: .debug, category: "IRC") }
        } else {
            Task { await ConsoleLogger.shared.log("Channel \(channelName) not found in server channels", level: .warning, category: "IRC") }
        }
    }
    
    // MARK: - ZNC Bouncer Handling

    /// Route messages from ZNC pseudo-users (*status, *playback, etc.) to a server console channel.
    private func handleZNCStatus(message text: String, from sender: String, server: IRCServer) {
        let consoleName = sender  // e.g. "*status" or "*playback"

        let channel: IRCChannel
        if let existing = server.channels.first(where: { $0.name == consoleName }) {
            channel = existing
        } else {
            let newChannel = IRCChannel(name: consoleName, server: server)
            server.channels.append(newChannel)
            channel = newChannel
        }

        let msg = IRCChatMessage(sender: sender, content: text, type: .system)
        channel.appendMessage(msg, isActive: channel === selectedChannel)

        Task { await ConsoleLogger.shared.log("ZNC \(sender): \(text)", level: .info, category: "ZNC") }
    }

    // MARK: - Channel List Handling
    
    private func handleListStart(_ message: IRCMessage, server: IRCServer) {
        // Clear previous list and start loading
        server.availableChannels.removeAll()
        server.isLoadingChannelList = true
        Task { await ConsoleLogger.shared.log("LIST START - loading channels...", level: .info, category: "IRC") }
        
        // Show the channel list dialog now that server has responded
        // (prevents opening empty dialog before data arrives)
        Task { @MainActor in
            if showingChannelListForServer == nil {
                showingChannelListForServer = server
            }
        }
    }
    
    private func handleList(_ message: IRCMessage, server: IRCServer) {
        // 322 <client> <channel> <# visible> :<topic>
        guard message.parameters.count >= 3 else { return }
        
        let channelName = message.parameters[1]
        let userCount = Int(message.parameters[2]) ?? 0
        let topic = message.parameters.count >= 4 ? message.parameters[3] : ""
        
        let entry = IRCChannelListEntry(
            name: channelName,
            userCount: userCount,
            topic: topic
        )
        
        // Buffer without logging - prevents MainActor saturation
        server.bufferChannelListEntry(entry)
    }
    
    private func handleListEnd(_ message: IRCMessage, server: IRCServer) {
        Task { await ConsoleLogger.shared.log("LIST END received", level: .info, category: "IRC") }
        
        // Flush and sort in single operation (sorting happens in actor)
        Task.detached {
            await server.flushChannelListBuffer()
            
            await MainActor.run {
                server.isLoadingChannelList = false
            }
        }
    }
    
    // MARK: - Additional IRC Protocol Handlers (Apple Compliance)
    
    /// Handles NICK change messages from IRC server
    /// Performance: O(n×m) where n=channels, m=users per channel (unavoidable - user could be in any channel)
    private func handleNickChange(_ message: IRCMessage, server: IRCServer) {
        guard message.parameters.count >= 1,
              let oldNick = message.nick else { return }
        
        let newNick = message.parameters[0]
        
        // Update user in all channels they're in (optimized with firstIndex for single-pass lookup)
        for channel in server.channels {
            if let userIndex = channel.users.firstIndex(where: { $0.nickname == oldNick }) {
                let oldUser = channel.users[userIndex]
                let updatedUser = IRCUser(
                    nickname: newNick,
                    username: oldUser.username,
                    hostname: oldUser.hostname,
                    modes: oldUser.modes
                )
                channel.users[userIndex] = updatedUser
                
                // Add system message
                let nickMessage = IRCChatMessage(
                    sender: "System",
                    content: "\(oldNick) is now known as \(newNick)",
                    type: .nick
                )
                channel.appendMessage(nickMessage)
            }
        }
        
        // Update our own nickname if it's us
        if let connection = server.connection, connection.currentNickname == oldNick {
            // Connection handles its own nickname update
        }
    }
    
    private func handleMode(_ message: IRCMessage, server: IRCServer) {
        guard message.parameters.count >= 2 else { return }
        
        let target = message.parameters[0]
        let modeString = message.parameters[1]
        
        // Only handle channel modes
        guard target.hasPrefix("#") || target.hasPrefix("&"),
              let channel = server.channels.first(where: { $0.name == target }) else { return }
        
        // Parse mode changes (+o, -v, etc.)
        var adding = true
        var modeIndex = 2 // Parameter index for mode arguments
        
        for char in modeString {
            switch char {
            case "+":
                adding = true
            case "-":
                adding = false
            case "o", "v": // Op and Voice modes
                if modeIndex < message.parameters.count {
                    let nickname = message.parameters[modeIndex]
                    if let userIndex = channel.users.firstIndex(where: { $0.nickname == nickname }) {
                        var user = channel.users[userIndex]
                        if adding {
                            user.modes.insert(char)
                        } else {
                            user.modes.remove(char)
                        }
                        channel.users[userIndex] = user
                    }
                    modeIndex += 1
                }
            default:
                // Other modes don't affect user list
                break
            }
        }
        
        // Add system message
        if let setter = message.nick {
            let modeMessage = IRCChatMessage(
                sender: "System",
                content: "\(setter) sets mode \(modeString)",
                type: .system
            )
            channel.appendMessage(modeMessage)
        }
    }
    
    private func handleKick(_ message: IRCMessage, server: IRCServer) {
        guard message.parameters.count >= 2,
              let kicker = message.nick else { return }
        
        let channelName = message.parameters[0]
        let kickedUser = message.parameters[1]
        let reason = message.parameters.count >= 3 ? message.parameters[2] : "No reason given"
        
        if let channel = server.channels.first(where: { $0.name == channelName }) {
            // Remove kicked user from channel
            channel.users.removeAll { $0.nickname == kickedUser }
            
            // Add system message
            let kickMessage = IRCChatMessage(
                sender: "System",
                content: "\(kickedUser) was kicked by \(kicker) (\(reason))",
                type: .part
            )
            channel.appendMessage(kickMessage)
            
            // If we were kicked, mark channel as not joined
            if let connection = server.connection, kickedUser == connection.currentNickname {
                channel.isJoined = false
            }
        }
    }
    
    private func handleTopicChange(_ message: IRCMessage, server: IRCServer) {
        guard message.parameters.count >= 2,
              let setter = message.nick else { return }
        
        let channelName = message.parameters[0]
        let newTopic = message.parameters[1]
        
        if let channel = server.channels.first(where: { $0.name == channelName }) {
            channel.topic = newTopic
            
            // Add system message
            let topicMessage = IRCChatMessage(
                sender: "System",
                content: "\(setter) changed the topic to: \(newTopic)",
                type: .topic
            )
            channel.appendMessage(topicMessage)
        }
    }
    
    // MARK: - WHOIS Response Handlers
    
    private func handleWhoisUser(_ message: IRCMessage, server: IRCServer) {
        // 311 <client> <nick> <user> <host> * :<real name>
        guard message.parameters.count >= 6 else { return }
        
        let nick = message.parameters[1]
        let user = message.parameters[2]
        let host = message.parameters[3]
        let realName = message.parameters[5]
        
        // Display in all channels where this user is present
        for channel in server.channels where channel.users.contains(where: { $0.nickname == nick }) {
            let whoisMessage = IRCChatMessage(
                sender: "WHOIS",
                content: "\(nick) is \(user)@\(host) (\(realName))",
                type: .system
            )
            channel.appendMessage(whoisMessage)
        }
    }
    
    private func handleWhoisServer(_ message: IRCMessage, server: IRCServer) {
        // 312 <client> <nick> <server> :<server info>
        guard message.parameters.count >= 4 else { return }
        
        let nick = message.parameters[1]
        let serverName = message.parameters[2]
        let serverInfo = message.parameters[3]
        
        for channel in server.channels where channel.users.contains(where: { $0.nickname == nick }) {
            let whoisMessage = IRCChatMessage(
                sender: "WHOIS",
                content: "\(nick) is connected to \(serverName) (\(serverInfo))",
                type: .system
            )
            channel.appendMessage(whoisMessage)
        }
    }
    
    private func handleWhoisIdle(_ message: IRCMessage, server: IRCServer) {
        // 317 <client> <nick> <idle> <signon> :seconds idle, signon time
        guard message.parameters.count >= 4 else { return }
        
        let nick = message.parameters[1]
        let idleSeconds = Int(message.parameters[2]) ?? 0
        
        let idleTime = formatIdleTime(seconds: idleSeconds)
        
        for channel in server.channels where channel.users.contains(where: { $0.nickname == nick }) {
            let whoisMessage = IRCChatMessage(
                sender: "WHOIS",
                content: "\(nick) has been idle for \(idleTime)",
                type: .system
            )
            channel.appendMessage(whoisMessage)
        }
    }
    
    private func handleWhoisChannels(_ message: IRCMessage, server: IRCServer) {
        // 319 <client> <nick> :<channels>
        guard message.parameters.count >= 3 else { return }
        
        let nick = message.parameters[1]
        let channels = message.parameters[2]
        
        for channel in server.channels where channel.users.contains(where: { $0.nickname == nick }) {
            let whoisMessage = IRCChatMessage(
                sender: "WHOIS",
                content: "\(nick) is in channels: \(channels)",
                type: .system
            )
            channel.appendMessage(whoisMessage)
        }
    }
    
    private func formatIdleTime(seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m \(secs)s"
        } else if minutes > 0 {
            return "\(minutes)m \(secs)s"
        } else {
            return "\(secs)s"
        }
    }
}

/// Data for a connection error alert
struct ConnectionAlert: Identifiable {
    let id = UUID()
    let server: IRCServer
    let message: String
}
