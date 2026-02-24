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
    
    /// IRC user mask components
    var nick: String? {
        prefix?.components(separatedBy: "!").first
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
        prefix?.components(separatedBy: "@").last
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
                    tags[String(components[0])] = String(components[1])
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
        
        // Remove leading spaces
        remainder = remainder.trimmingCharacters(in: .whitespaces)
        
        // Parse command
        guard let commandEnd = remainder.firstIndex(of: " ") ?? remainder.indices.last else {
            return IRCMessage(raw: raw, prefix: prefix, command: remainder.uppercased(), parameters: [], tags: tags)
        }
        
        let command = String(remainder[..<commandEnd]).uppercased()
        remainder = commandEnd < remainder.endIndex 
            ? String(remainder[remainder.index(after: commandEnd)...])
            : ""
        
        // Parse parameters
        var parameters: [String] = []
        
        while !remainder.isEmpty {
            remainder = remainder.trimmingCharacters(in: .whitespaces)
            
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
    
    /// Format an IRC message for sending
    static func format(command: String, parameters: [String] = [], prefix: String? = nil) -> String {
        var message = ""
        
        if let prefix = prefix {
            message = ":\(prefix) "
        }
        
        message += command
        
        if !parameters.isEmpty {
            let lastIndex = parameters.count - 1
            for (index, param) in parameters.enumerated() {
                if index == lastIndex && (param.contains(" ") || param.hasPrefix(":")) {
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
