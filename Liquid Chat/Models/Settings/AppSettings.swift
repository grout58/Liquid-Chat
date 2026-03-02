//
//  AppSettings.swift
//  Liquid Chat
//
//  Centralized app settings and user preferences
//

import SwiftUI

/// Centralized application settings
@Observable
class AppSettings {
    static let shared = AppSettings()
    
    // MARK: - Appearance Settings
    
    /// Current theme
    var theme: AppTheme {
        didSet {
            UserDefaults.standard.set(theme.rawValue, forKey: "theme")
        }
    }
    
    /// Font size multiplier (0.8 to 1.5)
    var fontSizeMultiplier: Double {
        didSet {
            UserDefaults.standard.set(fontSizeMultiplier, forKey: "fontSizeMultiplier")
        }
    }
    
    // MARK: - Chat Behavior Settings
    
    /// Show timestamps on messages
    var showTimestamps: Bool {
        didSet {
            UserDefaults.standard.set(showTimestamps, forKey: "showTimestamps")
        }
    }
    
    /// Timestamp format (12h or 24h)
    var use24HourTime: Bool {
        didSet {
            UserDefaults.standard.set(use24HourTime, forKey: "use24HourTime")
        }
    }
    
    /// Show join/part messages
    var showJoinPartMessages: Bool {
        didSet {
            UserDefaults.standard.set(showJoinPartMessages, forKey: "showJoinPartMessages")
        }
    }
    
    /// Enable URL previews
    var enableURLPreviews: Bool {
        didSet {
            UserDefaults.standard.set(enableURLPreviews, forKey: "enableURLPreviews")
        }
    }
    
    /// Enable nickname colorization
    var enableNicknameColors: Bool {
        didSet {
            UserDefaults.standard.set(enableNicknameColors, forKey: "enableNicknameColors")
        }
    }
    
    /// Message history limit per channel
    var messageHistoryLimit: Int {
        didSet {
            UserDefaults.standard.set(messageHistoryLimit, forKey: "messageHistoryLimit")
        }
    }
    
    // MARK: - Notification Settings
    
    /// Enable sound notifications
    var enableSoundNotifications: Bool {
        didSet {
            UserDefaults.standard.set(enableSoundNotifications, forKey: "enableSoundNotifications")
        }
    }
    
    /// Enable mention notifications
    var enableMentionNotifications: Bool {
        didSet {
            UserDefaults.standard.set(enableMentionNotifications, forKey: "enableMentionNotifications")
        }
    }
    
    /// Enable private message notifications
    var enablePrivateMessageNotifications: Bool {
        didSet {
            UserDefaults.standard.set(enablePrivateMessageNotifications, forKey: "enablePrivateMessageNotifications")
        }
    }
    
    // MARK: - AI Settings
    
    /// Enable AI features
    var enableAIFeatures: Bool {
        didSet {
            UserDefaults.standard.set(enableAIFeatures, forKey: "enableAIFeatures")
        }
    }
    
    /// AI temperature (0.0 to 1.0)
    var aiTemperature: Double {
        didSet {
            UserDefaults.standard.set(aiTemperature, forKey: "aiTemperature")
        }
    }
    
    /// Auto-summarize after N messages
    var autoSummarizeThreshold: Int {
        didSet {
            UserDefaults.standard.set(autoSummarizeThreshold, forKey: "autoSummarizeThreshold")
        }
    }
    
    /// Enable smart reply suggestions (NEW macOS 26 AI Feature)
    var enableSmartReplies: Bool {
        didSet {
            UserDefaults.standard.set(enableSmartReplies, forKey: "enableSmartReplies")
        }
    }
    
    /// Auto-send smart replies without confirmation
    var autoSendSmartReplies: Bool {
        didSet {
            UserDefaults.standard.set(autoSendSmartReplies, forKey: "autoSendSmartReplies")
        }
    }
    
    // MARK: - Ignore List

