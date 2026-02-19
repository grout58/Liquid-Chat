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
    
    /// Parse an IRC message from a raw string (RFC 1459 format)
    static func parse(_ raw: String) -> IRCMessage? {
        var remainder = raw
        var prefix: String?
        
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
            return IRCMessage(raw: raw, prefix: prefix, command: remainder.uppercased(), parameters: [])
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
        
        return IRCMessage(raw: raw, prefix: prefix, command: command, parameters: parameters)
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
