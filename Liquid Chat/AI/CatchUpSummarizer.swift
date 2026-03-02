//
//  CatchUpSummarizer.swift
//  Liquid Chat
//
//  AI-powered chat summarization using FoundationModels
//
//  NOTE: This uses the FoundationModels framework which requires:
//  - macOS 26+ with Apple Intelligence enabled
//  - The framework may be in beta - APIs subject to change
//

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Summary output structure for structured generation
#if canImport(FoundationModels)
@Generable(description: "Summary of an IRC chat conversation")
struct ChatSummary {
    /// Key points discussed in the conversation
    let keyPoints: [String]
    
    /// Number of active participants
    let participantCount: Int
    
    /// Main topics discussed
    let topics: [String]
    
    /// Overall sentiment (positive, neutral, negative)
    let sentiment: String
    
    /// Total number of messages summarized
    let messageCount: Int
}
#else
struct ChatSummary: Codable {
    let keyPoints: [String]
    let participantCount: Int
    let topics: [String]
    let sentiment: String
    let messageCount: Int
}
#endif

/// Handles AI-powered summarization of IRC chat messages
@Observable
class CatchUpSummarizer {
    #if canImport(FoundationModels)
    private var session: LanguageModelSession?
    #endif
    private(set) var isAvailable: Bool = false
    private(set) var isProcessing: Bool = false
    
    init() {
        #if canImport(FoundationModels)
        // Create a session with the default on-device model
        let model = SystemLanguageModel.default
        if model.isAvailable {
            self.session = LanguageModelSession(model: model)
            self.isAvailable = true
        } else {
            self.session = nil
            self.isAvailable = false
        }
        #else
        self.isAvailable = false
        #endif
        
        Task {
            await ConsoleLogger.shared.log(
                isAvailable ? "AI Summarization available" : "AI Summarization unavailable (Apple Intelligence not enabled)",
                level: .info,
                category: "AI"
            )
        }
    }
    
    /// Generate a summary of recent chat messages
    /// - Parameter messages: Array of IRC chat messages to summarize
    /// - Returns: A structured summary with key points and topics
    func summarize(messages: [IRCChatMessage]) async throws -> ChatSummary {
        // Check if AI features are enabled in settings
        guard AppSettings.shared.enableAIFeatures else {
            throw SummarizerError.featuresDisabled
        }
        
        #if canImport(FoundationModels)
        guard let session = session else {
            throw SummarizerError.modelUnavailable
        }
        
        guard !messages.isEmpty else {
            throw SummarizerError.noMessages
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        // Format messages for the model
        let conversationText = formatMessagesForSummarization(messages)
        
        // Create the prompt for summarization
        let prompt = """
        Summarize this IRC chat conversation. Extract the key discussion points, identify main topics, count unique participants, and determine the overall sentiment.
        
        Conversation:
        \(conversationText)
        
        Provide a concise summary with:
        - Key points (3-5 bullet points)
        - Main topics discussed
        - Participant count
        - Overall sentiment (positive, neutral, or negative)
        """
        
        Task { await ConsoleLogger.shared.log("Generating summary for \(messages.count) messages", level: .info, category: "AI") }
        
        // Use structured generation to get a typed response
        // Use temperature from settings
        var options = GenerationOptions()
        options.temperature = AppSettings.shared.aiTemperature
        
        let response = try await session.respond(
            to: prompt,
            generating: ChatSummary.self,
            includeSchemaInPrompt: true,
            options: options
        )
        
        let summary = response.content
        Task { await ConsoleLogger.shared.log("Summary generated: \(summary.keyPoints.count) key points", level: .info, category: "AI") }
        
        return summary
        #else
        throw SummarizerError.modelUnavailable
        #endif
    }
    
    /// Format messages into a readable conversation format
    private func formatMessagesForSummarization(_ messages: [IRCChatMessage]) -> String {
        var formatted = ""
        var participants = Set<String>()
        
        for message in messages {
            // Skip system messages for summarization
            guard message.type == .message || message.type == .action else { continue }
            
            participants.insert(message.sender)
            
            let timestamp = DateFormatter.localizedString(from: message.timestamp, dateStyle: .none, timeStyle: .short)
            let content = String(message.content.characters)
            
            if message.type == .action {
                formatted += "[\(timestamp)] * \(message.sender) \(content)\n"
            } else {
                formatted += "[\(timestamp)] <\(message.sender)> \(content)\n"
            }
        }
        
        return formatted
    }
    
    /// Generate a quick one-line summary
    func quickSummary(messages: [IRCChatMessage]) async throws -> String {
        // Check if AI features are enabled in settings
        guard AppSettings.shared.enableAIFeatures else {
            throw SummarizerError.featuresDisabled
        }
        
        #if canImport(FoundationModels)
        guard let session = session else {
            throw SummarizerError.modelUnavailable
        }
        
        let conversationText = formatMessagesForSummarization(messages)
        
        let prompt = """
        Summarize this IRC conversation in one concise sentence:
        
        \(conversationText)
        """
        
        let response = try await session.respond(to: prompt)
        return response.content
        #else
        throw SummarizerError.modelUnavailable
        #endif
    }
    
    enum SummarizerError: LocalizedError {
        case modelUnavailable
        case noMessages
        case featuresDisabled
        
        var errorDescription: String? {
            switch self {
            case .modelUnavailable:
                return "AI summarization requires Apple Intelligence to be enabled on this device"
            case .noMessages:
                return "No messages to summarize"
            case .featuresDisabled:
                return "AI features are disabled in Settings"
            }
        }
    }
}

#if !canImport(FoundationModels)
/// Placeholder for when FoundationModels is unavailable
struct GenerationOptions {
    var temperature: Double = 0.3
}
#endif
