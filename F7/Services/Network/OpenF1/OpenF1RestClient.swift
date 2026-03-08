import Foundation

/// A REST client fallback that queries OpenF1 APIs for telemetry when SignalR fails.
public final class OpenF1RestClient: TelemetryProviderProtocol {
    private let baseURL = "https://api.openf1.org/v1"
    private let tokenURL = "https://api.openf1.org/token"
    private var pollingTimer: Timer?
    public var isConnected: Bool = false

    private var accessToken: String?
    private var tokenExpiryDate: Date?
    private let rateLimiter = OpenF1RateLimiter()
    
    public init() {
        print("[OpenF1RestClient] Initialized external fallback API structure.")
    }
    
    public func start() {
        print("[OpenF1RestClient] Commencing REST polling fallback.")
        isConnected = true
        
        // Simulating a polling structure since OpenF1 provides REST endpoints, not webSockets typically
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.fetchLatestTelemetry()
        }
    }
    
    public func stop() {
        print("[OpenF1RestClient] Halting OpenF1 periodic polling.")
        pollingTimer?.invalidate()
        pollingTimer = nil
        isConnected = false
    }
    
    private func fetchLatestTelemetry() {
        guard let url = URL(string: "\(baseURL)/car_data?session_key=latest") else { return }
        
        Task {
            do {
                let request = try await authorizedRequest(url: url)
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    return
                }
                
                print("[OpenF1RestClient] Extracted \(data.count) bytes of historical telemetry.")
                // Parse the data and dispatch to Repository
            } catch {
                print("[OpenF1RestClient] Failed to fetch REST telemetry: \(error)")
            }
        }
    }

    private func fetchGeneric<T: Decodable>(url: URL) async throws -> [T] {
        var lastError: Error = AuthError.invalidResponse

        for attempt in 0..<3 {
            do {
                try await rateLimiter.acquire()
                var request = try await authorizedRequest(url: url)
                request.setValue("application/json", forHTTPHeaderField: "accept")

                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw AuthError.invalidResponse
                }

                if httpResponse.statusCode == 401 {
                    if await refreshAccessTokenIfPossible(force: true) {
                        continue
                    }
                    throw AuthError.invalidResponse
                }

                if httpResponse.statusCode == 429 {
                    let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                        .flatMap(TimeInterval.init) ?? Double(2 + attempt)
                    try await Task.sleep(nanoseconds: UInt64(retryAfter * 1_000_000_000))
                    continue
                }

                guard (200...299).contains(httpResponse.statusCode) else {
                    throw AuthError.invalidResponse
                }

                return try decodedPayload(from: data)
            } catch {
                lastError = error
                if attempt < 2 {
                    let wait = UInt64(Double(attempt + 1) * 500_000_000)
                    try await Task.sleep(nanoseconds: wait)
                }
            }
        }

        throw lastError
    }

    private func fetchWithSession<T: Decodable>(endpoint: String, sessionKey: String) async throws -> [T] {
        guard let url = URL(string: "\(baseURL)/\(endpoint)?session_key=\(sessionKey)") else {
            throw AuthError.invalidResponse
        }
        return try await fetchGeneric(url: url)
    }

    private func decodedPayload<T: Decodable>(from data: Data) throws -> [T] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)

            let formatterWithFraction = ISO8601DateFormatter()
            formatterWithFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatterWithFraction.date(from: raw) {
                return date
            }

            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: raw) {
                return date
            }

            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(raw)")
        }
        return try decoder.decode([T].self, from: data)
    }

    private func authorizedRequest(url: URL) async throws -> URLRequest {
        var request = URLRequest(url: url)
        if let token = try await validAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func validAccessToken() async throws -> String? {
        if let token = accessToken, let expiry = tokenExpiryDate, expiry > Date().addingTimeInterval(30) {
            return token
        }
        let refreshed = await refreshAccessTokenIfPossible(force: false)
        if refreshed {
            return accessToken
        }
        return nil
    }

    @discardableResult
    private func refreshAccessTokenIfPossible(force: Bool) async -> Bool {
        if !force, let expiry = tokenExpiryDate, expiry > Date().addingTimeInterval(30), accessToken != nil {
            return true
        }

        let env = ProcessInfo.processInfo.environment
        guard let username = env["OPENF1_USERNAME"], !username.isEmpty,
              let password = env["OPENF1_PASSWORD"], !password.isEmpty else {
            return false
        }

        guard let url = URL(string: tokenURL) else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "username", value: username),
            URLQueryItem(name: "password", value: password)
        ]
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                return false
            }
            let token = try JSONDecoder().decode(OpenF1TokenResponse.self, from: data)
            accessToken = token.accessToken
            if let expiresIn = TimeInterval(token.expiresIn) {
                tokenExpiryDate = Date().addingTimeInterval(expiresIn)
            } else {
                tokenExpiryDate = Date().addingTimeInterval(3500)
            }
            return true
        } catch {
            return false
        }
    }

    // MARK: - OpenF1 API Endpoints

    public func fetchCarData(sessionKey: String = "latest") async throws -> [OpenF1CarData] { try await fetchWithSession(endpoint: "car_data", sessionKey: sessionKey) }
    public func fetchChampionshipDrivers(sessionKey: String = "latest") async throws -> [OpenF1ChampionshipDriver] { try await fetchWithSession(endpoint: "championship_drivers", sessionKey: sessionKey) }
    public func fetchChampionshipTeams(sessionKey: String = "latest") async throws -> [OpenF1ChampionshipTeam] { try await fetchWithSession(endpoint: "championship_teams", sessionKey: sessionKey) }
    public func fetchDrivers(sessionKey: String = "latest") async throws -> [OpenF1Driver] { try await fetchWithSession(endpoint: "drivers", sessionKey: sessionKey) }
    public func fetchIntervals(sessionKey: String = "latest") async throws -> [OpenF1Interval] { try await fetchWithSession(endpoint: "intervals", sessionKey: sessionKey) }
    public func fetchLaps(sessionKey: String = "latest") async throws -> [OpenF1Lap] { try await fetchWithSession(endpoint: "laps", sessionKey: sessionKey) }
    public func fetchLocation(sessionKey: String = "latest") async throws -> [OpenF1Location] { try await fetchWithSession(endpoint: "location", sessionKey: sessionKey) }
    public func fetchOvertakes(sessionKey: String = "latest") async throws -> [OpenF1Overtake] { try await fetchWithSession(endpoint: "overtakes", sessionKey: sessionKey) }
    public func fetchPitStops(sessionKey: String = "latest") async throws -> [OpenF1PitStop] { try await fetchWithSession(endpoint: "pit", sessionKey: sessionKey) }
    public func fetchPositions(sessionKey: String = "latest") async throws -> [OpenF1Position] { try await fetchWithSession(endpoint: "position", sessionKey: sessionKey) }
    public func fetchSessionResults(sessionKey: String = "latest") async throws -> [OpenF1SessionResult] { try await fetchWithSession(endpoint: "session_result", sessionKey: sessionKey) }
    public func fetchStartingGrid(sessionKey: String = "latest") async throws -> [OpenF1StartingGrid] { try await fetchWithSession(endpoint: "starting_grid", sessionKey: sessionKey) }
    public func fetchStints(sessionKey: String = "latest") async throws -> [OpenF1Stint] { try await fetchWithSession(endpoint: "stints", sessionKey: sessionKey) }
    public func fetchTeamRadio(sessionKey: String = "latest") async throws -> [OpenF1TeamRadio] { try await fetchWithSession(endpoint: "team_radio", sessionKey: sessionKey) }
    public func fetchWeather(sessionKey: String = "latest") async throws -> [OpenF1Weather] { try await fetchWithSession(endpoint: "weather", sessionKey: sessionKey) }

    public func fetchMeetings(year: Int? = nil) async throws -> [OpenF1Meeting] {
        var urlString = "\(baseURL)/meetings"
        if let y = year { urlString += "?year=\(y)" }
        guard let url = URL(string: urlString) else { throw AuthError.invalidResponse }
        return try await fetchGeneric(url: url)
    }

    public func fetchSessions(sessionKey: String? = nil, meetingKey: String? = nil) async throws -> [OpenF1Session] {
        var query = "session_key=latest"
        if let s = sessionKey { query = "session_key=\(s)" }
        else if let m = meetingKey { query = "meeting_key=\(m)" }
        guard let url = URL(string: "\(baseURL)/sessions?\(query)") else { throw AuthError.invalidResponse }
        return try await fetchGeneric(url: url)
    }

    public func fetchRaceControlFeed(limit: Int = 20, sessionKey: String = "latest") async throws -> [RaceControlMessage] {
        let entries: [OpenF1RaceControlEntry] = try await fetchWithSession(endpoint: "race_control", sessionKey: sessionKey)

        let messages = entries.map { entry in
            RaceControlMessage(
                id: entry.messageId.map(String.init) ?? UUID().uuidString,
                message: entry.message,
                category: mapCategory(entry.category),
                flag: entry.flag,
                driverNumber: entry.driverNumber,
                sector: entry.sector,
                timestamp: entry.date
            )
        }

        return Array(messages.sorted(by: { $0.timestamp > $1.timestamp }).prefix(limit))
    }

    private func mapCategory(_ raw: String?) -> RaceControlCategory {
        switch raw?.lowercased() {
        case "flag": return .flag
        case "penalty": return .penalty
        case "safetycar", "safety car": return .safetyCar
        case "track limits", "tracklimits": return .trackLimits
        case "info", "information": return .information
        default: return .unknown
        }
    }
}

