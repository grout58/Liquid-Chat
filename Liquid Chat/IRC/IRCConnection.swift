//
//  IRCConnection.swift
//  Liquid Chat
//
//  Swift-native IRC protocol implementation using Network.framework
//

import Foundation
import Network

/// Represents the connection state of an IRC server
enum IRCConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case authenticating
    case registered
    case error(String)
}

/// IRC authentication methods
enum IRCAuthMethod {
    case none
    case password
    case sasl
    case nickserv
}

/// IRC connection configuration
struct IRCServerConfig {
    let hostname: String
    let port: UInt16
    let useSSL: Bool
    let nickname: String
    let username: String
    let realname: String
    let password: String?
    let authMethod: IRCAuthMethod
    
    init(
        hostname: String,
        port: UInt16 = 6667,
        useSSL: Bool = false,
        nickname: String,
        username: String? = nil,
        realname: String? = nil,
        password: String? = nil,
        authMethod: IRCAuthMethod = .none
    ) {
        self.hostname = hostname
        self.port = useSSL ? 6697 : port
        self.useSSL = useSSL
        self.nickname = nickname
        self.username = username ?? nickname
        self.realname = realname ?? nickname
        self.password = password
        self.authMethod = authMethod
    }
}

/// Main IRC connection class using Network.framework
@Observable
class IRCConnection {
    private(set) var state: IRCConnectionState = .disconnected
    private(set) var config: IRCServerConfig
    
    private var connection: NWConnection?
    private var receiveQueue: DispatchQueue
    private var sendQueue: DispatchQueue
    
    // Capability negotiation state
    private var capabilitiesRequested: Set<String> = []
    private var capabilitiesAcknowledged: Set<String> = []
    private var sentCapEnd = false
    
    // Connection metadata
    private(set) var serverName: String?
    private(set) var currentNickname: String
    
    // Delegate for handling IRC messages
    weak var delegate: IRCConnectionDelegate?
    
    init(config: IRCServerConfig) {
        self.config = config
        self.currentNickname = config.nickname
        self.receiveQueue = DispatchQueue(label: "com.liquidchat.irc.receive", qos: .userInitiated)
        self.sendQueue = DispatchQueue(label: "com.liquidchat.irc.send", qos: .userInitiated)
    }
    
    // MARK: - Connection Management
    
    /// Connect to the IRC server
    func connect() {
        guard state == .disconnected else { return }
        
        state = .connecting
        
        // Configure NWConnection parameters
        let parameters: NWParameters
        if config.useSSL {
            parameters = .tls
        } else {
            parameters = .tcp
        }
        
        // Create connection
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(config.hostname),
            port: NWEndpoint.Port(rawValue: config.port)!
        )
        
        connection = NWConnection(to: endpoint, using: parameters)
        setupConnectionHandlers()
        
