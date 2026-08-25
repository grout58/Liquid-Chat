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

    /// Return a copy with a different password (used by Keychain migration).
    func withPassword(_ newPassword: String?) -> IRCServerConfig {
        IRCServerConfig(
            id: id,
            hostname: hostname,
            port: port,
            useSSL: useSSL,
            nickname: nickname,
            username: username,
            realname: realname,
            password: newPassword,
            authMethod: authMethod,
            autoConnect: autoConnect,
            savedName: savedName
        )
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
    
    // Capability negotiation state (mutated only on receiveQueue)
    private var capabilitiesRequested: Set<String> = []
    private var capabilitiesAcknowledged: Set<String> = []
    private var advertisedCapabilities: Set<String> = []
    private var sentCapEnd = false
    private var capNegotiationTimer: DispatchWorkItem?

    // Batch message handling (IRCv3)
    private var currentBatches: [String: [IRCMessage]] = [:]
    /// Safety valve: a batch the server never closes must not buffer unboundedly.
    private let maxBatchBufferSize = 2000

    // Connection metadata
    private(set) var serverName: String?
    /// The nickname the server knows us by. Mutated only on the main thread
    /// (confirmed by 001 / NICK echoes) so SwiftUI observation stays race-free.
    private(set) var currentNickname: String
    /// The nickname most recently sent in a NICK command, before server confirmation.
    /// Owned by receiveQueue (registration-time 433 retries).
    private var attemptedNickname: String
    
    // Delegate for handling IRC messages
    weak var delegate: IRCConnectionDelegate?
    
    init(config: IRCServerConfig) {
        self.config = config
        self.currentNickname = config.nickname
        self.attemptedNickname = config.nickname
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
        let closingConnection = connection
        connection = nil
        // Give the QUIT a moment to flush before tearing down the socket.
        receiveQueue.asyncAfter(deadline: .now() + 0.25) {
            closingConnection?.cancel()
        }
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
                self.flushPendingBatches()
                // Cancel to release Network.framework resources; the .cancelled
                // branch below then reports the disconnect.
                self.connection?.cancel()
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.state = .error(error.localizedDescription)
                    self.delegate?.connectionDidFail(self, error: error)
                }
            case .cancelled:
                log("Connection cancelled", level: .info)
                self.flushPendingBatches()
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
            // Run on receiveQueue so it never races the CAP handlers
            receiveQueue.asyncAfter(deadline: .now() + IRC.capNegotiationTimeout, execute: timer)
        }

        // Step 2: Send PASS if using password authentication
        // (send() adds the ":" trailing marker itself when the password has spaces)
        if let password = config.password, config.authMethod == .password {
            log("Sending PASS (hidden)", level: .debug)
            send(command: "PASS", parameters: [password])
        }

        // Step 3: Send NICK and USER commands
        // Sanitize nickname - remove spaces and invalid characters
        let sanitizedNickname = config.nickname.replacingOccurrences(of: " ", with: "_")
        receiveQueue.async { self.attemptedNickname = sanitizedNickname }
        send(command: "NICK", parameters: [sanitizedNickname])
        send(command: "USER", parameters: [
            config.username,
            "0",
            "*",
            config.realname  // Don't add : here, send() will handle it
        ])
    }
    
    // MARK: - Message Sending

    /// Strip characters that would let a parameter break out of its IRC line
    /// (CR/LF injection) or terminate it early.
    private func sanitizedParameter(_ parameter: String) -> String {
        parameter
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\0", with: "")
    }

    /// Send a raw IRC command
    func send(command: String, parameters: [String] = []) {
        var message = command

        if !parameters.isEmpty {
            let lastIndex = parameters.count - 1
            for (index, rawParam) in parameters.enumerated() {
                let param = sanitizedParameter(rawParam)
                if index == lastIndex && (param.contains(" ") || param.hasPrefix(":") || param.isEmpty) {
                    message += " :\(param)"
                } else {
                    // Middle parameters must not contain spaces (RFC 2812 §2.3.1)
                    message += " \(param.replacingOccurrences(of: " ", with: "_"))"
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
                self.connection?.cancel()
                return
            }

            if isComplete {
                // Server closed its side (EOF) — treat as a disconnect so the UI
                // and reconnect logic see it, instead of a silent dead socket.
                log("Server closed the connection (EOF)", level: .warning)
                self.connection?.cancel()
                return
            }

            self.receiveMessages()
        }
    }

    private var receiveBuffer = Data()

    private func handleReceivedData(_ data: Data) {
        receiveBuffer.append(data)

        // A peer that never sends CRLF must not grow the buffer unboundedly
        if receiveBuffer.count > 1_048_576 {
            log("Receive buffer exceeded 1MB without a line terminator — dropping buffered data", level: .error)
            receiveBuffer.removeAll(keepingCapacity: false)
            return
        }

        // Split by CRLF
        guard let crlfData = "\r\n".data(using: .utf8) else { return }
        while let range = receiveBuffer.range(of: crlfData) {
            let messageData = receiveBuffer.subdata(in: 0..<range.lowerBound)
            receiveBuffer.removeSubrange(0..<range.upperBound)

            // Fall back to Latin-1 for legacy-encoded lines rather than dropping them
            if let messageString = String(data: messageData, encoding: .utf8)
                ?? String(data: messageData, encoding: .isoLatin1) {
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
            // Respond to PING immediately (some servers/bouncers send it bare)
            if let token = parsed.parameters.first {
                send(command: "PONG", parameters: [token])
            } else {
                send(command: "PONG")
            }

        case "CAP":
            handleCapabilityResponse(parsed)

        case "AUTHENTICATE":
            handleAuthenticateResponse(parsed)

        case "900", "903": // RPL_LOGGEDIN, RPL_SASLSUCCESS
            log("✓ SASL authentication successful", level: .info)
            endCapabilityNegotiation()

        case "902", "904", "905", "906", "907", "908": // SASL failure / abort family
            log("✗ SASL authentication failed (\(parsed.command))", level: .error)
            endCapabilityNegotiation()

        case "001": // RPL_WELCOME
            log("✓ Registered successfully", level: .info)
            let prefix = parsed.prefix
            // The server addresses 001 to our accepted nickname — authoritative.
            let confirmedNick = parsed.parameters.first
            // Now that registration is complete, PRIVMSG to ZNC modules is legal.
            if capabilitiesAcknowledged.contains("znc.in/playback") {
                log("Requesting ZNC playback history", level: .info)
                send(raw: "PRIVMSG *playback :PLAY * 0")
            }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if let confirmedNick { self.currentNickname = confirmedNick }
                self.state = .registered
                self.serverName = prefix
                self.delegate?.connectionDidRegister(self)
            }
            return  // Delegate call moved to main thread above

        case "NICK":
            // Track our own confirmed nick changes
            if let oldNick = parsed.nick, let newNick = parsed.parameters.first,
               oldNick == currentNickname || oldNick == attemptedNickname {
                DispatchQueue.main.async { [weak self] in
                    self?.currentNickname = newNick
                }
            }

        case "433": // ERR_NICKNAMEINUSE
            log("Nickname in use, trying alternate", level: .warning)
            handleNicknameInUse()

        default:
            break
        }
        
        // Check if this message is part of a batch
        if let batchID = parsed.batchID, var buffered = currentBatches[batchID] {
            if buffered.count >= maxBatchBufferSize {
                // Runaway/never-closed batch: flush what we have and stop buffering
                log("Batch \(batchID) exceeded \(maxBatchBufferSize) messages — flushing early", level: .warning)
                currentBatches.removeValue(forKey: batchID)
                for msg in buffered {
                    delegate?.connection(self, didReceiveMessage: msg)
                }
                delegate?.connection(self, didReceiveMessage: parsed)
            } else {
                buffered.append(parsed)
                currentBatches[batchID] = buffered
            }
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
                // CAP LS 302 entries can carry values ("sasl=PLAIN,EXTERNAL") — key precedes '='
                let caps = capString.split(separator: " ").compactMap {
                    $0.split(separator: "=", maxSplits: 1).first.map(String.init)
                }
                advertisedCapabilities.formUnion(caps)

                log("Available capabilities: \(caps.joined(separator: ", "))\(isMultiline ? " (more coming...)" : "")", level: .debug)

                // Accumulate across multiline LS replies; act only on the final one
                if isMultiline {
                    return
                }

                // Build list of capabilities we want to request
                var requestedCaps: [String] = []

                // Request SASL if available and needed
                if advertisedCapabilities.contains("sasl")
                    && (config.authMethod == .sasl || config.authMethod == .saslExternal) {
                    requestedCaps.append("sasl")
                }

                // Request IRCv3 + bouncer capabilities
                for cap in ["multi-prefix", "server-time", "message-tags", "batch", "znc.in/playback"]
                    where advertisedCapabilities.contains(cap) {
                    requestedCaps.append(cap)
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
                
                // Note: ZNC playback is requested after 001 (RPL_WELCOME) —
                // PRIVMSG before registration is rejected with 451.
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
    
    /// Deliver any messages still buffered in open batches (e.g. the server
    /// dropped mid-playback) so they aren't silently lost.
    private func flushPendingBatches() {
        guard !currentBatches.isEmpty else { return }
        for (batchID, messages) in currentBatches {
            log("Flushing \(messages.count) message(s) from unterminated batch \(batchID)", level: .warning)
            for msg in messages {
                delegate?.connection(self, didReceiveMessage: msg)
            }
        }
        currentBatches.removeAll()
    }

    private func handleNicknameInUse() {
        // Track the attempt separately — currentNickname only changes once the
        // server confirms (001 or a NICK echo).
        attemptedNickname += "_"
        send(command: "NICK", parameters: [attemptedNickname])
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
        // One PRIVMSG per line, chunked to fit the 512-byte frame with headroom
        // for the ":nick!user@host PRIVMSG target :" prefix the server relays.
        let overhead = 100 + target.utf8.count
        let maxPayloadBytes = max(64, 510 - overhead)

        for line in message.split(whereSeparator: \.isNewline) {
            var rest = Substring(line)
            while !rest.isEmpty {
                var end = rest.endIndex
                while rest[rest.startIndex..<end].utf8.count > maxPayloadBytes {
                    end = rest.index(before: end)
                }
                send(command: "PRIVMSG", parameters: [target, String(rest[rest.startIndex..<end])])
                rest = rest[end...]
            }
        }
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
