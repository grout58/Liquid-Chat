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
    
    var body: some View {
        GlassEffectContainer(spacing: 8.0) {
            List(selection: $selectedChannel) {
                ForEach(chatState.servers) { server in
                    Section {
                        ForEach(server.channels) { channel in
                            ChannelRowView(channel: channel)
                                .tag(channel)
                        }
                    } header: {
                        ServerHeaderView(server: server, chatState: chatState)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Channels")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        // Add server action
                    } label: {
                        Label("Add Server", systemImage: "plus")
                    }
                    .buttonStyle(.glass)
                }
            }
        }
    }
}

struct ServerHeaderView: View {
    let server: IRCServer
    let chatState: ChatState
    @State private var isExpanded = true
    
    var body: some View {
        HStack {
            Image(systemName: server.isConnected ? "network" : "network.slash")
                .foregroundStyle(server.isConnected ? .green : .secondary)
            
            Text(server.config.hostname)
                .font(.headline)
            
            Spacer()
            
            if !server.isConnected {
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
    }
}

struct ChannelRowView: View {
    let channel: IRCChannel
    
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
        .glassEffect(.regular, in: .rect(cornerRadius: 8))
    }
}

#Preview {
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
    
    return ChannelSidebarView(chatState: chatState, selectedChannel: .constant(channel1))
}
