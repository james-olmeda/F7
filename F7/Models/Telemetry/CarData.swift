import Foundation

/// Represents the pure hardware telemetry extracted from an F1 car.
public struct CarData: Codable, Hashable, Identifiable {
    public let id: String
    
    /// The unique identifier of the driver.
    public let driverNumber: Int
    
    /// Spatial X coordinate on the track map.
    public let xCoordinate: Double
    
    /// Spatial Y coordinate on the track map.
    public let yCoordinate: Double
    
    /// Spatial Z coordinate on the track map.
    public let zCoordinate: Double
    
    /// Speed of the car in kilometers per hour.
    public let speed: Int
    
    /// Current engaged gear (e.g., 0 for Neutral, 1-8).
    public let gear: Int
    
    /// Engine revolutions per minute.
    public let rpm: Int
    
    /// Drag Reduction System status (e.g., 0 = Off, 1 = Available, 8 = Active).
    public let drsStatus: Int
    
    /// Brake pedal pressure / engagement (typically fractional 0.0 to 1.0, or expressed as boolean or 0-100).
    public let brake: Double
    
    /// Throttle pedal pressure (typically fractional 0.0 to 1.0, or 0-100).
    public let throttle: Double
    
    /// The timestamp when the telemetry reading was taken.
    public let timestamp: Date
    
    public init(
        id: String = UUID().uuidString,
        driverNumber: Int,
        xCoordinate: Double = 0.0,
        yCoordinate: Double = 0.0,
        zCoordinate: Double = 0.0,
        speed: Int,
        gear: Int,
        rpm: Int,
        drsStatus: Int = 0,
        brake: Double,
        throttle: Double,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.driverNumber = driverNumber
        self.xCoordinate = xCoordinate
        self.yCoordinate = yCoordinate
        self.zCoordinate = zCoordinate
        self.speed = speed
        self.gear = gear
        self.rpm = rpm
        self.drsStatus = drsStatus
        self.brake = brake
        self.throttle = throttle
        self.timestamp = timestamp
    }
}
