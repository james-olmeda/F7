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
        guard let selectedRound else { return "Season Total" }
        if let race = availableRounds.first(where: { $0.round == selectedRound }) {
            return "R\(race.round): \(race.raceName)"
        }
        return "Round \(selectedRound)"
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
            let rounds = try await service.fetchRaceRounds(season: selectedSeason)
            availableRounds = rounds
            lastLoadedSeason = selectedSeason

            if selectedRound == nil || forceRefresh {
                selectedRound = rounds.last?.round
            }
        } catch {
            availableRounds = []
            selectedRound = nil
            lastLoadedSeason = selectedSeason
        }
    }
}
