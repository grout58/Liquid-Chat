//
//  ChannelListView.swift
//  Liquid Chat
//
//  Channel list browser dialog with search and filtering
//

import SwiftUI

struct ChannelListView: View {
    let server: IRCServer
    let chatState: ChatState
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText = ""
    @State private var selectedChannel: IRCChannelListEntry?
    @State private var sortOrder: SortOrder = .userCount
    @State private var filteredAndSortedChannels: [IRCChannelListEntry] = []
    @State private var isProcessing = false
    @State private var filterTask: Task<Void, Never>?
    
    private var settings: AppSettings { AppSettings.shared }
    
    enum SortOrder {
        case userCount
        case name
        
        var displayName: String {
            switch self {
            case .userCount: return "Users"
            case .name: return "Name"
            }
        }
    }
    
    /// Update filtered channels asynchronously to prevent UI lockup
    /// Uses debouncing and background processing for large lists
    private func updateFilteredChannels() {
        // Cancel any in-flight task before starting a new one
        filterTask?.cancel()
        isProcessing = true

        // Capture values to avoid concurrency issues
        let channels = server.availableChannels
        let search = searchText
        let sort = sortOrder

        filterTask = Task.detached(priority: .userInitiated) {
            // Filter (in background thread for large lists)
            let filtered: [IRCChannelListEntry]
            if !search.isEmpty {
                filtered = channels.filter { channel in
                    channel.name.localizedCaseInsensitiveContains(search) ||
                    channel.topic.localizedCaseInsensitiveContains(search)
                }
            } else {
                filtered = channels
            }
            
            // Limit to reasonable size for display (prevents massive lists from crashing UI)
            let maxDisplayChannels = 5000
            let limited = filtered.count > maxDisplayChannels 
                ? Array(filtered.prefix(maxDisplayChannels))
                : filtered
            
            // Sort (in background thread)
            let sorted: [IRCChannelListEntry]
            switch sort {
            case .userCount:
                sorted = limited.sorted { $0.userCount > $1.userCount }
            case .name:
                sorted = limited.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            }
            
            // Update UI on main thread
            await MainActor.run {
                self.filteredAndSortedChannels = sorted
                self.isProcessing = false
            }
            await ConsoleLogger.shared.log("ChannelListView: Display updated with \(sorted.count) channels", level: .debug, category: "UI")
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header - Use subtle background instead of themed card
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Channel List")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    if server.isLoadingChannelList {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Loading channels...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        HStack(spacing: 4) {
                            Text("\(filteredAndSortedChannels.count) channels")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            if server.availableChannels.count > 5000 {
                                Text("(showing first 5000)")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
                
                Spacer()
                
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            // Search and filter bar with minimal styling
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .imageScale(.small)
                    
                    TextField("Search channels...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                
                Picker("Sort by", selection: $sortOrder) {
                    Text("Users").tag(SortOrder.userCount)
                    Text("Name").tag(SortOrder.name)
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            // Channel list
            if filteredAndSortedChannels.isEmpty && !server.isLoadingChannelList {
                ContentUnavailableView {
                    Label("No Channels Found", systemImage: "magnifyingglass")
                } description: {
                    Text(searchText.isEmpty ? "No channels available" : "Try a different search term")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredAndSortedChannels) { channel in
                            ChannelListRowView(
                                channel: channel,
                                isSelected: selectedChannel?.id == channel.id
                            )
                            .onTapGesture {
                                selectedChannel = channel
                            }
                        }
                    }
                    .padding(16)
                }
            }
            
            // Footer with join button - simplified styling
            HStack {
                if let selected = selectedChannel {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selected.name)
                            .font(.headline)
                        Text("\(selected.userCount) users")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                Button {
                    if let channel = selectedChannel {
                        chatState.joinChannel(name: channel.name, on: server)
                        dismiss()
                    }
                } label: {
                    Label("Join Channel", systemImage: "arrow.right.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedChannel == nil)
            }
            .padding()
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 0))
        }
        .frame(width: 700, height: 600)
        .background(.regularMaterial)
        .onAppear {
            Task { await ConsoleLogger.shared.log("ChannelListView appeared for server: \(server.config.hostname)", level: .info, category: "UI") }
            updateFilteredChannels()
            
            // Add timeout to prevent infinite loading
            Task {
                try? await Task.sleep(for: .seconds(30))
                if await MainActor.run(body: { server.isLoadingChannelList }) {
                    await ConsoleLogger.shared.log("Channel list loading timeout - forcing completion", level: .warning, category: "UI")
                    await MainActor.run {
                        server.isLoadingChannelList = false
                    }
                }
            }
        }
        .onChange(of: server.availableChannels.count) { oldCount, newCount in
            // Skip updates while loading to prevent MainActor saturation
            guard !server.isLoadingChannelList else { return }
            Task { await ConsoleLogger.shared.log("Channel count changed: \(oldCount) → \(newCount)", level: .debug, category: "UI") }
            updateFilteredChannels()
        }
        .onChange(of: server.isLoadingChannelList) { wasLoading, isNowLoading in
            // When loading finishes, update the display
            if wasLoading && !isNowLoading {
                Task { await ConsoleLogger.shared.log("Channel loading completed, refreshing display", level: .debug, category: "UI") }
                updateFilteredChannels()
            }
        }
        .onChange(of: searchText) { _, _ in
            updateFilteredChannels()
        }
        .onChange(of: sortOrder) { _, _ in
            updateFilteredChannels()
        }
    }
}

struct ChannelListRowView: View {
    let channel: IRCChannelListEntry
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Channel icon
            Image(systemName: "number.circle.fill")
                .font(.title2)
                .foregroundStyle(isSelected ? .blue : .secondary)
            
            // Channel info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(channel.name)
                        .font(.headline)
                    
                    Spacer()
                    
                    // User count badge
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.caption2)
                        Text("\(channel.userCount)")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary.opacity(0.6))
                    .clipShape(Capsule())
                }
                
                if !channel.topic.isEmpty {
                    Text(channel.topic)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(12)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.tint.opacity(0.15))
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.quaternary.opacity(0.3))
            }
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    let chatState = ChatState()
    let server = IRCServer(config: IRCServerConfig(
        hostname: "irc.libera.chat",
        useSSL: true,
        nickname: "TestUser"
    ))
    
    server.availableChannels = [
        IRCChannelListEntry(name: "#swift", userCount: 245, topic: "Swift programming language discussion"),
        IRCChannelListEntry(name: "#python", userCount: 189, topic: "Python development and help"),
        IRCChannelListEntry(name: "#javascript", userCount: 167, topic: "JavaScript, Node.js, and web development"),
        IRCChannelListEntry(name: "#linux", userCount: 523, topic: "Linux support and discussion"),
        IRCChannelListEntry(name: "#macos", userCount: 78, topic: "macOS help and discussion"),
    ]
    
    return ChannelListView(server: server, chatState: chatState)
}
