import Foundation

public final class ChampionshipRepository {
    private let openF1Client: OpenF1RestClient
    
    public init(openF1Client: OpenF1RestClient = OpenF1RestClient()) {
        self.openF1Client = openF1Client
    }
    
    public func fetchDriverStandings(sessionKey: String = "latest") async throws -> [OpenF1ChampionshipDriver] {
        return try await openF1Client.fetchChampionshipDrivers(sessionKey: sessionKey)
    }
    
    public func fetchTeamStandings(sessionKey: String = "latest") async throws -> [OpenF1ChampionshipTeam] {
        return try await openF1Client.fetchChampionshipTeams(sessionKey: sessionKey)
    }
}
