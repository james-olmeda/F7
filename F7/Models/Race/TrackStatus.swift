import Foundation

/// Represents the global safety status of the circuit.
/// For example, the value '1' indicates general green flag, '4' dictates the presence of the Safety Car, and '5' imposes a total stop via red flag.
public enum TrackStatus: String, Codable, Hashable, CaseIterable {
    /// 1 - General Green Flag, All Clear
    case allClear = "1"
    
    /// 2 - Yellow Flag (Sector specific)
    case yellow = "2"
    
    /// 3 - Unused/Unknown in standard recent telemetry, sometimes SC standby
    case unacknowledged = "3"
    
    /// 4 - Safety Car deployed
    case safetyCar = "4"
    
    /// 5 - Red Flag (Session suspended/stopped)
    case redFlag = "5"
    
    /// 6 - Virtual Safety Car deployed
    case virtualSafetyCar = "6"
    
    /// 7 - Virtual Safety Car Ending
    case virtualSafetyCarEnding = "7"
    
    /// Unknown status fallback
    case unknown = "0"
    
    /// Resolves to a human-readable description of the flag/status.
    public var description: String {
        switch self {
        case .allClear:
            return "All Clear (Green)"
        case .yellow:
            return "Yellow Flag"
        case .unacknowledged:
            return "Pending"
        case .safetyCar:
            return "Safety Car deployed"
        case .redFlag:
            return "Red Flag"
        case .virtualSafetyCar:
            return "Virtual Safety Car deployed"
        case .virtualSafetyCarEnding:
            return "Virtual Safety Car ending"
        case .unknown:
            return "Unknown Status"
        }
    }
}
