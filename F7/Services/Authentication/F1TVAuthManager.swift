import Foundation
import WebKit
import Combine
import SwiftUI

/// Manages F1TV authentication via an in-app WKWebView.
/// The user logs in through the real F1 website, bypassing anti-bot naturally,
/// then we extract cookies and use native URLSession to call F1TV API for the subscription token.
@MainActor
public final class F1TVAuthManager: NSObject, ObservableObject, WKNavigationDelegate {
    // ObservableObject conformance requires Combine import
    
    private let loginURL = URL(string: "https://account.formula1.com/#/en/login")!
    private let f1tvBootstrapURL = URL(string: "https://f1tv.formula1.com/")!
    
    /// The WKWebView instance — exposed so SwiftUI can embed it.
    public var webView: WKWebView!
    
    /// Called when authentication succeeds with a token and cookie header.
    public var onTokenExtracted: ((String, String?) -> Void)?
    
    /// Called if something fails.
    public var onError: ((String) -> Void)?
    
    private var tokenCheckTimer: Timer?
    private var hasExtractedToken = false
    private var hasTriggeredF1TVBootstrap = false
    
    public override init() {
        super.init()
        setupWebView()
    }
    
    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        
        self.webView = WKWebView(frame: .zero, configuration: config)
        self.webView.navigationDelegate = self
        self.webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
    }
    
    /// Loads the F1 login page in the WebView.
    public func loadLoginPage() {
        hasExtractedToken = false
        hasTriggeredF1TVBootstrap = false
        print("[F1TVAuthManager] Loading F1 login page...")
        webView.load(URLRequest(url: loginURL))
    }
    
    // MARK: - WKNavigationDelegate
    
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let currentURL = webView.url?.absoluteString ?? ""
        print("[F1TVAuthManager] Page loaded: \(currentURL.prefix(120))")
        startTokenPolling()
    }
    
    // MARK: - Token Extraction
    
    private func startTokenPolling() {
        tokenCheckTimer?.invalidate()
        tokenCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkForLoginViaCookies()
            }
        }
    }
    
    /// Checks WKWebView cookies for login session indicators.
    /// When found, extracts ALL cookies and uses them with native URLSession to call the F1TV API.
    private func checkForLoginViaCookies() {
        guard !hasExtractedToken else { return }
        
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
            guard let self = self, !self.hasExtractedToken else { return }
            
            let f1Cookies = cookies.filter { $0.domain.contains("formula1.com") || $0.domain.contains("f1tv") }
            let cookieNames = f1Cookies.map { $0.name }
            
            // Check for login indicators
            let hasLoginSession = f1Cookies.contains { $0.name == "login-session" }
            let hasSubscriber = f1Cookies.contains { $0.name == "subscriber" }
            let hasReese84 = cookies.contains { $0.name == "reese84" }
            
            // Force one SSO bootstrap hop into f1tv domain before token extraction.
            if hasLoginSession && !hasSubscriber && !self.hasTriggeredF1TVBootstrap {
                self.hasTriggeredF1TVBootstrap = true
                print("[F1TVAuthManager] Login-session detected without subscriber cookie. Bootstrapping F1TV SSO...")
                self.webView.load(URLRequest(url: self.f1tvBootstrapURL))
                return
            }

            if hasLoginSession || hasSubscriber {
                print("[F1TVAuthManager] Login detected! Cookies: \(cookieNames)")
                print("[F1TVAuthManager] Has reese84: \(hasReese84)")
                
                // Extract all cookies and call F1TV API natively (no CORS)
                self.tokenCheckTimer?.invalidate()
                
                Task {
                    await self.fetchSubscriptionTokenNatively(cookies: cookies)
                }
            }
        }
    }
    
    /// Calls the F1TV API using native URLSession with cookies extracted from the WebView.
    /// URLSession is not subject to CORS, so cross-origin requests work fine.
    private func fetchSubscriptionTokenNatively(cookies: [HTTPCookie]) async {
        guard !hasExtractedToken else { return }
        
        // Build cookie header from ALL cookies (reese84 + session + everything)
        let cookieHeader = cookies
            .filter { $0.domain.contains("formula1.com") || $0.domain.contains("f1tv") }
            .map { "\($0.name)=\($0.value)" }
            .joined(separator: "; ")
        
        print("[F1TVAuthManager] Cookie header length: \(cookieHeader.count)")
        
        // Also inject cookies into the shared cookie storage for URLSession
        for cookie in cookies {
            HTTPCookieStorage.shared.setCookie(cookie)
        }
        
        // Try endpoint 1: F1TV API authenticate
        if let token = await tryF1TVAuthAPI(cookieHeader: cookieHeader) {
            print("[F1TVAuthManager] Got subscription token from F1TV API! (length: \(token.count))")
            hasExtractedToken = true
            onTokenExtracted?(token, cookieHeader)
            return
        }
        
        // Try endpoint 2: Legacy F1 API
        if let token = await tryLegacyAuthAPI(cookieHeader: cookieHeader) {
            print("[F1TVAuthManager] Got subscription token from legacy API! (length: \(token.count))")
            hasExtractedToken = true
            onTokenExtracted?(token, cookieHeader)
            return
        }
        
        // Try endpoint 3: F1TV entitlement for a known content ID to see if cookies alone work
        if let token = await tryEntitlementProbe(cookieHeader: cookieHeader) {
            print("[F1TVAuthManager] Got token via entitlement probe! (length: \(token.count))")
            hasExtractedToken = true
            onTokenExtracted?(token, cookieHeader)
            return
        }
        
        // If API-based extraction fails, prefer known auth cookies in descending quality.
        let subscriberCookie = cookies.first { $0.name == "subscriber" }
        if let subscriberValue = subscriberCookie?.value, !subscriberValue.isEmpty {
            print("[F1TVAuthManager] Using subscriber cookie as token (length: \(subscriberValue.count))")
            hasExtractedToken = true
            onTokenExtracted?(subscriberValue, cookieHeader)
            return
        }

        let mkTokenCookie = cookies.first { $0.name == "mk-token" }
        if let mkTokenValue = mkTokenCookie?.value, !mkTokenValue.isEmpty {
            print("[F1TVAuthManager] Using mk-token cookie as token (length: \(mkTokenValue.count))")
            hasExtractedToken = true
            onTokenExtracted?(mkTokenValue, cookieHeader)
            return
        }

        let entitlementTokenCookie = cookies.first { $0.name == "entitlement_token" }
        if let entitlementTokenValue = entitlementTokenCookie?.value, !entitlementTokenValue.isEmpty {
            print("[F1TVAuthManager] Using entitlement_token cookie as token (length: \(entitlementTokenValue.count))")
            hasExtractedToken = true
            onTokenExtracted?(entitlementTokenValue, cookieHeader)
            return
        }

        // Final fallback: login-session cookie value.
        let loginSessionCookie = cookies.first { $0.name == "login-session" }
        if let sessionValue = loginSessionCookie?.value, !sessionValue.isEmpty {
            print("[F1TVAuthManager] Using login-session cookie as token (length: \(sessionValue.count))")
            hasExtractedToken = true
            onTokenExtracted?(sessionValue, cookieHeader)
            return
        }
        
        print("[F1TVAuthManager] All token extraction methods failed. Restarting polling...")
        startTokenPolling()
    }
    
    // MARK: - API Calls
    
    private func tryF1TVAuthAPI(cookieHeader: String) async -> String? {
        guard let url = URL(string: "https://f1tv-api.formula1.com/agl/1.0/unk/en/all_devices/global/authenticate") else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("fCUCjWrKPu9ylJwRAv8BpGLEgiAuThx7", forHTTPHeaderField: "apikey")
        request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        request.httpBody = "{}".data(using: .utf8)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let body = String(data: data, encoding: .utf8) ?? ""
            print("[F1TVAuthManager] F1TV Auth API status: \(statusCode)")
            print("[F1TVAuthManager] F1TV Auth API body: \(body.prefix(500))")
            
            if statusCode == 200, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return json["subscriptionToken"] as? String
                    ?? json["token"] as? String
                    ?? (json["data"] as? [String: Any])?["subscriptionToken"] as? String
            }
        } catch {
            print("[F1TVAuthManager] F1TV Auth API error: \(error.localizedDescription)")
        }
        return nil
    }
    
    private func tryLegacyAuthAPI(cookieHeader: String) async -> String? {
        guard let url = URL(string: "https://api.formula1.com/v2/account/subscriber/authenticate/by-password") else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("fCUCjWrKPu9ylJwRAv8BpGLEgiAuThx7", forHTTPHeaderField: "apikey")
        request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let body = String(data: data, encoding: .utf8) ?? ""
            print("[F1TVAuthManager] Legacy API status: \(statusCode)")
            print("[F1TVAuthManager] Legacy API body: \(body.prefix(500))")
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let d = json["data"] as? [String: Any] ?? json
                return d["subscriptionToken"] as? String
                    ?? d["SubscriptionToken"] as? String
                    ?? d["SessionToken"] as? String
            }
        } catch {
            print("[F1TVAuthManager] Legacy API error: \(error.localizedDescription)")
        }
        return nil
    }
    
    /// Probes a content entitlement to see if cookies carry auth implicitly.
    private func tryEntitlementProbe(cookieHeader: String) async -> String? {
        guard let url = URL(string: "https://f1tv.formula1.com/1.0/R/ENG/WEB_HLS/ALL/CONTENT/PLAY/1000010507/2") else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            print("[F1TVAuthManager] Entitlement probe status: \(statusCode)")
            
            if statusCode == 200, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let resultObj = json["resultObj"] as? [String: Any],
               let entitlementToken = resultObj["entitlementToken"] as? String {
                return entitlementToken
            }
        } catch {
            print("[F1TVAuthManager] Entitlement probe error: \(error.localizedDescription)")
        }
        return nil
    }
    
    /// Stops monitoring and cleans up.
    public func cleanup() {
        tokenCheckTimer?.invalidate()
        tokenCheckTimer = nil
        hasTriggeredF1TVBootstrap = false
    }
    
    deinit {
        tokenCheckTimer?.invalidate()
    }
}
