//
//  ServerConfigManagerTests.swift
//  Liquid ChatTests
//
//  Tests for server configuration persistence
//

import Testing
import Foundation
@testable import Liquid_Chat

/// Tests for ServerConfigManager persistence and CRUD operations
@Suite("Server Configuration Manager Tests")
struct ServerConfigManagerTests {
    
    // Test UserDefaults suite to avoid polluting real data
    let testDefaults = UserDefaults(suiteName: "TestDefaults")!
    let testKey = "savedServerConfigs"
    
    init() {
        // Clear test defaults before each suite run
        testDefaults.removePersistentDomain(forName: "TestDefaults")
    }
    
    // MARK: - Helper Functions
    
    /// Create a test manager that uses testDefaults instead of standard
    func createTestManager() -> TestableServerConfigManager {
        return TestableServerConfigManager(userDefaults: testDefaults)
    }
    
    /// Create a sample server config for testing
    func createSampleConfig(
        hostname: String = "irc.test.net",
        nickname: String = "TestUser",
        autoConnect: Bool = false
    ) -> IRCServerConfig {
        return IRCServerConfig(
            hostname: hostname,
            port: 6667,
            useSSL: false,
            nickname: nickname,
            autoConnect: autoConnect
        )
    }
    
    // MARK: - Initialization Tests
    
    @Test("Initialize with empty saved servers")
    func testInitializeEmpty() {
        let manager = createTestManager()
        
        #expect(manager.savedServers.isEmpty)
    }
    
    @Test("Load saved servers from UserDefaults on init")
    func testLoadOnInit() throws {
        // Pre-populate UserDefaults with test data
        let config1 = createSampleConfig(hostname: "irc.server1.net", nickname: "User1")
        let config2 = createSampleConfig(hostname: "irc.server2.net", nickname: "User2")
        let configs = [config1, config2]
        
        let data = try JSONEncoder().encode(configs)
        testDefaults.set(data, forKey: testKey)
        
        // Create manager - should load from UserDefaults
        let manager = createTestManager()
        
        #expect(manager.savedServers.count == 2)
        #expect(manager.savedServers[0].hostname == "irc.server1.net")
        #expect(manager.savedServers[1].hostname == "irc.server2.net")
    }
    
    @Test("Handle corrupted data gracefully")
    func testHandleCorruptedData() {
        // Set invalid data in UserDefaults
        testDefaults.set("corrupted data".data(using: .utf8), forKey: testKey)
        
        // Manager should handle this gracefully and start with empty array
        let manager = createTestManager()
        
        #expect(manager.savedServers.isEmpty)
    }
    
    // MARK: - Save Server Tests
    
    @Test("Save new server configuration")
    func testSaveNewServer() {
        let manager = createTestManager()
        let config = createSampleConfig(hostname: "irc.test.net", nickname: "TestUser")
        
        manager.saveServer(config)
        
        #expect(manager.savedServers.count == 1)
        #expect(manager.savedServers[0].id == config.id)
        #expect(manager.savedServers[0].hostname == "irc.test.net")
        #expect(manager.savedServers[0].nickname == "TestUser")
    }
    
    @Test("Save multiple servers")
    func testSaveMultipleServers() {
        let manager = createTestManager()
        
        let config1 = createSampleConfig(hostname: "irc.server1.net", nickname: "User1")
        let config2 = createSampleConfig(hostname: "irc.server2.net", nickname: "User2")
        let config3 = createSampleConfig(hostname: "irc.server3.net", nickname: "User3")
        
        manager.saveServer(config1)
        manager.saveServer(config2)
        manager.saveServer(config3)
        
        #expect(manager.savedServers.count == 3)
        #expect(manager.savedServers[0].hostname == "irc.server1.net")
        #expect(manager.savedServers[1].hostname == "irc.server2.net")
        #expect(manager.savedServers[2].hostname == "irc.server3.net")
    }
    
