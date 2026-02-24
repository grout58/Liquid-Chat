//
//  ServerConfigManager.swift
//  Liquid Chat
//
//  Manages saved IRC server configurations
//

import Foundation

/// Manages persistence and retrieval of saved server configurations
@Observable
class ServerConfigManager {
    static let shared = ServerConfigManager()
    
    private let userDefaultsKey = "savedServerConfigs"
    
    var savedServers: [IRCServerConfig] = []
    
    private init() {
        loadSavedServers()
    }
    
    // MARK: - Persistence
    
    /// Load saved servers from UserDefaults
    private func loadSavedServers() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            ConsoleLogger.shared.log("No saved servers found in UserDefaults", level: .info, category: "Settings")
            savedServers = []
            return
        }
        
        do {
            savedServers = try JSONDecoder().decode([IRCServerConfig].self, from: data)
            ConsoleLogger.shared.log("Loaded \(savedServers.count) saved servers", level: .info, category: "Settings")
        } catch {
            ConsoleLogger.shared.log("Failed to load saved servers: \(error)", level: .error, category: "Settings")
            savedServers = []
        }
    }
    
    /// Save servers to UserDefaults
    private func persist() {
        do {
            let data = try JSONEncoder().encode(savedServers)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
            UserDefaults.standard.synchronize() // Force write to disk
            ConsoleLogger.shared.log("Persisted \(savedServers.count) servers to UserDefaults", level: .debug, category: "Settings")
        } catch {
            ConsoleLogger.shared.log("Failed to save servers: \(error)", level: .error, category: "Settings")
        }
    }
    
    // MARK: - CRUD Operations
    
    /// Save a new server configuration
    func saveServer(_ config: IRCServerConfig) {
        // Check if server already exists (by id)
        if let index = savedServers.firstIndex(where: { $0.id == config.id }) {
            // Update existing
            savedServers[index] = config
        } else {
            // Add new
            savedServers.append(config)
        }
        persist()
    }
    
    /// Delete a server configuration
    func deleteServer(_ config: IRCServerConfig) {
        savedServers.removeAll { $0.id == config.id }
        persist()
    }
    
    /// Delete a server by id
    func deleteServer(id: UUID) {
        savedServers.removeAll { $0.id == id }
        persist()
    }
    
    /// Update an existing server configuration
    func updateServer(_ config: IRCServerConfig) {
        if let index = savedServers.firstIndex(where: { $0.id == config.id }) {
            savedServers[index] = config
            persist()
        }
    }
    
    /// Get auto-connect servers
    var autoConnectServers: [IRCServerConfig] {
        savedServers.filter { $0.autoConnect }
    }
    
    /// Clear all saved servers
    func clearAll() {
        savedServers.removeAll()
        persist()
    }
}
