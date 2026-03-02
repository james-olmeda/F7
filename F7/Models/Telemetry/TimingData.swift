import Foundation

/// Represents the absolute and relative timing data for a specific driver during a session.
public struct TimingData: Codable, Hashable, Identifiable {
    public let id: String
    
    /// The unique identifier of the driver (e.g., 1 for Verstappen, 44 for Hamilton).
    public let driverNumber: Int
    
    /// Overall position in the current session.
    public let position: Int
    
    /// Time of the best lap achieved in the session (in seconds).
    public let bestLapTime: Double?
    
    /// Time of the current/last completed lap (in seconds).
    public let lastLapTime: Double?
    
    /// Sector times for the current lap.
    public let sector1Time: Double?
    public let sector2Time: Double?
    public let sector3Time: Double?
    
    /// Array of micro-sector statuses (e.g., 0: no data, 1: purple, 2: green, 3: yellow).
    public let microSectors: [Int]
    
    /// The time interval to the leader (in seconds).
    public let intervalToLeader: Double?
    
    /// The time interval to the car immediately ahead (in seconds).
    public let intervalToCarAhead: Double?
    
    /// Indicates if the driver is currently in the pit lane.
    public let inPitLane: Bool
    
    /// The timestamp when the telemetry string was generated.
    public let timestamp: Date
    
    public init(
        id: String = UUID().uuidString,
        driverNumber: Int,
        position: Int,
        bestLapTime: Double? = nil,
        lastLapTime: Double? = nil,
        sector1Time: Double? = nil,
        sector2Time: Double? = nil,
        sector3Time: Double? = nil,
        microSectors: [Int] = [],
        intervalToLeader: Double? = nil,
        intervalToCarAhead: Double? = nil,
        inPitLane: Bool = false,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.driverNumber = driverNumber
        self.position = position
        self.bestLapTime = bestLapTime
        self.lastLapTime = lastLapTime
        self.sector1Time = sector1Time
        self.sector2Time = sector2Time
        self.sector3Time = sector3Time
        self.microSectors = microSectors
        self.intervalToLeader = intervalToLeader
        self.intervalToCarAhead = intervalToCarAhead
        self.inPitLane = inPitLane
        self.timestamp = timestamp
    }
}
