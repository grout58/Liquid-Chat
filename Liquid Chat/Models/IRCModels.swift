//
//  IRCModels.swift
//  Liquid Chat
//
//  Data models for IRC chat
//

import Foundation
import SwiftUI

/// Represents an IRC server
@Observable
class IRCServer: Identifiable {
    let id = UUID()
    let config: IRCServerConfig
    var connection: IRCConnection?
    var channels: [IRCChannel] = []
    var isConnected: Bool = false
    
    init(config: IRCServerConfig) {
        self.config = config
    }
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
    
    init(sender: String, content: String, type: MessageType = .message) {
        self.id = UUID()
        self.timestamp = Date()
        self.sender = sender
        self.content = AttributedString(content)
        self.type = type
    }
    
    init(sender: String, content: AttributedString, type: MessageType = .message) {
        self.id = UUID()
        self.timestamp = Date()
        self.sender = sender
        self.content = content
        self.type = type
    }
}
