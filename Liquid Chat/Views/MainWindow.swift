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
    
    init() {
        ConsoleLogger.shared.log("Main window initialized", level: .debug, category: "App")
    }
    
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
        .sheet(item: $chatState.showingChannelJoinForServer) { server in
            ChannelJoinView(server: server, chatState: chatState)
        }
    }
}

#Preview {
    MainWindow()
}
