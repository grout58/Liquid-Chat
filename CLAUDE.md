# Liquid Chat - Modern IRC Client Implementation Plan

## Status Overview

### ✅ Already Implemented
1. **Basic IRC Protocol (RFC 1459)**
   - Connection management with Network.framework
   - NICK, USER, PASS commands
   - JOIN, PART, PRIVMSG, NOTICE
   - PING/PONG automatic handling
   - TLS/SSL support (default port 6697)
   - Message parsing and routing

2. **SASL Authentication**
   - SASL PLAIN mechanism
   - Capability negotiation (CAP LS 302)
   - CAP REQ/ACK handling
   - AUTHENTICATE chunking for large payloads

3. **Multi-Network Support**
   - Multiple concurrent server connections
   - NavigationSplitView architecture
   - Per-server channel management

4. **Core UI Features**
   - Liquid Glass design system integration
   - Channel sidebar with server/channel hierarchy
   - Message list with virtualized scrolling (LazyVStack)
   - User list with mode indicators (@, +, etc.)
   - Private message support

5. **State Management**
   - @Observable macro for reactive updates
   - ChatState managing servers and channels
   - IRCConnection delegate pattern
   - Connection state tracking

6. **Message Types**
   - Regular messages (.message)
   - Actions (/me commands) (.action)
   - System messages (.system)
   - JOIN/PART/QUIT events
   - NICK changes
   - TOPIC updates

## 🚧 Required Implementations

### 1. Protocol & Security Enhancements

#### SASL EXTERNAL Mechanism
**Status:** Not implemented  
**Priority:** High  
**Location:** `IRC/IRCConnection.swift`

**Implementation:**
- Add `.external` case to `IRCAuthMethod`
- Implement SASL EXTERNAL in `handleAuthenticateResponse()`
- Use client certificate for authentication
- Update `IRCServerConfig` to support certificate paths

**Code snippet:**
```swift
case .external:
    // SASL EXTERNAL uses empty response
    send(command: "AUTHENTICATE", parameters: ["+"])
```

#### IRCv3 Capability Negotiation
**Status:** Partially implemented (CAP LS 302 only)  
**Priority:** High  
**Location:** `IRC/IRCConnection.swift`

**Required Capabilities:**
- `multi-prefix` - Multiple mode prefixes (@+user)
- `server-time` - Accurate message timestamps
- `message-tags` - Extended message metadata
- `batch` - Grouped message delivery

**Implementation:**
```swift
// In handleCapabilityResponse()
let requestedCaps: [String] = [
    "multi-prefix",
    "server-time", 
    "message-tags",
    "batch",
    "sasl" // if needed
]
```

**Impact:**
- Update `IRCMessage.swift` to parse message tags
- Add timestamp handling from `@time=` tag
- Support batch START/END commands
- Parse multiple mode prefixes in NAMES replies

#### Enhanced TLS Configuration
**Status:** Basic TLS implemented  
**Priority:** Medium  
**Location:** `IRC/IRCConnection.swift`

**Improvements:**
- Verify server certificates by default
- Support custom CA certificates
- Add certificate pinning option
- Display TLS version and cipher in UI

### 2. Bouncer Support

#### ZNC Bouncer Integration
**Status:** Not implemented  
**Priority:** High  
**Location:** `IRC/IRCConnection.swift`

**Features:**
- Support `PASS host:port:password` format
- Request `znc.in/playback` capability
- Handle ZNC-specific commands:
  - `*playback PLAY * 0` - Request full history
  - `*status` - Check ZNC status
- Parse ZNC module messages

**Implementation:**
```swift
// In performIRCHandshake()
if let password = config.password, config.authMethod == .password {
    // Check if password contains ZNC bouncer format
    if password.contains(":") {
        // Format: user/network:password or host:port:password
        send(command: "PASS", parameters: [password])
    }
}

// In handleCapabilityResponse()
if caps.contains("znc.in/playback") {
    requestedCaps.append("znc.in/playback")
}
```

#### Soju Bouncer Support
**Status:** Not implemented  
**Priority:** Medium  
**Location:** `IRC/IRCConnection.swift`

**Features:**
- Support `BOUNCER BIND` command
- Handle `soju.im/bouncer-networks` capability
- Network switching within single connection
- Persistent message history

### 3. UI/UX Enhancements

#### Tab Completion for Nicknames
**Status:** Not implemented  
**Priority:** High  
**Location:** `Views/ChatView.swift`

**Implementation:**
- Detect Tab key press in TextField
- Match current word against channel user list
- Cycle through matches on repeated Tab
- Add colon after nick if at start of line

**Pseudocode:**
```swift
.onKeyPress(.tab) { keyPress in
    let currentWord = extractCurrentWord()
    let matches = channel.users.filter { 
        $0.nickname.hasPrefix(currentWord) 
    }
    if let match = matches.first {
        replaceCurrentWord(with: match.nickname)
    }
    return .handled
}
```

#### Pastebin Trigger
**Status:** Not implemented  
**Priority:** Medium  
**Location:** `Views/ChatView.swift`

