//
//  MainWindow.swift
//  Liquid Chat
//
//  Main window with Liquid Glass split view layout
//

import SwiftUI

struct MainWindow: View {
    @State private var chatState = ChatState()
    @State private var selectedChannel: IRCChannel?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showConsole = false
    @State private var hasLoadedSavedServers = false
    
    // Use shared settings directly without @State copy
    private var settings: AppSettings { AppSettings.shared }
    
    var body: some View {
        VSplitView {
            // Main chat interface
            NavigationSplitView(columnVisibility: $columnVisibility) {
                // Sidebar: Server and channel list with Liquid Glass
                ChannelSidebarView(chatState: chatState, selectedChannel: $selectedChannel)
                    .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 300)
            } detail: {
                // Main chat area
                if let channel = selectedChannel {
                    ChatView(channel: channel, chatState: chatState)
                } else {
                    ContentUnavailableView(
                        "No Channel Selected",
                        systemImage: "bubble.left.and.bubble.right",
                        description: Text("Select a channel from the sidebar to start chatting")
                    )
                }
            }
            .onChange(of: chatState.selectedChannel) { _, newChannel in
                // Sync ChatState's selected channel to our local binding
                if let newChannel = newChannel, selectedChannel?.id != newChannel.id {
                    selectedChannel = newChannel
                }
            }
            .onChange(of: selectedChannel) { _, newChannel in
                // Sync our local binding back to ChatState
                if let newChannel = newChannel, chatState.selectedChannel?.id != newChannel.id {
                    chatState.selectedChannel = newChannel
                }
            }
            
            // Console panel (collapsible)
            if showConsole {
                ConsoleView()
                    .frame(minHeight: 200, idealHeight: 300)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    withAnimation {
                        showConsole.toggle()
                    }
                } label: {
                    Label("Console", systemImage: showConsole ? "terminal.fill" : "terminal")
                }
                .help("Toggle IRC Console")
            }
        }
        .environment(chatState)
        .themedStyle(settings)
        .sheet(item: $chatState.showingChannelJoinForServer) { server in
            ChannelJoinView(server: server, chatState: chatState)
                .themedStyle(settings)
        }
        .alert(item: $chatState.connectionAlert) { alert in
            Alert(
                title: Text("Connection Failed"),
                message: Text("\(alert.server.config.hostname): \(alert.message)\n\nReconnecting automatically…"),
                primaryButton: .default(Text("Retry Now")) {
                    chatState.connectToServer(alert.server)
                },
                secondaryButton: .cancel(Text("Stop Retrying")) {
                    chatState.disconnectFromServer(alert.server)
                }
            )
        }
        .task {
            // Load saved servers on app launch
            guard !hasLoadedSavedServers else { return }
            hasLoadedSavedServers = true
            
            let savedServers = ServerConfigManager.shared.savedServers
            
            if !savedServers.isEmpty {
                await ConsoleLogger.shared.log("Loading \(savedServers.count) saved servers", level: .info, category: "App")
                
                for config in savedServers {
                    chatState.addServer(config: config)
                    
                    // Auto-connect if enabled
                    if config.autoConnect, let server = chatState.servers.last {
                        await ConsoleLogger.shared.log("Auto-connecting to \(config.hostname)", level: .info, category: "App")
                        chatState.connectToServer(server)
                    }
                }
            }
        }
    }
}

#Preview {
    MainWindow()
}
