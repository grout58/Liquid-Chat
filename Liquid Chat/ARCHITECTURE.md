# Liquid Chat Architecture

A modern IRC client for macOS 26 built with SwiftUI and Liquid Glass design system.

## Overview

Liquid Chat is a Swift-native IRC client that leverages the latest macOS 26 technologies including:
- **Liquid Glass** for modern, dynamic UI materials
- **Network.framework** for efficient IRC protocol implementation
- **TextLayout API** (NSTextLayoutManager) for high-performance message rendering
- **SwiftUI** with `@Observable` macro for reactive state management

## Architecture Layers

### 1. IRC Protocol Layer (`IRC/`)

#### IRCConnection.swift
Swift-native IRC protocol implementation using Network.framework.

**Key Features:**
- Async TCP/TLS connection management using `NWConnection`
- IRC protocol handshake based on HexChat's `proto-irc.c:irc_login`:
  1. CAP LS 302 (capability negotiation)
  2. PASS (if password authentication)
  3. NICK + USER commands
- Automatic PING/PONG handling
- SASL authentication support
- Capability negotiation (CAP)
- Message buffering and CRLF parsing

**Connection States:**
- `.disconnected` → `.connecting` → `.connected` → `.authenticating` → `.registered`
- Error handling with `.error(String)` state

**Based on HexChat Implementation:**
```c
// HexChat's proto-irc.c:irc_login
tcp_sendf (serv, "CAP LS 302\r\n");
if (serv->password[0] && serv->loginmethod == LOGIN_PASS) {
    tcp_sendf (serv, "PASS %s\r\n", serv->password);
}
tcp_sendf (serv, "NICK %s\r\nUSER %s 0 * :%s\r\n", 
    serv->nick, user, realname);
```

#### IRCMessage.swift
RFC 1459 message parsing and formatting.

**Message Format:**
```
[:prefix] COMMAND [param1] [param2] [:trailing param]
```

**Features:**
- Parse IRC messages into structured format
- Extract nick!user@host from prefix
- Handle trailing parameters (`:` prefix)
- Format messages for sending

### 2. Data Models (`Models/`)

#### IRCModels.swift
Core data structures using `@Observable` macro for SwiftUI reactivity.

**Models:**
- `IRCServer` - Server connection and channel list
- `IRCChannel` - Channel state, topic, users, messages
- `IRCUser` - User information with mode prefixes (@, +, etc.)
- `IRCChatMessage` - Individual messages with type, sender, timestamp

**Message Types:**
- `.message` - Regular PRIVMSG
- `.action` - /me commands
- `.notice` - NOTICE messages
- `.join`, `.part`, `.quit` - User events
- `.nick` - Nickname changes
- `.topic` - Topic updates
- `.system` - Client-side messages

#### ChatState.swift
Application state manager implementing `IRCConnectionDelegate`.

**Responsibilities:**
- Server and channel management
- Message routing from IRC protocol to UI
- IRC event handling (JOIN, PART, PRIVMSG, etc.)
- User list management (NAMES replies)

**Key IRC Handlers:**
- `handlePrivMsg` - Route messages to channels
- `handleJoin/Part/Quit` - User list updates
- `handleTopic` - Channel topic updates
- `handleNamesReply` - Parse RPL_NAMREPLY (353)

### 3. User Interface (`Views/`)

#### MainWindow.swift
Root view with NavigationSplitView.

**Layout:**
```
┌─────────────────────────────────────┐
│ Sidebar │ Detail (Chat)             │
│         │                           │
│ Servers │ Messages with Liquid Glass│
│ Channels│                           │
└─────────────────────────────────────┘
```

#### ChannelSidebarView.swift
Server and channel list with Liquid Glass effects.

**Liquid Glass Features:**
- `GlassEffectContainer(spacing: 8.0)` - Container for morphing effects
- `.glassEffect(.regular)` on channel rows
- `.buttonStyle(.glass)` for actions
- Refractive glass material on sidebar background

**Visual Hierarchy:**
- Server headers with connection status
- Channel rows with unread counts
- Liquid Glass capsule backgrounds

#### ChatView.swift
Main chat interface with three sections:

**Layout Components:**
1. **Channel Header** - Name, topic, user count
   - `.glassEffect(.regular.tint(.blue.opacity(0.3)))`
   
2. **Message List** - Scrollable message history
   - `.glassEffect(.regular)` background
   - Auto-scroll to bottom on new messages
   
3. **Message Input** - Text field with send button
   - `.glassEffect(.regular.interactive())` - Responds to touch
   - `.glassEffectID()` for morphing transitions

4. **User List** (toggleable) - Channel participants
   - Sorted by mode (ops → voiced → regular)
   - Slide-in/out animation

**Liquid Glass Transitions:**
```swift
GlassEffectContainer(spacing: 12.0) {
    // All glassed elements morph into each other
    header.glassEffectID("header", in: namespace)
    messages.glassEffectID("messages", in: namespace)
    input.glassEffectID("input", in: namespace)
}
```

#### MessageListView.swift
High-performance message rendering.

**Performance Optimizations:**
- `LazyVStack` for virtualized rendering
- `ScrollViewReader` for programmatic scrolling
- TextLayout API via `NSTextLayoutManager` (optional)
- Attributed strings for rich text (links, formatting)

