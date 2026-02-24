//
//  AppSettingsTests.swift
//  Liquid ChatTests
//
//  Tests for application settings persistence and management
//

import Testing
import SwiftUI
@testable import Liquid_Chat

/// Tests for AppSettings persistence and management
@Suite("Application Settings Tests")
struct AppSettingsTests {
    
    // Test UserDefaults suite to avoid polluting real data
    let testDefaults = UserDefaults(suiteName: "TestAppSettings")!
    
    init() {
        // Clear test defaults before each suite run
        testDefaults.removePersistentDomain(forName: "TestAppSettings")
    }
    
    // MARK: - Helper Functions
    
    /// Create a testable settings instance
    func createTestSettings() -> TestableAppSettings {
        return TestableAppSettings(userDefaults: testDefaults)
    }
    
    // MARK: - Default Values Tests
    
    @Test("Default appearance settings")
    func testDefaultAppearanceSettings() {
        let settings = createTestSettings()
        
        #expect(settings.theme == .system)
        #expect(settings.fontSizeMultiplier == 1.0)
    }
    
    @Test("Default chat behavior settings")
    func testDefaultChatBehaviorSettings() {
        let settings = createTestSettings()
        
        #expect(settings.showTimestamps == true)
        #expect(settings.use24HourTime == false)
        #expect(settings.showJoinPartMessages == false)
        #expect(settings.enableURLPreviews == true)
        #expect(settings.enableNicknameColors == true)
        #expect(settings.messageHistoryLimit == 1000)
    }
    
    @Test("Default notification settings")
    func testDefaultNotificationSettings() {
        let settings = createTestSettings()
        
        #expect(settings.enableSoundNotifications == true)
        #expect(settings.enableMentionNotifications == true)
        #expect(settings.enablePrivateMessageNotifications == true)
    }
    
    @Test("Default AI settings")
    func testDefaultAISettings() {
        let settings = createTestSettings()
        
        #expect(settings.enableAIFeatures == true)
        #expect(settings.aiTemperature == 0.3)
        #expect(settings.autoSummarizeThreshold == 100)
    }
    
    @Test("Default advanced settings")
    func testDefaultAdvancedSettings() {
        let settings = createTestSettings()
        
        #expect(settings.enableConsoleLogging == true)
        #expect(settings.consoleLogLevel == .info)
        #expect(settings.enablePerformanceMonitoring == false)
        #expect(settings.autoReconnect == true)
        #expect(settings.connectionTimeout == 30)
    }
    
    // MARK: - Persistence Tests - Appearance
    
    @Test("Theme persists to UserDefaults")
    func testThemePersistence() {
        let settings = createTestSettings()
        
        settings.theme = .dark
        #expect(testDefaults.string(forKey: "theme") == "dark")
        
        settings.theme = .nord
        #expect(testDefaults.string(forKey: "theme") == "nord")
    }
    
    @Test("Font size multiplier persists")
    func testFontSizeMultiplierPersistence() {
        let settings = createTestSettings()
        
        settings.fontSizeMultiplier = 1.2
        #expect(testDefaults.double(forKey: "fontSizeMultiplier") == 1.2)
        
        settings.fontSizeMultiplier = 0.8
        #expect(testDefaults.double(forKey: "fontSizeMultiplier") == 0.8)
    }
    
    // MARK: - Persistence Tests - Chat Behavior
    
    @Test("Show timestamps persists")
    func testShowTimestampsPersistence() {
        let settings = createTestSettings()
        
        settings.showTimestamps = false
        #expect(testDefaults.bool(forKey: "showTimestamps") == false)
        
        settings.showTimestamps = true
        #expect(testDefaults.bool(forKey: "showTimestamps") == true)
    }
    
    @Test("24-hour time format persists")
    func testUse24HourTimePersistence() {
        let settings = createTestSettings()
        
        settings.use24HourTime = true
        #expect(testDefaults.bool(forKey: "use24HourTime") == true)
    }
    
