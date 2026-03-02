import Foundation

public struct OpenF1SessionResult: Codable, Hashable, Identifiable {
    public let position: Int
    public let driverNumber: Int
    public let gridPosition: Int?
    public let points: Double?
    public let status: String
    public let totalTime: Double?
    public let sessionKey: Int
    public let meetingKey: Int

    public var id: String { "\(sessionKey)-\(driverNumber)" }

    enum CodingKeys: String, CodingKey {
        case position
        case driverNumber = "driver_number"
        case gridPosition = "grid_position"
        case points
        case status
        case totalTime = "total_time"
        case sessionKey = "session_key"
        case meetingKey = "meeting_key"
    }
}
