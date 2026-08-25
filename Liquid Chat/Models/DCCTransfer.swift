//
//  DCCTransfer.swift
//  Liquid Chat
//
//  DCC file transfer model and offer parsing
//

import Foundation

/// A parsed `DCC SEND` offer from a CTCP message.
struct DCCOffer: Equatable {
    let filename: String     // sanitized — never contains path components
    let host: String
    let port: UInt16
    let fileSize: Int64      // 0 when the sender didn't include a size
    /// Port 0 means reverse/passive DCC (the sender wants US to listen) —
    /// unsupported, surfaced so the offer can be declined with a reason.
    var isPassive: Bool { port == 0 }

    /// Parse the arguments after "DCC SEND": `<filename> <ip> <port> [<size>]`.
    /// Filenames containing spaces arrive double-quoted.
    static func parse(sendArguments raw: String) -> DCCOffer? {
        var rest = Substring(raw).drop(while: { $0 == " " })

        // Filename: quoted (may contain spaces) or a bare token
        let rawFilename: String
        if rest.hasPrefix("\"") {
            rest = rest.dropFirst()
            guard let closeQuote = rest.firstIndex(of: "\"") else { return nil }
            rawFilename = String(rest[..<closeQuote])
            rest = rest[rest.index(after: closeQuote)...]
        } else {
            let end = rest.firstIndex(of: " ") ?? rest.endIndex
            rawFilename = String(rest[..<end])
            rest = rest[end...]
        }
        guard !rawFilename.isEmpty else { return nil }

        let fields = rest.split(separator: " ")
        guard fields.count >= 2 else { return nil }

        // Host: classic clients send a decimal integer (IPv4, big-endian);
        // modern ones may send a literal IPv4/IPv6 address
        let host: String
        if let packed = UInt32(fields[0]) {
            host = "\(packed >> 24 & 0xFF).\(packed >> 16 & 0xFF).\(packed >> 8 & 0xFF).\(packed & 0xFF)"
        } else {
            host = String(fields[0])
        }

        guard let port = UInt16(fields[1]) else { return nil }
        let size = fields.count >= 3 ? Int64(fields[2]) ?? 0 : 0
        guard size >= 0 else { return nil }

        return DCCOffer(filename: sanitizeFilename(rawFilename), host: host, port: port, fileSize: size)
    }

    /// Strip path components and hidden-file dots so a hostile offer can't
    /// escape the downloads folder or masquerade as a dotfile.
    static func sanitizeFilename(_ raw: String) -> String {
        let name = raw
            .components(separatedBy: CharacterSet(charactersIn: "/\\:"))
            .last { !$0.isEmpty } ?? ""
        let trimmed = name.drop(while: { $0 == "." })
        return trimmed.isEmpty ? "download" : String(trimmed)
    }
}

/// One DCC transfer as tracked by the UI.
@Observable
final class DCCTransfer: Identifiable {
    enum State: Equatable {
        case offered
        case connecting
        case transferring
        case completed
        case declined
        case failed(String)
    }

    let id = UUID()
    let sender: String
    let serverName: String
    let offer: DCCOffer
    var state: State = .offered
    var bytesTransferred: Int64 = 0
    /// Where the file was written (set once accepted)
    var destination: URL?

    init(sender: String, serverName: String, offer: DCCOffer) {
        self.sender = sender
        self.serverName = serverName
        self.offer = offer
    }

    var progress: Double? {
        guard offer.fileSize > 0 else { return nil }
        return Double(bytesTransferred) / Double(offer.fileSize)
    }

    var formattedSize: String {
        guard offer.fileSize > 0 else { return "unknown size" }
        return ByteCountFormatter.string(fromByteCount: offer.fileSize, countStyle: .file)
    }
}