    @Test("Join/part messages visibility persists")
    func testShowJoinPartMessagesPersistence() {
        let settings = createTestSettings()
        
        settings.showJoinPartMessages = true
        #expect(testDefaults.bool(forKey: "showJoinPartMessages") == true)
    }
    
    @Test("URL previews setting persists")
    func testEnableURLPreviewsPersistence() {
        let settings = createTestSettings()
        
        settings.enableURLPreviews = false
        #expect(testDefaults.bool(forKey: "enableURLPreviews") == false)
    }
    
    @Test("Nickname colors setting persists")
    func testEnableNicknameColorsPersistence() {
        let settings = createTestSettings()
        
        settings.enableNicknameColors = false
        #expect(testDefaults.bool(forKey: "enableNicknameColors") == false)
    }
    
    @Test("Message history limit persists")
    func testMessageHistoryLimitPersistence() {
        let settings = createTestSettings()
        
        settings.messageHistoryLimit = 500
        #expect(testDefaults.integer(forKey: "messageHistoryLimit") == 500)
        
        settings.messageHistoryLimit = 2000
        #expect(testDefaults.integer(forKey: "messageHistoryLimit") == 2000)
    }
    
    // MARK: - Persistence Tests - Notifications
    
    @Test("Sound notifications setting persists")
    func testEnableSoundNotificationsPersistence() {
        let settings = createTestSettings()
        
        settings.enableSoundNotifications = false
        #expect(testDefaults.bool(forKey: "enableSoundNotifications") == false)
    }
    
    @Test("Mention notifications setting persists")
    func testEnableMentionNotificationsPersistence() {
        let settings = createTestSettings()
        
        settings.enableMentionNotifications = false
        #expect(testDefaults.bool(forKey: "enableMentionNotifications") == false)
    }
    
    @Test("Private message notifications setting persists")
    func testEnablePrivateMessageNotificationsPersistence() {
        let settings = createTestSettings()
        
        settings.enablePrivateMessageNotifications = false
        #expect(testDefaults.bool(forKey: "enablePrivateMessageNotifications") == false)
    }
    
    // MARK: - Persistence Tests - AI Settings
    
    @Test("AI features toggle persists")
    func testEnableAIFeaturesPersistence() {
        let settings = createTestSettings()
        
        settings.enableAIFeatures = false
        #expect(testDefaults.bool(forKey: "enableAIFeatures") == false)
    }
    
    @Test("AI temperature persists")
    func testAITemperaturePersistence() {
        let settings = createTestSettings()
        
        settings.aiTemperature = 0.7
        #expect(testDefaults.double(forKey: "aiTemperature") == 0.7)
        
        settings.aiTemperature = 0.0
        #expect(testDefaults.double(forKey: "aiTemperature") == 0.0)
        
        settings.aiTemperature = 1.0
        #expect(testDefaults.double(forKey: "aiTemperature") == 1.0)
    }
    
    @Test("Auto-summarize threshold persists")
    func testAutoSummarizeThresholdPersistence() {
        let settings = createTestSettings()
        
        settings.autoSummarizeThreshold = 50
        #expect(testDefaults.integer(forKey: "autoSummarizeThreshold") == 50)
        
        settings.autoSummarizeThreshold = 200
        #expect(testDefaults.integer(forKey: "autoSummarizeThreshold") == 200)
    }
    
    // MARK: - Persistence Tests - Advanced Settings
    
    @Test("Console logging toggle persists")
    func testEnableConsoleLoggingPersistence() {
        let settings = createTestSettings()
        
        settings.enableConsoleLogging = false
        #expect(testDefaults.bool(forKey: "enableConsoleLogging") == false)
    }
    
    @Test("Console log level persists")
    func testConsoleLogLevelPersistence() {
        let settings = createTestSettings()
        
        settings.consoleLogLevel = .debug
        #expect(testDefaults.string(forKey: "consoleLogLevel") == "debug")
        
        settings.consoleLogLevel = .warning
        #expect(testDefaults.string(forKey: "consoleLogLevel") == "warning")
        
        settings.consoleLogLevel = .error
        #expect(testDefaults.string(forKey: "consoleLogLevel") == "error")
    }
    
