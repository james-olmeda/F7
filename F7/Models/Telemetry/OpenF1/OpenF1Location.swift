import Foundation

public struct OpenF1Location: Codable, Hashable, Identifiable {
    public let driverNumber: Int
    public let x: Double
    public let y: Double
    public let z: Double
    public let date: Date
    public let sessionKey: Int
    public let meetingKey: Int

    public var id: String { "\(driverNumber)-\(date.timeIntervalSince1970)" }

    enum CodingKeys: String, CodingKey {
        case driverNumber = "driver_number"
        case x
        case y
        case z
        case date
        case sessionKey = "session_key"
        case meetingKey = "meeting_key"
    }
}
