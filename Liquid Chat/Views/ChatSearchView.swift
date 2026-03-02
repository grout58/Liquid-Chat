//
//  ChatSearchView.swift
//  Liquid Chat
//
//  In-chat search with Liquid Glass design
//

import SwiftUI

struct ChatSearchView: View {
    let channel: IRCChannel
    @Binding var isPresented: Bool
    @Binding var currentSearchText: String?
    @FocusState private var isSearchFieldFocused: Bool
    @State private var searchText = ""
    @State private var currentMatchIndex = 0
    @State private var caseSensitive = false
    @State private var searchInProgress = false
    @Environment(\.themeColors) private var themeColors
    @Namespace private var glassNamespace
    
    // Computed search results
    private var searchResults: [SearchResult] {
        guard !searchText.isEmpty else { return [] }
        
        var results: [SearchResult] = []
        let query = caseSensitive ? searchText : searchText.lowercased()
        
        for (index, message) in channel.messages.enumerated() {
            // Only search in actual messages and actions
            guard message.type == .message || message.type == .action else { continue }
            
            let messageContent = String(message.content.characters)
            let searchContent = caseSensitive ? messageContent : messageContent.lowercased()
            
            // Find all occurrences in this message
            var startIndex = searchContent.startIndex
            while let range = searchContent.range(of: query, range: startIndex..<searchContent.endIndex) {
                results.append(SearchResult(
                    messageIndex: index,
                    message: message,
                    range: range,
                    matchText: String(messageContent[range])
                ))
                startIndex = range.upperBound
            }
        }
        
        return results
    }
    
    private var currentResult: SearchResult? {
        guard !searchResults.isEmpty, currentMatchIndex < searchResults.count else { return nil }
        return searchResults[currentMatchIndex]
    }
    
    var body: some View {
        GlassEffectContainer(spacing: 16.0) {
            VStack(spacing: 0) {
                // Search bar with Liquid Glass
                HStack(spacing: 12) {
                    // Search icon
                    Image(systemName: "magnifyingglass")
                        .font(.body)
                        .foregroundStyle(themeColors.secondaryText)
                        .frame(width: 20)
                    
                    // Search text field
                    TextField("Search in conversation...", text: $searchText)
                        .textFieldStyle(.plain)
                        .focused($isSearchFieldFocused)
                        .font(.body)
                        .onSubmit {
                            navigateToNext()
                        }
                        .onChange(of: searchText) { _, newValue in
                            currentMatchIndex = 0
                            currentSearchText = newValue.isEmpty ? nil : newValue
                        }
                    
                    // Clear button
                    if !searchText.isEmpty {
                        Button {
                            withAnimation(.spring(duration: 0.3)) {
                                searchText = ""
                                currentMatchIndex = 0
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.body)
                                .foregroundStyle(themeColors.secondaryText)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.interactive(), in: .circle)
                        .glassEffectID("clear", in: glassNamespace)
                        .glassEffectTransition(.matchedGeometry)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .glassEffect(.regular.tint(.blue.opacity(0.1)).interactive(), in: .rect(cornerRadius: 20))
                .glassEffectID("searchbar", in: glassNamespace)
                
                // Results bar with navigation
                if !searchText.isEmpty {
                    HStack(spacing: 16) {
                        // Match count
                        HStack(spacing: 6) {
                            if searchResults.isEmpty {
                                Text("No matches")
                                    .font(.caption)
                                    .foregroundStyle(themeColors.secondaryText.opacity(0.7))
                            } else {
                                Text("\(currentMatchIndex + 1) of \(searchResults.count)")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(themeColors.text)
                                    .monospacedDigit()
                            }
                        }
                        .frame(minWidth: 80, alignment: .leading)
                        
                        Spacer()
                        
                        // Case sensitive toggle
                        Button {
                            withAnimation(.spring(duration: 0.25)) {
                                caseSensitive.toggle()
                                currentMatchIndex = 0
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "textformat")
                                    .font(.caption)
                                Text("Aa")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                            }
                            .foregroundStyle(caseSensitive ? themeColors.accent : themeColors.secondaryText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(
                            caseSensitive 
                                ? .regular.tint(themeColors.accent.opacity(0.15)).interactive() 
                                : .regular.interactive(),
                            in: .rect(cornerRadius: 8)
                        )
                        .glassEffectID("casesensitive", in: glassNamespace)
                        .help(caseSensitive ? "Case sensitive (on)" : "Case insensitive (off)")
                        
                        // Navigation buttons
                        if !searchResults.isEmpty {
                            HStack(spacing: 8) {
                                // Previous button
                                Button {
                                    navigateToPrevious()
                                } label: {
                                    Image(systemName: "chevron.up")
                                        .font(.caption)
                                        .frame(width: 24, height: 24)
                                }
                                .buttonStyle(.plain)
                                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 8))
                                .glassEffectID("prev", in: glassNamespace)
                                .disabled(searchResults.isEmpty)
                                .help("Previous match (Shift+Enter)")
                                
                                // Next button
                                Button {
                                    navigateToNext()
                                } label: {
                                    Image(systemName: "chevron.down")
                                        .font(.caption)
                                        .frame(width: 24, height: 24)
                                }
                                .buttonStyle(.plain)
                                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 8))
                                .glassEffectID("next", in: glassNamespace)
                                .disabled(searchResults.isEmpty)
                                .help("Next match (Enter)")
                            }
                            .glassEffectTransition(.matchedGeometry)
                        }
                        
                        // Close button
                        Button {
                            withAnimation(.spring(duration: 0.3)) {
                                isPresented = false
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 8))
                        .glassEffectID("close", in: glassNamespace)
                        .help("Close search (Escape)")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .glassEffect(.regular, in: .rect(cornerRadius: 12))
                    .glassEffectID("resultsbar", in: glassNamespace)
                    .glassEffectTransition(.matchedGeometry)
                }
            }
            .padding(12)
        }
        .onAppear {
            isSearchFieldFocused = true
        }
        .onDisappear {
            currentSearchText = nil
        }
        .onKeyPress(.escape) {
            isPresented = false
            return .handled
        }
        .onKeyPress(.return) {
            navigateToNext()
            return .handled
        }
        // Notify parent to scroll to current match
        .onChange(of: currentResult) { oldValue, newValue in
            if let result = newValue {
                NotificationCenter.default.post(
                    name: .scrollToSearchResult,
                    object: nil,
                    userInfo: ["messageIndex": result.messageIndex, "range": result.range]
                )
            }
        }
    }
    
