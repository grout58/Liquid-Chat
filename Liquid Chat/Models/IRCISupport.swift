//
//  IRCISupport.swift
//  Liquid Chat
//
//  Server feature advertisement from RPL_ISUPPORT (005)
//

import Foundation

/// What the server advertised in RPL_ISUPPORT (005). Defaults cover servers
/// that never send one, matching the common superset (qaohv prefixes, #& channels).
struct IRCISupport: Equatable {
    /// Membership prefix mode letters in rank order (e.g. "qaohv")
    var prefixModes: [Character] = ["q", "a", "o", "h", "v"]
    /// Prefix symbols in the same rank order (e.g. "~&@%+")
    var prefixSymbols: [Character] = ["~", "&", "@", "%", "+"]

    /// CHANMODES categories: type A list modes (always take an argument)
    var listModes: Set<Character> = ["b", "e", "I"]
    /// Type B: always take an argument
    var alwaysArgModes: Set<Character> = ["k"]
    /// Type C: take an argument only when being set
    var argWhenSetModes: Set<Character> = ["l", "f", "j"]

    /// Characters that begin a channel name
    var chantypes: Set<Character> = ["#", "&"]

    var casemapping: String = "rfc1459"
    var network: String?

    /// NAMES prefix symbol → membership mode letter (e.g. "@" → "o")
    var symbolToMode: [Character: Character] {
        Dictionary(zip(prefixSymbols, prefixModes), uniquingKeysWith: { first, _ in first })
    }

    func isChannelName(_ name: String) -> Bool {
        name.first.map(chantypes.contains) ?? false
    }

    /// Fold a name for comparison per the server's advertised casemapping:
    /// "ascii" is plain lowercasing; anything else uses the rfc1459 rules.
    func fold(_ name: String) -> String {
        casemapping == "ascii" ? name.lowercased() : name.ircCasemapped
    }

    /// Whether this channel-mode character consumes a parameter in a MODE line.
    func modeTakesArgument(_ mode: Character, whenAdding adding: Bool) -> Bool {
        if prefixModes.contains(mode) { return true }
        if listModes.contains(mode) || alwaysArgModes.contains(mode) { return true }
        return adding && argWhenSetModes.contains(mode)
    }

    /// Apply one 005 token ("PREFIX=(ov)@+", "CHANTYPES=#", "MONITOR", …).
    mutating func apply(token: String) {
        // "-TOKEN" negates a previously advertised feature — rare; ignored.
        guard !token.hasPrefix("-") else { return }

        let parts = token.split(separator: "=", maxSplits: 1)
        guard let first = parts.first else { return }
        let key = String(first).uppercased()
        let value = parts.count > 1 ? String(parts[1]) : ""

        switch key {
        case "PREFIX":
            // Format: (modes)symbols — e.g. (qaohv)~&@%+
            guard value.hasPrefix("("),
                  let close = value.firstIndex(of: ")") else { return }
            let modes = Array(value[value.index(after: value.startIndex)..<close])
            let symbols = Array(value[value.index(after: close)...])
            guard modes.count == symbols.count, !modes.isEmpty else { return }
            prefixModes = modes
            prefixSymbols = symbols

        case "CHANMODES":
            // Four comma-separated categories: A,B,C,D
            let groups = value.split(separator: ",", omittingEmptySubsequences: false)
            if groups.count >= 1 { listModes = Set(groups[0]) }
            if groups.count >= 2 { alwaysArgModes = Set(groups[1]) }
            if groups.count >= 3 { argWhenSetModes = Set(groups[2]) }
            // Category D takes no arguments — nothing to track

        case "CHANTYPES":
            guard !value.isEmpty else { return }
            chantypes = Set(value)

        case "CASEMAPPING":
            casemapping = value.lowercased()

        case "NETWORK":
            network = value.isEmpty ? nil : value

        default:
            break
        }
    }
}
