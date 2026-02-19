//
//  ConsoleView.swift
//  Liquid Chat
//
//  IRC console log viewer with filtering
//

import SwiftUI

/// Represents a console log entry
struct ConsoleLogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let level: LogLevel
    let category: String
    let message: String
    
    enum LogLevel {
        case debug
        case info
        case warning
        case error
        
        var color: Color {
            switch self {
            case .debug: return .secondary
            case .info: return .blue
            case .warning: return .orange
            case .error: return .red
            }
        }
        
        var icon: String {
            switch self {
            case .debug: return "ant.circle"
            case .info: return "info.circle"
            case .warning: return "exclamationmark.triangle"
            case .error: return "xmark.circle"
            }
        }
    }
}

/// Global console logger
@Observable
class ConsoleLogger {
    static let shared = ConsoleLogger()
    
    var entries: [ConsoleLogEntry] = []
    var maxEntries = 1000
    
    private init() {}
    
    func log(_ message: String, level: ConsoleLogEntry.LogLevel = .info, category: String = "General") {
        let entry = ConsoleLogEntry(
            timestamp: Date(),
            level: level,
            category: category,
            message: message
        )
        
        entries.append(entry)
        
        // Keep only recent entries
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
        
        // Still print to Xcode console for development
        #if DEBUG
        print("[\(category)] \(message)")
        #endif
    }
    
    func clear() {
        entries.removeAll()
    }
}

struct ConsoleView: View {
    @State private var logger = ConsoleLogger.shared
    @State private var filterText = ""
    @State private var selectedLevel: ConsoleLogEntry.LogLevel?
    @State private var autoScroll = true
    
    var filteredEntries: [ConsoleLogEntry] {
        logger.entries.filter { entry in
            let matchesText = filterText.isEmpty || entry.message.localizedCaseInsensitiveContains(filterText) || entry.category.localizedCaseInsensitiveContains(filterText)
            let matchesLevel = selectedLevel == nil || entry.level == selectedLevel
            return matchesText && matchesLevel
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                // Filter
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Filter logs...", text: $filterText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                // Level filter
                Picker("Level", selection: $selectedLevel) {
                    Text("All").tag(nil as ConsoleLogEntry.LogLevel?)
                    Text("Debug").tag(ConsoleLogEntry.LogLevel.debug as ConsoleLogEntry.LogLevel?)
                    Text("Info").tag(ConsoleLogEntry.LogLevel.info as ConsoleLogEntry.LogLevel?)
                    Text("Warning").tag(ConsoleLogEntry.LogLevel.warning as ConsoleLogEntry.LogLevel?)
                    Text("Error").tag(ConsoleLogEntry.LogLevel.error as ConsoleLogEntry.LogLevel?)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 400)
                
                Spacer()
                
                // Auto-scroll toggle
                Toggle(isOn: $autoScroll) {
                    Label("Auto-scroll", systemImage: "arrow.down.to.line")
                }
                .toggleStyle(.switch)
                
                // Clear button
                Button {
                    logger.clear()
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .buttonStyle(.bordered)
            }
            .padding(12)
            .background(.ultraThinMaterial)
            
            Divider()
            
            // Log entries
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(filteredEntries) { entry in
                            ConsoleEntryView(entry: entry)
                                .id(entry.id)
                        }
                    }
                    .padding(8)
                }
                .onChange(of: logger.entries.count) { _, _ in
                    if autoScroll, let lastEntry = filteredEntries.last {
                        withAnimation {
                            proxy.scrollTo(lastEntry.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Status bar
            HStack {
                Text("\(filteredEntries.count) / \(logger.entries.count) entries")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if !filterText.isEmpty || selectedLevel != nil {
                    Button {
                        filterText = ""
                        selectedLevel = nil
                    } label: {
                        Text("Clear Filters")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(8)
            .background(.ultraThinMaterial)
        }
    }
}

struct ConsoleEntryView: View {
    let entry: ConsoleLogEntry
    
    @State private var isExpanded = false
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: entry.timestamp)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                // Timestamp
                Text(formattedTime)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 90, alignment: .leading)
                
                // Level icon
                Image(systemName: entry.level.icon)
                    .font(.caption)
                    .foregroundStyle(entry.level.color)
                    .frame(width: 16)
                
                // Category
                Text(entry.category)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(entry.level.color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(entry.level.color.opacity(0.1))
                    .clipShape(Capsule())
                
                // Message (truncated)
                Text(entry.message)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(isExpanded ? nil : 1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Expand button for long messages
                if entry.message.count > 80 {
                    Button {
                        withAnimation(.snappy) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(entry.level == .error ? Color.red.opacity(0.05) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .textSelection(.enabled)
    }
}

#Preview {
    ConsoleLogger.shared.log("App launched", level: .info, category: "App")
    ConsoleLogger.shared.log("Connecting to irc.libera.chat:6697", level: .info, category: "IRC")
    ConsoleLogger.shared.log("Connection established", level: .info, category: "Network")
    ConsoleLogger.shared.log("CAP LS 302 sent", level: .debug, category: "IRC")
    ConsoleLogger.shared.log("Received: Welcome to Libera.Chat", level: .info, category: "IRC")
    ConsoleLogger.shared.log("Failed to resolve hostname", level: .warning, category: "Network")
    ConsoleLogger.shared.log("Connection timeout", level: .error, category: "Network")
    
    return ConsoleView()
        .frame(height: 400)
}
