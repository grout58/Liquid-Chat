//
//  Constants.swift
//  Liquid Chat
//
//  Application-wide constants for configuration and magic numbers
//

import Foundation

/// IRC Protocol constants
enum IRC {
    /// Maximum number of messages to keep in chat history per channel
    static let maxMessageHistoryPerChannel = 1000
    
    /// Maximum message length (IRC protocol limit minus overhead)
    static let maxMessageLength = 510
    
    /// Capability negotiation timeout in seconds
    static let capNegotiationTimeout: TimeInterval = 10
    
    /// Connection timeout in seconds
    static let connectionTimeout: TimeInterval = 30
    
    /// PING interval for keepalive in seconds
    static let pingInterval: TimeInterval = 60
    
    /// Maximum number of command history items to store
    static let maxCommandHistory = 50
    
    /// Number of lines that triggers pastebin warning
    static let pastebinThreshold = 5
}

/// UI Configuration constants
enum UI {
    /// User list width in points
    static let userListWidth: CGFloat = 200
    
    /// Message list padding
    static let messageListPadding: CGFloat = 12
    
    /// Glass effect spacing
    static let glassEffectSpacing: CGFloat = 16
    
    /// Channel header corner radius
    static let cornerRadius: CGFloat = 12
    
    /// Input field corner radius
    static let inputCornerRadius: CGFloat = 20
    
    /// Animation duration for UI transitions
    static let animationDuration: TimeInterval = 0.2
}

/// Logging constants
enum Logging {
    /// Maximum console log entries to keep in memory
    static let maxConsoleEntries = 1000
    
    /// Maximum size of a single log file in bytes (10 MB)
    static let maxLogFileSize = 10 * 1024 * 1024
    
    /// Number of days to keep log files
    static let logRetentionDays = 30
}

/// Network constants
enum Network {
    /// Default IRC port (non-SSL)
    static let defaultPort: UInt16 = 6667
    
    /// Default IRC SSL port
    static let defaultSSLPort: UInt16 = 6697
    
    /// Maximum receive buffer size
    static let receiveBufferSize = 4096
    
    /// URL preview fetch timeout
    static let urlPreviewTimeout: TimeInterval = 10
    
    /// Maximum number of cached URL previews
    static let maxURLPreviewCache = 100
}

/// Settings defaults
enum Defaults {
    /// Default theme
    static let defaultTheme = "Auto"
    
    /// Default font size range
    static let fontSizeRange: ClosedRange<Double> = 12...20
    
    /// Default UI scale range
    static let uiScaleRange: ClosedRange<Double> = 0.8...1.5
    
    /// Default opacity range
    static let opacityRange: ClosedRange<Double> = 0.0...1.0
}
