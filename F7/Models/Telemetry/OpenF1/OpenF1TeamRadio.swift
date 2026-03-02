import Foundation

public struct OpenF1TeamRadio: Codable, Hashable, Identifiable {
    public let driverNumber: Int
    public let recordingUrl: String
    public let date: Date
    public let sessionKey: Int
    public let meetingKey: Int

    public var id: String { "\(driverNumber)-\(date.timeIntervalSince1970)" }

    enum CodingKeys: String, CodingKey {
        case driverNumber = "driver_number"
        case recordingUrl = "recording_url"
        case date
        case sessionKey = "session_key"
        case meetingKey = "meeting_key"
    }
}