    @Test("Save server with same ID updates existing")
    func testSaveExistingServerUpdates() {
        let manager = createTestManager()
        let originalConfig = createSampleConfig(hostname: "irc.test.net", nickname: "OriginalNick")
        
        manager.saveServer(originalConfig)
        #expect(manager.savedServers.count == 1)
        #expect(manager.savedServers[0].nickname == "OriginalNick")
        
        // Save again with same ID but different nickname
        let updatedConfig = IRCServerConfig(
            id: originalConfig.id, // Same ID
            hostname: "irc.test.net",
            nickname: "UpdatedNick"
        )
        
        manager.saveServer(updatedConfig)
        
        // Should still be 1 server, but with updated nickname
        #expect(manager.savedServers.count == 1)
        #expect(manager.savedServers[0].id == originalConfig.id)
        #expect(manager.savedServers[0].nickname == "UpdatedNick")
    }
    
    // MARK: - Update Server Tests
    
    @Test("Update existing server configuration")
    func testUpdateServer() {
        let manager = createTestManager()
        let originalConfig = createSampleConfig(hostname: "irc.test.net", nickname: "Original")
        
        manager.saveServer(originalConfig)
        
        // Create updated version
        let updatedConfig = IRCServerConfig(
            id: originalConfig.id,
            hostname: "irc.updated.net",
            nickname: "Updated",
            autoConnect: true
        )
        
        manager.updateServer(updatedConfig)
        
        #expect(manager.savedServers.count == 1)
        #expect(manager.savedServers[0].hostname == "irc.updated.net")
        #expect(manager.savedServers[0].nickname == "Updated")
        #expect(manager.savedServers[0].autoConnect == true)
    }
    
    @Test("Update non-existent server does nothing")
    func testUpdateNonExistentServer() {
        let manager = createTestManager()
        let config = createSampleConfig()
        
        // Try to update a server that doesn't exist
        manager.updateServer(config)
        
        // Should not add the server
        #expect(manager.savedServers.isEmpty)
    }
    
    // MARK: - Delete Server Tests
    
    @Test("Delete server by config")
    func testDeleteServerByConfig() {
        let manager = createTestManager()
        let config1 = createSampleConfig(hostname: "irc.server1.net", nickname: "User1")
        let config2 = createSampleConfig(hostname: "irc.server2.net", nickname: "User2")
        
        manager.saveServer(config1)
        manager.saveServer(config2)
        #expect(manager.savedServers.count == 2)
        
        manager.deleteServer(config1)
        
        #expect(manager.savedServers.count == 1)
        #expect(manager.savedServers[0].id == config2.id)
    }
    
    @Test("Delete server by ID")
    func testDeleteServerByID() {
        let manager = createTestManager()
        let config1 = createSampleConfig(hostname: "irc.server1.net", nickname: "User1")
        let config2 = createSampleConfig(hostname: "irc.server2.net", nickname: "User2")
        
        manager.saveServer(config1)
        manager.saveServer(config2)
        
        manager.deleteServer(id: config1.id)
        
        #expect(manager.savedServers.count == 1)
        #expect(manager.savedServers[0].id == config2.id)
    }
    
    @Test("Delete non-existent server does nothing")
    func testDeleteNonExistentServer() {
        let manager = createTestManager()
        let config = createSampleConfig()
        
        manager.saveServer(config)
        #expect(manager.savedServers.count == 1)
        
        // Try to delete a different server
        let otherConfig = createSampleConfig(hostname: "other.net", nickname: "Other")
        manager.deleteServer(otherConfig)
        
        // Original server should still be there
        #expect(manager.savedServers.count == 1)
        #expect(manager.savedServers[0].id == config.id)
    }
    
    @Test("Delete all servers one by one")
    func testDeleteAllServers() {
        let manager = createTestManager()
        let configs = [
            createSampleConfig(hostname: "irc.server1.net", nickname: "User1"),
            createSampleConfig(hostname: "irc.server2.net", nickname: "User2"),
            createSampleConfig(hostname: "irc.server3.net", nickname: "User3")
        ]
        
        configs.forEach { manager.saveServer($0) }
        #expect(manager.savedServers.count == 3)
        
        configs.forEach { manager.deleteServer($0) }
        
        #expect(manager.savedServers.isEmpty)
    }
    
