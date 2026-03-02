import Foundation

/// Interceptor that attaches the proprietary X-F1-Cookie-Data header
/// to all outgoing requests directed to the Fantasy F1 API (`partner_games/f1`).
public final class FantasyNetworkInterceptor {
    
    // The extracted encrypted cookie from the initial two-step auth phase.
    // In production, this must be retrieved securely from the iOS Keychain.
    private var xF1CookieData: String?
    
    public init() {
        print("[FantasyNetworkInterceptor] Initialized.")
    }
    
    /// Updates the interceptor with a newly minted or retrieved cookie string.
    public func updateCookieData(_ cookie: String) {
        self.xF1CookieData = cookie
        print("[FantasyNetworkInterceptor] Valid X-F1-Cookie-Data injected into memory.")
    }
    
    /// Mutates the outgoing URLRequest if it targets the Fantasy F1 domain.
    /// - Parameter request: The original outbound request.
    /// - Returns: The intercepted and structurally modified request.
    public func intercept(request: URLRequest) -> URLRequest {
        guard let url = request.url,
              url.absoluteString.contains("fantasy-api.formula1.com/partner_games/f1") else {
            return request
        }
        
        var interceptedRequest = request
        
        if let cookie = xF1CookieData {
            interceptedRequest.setValue(cookie, forHTTPHeaderField: "X-F1-Cookie-Data")
            // Apply standard JSON headers
            interceptedRequest.setValue("application/json", forHTTPHeaderField: "Accept")
            interceptedRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            // Note: If required by future anti-bot versions, we might need to inject fake User-Agents here too.
        } else {
            print("[FantasyNetworkInterceptor] WARNING: Attempting to call Fantasy API without a valid X-F1-Cookie-Data header. Call will likely fail with 401 Unauthorized.")
        }
        
        return interceptedRequest
    }
}
