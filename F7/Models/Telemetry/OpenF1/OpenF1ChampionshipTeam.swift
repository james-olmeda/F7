import Foundation

public struct OpenF1ChampionshipTeam: Codable, Hashable, Identifiable {
    public let teamName: String
    public let position: Int
    public let points: Double
    public let sessionKey: Int
    public let meetingKey: Int

    public var id: String { "\(sessionKey)-\(teamName)" }

    enum CodingKeys: String, CodingKey {
        case teamName = "team_name"
        case position
        case points
        case sessionKey = "session_key"
        case meetingKey = "meeting_key"
    }
}