    @Test("Performance monitoring toggle persists")
    func testEnablePerformanceMonitoringPersistence() {
        let settings = createTestSettings()
        
        settings.enablePerformanceMonitoring = true
        #expect(testDefaults.bool(forKey: "enablePerformanceMonitoring") == true)
    }
    
    @Test("Auto-reconnect setting persists")
    func testAutoReconnectPersistence() {
        let settings = createTestSettings()
        
        settings.autoReconnect = false
        #expect(testDefaults.bool(forKey: "autoReconnect") == false)
    }
    
    @Test("Connection timeout persists")
    func testConnectionTimeoutPersistence() {
        let settings = createTestSettings()
        
        settings.connectionTimeout = 60
        #expect(testDefaults.integer(forKey: "connectionTimeout") == 60)
        
        settings.connectionTimeout = 10
        #expect(testDefaults.integer(forKey: "connectionTimeout") == 10)
    }
    
    // MARK: - Load from UserDefaults Tests
    
    @Test("Load theme from UserDefaults on init")
    func testLoadThemeOnInit() {
        testDefaults.set("dark", forKey: "theme")
        
        let settings = createTestSettings()
        
        #expect(settings.theme == .dark)
    }
    
    @Test("Load font size from UserDefaults on init")
    func testLoadFontSizeOnInit() {
        testDefaults.set(1.5, forKey: "fontSizeMultiplier")
        
        let settings = createTestSettings()
        
        #expect(settings.fontSizeMultiplier == 1.5)
    }
    
    @Test("Load all chat settings from UserDefaults on init")
    func testLoadChatSettingsOnInit() {
        testDefaults.set(false, forKey: "showTimestamps")
        testDefaults.set(true, forKey: "use24HourTime")
        testDefaults.set(true, forKey: "showJoinPartMessages")
        testDefaults.set(false, forKey: "enableURLPreviews")
        testDefaults.set(false, forKey: "enableNicknameColors")
        testDefaults.set(500, forKey: "messageHistoryLimit")
        
        let settings = createTestSettings()
        
        #expect(settings.showTimestamps == false)
        #expect(settings.use24HourTime == true)
        #expect(settings.showJoinPartMessages == true)
        #expect(settings.enableURLPreviews == false)
        #expect(settings.enableNicknameColors == false)
        #expect(settings.messageHistoryLimit == 500)
    }
    
    // MARK: - Reset to Defaults Tests
    
    @Test("Reset all settings to defaults")
    func testResetToDefaults() {
        let settings = createTestSettings()
        
        // Modify all settings
        settings.theme = .dark
        settings.fontSizeMultiplier = 1.5
        settings.showTimestamps = false
        settings.use24HourTime = true
        settings.showJoinPartMessages = true
        settings.enableURLPreviews = false
        settings.enableNicknameColors = false
        settings.messageHistoryLimit = 500
        settings.enableSoundNotifications = false
        settings.enableMentionNotifications = false
        settings.enablePrivateMessageNotifications = false
        settings.enableAIFeatures = false
        settings.aiTemperature = 0.8
        settings.autoSummarizeThreshold = 200
        settings.enableConsoleLogging = false
        settings.consoleLogLevel = .error
        settings.enablePerformanceMonitoring = true
        settings.autoReconnect = false
        settings.connectionTimeout = 60
        
        // Reset
        settings.resetToDefaults()
        
        // Verify all defaults
        #expect(settings.theme == .system)
        #expect(settings.fontSizeMultiplier == 1.0)
        #expect(settings.showTimestamps == true)
        #expect(settings.use24HourTime == false)
        #expect(settings.showJoinPartMessages == false)
        #expect(settings.enableURLPreviews == true)
        #expect(settings.enableNicknameColors == true)
        #expect(settings.messageHistoryLimit == 1000)
        #expect(settings.enableSoundNotifications == true)
        #expect(settings.enableMentionNotifications == true)
        #expect(settings.enablePrivateMessageNotifications == true)
        #expect(settings.enableAIFeatures == true)
        #expect(settings.aiTemperature == 0.3)
        #expect(settings.autoSummarizeThreshold == 100)
        #expect(settings.enableConsoleLogging == true)
        #expect(settings.consoleLogLevel == .info)
        #expect(settings.enablePerformanceMonitoring == false)
        #expect(settings.autoReconnect == true)
        #expect(settings.connectionTimeout == 30)
    }
    
