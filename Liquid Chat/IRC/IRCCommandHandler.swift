//
//  IRCCommandHandler.swift
//  Liquid Chat
//
//  Handles IRC command parsing and execution
//

import Foundation
import SwiftUI

/// Handles IRC client commands (starting with /)
class IRCCommandHandler {
    weak var connection: IRCConnection?
    weak var chatState: ChatState?
    
    init(connection: IRCConnection?, chatState: ChatState?) {
        self.connection = connection
        self.chatState = chatState
    }
    
    /// Parse and execute an IRC command or send as message
    /// Returns true if it was a command, false if it should be sent as a message
    func handleInput(_ text: String, in channel: IRCChannel) -> Bool {
        guard text.hasPrefix("/") else {
            // Not a command, send as regular message
            return false
        }
        
        // Parse command and arguments
        let trimmed = String(text.dropFirst()) // Remove /
        let parts = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard let command = parts.first else { return true }
        
        let args = parts.count > 1 ? String(parts[1]) : ""
        
        // Execute command
        executeCommand(String(command).lowercased(), args: args, channel: channel)
        return true
    }
    
    private func executeCommand(_ command: String, args: String, channel: IRCChannel) {
        guard let connection = connection else { return }
        
        switch command {
        // Channel operations
        case "join", "j":
            let channelName = args.hasPrefix("#") ? args : "#\(args)"
            if !args.isEmpty {
                chatState?.joinChannel(name: channelName, on: channel.server)
            }
            
        case "part", "leave":
            let reason = args.isEmpty ? "Leaving" : args
            connection.part(channel: channel.name, message: reason)
            chatState?.partChannel(channel)
            
        case "topic":
            if args.isEmpty {
                // Request topic
                connection.send(command: "TOPIC", parameters: [channel.name])
            } else {
                // Set topic
                connection.send(command: "TOPIC", parameters: [channel.name, args])
            }
            
        // User information
        case "whois":
            let nickname = args.isEmpty ? connection.currentNickname : args
            connection.send(command: "WHOIS", parameters: [nickname])
            
        case "who":
            let target = args.isEmpty ? channel.name : args
            connection.send(command: "WHO", parameters: [target])
            
        case "whowas":
            guard !args.isEmpty else { return }
            connection.send(command: "WHOWAS", parameters: [args])
            
        // Messaging
        case "msg", "query":
            let msgParts = args.split(separator: " ", maxSplits: 1)
            guard msgParts.count == 2 else { return }
            let target = String(msgParts[0])
            let message = String(msgParts[1])
            connection.sendMessage(message, to: target)
            
        case "me":
            guard !args.isEmpty else { return }
            let actionMessage = "\u{01}ACTION \(args)\u{01}"
            connection.sendMessage(actionMessage, to: channel.name)
            
            // Add to local history
            let message = IRCChatMessage(
                sender: connection.currentNickname,
                content: args,
                type: .action
            )
            channel.appendMessage(message)
            
        case "notice":
            let noticeParts = args.split(separator: " ", maxSplits: 1)
            guard noticeParts.count == 2 else { return }
            let target = String(noticeParts[0])
            let message = String(noticeParts[1])
            connection.send(command: "NOTICE", parameters: [target, message])
            
        // Channel modes
        case "mode":
            let modeParts = args.split(separator: " ", maxSplits: 2)
            if modeParts.isEmpty {
                connection.send(command: "MODE", parameters: [channel.name])
            } else {
                let params = [channel.name] + modeParts.map(String.init)
                connection.send(command: "MODE", parameters: params)
            }
            
        case "op":
            guard !args.isEmpty else { return }
            connection.send(command: "MODE", parameters: [channel.name, "+o", args])
            
        case "deop":
            guard !args.isEmpty else { return }
            connection.send(command: "MODE", parameters: [channel.name, "-o", args])
            
        case "voice":
            guard !args.isEmpty else { return }
            connection.send(command: "MODE", parameters: [channel.name, "+v", args])
            
        case "devoice":
            guard !args.isEmpty else { return }
            connection.send(command: "MODE", parameters: [channel.name, "-v", args])
            
        case "kick":
            let kickParts = args.split(separator: " ", maxSplits: 1)
            guard !kickParts.isEmpty else { return }
            let nickname = String(kickParts[0])
            let reason = kickParts.count > 1 ? String(kickParts[1]) : "Kicked"
            connection.send(command: "KICK", parameters: [channel.name, nickname, reason])
            
        case "ban":
            guard !args.isEmpty else { return }
            connection.send(command: "MODE", parameters: [channel.name, "+b", args])
            
        case "unban":
            guard !args.isEmpty else { return }
            connection.send(command: "MODE", parameters: [channel.name, "-b", args])
            
        // Connection
        case "nick":
            guard !args.isEmpty else { return }
            connection.send(command: "NICK", parameters: [args])
            
        case "quit":
            let quitMessage = args.isEmpty ? "Leaving" : args
            connection.disconnect(message: quitMessage)
            
        case "away":
            if args.isEmpty {
                connection.send(command: "AWAY")
            } else {
                connection.send(command: "AWAY", parameters: [args])
            }
            
        // Server information
        case "list":
            connection.send(command: "LIST")
            // Don't show dialog yet - wait for LIST START response
            // (dialog will be shown in handleListStart to prevent freeze)
            
        case "names":
            connection.send(command: "NAMES", parameters: [channel.name])
            
        case "motd":
            connection.send(command: "MOTD")
            
        case "version":
            let target = args.isEmpty ? "" : args
            connection.send(command: "VERSION", parameters: target.isEmpty ? [] : [target])
            
        case "time":
            let target = args.isEmpty ? "" : args
            connection.send(command: "TIME", parameters: target.isEmpty ? [] : [target])
            
        case "admin":
            let target = args.isEmpty ? "" : args
            connection.send(command: "ADMIN", parameters: target.isEmpty ? [] : [target])
            
        // Help
        case "help", "?":
            showHelp(in: channel)
            
        // Clear messages (client-side only)
        case "clear":
            channel.messages.removeAll()
            
        // Secret Zelda 40th Anniversary Easter Egg 🗡️
        case "triforce", "zelda":
            showZeldaEasterEgg(in: channel)
            
        default:
            // Unknown command - add system message
            let systemMessage = IRCChatMessage(
                sender: "System",
                content: "Unknown command: /\(command). Type /help for available commands.",
                type: .system
            )
            channel.appendMessage(systemMessage)
        }
    }
    
