import SwiftUI

/// Root view with TabView navigation for the full app experience.
public struct RaceDashboardView: View {
    
    @Environment(TelemetryViewModel.self) private var telemetryVM
    @Environment(ContentBrowserViewModel.self) private var contentBrowserVM
    @Environment(VideoPlayerViewModel.self) private var videoPlayerVM
    @Environment(AuthViewModel.self) private var authVM
    
    public var body: some View {
        TabView {
            LiveTimingTab()
                .environment(telemetryVM)
                .tabItem {
                    Label("Live", systemImage: "antenna.radiowaves.left.and.right")
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
        .preferredColorScheme(.dark)
        .tint(.red)
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

// MARK: - Live Timing Tab
struct LiveTimingTab: View {
    @Environment(TelemetryViewModel.self) private var telemetryVM

    private var sortedDrivers: [TimingData] {
        telemetryVM.timingDataByDriver.values.sorted { $0.position < $1.position }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        // Track Status Banner
                        TrackStatusBanner(status: telemetryVM.currentTrackStatus)

                        // Session Info Header
                        SessionInfoHeader()
                            .padding(.horizontal)
                            .padding(.top, 8)

                        LiveMapPanel(drivers: sortedDrivers)
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

                        // Timing Tower
                        LazyVStack(spacing: 0) {
                            ForEach(sortedDrivers) { driverTiming in
                                LapTimeRowView(timingData: driverTiming)
                            }
                        }
                        .background(Color(white: 0.08))
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
                        .fill(.red)
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle()
                                .fill(.red.opacity(0.4))
                                .frame(width: 16, height: 16)
                        )
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Text("LAP 42/57")
                        .font(.system(.caption, design: .monospaced, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Session Info Header
fileprivate struct SessionInfoHeader: View {
    var body: some View {
        VStack(spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("FORMULA 1")
                        .font(.system(.caption2, design: .default, weight: .bold))
                        .foregroundColor(.red)
                    Text("Monaco Grand Prix 2025")
                        .font(.system(.title3, design: .default, weight: .bold))
                        .foregroundColor(.white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("RACE")
                        .font(.system(.caption2, design: .default, weight: .bold))
                        .foregroundColor(.green)
                    Text("Circuit de Monaco")
                        .font(.system(.caption, design: .default, weight: .regular))
                        .foregroundColor(.secondary)
                }
            }
            
            // Gap/Speed quick stats
            HStack(spacing: 16) {
                StatPill(label: "LEADER", value: "VER", color: Color(red: 0.14, green: 0.21, blue: 0.58))
                StatPill(label: "FASTEST", value: "1:31.234", color: .purple)
                StatPill(label: "DRS", value: "ENABLED", color: .green)
            }
        }
        .padding(12)
        .background(Color(white: 0.08))
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
                .font(.system(.caption2, design: .default, weight: .medium))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(.caption, design: .monospaced, weight: .bold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }
}

fileprivate struct LiveMapPanel: View {
    let drivers: [TimingData]

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
                .font(.system(.headline, design: .default, weight: .bold))
                .foregroundColor(.white)

            GeometryReader { proxy in
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(white: 0.06))

                    MonacoTrackShape()
                        .stroke(Color.white.opacity(0.35), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: [8, 6]))
                        .padding(22)

                    ForEach(Array(topDrivers.enumerated()), id: \.element.id) { index, driver in
                        let point = markerPoint(for: driver, in: proxy.size)
                        Circle()
                            .fill(driverColor(driver))
                            .frame(width: 12, height: 12)
                            .overlay(Circle().stroke(Color.black, lineWidth: 1))
                            .position(point)

                        Text(driverLabel(driver, index: index))
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(4)
                            .position(x: point.x, y: max(10, point.y - 14))
                    }
                }
            }
            .frame(height: 210)

            HStack(spacing: 8) {
                StatPill(label: "LEADER", value: leaderCode, color: .white)
                StatPill(label: "GAP P2", value: gapToP2, color: .yellow)
                StatPill(label: "AVG TOP5", value: averageTop5LastLap, color: .green)
            }
        }
        .padding(12)
        .background(Color(white: 0.08))
        .cornerRadius(12)
    }

    private func markerPoint(for driver: TimingData, in size: CGSize) -> CGPoint {
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

    private func driverColor(_ driver: TimingData) -> Color {
        DriverInfo.all[driver.driverNumber]?.teamColor ?? .gray
    }

    private func driverLabel(_ driver: TimingData, index: Int) -> String {
        let code = DriverInfo.all[driver.driverNumber]?.abbreviation ?? "#\(driver.driverNumber)"
        return "P\(driver.position) \(code)"
    }
}

fileprivate struct MonacoTrackShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        path.move(to: CGPoint(x: rect.minX + rect.width * 0.18, y: rect.maxY - rect.height * 0.22))
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.30, y: rect.maxY - rect.height * 0.12),
            control1: CGPoint(x: rect.minX + rect.width * 0.20, y: rect.maxY - rect.height * 0.10),
            control2: CGPoint(x: rect.minX + rect.width * 0.26, y: rect.maxY - rect.height * 0.06)
        )
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY - rect.height * 0.18),
            control1: CGPoint(x: rect.minX + rect.width * 0.36, y: rect.maxY - rect.height * 0.20),
            control2: CGPoint(x: rect.minX + rect.width * 0.44, y: rect.maxY - rect.height * 0.22)
        )

        path.addCurve(
            to: CGPoint(x: rect.maxX - rect.width * 0.16, y: rect.maxY - rect.height * 0.34),
            control1: CGPoint(x: rect.minX + rect.width * 0.58, y: rect.maxY - rect.height * 0.10),
            control2: CGPoint(x: rect.maxX - rect.width * 0.20, y: rect.maxY - rect.height * 0.08)
        )
        path.addCurve(
            to: CGPoint(x: rect.maxX - rect.width * 0.20, y: rect.midY),
            control1: CGPoint(x: rect.maxX - rect.width * 0.10, y: rect.maxY - rect.height * 0.50),
            control2: CGPoint(x: rect.maxX - rect.width * 0.14, y: rect.maxY - rect.height * 0.44)
        )

        path.addCurve(
            to: CGPoint(x: rect.maxX - rect.width * 0.36, y: rect.minY + rect.height * 0.18),
            control1: CGPoint(x: rect.maxX - rect.width * 0.26, y: rect.minY + rect.height * 0.34),
            control2: CGPoint(x: rect.maxX - rect.width * 0.30, y: rect.minY + rect.height * 0.24)
        )
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.12),
            control1: CGPoint(x: rect.maxX - rect.width * 0.34, y: rect.minY + rect.height * 0.10),
            control2: CGPoint(x: rect.minX + rect.width * 0.56, y: rect.minY + rect.height * 0.08)
        )

        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.24, y: rect.minY + rect.height * 0.26),
            control1: CGPoint(x: rect.minX + rect.width * 0.40, y: rect.minY + rect.height * 0.16),
            control2: CGPoint(x: rect.minX + rect.width * 0.30, y: rect.minY + rect.height * 0.18)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.18, y: rect.maxY - rect.height * 0.22),
            control1: CGPoint(x: rect.minX + rect.width * 0.12, y: rect.minY + rect.height * 0.42),
            control2: CGPoint(x: rect.minX + rect.width * 0.08, y: rect.maxY - rect.height * 0.38)
        )

        return path
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
                    .font(.system(.headline, design: .default, weight: .bold))
                    .foregroundColor(.white)

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
                    .font(.caption)
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
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(timeString(message.timestamp))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Text(message.message)
                                .font(.caption)
                                .foregroundColor(.white)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(12)
        .background(Color(white: 0.08))
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

