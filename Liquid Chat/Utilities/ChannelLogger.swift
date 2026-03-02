//
//  ChannelLogger.swift
//  Liquid Chat
//
//  Background actor for logging channel messages to disk
//

import Foundation

/// Actor-based channel logger for safe concurrent file access
actor ChannelLogger {
    static let shared = ChannelLogger()
    
    private let baseURL: URL
    private let dateFormatter: DateFormatter
    private let timestampFormatter: DateFormatter
    
    // Keep track of open file handles for better performance
    private var fileHandles: [String: FileHandle] = [:]
    private var lastAccessTime: [String: Date] = [:]
    
    private init() {
        // Setup base directory: ~/Library/Application Support/Liquid Chat/Logs
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        baseURL = appSupport.appendingPathComponent("Liquid Chat/Logs")
        
        // Create base directory if it doesn't exist
        try? FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
        
        // Date formatter for log filenames (YYYY-MM-DD.log)
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        // Timestamp formatter for log entries ([HH:MM:SS])
        timestampFormatter = DateFormatter()
        timestampFormatter.dateFormat = "HH:mm:ss"
        
        // Log initialization asynchronously
        Task {
            await ConsoleLogger.shared.log("Channel logger initialized at \(baseURL.path)", level: .info, category: "Logger")
        }
        
        // Start periodic cleanup task (fire-and-forget; singleton lives for app lifetime)
        Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(300)) // Every 5 minutes
                await ChannelLogger.shared.cleanupInactiveHandles()
            }
        }
    }
    
    /// Close file handles that haven't been accessed in 5 minutes
    private func cleanupInactiveHandles() {
        let now = Date()
        let inactivityThreshold: TimeInterval = 300 // 5 minutes
        
        for (path, lastAccess) in lastAccessTime {
            if now.timeIntervalSince(lastAccess) > inactivityThreshold {
                if let handle = fileHandles[path] {
                    try? handle.close()
                    fileHandles.removeValue(forKey: path)
                    lastAccessTime.removeValue(forKey: path)
                }
            }
        }
    }
    
    /// Log a message to the appropriate channel log file
    func log(message: IRCChatMessage, channel: String, server: String) async {
        // Sanitize channel and server names for filesystem
        let sanitizedServer = sanitizeFilename(server)
        let sanitizedChannel = sanitizeFilename(channel)
        
        // Get the log file path
        let filename = dateFormatter.string(from: message.timestamp)
        let logURL = baseURL
            .appendingPathComponent(sanitizedServer)
            .appendingPathComponent(sanitizedChannel)
            .appendingPathComponent("\(filename).log")
        
        // Ensure directory exists
        let directoryURL = logURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: directoryURL.path) {
            do {
                try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            } catch {
                await ConsoleLogger.shared.log("Failed to create log directory: \(error)", level: .error, category: "Logger")
                return
            }
        }
        
        // Format the log line
        let timestamp = timestampFormatter.string(from: message.timestamp)
        let logLine = formatLogLine(timestamp: timestamp, message: message)
        
        // Write to file
        await writeToLog(logURL: logURL, line: logLine)
    }
    
    /// Format a message into a log line
    private func formatLogLine(timestamp: String, message: IRCChatMessage) -> String {
        let content = String(message.content.characters)
        
        switch message.type {
        case .message:
            return "[\(timestamp)] <\(message.sender)> \(content)\n"
        case .action:
            return "[\(timestamp)] * \(message.sender) \(content)\n"
        case .notice:
            return "[\(timestamp)] -\(message.sender)- \(content)\n"
        case .join:
            return "[\(timestamp)] --> \(message.sender) has joined\n"
        case .part:
            return "[\(timestamp)] <-- \(message.sender) has left (\(content))\n"
        case .quit:
            return "[\(timestamp)] <-- \(message.sender) has quit (\(content))\n"
        case .nick:
            return "[\(timestamp)] -- \(content)\n"
        case .topic:
            return "[\(timestamp)] -- \(content)\n"
        case .system:
            return "[\(timestamp)] -- \(content)\n"
        }
    }
    
    /// Write a line to the log file
    private func writeToLog(logURL: URL, line: String) async {
        guard let data = line.data(using: .utf8) else { return }
        
        let logPath = logURL.path
        
        // Track access time for cleanup
        lastAccessTime[logPath] = Date()
        
        do {
            // Check if file exists
            if FileManager.default.fileExists(atPath: logPath) {
                // Append to existing file
                if let fileHandle = fileHandles[logPath] {
                    // Use existing file handle
                    try fileHandle.seekToEnd()
                    try fileHandle.write(contentsOf: data)
                } else {
                    // Open new file handle
                    let fileHandle = try FileHandle(forWritingTo: logURL)
                    try fileHandle.seekToEnd()
                    try fileHandle.write(contentsOf: data)
                    fileHandles[logPath] = fileHandle
                }
            } else {
                // Create new file
                try data.write(to: logURL, options: .atomic)
                
                // Open file handle for future writes
                if let fileHandle = try? FileHandle(forWritingTo: logURL) {
                    fileHandles[logPath] = fileHandle
                }
            }
        } catch {
            await ConsoleLogger.shared.log("Failed to write to log: \(error)", level: .error, category: "Logger")
        }
    }
    
    /// Sanitize filename by removing invalid characters
    private func sanitizeFilename(_ name: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: ":/\\?%*|\"<>")
        return name
            .components(separatedBy: invalidCharacters)
            .joined(separator: "_")
            .trimmingCharacters(in: .whitespaces)
    }
    
    /// Close file handle for a specific log (useful for cleanup)
    func closeLog(channel: String, server: String) {
        let sanitizedServer = sanitizeFilename(server)
        let sanitizedChannel = sanitizeFilename(channel)
        let directoryPath = baseURL
            .appendingPathComponent(sanitizedServer)
            .appendingPathComponent(sanitizedChannel)
            .path
        
        // Close all file handles for this channel
        let keysToClose = fileHandles.keys.filter { $0.hasPrefix(directoryPath) }
        for key in keysToClose {
            if let handle = fileHandles[key] {
                try? handle.close()
                fileHandles.removeValue(forKey: key)
            }
        }
    }
    
    /// Get the log directory URL for a specific channel
    func getLogDirectory(channel: String, server: String) -> URL {
        let sanitizedServer = sanitizeFilename(server)
        let sanitizedChannel = sanitizeFilename(channel)
        return baseURL
            .appendingPathComponent(sanitizedServer)
            .appendingPathComponent(sanitizedChannel)
    }
    
    /// Check if logs exist for a channel
    func hasLogs(channel: String, server: String) -> Bool {
        let logDir = getLogDirectory(channel: channel, server: server)
        return FileManager.default.fileExists(atPath: logDir.path)
    }
}