    /// Nicknames whose messages are hidden across all servers.
    var ignoredNicknames: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(ignoredNicknames), forKey: "ignoredNicknames")
        }
    }

    func ignore(_ nickname: String) { ignoredNicknames.insert(nickname.lowercased()) }
    func unignore(_ nickname: String) { ignoredNicknames.remove(nickname.lowercased()) }
    func isIgnored(_ nickname: String) -> Bool { ignoredNicknames.contains(nickname.lowercased()) }

    // MARK: - Advanced Settings
    
    /// Enable console logging
    var enableConsoleLogging: Bool {
        didSet {
            UserDefaults.standard.set(enableConsoleLogging, forKey: "enableConsoleLogging")
        }
    }
    
    /// Console log level
    var consoleLogLevel: ConsoleLogEntry.LogLevel {
        didSet {
            UserDefaults.standard.set(consoleLogLevel.rawValue, forKey: "consoleLogLevel")
        }
    }
    
    /// Enable performance monitoring
    var enablePerformanceMonitoring: Bool {
        didSet {
            UserDefaults.standard.set(enablePerformanceMonitoring, forKey: "enablePerformanceMonitoring")
        }
    }
    
    /// Reconnect automatically on disconnect
    var autoReconnect: Bool {
        didSet {
            UserDefaults.standard.set(autoReconnect, forKey: "autoReconnect")
        }
    }
    
    /// Connection timeout (seconds)
    var connectionTimeout: Int {
        didSet {
            UserDefaults.standard.set(connectionTimeout, forKey: "connectionTimeout")
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        // Load from UserDefaults or use defaults
        self.theme = AppTheme(rawValue: UserDefaults.standard.string(forKey: "theme") ?? "") ?? .system
        self.fontSizeMultiplier = UserDefaults.standard.double(forKey: "fontSizeMultiplier") != 0 
            ? UserDefaults.standard.double(forKey: "fontSizeMultiplier") : 1.0
        
        self.showTimestamps = UserDefaults.standard.object(forKey: "showTimestamps") as? Bool ?? true
        self.use24HourTime = UserDefaults.standard.object(forKey: "use24HourTime") as? Bool ?? false
        self.showJoinPartMessages = UserDefaults.standard.object(forKey: "showJoinPartMessages") as? Bool ?? false
        self.enableURLPreviews = UserDefaults.standard.object(forKey: "enableURLPreviews") as? Bool ?? true
        self.enableNicknameColors = UserDefaults.standard.object(forKey: "enableNicknameColors") as? Bool ?? true
        self.messageHistoryLimit = UserDefaults.standard.integer(forKey: "messageHistoryLimit") != 0
            ? UserDefaults.standard.integer(forKey: "messageHistoryLimit") : 1000
        
        let ignoredArray = UserDefaults.standard.stringArray(forKey: "ignoredNicknames") ?? []
        self.ignoredNicknames = Set(ignoredArray)

        self.enableSoundNotifications = UserDefaults.standard.object(forKey: "enableSoundNotifications") as? Bool ?? true
        self.enableMentionNotifications = UserDefaults.standard.object(forKey: "enableMentionNotifications") as? Bool ?? true
        self.enablePrivateMessageNotifications = UserDefaults.standard.object(forKey: "enablePrivateMessageNotifications") as? Bool ?? true
        
        self.enableAIFeatures = UserDefaults.standard.object(forKey: "enableAIFeatures") as? Bool ?? true
        self.aiTemperature = UserDefaults.standard.double(forKey: "aiTemperature") != 0
            ? UserDefaults.standard.double(forKey: "aiTemperature") : 0.3
        self.autoSummarizeThreshold = UserDefaults.standard.integer(forKey: "autoSummarizeThreshold") != 0
            ? UserDefaults.standard.integer(forKey: "autoSummarizeThreshold") : 100
        self.enableSmartReplies = UserDefaults.standard.object(forKey: "enableSmartReplies") as? Bool ?? true
        self.autoSendSmartReplies = UserDefaults.standard.object(forKey: "autoSendSmartReplies") as? Bool ?? false
        
        self.enableConsoleLogging = UserDefaults.standard.object(forKey: "enableConsoleLogging") as? Bool ?? true
        let logLevelRaw = UserDefaults.standard.string(forKey: "consoleLogLevel") ?? "info"
        self.consoleLogLevel = ConsoleLogEntry.LogLevel(rawValue: logLevelRaw) ?? .info
        self.enablePerformanceMonitoring = UserDefaults.standard.object(forKey: "enablePerformanceMonitoring") as? Bool ?? false
        self.autoReconnect = UserDefaults.standard.object(forKey: "autoReconnect") as? Bool ?? true
        self.connectionTimeout = UserDefaults.standard.integer(forKey: "connectionTimeout") != 0
            ? UserDefaults.standard.integer(forKey: "connectionTimeout") : 30
    }
    
    // MARK: - Reset to Defaults
    
    func resetToDefaults() {
        theme = .system
        fontSizeMultiplier = 1.0
        
        showTimestamps = true
        use24HourTime = false
        showJoinPartMessages = false
        enableURLPreviews = true
        enableNicknameColors = true
        messageHistoryLimit = 1000
        
        ignoredNicknames = []
        enableSoundNotifications = true
        enableMentionNotifications = true
        enablePrivateMessageNotifications = true
        
        enableAIFeatures = true
        aiTemperature = 0.3
        autoSummarizeThreshold = 100
        enableSmartReplies = true
        autoSendSmartReplies = false
        
        enableConsoleLogging = true
        consoleLogLevel = .info
        enablePerformanceMonitoring = false
        autoReconnect = true
        connectionTimeout = 30
    }
}