    @Test("Reset persists to UserDefaults")
    func testResetPersistsToUserDefaults() {
        let settings = createTestSettings()
        
        // Modify settings
        settings.theme = .dark
        settings.fontSizeMultiplier = 1.5
        settings.showTimestamps = false
        
        // Reset
        settings.resetToDefaults()
        
        // Verify persistence
        #expect(testDefaults.string(forKey: "theme") == "system")
        #expect(testDefaults.double(forKey: "fontSizeMultiplier") == 1.0)
        #expect(testDefaults.bool(forKey: "showTimestamps") == true)
    }
    
    // MARK: - Edge Cases
    
    @Test("Invalid theme falls back to system")
    func testInvalidThemeFallback() {
        testDefaults.set("invalid_theme_name", forKey: "theme")
        
        let settings = createTestSettings()
        
        #expect(settings.theme == .system)
    }
    
    @Test("Zero font size falls back to 1.0")
    func testZeroFontSizeFallback() {
        testDefaults.set(0.0, forKey: "fontSizeMultiplier")
        
        let settings = createTestSettings()
        
        #expect(settings.fontSizeMultiplier == 1.0)
    }
    
    @Test("Zero message history limit falls back to 1000")
    func testZeroMessageHistoryFallback() {
        testDefaults.set(0, forKey: "messageHistoryLimit")
        
        let settings = createTestSettings()
        
        #expect(settings.messageHistoryLimit == 1000)
    }
    
    @Test("Invalid log level falls back to info")
    func testInvalidLogLevelFallback() {
        testDefaults.set("invalid_level", forKey: "consoleLogLevel")
        
        let settings = createTestSettings()
        
        #expect(settings.consoleLogLevel == .info)
    }
    
    // MARK: - Boundary Value Tests
    
    @Test("Font size multiplier extremes")
    func testFontSizeExtremes() {
        let settings = createTestSettings()
        
        settings.fontSizeMultiplier = 0.8
        #expect(settings.fontSizeMultiplier == 0.8)
        
        settings.fontSizeMultiplier = 1.5
        #expect(settings.fontSizeMultiplier == 1.5)
    }
    
    @Test("AI temperature boundaries")
    func testAITemperatureBoundaries() {
        let settings = createTestSettings()
        
        settings.aiTemperature = 0.0
        #expect(settings.aiTemperature == 0.0)
        
        settings.aiTemperature = 1.0
        #expect(settings.aiTemperature == 1.0)
    }
    
    @Test("Message history limit ranges")
    func testMessageHistoryLimitRanges() {
        let settings = createTestSettings()
        
        settings.messageHistoryLimit = 100
        #expect(settings.messageHistoryLimit == 100)
        
        settings.messageHistoryLimit = 10000
        #expect(settings.messageHistoryLimit == 10000)
    }
    
    @Test("Connection timeout ranges")
    func testConnectionTimeoutRanges() {
        let settings = createTestSettings()
        
        settings.connectionTimeout = 5
        #expect(settings.connectionTimeout == 5)
        
        settings.connectionTimeout = 300
        #expect(settings.connectionTimeout == 300)
    }
    
    // MARK: - Settings Persistence Across Instances
    
