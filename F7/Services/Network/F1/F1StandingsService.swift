import Foundation

public struct F1RaceRound: Identifiable, Hashable {
    public let id: Int
    public let round: Int
    public let raceName: String
    public let raceDate: Date?
    public let circuitName: String
    public let locality: String
    public let country: String
}

public struct DriverStanding: Identifiable, Hashable {
    public let id: String
    public let position: Int
    public let points: Double
    public let wins: Int
    public let driverId: String
    public let driverCode: String
    public let driverName: String
    public let teamName: String
    public let permanentNumber: String?
    public let nationality: String?
    public let dateOfBirth: String?
}

public struct ConstructorStanding: Identifiable, Hashable {
    public let id: String
    public let position: Int
    public let points: Double
    public let wins: Int
    public let teamName: String
}

public final class F1StandingsService {
    private let baseURL = "https://api.jolpi.ca/ergast/f1"
    private static let raceDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    public init() {}

    public func fetchRaceRounds(season: Int) async throws -> [F1RaceRound] {
        let url = try endpointURL(path: "\(season).json")
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw AuthError.invalidResponse
        }

        let decoded = try JSONDecoder().decode(RaceScheduleResponse.self, from: data)
        let races = decoded.MRData.RaceTable.Races

        return races.compactMap { race in
            guard let round = Int(race.round) else { return nil }
            return F1RaceRound(
                id: round,
                round: round,
                raceName: race.raceName,
                raceDate: Self.raceDateFormatter.date(from: race.date),
                circuitName: race.Circuit.circuitName,
                locality: race.Circuit.Location.locality,
                country: race.Circuit.Location.country
            )
        }
    }

    public func fetchDriverStandings(season: Int, round: Int?) async throws -> [DriverStanding] {
        let path: String
        if let round {
            path = "\(season)/\(round)/driverStandings.json"
        } else {
            path = "\(season)/driverStandings.json"
        }

        let url = try endpointURL(path: path)
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw AuthError.invalidResponse
        }

        let decoded = try JSONDecoder().decode(DriverStandingsResponse.self, from: data)
        let standings = decoded.MRData.StandingsTable.StandingsLists.first?.DriverStandings ?? []

        let roundKey = round.map(String.init) ?? "season"

        return standings.map {
            DriverStanding(
                id: "\(season)-\(roundKey)-\($0.Driver.driverId)",
                position: Int($0.position) ?? 0,
                points: Double($0.points) ?? 0,
                wins: Int($0.wins) ?? 0,
                driverId: $0.Driver.driverId,
                driverCode: $0.Driver.code ?? String($0.Driver.familyName.prefix(3)).uppercased(),
                driverName: "\($0.Driver.givenName) \($0.Driver.familyName)",
                teamName: $0.Constructors.first?.name ?? "Unknown",
                permanentNumber: $0.Driver.permanentNumber,
                nationality: $0.Driver.nationality,
                dateOfBirth: $0.Driver.dateOfBirth
            )
        }
    }

    public func fetchConstructorStandings(season: Int, round: Int?) async throws -> [ConstructorStanding] {
        let path: String
        if let round {
            path = "\(season)/\(round)/constructorStandings.json"
        } else {
            path = "\(season)/constructorStandings.json"
        }

        let url = try endpointURL(path: path)
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw AuthError.invalidResponse
        }

        let decoded = try JSONDecoder().decode(ConstructorStandingsResponse.self, from: data)
        let standings = decoded.MRData.StandingsTable.StandingsLists.first?.ConstructorStandings ?? []

        let roundKey = round.map(String.init) ?? "season"

        return standings.map {
            ConstructorStanding(
                id: "\(season)-\(roundKey)-\($0.Constructor.constructorId)",
                position: Int($0.position) ?? 0,
                points: Double($0.points) ?? 0,
                wins: Int($0.wins) ?? 0,
                teamName: $0.Constructor.name
            )
        }
    }

    public func fetchDriverRaceResults(season: Int, driverId: String) async throws -> [DriverRaceResult] {
        let path = "\(season)/drivers/\(driverId)/results.json?limit=100"
        let url = try endpointURL(path: path)
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw AuthError.invalidResponse
        }

        let decoded = try JSONDecoder().decode(DriverResultsResponse.self, from: data)
        let races = decoded.MRData.RaceTable.Races

        return races.compactMap { race in
            guard let result = race.Results.first else { return nil }

            return DriverRaceResult(
                round: Int(race.round) ?? 0,
                raceName: race.raceName,
                grid: Int(result.grid) ?? 0,
                finishPosition: result.position.flatMap(Int.init),
                finishText: result.positionText,
                points: Double(result.points) ?? 0,
                status: result.status
            )
        }
    }

    private func endpointURL(path: String) throws -> URL {
        guard let url = URL(string: "\(baseURL)/\(path)") else {
            throw AuthError.invalidResponse
        }
        return url
    }
}

