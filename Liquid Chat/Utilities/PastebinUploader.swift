//
//  PastebinUploader.swift
//  Liquid Chat
//
//  Uploads large text blocks to paste.rs and returns the paste URL.
//

import Foundation

actor PastebinUploader {
    static let shared = PastebinUploader()

    private let endpoint = URL(string: "https://paste.rs/")!

    /// Upload text to paste.rs and return the resulting URL string.
    func upload(_ text: String) async throws -> String {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.httpBody = Data(text.utf8)
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 201 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw PastebinError.serverError(code)
        }

        let urlString = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !urlString.isEmpty else { throw PastebinError.emptyResponse }
        return urlString
    }
}

enum PastebinError: LocalizedError {
    case serverError(Int)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .serverError(let code): return "paste.rs returned HTTP \(code)"
        case .emptyResponse:         return "paste.rs returned an empty URL"
        }
    }
}
