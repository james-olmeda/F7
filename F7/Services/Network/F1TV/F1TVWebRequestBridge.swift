import Foundation
import WebKit

@MainActor
public final class F1TVWebRequestBridge: NSObject, WKNavigationDelegate {
    public static let shared = F1TVWebRequestBridge()

    private let webView: WKWebView
    private var warmupContinuation: CheckedContinuation<Void, Error>?
    private var isWarm = false

    private override init() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()

        self.webView = WKWebView(frame: .zero, configuration: config)
        super.init()

        webView.navigationDelegate = self
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
    }

    public func warmupIfNeeded() async throws {
        if isWarm { return }

        guard let url = URL(string: "https://f1tv.formula1.com/") else {
            throw AuthError.invalidResponse
        }

        try await withCheckedThrowingContinuation { continuation in
            self.warmupContinuation = continuation
            self.webView.load(URLRequest(url: url))
        }
    }

    public func postJSON(urlString: String, body: String = "{}") async throws -> (statusCode: Int, body: String) {
        try await warmupIfNeeded()

        let script = """
        const response = await fetch(urlString, {
            method: 'POST',
            credentials: 'include',
            headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json, text/plain, */*'
            },
            body: body
        });

        const text = await response.text();
        return { statusCode: response.status, body: text };
        """

        let result = try await webView.callAsyncJavaScript(
            script,
            arguments: ["urlString": urlString, "body": body],
            in: nil,
            contentWorld: .defaultClient
        )

        guard let dictionary = result as? [String: Any],
              let statusCode = dictionary["statusCode"] as? Int,
              let bodyString = dictionary["body"] as? String else {
            throw AuthError.invalidResponse
        }

        return (statusCode, bodyString)
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isWarm = true
        warmupContinuation?.resume()
        warmupContinuation = nil
    }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        warmupContinuation?.resume(throwing: error)
        warmupContinuation = nil
    }

    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        warmupContinuation?.resume(throwing: error)
        warmupContinuation = nil
    }

}
