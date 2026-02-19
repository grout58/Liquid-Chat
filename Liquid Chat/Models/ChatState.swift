//
//  ChatState.swift
//  Liquid Chat
//
//  Main application state management
//

import Foundation
import SwiftUI

@Observable
class ChatState: IRCConnectionDelegate {
    var servers: [IRCServer] = []
    var selectedChannel: IRCChannel?
    var showingChannelJoinForServer: IRCServer?
    
    init() {
        // Initialize with empty state
    }
    
    // MARK: - Server Management
    
    func addServer(config: IRCServerConfig) {
        let server = IRCServer(config: config)
        servers.append(server)
    }
    
    func connectToServer(_ server: IRCServer) {
        let connection = IRCConnection(config: server.config)
        connection.delegate = self
        server.connection = connection
        connection.connect()
    }
    
    func disconnectFromServer(_ server: IRCServer) {
        server.connection?.disconnect()
        server.connection = nil
        server.isConnected = false
    }
    
    // MARK: - Channel Management
    
    func joinChannel(name: String, on server: IRCServer) {
        guard let connection = server.connection else { return }
        
        // Create channel if it doesn't exist
        if !server.channels.contains(where: { $0.name == name }) {
            let channel = IRCChannel(name: name, server: server)
            server.channels.append(channel)
        }
        
        connection.join(channel: name)
    }
    
    func partChannel(_ channel: IRCChannel) {
        guard let connection = channel.server.connection else { return }
        connection.part(channel: channel.name)
        channel.isJoined = false
    }
    
    func sendMessage(_ text: String, to channel: IRCChannel) {
        guard let connection = channel.server.connection else { return }
        connection.sendMessage(text, to: channel.name)
        
        // Add message to local history
        let message = IRCChatMessage(
            sender: connection.currentNickname,
            content: text,
            type: .message
        )
        channel.messages.append(message)
    }
    
    // MARK: - IRCConnectionDelegate
    
    func connectionDidConnect(_ connection: IRCConnection) {
        ConsoleLogger.shared.log("Connected to \(connection.config.hostname)", level: .info, category: "Connection")
    }
    
    func connectionDidRegister(_ connection: IRCConnection) {
        ConsoleLogger.shared.log("Registered on \(connection.config.hostname)", level: .info, category: "Connection")
        
        // Mark server as connected
        if let server = servers.first(where: { $0.connection === connection }) {
            server.isConnected = true
            
            // Show channel join dialog
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.showingChannelJoinForServer = server
            }
        }
    }
    
    func connectionDidDisconnect(_ connection: IRCConnection) {
        ConsoleLogger.shared.log("Disconnected from \(connection.config.hostname)", level: .warning, category: "Connection")
        
        if let server = servers.first(where: { $0.connection === connection }) {
            server.isConnected = false
        }
    }
    
    func connectionDidFail(_ connection: IRCConnection, error: Error) {
        ConsoleLogger.shared.log("Connection failed: \(error.localizedDescription)", level: .error, category: "Connection")
    }
    
    func connection(_ connection: IRCConnection, didReceiveMessage message: IRCMessage) {
        handleIRCMessage(message, from: connection)
    }
    
    func connection(_ connection: IRCConnection, didEncounterError error: Error) {
        ConsoleLogger.shared.log("Connection error: \(error.localizedDescription)", level: .error, category: "Connection")
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
            
        default:
            break
        }
    }
    
    private func handlePrivMsg(_ message: IRCMessage, server: IRCServer) {
        guard message.parameters.count >= 2,
              let sender = message.nick else { return }
        
        let target = message.parameters[0]
        let text = message.parameters[1]
        
        // Find or create channel
        if let channel = server.channels.first(where: { $0.name == target }) {
            let chatMessage = IRCChatMessage(sender: sender, content: text, type: .message)
            channel.messages.append(chatMessage)
        }
    }
    
    private func handleJoin(_ message: IRCMessage, server: IRCServer) {
        guard message.parameters.count >= 1,
              let nick = message.nick else { return }
        
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
            channel.messages.append(joinMessage)
            
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
            channel.messages.append(partMessage)
        }
    }
    
    private func handleQuit(_ message: IRCMessage, server: IRCServer) {
        guard let nick = message.nick else { return }
        
        let quitMessage = message.parameters.first ?? "Quit"
        
        // Remove user from all channels and add quit messages
        for channel in server.channels {
            if channel.users.contains(where: { $0.nickname == nick }) {
                channel.users.removeAll { $0.nickname == nick }
                
                let systemMessage = IRCChatMessage(
                    sender: "System",
                    content: "\(nick) has quit (\(quitMessage))",
                    type: .quit
                )
                channel.messages.append(systemMessage)
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
        guard message.parameters.count >= 4 else { return }
        
        let channelName = message.parameters[2]
        let names = message.parameters[3].split(separator: " ").map(String.init)
        
        if let channel = server.channels.first(where: { $0.name == channelName }) {
            for name in names {
                var nickname = name
                var modes: Set<Character> = []
                
                // Parse mode prefixes
                if let first = nickname.first, ["@", "+", "%", "&", "~"].contains(first) {
                    modes.insert(first)
                    nickname.removeFirst()
                }
                
                let user = IRCUser(nickname: nickname, modes: modes)
                if !channel.users.contains(where: { $0.nickname == nickname }) {
                    channel.users.append(user)
                }
            }
        }
    }
}
