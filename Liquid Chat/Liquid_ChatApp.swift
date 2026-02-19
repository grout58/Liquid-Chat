//
//  Liquid_ChatApp.swift
//  Liquid Chat
//
//  Modern IRC client for macOS 26 with Liquid Glass
//  Created by Jason Grout on 2/19/26.
//

import SwiftUI

@main
struct Liquid_ChatApp: App {
    init() {
        ConsoleLogger.shared.log("Liquid Chat launched", level: .info, category: "App")
    }
    
    var body: some Scene {
        WindowGroup {
            MainWindow()
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Connection...") {
                    // Open server connection dialog
                }
                .keyboardShortcut("n", modifiers: [.command])
            }
        }
    }
}
