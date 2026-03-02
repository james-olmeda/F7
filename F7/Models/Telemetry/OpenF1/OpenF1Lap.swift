import Foundation

public struct OpenF1Lap: Codable, Hashable, Identifiable {
    public let driverNumber: Int
    public let lapNumber: Int
    public let lapDuration: Double?
    public let isPitOutLap: Bool
    public let durationSector1: Double?
    public let durationSector2: Double?
    public let durationSector3: Double?
    public let segmentsSector1: [Int]?
    public let segmentsSector2: [Int]?
    public let segmentsSector3: [Int]?
    public let stSpeed: Int?
    public let i1Speed: Int?
    public let i2Speed: Int?
    public let dateStart: Date?
    public let sessionKey: Int
    public let meetingKey: Int

    public var id: String { "\(sessionKey)-\(driverNumber)-\(lapNumber)" }

    enum CodingKeys: String, CodingKey {
        case driverNumber = "driver_number"
        case lapNumber = "lap_number"
        case lapDuration = "lap_duration"
        case isPitOutLap = "is_pit_out_lap"
        case durationSector1 = "duration_sector_1"
        case durationSector2 = "duration_sector_2"
        case durationSector3 = "duration_sector_3"
        case segmentsSector1 = "segments_sector_1"
        case segmentsSector2 = "segments_sector_2"
        case segmentsSector3 = "segments_sector_3"
        case stSpeed = "st_speed"
        case i1Speed = "i1_speed"
        case i2Speed = "i2_speed"
        case dateStart = "date_start"
        case sessionKey = "session_key"
        case meetingKey = "meeting_key"
    }
}