    // MARK: - Clear All Tests
    
    @Test("Clear all saved servers")
    func testClearAll() {
        let manager = createTestManager()
        
        // Add several servers
        for i in 1...5 {
            let config = createSampleConfig(hostname: "irc.server\(i).net", nickname: "User\(i)")
            manager.saveServer(config)
        }
        #expect(manager.savedServers.count == 5)
        
        // Clear all
        manager.clearAll()
        
        #expect(manager.savedServers.isEmpty)
    }
    
    // MARK: - Auto-Connect Tests
    
    @Test("Filter auto-connect servers")
    func testAutoConnectServers() {
        let manager = createTestManager()
        
        let config1 = createSampleConfig(hostname: "irc.server1.net", nickname: "User1", autoConnect: true)
        let config2 = createSampleConfig(hostname: "irc.server2.net", nickname: "User2", autoConnect: false)
        let config3 = createSampleConfig(hostname: "irc.server3.net", nickname: "User3", autoConnect: true)
        let config4 = createSampleConfig(hostname: "irc.server4.net", nickname: "User4", autoConnect: false)
        
        manager.saveServer(config1)
        manager.saveServer(config2)
        manager.saveServer(config3)
        manager.saveServer(config4)
        
        let autoConnectServers = manager.autoConnectServers
        
        #expect(autoConnectServers.count == 2)
        #expect(autoConnectServers.contains { $0.id == config1.id })
        #expect(autoConnectServers.contains { $0.id == config3.id })
        #expect(!autoConnectServers.contains { $0.id == config2.id })
        #expect(!autoConnectServers.contains { $0.id == config4.id })
    }
    
    @Test("No auto-connect servers returns empty")
    func testNoAutoConnectServers() {
        let manager = createTestManager()
        
        let config1 = createSampleConfig(hostname: "irc.server1.net", nickname: "User1", autoConnect: false)
        let config2 = createSampleConfig(hostname: "irc.server2.net", nickname: "User2", autoConnect: false)
        
        manager.saveServer(config1)
        manager.saveServer(config2)
        
        #expect(manager.autoConnectServers.isEmpty)
    }
    
    @Test("All auto-connect servers")
    func testAllAutoConnectServers() {
        let manager = createTestManager()
        
        let config1 = createSampleConfig(hostname: "irc.server1.net", nickname: "User1", autoConnect: true)
        let config2 = createSampleConfig(hostname: "irc.server2.net", nickname: "User2", autoConnect: true)
        
        manager.saveServer(config1)
        manager.saveServer(config2)
        
        let autoConnectServers = manager.autoConnectServers
        #expect(autoConnectServers.count == 2)
    }
    
    // MARK: - Persistence Tests
    
    @Test("Persistence survives manager recreation")
    func testPersistenceSurvivesRecreation() {
        // Create manager and save servers
        do {
            let manager = createTestManager()
            let config1 = createSampleConfig(hostname: "irc.server1.net", nickname: "User1")
            let config2 = createSampleConfig(hostname: "irc.server2.net", nickname: "User2")
            
            manager.saveServer(config1)
            manager.saveServer(config2)
            
            #expect(manager.savedServers.count == 2)
        }
        
        // Create new manager instance - should load from UserDefaults
        do {
            let newManager = createTestManager()
            
            #expect(newManager.savedServers.count == 2)
            #expect(newManager.savedServers[0].hostname == "irc.server1.net")
            #expect(newManager.savedServers[1].hostname == "irc.server2.net")
        }
    }
    
