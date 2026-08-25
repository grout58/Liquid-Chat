//
//  DCCManager.swift
//  Liquid Chat
//
//  Accepts and runs incoming DCC file transfers
//

import Foundation
import Network

/// Tracks DCC transfers and runs the receive side. Files are only ever
/// downloaded after an explicit Accept, always into ~/Downloads under a
/// sanitized name.
@MainActor
@Observable
final class DCCManager {
    var transfers: [DCCTransfer] = []

    @ObservationIgnored private var sessions: [UUID: DCCReceiveSession] = [:]

    /// Number of transfers waiting on the user or actively running.
    var attentionCount: Int {
        transfers.count {
            switch $0.state {
            case .offered, .connecting, .transferring: return true
            default: return false
            }
        }
    }

    /// Register an incoming offer (does not connect anywhere).
    func addOffer(_ transfer: DCCTransfer) {
        transfers.insert(transfer, at: 0)
    }

    func decline(_ transfer: DCCTransfer) {
        guard transfer.state == .offered else { return }
        transfer.state = .declined
    }

    func cancel(_ transfer: DCCTransfer) {
        sessions.removeValue(forKey: transfer.id)?.stop()
        if transfer.state == .connecting || transfer.state == .transferring {
            transfer.state = .failed("Cancelled")
        }
    }

    func removeFinished() {
        transfers.removeAll {
            switch $0.state {
            case .completed, .declined, .failed: return true
            default: return false
            }
        }
    }

    /// Accept an offer: create the destination file and start receiving.
    func accept(_ transfer: DCCTransfer) {
        guard transfer.state == .offered, !transfer.offer.isPassive else { return }

        let destination = Self.availableDestination(for: transfer.offer.filename)
        guard FileManager.default.createFile(atPath: destination.path, contents: nil),
              let handle = try? FileHandle(forWritingTo: destination) else {
            transfer.state = .failed("Could not create \(destination.lastPathComponent)")
            return
        }
        transfer.destination = destination
        transfer.state = .connecting

        let session = DCCReceiveSession(
            host: transfer.offer.host,
            port: transfer.offer.port,
            fileHandle: handle,
            expectedSize: transfer.offer.fileSize,
            onEvent: { [weak self, weak transfer] event in
                Task { @MainActor [weak self, weak transfer] in
                    guard let self, let transfer else { return }
                    switch event {
                    case .connected:
                        transfer.state = .transferring
                    case .progress(let bytes):
                        transfer.bytesTransferred = bytes
                    case .finished(let bytes):
                        transfer.bytesTransferred = bytes
                        transfer.state = .completed
                        self.sessions.removeValue(forKey: transfer.id)
                    case .failed(let reason):
                        transfer.state = .failed(reason)
                        self.sessions.removeValue(forKey: transfer.id)
                        // A partial file is not the file — remove it
                        if let destination = transfer.destination {
                            try? FileManager.default.removeItem(at: destination)
                        }
                    }
                }
            }
        )
        sessions[transfer.id] = session
        session.start()
    }

    /// A non-colliding path in ~/Downloads for the given (sanitized) filename.
    static func availableDestination(for filename: String) -> URL {
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        var url = downloads.appendingPathComponent(filename)
        let base = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension
        var counter = 1
        while FileManager.default.fileExists(atPath: url.path) {
            let candidate = ext.isEmpty ? "\(base) (\(counter))" : "\(base) (\(counter)).\(ext)"
            url = downloads.appendingPathComponent(candidate)
            counter += 1
        }
        return url
    }
}

/// One running DCC receive: owns the socket and file handle on its own queue,
/// reporting back through `onEvent` (called on the queue — hop as needed).
final class DCCReceiveSession {
    enum Event {
        case connected
        case progress(Int64)
        case finished(Int64)
        case failed(String)
    }

    private let connection: NWConnection
    private let fileHandle: FileHandle
    private let expectedSize: Int64
    private let onEvent: (Event) -> Void
    private let queue = DispatchQueue(label: "com.liquidchat.dcc.receive")
    private var received: Int64 = 0
    private var finished = false

    init(host: String, port: UInt16, fileHandle: FileHandle, expectedSize: Int64,
         onEvent: @escaping (Event) -> Void) {
        self.connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: port) ?? 1,
            using: .tcp
        )
        self.fileHandle = fileHandle
        self.expectedSize = expectedSize
        self.onEvent = onEvent
    }

    func start() {
        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                self.onEvent(.connected)
                self.receiveChunk()
            case .failed(let error):
                self.finish(with: .failed(error.localizedDescription))
            case .cancelled:
                if !self.finished {
                    self.finish(with: .failed("Connection closed"))
                }
            default:
                break
            }
        }
        connection.start(queue: queue)
    }

    func stop() {
        queue.async { [self] in
            finished = true
            connection.cancel()
            try? fileHandle.close()
        }
    }

    private func receiveChunk() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self, !self.finished else { return }

            if let data, !data.isEmpty {
                do {
                    try self.fileHandle.write(contentsOf: data)
                } catch {
                    self.finish(with: .failed("Write failed: \(error.localizedDescription)"))
                    return
                }
                self.received += Int64(data.count)
                self.sendAck()
                self.onEvent(.progress(self.received))

                if self.expectedSize > 0 && self.received >= self.expectedSize {
                    self.finish(with: .finished(self.received))
                    return
                }
            }

            if let error {
                self.finish(with: .failed(error.localizedDescription))
                return
            }
            if isComplete {
                // EOF: success when we got everything (or size was unknown)
                if self.expectedSize <= 0 || self.received >= self.expectedSize {
                    self.finish(with: .finished(self.received))
                } else {
                    self.finish(with: .failed("Connection closed after \(self.received) of \(self.expectedSize) bytes"))
                }
                return
            }
            self.receiveChunk()
        }
    }

    /// DCC acknowledgment: cumulative byte count as a 4-byte big-endian
    /// integer (wraps for >4GB files, as the classic protocol does).
    private func sendAck() {
        var ack = UInt32(truncatingIfNeeded: received).bigEndian
        let data = Data(bytes: &ack, count: 4)
        connection.send(content: data, completion: .contentProcessed { _ in })
    }

    private func finish(with event: Event) {
        guard !finished else { return }
        finished = true
        try? fileHandle.close()
        connection.cancel()
        onEvent(event)
    }
}
