import SwiftUI
import AVFoundation

/// Root view with TabView navigation for the full app experience.
public struct RaceDashboardView: View {
    
    @Environment(TelemetryViewModel.self) private var telemetryVM
    @Environment(ContentBrowserViewModel.self) private var contentBrowserVM
    @Environment(VideoPlayerViewModel.self) private var videoPlayerVM
    @Environment(F1NewsViewModel.self) private var newsVM
    @Environment(AuthViewModel.self) private var authVM
    
    public var body: some View {
        TabView {
            NewsTab()
                .environment(newsVM)
                .tabItem {
                    Label("News", systemImage: "newspaper")
                }

            LiveTimingTab()
                .environment(telemetryVM)
                .tabItem {
                    Label("Live", systemImage: "antenna.radiowaves.left.and.right")
                }

            CalendarTab()
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }
            
            F1TVTab()
                .environment(contentBrowserVM)
                .environment(videoPlayerVM)
                .environment(telemetryVM)
                .tabItem {
                    Label("F1TV", systemImage: "play.tv")
                }
            
            StandingsTab()
                .environment(telemetryVM)
                .tabItem {
                    Label("Standings", systemImage: "list.number")
                }
            
            PredictionsTab()
                .environment(telemetryVM)
                .tabItem {
                    Label("Predictions", systemImage: "brain.head.profile")
                }
            
            SettingsTab()
                .environment(authVM)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .tint(.appAccent)
    }
}

// MARK: - F1TV Tab
struct F1TVTab: View {
    var body: some View {
        NavigationStack {
            ContentBrowserView()
        }
    }
}

// MARK: - News Tab
struct NewsTab: View {
    var body: some View {
        NavigationStack {
            F1NewsView()
        }
    }
}

// MARK: - Calendar Tab
struct CalendarTab: View {
    @State private var selectedSeason: Int = Calendar.current.component(.year, from: Date())
    @State private var rounds: [F1RaceRound] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let standingsService = F1StandingsService()
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    private var availableSeasons: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Array((1950...currentYear).reversed())
    }

    private var today: Date {
        Calendar.current.startOfDay(for: Date())
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                HStack {
                    Picker("Season", selection: $selectedSeason) {
                        ForEach(availableSeasons, id: \.self) { season in
                            Text(String(season)).tag(season)
                        }
                    }
                    .pickerStyle(.menu)

                    Spacer()
                }
                .padding(.horizontal, 16)

                if isLoading {
                    Spacer()
                    ProgressView("Loading calendar...")
                    Spacer()
                } else if let errorMessage {
                    Spacer()
                    Text(errorMessage)
                        .font(.inter(.subheadline))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    Spacer()
                } else {
                    List {
                        ForEach(rounds) { round in
                            HStack(spacing: 12) {
                                Text("R\(round.round)")
                                    .font(.inter(.caption, weight: .bold))
                                    .foregroundColor(.secondary)
                                    .frame(width: 36, alignment: .leading)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(round.raceName)
                                        .font(.inter(.body, weight: .semibold))
                                        .foregroundColor(.primary)
                                    Text("\(round.circuitName) • \(round.locality), \(round.country)")
                                        .font(.inter(.caption))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                    NavigationLink(value: round) {
                                        Text("\(dateText(for: round)) • \(relativeText(for: round))")
                                            .font(.inter(.caption))
                                            .foregroundColor(.appAccent)
                                    }
                                }

                                Spacer()

                                Text(statusText(for: round))
                                    .font(.inter(.caption2, weight: .bold))
                                    .foregroundColor(statusColor(for: round))
                            }
                            .padding(.vertical, 4)
                            .listRowBackground(Color(.secondarySystemBackground))
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color(.systemBackground))
                }
            }
            .background(Color(.systemBackground).ignoresSafeArea())
            .navigationTitle("Calendar")
            .navigationDestination(for: F1RaceRound.self) { round in
                CalendarRaceDetailView(
                    round: round,
                    season: selectedSeason,
                    dateFormatter: dateFormatter,
                    statusText: statusText(for: round),
                    relativeText: relativeText(for: round)
                )
            }
            .task(id: selectedSeason) {
                await loadCalendar()
            }
        }
    }

    private func loadCalendar() async {
        isLoading = true
        errorMessage = nil

        do {
            let fetched = try await standingsService.fetchRaceRounds(season: selectedSeason)
            rounds = fetched.sorted(by: { $0.round < $1.round })
        } catch {
            rounds = []
            errorMessage = "Could not load race calendar."
        }

        isLoading = false
    }

    private func dateText(for round: F1RaceRound) -> String {
        guard let raceDate = round.raceDate else { return "Date TBC" }
        return dateFormatter.string(from: raceDate)
    }

    private func statusText(for round: F1RaceRound) -> String {
        guard let raceDate = round.raceDate else { return "TBC" }
        return raceDate <= today ? "COMPLETED" : "UPCOMING"
    }

    private func statusColor(for round: F1RaceRound) -> Color {
        guard let raceDate = round.raceDate else { return .secondary }
        return raceDate <= today ? .secondary : .appAccent
    }

    private func relativeText(for round: F1RaceRound) -> String {
        guard let raceDate = round.raceDate else { return "Date TBC" }
        let raceStart = Calendar.current.startOfDay(for: raceDate)
        let dayDelta = Calendar.current.dateComponents([.day], from: today, to: raceStart).day ?? 0

        if dayDelta == 0 { return "Today" }
        if dayDelta > 0 { return "in \(dayDelta)d" }
        return "\(-dayDelta)d ago"
    }
}

private struct CalendarRaceDetailView: View {
    let round: F1RaceRound
    let season: Int
    let dateFormatter: DateFormatter
    let statusText: String
    let relativeText: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                detailRow(title: "Season", value: "\(season)")
                detailRow(title: "Round", value: "R\(round.round)")
                detailRow(title: "Grand Prix", value: round.raceName)
                detailRow(title: "Circuit", value: round.circuitName)
                detailRow(title: "Location", value: "\(round.locality), \(round.country)")
                detailRow(title: "Race Date", value: round.raceDate.map { dateFormatter.string(from: $0) } ?? "Date TBC")
                detailRow(title: "Status", value: statusText)
                detailRow(title: "Relative", value: relativeText)

