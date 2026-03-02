# Testing Guide: /list Command Debugging

## Quick Test Procedure

### 1. Enable Console Logging
1. Open Liquid Chat
2. Go to **Settings** (Cmd+,)
3. Navigate to **Advanced** tab
4. Set **Console Logging Level** to **Debug**
5. Click **OK**

### 2. Connect to Test Server
1. Connect to a known-good IRC server (e.g., `irc.libera.chat:6697`)
2. Wait for connection to complete
3. Join a test channel (e.g., `/join #test`)

### 3. Execute /list Command
1. In the message input field, type: `/list`
2. Press Enter
3. Watch for the channel list dialog to appear

### 4. Check Console Logs
Look for this expected log sequence in the Xcode console:

```
[IRC] → LIST
[UI] ChannelListView appeared for server: irc.libera.chat
[IRC] LIST message: 321 with 2 params
[IRC] LIST START received
[IRC] LIST message: 322 with 4 params
[IRC] LIST message: 322 with 4 params
[IRC] LIST message: 322 with 4 params
... (many 322 messages) ...
[IRC] Loaded 1000 channels...
[UI] Channel count changed: 0 → 1000
[IRC] Loaded 2000 channels...
[UI] Channel count changed: 1000 → 2000
... (continues) ...
[IRC] LIST message: 323 with 1 param
[IRC] LIST END received
[IRC] Flushed final batch: 5234 total channels
[IRC] Sorting 5234 channels...
[IRC] ✓ Channel list sorted: 5234 channels ready
[UI] Display updated with 5000 channels
```

## Diagnosing Issues

### If You See No Logs:
- Console logging not enabled properly
- Recheck Settings > Advanced > Console Logging Level

### If Logs Stop at "→ LIST":
- IRC server not responding
- Check network connection
- Try different server

### If Logs Stop at "LIST START received":
- Server acknowledged but not sending data
- Server may have /list disabled
- Try: `/list >10` (channels with 10+ users only)

### If Logs Show 322 Messages But UI Doesn't Update:
- Check for: "Channel count changed" logs
- If missing: SwiftUI observation broken
- Check for: "Display updated with X channels"
- If missing: ChannelListView not receiving updates

### If Logs Stop Mid-Stream:
- Look at the last log message
- Check for error messages
- Note the channel count where it stopped

### If "Loading..." Never Disappears:
- 30-second timeout should trigger
- Look for: "Channel list loading timeout - forcing completion"
- If you see this: Server never sent LIST END (323)

## Performance Notes

- **Large Lists**: Lists with 10,000+ channels may take 5-10 seconds to process
- **Display Limit**: Only first 5,000 channels are displayed (safety limit)
- **Batching**: Channels are added in batches of ~50ms to prevent UI freeze
- **Sorting**: Final sort happens in background thread

## What Was Fixed

1. **Thread-Safe Buffering**: Channel entries buffered asynchronously to prevent MainActor deadlock
2. **Async Processing**: Filtering and sorting moved to background threads
3. **Batched Updates**: UI updates happen in 50ms batches instead of per-channel
4. **Timeout Protection**: 30-second timeout prevents infinite loading
5. **Progress Logging**: Every 1000 channels logged for visibility
6. **Display Limit**: Hard limit of 5000 channels prevents UI overload

## If Problem Persists

Share the console log output showing where the logs stop. This will pinpoint the exact failure location:

1. Copy all logs from `/list` command through to end (or where it hangs)
2. Look for the last log message before hang
3. Note any error messages or warnings
4. Check if timeout message appears after 30 seconds

## Alternative Testing

If `/list` hangs on all servers, try:
- `/list #python` (list only channels matching "python")
- `/list >100` (list only channels with 100+ users)
- Use a smaller IRC network with fewer channels

## Expected Behavior

✅ **Success Looks Like:**
- Dialog appears within 1-2 seconds
- Progress shown as channels load
- List populates progressively
- Search and sort work smoothly
- No UI freeze or beach ball

❌ **Failure Looks Like:**
- App freezes/beach ball appears
- Dialog never appears
- "Loading..." never completes
- Console shows no progress logs
- Logs stop mid-stream

---

**Created**: 2026-02-23  
**Purpose**: Diagnose /list command hanging issue with comprehensive logging
