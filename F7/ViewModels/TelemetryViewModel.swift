import Foundation
import Combine

/// Main ViewModel that manages the incoming telemetry state
@MainActor
@Observable
public final class TelemetryViewModel {
    
    // Marked with @ObservationIgnored if we don't want SwiftUI to track this specific property,
    // but the intention here is to expose reactive states for the UI.
    
    /// Global Circuit Safety Status
    public var currentTrackStatus: TrackStatus = .allClear
    
    /// Latest race control message
    public var latestRaceControlMessage: RaceControlMessage?

    /// Recent FIA race control feed from OpenF1.
    public var raceControlFeed: [RaceControlMessage] = []
    public var isRaceControlLoading: Bool = false

    /// Latest Weather from OpenF1
    public var latestWeather: OpenF1Weather?
    public var weatherHistory: [OpenF1Weather] = []

    /// Pit stops from OpenF1
    public var recentPitStops: [OpenF1PitStop] = []
    public var recentOvertakes: [OpenF1Overtake] = []
    public var recentTeamRadio: [OpenF1TeamRadio] = []
    public var latestIntervalsByDriver: [Int: OpenF1Interval] = [:]
    public var latestStintsByDriver: [Int: OpenF1Stint] = [:]

    /// Active OpenF1 session metadata
    public var activeSession: OpenF1Session?
    public var currentLap: Int?
    
    /// Telemetry data for specific drivers, keyed by Driver Number
    public var carDataByDriver: [Int: CarData] = [:]
    
    /// Timing loops and sector data, keyed by Driver Number
    public var timingDataByDriver: [Int: TimingData] = [:]
    
    /// The user-configured delay calibration offset in seconds (to sync visualization with video streams)
    public var visualizationDelayOffset: Double = 0.0
    
    // Dependencies injected via DIContainer
    // Example: private let signalRService = DIContainer.shared.resolve(type: SignalRServiceProtocol.self)
    private let openF1Client = OpenF1RestClient()
    private var raceControlTimer: Timer?
    private var refreshTick: Int = 0

    public init() {
        print("[TelemetryViewModel] Initialized. Ready to bind to telemetry streams.")
        startRaceControlPolling()
        Task { await refreshRaceControlFeed() }
    }
    
    // Methods to handle incoming decodings
    
    public func update(trackStatus newStatus: TrackStatus) {
        self.currentTrackStatus = newStatus
    }
    
    public func update(raceControlMessage newMessage: RaceControlMessage) {
        self.latestRaceControlMessage = newMessage
    }
    
    public func update(carData newData: CarData) {
        self.carDataByDriver[newData.driverNumber] = newData
    }
    
    public func update(timingData newData: TimingData) {
        self.timingDataByDriver[newData.driverNumber] = newData
    }

    public func refreshRaceControlFeed() async {
        isRaceControlLoading = true
        refreshTick += 1

        do {
            if activeSession == nil || refreshTick % 5 == 0 {
                let sessions = try await openF1Client.fetchSessions(sessionKey: "latest")
                guard let session = sessions.first else {
                    clearLiveStateForNoSession()
                    isRaceControlLoading = false
                    return
                }
                activeSession = session
            }

            guard let activeSession else {
                clearLiveStateForNoSession()
                isRaceControlLoading = false
                return
            }

            let sessionKey = String(activeSession.sessionKey)

            let shouldRefreshLocation = refreshTick % 2 == 0
            let shouldRefreshContextFeeds = refreshTick % 3 == 0
            await refreshLiveTimingData(
                sessionKey: sessionKey,
                includeLocation: shouldRefreshLocation
            )

            if shouldRefreshContextFeeds {
                let messages = try await openF1Client.fetchRaceControlFeed(limit: 25, sessionKey: sessionKey)
                self.raceControlFeed = messages
                self.latestRaceControlMessage = messages.first
                if let first = messages.first {
                    self.currentTrackStatus = mapTrackStatus(from: first)
                }

                let weatherData = try await openF1Client.fetchWeather(sessionKey: sessionKey)
                self.weatherHistory = weatherData.sorted(by: { $0.date > $1.date })
                self.latestWeather = weatherHistory.first

                let pitStops = try await openF1Client.fetchPitStops(sessionKey: sessionKey)
                self.recentPitStops = pitStops.sorted(by: { $0.date > $1.date })
            }

            let shouldRefreshExtendedFeeds = refreshTick % 4 == 0
            if shouldRefreshExtendedFeeds {
                await refreshExtendedLiveFeeds(sessionKey: sessionKey)
            }

        } catch {
            print("[TelemetryViewModel] Failed to load OpenF1 data feeds: \(error.localizedDescription)")
        }

        isRaceControlLoading = false
    }

