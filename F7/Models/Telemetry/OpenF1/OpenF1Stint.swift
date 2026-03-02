import Foundation

public struct OpenF1Stint: Codable, Hashable, Identifiable {
    public let driverNumber: Int
    public let stintNumber: Int
    public let lapStart: Int
    public let lapEnd: Int
    public let compound: String?
    public let tyreAgeAtStart: Int?
    public let sessionKey: Int
    public let meetingKey: Int

    public var id: String { "\(sessionKey)-\(driverNumber)-\(stintNumber)" }

    enum CodingKeys: String, CodingKey {
        case driverNumber = "driver_number"
        case stintNumber = "stint_number"
        case lapStart = "lap_start"
        case lapEnd = "lap_end"
        case compound
        case tyreAgeAtStart = "tyre_age_at_start"
        case sessionKey = "session_key"
        case meetingKey = "meeting_key"
    }
}
