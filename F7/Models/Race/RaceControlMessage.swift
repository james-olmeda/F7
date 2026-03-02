import Foundation

/// Enumeration defining the specific categories of Race Control messages.
public enum RaceControlCategory: String, Codable, Hashable {
    case flag = "Flag"
    case penalty = "Penalty"
    case safetyCar = "SafetyCar"
    case trackLimits = "TrackLimits"
    case information = "Info"
    case unknown = "Unknown"
}

/// Represents official broadcasts from FIA race control.
public struct RaceControlMessage: Codable, Hashable, Identifiable {
    public let id: String
    
    /// The raw text message emitted by race control.
    public let message: String
    
    /// Categorization of the message.
    public let category: RaceControlCategory
    
    /// Flag status string if applicable (e.g., "YELLOW", "RED", "GREEN", "DOUBLE YELLOW").
    public let flag: String?
    
    /// The number of the driver involved (if the message targets a specific driver).
    public let driverNumber: Int?
    
    /// The sector or corner number involved in the incident.
    public let sector: Int?
    
    /// The timestamp when the message was published.
    public let timestamp: Date
    
    public init(
        id: String = UUID().uuidString,
        message: String,
        category: RaceControlCategory,
        flag: String? = nil,
        driverNumber: Int? = nil,
        sector: Int? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.message = message
        self.category = category
        self.flag = flag
        self.driverNumber = driverNumber
        self.sector = sector
        self.timestamp = timestamp
    }
}
