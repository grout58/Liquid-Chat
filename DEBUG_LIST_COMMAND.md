# Debugging /list Command Issues

## Current Status

The `/list` command has been significantly improved with:
1. ✅ Async processing to prevent UI freezes
2. ✅ Thread-safe buffering with proper MainActor handling
3. ✅ Comprehensive logging to track data flow
4. ✅ 5,000 channel display limit
5. ✅ Progress indicators and status messages

## Changes Made

### File: `IRCModels.swift`
**Issue:** `@MainActor` methods being called from background threads causing deadlocks

**Fix:**
```swift
func bufferChannelListEntry(_ entry: IRCChannelListEntry) {
    // Now wraps in Task { @MainActor } to safely hop to main thread
    Task { @MainActor in
        channelListBuffer.append(entry)
        // Batches every 50ms with progress logging
    }
}
```

### File: `ChatState.swift`
**Added Comprehensive Logging:**
- "LIST START received" - When 321 message arrives
- "LIST END received" - When 323 message arrives
- "Loaded X channels..." - Every 1000 channels
- "Sorting X channels..." - Before sort operation
- "✓ Channel list sorted: X channels ready" - Success
- "⚠️ No channels received!" - If empty list

### File: `ChannelListView.swift`
**Async Filtering:**
- Background thread processing for filter/sort
- Value capture to avoid concurrency issues
- 5,000 channel limit with warning message

## How to Debug

### Step 1: Enable Console Logging
1. Open the app
2. Go to Settings > Advanced
3. Enable "Console Logging"
4. Set log level to "Debug"

### Step 2: Connect and Test
1. Connect to an IRC server (e.g., irc.libera.chat)
2. Join any channel
3. Type `/list` in the chat

### Step 3: Check Console Output
Open **ConsoleView** (View menu or toolbar) and look for:

**Expected Success Flow:**
```
[IRC] LIST START received
[IRC] Loaded 1000 channels...
[IRC] Loaded 2000 channels...
[IRC] Loaded 3000 channels...
[IRC] LIST END received
[IRC] Flushed final batch: 3456 total channels
[IRC] Sorting 3456 channels...
[IRC] ✓ Channel list sorted: 3456 channels ready
```

**If Hanging - Look For:**
```
[IRC] LIST START received
[IRC] (no more messages)
```
→ **Server not sending channel list** - Try different server or check network

```
[IRC] LIST START received
[IRC] Loaded 1000 channels...
(hangs here)
```
→ **Buffering issue** - Check MainActor logs for deadlock

```
[IRC] LIST END received
[IRC] Flushed final batch: 0 total channels
[IRC] ⚠️ No channels received!
```
→ **Messages received but not parsed** - Check IRC message parsing

### Step 4: Network Analysis
If channels aren't loading, check raw IRC traffic:

```bash
# In Terminal, monitor IRC connection
nc irc.libera.chat 6667
NICK TestUser
USER testuser 0 * :Test User
JOIN #test
LIST
```

Look for responses like:
```
:server 321 TestUser Channel :Users  Name
:server 322 TestUser #channel 42 :Channel topic
:server 322 TestUser #another 123 :Another topic
:server 323 TestUser :End of /LIST
```

## Common Issues

### Issue 1: "App hangs immediately"
**Cause:** Deadlock between background IRC thread and MainActor

**Check:**
- Look for "LIST START received" in console
- If it appears, buffering is working
- If it doesn't appear, IRC message handler isn't triggering

**Fix:** Already implemented in current code (Task wrapping)

### Issue 2: "Channels load but UI freezes"
**Cause:** Too many channels overwhelming UI

**Check:**
- Console shows "Loaded X channels..."
- X is > 10,000

**Fix:** Already implemented (5,000 limit in ChannelListView)

### Issue 3: "Dialog opens but stays empty"
**Cause:** Either no messages received OR messages not reaching ChatState

**Check:**
1. Console for "LIST START received"
2. If not present: IRC connection issue
3. If present but no "Loaded": handleList() not being called

**Fix:**
```swift
// In ChatState.swift, line 241-242
case "322": // RPL_LIST
    handleList(message, server: server)
```

### Issue 4: "Loading spinner stuck"
**Cause:** LIST END never received or isLoadingChannelList not updated

**Check:**
- Console for "LIST END received"
- If missing: Server not sending RPL_LISTEND (323)

**Fix:** Add timeout in ChannelListView:
```swift
.onAppear {
    updateFilteredChannels()
    
    // Add timeout for loading state
    Task {
        try? await Task.sleep(for: .seconds(30))
        if server.isLoadingChannelList {
            ConsoleLogger.shared.log("LIST timeout - forcing end", level: .warning, category: "IRC")
            await MainActor.run {
                server.isLoadingChannelList = false
            }
        }
    }
}
```

## Performance Metrics

### Target Performance
- **Small networks (< 100 channels):** Instant
- **Medium networks (100-1000 channels):** < 1 second
- **Large networks (1000-10000 channels):** 1-3 seconds
- **Huge networks (10000+ channels):** 3-5 seconds (limited to 5000 display)

### Current Implementation
- Batching: Every 50ms
- Buffer size: Unlimited (until flush)
- Sort: O(n log n) on background thread
- Display limit: 5,000 channels

## Testing Checklist

- [ ] Connect to small network (e.g., local server)
- [ ] Type `/list` - should load instantly
- [ ] Connect to Libera.Chat (50,000+ channels)
- [ ] Type `/list` - should show progress
- [ ] Verify 5,000 channel warning appears
- [ ] Check console for all expected log messages
- [ ] Test search/filter with large list
- [ ] Test sort toggle (Users vs Name)
- [ ] Verify no app hangs or freezes

## Code Locations

**IRC Command Handler:**
- File: `IRC/IRCCommandHandler.swift`
- Line: 165-168
- Sends `LIST` command and shows dialog

**Message Routing:**
- File: `Models/ChatState.swift`
- Lines: 238-245
- Routes 321/322/323 to handlers

**List Handlers:**
- File: `Models/ChatState.swift`
- Lines: 432-476
- handleListStart, handleList, handleListEnd

**Buffering:**
- File: `Models/IRCModels.swift`
- Lines: 81-147
- Thread-safe batch updates

**UI Display:**
- File: `Views/ChannelListView.swift`
- Lines: 36-75
- Async filtering and display

## Next Steps If Still Broken

1. **Add breakpoints:**
   - `IRCCommandHandler.swift:166` (LIST command sent)
   - `ChatState.swift:239` (321 message received)
   - `ChatState.swift:242` (322 message received)
   - `ChatState.swift:245` (323 message received)

2. **Check IRC message parsing:**
   - Add breakpoint in `IRCMessage.parse()`
   - Verify 321/322/323 are being parsed correctly
   - Check parameters array contains channel data

3. **Enable verbose IRC logging:**
   - In `IRCConnection.swift`, log ALL received messages
   - Verify server is actually sending LIST responses

4. **Test with different servers:**
   - Libera.Chat: Large (50k+ channels)
   - OFTC: Medium (5k channels)
   - Local server: Small (< 100 channels)

## Contact & Support

If issue persists after these steps:
1. Export console logs
2. Note which server you're connecting to
3. Provide steps to reproduce
4. Include any error messages from console

---

**Last Updated:** February 23, 2026  
**Status:** Improved with comprehensive logging  
**Build:** Successful, 0 errors, 0 warnings
