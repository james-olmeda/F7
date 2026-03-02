import Foundation

public struct OpenF1Driver: Codable, Hashable, Identifiable {
    public let driverNumber: Int
    public let broadcastName: String
    public let fullName: String
    public let nameAcronym: String
    public let teamName: String
    public let teamColour: String?
    public let firstName: String
    public let lastName: String
    public let headshotUrl: String?
    public let countryCode: String?
    public let sessionKey: Int
    public let meetingKey: Int

    public var id: String { "\(sessionKey)-\(driverNumber)" }

    enum CodingKeys: String, CodingKey {
        case driverNumber = "driver_number"
        case broadcastName = "broadcast_name"
        case fullName = "full_name"
        case nameAcronym = "name_acronym"
        case teamName = "team_name"
        case teamColour = "team_colour"
        case firstName = "first_name"
        case lastName = "last_name"
        case headshotUrl = "headshot_url"
        case countryCode = "country_code"
        case sessionKey = "session_key"
        case meetingKey = "meeting_key"
    }
}
