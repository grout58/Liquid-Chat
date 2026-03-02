//
//  ServerConfigManager.swift
//  Liquid Chat
//
//  Manages saved IRC server configurations.
//  Passwords are stored in the macOS Keychain — NOT in UserDefaults.
//

import Foundation

/// Manages persistence and retrieval of saved server configurations.
@Observable
class ServerConfigManager {
    static let shared = ServerConfigManager()

    private let userDefaultsKey = "savedServerConfigs"

    var savedServers: [IRCServerConfig] = []

    private init() {
        loadSavedServers()
    }

    // MARK: - Persistence

    private func loadSavedServers() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            Task { await ConsoleLogger.shared.log("No saved servers found in UserDefaults", level: .info, category: "Settings") }
            savedServers = []
            return
        }

        do {
            // Configs on disk have password = nil (stripped before save).
            // Re-hydrate each config with its Keychain password.
            var configs = try JSONDecoder().decode([IRCServerConfig].self, from: data)
            configs = configs.map { config in
                let stored = KeychainManager.loadPassword(for: config.id)
                return config.withPassword(stored)
            }
            savedServers = configs
            Task { await ConsoleLogger.shared.log("Loaded \(savedServers.count) saved servers", level: .info, category: "Settings") }
        } catch {
            Task { await ConsoleLogger.shared.log("Failed to load saved servers: \(error)", level: .error, category: "Settings") }
            savedServers = []
        }
    }

    private func persist() {
        // Strip passwords before writing to UserDefaults; store them in Keychain.
        let stripped = savedServers.map { $0.withPassword(nil) }
        do {
            let data = try JSONEncoder().encode(stripped)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
            Task { await ConsoleLogger.shared.log("Persisted \(savedServers.count) servers", level: .debug, category: "Settings") }
        } catch {
            Task { await ConsoleLogger.shared.log("Failed to save servers: \(error)", level: .error, category: "Settings") }
        }
    }

    // MARK: - CRUD

    func saveServer(_ config: IRCServerConfig) {
        // Save password to Keychain (or delete if nil)
        if let pw = config.password {
            KeychainManager.savePassword(pw, for: config.id)
        } else {
            KeychainManager.deletePassword(for: config.id)
        }

        if let index = savedServers.firstIndex(where: { $0.id == config.id }) {
            savedServers[index] = config
        } else {
            savedServers.append(config)
        }
        persist()
    }

    func deleteServer(_ config: IRCServerConfig) {
        KeychainManager.deletePassword(for: config.id)
        savedServers.removeAll { $0.id == config.id }
        persist()
    }

    func deleteServer(id: UUID) {
        KeychainManager.deletePassword(for: id)
        savedServers.removeAll { $0.id == id }
        persist()
    }

    func updateServer(_ config: IRCServerConfig) {
        if let index = savedServers.firstIndex(where: { $0.id == config.id }) {
            if let pw = config.password {
                KeychainManager.savePassword(pw, for: config.id)
            } else {
                KeychainManager.deletePassword(for: config.id)
            }
            savedServers[index] = config
            persist()
        }
    }

    var autoConnectServers: [IRCServerConfig] {
        savedServers.filter { $0.autoConnect }
    }

    func clearAll() {
        savedServers.forEach { KeychainManager.deletePassword(for: $0.id) }
        savedServers.removeAll()
        persist()
    }
}
