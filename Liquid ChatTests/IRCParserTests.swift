//
//  IRCParserTests.swift
//  Liquid ChatTests
//
//  Comprehensive tests for IRC protocol message parsing
//

import Testing
import Foundation
@testable import Liquid_Chat

/// Tests for IRC message parsing (RFC 1459 + IRCv3)
@Suite("IRC Protocol Parser Tests")
struct IRCParserTests {
    
    // MARK: - Basic Message Parsing
    
    @Test("Parse simple command without parameters")
    func parseSimpleCommand() throws {
        let message = IRCMessage.parse("PING")
        
        #expect(message != nil)
        #expect(message?.command == "PING")
        #expect(message?.parameters.isEmpty == true)
        #expect(message?.prefix == nil)
        #expect(message?.tags.isEmpty == true)
    }
    
    @Test("Parse command with single parameter")
    func parseCommandWithSingleParameter() throws {
        let message = IRCMessage.parse("NICK testuser")
        
        #expect(message != nil)
        #expect(message?.command == "NICK")
        #expect(message?.parameters == ["testuser"])
        #expect(message?.prefix == nil)
    }
    
    @Test("Parse command with multiple parameters")
    func parseCommandWithMultipleParameters() throws {
        let message = IRCMessage.parse("USER guest 0 * :Real Name")
        
        #expect(message != nil)
        #expect(message?.command == "USER")
        #expect(message?.parameters == ["guest", "0", "*", "Real Name"])
    }
    
    @Test("Parse command with trailing parameter")
    func parseCommandWithTrailingParameter() throws {
        let message = IRCMessage.parse("PRIVMSG #channel :Hello, World!")
        
        #expect(message != nil)
        #expect(message?.command == "PRIVMSG")
        #expect(message?.parameters == ["#channel", "Hello, World!"])
    }
    
    @Test("Parse command with empty trailing parameter")
    func parseCommandWithEmptyTrailingParameter() throws {
        let message = IRCMessage.parse("PRIVMSG #channel :")
        
        #expect(message != nil)
        #expect(message?.command == "PRIVMSG")
        #expect(message?.parameters == ["#channel", ""])
    }
    
    // MARK: - Prefix Parsing
    
    @Test("Parse message with server prefix")
    func parseMessageWithServerPrefix() throws {
        let message = IRCMessage.parse(":irc.example.com NOTICE * :Welcome")
        
        #expect(message != nil)
        #expect(message?.prefix == "irc.example.com")
        #expect(message?.command == "NOTICE")
        #expect(message?.parameters == ["*", "Welcome"])
    }
    
    @Test("Parse message with full user prefix")
    func parseMessageWithFullUserPrefix() throws {
        let message = IRCMessage.parse(":nick!user@host.com PRIVMSG #channel :Hello")
        
        #expect(message != nil)
        #expect(message?.prefix == "nick!user@host.com")
        #expect(message?.nick == "nick")
        #expect(message?.user == "user")
        #expect(message?.host == "host.com")
        #expect(message?.command == "PRIVMSG")
    }
    
    @Test("Parse message with nickname only prefix")
    func parseMessageWithNicknameOnlyPrefix() throws {
        let message = IRCMessage.parse(":nick JOIN #channel")
        
        #expect(message != nil)
        #expect(message?.prefix == "nick")
        #expect(message?.nick == "nick")
        #expect(message?.user == nil)
        #expect(message?.host == nil)
    }
    
    @Test("Parse message with nickname and host prefix")
    func parseMessageWithNicknameAndHostPrefix() throws {
        let message = IRCMessage.parse(":nick@host.com QUIT :Leaving")
        
        #expect(message != nil)
        #expect(message?.prefix == "nick@host.com")
        #expect(message?.nick == "nick")
        #expect(message?.host == "host.com")
        #expect(message?.user == nil)
    }
    
    // MARK: - IRCv3 Message Tags
    
    @Test("Parse message with single tag")
    func parseMessageWithSingleTag() throws {
        let message = IRCMessage.parse("@id=123 PRIVMSG #channel :Hello")
        
        #expect(message != nil)
        #expect(message?.tags["id"] == "123")
        #expect(message?.command == "PRIVMSG")
        #expect(message?.parameters == ["#channel", "Hello"])
    }
    
