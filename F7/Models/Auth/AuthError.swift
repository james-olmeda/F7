import Foundation

/// Typed errors for F1TV authentication failures.
public enum AuthError: Error, LocalizedError {
    case invalidCredentials
    case networkFailure(underlying: Error)
    case tokenExpired
    case noActiveSubscription
    case keychainWriteFailed
    case keychainReadFailed
    case invalidResponse
    case unknownResponse(statusCode: Int)
    
    public var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password."
        case .networkFailure(let error):
            return "Network error: \(error.localizedDescription)"
        case .tokenExpired:
            return "Session expired. Please log in again."
        case .noActiveSubscription:
            return "No active F1TV Pro subscription found."
        case .keychainWriteFailed:
            return "Failed to save credentials securely."
        case .keychainReadFailed:
            return "Failed to retrieve saved credentials."
        case .invalidResponse:
            return "Unexpected response from server."
        case .unknownResponse(let code):
            return "Unexpected response (HTTP \(code))."
        }
    }
}