    @Test("Settings persist across instance recreation")
    func testSettingsPersistAcrossInstances() {
        // First instance
        do {
            let settings = createTestSettings()
            settings.theme = .nord
            settings.fontSizeMultiplier = 1.3
            settings.showTimestamps = false
            settings.enableURLPreviews = false
        }
        
        // Second instance should load the same values
        do {
            let settings = createTestSettings()
            #expect(settings.theme == .nord)
            #expect(settings.fontSizeMultiplier == 1.3)
            #expect(settings.showTimestamps == false)
            #expect(settings.enableURLPreviews == false)
        }
    }
    
    // MARK: - Concurrent Modifications
    
    @Test("Concurrent setting modifications")
    func testConcurrentModifications() async {
        let settings = createTestSettings()
        
        await withTaskGroup(of: Void.self) { group in
            // Theme changes
            for theme in [AppTheme.dark, .light, .nord, .gameBoy] {
                group.addTask {
                    settings.theme = theme
                }
            }
            
            // Font size changes
            for size in stride(from: 0.8, through: 1.5, by: 0.1) {
                group.addTask {
                    settings.fontSizeMultiplier = size
                }
            }
        }
        
        // Settings should have a valid state after concurrent modifications
        #expect(AppTheme.allCases.contains(settings.theme))
        #expect(settings.fontSizeMultiplier >= 0.8)
        #expect(settings.fontSizeMultiplier <= 1.5)
    }
}

// MARK: - Testable AppSettings

/// Testable version of AppSettings that uses custom UserDefaults
@Observable
class TestableAppSettings {
    private let userDefaults: UserDefaults
    
    // Appearance Settings
    var theme: AppTheme {
        didSet { userDefaults.set(theme.rawValue, forKey: "theme") }
    }
    
    var fontSizeMultiplier: Double {
        didSet { userDefaults.set(fontSizeMultiplier, forKey: "fontSizeMultiplier") }
    }
    
    // Chat Behavior Settings
    var showTimestamps: Bool {
        didSet { userDefaults.set(showTimestamps, forKey: "showTimestamps") }
    }
    
    var use24HourTime: Bool {
        didSet { userDefaults.set(use24HourTime, forKey: "use24HourTime") }
    }
    
    var showJoinPartMessages: Bool {
        didSet { userDefaults.set(showJoinPartMessages, forKey: "showJoinPartMessages") }
    }
    
    var enableURLPreviews: Bool {
        didSet { userDefaults.set(enableURLPreviews, forKey: "enableURLPreviews") }
    }
    
    var enableNicknameColors: Bool {
        didSet { userDefaults.set(enableNicknameColors, forKey: "enableNicknameColors") }
    }
    
    var messageHistoryLimit: Int {
        didSet { userDefaults.set(messageHistoryLimit, forKey: "messageHistoryLimit") }
    }
    
    // Notification Settings
    var enableSoundNotifications: Bool {
        didSet { userDefaults.set(enableSoundNotifications, forKey: "enableSoundNotifications") }
    }
    
    var enableMentionNotifications: Bool {
        didSet { userDefaults.set(enableMentionNotifications, forKey: "enableMentionNotifications") }
    }
    
    var enablePrivateMessageNotifications: Bool {
        didSet { userDefaults.set(enablePrivateMessageNotifications, forKey: "enablePrivateMessageNotifications") }
    }
    
    // AI Settings
    var enableAIFeatures: Bool {
        didSet { userDefaults.set(enableAIFeatures, forKey: "enableAIFeatures") }
    }
    
    var aiTemperature: Double {
        didSet { userDefaults.set(aiTemperature, forKey: "aiTemperature") }
    }
    
    var autoSummarizeThreshold: Int {
        didSet { userDefaults.set(autoSummarizeThreshold, forKey: "autoSummarizeThreshold") }
    }
    
    // Advanced Settings
    var enableConsoleLogging: Bool {
        didSet { userDefaults.set(enableConsoleLogging, forKey: "enableConsoleLogging") }
    }
    
