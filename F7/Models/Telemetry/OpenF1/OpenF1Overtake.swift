import Foundation

public struct OpenF1Overtake: Codable, Hashable, Identifiable {
    public let timestamp: Date
    public let driverNumber: Int
    public let overtakenDriverNumber: Int
    public let sessionKey: Int
    public let meetingKey: Int

    public var id: String { "\(driverNumber)-overtakes-\(overtakenDriverNumber)-\(timestamp.timeIntervalSince1970)" }

    enum CodingKeys: String, CodingKey {
        case timestamp
        case driverNumber = "driver_number"
        case overtakenDriverNumber = "overtaken_driver_number"
        case sessionKey = "session_key"
        case meetingKey = "meeting_key"
    }
}
