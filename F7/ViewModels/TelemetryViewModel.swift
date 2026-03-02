import Foundation
import Combine

/// Main ViewModel that manages the incoming telemetry state
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

    public init() {
        print("[TelemetryViewModel] Initialized. Ready to bind to telemetry streams.")
        loadMockData()
        startRaceControlPolling()
        Task { await refreshRaceControlFeed() }
    }
    
    /// Populates the ViewModel with a realistic mock F1 grid for development/preview purposes.
    private func loadMockData() {
        let mockDrivers: [(number: Int, position: Int, interval: Double?, lastLap: Double?, bestLap: Double?, inPit: Bool)] = [
            (1,   1,  nil,    91.234, 90.876, false),  // VER
            (4,   2,  0.892,  91.456, 91.102, false),  // NOR
            (81,  3,  1.204,  91.789, 91.345, false),  // PIA
            (44,  4,  2.541,  92.012, 91.567, false),  // HAM
            (63,  5,  3.108,  92.234, 91.890, false),  // RUS
            (16,  6,  4.567,  92.456, 92.012, false),  // LEC
            (55,  7,  5.234,  92.678, 92.234, false),  // SAI
            (14,  8,  7.891,  93.012, 92.567, false),  // ALO
            (18,  9,  9.345,  93.234, 92.890, false),  // STR
            (10,  10, 11.234, 93.456, 93.012, false),  // GAS
            (31,  11, 12.567, 93.678, 93.234, false),  // OCO
            (23,  12, 14.891, 93.890, 93.456, false),  // ALB
            (2,   13, 16.234, 94.012, 93.678, false),  // SAR
            (27,  14, 18.567, 94.234, 93.890, false),  // HUL
            (20,  15, 20.123, 94.456, 94.012, false),  // MAG
            (22,  16, 22.456, 94.678, 94.234, false),  // TSU
            (30,  17, 24.789, 94.890, 94.456, true),   // LAW
            (77,  18, 27.123, 95.012, 94.678, false),  // BOT
            (24,  19, 29.456, 95.234, 94.890, false),  // ZHO
            (11,  20, 31.789, 95.456, 95.012, false),  // PER
        ]
        
        for driver in mockDrivers {
            let timing = TimingData(
                driverNumber: driver.number,
                position: driver.position,
                bestLapTime: driver.bestLap,
                lastLapTime: driver.lastLap,
                intervalToLeader: driver.interval,
                inPitLane: driver.inPit
            )
            timingDataByDriver[driver.number] = timing
        }
        
        print("[TelemetryViewModel] Loaded mock data for \(mockDrivers.count) drivers.")
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

        do {
            let messages = try await openF1Client.fetchRaceControlFeed(limit: 25)
            self.raceControlFeed = messages
            self.latestRaceControlMessage = messages.first
            if let first = messages.first {
                self.currentTrackStatus = mapTrackStatus(from: first)
            }

            // Also fetch latest weather and pitstops in parallel if possible, or sequentially here
            let weatherData = try await openF1Client.fetchWeather(sessionKey: "latest")
            self.weatherHistory = weatherData.sorted(by: { $0.date > $1.date })
            self.latestWeather = weatherHistory.first

            let pitStops = try await openF1Client.fetchPitStops(sessionKey: "latest")
            self.recentPitStops = pitStops.sorted(by: { $0.date > $1.date })

        } catch {
            print("[TelemetryViewModel] Failed to load OpenF1 data feeds: \(error.localizedDescription)")
        }

        isRaceControlLoading = false
    }

    private func startRaceControlPolling() {
        raceControlTimer?.invalidate()
        raceControlTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
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

    deinit {
        raceControlTimer?.invalidate()
    }
}
