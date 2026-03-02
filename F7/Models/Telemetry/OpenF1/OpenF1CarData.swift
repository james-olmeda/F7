import Foundation

public struct OpenF1CarData: Codable, Hashable, Identifiable {
    public let id: String
    public let driverNumber: Int
    public let rpm: Int
    public let speed: Int
    public let gear: Int
    public let throttle: Int
    public let brake: Int
    public let drs: Int
    public let date: Date
    public let sessionKey: Int?
    public let meetingKey: Int?

    enum CodingKeys: String, CodingKey {
        case driverNumber = "driver_number"
        case rpm
        case speed
        case gear
        case throttle
        case brake
        case drs
        case date
        case sessionKey = "session_key"
        case meetingKey = "meeting_key"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.driverNumber = try container.decode(Int.self, forKey: .driverNumber)
        self.rpm = try container.decode(Int.self, forKey: .rpm)
        self.speed = try container.decode(Int.self, forKey: .speed)
        self.gear = try container.decode(Int.self, forKey: .gear)
        
        // Sometimes throttle/brake are returned as Double, but OpenF1 typically uses Int for throttle/brake (0-100)
        self.throttle = try container.decodeIfPresent(Int.self, forKey: .throttle) ?? Int(try container.decodeIfPresent(Double.self, forKey: .throttle) ?? 0)
        self.brake = try container.decodeIfPresent(Int.self, forKey: .brake) ?? Int(try container.decodeIfPresent(Double.self, forKey: .brake) ?? 0)
        
        self.drs = try container.decode(Int.self, forKey: .drs)
        self.sessionKey = try container.decodeIfPresent(Int.self, forKey: .sessionKey)
        self.meetingKey = try container.decodeIfPresent(Int.self, forKey: .meetingKey)
        
        // The date parsing relies on the custom decoder date formatting in OpenF1RestClient
        self.date = try container.decode(Date.self, forKey: .date)
        
        self.id = "\(driverNumber)-\(date.timeIntervalSince1970)"
    }
}
