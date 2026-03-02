//
//  ChannelSidebarView.swift
//  Liquid Chat
//
//  Channel list sidebar with Liquid Glass effects
//

import SwiftUI

struct ChannelSidebarView: View {
    let chatState: ChatState
    @Binding var selectedChannel: IRCChannel?
    @State private var showingConnectionSheet = false
    @State private var editingServer: IRCServer?
    
    private var settings: AppSettings { AppSettings.shared }
    
    var body: some View {
        VStack(spacing: 0) {
            Group {
                if chatState.servers.isEmpty {
                    ContentUnavailableView {
                        Label("No Servers", systemImage: "network.slash")
                    } description: {
                        Text("Connect to an IRC server to get started")
                    } actions: {
                        Button {
                            showingConnectionSheet = true
                        } label: {
                            Text("Add Server")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(nsColor: .windowBackgroundColor))
                } else {
                    List(selection: $selectedChannel) {
                        ForEach(chatState.servers) { server in
                            Section {
                                ForEach(server.channels) { channel in
                                    ChannelRowView(channel: channel, chatState: chatState)
                                        .tag(channel)
                                }
                            } header: {
                                ServerHeaderView(server: server, chatState: chatState, editingServer: $editingServer)
                            }
                        }
                    }
                    .listStyle(.sidebar)
                }
            }
            .navigationTitle("Channels")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingConnectionSheet = true
                    } label: {
                        Label("Add Server", systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .sheet(isPresented: $showingConnectionSheet) {
                ServerConnectionView { config in
                    chatState.addServer(config: config)
                    if let server = chatState.servers.last {
                        chatState.connectToServer(server)
                    }
                }
            }
            .sheet(item: $editingServer) { server in
                ServerConnectionView(
                    existingConfig: server.config,
                    onSave: { updatedConfig in
                        // Update the server configuration
                        if let index = chatState.servers.firstIndex(where: { $0.id == server.id }) {
                            // Disconnect first if connected
                            if case .disconnected = server.connectionState {
                                // Already disconnected, no action needed
                            } else {
                                chatState.disconnectFromServer(server)
                            }
                            
                            // Update saved config
                            ServerConfigManager.shared.updateServer(updatedConfig)
                            
                            // Create new server with updated config
                            let newServer = IRCServer(config: updatedConfig)
                            chatState.servers[index] = newServer
                            
                            // Reconnect if it was previously connected
                            if server.isConnected {
                                chatState.connectToServer(newServer)
                            }
                        }
                        editingServer = nil
                    }
                )
            }
        }
        .themedBackground(settings)
    }
}

struct ServerHeaderView: View {
    let server: IRCServer
    let chatState: ChatState
    @Binding var editingServer: IRCServer?
    @State private var isExpanded = true
    @State private var showingJoinChannel = false
    @State private var showingNewDM = false
    @State private var channelName = ""
    @State private var dmNickname = ""
    
    private var isConnecting: Bool {
        switch server.connectionState {
        case .connecting, .authenticating:
            return true
        default:
            return false
        }
    }
    
    var body: some View {
        HStack {
            // Connection status indicator with animation
            HStack(spacing: 4) {
                Image(systemName: server.connectionState.systemImage)
                    .foregroundStyle(server.connectionState.statusColor)
                    .symbolEffect(.variableColor.iterative, isActive: isConnecting)
                
                if isConnecting {
                    Text(server.connectionState.displayText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Text(server.config.hostname)
                .font(.headline)
            
            Spacer()
            
            if server.isConnected {
                Button {
                    showingJoinChannel = true
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("Join Channel")
                
                Button {
                    chatState.disconnectFromServer(server)
                } label: {
                    Image(systemName: "xmark.circle")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                .help("Disconnect")
            } else if !isConnecting {
                Button {
                    chatState.connectToServer(server)
                } label: {
                    Text("Connect")
                        .font(.caption)
                }
                .buttonStyle(.glass)
            }
        }
        .padding(.vertical, 4)
        .contextMenu {
            if server.isConnected {
                Button {
                    chatState.disconnectFromServer(server)
                } label: {
                    Label("Disconnect", systemImage: "power")
                }
                
                Divider()
                
                Button {
                    showingJoinChannel = true
                } label: {
                    Label("Join Channel", systemImage: "plus.circle")
                }
                
                Button {
                    showingNewDM = true
                } label: {
                    Label("New Direct Message", systemImage: "bubble.left.and.bubble.right")
                }
                
                Button {
                    if let connection = server.connection {
                        connection.send(command: "LIST")
                        // Don't show dialog yet - wait for LIST START response
                        // (dialog will be shown automatically to prevent freeze)
                    }
                } label: {
                    Label("List Channels", systemImage: "list.bullet")
                }
                
                Divider()
                
                Button {
                    if let connection = server.connection {
                        connection.send(command: "MOTD")
                    }
                } label: {
                    Label("View MOTD", systemImage: "doc.text")
                }
                
                Button {
                    if let connection = server.connection {
                        connection.send(command: "WHOIS", parameters: [connection.currentNickname])
                    }
                } label: {
                    Label("WHOIS Self", systemImage: "person.circle")
                }
                
                Button {
                    if let connection = server.connection {
                        connection.send(command: "AWAY", parameters: [])
                    }
                } label: {
                    Label("Mark Away/Back", systemImage: "moon")
                }
            } else if !isConnecting {
                Button {
                    chatState.connectToServer(server)
                } label: {
                    Label("Connect", systemImage: "network")
                }
                
                Divider()
                
                Button {
                    editingServer = server
                } label: {
                    Label("Edit Server", systemImage: "pencil")
                }
                
                Button(role: .destructive) {
                    ServerConfigManager.shared.deleteServer(server.config)
                } label: {
                    Label("Remove Server", systemImage: "trash")
                }
            }
        }
        .alert("Join Channel", isPresented: $showingJoinChannel) {
            TextField("Channel name (e.g., #swift)", text: $channelName)
            Button("Cancel", role: .cancel) {
                channelName = ""
            }
            Button("Join") {
                let channel = channelName.hasPrefix("#") ? channelName : "#\(channelName)"
                chatState.joinChannel(name: channel, on: server)
                channelName = ""
            }
            .disabled(channelName.isEmpty)
        } message: {
            Text("Enter the name of the channel you want to join")
        }
        .alert("New Direct Message", isPresented: $showingNewDM) {
            TextField("Nickname", text: $dmNickname)
            Button("Cancel", role: .cancel) {
                dmNickname = ""
            }
            Button("Open") {
                chatState.openPrivateMessage(with: dmNickname, on: server)
                dmNickname = ""
            }
            .disabled(dmNickname.isEmpty)
        } message: {
            Text("Enter the nickname of the person you want to message")
        }
    }
}

struct ChannelRowView: View {
    let channel: IRCChannel
    let chatState: ChatState
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: channel.name.hasPrefix("#") ? "number" : "person.circle")
                .foregroundStyle(.secondary)
                .font(.caption)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(channel.name)
                    .font(.body)
                
                if !channel.topic.isEmpty {
                    Text(channel.topic)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            if !channel.messages.isEmpty {
                Text("\(channel.messages.count)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .contextMenu {
            // Only show Part option for actual channels (not DMs)
            if channel.name.hasPrefix("#") || channel.name.hasPrefix("&") {
                Button(role: .destructive) {
                    // Send PART command to leave the channel
                    if let connection = channel.server.connection {
                        connection.part(channel: channel.name, message: "Leaving")
                    }
                    
                    // Remove channel from server's channel list
                    channel.server.channels.removeAll { $0.id == channel.id }
                } label: {
                    Label("Leave Channel", systemImage: "rectangle.portrait.and.arrow.right")
                }
            } else {
                // For DMs, just close the conversation
                Button(role: .destructive) {
                    channel.server.channels.removeAll { $0.id == channel.id }
                } label: {
                    Label("Close Conversation", systemImage: "xmark.circle")
                }
            }
            
            Divider()
            
            // Copy channel name
            Button {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(channel.name, forType: .string)
            } label: {
                Label("Copy Channel Name", systemImage: "doc.on.doc")
            }
            
            // Clear messages
            Button {
                channel.messages.removeAll()
            } label: {
                Label("Clear Messages", systemImage: "trash")
            }
        }
    }
}

#Preview("Empty State") {
    let chatState = ChatState()
    return ChannelSidebarView(chatState: chatState, selectedChannel: .constant(nil))
}

#Preview("With Servers") {
    @Previewable @State var selectedChannel: IRCChannel? = nil
    
    let chatState = ChatState()
    let server = IRCServer(config: IRCServerConfig(
        hostname: "irc.libera.chat",
        useSSL: true,
        nickname: "TestUser"
    ))
    server.isConnected = true
    
    let channel1 = IRCChannel(name: "#swift", server: server)
    channel1.topic = "Swift programming discussion"
    channel1.messages = [
        IRCChatMessage(sender: "Alice", content: "Hello world!", type: .message)
    ]
    
    let channel2 = IRCChannel(name: "#macos", server: server)
    server.channels = [channel1, channel2]
    
    chatState.servers = [server]
    selectedChannel = channel1
    
    return ChannelSidebarView(chatState: chatState, selectedChannel: $selectedChannel)
}
