import Foundation

public final class F1NewsService {
    private let feedURLs: [URL] = [
        URL(string: "https://www.formula1.com/en/latest/all.xml")!,
        URL(string: "https://www.autosport.com/rss/f1/news/")!
    ]

    public init() {}

    public func fetchLatestNews(limit: Int = 30) async throws -> [F1NewsItem] {
        var lastError: Error?

        for feedURL in feedURLs {
            do {
                let (data, response) = try await URLSession.shared.data(from: feedURL)
                guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                    throw AuthError.invalidResponse
                }

                let parser = F1NewsRSSParser()
                let items = try parser.parse(data: data)

                if !items.isEmpty {
                    return Array(items.prefix(limit))
                }
            } catch {
                lastError = error
            }
        }

        throw lastError ?? AuthError.invalidResponse
    }
}

private final class F1NewsRSSParser: NSObject, XMLParserDelegate {
    private struct CurrentItem {
        var title: String = ""
        var link: String = ""
        var description: String = ""
        var pubDate: String = ""
        var source: String = ""
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

        return F1NewsItem(
            id: id,
            title: item.title,
            summary: cleanSummary,
            link: url,
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
