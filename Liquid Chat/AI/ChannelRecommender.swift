//
//  ChannelRecommender.swift
//  Liquid Chat
//
//  AI-powered channel recommendations using Apple Intelligence
//

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Represents a recommended IRC channel with relevance score
struct ChannelRecommendation: Identifiable, Codable {
    var id = UUID()
    let channelName: String
    let reason: String
    let relevanceScore: Double // 0.0 - 1.0
    let similarTopics: [String]
}

/// AI-powered channel recommendation engine using Apple Intelligence
/// Analyzes conversation history to suggest relevant channels
@Observable
class ChannelRecommender {
    /// Whether the recommender is currently processing
    var isProcessing = false
    
    /// Last error encountered during recommendation
    var lastError: RecommenderError?
    
    init() {
        #if canImport(FoundationModels)
        Task { await ConsoleLogger.shared.log("ChannelRecommender initialized with FoundationModels support", level: .info, category: "AI") }
        #else
        Task { await ConsoleLogger.shared.log("ChannelRecommender initialized without FoundationModels (requires macOS 26+)", level: .warning, category: "AI") }
        #endif
    }
    
    /// Generate channel recommendations based on conversation history
    /// - Parameters:
    ///   - messages: Recent messages from current channel
    ///   - availableChannels: List of channels available on the server
    ///   - currentChannel: The channel user is currently in
    /// - Returns: Array of recommended channels sorted by relevance
    @MainActor
    func recommend(
        basedOn messages: [IRCChatMessage],
        from availableChannels: [IRCChannelListEntry],
        excluding currentChannel: String
    ) async throws -> [ChannelRecommendation] {
        guard !isProcessing else {
            throw RecommenderError.alreadyProcessing
        }
        
        // Check if AI features are enabled
        guard AppSettings.shared.enableAIFeatures else {
            throw RecommenderError.featuresDisabled
        }
        
        // Validate input
        guard !messages.isEmpty else {
            throw RecommenderError.noMessages
        }
        
        guard !availableChannels.isEmpty else {
            throw RecommenderError.noChannelsAvailable
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        #if canImport(FoundationModels)
        return try await generateRecommendationsWithAI(
            messages: messages,
            availableChannels: availableChannels,
            currentChannel: currentChannel
        )
        #else
        // Fallback for systems without FoundationModels
        return generateBasicRecommendations(
            messages: messages,
            availableChannels: availableChannels,
            currentChannel: currentChannel
        )
        #endif
    }
    
    #if canImport(FoundationModels)
    /// Generate recommendations using Apple Intelligence
    @MainActor
    private func generateRecommendationsWithAI(
        messages: [IRCChatMessage],
        availableChannels: [IRCChannelListEntry],
        currentChannel: String
    ) async throws -> [ChannelRecommendation] {
        // Check if FoundationModels model is available
        let model = SystemLanguageModel.default
        guard model.isAvailable else {
            throw RecommenderError.modelUnavailable
        }
        
        let session = LanguageModelSession(model: model)
        
        // Format recent messages for analysis (reduced to last 20 messages to fit context)
        let recentMessages = messages.suffix(20)
        let conversationSummary = formatMessagesForAnalysis(Array(recentMessages))
        
        // Format available channels (reduced to top 30 by user count to fit context)
        let topChannels = availableChannels
            .sorted { $0.userCount > $1.userCount }
            .prefix(30)
        
        // Compact channel list format to save tokens
        let channelList = topChannels.map { channel in
            let topic = channel.topic.isEmpty ? "no topic" : (channel.topic.count > 50 ? String(channel.topic.prefix(50)) + "..." : channel.topic)
            return "\(channel.name) (\(channel.userCount)): \(topic)"
        }.joined(separator: "\n")
        
        // Create AI prompt for channel recommendations (simplified to reduce tokens)
        let prompt = """
        Recommend 3 IRC channels from this list based on the conversation.
        
        Current: \(currentChannel)
        
        Recent chat:
        \(conversationSummary)
        
        Channels:
        \(channelList)
        
        For each:
        - Channel name (from list above)
        - Brief reason (5-10 words)
        - Score (0.0-1.0)
        - Topics (2-3 words)
        
        Match technical topics and interests. Skip current channel.
        """
        
        // Configure generation options
        var options = GenerationOptions()
        options.temperature = AppSettings.shared.aiTemperature
        
        // Generate recommendations using structured output
        let response: [AIChannelRecommendation]
        do {
            let result = try await session.respond(
                to: prompt,
                generating: [AIChannelRecommendation].self,
                includeSchemaInPrompt: true,
                options: options
            )
            response = result.content
        } catch {
            Task { await ConsoleLogger.shared.log("AI recommendation generation failed: \(error)", level: .error, category: "AI") }
            throw RecommenderError.generationFailed(error.localizedDescription)
        }
        
        let recommendations = response
        
        // Convert AI recommendations to app model
        let result = recommendations
            .filter { $0.channelName != currentChannel }
            .filter { rec in
                // Verify channel exists in available list
                topChannels.contains(where: { $0.name == rec.channelName })
            }
            .map { aiRec in
                ChannelRecommendation(
                    channelName: aiRec.channelName,
                    reason: aiRec.reason,
                    relevanceScore: aiRec.relevanceScore,
                    similarTopics: aiRec.similarTopics
                )
            }
            .sorted { $0.relevanceScore > $1.relevanceScore }
        
        Task { await ConsoleLogger.shared.log("Generated \(result.count) AI-powered channel recommendations", level: .info, category: "AI") }
        return result
    }
    
    /// AI-structured recommendation format for FoundationModels
    @Generable(description: "IRC channel recommendation with relevance scoring")
    struct AIChannelRecommendation {
        let channelName: String
        let reason: String
        let relevanceScore: Double
        let similarTopics: [String]
    }
    #endif
    
    /// Fallback recommendation engine using keyword matching (no AI)
    private func generateBasicRecommendations(
        messages: [IRCChatMessage],
        availableChannels: [IRCChannelListEntry],
        currentChannel: String
    ) -> [ChannelRecommendation] {
        Task { await ConsoleLogger.shared.log("Using basic keyword matching (FoundationModels unavailable)", level: .info, category: "AI") }
        
        // Extract keywords from recent messages
        let recentMessages = messages.suffix(50)
        let text = recentMessages
            .filter { $0.type == .message }
            .map { String($0.content.characters) }
            .joined(separator: " ")
            .lowercased()
        
        // Common technical keywords to look for
        let keywords = extractKeywords(from: text)
        
        // Score channels based on keyword overlap
        let scored = availableChannels
            .filter { $0.name != currentChannel }
            .filter { $0.userCount > 5 } // Only channels with active users
            .compactMap { channel -> (channel: IRCChannelListEntry, score: Double)? in
                let channelText = "\(channel.name) \(channel.topic)".lowercased()
                let matches = keywords.filter { channelText.contains($0) }
                
                guard !matches.isEmpty else { return nil }
                
                let score = Double(matches.count) / Double(keywords.count)
                return (channel, score)
            }
            .sorted { $0.score > $1.score }
            .prefix(5)
        
        // Convert to recommendations
        return scored.map { item in
            ChannelRecommendation(
                channelName: item.channel.name,
                reason: "Related topics: \(item.channel.topic.isEmpty ? "general discussion" : item.channel.topic)",
                relevanceScore: item.score,
                similarTopics: keywords.prefix(3).map { String($0) }
            )
        }
    }
    
    /// Extract keywords from conversation text
    private func extractKeywords(from text: String) -> Set<String> {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        let filtered = words.filter { word in
            word.count > 3 && // Skip short words
            !stopWords.contains(word) // Skip common words
        }
        return Set(filtered.prefix(20))
    }
    
    /// Common stop words to exclude from keyword extraction
    private let stopWords: Set<String> = [
        "that", "this", "with", "from", "have", "been", "were", "said",
        "what", "when", "where", "which", "while", "would", "could", "should",
        "about", "after", "before", "other", "into", "through", "there"
    ]
    
    /// Format messages for AI analysis (compact format to save tokens)
    private func formatMessagesForAnalysis(_ messages: [IRCChatMessage]) -> String {
        let formatted = messages
            .filter { $0.type == .message || $0.type == .action }
            .suffix(15) // Reduced to last 15 messages to fit context
            .map { message -> String in
                let content = String(message.content.characters)
                // Truncate long messages to save tokens
                let truncated = content.count > 100 ? String(content.prefix(100)) + "..." : content
                return "<\(message.sender)> \(truncated)"
            }
            .joined(separator: "\n")
        
        return formatted.isEmpty ? "No recent messages" : formatted
    }
}

/// Errors that can occur during channel recommendation
enum RecommenderError: LocalizedError {
    case featuresDisabled
    case modelUnavailable
    case noMessages
    case noChannelsAvailable
    case alreadyProcessing
    case generationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .featuresDisabled:
            return "AI features are disabled. Enable them in Settings > Advanced > AI Features."
        case .modelUnavailable:
            return "AI model unavailable. Requires macOS 26+ with Apple Intelligence enabled."
        case .noMessages:
            return "No messages to analyze. Start a conversation first."
        case .noChannelsAvailable:
            return "No channels available for recommendations."
        case .alreadyProcessing:
            return "Recommendation already in progress."
        case .generationFailed(let message):
            return "Failed to generate recommendations: \(message)"
        }
    }
}

// MARK: - Fallback Types (when FoundationModels unavailable)

#if !canImport(FoundationModels)
/// Placeholder types when FoundationModels is unavailable
struct SystemLanguageModel {
    static let `default` = SystemLanguageModel()
    var isAvailable: Bool { false }
}

struct LanguageModelSession {
    init(model: SystemLanguageModel) {}
    
    func generate<T>(_ prompt: String, options: GenerationOptions) async throws -> T {
        throw RecommenderError.modelUnavailable
    }
}

/// Placeholder for FoundationModels.GenerationOptions
struct GenerationOptions {
    var temperature: Double = 0.3
}

/// Placeholder macro when FoundationModels unavailable
@attached(member)
macro Generable(description: String) = #externalMacro(module: "FoundationModelsMacros", type: "GenerableMacro")
#endif