    private func startRaceControlPolling() {
        raceControlTimer?.invalidate()
        raceControlTimer = Timer.scheduledTimer(withTimeInterval: 6.0, repeats: true) { [weak self] _ in
            Task { await self?.refreshRaceControlFeed() }
        }
    }

    private func mapTrackStatus(from message: RaceControlMessage) -> TrackStatus {
        let text = "\(message.flag ?? "") \(message.message)".lowercased()
        if text.contains("red") { return .redFlag }
        if text.contains("safety car") && !text.contains("virtual") { return .safetyCar }
        if text.contains("vsc") || text.contains("virtual safety car") {
            if text.contains("ending") || text.contains("end") {
                return .virtualSafetyCarEnding
            }
            return .virtualSafetyCar
        }
        if text.contains("yellow") { return .yellow }
        if text.contains("green") || text.contains("clear") { return .allClear }
        return currentTrackStatus
    }

    private func applyLatestLocationsToCarData(_ locations: [OpenF1Location]) {
        guard !locations.isEmpty else { return }

        var latestByDriver: [Int: OpenF1Location] = [:]
        for location in locations.sorted(by: { $0.date > $1.date }) {
            if latestByDriver[location.driverNumber] == nil {
                latestByDriver[location.driverNumber] = location
            }
            if latestByDriver.count >= 20 {
                break
            }
        }

        for (driverNumber, location) in latestByDriver {
            let existing = carDataByDriver[driverNumber]
            carDataByDriver[driverNumber] = CarData(
                id: existing?.id ?? UUID().uuidString,
                driverNumber: driverNumber,
                xCoordinate: location.x,
                yCoordinate: location.y,
                zCoordinate: location.z,
                speed: existing?.speed ?? 0,
                gear: existing?.gear ?? 0,
                rpm: existing?.rpm ?? 0,
                drsStatus: existing?.drsStatus ?? 0,
                brake: existing?.brake ?? 0,
                throttle: existing?.throttle ?? 0,
                timestamp: location.date
            )
        }
    }

    private func refreshLiveTimingData(sessionKey: String, includeLocation: Bool) async {
        var loadedSomething = false

        do {
            let positions = try await openF1Client.fetchPositions(sessionKey: sessionKey)
            applyLatestPositions(positions)
            loadedSomething = loadedSomething || !positions.isEmpty
        } catch {
            print("[TelemetryViewModel] Failed to load positions: \(error.localizedDescription)")
        }

        do {
            let laps = try await openF1Client.fetchLaps(sessionKey: sessionKey)
            applyLapTiming(laps)
            loadedSomething = loadedSomething || !laps.isEmpty
        } catch {
            print("[TelemetryViewModel] Failed to load laps: \(error.localizedDescription)")
        }

        do {
            let carSamples = try await openF1Client.fetchCarData(sessionKey: sessionKey)
            applyLatestCarSamples(carSamples)
            loadedSomething = loadedSomething || !carSamples.isEmpty
        } catch {
            print("[TelemetryViewModel] Failed to load car data: \(error.localizedDescription)")
        }

        if includeLocation {
            do {
                let locations = try await openF1Client.fetchLocation(sessionKey: sessionKey)
                applyLatestLocationsToCarData(locations)
                loadedSomething = loadedSomething || !locations.isEmpty
            } catch {
                print("[TelemetryViewModel] Failed to load locations: \(error.localizedDescription)")
            }
        }

        if !loadedSomething {
            print("[TelemetryViewModel] No live timing payloads available for session \(sessionKey).")
        }
    }

