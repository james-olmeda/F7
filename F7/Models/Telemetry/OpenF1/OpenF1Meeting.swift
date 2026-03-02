import Foundation

public struct OpenF1Meeting: Codable, Hashable, Identifiable {
    public let meetingKey: Int
    public let meetingName: String
    public let meetingOfficialName: String
    public let location: String
    public let countryKey: Int
    public let countryCode: String
    public let countryName: String
    public let circuitKey: Int
    public let circuitShortName: String
    public let dateStart: Date
    public let year: Int

    public var id: Int { meetingKey }

    enum CodingKeys: String, CodingKey {
        case meetingKey = "meeting_key"
        case meetingName = "meeting_name"
        case meetingOfficialName = "meeting_official_name"
        case location
        case countryKey = "country_key"
        case countryCode = "country_code"
        case countryName = "country_name"
        case circuitKey = "circuit_key"
        case circuitShortName = "circuit_short_name"
        case dateStart = "date_start"
        case year
    }
}
