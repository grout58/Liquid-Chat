//
//  IRCConnectionIntegrationTests.swift
//  Liquid ChatTests
//
//  Integration tests for IRC connection with mocked network
//

import Testing
import Foundation
@testable import Liquid_Chat

/// Integration tests for IRC connection flows using mock network
@Suite("IRC Connection Integration Tests")
struct IRCConnectionIntegrationTests {
    
    // MARK: - Connection Flow Tests
    
    @Test("Connection lifecycle - connect and disconnect")
    func testConnectionLifecycle() async {
        let mock = MockIRCConnection()
        
        // Initial state
        #expect(mock.state == .disconnected)
        #expect(mock.connectionAttempts == 0)
        
        // Connect
        mock.connect()
        #expect(mock.connectionAttempts == 1)
        #expect(mock.state == .connecting)
        
        // Wait for simulated connection
        try? await Task.sleep(for: .milliseconds(250))
        #expect(mock.state == .registered)
        
        // Disconnect
        mock.disconnect()
        #expect(mock.disconnectCalled == true)
        #expect(mock.state == .disconnected)
    }
    
    @Test("Multiple connection attempts tracked")
    func testMultipleConnectionAttempts() async {
        let mock = MockIRCConnection()
        
        mock.connect()
        mock.connect()
        mock.connect()
        
        #expect(mock.connectionAttempts == 3)
    }
    
    @Test("Connection failure simulation")
    func testConnectionFailure() async {
        let mock = MockIRCConnection()
        let error = MockConnectionError(message: "Connection refused")
        
        mock.simulateConnectionFailure(error)
        
        #expect(mock.state == .error("Connection refused"))
    }
    
    // MARK: - Command Sending Tests
    
    @Test("Send basic IRC commands")
    func testSendBasicCommands() {
        let mock = MockIRCConnection()
        
        mock.send(command: "NICK", parameters: ["TestUser"])
        mock.send(command: "USER", parameters: ["test", "0", "*", "Test User"])
        mock.send(command: "JOIN", parameters: ["#swift"])
        
        #expect(mock.sentCommands.count == 3)
        #expect(mock.sentCommands[0].command == "NICK")
        #expect(mock.sentCommands[0].parameters == ["TestUser"])
        #expect(mock.sentCommands[1].command == "USER")
        #expect(mock.sentCommands[2].command == "JOIN")
        #expect(mock.sentCommands[2].parameters == ["#swift"])
    }
    
    @Test("Send PRIVMSG command")
    func testSendPrivmsg() {
        let mock = MockIRCConnection()
        
        mock.send(command: "PRIVMSG", parameters: ["#channel", "Hello, World!"])
        
        #expect(mock.didSendCommand("PRIVMSG"))
        #expect(mock.didSendCommand("PRIVMSG", withParameters: ["#channel", "Hello, World!"]))
        #expect(!mock.didSendCommand("PRIVMSG", withParameters: ["#other", "Test"]))
    }
    
    @Test("Send raw IRC message")
    func testSendRawMessage() {
        let mock = MockIRCConnection()
        
        mock.send(raw: "PING :irc.server.com")
        mock.send(raw: "PONG :irc.server.com")
        
        #expect(mock.sentRawMessages.count == 2)
        #expect(mock.sentRawMessages[0] == "PING :irc.server.com")
        #expect(mock.sentRawMessages[1] == "PONG :irc.server.com")
    }
    
    @Test("Get sent commands of specific type")
    func testGetSentCommands() {
        let mock = MockIRCConnection()
        
        mock.send(command: "PRIVMSG", parameters: ["#channel1", "Message 1"])
        mock.send(command: "JOIN", parameters: ["#test"])
        mock.send(command: "PRIVMSG", parameters: ["#channel2", "Message 2"])
        mock.send(command: "PRIVMSG", parameters: ["user", "Private message"])
        
        let privmsgs = mock.getSentCommands("PRIVMSG")
        #expect(privmsgs.count == 3)
        
        let joins = mock.getSentCommands("JOIN")
        #expect(joins.count == 1)
        #expect(joins[0].parameters == ["#test"])
    }
    
