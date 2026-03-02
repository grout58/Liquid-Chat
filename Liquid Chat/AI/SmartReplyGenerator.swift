//
//  SmartReplyGenerator.swift
//  Liquid Chat
//
//  AI-powered smart reply suggestions using Apple Intelligence
//  Generates contextual quick replies based on recent conversation
//

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Represents a suggested quick reply with context
struct SmartReply: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let emoji: String
    let category: ReplyCategory
    let confidence: Double // 0.0 - 1.0
    
    enum ReplyCategory: String, CaseIterable {
        case agreement = "👍"
        case question = "❓"
        case thanks = "🙏"
        case greeting = "👋"
        case technical = "⚙️"
        case humor = "😄"
    }
}

/// AI-powered smart reply suggestion engine
/// Analyzes recent messages to generate contextual quick replies
@Observable
class SmartReplyGenerator {
    /// Whether the generator is currently processing
    var isProcessing = false
    
    /// Current smart reply suggestions
    var suggestions: [SmartReply] = []
    
    /// Last error encountered
    var lastError: SmartReplyError?
    
    /// Minimum confidence threshold for displaying suggestions
    private let confidenceThreshold: Double = 0.6
    
    init() {
        #if canImport(FoundationModels)
        Task { await ConsoleLogger.shared.log("SmartReplyGenerator initialized with FoundationModels support", level: .info, category: "AI") }
        #else
        Task { await ConsoleLogger.shared.log("SmartReplyGenerator initialized without FoundationModels (requires macOS 26+)", level: .warning, category: "AI") }
        #endif
    }
    