                VStack(spacing: 10) {
                    Link(destination: URL(string: "https://tickets.formula1.com/en")!) {
                        Label("Buy Tickets (Official F1)", systemImage: "ticket.fill")
                            .font(.inter(.subheadline, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.appAccent)

                    if let searchURL = ticketSearchURL {
                        Link(destination: searchURL) {
                            Label("Find \(round.raceName) Tickets", systemImage: "safari")
                                .font(.inter(.subheadline, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding(16)
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .navigationTitle(round.raceName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var ticketSearchURL: URL? {
        var components = URLComponents(string: "https://www.google.com/search")
        components?.queryItems = [
            URLQueryItem(name: "q", value: "\(season) \(round.raceName) tickets")
        ]
        return components?.url
    }

    private func detailRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.inter(.caption2, weight: .bold))
                .foregroundColor(.secondary)

            Text(value)
                .font(.inter(.body, weight: .semibold))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Live Timing Tab
struct LiveTimingTab: View {
    @Environment(TelemetryViewModel.self) private var telemetryVM

    private var sortedDrivers: [TimingData] {
        telemetryVM.timingDataByDriver.values.sorted { $0.position < $1.position }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color(.systemBackground).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        // Track Status Banner
                        TrackStatusBanner(status: telemetryVM.currentTrackStatus)

                        // Session Info Header
                        SessionInfoHeader()
                            .padding(.horizontal)
                            .padding(.top, 8)

                        LiveMapPanel(drivers: sortedDrivers, carDataByDriver: telemetryVM.carDataByDriver)
                            .padding(.horizontal, 12)
                            .padding(.top, 8)

                        if let weather = telemetryVM.latestWeather {
                            WeatherWidget(weather: weather)
                                .padding(.horizontal, 12)
                                .padding(.top, 8)
                        }

                        RaceControlFeedPanel()
                            .environment(telemetryVM)
                            .padding(.horizontal, 12)
                            .padding(.top, 8)

                        TeamRadioLivePanel()
                            .environment(telemetryVM)
                            .padding(.horizontal, 12)
                            .padding(.top, 8)

                        LiveEventsPanel()
                            .environment(telemetryVM)
                            .padding(.horizontal, 12)
                            .padding(.top, 8)

                        TyreStintsPanel()
                            .environment(telemetryVM)
                            .padding(.horizontal, 12)
                            .padding(.top, 8)

                        // Timing Tower
                        LazyVStack(spacing: 0) {
                            ForEach(sortedDrivers) { driverTiming in
                                NavigationLink(value: driverTiming) {
                                    LapTimeRowView(timingData: driverTiming)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                        .padding(.bottom, 16)
                    }
                }
            }
            .navigationTitle("GRAND PRIX LIVE")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Circle()
                        .fill(Color.appAccent)
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle()
                                .fill(Color.appAccent.opacity(0.4))
                                .frame(width: 16, height: 16)
                        )
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Text(liveStatusText)
                        .font(.inter(.caption, design: .monospaced, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            .navigationDestination(for: TimingData.self) { timingData in
                LiveDriverDetailView(driverNumber: timingData.driverNumber, fallbackTimingData: timingData)
                    .environment(telemetryVM)
            }
        }
    }

    private var liveStatusText: String {
        if let lap = telemetryVM.currentLap {
            return "LAP \(lap)"
        }
        if let session = telemetryVM.activeSession {
            return session.sessionName.uppercased()
        }
        return "NO LIVE SESSION"
    }
}

fileprivate struct LiveDriverDetailView: View {
    @Environment(TelemetryViewModel.self) private var telemetryVM

    let driverNumber: Int
    let fallbackTimingData: TimingData

    @State private var teamRadios: [OpenF1TeamRadio] = []
    @State private var isLoadingTeamRadio = false
    @State private var teamRadioError: String?
    @State private var player: AVPlayer?
    @State private var playingRadioID: String?

    private let openF1Client = OpenF1RestClient()

    private var driverInfo: DriverInfo? {
        DriverInfo.all[driverNumber]
    }

    private var timingData: TimingData {
        telemetryVM.timingDataByDriver[driverNumber] ?? fallbackTimingData
    }

    private var carData: CarData? {
        telemetryVM.carDataByDriver[driverNumber]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                headerCard
                telemetryCard
                teamRadioCard
            }
            .padding(16)
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .navigationTitle(driverInfo?.abbreviation ?? "#\(driverNumber)")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: driverNumber) {
            await loadTeamRadio()
        }
        .onDisappear {
            player?.pause()
            playingRadioID = nil
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(driverInfo?.fullName ?? "Driver #\(driverNumber)")
                    .font(.inter(.title2, design: .rounded, weight: .bold))
                    .foregroundColor(.primary)

                Spacer()

                Text("P\(timingData.position)")
                    .font(.inter(.headline, design: .rounded, weight: .bold))
                    .foregroundColor(.primary)
            }

            Text(driverInfo?.teamName ?? "Unknown Team")
                .font(.inter(.subheadline))
                .foregroundColor(.secondary)
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var telemetryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Live Telemetry")
                .font(.inter(.headline, design: .default, weight: .bold))
                .foregroundColor(.primary)

            HStack(spacing: 10) {
                detailPill(title: "LAST", value: lapText(timingData.lastLapTime))
                detailPill(title: "BEST", value: lapText(timingData.bestLapTime))
                detailPill(title: "GAP", value: gapText(timingData.intervalToLeader))
            }

            HStack(spacing: 10) {
                detailPill(title: "SPEED", value: carData.map { "\($0.speed) km/h" } ?? "-")
                detailPill(title: "GEAR", value: carData.map { "\($0.gear)" } ?? "-")
                detailPill(title: "RPM", value: carData.map { "\($0.rpm)" } ?? "-")
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private var teamRadioCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Team Radio Feed")
                    .font(.inter(.headline, design: .default, weight: .bold))
                    .foregroundColor(.primary)

                Spacer()

                if isLoadingTeamRadio {
                    ProgressView()
                        .controlSize(.small)
                }

                Button {
                    Task { await loadTeamRadio() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .foregroundColor(.secondary)
            }

            if let teamRadioError {
                Text(teamRadioError)
                    .font(.inter(.caption))
                    .foregroundColor(.secondary)
            } else if teamRadios.isEmpty && !isLoadingTeamRadio {
                Text("No team radio clips available for this driver.")
                    .font(.inter(.subheadline))
                    .foregroundColor(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(teamRadios.prefix(8).enumerated()), id: \.element.id) { index, radio in
                        Button {
                            togglePlayback(for: radio)
                        } label: {
                            HStack(alignment: .center, spacing: 10) {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(playingRadioID == radio.id ? Color.red.opacity(0.2) : Color(.tertiarySystemFill))
                                    .frame(width: 34, height: 26)
                                    .overlay {
                                        Text("RAD")
                                            .font(.inter(size: 10, weight: .bold, design: .rounded))
                                            .foregroundColor(playingRadioID == radio.id ? .red : .secondary)
                                    }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Race engineer comms")
                                        .font(.inter(.subheadline, weight: .semibold))
                                        .foregroundColor(.primary)
                                    Text(shortTime(radio.date))
                                        .font(.inter(.caption))
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Text(playingRadioID == radio.id ? "STOP" : "LISTEN")
                                    .font(.inter(.caption2, design: .rounded, weight: .bold))
                                    .foregroundColor(playingRadioID == radio.id ? .red : .appAccent)
                            }
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)

                        if index < min(teamRadios.count, 8) - 1 {
                            Divider().overlay(Color(.separator))
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func detailPill(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.inter(.caption2))
                .foregroundColor(.secondary)
            Text(value)
                .font(.inter(.caption, design: .monospaced, weight: .bold))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private func lapText(_ value: Double?) -> String {
        guard let value else { return "-" }
        let mins = Int(value) / 60
        let secs = value - Double(mins * 60)
        return String(format: "%d:%06.3f", mins, secs)
    }

    private func gapText(_ value: Double?) -> String {
        guard let value else { return "LEADER" }
        return String(format: "+%.3f", value)
    }

    private func shortTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }

    private func togglePlayback(for radio: OpenF1TeamRadio) {
        if playingRadioID == radio.id {
            player?.pause()
            playingRadioID = nil
            return
        }
        play(radio: radio)
    }

    private func play(radio: OpenF1TeamRadio) {
        guard let url = URL(string: radio.recordingUrl) else { return }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Continue even if the audio session fails; player may still work depending on route.
        }

        player?.pause()
        player = AVPlayer(url: url)
        player?.play()
        playingRadioID = radio.id
    }

    private func loadTeamRadio() async {
        isLoadingTeamRadio = true
        teamRadioError = nil

        do {
            let all = try await openF1Client.fetchTeamRadio(sessionKey: "latest")
            let filtered = all
                .filter { $0.driverNumber == driverNumber }
                .sorted(by: { $0.date > $1.date })
            teamRadios = filtered
        } catch {
            teamRadioError = "Could not load team radio clips right now."
        }

        isLoadingTeamRadio = false
    }
}

// MARK: - Session Info Header
fileprivate struct SessionInfoHeader: View {
    @Environment(TelemetryViewModel.self) private var telemetryVM

    private var sortedDrivers: [TimingData] {
        telemetryVM.timingDataByDriver.values.sorted(by: { $0.position < $1.position })
    }

    private var leaderCode: String {
        guard let leader = sortedDrivers.first else { return "---" }
        return DriverInfo.all[leader.driverNumber]?.abbreviation ?? "#\(leader.driverNumber)"
    }

    private var fastestLapText: String {
        let best = sortedDrivers.compactMap(\.bestLapTime).min()
        guard let best else { return "-" }
        let mins = Int(best) / 60
        let secs = best - Double(mins * 60)
        return String(format: "%d:%06.3f", mins, secs)
    }

    private var drsText: String {
        let active = telemetryVM.carDataByDriver.values.contains { $0.drsStatus > 0 }
        return active ? "ENABLED" : "OFF"
    }

    private var sessionTitle: String {
        if let session = telemetryVM.activeSession {
            return "\(session.countryName) Grand Prix \(session.year)"
        }
        return "No Active Session"
    }

    private var sessionTypeText: String {
        telemetryVM.activeSession?.sessionType.uppercased() ?? "OFFLINE"
    }

    private var circuitText: String {
        telemetryVM.activeSession?.circuitShortName ?? "-"
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("FORMULA 1")
                        .font(.inter(.caption2, design: .default, weight: .bold))
                        .foregroundColor(.appAccent)
                    Text(sessionTitle)
                        .font(.inter(.title3, design: .default, weight: .bold))
                        .foregroundColor(.primary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(sessionTypeText)
                        .font(.inter(.caption2, design: .default, weight: .bold))
                        .foregroundColor(.green)
                    Text(circuitText)
                        .font(.inter(.caption, design: .default, weight: .regular))
                        .foregroundColor(.secondary)
                }
            }
            
            // Gap/Speed quick stats
            HStack(spacing: 16) {
                StatPill(label: "LEADER", value: leaderCode, color: .primary)
                StatPill(label: "FASTEST", value: fastestLapText, color: .purple)
                StatPill(label: "DRS", value: drsText, color: .green)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

fileprivate struct StatPill: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.inter(.caption2, design: .default, weight: .medium))
                .foregroundColor(.secondary)
            Text(value)
                .font(.inter(.caption, design: .monospaced, weight: .bold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }
}

fileprivate struct LiveMapPanel: View {
    let drivers: [TimingData]
    let carDataByDriver: [Int: CarData]

    private var topDrivers: [TimingData] {
        Array(drivers.prefix(10))
    }

    private var leaderCode: String {
        guard let leader = drivers.first else { return "---" }
        return DriverInfo.all[leader.driverNumber]?.abbreviation ?? "#\(leader.driverNumber)"
    }

    private var gapToP2: String {
        guard drivers.count > 1 else { return "-" }
        if let gap = drivers[1].intervalToLeader {
            return String(format: "+%.3f", gap)
        }
        return "-"
    }

    private var averageTop5LastLap: String {
        let samples = drivers.prefix(5).compactMap(\.lastLapTime)
        guard !samples.isEmpty else { return "-" }
        let avg = samples.reduce(0, +) / Double(samples.count)
        let minutes = Int(avg) / 60
        let seconds = avg - Double(minutes * 60)
        return String(format: "%d:%06.3f", minutes, seconds)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Live Map")
                .font(.inter(.headline, design: .default, weight: .bold))
                .foregroundColor(.primary)

            GeometryReader { proxy in
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(.secondarySystemBackground))

                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.separator), style: StrokeStyle(lineWidth: 1, dash: [6, 5]))
                        .padding(18)

                    ForEach(Array(topDrivers.enumerated()), id: \.element.id) { index, driver in
                        let point = markerPoint(for: driver, in: proxy.size)
                        Circle()
                            .fill(driverColor(driver))
                            .frame(width: 12, height: 12)
                            .overlay(Circle().stroke(Color(.separator), lineWidth: 1))
                            .position(point)

                        Text(driverLabel(driver, index: index))
                            .font(.inter(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color(.systemBackground).opacity(0.8))
                            .cornerRadius(4)
                            .position(x: point.x, y: max(10, point.y - 14))
                    }
                }
            }
            .frame(height: 210)

            HStack(spacing: 8) {
                StatPill(label: "LEADER", value: leaderCode, color: .primary)
                StatPill(label: "GAP P2", value: gapToP2, color: .yellow)
                StatPill(label: "AVG TOP5", value: averageTop5LastLap, color: .green)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func markerPoint(for driver: TimingData, in size: CGSize) -> CGPoint {
        if let coordinate = normalizedCoordinate(for: driver.driverNumber) {
            let inset: CGFloat = 24
            let x = inset + coordinate.x * (size.width - inset * 2)
            let y = inset + coordinate.y * (size.height - inset * 2)
            return CGPoint(x: x, y: y)
        }

        let orderedPosition = max(driver.position, 1)
        let normalized = Double(orderedPosition - 1) / Double(max(topDrivers.count, 1))
        let angle = (normalized * 2.0 * .pi) - (.pi / 2.0)
        let inset: CGFloat = 42
        let rx = (size.width / 2) - inset
        let ry = (size.height / 2) - inset

        let x = (size.width / 2) + CGFloat(cos(angle)) * rx
        let y = (size.height / 2) + CGFloat(sin(angle)) * ry
        return CGPoint(x: x, y: y)
    }

    private func normalizedCoordinate(for driverNumber: Int) -> CGPoint? {
        let locationPoints = topDrivers.compactMap { timing -> (Int, Double, Double)? in
            guard let car = carDataByDriver[timing.driverNumber] else { return nil }
            return (timing.driverNumber, car.xCoordinate, car.yCoordinate)
        }

        guard !locationPoints.isEmpty else { return nil }
        guard let point = locationPoints.first(where: { $0.0 == driverNumber }) else { return nil }

        let xs = locationPoints.map(\.1)
        let ys = locationPoints.map(\.2)
        guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else {
            return nil
        }

        let dx = max(maxX - minX, 1)
        let dy = max(maxY - minY, 1)

        let normalizedX = (point.1 - minX) / dx
        let normalizedY = (point.2 - minY) / dy

        return CGPoint(x: normalizedX, y: 1 - normalizedY)
    }

    private func driverColor(_ driver: TimingData) -> Color {
        DriverInfo.all[driver.driverNumber]?.teamColor ?? .gray
    }

    private func driverLabel(_ driver: TimingData, index: Int) -> String {
        let code = DriverInfo.all[driver.driverNumber]?.abbreviation ?? "#\(driver.driverNumber)"
        return "P\(driver.position) \(code)"
    }
}

fileprivate struct RaceControlFeedPanel: View {
    @Environment(TelemetryViewModel.self) private var telemetryVM

    private var items: [RaceControlMessage] {
        Array(telemetryVM.raceControlFeed.prefix(6))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Race Control")
                    .font(.inter(.headline, design: .default, weight: .bold))
                    .foregroundColor(.primary)

                Spacer()

                if telemetryVM.isRaceControlLoading {
                    ProgressView()
                        .controlSize(.small)
                }

                Button {
                    Task { await telemetryVM.refreshRaceControlFeed() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .foregroundColor(.secondary)
            }

            if items.isEmpty {
                Text("No hay mensajes recientes.")
                    .font(.inter(.caption))
                    .foregroundColor(.secondary)
            } else {
                ForEach(items) { message in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(categoryColor(message.category))
                            .frame(width: 8, height: 8)
                            .padding(.top, 5)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(categoryLabel(message.category))
                                    .font(.inter(.caption2))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(timeString(message.timestamp))
                                    .font(.inter(.caption2))
                                    .foregroundColor(.secondary)
                            }
                            Text(message.message)
                                .font(.inter(.caption))
                                .foregroundColor(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func categoryLabel(_ category: RaceControlCategory) -> String {
        switch category {
        case .flag: return "Flag"
        case .penalty: return "Penalty"
        case .safetyCar: return "Safety Car"
        case .trackLimits: return "Track Limits"
        case .information: return "Info"
        case .unknown: return "Unknown"
        }
    }

    private func categoryColor(_ category: RaceControlCategory) -> Color {
        switch category {
        case .flag: return .yellow
        case .penalty: return .red
        case .safetyCar: return .orange
        case .trackLimits: return .blue
        case .information: return .green
        case .unknown: return .gray
        }
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

fileprivate struct TeamRadioLivePanel: View {
    @Environment(TelemetryViewModel.self) private var telemetryVM

    private var items: [OpenF1TeamRadio] {
        Array(telemetryVM.recentTeamRadio.prefix(6))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Team Radio")
                .font(.inter(.headline, design: .default, weight: .bold))
                .foregroundColor(.primary)

            if items.isEmpty {
                Text("No radio clips published yet.")
                    .font(.inter(.caption))
                    .foregroundColor(.secondary)
            } else {
                ForEach(items) { item in
                    HStack(spacing: 8) {
                        Text(driverCode(item.driverNumber))
                            .font(.inter(.caption, design: .rounded, weight: .bold))
                            .foregroundColor(.primary)
                            .frame(width: 36, alignment: .leading)

                        Text(shortTime(item.date))
                            .font(.inter(.caption))
                            .foregroundColor(.secondary)

                        Spacer()

                        Image(systemName: "waveform")
                            .font(.inter(.caption2))
                            .foregroundColor(.appAccent)
                    }
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func driverCode(_ number: Int) -> String {
        DriverInfo.all[number]?.abbreviation ?? "#\(number)"
    }

    private func shortTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

fileprivate struct LiveEventsPanel: View {
    @Environment(TelemetryViewModel.self) private var telemetryVM

    private var overtakes: [OpenF1Overtake] {
        Array(telemetryVM.recentOvertakes.prefix(5))
    }

    private var pitStops: [OpenF1PitStop] {
        Array(telemetryVM.recentPitStops.prefix(5))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Live Events")
                .font(.inter(.headline, design: .default, weight: .bold))
                .foregroundColor(.primary)

            if overtakes.isEmpty && pitStops.isEmpty {
                Text("No overtakes or pit stops yet.")
                    .font(.inter(.caption))
                    .foregroundColor(.secondary)
            } else {
                ForEach(overtakes) { event in
                    HStack(spacing: 8) {
                        Text("OVERTAKE")
                            .font(.inter(.caption2, weight: .bold))
                            .foregroundColor(.appAccent)
                            .frame(width: 62, alignment: .leading)

                        Text("\(driverCode(event.driverNumber)) > \(driverCode(event.overtakenDriverNumber))")
                            .font(.inter(.caption, weight: .semibold))
                            .foregroundColor(.primary)

                        Spacer()

                        Text(shortTime(event.timestamp))
                            .font(.inter(.caption2))
                            .foregroundColor(.secondary)
                    }
                }

                ForEach(pitStops) { pit in
                    HStack(spacing: 8) {
                        Text("PIT")
                            .font(.inter(.caption2, weight: .bold))
                            .foregroundColor(.orange)
                            .frame(width: 62, alignment: .leading)

                        let durationText = pit.pitDuration.map { String(format: "%.2fs", $0) } ?? "-"
                        Text("\(driverCode(pit.driverNumber)) L\(pit.lapNumber) • \(durationText)")
                            .font(.inter(.caption, weight: .semibold))
                            .foregroundColor(.primary)

                        Spacer()

                        Text(shortTime(pit.date))
                            .font(.inter(.caption2))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func driverCode(_ number: Int) -> String {
        DriverInfo.all[number]?.abbreviation ?? "#\(number)"
    }

    private func shortTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

fileprivate struct TyreStintsPanel: View {
    @Environment(TelemetryViewModel.self) private var telemetryVM

    private var rows: [(TimingData, OpenF1Stint)] {
        telemetryVM.timingDataByDriver.values
            .sorted(by: { $0.position < $1.position })
            .compactMap { timing in
                guard let stint = telemetryVM.latestStintsByDriver[timing.driverNumber] else { return nil }
                return (timing, stint)
            }
            .prefix(8)
            .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tyre Stints")
                .font(.inter(.headline, design: .default, weight: .bold))
                .foregroundColor(.primary)

            if rows.isEmpty {
                Text("No stint data available yet.")
                    .font(.inter(.caption))
                    .foregroundColor(.secondary)
            } else {
                ForEach(rows, id: \.0.id) { timing, stint in
                    HStack(spacing: 8) {
                        Text("P\(timing.position)")
                            .font(.inter(.caption, design: .rounded, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(width: 30, alignment: .leading)

                        Text(DriverInfo.all[timing.driverNumber]?.abbreviation ?? "#\(timing.driverNumber)")
                            .font(.inter(.caption, weight: .bold))
                            .foregroundColor(.primary)
                            .frame(width: 36, alignment: .leading)

                        Text(stint.compound?.uppercased() ?? "UNKNOWN")
                            .font(.inter(.caption2, weight: .bold))
                            .foregroundColor(.primary)
                            .frame(width: 70, alignment: .leading)

                        Text("L\(stint.lapStart)-L\(stint.lapEnd)")
                            .font(.inter(.caption2))
                            .foregroundColor(.secondary)

                        Spacer()

                        if let age = stint.tyreAgeAtStart {
                            Text("Age \(age)")
                                .font(.inter(.caption2))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Weather Widget
fileprivate struct WeatherWidget: View {
    let weather: OpenF1Weather
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: weatherIcon(rainfall: weather.rainfall))
                .font(.inter(size: 32))
                .foregroundColor(.primary)
                
            VStack(alignment: .leading, spacing: 4) {
                Text("Air: \(String(format: "%.1f", weather.airTemperature))°C")
                    .font(.inter(.caption))
                    .foregroundColor(.secondary)
                Text("Track: \(String(format: "%.1f", weather.trackTemperature))°C")
                    .font(.inter(.caption))
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("Wind: \(String(format: "%.1f", weather.windSpeed)) m/s")
                    .font(.inter(.caption))
                    .foregroundColor(.secondary)
                Text("Rainfall: \(weather.rainfall == 1 ? "Yes" : "No")")
                    .font(.inter(.caption))
                    .foregroundColor(weather.rainfall == 1 ? .blue : .secondary)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private func weatherIcon(rainfall: Int) -> String {
        return rainfall == 1 ? "cloud.rain" : "sun.max"
    }
}

// MARK: - Standings Tab
struct StandingsTab: View {
    private enum StandingsDisplayMode: String, CaseIterable {
        case standings = "Standings"
        case results = "Results"
    }

    private enum ResultSessionFilter: String, CaseIterable {
        case race = "Race Result"
        case qualifying = "Qualifying"
        case practice = "Practice"
        case sprint = "Sprint"
        case all = "All Sessions"

        func matches(_ summary: WeekendSessionSummary) -> Bool {
            let value = "\(summary.sessionName) \(summary.sessionType)".lowercased()
            switch self {
            case .race:
                return value.contains("race") && !value.contains("sprint")
            case .qualifying:
                return value.contains("qualifying")
            case .practice:
                return value.contains("practice")
            case .sprint:
                return value.contains("sprint") || value.contains("shootout")
            case .all:
                return true
            }
        }
    }

    @Environment(StandingsViewModel.self) private var standingsVM
    @State private var headshotsByNumber: [Int: URL] = [:]
    @State private var headshotsByCode: [String: URL] = [:]
    @State private var headshotsByName: [String: URL] = [:]
    @State private var weekendSessionResults: [WeekendSessionSummary] = []
    @State private var isLoadingWeekendResults = false
    @State private var weekendResultsError: String?
    @State private var lastWeekendResultsKey: String?
    @State private var selectedDisplayMode: StandingsDisplayMode = .results
    @State private var selectedSessionFilter: ResultSessionFilter = .race

    private let openF1Client = OpenF1RestClient()

    var body: some View {
        NavigationStack {
            @Bindable var vm = standingsVM

            VStack(spacing: 12) {
                VStack(spacing: 8) {
                    HStack {
                        Text("\(vm.selectedSeason) SEASON")
                            .font(.inter(.headline, weight: .bold))
                            .foregroundColor(.primary)

                        Spacer()

                        Picker("View", selection: $selectedDisplayMode) {
                            ForEach(StandingsDisplayMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    Rectangle()
                        .fill(Color.appAccent)
                        .frame(height: 3)
                }
                .padding(.horizontal, 16)

                HStack(spacing: 12) {
                    Picker("Season", selection: $vm.selectedSeason) {
                        ForEach(vm.availableSeasons, id: \.self) { season in
                            Text(String(season)).tag(season)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("Grand Prix", selection: $vm.selectedRound) {
                        ForEach(vm.availableRounds) { round in
                            Text(round.raceName).tag(Optional(round.round))
                        }
                    }
                    .pickerStyle(.menu)

                    if selectedDisplayMode == .results {
                        Picker("Session", selection: $selectedSessionFilter) {
                            ForEach(ResultSessionFilter.allCases, id: \.self) { filter in
                                Text(filter.rawValue).tag(filter)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
                .padding(.horizontal, 16)

                Text(vm.selectedRoundLabel)
                    .font(.inter(.caption))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)

                if selectedDisplayMode == .standings {
                    Picker("Category", selection: $vm.selectedCategory) {
                        ForEach(StandingsViewModel.Category.allCases, id: \.self) { category in
                            Text(category.rawValue).tag(category)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                }

                if selectedDisplayMode == .results {
                    weekendResultsSection
                        .padding(.horizontal, 16)
                }

                if vm.isLoading {
                    Spacer()
                    ProgressView("Loading standings...")
                    Spacer()
                } else if let error = vm.errorMessage {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .font(.inter(.title))
                        Text(error)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            Task { await vm.loadStandings() }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.horizontal, 24)
                    Spacer()
                } else if selectedDisplayMode == .standings {
                    List {
                        if vm.selectedCategory == .drivers {
                            ForEach(vm.driverStandings) { standing in
                                NavigationLink(value: standing) {
                                    DriverStandingRow(
                                        standing: standing,
                                        imageURL: headshotURL(for: standing)
                                    )
                                }
                                .listRowBackground(Color(.secondarySystemBackground))
                            }
                        } else {
                            ForEach(vm.constructorStandings) { standing in
                                ConstructorStandingRow(standing: standing)
                                    .listRowBackground(Color(.secondarySystemBackground))
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color(.systemBackground))
                } else {
                    Spacer(minLength: 0)
                }
            }
            .background(Color(.systemBackground).ignoresSafeArea())
            .navigationTitle("Standings")
            .navigationDestination(for: DriverStanding.self) { standing in
                DriverProfileView(
                    standing: standing,
                    headshotURL: headshotURL(for: standing),
                    season: vm.selectedSeason
                )
            }
            .task(id: vm.selectedSeason) { await vm.seasonChanged() }
            .task(id: vm.selectedRound ?? -1) { await vm.roundChanged() }
            .task(id: "\(vm.selectedSeason)-\(vm.selectedRound ?? -1)") {
                await loadWeekendResults(for: vm)
            }
            .task {
                await loadHeadshotsIfNeeded()
            }
        }
    }

    @ViewBuilder
    private var weekendResultsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(selectedRoundTitle)
                    .font(.inter(.title2, design: .rounded, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(2)

                Spacer()

                if isLoadingWeekendResults {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if let weekendResultsError {
                Text(weekendResultsError)
                    .font(.inter(.caption))
                    .foregroundColor(.secondary)
            } else if weekendSessionResults.isEmpty && !isLoadingWeekendResults {
                Text("No practice/qualifying/race results available for this round.")
                    .font(.inter(.caption))
                    .foregroundColor(.secondary)
            } else if let session = selectedSessionSummary {
                VStack(spacing: 0) {
                    HStack {
                        Text("POS.")
                            .frame(width: 36, alignment: .leading)
                        Text("DRIVER")
                        Spacer()
                        Text("PTS.")
                            .frame(width: 36, alignment: .trailing)
                    }
                    .font(.inter(.caption2, weight: .bold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)

                    Divider().overlay(Color(.separator))

                    ForEach(Array(session.entries.prefix(12).enumerated()), id: \.element.id) { index, entry in
                        HStack(spacing: 10) {
                            Text("\(entry.position)")
                                .font(.inter(.subheadline, weight: .bold))
                                .frame(width: 36, alignment: .leading)
                                .foregroundColor(.primary)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(entry.driverCode)
                                    .font(.inter(.body, weight: .semibold))
                                    .foregroundColor(.primary)
                                Text(entry.teamName)
                                    .font(.inter(.caption))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Text(entry.pointsText)
                                .font(.inter(.subheadline, weight: .semibold))
                                .foregroundColor(.primary)
                                .frame(width: 36, alignment: .trailing)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)

                        if index < min(session.entries.count, 12) - 1 {
                            Divider().overlay(Color(.separator))
                        }
                    }
                }
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                Text("No results for the selected session.")
                    .font(.inter(.caption))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var selectedSessionSummary: WeekendSessionSummary? {
        let filtered = weekendSessionResults.filter { selectedSessionFilter.matches($0) }
        if let race = filtered.first(where: { "\($0.sessionName) \($0.sessionType)".lowercased().contains("race") }) {
            return race
        }
        return filtered.first
    }

    private var selectedRoundTitle: String {
        if let round = standingsVM.selectedRound,
           let selected = standingsVM.availableRounds.first(where: { $0.round == round }) {
            return selected.raceName.uppercased()
        }
        return "WEEKEND RESULTS"
    }

    private func loadHeadshotsIfNeeded() async {
        guard headshotsByNumber.isEmpty && headshotsByCode.isEmpty && headshotsByName.isEmpty else { return }

        do {
            let drivers = try await openF1Client.fetchDrivers(sessionKey: "latest")
            var byNumber: [Int: URL] = [:]
            var byCode: [String: URL] = [:]
            var byName: [String: URL] = [:]

            for driver in drivers {
                guard let raw = driver.headshotUrl, let url = URL(string: raw) else { continue }

                byNumber[driver.driverNumber] = url
                byCode[normalized(driver.nameAcronym)] = url
                byName[normalized(driver.fullName)] = url
            }

            headshotsByNumber = byNumber
            headshotsByCode = byCode
            headshotsByName = byName
        } catch {
            // Keep empty maps. UI will show placeholders.
        }
    }

    private func headshotURL(for standing: DriverStanding) -> URL? {
        if let byCode = headshotsByCode[normalized(standing.driverCode)] {
            return byCode
        }

        if let byName = headshotsByName[normalized(standing.driverName)] {
            return byName
        }

        guard let number = driverNumber(for: standing) else { return nil }
        return headshotsByNumber[number]
    }

    private func driverNumber(for standing: DriverStanding) -> Int? {
        if let matched = DriverInfo.all.values.first(where: { $0.abbreviation == standing.driverCode }) {
            return matched.number
        }
        if let matched = DriverInfo.all.values.first(where: { $0.fullName.caseInsensitiveCompare(standing.driverName) == .orderedSame }) {
            return matched.number
        }
        return nil
    }

    private func normalized(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .uppercased()
    }

    private func loadWeekendResults(for vm: StandingsViewModel) async {
        guard let selectedRound = vm.selectedRound else {
            weekendSessionResults = []
            weekendResultsError = nil
            lastWeekendResultsKey = nil
            return
        }

        let requestKey = "\(vm.selectedSeason)-\(selectedRound)"
        if lastWeekendResultsKey == requestKey, !weekendSessionResults.isEmpty {
            return
        }

        isLoadingWeekendResults = true
        weekendResultsError = nil

        do {
            guard let selectedRace = vm.availableRounds.first(where: { $0.round == selectedRound }) else {
                weekendSessionResults = []
                isLoadingWeekendResults = false
                return
            }

            let meetings = try await openF1Client.fetchMeetings(year: vm.selectedSeason)
            guard let matchedMeeting = bestMeetingMatch(
                forRaceName: selectedRace.raceName,
                round: selectedRound,
                meetings: meetings
            ) else {
                weekendResultsError = "Could not match this round to an OpenF1 weekend."
                weekendSessionResults = []
                isLoadingWeekendResults = false
                return
            }

            let sessions = try await openF1Client.fetchSessions(meetingKey: String(matchedMeeting.meetingKey))
                .filter(shouldIncludeSession)
                .sorted(by: { $0.dateStart < $1.dateStart })

            var summaries: [WeekendSessionSummary] = []
            for session in sessions {
                let results = try await openF1Client.fetchSessionResults(sessionKey: String(session.sessionKey))
                    .sorted(by: { $0.position < $1.position })

                guard !results.isEmpty else { continue }

                let entries = results.prefix(8).map { result in
                    let driverInfo = DriverInfo.all[result.driverNumber]
                    return WeekendSessionEntry(
                        id: "\(session.sessionKey)-\(result.driverNumber)",
                        position: result.position,
                        driverCode: driverInfo?.abbreviation ?? "#\(result.driverNumber)",
                        teamName: driverInfo?.teamName ?? "Unknown Team",
                        points: result.points
                    )
                }

                summaries.append(
                    WeekendSessionSummary(
                        sessionKey: session.sessionKey,
                        sessionName: session.sessionName,
                        sessionType: session.sessionType,
                        entries: entries
                    )
                )
            }

            weekendSessionResults = summaries
            lastWeekendResultsKey = requestKey
        } catch {
            weekendSessionResults = []
            weekendResultsError = "Failed to load weekend session results."
            lastWeekendResultsKey = nil
        }

        isLoadingWeekendResults = false
    }

    private func shouldIncludeSession(_ session: OpenF1Session) -> Bool {
        let value = "\(session.sessionName) \(session.sessionType)".lowercased()
        return value.contains("practice")
            || value.contains("qualifying")
            || value.contains("race")
            || value.contains("sprint")
            || value.contains("shootout")
    }

    private func bestMeetingMatch(forRaceName raceName: String, round: Int, meetings: [OpenF1Meeting]) -> OpenF1Meeting? {
        guard !meetings.isEmpty else { return nil }

        let sortedByDate = meetings.sorted(by: { $0.dateStart < $1.dateStart })
        let fallbackByRound = (round - 1) < sortedByDate.count && (round - 1) >= 0 ? sortedByDate[round - 1] : sortedByDate.last

        let raceTokens = tokenSet(from: raceName)
        var best: (meeting: OpenF1Meeting, score: Int)?

        for meeting in meetings {
            let meetingTokens = tokenSet(
                from: "\(meeting.meetingName) \(meeting.meetingOfficialName) \(meeting.countryName) \(meeting.location)"
            )
            let overlap = raceTokens.intersection(meetingTokens).count
            if let current = best {
                if overlap > current.score {
                    best = (meeting, overlap)
                }
            } else {
                best = (meeting, overlap)
            }
        }

        if let best, best.score > 0 {
            return best.meeting
        }

        return fallbackByRound
    }

    private func tokenSet(from value: String) -> Set<String> {
        let stopWords: Set<String> = [
            "grand", "prix", "formula", "world", "championship", "f1",
            "race", "official", "the", "etihad", "aramco"
        ]
        let tokens = value
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9 ]", with: " ", options: .regularExpression)
            .split(separator: " ")
            .map(String.init)
            .filter { $0.count > 2 && !stopWords.contains($0) }
        return Set(tokens)
    }
}

private struct WeekendSessionSummary: Identifiable, Hashable {
    let sessionKey: Int
    let sessionName: String
    let sessionType: String
    let entries: [WeekendSessionEntry]

    var id: Int { sessionKey }
}

private struct WeekendSessionEntry: Identifiable, Hashable {
    let id: String
    let position: Int
    let driverCode: String
    let teamName: String
    let points: Double?

    var pointsText: String {
        guard let points else { return "-" }
        return points.formatted(.number.precision(.fractionLength(0...1)))
    }
}

private struct DriverStandingRow: View {
    let standing: DriverStanding
    let imageURL: URL?

    var body: some View {
        HStack(spacing: 12) {
            Text("\(standing.position)")
                .font(.inter(.headline, design: .rounded, weight: .bold))
                .frame(width: 28)
                .foregroundColor(.secondary)

            DriverHeadshotView(imageURL: imageURL, code: standing.driverCode)

            VStack(alignment: .leading, spacing: 2) {
                Text(standing.driverName)
                    .font(.inter(.body, design: .default, weight: .semibold))
                    .foregroundColor(.primary)
                Text(standing.teamName)
                    .font(.inter(.caption))
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(standing.points.formatted(.number.precision(.fractionLength(0...1))))
                    .font(.inter(.headline, design: .rounded, weight: .bold))
                    .foregroundColor(.primary)
                Text("Wins \(standing.wins)")
                    .font(.inter(.caption))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ConstructorStandingRow: View {
    let standing: ConstructorStanding

    var body: some View {
        HStack(spacing: 12) {
            Text("\(standing.position)")
                .font(.inter(.headline, design: .rounded, weight: .bold))
                .frame(width: 28)
                .foregroundColor(.secondary)

            Text(standing.teamName)
                .font(.inter(.body, design: .default, weight: .semibold))
                .foregroundColor(.primary)

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(standing.points.formatted(.number.precision(.fractionLength(0...1))))
                    .font(.inter(.headline, design: .rounded, weight: .bold))
                    .foregroundColor(.primary)
                Text("Wins \(standing.wins)")
                    .font(.inter(.caption))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct DriverHeadshotView: View {
    let imageURL: URL?
    let code: String

    var body: some View {
        Group {
            if let imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure, .empty:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: 38, height: 38)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color(.separator), lineWidth: 1))
    }

    private var placeholder: some View {
        ZStack {
            Circle().fill(Color(.tertiarySystemFill))
            Text(code)
                .font(.inter(.caption2, design: .rounded, weight: .bold))
                .foregroundColor(.primary)
        }
    }
}

private struct DriverProfileView: View {
    let standing: DriverStanding
    let headshotURL: URL?
    let season: Int

    @State private var raceResults: [DriverRaceResult] = []
    @State private var isLoadingResults = false
    @State private var loadError: String?

    private let standingsService = F1StandingsService()
    private let heroHeight: CGFloat = 360

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [profileBackdropColor.opacity(0.92), Color(.systemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    heroHeader

                    VStack(alignment: .leading, spacing: 18) {
                        seasonMeta

                        Text("Top Results")
                            .font(.inter(.title2, design: .rounded, weight: .bold))
                            .foregroundColor(.primary)

                        resultsContent
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                    .background(Color(.systemBackground))
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task(id: standing.id) {
            await loadResults()
        }
    }

    private var heroHeader: some View {
        ZStack(alignment: .bottom) {
            Group {
                if let profileImageURL {
                    AsyncImage(url: profileImageURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity, minHeight: heroHeight, maxHeight: heroHeight)
                                .clipped()
                        case .empty, .failure:
                            heroPlaceholder
                        @unknown default:
                            heroPlaceholder
                        }
                    }
                } else {
                    heroPlaceholder
                }
            }
            .frame(height: heroHeight)
            .clipped()

            LinearGradient(
                colors: [.clear, .black.opacity(0.4), .black.opacity(0.85)],
                startPoint: .center,
                endPoint: .bottom
            )
            .frame(height: heroHeight)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(standing.driverName)
                        .font(.inter(size: 40, weight: .bold, design: .default))
                        .foregroundColor(.white)
                        .lineLimit(2)

                    Text(standing.teamName)
                        .font(.inter(.subheadline, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    private var seasonMeta: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(season) SEASON")
                .font(.inter(.caption, design: .rounded, weight: .bold))
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                statPill(title: "P\(standing.position)", subtitle: "Position")
                statPill(
                    title: standing.points.formatted(.number.precision(.fractionLength(0...1))),
                    subtitle: "Points"
                )
                statPill(title: String(standing.wins), subtitle: "Wins")
            }

            if let nationality = standing.nationality {
                Text(nationality)
                    .font(.inter(.footnote))
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private var resultsContent: some View {
        if isLoadingResults {
            ProgressView("Loading race results...")
                .padding(.top, 20)
        } else if let loadError {
            Text(loadError)
                .foregroundColor(.secondary)
        } else if raceResults.isEmpty {
            Text("No race result data available.")
                .foregroundColor(.secondary)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(raceResults.prefix(10).enumerated()), id: \.element.id) { index, result in
                    resultRow(result, index: index)

                    if index < min(raceResults.count, 10) - 1 {
                        Divider()
                            .overlay(Color(.separator))
                    }
                }
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func resultRow(_ result: DriverRaceResult, index: Int) -> some View {
        HStack(spacing: 12) {
            Text("\(index + 1)")
                .font(.inter(.subheadline, design: .rounded, weight: .bold))
                .foregroundColor(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(result.raceName)
                    .font(.inter(.subheadline, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text("R\(result.round) • \(result.status)")
                    .font(.inter(.caption))
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(result.finishPosition.map { "P\($0)" } ?? result.finishText)
                    .font(.inter(.subheadline, weight: .bold))
                    .foregroundColor(result.finishPosition == 1 ? .green : .primary)
                Text("+\(result.points.formatted(.number.precision(.fractionLength(0...1)))) pts")
                    .font(.inter(.caption))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func statPill(title: String, subtitle: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.inter(.headline, design: .rounded, weight: .bold))
                .foregroundColor(.primary)
            Text(subtitle)
                .font(.inter(.caption2))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var profileBackdropColor: Color {
        if let driver = DriverInfo.all.values.first(where: { $0.abbreviation == standing.driverCode }) {
            return driver.teamColor
        }
        return .appAccent
    }

    private var heroPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [Color(.systemGray3), Color(.systemGray5)],
                startPoint: .top,
                endPoint: .bottom
            )
            Text(standing.driverCode)
                .font(.inter(size: 90, weight: .black, design: .rounded))
                .foregroundColor(.white.opacity(0.45))
        }
    }

    private var profileImageURL: URL? {
        if let formula1URL = formula1DriverImageURL(driverId: standing.driverId) {
            return formula1URL
        }
        return headshotURL
    }

    private func formula1DriverImageURL(driverId: String) -> URL? {
        let slugOverrides: [String: String] = [
            "max_verstappen": "verstappen",
            "sergio_perez": "perez",
            "charles_leclerc": "leclerc",
            "george_russell": "russell",
            "kevin_magnussen": "magnussen",
            "zhou_guanyu": "zhou"
        ]

        let slug: String
        if let override = slugOverrides[driverId.lowercased()] {
            slug = override
        } else {
            slug = driverId
                .lowercased()
                .split(separator: "_")
                .last
                .map(String.init) ?? driverId.lowercased()
        }

        return URL(string: "https://www.formula1.com/content/dam/fom-website/drivers/2025Drivers/\(slug).png")
    }

    private func loadResults() async {
        guard !isLoadingResults else { return }
        isLoadingResults = true
        loadError = nil

        do {
            raceResults = try await standingsService.fetchDriverRaceResults(
                season: season,
                driverId: standing.driverId
            )
        } catch {
            raceResults = []
            loadError = "Could not load detailed results."
        }

        isLoadingResults = false
    }
}

// MARK: - Predictions Tab
struct PredictionsTab: View {
    @Environment(TelemetryViewModel.self) private var telemetryVM
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    PredictionOverlayView(
                        prediction: PredictionResult(driverNumber: 1, winProbability: 0.82, predictedNextLapTime: 92.4)
                    )
                    
                    PredictionOverlayView(
                        prediction: PredictionResult(driverNumber: 4, winProbability: 0.12, predictedNextLapTime: 91.8)
                    )
                    
                    PredictionOverlayView(
                        prediction: PredictionResult(driverNumber: 44, winProbability: 0.04, predictedNextLapTime: 92.1)
                    )
                }
                .padding()
            }
            .background(Color(.systemBackground))
            .navigationTitle("ML Predictions")
        }
    }
}

// MARK: - Settings Tab
struct SettingsTab: View {
    @Environment(AuthViewModel.self) private var authVM
    @State private var delayOffset: Double = 0.0
    @State private var notificationsEnabled = true
    @State private var hapticFeedback = true
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    if let session = authVM.currentSession {
                        HStack {
                            Text("Subscriber")
                            Spacer()
                            Text(session.subscriberId)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        HStack {
                            Text("Region")
                            Spacer()
                            Text(session.country)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button("Sign Out", role: .destructive) {
                        authVM.logout()
                    }
                }
                
                Section("Stream Sync") {
                    VStack(alignment: .leading) {
                        Text("Visualization Delay: \(String(format: "%.1f", delayOffset))s")
                        Slider(value: $delayOffset, in: -5...10, step: 0.5)
                            .tint(.appAccent)
                    }
                }
                
                Section("Notifications") {
                    Toggle("Race Control Messages", isOn: $notificationsEnabled)
                    Toggle("Haptic Feedback", isOn: $hapticFeedback)
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Data Source")
                        Spacer()
                        Text("OpenF1 API")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(.systemBackground))
            .navigationTitle("Settings")
        }
    }
}

// MARK: - Track Status Banner
fileprivate struct TrackStatusBanner: View {
    let status: TrackStatus
    
    var body: some View {
        if status != .allClear && status != .unknown {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                Text(status.description.uppercased())
                    .font(.inter(.headline))
                    .fontWeight(.black)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(bannerColor)
            .foregroundColor(status == .yellow ? .black : .white)
            .animation(.spring(), value: status)
        }
    }
    
    private var bannerColor: Color {
        switch status {
        case .yellow, .virtualSafetyCar: return .yellow
        case .safetyCar: return .orange
        case .redFlag: return .red
        default: return .clear
        }
    }
}