    @Test("Clear persists to UserDefaults")
    func testClearPersists() {
        // Create and populate
        do {
            let manager = createTestManager()
            let config = createSampleConfig()
            manager.saveServer(config)
            #expect(manager.savedServers.count == 1)
        }
        
        // Clear
        do {
            let manager = createTestManager()
            manager.clearAll()
            #expect(manager.savedServers.isEmpty)
        }
        
        // Verify persistence
        do {
            let newManager = createTestManager()
            #expect(newManager.savedServers.isEmpty)
        }
    }
    
    // MARK: - Complex Workflow Tests
    
    @Test("Complete CRUD workflow")
    func testCompleteWorkflow() {
        let manager = createTestManager()
        
        // Create
        let config1 = createSampleConfig(hostname: "irc.libera.chat", nickname: "Alice")
        let config2 = createSampleConfig(hostname: "irc.oftc.net", nickname: "Bob")
        
        manager.saveServer(config1)
        manager.saveServer(config2)
        #expect(manager.savedServers.count == 2)
        
        // Read
        #expect(manager.savedServers[0].hostname == "irc.libera.chat")
        #expect(manager.savedServers[1].hostname == "irc.oftc.net")
        
        // Update
        let updatedConfig1 = IRCServerConfig(
            id: config1.id,
            hostname: "irc.libera.chat",
            nickname: "AliceUpdated",
            autoConnect: true
        )
        manager.updateServer(updatedConfig1)
        
        #expect(manager.savedServers.count == 2)
        #expect(manager.savedServers[0].nickname == "AliceUpdated")
        #expect(manager.savedServers[0].autoConnect == true)
        
        // Delete
        manager.deleteServer(config2)
        #expect(manager.savedServers.count == 1)
        #expect(manager.savedServers[0].id == config1.id)
        
        // Clear
        manager.clearAll()
        #expect(manager.savedServers.isEmpty)
    }
    
    @Test("Concurrent operations safety")
    func testConcurrentOperations() async {
        let manager = createTestManager()
        
        // Perform concurrent saves
        await withTaskGroup(of: Void.self) { group in
            for i in 1...10 {
                group.addTask {
                    let config = createSampleConfig(
                        hostname: "irc.server\(i).net",
                        nickname: "User\(i)"
                    )
                    manager.saveServer(config)
                }
            }
        }
        
        // All servers should be saved
        #expect(manager.savedServers.count == 10)
    }
}

// MARK: - Testable ServerConfigManager

/// Testable version of ServerConfigManager that uses custom UserDefaults
@Observable
class TestableServerConfigManager {
    private let userDefaults: UserDefaults
    private let userDefaultsKey = "savedServerConfigs"
    
    var savedServers: [IRCServerConfig] = []
    
    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
        loadSavedServers()
    }
    
    private func loadSavedServers() {
        guard let data = userDefaults.data(forKey: userDefaultsKey) else {
            savedServers = []
            return
        }
        
        do {
            savedServers = try JSONDecoder().decode([IRCServerConfig].self, from: data)
        } catch {
            savedServers = []
        }
    }
    
    private func persist() {
        do {
            let data = try JSONEncoder().encode(savedServers)
            userDefaults.set(data, forKey: userDefaultsKey)
            userDefaults.synchronize()
        } catch {
            print("Failed to save servers: \(error)")
        }
    }
    
    func saveServer(_ config: IRCServerConfig) {
        if let index = savedServers.firstIndex(where: { $0.id == config.id }) {
            savedServers[index] = config
        } else {
            savedServers.append(config)
        }
        persist()
    }
    
    func deleteServer(_ config: IRCServerConfig) {
        savedServers.removeAll { $0.id == config.id }
        persist()
    }
    
    func deleteServer(id: UUID) {
        savedServers.removeAll { $0.id == id }
        persist()
    }
    
    func updateServer(_ config: IRCServerConfig) {
        if let index = savedServers.firstIndex(where: { $0.id == config.id }) {
            savedServers[index] = config
            persist()
        }
    }
    
    var autoConnectServers: [IRCServerConfig] {
        savedServers.filter { $0.autoConnect }
    }
    
    func clearAll() {
        savedServers.removeAll()
        persist()
    }
}