**Features:**
- Detect when message contains 5+ newlines
- Show alert: "This message is large. Upload to pastebin?"
- Options: [Send Anyway] [Upload to Pastebin] [Cancel]
- Support pastebin.com or custom service

**Implementation:**
```swift
func sendMessage() {
    let lineCount = messageText.components(separatedBy: "\n").count
    if lineCount >= 5 {
        showPastebinPrompt = true
        return
    }
    // Normal send...
}
```

#### Inline Image Preview
**Status:** Not implemented  
**Priority:** Medium  
**Location:** `Views/MessageListView.swift`

**Features:**
- Detect URLs in messages (http, https)
- Fetch URL metadata (title, description, image)
- Display thumbnail inline with message
- Click to open in browser or expand
- Support: images (jpg, png, gif), videos (youtube), links

**Implementation:**
```swift
// New file: Utilities/URLPreviewFetcher.swift
actor URLPreviewFetcher {
    func fetchPreview(for url: URL) async -> URLPreview? {
        // Fetch HTML, parse <meta> tags
        // Return title, description, imageURL
    }
}

// In MessageListView:
if let url = extractFirstURL(from: message.content) {
    AsyncImage(url: url) { image in
        image.resizable().aspectRatio(contentMode: .fit)
    }
}
```

#### Nicklist Context Menu
**Status:** Partially implemented (user list exists)  
**Priority:** Medium  
**Location:** `Views/ChatView.swift`

