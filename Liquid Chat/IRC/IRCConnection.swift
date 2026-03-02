//
//  IRCConnection.swift
//  Liquid Chat
//
//  Swift-native IRC protocol implementation using Network.framework
//

import Foundation
import Network

// Convenience logging - calls actor directly (thread-safe)
private func log(_ message: String, level: ConsoleLogEntry.LogLevel = .info) {
    Task {
        await ConsoleLogger.shared.log(message, level: level, category: "IRC")
    }
}

// MARK: - String Extension for SASL Chunking

extension String {
    func split(every length: Int) -> [Substring] {
        guard length > 0 else { return [] }
        var result: [Substring] = []
        var index = startIndex
        while index < endIndex {
            let nextIndex = self.index(index, offsetBy: length, limitedBy: endIndex) ?? endIndex
            result.append(self[index..<nextIndex])
            index = nextIndex
        }
        return result
    }
}

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
enum IRCAuthMethod: String, Codable, CaseIterable {
    case none
    case password
    case sasl
    case saslExternal
    case nickserv
}

/// IRC connection configuration
struct IRCServerConfig: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    let hostname: String
    let port: UInt16
    let useSSL: Bool
    let nickname: String
    let username: String
    let realname: String
    let password: String?
    let authMethod: IRCAuthMethod
    var autoConnect: Bool
    var savedName: String? // Optional friendly name for saved servers
    
    init(
        id: UUID = UUID(),
        hostname: String,
        port: UInt16 = 6667,
        useSSL: Bool = false,
        nickname: String,
        username: String? = nil,
        realname: String? = nil,
        password: String? = nil,
        authMethod: IRCAuthMethod = .none,
        autoConnect: Bool = false,
        savedName: String? = nil
    ) {
        self.id = id
        self.hostname = hostname
        self.port = useSSL ? 6697 : port
        self.useSSL = useSSL
        self.nickname = nickname
        self.username = username ?? nickname
        self.realname = realname ?? nickname
        self.password = password
        self.authMethod = authMethod
        self.autoConnect = autoConnect
        self.savedName = savedName
    }
    
    var displayName: String {
        savedName ?? "\(nickname)@\(hostname)"
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
    private var capNegotiationTimer: DispatchWorkItem?
    
    // Batch message handling (IRCv3)
    private var currentBatches: [String: [IRCMessage]] = [:]
    
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
        Task {
            await ConsoleLogger.shared.log("connect() called, current state: \(state)", level: .debug, category: "IRC")
        }
        guard state == .disconnected else {
            Task {
                await ConsoleLogger.shared.log("Already connecting/connected, ignoring", level: .debug, category: "IRC")
            }
            return
        }
        
        state = .connecting
        Task {
            await ConsoleLogger.shared.log("Connecting to \(config.hostname):\(config.port) (SSL: \(config.useSSL))", level: .info, category: "IRC")
        }
        
        // Configure NWConnection parameters
        let parameters: NWParameters
        if config.useSSL {
            parameters = .tls
        } else {
            parameters = .tcp
        }
        
        // Create connection directly - sandbox is now configured properly
        guard let port = NWEndpoint.Port(rawValue: config.port) else {
            log("Invalid port number: \(config.port)", level: .error)
            state = .error("Invalid port number: \(config.port)")
            return
        }
        
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(config.hostname),
            port: port
        )
        
        log("Creating connection to \(endpoint)")
        connection = NWConnection(to: endpoint, using: parameters)
        setupConnectionHandlers()
        
        log("Starting connection on queue")
        connection?.start(queue: receiveQueue)
    }
    
    /// Disconnect from the IRC server
    func disconnect(message: String = "Leaving") {
        capNegotiationTimer?.cancel()
        capNegotiationTimer = nil
        send(command: "QUIT", parameters: [message])
        connection?.cancel()
        connection = nil
        state = .disconnected
    }
    
    // MARK: - Connection Setup
    
    private func setupConnectionHandlers() {
        connection?.stateUpdateHandler = { [weak self] newState in
            guard let self = self else { return }

            log("Connection state changed: \(newState)", level: .debug)

            switch newState {
            case .ready:
                // handleConnectionReady also mutates state — dispatch to main
                DispatchQueue.main.async { [weak self] in self?.handleConnectionReady() }
            case .failed(let error):
                log("Connection failed: \(error.localizedDescription)", level: .error)
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.state = .error(error.localizedDescription)
                    self.delegate?.connectionDidFail(self, error: error)
                }
            case .cancelled:
                log("Connection cancelled", level: .info)
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.state = .disconnected
                    self.delegate?.connectionDidDisconnect(self)
                }
            case .waiting(let error):
                log("Connection waiting: \(error.localizedDescription)", level: .warning)
            case .preparing:
                log("Connection preparing...", level: .debug)
            default:
                break
            }
        }
        
        receiveMessages()
    }
    
    /// Handle successful TCP connection - begin IRC handshake (must run on main thread)
    private func handleConnectionReady() {
        log("Connection ready to \(config.hostname):\(config.port)", level: .info)
        state = .connected          // Safe: now always called on main thread
        delegate?.connectionDidConnect(self)
        performIRCHandshake()
    }
    
    // MARK: - IRC Protocol Handshake
    
    /// Perform the IRC connection handshake (based on HexChat's proto-irc.c:irc_login)
    private func performIRCHandshake() {
        guard state == .connected else {
            log("Skipping handshake - already in state: \(state)", level: .debug)
            return
        }
        log("Beginning handshake", level: .info)
        state = .authenticating
        
        // Step 1: Request capabilities (CAP LS 302)
        send(command: "CAP", parameters: ["LS", "302"])
        
        // Set a timeout for capability negotiation
        // If server doesn't respond, continue anyway
        capNegotiationTimer = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            if !self.sentCapEnd {
                log("CAP negotiation timeout - ending negotiation", level: .warning)
                self.endCapabilityNegotiation()
            }
        }
        if let timer = capNegotiationTimer {
            DispatchQueue.global().asyncAfter(deadline: .now() + IRC.capNegotiationTimeout, execute: timer)
        }
        
        // Step 2: Send PASS if using password authentication
        if let password = config.password, config.authMethod == .password {
            // Only prefix with colon if password contains spaces (per IRC RFC)
            let formattedPassword = password.contains(" ") ? ":\(password)" : password
            log("Sending PASS (hidden)", level: .debug)
            send(command: "PASS", parameters: [formattedPassword])
        }
        
        // Step 3: Send NICK and USER commands
        // Sanitize nickname - remove spaces and invalid characters
        let sanitizedNickname = config.nickname.replacingOccurrences(of: " ", with: "_")
        send(command: "NICK", parameters: [sanitizedNickname])
        send(command: "USER", parameters: [
            config.username,
            "0",
            "*",
            config.realname  // Don't add : here, send() will handle it
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
        guard let data = "\(message)\r\n".data(using: .utf8) else {
            log("Failed to encode message as UTF-8: \(message)", level: .error)
            return
        }
        log("→ \(message)", level: .debug)
        
        connection?.send(content: data, completion: .contentProcessed { [weak self] error in
            if let error = error {
                log("Send error: \(error)", level: .error)
                guard let self else { return }
                self.delegate?.connection(self, didEncounterError: error)
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
        guard let crlfData = "\r\n".data(using: .utf8) else { return }
        while let range = receiveBuffer.range(of: crlfData) {
            let messageData = receiveBuffer.subdata(in: 0..<range.lowerBound)
            receiveBuffer.removeSubrange(0..<range.upperBound)
            
            if let messageString = String(data: messageData, encoding: .utf8) {
                handleIRCMessage(messageString)
            }
        }
    }
    
    // MARK: - IRC Message Parsing
    
    private func handleIRCMessage(_ message: String) {
        log("← \(message)", level: .debug)
        
        guard let parsed = IRCMessage.parse(message) else {
            log("Failed to parse message: \(message)", level: .warning)
            return
        }
        
        // Handle IRCv3 BATCH messages
        if parsed.command == "BATCH" {
            handleBatch(parsed)
            return // Don't forward batch markers to delegate
        }
        
        // Disabled: Logging every LIST message causes MainActor saturation with 10K+ channels
        // if ["321", "322", "323"].contains(parsed.command) {
        //     log("LIST message: \(parsed.command) with \(parsed.parameters.count) params", level: .debug)
        // }
        
        // Handle server-specific messages
        switch parsed.command {
        case "PING":
            // Respond to PING immediately
            if let server = parsed.parameters.first {
                send(command: "PONG", parameters: [server])
            }
            
        case "CAP":
            handleCapabilityResponse(parsed)
            
        case "AUTHENTICATE":
            handleAuthenticateResponse(parsed)
            
        case "900": // RPL_LOGGEDIN
            log("✓ SASL authentication successful", level: .info)
            endCapabilityNegotiation()
            
        case "904", "905": // ERR_SASLFAIL, ERR_SASLTOOLONG
            log("✗ SASL authentication failed", level: .error)
            endCapabilityNegotiation()
            
        case "001": // RPL_WELCOME
            log("✓ Registered successfully", level: .info)
            let prefix = parsed.prefix
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.state = .registered
                self.serverName = prefix
                self.delegate?.connectionDidRegister(self)
            }
            return  // Delegate call moved to main thread above
            
        case "433": // ERR_NICKNAMEINUSE
            log("Nickname in use, trying alternate", level: .warning)
            handleNicknameInUse()
            
        default:
            break
        }
        
        // Check if this message is part of a batch
        if let batchID = parsed.batchID, currentBatches[batchID] != nil {
            // Add to batch instead of forwarding immediately
            currentBatches[batchID]?.append(parsed)
            return
        }
        
        // Forward to delegate (delegate handles MainActor dispatch)
        // DO NOT wrap in Task here - delegate is nonisolated and handles its own MainActor hop
        delegate?.connection(self, didReceiveMessage: parsed)
    }
    
    private func handleCapabilityResponse(_ message: IRCMessage) {
        guard message.parameters.count >= 2 else { return }
        
        let subcommand = message.parameters[1]
        
        switch subcommand {
        case "LS":
            // Server lists available capabilities
            // Format: CAP * LS :cap1 cap2 cap3 (final)
            // Format: CAP * LS * :cap1 cap2 cap3 (more to come)
            if message.parameters.count >= 3 {
                let isMultiline = message.parameters.count >= 4 && message.parameters[2] == "*"
                let capString = isMultiline ? message.parameters[3] : message.parameters[2]
                let caps = capString.split(separator: " ").map(String.init)
                
                log("Available capabilities: \(caps.joined(separator: ", "))\(isMultiline ? " (more coming...)" : "")", level: .debug)
                
                // If this is multiline, wait for the final LS
                if isMultiline {
                    return
                }
                
                // Build list of capabilities we want to request
                var requestedCaps: [String] = []
                
                // Request SASL if available and needed
                if caps.contains("sasl") && (config.authMethod == .sasl || config.authMethod == .saslExternal) {
                    requestedCaps.append("sasl")
                }
                
                // Request IRCv3 capabilities
                if caps.contains("multi-prefix") {
                    requestedCaps.append("multi-prefix")
                }
                if caps.contains("server-time") {
                    requestedCaps.append("server-time")
                }
                if caps.contains("message-tags") {
                    requestedCaps.append("message-tags")
                }
                if caps.contains("batch") {
                    requestedCaps.append("batch")
                }
                
                // ZNC bouncer support
                if caps.contains("znc.in/playback") {
                    requestedCaps.append("znc.in/playback")
                }
                
                if !requestedCaps.isEmpty {
                    log("Requesting capabilities: \(requestedCaps.joined(separator: ", "))", level: .info)
                    send(command: "CAP", parameters: ["REQ", requestedCaps.joined(separator: " ")])
                    capabilitiesRequested.formUnion(requestedCaps)
                } else {
                    log("No capabilities to request, ending negotiation", level: .debug)
                    endCapabilityNegotiation()
                }
            } else {
                // Malformed CAP LS or no capabilities available
                log("No capabilities available or malformed CAP LS", level: .debug)
                endCapabilityNegotiation()
            }
            
        case "ACK":
            // Server acknowledges capability request
            if message.parameters.count >= 3 {
                let caps = message.parameters[2].split(separator: " ").map(String.init)
                capabilitiesAcknowledged.formUnion(caps)
                
                log("✓ Capabilities acknowledged: \(caps.joined(separator: ", "))", level: .info)
                
                // If SASL was acknowledged, begin SASL auth
                if caps.contains("sasl") {
                    if config.authMethod == .saslExternal {
                        send(command: "AUTHENTICATE", parameters: ["EXTERNAL"])
                    } else if config.authMethod == .sasl {
                        send(command: "AUTHENTICATE", parameters: ["PLAIN"])
                    } else {
                        // SASL capability acknowledged but we're not using it
                        endCapabilityNegotiation()
                    }
                } else {
                    // No SASL in this ACK, end negotiation if not waiting for SASL
                    if config.authMethod != .sasl && config.authMethod != .saslExternal {
                        endCapabilityNegotiation()
                    }
                }
                
                // Request ZNC playback if available
                if caps.contains("znc.in/playback") {
                    log("Requesting ZNC playback history", level: .info)
                    send(raw: "PRIVMSG *playback :PLAY * 0")
                }
            }
            
        case "NAK":
            // Server rejected capability request
            endCapabilityNegotiation()
            
        default:
            break
        }
    }
    
    private func handleAuthenticateResponse(_ message: IRCMessage) {
        guard message.parameters.count >= 1 else { return }
        
        // Server sends "+" to request SASL credentials
        if message.parameters[0] == "+" {
            // Handle SASL EXTERNAL (certificate-based auth)
            if config.authMethod == .saslExternal {
                // SASL EXTERNAL uses empty response (certificate is already provided by TLS)
                send(command: "AUTHENTICATE", parameters: ["+"])
                return
            }
            
            // Handle SASL PLAIN (username/password auth)
            guard let password = config.password else {
                log("SASL requested but no password configured", level: .error)
                send(command: "AUTHENTICATE", parameters: ["*"]) // Abort SASL
                endCapabilityNegotiation()
                return
            }
            
            // SASL PLAIN format: \0username\0password
            let authString = "\0\(config.username)\0\(password)"
            
            if let authData = authString.data(using: .utf8) {
                let base64 = authData.base64EncodedString()
                
                // Split into 400-byte chunks if needed (IRC line limit).
                // A payload of exactly 400 bytes must be followed by "+" to signal end-of-stream.
                if base64.count < 400 {
                    send(command: "AUTHENTICATE", parameters: [base64])
                } else {
                    // Handle chunked SASL (rarely needed)
                    let chunks = base64.split(every: 400)
                    for chunk in chunks {
                        send(command: "AUTHENTICATE", parameters: [String(chunk)])
                    }
                    if base64.count % 400 == 0 {
                        send(command: "AUTHENTICATE", parameters: ["+"])
                    }
                }
            }
        }
    }
    
    private func endCapabilityNegotiation() {
        guard !sentCapEnd else { return }
        
        // Cancel the timeout timer
        capNegotiationTimer?.cancel()
        capNegotiationTimer = nil
        
        log("Ending capability negotiation", level: .info)
        send(command: "CAP", parameters: ["END"])
        sentCapEnd = true
    }
    
    private func handleBatch(_ message: IRCMessage) {
        guard message.parameters.count >= 1 else { return }
        
        let batchParam = message.parameters[0]
        
        if batchParam.hasPrefix("+") {
            // Start of batch
            let batchID = String(batchParam.dropFirst())
            currentBatches[batchID] = []
            log("Started batch: \(batchID)", level: .debug)
        } else if batchParam.hasPrefix("-") {
            // End of batch
            let batchID = String(batchParam.dropFirst())
            if let batchMessages = currentBatches[batchID] {
                log("Completed batch: \(batchID) with \(batchMessages.count) messages", level: .debug)
                // Forward all batch messages to delegate at once
                for msg in batchMessages {
                    delegate?.connection(self, didReceiveMessage: msg)
                }
                currentBatches.removeValue(forKey: batchID)
            }
        }
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
