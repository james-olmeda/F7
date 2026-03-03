import SwiftUI

public struct F1NewsView: View {
    @Environment(F1NewsViewModel.self) private var newsVM

    public var body: some View {
        @Bindable var vm = newsVM

        VStack(spacing: 0) {
            if vm.isLoading && vm.newsItems.isEmpty {
                Spacer()
                ProgressView("Loading latest F1 news...")
                Spacer()
            } else if let error = vm.errorMessage, vm.newsItems.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "newspaper.fill")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task { await vm.loadLatestNews() }
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, 24)
                Spacer()
            } else if vm.newsItems.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "newspaper")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No latest news available")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                List(vm.newsItems) { item in
                    Link(destination: item.link) {
                        F1NewsRowView(item: item)
                    }
                    .listRowBackground(Color(white: 0.1))
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.black)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Latest News")
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
}

private struct F1NewsRowView: View {
    let item: F1NewsItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.title)
                .font(.system(.headline, design: .default, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(3)

            if let summary = item.summary, !summary.isEmpty {
                Text(summary)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }

            HStack(spacing: 8) {
                Text(item.source)
                    .font(.caption)
                    .foregroundColor(.red)

                Spacer()

                if let publishedAt = item.publishedAt {
                    Text(relativeDateString(from: publishedAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private func relativeDateString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