**Message Row Features:**
- Timestamp (HH:MM format)
- Type-specific icons and colors
- Rich text with `.textSelection(.enabled)`
- Background tinting for system messages

**NSTextLayoutView (Advanced):**
- Uses TextKit 2's `NSTextLayoutManager` for optimal performance
- Efficient rendering of large chat histories
- Support for embedded images/emojis via text attachments
- Automatic text selection and accessibility

### 4. Liquid Glass Implementation

#### Material System

**SwiftUI Modifiers Used:**
```swift
.glassEffect()                          // Regular glass
.glassEffect(.regular.tint(.blue))      // Tinted glass
.glassEffect(.regular.interactive())    // Touch-responsive
.glassEffect(in: .rect(cornerRadius: 12)) // Custom shape
.buttonStyle(.glass)                    // Glass buttons
```

**Container for Morphing:**
```swift
GlassEffectContainer(spacing: 40.0) {
    // Views with .glassEffectID() morph during transitions
    // Spacing controls when shapes blend together
}
```

#### Glass Effect Properties

**From Apple Documentation:**
- Blurs content behind the view
- Reflects color and light from surroundings
- Reacts to touch and pointer in real-time (with `.interactive()`)
- Morphs between shapes during transitions
- Adapts to accessibility settings (reduced transparency/motion)

**Design Principles:**
- Use sparingly - only on functional elements (toolbars, controls)
- Brings focus to underlying content
- Maintain hierarchy with tinting and prominence
- Test with reduced transparency enabled

## Protocol Flow

### Connection Handshake

```
Client                          Server
  |                               |
  |--- CAP LS 302 --------------->|
  |<-- CAP * LS :capabilities ----|
  |                               |
  |--- CAP REQ :sasl ------------>| (if SASL available)
  |<-- CAP * ACK :sasl -----------|
  |                               |
  |--- PASS password ------------>| (if password auth)
  |                               |
  |--- NICK nickname ------------>|
  |--- USER user 0 * :realname -->|
  |                               |
  |--- CAP END ------------------>|
  |                               |
  |<-- 001 Welcome message -------|
  |<-- 002-004 Server info -------|
  |                               |
  |--- JOIN #channel ------------>|
  |<-- JOIN #channel -------------|
  |<-- 332 Topic -----------------|
  |<-- 353 Names -----------------|
  |<-- 366 End of names ----------|
```

### Message Flow

```
Network Layer           Protocol Layer          Model Layer            View Layer
    |                        |                       |                     |
PRIVMSG received ---------> IRCMessage.parse()       |                     |
    |                        |                       |                     |
    |                   handleIRCMessage() --------> ChatState             |
    |                        |                  handlePrivMsg()            |
    |                        |                       |                     |
    |                        |                  channel.messages      <----- 
    |                        |                    .append()          @Observable
    |                        |                       |                     |
    |                        |                       |              MessageListView
    |                        |                       |               auto-updates
```

## Performance Considerations

### Message Rendering
- Use `LazyVStack` for thousands of messages
- Consider `NSTextLayoutManager` for very large histories (10k+ messages)
- AttributedString caching for repeated formatting
- Virtualized scrolling prevents rendering off-screen content

### Network Efficiency
- Message buffering prevents send queue overflow
- Async receive loop with 4KB buffer
- CRLF-based message splitting handles partial receives
- Connection pooling for multiple servers

### State Management
- `@Observable` macro provides fine-grained reactivity
- Only changed properties trigger view updates
- Weak delegate references prevent retain cycles
- Background queue for network I/O

## Future Enhancements

### Protocol Features
- [ ] DCC file transfers
- [ ] CTCP responses (VERSION, TIME, etc.)
- [ ] Channel modes and user modes
- [ ] Away message tracking
- [ ] Message flood protection

### UI Features
- [ ] Multi-server connections
- [ ] Split view for multiple channels
- [ ] Message search and filtering
- [ ] Notification preferences
- [ ] Custom themes and fonts
- [ ] Emoji picker with skin tone support
- [ ] Image inline preview

### Advanced TextLayout
- [ ] Inline image rendering via text attachments
- [ ] Emoji rendering with high-quality assets
- [ ] Link preview cards
- [ ] Code syntax highlighting in messages
- [ ] Markdown formatting support

## References

### HexChat Source Files
- `common/server.c` - Connection management and handshake
- `common/proto-irc.c` - IRC protocol implementation (irc_login, capability negotiation)
- `common/inbound.c` - Message parsing and event handling

### Apple Documentation
- [Liquid Glass Overview](https://developer.apple.com/documentation/TechnologyOverviews/liquid-glass)
- [Applying Liquid Glass to custom views](https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views)
- [NSTextLayoutManager](https://developer.apple.com/documentation/AppKit/NSTextLayoutManager)
- [Network.framework](https://developer.apple.com/documentation/Network)

### IRC Specifications
- RFC 1459 - Internet Relay Chat Protocol
- RFC 2812 - Internet Relay Chat: Client Protocol
- IRCv3 - Modern IRC extensions (SASL, capabilities, etc.)
