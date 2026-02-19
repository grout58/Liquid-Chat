//
//  SettingsView.swift
//  Liquid Chat
//
//  Comprehensive settings interface
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var settings = AppSettings.shared
    @State private var selectedTab: SettingsTab = .appearance
    
    enum SettingsTab: String, CaseIterable {
        case appearance = "Appearance"
        case chat = "Chat"
        case notifications = "Notifications"
        case ai = "AI Features"
        case advanced = "Advanced"
        
        var icon: String {
            switch self {
            case .appearance: return "paintbrush.fill"
            case .chat: return "bubble.left.and.bubble.right.fill"
            case .notifications: return "bell.fill"
            case .ai: return "sparkles"
            case .advanced: return "gearshape.2.fill"
            }
        }
    }
    
    var body: some View {
        NavigationSplitView {
            // Sidebar with tabs
            List(SettingsTab.allCases, id: \.self, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
                    .tag(tab)
            }
            .navigationTitle("Settings")
            .frame(minWidth: 200)
        } detail: {
            // Detail view based on selected tab
            ScrollView {
                switch selectedTab {
                case .appearance:
                    AppearanceSettingsView(settings: settings)
                case .chat:
                    ChatSettingsView(settings: settings)
                case .notifications:
                    NotificationSettingsView(settings: settings)
                case .ai:
                    AISettingsView(settings: settings)
                case .advanced:
                    AdvancedSettingsView(settings: settings)
                }
            }
            .frame(minWidth: 500, minHeight: 400)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Reset to Defaults") {
                        settings.resetToDefaults()
                    }
                }
            }
        }
        .frame(width: 800, height: 600)
    }
}

// MARK: - Appearance Settings

struct AppearanceSettingsView: View {
    @Bindable var settings: AppSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingsSection(title: "Theme", icon: "paintpalette.fill") {
                ThemePickerView(selectedTheme: $settings.theme)
            }
            
            SettingsSection(title: "Typography", icon: "textformat.size") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Font Size")
                        Spacer()
                        Text("\(Int(settings.fontSizeMultiplier * 100))%")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $settings.fontSizeMultiplier, in: 0.8...1.5, step: 0.1)
                }
            }
        }
        .padding(24)
    }
}

// MARK: - Chat Settings

struct ChatSettingsView: View {
    @Bindable var settings: AppSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingsSection(title: "Messages", icon: "message.fill") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Show Timestamps", isOn: $settings.showTimestamps)
                    Toggle("Use 24-Hour Time", isOn: $settings.use24HourTime)
                        .disabled(!settings.showTimestamps)
                    Toggle("Show Join/Part Messages", isOn: $settings.showJoinPartMessages)
                    Toggle("Enable URL Previews", isOn: $settings.enableURLPreviews)
                    Toggle("Colorize Nicknames", isOn: $settings.enableNicknameColors)
                }
            }
            
            SettingsSection(title: "History", icon: "clock.arrow.circlepath") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Message History Limit")
                        Spacer()
                        TextField("Limit", value: $settings.messageHistoryLimit, format: .number)
                            .frame(width: 80)
                            .textFieldStyle(.roundedBorder)
                    }
                    Text("Number of messages to keep per channel (0 = unlimited)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(24)
    }
}

// MARK: - Notification Settings

struct NotificationSettingsView: View {
    @Bindable var settings: AppSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingsSection(title: "Alerts", icon: "bell.badge.fill") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Sound Notifications", isOn: $settings.enableSoundNotifications)
                    Toggle("Mention Notifications", isOn: $settings.enableMentionNotifications)
                    Toggle("Private Message Notifications", isOn: $settings.enablePrivateMessageNotifications)
                }
            }
            
            Text("Note: Notifications require system permissions in System Settings.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
        .padding(24)
    }
}

// MARK: - AI Settings

struct AISettingsView: View {
    @Bindable var settings: AppSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingsSection(title: "AI Features", icon: "brain.head.profile") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Enable AI Features", isOn: $settings.enableAIFeatures)
                    
                    Text("Requires Apple Intelligence to be enabled on this device")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            SettingsSection(title: "Generation Settings", icon: "slider.horizontal.3") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Temperature")
                        Spacer()
                        Text(String(format: "%.1f", settings.aiTemperature))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $settings.aiTemperature, in: 0.0...1.0, step: 0.1)
                    Text("Lower values = more focused, higher values = more creative")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .disabled(!settings.enableAIFeatures)
            }
            
            SettingsSection(title: "Auto-Summarization", icon: "text.quote") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Auto-Summarize After")
                        Spacer()
                        TextField("Messages", value: $settings.autoSummarizeThreshold, format: .number)
                            .frame(width: 80)
                            .textFieldStyle(.roundedBorder)
                        Text("messages")
                    }
                    Text("Automatically generate summaries after this many messages (0 = disabled)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .disabled(!settings.enableAIFeatures)
            }
        }
        .padding(24)
    }
}

// MARK: - Advanced Settings

struct AdvancedSettingsView: View {
    @Bindable var settings: AppSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingsSection(title: "Logging", icon: "doc.text.magnifyingglass") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Enable Console Logging", isOn: $settings.enableConsoleLogging)
                    
                    HStack {
                        Text("Log Level")
                        Spacer()
                        Picker("Log Level", selection: $settings.consoleLogLevel) {
                            Text("Debug").tag(ConsoleLogEntry.LogLevel.debug)
                            Text("Info").tag(ConsoleLogEntry.LogLevel.info)
                            Text("Warning").tag(ConsoleLogEntry.LogLevel.warning)
                            Text("Error").tag(ConsoleLogEntry.LogLevel.error)
                        }
                        .pickerStyle(.menu)
                        .frame(width: 120)
                    }
                    .disabled(!settings.enableConsoleLogging)
                }
            }
            
            SettingsSection(title: "Performance", icon: "speedometer") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Enable Performance Monitoring", isOn: $settings.enablePerformanceMonitoring)
                    Text("Monitor app performance metrics (may impact performance)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            SettingsSection(title: "Connection", icon: "network") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Auto-Reconnect on Disconnect", isOn: $settings.autoReconnect)
                    
                    HStack {
                        Text("Connection Timeout")
                        Spacer()
                        TextField("Seconds", value: $settings.connectionTimeout, format: .number)
                            .frame(width: 80)
                            .textFieldStyle(.roundedBorder)
                        Text("seconds")
                    }
                }
            }
        }
        .padding(24)
    }
}

// MARK: - Theme Picker

struct ThemePickerView: View {
    @Binding var selectedTheme: AppTheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(AppTheme.allCases) { theme in
                ThemeOptionRow(theme: theme, isSelected: selectedTheme == theme)
                    .onTapGesture {
                        selectedTheme = theme
                    }
            }
        }
    }
}

struct ThemeOptionRow: View {
    let theme: AppTheme
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: theme.previewIcon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(theme.displayName)
                    .font(.headline)
                Text(theme.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.blue)
                    .font(.title3)
            }
        }
        .padding(12)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        }
    }
}

// MARK: - Settings Section

struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text(title)
                    .font(.headline)
            } icon: {
                Image(systemName: icon)
                    .foregroundStyle(.blue)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                content
            }
            .padding(16)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

#Preview {
    SettingsView()
}
