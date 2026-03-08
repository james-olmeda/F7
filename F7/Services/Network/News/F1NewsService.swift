import Foundation

public final class F1NewsService {
    private let feedURLs: [URL] = [
        URL(string: "https://www.formula1.com/en/latest/all.xml")!,
        URL(string: "https://www.autosport.com/rss/f1/news/")!
    ]

    public init() {}

    public func fetchLatestNews(limit: Int = 30) async throws -> [F1NewsItem] {
        var lastError: Error?
        var aggregatedItems: [F1NewsItem] = []

        for feedURL in feedURLs {
            do {
                let (data, response) = try await URLSession.shared.data(from: feedURL)
                guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                    throw AuthError.invalidResponse
                }

                let parser = F1NewsRSSParser()
                let items = try parser.parse(data: data)
                aggregatedItems.append(contentsOf: items)
            } catch {
                lastError = error
            }
        }

        let deduplicated = deduplicate(items: aggregatedItems)
        guard !deduplicated.isEmpty else {
            throw lastError ?? AuthError.invalidResponse
        }

        let sorted = deduplicated.sorted {
            ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast)
        }
        let trimmed = Array(sorted.prefix(limit))

        return await enrichMissingImages(in: trimmed)
    }

    private func deduplicate(items: [F1NewsItem]) -> [F1NewsItem] {
        var seen = Set<String>()
        var result: [F1NewsItem] = []

        for item in items {
            if seen.insert(item.id).inserted {
                result.append(item)
            }
        }

        return result
    }

    private func enrichMissingImages(in items: [F1NewsItem]) async -> [F1NewsItem] {
        var enriched = items
        var lookupsRemaining = 8

        for index in enriched.indices {
            if enriched[index].imageURL != nil {
                continue
            }
            guard lookupsRemaining > 0 else {
                break
            }

            lookupsRemaining -= 1

            if let discoveredImageURL = await fetchPreviewImage(for: enriched[index].link) {
                let current = enriched[index]
                enriched[index] = F1NewsItem(
                    id: current.id,
                    title: current.title,
                    summary: current.summary,
                    link: current.link,
                    imageURL: discoveredImageURL,
                    publishedAt: current.publishedAt,
                    source: current.source
                )
            }
        }

        return enriched
    }

    private func fetchPreviewImage(for articleURL: URL) async -> URL? {
        do {
            let (data, response) = try await URLSession.shared.data(from: articleURL)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                return nil
            }

            guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .unicode) else {
                return nil
            }

            return extractMetaImageURL(fromHTML: html, baseURL: articleURL)
        } catch {
            return nil
        }
    }

    private func extractMetaImageURL(fromHTML html: String, baseURL: URL) -> URL? {
        let patterns = [
            #"<meta[^>]*property=[\"']og:image[\"'][^>]*content=[\"']([^\"']+)[\"']"#,
            #"<meta[^>]*content=[\"']([^\"']+)[\"'][^>]*property=[\"']og:image[\"']"#,
            #"<meta[^>]*name=[\"']twitter:image[\"'][^>]*content=[\"']([^\"']+)[\"']"#,
            #"<meta[^>]*content=[\"']([^\"']+)[\"'][^>]*name=[\"']twitter:image[\"']"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                continue
            }

            let range = NSRange(html.startIndex..<html.endIndex, in: html)
            guard let match = regex.firstMatch(in: html, options: [], range: range),
                  let valueRange = Range(match.range(at: 1), in: html) else {
                continue
            }

            let rawValue = String(html[valueRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            if rawValue.hasPrefix("//") {
                return URL(string: "https:" + rawValue)
            }

            if let absolute = URL(string: rawValue), absolute.scheme != nil {
                return absolute
            }

            if let relative = URL(string: rawValue, relativeTo: baseURL)?.absoluteURL {
                return relative
            }
        }

        return nil
    }
}

private final class F1NewsRSSParser: NSObject, XMLParserDelegate {
    private struct CurrentItem {
        var title: String = ""
        var link: String = ""
        var description: String = ""
        var pubDate: String = ""
        var source: String = ""
        var imageURL: String = ""
    }

    private var items: [F1NewsItem] = []
    private var currentItem: CurrentItem?
    private var currentElement = ""
    private var currentText = ""
    private var didParseChannelTitle = false
    private var channelTitle = "F1"

