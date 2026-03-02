import SwiftUI

/// Grid view of available F1TV content with filtering.
public struct ContentBrowserView: View {
    @Environment(ContentBrowserViewModel.self) private var contentVM
    
    public var body: some View {
        @Bindable var vm = contentVM
        
        VStack(spacing: 0) {
            // Filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ContentBrowserViewModel.ContentFilter.allCases, id: \.self) { filter in
                        FilterChip(
                            title: filter.rawValue,
                            isSelected: contentVM.selectedFilter == filter
                        ) {
                            contentVM.selectedFilter = filter
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            
            // Content grid
            if contentVM.isLoading {
                Spacer()
                ProgressView("Loading F1TV content...")
                    .foregroundColor(.secondary)
                Spacer()
            } else if let error = contentVM.errorMessage {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task { await contentVM.loadContent() }
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
                .padding()
                Spacer()
            } else if contentVM.filteredItems.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "tv.slash")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No content available")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(contentVM.filteredItems) { item in
                            NavigationLink(value: item) {
                                ContentCardView(item: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            }
        }
        .background(Color.black)
        .navigationTitle("F1TV")
        .navigationDestination(for: F1TVContentItem.self) { item in
            VideoPlayerView(contentItem: item)
        }
        .task {
            if contentVM.contentItems.isEmpty {
                await contentVM.loadContent()
            }
        }
        .refreshable {
            await contentVM.refresh()
        }
    }
}

// MARK: - Filter Chip
fileprivate struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.caption, design: .default, weight: .semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(isSelected ? Color.red : Color(white: 0.15))
                .foregroundColor(isSelected ? .white : .secondary)
                .cornerRadius(16)
        }
    }
}

// MARK: - Content Card
fileprivate struct ContentCardView: View {
    let item: F1TVContentItem
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            ZStack {
                if let pictureUrl = item.pictureUrl {
                    F1TVImageView(pictureUrl: pictureUrl, width: 120, height: 68)
                        .frame(width: 120, height: 68)
                        .cornerRadius(8)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(white: 0.12))
                        .frame(width: 120, height: 68)
                    Image(systemName: "play.rectangle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                
                // Live badge
                if item.isLive {
                    VStack {
                        HStack {
                            Spacer()
                            Text("LIVE")
                                .font(.system(.caption2, design: .default, weight: .black))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red)
                                .cornerRadius(4)
                        }
                        Spacer()
                    }
                    .padding(4)
                }
            }
            .frame(width: 120, height: 68)
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(.subheadline, design: .default, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                if let gpName = item.grandPrixName {
                    Text(gpName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 8) {
                    Text(item.sessionType.displayName)
                        .font(.system(.caption2, design: .default, weight: .medium))
                        .foregroundColor(.red)
                    
                    if let duration = item.durationSeconds {
                        Text(formatDuration(duration))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color(white: 0.08))
        .cornerRadius(12)
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes) min"
    }
}
