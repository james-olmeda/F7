import Foundation

/// Manages the F1TV content catalog state for the browser view.
@Observable
public final class ContentBrowserViewModel {
    
    /// All available content items.
    public var contentItems: [F1TVContentItem] = []
    
    /// Whether content is being loaded.
    public var isLoading: Bool = false
    
    /// Error message if content loading fails.
    public var errorMessage: String?
    
    /// Current filter selection.
    public var selectedFilter: ContentFilter = .all
    
    private let contentService: F1TVContentService
    
    public enum ContentFilter: String, CaseIterable {
        case all = "All"
        case live = "Live"
        case races = "Races"
        case qualifying = "Qualifying"
        case practice = "Practice"
        case replays = "Replays"
    }
    
    public init(contentService: F1TVContentService) {
        self.contentService = contentService
    }
    
    /// Filtered items based on the current filter selection.
    public var filteredItems: [F1TVContentItem] {
        switch selectedFilter {
        case .all:
            return contentItems
        case .live:
            return contentItems.filter { $0.isLive }
        case .races:
            return contentItems.filter { $0.sessionType == .race || $0.sessionType == .sprintRace }
        case .qualifying:
            return contentItems.filter { $0.sessionType == .qualifying || $0.sessionType == .sprintQualifying }
        case .practice:
            return contentItems.filter { $0.sessionType == .practice }
        case .replays:
            return contentItems.filter { $0.sessionType == .replay }
        }
    }
    
    /// Loads the content catalog from F1TV.
    public func loadContent() async {
        isLoading = true
        errorMessage = nil
        
        do {
            contentItems = try await contentService.fetchContentCatalog()
            print("[ContentBrowserViewModel] Loaded \(contentItems.count) content items.")
        } catch {
            errorMessage = "Failed to load content: \(error.localizedDescription)"
            print("[ContentBrowserViewModel] Error loading content: \(error)")
        }
        
        isLoading = false
    }
    
    /// Refreshes the content catalog.
    public func refresh() async {
        await loadContent()
    }
}
