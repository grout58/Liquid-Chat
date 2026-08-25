//
//  IRCModels.swift
//  Liquid Chat
//
//  Data models for IRC chat
//

import Foundation
import SwiftUI

// MARK: - IRC String Semantics

extension String {
    /// Canonical form for IRC name comparison (RFC 1459 casemapping:
    /// case-insensitive, with []\^ being the uppercase forms of {}|~).
    var ircCasemapped: String {
        lowercased()
            .replacingOccurrences(of: "[", with: "{")
            .replacingOccurrences(of: "]", with: "}")
            .replacingOccurrences(of: "\\", with: "|")
            .replacingOccurrences(of: "^", with: "~")
    }

    /// True when `nick` appears as a standalone word — "ed" must not match "edited".
    /// Word characters include the specials IRC allows in nicknames.
    func containsNick(_ nick: String) -> Bool {
        guard !nick.isEmpty else { return false }
        let nickChar = "[A-Za-z0-9_\\[\\]\\\\{}|^`-]"
        let pattern = "(?<!\(nickChar))\(NSRegularExpression.escapedPattern(for: nick))(?!\(nickChar))"
        return range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
}

// MARK: - IRC Text Formatting

/// Renders raw IRC message text for display: strips mIRC formatting control
/// codes and linkifies URLs once, at ingest, so per-row rendering stays cheap.
enum IRCTextFormatter {
    private static let urlDetector = try? NSDataDetector(
        types: NSTextCheckingResult.CheckingType.link.rawValue
    )

    static func render(_ raw: String) -> AttributedString {
        let text = stripFormattingCodes(raw)
        var attributed = AttributedString(text)

        if let matches = urlDetector?.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            for match in matches {
                guard let url = match.url,
                      let range = Range(match.range, in: text) else { continue }
                let start = text.distance(from: text.startIndex, to: range.lowerBound)
                let length = text.distance(from: range.lowerBound, to: range.upperBound)
                guard let attrRange = attributed.characterRange(offset: start, length: length) else { continue }
                attributed[attrRange].link = url
                attributed[attrRange].foregroundColor = .blue
                attributed[attrRange].underlineStyle = .single
            }
        }

        return attributed
    }

    /// Strip mIRC formatting codes: bold (\x02), color (\x03 + digits), italic
    /// (\x1D), underline (\x1F), strikethrough (\x1E), monospace (\x11),
    /// reverse (\x16), reset (\x0F).
    static func stripFormattingCodes(_ s: String) -> String {
        guard s.contains(where: { $0.asciiValue.map { $0 < 0x20 && $0 != 0x09 } ?? false }) else { return s }
        var out = ""
        out.reserveCapacity(s.count)
        var i = s.startIndex
        while i < s.endIndex {
            let c = s[i]
            switch c {
            case "\u{02}", "\u{1D}", "\u{1F}", "\u{1E}", "\u{11}", "\u{16}", "\u{0F}":
                i = s.index(after: i)
            case "\u{03}":
                // Color: \x03[FG[,BG]] with 1–2 digits each
                i = s.index(after: i)
                var fgDigits = 0
                while i < s.endIndex, s[i].isASCII, s[i].isNumber, fgDigits < 2 {
                    i = s.index(after: i); fgDigits += 1
                }
                if fgDigits > 0, i < s.endIndex, s[i] == "," {
                    var j = s.index(after: i)
                    var bgDigits = 0
                    while j < s.endIndex, s[j].isASCII, s[j].isNumber, bgDigits < 2 {
                        j = s.index(after: j); bgDigits += 1
                    }
                    if bgDigits > 0 { i = j }   // consume ",NN"; a bare comma stays
                }
            default:
                out.append(c)
                i = s.index(after: i)
            }
        }
        return out
    }
}

