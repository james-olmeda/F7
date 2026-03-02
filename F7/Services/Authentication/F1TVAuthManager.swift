import Foundation
import WebKit

/// A headless authentication manager designed to silently bypass Incapsula/Imperva anti-bot screens.
/// It utilizes a hidden WKWebView to evaluate the required biometric checks and extract the `reese84` cookie.
public final class F1TVAuthManager: NSObject, WKNavigationDelegate {
    
    private var hiddenWebView: WKWebView!
    private let targetAuthURL = URL(string: "https://account.formula1.com/#/en/login")! // Typical redirect URL
    
    // Closures for callback reporting
    public var onCookieExtracted: ((String) -> Void)?
    public var onAuthFailed: ((Error) -> Void)?
    
    public override init() {
        super.init()
        setupHeadlessWebView()
    }
    
    private func setupHeadlessWebView() {
        // Instantiate a web view configuration that attempts to emulate a normal mobile browser
        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.nonPersistent() // Ensuring a clean state for testing
        
        self.hiddenWebView = WKWebView(frame: .zero, configuration: config)
        self.hiddenWebView.navigationDelegate = self
        // By NOT adding `hiddenWebView` to any active View hierarchy, it remains headless and invisible.
        
        // Setting a standard User-Agent so Incapsula doesn't instantly block it as an unusual headless client
        self.hiddenWebView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
    }
    
    /// Starts the silent sequence to negotiate the anti-bot challenge and extract the session cookie.
    public func initiateHeadlessAuthentication() {
        print("[F1TVAuthManager] Commencing headless anti-bot interception flow...")
        let request = URLRequest(url: targetAuthURL)
        hiddenWebView.load(request)
    }
    
    // MARK: - WKNavigationDelegate
    
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("[F1TVAuthManager] Headless WebView finished loading DOM. Analysing Cookies...")
        
        // Once the page loads, Incapsula scripts run and generate the cookie.
        // We delay slightly to allow JS execution of the biometric challenge.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.extractReese84Cookie()
        }
    }
    
    private func extractReese84Cookie() {
        hiddenWebView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
            if let reeseCookie = cookies.first(where: { $0.name == "reese84" }) {
                print("[F1TVAuthManager] SUCCESS: Extracted Incapsula boundary cookie 'reese84'.")
                // Pass it upward to the network layers for the absolute Okta JWT exchange
                self?.onCookieExtracted?(reeseCookie.value)
            } else {
                print("[F1TVAuthManager] FAILURE: 'reese84' cookie not found. Anti-bot logic may require interactive touch events.")
                // To solve this, we would use Javascript injection via `evaluateJavaScript` 
                // to trigger synthetic click events on the hidden DOM.
            }
        }
    }
}