    private func applyLatestPositions(_ positions: [OpenF1Position]) {
        guard !positions.isEmpty else { return }

        var latestByDriver: [Int: OpenF1Position] = [:]
        for position in positions.sorted(by: { $0.date > $1.date }) {
            if latestByDriver[position.driverNumber] == nil {
                latestByDriver[position.driverNumber] = position
            }
            if latestByDriver.count >= 20 {
                break
            }
        }

        for (_, latest) in latestByDriver {
            let existing = timingDataByDriver[latest.driverNumber]
            timingDataByDriver[latest.driverNumber] = TimingData(
                id: existing?.id ?? "timing-\(latest.driverNumber)-\(latest.date.timeIntervalSince1970)",
                driverNumber: latest.driverNumber,
                position: latest.position,
                bestLapTime: existing?.bestLapTime,
                lastLapTime: existing?.lastLapTime,
                sector1Time: existing?.sector1Time,
                sector2Time: existing?.sector2Time,
                sector3Time: existing?.sector3Time,
                microSectors: existing?.microSectors ?? [],
                intervalToLeader: existing?.intervalToLeader,
                intervalToCarAhead: existing?.intervalToCarAhead,
                inPitLane: existing?.inPitLane ?? false,
                timestamp: latest.date
            )
        }
    }

    private func applyLapTiming(_ laps: [OpenF1Lap]) {
        guard !laps.isEmpty else { return }

        let grouped = Dictionary(grouping: laps, by: \.driverNumber)
        for (driverNumber, driverLaps) in grouped {
            let latestLap = driverLaps.max {
                if $0.lapNumber != $1.lapNumber {
                    return $0.lapNumber < $1.lapNumber
                }
                return ($0.dateStart ?? .distantPast) < ($1.dateStart ?? .distantPast)
            }

            let bestLap = driverLaps
                .compactMap(\.lapDuration)
                .min()

            let existing = timingDataByDriver[driverNumber]
            let latestTime = latestLap?.dateStart ?? existing?.timestamp ?? Date()
            let sectors = [
                latestLap?.segmentsSector1 ?? [],
                latestLap?.segmentsSector2 ?? [],
                latestLap?.segmentsSector3 ?? []
            ].flatMap { $0 }

            timingDataByDriver[driverNumber] = TimingData(
                id: existing?.id ?? "timing-\(driverNumber)-\(latestTime.timeIntervalSince1970)",
                driverNumber: driverNumber,
                position: existing?.position ?? 0,
                bestLapTime: bestLap ?? existing?.bestLapTime,
                lastLapTime: latestLap?.lapDuration ?? existing?.lastLapTime,
                sector1Time: latestLap?.durationSector1 ?? existing?.sector1Time,
                sector2Time: latestLap?.durationSector2 ?? existing?.sector2Time,
                sector3Time: latestLap?.durationSector3 ?? existing?.sector3Time,
                microSectors: sectors.isEmpty ? (existing?.microSectors ?? []) : sectors,
                intervalToLeader: existing?.intervalToLeader,
                intervalToCarAhead: existing?.intervalToCarAhead,
                inPitLane: latestLap?.isPitOutLap ?? existing?.inPitLane ?? false,
                timestamp: latestTime
            )
        }

        currentLap = laps.map(\.lapNumber).max()
    }

    private func applyLatestCarSamples(_ carSamples: [OpenF1CarData]) {
        guard !carSamples.isEmpty else { return }

        var latestByDriver: [Int: OpenF1CarData] = [:]
        for sample in carSamples.sorted(by: { $0.date > $1.date }) {
            if latestByDriver[sample.driverNumber] == nil {
                latestByDriver[sample.driverNumber] = sample
            }
            if latestByDriver.count >= 20 {
                break
            }
        }

        for (_, sample) in latestByDriver {
            let existing = carDataByDriver[sample.driverNumber]
            carDataByDriver[sample.driverNumber] = CarData(
                id: existing?.id ?? "car-\(sample.driverNumber)-\(sample.date.timeIntervalSince1970)",
                driverNumber: sample.driverNumber,
                xCoordinate: existing?.xCoordinate ?? 0.0,
                yCoordinate: existing?.yCoordinate ?? 0.0,
                zCoordinate: existing?.zCoordinate ?? 0.0,
                speed: sample.speed,
                gear: sample.gear,
                rpm: sample.rpm,
                drsStatus: sample.drs,
                brake: Double(sample.brake),
                throttle: Double(sample.throttle),
                timestamp: sample.date
            )
        }
    }

