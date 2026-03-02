import Foundation

/// Contains the stream URL and DRM entitlement token needed to play F1TV content.
public struct F1TVStreamEntitlement: Codable {
    /// The HLS manifest URL (.m3u8) for the stream.
    public let streamURL: URL
    
    /// Bearer token for FairPlay DRM key server authorization.
    public let entitlementToken: String
    
    /// The content ID this entitlement is for.
    public let contentId: String
}
