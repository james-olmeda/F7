import Foundation

@Observable
public final class F1NewsViewModel {
    public var newsItems: [F1NewsItem] = []
    public var isLoading: Bool = false
    public var errorMessage: String?
    public var lastUpdated: Date?

    private let newsService: F1NewsService

    public init(newsService: F1NewsService = F1NewsService()) {
        self.newsService = newsService
    }

    public func loadLatestNews() async {
        isLoading = true
        errorMessage = nil

        do {
            newsItems = try await newsService.fetchLatestNews()
            lastUpdated = Date()
        } catch {
            newsItems = []
            errorMessage = "Failed to load latest news: \(error.localizedDescription)"
        }

        isLoading = false
    }

    public func refresh() async {
        await loadLatestNews()
    }
}
