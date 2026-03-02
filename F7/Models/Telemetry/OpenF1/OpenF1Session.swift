import Foundation

public struct OpenF1Session: Codable, Hashable, Identifiable {
    public let sessionKey: Int
    public let sessionName: String
    public let dateStart: Date
    public let dateEnd: Date
    public let gmtOffset: String
    public let sessionType: String
    public let meetingKey: Int
    public let location: String
    public let countryKey: Int
    public let countryCode: String
    public let countryName: String
    public let circuitKey: Int
    public let circuitShortName: String
    public let year: Int

    public var id: Int { sessionKey }

    enum CodingKeys: String, CodingKey {
        case sessionKey = "session_key"
        case sessionName = "session_name"
        case dateStart = "date_start"
        case dateEnd = "date_end"
        case gmtOffset = "gmt_offset"
        case sessionType = "session_type"
        case meetingKey = "meeting_key"
        case location
        case countryKey = "country_key"
        case countryCode = "country_code"
        case countryName = "country_name"
        case circuitKey = "circuit_key"
        case circuitShortName = "circuit_short_name"
        case year
    }
}
