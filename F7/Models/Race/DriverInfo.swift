import SwiftUI

/// Static reference data for F1 drivers, including team colors and abbreviations.
public struct DriverInfo {
    public let number: Int
    public let abbreviation: String
    public let fullName: String
    public let teamName: String
    public let teamColor: Color
    
    /// Lookup dictionary keyed by driver number.
    public static let all: [Int: DriverInfo] = {
        var dict = [Int: DriverInfo]()
        for driver in drivers {
            dict[driver.number] = driver
        }
        return dict
    }()
    
    private static let drivers: [DriverInfo] = [
        DriverInfo(number: 1,  abbreviation: "VER", fullName: "Max Verstappen",    teamName: "Red Bull Racing",    teamColor: Color(red: 0.14, green: 0.21, blue: 0.58)),
        DriverInfo(number: 11, abbreviation: "PER", fullName: "Sergio Pérez",      teamName: "Red Bull Racing",    teamColor: Color(red: 0.14, green: 0.21, blue: 0.58)),
        DriverInfo(number: 4,  abbreviation: "NOR", fullName: "Lando Norris",      teamName: "McLaren",            teamColor: Color(red: 1.0,  green: 0.52, blue: 0.0)),
        DriverInfo(number: 81, abbreviation: "PIA", fullName: "Oscar Piastri",     teamName: "McLaren",            teamColor: Color(red: 1.0,  green: 0.52, blue: 0.0)),
        DriverInfo(number: 44, abbreviation: "HAM", fullName: "Lewis Hamilton",    teamName: "Ferrari",            teamColor: Color(red: 0.9,  green: 0.1,  blue: 0.1)),
        DriverInfo(number: 16, abbreviation: "LEC", fullName: "Charles Leclerc",   teamName: "Ferrari",            teamColor: Color(red: 0.9,  green: 0.1,  blue: 0.1)),
        DriverInfo(number: 63, abbreviation: "RUS", fullName: "George Russell",    teamName: "Mercedes",           teamColor: Color(red: 0.15, green: 0.82, blue: 0.75)),
        DriverInfo(number: 55, abbreviation: "SAI", fullName: "Carlos Sainz",      teamName: "Williams",           teamColor: Color(red: 0.0,  green: 0.32, blue: 0.65)),
        DriverInfo(number: 14, abbreviation: "ALO", fullName: "Fernando Alonso",   teamName: "Aston Martin",       teamColor: Color(red: 0.0,  green: 0.45, blue: 0.34)),
        DriverInfo(number: 18, abbreviation: "STR", fullName: "Lance Stroll",      teamName: "Aston Martin",       teamColor: Color(red: 0.0,  green: 0.45, blue: 0.34)),
        DriverInfo(number: 10, abbreviation: "GAS", fullName: "Pierre Gasly",      teamName: "Alpine",             teamColor: Color(red: 0.0,  green: 0.58, blue: 0.85)),
        DriverInfo(number: 31, abbreviation: "OCO", fullName: "Esteban Ocon",      teamName: "Haas",               teamColor: Color(red: 0.65, green: 0.65, blue: 0.65)),
        DriverInfo(number: 23, abbreviation: "ALB", fullName: "Alexander Albon",   teamName: "Williams",           teamColor: Color(red: 0.0,  green: 0.32, blue: 0.65)),
        DriverInfo(number: 2,  abbreviation: "SAR", fullName: "Logan Sargeant",    teamName: "Williams",           teamColor: Color(red: 0.0,  green: 0.32, blue: 0.65)),
        DriverInfo(number: 27, abbreviation: "HUL", fullName: "Nico Hülkenberg",   teamName: "Sauber",             teamColor: Color(red: 0.0,  green: 0.55, blue: 0.25)),
        DriverInfo(number: 20, abbreviation: "MAG", fullName: "Kevin Magnussen",   teamName: "Haas",               teamColor: Color(red: 0.65, green: 0.65, blue: 0.65)),
        DriverInfo(number: 22, abbreviation: "TSU", fullName: "Yuki Tsunoda",      teamName: "RB",                 teamColor: Color(red: 0.27, green: 0.33, blue: 0.63)),
        DriverInfo(number: 30, abbreviation: "LAW", fullName: "Liam Lawson",       teamName: "Red Bull Racing",    teamColor: Color(red: 0.14, green: 0.21, blue: 0.58)),
        DriverInfo(number: 77, abbreviation: "BOT", fullName: "Valtteri Bottas",   teamName: "Sauber",             teamColor: Color(red: 0.0,  green: 0.55, blue: 0.25)),
        DriverInfo(number: 24, abbreviation: "ZHO", fullName: "Guanyu Zhou",       teamName: "Sauber",             teamColor: Color(red: 0.0,  green: 0.55, blue: 0.25)),
    ]
}
