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
    
    enum LogLevel: String, CaseIterable {
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

/// Global console logger - uses actor for thread-safe access from any thread
actor ConsoleLogger {
    static let shared = ConsoleLogger()
    
    private var _entries: [ConsoleLogEntry] = []
    private let maxEntries = 1000  // Fixed value to avoid MainActor isolation issues
    
    private init() {}
    
    /// Get current entries (async because it's actor-isolated)
    func getEntries() -> [ConsoleLogEntry] {
        return _entries
    }
    
    /// Get entry count (lightweight, doesn't copy array)
    func getCount() -> Int {
        return _entries.count
    }
    
    /// Logs a message to the console with the specified level and category
    /// - Parameters:
    ///   - message: The message to log
    ///   - level: The log level (debug, info, warning, error)
    ///   - category: The category for grouping related messages
    /// - Note: This is actor-isolated, safe to call from any thread
    func log(_ message: String, level: ConsoleLogEntry.LogLevel = .info, category: String = "General") {
        let entry = ConsoleLogEntry(
            timestamp: Date(),
            level: level,
            category: category,
            message: message
        )
        
        _entries.append(entry)
        
        // Enforce maximum entries limit to prevent memory growth
        while _entries.count > maxEntries {
            _entries.removeFirst()
        }
        
        // Print to Xcode console for development
        #if DEBUG
        print("[\(category)] \(message)")
        #endif
    }
    
    func clear() {
        _entries.removeAll()
    }
}

struct ConsoleView: View {
    @State private var filterText = ""
    @State private var selectedLevel: ConsoleLogEntry.LogLevel?
    @State private var autoScroll = true
    @State private var filteredEntries: [ConsoleLogEntry] = []
    @State private var entryCount: Int = 0
    @State private var updateTask: Task<Void, Never>?
    
    private func updateFilteredEntries() {
        // Cancel previous update to prevent MainActor saturation
        updateTask?.cancel()
        
        // Capture filter values
        let filter = filterText
        let level = selectedLevel
        
        // Fetch and filter asynchronously
        updateTask = Task.detached(priority: .userInitiated) {
            // Get entries from actor
            let entries = await ConsoleLogger.shared.getEntries()
            let count = entries.count
            
            // Debounce delay
            try? await Task.sleep(for: .milliseconds(50))
            guard !Task.isCancelled else { return }
            
            let filtered = entries.filter { entry in
                let matchesText = filter.isEmpty || entry.message.localizedCaseInsensitiveContains(filter) || entry.category.localizedCaseInsensitiveContains(filter)
                let matchesLevel = level == nil || entry.level == level
                return matchesText && matchesLevel
            }
            
            guard !Task.isCancelled else { return }
            
            await MainActor.run {
                self.filteredEntries = filtered
                self.entryCount = count
            }
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
                    Task {
                        await ConsoleLogger.shared.clear()
                        updateFilteredEntries()
                    }
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
                .task {
                    // Poll for new entries periodically
                    while !Task.isCancelled {
                        let newCount = await ConsoleLogger.shared.getCount()
                        if newCount != entryCount {
                            updateFilteredEntries()
                            
                            // Auto-scroll without animation to prevent render loop
                            if autoScroll {
                                if let lastEntry = filteredEntries.last {
                                    proxy.scrollTo(lastEntry.id, anchor: .bottom)
                                }
                            }
                        }
                        try? await Task.sleep(for: .milliseconds(500))
                    }
                }
            }
            .onAppear {
                updateFilteredEntries()
            }
            .onDisappear {
                // Cancel any pending updates when view is hidden
                updateTask?.cancel()
                updateTask = nil
            }
            .onChange(of: filterText) { _, _ in
                updateFilteredEntries()
            }
            .onChange(of: selectedLevel) { _, _ in
                updateFilteredEntries()
            }
            
            // Status bar
            HStack {
                Text("\(filteredEntries.count) / \(entryCount) entries")
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
    
    static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    var formattedTime: String {
        Self.timeFormatter.string(from: entry.timestamp)
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
    // Note: Preview logs are populated in real-time as app runs
    // Can't populate synchronously with actor-isolated logger
    ConsoleView()
        .frame(height: 400)
}
