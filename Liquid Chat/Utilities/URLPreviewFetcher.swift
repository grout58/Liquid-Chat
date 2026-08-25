//
//  URLPreviewFetcher.swift
//  Liquid Chat
//
//  Fetches URL previews and metadata for inline display
//

import Foundation
import SwiftUI

/// Represents preview data for a URL
struct URLPreview: Identifiable {
    let id = UUID()
    let url: URL
    let title: String?
    let description: String?
    let imageURL: URL?
    let siteName: String?
    
    var isImage: Bool {
        let pathExtension = url.pathExtension.lowercased()
        return ["jpg", "jpeg", "png", "gif", "webp", "bmp"].contains(pathExtension)
    }
}

/// Actor-based URL preview fetcher for safe concurrent access
actor URLPreviewFetcher {
    static let shared = URLPreviewFetcher()

    // Cache to avoid re-fetching the same URLs. Capped at 200 entries (LRU eviction).
    private var cache: [URL: URLPreview] = [:]
    private var cacheOrder: [URL] = []
    private let maxCacheSize = 200

    // Compiled regex cache keyed by pattern string, to avoid recompilation on every call.
    private var regexCache: [String: NSRegularExpression] = [:]

    // Requests already running, so N visible rows with the same URL share one fetch.
    private var inFlight: [URL: Task<URLPreview?, Never>] = [:]

    // Hard cap on how much of a page is downloaded for metadata — protects
    // against a link to a multi-gigabyte resource flooding memory.
    private let maxDownloadBytes = 512 * 1024

    private static let urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        return URLSession(configuration: config)
    }()

    private init() {}
    
    /// Fetch preview data for a URL
    func fetchPreview(for url: URL) async -> URLPreview? {
        // Check cache first (touch the entry so eviction is true LRU)
        if let cached = cache[url] {
            if let index = cacheOrder.firstIndex(of: url) {
                cacheOrder.remove(at: index)
                cacheOrder.append(url)
            }
            return cached
        }

        // If it's a direct image URL, return basic preview
        if isImageURL(url) {
            let preview = URLPreview(
                url: url,
                title: url.lastPathComponent,
                description: nil,
                imageURL: url,
                siteName: url.host
            )
            store(preview, for: url)
            return preview
        }

        // Coalesce concurrent requests for the same URL into one fetch
        if let running = inFlight[url] {
            return await running.value
        }

        let maxBytes = maxDownloadBytes
        let fetchTask = Task<URLPreview?, Never> {
            guard let data = await Self.fetchHTMLHead(url: url, maxBytes: maxBytes),
                  let html = String(data: data, encoding: .utf8) else { return nil }
            return self.parseHTMLMetadata(html: html, url: url)
        }
        inFlight[url] = fetchTask
        let preview = await fetchTask.value
        inFlight[url] = nil

        store(preview, for: url)
        return preview
    }

    /// Download at most `maxBytes` of an HTML page. Non-HTML responses are
    /// refused — metadata only ever lives in HTML, and this is what stops a
    /// posted link to a huge binary from being downloaded at all.
    private static func fetchHTMLHead(url: URL, maxBytes: Int) async -> Data? {
        do {
            let (bytes, response) = try await urlSession.bytes(from: url)

            if let http = response as? HTTPURLResponse {
                guard (200..<300).contains(http.statusCode) else { return nil }
            }
            let mimeType = response.mimeType ?? ""
            guard mimeType.isEmpty || mimeType.hasPrefix("text/html") || mimeType.hasPrefix("application/xhtml") else {
                return nil
            }

            var data = Data()
            data.reserveCapacity(min(maxBytes, 64 * 1024))
            for try await byte in bytes {
                data.append(byte)
                if data.count >= maxBytes { break }
            }
            return data
        } catch {
            Task {
                await ConsoleLogger.shared.log("Failed to fetch URL preview: \(error.localizedDescription)", level: .warning, category: "URLPreview")
            }
            return nil
        }
    }
    
    /// Store a preview in the cache, evicting the oldest entry if over the limit.
    private func store(_ preview: URLPreview?, for url: URL) {
        if let preview {
            if cache[url] == nil {
                cacheOrder.append(url)
                if cacheOrder.count > maxCacheSize {
                    let evict = cacheOrder.removeFirst()
                    cache.removeValue(forKey: evict)
                }
            }
            cache[url] = preview
        }
    }

    private func isImageURL(_ url: URL) -> Bool {
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "webp", "bmp"]
        return imageExtensions.contains(url.pathExtension.lowercased())
    }
    
    private func parseHTMLMetadata(html: String, url: URL) -> URLPreview? {
        var title: String?
        var description: String?
        var imageURL: URL?
        var siteName: String?
        
        // Parse Open Graph tags (og:title, og:description, og:image)
        if let ogTitle = extractMetaTag(from: html, property: "og:title") {
            title = ogTitle
        }
        
        if let ogDescription = extractMetaTag(from: html, property: "og:description") {
            description = ogDescription
        }
        
        if let ogImage = extractMetaTag(from: html, property: "og:image") {
            imageURL = URL(string: ogImage, relativeTo: url)
        }
        
        if let ogSiteName = extractMetaTag(from: html, property: "og:site_name") {
            siteName = ogSiteName
        }
        
        // Fallback to Twitter Card tags
        if title == nil, let twitterTitle = extractMetaTag(from: html, name: "twitter:title") {
            title = twitterTitle
        }
        
        if description == nil, let twitterDescription = extractMetaTag(from: html, name: "twitter:description") {
            description = twitterDescription
        }
        
        if imageURL == nil, let twitterImage = extractMetaTag(from: html, name: "twitter:image") {
            imageURL = URL(string: twitterImage, relativeTo: url)
        }
        
        // Fallback to HTML title tag
        if title == nil {
            title = extractTitleTag(from: html)
        }
        
        // Fallback to meta description
        if description == nil {
            description = extractMetaTag(from: html, name: "description")
        }
        
        return URLPreview(
            url: url,
            title: title,
            description: description,
            imageURL: imageURL,
            siteName: siteName ?? url.host
        )
    }
    
    private func extractMetaTag(from html: String, property: String) -> String? {
        // Match: <meta property="og:title" content="value">
        let pattern = "<meta\\s+property=\"\(property)\"\\s+content=\"([^\"]+)\""
        return extractPattern(pattern, from: html)
    }
    
    private func extractMetaTag(from html: String, name: String) -> String? {
        // Match: <meta name="description" content="value">
        let pattern = "<meta\\s+name=\"\(name)\"\\s+content=\"([^\"]+)\""
        return extractPattern(pattern, from: html)
    }
    
    private func extractTitleTag(from html: String) -> String? {
        // Match: <title>value</title>
        let pattern = "<title>([^<]+)</title>"
        return extractPattern(pattern, from: html)
    }
    
    /// Extracts content using a regex pattern, caching compiled expressions.
    private func extractPattern(_ pattern: String, from html: String) -> String? {
        let regex: NSRegularExpression
        if let cached = regexCache[pattern] {
            regex = cached
        } else {
            guard let compiled = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                return nil
            }
            regexCache[pattern] = compiled
            regex = compiled
        }
        
        let range = NSRange(html.startIndex..., in: html)
        guard let match = regex.firstMatch(in: html, range: range),
              match.numberOfRanges >= 2,
              let contentRange = Range(match.range(at: 1), in: html) else {
            return nil
        }
        
        return decodeHTMLEntities(String(html[contentRange]))
    }
    
    /// Decodes common HTML entities
    /// - Parameter text: Text containing HTML entities
    /// - Returns: Decoded text
    private func decodeHTMLEntities(_ text: String) -> String {
        // &amp; must decode LAST or "&amp;lt;" double-decodes into "<"
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&amp;", with: "&")
    }
}

