import Foundation

/// Represents an active F1TV authenticated session including tokens and expiry metadata.
public struct AuthSession: Codable {
    /// The subscriber token used as Bearer authorization for F1TV API requests.
    public let subscriberToken: String
    
    /// The session identifier from the F1 auth response.
    public let sessionId: String
    
    /// When this session expires.
    public let expiresAt: Date
    
    /// The subscriber's unique identifier.
    public let subscriberId: String
    
    /// The subscriber's country code (affects content availability).
    public let country: String

    /// Raw Formula1 web cookies captured during WebView login.
    /// Required by some F1TV endpoints that validate cookie-bound sessions.
    public let webCookieHeader: String?
    
    /// Whether the session has expired.
    public var isExpired: Bool {
        Date() >= expiresAt
    }
}
