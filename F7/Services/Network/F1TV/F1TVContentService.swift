import Foundation

/// Provides content discovery and stream entitlement for F1TV.
/// Fetches the content catalog and obtains HLS stream URLs with DRM tokens.
public final class F1TVContentService {
    
    // F1TV API endpoints
    private let contentBaseURL = "https://f1tv.formula1.com/2.0/R/ENG/WEB_HLS/ALL"
    private let entitlementURL = "https://f1tv.formula1.com/1.0/R/ENG/WEB_HLS/ALL"
    private let apiKey = "fCUCjWrKPu9ylJwRAv8BpGLEgiAuThx7"
    
    private let sessionProvider: () -> AuthSession?
    
    public init(sessionProvider: @escaping () -> AuthSession?) {
        self.sessionProvider = sessionProvider
        print("[F1TVContentService] Initialized.")
    }
    
    // MARK: - Content Catalog
    
    /// Fetches available content (live sessions + recent replays) from F1TV.
    public func fetchContentCatalog() async throws -> [F1TVContentItem] {
        // Page 395 is the main F1TV Pro content page
        let pageURL = URL(string: "\(contentBaseURL)/PAGE/395/F1_TV_Pro_Annual/2")!
        
        let request = authenticatedRequest(url: pageURL)
        
        print("[F1TVContentService] Fetching content catalog...")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            print("[F1TVContentService] Catalog fetch failed with status: \(statusCode)")
            throw AuthError.unknownResponse(statusCode: statusCode)
        }
        