    func parse(data: Data) throws -> [F1NewsItem] {
        items = []
        currentItem = nil
        currentElement = ""
        currentText = ""
        didParseChannelTitle = false
        channelTitle = "F1"

        let parser = XMLParser(data: data)
        parser.delegate = self

        guard parser.parse() else {
            throw parser.parserError ?? AuthError.invalidResponse
        }

        return items.sorted {
            ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast)
        }
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
        currentText = ""

        if elementName == "item" || elementName == "entry" {
            currentItem = CurrentItem(source: channelTitle)
        }

        guard var item = currentItem else { return }

        let element = elementName.lowercased()
        if (element == "media:content" || element == "media:thumbnail" || element == "enclosure"),
           item.imageURL.isEmpty,
           let candidate = attributeDict["url"],
           isLikelyImageURL(candidate) {
            item.imageURL = candidate
        }

        if element == "link", item.link.isEmpty,
           let href = attributeDict["href"],
           let rel = attributeDict["rel"],
           rel.lowercased() == "alternate" {
            item.link = href
        }

        currentItem = item
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        if currentItem == nil, elementName == "title", !didParseChannelTitle, !trimmed.isEmpty {
            channelTitle = trimmed
            didParseChannelTitle = true
        }

        guard var item = currentItem else { return }

        switch elementName {
        case "title":
            if !trimmed.isEmpty {
                item.title = trimmed
            }
        case "link":
            if !trimmed.isEmpty {
                item.link = trimmed
            }
        case "description", "summary", "content":
            if !trimmed.isEmpty {
                item.description = trimmed
                if item.imageURL.isEmpty, let extractedImage = extractImageURL(fromHTML: trimmed) {
                    item.imageURL = extractedImage
                }
            }
        case "pubDate", "published", "updated":
            if !trimmed.isEmpty {
                item.pubDate = trimmed
            }
        case "item", "entry":
            if let newsItem = buildNewsItem(from: item) {
                items.append(newsItem)
            }
            currentItem = nil
            return
        default:
            break
        }

        currentItem = item
    }

    private func buildNewsItem(from item: CurrentItem) -> F1NewsItem? {
        guard !item.title.isEmpty else { return nil }
        guard let url = URL(string: item.link), !item.link.isEmpty else { return nil }

        let cleanSummary = stripHTML(from: item.description)
        let publishedAt = parseDate(item.pubDate)
        let id = url.absoluteString
        let imageURL = URL(string: item.imageURL)

        return F1NewsItem(
            id: id,
            title: item.title,
            summary: cleanSummary,
            link: url,
            imageURL: imageURL,
            publishedAt: publishedAt,
            source: item.source
        )
    }

    private func stripHTML(from input: String) -> String? {
        guard !input.isEmpty else { return nil }

        let plain = input.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        let decoded = plain
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return decoded.isEmpty ? nil : decoded
    }

    private func extractImageURL(fromHTML html: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: #"<img[^>]*src=\"([^\"]+)\""#, options: [.caseInsensitive]) else {
            return nil
        }

        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        guard let match = regex.firstMatch(in: html, options: [], range: range),
              let sourceRange = Range(match.range(at: 1), in: html) else {
            return nil
        }

        let candidate = String(html[sourceRange])
        return isLikelyImageURL(candidate) ? candidate : nil
    }

    private func isLikelyImageURL(_ value: String) -> Bool {
        guard let url = URL(string: value), let scheme = url.scheme?.lowercased() else {
            return false
        }

        guard scheme == "http" || scheme == "https" else {
            return false
        }

        let lowercase = value.lowercased()
        return lowercase.contains(".jpg")
            || lowercase.contains(".jpeg")
            || lowercase.contains(".png")
            || lowercase.contains(".webp")
            || lowercase.contains(".avif")
            || lowercase.contains("image")
    }

    private func parseDate(_ value: String) -> Date? {
        guard !value.isEmpty else { return nil }

        let formatters: [DateFormatter] = [
            rfc822Formatter,
            iso8601Formatter,
            alternateISO8601Formatter
        ]

        for formatter in formatters {
            if let date = formatter.date(from: value) {
                return date
            }
        }

        return nil
    }

    private lazy var rfc822Formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return formatter
    }()

    private lazy var iso8601Formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return formatter
    }()

    private lazy var alternateISO8601Formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        return formatter
    }()
}
