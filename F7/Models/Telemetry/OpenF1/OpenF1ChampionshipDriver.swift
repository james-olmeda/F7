import Foundation

public struct OpenF1ChampionshipDriver: Codable, Hashable, Identifiable {
    public let driverNumber: Int
    public let position: Int
    public let points: Double
    public let sessionKey: Int
    public let meetingKey: Int

    public var id: String { "\(sessionKey)-\(driverNumber)" }

    enum CodingKeys: String, CodingKey {
        case driverNumber = "driver_number"
        case position
        case points
        case sessionKey = "session_key"
        case meetingKey = "meeting_key"
    }
}
