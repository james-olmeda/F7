import Foundation

/// Represents a single content item from the F1TV catalog (race session, replay, etc.).
public struct F1TVContentItem: Codable, Hashable, Identifiable {
    public let id: String
    public let title: String
    public let subtitle: String?
    public let sessionType: F1TVSessionType
    public let imageURL: URL?
    /// Raw `pictureUrl` path from the F1TV API (e.g. "1000010548-uuid/landscape_web").
    /// Used by `F1TVImageView` to load images through the cookie-aware CDN.
    public let pictureUrl: String?
    public let isLive: Bool
    public let startTime: Date?
    public let durationSeconds: Int?
    public let grandPrixName: String?
    
    public init(
        id: String,
        title: String,
        subtitle: String? = nil,
        sessionType: F1TVSessionType = .unknown,
        imageURL: URL? = nil,
        pictureUrl: String? = nil,
        isLive: Bool = false,
        startTime: Date? = nil,
        durationSeconds: Int? = nil,
        grandPrixName: String? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.sessionType = sessionType
        self.imageURL = imageURL
        self.pictureUrl = pictureUrl
        self.isLive = isLive
        self.startTime = startTime
        self.durationSeconds = durationSeconds
        self.grandPrixName = grandPrixName
    }
}

/// The type of F1 session.
public enum F1TVSessionType: String, Codable, Hashable {
    case race = "RACE"
    case qualifying = "QUALIFYING"
    case practice = "PRACTICE"
    case sprintRace = "SPRINT_RACE"
    case sprintQualifying = "SPRINT_QUALIFYING"
    case replay = "REPLAY"
    case unknown = "UNKNOWN"
    
    public var displayName: String {
        switch self {
        case .race: return "Race"
        case .qualifying: return "Qualifying"
        case .practice: return "Practice"
        case .sprintRace: return "Sprint Race"
        case .sprintQualifying: return "Sprint Qualifying"
        case .replay: return "Replay"
        case .unknown: return "Session"
        }
    }
}