**Features:**
- Right-click user in nicklist
- Actions:
  - **Whois** - Show user information
  - **Query** - Open private message
  - **Ignore** - Hide messages from user
  - **Op/Deop** - Change user modes (if you're op)
  - **Kick/Ban** - Moderation actions

**Implementation:**
```swift
// In user list ForEach:
.contextMenu {
    Button("Whois \(user.nickname)") {
        connection.send(command: "WHOIS", parameters: [user.nickname])
    }
    Button("Send Message") {
        chatState.openPrivateMessage(with: user.nickname, on: server)
    }
    Button("Ignore") {
        ignoreList.add(user.nickname)
    }
}
```

### 4. Automation & Persistence

#### Background Logging Actor
**Status:** Not implemented  
**Priority:** High  
**Location:** New file `Utilities/ChannelLogger.swift`

**Features:**
- Log all channel messages to local files
- Organize logs: `~/Library/Application Support/Liquid Chat/Logs/{server}/{channel}/`
- File format: `YYYY-MM-DD.log`
- Include timestamps and user prefixes
- Run in background without blocking UI

**Implementation:**
```swift
actor ChannelLogger {
    private let baseURL: URL
    
    init() {
        baseURL = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Liquid Chat/Logs")
    }
    
    func log(message: IRCChatMessage, channel: String, server: String) async {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let filename = dateFormatter.string(from: message.timestamp)
        
        let logURL = baseURL
            .appendingPathComponent(server)
            .appendingPathComponent(channel)
            .appendingPathComponent("\(filename).log")
        
        // Ensure directory exists
        try? FileManager.default.createDirectory(
            at: logURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        
        // Append message
        let logLine = "[\(message.timestamp)] <\(message.sender)> \(message.content)\n"
        if let data = logLine.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logURL.path) {
                let fileHandle = try? FileHandle(forWritingTo: logURL)
                fileHandle?.seekToEndOfFile()
                fileHandle?.write(data)
                fileHandle?.closeFile()
            } else {
                try? data.write(to: logURL)
            }
        }
    }
}
```

**Integration:**
```swift
// In ChatState.handlePrivMsg():
Task {
    await ChannelLogger.shared.log(
        message: chatMessage,
        channel: channelName,
        server: server.config.hostname
    )
}
```

#### Persistent Server Configuration
**Status:** Partially implemented (ServerConfigManager exists)  
**Priority:** Medium  
**Location:** `Models/ServerConfigManager.swift`

**Enhancements:**
- Save auto-connect servers
- Restore channels on reconnect
- Store server-specific settings (encoding, etc.)
- Import/export server configurations

### 5. Protocol Extensions

#### IRCMessage Enhancement
**Status:** Basic parsing implemented  
**Priority:** High  
**Location:** `IRC/IRCMessage.swift`

**Add Support For:**
```swift
struct IRCMessage {
    let prefix: String?
    let command: String
    let parameters: [String]
    
    // NEW: IRCv3 message tags
    let tags: [String: String]  // @time=2024-01-01T12:00:00.000Z
    
    // NEW: Parsed timestamp from server-time
    var serverTime: Date? {
        if let timeTag = tags["time"] {
            return ISO8601DateFormatter().date(from: timeTag)
        }
        return nil
    }
}
```

#### Command Handler
**Status:** Not implemented  
**Priority:** Medium  
**Location:** New file `IRC/IRCCommandHandler.swift`

**Features:**
- Parse user input commands (/join, /part, /quit, /me, etc.)
- Handle client-side commands (/clear, /help)
- Support command aliases
- Show command help

**Implementation:**
```swift
class IRCCommandHandler {
    func handleCommand(_ input: String, connection: IRCConnection) {
        guard input.hasPrefix("/") else {
            // Regular message
            return
        }
        
        let parts = input.dropFirst().split(separator: " ", maxSplits: 1)
        let command = String(parts[0]).lowercased()
        let args = parts.count > 1 ? String(parts[1]) : ""
        
        switch command {
        case "join":
            connection.join(channel: args)
        case "part":
            connection.part(channel: args)
        case "me":
            connection.send(command: "PRIVMSG", parameters: [channel, "\u{01}ACTION \(args)\u{01}"])
        case "quit":
            connection.disconnect(message: args)
        default:
            // Show error
            break
        }
    }
}
```

## Implementation Priority

### Phase 1: Core Protocol Enhancements
1. ✅ IRCv3 capabilities (multi-prefix, server-time, message-tags, batch)
2. ✅ Enhanced IRCMessage with tag support
3. ✅ SASL EXTERNAL mechanism
4. ✅ ZNC bouncer support

### Phase 2: UI/UX Features
1. ✅ Tab completion for nicknames
2. ✅ Nicklist context menu (Whois/Ignore)
3. ✅ Pastebin trigger
4. ✅ Inline image preview

### Phase 3: Automation & Persistence
1. ✅ Background logging actor
2. ✅ Enhanced server configuration
3. ✅ Auto-reconnect logic
4. ✅ Command handler

### Phase 4: Advanced Features
1. ⏳ Soju bouncer support
2. ⏳ DCC file transfers
3. ⏳ Custom themes
4. ⏳ Notification system

## Testing Checklist

### Connection Testing
- [ ] Connect to standard IRC server (Libera.Chat)
- [ ] Connect via SSL/TLS
- [ ] SASL PLAIN authentication
- [ ] SASL EXTERNAL authentication (with certificate)
- [ ] Connect through ZNC bouncer
- [ ] Reconnect after disconnect
- [ ] Handle nickname conflicts

### Protocol Testing
- [ ] Send/receive PRIVMSG
- [ ] JOIN/PART channels
- [ ] NAMES list parsing with multi-prefix
- [ ] TOPIC display and changes
- [ ] MODE changes (op/voice)
- [ ] KICK/BAN handling
- [ ] NICK changes
- [ ] QUIT messages

### IRCv3 Testing
- [ ] server-time timestamps display correctly
- [ ] message-tags parsed properly
- [ ] batch messages grouped correctly
- [ ] multi-prefix shows all modes (@+user)

### UI Testing
- [ ] Tab completion cycles through nicks
- [ ] Pastebin prompt appears for 5+ lines
- [ ] Image URLs show thumbnails
- [ ] Context menu actions work
- [ ] Liquid Glass effects perform well
- [ ] Scrolling is smooth with 1000+ messages

### Persistence Testing
- [ ] Logs written to correct location
- [ ] Server configs saved and restored
- [ ] Auto-connect servers reconnect on launch
- [ ] Channel list preserved across sessions

## Technical Debt

### Current Issues
1. **Error Handling:** Need better error recovery for network failures
2. **Memory Management:** Large message histories may consume memory
3. **Performance:** Image preview fetching should be rate-limited
4. **Accessibility:** VoiceOver support needs improvement
5. **Localization:** UI strings should be localized

### Future Improvements
1. **SwiftData Migration:** Consider migrating from @Observable to SwiftData
2. **CloudKit Sync:** Sync settings across devices
3. **iOS Support:** Adapt UI for iPhone/iPad
4. **Widgets:** Show recent messages in widgets
5. **Shortcuts:** Siri shortcuts for sending messages

## Resources

### IRC Specifications
- RFC 1459: Internet Relay Chat Protocol
- RFC 2812: Internet Relay Chat: Client Protocol
- IRCv3: https://ircv3.net/

### Apple Documentation
- Liquid Glass: https://developer.apple.com/documentation/TechnologyOverviews/liquid-glass
- Network.framework: https://developer.apple.com/documentation/Network
- SwiftUI: https://developer.apple.com/documentation/SwiftUI

### Reference Implementations
- HexChat: External/HexChat (included in project)
- Textual: https://github.com/Codeux-Software/Textual
- Irssi: https://github.com/irssi/irssi

## Notes

### Liquid Glass Best Practices
- Use `.glassEffect()` sparingly - only on functional elements
- Test with Accessibility > Reduce Transparency enabled
- Morphing containers need `.glassEffectID()` on all children
- Interactive glass responds to touch/pointer automatically

### IRC Protocol Quirks
- Channel names can start with # & ! +
- Nicknames can contain special chars: []{}\\|`^_-
- MODE changes may come as individual events or batched
- Some servers don't support IRCv3 capabilities
- ZNC requires special PASS format: user/network:password

### Performance Considerations
- Use LazyVStack for message lists (already done)
- Consider NSTextLayoutManager for very large histories
- Cache URL preview metadata to avoid repeated fetches
- Run background logging on separate actor (non-blocking)
- Limit concurrent image preview downloads

---

**Last Updated:** 2026-02-20  
**Version:** 1.0  
**Maintainer:** Claude Agent