    private func navigateToNext() {
        guard !searchResults.isEmpty else { return }
        withAnimation(.spring(duration: 0.25)) {
            currentMatchIndex = (currentMatchIndex + 1) % searchResults.count
        }
    }
    
    private func navigateToPrevious() {
        guard !searchResults.isEmpty else { return }
        withAnimation(.spring(duration: 0.25)) {
            currentMatchIndex = currentMatchIndex > 0 ? currentMatchIndex - 1 : searchResults.count - 1
        }
    }
}

// MARK: - Search Result Model

struct SearchResult: Identifiable, Equatable {
    let id = UUID()
    let messageIndex: Int
    let message: IRCChatMessage
    let range: Range<String.Index>
    let matchText: String
    
    static func == (lhs: SearchResult, rhs: SearchResult) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Notification Name Extension

extension Notification.Name {
    static let scrollToSearchResult = Notification.Name("scrollToSearchResult")
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State var isPresented = true
        @State var searchText: String? = nil
        
        var body: some View {
            let channel = IRCChannel(
                name: "#swift",
                server: IRCServer(config: IRCServerConfig(
                    hostname: "irc.libera.chat",
                    useSSL: true,
                    nickname: "TestUser"
                ))
            )
            
            channel.messages = [
                IRCChatMessage(sender: "Alice", content: "Hello everyone! Welcome to #swift", type: .message),
                IRCChatMessage(sender: "Bob", content: "Hi Alice, how are you doing today?", type: .message),
                IRCChatMessage(sender: "Charlie", content: "Working on a SwiftUI project", type: .message),
                IRCChatMessage(sender: "Alice", content: "That sounds exciting! What kind of project?", type: .message),
                IRCChatMessage(sender: "Charlie", content: "Building a macOS app with Liquid Glass effects", type: .message),
            ]
            
            return VStack {
                if isPresented {
                    ChatSearchView(channel: channel, isPresented: $isPresented, currentSearchText: $searchText)
                        .padding()
                }
                Spacer()
            }
            .frame(width: 600, height: 400)
        }
    }
    
    return PreviewWrapper()
}