    // MARK: - Message Reception Tests
    
    @Test("Receive and parse PRIVMSG")
    func testReceivePrivmsg() async {
        let mock = MockIRCConnection()
        var receivedMessage: IRCMessage?
        
        // Set up delegate to capture message
        let delegate = MockConnectionDelegate { message in
            receivedMessage = message
        }
        mock.delegate = delegate
        
        // Simulate server sending a PRIVMSG
        mock.simulateServerMessage(":alice!user@host PRIVMSG #channel :Hello!")
        
        #expect(receivedMessage != nil)
        #expect(receivedMessage?.command == "PRIVMSG")
        #expect(receivedMessage?.nick == "alice")
        #expect(receivedMessage?.parameters == ["#channel", "Hello!"])
    }
    
    @Test("Receive multiple messages")
    func testReceiveMultipleMessages() async {
        let mock = MockIRCConnection()
        var messages: [IRCMessage] = []
        
        let delegate = MockConnectionDelegate { message in
            messages.append(message)
        }
        mock.delegate = delegate
        
        let serverMessages = [
            ":alice!a@host PRIVMSG #channel :Message 1",
            ":bob!b@host PRIVMSG #channel :Message 2",
            ":charlie!c@host JOIN #channel"
        ]
        
        mock.simulateServerMessages(serverMessages)
        
        #expect(messages.count == 3)
        #expect(messages[0].command == "PRIVMSG")
        #expect(messages[1].command == "PRIVMSG")
        #expect(messages[2].command == "JOIN")
    }
    
    @Test("Receive malformed message is ignored")
    func testReceiveMalformedMessage() async {
        let mock = MockIRCConnection()
        var receivedMessage: IRCMessage?
        
        let delegate = MockConnectionDelegate { message in
            receivedMessage = message
        }
        mock.delegate = delegate
        
        // Malformed message should not parse
        mock.simulateServerMessage("@invalidtagPRIVMSG")
        
        #expect(receivedMessage == nil)
    }
    
    // MARK: - Handshake Tests
    
    @Test("Successful IRC handshake")
    func testSuccessfulHandshake() async {
        let mock = MockIRCConnection()
        var messages: [IRCMessage] = []
        
        let delegate = MockConnectionDelegate { message in
            messages.append(message)
        }
        mock.delegate = delegate
        
        mock.simulateSuccessfulHandshake()
        
        // Should receive welcome messages (001-004)
        #expect(messages.count == 4)
        #expect(messages[0].command == "001")
        #expect(messages[1].command == "002")
        #expect(messages[2].command == "003")
        #expect(messages[3].command == "004")
        
        // Welcome message should contain nickname
        #expect(messages[0].parameters.contains("TestUser"))
    }
    
    // MARK: - Channel Operations Tests
    
    @Test("Channel join sequence")
    func testChannelJoinSequence() async {
        let mock = MockIRCConnection()
        var messages: [IRCMessage] = []
        
        let delegate = MockConnectionDelegate { message in
            messages.append(message)
        }
        mock.delegate = delegate
        
        mock.simulateChannelJoin(channel: "#swift", nickname: "TestUser")
        
        // Should receive JOIN, TOPIC (332), NAMES (353), and end of NAMES (366)
        #expect(messages.count == 4)
        #expect(messages[0].command == "JOIN")
        #expect(messages[0].parameters == ["#swift"])
        #expect(messages[1].command == "332") // Topic
        #expect(messages[2].command == "353") // Names list
        #expect(messages[3].command == "366") // End of names
    }
    
    @Test("Join multiple channels")
    func testJoinMultipleChannels() async {
        let mock = MockIRCConnection()
        
        mock.send(command: "JOIN", parameters: ["#swift"])
        mock.send(command: "JOIN", parameters: ["#macos"])
        mock.send(command: "JOIN", parameters: ["#testing"])
        
        let joins = mock.getSentCommands("JOIN")
        #expect(joins.count == 3)
        #expect(joins[0].parameters == ["#swift"])
        #expect(joins[1].parameters == ["#macos"])
        #expect(joins[2].parameters == ["#testing"])
    }
    