extension AttributedString {
    /// Convert a character offset + length into an AttributedString range.
    func characterRange(offset: Int, length: Int) -> Range<AttributedString.Index>? {
        guard offset >= 0, length >= 0, offset + length <= characters.count else { return nil }
        let start = characters.index(startIndex, offsetBy: offset)
        let end = characters.index(start, offsetBy: length)
        return start..<end
    }
}

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

    /// What this server advertised in RPL_ISUPPORT (005); defaults until then.
    var isupport = IRCISupport()

    /// Task for observing connection state changes (can be cancelled)
    var observationTask: Task<Void, Never>?

    /// Whether the user manually disconnected (suppress auto-reconnect)
    var manuallyDisconnected: Bool = false

    /// Current reconnect delay for exponential backoff (seconds)
    var reconnectDelay: TimeInterval = 5.0

    /// Pending reconnect task
    var reconnectTask: Task<Void, Never>?

    /// Buffer for LIST (322) entries. All IRC message handling runs on the
    /// MainActor, so a plain array is race-free; @ObservationIgnored keeps the
    /// thousands of appends from invalidating SwiftUI views.
    @ObservationIgnored private var pendingChannelList: [IRCChannelListEntry] = []

    init(config: IRCServerConfig) {
        self.config = config
    }

    /// Look up a channel by IRC name semantics (case-insensitive per RFC 1459
    /// casemapping) — servers freely vary the case of channel and nick names.
    func channel(named name: String) -> IRCChannel? {
        let key = name.ircCasemapped
        return channels.first { $0.name.ircCasemapped == key }
    }

    /// Cancel any ongoing observation tasks
    func cancelObservation() {
        observationTask?.cancel()
        observationTask = nil
    }

    /// Cancel any pending reconnect task
    func cancelReconnect() {
        reconnectTask?.cancel()
        reconnectTask = nil
    }

    /// Buffer a LIST entry (called on the MainActor message path)
    func bufferChannelListEntry(_ entry: IRCChannelListEntry) {
        pendingChannelList.append(entry)
    }

    /// Discard buffered entries (start of a new LIST)
    func clearChannelListBuffer() {
        pendingChannelList.removeAll()
    }

    /// Sort the buffered entries off-main, then publish them in one update
    func flushChannelListBuffer() async {
        let snapshot = pendingChannelList
        pendingChannelList = []
        guard !snapshot.isEmpty else { return }

        let sorted = await Task.detached(priority: .userInitiated) {
            snapshot.sorted { $0.userCount > $1.userCount }
        }.value

        availableChannels = sorted  // Replace, don't append
        await ConsoleLogger.shared.log("✓ Loaded and sorted \(sorted.count) channels", level: .info, category: "IRC")
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
    
    /// Messages array - kept as regular property so SwiftUI can observe it
    /// The key insight: SwiftUI is smart enough to only re-render visible rows in LazyVStack
    /// The MainActor saturation was from the double-hop, not from observation itself
    var messages: [IRCChatMessage] = []

    /// Users array
    var users: [IRCUser] = []

    /// Append a message, trimming oldest entries beyond the limit.
    /// Pass `currentNickname` to enable unread/mention tracking.
    func appendMessage(_ message: IRCChatMessage, currentNickname: String? = nil, isActive: Bool = false) {
        messages.append(message)
        let limit = AppSettings.shared.messageHistoryLimit
        if messages.count > limit {
            messages.removeFirst(messages.count - limit)
        }

        guard !isActive, message.type == .message || message.type == .action || message.type == .notice else { return }
        unreadCount += 1

        if let nick = currentNickname {
            let text = String(message.content.characters)
            if text.containsNick(nick) {
                hasMention = true
            }
        }
    }

    var isJoined: Bool = false

    /// True while a NAMES (353) burst is being received. The first reply of a
    /// burst clears the stale user list; 366 (end of NAMES) resets the flag.
    @ObservationIgnored var isReceivingNames: Bool = false

    /// Number of messages received while this channel was not selected.
    var unreadCount: Int = 0

    /// True when an unread message contains a mention of the current user's nick.
    var hasMention: Bool = false

    /// Is this a private message (DM) rather than a channel?
    var isPrivateMessage: Bool {
        !name.hasPrefix("#") && !name.hasPrefix("&")
    }

    /// Clear unread state (call when the user switches to this channel).
    func markRead() {
        unreadCount = 0
        hasMention = false
    }

    /// Index of a user by IRC name semantics (case-insensitive).
    func userIndex(named nick: String) -> Int? {
        let key = nick.ircCasemapped
        return users.firstIndex { $0.nickname.ircCasemapped == key }
    }

    func hasUser(named nick: String) -> Bool {
        userIndex(named: nick) != nil
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
        // Mode letters, highest rank first (owner, admin, op, half-op, voice)
        if modes.contains("q") { return "~" }
        if modes.contains("a") { return "&" }
        if modes.contains("o") { return "@" }
        if modes.contains("h") { return "%" }
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
    /// IRCv3 batch identifier — set when this message was delivered as part of a batch.
    /// Used to visually group batch-replayed messages (e.g. CHATHISTORY) in the message list.
    var batchID: String?
    
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
    
    init(sender: String, content: String, type: MessageType = .message, timestamp: Date? = nil, batchID: String? = nil) {
        self.timestamp = timestamp ?? Date()
        self.sender = sender
        // Strip mIRC control codes and linkify once at ingest — per-row render
        // then never re-runs detection over the whole history.
        self.content = IRCTextFormatter.render(content)
        self.type = type
        self.batchID = batchID
    }

    init(sender: String, content: AttributedString, type: MessageType = .message, timestamp: Date? = nil, batchID: String? = nil) {
        self.timestamp = timestamp ?? Date()
        self.sender = sender
        self.content = content
        self.type = type
        self.batchID = batchID
    }
}
