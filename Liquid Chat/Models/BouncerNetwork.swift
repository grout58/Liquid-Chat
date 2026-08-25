//
//  BouncerNetwork.swift
//  Liquid Chat
//
//  A network advertised by a soju.im/bouncer-networks bouncer
//

import Foundation

/// One network behind a Soju-style bouncer, as reported by
/// `BOUNCER NETWORK <netid> <attributes>`.
struct BouncerNetwork: Identifiable, Equatable {
    /// The bouncer's stable network id (the BIND target)
    let id: String
    /// Raw attributes: name, host, state, nickname, … (values tag-unescaped)
    var attributes: [String: String]

    var name: String {
        attributes["name"] ?? attributes["host"] ?? id
    }

    var host: String? {
        attributes["host"]
    }

    /// Upstream state as the bouncer reports it
    enum State: String {
        case connected, connecting, disconnected
    }

    var state: State? {
        attributes["state"].flatMap(State.init(rawValue:))
    }

    /// Parse "name=Libera;state=connected;host=irc.libera.chat" — values use
    /// message-tag escaping per the bouncer-networks spec.
    static func parseAttributes(_ string: String) -> [String: String] {
        var attributes: [String: String] = [:]
        for pair in string.split(separator: ";") {
            let parts = pair.split(separator: "=", maxSplits: 1)
            guard let key = parts.first, !key.isEmpty else { continue }
            attributes[String(key)] = parts.count > 1 ? IRCMessage.unescapeTagValue(parts[1]) : ""
        }
        return attributes
    }
}