    /// Generate smart reply suggestions based on recent conversation
    /// - Parameters:
    ///   - messages: Recent messages from the channel
    ///   - currentNickname: User's current nickname (to exclude their own messages)
    /// - Returns: Array of smart reply suggestions
    @MainActor
    func generateReplies(
        basedOn messages: [IRCChatMessage],
        currentNickname: String
    ) async throws -> [SmartReply] {
        guard !isProcessing else {
            throw SmartReplyError.alreadyProcessing
        }
        
        // Check if AI features are enabled
        guard AppSettings.shared.enableAIFeatures else {
            throw SmartReplyError.featuresDisabled
        }
        
        // Only generate replies if there are recent messages from others
        let recentMessages = messages.suffix(10).filter { $0.sender != currentNickname }
        guard !recentMessages.isEmpty else {
            throw SmartReplyError.noRecentMessages
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        #if canImport(FoundationModels)
        return try await generateRepliesWithAI(messages: Array(recentMessages))
        #else
        // Fallback to rule-based suggestions
        return generateBasicReplies(messages: Array(recentMessages))
        #endif
    }
    
    #if canImport(FoundationModels)
    /// Generate smart replies using Apple Intelligence
    @MainActor
    private func generateRepliesWithAI(messages: [IRCChatMessage]) async throws -> [SmartReply] {
        let model = SystemLanguageModel.default
        guard model.isAvailable else {
            throw SmartReplyError.modelUnavailable
        }
        
        let session = LanguageModelSession(model: model)
        
        // Format recent messages for context
        let conversationContext = formatConversation(messages)
        
        // Get the last message for immediate context
        guard let lastMessage = messages.last else {
            throw SmartReplyError.noRecentMessages
        }
        
        let lastContent = String(lastMessage.content.characters)
        
        // Create AI prompt for smart replies
        let prompt = """
        Based on this IRC conversation, generate 3-4 contextual quick reply suggestions.
        
        Recent Conversation:
        \(conversationContext)
        
        Last Message: <\(lastMessage.sender)> \(lastContent)
        
        Generate natural, conversational replies that:
        1. Respond directly to the last message
        2. Match IRC chat style (concise, casual)
        3. Are appropriate for technical/community discussions
        4. Include variety (agreement, question, thanks, technical response, etc.)
        5. Each reply should be 1-10 words maximum
        
        Provide confidence score (0.0-1.0) for each suggestion.
        Include an emoji category: agreement (👍), question (❓), thanks (🙏), greeting (👋), technical (⚙️), or humor (😄)
        """
        
        // Configure generation options for quick, focused responses
        var options = GenerationOptions()
        options.temperature = 0.4 // Lower temperature for more focused replies
        
        // Generate structured suggestions
        let response: [AISmartReply]
        do {
            let result = try await session.respond(
                to: prompt,
                generating: [AISmartReply].self,
                includeSchemaInPrompt: true,
                options: options
            )
            response = result.content
        } catch {
            Task { await ConsoleLogger.shared.log("Smart reply generation failed: \(error)", level: .error, category: "AI") }
            throw SmartReplyError.generationFailed(error.localizedDescription)
        }
        
        // Convert AI replies to app model, filtering by confidence
        let replies = response
            .filter { $0.confidence >= confidenceThreshold }
            .compactMap { aiReply -> SmartReply? in
                guard let category = SmartReply.ReplyCategory(rawValue: aiReply.emojiCategory) else {
                    return nil
                }
                return SmartReply(
                    text: aiReply.text,
                    emoji: category.rawValue,
                    category: category,
                    confidence: aiReply.confidence
                )
            }
            .sorted { $0.confidence > $1.confidence }
            .prefix(4)
        
        suggestions = Array(replies)
        
        Task { await ConsoleLogger.shared.log("Generated \(suggestions.count) AI-powered smart replies", level: .info, category: "AI") }
        return suggestions
    }
    
    /// AI-structured smart reply format
    @Generable(description: "Contextual quick reply suggestion for IRC chat")
    struct AISmartReply {
        let text: String
        let emojiCategory: String // One of: 👍, ❓, 🙏, 👋, ⚙️, 😄
        let confidence: Double
    }
    #endif
    
    /// Fallback rule-based smart replies (no AI)
    private func generateBasicReplies(messages: [IRCChatMessage]) -> [SmartReply] {
        Task { await ConsoleLogger.shared.log("Using basic rule-based replies (FoundationModels unavailable)", level: .info, category: "AI") }
        
        guard let lastMessage = messages.last else { return [] }
        let lastContent = String(lastMessage.content.characters).lowercased()
        
        var replies: [SmartReply] = []
        
        // Question detection
        if lastContent.contains("?") {
            replies.append(SmartReply(text: "I'm not sure, let me check", emoji: "❓", category: .question, confidence: 0.7))
            replies.append(SmartReply(text: "Good question!", emoji: "💡", category: .question, confidence: 0.7))
        }
        
        // Thanks detection
        if lastContent.contains("thanks") || lastContent.contains("thank") {
            replies.append(SmartReply(text: "You're welcome!", emoji: "🙏", category: .thanks, confidence: 0.85))
            replies.append(SmartReply(text: "Happy to help!", emoji: "😊", category: .thanks, confidence: 0.8))
        }
        
        // Greeting detection
        if lastContent.contains("hello") || lastContent.contains("hi ") || lastContent.hasPrefix("hi") {
            replies.append(SmartReply(text: "Hey there!", emoji: "👋", category: .greeting, confidence: 0.9))
        }
        
        // Technical keywords
        let technicalKeywords = ["error", "bug", "crash", "issue", "problem", "fail"]
        if technicalKeywords.contains(where: { lastContent.contains($0) }) {
            replies.append(SmartReply(text: "Can you share more details?", emoji: "⚙️", category: .technical, confidence: 0.75))
            replies.append(SmartReply(text: "Did you check the logs?", emoji: "🔍", category: .technical, confidence: 0.7))
        }
        
        // Default suggestions if nothing specific
        if replies.isEmpty {
            replies.append(SmartReply(text: "Agreed", emoji: "👍", category: .agreement, confidence: 0.65))
            replies.append(SmartReply(text: "Interesting!", emoji: "💡", category: .agreement, confidence: 0.6))
        }
        
        suggestions = Array(replies.prefix(3))
        return suggestions
    }
    
    /// Format messages for AI analysis
    private func formatConversation(_ messages: [IRCChatMessage]) -> String {
        messages
            .filter { $0.type == .message }
            .suffix(5)
            .map { "<\($0.sender)> \(String($0.content.characters))" }
            .joined(separator: "\n")
    }
    
    /// Clear current suggestions
    func clearSuggestions() {
        suggestions.removeAll()
    }
}

/// Errors that can occur during smart reply generation
enum SmartReplyError: LocalizedError {
    case featuresDisabled
    case modelUnavailable
    case noRecentMessages
    case alreadyProcessing
    case generationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .featuresDisabled:
            return "AI features are disabled. Enable them in Settings > Advanced > AI Features."
        case .modelUnavailable:
            return "AI model unavailable. Requires macOS 26+ with Apple Intelligence enabled."
        case .noRecentMessages:
            return "No recent messages to generate replies from."
        case .alreadyProcessing:
            return "Smart reply generation already in progress."
        case .generationFailed(let message):
            return "Failed to generate smart replies: \(message)"
        }
    }
}

// MARK: - Fallback Types (when FoundationModels unavailable)

#if !canImport(FoundationModels)
/// Placeholder macro when FoundationModels unavailable
@attached(member)
macro Generable(description: String) = #externalMacro(module: "FoundationModelsMacros", type: "GenerableMacro")
#endif
