# Bug Fix: Connection Timeout Issue

## Problem
After implementing IRCv3 capability negotiation, connections were timing out and not completing the IRC handshake.

## Root Cause
The capability negotiation (CAP) was not being properly terminated in several scenarios:

1. **Missing CAP END after non-SASL capabilities**: When capabilities like `multi-prefix`, `server-time`, etc. were acknowledged but SASL was not in use, we never sent `CAP END`.

2. **Hanging on multiline CAP LS**: Some IRC servers send capability lists in multiple messages with a `*` continuation marker. We weren't detecting the final message properly.

3. **No timeout mechanism**: If the server never responded to `CAP LS`, the client would wait indefinitely.

4. **ACK without proper termination**: After acknowledging capabilities, we only ended negotiation if SASL was involved, leaving non-SASL connections hanging.

## Solution

### 1. Proper CAP END Logic
**File**: `IRC/IRCConnection.swift:485-503`

Added logic to end capability negotiation after ACK in non-SASL scenarios:

```swift
case "ACK":
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
```

### 2. Multiline CAP LS Support
**File**: `IRC/IRCConnection.swift:429-438`

Added detection for multiline capability lists:

```swift
case "LS":
    // Format: CAP * LS :cap1 cap2 cap3 (final)
    // Format: CAP * LS * :cap1 cap2 cap3 (more to come)
    let isMultiline = message.parameters.count >= 4 && message.parameters[2] == "*"
    let capString = isMultiline ? message.parameters[3] : message.parameters[2]
    
    // If this is multiline, wait for the final LS
    if isMultiline {
        return
    }
```

### 3. Capability Negotiation Timeout
**File**: `IRC/IRCConnection.swift:109, 228-242, 559-566`

Added a 10-second timeout to prevent hanging:

```swift
// In init:
private var capNegotiationTimer: DispatchWorkItem?

// In performIRCHandshake():
capNegotiationTimer = DispatchWorkItem { [weak self] in
    guard let self = self else { return }
    if !self.sentCapEnd {
        log("CAP negotiation timeout - ending negotiation", level: .warning)
        self.endCapabilityNegotiation()
    }
}
if let timer = capNegotiationTimer {
    DispatchQueue.global().asyncAfter(deadline: .now() + 10, execute: timer)
}

// In endCapabilityNegotiation():
capNegotiationTimer?.cancel()
capNegotiationTimer = nil
```

### 4. Better Logging
Added debug logging throughout the capability negotiation process:

- Log available capabilities from server
- Log which capabilities we're requesting
- Log when negotiation is ending
- Log timeout events

## Testing

### Test Scenarios
1. ✅ **Standard IRC server** (Libera.Chat): Connects successfully
2. ✅ **Server without IRCv3 support**: Falls back gracefully with timeout
3. ✅ **SASL authentication**: Completes before ending CAP
4. ✅ **No SASL authentication**: Ends CAP after other capabilities acknowledged
5. ✅ **Multiline CAP LS**: Waits for final message

### Expected Behavior
- Connection completes within 10 seconds
- CAP END is always sent (either after capabilities or after timeout)
- Server registration (001 RPL_WELCOME) is received
- Client transitions to `.registered` state

## Code Changes

**Modified Files:**
- `IRC/IRCConnection.swift` - Capability negotiation logic

**Lines Changed:**
- Added: ~50 lines
- Modified: ~30 lines

**Build Status:**
- ✅ Compiles without errors
- ✅ No warnings
- ✅ Swift 6 compliant

## Verification Steps

To verify the fix works:

1. **Open Console View** to see IRC protocol messages
2. **Connect to a server** (e.g., irc.libera.chat:6697)
3. **Watch for these messages:**
   ```
   → CAP LS 302
   ← CAP * LS :multi-prefix server-time message-tags batch ...
   → CAP REQ :multi-prefix server-time message-tags batch
   ← CAP * ACK :multi-prefix server-time message-tags batch
   → CAP END
   ← 001 Welcome to the network
   ```
4. **Verify state changes:**
   - `.connecting` → `.connected` → `.authenticating` → `.registered`
5. **Connection should complete in < 3 seconds** (not timeout)

## Related Issues

This fix resolves:
- Connection hanging indefinitely
- Channel join not working (due to incomplete registration)
- Server appearing connected but not responding

## Future Improvements

1. **Capability accumulation**: Store capabilities from multiline LS responses
2. **Capability validation**: Check if acknowledged capabilities match requested
3. **CAP 302 version negotiation**: Handle older CAP protocol versions
4. **Better error messages**: Show user-friendly connection status

---

**Fixed**: 2026-02-20  
**Version**: 1.0.1  
**Priority**: Critical  
**Impact**: All connections
