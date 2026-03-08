import Foundation

public struct F1NewsItem: Identifiable, Hashable {
    public let id: String
    public let title: String
    public let summary: String?
    public let link: URL
    public let imageURL: URL?
    public let publishedAt: Date?
    public let source: String

    public init(
        id: String,
        title: String,
        summary: String?,
        link: URL,
        imageURL: URL? = nil,
        publishedAt: Date?,
        source: String
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.link = link
        self.imageURL = imageURL
        self.publishedAt = publishedAt
        self.source = source
    }
}
