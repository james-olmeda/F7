import SwiftUI
import WebKit

public struct F1NewsView: View {
    @Environment(F1NewsViewModel.self) private var newsVM

    public var body: some View {
        @Bindable var vm = newsVM

        ZStack {
            Color.black.ignoresSafeArea()

            if vm.isLoading && vm.newsItems.isEmpty {
                ProgressView("Loading latest F1 news...")
            } else if let error = vm.errorMessage, vm.newsItems.isEmpty {
                emptyState(
                    icon: "newspaper.fill",
                    title: "News unavailable",
                    subtitle: error,
                    actionTitle: "Retry"
                ) {
                    Task { await vm.loadLatestNews() }
                }
            } else if vm.newsItems.isEmpty {
                emptyState(
                    icon: "newspaper",
                    title: "No latest news",
                    subtitle: "Check back shortly for fresh F1 coverage.",
                    actionTitle: nil,
                    action: nil
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HeaderView()
                            .padding(.top, 8)

                        TopicChipsView()

                        Text("Top Stories")
                            .font(.system(size: 38, weight: .black, design: .rounded))
                            .foregroundColor(.red)
                            .padding(.top, 2)

                        if let topStory = vm.newsItems.first {
                            NavigationLink(value: topStory) {
                                TopStoryCard(item: topStory)
                            }
                            .buttonStyle(.plain)
                        }

                        let moreCoverage = Array(vm.newsItems.dropFirst().prefix(8))
                        if !moreCoverage.isEmpty {
                            Text("More Coverage")
                                .font(.system(.caption, design: .rounded, weight: .bold))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .padding(.top, 4)

                            VStack(spacing: 0) {
                                ForEach(Array(moreCoverage.enumerated()), id: \.element.id) { index, item in
                                    NavigationLink(value: item) {
                                        CoverageRow(item: item)
                                    }
                                    .buttonStyle(.plain)

                                    if index < moreCoverage.count - 1 {
                                        Divider()
                                            .overlay(Color.white.opacity(0.1))
                                    }
                                }
                            }
                            .padding(14)
                            .background(Color(white: 0.10))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
        }
        .navigationDestination(for: F1NewsItem.self) { item in
            NewsDetailView(item: item)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if vm.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await vm.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(vm.isLoading)
            }
        }
        .task {
            if vm.newsItems.isEmpty {
                await vm.loadLatestNews()
            }
        }
        .refreshable {
            await vm.refresh()
        }
    }

    @ViewBuilder
    private func emptyState(
        icon: String,
        title: String,
        subtitle: String,
        actionTitle: String?,
        action: (() -> Void)?
    ) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 34, weight: .semibold))
                .foregroundColor(.secondary)

            Text(title)
                .font(.headline)
                .foregroundColor(.white)

            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
            }
        }
    }
}

private struct HeaderView: View {
    private static let headerDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: "applelogo")
                    .font(.title3.weight(.bold))
                    .foregroundColor(.white)
                Text("News+")
                    .font(.system(size: 45, weight: .black, design: .rounded))
                    .foregroundColor(.white)
            }

            Text(Self.headerDateFormatter.string(from: Date()))
                .font(.system(size: 48, weight: .black, design: .rounded))
                .foregroundColor(Color(red: 0.58, green: 0.58, blue: 0.62))
                .lineLimit(1)
        }
    }
}

private struct TopicChipsView: View {
    private let topics = ["Races", "Teams", "Drivers", "Business"]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(topics, id: \.self) { topic in
                    HStack(spacing: 6) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 5))
                        Text(topic)
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    }
                    .foregroundColor(.white.opacity(0.88))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color(white: 0.16))
                    .clipShape(Capsule())
                }
            }
        }
    }
}

private struct TopStoryCard: View {
    let item: F1NewsItem

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RemoteNewsImage(url: item.imageURL)
                .frame(height: 230)
                .overlay(alignment: .topLeading) {
                    HStack(spacing: 6) {
                        Text(item.source)
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .foregroundColor(.white.opacity(0.95))
                        Text(publishedAtText)
                            .font(.system(.caption, design: .rounded, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(10)
                }

            VStack(alignment: .leading, spacing: 8) {
                Text(item.title)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(3)

                if let summary = item.summary, !summary.isEmpty {
                    Text(summary)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }
            }
            .padding(14)
            .background(Color(white: 0.10))
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var publishedAtText: String {
        guard let date = item.publishedAt else {
            return ""
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return "• " + formatter.localizedString(for: date, relativeTo: Date())
    }
}

private struct CoverageRow: View {
    let item: F1NewsItem

    var body: some View {
        HStack(spacing: 12) {
            RemoteNewsImage(url: item.imageURL)
                .frame(width: 86, height: 62)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(item.source)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundColor(.secondary)

                Text(item.title)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
    }
}

private struct RemoteNewsImage: View {
    let url: URL?

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        placeholder
                    case .empty:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .clipped()
    }

    private var placeholder: some View {
        LinearGradient(
            colors: [Color(white: 0.35), Color(white: 0.2), Color(white: 0.1)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

private struct NewsDetailView: View {
    let item: F1NewsItem

    private static let detailDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    RemoteNewsImage(url: item.imageURL)
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    Text(item.title)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundColor(.white)

                    HStack(spacing: 8) {
                        Text(item.source)
                            .font(.caption)
                            .foregroundColor(.red)

                        if let date = item.publishedAt {
                            Text("• \(Self.detailDateFormatter.string(from: date))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if let summary = item.summary, !summary.isEmpty {
                        Text(summary)
                            .font(.body)
                            .foregroundColor(.white.opacity(0.92))
                    }
                }
                .padding(16)
            }
            .background(Color.black)

            Divider()
                .overlay(Color.white.opacity(0.1))

            NewsArticleWebView(url: item.link)
                .background(Color.black)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("News")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct NewsArticleWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if uiView.url != url {
            uiView.load(URLRequest(url: url))
        }
    }
}
