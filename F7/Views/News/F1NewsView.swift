import SwiftUI

public struct F1NewsView: View {
    @Environment(F1NewsViewModel.self) private var newsVM

    public var body: some View {
        @Bindable var vm = newsVM

        ZStack {
            Color(.systemBackground).ignoresSafeArea()

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
                            .font(.inter(size: 38, weight: .black, design: .rounded))
                            .foregroundColor(.appAccent)
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
                                .font(.inter(.caption, design: .rounded, weight: .bold))
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
                                            .overlay(Color(.separator))
                                    }
                                }
                            }
                            .padding(14)
                            .background(Color(.secondarySystemBackground))
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
                .font(.inter(size: 34, weight: .semibold))
                .foregroundColor(.secondary)

            Text(title)
                .font(.inter(.headline))
                .foregroundColor(.primary)

            Text(subtitle)
                .font(.inter(.subheadline))
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
               
                Text("Argon F7 News")
                    .font(.inter(size: 45, weight: .black, design: .rounded))
                    .foregroundColor(.primary)
            }

            Text(Self.headerDateFormatter.string(from: Date()))
                .font(.inter(size: 48, weight: .black, design: .rounded))
                .foregroundColor(.secondary)
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
                            .font(.inter(size: 5))
                        Text(topic)
                            .font(.inter(.subheadline, design: .rounded, weight: .semibold))
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color(.tertiarySystemFill))
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
                            .font(.inter(.caption, design: .rounded, weight: .bold))
                            .foregroundColor(.white.opacity(0.95))
                        Text(publishedAtText)
                            .font(.inter(.caption, design: .rounded, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(10)
                }

            VStack(alignment: .leading, spacing: 8) {
                Text(item.title)
                    .font(.inter(.title3, design: .rounded, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(3)

                if let summary = item.summary, !summary.isEmpty {
                    Text(summary)
                        .font(.inter(.subheadline))
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }
            }
            .padding(14)
            .background(Color(.secondarySystemBackground))
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
                    .font(.inter(.caption, design: .rounded, weight: .semibold))
                    .foregroundColor(.secondary)

                Text(item.title)
                    .font(.inter(.headline, design: .rounded, weight: .semibold))
                    .foregroundColor(.primary)
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
            colors: [Color(.systemGray4), Color(.systemGray5), Color(.systemGray6)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

private struct NewsDetailView: View {
    let item: F1NewsItem

    @State private var articleText: String?
    @State private var isLoadingArticle = false
    @State private var articleError: String?

    private static let detailDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                RemoteNewsImage(url: item.imageURL)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Text(item.title)
                    .font(.inter(.title2, design: .rounded, weight: .bold))
                    .foregroundColor(.primary)

                HStack(spacing: 8) {
                    Text(item.source)
                        .font(.inter(.caption))
                        .foregroundColor(.appAccent)

                    if let date = item.publishedAt {
                        Text("• \(Self.detailDateFormatter.string(from: date))")
                            .font(.inter(.caption))
                            .foregroundColor(.secondary)
                    }
                }

                if let summary = item.summary, !summary.isEmpty {
                    Text(summary)
                        .font(.inter(.body))
                        .foregroundColor(.primary)
                }

                Divider()
                    .overlay(Color(.separator))

                Group {
                    if isLoadingArticle {
                        ProgressView("Loading full article...")
                            .tint(.appAccent)
                    } else if let articleText, !articleText.isEmpty {
                        Text(articleText)
                            .font(.inter(.body, design: .default, weight: .regular))
                            .foregroundColor(.primary)
                            .lineSpacing(7)
                            .textSelection(.enabled)
                    } else if let articleError {
                        Text(articleError)
                            .font(.inter(.subheadline))
                            .foregroundColor(.secondary)
                    }
                }

                Link(destination: item.link) {
                    Label("Open original source", systemImage: "arrow.up.right.square")
                        .font(.inter(.footnote))
                }
                .foregroundColor(.secondary)
                .padding(.top, 6)
            }
            .padding(16)
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .navigationTitle("News")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: item.id) {
            await loadFullArticle()
        }
    }

    private func loadFullArticle() async {
        guard !isLoadingArticle else { return }
        isLoadingArticle = true
        articleError = nil

        do {
            let (data, response) = try await URLSession.shared.data(from: item.link)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                throw AuthError.invalidResponse
            }

            guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .unicode) else {
                throw AuthError.invalidResponse
            }

            let extracted = ArticleContentExtractor.extractText(fromHTML: html)
            if extracted.isEmpty {
                articleText = item.summary ?? "No readable article body found for this source."
            } else {
                articleText = extracted
            }
        } catch {
            articleError = "Could not load full article text."
            articleText = item.summary
        }

        isLoadingArticle = false
    }
}

private enum ArticleContentExtractor {
    static func extractText(fromHTML html: String) -> String {
        let source = mainSection(from: html)

        if let paragraphRegex = try? NSRegularExpression(pattern: "<p[^>]*>(.*?)</p>", options: [.caseInsensitive, .dotMatchesLineSeparators]) {
            let range = NSRange(source.startIndex..<source.endIndex, in: source)
            let paragraphs = paragraphRegex.matches(in: source, options: [], range: range).compactMap { match -> String? in
                guard let bodyRange = Range(match.range(at: 1), in: source) else {
                    return nil
                }

                let raw = String(source[bodyRange])
                let clean = decodeEntities(stripTags(raw)).trimmingCharacters(in: .whitespacesAndNewlines)
                return clean.count >= 50 ? clean : nil
            }

            let joined = paragraphs.prefix(30).joined(separator: "\n\n")
            if !joined.isEmpty {
                return joined
            }
        }

        let fallback = decodeEntities(stripTags(source))
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if fallback.count > 6000 {
            let index = fallback.index(fallback.startIndex, offsetBy: 6000)
            return String(fallback[..<index]) + "..."
        }

        return fallback
    }

    private static func mainSection(from html: String) -> String {
        let withoutScripts = html
            .replacingOccurrences(of: "<script[\\s\\S]*?</script>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "<style[\\s\\S]*?</style>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "<noscript[\\s\\S]*?</noscript>", with: "", options: .regularExpression)

        let patterns = [
            "<article[^>]*>([\\s\\S]*?)</article>",
            "<main[^>]*>([\\s\\S]*?)</main>",
            "<body[^>]*>([\\s\\S]*?)</body>"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               let match = regex.firstMatch(in: withoutScripts, options: [], range: NSRange(withoutScripts.startIndex..<withoutScripts.endIndex, in: withoutScripts)),
               let range = Range(match.range(at: 1), in: withoutScripts) {
                return String(withoutScripts[range])
            }
        }

        return withoutScripts
    }

    private static func stripTags(_ input: String) -> String {
        input.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
    }

    private static func decodeEntities(_ input: String) -> String {
        input
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
    }
}