    @Test("Parse message with multiple tags")
    func parseMessageWithMultipleTags() throws {
        let message = IRCMessage.parse("@id=123;batch=ref123;time=2024-01-01T12:00:00.000Z :nick!user@host PRIVMSG #channel :Hello")
        
        #expect(message != nil)
        #expect(message?.tags["id"] == "123")
        #expect(message?.tags["batch"] == "ref123")
        #expect(message?.tags["time"] == "2024-01-01T12:00:00.000Z")
        #expect(message?.command == "PRIVMSG")
    }
    
    @Test("Parse message with tag without value")
    func parseMessageWithTagWithoutValue() throws {
        let message = IRCMessage.parse("@draft/reply PRIVMSG #channel :Hello")
        
        #expect(message != nil)
        #expect(message?.tags["draft/reply"] == "")
        #expect(message?.command == "PRIVMSG")
    }
    
    @Test("Parse server-time tag and extract date")
    func parseServerTimeTag() throws {
        let message = IRCMessage.parse("@time=2024-01-15T10:30:45.123Z :nick!user@host PRIVMSG #channel :Hello")
        
        #expect(message != nil)
        #expect(message?.tags["time"] != nil)
        
        let serverTime = message?.serverTime
        #expect(serverTime != nil)
        
        // Verify it's a valid date (within reasonable range)
        let now = Date()
        let yearAgo = now.addingTimeInterval(-365 * 24 * 3600)
        #expect(serverTime! > yearAgo)
        #expect(serverTime! < now.addingTimeInterval(3600))
    }
    
    @Test("Parse batch tag")
    func parseBatchTag() throws {
        let message = IRCMessage.parse("@batch=123abc :server 005 nick NETWORK=Freenode")
        
        #expect(message != nil)
        #expect(message?.batchID == "123abc")
    }
    
    // MARK: - Numeric Replies
    
    @Test("Parse numeric reply")
    func parseNumericReply() throws {
        let message = IRCMessage.parse(":irc.example.com 001 nick :Welcome to the IRC Network")
        
        #expect(message != nil)
        #expect(message?.command == "001")
        #expect(message?.parameters == ["nick", "Welcome to the IRC Network"])
    }
    
    @Test("Parse multi-parameter numeric reply")
    func parseMultiParameterNumericReply() throws {
        let message = IRCMessage.parse(":irc.example.com 353 nick = #channel :user1 user2 @op1 +voice1")
        
        #expect(message != nil)
        #expect(message?.command == "353")
        #expect(message?.parameters == ["nick", "=", "#channel", "user1 user2 @op1 +voice1"])
    }
    
    // MARK: - Edge Cases
    
    @Test("Parse empty string returns nil")
    func parseEmptyString() throws {
        let message = IRCMessage.parse("")
        #expect(message == nil)
    }
    
    @Test("Parse whitespace only returns nil")
    func parseWhitespaceOnly() throws {
        let message = IRCMessage.parse("   ")
        #expect(message == nil)
    }
    
    @Test("Parse malformed tag section returns nil")
    func parseMalformedTagSection() throws {
        // Tag section without space separator
        let message = IRCMessage.parse("@tag=valuePRIVMSG #channel :Hello")
        #expect(message == nil)
    }
    
    @Test("Parse malformed prefix returns nil")
    func parseMalformedPrefix() throws {
        // Prefix without space separator
        let message = IRCMessage.parse(":prefixPRIVMSG #channel :Hello")
        #expect(message == nil)
    }
    
    @Test("Parse message with excessive whitespace")
    func parseMessageWithExcessiveWhitespace() throws {
        let message = IRCMessage.parse("   PRIVMSG    #channel    :Hello   World   ")
        
        #expect(message != nil)
        #expect(message?.command == "PRIVMSG")
        #expect(message?.parameters == ["#channel", "Hello   World   "])
    }
    
    @Test("Parse 512-byte maximum length message")
    func parseMaximumLengthMessage() throws {
        // IRC spec: messages should not exceed 512 bytes including CRLF
        let longMessage = String(repeating: "A", count: 400)
        let raw = "PRIVMSG #channel :\(longMessage)"
        
        #expect(raw.count < 512)
        
        let message = IRCMessage.parse(raw)
        #expect(message != nil)
        #expect(message?.command == "PRIVMSG")
        #expect(message?.parameters.last?.count == 400)
    }
    