private struct OpenF1TokenResponse: Decodable {
    let expiresIn: String
    let accessToken: String

    private enum CodingKeys: String, CodingKey {
        case expiresIn = "expires_in"
        case accessToken = "access_token"
    }
}

private actor OpenF1RateLimiter {
    private var secondBucket: [Date] = []
    private var minuteBucket: [Date] = []

    func acquire() async throws {
        while true {
            let now = Date()
            secondBucket = secondBucket.filter { now.timeIntervalSince($0) < 1.0 }
            minuteBucket = minuteBucket.filter { now.timeIntervalSince($0) < 60.0 }

            if secondBucket.count < 6 && minuteBucket.count < 60 {
                secondBucket.append(now)
                minuteBucket.append(now)
                return
            }

            let waitSecond = secondBucket.first.map { 1.0 - now.timeIntervalSince($0) } ?? 0.1
            let waitMinute = minuteBucket.first.map { 60.0 - now.timeIntervalSince($0) } ?? 0.1
            let wait = max(0.05, min(waitSecond, waitMinute))
            try await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
        }
    }
}

private struct OpenF1RaceControlEntry: Decodable {
    let category: String?
    let date: Date
    let driverNumber: Int?
    let flag: String?
    let message: String
    let messageId: Int?
    let sector: Int?

    private enum CodingKeys: String, CodingKey {
        case category
        case date
        case driverNumber = "driver_number"
        case flag
        case message
        case messageId = "message_id"
        case sector
    }
}