    private func showHelp(in channel: IRCChannel) {
        let helpText = """
        Available Commands:
        
        Channel: /join #channel, /part [reason], /topic [new topic]
        Users: /whois nick, /who [target], /nick newnick
        Messages: /msg nick message, /me action, /notice nick message
        Modes: /op nick, /deop nick, /voice nick, /kick nick [reason]
        Server: /list, /names, /motd, /away [message], /quit [message]
        Client: /clear (clear messages), /help (this message)
        
        💎 Hint: Try seeking the golden power... (/triforce)
        """
        
        let message = IRCChatMessage(
            sender: "System",
            content: helpText,
            type: .system
        )
        channel.appendMessage(message)
    }
    
    private func showZeldaEasterEgg(in channel: IRCChannel) {
        // Create the PROPER Triforce using triangle symbols
        let triforceArt = """
                           ▲
                          ▲ ▲
                         ▲   ▲
                        ▲ ▲ ▲ ▲
                       ▲       ▲
                      ▲ ▲     ▲ ▲
                     ▲   ▲   ▲   ▲
                    ▲ ▲ ▲ ▲ ▲ ▲ ▲ ▲
        """
        
        var zeldaContent = AttributedString("""
        
        ⚔️  THE LEGEND OF ZELDA - 40TH ANNIVERSARY (1986-2026) ⚔️
        
        \(triforceArt)
        
                  ✨ THE TRIFORCE ✨
        
        "It's dangerous to go alone! Take this."
        
        🗡️ Master Sword obtained!
        💚 You found a Heart Container!
        🎵 *Zelda Theme plays*
        
        Fun Facts:
        • The first Zelda game was released on February 21, 1986
        • Link has saved Hyrule across 20+ games
        • "The Legend of Zelda" was one of the first games to have a save feature
        • Shigeru Miyamoto named Zelda after Zelda Fitzgerald
        
        Easter Egg: You've discovered the secret of Liquid Chat!
        Type /help to see other commands, or continue your adventure in IRC! 🏹
        
        """)
        
        // Apply gold color and monospace to the triforce
        if let triforceRange = zeldaContent.range(of: triforceArt) {
            zeldaContent[triforceRange].foregroundColor = Color(red: 1.0, green: 0.84, blue: 0.0) // Gold color
            zeldaContent[triforceRange].font = .monospaced(.system(.body))()
        }
        
        let message = IRCChatMessage(
            sender: "🧙 Old Man",
            content: zeldaContent,
            type: .system
        )
        channel.appendMessage(message)
        
        // Add a follow-up message with a fun surprise
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let followUp = IRCChatMessage(
                sender: "🧚 Navi",
                content: "Hey! Listen! You can enable the Hyrule theme in Settings → Appearance for a full Zelda experience! 🌲✨",
                type: .system
            )
            channel.appendMessage(followUp)
        }
    }
}