    var consoleLogLevel: ConsoleLogEntry.LogLevel {
        didSet { userDefaults.set(consoleLogLevel.rawValue, forKey: "consoleLogLevel") }
    }
    
    var enablePerformanceMonitoring: Bool {
        didSet { userDefaults.set(enablePerformanceMonitoring, forKey: "enablePerformanceMonitoring") }
    }
    
    var autoReconnect: Bool {
        didSet { userDefaults.set(autoReconnect, forKey: "autoReconnect") }
    }
    
    var connectionTimeout: Int {
        didSet { userDefaults.set(connectionTimeout, forKey: "connectionTimeout") }
    }
    
    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
        
        // Load from UserDefaults or use defaults
        self.theme = AppTheme(rawValue: userDefaults.string(forKey: "theme") ?? "") ?? .system
        self.fontSizeMultiplier = userDefaults.double(forKey: "fontSizeMultiplier") != 0 
            ? userDefaults.double(forKey: "fontSizeMultiplier") : 1.0
        
        self.showTimestamps = userDefaults.object(forKey: "showTimestamps") as? Bool ?? true
        self.use24HourTime = userDefaults.object(forKey: "use24HourTime") as? Bool ?? false
        self.showJoinPartMessages = userDefaults.object(forKey: "showJoinPartMessages") as? Bool ?? false
        self.enableURLPreviews = userDefaults.object(forKey: "enableURLPreviews") as? Bool ?? true
        self.enableNicknameColors = userDefaults.object(forKey: "enableNicknameColors") as? Bool ?? true
        self.messageHistoryLimit = userDefaults.integer(forKey: "messageHistoryLimit") != 0
            ? userDefaults.integer(forKey: "messageHistoryLimit") : 1000
        
        self.enableSoundNotifications = userDefaults.object(forKey: "enableSoundNotifications") as? Bool ?? true
        self.enableMentionNotifications = userDefaults.object(forKey: "enableMentionNotifications") as? Bool ?? true
        self.enablePrivateMessageNotifications = userDefaults.object(forKey: "enablePrivateMessageNotifications") as? Bool ?? true
        
        self.enableAIFeatures = userDefaults.object(forKey: "enableAIFeatures") as? Bool ?? true
        self.aiTemperature = userDefaults.double(forKey: "aiTemperature") != 0
            ? userDefaults.double(forKey: "aiTemperature") : 0.3
        self.autoSummarizeThreshold = userDefaults.integer(forKey: "autoSummarizeThreshold") != 0
            ? userDefaults.integer(forKey: "autoSummarizeThreshold") : 100
        
        self.enableConsoleLogging = userDefaults.object(forKey: "enableConsoleLogging") as? Bool ?? true
        let logLevelRaw = userDefaults.string(forKey: "consoleLogLevel") ?? "info"
        self.consoleLogLevel = ConsoleLogEntry.LogLevel(rawValue: logLevelRaw) ?? .info
        self.enablePerformanceMonitoring = userDefaults.object(forKey: "enablePerformanceMonitoring") as? Bool ?? false
        self.autoReconnect = userDefaults.object(forKey: "autoReconnect") as? Bool ?? true
        self.connectionTimeout = userDefaults.integer(forKey: "connectionTimeout") != 0
            ? userDefaults.integer(forKey: "connectionTimeout") : 30
    }
    
    func resetToDefaults() {
        theme = .system
        fontSizeMultiplier = 1.0
        
        showTimestamps = true
        use24HourTime = false
        showJoinPartMessages = false
        enableURLPreviews = true
        enableNicknameColors = true
        messageHistoryLimit = 1000
        
        enableSoundNotifications = true
        enableMentionNotifications = true
        enablePrivateMessageNotifications = true
        
        enableAIFeatures = true
        aiTemperature = 0.3
        autoSummarizeThreshold = 100
        
        enableConsoleLogging = true
        consoleLogLevel = .info
        enablePerformanceMonitoring = false
        autoReconnect = true
        connectionTimeout = 30
    }
}
