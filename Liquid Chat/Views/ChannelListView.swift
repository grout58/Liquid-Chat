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
    
    private var filteredAndSortedChannels: [IRCChannelListEntry] {
        var channels = server.availableChannels
        
        // Filter by search text
        if !searchText.isEmpty {
            channels = channels.filter { channel in
                channel.name.localizedCaseInsensitiveContains(searchText) ||
                channel.topic.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Sort
        switch sortOrder {
        case .userCount:
            channels.sort { $0.userCount > $1.userCount }
        case .name:
            channels.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
        
        return channels
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
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
                        Text("\(filteredAndSortedChannels.count) channels")
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
            .themedCard(cornerRadius: 12, settings: settings)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            // Search and filter bar
            HStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    
                    TextField("Search channels...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .themedCard(cornerRadius: 8, settings: settings)
                
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
            
            // Footer with join button
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
            .themedCard(cornerRadius: 12, settings: settings)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .frame(width: 700, height: 600)
        .themedBackground(settings)
    }
}

struct ChannelListRowView: View {
    let channel: IRCChannelListEntry
    let isSelected: Bool
    
    private var settings: AppSettings { AppSettings.shared }
    
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
                        .foregroundStyle(isSelected ? .primary : .primary)
                    
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
                    .background(.quaternary)
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
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .themedCard(cornerRadius: 12, settings: settings)
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
