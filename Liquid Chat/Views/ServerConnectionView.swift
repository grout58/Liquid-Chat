//
//  ServerConnectionView.swift
//  Liquid Chat
//
//  Server connection dialog with Liquid Glass
//

import SwiftUI

struct ServerConnectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var serverManager = ServerConfigManager.shared
    @State private var selectedSavedServer: IRCServerConfig?
    @State private var showingSavedServers = true
    
    @State private var hostname = "irc.libera.chat"
    @State private var port = "6697"
    @State private var useSSL = true
    @State private var nickname = NSFullUserName()
    @State private var username = ""
    @State private var realname = ""
    @State private var password = ""
    @State private var savedName = ""
    @State private var authMethod: IRCAuthMethod = .none
    @State private var autoConnect = false
    @State private var saveServer = false
    
    /// Existing configuration to edit (nil for new connection)
    let existingConfig: IRCServerConfig?
    
    /// Callback when connecting to a new server
    let onConnect: ((IRCServerConfig) -> Void)?
    
    /// Callback when saving an edited server
    let onSave: ((IRCServerConfig) -> Void)?
    
    /// Initialize for creating a new server connection
    init(onConnect: @escaping (IRCServerConfig) -> Void) {
        self.existingConfig = nil
        self.onConnect = onConnect
        self.onSave = nil
    }
    
    /// Initialize for editing an existing server configuration
    init(existingConfig: IRCServerConfig, onSave: @escaping (IRCServerConfig) -> Void) {
        self.existingConfig = existingConfig
        self.onConnect = nil
        self.onSave = onSave
        
        // Pre-populate fields with existing config
        _hostname = State(initialValue: existingConfig.hostname)
        _port = State(initialValue: String(existingConfig.port))
        _useSSL = State(initialValue: existingConfig.useSSL)
        _nickname = State(initialValue: existingConfig.nickname)
        _username = State(initialValue: existingConfig.username)
        _realname = State(initialValue: existingConfig.realname)
        _password = State(initialValue: existingConfig.password ?? "")
        _savedName = State(initialValue: existingConfig.savedName ?? "")
        _authMethod = State(initialValue: existingConfig.authMethod)
        _autoConnect = State(initialValue: existingConfig.autoConnect)
        _saveServer = State(initialValue: true) // Always save when editing
        _showingSavedServers = State(initialValue: false) // Hide sidebar when editing
    }
    
    var body: some View {
        NavigationSplitView {
            // Saved servers sidebar
            VStack(alignment: .leading, spacing: 0) {
                Text("Saved Servers")
                    .font(.headline)
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                
                if serverManager.savedServers.isEmpty {
                    ContentUnavailableView {
                        Label("No Saved Servers", systemImage: "server.rack")
                    } description: {
                        Text("Configure and save a server to reuse it later")
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(serverManager.savedServers, selection: $selectedSavedServer) { server in
                        SavedServerRow(server: server)
                            .tag(server)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    serverManager.deleteServer(server)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                
                Button {
                    selectedSavedServer = nil
                    clearForm()
                } label: {
                    Label("New Server", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }
            .frame(minWidth: 200, idealWidth: 250)
            .navigationTitle("Servers")
        } detail: {
            // Server configuration form
            Form {
                Section("Server") {
                TextField("Hostname", text: $hostname)
                    .textContentType(.URL)
                
                HStack {
                    TextField("Port", text: $port)
                        .textContentType(.none)
                        .frame(width: 100)
                    
                    Spacer()
                    
                    Toggle("Use SSL/TLS", isOn: $useSSL)
                }
            }
            
            Section("Identity") {
                TextField("Nickname", text: $nickname)
                    .textContentType(.nickname)
                
                TextField("Username (optional)", text: $username)
                    .textContentType(.username)
                
                TextField("Real Name (optional)", text: $realname)
                    .textContentType(.name)
            }
            
            Section("Authentication") {
                Picker("Method", selection: $authMethod) {
                    Text("None").tag(IRCAuthMethod.none)
                    Text("Server Password").tag(IRCAuthMethod.password)
                    Text("SASL").tag(IRCAuthMethod.sasl)
                    Text("NickServ").tag(IRCAuthMethod.nickserv)
                }
                
                if authMethod != .none {
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                }
            }
            
            Section("Options") {
                Toggle("Save this server", isOn: $saveServer)
                
                if saveServer {
                    TextField("Server name (optional)", text: $savedName)
                        .textContentType(.organizationName)
                }
                
                Toggle("Connect automatically on startup", isOn: $autoConnect)
                    .disabled(!saveServer)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(selectedSavedServer != nil ? "Edit Server" : "New Server")
        .onChange(of: selectedSavedServer) { _, newValue in
            if let server = newValue {
                loadServerIntoForm(server)
            }
        }
        }
        .frame(width: 800, height: 500)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.glass)
            }
            
            ToolbarItem(placement: .automatic) {
                Button("Save") {
                    saveOnly()
                }
                .buttonStyle(.bordered)
                .disabled(!isValid)
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button("Connect") {
                    connect()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
            }
        }
    }
    
    private var isValid: Bool {
        guard !hostname.trimmingCharacters(in: .whitespaces).isEmpty,
              !nickname.trimmingCharacters(in: .whitespaces).isEmpty else {
            return false
        }
        
        // Validate port is a valid UInt16 (1-65535)
        guard let portNumber = UInt16(port), portNumber > 0 else {
            return false
        }
        
        return true
    }
    
    private func connect() {
        let config = createConfig()
        
        // Save server if requested
        if saveServer {
            serverManager.saveServer(config)
        }
        
        // Handle both new connections and edits
        if let onSave = onSave {
            // Editing existing server
            onSave(config)
        } else if let onConnect = onConnect {
            // New connection
            onConnect(config)
        }
        
        dismiss()
    }
    
    private func saveOnly() {
        // Ensure saveServer is enabled when explicitly saving
        saveServer = true
        
        let config = createConfig()
        ConsoleLogger.shared.log("Saving server: \(config.displayName) with ID: \(config.id)", level: .info, category: "Settings")
        ConsoleLogger.shared.log("Current saved servers count: \(serverManager.savedServers.count)", level: .debug, category: "Settings")
        serverManager.saveServer(config)
        ConsoleLogger.shared.log("After save, saved servers count: \(serverManager.savedServers.count)", level: .debug, category: "Settings")
        ConsoleLogger.shared.log("Saved servers: \(serverManager.savedServers.map { $0.displayName })", level: .debug, category: "Settings")
        
        // Update the selected server to reflect the save
        selectedSavedServer = config
    }
    
    private func createConfig() -> IRCServerConfig {
        // Preserve ID when editing, otherwise create new
        let configId = existingConfig?.id ?? selectedSavedServer?.id ?? UUID()
        
        return IRCServerConfig(
            id: configId,
            hostname: hostname,
            port: UInt16(port) ?? 6667,
            useSSL: useSSL,
            nickname: nickname,
            username: username.isEmpty ? nil : username,
            realname: realname.isEmpty ? nil : realname,
            password: password.isEmpty ? nil : password,
            authMethod: authMethod,
            autoConnect: saveServer ? autoConnect : false,
            savedName: savedName.isEmpty ? nil : savedName
        )
    }
    
    private func loadServerIntoForm(_ server: IRCServerConfig) {
        hostname = server.hostname
        port = String(server.port)
        useSSL = server.useSSL
        nickname = server.nickname
        username = server.username == server.nickname ? "" : server.username
        realname = server.realname == server.nickname ? "" : server.realname
        password = server.password ?? ""
        savedName = server.savedName ?? ""
        authMethod = server.authMethod
        autoConnect = server.autoConnect
        saveServer = true
    }
    
    private func clearForm() {
        hostname = "irc.libera.chat"
        port = "6697"
        useSSL = true
        nickname = NSFullUserName()
        username = ""
        realname = ""
        password = ""
        savedName = ""
        authMethod = .none
        autoConnect = false
        saveServer = false
    }
}

struct SavedServerRow: View {
    let server: IRCServerConfig
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(server.displayName)
                .font(.headline)
            
            HStack(spacing: 4) {
                Image(systemName: server.useSSL ? "lock.fill" : "lock.open")
                    .font(.caption2)
                Text(server.hostname)
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
            
            if server.autoConnect {
                Label("Auto-connect", systemImage: "bolt.fill")
                    .font(.caption2)
                    .foregroundStyle(.blue)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ServerConnectionView { config in
        print("Connecting to \(config.hostname)")
    }
}
