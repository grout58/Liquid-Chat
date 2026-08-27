# Liquid Chat - Modern IRC Client Implementation Plan

## Status Overview

### ✅ Implemented

1. **IRC Protocol (RFC 1459 / 2812)**
   - Connection management with Network.framework, TLS by default (6697)
   - Full registration handshake (CAP LS 302 → PASS/NICK/USER → CAP END)
   - RFC-validated message parser (`IRC/IRCMessage.swift`): commands must be
     letters or 3-digit numerics; bare commands, empty trailing params, and
     trailing-whitespace preservation are all covered by `IRCParserTests`
   - Outgoing sanitization: CR/LF stripped from parameters; `sendMessage`
     splits multiline/oversized text into ≤510-byte PRIVMSGs per line
   - PING/PONG both directions: server PINGs answered (bare PING included);
     client-side keepalive PINGs after 60s idle, unanswered-for-120s marks
     the connection dead (`IRC.pingInterval` / `IRC.pingTimeout`); round-trip
     lag surfaced as `IRCConnection.lastLagMs` and shown in the sidebar
   - EOF and receive errors tear the socket down so reconnect logic runs
   - Latin-1 fallback for non-UTF-8 lines; 1MB receive-buffer cap

2. **IRCv3**
   - Capabilities requested when advertised: `multi-prefix`, `server-time`,
     `message-tags`, `batch`, `sasl`, `znc.in/playback`,
     `soju.im/bouncer-networks`(+`-notify`)
   - Multiline `CAP LS 302` accumulation (values like `sasl=PLAIN` handled)
   - Message tags parsed with spec unescaping (`\:` `\s` `\\` `\r` `\n`)
   - server-time drives message timestamps; batches buffered (2000-message
     cap, flushed on disconnect) and rendered with a "replayed history" rule
   - SASL PLAIN (with 400-byte AUTHENTICATE chunking) and SASL EXTERNAL
     (presents a Keychain client identity as the TLS local identity;
     configured per-server via `clientCertificateName`)
   - SASL numerics: 900/903 success, 902/904–908 failure/abort
   - RPL_ISUPPORT (005) negotiation (`Models/IRCISupport.swift`): PREFIX,
     CHANMODES A/B/C/D argument categories, CHANTYPES, CASEMAPPING
     (rfc1459 + ascii), NETWORK — drives NAMES prefix parsing, MODE argument
     consumption, channel-vs-query detection, and name folding

3. **Bouncers**
   - ZNC: `*status`/`*playback` pseudo-users routed to console channels;
     playback requested after 001 (never pre-registration)
   - Soju `bouncer-networks`: controller connection lists networks
     (`BOUNCER LISTNETWORKS`), sidebar shows them with upstream-state dots,
     "Open" spawns a bound connection that sends `BOUNCER BIND <netid>`
     during registration (`Models/BouncerNetwork.swift`)

4. **State & correctness invariants** (`Models/ChatState.swift`)
   - All channel/nick lookups use the server's casemapping
     (`IRCISupport.fold`, `IRCServer.channel(named:)`,
     `IRCChannel.userIndex(named:)`) — never compare names with `==`
   - `currentNickname` is authoritative from 001 / NICK echoes only;
     433 retries track `attemptedNickname` separately
   - NAMES bursts replace the user list (first 353 clears, 366 ends);
     prefix symbols map to mode letters so `@`/`+`/`~`/`&`/`%` display
   - CTCP: incoming ACTION rendered as action; VERSION/PING answered
   - NOTICE routed like PRIVMSG (server notices → server console channel)
   - Reconnect: exponential backoff 5s→300s that survives failed attempts,
     single-scheduled, skipped after manual disconnect (`/quit` counts as
     manual); instant reconnect on wake-from-sleep and network restoration
     (`startSystemMonitors`)
   - Old connections are torn down before replacement (no socket leaks)

5. **UI/UX**
   - Liquid Glass design system; NavigationSplitView; user list with full
     prefix ladder; per-conversation unread + mention badges
   - Tab completion that cycles matches on repeated Tab (colon only at
     line start); ⌘K clear; ⌥⌘↑/↓ channel navigation; ⌥⌘U next unread;
     ⌘T join; ⌘N new connection (Channel menu in `Liquid_ChatApp.swift`)
   - Message list: O(n) grouping with O(1) row lookups, collapsed status
     events, auto-scroll only while pinned to bottom
   - Text pipeline: mIRC formatting codes stripped and URLs linkified once
     at ingest (`IRCTextFormatter`); word-boundary mention detection
     (`String.containsNick`)
   - URL previews: opt-in-able setting, 512KB/HTML-only cap, in-flight
     dedup, LRU cache
   - Notifications: suppressed only when the channel is visible AND the app
     is active; click focuses the channel; inline Reply action sends from
     the banner; grouped per conversation; permission requested lazily
     (`Utilities/NotificationManager.swift`)
   - Dock badge: unread DMs + channels with mentions
   - App termination sends QUIT everywhere and closes log handles
     (`AppDelegate` in `Liquid_ChatApp.swift`)