    private func refreshExtendedLiveFeeds(sessionKey: String) async {
        do {
            let intervals = try await openF1Client.fetchIntervals(sessionKey: sessionKey)
            applyLatestIntervals(intervals)
        } catch {
            print("[TelemetryViewModel] Failed to load intervals: \(error.localizedDescription)")
        }

        do {
            let stints = try await openF1Client.fetchStints(sessionKey: sessionKey)
            applyLatestStints(stints)
        } catch {
            print("[TelemetryViewModel] Failed to load stints: \(error.localizedDescription)")
        }

        do {
            let overtakes = try await openF1Client.fetchOvertakes(sessionKey: sessionKey)
            self.recentOvertakes = overtakes
                .sorted(by: { $0.timestamp > $1.timestamp })
        } catch {
            print("[TelemetryViewModel] Failed to load overtakes: \(error.localizedDescription)")
        }

        do {
            let radios = try await openF1Client.fetchTeamRadio(sessionKey: sessionKey)
            self.recentTeamRadio = radios.sorted(by: { $0.date > $1.date })
        } catch {
            print("[TelemetryViewModel] Failed to load team radio feed: \(error.localizedDescription)")
        }
    }

    private func applyLatestIntervals(_ intervals: [OpenF1Interval]) {
        guard !intervals.isEmpty else { return }

        var latestByDriver: [Int: OpenF1Interval] = [:]
        for item in intervals.sorted(by: { $0.date > $1.date }) {
            if latestByDriver[item.driverNumber] == nil {
                latestByDriver[item.driverNumber] = item
            }
        }
        latestIntervalsByDriver = latestByDriver

        for (driverNumber, latest) in latestByDriver {
            let existing = timingDataByDriver[driverNumber]
            guard let existing else { continue }
            timingDataByDriver[driverNumber] = TimingData(
                id: existing.id,
                driverNumber: driverNumber,
                position: existing.position,
                bestLapTime: existing.bestLapTime,
                lastLapTime: existing.lastLapTime,
                sector1Time: existing.sector1Time,
                sector2Time: existing.sector2Time,
                sector3Time: existing.sector3Time,
                microSectors: existing.microSectors,
                intervalToLeader: latest.gapToLeader,
                intervalToCarAhead: latest.interval,
                inPitLane: existing.inPitLane,
                timestamp: max(existing.timestamp, latest.date)
            )
        }
    }

    private func applyLatestStints(_ stints: [OpenF1Stint]) {
        guard !stints.isEmpty else { return }

        var latestByDriver: [Int: OpenF1Stint] = [:]
        for stint in stints {
            if let existing = latestByDriver[stint.driverNumber] {
                if stint.stintNumber > existing.stintNumber {
                    latestByDriver[stint.driverNumber] = stint
                } else if stint.stintNumber == existing.stintNumber, stint.lapEnd > existing.lapEnd {
                    latestByDriver[stint.driverNumber] = stint
                }
            } else {
                latestByDriver[stint.driverNumber] = stint
            }
        }
        latestStintsByDriver = latestByDriver
    }

    private func clearLiveStateForNoSession() {
        activeSession = nil
        currentLap = nil
        raceControlFeed = []
        latestRaceControlMessage = nil
        latestWeather = nil
        weatherHistory = []
        recentPitStops = []
        recentOvertakes = []
        recentTeamRadio = []
        latestIntervalsByDriver = [:]
        latestStintsByDriver = [:]
        timingDataByDriver = [:]
        carDataByDriver = [:]
    }

    deinit {}
}
