import Foundation

public struct OpenF1Position: Codable, Hashable, Identifiable {
    public let driverNumber: Int
    public let position: Int
    public let date: Date
    public let sessionKey: Int
    public let meetingKey: Int

    public var id: String { "\(driverNumber)-\(date.timeIntervalSince1970)" }

    enum CodingKeys: String, CodingKey {
        case driverNumber = "driver_number"
        case position
        case date
        case sessionKey = "session_key"
        case meetingKey = "meeting_key"
    }
}
