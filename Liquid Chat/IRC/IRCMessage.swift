//
//  IRCMessage.swift
//  Liquid Chat
//
//  IRC message parsing and formatting
//

import Foundation

/// Represents a parsed IRC message
struct IRCMessage {
    let raw: String
    let prefix: String?
    let command: String
    let parameters: [String]
    
    /// IRCv3 message tags (@key=value)
    let tags: [String: String]
    
    /// Cached ISO8601 date formatter for server-time parsing (thread-safe)
    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    /// Server timestamp from IRCv3 server-time capability
    /// Optimized: Uses cached formatter instead of creating new one each time
    var serverTime: Date? {
        guard let timeTag = tags["time"] else { return nil }
        return Self.iso8601Formatter.date(from: timeTag)
    }
    
    /// Batch ID from IRCv3 batch capability
    var batchID: String? {
        tags["batch"]
    }
    
    /// IRC user mask components — prefix forms: "nick", "nick@host",
    /// "nick!user@host", or a bare server name.
    var nick: String? {
        guard let prefix else { return nil }
        let end = prefix.firstIndex { $0 == "!" || $0 == "@" } ?? prefix.endIndex
        return String(prefix[..<end])
    }

    var user: String? {
        guard let prefix = prefix, let atIndex = prefix.firstIndex(of: "@") else { return nil }
        let beforeAt = prefix[..<atIndex]
        if let bangIndex = beforeAt.firstIndex(of: "!") {
            return String(beforeAt[beforeAt.index(after: bangIndex)...])
        }
        return nil
    }

    var host: String? {
        guard let prefix, let atIndex = prefix.firstIndex(of: "@") else { return nil }
        return String(prefix[prefix.index(after: atIndex)...])
    }
    
    /// Parse an IRC message from a raw string (RFC 1459 format with IRCv3 tags)
    static func parse(_ raw: String) -> IRCMessage? {
        var remainder = raw
        var tags: [String: String] = [:]
        var prefix: String?
        
        // Parse IRCv3 message tags (if present)
        if remainder.hasPrefix("@") {
            guard let spaceIndex = remainder.firstIndex(of: " ") else { return nil }
            let tagString = String(remainder[remainder.index(after: remainder.startIndex)..<spaceIndex])
            
            // Parse tags: key=value;key2=value2
            let tagPairs = tagString.split(separator: ";")
            for pair in tagPairs {
                let components = pair.split(separator: "=", maxSplits: 1)
                if components.count == 2 {
                    tags[String(components[0])] = unescapeTagValue(components[1])
                } else if components.count == 1 {
                    tags[String(components[0])] = ""
                }
            }
            
            remainder = String(remainder[remainder.index(after: spaceIndex)...])
        }
        
        // Parse prefix (if present)
        if remainder.hasPrefix(":") {
            guard let spaceIndex = remainder.firstIndex(of: " ") else { return nil }
            prefix = String(remainder[remainder.index(after: remainder.startIndex)..<spaceIndex])
            remainder = String(remainder[remainder.index(after: spaceIndex)...])
        }
        
        // Remove leading spaces only — a trailing parameter's own trailing
        // whitespace is significant and must survive
        while remainder.hasPrefix(" ") {
            remainder.removeFirst()
        }

        // Parse command
        guard !remainder.isEmpty else { return nil }

        let command: String
        if let commandEnd = remainder.firstIndex(of: " ") {
            command = String(remainder[..<commandEnd]).uppercased()
            remainder = String(remainder[remainder.index(after: commandEnd)...])
        } else {
            // Bare command with no parameters (e.g. "PING")
            let bare = remainder.uppercased()
            guard isValidCommand(bare) else { return nil }
            return IRCMessage(raw: raw, prefix: prefix, command: bare, parameters: [], tags: tags)
        }

        // RFC 2812 §2.3.1: a command is a letter sequence or a 3-digit numeric —
        // anything else means the line is malformed (e.g. a prefix or tag
        // section that ran into the command with no separating space).
        guard isValidCommand(command) else { return nil }

        // Parse parameters
        var parameters: [String] = []

        while !remainder.isEmpty {
            // Skip separating spaces only — trailing content must stay intact
            while remainder.hasPrefix(" ") {
                remainder.removeFirst()
            }
            guard !remainder.isEmpty else { break }

            if remainder.hasPrefix(":") {
                // Trailing parameter (rest of the message)
                parameters.append(String(remainder.dropFirst()))
                break
            } else if let spaceIndex = remainder.firstIndex(of: " ") {
                // Regular parameter
                parameters.append(String(remainder[..<spaceIndex]))
                remainder = String(remainder[remainder.index(after: spaceIndex)...])
            } else {
                // Last parameter
                parameters.append(remainder)
                break
            }
        }
        
        return IRCMessage(raw: raw, prefix: prefix, command: command, parameters: parameters, tags: tags)
    }

    /// A command is 1+ ASCII letters or exactly 3 digits (RFC 2812 §2.3.1).
    private static func isValidCommand(_ command: String) -> Bool {
        guard !command.isEmpty else { return false }
        if command.allSatisfy({ $0.isASCII && $0.isLetter }) { return true }
        return command.count == 3 && command.allSatisfy { $0.isASCII && $0.isNumber }
    }

    /// Unescape an IRCv3 message-tag value (\: → ; \s → space, \\, \r, \n).
    /// Internal because bouncer-network attributes share this escaping.
    static func unescapeTagValue(_ value: Substring) -> String {
        guard value.contains("\\") else { return String(value) }
        var result = ""
        result.reserveCapacity(value.count)
        var iterator = value.makeIterator()
        while let char = iterator.next() {
            guard char == "\\", let next = iterator.next() else {
                result.append(char)
                continue
            }
            switch next {
            case ":": result.append(";")
            case "s": result.append(" ")
            case "r": result.append("\r")
            case "n": result.append("\n")
            case "\\": result.append("\\")
            default: result.append(next)   // spec: drop the backslash, keep the char
            }
        }
        return result
    }

    /// Format an IRC message for sending.
    /// The trailing parameter is always colon-prefixed — that is legal for every
    /// command and keeps parse→format round trips stable for trailing content.
    static func format(command: String, parameters: [String] = [], prefix: String? = nil) -> String {
        var message = ""

        if let prefix = prefix {
            message = ":\(prefix) "
        }

        message += command

        if !parameters.isEmpty {
            let lastIndex = parameters.count - 1
            for (index, param) in parameters.enumerated() {
                if index == lastIndex {
                    message += " :\(param)"
                } else {
                    message += " \(param)"
                }
            }
        }

        return message
    }
}

extension IRCMessage: CustomStringConvertible {
    var description: String {
        var desc = ""
        if let prefix = prefix {
            desc += "[\(prefix)] "
        }
        desc += command
        if !parameters.isEmpty {
            desc += " " + parameters.joined(separator: ", ")
        }
        return desc
    }
}
