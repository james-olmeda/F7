import Foundation
import WebKit

/// A hidden WebView dedicated to intercepting the HLS stream URL from the F1TV website.
/// By loading the official player page, we let WebKit solve all CloudFront WAF challenges naturally.
@MainActor
public final class F1TVStreamExtractor: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
    
    private let webView: WKWebView
    private var activeContinuation: CheckedContinuation<F1TVStreamEntitlement, Error>?
    private var currentContentId: String?
    private var timeoutTask: Task<Void, Never>?
    
    public override init() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default() // Use the same cookies as the AuthManager
        
        // Sometimes the WebKit process wants an arbitrary frame size or it suspends JS timers.
        self.webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1024, height: 768), configuration: config)
        
        super.init()
        
        self.webView.navigationDelegate = self
        // Standard Desktop viewport user agent ensures it doesn't trigger mobile degraded layouts
        self.webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36"
    }
    
    /// Loads the F1TV detail page for the given content and waits for the JS interceptor to catch the stream URL.
    public func extractEntitlement(contentId: String) async throws -> F1TVStreamEntitlement {
        // If an extraction is already running, cancel it
        if let cont = activeContinuation {
            cont.resume(throwing: AuthError.unknownResponse(statusCode: -1))
            activeContinuation = nil
        }
        
        self.currentContentId = contentId
        let pageUrl = URL(string: "https://f1tv.formula1.com/detail/\(contentId)")!
        
        print("[F1TVStreamExtractor] Instructing hidden WebView to load: \(pageUrl.absoluteString)")
        
        return try await withCheckedThrowingContinuation { continuation in
            self.activeContinuation = continuation
            
            // Set a 15-second timeout safeguard
            self.timeoutTask?.cancel()
            self.timeoutTask = Task {
                try? await Task.sleep(nanoseconds: 15_000_000_000)
                if !Task.isCancelled {
                    self.finishExtraction(error: AuthError.invalidResponse)
                }
            }
            
            self.webView.load(URLRequest(url: pageUrl))
        }
    }
    
    // MARK: - Navigation Delegate
    
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let contentId = currentContentId else { return }
        print("[F1TVStreamExtractor] Page loaded. Injecting active fetch command for \(contentId)...")
        
        let js = """
        const targetUrl = "https://f1tv.formula1.com/1.0/R/ENG/WEB_HLS/ALL/CONTENT/PLAY/\(contentId)/2";
        const response = await fetch(targetUrl, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({})
        });
        if (!response.ok) throw new Error('HTTP ' + response.status);
        const json = await response.json();
        
        let streamUrl = json.resultObj?.url 
            || (json.resultObj?.containers?.[0]?.bundle?.streams?.[0]?.playbackUrl)
            || (json.resultObj?.containers?.[0]?.bundle?.streams?.[0]?.streamUrl);
            
        let entitlementToken = json.resultObj?.entitlementToken || "";
        
        if (!streamUrl) throw new Error('No stream URL located in JSON');
        
        return { streamUrl, entitlementToken };
        """
        
        Task { @MainActor in
            // Give the browser 2 seconds for JS challenges (like Imperva) to finish settling
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            
            do {
                let result = try await webView.callAsyncJavaScript(
                    js,
                    arguments: [:],
                    in: nil,
                    contentWorld: .page
                )
                
                if let dict = result as? [String: Any],
                   let streamUrlString = dict["streamUrl"] as? String,
                   let streamUrl = URL(string: streamUrlString) {
                    
                    let token = dict["entitlementToken"] as? String ?? ""
                    print("[F1TVStreamExtractor] Successfully actively extracted stream URL!")
                    let entitlement = F1TVStreamEntitlement(streamURL: streamUrl, entitlementToken: token, contentId: contentId)
                    self.finishExtraction(entitlement: entitlement)
                } else {
                    self.finishExtraction(error: AuthError.invalidResponse)
                }
            } catch {
                print("[F1TVStreamExtractor] Active extraction returned error: \(error.localizedDescription)")
                self.finishExtraction(error: error)
            }
        }
    }
    
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("[F1TVStreamExtractor] WebView load failed: \(error.localizedDescription)")
        finishExtraction(error: error)
    }
    
    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("[F1TVStreamExtractor] Provisional load failed: \(error.localizedDescription)")
        finishExtraction(error: error)
    }
    
    // MARK: - Cleanup
    
    private func finishExtraction(entitlement: F1TVStreamEntitlement? = nil, error: Error? = nil) {
        self.timeoutTask?.cancel()
        
        // Halt any further loading/scripts in the invisible webview
        self.webView.stopLoading()
        self.webView.evaluateJavaScript("document.body.innerHTML = '';", completionHandler: nil)
        
        if let ent = entitlement {
            activeContinuation?.resume(returning: ent)
        } else if let err = error {
            activeContinuation?.resume(throwing: err)
        }
        
        activeContinuation = nil
        currentContentId = nil
    }
}
