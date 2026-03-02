import Foundation

public struct OpenF1PitStop: Codable, Hashable, Identifiable {
    public let driverNumber: Int
    public let lapNumber: Int
    public let pitDuration: Double?
    public let date: Date
    public let sessionKey: Int
    public let meetingKey: Int

    public var id: String { "\(sessionKey)-\(driverNumber)-\(lapNumber)" }

    enum CodingKeys: String, CodingKey {
        case driverNumber = "driver_number"
        case lapNumber = "lap_number"
        case pitDuration = "pit_duration"
        case date
        case sessionKey = "session_key"
        case meetingKey = "meeting_key"
    }
}
