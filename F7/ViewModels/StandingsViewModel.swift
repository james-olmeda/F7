import Foundation

@Observable
public final class StandingsViewModel {
    public enum Category: String, CaseIterable {
        case drivers = "Drivers"
        case teams = "Teams"
    }

    public var selectedSeason: Int
    public var selectedRound: Int?
    public var selectedCategory: Category = .drivers

    public var availableRounds: [F1RaceRound] = []
    public var driverStandings: [DriverStanding] = []
    public var constructorStandings: [ConstructorStanding] = []

    public var isLoading: Bool = false
    public var errorMessage: String?

    public let availableSeasons: [Int]

    private let service: F1StandingsService
    private var lastLoadedSeason: Int?

    public init(service: F1StandingsService = F1StandingsService()) {
        let currentYear = Calendar.current.component(.year, from: Date())
        self.selectedSeason = currentYear
        self.availableSeasons = Array((1950...currentYear).reversed())
        self.service = service
    }

    public var selectedRoundLabel: String {
        guard let selectedRound else { return "\(selectedSeason) Season Total" }
        if let race = availableRounds.first(where: { $0.round == selectedRound }) {
            return "\(selectedSeason) Season • \(race.raceName)"
        }
        return "\(selectedSeason) Season • Round \(selectedRound)"
    }

    public func seasonChanged() async {
        await loadRoundsForSelectedSeason(forceRefresh: true)
        await loadStandings()
    }

    public func roundChanged() async {
        await loadStandings()
    }

    public func loadStandings() async {
        isLoading = true
        errorMessage = nil

        do {
            if availableRounds.isEmpty {
                await loadRoundsForSelectedSeason(forceRefresh: false)
            }

            async let drivers = service.fetchDriverStandings(season: selectedSeason, round: selectedRound)
            async let constructors = service.fetchConstructorStandings(season: selectedSeason, round: selectedRound)
            driverStandings = try await drivers
            constructorStandings = try await constructors
        } catch {
            errorMessage = "Failed to load standings: \(error.localizedDescription)"
            driverStandings = []
            constructorStandings = []
        }

        isLoading = false
    }

    private func loadRoundsForSelectedSeason(forceRefresh: Bool) async {
        if !forceRefresh, lastLoadedSeason == selectedSeason, !availableRounds.isEmpty {
            return
        }

        do {
            let currentYear = Calendar.current.component(.year, from: Date())
            let now = Date()

            var seasonToLoad = selectedSeason
            var rounds = try await service.fetchRaceRounds(season: seasonToLoad)

            if latestCompletedRound(in: rounds, asOf: now) == nil, seasonToLoad == currentYear {
                let previousSeason = currentYear - 1
                let previousRounds = try await service.fetchRaceRounds(season: previousSeason)
                if latestCompletedRound(in: previousRounds, asOf: now) != nil {
                    seasonToLoad = previousSeason
                    rounds = previousRounds
                    selectedSeason = previousSeason
                }
            }

            availableRounds = rounds
            lastLoadedSeason = seasonToLoad

            if selectedRound == nil || forceRefresh {
                selectedRound = latestCompletedRound(in: rounds, asOf: now) ?? rounds.last?.round
            }
        } catch {
            availableRounds = []
            selectedRound = nil
            lastLoadedSeason = selectedSeason
        }
    }

    private func latestCompletedRound(in rounds: [F1RaceRound], asOf now: Date) -> Int? {
        let completed = rounds.filter { round in
            guard let raceDate = round.raceDate else { return false }
            return raceDate <= now
        }
        return completed.max(by: { $0.round < $1.round })?.round
    }
}