        return try parseContentCatalog(data)
    }
    
    /// Fetches content for a specific event/session page.
    public func fetchEventContent(pageId: String) async throws -> [F1TVContentItem] {
        let pageURL = URL(string: "\(contentBaseURL)/PAGE/\(pageId)/F1_TV_Pro_Annual/2")!
        let request = authenticatedRequest(url: pageURL)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw AuthError.invalidResponse
        }
        
        return try parseContentCatalog(data)
    }
    
    // MARK: - Stream Entitlement
    
    /// Obtains the stream entitlement (HLS URL + DRM token) for a specific content item.
    public func fetchStreamEntitlement(contentId: String) async throws -> F1TVStreamEntitlement {
        let candidates = [
            "\(entitlementURL)/CONTENT/PLAY/\(contentId)/F1_TV_Pro_Annual/2",
            "\(entitlementURL)/CONTENT/PLAY/\(contentId)/2",
            "\(entitlementURL)/CONTENT/PLAY/\(contentId)"
        ]

        var lastStatusCode = 0
        var lastResponseBody = ""

        for endpoint in candidates {
            guard let url = URL(string: endpoint) else { continue }

            print("[F1TVContentService] Requesting stream entitlement for content: \(contentId) via \(endpoint)")

            // First attempt: native URLSession.
            do {
                var request = authenticatedRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = "{}".data(using: .utf8)

                let (data, response) = try await URLSession.shared.data(for: request)
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                let body = String(data: data, encoding: .utf8) ?? ""

                if statusCode == 200 {
                    return try parseStreamEntitlement(data, contentId: contentId)
                }

                lastStatusCode = statusCode
                lastResponseBody = body
                print("[F1TVContentService] Entitlement request failed with status: \(statusCode) at endpoint: \(endpoint)")
                print("[F1TVContentService] Entitlement error body: \(body.prefix(400))")
            } catch {
                print("[F1TVContentService] Native entitlement request error at endpoint \(endpoint): \(error.localizedDescription)")
            }

        }

        if lastStatusCode == 403 {
            if lastResponseBody.localizedCaseInsensitiveContains("subscription") ||
                lastResponseBody.localizedCaseInsensitiveContains("entitled") {
                throw AuthError.noActiveSubscription
            }
            throw AuthError.unknownResponse(statusCode: 403)
        }

        throw AuthError.unknownResponse(statusCode: lastStatusCode)
    }
    
    // MARK: - Private Helpers
    
    private func authenticatedRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        if let session = sessionProvider() {
            // F1TV uses 'ascendontoken' for API authentication.
            request.setValue(session.subscriberToken, forHTTPHeaderField: "ascendontoken")

            // Do not inject raw Cookie header from captured strings.
            // Let URLSession + HTTPCookieStorage apply domain/path-scoped cookies.
            let cookieCount = scopedCookies(for: url).count
            print("[F1TVContentService] Scoped cookies for \(url.host ?? "unknown"): \(cookieCount)")
        }
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("https://f1tv.formula1.com", forHTTPHeaderField: "Origin")
        request.setValue("https://f1tv.formula1.com/", forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        return request
    }

    private func scopedCookies(for url: URL) -> [HTTPCookie] {
        HTTPCookieStorage.shared.cookies(for: url) ?? []
    }
    
    /// Parses the deeply nested F1TV content API response.
    private func parseContentCatalog(_ data: Data) throws -> [F1TVContentItem] {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let resultObj = json["resultObj"] as? [String: Any],
              let containers = resultObj["containers"] as? [[String: Any]] else {
            print("[F1TVContentService] Failed to parse catalog root structure.")
            return []
        }
        
        var items: [F1TVContentItem] = []
        
        for container in containers {
            // Each container may have nested retrieveItems with more containers
            if let retrieveItems = container["retrieveItems"] as? [String: Any],
               let innerResultObj = retrieveItems["resultObj"] as? [String: Any],
               let innerContainers = innerResultObj["containers"] as? [[String: Any]] {
                
                for innerContainer in innerContainers {
                    if let item = parseContentItem(from: innerContainer) {
                        items.append(item)
                    }
                }
            }
            
            // Also check direct metadata
            if let item = parseContentItem(from: container) {
                items.append(item)
            }
        }
        
        print("[F1TVContentService] Parsed \(items.count) content items.")
        return items
    }
    
    private func parseContentItem(from container: [String: Any]) -> F1TVContentItem? {
        guard let metadata = container["metadata"] as? [String: Any] else {
            return nil
        }
        
        let contentId = metadata["contentId"] as? Int
        let contentIdStr = contentId.map { String($0) }
            ?? (container["id"] as? String)
            ?? (metadata["objectType"] as? String)
        
        guard let id = contentIdStr else { return nil }
        let numericID = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard numericID.allSatisfy(\.isNumber) else { return nil }
        
        let title = metadata["title"] as? String
            ?? metadata["longDescription"] as? String
            ?? "Untitled"
        
        let subtitle = metadata["objectType"] as? String
        let isLive = metadata["isLive"] as? Bool ?? false
        
        let sessionTypeName = metadata["sessionType"] as? String ?? ""
        let sessionType = mapSessionType(sessionTypeName)
        
        // Store the raw pictureUrl path for F1TVImageView (cookie-aware loading)
        let rawPictureUrl = metadata["pictureUrl"] as? String
        
        let grandPrixName = metadata["emfAttributes"] as? [String: Any]
        let gpName = grandPrixName?["Meeting_Name"] as? String
            ?? metadata["meetingName"] as? String
        
        let durationStr = metadata["duration"] as? Int
        
        return F1TVContentItem(
            id: numericID,
            title: title,
            subtitle: subtitle,
            sessionType: sessionType,
            pictureUrl: rawPictureUrl,
            isLive: isLive,
            startTime: nil,
            durationSeconds: durationStr,
            grandPrixName: gpName
        )
    }
    
    private func mapSessionType(_ raw: String) -> F1TVSessionType {
        let lowered = raw.lowercased()
        if lowered.contains("race") && lowered.contains("sprint") { return .sprintRace }
        if lowered.contains("race") { return .race }
        if lowered.contains("qualifying") && lowered.contains("sprint") { return .sprintQualifying }
        if lowered.contains("qualifying") { return .qualifying }
        if lowered.contains("practice") { return .practice }
        if lowered.contains("replay") { return .replay }
        return .unknown
    }
    
    /// Parses the stream entitlement response to extract the HLS URL and token.
    private func parseStreamEntitlement(_ data: Data, contentId: String) throws -> F1TVStreamEntitlement {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let resultObj = json["resultObj"] as? [String: Any] else {
            throw AuthError.invalidResponse
        }
        
        // The entitlement response may contain the stream URL in different locations:
        // - resultObj.url (direct URL string)
        // - resultObj.containers[0].bundle.streams[0].playbackUrl (newer API format)
        var streamURLString = resultObj["url"] as? String
        
        if streamURLString == nil,
           let containers = resultObj["containers"] as? [[String: Any]],
           let firstContainer = containers.first,
           let bundle = firstContainer["bundle"] as? [String: Any],
           let streams = bundle["streams"] as? [[String: Any]],
           let firstStream = streams.first {
            streamURLString = firstStream["playbackUrl"] as? String
                ?? firstStream["streamUrl"] as? String
                ?? firstStream["url"] as? String
        }
        
        guard let urlString = streamURLString, let streamURL = URL(string: urlString) else {
            print("[F1TVContentService] No stream URL found in entitlement response. Keys: \(resultObj.keys.sorted())")
            throw AuthError.invalidResponse
        }
        
        let entitlementToken = resultObj["entitlementToken"] as? String
            ?? sessionProvider()?.subscriberToken
            ?? ""
        
        print("[F1TVContentService] Stream entitlement obtained. URL: \(streamURL.absoluteString.prefix(80))...")
        
        return F1TVStreamEntitlement(
            streamURL: streamURL,
            entitlementToken: entitlementToken,
            contentId: contentId
        )
    }
}
