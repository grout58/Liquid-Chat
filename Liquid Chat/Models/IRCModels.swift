//
//  IRCModels.swift
//  Liquid Chat
//
//  Data models for IRC chat
//

import Foundation
import SwiftUI

/// Connection state for display purposes
enum ServerConnectionState {
    case disconnected
    case connecting
    case authenticating
    case connected
    case error(String)
    
    var displayText: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting..."
        case .authenticating: return "Authenticating..."
        case .connected: return "Connected"
        case .error(let message): return "Error: \(message)"
        }
    }
    
    var systemImage: String {
        switch self {
        case .disconnected: return "network.slash"
        case .connecting: return "network"
        case .authenticating: return "network"
        case .connected: return "network"
        case .error: return "exclamationmark.triangle"
        }
    }
    
    var statusColor: Color {
        switch self {
        case .disconnected: return .secondary
        case .connecting: return .orange
        case .authenticating: return .orange
        case .connected: return .green
        case .error: return .red
        }
    }
}

/// Represents an IRC server
@Observable
class IRCServer: Identifiable {
    let id = UUID()
    let config: IRCServerConfig
    var connection: IRCConnection?
    var channels: [IRCChannel] = []
    var isConnected: Bool = false
    var connectionState: ServerConnectionState = .disconnected
    var availableChannels: [IRCChannelListEntry] = []
    var isLoadingChannelList: Bool = false
    
    /// Task for observing connection state changes (can be cancelled)
    var observationTask: Task<Void, Never>?
    
    /// Temporary buffer for batching channel list updates (not observable)
    private var channelListBuffer: [IRCChannelListEntry] = []
    private var listUpdateTask: Task<Void, Never>?
    
    init(config: IRCServerConfig) {
        self.config = config
    }
    
    /// Cancel any ongoing observation tasks
    func cancelObservation() {
        observationTask?.cancel()
        observationTask = nil
        listUpdateTask?.cancel()
        listUpdateTask = nil
    }
    
    /// Add channel to buffer for batched updates
    @MainActor
    func bufferChannelListEntry(_ entry: IRCChannelListEntry) {
        channelListBuffer.append(entry)
        
        // Schedule a batched update if not already scheduled
        if listUpdateTask == nil {
            listUpdateTask = Task { @MainActor in
                // Wait a bit to accumulate more entries
                try? await Task.sleep(for: .milliseconds(100))
                
                // Append all buffered entries at once
                if !channelListBuffer.isEmpty {
                    availableChannels.append(contentsOf: channelListBuffer)
                    channelListBuffer.removeAll(keepingCapacity: true)
                }
                
                listUpdateTask = nil
            }
        }
    }
    
    /// Flush any remaining buffered entries
    @MainActor
    func flushChannelListBuffer() {
        listUpdateTask?.cancel()
        listUpdateTask = nil
        
        if !channelListBuffer.isEmpty {
            availableChannels.append(contentsOf: channelListBuffer)
            channelListBuffer.removeAll()
        }
    }
}

/// Represents a channel in the server's channel list
struct IRCChannelListEntry: Identifiable {
    let id = UUID()
    let name: String
    let userCount: Int
    let topic: String
}

/// Represents an IRC channel
@Observable
class IRCChannel: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let server: IRCServer
    var topic: String = ""
    var messages: [IRCChatMessage] = []
    var users: [IRCUser] = []
    var isJoined: Bool = false
    
    /// Is this a private message (DM) rather than a channel?
    var isPrivateMessage: Bool {
        !name.hasPrefix("#") && !name.hasPrefix("&")
    }
    
    init(name: String, server: IRCServer) {
        self.name = name
        self.server = server
    }
    
    static func == (lhs: IRCChannel, rhs: IRCChannel) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Represents a user in a channel
struct IRCUser: Identifiable, Hashable {
    let id = UUID()
    let nickname: String
    var username: String?
    var hostname: String?
    var modes: Set<Character> = []
    
    var displayPrefix: String {
        if modes.contains("o") { return "@" }
        if modes.contains("v") { return "+" }
        return ""
    }
    
    var displayName: String {
        displayPrefix + nickname
    }
}

/// Represents a chat message
struct IRCChatMessage: Identifiable {
    let id = UUID()
    let timestamp: Date
    let sender: String
    let content: AttributedString
    let type: MessageType
    
    enum MessageType {
        case message
        case action
        case notice
        case join
        case part
        case quit
        case nick
        case topic
        case system
    }
    
    init(sender: String, content: String, type: MessageType = .message, timestamp: Date? = nil) {
        self.timestamp = timestamp ?? Date()
        self.sender = sender
        self.content = AttributedString(content)
        self.type = type
    }
    
    init(sender: String, content: AttributedString, type: MessageType = .message, timestamp: Date? = nil) {
        self.timestamp = timestamp ?? Date()
        self.sender = sender
        self.content = content
        self.type = type
    }
}
