//
//  MockIRCConnection.swift
//  Liquid ChatTests
//
//  Mock IRC connection for testing protocol logic without network I/O
//

import Foundation
@testable import Liquid_Chat

/// Mock IRC connection that simulates server responses without actual network I/O
class MockIRCConnection: IRCConnection {
    // Captured state for verification
    var sentCommands: [(command: String, parameters: [String])] = []
    var sentRawMessages: [String] = []
    var connectionAttempts: Int = 0
    var disconnectCalled: Bool = false
    
    // Simulated server responses to inject
    var serverResponsesToSend: [String] = []
    
    // Override state for testing
    var mockState: IRCConnectionState = .disconnected
    
    override var state: IRCConnectionState {
        get { mockState }
        set { mockState = newValue }
    }
    
    /// Initialize mock connection with a test configuration
    init(testConfig: IRCServerConfig? = nil) {
        let config = testConfig ?? IRCServerConfig(
            hostname: "mock.test.server",
            port: 6667,
            useSSL: false,
            nickname: "TestUser",
            username: "testuser",
            realname: "Test User"
        )
        super.init(config: config)
    }
    
    // MARK: - Override Connection Methods
    
    override func connect() {
        connectionAttempts += 1
        mockState = .connecting
        
        // Simulate successful connection after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.mockState = .connected
            self.delegate?.connectionDidConnect(self)
            
            // Simulate handshake completion
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.mockState = .registered
                self.delegate?.connectionDidRegister(self)
            }
        }
    }
    
    override func disconnect(message: String = "Leaving") {
        disconnectCalled = true
        mockState = .disconnected
        delegate?.connectionDidDisconnect(self)
    }
    
    override func send(command: String, parameters: [String] = []) {
        sentCommands.append((command, parameters))
    }
    
    override func send(raw message: String) {
        sentRawMessages.append(message)
    }
    
    // MARK: - Test Helper Methods
    
    /// Simulate receiving a message from the server
    func simulateServerMessage(_ rawMessage: String) {
        guard let parsed = IRCMessage.parse(rawMessage) else {
            return
        }
        delegate?.connection(self, didReceiveMessage: parsed)
    }
    
    /// Simulate multiple server messages in sequence
    func simulateServerMessages(_ messages: [String]) {
        for message in messages {
            simulateServerMessage(message)
        }
    }
    
    /// Simulate a connection failure
    func simulateConnectionFailure(_ error: Error) {
        mockState = .error(error.localizedDescription)
        delegate?.connectionDidFail(self, error: error)
    }
    
    /// Simulate a complete IRC handshake sequence
    func simulateSuccessfulHandshake() {
        let handshakeMessages = [
            ":irc.test.server 001 TestUser :Welcome to the Test IRC Network",
            ":irc.test.server 002 TestUser :Your host is irc.test.server",
            ":irc.test.server 003 TestUser :This server was created today",
            ":irc.test.server 004 TestUser irc.test.server v1.0 DOQRSZaghilopsuwz CFILMPQSbcefgijklmnopqrstvz bkloveqjfI"
        ]
        simulateServerMessages(handshakeMessages)
    }
    
    /// Simulate a channel join sequence
    func simulateChannelJoin(channel: String, nickname: String) {
        let joinMessages = [
            ":\(nickname)!user@host.test JOIN :\(channel)",
            ":irc.test.server 332 \(nickname) \(channel) :Channel topic here",
            ":irc.test.server 353 \(nickname) = \(channel) :@alice +bob charlie",
            ":irc.test.server 366 \(nickname) \(channel) :End of /NAMES list"
        ]
        simulateServerMessages(joinMessages)
    }
    
    /// Simulate receiving a private message
    func simulatePrivateMessage(from sender: String, to target: String, message: String) {
        let privmsg = ":\(sender)!user@host.test PRIVMSG \(target) :\(message)"
        simulateServerMessage(privmsg)
    }
    
    /// Simulate a PING/PONG exchange
    func simulatePing(server: String = "irc.test.server") {
        simulateServerMessage("PING :\(server)")
    }
    
    /// Reset all captured state for a new test
    func reset() {
        sentCommands.removeAll()
        sentRawMessages.removeAll()
        connectionAttempts = 0
        disconnectCalled = false
        serverResponsesToSend.removeAll()
        mockState = .disconnected
    }
    
    /// Verify that a specific command was sent
    func didSendCommand(_ command: String, withParameters params: [String]? = nil) -> Bool {
        if let params = params {
            return sentCommands.contains { $0.command == command && $0.parameters == params }
        } else {
            return sentCommands.contains { $0.command == command }
        }
    }
    
    /// Get all sent commands of a specific type
    func getSentCommands(_ command: String) -> [(command: String, parameters: [String])] {
        return sentCommands.filter { $0.command == command }
    }
}

/// Mock test error for simulating connection failures
struct MockConnectionError: Error, LocalizedError {
    let message: String
    
    var errorDescription: String? {
        message
    }
}
