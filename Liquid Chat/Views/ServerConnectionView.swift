//
//  ServerConnectionView.swift
//  Liquid Chat
//
//  Server connection dialog with Liquid Glass
//

import SwiftUI

struct ServerConnectionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var hostname = "irc.libera.chat"
    @State private var port = "6697"
    @State private var useSSL = true
    @State private var nickname = NSFullUserName()
    @State private var username = ""
    @State private var realname = ""
    @State private var password = ""
    @State private var authMethod: IRCAuthMethod = .none
    @State private var autoConnect = true
    
    let onConnect: (IRCServerConfig) -> Void
    
    var body: some View {
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
            
            Section {
                Toggle("Connect automatically on startup", isOn: $autoConnect)
            }
        }
        .formStyle(.grouped)
        .frame(width: 500, height: 450)
        .navigationTitle("Connect to Server")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.glass)
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button("Connect") {
                    connect()
                }
                .buttonStyle(.glassProminent)
                .disabled(!isValid)
            }
        }
    }
    
    private var isValid: Bool {
        !hostname.trimmingCharacters(in: .whitespaces).isEmpty &&
        !nickname.trimmingCharacters(in: .whitespaces).isEmpty &&
        Int(port) != nil
    }
    
    private func connect() {
        let config = IRCServerConfig(
            hostname: hostname,
            port: UInt16(port) ?? 6667,
            useSSL: useSSL,
            nickname: nickname,
            username: username.isEmpty ? nil : username,
            realname: realname.isEmpty ? nil : realname,
            password: password.isEmpty ? nil : password,
            authMethod: authMethod
        )
        
        onConnect(config)
        dismiss()
    }
}

#Preview {
    ServerConnectionView { config in
        print("Connecting to \(config.hostname)")
    }
}
