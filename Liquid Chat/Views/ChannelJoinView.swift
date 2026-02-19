//
//  ChannelJoinView.swift
//  Liquid Chat
//
//  Channel join dialog with Liquid Glass
//

import SwiftUI

struct ChannelJoinView: View {
    let server: IRCServer
    let chatState: ChatState
    @Environment(\.dismiss) private var dismiss
    
    @State private var channelName = ""
    @State private var channelKey = ""
    @State private var showAdvanced = false
    
    private var settings: AppSettings { AppSettings.shared }
    
    // Popular channels for quick join
    private let popularChannels = [
        "#swift", "#apple", "#macos", "#ios", "#xcode",
        "#programming", "#webdev", "#linux", "#python", "#javascript"
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "number.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue.gradient)
                
                Text("Join a Channel")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("on \(server.config.hostname)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 24)
            .padding(.bottom, 16)
            
            Divider()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Manual channel entry
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Enter Channel Name")
                            .font(.headline)
                        
                        HStack {
                            Text("#")
                                .foregroundStyle(.secondary)
                            
                            TextField("channel-name", text: $channelName)
                                .textFieldStyle(.plain)
                                .onSubmit {
                                    joinChannel()
                                }
                        }
                        .padding(12)
                        .background(.quaternary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        if showAdvanced {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Channel Key (optional)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                
                                SecureField("password", text: $channelKey)
                                    .textFieldStyle(.plain)
                                    .padding(12)
                                    .background(.quaternary)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        
                        Button {
                            withAnimation {
                                showAdvanced.toggle()
                            }
                        } label: {
                            HStack {
                                Image(systemName: showAdvanced ? "chevron.up" : "chevron.down")
                                Text(showAdvanced ? "Hide Advanced" : "Show Advanced")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(16)
                    .glassEffect(.regular, in: .rect(cornerRadius: 12))
                    
                    // Popular channels
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Popular Channels")
                            .font(.headline)
                            .padding(.horizontal, 4)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 8) {
                            ForEach(popularChannels, id: \.self) { channel in
                                Button {
                                    channelName = String(channel.dropFirst()) // Remove #
                                    joinChannel()
                                } label: {
                                    HStack {
                                        Image(systemName: "number")
                                            .font(.caption)
                                        Text(channel)
                                            .font(.body)
                                        Spacer()
                                        Image(systemName: "arrow.right.circle.fill")
                                            .font(.caption)
                                            .foregroundStyle(.blue)
                                    }
                                    .padding(10)
                                    .frame(maxWidth: .infinity)
                                    .background(.quaternary)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(16)
                    .glassEffect(.regular, in: .rect(cornerRadius: 12))
                }
                .padding(16)
            }
            
            Divider()
            
            // Action buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.borderless)
                
                Spacer()
                
                Button("Join Channel") {
                    joinChannel()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(channelName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(16)
        }
        .frame(width: 500, height: 600)
        .themedBackground(settings)
    }
    
    private func joinChannel() {
        guard !channelName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        let finalName = channelName.hasPrefix("#") ? channelName : "#\(channelName)"
        
        if channelKey.isEmpty {
            chatState.joinChannel(name: finalName, on: server)
        } else {
            // Join with key
            server.connection?.join(channel: finalName, key: channelKey)
            
            // Create channel in state
            if !server.channels.contains(where: { $0.name == finalName }) {
                let channel = IRCChannel(name: finalName, server: server)
                server.channels.append(channel)
            }
        }
        
        dismiss()
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
    chatState.servers = [server]
    
    return ChannelJoinView(server: server, chatState: chatState)
}
