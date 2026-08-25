//
//  Liquid_ChatApp.swift
//  Liquid Chat
//
//  Modern IRC client for macOS 26 with Liquid Glass
//  Created by Jason Grout on 2/19/26.
//

import SwiftUI
import AppKit

/// App delegate: sends a clean QUIT to every connected server and closes the
/// channel-log file handles before the process exits, so other users see a
/// normal quit instead of "Connection reset by peer".
final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var chatState: ChatState?

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let connectedServers = chatState?.servers.filter { $0.isConnected } ?? []

        guard !connectedServers.isEmpty else {
            Task { await ChannelLogger.shared.closeAll() }
            return .terminateNow
        }

        for server in connectedServers {
            chatState?.disconnectFromServer(server, message: "Quit: Liquid Chat")
        }

        // Give the QUIT lines a moment to flush, then finish terminating.
        Task {
            await ChannelLogger.shared.closeAll()
            try? await Task.sleep(for: .milliseconds(400))
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}

@main
struct Liquid_ChatApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var chatState = ChatState()

    init() {
        Task {
            await ConsoleLogger.shared.log("Liquid Chat launched", level: .info, category: "App")
        }
    }

    var body: some Scene {
        WindowGroup {
            MainWindow(chatState: chatState)
                .onAppear {
                    appDelegate.chatState = chatState
                    NotificationManager.shared.configure(chatState: chatState)
                    chatState.startSystemMonitors()
                }
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Connection...") {
                    chatState.showingNewConnectionSheet = true
                }
                .keyboardShortcut("n", modifiers: [.command])
            }

            CommandMenu("Channel") {
                Button("Join Channel...") {
                    // Prefer the selected channel's server, else the first connected one
                    let server = chatState.selectedChannel?.server
                        ?? chatState.servers.first(where: \.isConnected)
                    if let server {
                        chatState.showingChannelJoinForServer = server
                    }
                }
                .keyboardShortcut("t", modifiers: [.command])
                .disabled(chatState.servers.isEmpty)

                Button("Clear Buffer") {
                    chatState.clearSelectedChannelBuffer()
                }
                .keyboardShortcut("k", modifiers: [.command])
                .disabled(chatState.selectedChannel == nil)

                Divider()

                Button("Next Channel") {
                    chatState.selectNextChannel()
                }
                .keyboardShortcut(.downArrow, modifiers: [.command, .option])

                Button("Previous Channel") {
                    chatState.selectPreviousChannel()
                }
                .keyboardShortcut(.upArrow, modifiers: [.command, .option])

                Button("Next Unread") {
                    chatState.selectNextUnreadChannel()
                }
                .keyboardShortcut("u", modifiers: [.command, .option])
            }
        }

        Settings {
            SettingsView()
        }
    }
}
