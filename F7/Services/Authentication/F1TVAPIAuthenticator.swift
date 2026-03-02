import Foundation
import Security

/// Performs direct API-based authentication against the F1TV subscriber endpoint.
/// Handles Keychain storage of tokens and session refresh logic.
public final class F1TVAPIAuthenticator {
    
    private let authEndpoint = URL(string: "https://api.formula1.com/v2/account/subscriber/authenticate/by-password")!
    
    // Known public API key used by the F1 web client
    private let apiKey = "fCUCjWrKPu9ylJwRAv8BpGLEgiAuThx7"
    
    private static let keychainService = "com.argonF7.f1tv.session"
    private static let keychainAccount = "subscriberSession"
    
    public init() {
        print("[F1TVAPIAuthenticator] Initialized.")
    }
    
    // MARK: - Public API
    
    /// Authenticates with F1TV using email and password via direct API call.
    /// Note: This may fail with 403 due to Imperva anti-bot protection.
    /// The preferred auth flow uses the visible WebView login (see F1TVAuthManager).
    public func authenticate(email: String, password: String) async throws -> AuthSession {
        print("[F1TVAPIAuthenticator] Authenticating with F1TV API...")
        
        var request = URLRequest(url: authEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        
        let body: [String: String] = [
            "Login": email,
            "Password": password
        ]
        request.httpBody = try JSONEncoder().encode(body)
        
        print("[F1TVAPIAuthenticator] Attempting authentication for: \(email)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkFailure(underlying: URLError(.badServerResponse))
        }
        
        // Log response for debugging
        let rawBody = String(data: data, encoding: .utf8) ?? "unable to decode"
        print("[F1TVAPIAuthenticator] Auth response status: \(httpResponse.statusCode)")
        print("[F1TVAPIAuthenticator] Raw response body: \(rawBody.prefix(2000))")
        
        switch httpResponse.statusCode {
        case 200...299:
            let session = try parseAuthResponse(data)
            try saveToKeychain(session)
            print("[F1TVAPIAuthenticator] Authentication successful. Subscriber: \(session.subscriberId)")
            return session
        case 401:
            throw AuthError.invalidCredentials
        case 403:
            // Check if it's still anti-bot (HTML response) vs actual auth rejection
            if rawBody.contains("Pardon Our Interruption") || rawBody.contains("<html") {
                print("[F1TVAPIAuthenticator] Still blocked by anti-bot after cookie injection.")
                throw AuthError.networkFailure(underlying: URLError(.userAuthenticationRequired))
            }
            throw AuthError.invalidCredentials
        default:
            throw AuthError.unknownResponse(statusCode: httpResponse.statusCode)
        }
    }
    
    /// Attempts to load a previously saved session from the Keychain.
    public func loadSavedSession() -> AuthSession? {
        guard let data = KeychainHelper.load(
            service: Self.keychainService,
            account: Self.keychainAccount
        ) else {
            print("[F1TVAPIAuthenticator] No saved session found in Keychain.")
            return nil
        }
        
        do {
            let session = try JSONDecoder().decode(AuthSession.self, from: data)
            if session.isExpired {
                print("[F1TVAPIAuthenticator] Saved session is expired. Clearing.")
                clearSession()
                return nil
            }
            print("[F1TVAPIAuthenticator] Restored session from Keychain. Subscriber: \(session.subscriberId)")
            return session
        } catch {
            print("[F1TVAPIAuthenticator] Failed to decode saved session: \(error)")
            clearSession()
            return nil
        }
    }
    
    /// Clears the saved session from the Keychain (logout).
    public func clearSession() {
        KeychainHelper.delete(
            service: Self.keychainService,
            account: Self.keychainAccount
        )
        print("[F1TVAPIAuthenticator] Session cleared from Keychain.")
    }
    
    // MARK: - Session Persistence
    
    /// Saves a session to the Keychain. Used by AuthViewModel for WebView-based login.
    public func saveSession(_ session: AuthSession) {
        do {
            let data = try JSONEncoder().encode(session)
            try KeychainHelper.save(
                data: data,
                service: Self.keychainService,
                account: Self.keychainAccount
            )
            print("[F1TVAPIAuthenticator] Session saved to Keychain.")
        } catch {
            print("[F1TVAPIAuthenticator] Failed to save session: \(error)")
        }
    }
    
    private func saveToKeychain(_ session: AuthSession) throws {
        let data = try JSONEncoder().encode(session)
        try KeychainHelper.save(
            data: data,
            service: Self.keychainService,
            account: Self.keychainAccount
        )
    }
    
    /// Parses the F1 API auth response into an AuthSession.
    /// Handles multiple known response structures from the F1 API.
    private func parseAuthResponse(_ data: Data) throws -> AuthSession {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AuthError.invalidResponse
        }
        
        print("[F1TVAPIAuthenticator] Parsing response keys: \(json.keys.sorted())")
        
        // The F1 API may nest data under "data", or return flat
        let responseData = json["data"] as? [String: Any] ?? json
        
        if let nestedData = responseData["data"] as? [String: Any] {
            // Double-nested: { "data": { "data": { ... } } }
            return try extractSession(from: nestedData)
        }
        
        return try extractSession(from: responseData)
    }
    
    private func extractSession(from dict: [String: Any]) throws -> AuthSession {
        print("[F1TVAPIAuthenticator] Extracting session from keys: \(dict.keys.sorted())")
        
        // Try multiple known key names for the subscription token
        let tokenKeys = ["subscriptionToken", "SubscriptionToken", "token", "Token", "SessionToken"]
        var subscriberToken: String?
        for key in tokenKeys {
            if let value = dict[key] as? String, !value.isEmpty {
                subscriberToken = value
                print("[F1TVAPIAuthenticator] Found token with key: \(key)")
                break
            }
        }
        
        guard let token = subscriberToken else {
            // Check subscription status for better error
            let status = dict["subscriptionStatus"] as? String
                ?? dict["SubscriptionStatus"] as? String
                ?? ""
            print("[F1TVAPIAuthenticator] No token found. Subscription status: \(status)")
            
            if !status.isEmpty && status.lowercased() != "active" {
                throw AuthError.noActiveSubscription
            }
            throw AuthError.invalidResponse
        }
        
        let sessionId = dict["SessionId"] as? String
            ?? dict["sessionId"] as? String
            ?? UUID().uuidString
        
        // Try various subscriber ID keys
        let subscriberId: String = {
            if let id = dict["Subscriber"] as? [String: Any], let sub = id["Id"] as? String { return sub }
            if let id = dict["Subscriber"] as? String { return id }
            if let id = dict["subscriberId"] as? String { return id }
            if let id = dict["SubscriberId"] as? String { return id }
            return "subscriber"
        }()
        
        let country = dict["Country"] as? String
            ?? dict["country"] as? String
            ?? "US"
        
        let expiresAt = Date().addingTimeInterval(24 * 60 * 60)
        
        return AuthSession(
            subscriberToken: token,
            sessionId: sessionId,
            expiresAt: expiresAt,
            subscriberId: subscriberId,
            country: country,
            webCookieHeader: nil
        )
    }
}