    @Test("Parse message with special characters")
    func parseMessageWithSpecialCharacters() throws {
        let message = IRCMessage.parse("PRIVMSG #channel :Hello 👋 World 🌍")
        
        #expect(message != nil)
        #expect(message?.command == "PRIVMSG")
        #expect(message?.parameters == ["#channel", "Hello 👋 World 🌍"])
    }
    
    @Test("Parse message with colon in middle parameter works")
    func parseMessageWithColonInMiddleParameter() throws {
        // Colon should only be special at the start of a parameter
        let message = IRCMessage.parse("MODE #channel +o user:name")
        
        #expect(message != nil)
        #expect(message?.command == "MODE")
        #expect(message?.parameters == ["#channel", "+o", "user:name"])
    }
    
    // MARK: - Real-World Examples
    
    @Test("Parse real PRIVMSG")
    func parseRealPrivmsg() throws {
        let message = IRCMessage.parse(":alice!alice@example.com PRIVMSG #test :Hello everyone!")
        
        #expect(message != nil)
        #expect(message?.nick == "alice")
        #expect(message?.user == "alice")
        #expect(message?.host == "example.com")
        #expect(message?.command == "PRIVMSG")
        #expect(message?.parameters == ["#test", "Hello everyone!"])
    }
    
    @Test("Parse real JOIN")
    func parseRealJoin() throws {
        let message = IRCMessage.parse(":bob!~bob@192.168.1.1 JOIN #channel")
        
        #expect(message != nil)
        #expect(message?.nick == "bob")
        #expect(message?.user == "~bob")
        #expect(message?.host == "192.168.1.1")
        #expect(message?.command == "JOIN")
        #expect(message?.parameters == ["#channel"])
    }
    
    @Test("Parse real PART with reason")
    func parseRealPartWithReason() throws {
        let message = IRCMessage.parse(":charlie!charlie@host.com PART #channel :Goodbye!")
        
        #expect(message != nil)
        #expect(message?.nick == "charlie")
        #expect(message?.command == "PART")
        #expect(message?.parameters == ["#channel", "Goodbye!"])
    }
    
    @Test("Parse real QUIT")
    func parseRealQuit() throws {
        let message = IRCMessage.parse(":dave!~dave@host.com QUIT :Client Quit")
        
        #expect(message != nil)
        #expect(message?.nick == "dave")
        #expect(message?.command == "QUIT")
        #expect(message?.parameters == ["Client Quit"])
    }
    
    @Test("Parse real MODE change")
    func parseRealMode() throws {
        let message = IRCMessage.parse(":ChanServ!services@services.host MODE #channel +o alice")
        
        #expect(message != nil)
        #expect(message?.nick == "ChanServ")
        #expect(message?.command == "MODE")
        #expect(message?.parameters == ["#channel", "+o", "alice"])
    }
    
    @Test("Parse real KICK")
    func parseRealKick() throws {
        let message = IRCMessage.parse(":operator!op@host.com KICK #channel spammer :Spamming")
        
        #expect(message != nil)
        #expect(message?.nick == "operator")
        #expect(message?.command == "KICK")
        #expect(message?.parameters == ["#channel", "spammer", "Spamming"])
    }
    
    @Test("Parse real TOPIC")
    func parseRealTopic() throws {
        let message = IRCMessage.parse(":irc.example.com 332 nick #channel :Welcome to our channel!")
        
        #expect(message != nil)
        #expect(message?.command == "332")
        #expect(message?.parameters == ["nick", "#channel", "Welcome to our channel!"])
    }
    
    @Test("Parse real NAMES reply")
    func parseRealNamesReply() throws {
        let message = IRCMessage.parse(":irc.example.com 353 nick = #channel :@alice +bob charlie")
        
        #expect(message != nil)
        #expect(message?.command == "353")
        #expect(message?.parameters == ["nick", "=", "#channel", "@alice +bob charlie"])
    }
    
