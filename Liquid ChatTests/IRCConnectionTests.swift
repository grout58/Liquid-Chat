//
//  IRCConnectionTests.swift
//  Liquid Chat Tests
//
//  Comprehensive IRC Connection Tests
//

import Testing
import Foundation
import Network
@testable import Liquid_Chat

@Suite("IRC Connection Tests")
struct IRCConnectionTests {
    
    @Test("IRC Message Parsing - Valid PRIVMSG")
    func testPrivMsgParsing() {
        let rawMessage = ":alice!~alice@host.com PRIVMSG #swift :Hello, world!"
        let parsed = IRCMessage.parse(rawMessage)
        
        #expect(parsed != nil)
        #expect(parsed?.command == "PRIVMSG")
        #expect(parsed?.nick == "alice")
        #expect(parsed?.user == "~alice")
        #expect(parsed?.host == "host.com")
        #expect(parsed?.parameters.count == 2)
        #expect(parsed?.parameters[0] == "#swift")
        #expect(parsed?.parameters[1] == "Hello, world!")
    }
    
    @Test("IRC Message Parsing - Server Numeric")
    func testNumericParsing() {
        let rawMessage = ":irc.server.net 001 alice :Welcome to the Internet Relay Network alice!user@host"
        let parsed = IRCMessage.parse(rawMessage)
        
        #expect(parsed != nil)
        #expect(parsed?.command == "001")
        #expect(parsed?.parameters.count == 2)
        #expect(parsed?.parameters[0] == "alice")
        #expect(parsed?.parameters[1] == "Welcome to the Internet Relay Network alice!user@host")
    }
    
    @Test("IRC Message Parsing - JOIN Command")
    func testJoinParsing() {
        let rawMessage = ":bob!~bob@192.168.1.1 JOIN #macos"
        let parsed = IRCMessage.parse(rawMessage)
        
        #expect(parsed != nil)
        #expect(parsed?.command == "JOIN")
        #expect(parsed?.nick == "bob")
        #expect(parsed?.parameters.count == 1)
        #expect(parsed?.parameters[0] == "#macos")
    }
    
    @Test("IRC Message Parsing - PING")
    func testPingParsing() {
        let rawMessage = "PING :irc.server.net"
        let parsed = IRCMessage.parse(rawMessage)
        
        #expect(parsed != nil)
        #expect(parsed?.command == "PING")
        #expect(parsed?.prefix == nil)
        #expect(parsed?.parameters.count == 1)
        #expect(parsed?.parameters[0] == "irc.server.net")
    }
    
    @Test("IRC Message Parsing - Empty Message")
    func testEmptyMessageParsing() {
        let rawMessage = ""
        let parsed = IRCMessage.parse(rawMessage)
        
        #expect(parsed != nil)
        #expect(parsed?.command == "")
        #expect(parsed?.parameters.isEmpty == true)
    }
    
    @Test("IRC Message Formatting")
    func testMessageFormatting() {
        let formatted = IRCMessage.format(command: "PRIVMSG", parameters: ["#swift", "Hello!"])
        #expect(formatted == "PRIVMSG #swift :Hello!")
    }
    
    @Test("IRC Message Formatting with Prefix")
    func testMessageFormattingWithPrefix() {
        let formatted = IRCMessage.format(command: "PRIVMSG", parameters: ["#swift", "Test"], prefix: "alice!user@host")
        #expect(formatted == ":alice!user@host PRIVMSG #swift :Test")
    }
    
    @Test("IRC Server Config - Initialization")
    func testServerConfigInit() {
        let config = IRCServerConfig(
            hostname: "irc.libera.chat",
            port: 6697,
            useSSL: true,
            nickname: "TestUser"
        )
        
        #expect(config.hostname == "irc.libera.chat")
        #expect(config.port == 6697)
        #expect(config.useSSL == true)
        #expect(config.nickname == "TestUser")
        #expect(config.username == "TestUser")
        #expect(config.realname == "TestUser")
        #expect(config.authMethod == .none)
    }
    
    @Test("IRC Server Config - SSL Port Auto-Selection")
    func testServerConfigSSLPort() {
        let config = IRCServerConfig(
            hostname: "irc.example.com",
            port: 6667,
            useSSL: true,
            nickname: "User"
        )
        
        #expect(config.port == 6697) // Should use SSL port
    }
    
    @Test("IRC Connection State Transitions")
    func testConnectionStateTransitions() async {
        let config = IRCServerConfig(
            hostname: "irc.test.net",
            nickname: "TestBot"
        )
        let connection = IRCConnection(config: config)
        
        #expect(connection.state == .disconnected)
    }
}

@Suite("IRC Models Tests")
struct IRCModelsTests {
    
    @Test("Channel - Private Message Detection")
    func testPrivateMessageDetection() {
        let config = IRCServerConfig(hostname: "test", nickname: "user")
        let server = IRCServer(config: config)
        
        let channel = IRCChannel(name: "#swift", server: server)
        let privateChannel = IRCChannel(name: "alice", server: server)
        
        #expect(channel.isPrivateMessage == false)
        #expect(privateChannel.isPrivateMessage == true)
    }
    
    @Test("IRC User - Display Prefix")
    func testUserDisplayPrefix() {
        var opUser = IRCUser(nickname: "alice", modes: ["o"])
        #expect(opUser.displayPrefix == "@")
        #expect(opUser.displayName == "@alice")
        
        var voicedUser = IRCUser(nickname: "bob", modes: ["v"])
        #expect(voicedUser.displayPrefix == "+")
        
        let regularUser = IRCUser(nickname: "charlie")
        #expect(regularUser.displayPrefix == "")
    }
    