    @Test("Part from channel")
    func testPartChannel() async {
        let mock = MockIRCConnection()
        
        mock.send(command: "PART", parameters: ["#channel", "Goodbye!"])
        
        #expect(mock.didSendCommand("PART"))
        #expect(mock.sentCommands[0].parameters == ["#channel", "Goodbye!"])
    }
    
    // MARK: - Private Message Tests
    
    @Test("Send and receive private messages")
    func testPrivateMessages() async {
        let mock = MockIRCConnection()
        var receivedMessage: IRCMessage?
        
        let delegate = MockConnectionDelegate { message in
            receivedMessage = message
        }
        mock.delegate = delegate
        
        // Send a private message
        mock.send(command: "PRIVMSG", parameters: ["alice", "Hello Alice!"])
        #expect(mock.didSendCommand("PRIVMSG", withParameters: ["alice", "Hello Alice!"]))
        
        // Receive a private message
        mock.simulatePrivateMessage(from: "alice", to: "TestUser", message: "Hi there!")
        
        #expect(receivedMessage != nil)
        #expect(receivedMessage?.command == "PRIVMSG")
        #expect(receivedMessage?.nick == "alice")
        #expect(receivedMessage?.parameters == ["TestUser", "Hi there!"])
    }
    
    // MARK: - PING/PONG Tests
    
    @Test("PING/PONG exchange")
    func testPingPong() async {
        let mock = MockIRCConnection()
        var receivedMessage: IRCMessage?
        
        let delegate = MockConnectionDelegate { message in
            receivedMessage = message
        }
        mock.delegate = delegate
        
        // Receive PING from server
        mock.simulatePing(server: "irc.example.com")
        
        #expect(receivedMessage != nil)
        #expect(receivedMessage?.command == "PING")
        #expect(receivedMessage?.parameters == ["irc.example.com"])
        
        // Should respond with PONG
        mock.send(command: "PONG", parameters: ["irc.example.com"])
        #expect(mock.didSendCommand("PONG"))
    }
    
    // MARK: - Reset and State Management Tests
    
    @Test("Reset clears all state")
    func testReset() {
        let mock = MockIRCConnection()
        
        // Generate some state
        mock.connect()
        mock.send(command: "NICK", parameters: ["TestUser"])
        mock.send(command: "USER", parameters: ["test", "0", "*", "Test"])
        mock.send(raw: "PING :test")
        mock.simulateConnectionFailure(MockConnectionError(message: "Test error"))
        
        #expect(mock.connectionAttempts > 0)
        #expect(mock.sentCommands.count > 0)
        #expect(mock.sentRawMessages.count > 0)
        #expect(mock.state != .disconnected)
        
        // Reset
        mock.reset()
        
        // All state should be cleared
        #expect(mock.connectionAttempts == 0)
        #expect(mock.sentCommands.isEmpty)
        #expect(mock.sentRawMessages.isEmpty)
        #expect(!mock.disconnectCalled)
        #expect(mock.serverResponsesToSend.isEmpty)
        #expect(mock.state == .disconnected)
    }
    
    // MARK: - Configuration Tests
    
    @Test("Custom configuration initialization")
    func testCustomConfiguration() {
        let config = IRCServerConfig(
            hostname: "irc.custom.net",
            port: 6697,
            useSSL: true,
            nickname: "CustomUser",
            username: "custom",
            realname: "Custom Real Name",
            authMethod: .sasl
        )
        
        let mock = MockIRCConnection(testConfig: config)
        
        #expect(mock.config.hostname == "irc.custom.net")
        #expect(mock.config.port == 6697)
        #expect(mock.config.useSSL == true)
        #expect(mock.config.nickname == "CustomUser")
        #expect(mock.config.username == "custom")
        #expect(mock.config.realname == "Custom Real Name")
        #expect(mock.config.authMethod == .sasl)
    }
    
