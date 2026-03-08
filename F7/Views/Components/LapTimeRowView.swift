import SwiftUI

/// Reusable component for displaying driver lap times conforming strictly to Apple HIG.
/// Implements `.monospacedDigit()` to enforce tabular lining,
/// preventing horizontal jitter when milliseconds update frequently.
public struct LapTimeRowView: View {
    public let timingData: TimingData
    
    private var driverInfo: DriverInfo? {
        DriverInfo.all[timingData.driverNumber]
    }
    
    public var body: some View {
        HStack(alignment: .center, spacing: 10) {
            // Team color bar
            RoundedRectangle(cornerRadius: 2)
                .fill(driverInfo?.teamColor ?? .gray)
                .frame(width: 4, height: 32)
            
            // Grid Position
            Text("\(timingData.position)")
                .font(.inter(.subheadline, design: .rounded, weight: .bold))
                .foregroundColor(.secondary)
                .frame(width: 24, alignment: .trailing)
            
            // Driver abbreviation
            Text(driverInfo?.abbreviation ?? "---")
                .font(.inter(.headline, design: .default, weight: .bold))
                .foregroundColor(.primary)
                .frame(width: 44, alignment: .leading)
            
            // Last lap time
            if let lastLap = timingData.lastLapTime {
                Text(formatLapTime(lastLap))
                    .font(.inter(.caption, design: .monospaced, weight: .regular))
                    .monospacedDigit()
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Pit indicator
            if timingData.inPitLane {
                Text("PIT")
                    .font(.inter(.caption2, design: .default, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.yellow)
                    .cornerRadius(4)
            }
            
            // Interval to Leader
            if let interval = timingData.intervalToLeader {
                Text("+\(String(format: "%.3f", interval))")
                    .font(.inter(.subheadline, design: .rounded, weight: .medium))
                    .monospacedDigit()
                    .foregroundColor(.secondary)
            } else {
                Text("INTERVAL")
                    .font(.inter(.caption2, design: .default, weight: .semibold))
                    .foregroundColor(Color(red: 0.6, green: 0.2, blue: 0.9))
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(timingData.position % 2 == 0 ? Color.white.opacity(0.03) : Color.clear)
    }
    
    private func formatLapTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = seconds - Double(mins * 60)
        return String(format: "%d:%06.3f", mins, secs)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 0) {
        LapTimeRowView(timingData: TimingData(driverNumber: 1, position: 1, lastLapTime: 91.234, intervalToLeader: nil))
        LapTimeRowView(timingData: TimingData(driverNumber: 4, position: 2, lastLapTime: 91.456, intervalToLeader: 0.892))
        LapTimeRowView(timingData: TimingData(driverNumber: 30, position: 3, lastLapTime: 92.012, intervalToLeader: 1.204, inPitLane: true))
    }
    .background(Color.black)
}