// MARK: - Weather Widget
fileprivate struct WeatherWidget: View {
    let weather: OpenF1Weather
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: weatherIcon(rainfall: weather.rainfall))
                .font(.system(size: 32))
                .foregroundColor(.white)
                
            VStack(alignment: .leading, spacing: 4) {
                Text("Air: \(String(format: "%.1f", weather.airTemperature))°C")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Track: \(String(format: "%.1f", weather.trackTemperature))°C")
                    .font(.caption)
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("Wind: \(String(format: "%.1f", weather.windSpeed)) m/s")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Rainfall: \(weather.rainfall == 1 ? "Yes" : "No")")
                    .font(.caption)
                    .foregroundColor(weather.rainfall == 1 ? .blue : .secondary)
            }
        }
        .padding(16)
        .background(Color(white: 0.08))
        .cornerRadius(12)
    }
    
    private func weatherIcon(rainfall: Int) -> String {
        return rainfall == 1 ? "cloud.rain" : "sun.max"
    }
}

// MARK: - Standings Tab
struct StandingsTab: View {
    @Environment(StandingsViewModel.self) private var standingsVM

    var body: some View {
        NavigationStack {
            @Bindable var vm = standingsVM

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Picker("Season", selection: $vm.selectedSeason) {
                        ForEach(vm.availableSeasons, id: \.self) { season in
                            Text(String(season)).tag(season)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("Grand Prix", selection: $vm.selectedRound) {
                        Text("Season Total").tag(Optional<Int>.none)
                        ForEach(vm.availableRounds) { round in
                            Text("R\(round.round) \(round.raceName)").tag(Optional(round.round))
                        }
                    }
                    .pickerStyle(.menu)

                    Spacer()
                }
                .padding(.horizontal, 16)

                Text(vm.selectedRoundLabel)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)

                Picker("Category", selection: $vm.selectedCategory) {
                    ForEach(StandingsViewModel.Category.allCases, id: \.self) { category in
                        Text(category.rawValue).tag(category)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)

                if vm.isLoading {
                    Spacer()
                    ProgressView("Loading standings...")
                    Spacer()
                } else if let error = vm.errorMessage {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .font(.title)
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
                } else {
                    List {
                        if vm.selectedCategory == .drivers {
                            ForEach(vm.driverStandings) { standing in
                                DriverStandingRow(standing: standing)
                                    .listRowBackground(Color(white: 0.1))
                            }
                        } else {
                            ForEach(vm.constructorStandings) { standing in
                                ConstructorStandingRow(standing: standing)
                                    .listRowBackground(Color(white: 0.1))
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color.black)
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Standings")
            .task(id: vm.selectedSeason) { await vm.seasonChanged() }
            .task(id: vm.selectedRound ?? -1) { await vm.roundChanged() }
        }
    }
}

private struct DriverStandingRow: View {
    let standing: DriverStanding

    var body: some View {
        HStack(spacing: 12) {
            Text("\(standing.position)")
                .font(.system(.headline, design: .rounded, weight: .bold))
                .frame(width: 28)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(standing.driverName)
                    .font(.system(.body, design: .default, weight: .semibold))
                    .foregroundColor(.white)
                Text(standing.teamName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(standing.points.formatted(.number.precision(.fractionLength(0...1))))
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundColor(.white)
                Text("Wins \(standing.wins)")
                    .font(.caption)
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
                .font(.system(.headline, design: .rounded, weight: .bold))
                .frame(width: 28)
                .foregroundColor(.secondary)

            Text(standing.teamName)
                .font(.system(.body, design: .default, weight: .semibold))
                .foregroundColor(.white)

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(standing.points.formatted(.number.precision(.fractionLength(0...1))))
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundColor(.white)
                Text("Wins \(standing.wins)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
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
            .background(Color.black)
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
                            .tint(.red)
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
            .background(Color.black)
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
                    .font(.headline)
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