    @Test("Default configuration initialization")
    func testDefaultConfiguration() {
        let mock = MockIRCConnection()
        
        #expect(mock.config.hostname == "mock.test.server")
        #expect(mock.config.nickname == "TestUser")
        #expect(mock.config.username == "testuser")
        #expect(mock.config.realname == "Test User")
    }
    
    // MARK: - Concurrent Operations Tests
    
    @Test("Concurrent message sending")
    func testConcurrentMessageSending() async {
        let mock = MockIRCConnection()
        
        // Send messages concurrently
        await withTaskGroup(of: Void.self) { group in
            for i in 1...10 {
                group.addTask {
                    mock.send(command: "PRIVMSG", parameters: ["#test", "Message \(i)"])
                }
            }
        }
        
        // All messages should be captured
        #expect(mock.sentCommands.count == 10)
        
        let privmsgs = mock.getSentCommands("PRIVMSG")
        #expect(privmsgs.count == 10)
    }
    
    // MARK: - Complex Workflow Tests
    
    @Test("Complete IRC session workflow")
    func testCompleteIRCWorkflow() async {
        let mock = MockIRCConnection()
        var receivedMessages: [IRCMessage] = []
        
        let delegate = MockConnectionDelegate { message in
            receivedMessages.append(message)
        }
        mock.delegate = delegate
        
        // 1. Connect
        mock.connect()
        try? await Task.sleep(for: .milliseconds(250))
        #expect(mock.state == .registered)
        
        // 2. Receive handshake
        mock.simulateSuccessfulHandshake()
        #expect(receivedMessages.count == 4) // Welcome messages
        
        // 3. Join channel
        mock.send(command: "JOIN", parameters: ["#swift"])
        mock.simulateChannelJoin(channel: "#swift", nickname: "TestUser")
        #expect(mock.didSendCommand("JOIN", withParameters: ["#swift"]))
        
        // 4. Send a message
        mock.send(command: "PRIVMSG", parameters: ["#swift", "Hello everyone!"])
        #expect(mock.didSendCommand("PRIVMSG"))
        
        // 5. Receive messages from others
        mock.simulatePrivateMessage(from: "alice", to: "#swift", message: "Welcome!")
        mock.simulatePrivateMessage(from: "bob", to: "#swift", message: "Hi there!")
        
        // 6. Respond to PING
        mock.simulatePing()
        mock.send(command: "PONG", parameters: ["irc.test.server"])
        #expect(mock.didSendCommand("PONG"))
        
        // 7. Part channel
        mock.send(command: "PART", parameters: ["#swift", "Goodbye!"])
        #expect(mock.didSendCommand("PART"))
        
        // 8. Disconnect
        mock.disconnect()
        #expect(mock.state == .disconnected)
        
        // Verify all operations were tracked
        #expect(mock.sentCommands.count >= 4) // JOIN, PRIVMSG, PONG, PART
        #expect(receivedMessages.count >= 8) // Handshake + join sequence + messages + PING
    }
}

// MARK: - Mock Delegate

/// Mock IRC connection delegate for testing
class MockConnectionDelegate: IRCConnectionDelegate {
    private let onMessage: (IRCMessage) -> Void
    var didConnect = false
    var didRegister = false
    var didDisconnect = false
    var lastError: Error?
    
    init(onMessage: @escaping (IRCMessage) -> Void = { _ in }) {
        self.onMessage = onMessage
    }
    
    func connection(_ connection: IRCConnection, didReceiveMessage message: IRCMessage) {
        onMessage(message)
    }
    
    func connectionDidConnect(_ connection: IRCConnection) {
        didConnect = true
    }
    
    func connectionDidRegister(_ connection: IRCConnection) {
        didRegister = true
    }
    
    func connectionDidDisconnect(_ connection: IRCConnection) {
        didDisconnect = true
    }
    
    func connectionDidFail(_ connection: IRCConnection, error: Error) {
        lastError = error
    }
    
    func connection(_ connection: IRCConnection, didEncounterError error: Error) {
        lastError = error
    }
}
