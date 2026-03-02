import Foundation

public struct OpenF1Weather: Codable, Hashable, Identifiable {
    public let airTemperature: Double
    public let trackTemperature: Double
    public let humidity: Double
    public let pressure: Double
    public let windSpeed: Double
    public let windDirection: Int
    public let rainfall: Int
    public let date: Date
    public let sessionKey: Int
    public let meetingKey: Int

    public var id: String { "\(sessionKey)-\(date.timeIntervalSince1970)" }

    enum CodingKeys: String, CodingKey {
        case airTemperature = "air_temperature"
        case trackTemperature = "track_temperature"
        case humidity
        case pressure
        case windSpeed = "wind_speed"
        case windDirection = "wind_direction"
        case rainfall
        case date
        case sessionKey = "session_key"
        case meetingKey = "meeting_key"
    }
}