    @Test("Parse real IRCv3 message with tags and prefix")
    func parseRealIRCv3Message() throws {
        let message = IRCMessage.parse("@time=2024-01-15T10:30:00.000Z;msgid=abc123 :nick!user@host.com PRIVMSG #channel :Test message")
        
        #expect(message != nil)
        #expect(message?.tags["time"] == "2024-01-15T10:30:00.000Z")
        #expect(message?.tags["msgid"] == "abc123")
        #expect(message?.nick == "nick")
        #expect(message?.user == "user")
        #expect(message?.host == "host.com")
        #expect(message?.command == "PRIVMSG")
        #expect(message?.parameters == ["#channel", "Test message"])
    }
    
    // MARK: - Message Formatting
    
    @Test("Format simple command")
    func formatSimpleCommand() throws {
        let formatted = IRCMessage.format(command: "PING")
        #expect(formatted == "PING")
    }
    
    @Test("Format command with parameters")
    func formatCommandWithParameters() throws {
        let formatted = IRCMessage.format(command: "PRIVMSG", parameters: ["#channel", "Hello"])
        #expect(formatted == "PRIVMSG #channel :Hello")
    }
    
    @Test("Format command with prefix")
    func formatCommandWithPrefix() throws {
        let formatted = IRCMessage.format(command: "NOTICE", parameters: ["user", "Message"], prefix: "server.com")
        #expect(formatted == ":server.com NOTICE user :Message")
    }
    
    @Test("Format command with multiple middle parameters")
    func formatCommandWithMultipleParameters() throws {
        let formatted = IRCMessage.format(command: "MODE", parameters: ["#channel", "+o", "alice"])
        #expect(formatted == "MODE #channel +o alice")
    }
    
    @Test("Format command with trailing parameter containing space")
    func formatCommandWithTrailingSpace() throws {
        let formatted = IRCMessage.format(command: "PRIVMSG", parameters: ["#channel", "Hello World"])
        #expect(formatted == "PRIVMSG #channel :Hello World")
    }
    
    @Test("Format command with trailing parameter starting with colon")
    func formatCommandWithTrailingColon() throws {
        let formatted = IRCMessage.format(command: "PRIVMSG", parameters: ["#channel", ":important"])
        #expect(formatted == "PRIVMSG #channel ::important")
    }
    
    // MARK: - Round-trip Parsing and Formatting
    
    @Test("Round-trip simple message")
    func roundTripSimpleMessage() throws {
        let original = "PRIVMSG #channel :Hello"
        let parsed = IRCMessage.parse(original)
        
        #expect(parsed != nil)
        
        let formatted = IRCMessage.format(
            command: parsed!.command,
            parameters: parsed!.parameters,
            prefix: parsed!.prefix
        )
        
        #expect(formatted == original)
    }
    
    @Test("Round-trip message with prefix")
    func roundTripMessageWithPrefix() throws {
        let original = ":nick!user@host PRIVMSG #channel :Hello"
        let parsed = IRCMessage.parse(original)
        
        #expect(parsed != nil)
        
        let formatted = IRCMessage.format(
            command: parsed!.command,
            parameters: parsed!.parameters,
            prefix: parsed!.prefix
        )
        
        #expect(formatted == original)
    }
    
    // MARK: - Case Sensitivity
    
    @Test("Command is case-insensitive (uppercased)")
    func commandIsCaseInsensitive() throws {
        let message1 = IRCMessage.parse("privmsg #channel :Hello")
        let message2 = IRCMessage.parse("PRIVMSG #channel :Hello")
        let message3 = IRCMessage.parse("PrIvMsG #channel :Hello")
        
        #expect(message1?.command == "PRIVMSG")
        #expect(message2?.command == "PRIVMSG")
        #expect(message3?.command == "PRIVMSG")
    }
    
    @Test("Parameters preserve case")
    func parametersPreserveCase() throws {
        let message = IRCMessage.parse("PRIVMSG #ChAnNeL :HeLLo")
        
        #expect(message != nil)
        #expect(message?.parameters == ["#ChAnNeL", "HeLLo"])
    }
    
    // MARK: - Description Tests
    
    @Test("Message description format")
    func messageDescriptionFormat() throws {
        let message = IRCMessage.parse(":nick!user@host PRIVMSG #channel :Hello")
        
        #expect(message != nil)
        
        let description = message!.description
        #expect(description.contains("nick!user@host"))
        #expect(description.contains("PRIVMSG"))
        #expect(description.contains("#channel"))
        #expect(description.contains("Hello"))
    }
}