private struct RaceScheduleResponse: Decodable {
    let MRData: RaceScheduleMRData
}

private struct RaceScheduleMRData: Decodable {
    let RaceTable: RaceTable
}

private struct RaceTable: Decodable {
    let Races: [RaceEntry]
}

private struct RaceEntry: Decodable {
    let round: String
    let raceName: String
    let date: String
    let Circuit: CircuitEntry
}

private struct CircuitEntry: Decodable {
    let circuitName: String
    let Location: CircuitLocationEntry
}

private struct CircuitLocationEntry: Decodable {
    let locality: String
    let country: String
}

private struct DriverStandingsResponse: Decodable {
    let MRData: DriverMRData
}

private struct DriverMRData: Decodable {
    let StandingsTable: DriverStandingsTable
}

private struct DriverStandingsTable: Decodable {
    let StandingsLists: [DriverStandingsList]
}

private struct DriverStandingsList: Decodable {
    let DriverStandings: [DriverStandingEntry]
}

private struct DriverStandingEntry: Decodable {
    let position: String
    let points: String
    let wins: String
    let Driver: DriverEntry
    let Constructors: [ConstructorEntry]
}

private struct DriverEntry: Decodable {
    let driverId: String
    let code: String?
    let givenName: String
    let familyName: String
    let permanentNumber: String?
    let dateOfBirth: String?
    let nationality: String?
}

private struct ConstructorStandingsResponse: Decodable {
    let MRData: ConstructorMRData
}

private struct ConstructorMRData: Decodable {
    let StandingsTable: ConstructorStandingsTable
}

private struct ConstructorStandingsTable: Decodable {
    let StandingsLists: [ConstructorStandingsList]
}

private struct ConstructorStandingsList: Decodable {
    let ConstructorStandings: [ConstructorStandingEntry]
}

private struct ConstructorStandingEntry: Decodable {
    let position: String
    let points: String
    let wins: String
    let Constructor: ConstructorEntry
}

private struct ConstructorEntry: Decodable {
    let constructorId: String
    let name: String
}
public struct DriverRaceResult: Identifiable, Hashable {
    public let round: Int
    public let raceName: String
    public let grid: Int
    public let finishPosition: Int?
    public let finishText: String
    public let points: Double
    public let status: String

    public var id: Int { round }
}

private struct DriverResultsResponse: Decodable {
    let MRData: DriverResultsMRData
}

private struct DriverResultsMRData: Decodable {
    let RaceTable: DriverResultsRaceTable
}

private struct DriverResultsRaceTable: Decodable {
    let Races: [DriverResultRace]
}

private struct DriverResultRace: Decodable {
    let round: String
    let raceName: String
    let Results: [DriverResultEntry]
}

private struct DriverResultEntry: Decodable {
    let grid: String
    let position: String?
    let positionText: String
    let points: String
    let status: String
}
