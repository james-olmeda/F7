import Foundation
import AVFoundation

/// Handles Apple FairPlay Streaming (FPS) encryption negotiations for the F1TV HLS video streams.
/// Acts as the delegate for `AVAssetResourceLoader` to intercept raw key requests from the stream manifesto.
public final class FairPlayDRMDelegate: NSObject, AVAssetResourceLoaderDelegate {

    // The Okta identity/entitlement token proving the user paid for F1TV Pro.
    private let entitlementToken: String
    
    // The F1 Key Server Module (KSM) endpoint.
    private let keyServerURL = URL(string: "https://f1tv.formula1.com/api/fps/key")!
    
    // The local certificate URL (often embedded in the stream or fetched prior)
    private let certificateURL = URL(string: "https://f1tv.formula1.com/api/fps/cert")!
    
    public init(entitlementToken: String) {
        self.entitlementToken = entitlementToken
        super.init()
        print("[FairPlayDRMDelegate] Initialized. Ready to intercept AVPlayer key requests.")
    }

    /// Invoked automatically by `AVPlayer` when encountering an `#EXT-X-KEY` tag demanding FPS decryption.
    public func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        
        guard let url = loadingRequest.request.url else { return false }
        print("[FairPlayDRMDelegate] AVPlayer intercepted DRM resource request for URI: \(url.absoluteString)")
        
        Task {
            do {
                // 1. Fetch the Application Certificate from the F1 Server.
                let certificateData = try await fetchFairPlayCertificate()
                
                // 2. Extract the Content ID (Asset ID) from the manifest's URL.
                guard let contentIdString = url.host, let contentIdData = contentIdString.data(using: .utf8) else {
                    loadingRequest.finishLoading(with: NSError(domain: "FairPlay", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid Content ID in URL"]))
                    return
                }
                
                // 3. Ask AVFoundation to generate the Server Playback Context (SPC).
                let spcData = try loadingRequest.streamingContentKeyRequestData(forApp: certificateData, contentIdentifier: contentIdData, options: nil)
                
                // 4. Send the SPC payload to the F1 Key Server, appending our entitlement JWT, to get the CKC.
                let ckcData = try await requestContentKeyContext(spcData: spcData, assetId: contentIdString)
                
                // 5. Provide the CKC back to the AVPlayer to unlock the video frames.
                loadingRequest.dataRequest?.respond(with: ckcData)
                loadingRequest.finishLoading()
                print("[FairPlayDRMDelegate] Successfully unlocked HLS stream cipher.")
                
            } catch {
                print("[FairPlayDRMDelegate] DRM handshake failed abruptly: \(error)")
                loadingRequest.finishLoading(with: error)
            }
        }
        
        return true
    }
    
    private func fetchFairPlayCertificate() async throws -> Data {
        let (data, _) = try await URLSession.shared.data(from: certificateURL)
        return data
    }
    
    private func requestContentKeyContext(spcData: Data, assetId: String) async throws -> Data {
        var request = URLRequest(url: keyServerURL)
        request.httpMethod = "POST"
        request.httpBody = spcData
        
        // Critical Authorization injection
        request.setValue("Bearer \(entitlementToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "FairPlay", code: -2, userInfo: [NSLocalizedDescriptionKey: "KSM rejected the SPC request."])
        }
        
        return data
    }
}
