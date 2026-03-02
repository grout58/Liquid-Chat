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
        guard let pathExtension = url.pathExtension.lowercased() as String? else { return false }
        return ["jpg", "jpeg", "png", "gif", "webp", "bmp"].contains(pathExtension)
    }
}

/// Actor-based URL preview fetcher for safe concurrent access
actor URLPreviewFetcher {
    static let shared = URLPreviewFetcher()
    
    // Cache to avoid re-fetching the same URLs
    private var cache: [URL: URLPreview] = [:]
    
    // Cached regex patterns for HTML parsing (improves performance)
    private static let cachedRegexPatterns: [String: NSRegularExpression] = {
        var patterns: [String: NSRegularExpression] = [:]
        
        // Common HTML meta tag patterns
        let metaPatterns = [
            "title": "<title>([^<]+)</title>",
            "meta_property": "<meta\\s+property=\"([^\"]+)\"\\s+content=\"([^\"]+)\"",
            "meta_name": "<meta\\s+name=\"([^\"]+)\"\\s+content=\"([^\"]+)\""
        ]
        
        for (key, pattern) in metaPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                patterns[key] = regex
            }
        }
        
        return patterns
    }()
    
    private init() {}
    
    /// Fetch preview data for a URL
    func fetchPreview(for url: URL) async -> URLPreview? {
        // Check cache first
        if let cached = cache[url] {
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
            cache[url] = preview
            return preview
        }
        
        // Fetch HTML and parse metadata
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            guard let html = String(data: data, encoding: .utf8) else {
                return nil
            }
            
            let preview = parseHTMLMetadata(html: html, url: url)
            cache[url] = preview
            return preview
            
        } catch {
            await ConsoleLogger.shared.log("Failed to fetch URL preview: \(error.localizedDescription)", level: .warning, category: "URLPreview")
            return nil
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
    
    /// Extracts content using a regex pattern (with compiled pattern caching)
    /// - Parameters:
    ///   - pattern: The regex pattern to match
    ///   - html: The HTML string to search
    /// - Returns: The extracted content with HTML entities decoded
    private func extractPattern(_ pattern: String, from html: String) -> String? {
        // Try to compile regex (this should be fast due to simplicity)
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
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
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&apos;", with: "'")
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