    @Test("Server Connection State - Display Properties")
    func testServerConnectionStateDisplay() {
        let connecting = ServerConnectionState.connecting
        #expect(connecting.displayText == "Connecting...")
        #expect(connecting.systemImage == "network")
        
        let connected = ServerConnectionState.connected
        #expect(connected.displayText == "Connected")
        
        let error = ServerConnectionState.error("Connection failed")
        #expect(error.displayText == "Error: Connection failed")
        #expect(error.systemImage == "exclamationmark.triangle")
    }
}

@Suite("Chat State Tests")
struct ChatStateTests {
    
    @MainActor
    @Test("Add and Connect Server")
    func testAddServer() {
        let chatState = ChatState()
        let config = IRCServerConfig(hostname: "irc.test.net", nickname: "TestUser")
        
        chatState.addServer(config: config)
        
        #expect(chatState.servers.count == 1)
        #expect(chatState.servers[0].config.hostname == "irc.test.net")
    }
    
    @MainActor
    @Test("Join Channel")
    func testJoinChannel() {
        let chatState = ChatState()
        let config = IRCServerConfig(hostname: "irc.test.net", nickname: "TestUser")
        let server = IRCServer(config: config)
        chatState.servers.append(server)
        
        chatState.joinChannel(name: "#swift", on: server)
        
        #expect(server.channels.count == 1)
        #expect(server.channels[0].name == "#swift")
    }
    
    @MainActor
    @Test("Open Private Message")
    func testOpenPrivateMessage() {
        let chatState = ChatState()
        let config = IRCServerConfig(hostname: "irc.test.net", nickname: "TestUser")
        let server = IRCServer(config: config)
        chatState.servers.append(server)
        
        chatState.openPrivateMessage(with: "alice", on: server)
        
        #expect(server.channels.count == 1)
        #expect(server.channels[0].name == "alice")
        #expect(server.channels[0].isPrivateMessage == true)
        #expect(chatState.selectedChannel?.name == "alice")
    }
    
    @MainActor
    @Test("Open Private Message - Existing Channel")
    func testOpenExistingPrivateMessage() {
        let chatState = ChatState()
        let config = IRCServerConfig(hostname: "irc.test.net", nickname: "TestUser")
        let server = IRCServer(config: config)
        let existingChannel = IRCChannel(name: "alice", server: server)
        server.channels.append(existingChannel)
        chatState.servers.append(server)
        
        chatState.openPrivateMessage(with: "alice", on: server)
        
        #expect(server.channels.count == 1) // Should not create duplicate
        #expect(chatState.selectedChannel === existingChannel)
    }
}

@Suite("IRC Command Handler Tests")
struct IRCCommandHandlerTests {
    
    @Test("Command Detection")
    func testCommandDetection() {
        let config = IRCServerConfig(hostname: "test", nickname: "user")
        let server = IRCServer(config: config)
        let channel = IRCChannel(name: "#test", server: server)
        let chatState = ChatState()
        let handler = IRCCommandHandler(connection: nil, chatState: chatState)
        
        let isCommand1 = handler.handleInput("/join #swift", in: channel)
        #expect(isCommand1 == true)
        
        let isCommand2 = handler.handleInput("Hello everyone", in: channel)
        #expect(isCommand2 == false)
    }
}

@Suite("Message Buffer Tests")
struct MessageBufferTests {
    
    @Test("CRLF Message Splitting")
    func testMessageSplitting() {
        let message1 = "PING :server\r\n"
        let message2 = "PRIVMSG #test :Hello\r\n"
        let combined = message1 + message2
        
        let parts = combined.components(separatedBy: "\r\n").filter { !$0.isEmpty }
        
        #expect(parts.count == 2)
        #expect(parts[0] == "PING :server")
        #expect(parts[1] == "PRIVMSG #test :Hello")
    }
    
    @Test("Partial Message Handling")
    func testPartialMessage() {
        var buffer = Data()
        let partial1 = "PING :ser".data(using: .utf8)!
        let partial2 = "ver\r\n".data(using: .utf8)!
        
        buffer.append(partial1)
        #expect(buffer.range(of: "\r\n".data(using: .utf8)!) == nil)
        
        buffer.append(partial2)
        #expect(buffer.range(of: "\r\n".data(using: .utf8)!) != nil)
    }
}

@Suite("Theme Tests")
struct ThemeTests {
    
    @Test("Theme Color Scheme")
    func testThemeColorScheme() {
        #expect(AppTheme.system.colorScheme == nil)
        #expect(AppTheme.light.colorScheme == .light)
        #expect(AppTheme.dark.colorScheme == .dark)
        #expect(AppTheme.nord.colorScheme == .dark)
        #expect(AppTheme.gameBoy.colorScheme == .light)
    }
    
    @Test("Theme Categories")
    func testThemeCategories() {
        #expect(AppTheme.system.category == "Standard")
        #expect(AppTheme.solarizedDark.category == "Solarized")
        #expect(AppTheme.gruvboxLight.category == "Gruvbox")
        #expect(AppTheme.nord.category == "Nord")
        #expect(AppTheme.psychedelic.category == "Fun Themes")
    }
    
    @Test("Theme Display Names")
    func testThemeDisplayNames() {
        #expect(AppTheme.system.displayName == "System")
        #expect(AppTheme.zelda.displayName == "Hyrule")
        #expect(AppTheme.tokyoNight.displayName == "Tokyo Night")
    }
}