        connection?.start(queue: receiveQueue)
    }
    
    /// Disconnect from the IRC server
    func disconnect(message: String = "Leaving") {
        send(command: "QUIT", parameters: [message])
        connection?.cancel()
        connection = nil
        state = .disconnected
    }
    
    // MARK: - Connection Setup
    
    private func setupConnectionHandlers() {
        connection?.stateUpdateHandler = { [weak self] newState in
            guard let self = self else { return }
            
            switch newState {
            case .ready:
                self.handleConnectionReady()
            case .failed(let error):
                self.state = .error(error.localizedDescription)
                self.delegate?.connectionDidFail(self, error: error)
            case .cancelled:
                self.state = .disconnected
                self.delegate?.connectionDidDisconnect(self)
            default:
                break
            }
        }
        
        receiveMessages()
    }
    
    /// Handle successful TCP connection - begin IRC handshake
    private func handleConnectionReady() {
        state = .connected
        delegate?.connectionDidConnect(self)
        performIRCHandshake()
    }
    
    // MARK: - IRC Protocol Handshake
    
    /// Perform the IRC connection handshake (based on HexChat's proto-irc.c:irc_login)
    private func performIRCHandshake() {
        state = .authenticating
        
        // Step 1: Request capabilities (CAP LS 302)
        send(command: "CAP", parameters: ["LS", "302"])
        
        // Step 2: Send PASS if using password authentication
        if let password = config.password, config.authMethod == .password {
            // Handle passwords that start with ':' or contain spaces
            let formattedPassword = (password.hasPrefix(":") || password.contains(" ")) 
                ? ":\(password)" 
                : password
            send(command: "PASS", parameters: [formattedPassword])
        }
        
        // Step 3: Send NICK and USER commands
        send(command: "NICK", parameters: [config.nickname])
        send(command: "USER", parameters: [
            config.username,
            "0",
            "*",
            ":\(config.realname)"
        ])
    }
    
    // MARK: - Message Sending
    
    /// Send a raw IRC command
    func send(command: String, parameters: [String] = []) {
        var message = command
        
        if !parameters.isEmpty {
            let lastIndex = parameters.count - 1
            for (index, param) in parameters.enumerated() {
                if index == lastIndex && (param.contains(" ") || param.hasPrefix(":")) {
                    message += " :\(param)"
                } else {
                    message += " \(param)"
                }
            }
        }
        
        send(raw: message)
    }
    
    /// Send raw IRC message
    func send(raw message: String) {
        let data = "\(message)\r\n".data(using: .utf8)!
        
        connection?.send(content: data, completion: .contentProcessed { [weak self] error in
            if let error = error {
                print("Send error: \(error)")
                self?.delegate?.connection(self!, didEncounterError: error)
            }
        })
    }
    
    // MARK: - Message Receiving
    
    private func receiveMessages() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            
            if let data = data, !data.isEmpty {
                self.handleReceivedData(data)
            }
            
            if let error = error {
                self.delegate?.connection(self, didEncounterError: error)
                return
            }
            
            if !isComplete {
                self.receiveMessages()
            }
        }
    }
    
    private var receiveBuffer = Data()
    
    private func handleReceivedData(_ data: Data) {
        receiveBuffer.append(data)
        
        // Split by CRLF
        while let range = receiveBuffer.range(of: "\r\n".data(using: .utf8)!) {
            let messageData = receiveBuffer.subdata(in: 0..<range.lowerBound)
            receiveBuffer.removeSubrange(0..<range.upperBound)
            
            if let messageString = String(data: messageData, encoding: .utf8) {
                handleIRCMessage(messageString)
            }
        }
    }
    
    // MARK: - IRC Message Parsing
    
    private func handleIRCMessage(_ message: String) {
        guard let parsed = IRCMessage.parse(message) else { return }
        
        // Handle server-specific messages
        switch parsed.command {
        case "PING":
            // Respond to PING immediately
            if let server = parsed.parameters.first {
                send(command: "PONG", parameters: [server])
            }
            
        case "CAP":
            handleCapabilityResponse(parsed)
            
        case "001": // RPL_WELCOME
            state = .registered
            serverName = parsed.prefix
            delegate?.connectionDidRegister(self)
            
        case "433": // ERR_NICKNAMEINUSE
            handleNicknameInUse()
            
        default:
            break
        }
        
        // Forward to delegate
        delegate?.connection(self, didReceiveMessage: parsed)
    }
    
    private func handleCapabilityResponse(_ message: IRCMessage) {
        guard message.parameters.count >= 2 else { return }
        
        let subcommand = message.parameters[1]
        
        switch subcommand {
        case "LS":
            // Server lists available capabilities
            if message.parameters.count >= 3 {
                let caps = message.parameters[2].split(separator: " ").map(String.init)
                
                // Request SASL if available and needed
                var requestedCaps: [String] = []
                if caps.contains("sasl") && config.authMethod == .sasl {
                    requestedCaps.append("sasl")
                }
                
                if !requestedCaps.isEmpty {
                    send(command: "CAP", parameters: ["REQ", requestedCaps.joined(separator: " ")])
                    capabilitiesRequested.formUnion(requestedCaps)
                } else {
                    endCapabilityNegotiation()
                }
            }
            
        case "ACK":
            // Server acknowledges capability request
            if message.parameters.count >= 3 {
                let caps = message.parameters[2].split(separator: " ").map(String.init)
                capabilitiesAcknowledged.formUnion(caps)
                
                // If SASL was acknowledged, begin SASL auth
                if caps.contains("sasl") {
                    send(command: "AUTHENTICATE", parameters: ["PLAIN"])
                }
            }
            
        case "NAK":
            // Server rejected capability request
            endCapabilityNegotiation()
            
        default:
            break
        }
    }
    
    private func endCapabilityNegotiation() {
        guard !sentCapEnd else { return }
        send(command: "CAP", parameters: ["END"])
        sentCapEnd = true
    }
    
    private func handleNicknameInUse() {
        // Add underscore to nickname and try again
        currentNickname += "_"
        send(command: "NICK", parameters: [currentNickname])
    }
    
    // MARK: - Channel Operations
    
    func join(channel: String, key: String? = nil) {
        if let key = key {
            send(command: "JOIN", parameters: [channel, key])
        } else {
            send(command: "JOIN", parameters: [channel])
        }
    }
    
    func part(channel: String, message: String? = nil) {
        if let message = message {
            send(command: "PART", parameters: [channel, message])
        } else {
            send(command: "PART", parameters: [channel])
        }
    }
    
    func sendMessage(_ message: String, to target: String) {
        send(command: "PRIVMSG", parameters: [target, message])
    }
}

// MARK: - IRC Connection Delegate

protocol IRCConnectionDelegate: AnyObject {
    func connectionDidConnect(_ connection: IRCConnection)
    func connectionDidRegister(_ connection: IRCConnection)
    func connectionDidDisconnect(_ connection: IRCConnection)
    func connectionDidFail(_ connection: IRCConnection, error: Error)
    func connection(_ connection: IRCConnection, didReceiveMessage message: IRCMessage)
    func connection(_ connection: IRCConnection, didEncounterError error: Error)
}
