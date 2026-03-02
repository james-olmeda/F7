import Foundation

public struct OpenF1StartingGrid: Codable, Hashable, Identifiable {
    public let gridPosition: Int
    public let driverNumber: Int
    public let q1: String?
    public let q2: String?
    public let q3: String?
    public let sessionKey: Int
    public let meetingKey: Int

    public var id: String { "\(sessionKey)-\(driverNumber)" }

    enum CodingKeys: String, CodingKey {
        case gridPosition = "grid_position"
        case driverNumber = "driver_number"
        case q1
        case q2
        case q3
        case sessionKey = "session_key"
        case meetingKey = "meeting_key"
    }
}
