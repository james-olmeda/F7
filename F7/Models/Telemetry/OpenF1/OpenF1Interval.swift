import Foundation

public struct OpenF1Interval: Codable, Hashable, Identifiable {
    public let driverNumber: Int
    public let gapToLeader: Double?
    public let interval: Double?
    public let date: Date
    public let sessionKey: Int
    public let meetingKey: Int

    public var id: String { "\(driverNumber)-\(date.timeIntervalSince1970)" }

    enum CodingKeys: String, CodingKey {
        case driverNumber = "driver_number"
        case gapToLeader = "gap_to_leader"
        case interval
        case date
        case sessionKey = "session_key"
        case meetingKey = "meeting_key"
    }
}
