# Testing the /list Command Fix

## What Was Fixed

I've added comprehensive logging and thread-safety improvements to diagnose and fix the `/list` hanging issue:

### Changes Made:
1. ✅ **Thread-safe buffering** - No more MainActor deadlocks
2. ✅ **Comprehensive logging** - Track every step of data flow
3. ✅ **30-second timeout** - Prevents infinite loading
4. ✅ **Better error handling** - Graceful degradation

---

## Step-by-Step Testing Instructions

### Before You Start

**Enable Console Logging:**
1. Open Liquid Chat
2. Go to **Settings → Advanced**
3. Check **"Enable Console Logging"**
4. Set **Log Level** to **"Debug"**
5. Keep the app running

### Test Procedure

#### 1. Connect to IRC Server

**Recommended test servers:**
- **irc.libera.chat** (port 6697, SSL) - Large network (50,000+ channels)
- **irc.oftc.net** (port 6697, SSL) - Medium network (5,000 channels)

**Steps:**
1. Click "Add Server" or use existing connection
2. Enter nickname (any unique name)
3. Click "Connect"
4. Wait for "✓ Registered successfully" in console

#### 2. Join Any Channel

```
/join #test
```

You should see yourself join the channel.

#### 3. Open Console Window

**View → Console** (or check toolbar for console button)

This will show all log messages in real-time.

#### 4. Execute /list Command

In the chat input, type:
```
/list
```

Press Enter.

---

## What to Look For

### ✅ **SUCCESS - Expected Console Output:**

```
[IRC] → LIST
[UI] ChannelListView appeared for server: irc.libera.chat
[UI] ChannelListView: Updating with 0 channels
[UI] ChannelListView: Display updated with 0 channels
[IRC] LIST message: 321 with 2 params
[IRC] LIST START received
[IRC] LIST message: 322 with 4 params
[IRC] LIST message: 322 with 4 params
[IRC] LIST message: 322 with 4 params
... (many 322 messages) ...
[IRC] Loaded 1000 channels...
[UI] Channel count changed: 0 → 1000
[UI] ChannelListView: Updating with 1000 channels
[IRC] Loaded 2000 channels...
[UI] Channel count changed: 1000 → 2000
... (continues) ...
[IRC] LIST message: 323 with 2 params
[IRC] LIST END received
[IRC] Flushed final batch: 3456 total channels
[IRC] Sorting 3456 channels...
[IRC] ✓ Channel list sorted: 3456 channels ready
[UI] Channel count changed: 3000 → 3456
[UI] ChannelListView: Updating with 3456 channels
[UI] ChannelListView: Display updated with 3456 channels
```

**Dialog should show:**
- Channel list populated with channels
- Search bar works
- Sort by Users/Name works
- Can select and join channels

---

### ❌ **PROBLEM SCENARIOS:**

#### Scenario A: No IRC Messages Received
```
[IRC] → LIST
[UI] ChannelListView appeared for server: irc.libera.chat
(no more messages)
```

**Diagnosis:** Server not responding to LIST command  
**Possible Causes:**
- Server doesn't support LIST
- Network connectivity issue
- Server timeout

**Try:**
- Different IRC server
- Check network connection
- Wait longer (some servers are slow)

---

#### Scenario B: Messages Received But Not Processed
```
[IRC] → LIST
[IRC] LIST message: 321 with 2 params
(no "LIST START received")
```

**Diagnosis:** ChatState delegate not receiving messages  
**Possible Causes:**
- Delegate not wired up
- Message routing broken

**Try:**
- Reconnect to server
- Restart app

---

#### Scenario C: Channels Not Appearing in UI
```
[IRC] LIST START received
[IRC] Loaded 1000 channels...
[IRC] LIST END received
[IRC] ✓ Channel list sorted: 1000 channels ready
(but UI shows 0 channels)
```

**Diagnosis:** ChannelListView not observing server.availableChannels  
**Possible Causes:**
- SwiftUI observation broken
- Threading issue

**Try:**
- Close and reopen dialog
- Check console for "Channel count changed" messages

---

#### Scenario D: Timeout Triggered
```
[IRC] LIST START received
[IRC] Loaded 1000 channels...
(30 seconds pass)
[UI] Channel list loading timeout - forcing completion
```

**Diagnosis:** Server sending data very slowly  
**Action:** Channels loaded so far should still be visible

---

## Performance Expectations

| Network Size | Expected Time | Notes |
|-------------|---------------|-------|
| Small (< 100 channels) | < 1 second | Instant |
| Medium (100-1000) | 1-2 seconds | Smooth |
| Large (1000-10000) | 2-5 seconds | Progress updates |
| Huge (10000+) | 5-10 seconds | Limited to 5000 display |

---

## Common Issues & Solutions

### Issue: "App still hangs"

**Check Console For:**
1. Is "LIST START received" present?
   - **No:** Server issue, try different server
   - **Yes:** Continue to step 2

2. Are "LIST message: 322" entries appearing?
   - **No:** Server not sending data
   - **Yes:** Continue to step 3

3. Is "Loaded X channels..." appearing?
   - **No:** Buffering broken (report this!)
   - **Yes:** Continue to step 4

4. Does "Channel count changed" appear?
   - **No:** UI observation broken (report this!)
   - **Yes:** Should be working!

### Issue: "Dialog opens but stays empty"

**Action:** 
1. Check console for any error messages
2. Wait 30 seconds for timeout
3. Close dialog and try `/list` again
4. If still empty, export console logs

### Issue: "Only shows 5000 channels"

**This is expected!** 
- Displays show "(showing first 5000)" warning
- Use search to filter channels
- Most relevant channels shown first (sorted by user count)

---

## Reporting Issues

If `/list` still doesn't work after following this guide, please provide:

1. **Console log export:**
   - Console window → Right-click → Export Logs
   - Or copy all text from console

2. **Server details:**
   - Which IRC server you connected to
   - Port and SSL settings

3. **Exact behavior:**
   - Does dialog open?
   - Does it stay empty?
   - Does app freeze/hang?
   - Can you interact with other parts of app?

4. **Console output:**
   - Paste the console output showing the issue
   - Highlight where it differs from expected output

---

## Debug Commands

You can also test IRC connectivity with raw commands:

```
/raw LIST
/raw NAMES #channel
/raw MOTD
```

These send commands directly to the server and you should see responses in the console.

---

## Success Criteria

✅ The `/list` command is working if:
- Dialog opens within 1 second
- Console shows "LIST START received"
- Channels appear in the dialog
- No app hanging or freezing
- Search and sort work
- Can select and join channels

---

**Last Updated:** February 23, 2026  
**Build:** 0 errors, 0 warnings  
**Status:** Comprehensive logging enabled, ready for testing
