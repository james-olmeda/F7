import Foundation

/// Manages authentication state for the UI.
@Observable
public final class AuthViewModel {
    
    /// Whether the user is currently authenticated.
    public var isAuthenticated: Bool = false
    
    /// Whether an authentication request is in progress.
    public var isLoading: Bool = false
    
    /// Error message to display to the user.
    public var errorMessage: String?
    
    /// The current active session, if authenticated.
    public var currentSession: AuthSession?
    
    private let authenticator: F1TVAPIAuthenticator
    
    public init(authenticator: F1TVAPIAuthenticator = F1TVAPIAuthenticator()) {
        self.authenticator = authenticator
        restoreSavedSession()
    }
    
    /// Authenticates with F1TV using email and password.
    public func login(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let session = try await authenticator.authenticate(email: email, password: password)
            currentSession = session
            isAuthenticated = true
            print("[AuthViewModel] Login successful.")
        } catch let error as AuthError {
            errorMessage = error.errorDescription
            print("[AuthViewModel] Login failed: \(error.errorDescription ?? "unknown")")
        } catch {
            errorMessage = error.localizedDescription
            print("[AuthViewModel] Login failed: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    /// Authenticates using a token extracted from the WebView login flow.
    /// Creates a session from the raw token and persists it.
    public func loginWithToken(_ token: String, cookieHeader: String? = nil, subscriberId: String = "", country: String = "US") {
        isLoading = true
        errorMessage = nil
        
        let session = AuthSession(
            subscriberToken: token,
            sessionId: UUID().uuidString,
            expiresAt: Date().addingTimeInterval(24 * 60 * 60),
            subscriberId: subscriberId.isEmpty ? "subscriber" : subscriberId,
            country: country,
            webCookieHeader: cookieHeader
        )
        
        authenticator.saveSession(session)
        currentSession = session
        isAuthenticated = true
        isLoading = false
        print("[AuthViewModel] Login via WebView successful. Token length: \(token.count), subscriber: \(session.subscriberId)")
    }
    
    /// Logs out the user and clears the saved session.
    public func logout() {
        authenticator.clearSession()
        currentSession = nil
        isAuthenticated = false
        errorMessage = nil
        print("[AuthViewModel] User logged out.")
    }
    
    /// Attempts to restore a previously saved session from the Keychain.
    private func restoreSavedSession() {
        if let session = authenticator.loadSavedSession(), !session.isExpired {
            // Validate the token is real (not a previous bad extraction)
            if session.subscriberToken.count < 30 || session.subscriberId == "weblogin" {
                print("[AuthViewModel] Clearing invalid cached session.")
                authenticator.clearSession()
                return
            }

            // WebView-derived sessions require cookie context for entitlement calls.
            if session.subscriberId == "subscriber" && (session.webCookieHeader?.isEmpty != false) {
                print("[AuthViewModel] Clearing stale cached web session without cookies.")
                authenticator.clearSession()
                return
            }

            // A very long web-login token is usually a raw login-session cookie, not a playback entitlement token.
            if session.subscriberId == "subscriber" && session.subscriberToken.count > 1500 {
                print("[AuthViewModel] Clearing stale cached web session with raw login-session token.")
                authenticator.clearSession()
                return
            }

            currentSession = session
            isAuthenticated = true
            print("[AuthViewModel] Session restored from Keychain. Token length: \(session.subscriberToken.count)")
        }
    }
}