/// View component for displaying URL previews
struct URLPreviewView: View {
    let preview: URLPreview
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Image preview
            if let imageURL = preview.imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 200)
                            .cornerRadius(8)
                    case .failure:
                        HStack {
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                            Text("Failed to load image")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(height: 100)
                    case .empty:
                        ProgressView()
                            .frame(height: 100)
                    @unknown default:
                        EmptyView()
                    }
                }
            }
            
            // Text metadata
            VStack(alignment: .leading, spacing: 4) {
                if let siteName = preview.siteName {
                    Text(siteName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                if let title = preview.title {
                    Text(title)
                        .font(.headline)
                        .lineLimit(2)
                }
                
                if let description = preview.description {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
                
                // URL
                Text(preview.url.absoluteString)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(8)
        .background(.thinMaterial)
        .cornerRadius(8)
        .onTapGesture {
            #if os(macOS)
            NSWorkspace.shared.open(preview.url)
            #endif
        }
    }
}

/// Extension to detect URLs in text
extension String {
    func extractURLs() -> [URL] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return []
        }
        
        let matches = detector.matches(in: self, range: NSRange(startIndex..., in: self))
        
        return matches.compactMap { match in
            guard let range = Range(match.range, in: self),
                  let url = URL(string: String(self[range])) else {
                return nil
            }
            return url
        }
    }
}
