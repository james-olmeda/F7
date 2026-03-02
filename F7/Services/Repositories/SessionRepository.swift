import Foundation

public final class SessionRepository {
    private let openF1Client: OpenF1RestClient
    
    public init(openF1Client: OpenF1RestClient = OpenF1RestClient()) {
        self.openF1Client = openF1Client
    }
    
    public func fetchMeetings(year: Int? = nil) async throws -> [OpenF1Meeting] {
        return try await openF1Client.fetchMeetings(year: year)
    }
    
    public func fetchSessions(meetingKey: String) async throws -> [OpenF1Session] {
        return try await openF1Client.fetchSessions(meetingKey: meetingKey)
    }
    
    public func fetchSessionResults(sessionKey: String) async throws -> [OpenF1SessionResult] {
        return try await openF1Client.fetchSessionResults(sessionKey: sessionKey)
    }
    
    public func fetchStartingGrid(sessionKey: String) async throws -> [OpenF1StartingGrid] {
        return try await openF1Client.fetchStartingGrid(sessionKey: sessionKey)
    }
}
