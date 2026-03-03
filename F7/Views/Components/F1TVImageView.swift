import SwiftUI
import WebKit

// MARK: - Shared image loader

/// Singleton that fetches F1TV images using cookies from the default WKWebsiteDataStore.
///
/// `ott-img.formula1.com` blocks direct requests (CloudFront WAF / Imperva reese84).
/// After the user logs in through WKWebView the default data store holds the needed cookies.
/// This loader reuses a single hidden WKWebView for all fetches and keeps an NSCache.
@MainActor
final class F1TVImageLoader {
    static let shared = F1TVImageLoader()

    private static let imageCDNBase = "https://ott-img.formula1.com/"
    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 200
    }

    /// Builds the full CDN URL for a raw `pictureUrl` from the API.
    func imageURL(for pictureUrl: String, width: CGFloat, height: CGFloat) -> URL? {
        let stripped = pictureUrl.hasPrefix("/") ? String(pictureUrl.dropFirst()) : pictureUrl
        let urlString = "\(Self.imageCDNBase)image-resizer/image/\(stripped)?w=\(Int(width * 2))&h=\(Int(height * 2))&q=HI&o=L"
        return URL(string: urlString)
    }

    /// Main entry point — returns a cached UIImage or fetches it natively with synced cookies.
    func loadImage(pictureUrl: String, width: CGFloat, height: CGFloat) async -> UIImage? {
        let cacheKey = pictureUrl as NSString
        if let cached = cache.object(forKey: cacheKey) {
            return cached
        }

        guard let url = imageURL(for: pictureUrl, width: width, height: height) else { return nil }

        // Fetch WKWebsiteDataStore cookies and inject them into a native URLSession request.
        let cookies = await withCheckedContinuation { continuation in
            WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
                continuation.resume(returning: cookies)
            }
        }
        
        if let image = await downloadWithURLSession(url: url, cookies: cookies) {
            cache.setObject(image, forKey: cacheKey)
            return image
        }

        return nil
    }

    // MARK: - URLSession

    private func downloadWithURLSession(url: URL, cookies: [HTTPCookie]) async -> UIImage? {
        var request = URLRequest(url: url)
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("https://f1tv.formula1.com/", forHTTPHeaderField: "Referer")
        request.setValue("image/webp,image/*,*/*;q=0.8", forHTTPHeaderField: "Accept")

        // Explictly inject the cookies into the HTTP Header of the request natively
        if !cookies.isEmpty {
            let cookieHeaders = HTTPCookie.requestHeaderFields(with: cookies)
            if let cookieValue = cookieHeaders["Cookie"] {
                request.setValue(cookieValue, forHTTPHeaderField: "Cookie")
            }
        }

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let image = UIImage(data: data) else {
            let status = (try? await URLSession.shared.data(for: request).1 as? HTTPURLResponse)?.statusCode ?? 0
            print("[F1TVImageLoader] Image fetch failed natively for \(url.lastPathComponent) (Status: \(status))")
            return nil
        }
        return image
    }
}

// MARK: - SwiftUI View

/// Displays an F1TV image, handling the WAF-protected CDN transparently.
struct F1TVImageView: View {
    let pictureUrl: String
    let width: CGFloat
    let height: CGFloat

    @State private var loadedImage: UIImage?
    @State private var hasFailed = false

    var body: some View {
        Group {
            if let image = loadedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if hasFailed {
                placeholder
            } else {
                placeholder
                    .overlay {
                        ProgressView()
                            .tint(.gray)
                    }
            }
        }
        .task(id: pictureUrl) {
            if let image = await F1TVImageLoader.shared.loadImage(
                pictureUrl: pictureUrl,
                width: width,
                height: height
            ) {
                loadedImage = image
            } else {
                hasFailed = true
            }
        }
    }

    private var placeholder: some View {
        ZStack {
            Color(white: 0.12)
            Image(systemName: "play.rectangle.fill")
                .font(.title2)
                .foregroundColor(Color(white: 0.25))
        }
    }
}