6. **Persistence & automation**
   - `ChannelLogger` actor: per-day log files under Application Support,
     stale-handle recovery, handles closed on quit; both sent and received
     messages logged
   - `ServerConfigManager` (@MainActor): saved servers in UserDefaults,
     passwords in Keychain (`KeychainManager`), auto-connect on launch
   - `IRCCommandHandler`: /join /part /topic /whois /msg /me /notice
     /mode /op /voice /kick /ban /nick /quit /away /list /names /clear …

7. **AI features (macOS 26 Apple Intelligence)**
   - Catch-up summarizer, channel recommender, smart replies

### 🚧 Remaining Work

1. **DCC file transfers** — not started; design the security model first
   (explicit accept, no auto-accept, sanitized filenames, size caps)
2. **Soju network management** — ADDNETWORK/CHANGENETWORK/DELNETWORK UI
   (discovery + BIND are done)
3. **TextKit 2 message view** — only needed for >10k-message flood
   scenarios; ingest-time caching covers normal use (the `NSTextLayoutView`
   stub in MessageListView is unused)
4. **Certificate pinning / custom CA options** for TLS
5. **iOS/iPadOS adaptation, CloudKit sync, widgets, Shortcuts**

## Testing

Run the suite (needs Xcode; use DEVELOPER_DIR if xcode-select points at CLT):

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild test -project "Liquid Chat.xcodeproj" -scheme "Liquid Chat" -destination 'platform=macOS' -only-testing:"Liquid ChatTests" CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO DEVELOPMENT_TEAM=
```

174 tests across parser, ISUPPORT, casemapping/mention semantics, bouncer
attributes, DCC offer parsing/sanitization, connection integration
(MockIRCConnection), real-socket integration (`LoopbackIRCTests`),
settings, and server persistence. Conventions learned the hard way:

- `AppSettingsTests` and `ServerConfigManagerTests` are `.serialized` —
  they share a UserDefaults domain that each test's `init()` clears
- Never assert with `array[0]` in tests — a trap kills the shared test
  host and cascades "Crash" failures onto unrelated tests; use `first?`
- `IRCMessage.format` always colon-prefixes the trailing parameter
- Theme rawValues are capitalized ("Dark", not "dark")

### Manual testing still worth doing
- [ ] Live connect to Libera.Chat (SASL PLAIN + EXTERNAL)
- [ ] ZNC playback and Soju BIND against real bouncers
- [ ] Sleep/wake and Wi-Fi-switch reconnect behavior
- [ ] Notification reply while app is quit… backgrounded
- [ ] 1000+ message channels for scroll performance

## Handoff: where the last session stopped

Everything through DCC receive is implemented, committed, and covered by
174 passing tests (including real-socket `LoopbackIRCTests`). **No code
work is pending.** The immediate next step is the first item above — the
app has never exchanged bytes with a real ircd, so the live smoke test is
what validates the stack end to end.

Build and launch:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild build -project "Liquid Chat.xcodeproj" -scheme "Liquid Chat" -destination 'platform=macOS' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO DEVELOPMENT_TEAM=
open ~/Library/Developer/Xcode/DerivedData/Liquid_Chat-*/Build/Products/Debug/"Liquid Chat.app"
```

Smoke-test script: ⌘N → `irc.libera.chat`, port 6697, SSL on, auth None →
Connect. Then confirm, in order:

1. Sidebar header goes green and shows **Libera.Chat** (005 NETWORK parsed)
2. A **"NN ms"** lag readout appears after ~60s idle (keepalive round-trip)
3. `/join #libera-sandbox` populates the user list with `@`/`+` prefixes
   (NAMES prefix→mode mapping)
4. Tab cycles through matching nicks; a 2–4 line paste arrives as separate
   messages rather than one mangled line
5. The Console panel (toolbar) shows the raw `→`/`←` protocol trace — the
   place to look first if anything misbehaves

After that, the open feature work is: DCC **send** (needs a listening-socket
/ NAT design decision first), Soju ADDNETWORK/CHANGENETWORK/DELNETWORK UI,
and the TextKit 2 message view.

## Build & Versioning

- `MARKETING_VERSION` (CFBundleShortVersionString) is the human-facing
  version and is bumped by hand in the project settings.
