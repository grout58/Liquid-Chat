//
//  LoopbackIRCTests.swift
//  Liquid ChatTests
//
//  End-to-end tests running the real IRCConnection against a scripted
//  IRC server on 127.0.0.1 — the only tests that exercise actual sockets.
//

import Testing
import Foundation
import Network
@testable import Liquid_Chat

/// A minimal scripted IRC server bound to loopback on an ephemeral port.
/// Records every CRLF line the client sends; tests reply by hand.
/// Built on BSD sockets — NWListener fails with EPERM/EINVAL in some
/// test-host environments, plain sockets do not.
final class LoopbackIRCServer: @unchecked Sendable {
    private var listenFD: Int32 = -1
    private var clientFD: Int32 = -1
    private let lock = NSLock()
    private var lineBuffer = Data()
    private var receivedLines: [String] = []
    private let acceptQueue = DispatchQueue(label: "com.liquidchat.tests.loopback")

    /// Bind, listen, and start accepting; returns the assigned port.
    func start() throws -> UInt16 {
        listenFD = socket(AF_INET, SOCK_STREAM, 0)
        guard listenFD >= 0 else { throw Self.posixError() }

        var reuse: Int32 = 1
        setsockopt(listenFD, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = 0                                   // ephemeral
        address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))

        let bindResult = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(listenFD, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else { throw Self.posixError() }
        guard listen(listenFD, 1) == 0 else { throw Self.posixError() }

        // Read back the assigned port
        var assigned = sockaddr_in()
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        _ = withUnsafeMutablePointer(to: &assigned) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getsockname(listenFD, $0, &length)
            }
        }
        let port = UInt16(bigEndian: assigned.sin_port)

        acceptQueue.async { [self] in
            let fd = accept(listenFD, nil, nil)
            guard fd >= 0 else { return }
            lock.lock()
            clientFD = fd
            lock.unlock()
            readLoop(fd)
        }
        return port
    }

    private func readLoop(_ fd: Int32) {
        var chunk = [UInt8](repeating: 0, count: 4096)
        while true {
            let count = read(fd, &chunk, chunk.count)
            guard count > 0 else { break }
            lock.lock()
            lineBuffer.append(contentsOf: chunk[0..<count])
            while let range = lineBuffer.range(of: Data("\r\n".utf8)) {
                let lineData = lineBuffer.subdata(in: 0..<range.lowerBound)
                lineBuffer.removeSubrange(0..<range.upperBound)
                if let line = String(data: lineData, encoding: .utf8) {
                    receivedLines.append(line)
                }
            }
            lock.unlock()
        }
    }

    private var currentClientFD: Int32 {
        lock.lock()
        defer { lock.unlock() }
        return clientFD
    }

    /// Send one server line (CRLF appended). Only call after the client has
    /// connected (i.e. after an expectLine succeeded).
    func send(_ line: String) {
        let fd = currentClientFD
        guard fd >= 0 else { return }
        let data = Array((line + "\r\n").utf8)
        _ = data.withUnsafeBytes { write(fd, $0.baseAddress, $0.count) }
    }

    /// Half-close from the server side (FIN) — the clean EOF path.
    func sendEOF() {
        let fd = currentClientFD
        guard fd >= 0 else { return }
        shutdown(fd, SHUT_WR)
    }

    func stop() {
        lock.lock()
        let client = clientFD
        clientFD = -1
        lock.unlock()
        if client >= 0 { close(client) }
        if listenFD >= 0 { close(listenFD); listenFD = -1 }
    }

    /// Wait until the client has sent a line containing `needle`.
    func expectLine(containing needle: String, timeout: TimeInterval = 5.0) async -> String? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            lock.lock()
            let match = receivedLines.first { $0.contains(needle) }
            lock.unlock()
            if let match { return match }
            try? await Task.sleep(for: .milliseconds(25))
        }
        return nil
    }

    /// All lines received so far that contain `needle`.
    func lines(containing needle: String) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return receivedLines.filter { $0.contains(needle) }
    }

    private static func posixError() -> NSError {
        NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }
}

