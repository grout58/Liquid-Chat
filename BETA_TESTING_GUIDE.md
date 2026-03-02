# Liquid Chat - Beta Testing Guide

Welcome! Thank you for testing Liquid Chat, a modern IRC client for macOS 26 with Apple Intelligence features.

## Quick Start (5 Minutes)

### 1. First Launch
1. Right-click `Liquid Chat.app` and select "Open" (required for first launch)
2. Grant network permissions if macOS prompts you
3. The app will open to the main window

### 2. Connect to a Test Server
**Recommended Test Server:** Libera.Chat (friendly, active IRC network)

1. Click "+ Add Server" in the left sidebar
2. Fill in:
   - **Display Name:** Libera Chat
   - **Hostname:** irc.libera.chat
   - **Port:** 6697
   - **SSL:** ✅ (checked)
   - **Your Nickname:** (choose any unique name, e.g., "tester123")
   - **Real Name:** (your name or "Beta Tester")
3. Check "Save this server" and "Auto-connect on startup"
4. Click "Connect"

### 3. Join Your First Channel
1. Wait for "Connected" status (green dot)
2. Type: `/join #test`
3. Press Enter
4. You're now in #test channel!

## Features to Test

### Basic IRC Features ✅
- [x] **Send/Receive Messages:** Type in the bottom text field
- [x] **Join Channels:** `/join #channelname`
- [x] **Browse Channels:** Type `/list` then click the channel list button
- [x] **Private Messages:** Right-click a user in the user list → "Send Message"
- [x] **Search Messages:** Click the search icon (🔍) in toolbar
- [x] **Part Channel:** `/part` or close channel in sidebar

### AI Features 🤖
Try these in any active channel with ongoing conversation:

- **Smart Replies:** Click the sparkle button (✨) - AI suggests 3 contextual responses
- **Catch-Up Summary:** Click "Summarize" button - get summary of missed messages
- **Channel Recommendations:** Click "Recommend" button - AI suggests relevant channels

**Toggle AI features:** Settings (⚙️) > AI Features > Enable AI Features

### UI Features 🎨
- **Liquid Glass Effects:** Notice translucent materials throughout the app
- **Dark Mode:** Automatically follows system appearance
- **Split View:** Resize panels by dragging dividers
- **Console Logging:** View > Console (see raw IRC protocol messages)

## Common Commands

```
/join #channel        - Join a channel
/part                 - Leave current channel
/quit [message]       - Disconnect from server
/list                 - List all channels on server
/me does something    - Send an action message
/msg nickname text    - Send private message
```

## What to Look For

### Things That Should Work
- Smooth scrolling in chat
- Messages appear instantly
- No UI lag when typing
- Server reconnects if disconnected
- Settings save and persist
- Multiple channels work simultaneously

### Things to Report
- Any crashes or freezes
- Slow/laggy behavior
- UI elements that look wrong
- Confusing features or unclear buttons
- Missing features you expected
- Anything that "feels off"

## Test Scenarios

### Scenario 1: Active Chat Test (10 min)
1. Join a busy channel (try #libera or #help on Libera.Chat)
2. Send several messages
3. Let messages scroll by for a few minutes
4. Try search feature
5. Use smart reply suggestions
6. Leave and rejoin channel

### Scenario 2: Multi-Channel Test (15 min)
1. Join 5+ channels using /list
2. Switch between channels rapidly
3. Send messages in different channels
4. Check that messages appear in correct channel
5. Close some channels
6. Verify app doesn't slow down

### Scenario 3: AI Features Test (10 min)
1. Find an active channel with technical discussion
2. Wait for ~20 messages to accumulate
3. Click "Summarize" - does summary make sense?
4. Click "Smart Reply" - are suggestions relevant?
5. Click "Recommend" - are channel suggestions good?
6. Disable AI in settings - features should disappear

### Scenario 4: Stress Test (Optional)
1. Run `/list` on server (may return 5000+ channels)
2. Join 20+ channels
3. Send 100+ messages quickly (paste lorem ipsum)
4. Disconnect network, reconnect
5. Close and reopen app - does it restore state?

## Feedback Format

Please note:
- **macOS Version:** (e.g., macOS 26.1)
- **Mac Model:** (e.g., MacBook Pro M3)
- **Issue Description:** What happened?
- **Expected Behavior:** What should have happened?
- **Steps to Reproduce:** How to recreate the issue?
- **Screenshot/Video:** If possible

## Known Limitations

These are features not yet implemented:
- File transfers (DCC)
- System notifications
- Custom themes beyond light/dark
- Inline image previews
- Nickname auto-completion with Tab
- Pastebin integration
- Bouncer (ZNC/Soju) support

## Troubleshooting

### "Can't connect to server"
- Check your internet connection
- Try changing port to 6667 and disable SSL
- Some networks may block IRC ports

### "Nickname already in use"
- Choose a different nickname
- Wait a few minutes and try again

### App runs slowly
- Check how many channels you've joined
- Try closing unused channels
- Disable AI features in settings if needed

### Messages not appearing
- Check if you're in the correct channel
- Verify server is still connected (green dot)
- Try leaving and rejoining channel

## Privacy & Security

- **All chat is encrypted in transit** (SSL/TLS)
- **No data is sent to external services** except IRC servers
- **AI features run entirely on-device** using Apple Intelligence
- **Logs are stored locally** in `~/Library/Application Support/Liquid Chat/Logs/`

## Getting Help

If you encounter issues:
1. Check Console.app for crash logs (search "Liquid Chat")
2. Take screenshots of the problem
3. Note exact steps that caused the issue
4. Send feedback with details above

## Have Fun!

IRC is a 50+ year old protocol with a vibrant community. Explore channels on topics you love:
- **Programming:** #python, #javascript, #rust
- **Linux:** #linux, #debian, #archlinux
- **Gaming:** #gaming, #minecraft, #pokemon
- **General:** #chat, #lobby, #general

**Popular IRC Networks:**
- Libera.Chat (irc.libera.chat:6697) - Open source projects
- OFTC (irc.oftc.net:6697) - Debian, FOSS projects
- IRCnet (irc.ircnet.com:6667) - General chat
- EFnet (irc.efnet.org:6697) - Original IRC network

---

**Thank you for testing Liquid Chat! Your feedback helps make it better.**