- `CFBundleVersion` is stamped at build time by
  `Scripts/stamp-build-number.sh`, wired up as the "Stamp Build Number"
  run-script phase on the app target. It uses `git rev-list --count HEAD`,
  so the build number increments with every commit, is identical for the
  same checkout on any machine, and needs no project-file churn.
- The script also writes `LCSourceVersion` (`git describe --always --dirty`)
  so a build made from uncommitted work is identifiable after the fact.
- `CURRENT_PROJECT_VERSION` in the project file is only the fallback used
  when git is unavailable; the script overwrites it in the built product.
- The phase runs after `ProcessInfoPlistFile` and before `CodeSign`, so the
  signature stays valid. It needs `ENABLE_USER_SCRIPT_SANDBOXING = NO` on
  the app target (the script reads `.git`); the test targets keep the
  sandbox on.

## Architecture Notes

### Threading model (do not regress)
- `IRCConnection` protocol state (`receiveBuffer`, CAP state, batches,
  keepalive, `attemptedNickname`) is owned by `receiveQueue`; UI-facing
  properties (`state`, `currentNickname`, `lastLagMs`,
  `supportsBouncerNetworks`) are mutated only via main-thread hops
- The CAP timeout and keepalive timers run on `receiveQueue`, never a
  global queue
- `ChatState` is `@MainActor`; delegate callbacks hop via `Task { @MainActor }`
- Project uses `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (Swift 5 mode)

### IRC protocol quirks encoded in the implementation
- Channel names can start with # & (and per-005 CHANTYPES); nicknames can
  contain `[]{}\|^`-` — always compare via `IRCISupport.fold`
- Casemapping rfc1459: `[]\^` are uppercase of `{}|~`
- ZNC PASS format: `user/network:password`
- `BOUNCER BIND` must be sent during registration (after CAP ACK, before
  CAP END completes registration)
- PRIVMSG to ZNC modules is rejected before 001
- A 400-byte-exact SASL payload needs a trailing `AUTHENTICATE +`

### Liquid Glass / macOS 26–27 design rules
- **Layering is the rule that matters**: Liquid Glass belongs to the
  navigation layer that floats *above* content — toolbars, the search
  overlay, the message input. It does **not** go on content containers.
  The message list and user list deliberately have no `.glassEffect()`;
  re-adding it there is a regression, not a polish.
- Never stack glass on glass, or glass on a `.ultraThinMaterial`
  background — one treatment per surface.
- Don't mix `.regular` and `.clear` variants in the same interface.
- Morphing containers need `.glassEffectID()` on all children.
- Test with Accessibility > Reduce Transparency enabled; if the layout
  falls apart, the glass was decoration rather than structure.
- Toolbar groups carry `.visibilityPriority` (macOS 26.1+): core view
  controls are `.high`, the AI actions are `.low` so they collapse first
  in a narrow window.

### App icon
- `Liquid Chat/AppIcon.icon` is an Icon Composer document (the format
  introduced with macOS 26): `icon.json` plus layer art in `Assets/`. The
  system draws the squircle, shadow, specular highlights, and the
  light/dark/tinted renditions — the source art is just the glyph on a
  fill, and must not draw its own squircle or shadow.
- It is picked up automatically by the synchronized file group and wins
  over the asset catalog because both are named `AppIcon`.
- `Assets.xcassets/AppIcon.appiconset` is kept only as the fallback for
  Xcode 26, which ignores `.icon` files. Xcode 27+ uses the `.icon`.
- **A rebuilt icon usually still shows the old one.** macOS caches app
  icons in IconServices by bundle path, so the Dock and Finder keep
  serving the previous icon even though the bundle is correct — verify
  the bundle with `assetutil --info .../Assets.car` (look for
  `AppIcon/Group` and `AppIcon_Assets/*` entries) before suspecting the
  build. `Scripts/refresh-icon-cache.sh` clears it without sudo
  (re-register, restart iconservicesagent, restart the Dock).
- Preview any rendition without opening Icon Composer:
  `"/Applications/Xcode-beta.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool" "Liquid Chat/AppIcon.icon" --export-image --output-file /tmp/icon.png --platform macOS --rendition Dark --width 512 --height 512 --scale 1 --design-generation 27`

## Resources

- RFC 1459 / RFC 2812; IRCv3: https://ircv3.net/
- soju.im/bouncer-networks: https://soju.im/doc/bouncer-networks.html
- Liquid Glass: https://developer.apple.com/documentation/TechnologyOverviews/liquid-glass
- Reference clients: HexChat (External/HexChat), Textual, Irssi

---

**Last Updated:** 2026-08-25
**Version:** 2.0
**Maintainer:** Claude Agent