/// Poll an assertion until it holds or the timeout passes.
@MainActor
private func eventually(timeout: TimeInterval = 5.0, _ condition: @MainActor () -> Bool) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() { return true }
        try? await Task.sleep(for: .milliseconds(25))
    }
    return condition()
}

@Suite("Loopback Socket Integration Tests", .serialized)
struct LoopbackIRCTests {

    private func makeClient(port: UInt16, nickname: String) -> (IRCConnection, MockConnectionDelegate) {
        let config = IRCServerConfig(
            hostname: "127.0.0.1",
            port: port,
            useSSL: false,
            nickname: nickname
        )
        let connection = IRCConnection(config: config)
        let delegate = MockConnectionDelegate()
        connection.delegate = delegate
        return (connection, delegate)
    }

    @MainActor
    @Test("Registration handshake over a real socket")
    func realSocketHandshake() async throws {
        let server = try LoopbackIRCServer()
        let port = try server.start()
        let (client, _) = makeClient(port: port, nickname: "LoopUser")
        defer { client.disconnect(); server.stop() }

        client.connect()

        // Handshake, in order: capability listing, then identity
        #expect(await server.expectLine(containing: "CAP LS 302") != nil)
        #expect(await server.expectLine(containing: "NICK LoopUser") != nil)
        #expect(await server.expectLine(containing: "USER LoopUser") != nil)

        // No capabilities on offer → the client must end negotiation
        server.send(":loop.test CAP * LS :")
        #expect(await server.expectLine(containing: "CAP END") != nil)

        // Welcome completes registration
        server.send(":loop.test 001 LoopUser :Welcome to the loopback network")
        #expect(await eventually { client.state == .registered })
        #expect(client.currentNickname == "LoopUser")
    }

    @MainActor
    @Test("Server PING is answered with PONG carrying the token")
    func pingPongOverSocket() async throws {
        let server = try LoopbackIRCServer()
        let port = try server.start()
        let (client, _) = makeClient(port: port, nickname: "PingUser")
        defer { client.disconnect(); server.stop() }

        client.connect()
        _ = await server.expectLine(containing: "USER")
        server.send("PING :token-xyz")

        let pong = await server.expectLine(containing: "PONG")
        #expect(pong?.contains("token-xyz") == true)
    }

    @MainActor
    @Test("Multiline messages are split into one PRIVMSG per line on the wire")
    func multilineSplitOverSocket() async throws {
        let server = try LoopbackIRCServer()
        let port = try server.start()
        let (client, _) = makeClient(port: port, nickname: "SplitUser")
        defer { client.disconnect(); server.stop() }

        client.connect()
        _ = await server.expectLine(containing: "USER")

        client.sendMessage("first line\nsecond line", to: "#test")

        #expect(await server.expectLine(containing: ":first line") != nil)
        #expect(await server.expectLine(containing: ":second line") != nil)
        let privmsgs = server.lines(containing: "PRIVMSG #test")
        #expect(privmsgs.count == 2)
    }

    @MainActor
    @Test("Server EOF is reported as a disconnect")
    func eofDisconnectOverSocket() async throws {
        let server = try LoopbackIRCServer()
        let port = try server.start()
        let (client, delegate) = makeClient(port: port, nickname: "EOFUser")
        defer { server.stop() }

        client.connect()
        _ = await server.expectLine(containing: "USER")

        server.sendEOF()

        #expect(await eventually { delegate.didDisconnect })
        #expect(await eventually { client.state == .disconnected })
    }

    @MainActor
    @Test("QUIT goes out on the wire before disconnect tears down the socket")
    func quitFlushOverSocket() async throws {
        let server = try LoopbackIRCServer()
        let port = try server.start()
        let (client, _) = makeClient(port: port, nickname: "QuitUser")
        defer { server.stop() }

        client.connect()
        _ = await server.expectLine(containing: "USER")

        client.disconnect(message: "Goodbye loopback")

        let quit = await server.expectLine(containing: "QUIT")
        #expect(quit?.contains("Goodbye loopback") == true)
    }
}
